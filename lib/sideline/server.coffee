Net = require("net")
CoffeeScript = require("coffee-script")
JS2Coffee = require("js2coffee")
Eyes = require("eyes")
Script = require("vm").Script
Sideline = require("../sideline")
EventEmitter = require("events").EventEmitter
exec = require("child_process").exec
Client = require("./client").Client


PADDING = "                                        " # 40
ROOTS = [Object, String, Array, Function, Date, Number, Boolean]

# Expanded information about an object.
expand = (object)->
  # Indent all lines by 2 spaces.
  indent = (text)-> text.split("\n").map((line)-> "  #{line}").join("\n")
  # Truncate text to length characters.
  truncate = (text, length = 250)-> if text.length > length then text.slice(0, length - 4) + " ..." else text
  # Show function definition: requires name, Function and optional
  # prefix (for getter/setter).
  func = (name, func, prefix)->
    try
      # Functions without a prototype are native, as is the Object
      # constructor
      body = if func.prototype && func.name != "Object"
        truncate(JS2Coffee.build("#{name} = #{func.toString()}"))
      else
        "[NATIVE]"
    catch ex
      "#{ex}"
    body = "#{prefix} #{body}" if prefix
    lines = body.split("\n")
    lines[0] = Eyes.stylize(lines[0], "yellow", all: null)
    indent(lines.join("\n"))

  items = []
  # Enumerate all properties and expand information about each one:
  #   name (writeable, configurable, enumerable)
  #   getter function definition if exists
  #   setter function definition if exists
  #   function definition if a function
  for name in Object.getOwnPropertyNames(object).sort()
    padded = Eyes.stylize((name + PADDING).slice(0, PADDING.length), "blue", all: null)
    desc = Object.getOwnPropertyDescriptor(object, name)
    attrs = []
    attrs.push "write" if desc.writable
    attrs.push "enum" if desc.enumerable
    attrs.push "config" if desc.configurable
    joined = Eyes.stylize("(#{attrs.join(", ")})", "grey", all: null) if attrs.length > 0
    items.push "#{padded} #{joined || ""}"
    items.push func(name, desc.get, 1, "get") if desc.get
    items.push func(name, desc.set, 1, "set") if desc.set
    items.push func(name, desc.value, 1) if typeof desc.value == "function"
  # Add from prototype, but skip Object, we've all seen that.
  if parent = Object.getPrototypeOf(object)
    for root in ROOTS
      if object instanceof root || parent instanceof root
        items.push indent(Eyes.stylize("- #{root.name}", "bold", all: null))
        parent = null
        break
    if parent
      items.push indent(Eyes.stylize("+ #{parent.constructor.name}", "bold", all: null))
      items.push indent(expand(parent))
  items.join("\n")


# Sideline Server.
class Server extends EventEmitter
  constructor: ->
    # Keep list of connected clients so we can broadcast messages to all of them.
    @clients = []

    # Establish context for executing statements.
    @context = Script.createContext()
    GLOBALS = ["process", "setInterval", "clearInterval", "setTimeout", "clearTimeout"]
    for n in GLOBALS
      @context[n] = global[n]
    @context.GLOBAL = @context.global = @context
    @context.sideline = Sideline
    @context.console =
      log:  Sideline.send
      debug: Sideline.debug


    # Server initiated events

    # Send message to all specified clients.  Message is either
    # `<directive>\n` or `<directive><length>\n<data>\n`.
    send = (clients, directive, value)=>
      message = if arguments.length == 2 then "#{directive}\n" else "#{directive}#{value.length}\n#{value}\n"
      clients = [clients] unless clients instanceof Array
      for client in clients
        try
          client.write message
        catch ex

    # The `render` event sends a message for the client to display.
    this.on "render", (clients, value)->
      send clients, "=", value

    # The `ok` event tells the client command was accepted but there's
    # no output.
    this.on "ok", (clients)->
      send clients, "."

    # The `edit` event tells the client to edit the piece of code
    # identified by the first path.
    this.on "edit", (clients, fn, code)->
      send clients, "#", "#{fn.length}\n#{fn}\n#{code}"

    # The `error` events takes a JS exception and sends it to the client.
    this.on "error", (clients, error)->
      send clients, "!", JSON.stringify(message: error.message, stack: error.stack)


    # Client initiated events

    # The `EXEC` event is the client asking us to evaluate an expression
    # and send back the result.
    this.on "EXEC", (client, expr)=>
      try
        _ = @context._
        if expr
          result = CoffeeScript.eval("_=(#{expr}\n)", sandbox: @context, filename: "sideline", modulename: "sideline")
          if result == undefined
            @context._ = _
          else
            this.emit "render", client, Sideline.stylize(result)
            return
        this.emit "ok", client
      catch err
        this.emit "error", client, err
    
    # The `SHOW` event is the client asking us to return the source code
    # for a function.
    this.on "SHOW", (client, expr)=>
      try
        result = CoffeeScript.eval("(#{expr}\n)", sandbox: @context, filename: "sideline", modulename: "sideline")
        if typeof result == "function"
          this.emit "render", client, JS2Coffee.build("#{expr} = #{result.toString()}")
        else
          this.emit "error", client, new Error("'#{expr}' is not a function")
      catch err
        this.emit "error", client, err

    # The `EDIT` event is the client asking us to return the source code
    # for a function for editing.
    this.on "EDIT", (client, expr)=>
      try
        result = CoffeeScript.eval("(#{expr}\n)", sandbox: @context, filename: "sideline", modulename: "sideline")
        if typeof result == "function"
          code = JS2Coffee.build("fn = #{result.toString()}").slice(5)
          this.emit "edit", client, expr, code
        else
          this.emit "error", client, new Error("'#{expr}' is not a function")
      catch err
        if err.type == "not_defined"
          this.emit "edit", client, expr, "->"
        else
          this.emit "error", client, err

    # The `DEFINE` event is the client asking us to change a function definition.
    this.on "DEFINE", (client, request)=>
      try
        [_, fn, body] = request.match(/^([\S]+)\s([\s\S]*)/)
        CoffeeScript.eval("(#{fn} = #{body}\n)", sandbox: @context, filename: "sideline", modulename: "sideline")
        this.emit "ok", client
      catch err
        this.emit "error", client, err

    # The 'EXPAND' event is the client asking us for expanded
    # information about an object's properties.
    this.on "EXPAND", (client, expr)=>
      try
        result = CoffeeScript.eval("(#{expr}\n)", sandbox: @context, filename: "sideline", modulename: "sideline")
        if result == undefined || result == null
          this.emit "error", client, new Error("'#{expr}' is not an object")
        else
          this.emit "render", client, expand(result)
      catch err
        this.emit "error", client, err

    # The `SHELL` event is the client asking us to execute a shell command.
    this.on "SHELL", (client, command)=>
      try
        exec command, (err, stdout, stderr)=>
          if err
            this.emit "error", client, message: stderr
            @context._ = err.code
          else
            this.emit "render", client, stdout.slice(0, -1)
            @context._ = 0
      catch err
        this.emit "error", client, err


  # Start the Sideline server and returns it.  Available options are
  # port and host.  Optional callback called with error/null.
  listen: (options, callback)->
    options ||= {}
    @port = options.port || Sideline.PORT
    @host = options.host || Sideline.HOST
    server = Net.createServer (client)=>
      console.log "Sideline client connected from #{client.remoteAddress}"
      # Add connection to list of clients we can broadcast to.
      @clients.push client
      client.on "end", =>
        console.log "Sideline client #{client.remoteAddress} disconnected"
        @clients = @clients.filter((c)-> c != client)
      # This is the main request processing loop, one per client.  We
      # expect request to look like:
      #   <length>\n<command> <arguments>\n
      input = ""
      expecting = -1
      client.on "data", (chunk)=>
        input += chunk
        while input.length > 0
          if expecting < 0 && match = input.match(/^(\d+)\n/)
            input = input.slice(match[0].length)
            expecting = parseInt(match[1], 10)
          else if expecting >= 0 && input.length >= expecting + 1
            command = input.slice(0, expecting)
            input = input.slice(expecting + 1)
            expecting = -1
            [_, command, args] = command.match(/^(\w+)\s?([\s\S]*)/)
            this.emit command, client, args
          else break
    # Start listening on specified port/host.
    server.listen @port, @host, (err)=>
      callback err if callback
      if err
        console.error err.message
      else
        console.log "Sideline listening on port #{@port}"
    return this

  # Adds key/value pairs from the Object to the Sideline context and
  # returns this.
  using: (object)->
    for key, value of object
      @context[key] = value
    return this

  # Sends arguments to all connected clients to display.
  send: ->
    lines = []
    for arg in arguments
      lines.push arg.toString()
    this.emit "render", @clients, lines.join("\n")

  # Sends formatted arguments to all clients to display.
  debug: ->
    lines = []
    for arg in arguments
      lines.push Sideline.stylize(arg)
    this.emit "render", @clients, lines.join("\n")

  # Connect Sideline client to this server.  Used for executing
  # client/server in same process.  If not listening, starts server on
  # port `PORT + 1`.
  connect: ->
    if @port
      new Client().connect(port: @port)
    else
      this.listen(port: Sideline.PORT + 1).connect()


exports.Server = Server
