 # RosterController
 #
 # @description :: Server-side logic for managing rosters
 # @help        :: See http://links.sailsjs.org/docs/controllers
_ = require 'lodash'
Promise = require 'promise'
actionUtil = require 'sails/lib/hooks/blueprints/actionUtil'

module.exports =
	find: (req, res) ->
		req.options.where = req.options.where || {}
		_.extend req.options.where, createdBy: req.user.id
		
		model = actionUtil.parseModel req
		cond = actionUtil.parseCriteria req
		count = new Promise (fulfill, reject) ->
			model.count()
				.where( cond )
				.exec (err, data) ->
					if err
						reject err
					else
						fulfill data
		query = new Promise (fulfill, reject) ->
			model.find()
				.where( cond )
				.limit( actionUtil.parseLimit(req) )
				.skip( actionUtil.parseSkip(req) )
				.sort( actionUtil.parseSort(req) )
				.exec (err, data) ->
					if err
						reject err
					else
						if req._sails.hooks.pubsub && req.isSocket
							model.subscribe(req, data)
							if req.options.autoWatch
								model.watch(req)
						_.each data, (record) ->
							actionUtil.subscribeDeep(req, record)
						p = _.map data, (item) ->
							new Promise (fulfill, reject) ->
								sails.models.user.findOne(jid: item.jid).exec (err, user) ->
									if err
										reject err
									else
										fulfill _.extend item, _.pick(user, 'online', 'status')
						Promise.all(p)
							.then (results) ->
								fulfill results
							.catch reject
		Promise.all([count, query])
			.then (data) ->
				res.ok
					count:		data[0]
					results:	data[1]
			.catch res.serverError