express = require('express')
http = require('http')
WebSocket = require('ws')
_ = require('lodash')


#Local Server

app = express()
httpserver = http.createServer app
port = Number(process.env.PORT || 3001)
httpserver.listen port
console.log "Houm.io bridge HTTP server listening on port #{port}"
websocketserver = new WebSocket.Server(server: httpserver)
console.log "Huom.io bridge WebSocket server listening on port #{port}"


websocketserver.on 'connection', (socket) ->

  console.log "Socket connected", socket.data
  socket.on 'close', ->
    console.log "Socket closed (site: #{socket})"
  socket.on 'error', (error) ->
    console.log error
    console.log "Terminating socket: site: #{socket}"
    socket.terminate()
  socket.on 'ping', ->
    socket.pong()
  socket.on 'pong', ->
    storePingTs socket, _.identity
  socket.on 'message', (s) ->
    try
      message = JSON.parse s
      console.log "MEssage", message


      #switch message.command
      #  when "publish" then onPublish socket, message
      #  when "subscribe" then onSubscribe socket, message
      #  when "sensorevent" then onSensorevent message
      #  when "knxbusdata" then onKnxbusdata socket, message
      #  when "set" then onSet socket, message
      #  when "enoceandata" then onEnOceanData socket, message
      #  when "generaldata" then onGeneralSiteData socket, message
      #  else console.log "Unknown command:", message.command
    catch error
      console.log "Error while handling message:", error, message









#Connection to Cloud
houmioServer = process.env.HOUMIO_SERVER || "ws://localhost:3000"
houmioSiteKey = process.env.HOUMIO_SITEKEY || "devsite"
console.log "Using HOUMIO_SERVER=#{houmioServer}"
console.log "Using HOUMIO_SITEKEY=#{houmioSiteKey}"










onSocketOpen = ->
  console.log "Socket to Houm.io server opened"

onSocketClose = ->
  console.log "Socket to Houm.io server closed"

onSocketError = (err) ->
  console.log "Error in Houmio. server socket", err

onSocketMessage = (msg) ->
  console.log "Received message from Houm.io server", msg




socket = new WebSocket(houmioServer)
socket.on 'open', onSocketOpen
socket.on 'close', onSocketClose
socket.on 'error', onSocketError
socket.on 'ping', -> socket.pong()
socket.on 'message', onSocketMessage

#Bacon = require('baconjs')
#serialport = require("serialport")
#sleep = require('sleep')
#WebSocket = require('ws')
#winston = require('winston')
#
#winston.remove(winston.transports.Console)
#winston.add(winston.transports.Console, { timestamp: ( -> new Date() ) })
#console.log = winston.info
#
#horselightsServer = process.env.HORSELIGHTS_SERVER || "ws://localhost:3000"
#horselightsSitekey = process.env.HORSELIGHTS_SITEKEY || "devsite"
#horselightsEnOceanDeviceFile = process.env.HORSELIGHTS_ENOCEAN_DEVICE_FILE || "/dev/cu.usbserial-FTXMJM92"
#
#console.log "Using HORSELIGHTS_SERVER=#{horselightsServer}"
#console.log "Using HORSELIGHTS_SITEKEY=#{horselightsSitekey}"
#console.log "Using HORSELIGHTS_ENOCEAN_DEVICE_FILE=#{horselightsEnOceanDeviceFile}"
#
#exit = (msg) ->
#  console.log msg
#  process.exit 1
#
#enOceanSerialBuffer = null
#onEnOceanTimeoutObj = null
#socket = null
#pingId = null
#
#enOceanData = new Bacon.Bus()
#writeReady = new Bacon.Bus()
#
#enOceanWriteAndDrain = (data, callback) ->
#  enOceanSerial.write data, (err, res) ->
#    enOceanSerial.drain callback
#
#enOceanData
#  .zip(writeReady, (d, w) -> d)
#  .flatMap (d) -> Bacon.fromNodeCallback(enOceanWriteAndDrain, d)
#  .onValue (err) ->
#    sleep.usleep(0.01*1000000)
#    writeReady.push(true)
#
#enOceanStartByte = 0x55
#
#enOceanHeaderLength = 6
#
#enOceanIsDataValid = (cmd) ->
#  if cmd.length < 7 then return false
#  if cmd[0] != enOceanStartByte then return false
#  if !enOceanIsDataLengthValid(cmd) then return false
#  true
#
#enOceanIsDataLengthValid = (data) ->
#  dataLen = data[1] * 0xff + data[2]
#  optLen = data[3]
#  totalLen = enOceanHeaderLength + dataLen + optLen + 1
#  data.length == totalLen
#
#onSocketOpen = ->
#  console.log "Connected to #{horselightsServer}"
#  pingId = setInterval ( -> socket.ping(null, {}, false) ), 3000
#  publish = JSON.stringify { command: "publish", data: { sitekey: horselightsSitekey, vendor: "enocean" } }
#  socket.send(publish)
#  console.log "Sent message:", publish
#
#onSocketClose = ->
#  clearInterval pingId
#  exit "Disconnected from #{horselightsServer}"
#
#onSocketMessage = (s) ->
#  console.log "Received message:", s
#  try
#    message = JSON.parse s
#    enOceanData.push message.data
#
#onEnOceanSerialData = (data) ->
#  if data[0] == enOceanStartByte && enOceanSerialBuffer == null
#    onEnOceanTimeoutObj = setTimeout onEnOceanTimeout, 100
#    if enOceanIsDataValid data
#      socket.send JSON.stringify { command: "enoceandata", data: data }
#      enOceanSerialBuffer = null
#      clearTimeout onEnOceanTimeoutObj
#    else
#      enOceanSerialBuffer = data.slice 0, data.length
#  else if enOceanSerialBuffer != null
#    enOceanSerialBuffer = Buffer.concat [enOceanSerialBuffer, data]
#    if enOceanIsDataValid enOceanSerialBuffer
#      datamessage = JSON.stringify { command: "enoceandata", data: enOceanSerialBuffer }
#      socket.send datamessage
#      console.log "Sent message:", datamessage
#      enOceanSerialBuffer = null
#      clearTimeout onEnOceanTimeoutObj
#
#onEnOceanTimeout = () ->
#  enOceanSerialBuffer = null
#  clearTimeout onEnOceanTimeoutObj
#
#onEnOceanSerialOpen = ->
#  console.log 'Serial port opened:', horselightsEnOceanDeviceFile
#  enOceanSerial.on 'data', onEnOceanSerialData
#  writeReady.push(true)
#  socket = new WebSocket(horselightsServer)
#  socket.on 'open', onSocketOpen
#  socket.on 'close', onSocketClose
#  socket.on 'error', exit
#  socket.on 'ping', -> socket.pong()
#  socket.on 'message', onSocketMessage
#
#onEnOceanSerialError = (err) ->
#  exit "An error occurred in EnOcean serial port: #{err}"
#
#onEnOceanSerialClose = (err) ->
#  exit "EnOcean serial port closed, reason: #{err}"
#
#enOceanSerialConfig = { baudrate: 57600, parser: serialport.parsers.raw }
#enOceanSerial = new serialport.SerialPort horselightsEnOceanDeviceFile, enOceanSerialConfig, true
#enOceanSerial.on "open", onEnOceanSerialOpen
#enOceanSerial.on "close", onEnOceanSerialClose
#enOceanSerial.on "error", onEnOceanSerialError
#