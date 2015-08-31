env = require './env.coffee'

io.sails.url = env.server.app.urlRoot
io.sails.path = "#{env.path}/socket.io"
io.sails.useCORSRouteToGetCookie = false
	
window.Promise = require 'promise'
window._ = require 'lodash'
window.$ = require 'jquery'
window.$.deparam = require 'jquery-deparam'
if env.isNative()
	window.$.getScript 'cordova.js'
	
	# ensure all cordova plugins are loaded
	document.addEventListener 'deviceready', ->
		console.log 'ready'
		angular.bootstrap(document, ['starter'])
else
	$(document).ready ->
		angular.bootstrap(document, ['starter'])
		
require 'ngCordova'
require 'angular-activerecord'
require 'sails-auth'
require 'angular-touch'
require 'ng-file-upload'
require 'ngImgCrop'
require 'tagDirective'
require 'jq-postmessage'
require './templates.js'
require './app.coffee'
require './controllers/index.coffee'
require './model.coffee'
require './platform.coffee'