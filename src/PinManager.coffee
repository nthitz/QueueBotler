redisClient = null
init = (redis) ->
	redisClient = redis
get = (userid,cb) ->
	redisClient.get "PIN-"+userid, (error, json) ->
		if json is null
			cb error, null
		else
			cb error, JSON.parse(json)
	
set = (userid,pin) ->
	redisClient.set("PIN-" + userid, JSON.stringify(pin))
del = (userid) ->
	redisClient.del("PIN-" + userid)
exports.get = get
exports.set = set
exports.del = del
exports.init = init