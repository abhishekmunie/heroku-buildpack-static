fs            = require 'fs'
url           = require 'url'
path          = require 'path'
http          = require 'http'
zlib          = require 'zlib'
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

  app = http.createServer (req, res) ->
    reql = "Req: #{req.url}"
    console.time reql
    req.url = req.url.replace(/^(.+)\.(\d+)\.(js|css|png|jpg|gif)$/, '$1.$3');
    uri = url.parse(req.url).pathname

    res.removeHeader 'X-Powered-By'
    res.removeHeader 'Last-Modified'

    if cache = fileCache[uri]
      type = (uri.replace(/.*[\.\/]/, '').toLowerCase() || 'html')
      res.setHeader 'content-encoding', 'gzip' if cache.gzipped
      res.setHeader 'X-UA-Compatible', 'IE=Edge,chrome=1' if req.headers['user-agent'].indexOf('MSIE') > -1 && /html?($|\?|#)/.test url
      res.writeHead 200,
        'Content-Type'                : mimeTypes[type]
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
      res.setHeader 'content-encoding', 'gzip' if cache.gzipped
      res.writeHead 404,
        'Content-Type'                : 'text/html'
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

mimeTypes =
  'js': 'application/javascript'
  'jsonp': 'application/javascript'
  'json': 'application/json'
  'css': 'text/css'
  'oga': 'audio/ogg'
  'ogg': 'audio/ogg'
  'm4a': 'audio/mp4'
  'f4a': 'audio/mp4'
  'f4b': 'audio/mp4'
  'ogv': 'video/ogg'
  'mp4': 'video/mp4'
  'm4v': 'video/mp4'
  'f4v': 'video/mp4'
  'f4p': 'video/mp4'
  'webm': 'video/webm'
  'flv': 'video/x-flv'
  'eot': 'application/vnd.ms-fontobject'
  'ttf': 'application/x-font-ttf'
  'ttc': 'application/x-font-ttf'
  'otf': 'font/opentype'
  'woff': 'application/font-woff'
  'webp': 'image/webp'
  'appcache': 'text/cache-manifest'
  'manifest': 'text/cache-manifest'
  'htc': 'text/x-component'
  'rss': 'application/rss+xml'
  'atom': 'application/atom+xml'
  'xml': 'application/xml'
  'rdf': 'application/xml'
  'crx': 'application/x-chrome-extension'
  'oex': 'application/x-opera-extension'
  'xpi': 'application/x-xpinstall'
  'safariextz': 'application/octet-stream'
  'webapp': 'application/x-web-app-manifest+json'
  'vcf': 'text/x-vcard'
  'swf': 'application/x-shockwave-flash'
  'vtt': 'text/vtt'
  'html': 'text/html'
  'htm': 'text/html'
  'bmp': 'image/bmp'
  'gif': 'image/gif'
  'jpeg': 'image/jpeg'
  'jpg': 'image/jpeg'
  'jpe': 'image/jpeg'
  'png': 'image/png'
  'svg': 'image/svg+xml'
  'svgz': 'image/svg+xml'
  'tiff': 'image/tiff'
  'tif': 'image/tiff'
  'ico': 'image/x-icon'

console.time 'Caching Files'
walk = (dir, error, onFile, end) ->
  fs.readdir dir, (err, list) ->
    if err
      error(err)
      return end()
    l = list.length
    return end() if l == 0
    for file in list
      if file == 'Icon\r' or /(^|\/)\./.test(file) or /\.(bak|config|sql|fla|psd|ini|log|sh|inc|swp|dist|tmp)|~/.test(file)
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