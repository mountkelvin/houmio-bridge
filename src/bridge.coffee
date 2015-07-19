_ = require('lodash')
Bacon = require('baconjs')
carrier = require('carrier')
cron = require('cron')
fs = require('fs')
io = require('socket.io-client')
moment = require('moment')
net = require('net')
protocols = require('./protocols')
winston = require('winston')

winston.remove winston.transports.Console
winston.add winston.transports.Console, timestamp: true

exit = (msg) ->
  winston.info msg
  process.exit 1

# Bridge configuration update and persistence

bridgeConfigurationFilePath = "bridgeConfiguration.json"
bridgeConfiguration = {}

if fs.existsSync(bridgeConfigurationFilePath)
  bridgeConfiguration = JSON.parse fs.readFileSync bridgeConfigurationFilePath

updateBridgeConfiguration = (newBridgeConfiguration) ->
  fs.writeFileSync bridgeConfigurationFilePath, JSON.stringify(newBridgeConfiguration)
  bridgeConfiguration = newBridgeConfiguration
  winston.info "Updated bridge configuration, persisted to #{bridgeConfigurationFilePath}"

# Listener sockets

listenerSockets = []
listenerSocketServer = net.createServer  (listenerSocket) ->
  console.log "Listener connected"
  listenerSockets.push listenerSocket
  listenerSocket.on 'data', (data) -> console.log "Listener sent", data
  onEnd = ->
    listenerSockets.splice listenerSockets.indexOf(listenerSocket), 1
  listenerSocket.on 'end', onEnd
  listenerSocket.on 'error', ->
    listenerSocket.destroy()
    onEnd()

sendToListeners = (message) ->
  listenerSockets.forEach (socket) ->
    messageAsString = (JSON.stringify message) + "\n"
    socket.write messageAsString
    console.log "Wrote message to listener: #{messageAsString}".trim()

listenerSocketServer.listen 3666
console.log "Listener TCP socket server listening on port 3666"

# Driver sockets

writeToDriverSockets = (message) ->
  winston.info "Received message from server:", JSON.stringify message
  protocol = message.protocol
  driverSockets = driverSocketsOf protocol
  writeMessage = _.assign { command: "write" }, message
  driverSockets?.forEach (driverSocket) ->
    messageAsString = (JSON.stringify writeMessage) + "\n"
    driverSocket.write messageAsString
    winston.info "Wrote message to driver: #{messageAsString}".trim()

handleDriverDataLocally = (message) ->
  key = protocols.find(message.protocol).messageToEventSourceKey message
  if key
    uri = protocols.keyToURI key
    matchingEntry = _.find bridgeConfiguration, (entry) -> entry.eventSourceURI is uri
    driverWriteData = matchingEntry?.state || []
    driverWriteData.forEach writeToDriverSockets

onDriverSocketDriverData = (message) ->
  winston.info "Received data from driver:", JSON.stringify message
  dataS = protocols.find(message.protocol).driverDataToString message.data
  handleDriverDataLocally message
  houmioSocket.emit "driverData", { protocol: message.protocol, data: message.data }
  sendToListeners message

onDriverSocketDriverReady = (driverSocket, message) ->
  driverSocket.protocol = message.protocol
  driverSocket.write (JSON.stringify { command: "driverReadyAck" }) + "\n"

onDriverSocketData = (driverSocket) -> (s) ->
  try
    message = JSON.parse s
    switch message.command
      when "driverReady" then onDriverSocketDriverReady driverSocket, message
      when "driverData" then onDriverSocketDriverData message
      else winston.info "Unknown message from driver socket, protocol: #{driverSocket.protocol}, message:", data
  catch error
    winston.info "Error while handling message:", error, message

onDriverSocketEnd = (driverSocket) -> () ->
  driverSockets.splice driverSockets.indexOf(driverSocket), 1

onDriverSocketError = (driverSocket) -> (err) ->
  winston.info "Error from socket, protocol: #{driverSocket.protocol}, error: #{err}"
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
winston.info "TCP socket server listening on port 3001"

# Houm.io server socket

houmioServer = process.env.HOUMIO_SERVER || "http://localhost:3000"
houmioSiteKey = process.env.HOUMIO_SITEKEY || "devsite"
houmioBridgeVersion = JSON.parse(fs.readFileSync('./package.json')).version
winston.info "Using HOUMIO_SERVER=#{houmioServer}"
winston.info "Using HOUMIO_SITEKEY=#{houmioSiteKey}"
winston.info "Using houmio-bridge version #{houmioBridgeVersion}"

onHoumioSocketConnect = ->
  winston.info "Connected to #{houmioServer}"
  houmioSocket.emit "bridgeReady", { siteKey: houmioSiteKey, bridgeVersion: houmioBridgeVersion }

onHoumioSocketReconnect = ->
  winston.info "Reconnected to #{houmioServer}"
  houmioSocket.emit "bridgeReady", { siteKey: houmioSiteKey, bridgeVersion: houmioBridgeVersion }

onHoumioSocketConnectError = (err) ->
  winston.info "Connect error to #{houmioServer}: #{err}"

onHoumioSocketReconnectError = (err) ->
  winston.info "Reconnect error to #{houmioServer}: #{err}"

onHoumioSocketConnectTimeout = ->
  winston.info "Connect timeout to #{houmioServer}"

onHoumioSocketDisconnect = ->
  winston.info "Disconnected from #{houmioServer}"

onHoumioSocketUnknownSiteKey = (siteKey) ->
  exit "Server did not accept site key '#{siteKey}'"

houmioSocket = io houmioServer, { timeout: 60000, reconnectionDelay: 1000, reconnectionDelayMax: 10000 }
houmioSocket.on 'connect', onHoumioSocketConnect
houmioSocket.on 'reconnect', onHoumioSocketReconnect
houmioSocket.on 'connect_error', onHoumioSocketConnectError
houmioSocket.on 'reconnect_error', onHoumioSocketReconnectError
houmioSocket.on 'connect_timeout', onHoumioSocketConnectTimeout
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
