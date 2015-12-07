env = require './env.coffee'
require 'util.auth'
require 'util.audio'

modules = [
	'ionic'
	'starter.controller'
	'starter.model'
	'locale'
	'ngTagEditor'
	'ActiveRecord'
	'ngFileUpload'
	'ngTouch'
	'ngImgCrop'
	'ngFancySelect'
	'ngIcon'
	'templates'
	'ionic-press-again-to-exit'
	'toaster'
	'util.auth'
	'util.audio'
	'ngCordova'
]

angular.module('starter', modules)
	
	.config ($sceDelegateProvider, $compileProvider) ->
		$sceDelegateProvider.resourceUrlWhitelist ['self', 'https://mob.myvnc.com/**', 'filesystem:**']
		$compileProvider.imgSrcSanitizationWhitelist /^\s*((https?|ftp|file|blob|filesystem):|data:image\/)/
	
	.run (authService) ->
		authService.login env.oauth2().opts
	
	# default page url
	.config ($urlRouterProvider) ->
		$urlRouterProvider.otherwise('/roster/list')
		
	# ionic default settings
	.config ($ionicConfigProvider) ->
		$ionicConfigProvider.tabs.style 'standard'
		$ionicConfigProvider.tabs.position 'bottom'

	# define showAction method for ionic action sheet 
	.config ($provide) ->
		$provide.decorator '$ionicActionSheet', ($delegate) ->
			###
				opts:
					titleText:	'action title'
					action: [
						{type: 'button', text: 'button label', cb: func, show: true|false}
						...
						{type: 'destructive', text: 'Delete', cb: func, show: true|false}
						{type: 'cancel', text': 'Cancel', cb: func, show true|false}
					]
			###
			$delegate.showAction = (opts) ->
				newopts = _.extend {}, _.pick(opts, 'titleText')
				buttons = _.where(opts.action, type: 'button', show: true)
				newopts.buttons = _.map buttons, (button) ->
					_.pick button, 'text'
				newopts.buttonClicked = (index) ->
					buttons[index]?.cb()
				destructive = _.find(opts.action, type: 'destructive', show: true)
				if not _.isUndefined(destructive)
					newopts.destructiveText = destructive.text
					newopts.destructiveButtonClicked = destructive.cb
				cancel = _.find(opts.action, type: 'cancel', show: true)
				if not _.isUndefined(cancel)
					newopts.cancelText = cancel.text
					newopts.cancel = cancel.cb
				$delegate.show newopts
				
			return $delegate
					
	# press again to exit
	.run ($translate, $ionicPressAgainToExit, toaster) ->
		$ionicPressAgainToExit ->
			$translate 'Press again to exit'
				.then (text) ->
					toaster.pop
						type:			'info'
						body:			text
						bodyOutputType: 'trustedHtml'
						timeout:		2000
					
	# state change error
	.run ($rootScope) ->
		$rootScope.$on '$stateChangeError', (evt, toState, toParams, fromState, fromParams, error) ->
			window.alert error
	
	# image crop
	.run ($rootScope, $ionicModal) ->
		$rootScope.$on 'cropImg', (event, inImg) ->
			_.extend $rootScope,
				model: 
					inImg: inImg
					outImg: ''
				confirm: ->
					$rootScope.$broadcast 'cropImg.completed', $rootScope.model.outImg
					$rootScope.modal?.remove()
			$ionicModal.fromTemplateUrl 'templates/img/crop.html', scope: $rootScope
				.then (modal) ->
					modal.show()
					$rootScope.modal = modal
					
	# push notification
	.run ($cordovaDevice, $cordovaDialogs, $cordovaVibration, $log, resource) ->
		document.addEventListener 'deviceready', ->
			if $cordovaDevice.getPlatform() != 'browser'
				push = PushNotification.init
					android: 
						env.push.gcm
					ios: 
						alert: "true"
						badge: "true"
						sound: "true"
					windows: 
						{}
	         			
				push.on 'registration', (data) ->
					device = new resource.Device
						regid: 		data.registrationId
						model:		$cordovaDevice.getModel()
						version:	$cordovaDevice.getVersion()
					device.$save().catch alert
						
				push.on 'notification', (data) ->
					if data.additionalData.foreground
						$cordovaDialogs.beep(1)
						$cordovaVibration.vibrate(1000)
						location.hash = '/roster/list'
					else
						location.hash = data.additionalData.data.url
				
				push.on 'error', alert