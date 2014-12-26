_ = require 'lodash'
enocean = require('./enocean')

enoceanMap = {
  driverDataToString: enocean.toHexString
  lightStateToDriverWriteData: enocean.lightStateToProtocolCommands
  driverDataToEventSourceKey: (data) ->
    k = enocean.driverDataToEventSourceKey data
    if k then { protocol: "enocean", sourceId: k.enoceanAddress, which: k.key } else null
}

defaultMap = {
  driverDataToString: (x) -> x.toString()
  lightStateToDriverWriteData: _.identity
  driverDataToEventSourceKey: -> null
}

find = (protocol) ->
  switch protocol
    when "enocean" then enoceanMap
    else defaultMap

keyToURI = (x) ->
  "#{x.protocol}://#{x.sourceId}/#{x.which}"

exports.find = find
exports.keyToURI = keyToURI
