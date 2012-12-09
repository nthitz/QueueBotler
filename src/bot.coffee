http = require 'http'
$ = require 'jquery'

Bot    = require('ttapi');
auth = require './botAuth'

console.log auth
requestQueue = (callback) ->
	console.log 'requesting queue'
	queueOptions = {
		host: 'www.sosimpull.com'
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
		if person.status isnt 'Here'
			continue
		lineNum++
		pMsg = numberToEmoji(lineNum)
		pMsg += ' ' + person.name
		msgs.push pMsg
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


# requestQueue(sendQueueInChat)

bot = new Bot(auth.AUTH, auth.USERID);
bot.on 'ready',       (data) -> 
	bot.roomRegister(auth.ROOMID)
#bot.on 'roomChanged',  (data) ->
#	console.log('The bot has changed room.', data)

bot.on 'speak',        (data) ->
	if data.text.toLowerCase().indexOf('queuebot') isnt -1
		console.log 'requesting queue'
		requestQueue(sendQueueInChat)
bot.on 'pmmed', (data) ->
	requestQueue(sendQueueInChat)

#bot.on 'update_votes', (data) ->
#	console.log('Someone has voted',  data)
#bot.on 'registered',   (data) ->
#	console.log('Someone registered', data)

