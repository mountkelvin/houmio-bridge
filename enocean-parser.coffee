_ = require('lodash')

#SYNC WORD

SYNC = 0x55

#PACKET TYPES

PT_RADIO = 0x01 #Radio telegram
PT_RESPONSE = 0x02 #Response to any packet
PT_RADIO_SUB_TEL = 0x03 #Radio subtelegram
PT_EVENT = 0x04 #Event message
PT_COMMON_COMMAND = 0x05 #Common command
PT_SMART_ACK_COMMAND = 0x06 #Smart Ack command
PT_REMOTE_MAN_COMMAND = 0x07 #Remote management command
PT_RADIO_MESSAGE = 0x09 #Radio message
PT_RADIO_ADVANCED = 0x0A #Advanced protocol radio telegram

#COMMON COMMAND CODES

CO_RD_ID_BASE = 0x08 #Read ID Range Base Number
CO_WD_ID_BASE = 0x07 #WRITE ID Range Base Number

#RADIO MESSAGE TYPES

RORG_RPS_TELEGRAM = 0xF6
RORG_4B_COMMUNICATION = 0xA5
RORG_UTE_TEACH = 0xD4
RORG_VLD_TELEGRAM = 0xD2

#PARSE MESSAGE TYPES

PS_BUTTON_DATA = 0x01
PS_DIMMER_DATA = 0x02
PS_UTE_TEACH_IN = 0x03
PS_VLD_SWITCH_EVENT = 0x04
PS_RAW_DATA = 0xFF


#Radio telegram parsing

createBtnEventNum = (primaryBtn, secondaryBtn) ->
  ret = 0
  if (secondaryBtn == 0)
    if(primaryBtn == 0)
      ret = 3
    if(primaryBtn == 1)
      ret = 1
    if(primaryBtn == 2)
      ret = 4
    if(primaryBtn == 3)
      ret = 2
  else
    if (primaryBtn == 0 && secondaryBtn == 2)
      ret = 34
    if (primaryBtn == 0 && secondaryBtn == 3)
      ret = 32
    if (primaryBtn == 1 && secondaryBtn == 2)
      ret = 14
    if (primaryBtn == 1 && secondaryBtn == 3)
      ret = 12
  ret




parseRadioTelegram = (dataBytes, dataLen, optLen) ->
  radioTelegramType = dataBytes[0]
  if(radioTelegramType == RORG_RPS_TELEGRAM && dataLen == 7 && optLen == 7)
    enoAddr = dataBytes.slice 2, 6
    buttonStatus = dataBytes[1]
    if buttonStatus == 0xf0 || buttonStatus == 0xe0
      #FTKE 0xe0 == Open, 0xf0 == Closed
      if buttonStatus is 0xe0 then eventNum = 12 else eventNum = 34
      upDown = "pressed"
    else
      #Normal button handling
      upDown = if (buttonStatus & 0x10) then "pressed" else "released"
      primaryBtnNum = (buttonStatus & 0xE0) >> 5
      secondaryBtnNum = (buttonStatus & 0x0E) >> 1
      if upDown is "pressed" then eventNum = createBtnEventNum primaryBtnNum, secondaryBtnNum else eventNum = 0
    hexAddr = toHexString enoAddr
    return {
      command: "buttonevent",
      data: {
        type: PT_RADIO,
        dataid: PS_BUTTON_DATA,
        enoaddr: hexAddr,
        updown: upDown,
        eventnum: eventNum,
      }
    }


parseMessage = (ints) ->
  #Parse Header
  #console.log ints
  dataLen = ints[1] * 0xFF + ints[2]
  optLen = ints[3]
  pktType = ints[4]
  dataBytes = ints.slice 6
  if pktType is PT_RADIO then return parseRadioTelegram dataBytes, dataLen, optLen


toHexString = (ints) ->
  _.map(ints, (num) ->
    hex = num.toString 16
    if hex.length is 1 then hex = "0" + hex
    hex
    ).join ':'

exports.parseMessage = parseMessage
