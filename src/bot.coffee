http = require 'http'
$ = require 'jquery'
querystring = require 'querystring'
Bot    = require('ttapi');
profiles = require './UserProfiles'
PMManager = require './PMManager'
ChatManager = require './ChatManager'
DEBUG = false
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
	if queue.length isnt 0
		for index of queue
			person = queue[index]
			lineNum++
			pMsg = numberToEmoji(lineNum)
			pMsg += ' ' + person.name + ' ('+person.time
			if person.status isnt 'Here'
				pMsg += ', ' + person.status
			pMsg += ')'
			msgs.push pMsg
	else
		msgs.push "Empty!"
	return msgs
sendQueueInPM = (queue, user) ->
	console.log 'send queue in pm'
	msgs = getQueueMessages(queue)
	PMManager.queuePMs(msgs, user.userid)

sendQueueInChatIfVerified = (user) ->
	bot.roomInfo(false,(data) ->
		verified = false
		if data.room.metadata.moderator_id.indexOf(user.userid) isnt -1
			verified = true
		if data.room.metadata.djs.indexOf(user.userid) isnt -1
			verified = true
		if user.userid is '4f50f403590ca262030050e7' # dev nthitz
			verified = true
		if verified
			requestQueue (queue) -> sendQueueInChat(queue)
		else
			PMManager.queuePMs ["Sorry I can't let you do that."], user.userid
	)

sendQueueInChat = (queue) ->

	msgs = getQueueMessages(queue)
	ChatManager.sendChat(msgs)



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

if typeof process.env.AUTH is 'undefined'
	console.log 'setup bot environmnet vars first'
	process.exit()

bot = new Bot(process.env.AUTH, process.env.USERID);
profiles.init(bot)
PMManager.setBot(bot)
ChatManager.setBot bot
bot.on 'ready', (data) -> 
	bot.roomRegister process.env.ROOMID

addToQueueIfNotInQueue = (queue, user) ->
	username = user.name
	for person in queue
		if person.name is username
			console.log 'user already in queue, maybe some chat response here?'
			PMManager.queuePMs ["You are already in the queue."], user.userid
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
			requestQueue (queue) -> savePinInQueue queue, strPin, user.name
			msg = "You've been added to the queue, your pin is " + strPin + ". Estimated position in line #" + (latestQueue.length + 1)
			PMManager.queuePMs [msg], user.userid
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
	PMManager.queuePMs ['You are not in the queue. I think.'], user.userid
removeQueuedPerson = (queuePerson, user) ->
	#http://www.sosimpull.com/lineDeleteProcess.php?lineID=" + lineID  + 
		#"&linePIN=" + linePIN + "&whichLine=0
	if typeof pins[user.name] is 'undefined'
		PMManager.queuePMs ["Sorry, I don't know your PIN."], user.userid
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
			PMManager.queuePMs [msg], user.userid
	http.request(queueOptions, cb).end()
checkInIfInList = (queue, user) ->
	userID = user.userid
	name = user.name
	console.log queue
	for queuePerson in queue
		if queuePerson.name is name
			checkIn(queuePerson, user)
			return
	PMManager.queuePMs ['You are not in the queue. I think.'], user.userid
checkIn = (queuePerson, user) ->
	#http://www.sosimpull.com/lineDeleteProcess.php?lineID=" + lineID  + 
		#"&linePIN=" + linePIN + "&whichLine=0
	if typeof pins[user.name] is 'undefined'
		PMManager.queuePMs ["Sorry, I don't know your PIN."], user.userid
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
			PMManager.queuePMs [msg], user.userid
	http.request(queueOptions, cb).end()
parsePM = (pm, user) ->
	pm.text = pm.text.toLowerCase().trim()
	if pm.text is 'q chat' or pm.text is 'queue chat'
		sendQueueInChatIfVerified(user)
	else if pm.text is 'add' or pm.text is 'a'
		requestQueue (queue) -> addToQueueIfNotInQueue(queue, user)
	else if pm.text is 'rm' or pm.text is 'r' or pm.text is 'remove'
		requestQueue (queue) -> removeFromQueue(queue,user)
	else if pm.text is 'c' or pm.text is 'ci' or pm.text is 'checkin' or pm.text is 'check in'
		requestQueue (queue) -> checkInIfInList(queue,user)
	else if pm.text is 'q' or pm.text is 'queue'
		requestQueue (queue) -> sendQueueInPM(queue,user)
	else if  pm.text is 'help'
		pmHelp("help",user.userid)
	else if pm.text is 'help add'
		pmHelp("add",user.userid)
	else if pm.text is 'help remove'
		pmHelp('remove', user.userid)
	else if pm.text is 'help checkin'
		pmHelp 'checkin', user.userid
	else if pm.text is 'help queue'
		pmHelp 'queue', user.userid
	else 
		PMManager.queuePMs ["Sorry I don't know what you mean. PM me \"help\" for info."], user.userid
	console.log pm
	#console.log user
pmHelp = (msg, userid) ->
	msgs = []
	if msg is "help"
		msgs = ["Hello, I'm QueueBotler. Here are some commands: add, remove, checkin, queue. Reply \"help [command]\" for more info on any command (I only work through PMs!)"]
	else if msg is 'add'
		msgs = ["add: adds you to the sosimpull.com queue", "aliases: add, a"]
	else if msg is "remove"
		msgs = ["remove: removes you from the sosimpull.com queue","only works if you added with the bot"
		"aliases: remove, rm, r"]
	else if msg is "checkin"
		msgs = ["checkin: checks you in to the sosimpull.com queue", "only works if you added with the bot"
		,"aliases: checkin, check in, ci, c"]
	else if msg is "queue"
		msgs = ["queue: pms you the current queue", "aliases: queue, q",
		 "if you are a mod or on deck you can append 'chat' to send the queue to the chat ex: \"q chat\""]

	PMManager.queuePMs msgs, userid
bot.on 'speak', (data) ->
	lower  = data.text.toLowerCase().trim()
	if lower.match(/^\/?q(ueue)?\+?$/)
		pmHelp("help", data.userid)

bot.on 'pmmed', (data) ->
	profiles.getProfile data.senderid, (profile) ->
		parsePM data, profile

