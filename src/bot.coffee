http = require 'http'
$ = require 'jquery'
querystring = require 'querystring'
TTAPI    = require('ttapi');
profiles = require './UserProfiles'
PMManager = require './PMManager'
ChatManager = require './ChatManager'
PinManager = require './PinManager'
util = require 'util'
redis = require 'redis'
DEBUG = false
host = 'www.sosimpull.com'
latestQueue = null
queueLineID = 0 # it's 0 for mashup.fm 
#pins = {} # meh, poor, hey using redis now, way better!
adminIDs = ["4f50f403590ca262030050e7"]
devMode = false
bot = null
redisClient = null
chatModeOnFor = []
requestQueue = (callback) ->
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
	msgs.push 'Current Queue from http://sosimpull.com/mashupfm-line/'
	lineNum = 0
	if queue.length isnt 0
		for index of queue
			person = queue[index]
			lineNum++
			pMsg = numberToEmoji(lineNum) + ' '
			pMsg += if person.name.charAt(0) is '@' then '' else '@' 
			pMsg += person.name
			pMsg += ' ('+person.time
			if person.status isnt 'Here'
				pMsg += ', ' + person.status
			pMsg += ')'
			msgs.push pMsg
	else
		msgs.push "Empty!"
	return msgs
sendQueueInPM = (queue, user) ->
	msgs = getQueueMessages(queue)
	PMManager.queuePMs(msgs, user.userid)
# check if the user is a mod, on deck, or a QB admin
sendQueueInChatIfVerified = (user) ->
	bot.roomInfo(false,(data) ->
		verified = false
		if data.room.metadata.moderator_id.indexOf(user.userid) isnt -1
			verified = true
		if data.room.metadata.djs.indexOf(user.userid) isnt -1
			verified = true
		if adminIDs.indexOf(user.userid) isnt - 1 # dev nthitz
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
makeNameQueueSafe = (name) ->
	return name.replace(/'/g, "")
addToQueueIfNotInQueue = (queue, user) ->
	username = makeNameQueueSafe(user.name)
	for person in queue
		if person.name is username
			PMManager.queuePMs ["You are already in the queue."], user.userid
			return false
	addToQueue(user)
savePinInQueue = (queue, pin, user) ->
	queueName = makeNameQueueSafe(user.name)
	for person in queue
		if person.name is queueName
			savePin person.queueID, pin, user.userid
			break
savePin = (lineID, pin, userid) ->
	pinO = {lineID: lineID, pin: pin}
	PinManager.set(userid, pinO)
addToQueue = (user) -> 
	pin = Math.floor(Math.random() * 1000);
	strPin = "" + pin
	if pin < 100
		strPin = Math.floor(Math.random()*10) + strPin
	if pin < 10
		strPin = Math.floor(Math.random()*10) + strPin
	
	queueName = makeNameQueueSafe(user.name)
	addData = querystring.stringify {
      whichLine: queueLineID #mashup.fm lime
      lineName: queueName
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
			requestQueue (queue) -> savePinInQueue queue, strPin, user
			msg = "You've been added to the queue, your pin is " + strPin + ". Estimated position in line #" + (latestQueue.length + 1)
			PMManager.queuePMs [msg], user.userid
	req = http.request queueOptions, cb
	console.log addData
	req.write(addData)
	req.end()
doQueueActionIfInQueue = (queue, user, action, pmOnFail = false) ->
	#we need the line ID that is saved
	PinManager.get user.userid, (error, pin) ->
		if pin is null
			if pmOnFail
				PMManager.queuePMs ["Hmm I don't know anything about you."], user.userid
			return
		for queuePerson in queue
			if queuePerson.lineID is pin.lineID
				action queuePerson, user
				return
		# if method hasn't returned by now. it hasn't been successful
		if pmOnFail
			PMManager.queuePMs ["Hmm you don't seem to be in the queue."]
			console.log("REMOVE THEM FROM PinManager?!")
removeFromQueue = (queue, user) ->
	userID = user.userid
	name = makeNameQueueSafe(user.name)

	for queuePerson in queue
		if queuePerson.name is name
			removeQueuedPerson(queuePerson, user)
			return
	PMManager.queuePMs ['You are not in the queue. I think.'], user.userid
removeQueuedPerson = (queuePerson, user) ->
	#http://www.sosimpull.com/lineDeleteProcess.php?lineID=" + lineID  + 
		#"&linePIN=" + linePIN + "&whichLine=0
	PinManager.get user.userid, (error, pin) ->
		if pin is null
			PMManager.queuePMs ["Sorry, I don't know your PIN."], user.userid
			return
		queueOptions = {
			host: host
			path: '/lineDeleteProcess.php?lineID=' + queuePerson.queueID + '&linePIN=' + pin.pin +
				"&whichLine="+queueLineID
		}
		console.log queueOptions.path
		cb = (response) ->
			response.setEncoding('utf8');
			str = ''
			response.on 'data', (data) ->
				str += data
			response.on 'end', ->
				msg = "You've been removed from the queue"
				PinManager.del user.userid
				PMManager.queuePMs [msg], user.userid
		http.request(queueOptions, cb).end()
updateStatusIfInQueue = (queue, user, status) ->
	userID = user.userID
	name = makeNameQueueSafe(user.name)
	for queuePerson in queue
		if queuePerson.name is name
			updateStatus(queuePerson, user, status)
			return
	PMManager.queuePMs ['You are not in the queue. I think.'], user.userid
updateStatus = (queuePerson, user, status) ->
	oldStatus = status.toLowerCase()
	if oldStatus is 'bathroom'
		oldStatus = 'restroom'
	status = oldStatus.charAt(0).toUpperCase() + oldStatus.slice(1);
	PinManager.get user.userid, (error, pin)->
		if pin is null
			PMManager.queuePMs ['Sorry, I don\'t know your PIN.'], user.userid
			return
		reqOpts = {
			host: host
			path: '/lineCheckInProcess.php?lineID=' + queuePerson.queueID +
				'&linePIN=' + pin.pin +
				'&whichLine=' + queueLineID + '&lineStatus=' + status
		}
		console.log reqOpts.path
		cb = (response) ->
			response.setEncoding('utf8');
			str = ''
			response.on 'data', (data) ->
				str += data
			response.on 'end', ->
				msg = "Your status has been updated to: " + status
				PMManager.queuePMs [msg], user.userid
		http.request(reqOpts, cb).end()
checkInIfInList = (queue, user) ->
	userID = user.userid
	name = makeNameQueueSafe(user.name)
	for queuePerson in queue
		if queuePerson.name is name
			checkIn(queuePerson, user)
			return
	PMManager.queuePMs ['You are not in the queue. I think.'], user.userid
checkIn = (queuePerson, user) ->
	#http://www.sosimpull.com/lineDeleteProcess.php?lineID=" + lineID  + 
		#"&linePIN=" + linePIN + "&whichLine=0
	PinManager.get user.userid, (error, pin) ->
		if pin is null
			PMManager.queuePMs ["Sorry, I don't know your PIN."], user.userid
			return
		queueOptions = {
			host: host
			path: '/lineCheckInProcess.php?lineID=' + queuePerson.queueID + '&linePIN=' + pin.pin +
				"&whichLine="+queueLineID
		}
		console.log queueOptions.path
		cb = (response) ->
			response.setEncoding('utf8');
			str = ''
			response.on 'data', (data) ->
				str += data
			response.on 'end', ->
				msg = "You've been checked in"
				PMManager.queuePMs [msg], user.userid
		http.request(queueOptions, cb).end()
parsePM = (pm, user) ->
	originalText = pm.text
	pm.text = pm.text.toLowerCase().trim()
	if devMode
		if adminIDs.indexOf(user.userid) is -1
			PMManager.queuePMs ["I'm currently offline while @nthitz rewires my circuits. Please goto http://sosimpull.com/mashupfm-line/ to join the queue!"], user.userid
			return
	if pm.text is '=chatmodeoff'
		delete chatModeOnFor[user.userid]
		PMManager.queuePMs [":("], user.userid
	else if typeof chatModeOnFor[user.userid] isnt 'undefined'
		ChatManager.sendChat [originalText]
	else if pm.text is 'q chat' or pm.text is 'queue chat'
		sendQueueInChatIfVerified(user)
	else if pm.text is 'add' or pm.text is 'a'
		requestQueue (queue) -> addToQueueIfNotInQueue(queue, user)
	else if pm.text is 'rm' or pm.text is 'r' or pm.text is 'remove'
		requestQueue (queue) -> removeFromQueue(queue,user)
	else if pm.text is 'c' or pm.text is 'ci' or pm.text is 'checkin' or pm.text is 'check in'
		requestQueue (queue) -> checkInIfInList(queue,user)
	else if pm.text is 'q' or pm.text is 'queue'
		requestQueue (queue) -> sendQueueInPM(queue,user)
	else if pm.text is 'lunch' or pm.text is 'meeting' or pm.text is 'restroom' or pm.text is 'bathroom' or pm.text is 'here'
		 requestQueue (queue) -> updateStatusIfInQueue(queue, user, pm.text)
	
	else if pm.text is '=chatmodeon'
		if adminIDs.indexOf user.userid isnt -1
			chatModeOnFor[user.userid] = true
			PMManager.queuePMs [":)"], user.userid

	#help bullshit below

	else if  pm.text is 'help'
		pmHelp("help",user.userid)
	else if pm.text is 'about'
		pmHelp 'about', user.userid
	else if pm.text is 'status' or pm.text is 'help status'
		pmHelp 'status', user.userid
	else if pm.text is 'help add'
		pmHelp("add",user.userid)
	else if pm.text is 'help remove'
		pmHelp('remove', user.userid)
	else if pm.text is 'help checkin'
		pmHelp 'checkin', user.userid
	else if pm.text is 'help queue'
		pmHelp 'queue', user.userid
	else if pm.text is 'help about'
		pmHelp 'about', user.userid
	else 
		PMManager.queuePMs ["Sorry I don't know what you mean. PM me \"help\" for info."], user.userid
	console.log "pm: " + user.name + ": " + pm.text
	#console.log user
pmHelp = (msg, userid) ->
	msgs = []
	if msg is "help"
		msgs = ["Hello, I'm QueueBotler for the mashup.fm line @ http://sosimpull.com/mashupfm-line/. Here are some commands: add, remove, checkin, queue, about, status. Reply \"help [command]\" for more info on any command (I only work through PMs!)"]
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
	else if msg is 'about'
		msgs = ["Real line here: http://sosimpull.com/mashupfm-line/", 
    	"Facebook Group http://www.facebook.com/groups/mashupfm/",
    	"Rules http://bit.ly/TLBLyC" ,
    	"Created by @nthitz - nthtiz AT gmail DOT com"]
	else if msg is 'status'
    	msgs = ["To change your status, pm me one of the following: lunch, meeting, restroom or here"]
	PMManager.queuePMs msgs, userid

init = () -> 
	if typeof process.env.AUTH is 'undefined'
		console.log 'setup bot environmnet vars first'
		process.exit()
	if typeof process.env.REDISURL is 'undefined'
		console.log 'need redis url'
		process.exit()
	rtg = require("url").parse(process.env.REDISURL)
	redisClient = redis.createClient(rtg.port, rtg.hostname)
	redisClient.auth(rtg.auth.split(":")[1],redis.print)
	PinManager.init(redisClient)
	bot = new TTAPI(process.env.AUTH, process.env.USERID);
	profiles.init(bot)
	PMManager.setBot(bot)
	ChatManager.setBot bot
	bot.on 'ready', (data) -> 
		bot.roomRegister process.env.ROOMID

	bot.on 'speak', (data) ->
		lower  = data.text.toLowerCase().trim()
		if lower.match(/^\/?\+?q(ueue)?\+?$/)
			pmHelp("help", data.userid)

	bot.on 'pmmed', (data) ->
		profiles.getProfile data.senderid, (profile) ->
			parsePM data, profile
init()