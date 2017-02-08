argv = require('yargs').argv
gulp = require 'gulp'
bower = require 'bower'
sass = require 'gulp-sass'
less = require 'gulp-less'
concat = require 'gulp-concat'
merge = require 'streamqueue'
minifyCss = require 'gulp-minify-css'
rename = require 'gulp-rename'
sh = require 'shelljs'
browserify = require 'browserify'
streamify = require 'gulp-streamify'
bower = require 'gulp-bower'
source = require 'vinyl-source-stream'
rework = require 'gulp-rework'
imprt = require 'rework-import'
reworkNPM = require 'rework-npm'
reworkBower = require 'rework-bower'
vars = require 'rework-vars'
calc = require 'rework-calc'
cleanCSS = require 'gulp-clean-css'
uglify = require 'gulp-uglify'
templateCache = require 'gulp-angular-templatecache'
whitespace = require 'gulp-css-whitespace'
del = require 'del'
_ = require 'lodash'
fs = require 'fs'
util = require 'util'
modernizr = require 'modernizr'
stream = require 'stream'

config = (params) ->
  _.defaults params,
    _.pick(process.env, 'ROOTURL', 'AUTHURL', 'MOBILEURL', 'SENDER_ID', 'CLIENT_ID', 'OAUTH2_SCOPE')
  fs.writeFileSync 'www/js/config.json', util.inspect(params)

class StringStream extends stream.Readable
  constructor: (@str) ->
    super()

  _read: (size) ->
    @push @str
    @push null

gulp.task 'default', ['browser', 'android', 'ios']

gulp.task 'modernizr', ->
  modernizr.build 'feature-detects': ['webrtc/getusermedia'], (test) ->
    new StringStream test
      .pipe source 'detect.js'
      .pipe gulp.dest 'www/js/'

gulp.task 'css', (done) ->
  [lessAll, scssAll, cssAll] = [
    gulp.src ['./scss/bootstrap.less']
      .pipe less()
      .pipe concat 'less-files.less'
    gulp.src ['./scss/ionic.app.scss']
      .pipe sass()
      .pipe concat 'scss-files.scss'
    gulp.src 'www/css/index.css'
      .pipe whitespace()
      .pipe rework reworkNPM(shim: 'angular-toastr': 'dist/angular-toastr.css'), reworkBower(), imprt(path: 'www/css'), vars(), calc
      .pipe concat 'css-files.css'
  ]
  merge objectMode: true, lessAll, cssAll, scssAll
    .pipe concat 'ionic.app.css'
    .pipe gulp.dest 'www/css/'
    .pipe cleanCSS()
    .pipe rename extname: '.min.css'
    .pipe gulp.dest 'www/css/'

gulp.task 'coffee', ['template', 'modernizr'],  ->
  browserify(entries: ['./www/js/index.coffee'])
    .transform 'coffeeify'
    .transform 'debowerify'
    .bundle()
    .pipe source 'index.js'
    .pipe gulp.dest './www/js/'
    .pipe streamify uglify()
    .pipe rename extname: '.min.js'
    .pipe gulp.dest './www/js/'

gulp.task 'template', ->
  gulp.src('./www/templates/**/*.html')
    .pipe(templateCache(root: 'templates', standalone: true))
    .pipe(gulp.dest('./www/js/'))

gulp.task 'pre-ios', ->
  config CLIENT_ID: process.env.NATIVE_CLIENT_ID
  sh.exec "cordova platform rm ios"
  sh.exec "cordova platform add ios"
  sh.exec "ionic resources ios"

gulp.task 'ios', ['pre-ios', 'plugin', 'css', 'coffee'], ->
  sh.exec "cordova build ios --device"

gulp.task 'pre-android', ->
  config CLIENT_ID: process.env.NATIVE_CLIENT_ID
  sh.exec "cordova platform rm android"
  sh.exec "cordova platform add android"
  sh.exec "ionic resources android"

gulp.task 'android', ['pre-android', 'plugin', 'css', 'coffee'], ->
  sh.exec "cordova build android"

gulp.task 'pre-browser', ->
  config CLIENT_ID: process.env.WEB_CLIENT_ID
  sh.exec "cordova platform rm browser"
  sh.exec "cordova platform add browser"
  sh.exec "ionic resources browser"

gulp.task 'browser', ['pre-browser', 'plugin', 'css', 'coffee'], ->
  sh.exec "cordova build browser"

gulp.task 'plugin', ->
  for plugin in require('./package.json').cordovaPlugins
    sh.exec "cordova plugin add #{plugin}"
  sh.exec "cordova plugin add phonegap-plugin-push --variable SENDER_ID='#{process.env.SENDER_ID}'"

gulp.task 'clean', ->
  sh.exec "cordova platform rm browser"
  sh.exec "cordova platform rm android"
  del [
    'node_modules'
    'www/lib'
    'resources/browser'
    'resources/android'
    'plugins'
  ]

gulp.task 'verify', ->
  sh.exec "jarsigner -keystore /home/twhtang/.android/release.keystore -verify -certs -sigalg SHA1withRSA -digestalg SHA1 -verbose platforms/android/build/outputs/apk/android-armv7-debug.apk"
