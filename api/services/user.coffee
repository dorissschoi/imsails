module.exports =
	isOwner: (user, group) ->
		group.createdBy.id == user?.id
		
	isModerator: (user, group) ->
		_.any group.moderators, (item) ->
			item.id == user?.id
			
	isMember: (user, group) ->
		group.type == 'Unmoderated' or _.any group.members, (item) ->
			item.id == user?.id
			
	isVisitor: (user, group) ->
		group.type == 'Moderated'

	# check if user is authorized to enter the chatroom
	canEnter: (user, group) ->
		@isVisitor(user, group) or @isMember(user, group) or @isModerator(user, group) or @isOwner(user, group)
		
	# check if user is authorized to send message to the chatroom
	canVoice: (user, group) ->
		@isMember(user, group) or @isModerator(user, group) or @isOwner(user, group)
		
	# check if user is authorized to edit the group settings
	canEdit: (user, group) ->
		@isModerator(user, group) or @isOwner(user, group)
	
	# check if user is authorized to remove this group
	canRemove: (user, group) ->
		@isOwner(user, group)
		
	# check if user is authorized to read the message
	canRead: (user, msg) ->
		new Promise (fulfill, reject) ->
			if sails.services.jid.isMuc(msg.to)
				sails.models.group
					.findOne(jid: msg.to)
					.then (group) ->
						if group
							return fulfill(group.canEnter(user))
						sails.log.error "No record found with the specified group #{msg.to}."
						reject(false)
					.catch sails.log.error
			else
				fulfill(user.jid == msg.from or user.jid == msg.to)