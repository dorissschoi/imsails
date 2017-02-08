env = require '../env.coffee'
sails =
	services:
		file:	require '../../../api/services/file.coffee'

angular

	.module 'starter.controller'

	.config ($stateProvider) ->
		$stateProvider.state 'app.chat',
			url: "/chat"
			abstract: true
			views:
				menuContent:
					templateUrl: "templates/chat/index.html"

		$stateProvider.state 'app.chat.list',
			cache: false

			url: "/:type/:id"

			views:
				chatContent:
					templateUrl: 'templates/chat/list.html'
					controller: 'ChatCtrl'
			resolve:
				resource: 'resource'
				type: ($stateParams) ->
					$stateParams.type
				id: ($stateParams) ->
					$stateParams.id
				chat: (resource, type, id) ->
					ret = if type == 'chat' then new resource.User id: id else new resource.Group id: id
					ret.$fetch()
				me: (resource) ->
					resource.User.me()
				collection: (type, chat, resource) ->
					ret = new resource.Msgs()
					ret.$fetch params: {type: type, to: chat.jid, sort: 'createdAt DESC'}

			onExit: (resource, chat) ->
				# clear roster newmsg counter
				item = _.findWhere resource.Roster.instance().models, jid: chat.jid
				item?.$save(newmsg: 0)

				# no more listen to those registered events
				io.socket?.removeAllListeners 'msg'

	.controller 'ChatCtrl', ($scope, $cordovaClipboard, $log, $ionicScrollDelegate, $location, type, chat, me, collection, resource, $cordovaFileTransfer, $http, audioService, $ionicTabsDelegate) ->
		_.extend $scope,
			type: type
			chat: chat
			me: me
			collection: collection
			msg: ''
			loadMore: ->
				collection.$fetch params: {type: type, to: chat.jid, sort: 'createdAt DESC'}
					.then ->
						$scope.$broadcast('scroll.infiniteScrollComplete')
				return @
			# to control no of rows required for the input textarea
			row: (msg) ->
				$scope.msg = msg
				rows = if msg == '' then 1 else Math.min(3, msg.split('\n').length)
				$('textarea').attr('rows', rows).css('overflow-y', if rows == 1 then 'hidden' else 'scroll')
				return false
			send: ->
				if $scope.msg != ''
					msg = new resource.Msg type: type, to: chat.jid, body: $scope.msg
					msg.$save()
					$scope.msg = ''
					$scope.row('')
			cancel: ->
				$scope.collection.models.pop()
				$scope.show_dialog = false 
			addMsg: (type, index) ->
				$ionicTabsDelegate.select index
				$scope.show_dialog = true 
				$scope.collection.models.push new resource.Msg compose:true, from: me.jid
			putfile: ($files) ->
				if $files and $files.length != 0
					attachment = new resource.Attachment type: type, to: chat.jid, local: $files[0]
					if $files[0] instanceof MediaFile
						opts =
							fileName: $files[0].name
							mimeType: 'audio/wav'
							params: 
								to: attachment.to
								type: attachment.type
							headers: $http.defaults.headers.common
						$cordovaFileTransfer.upload attachment.$urlRoot(), $files[0].localURL, opts,
					else
						attachment.$save()
			copy: (msg) ->
				if env.isNative()
					$cordovaClipboard.copy(msg.body)
						.then ->
							$log.info 'Message copied'
						.catch $log.error

		# reload collection once reconnected
		io.socket?.on 'connect', (event) ->
			if $location.url().indexOf('/chat') != -1
				$scope.collection.$refetch params: {type: type, to: chat.jid, sort: 'createdAt DESC'}

		# listen if msg is created on server
		isValid = (msg) ->
			if type == 'chat'
				return (msg.from == chat.jid and msg.to == me.jid) or (msg.to == chat.jid and msg.from == me.jid)
			else
				return msg.to == chat.jid
		io.socket?.on "msg", (event) ->
			if event.verb == 'created' and isValid(event.data)
				collection.add new resource.Msg event.data
				$scope.$apply 'collection.models'
				$ionicScrollDelegate.scrollTop true

		recorded = ->
			$scope.putfile [audioService.recorder.file]
		audioService.recorder.on 'stop', recorded
		$scope.$on '$destroy', ->
			audioService.recorder.removeListener 'stop', recorded

	.controller 'msgCtrl', ($scope, resource, $cordovaFileOpener2, $http, fileService, $log) ->
		fs = fileService.fs

		msg = $scope.model

		if msg.file
			dest = msg.file.org
			switch true
				when sails.services.file.isImg(msg.file_inode) or sails.services.file.isVideo(msg.file_inode)
					thumb = new resource.Thumb _.pick msg, 'id', 'file'
					thumb.$fetch()
						.then ->
							$scope.$apply()
						.catch $log.error
				when sails.services.file.isAudio msg.file_inode
					audio = new resource.Attachment _.pick msg, 'id', 'file'
					audio.$fetch()
						.then ->
							$scope.$apply()
						.catch $log.error

		_.extend $scope,
			getfile: ->
				file = new resource.Attachment _.pick msg, 'id', 'file'
				switch device.platform
					when 'browser'
						file
							.$saveAs()
					else
						transfer = new fileService.Progress msg.file.base
						file
							.$fetch progress: transfer.progress
							.then ->
								transfer.end()
								$cordovaFileOpener2.open file.file.local, sails.services.file.type(msg.file_inode)
							.catch (err) ->
								transfer.end()
								$log.error err

	.controller 'AudioCtrl', ($scope, $cordovaDevice, $cordovaCapture, $log) ->
		$scope.start = ->
			$cordovaCapture.captureAudio()
				.then (files) ->
					$scope.putfile files
				# ignore caputre error and show as debug only
				.catch $log.debug 

	.filter 'msgFilter', ->
		(msgs, search) ->
			if search
				return _.filter msgs, (msg) ->
					r = new RegExp RegExp.quote(search), 'i'
					r.test(msg.body) or r.test(msg.file?.base)
			else
				return msgs
