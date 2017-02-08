env = require './env.coffee'
lurl = require 'url'
lpath = require 'path'
require 'PageableAR'
_ = require 'lodash'
sails =
	services:
		user:	require '../../api/services/user.coffee'
		file:	require '../../api/services/file.coffee'

urlRoot = (model, url, root = env.server.app.urlRoot) ->
	ret = lurl.parse root
	ret.pathname = lpath.join ret.pathname, url
	if model.transport() == 'io' then "/#{url}" else lurl.format ret

angular.module('starter.model', ['ionic', 'PageableAR', 'util.file'])

	.factory 'resource',  ($rootScope, pageableAR, $http, $log, fileService) ->

		pageableAR.setTransport(pageableAR.Model.iosync)

		class RosterItem extends pageableAR.Model
			$urlRoot: ->
				urlRoot(@, "api/roster")

			$parse: (data, opts) ->
				ret = super(data, opts)

				_.each ['updatedAt', 'createdAt', 'lastmsgAt'], (field) ->
					if ret[field]
						ret[field] = new Date ret[field]

				if ret.user
					ret.user = new User ret.user

				if ret.group
					ret.group = new Group ret.group

				return ret

			$fetch: (opts = {}) ->
				opts.params = _.defaults populate: ['user', 'group', 'createdBy'], opts.params
				super opts

		class Roster extends pageableAR.PageableCollection
			_instance = null

			$urlRoot: ->
				urlRoot(@, "api/roster")

			model: RosterItem

			@instance: ->
				_instance ?= new Roster()

			$fetch: (opts = {}) ->
				opts.params = _.defaults populate: ['user', 'group', 'createdBy'], opts.params
				super opts

		class User extends pageableAR.Model
			@type:
				placeholder:
					phone:		'Phone'
					otherEmail:	'Email'
					address:	'Address'
				values:
					phone:		['Mobile', 'Office', 'Home', 'Other']
					otherEmail:	['Office', 'Personal', 'Other']
					address:	['Office', 'Home', 'Other']
				status: [
					"Available"
					"In a meeting"
					"Busy"
					"On leave"
					"Battery about to die"
					"Can't talk, IM only"
					"Urgent calls only"
				]

			_me = null

			$urlRoot: ->
				urlRoot(@, "api/user")

			@me: ->
				_me ?= new User id: 'me'

			$parse: (data, opts) ->
				ret = super(data, opts)
				_.each ['updatedAt', 'createdAt'], (field) ->
					if ret[field]
						ret[field] = new Date ret[field]
				if env.isNative() and ret.photoUrl and ret.photoUrl.indexOf(env.server.app.urlRoot) == -1
					ret.photoUrl = "#{env.server.app.urlRoot}/#{ret.photoUrl}"
				return ret

			$fetch: (opts = {}) ->
				opts.params = _.defaults populate: ['ownerGrps', 'moderatorGrps', 'memberGrps', 'createdBy'], opts.params
				super opts

			post: ->
				sails.services.user.post(@)

			fullname: ->
				sails.services.user.fullname(@)

			isOwner: (group) ->
				sails.services.user.isOwner(@, group)

			isModerator: (group) ->
				sails.services.user.isModerator(@, group)

			isMember: (group) ->
				sails.services.user.isMember(@, group)

			isVisitor: (group) ->
				sails.services.user.isVisitor(@, group)

			# check if user is authorized to enter the chatroom
			canEnter: (group) ->
				sails.services.user.canEnter(@, group)

			# check if user is authorized to send message to the chatroom
			canVoice: (group) ->
				sails.services.user.canVoice(@, group)

			# check if user is authorized to edit the group settings
			canEdit: (group) ->
				sails.services.user.canEdit(@, group)

			# check if user is authorized to remove this group
			canRemove: (group) ->
				sails.services.user.canRemove(@, group)

		class Users extends pageableAR.PageableCollection
			_instance = null

			$urlRoot: ->
				urlRoot(@, "api/user")

			model: User

			@instance: ->
				_instance ?= new Users()
				if _instance.state.count == 0
					_instance.$fetch()
				return _instance

			$fetch: (opts = {}) ->
				opts.params = _.defaults populate: ['ownerGrps', 'moderatorGrps', 'memberGrps', 'createdBy'], opts.params
				super opts

		class Group extends pageableAR.Model
			@type:
				placeholder:
					moderators:	'Moderators'
					members:	'Members'
					visitors:	'Visitors'
				values: ['Members-Only', 'Moderated', 'Unmoderated']

			$urlRoot: ->
				urlRoot(@, "api/group")

			$defaults:
				type:		'Members-Only'
				moderators:	[]
				members:	[]
				visitors:	[]

			$parse: (data, opts) ->
				ret = super(data, opts)

				_.each ['updatedAt', 'createdAt'], (field) ->
					if ret[field]
						ret[field] = new Date ret[field]

				if ret.moderators
					ret.moderators = _.map ret.moderators, (user) ->
						new User user

				if ret.members
					ret.members = _.map ret.members, (user) ->
						new User user

				if ret.createdBy and typeof ret.createdBy == 'object'
					ret.createdBy = new User ret.createdBy

				if env.isNative() and ret.photoUrl and ret.photoUrl.indexOf(env.server.app.urlRoot) == -1
					ret.photoUrl = "#{env.server.app.urlRoot}/#{ret.photoUrl}"

				return ret

			$fetch: (opts = {}) ->
				opts.params = _.defaults populate: ['moderators', 'members', 'createdBy'], opts.params
				super opts

			exit: ->
				@$save {}, url: "#{@$url()}/exit"

		# public groups
		class Groups extends pageableAR.PageableCollection
			_instance = null

			$urlRoot: ->
				urlRoot(@, "api/group")

			model: Group

			@instance: ->
				_instance ?= new Groups()

			$fetch: (opts = {}) ->
				opts.params = _.defaults populate: ['moderators', 'members', 'createdBy'], opts.params
				super opts

		# membersOnly groups
		class GroupsPrivate extends pageableAR.PageableCollection
			_instance = null

			$urlRoot: ->
				urlRoot(@, "api/group/membersOnly")

			model: Group

			@instance: ->
				_instance ?= new GroupsPrivate()

			$fetch: (opts = {}) ->
				opts.params = _.defaults populate: ['moderators', 'members', 'createdBy'], opts.params
				super opts

		class Msg extends pageableAR.Model
			$urlRoot: ->
				urlRoot(@, "api/msg")

			@msgType: (msg) ->
				if msg.file
					switch true
						when sails.services.file.isImg msg.file_inode
							return 'img'
						when sails.services.file.isAudio msg.file_inode
							return 'audio'
						when sails.services.file.isVideo msg.file_inode
							return 'video'
						else
							return 'file'
				else
					return 'msg'

			msgType: ->
				Msg.msgType @

			templateUrl: ->
				if _.isUndefined @id
					"templates/chat/inputText.html"
				else
					switch @msgType()
						when 'img'
							"templates/chat/thumb.html"
						when 'audio'
							"templates/chat/audio.html"
						when 'video'
							"templates/chat/thumb.html"
						when 'file'
							"templates/chat/file.html"
						else
							"templates/chat/msg.html"

			$parse: (data, opts) ->
				ret = super(data, opts)
				_.each ['updatedAt', 'createdAt'], (field) ->
					if ret[field]
						ret[field] = new Date ret[field]

				return ret

			$fetch: (opts = {}) ->
				opts.params = _.defaults populate: ['file_inode', 'createdBy'], opts.params
				super opts

		class Attachment extends pageableAR.Model
			$urlRoot: ->
				urlRoot(@, "api/msg/file")

			isImg: ->
				sails.services.file.isImg(@file)

			$save: (values = {}, opts = {}) ->
				_.extend @, values
				_.extend opts, data: _.pick(@, 'to', 'type')
				fileService.fs.then (fs) =>
					fs.uploadFile @local, @$urlRoot(), opts

			$fetch: (opts = {}) ->
				localfs = fileService.fs
				path = @localPath()
				localfs
					.then (localfs) =>
						localfs.exists path
							.then (entry) =>
								if entry
									return entry
								# local file not found, create and download, resolve local entry
								localfs.create path
							.then (entry) =>
								target = entry.toURL()
								if device.platform != 'iOS'
									target = decodeURIComponent target
								localfs.download @$url(), target, opts, opts.progress
									.then =>
										@file.local = target
										entry

			$saveAs: ->
				$http.get @file.url, responseType: 'blob'
					.then (res) =>
						contentType = res.headers('Content-type')
						saveAs new Blob([res.data], type: contentType), @file.base

			localPath: ->
				@file.org

			@sync: pageableAR.Model.restsync

		class Thumb extends Attachment
			$urlRoot: ->
				urlRoot @, "api/msg/file/thumb"

			$save: ->
				$log.error 'saving thumb image is not allowed'

			localPath: ->
				sails.services.file.thumbName @file.org

		class Msgs extends pageableAR.PageableCollection
			$urlRoot: ->
				urlRoot(@, "api/msg")

			model: Msg

			$fetch: (opts = {}) ->
				opts.params = _.defaults populate: ['file_inode', 'createdBy'], opts.params
				super opts

		class Device extends pageableAR.Model
			$urlRoot: ->
				urlRoot(@, "api/device", env.server.mobile.urlRoot)

			@sync: pageableAR.Model.restsync

		User:			User
		Users:			Users
		Group:			Group
		Groups:			Groups
		GroupsPrivate:	GroupsPrivate
		RosterItem:		RosterItem
		Roster:			Roster
		Msg:			Msg
		Attachment:		Attachment
		Thumb:			Thumb
		Msgs:			Msgs
		Device:			Device
