 # Msg.coffee
 #
 # @description :: TODO: You might write a short summary of how this model works and what it represents here.
 # @docs        :: http://sailsjs.org/#!documentation/models

module.exports =

	autoWatch:			true
	
	autoSubscribe:		false
	
	autoSubscribeDeep:	false
	
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
		createdBy:
			model:		'user'
			required:	true
			
	broadcast: (roomName, eventName, data, socketToOmit) ->
		# filter if socket.user is authorized to listen the created msg
		sockets = _.map sails.sockets.subscribers(roomName)
		to = data.data.to
		if sails.services.jid.isMuc to
			sails.models.group
				.findOne jid: to
				.populateAll()
				.then (group) ->
					ret = _.filter sockets, (id) ->
						group?.enterAllowed sails.sockets.get(id).user
					sails.sockets.emit ret, eventName, data
				.catch sails.log.error
		else
			ret = _.filter sockets, (id) ->
				to == sails.sockets.get(id)?.user.jid
			sails.sockets.emit ret, eventName, data
			
	afterPublishCreate: (values, req) ->
		# query for chat
		query = sails.models.roster
			.find()
			.where(jid: values.from)
			.populate('createdBy', where: jid: values.to)
		# query for groupchat
		if values.type != 'chat'
			query = sails.models.roster
			.find()
			.where(jid: values.to)
		query
			.then (roster) ->
				_.each roster, (item) ->
					item.newmsg ?= 0
					item.newmsg = item.newmsg + 1
					item.save().catch sails.log.error
			.catch sails.log.error