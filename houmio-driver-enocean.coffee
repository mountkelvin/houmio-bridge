Bacon = require('baconjs')
serialport = require("serialport")
sleep = require('sleep')
WebSocket = require('ws')
winston = require('winston')
_ = require('lodash')

winston.remove(winston.transports.Console)
winston.add(winston.transports.Console, { timestamp: ( -> new Date() ) })
console.log = winston.info

horselightsServer = process.env.HORSELIGHTS_SERVER || "ws://localhost:3000"
horselightsSitekey = process.env.HORSELIGHTS_SITEKEY || "devsite"
horselightsEnOceanDeviceFile = process.env.HORSELIGHTS_ENOCEAN_DEVICE_FILE || "/dev/cu.usbserial-FTXMIMLY"

console.log "Using HORSELIGHTS_SERVER=#{horselightsServer}"
console.log "Using HORSELIGHTS_SITEKEY=#{horselightsSitekey}"
console.log "Using HORSELIGHTS_ENOCEAN_DEVICE_FILE=#{horselightsEnOceanDeviceFile}"

exit = (msg) ->
  console.log msg
  process.exit 1

enOceanSerialBuffer = null
onEnOceanTimeoutObj = null
socket = null
pingId = null

enOceanData = new Bacon.Bus()
writeReady = new Bacon.Bus()

enOceanWriteAndDrain = (data, callback) ->
  enOceanSerial.write data, (err, res) ->
    enOceanSerial.drain callback

enOceanData
  .zip(writeReady, (d, w) -> d)
  .flatMap (d) -> Bacon.fromNodeCallback(enOceanWriteAndDrain, d)
  .onValue (err) ->
    sleep.usleep(0.01*1000000)
    writeReady.push(true)

enOceanStartByte = 0x55

enOceanHeaderLength = 6

enOceanIsDataValid = (cmd) ->
  if cmd.length < 7 then return false
  if cmd[0] != enOceanStartByte then return false
  if !enOceanIsDataLengthValid(cmd) then return false
  true

enOceanIsDataLengthValid = (data) ->
  dataLen = data[1] * 0xff + data[2]
  optLen = data[3]
  totalLen = enOceanHeaderLength + dataLen + optLen + 1
  data.length == totalLen

onSocketOpen = ->
  console.log "Connected to #{horselightsServer}"
  pingId = setInterval ( -> socket.ping(null, {}, false) ), 3000
  publish = JSON.stringify { command: "publish", data: { sitekey: horselightsSitekey, vendor: "enocean" } }
  socket.send(publish)
  console.log "Sent message:", publish

onSocketClose = ->
  clearInterval pingId
  exit "Disconnected from #{horselightsServer}"

onSocketMessage = (s) ->

  try
    message = JSON.parse s
    console.log "Received message:", toHexString3 message.data
    enOceanData.push message.data

onEnOceanSerialData = (data) ->
  if data[0] == enOceanStartByte && enOceanSerialBuffer == null
    onEnOceanTimeoutObj = setTimeout onEnOceanTimeout, 100
    if enOceanIsDataValid data
      socket.send JSON.stringify { command: "enoceandata", data: data }
      enOceanSerialBuffer = null
      clearTimeout onEnOceanTimeoutObj
    else
      enOceanSerialBuffer = data.slice 0, data.length
  else if enOceanSerialBuffer != null
    enOceanSerialBuffer = Buffer.concat [enOceanSerialBuffer, data]
    if enOceanIsDataValid enOceanSerialBuffer
      datamessage = JSON.stringify { command: "enoceandata", data: enOceanSerialBuffer }
      socket.send datamessage
      #console.log "Sent message:", toHexString3 enOceanSerialBuffer
      enOceanSerialBuffer = null
      clearTimeout onEnOceanTimeoutObj

onEnOceanTimeout = () ->
  enOceanSerialBuffer = null
  console.log "Timeout"
  clearTimeout onEnOceanTimeoutObj

onEnOceanSerialOpen = ->
  console.log 'Serial port opened:', horselightsEnOceanDeviceFile
  enOceanSerial.on 'data', onEnOceanSerialData
  writeReady.push(true)
  socket = new WebSocket(horselightsServer)
  socket.on 'open', onSocketOpen
  socket.on 'close', onSocketClose
  socket.on 'error', exit
  socket.on 'ping', -> socket.pong()
  socket.on 'message', onSocketMessage

onEnOceanSerialError = (err) ->
  exit "An error occurred in EnOcean serial port: #{err}"

onEnOceanSerialClose = (err) ->
  exit "EnOcean serial port closed, reason: #{err}"


toHexString3 = (ints) ->
  _.map(ints, (num) ->
    hex = num.toString 16
    if hex.length is 1 then hex = "0" + hex
    hex
    ).join ':'

enOceanSerialConfig = { baudrate: 57600, parser: serialport.parsers.raw }
enOceanSerial = new serialport.SerialPort horselightsEnOceanDeviceFile, enOceanSerialConfig, true
enOceanSerial.on "open", onEnOceanSerialOpen
enOceanSerial.on "close", onEnOceanSerialClose
enOceanSerial.on "error", onEnOceanSerialError
