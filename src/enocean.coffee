_ = require('lodash')
crc = require("crc")
zeroFill = require("zerofill")

# Enocean bytes

## Sync word

SYNC = 0x55

## Packet types

PT_RADIO = 0x01 # Radio telegram
PT_RESPONSE = 0x02 # Response to any packet
PT_RADIO_SUB_TEL = 0x03 # Radio subtelegram
PT_EVENT = 0x04 # Event message
PT_COMMON_COMMAND = 0x05 # Common command
PT_SMART_ACK_COMMAND = 0x06 # Smart Ack command
PT_REMOTE_MAN_COMMAND = 0x07 # Remote management command
PT_RADIO_MESSAGE = 0x09 # Radio message
PT_RADIO_ADVANCED = 0x0A # Advanced protocol radio telegram

## Common command codes

CO_RD_ID_BASE = 0x08 # Read ID Range Base Number
CO_WD_ID_BASE = 0x07 # Write ID Range Base Number

## Radio message types

RORG_RPS_TELEGRAM = 0xF6
RORG_4B_COMMUNICATION = 0xA5
RORG_UTE_TEACH = 0xD4
RORG_VLD_TELEGRAM = 0xD2

## Parse message types

PS_BUTTON_DATA = 0x01
PS_DIMMER_DATA = 0x02
PS_UTE_TEACH_IN = 0x03
PS_VLD_SWITCH_EVENT = 0x04
PS_RAW_DATA = 0xFF

## Button bytes

eventByteMapping = {}
eventByteMapping[0x50] = "1"
eventByteMapping[0x10] = "2"
eventByteMapping[0x70] = "3"
eventByteMapping[0x30] = "4"
eventByteMapping[0x15] = "12"
eventByteMapping[0x37] = "34"
eventByteMapping[0x35] = "14"
eventByteMapping[0x17] = "23"

# Private functions

crcOf = (bytes) -> parseInt crc.crc8(bytes), 16

toByteArray = (s) -> (split2 s).map (i) -> parseInt(i, 16)

split2 = (s) -> s.match(/.{1,2}/g)

parseHex = (s) -> parseInt s, 16

toHex = (i) -> i.toString 16

enoceanBytes = (header, data) -> [SYNC].concat(header).concat(crcOf(header)).concat(data).concat(crcOf(data))

teachDimmer = (subDef) ->
  header = [0x00, 0x0a, 0x07, PT_RADIO]
  data = [RORG_4B_COMMUNICATION, 0x02, 0x00, 0x00, 0x00]
   .concat subDef
   .concat [0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0x00, 0x00]
  enoceanBytes header, data

teachSwitch = (subDef) ->
  header = [0x00, 0x0a, 0x07, PT_RADIO]
  data = [RORG_4B_COMMUNICATION, 0xE0, 0x47, 0xFF, 0x80]
   .concat subDef
   .concat [0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0x00, 0x00]
  enoceanBytes header, data

setLightDimmerState = (subDef, onB, bri) ->
  header = [0x00, 0x0a, 0x07, PT_RADIO]
  onByte = if onB then 0x09 else 0x08
  enOceanBri = Math.floor(bri/0xff*100)
  data = [RORG_4B_COMMUNICATION, 0x02, enOceanBri, 0x01, onByte]
    .concat subDef
    .concat [0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0x00, 0x00]
  enoceanBytes header, data

setLightSwitchState = (subDef, onB) ->
  header = [0x00, 0x0a, 0x07, PT_RADIO]
  onByte = if onB then 0x09 else 0x08
  data = [RORG_4B_COMMUNICATION, 0x01, 0x00, 0x00, onByte]
    .concat subDef
    .concat [0x00, 0x00, 0xff, 0xff, 0xff, 0xff, 0x00, 0x00]
  enoceanBytes header, data

bufferDataLength = (buffer) ->
  buffer[1] * 0xff + buffer[2]

bufferOptionalDataLength = (buffer) ->
  buffer[3]

bufferStartsWithStartByte = (buffer) ->
  buffer[0] == 0x55

bufferHasValidLength = (buffer) ->
  enoceanHeaderLength = 6
  totalLength = enoceanHeaderLength + (bufferDataLength buffer) + (bufferOptionalDataLength buffer) + 1
  buffer.length == totalLength

bufferData = (buffer) ->
  dataLength = bufferDataLength buffer
  buffer.slice 6, 6 + dataLength

bufferCanBeInterpretedAsButtonEvent = (buffer) ->
  data = bufferData buffer
  data[0] == RORG_RPS_TELEGRAM && bufferDataLength(buffer) == 7 && bufferOptionalDataLength(buffer) == 7

parseBufferAsButtonEvent = (buffer) ->
  data = bufferData buffer
  enoceanAddressBuffer = data.slice 2, 6
  eventByte = data[1]
  enoceanAddress = (_.map enoceanAddressBuffer, toHex).join("")
  key = eventByteMapping[eventByte]
  event = if key? then "keydown" else "keyup"
  { enoceanAddress, event, key }

# Exported functions

teach = (light) ->
  subDefAsBytes = _.map (split2 light.protocolAddress), parseHex
  if light.type is 'binary'
    teachSwitch subDefAsBytes
  else
    teachDimmer subDefAsBytes

smallestAvailableSubDef = (subDefs, subDefBase) ->
  if _.isEmpty subDefs
    subDefBase
  else
    takenInts = _ subDefs
      .map parseHex
      .sortBy _.identity
      .value()
    base = parseHex subDefBase
    allInts = [base..base+0xff]
    availableInts = _.difference allInts, takenInts
    firstAvailable = _.first availableInts
    if firstAvailable then toHex firstAvailable else null

lightStateToProtocolCommands = (light) ->
  command = if light.type is 'binary'
    setLightSwitchState(toByteArray(light.protocolAddress), light.on)
  else
    setLightDimmerState(toByteArray(light.protocolAddress), light.on, light.bri)
  [ command ]

toHexString = (bytes) ->
  byteToHexString = (b) -> b.toString(16)
  addZeroes = (s) -> zeroFill(s, 2)
  bytes.map(byteToHexString).map(addZeroes).join(':')

driverDataToEventSourceKey = (data) ->
  if bufferCanBeInterpretedAsButtonEvent data
    parseBufferAsButtonEvent data
  else
    null

exports.teach = teach
exports.smallestAvailableSubDef = smallestAvailableSubDef
exports.lightStateToProtocolCommands = lightStateToProtocolCommands
exports.toHexString = toHexString
exports.driverDataToEventSourceKey = driverDataToEventSourceKey