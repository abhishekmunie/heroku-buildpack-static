path    = require 'path'
http    = require 'http'
express = require 'express'
favicon = require 'static-favicon'

STATIC_DIR = process.env['STATIC_DIR'] || '.'

if process.env['USE_CACHELICIOUS']
  cachelicious = require 'cachelicious'
  cacheliciousConnect = cachelicious.connect
  staticHandler = cacheliciousConnect STATIC_DIR, maxCacheSize: process.env['CACHE_SIZE'] || 50 * 1024 * 1024
else
  serveStatic = require 'serve-static'
  staticHandler = serveStatic STATIC_DIR

app = express()

app.set 'port', process.env['PORT'] || 1337

app.enable 'trust proxy'
console.log path.resolve STATIC_DIR, 'favicon.ico'
app.use favicon path.resolve STATIC_DIR, 'favicon.ico'

## catch 404 and forwarding to error handler
app.use '/error', (req, res, next) ->
  err = new Error('File Not Found')
  err.status = 404
  next err
  return

if process.env['USE_CACHEBUSTING_API']
  console.log "Using Cachebusting"
  fs = require 'fs'
  resolve = require 'resolve-path'
  crypto = require 'crypto'
  app.get /^\/_api\/(.+)$/, (req, res, next) ->
    sha1Hash = crypto.createHash 'sha1'
    sha1Hash.setEncoding 'hex'
    try
      rs = fs.ReadStream resolve path.resolve(STATIC_DIR), req.params[0]
      rs.on 'end', ->
        sha1Hash.end()
        sha1 = sha1Hash.read()
        res.format
          'text/plain': ->
            res.send sha1
            return
          'text/html': ->
            res.send sha1
            return
          'application/json': ->
            res.send
              sha1: sha1
            return
        return
      rs.pipe sha1Hash
    catch err
      next err
    return

  app.use (req, res, next) ->
    req.url = req.url.replace /^\/[0-9a-f]{40}\/(.*)$/, '/$1'
    next()
    return

app.all /.*\/[^\.\/]*$/, (req, res, next) ->
  [urlPath, query] = req.url.split '?'
  [urlPath, query] = req.url.split '?'
  req.url = "#{path.join urlPath, process.env['INDEX_FILE'] || 'index.html'}#{if query then "?#{query}" else ""}"
  next()
  return

## static content handler
app.use (req, res, next) ->
  return next() if req.url[1] is '_' or /^\/(.*\/_.*|node_modules\/.*|package.json|server.js|Procfile|vendor\/.*)$/.test req.url
  req.url = req.url.replace /^(.+)\.(\d+)\.(js|css|png|jpg|gif|jpeg)$/, '$1.$3'
  res.removeHeader 'X-Powered-By'
  res.removeHeader 'Last-Modified'
  return staticHandler.apply @, arguments

## catch 404 and forwarding to error handler
app.use (req, res, next) ->
  err = new Error('File Not Found')
  err.status = 404
  next err
  return

## error handler
app.use (err, req, res, next) ->
  console.error "#{req.url}: ", err.stack
  next err
  return

app.use (err, req, res, next) ->
  res.status err.status || 500
  if req.xhr
    res.send
      error: if err.status is 404 then '404 Not Found' else 'Something blew up!'
  else
    req.url = "/error/#{err.status || 500}.html"
    return staticHandler.apply @, [req, res, next]
  return

app.use (err, req, res, next) ->
  res.send 'Something blew up!'
  return

server = http.createServer(app).listen app.get('port'), ->
  address = server.address();
  console.log "Listening on port #{address.port}..."
  return
