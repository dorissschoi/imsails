env = require '../env.coffee'
_ = require 'lodash'
util = require 'util'

service = 
	error: ($ionicPopup, $timeout, $log) ->
		alert: (err) ->
			$log.debug util.inspect(err)
			popup = $ionicPopup.alert template: util.inspect(err)
			popup.then ->
				return
			$timeout popup.close, 3000
			
		formErr: (form, err) ->
			_.each err.data.fields, (value, key) ->
				_.extend form[key].$error, server: err.data.fields[key]
			
ctrl = 
	state: ($stateProvider) ->
		$stateProvider.state 'app',
			url: ""
			abstract: true
			templateUrl: "templates/menu.html"
	
	menu: ($scope, resource) ->
		_.extend $scope,
			env: env
			resource: resource
			model: resource.User.me()
			
		resource.User.me().promise.then ->		
			$scope.$watch 'model.status', (newvalue, oldvalue) ->
				if newvalue != oldvalue
					data = new resource.User id: $scope.model.id
					data.$save(status: $scope.model.status).catch alert
	
module.exports = (angularModule) ->
	angularModule
		.factory 'ErrorService', ['$ionicPopup', '$timeout', '$log', service.error]
		.config ['$stateProvider', ctrl.state]
		.controller 'MenuCtrl', ['$scope', 'resource', ctrl.menu]
		.run (ErrorService) ->
			window.alert = ErrorService.alert