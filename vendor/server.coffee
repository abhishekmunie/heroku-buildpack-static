url        = require 'url'
path       = require 'path'
http       = require 'http'
zlib       = require 'zlib'
resolve    = require 'resolve-path'
mime       = require 'mime-types'
onFinished = require 'finished'

STATIC_DIR = process.env['STATIC_DIR'] or '.'

if process.env['USE_CACHELICIOUS']
  cachelicious = require 'cachelicious'
  CacheliciousFs = cachelicious.fs
  fs = new CacheliciousFs(process.env['CACHE_SIZE'] or 50 * 1024 * 1024)
else
  fs = require 'fs'

## cache values
ONE_HOUR = 60 * 60
ONE_WEEK = ONE_HOUR * 24 * 7
ONE_MONTH = ONE_WEEK * 4
ONE_YEAR = ONE_MONTH * 12

staticHandler = (pathname, req, res, callback) ->
  try
    absolutePath = resolve path.resolve(STATIC_DIR), pathname.slice 1
    stream = fs.createReadStream absolutePath
    res.setHeader "Content-Type", mime.lookup pathname
    stream.on 'error', (err) ->
      callback err
    stream.pipe res
    onFinished res, (err) ->
      stream.destroy()
      return
  catch err
    callback err
  return

errorHandler = (err, pathname, req, res) ->
  console.error "#{pathname}: ", err.stack

  res.statusCode = err.status or 500
  pathname = "/error/#{err.status or 500}.html"
  staticHandler pathname, req, res, (err) ->
    res.setHeader 'Content-Type', 'text/plain'
    res.end if res.statusCode is 404 then '404 Not Found!' else 'Something blew up!'
    return
  return

error404 = (pathname, req, res) ->
  err = new Error('File Not Found')
  err.status = 404
  errorHandler err, pathname, req, res
  return

app = http.createServer (req, res) ->
  {pathname, query} = url.parse req.url
  return error404 pathname, req, res if pathname[1] is '_' or /^\/(.*\/_.*|node_modules\/.*|package.json|server.js|Procfile|vendor\/.*)$/.test pathname

  pathname = pathname.replace /^\/[0-9a-f]{40}\/(.*)$/, '/$1'
  pathname = pathname.replace /^(.+)\.(\d+)\.(js|css|png|jpg|gif|jpeg)$/, '$1.$3'

  res.removeHeader 'X-Powered-By'
  res.removeHeader 'Last-Modified'

  pathname = path.join pathname, process.env['INDEX_FILE'] or 'index.html' if /.*\/[^\.\/]*$/.test pathname

  res.statusCode = 200
  staticHandler pathname, req, res, (err) ->
   error404 pathname, req, res
   return
  return

server = app.listen process.env['PORT'] or 1337, ->
  address = server.address();
  console.log "Listening on port #{address.port}..."
  return
