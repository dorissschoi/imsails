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
			url: "/list"
			views:
				userContent:
					templateUrl: 'templates/user/list.html'
					controller: 'UsersCtrl'
			resolve:
				resource: 'resource'
				collection: (resource) ->
					resource.Users.instance().$fetch reset: true
				
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
			url: "/:jid"
			views:
				userContent:
					templateUrl: 'templates/user/read.html'
					controller: 'UserDetailCtrl'
			resolve:
				resource: 'resource'
				jid: ($stateParams) ->
					$stateParams.jid
				collection: (resource) ->
					resource.Users.instance()
				model: (jid, collection) ->
					_.findWhere collection.models, jid: jid
		
	detail: ($scope, model) ->
		$scope.model = model
	
	item: ($scope, pageableAR, resource) ->
		_.extend $scope,
			addRoster: ->
				item = new resource.RosterItem
					type: 'chat'
					user: $scope.model
				item.$save()
	
		# listen if user status is updated
		io.socket.on "user", (event) ->
			if event.verb == 'updated' and event.id == $scope.model.id
				_.extend $scope.model, event.data
				$scope.$apply 'model'
		
	list: ($scope, pageableAR, collection) ->
		_.extend $scope,
			searchText:		''
			collection:		collection
			loadMore: ->
				collection.$fetch()
					.then ->
						$scope.$broadcast('scroll.infiniteScrollComplete')
					.catch alert
				return @
				
	select: ($scope, resource) ->
		convert = (collection, selected) ->
			_.map collection, (item) ->
				label:		item.fullname
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
					.catch alert
				return @
		
		$scope.collection.$fetch()
		
		$scope.$watchCollection 'collection', ->
			$scope.model = convert($scope.collection.models, $scope.selected)
			
	update: ($scope, $state, resource, model) ->
		_.extend $scope,
			resource: resource
			model: model
			save: ->
				model.$save().then ->
					$state.go 'app.user.list'
			select: (files) ->
				if files.length != 0
					lib.readFile(files)
						.then (inImg) ->
							$scope.$emit 'cropImg', inImg 
						.catch alert
				
		$scope.$on 'cropImg.completed', (event, outImg) ->
			$scope.model.photoUrl = outImg
	
filter =
	select: ->
		(collection) ->
			_.map collection, (item) ->
				ret = {}
				ret[item.fullname] = item.id
				ret['selected'] = false
				return ret 
			
	search: ->
		(collection, search) ->
			if search
				return _.filter collection, (item) ->
					item.fullname.indexOf(search) > -1 or item.post.indexOf(search) > -1
			else
				return collection
		
module.exports = (angularModule) ->
	angularModule
		.config ['$stateProvider', domain.state]
		.controller 'UserDetailCtrl', ['$scope', 'model', domain.detail]
		.controller 'UserCtrl', ['$scope', 'pageableAR', 'resource', domain.item]
		.controller 'UsersCtrl', ['$scope', 'pageableAR', 'collection', domain.list]
		.controller 'UserUpdateCtrl', ['$scope', '$state', 'resource', 'model', domain.update]
		.controller 'UserSelectCtrl', ['$scope', 'resource', domain.select]
		.filter 'UserSelectFilter', filter.select
		.filter 'UserSearchFilter', filter.search