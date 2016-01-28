actionUtil = require 'sails/lib/hooks/blueprints/actionUtil'

module.exports = (req, res, next) ->
	values = actionUtil.parseValues(req)
	sails.services.roster
		.findOrCreate req.user.jid, values.to
		.then ->
			next()
		.catch res.serverError