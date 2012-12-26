pmsToSend = []
bot = null;
setBot = (_bot) ->
	bot = _bot
queuePMs = (msgs, user) ->
	numInQueue = pmsToSend.length
	for msg in msgs
		pmsToSend.push({msg: msg, user:user})
	if numInQueue is 0
		sendPMInQueue()
sendPMInQueue = ->
	if pmsToSend.length is 0
		return
	pmToSend = pmsToSend.shift()
	setTimeout ->
		bot.pm pmToSend.msg, pmToSend.user.userid, sendPMInQueue
exports.queuePMs = queuePMs
exports.setBot = setBot