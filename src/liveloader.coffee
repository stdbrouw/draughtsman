###
We're going to combine the raw nowjs/dist/now.js file with our liveloading code.

window.now = nowInitialize "//localhost:#{port}", {}
###

###
###
###
###

fs = require 'fs'
fs.path = require 'path'
http = require 'http'
watch = require 'watch'

NOW =
    lib: fs.readFileSync (fs.path.join __dirname, '../node_modules/now/dist/now.js'), 'utf8'
    socketio:
        # web sockets can be unpredictably slow during page load, 
        # so we're using more old school methods
        transports: ['xhr-polling', 'jsonp-polling']

exports.enable = (app, root) ->
    app.get '/vendor/draughtsman/latest/live.js', (req, res) ->
        port = 3500
        res.type 'text/javascript'
        res.send """
            #{NOW.lib}
            window.now = nowInitialize("//localhost:#{port}", {})
            now.reload = function(){window.location.reload(true);}
            now.ready(function(){
                now.watch(window.location.pathname);
            });
            """

    app.live = (port) ->
        server = http.createServer app
        everyone = (require "now").initialize server, {socketio: NOW.socketio}
    
        # there are a considerable number of edge cases in which it is impossible
        # to know when we need to reload a file, e.g. whenever there's an 
        # @import statement in a LESS file (which is invisible in the compiled
        # CSS) so our reloader has to be a bit paranoid: if *any* file in 
        # what we assume to be the project directory changes, then we'll reload
        everyone.now.watch = (dir) ->
            dir = fs.path.dirname fs.path.join root, dir
            watch.watchTree dir, {persistent: yes, interval: 250}, (f, curr, prev) ->
                if curr and everyone.now.reload
                    everyone.now.reload()
            console.log "Watching #{dir} for changes and will live reload pages as needed."

        server.listen port