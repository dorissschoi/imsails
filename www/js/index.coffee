env = require './env.coffee'

window.Promise = require 'promise'
window._ = require 'lodash'
window.$ = require 'jquery'
window.$.deparam = require 'jquery-deparam'
window.saveAs = require('file-saver.js').saveAs

require 'angular'
require 'ngCordova'
require 'ng-cordova-oauth'
require 'AngularJS-Toaster'
require 'ionic-press-again-to-exit'
require 'angular-activerecord'
require 'angular-translate'
require 'angular-translate-loader-static-files'
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
require './locale.coffee'
require './file.coffee'