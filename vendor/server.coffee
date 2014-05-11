url        = require 'url'
path       = require 'path'
http       = require 'http'
zlib       = require 'zlib'
resolve    = require 'resolve-path'
onFinished = require 'finished'

STATIC_DIR = process.env['STATIC_DIR'] || '.'

if process.env['USE_CACHELICIOUS']
  cachelicious = require 'cachelicious'
  CacheliciousFs = cachelicious.fs
  fs = new CacheliciousFs(process.env['CACHE_SIZE'] || 50 * 1024 * 1024)
else
  fs = require 'fs'

ONE_HOUR = 60 * 60
ONE_WEEK = ONE_HOUR * 24 * 7
ONE_MONTH = ONE_WEEK * 4
ONE_YEAR = ONE_MONTH * 12

staticHandler = (pathname, req, res, callback) ->
  try
    pathname = parse(req.url).pathname
    absolutePath = resolve req.path.slice 1
    stream = fs.createReadStream absolutePath
    stream.pipe res
    onFinished res, (err) ->
      stream.destroy()
      callback err if err
      return
  catch err
    callback err
  return

errorHandler = (err, pathname, req, res) ->
  console.error "#{pathname}: ", err.stack

  res.status err.status || 500
  if req.xhr
    res.send
      error: if err.status is 404 then '404 Not Found' else 'Something blew up!'
  else
    pathname = "/error/#{err.status || 500}.html"
    staticHandler pathname, req, res, (err) ->
      res.send 'Something blew up!'
      return
  return

error404 = (pathname, req, res) ->
  err = new Error('File Not Found')
  err.status = 404
  errorHandler err
  return

app = http.createServer (req, res) ->
  {pathname, query} = parse(req.url).pathname
  return error404 pathname, req, res if pathname[1] is '_' or /^\/(.*\/_.*|node_modules\/.*|package.json|server.js|Procfile|vendor\/.*)$/.test pathname

  pathname = pathname /^(.+)\.(\d+)\.(js|css|png|jpg|gif)$/, '$1.$3'
  host = req.headers.host

  res.removeHeader 'X-Powered-By'
  res.removeHeader 'Last-Modified'

  pathname = path.join pathname, process.env['INDEX_FILE'] || 'index.html' if /.*\/[^\.\/]*$/.test pathname

  staticHandler pathname, req, res, (err) ->
   error404 pathname, req, res
   return
  return


server = app.listen process.env['PORT'], ->
  address = server.address();
  console.log "Listening on port #{address.port}..."
  return
