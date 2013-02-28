Util   = require 'util'
crypto = require 'crypto'
Stream = require('stream').Stream

module.exports = class StreamCache extends Stream

  constructor: ->
    Stream.call this

    @writable = true
    @readable = true

    @_buffers = []
    @_dests   = []
    @_ended   = false

  write: (buffer) ->
    @_buffers.push buffer
    dest.write buffer for dest in @_dests
    undefined

  pipe: (dest, options) ->
    throw Error 'StreamCache#pipe: options are not supported yet.' if options

    dest.write buffer for buffer in @_buffers

    if @_ended
      dest.end()
      return dest

    @_dests.push dest
    dest

  getLength: ->
    @_buffers.reduce (totalLength, buffer) ->
      return totalLength + buffer.length
    , 0

  end: ->
    dest.end() for dest in @_dests
    @_ended = true
    @_dests = []

  hash: ->
    h = crypto.createHash 'sha1'
    h.update buffer for buffer in @_buffers
    h.digest 'hex'