_ = require('lodash')
carrier = require('carrier')
enocean = require('./enocean-parser')
fs = require('fs')
io = require('socket.io-client')
net = require('net')

# Hex array printing

toCommaSeparatedHexString = (ints) ->
  toHexString = (i) -> i.toString(16)
  addZeroes = (s) -> zerofill(s, 2)
  ints.map(toHexString).map(addZeroes).join(':')

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

handleDriverDataLocally = (message) ->
  parseKey = bridgeConfigurationKeyParsers[message.protocol]
  key = parseKey? message.data
  driverWriteData = bridgeConfiguration[key]
  driverWriteData?.forEach (datum) ->
    driverSockets = driverSocketServer.socketsOf datum.protocol
    driverWriteMessage = _.assign { command: "write" }, datum
    driverSockets?.forEach (driverSocket) ->
      messageS = (JSON.stringify driverWriteMessage)
      driverSocket.write messageS + "\n"
      console.log "Wrote message to driver, protocol: #{datum.protocol}, message: #{messageS}"

onDriverSocketDriverData = (message) ->
  handleDriverDataLocally message
  houmioSocket.emit "driverData", { siteKey: houmioSiteKey, protocol: message.protocol, data: message.data }

onDriverSocketDriverReady = (driverSocket, message) ->
  driverSocket.protocol = message.protocol

onDriverSocketData = (driverSocket) -> (s) ->
  try
    message = JSON.parse s
    switch message.command
      when "driverReady" then onDriverSocketDriverReady driverSocket, message
      when "driverData" then onDriverSocketDriverData message
      else console.log "Unknown message from driver socket, protocol: #{driverSocket.protocol}, message:", data
  catch error
    console.log "Error while handling message:", error, message

onDriverSocketEnd = (driverSocket) -> () ->
  driverSocketServer.sockets.splice driverSocketServer.sockets.indexOf(driverSocket), 1

onDriverSocketConnect = (driverSocket) ->
  driverSocketServer.sockets.push driverSocket
  carrier.carry driverSocket, onDriverSocketData(driverSocket)
  driverSocket.on 'end', onDriverSocketEnd(driverSocket)

driverSocketServer = net.createServer onDriverSocketConnect
driverSocketServer.sockets = []
driverSocketServer.socketsOf = (protocol) -> _.filter (_.values this.sockets), protocol: protocol

driverSocketServer.listen 3001
console.log "TCP socket server listening on port 3001"

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

onHoumioSocketUnknownSiteKey = (siteKey) ->
  console.log "Server did not accept site key '#{siteKey}'"

houmioSocket = io houmioServer, { reconnectionDelay: 3000, reconnectionDelayMax: 60000 }
houmioSocket.on 'connect', onHoumioSocketConnect
houmioSocket.on 'connect_error', onHoumioSocketConnectError
houmioSocket.on 'disconnect', onHoumioSocketDisconnect
houmioSocket.on 'unknownSiteKey', onHoumioSocketUnknownSiteKey
houmioSocket.on 'bridgeConfiguration', updateBridgeConfiguration
