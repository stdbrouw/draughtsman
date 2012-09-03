fs = require 'fs'
fs.path = require 'path'
http = require 'http'
url = require 'url'
mime = require 'mime'
express = require 'express'
http_proxy = require 'http-proxy'
_ = require 'underscore'
handlers = exports.handlers = require 'tilt'
stockpile = require 'stockpile'
espy = require 'espy'
http = require 'http'
middleware = require './middleware'
listing = require './listing'
liveloader = require './liveloader'

fs.path.here = (parts...) -> fs.path.join __dirname, parts...

# App

exports.VERSION = (JSON.parse fs.readFileSync 'package.json', 'utf8').version

app = express()
# allow reverse proxies
app.set 'trust proxy', yes
#proxy = new http_proxy.RoutingProxy()

ROOT = process.argv[2]

class Resolver
    constructor: (@root) ->
        @aliases = []

    alias: (from, to) ->
        @aliases.push {from, to}

    resolve: (path) ->
        alias = _.find @aliases, (map) ->
            (path.indexOf map.from) is 0

        if alias
            path.replace alias.from, alias.to
        else
            fs.path.join @root, path

resolver = new Resolver ROOT
resolver.alias '/vendor/draughtsman/latest', fs.path.here 'client'
resolver.alias '/vendor/bootstrap/2.1.0', fs.path.here 'vendor/bootstrap/2.1.0'



# only look for /vendor libraries remotely or in the 
# stockpile cache if we don't have them locally
conditionalCache = (req) ->
    req.file or (req.path.indexOf '/vendor/draughtsman') is 0

app.use middleware.loader resolver
app.use '/vendor', middleware.fallback conditionalCache, stockpile.middleware.libs('')
app.use middleware.contextFinder()
app.use middleware.debugger fs.path.here 'views/debug.jade'
liveloader.enable app, ROOT
app.use middleware.fileServer()

###
(req, res) ->
    destination = url.parse 'relay_server'
    proxy.proxyRequest req, res, {host: destination.hostname, port: destination.port}
###

app.get '*', (req, res, next) ->
    return next() unless req.handler

    res.type req.handler.mime.output
    if req.handler.mime.output is 'text/html'
        req.handler.compiler req.file, req.context, (output) ->
            res.send output
    else
        req.handler.compiler req.file, null, (output) ->
            res.send output

# directory listing
#app.get /^(.*)\/$/, listing.controller

exports.listen = (port) ->
    app.live port

    console.log "Draughtsman proxy v#{exports.VERSION} listening on port #{port}, server on #{port+1}"
    if relay_server?
        console.log "Relaying handling for unknown file types to #{relay_server}"