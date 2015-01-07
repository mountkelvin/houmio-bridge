_ = require 'lodash'
enocean = require('./enocean')

enoceanMap = {
  driverDataToString: enocean.toHexString
  lightStateToDriverWriteData: enocean.lightStateToProtocolCommands
  messageToEventSourceKey: (message) ->
    k = enocean.driverDataToEventSourceKey message.data
    if k then { protocol: "enocean", sourceId: k.enoceanAddress, which: k.key } else null
}

defaultMap = {
  driverDataToString: (x) -> JSON.stringify x
  lightStateToDriverWriteData: (x) -> [ _.identity x ]
  messageToEventSourceKey: (message) ->
    { protocol: message.protocol, sourceId: message.data?.sourceId, which: message.data?.which }
}

find = (protocol) ->
  switch protocol
    when "enocean" then enoceanMap
    else defaultMap

keyToURI = (x) ->
  "#{x.protocol}://#{x.sourceId}/#{x.which}"

exports.find = find
exports.keyToURI = keyToURI
