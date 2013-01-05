pmsToSend = []
bot = null;
setBot = (_bot) ->
	bot = _bot
queuePMs = (msgs, userid) ->
	numInQueue = pmsToSend.length
	for msg in msgs
		pmsToSend.push({msg: msg, userid:userid})
	if numInQueue is 0
		sendPMInQueue()
sendPMInQueue = ->
	if pmsToSend.length is 0
		return
	pmToSend = pmsToSend.shift()
	setTimeout ->
		bot.pm pmToSend.msg, pmToSend.userid, sendPMInQueue
	,25
exports.queuePMs = queuePMs
exports.setBot = setBot