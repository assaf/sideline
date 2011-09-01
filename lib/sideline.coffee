Client = require("./sideline/client").Client
Server = require("./sideline/server").Server
Eyes = require("eyes")


# Default port is 1973.
exports.PORT = 1973
# Default host is `localhost` so we only listen to local requests.
exports.HOST = "localhost"

# Uses Eyes to stylize the argument.
exports.stylize = Eyes.inspector(stream: null)

exports.Client = Client
exports.Server = Server


# ## Sideline client

client = null

# Returns the Sideline server.
exports.__defineGetter__ "client", ->
  return client ||= new Client

# Connect to Sideline server.  Available options are port, host and prompt.
#
# You can also start a server and connect to itself using:
#    Sideline.server.connect()
exports.connect = (options)->
  exports.client.connect options


# ## Sideline server

server = null

# Returns the Sideline server.
exports.__defineGetter__ "server", ->
  return server ||= new Server

# Returns the Sideline server context.
#
# Same as accessing `sideline.server.context`
exports.__defineGetter__ "context", ->
  return exports.server.context

# Start the Sideline server and returns it.  Available options are
# `port` and `host`.
#
# Same as calling `sideline.server.listen()`.
exports.listen = (options, callback)->
  return server.listen(options, callback)

# Adds key/value pairs from the Object to the Sideline context and
# returns the Sideline server.
#
# For example:
#   sideline.with(app: app, db: db).listen()
#
# Same as:
#   sideline.context.db = db
#   sideline.context.app = app
#   sideline.listen()
exports.with = (object)->
  return exports.server.with(object)

# Sends arguments to all connected clients to display.
#
# For example:
#   sideline.send "Created #{account.id}".
exports.send = ->
  exports.server.send.apply(exports.server, arguments)
  return

# Sends formatted arguments to all clients to display.
#
# For example:
#   sideline.inspect account
exports.debug = ->
  exports.server.debug.apply(exports.server, arguments)
  return
