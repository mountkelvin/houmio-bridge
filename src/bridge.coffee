_ = require('lodash')
Bacon = require('baconjs')
carrier = require('carrier')
cron = require('cron')
fs = require('fs')
io = require('socket.io-client')
moment = require('moment')
net = require('net')
protocols = require('./protocols')

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

writeToDriverSockets = (message) ->
  protocol = message.protocol
  driverSockets = driverSocketsOf protocol
  messageWithoutProtocol = _.omit message, "protocol"
  writeMessage = _.assign { command: "write" }, messageWithoutProtocol
  driverSockets?.forEach (driverSocket) ->
    driverSocket.write (JSON.stringify writeMessage) + "\n"
    dataS = protocols.find(protocol).driverDataToString message.data
    console.log "Wrote message to driver, protocol: #{protocol}, data: #{dataS}"

handleDriverDataLocally = (message) ->
  key = protocols.find(message.protocol).messageToEventSourceKey message
  if key
    uri = protocols.keyToURI key
    matchingEntry = _.find bridgeConfiguration, (entry) -> entry.eventSourceURI is uri
    driverWriteData = matchingEntry?.state || []
    driverWriteData.forEach writeToDriverSockets

onDriverSocketDriverData = (message) ->
  dataS = protocols.find(message.protocol).driverDataToString message.data
  console.log "Received data from driver, protocol: #{message.protocol}, data: #{dataS}"
  handleDriverDataLocally message
  houmioSocket.emit "driverData", { protocol: message.protocol, data: message.data }

onDriverSocketDriverReady = (driverSocket, message) ->
  driverSocket.protocol = message.protocol
  driverSocket.write (JSON.stringify { command: "driverReadyAck" }) + "\n"

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
  driverSockets.splice driverSockets.indexOf(driverSocket), 1

onDriverSocketError = (driverSocket) -> (err) ->
  console.log "Error from socket, protocol: #{driverSocket.protocol}, error: #{err}"
  driverSocket.destroy()
  onDriverSocketEnd(driverSocket)()

onDriverSocketConnect = (driverSocket) ->
  driverSockets.push driverSocket
  carrier.carry driverSocket, onDriverSocketData(driverSocket)
  driverSocket.on 'end', onDriverSocketEnd(driverSocket)
  driverSocket.on 'error', onDriverSocketError(driverSocket)

driverSocketServer = net.createServer onDriverSocketConnect
driverSockets = []

driverSocketsOf = (protocol) ->
  _ driverSockets
    .values()
    .filter protocol: protocol

availableProtocols = ->
  _ driverSockets
    .values()
    .pluck "protocol"
    .uniq()
    .reject _.isUndefined
    .value()

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
houmioSocket.on 'driverWrite', writeToDriverSockets

# Schedules

minutes = Bacon.fromBinder (sink) ->
  sinkMoment = -> sink moment().utc().format("ddd/HH:mm")
  new cron.CronJob '0 * * * * *', sinkMoment, null, true
  ( -> )

minutes
  .map (minute) -> { protocol: "schedule", data: { sourceId: "bridge", which: minute } }
  .onValue onDriverSocketDriverData

# Heartbeat with available protocols

Bacon.fromPoll(10000, availableProtocols)
  .onValue (protocols) -> houmioSocket.emit "heartBeatWithAvailableProtocols", protocols
