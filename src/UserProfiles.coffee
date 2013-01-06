profiles = {}
bot = null
init = (_bot) ->
	bot = _bot
	bot.on 'update_user',(data) ->
		console.log 'update_user'
		console.log data
		delete profiles[data.userid]
callbackQueue = []
useridQueue = []
getProfile = (userid, callback) ->
	console.log 'request profile'
	if typeof profiles[userid] isnt 'undefined'
		console.log 'profile found retuning'
		return callback(profiles[userid])

	console.log 'unknown profile'
	callbackQueue.push(callback)
	useridQueue.push(userid)
	bot.getProfile(userid, profileGot)
profileGot = (data) ->
	cb = callbackQueue.shift()
	userid = useridQueue.shift()
	profiles[userid] = data
	cb(data)
exports.getProfile = getProfile
exports.init = init