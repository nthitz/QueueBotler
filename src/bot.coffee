http = require 'http'
$ = require 'jquery'
querystring = require 'querystring'
Bot    = require('ttapi');
auth = require './botAuth'
profiles = require './UserProfiles'
DEBUG = true
host = 'www.sosimpull.com'
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
		item = {name: name, time: time, status: status}
		curQ.push(item)
	callback(curQ)
sendQueueInChat = (queue) ->
	console.log 'sendq'
	console.log queue
	msgs = []
	msgs.push 'Current Queue from sosimpull.com/mashupfm-line/ :'
#	bot.speak(msg)
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
	if DEBUG
		console.log msgs
	else
		sendChat(msgs)
chatToSend = []
msgToSend = ''
sendChat = (msgs) ->
	if chatToSend.length isnt 0
		console.log 'pending chat messages, not implemented'
		return
	chatToSend = msgs
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
			return false
	#addToQueue(user)
addToQueue = (user) -> 
	console.log 'add to queue'
	addData = querystring.stringify {
      whichLine: 0 #mashup.fm lime
      lineName: user.name
      linePIN: 'asd'
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
	console.log queueOptions
	cb = (response) ->
		response.setEncoding('utf8');

		str = ''
		response.on 'data', (data) ->
			str += data
		response.on 'end', ->
			console.log 'added to queue ? '
			console.log str
	req = http.request queueOptions, cb
	console.log addData
	req.write(addData)
	req.end()
parsePM = (pm, user) ->
	if pm.text is 'queuebot'
		requestQueue(sendQueueInChat)
	if pm.text is 'add'
		requestQueue (queue) ->
			addToQueueIfNotInQueue(queue, user)

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

