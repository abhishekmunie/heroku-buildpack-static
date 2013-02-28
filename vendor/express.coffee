fs            = require 'fs'
url           = require 'url'
path          = require 'path'
http          = require 'http'
zlib          = require 'zlib'
express       = require 'express'
StreamCache   = require 'StreamCache'

files_cached = 0
generateFileCache = (file) ->
  fbp++
  files_cached++
  data_raw = new StreamCache
  src = fs.createReadStream(file)
  src.once 'end', ->
    data_gzipped = new StreamCache
    srcgz = data_raw.pipe(zlib.createGzip())
    srcgz.once 'end', ->
      data = if gzipped = data_gzipped.getLength() < 0.85*data_raw.getLength() then data_gzipped else data_raw
      etag = data.hash()
      fileCache[('/' + path.relative _STATIC_DIR, file).split('index.html')[0].split('index.htm')[0]] =
        data: data
        gzipped: gzipped
        etag: etag
      fbp--
      process.nextTick createServer if ccs and fbp == 0
    srcgz.pipe data_gzipped
  src.on 'error', (e) ->
    fbp--
    console.error "Could not cache: #{file} as #{e}"
    files_cached--
  src.pipe data_raw

_STATIC_DIR = __dirname

fileCache = {}
fbp = 0
ccs = false

ONE_HOUR = 60 * 60
ONE_WEEK = ONE_HOUR * 24 * 7
ONE_MONTH = ONE_WEEK * 4
ONE_YEAR = ONE_MONTH * 12

createServer = ->
  console.log "Number of files cached: #{files_cached}"
  console.timeEnd 'Caching Files'
  console.time 'Starting Server'
  C404 = fileCache['/404.html'] or fileCache['/404.htm']

  app = express()

  app.configure () ->
    if process.env.FORCE_HTTPS_HOST
      app.use (req, res, next) ->
        if req.headers['x-forwarded-proto'] == 'https' or req.secure
          next()
        else
          res.redirect 301, process.env.FORCE_HTTPS_HOST + req.path
    app.use express.favicon()
    app.use express.cookieParser process.env.COOKIE_SECRET if process.env.COOKIE_SECRET
    app.use express.bodyParser()
    app.use express.session secret: process.env.SESSION_SECRET if process.env.SESSION_SECRET

  app.get '*', (req, res) ->
    reql = "Req: #{req.url}"
    console.time reql
    req.url = req.url.replace(/^(.+)\.(\d+)\.(js|css|png|jpg|gif)$/, '$1.$3');
    uri = url.parse(req.url).pathname

    res.removeHeader 'X-Powered-By'
    res.removeHeader 'Last-Modified'

    if cache = fileCache[uri]
      type = (uri.replace(/.*[\.\/]/, '').toLowerCase() || 'html')
      res.status 200
      res.type type
      res.set 'content-encoding', 'gzip' if cache.gzipped
      res.set 'X-UA-Compatible', 'IE=Edge,chrome=1' if req.headers['user-agent'].indexOf('MSIE') > -1 && /html?($|\?|#)/.test url
      res.set
        'Transfer-Encoding'           : 'chunked'
        'Vary'                        : 'Accept-Encoding'
        'Connection'                  : 'Keep-Alive'
        'ETag'                        : cache.etag
        'cache-control'               : ((type) ->
          if /(text\/(cache-manifest|html|xml)|application\/(xml|json))/.test type
              cc = 'public,max-age=0';
            # Feed
          else if /application\/(rss\+xml|atom\+xml)/.test type
              cc = 'public,max-age=' + ONE_HOUR;
            # Favicon (cannot be renamed)
          else if /image\/x-icon/.test type
              cc = 'public,max-age=' + ONE_WEEK;
            # Media: images, video, audio
            # HTC files  (css3pie)
            # Webfonts
            # (we should probably put these regexs in a variable)
          else if /(image|video|audio|text\/x-component|application\/font-woff|application\/x-font-ttf|application\/vnd\.ms-fontobject|font\/opentype)/.test type
              cc = 'public,max-age=' + ONE_MONTH;
            # CSS and JavaScript
          else if /(text\/(css|x-component)|application\/javascript)/.test type
              cc = 'public,max-age=' + ONE_YEAR;
            # Misc
          else
              cc = 'public,max-age=' + ONE_MONTH
          )(type) + ',no-transform'
    else
      cache = C404
      res.set 'content-encoding', 'gzip' if cache.gzipped
      res.status 404
      res.type "html"
      res.set
        'content-encoding'            : 'gzip'
        'Transfer-Encoding'           : 'chunked'
        'Vary'                        : 'Accept-Encoding'
        'ETag'                        : cache.etag

    try
      cache.data.once 'end', ->
        console.log 'hi'
        res.end()
        console.timeEnd reql
      cache.data.pipe res
    catch e
      res.end "Request: " + req.url + "\nOops! node toppled while getting: " + url.parse(req.url).pathname

  app.listen process.env.PORT || process.env.C9_PORT || process.env.VCAP_APP_PORT || process.env.VMC_APP_PORT || 1337 || 8001, ->
    console.timeEnd 'Starting Server'
    console.log "Listening ..."

console.time 'Caching Files'
walk = (dir, error, onFile, end) ->
  fs.readdir dir, (err, list) ->
    if err
      error(err)
      return end()
    l = list.length
    return end() if l == 0
    for file in list
      if file == 'Icon\r' or /(^|\/)\./.test(file) or /\.(bak|config|sql|fla|psd|ini|log|sh|inc|swp|dist|tmp|node_modules|bin)|~/.test(file)
        l--
        continue
      ((fn) ->
        fs.lstat fn, (err, stat) ->
          if stat and stat.isDirectory()
            walk fn, error, onFile, ->
              end() if --l == 0
          else
            onFile fn
            end() if --l == 0
      )(dir + '/' + file)

walk path.relative(_STATIC_DIR, __dirname) || '.', (err) ->
  console.error err
, (file) ->
  process.nextTick -> generateFileCache file
, ->
  if fbp == 0
    process.nextTick createServer
  else
    ccs = true