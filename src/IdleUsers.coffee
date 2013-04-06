latestUserActions = {}
logUserAction = (userid) ->
	latestUserActions[userid] = new Date().getTime()
getActiveCount = (activeTime) ->
	now = new Date().getTime()
	timeAgo = now - activeTime
	numActive = 0
	for userid, time of latestUserActions
		if time > timeAgo
			numActive++
	return numActive
pruneUsers = () ->
	now = new Date().getTime()
	pruneLimit = 60 * 60 * 1000 # one hour
	pruneTime = now - prumeLimit
	idsToDelete = []
	for userid, time of latestUserActions
		if time < pruneTime
			idsToDelete.push userid
	for userid in idsToDelete
		delete latestUserActions[userid]
setVotersActive = (voters) ->
	return
	console.log latestUserActions
	console.log voters
	for vote in voters
		logUserAction(vote[0])
exports.logUserAction = logUserAction
exports.getActiveCount = getActiveCount
exports.pruneUsers = pruneUsers
exports.setVotersActive = setVotersActive