lib = require './lib.coffee'

domain =
	state: ($stateProvider) ->
		$stateProvider.state 'app.roster',
			url: "/roster"
			abstract: true
			views:
				menuContent:
					templateUrl: "templates/roster/index.html"
		
		$stateProvider.state 'app.roster.list',
			url: "/list"
			views:
				rosterContent:
					templateUrl: 'templates/roster/list.html'
					controller: 'RosterCtrl'
			resolve:
				resource: 'resource'
				collection: (resource) ->
					ret = resource.Roster.instance()
					ret.$fetch reset: true
		
	item: ($rootScope, $scope, resource) ->
		_.extend $scope,
			edit: ->
				return
			remove: ->
				$scope.collection.remove $scope.model
		
		# listen if user status is updated
		io.socket.on "user", (event) ->
			if event.verb == 'updated' and event.id == $scope.model.user?.id
				_.extend $scope.model.user, event.data
				$scope.$apply 'model'
						
	list: ($scope, collection) ->
		_.extend $scope,
			searchText:		''
			collection:		collection
			loadMore: ->
				collection.$fetch()
					.then ->
						$scope.$broadcast('scroll.infiniteScrollComplete')
					.catch alert
				return @

filter =		
	list: ->
		(roster, search) ->
			if search
				return _.filter roster, (item) ->
					item.user?.jid.indexOf(search) > -1 or
					item.user?.fullname.indexOf(search) > -1 or
					item.group?.jid.indexOf(search) > -1 or
					item.group?.name.indexOf(search) > -1
			else
				return roster
		
module.exports = (angularModule) ->
	angularModule
		.config ['$stateProvider', domain.state]
		.controller 'RosterItemCtrl', ['$rootScope', '$scope', 'resource', domain.item]
		.controller 'RosterCtrl', ['$scope', 'collection', domain.list]
		.filter 'rosterFilter', filter.list