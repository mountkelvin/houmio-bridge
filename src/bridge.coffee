express = require('express')
http = require('http')
WebSocket = require('ws')
_ = require('lodash')
fs = require('fs')
enocean = require('./enocean-parser')

app = express()
httpServer = http.createServer app
port = Number(process.env.PORT || 3001)
httpServer.listen port
console.log "Houm.io bridge HTTP server listening on port #{port}"
driverWebSocketServer = new WebSocket.Server(server: httpServer)
console.log "Huom.io bridge WebSocket server listening on port #{port}"

bridgeConfigurationKeyParsers =
  enocean: enocean.parseKey

bridgeConfigurationFilePath = "bridgeConfiguration.json"
bridgeConfiguration = {}

if fs.existsSync(bridgeConfigurationFilePath)
  bridgeConfiguration = JSON.parse fs.readFileSync bridgeConfigurationFilePath

updateBridgeConfiguration = (newBridgeConfiguration) ->
  fs.writeFileSync bridgeConfigurationFilePath, JSON.stringify(newBridgeConfiguration)
  bridgeConfiguration = newBridgeConfiguration

driverWebSocketServer.socketOf = (protocol) ->
  for v, k in this.clients
    socket = this.clients[k]
    if socket.protocol is protocol then return socket
  return

handleDriverDataLocally = (message) ->
  parseKey = bridgeConfigurationKeyParsers[message.protocol]
  key = parseKey? message.data
  driverWrites = bridgeConfiguration[key]
  driverWrites?.forEach (driverWrite) ->
    driverSocket = driverWebSocketServer.socketOf driverWrite.protocol
    driverSocket?.send JSON.stringify driverWrite

onDriverData = (message) ->
  handleDriverDataLocally message
  houmioSocket.send message

onDriverReady = (socket, message) ->
	socket.protocol = message.protocol
	console.log "#{message.protocol} driver socket connected"

driverWebSocketServer.on 'connection', (driverSocket) ->
  driverSocket.on 'close', ->
    console.log "Driver socket closed"
  driverSocket.on 'error', (error) ->
    console.log error
    console.log "Terminating socket"
    driverSocket.terminate()
  driverSocket.on 'message', (s) ->
    console.log "Received message from driver:", s
    try
      message = JSON.parse s
      switch message.command
        when "driverData" then onDriverData message
        when "driverReady" then onDriverReady driverSocket, message
    catch error
      console.log "Error while handling message:", error, message

houmioServer = process.env.HOUMIO_SERVER || "ws://192.168.88.67:3000"
houmioSiteKey = process.env.HOUMIO_SITEKEY || "devsite"
console.log "Using HOUMIO_SERVER=#{houmioServer}"
console.log "Using HOUMIO_SITEKEY=#{houmioSiteKey}"

onHoumioSocketOpen = ->
  console.log "Socket to Houm.io server opened"
  houmioSocket.send JSON.stringify { command: "bridgeReady", data: { siteKey: houmioSiteKey } }

onHoumioSocketClose = ->
  console.log "Socket to Houm.io server closed"

onHoumioSocketError = (err) ->
  console.log "Error in Houm.io server socket", err

onHoumioSocketMessage = (msg) ->
  console.log "Received message from Houm.io server", msg
  try
    message = JSON.parse msg
    switch message.command
       when "bridgeConfiguration" then updateBridgeConfiguration message.data
  catch error
    console.log "Error while handling message:", error, message

houmioSocket = new WebSocket(houmioServer)
houmioSocket.on 'open', onHoumioSocketOpen
houmioSocket.on 'close', onHoumioSocketClose
houmioSocket.on 'error', onHoumioSocketError
houmioSocket.on 'ping', -> houmioSocket.pong()
houmioSocket.on 'message', onHoumioSocketMessage
