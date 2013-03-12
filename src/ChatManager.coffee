chatToSend = []
bot = null;
setBot = (_bot) ->
	bot = _bot
sendChat = (msgs) ->
	numInQueue = chatToSend.length
	for msg in msgs
		chatToSend.push(msg)
	if numInQueue is 0
		sendChatMessage()
sendChatMessage = ->
	if chatToSend.length is 0
		return
	msgToSend = chatToSend.shift()
	setTimeout ->
		console.log 'chat: ' + msgToSend
		bot.speak msgToSend, sendChatMessage
	, 50
exports.setBot = setBot
exports.sendChat = sendChat