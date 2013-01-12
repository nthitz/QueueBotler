profiles = {}
bot = null
init = (_bot) ->
	bot = _bot
	bot.on 'update_user',(data) ->
		delete profiles[data.userid]
callbackQueue = []
useridQueue = []
getProfile = (userid, callback) ->
	if typeof profiles[userid] isnt 'undefined'
		return callback(profiles[userid])

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