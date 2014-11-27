express = require('express')
http = require('http')
WebSocket = require('ws')
_ = require('lodash')
fs = require('fs')
enocean = require('./enocean-parser')

app = express()
httpServer = http.createServer app
port = Number(process.env.PORT || 3001)
httpServer.listen port
console.log "Houm.io bridge HTTP server listening on port #{port}"
driverWebSocketServer = new WebSocket.Server(server: httpServer)
console.log "Huom.io bridge WebSocket server listening on port #{port}"

localStorage = "localStorage.json"

writeDataToLocalStorage = (data) ->
	console.log "DATAA", JSON.stringify data
	fs.writeFileSync localStorage, JSON.stringify data

driverWebSocketServer.socketOf = (protocol) ->
  for v, k in this.clients
    socket = this.clients[k]
    if socket.protocol is protocol then return socket
  return


sendSceneDataToDriver = (sceneData) ->
	_.each sceneData, (data) ->
		socket = driverWebSocketServer.socketOf data.protocol
		if socket and data.protocol is 'enocean'
			try
				console.log "Data:", JSON.stringify data
				socket.send JSON.stringify data
			catch error
				console.log "Protocol transmit error: ", error

parseEnoMessage = (msg) ->
	enoMsg = enocean.parseMessage msg.data
	if(enoMsg != undefined)
		console.log enoMsg

		fs.readFile localStorage, (err, data) ->
			if !err
				key = "enocean #{enoMsg.data.enoaddr} #{enoMsg.data.eventnum}"
				jsonData = JSON.parse data

				sceneData = jsonData[ key ]
				if sceneData != undefined
					sendSceneDataToDriver sceneData

onData = (message) ->
	console.log "Received driver data: ", message
	if message.protocol is "enocean" then parseEnoMessage message

onDriverReady = (socket, message) ->
	socket.protocol = message.protocol
	console.log "#{message.protocol} driver socket connected"

driverWebSocketServer.on 'connection', (driverSocket) ->
  driverSocket.on 'close', ->
    console.log "Socket closed"
  driverSocket.on 'error', (error) ->
    console.log error
    console.log "Terminating socket"
    driverSocket.terminate()
  driverSocket.on 'message', (s) ->
    try
      message = JSON.parse s
      switch message.command
        when "data" then onData message
        when "driverReady" then onDriverReady driverSocket, message
    catch error
      console.log "Error while handling message:", error, message

houmioServer = process.env.HOUMIO_SERVER || "ws://192.168.88.67:3000"
houmioSiteKey = process.env.HOUMIO_SITEKEY || "devsite"
console.log "Using HOUMIO_SERVER=#{houmioServer}"
console.log "Using HOUMIO_SITEKEY=#{houmioSiteKey}"

onHoumioSocketOpen = ->
  console.log "Socket to Houm.io server opened"
  houmioSocket.send JSON.stringify { command: "bridgeReady", data: { siteKey: houmioSiteKey } }

onHoumioSocketClose = ->
  console.log "Socket to Houm.io server closed"

onHoumioSocketError = (err) ->
  console.log "Error in Houmio. server socket", err

onHoumioSocketMessage = (msg) ->
  console.log "Received message from Houm.io server", msg
  try
    message = JSON.parse msg
    switch message.command
       when "bridgeConfiguration" then writeDataToLocalStorage message.data
  catch error
    console.log "Error while handling message:", error, message

houmioSocket = new WebSocket(houmioServer)
houmioSocket.on 'open', onHoumioSocketOpen
houmioSocket.on 'close', onHoumioSocketClose
houmioSocket.on 'error', onHoumioSocketError
houmioSocket.on 'ping', -> houmioSocket.pong()
houmioSocket.on 'message', onHoumioSocketMessage
