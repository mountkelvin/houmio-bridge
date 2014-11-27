express = require('express')
http = require('http')
WebSocket = require('ws')
_ = require('lodash')
enocean = require('./enocean-parser')

app = express()
httpServer = http.createServer app
port = Number(process.env.PORT || 3001)
httpServer.listen port
console.log "Houm.io bridge HTTP server listening on port #{port}"
driverWebSocketServer = new WebSocket.Server(server: httpServer)
console.log "Huom.io bridge WebSocket server listening on port #{port}"

driverWebSocketServer.on 'connection', (driverSocket) ->
  console.log "Driver socket connected"
  driverSocket.on 'close', ->
    console.log "Socket closed"
  driverSocket.on 'error', (error) ->
    console.log error
    console.log "Terminating socket"
    driverSocket.terminate()
  driverSocket.on 'message', (s) ->
    try
      message = JSON.parse s
      console.log "Message", message
      data = null
      if message.protocol is "enocean" then data = enocean.parseMessage message.data
      console.log data

    catch error
      console.log "Error while handling message:", error, message

houmioServer = process.env.HOUMIO_SERVER || "ws://localhost:3000"
houmioSiteKey = process.env.HOUMIO_SITEKEY || "devsite"
console.log "Using HOUMIO_SERVER=#{houmioServer}"
console.log "Using HOUMIO_SITEKEY=#{houmioSiteKey}"

onHoumioSocketOpen = ->
  console.log "Socket to Houm.io server opened"

onHoumioSocketClose = ->
  console.log "Socket to Houm.io server closed"

onHoumioSocketError = (err) ->
  console.log "Error in Houmio. server socket", err

onHoumioSocketMessage = (msg) ->
  console.log "Received message from Houm.io server", msg

houmioSocket = new WebSocket(houmioServer)
houmioSocket.on 'open', onHoumioSocketOpen
houmioSocket.on 'close', onHoumioSocketClose
houmioSocket.on 'error', onHoumioSocketError
houmioSocket.on 'ping', -> houmioSocket.pong()
houmioSocket.on 'message', onHoumioSocketMessage
