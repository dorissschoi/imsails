lib = require './lib.coffee'

domain =
	state: ($stateProvider) ->
		$stateProvider.state 'app.user',
			url: "/user"
			abstract: true
			views:
				menuContent:
					templateUrl: "templates/user/index.html"
			
		$stateProvider.state 'app.user.list',
			cache:	false
			url: 	"/list"
			views:
				userContent:
					templateUrl: 'templates/user/list.html'
					controller: 'UsersCtrl'
			resolve:
				resource: 'resource'
				collection: (resource) ->
					resource.Users.instance().$fetch reset: true
			onExit: ->
				# no more listen to those registered events
				_.each ['connect', 'user'], (event) ->
					io.socket?.removeAllListeners event
				
		$stateProvider.state 'app.user.update',
			url: '/update'
			views:
				userContent:
					templateUrl: 'templates/user/update.html'
					controller: 'UserUpdateCtrl'
			resolve:
				resource: 'resource'
				model: (resource) ->
					resource.User.me().$fetch()
		
		$stateProvider.state 'app.user.read',
			cache: false
			url: "/:id"
			views:
				userContent:
					templateUrl: 'templates/user/read.html'
					controller: 'UserDetailCtrl'
			resolve:
				resource: 'resource'
				id: ($stateParams) ->
					$stateParams.id
				model: (id, resource) ->
					ret = new resource.User id: id
					ret.$fetch()
		
	detail: ($scope, model) ->
		$scope.model = model
	
	item: ($rootScope, $scope, pageableAR, resource) ->
		_.extend $scope,
			addRoster: ->
				item = new resource.RosterItem
					type: 'chat'
					user: $scope.model
				item.$save()
			select: ->
				$rootScope.$broadcast 'user:select', $scope.model		
		
		# listen if user status is updated
		io.socket?.on "user", (event) ->
			if event.verb == 'updated' and event.id == $scope.model.id
				_.extend $scope.model, new resource.User event.data
				$scope.$apply 'model'
		
	list: ($scope, $location, pageableAR, resource, collection) ->
		_.extend $scope,
			searchText:		''
			resource:		resource
			collection:		collection
			fullname: (user) ->
				user.fullname()
			loadMore: ->
				collection.$fetch()
					.then ->
						$scope.$broadcast('scroll.infiniteScrollComplete')
				return @
				
		# reload collection once reconnected
		io.socket?.on 'connect', (event) ->
			if $location.url().indexOf('/user/list') != -1
				$scope.collection.$refetch()
				
	select: ($scope, resource) ->
		convert = (collection, selected) ->
			_.map collection, (item) ->
				label:		item.fullname()
				value:		item.id
				selected:	not _.isUndefined _.findWhere selected, id: item.id
		
		_.extend $scope,
			searchText:		''
			collection: resource.Users.instance()
			model:		convert(resource.Users.instance().models, $scope.selected)
			loadMore: ->
				collection.$fetch()
					.then ->
						$scope.$broadcast('scroll.infiniteScrollComplete')
				return @
		
		$scope.collection.$fetch()
		
		$scope.$watchCollection 'collection', ->
			$scope.model = convert($scope.collection.models, $scope.selected)
			
	update: ($scope, $state, resource, model) ->
		_.extend $scope,
			resource: resource
			model: model
			save: ->
				if model.photoUrl?.match(/^data:(.+);base64,(.*)$/)
					model.photo = model.photoUrl
				model.$save().then ->
					$state.go 'app.user.list'
			select: (files) ->
				if files?.length != 0
					lib.readFile(files)
						.then (inImg) ->
							$scope.$emit 'cropImg', inImg 
				
		$scope.$on 'cropImg.completed', (event, outImg) ->
			$scope.model.photoUrl = outImg
	
filter =
	select: ->
		(collection) ->
			_.map collection, (item) ->
				ret = {}
				ret[item.fullname()] = item.id
				ret['selected'] = false
				return ret 
			
	search: ->
		(collection, search) ->
			if search
				return _.filter collection, (item) ->
					r = new RegExp RegExp.quote(search), 'i'
					r.test(item.fullname()) or r.test(item.post())
			else
				return collection
		
module.exports = (angularModule) ->
	angularModule
		.config ['$stateProvider', domain.state]
		.controller 'UserDetailCtrl', ['$scope', 'model', domain.detail]
		.controller 'UserCtrl', ['$rootScope', '$scope', 'pageableAR', 'resource', domain.item]
		.controller 'UsersCtrl', ['$scope', '$location', 'pageableAR', 'resource', 'collection', domain.list]
		.controller 'UserUpdateCtrl', ['$scope', '$state', 'resource', 'model', domain.update]
		.controller 'UserSelectCtrl', ['$scope', 'resource', domain.select]
		.filter 'UserSelectFilter', filter.select
		.filter 'UserSearchFilter', filter.search
		
		.filter 'excludeMe', (resource) ->
			(collection) ->
				_.filter collection, (user) ->
					user.id != resource.User.me().id
			
		.run ($rootScope, $ionicActionSheet, $translate, $location, $ionicHistory, resource) ->
			$rootScope.$on 'user:select', (event, user, roster = null) ->
				$translate ['Info', 'Delete', 'Cancel']
					.then (translations) -> 
						info =
							type:	'button'
							text:	translations['Info']
							show:	true
							cb:		->
								$location.path("/user/#{user.id}")
						del =
							type:	'destructive'
							text:	translations['Delete']
							show:	roster?
							cb:		->
								resource.Roster.instance().remove roster
								close()
						cancel =
							type:	'cancel'
							text:	translations['Cancel']
							show:	true
						close = $ionicActionSheet.showAction
							action: [info, del, cancel] 
