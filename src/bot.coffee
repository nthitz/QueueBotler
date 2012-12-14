http = require 'http'
$ = require 'jquery'
querystring = require 'querystring'
Bot    = require('ttapi');
auth = require './botAuth'
profiles = require './UserProfiles'
DEBUG = true
host = 'www.sosimpull.com'
latestQueue = null
queueLineID = 0 # it's 0 for mashup.fm 
pins = {} # meh, poor 
requestQueue = (callback) ->
	console.log 'requesting queue'
	queueOptions = {
		host: host
		path: '/line.php'
	}
	cb = (response) ->
		str = ''
		response.on 'data', (data) ->
			str += data
		response.on 'end', ->
			processQueueHTML(str,callback)
	req = http.request queueOptions, cb
	req.end()

processQueueHTML = (html, callback) ->
	console.log 'queue html receieved'
	$h = $(html)
	trs = $h.find('tbody').find('tr')
	curQ = []
	for tr in trs
		tds = $(tr).find('td')
		name = $(tds[1]).text()
		time = $(tds[2]).text()
		status = $(tds[6]).find('select').val()
		queueID = $(tds[6]).find('select').attr('id').substr(7)
		item = {name: name, time: time, status: status, queueID: queueID}
		curQ.push(item)
	latestQueue = curQ
	callback(curQ)
getQueueMessages = (queue) ->
	msgs = []
	msgs.push 'Current Queue from sosimpull.com/mashupfm-line/ :'
	lineNum = 0
	for index of queue
		person = queue[index]
		lineNum++
		pMsg = numberToEmoji(lineNum)
		pMsg += ' ' + person.name + ' ('+person.time
		if person.status isnt 'Here'
			pMsg += ', ' + person.status
		pMsg += ')'
		msgs.push pMsg
	return msgs
sendQueueInPM = (queue, user) ->
	console.log 'send queue in pm'
	msgs = getQueueMessages(queue)
	queuePMs(msgs, user)
pmsToSend = []
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
sendQueueInChat = (queue) ->
	console.log 'sendq in chat'
	console.log queue
	msgs = getQueueMessages(queue)
	if DEBUG
		console.log msgs
	else
		sendChat(msgs)
chatToSend = []
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


numberToEmoji = (num) ->
	switch num
		when 1 then return ":one:"
		when 2 then return ":two:"
		when 3 then return ":three:"
		when 4 then return ":four:"
		when 5 then return ":five:"
		when 6 then return ":six:"
		when 7 then return ":seven:"
		when 8 then return ":eight:"
		when 9 then return ":nine:"
		else return num	+ ":"


bot = new Bot(auth.AUTH, auth.USERID);
profiles.init(bot)
bot.on 'ready', (data) -> 
	bot.roomRegister auth.ROOMID

addToQueueIfNotInQueue = (queue, user) ->
	username = user.name
	for person in queue
		if person.name is username
			console.log 'user already in queue, maybe some chat response here?'
			bot.pm "You are already in the queue.", user.userid
			return false
	addToQueue(user)
savePinInQueue = (queue, pin, queueName) ->
	for person in queue
		if person.name is queueName
			savePin person.queueID, pin, queueName
			break
savePin = (lineID, pin, queueName) ->
	pins[queueName] = {lineID: lineID, pin: pin}
addToQueue = (user) -> 
	console.log 'add to queue'
	pin = Math.floor(Math.random() * 1000);
	strPin = "" + pin
	if pin < 100
		strPin = Math.floor(Math.random()*10) + strPin
	if pin < 10
		strPin = Math.floor(Math.random()*10) + strPin
	#pins[user.name] = strPin
	
	addData = querystring.stringify {
      whichLine: queueLineID #mashup.fm lime
      lineName: user.name
      linePIN: strPin
      Add: 'Add'
    }
    queueOptions = {
		host: host
		path: '/lineProcess.php'
		method: 'POST'
		headers: 
	        'Content-Type': 'application/x-www-form-urlencoded'
	        'Content-Length': addData.length
    
	}
	cb = (response) ->
		response.setEncoding('utf8');

		str = ''
		response.on 'data', (data) ->
			str += data
		response.on 'end', ->
			console.log 'added to queue ? '
			requesttQueue (queue) -> savePinInQueue queue, strPin, user.name
			msg = "You've been added to the queue, your pin is " + strPin + ". Estimated position in line #" + (latestQueue.length + 1)
			bot.pm msg, user.userid
	req = http.request queueOptions, cb
	console.log addData
	req.write(addData)
	req.end()
removeFromQueue = (queue, user) ->
	userID = user.userid
	name = user.name

	for queuePerson in queue
		if queuePerson.name is name
			removeQueuedPerson(queuePerson, user)
			return
	bot.pm 'You are not in the queue. I think.', user.userid
removeQueuedPerson = (queuePerson, user) ->
	#http://www.sosimpull.com/lineDeleteProcess.php?lineID=" + lineID  + 
		#"&linePIN=" + linePIN + "&whichLine=0
	if typeof pins[user.name] is 'undefined'
		bot.pm "Sorry, I don't know your PIN.", user.userid
		return
	queueOptions = {
		host: host
		path: '/lineDeleteProcess.php?lineID=' + queuePerson.queueID + '&linePIN=' + pins[user.name]['pin'] +
			"&whichLine="+queueLineID
	}
	cb = (response) ->
		response.setEncoding('utf8');
		str = ''
		response.on 'data', (data) ->
			str += data
		response.on 'end', ->
			console.log 'removed from queue ? '
			console.log str
			msg = "You've been removed from the queue"
			delete pins[user.name]
			bot.pm msg, user.userid
	http.request(queueOptions, cb).end()
checkInIfInList = (queue, user) ->
	userID = user.userid
	name = user.name
	console.log queue
	for queuePerson in queue
		if queuePerson.name is name
			checkIn(queuePerson, user)
			return
	bot.pm 'You are not in the queue. I think.', user.userid
checkIn = (queuePerson, user) ->
	#http://www.sosimpull.com/lineDeleteProcess.php?lineID=" + lineID  + 
		#"&linePIN=" + linePIN + "&whichLine=0
	if typeof pins[user.name] is 'undefined'
		bot.pm "Sorry, I don't know your PIN.", user.userid
		return
	queueOptions = {
		host: host
		path: '/lineCheckInProcess.php?lineID=' + queuePerson.queueID + '&linePIN=' + pins[user.name]['pin'] +
			"&whichLine="+queueLineID
	}
	console.log queueOptions
	cb = (response) ->
		response.setEncoding('utf8');
		str = ''
		response.on 'data', (data) ->
			str += data
		response.on 'end', ->
			console.log 'checked in '
			console.log str
			msg = "You've been checked in"
			bot.pm msg, user.userid
	http.request(queueOptions, cb).end()
parsePM = (pm, user) ->
	if pm.text is 'queuebot'
		requestQueue(sendQueueInChat)
	if pm.text is 'add' or pm.text is 'a'
		requestQueue (queue) -> addToQueueIfNotInQueue(queue, user)
	if pm.text is 'rm' or pm.text is 'r' or pm.text is 'remove'
		requestQueue (queue) -> removeFromQueue(queue,user)
	if pm.text is 'c' or pm.text is 'ci' or pm.text is 'checkin' or pm.text is 'check in'
		requestQueue (queue) -> checkInIfInList(queue,user)
	if pm.text is 'q' or pm.text is 'queue'
		requestQueue (queue) -> sendQueueInPM(queue,user)

	console.log pm
	#console.log user
###
bot.on 'speak', (data) ->
	if data.text.toLowerCase().indexOf('queuebot') isnt -1
		console.log 'requesting queue'
		requestQueue(sendQueueInChat)
###
bot.on 'pmmed', (data) ->
	profiles.getProfile data.senderid, (profile) ->
		parsePM data, profile

