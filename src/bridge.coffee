_ = require('lodash')
enocean = require('./enocean-parser')
express = require('express')
fs = require('fs')
http = require('http')
io = require('socket.io-client')
WebSocket = require('ws')

app = express()
httpServer = http.createServer app
port = Number(process.env.PORT || 3001)
httpServer.listen port
driverWebSocketServer = new WebSocket.Server(server: httpServer)
console.log "Huom.io bridge WebSocket server listening on port #{port}"

# Key parsers

bridgeConfigurationKeyParsers =
  enocean: enocean.parseKey

# Bridge configuration update and persistence

bridgeConfigurationFilePath = "bridgeConfiguration.json"
bridgeConfiguration = {}

if fs.existsSync(bridgeConfigurationFilePath)
  bridgeConfiguration = JSON.parse fs.readFileSync bridgeConfigurationFilePath

updateBridgeConfiguration = (newBridgeConfiguration) ->
  fs.writeFileSync bridgeConfigurationFilePath, JSON.stringify(newBridgeConfiguration)
  bridgeConfiguration = newBridgeConfiguration
  console.log "Updated bridge configuration, persisted to #{bridgeConfigurationFilePath}"

# Driver sockets

driverWebSocketServer.socketsOf = (protocol) ->
  _.filter (_.values this.clients), protocol: protocol

handleDriverDataLocally = (message) ->
  parseKey = bridgeConfigurationKeyParsers[message.protocol]
  key = parseKey? message.data
  driverWriteData = bridgeConfiguration[key]
  driverWriteData?.forEach (datum) ->
    driverSockets = driverWebSocketServer.socketsOf datum.protocol
    driverWriteMessage = _.assign { command: "write" }, datum
    driverSockets?.forEach (driverSocket) -> driverSocket.send (JSON.stringify driverWriteMessage)

onDriverData = (message) ->
  handleDriverDataLocally message
  houmioSocket.emit "driverData", { siteKey: houmioSiteKey, protocol: message.protocol, data: message.data }

onDriverReady = (socket, message) ->
	socket.protocol = message.protocol
	console.log "Driver socket connected, protocol: #{message.protocol}"

onDriverSocketClose = ->
  console.log "Driver socket closed"

onDriverSocketError = (error) ->
  console.log error
  console.log "Terminating socket"
  driverSocket.terminate()

onDriverSocketMessage = (driverSocket) -> (s) ->
  console.log "Received message from driver:", s
  try
    message = JSON.parse s
    switch message.command
      when "driverData" then onDriverData message
      when "driverReady" then onDriverReady driverSocket, message
  catch error
    console.log "Error while handling message:", error, message

onDriverSocketConnection = (driverSocket) ->
  driverSocket.on 'close', onDriverSocketClose
  driverSocket.on 'error', onDriverSocketError
  driverSocket.on 'message', onDriverSocketMessage(driverSocket)

driverWebSocketServer.on 'connection', onDriverSocketConnection

# Houm.io server socket

houmioServer = process.env.HOUMIO_SERVER || "http://localhost:3000"
houmioSiteKey = process.env.HOUMIO_SITEKEY || "devsite"
console.log "Using HOUMIO_SERVER=#{houmioServer}"
console.log "Using HOUMIO_SITEKEY=#{houmioSiteKey}"

onHoumioSocketConnect = ->
  console.log "Connected to #{houmioServer}"
  houmioSocket.emit "bridgeReady", { siteKey: houmioSiteKey }

onHoumioSocketConnectError = (err) ->
  console.log "Connect error to #{houmioServer}:", err

onHoumioSocketDisconnect = ->
  console.log "Disconnected from #{houmioServer}"
  process.exit 0

onHoumioSocketUnknownSiteKey = (siteKey) ->
  console.log "Server did not accept site key '#{siteKey}'"

houmioSocket = io houmioServer, { reconnectionDelay: 3000, reconnectionDelayMax: 60000 }
houmioSocket.on 'connect', onHoumioSocketConnect
houmioSocket.on 'connect_error', onHoumioSocketConnectError
houmioSocket.on 'disconnect', onHoumioSocketDisconnect
houmioSocket.on 'unknownSiteKey', onHoumioSocketUnknownSiteKey
houmioSocket.on 'bridgeConfiguration', updateBridgeConfiguration