 # Msg.coffee
 #
 # @description :: TODO: You might write a short summary of how this model works and what it represents here.
 # @docs        :: http://sailsjs.org/#!documentation/models
Promise = require 'promise'
gfs = require('skipper-gridfs')(sails.config.file.opts)
path = require 'path'

module.exports =

	autoWatch:			true
	
	autosubscribe:		false
	
	tableName:	'msgs'
		
	schema:		true
	
	attributes:
		from:				
			type: 		'string'
			required:	true
		to:				
			type: 		'string'
			required: 	true
		type:
			type: 		'string'
			defaultsTo: 'chat'
		body:			
			type: 		'string'
			required:	true
			defaultsTo:	'file'
		file:
			type:		'string'
		createdBy:
			model:		'user'
			required:	true
		toJSON: ->
			ret = _.extend @toObject(), mime: @getMime()
			if ret.file
				ret.file = _.extend path.parse(ret.file), org: ret.file
			return ret
		getMime: ->
			return if @file then sails.services.file.type(@file) else 'text/html'
		isImg: ->
			return if @file then sails.services.file.isImg(@file) else false
			
	broadcast: (roomName, eventName, data, socketToOmit) ->
		to = data.data.to
		from = data.data.from
		msg = sails.models.msg.findOne(data.id)
		grp = sails.models.group.findOne(jid: to).populateAll()
		emit = (sockets) ->
			msg
				.then (message) ->
					_.extend data, data: message.toJSON()
					sails.sockets.emit sockets, eventName, data
				.catch sails.log.error
		
		# filter if socket.user is authorized to listen the created msg
		sockets = _.map sails.sockets.subscribers(roomName)
		if sails.services.jid.isMuc to
			grp
				.then (group) ->
					ret = _.filter sockets, (id) ->
						sails.sockets.get(id).user.canEnter group
					emit(ret)
				.catch sails.log.error
		else
			ret = _.filter sockets, (id) ->
				to == sails.sockets.get(id)?.user.jid or
				from == sails.sockets.get(id)?.user.jid
			emit(ret)
			
	afterCreate: (values, cb) ->
		# update sender corresponding roster item lastmsgAt timestamp
		sails.models.roster
			.find()
			.where(jid: values.to)
			.populateAll()
			.then (roster) ->
				_.each roster, (item) ->
					if item.createdBy.jid == values.from
						item.lastmsgAt = values.createdAt
						item.save().catch sails.log.error
		cb null, values
		
	afterDestroy: (values, cb) ->
		_.each values, (msg) ->
			if msg.file
				gfs.rm msg.file, (err) ->
					if err
						sails.log.error err
		cb()
		
	afterPublishCreate: (values, req) ->
		# update all target recipients corresponding roster items, and send push notification
		# update roster newmsg counter
		newmsg = (item) ->
			item.newmsg ?= 0
			item.newmsg = item.newmsg + 1
		
		if sails.services.jid.isMuc(values.to)
			# update all subscribed parties (jid exists in roster)
			sails.models.roster
				.find()
				.where(jid: values.to)
				.populateAll()
				.then (roster) ->
					_.each roster, (item) ->
						item.lastmsgAt = values.createdAt
						if item.createdBy.jid != values.from
							newmsg(item)
							sails.services.rest
								.push req.user.token, item, values
								.catch sails.log.error
						item.save().catch sails.log.error
		else
			sails.models.roster
				.find()
				.where(jid: values.from)
				.populateAll()
				.then (roster) ->
					_.each roster, (item) ->
						if item.createdBy.jid == values.to
							item.lastmsgAt = values.createdAt
							newmsg(item)
							item.save().catch sails.log.error
							sails.services.rest
								.push req.user.token, item, values
								.catch sails.log.error