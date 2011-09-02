#!/usr/bin/env coffee
Readline = require("readline")
Net = require("net")
Eyes = require("eyes")
EventEmitter = require("events").EventEmitter
FS = require("fs")
Path = require("path")
spawn = require("child_process").spawn
Sideline = require("../sideline")

stdin = process.stdin
stdout = process.stdout
stderr = process.stderr


class Client extends EventEmitter
  constructor: ->
    # Socket we use for client connect.
    @socket = new Net.Socket()

    # REPL

    if Readline.createInterface.length < 3
      @repl = Readline.createInterface(stdin)
      stdin.on "data", @repl.write.bind(@repl)
    else
      @repl = Readline.createInterface(stdin, stdout)
    history_fn = Path.resolve(process.env.HOME, ".sideline_hist")
    FS.readFile history_fn, "utf8", (err, history)=>
      if history
        @repl.history = history.split("\n")
    @repl.setPrompt "> "
    @repl.on "attemptClose", @repl.close.bind(@repl)
    @repl.on "close", =>
      history = @repl.history.slice(0, 100)
      history.shift() if /^\.exit/.test(history[0])
      FS.writeFile history_fn, history.join("\n"), (err)->
        process.stdout.write "\n"
        stdin.destroy()
        process.exit 0

    @repl.on "line", (line)=>
      [_, command, args] = line.match(/^(\.\w+)?\s*(.*)$/)
      if command
        command = command.slice(1)
        if @commands[command]
          this[command] args
        else
          stdout.write "Unrecognized command #{command}, try .help\n"
          @prompt()
      else
        @send "EXEC #{args}"

    # Show prompt on first successful connect.  Reconnect attempts show something else.
    @socket.once "connect", =>
      @prompt()

    @editor = process.env["SIDELINE_EDITOR"] || process.env["EDITOR"] || "vim --nofork -c \"set syntax=coffee\""

    # Commands and scratch area.

    @scratch = ""

    # Responses and messages

    # This is the main message processing loop.  A server message is one of:
    #   .\n
    #   =<length>\n<message>\n
    #   !<length>\n<error>\n
    #   #<length>\n<fn> <code>\n
    input = ""
    expecting = -1
    directive = ""
    @socket.on "data", (chunk)=>
      input += chunk
      while input.length > 0
        if expecting < 0 && match = input.match(/^(.)(\d*)\n/)
          input = input.slice(match[0].length)
          directive = match[1]
          if directive == "."
            this.emit directive
          else
            expecting = parseInt(match[2], 10)
        else if expecting >= 0 && input.length >= expecting + 1
          this.emit directive, input.slice(0, expecting)
          input = input.slice(expecting + 1)
          expecting = -1
        else break

    # Server sent OK with no data.
    this.on ".", =>
      @prompt()
    # Server sent us a message to render.
    this.on "=", (message)=>
      stdout.write "#{message}\n"
      @prompt()
    # Server sent us an error, consisting of message and stack trace.
    this.on "!", (error)->
      error = JSON.parse(error)
      stdout.write Eyes.stylize("#{error.stack || error.message}", "red", all: null)
      @prompt()
    # Server sent us a piece of code to edit.
    this.on "#", (message)=>
      [_, length, rest] = message.match(/^(\d+)\n([\s\S]*)/)
      length = parseInt(length, 10)
      fn = rest.substring(0, length)
      code = rest.substring(length + 1)
      @editCode code, (err, code)=>
        if err
          stderr.write err
        else
          @send "DEFINE #{fn} #{code}" if code
          @repl.prompt()


  # Show prompt.
  prompt: ->
    @repl.prompt()

  # Send request to the server.
  send: (request)=>
    @socket.write "#{request.length}\n#{request}\n"

  # Help for available commands.
  commands:
    show:   "Show function definition or scratch code"
    edit:   "Edit function definition or edit and execute scratch code"
    shell:  "Execute shell command"
    help:   "Show this help message"
    exit:   "Exit the console"

  # The .show command.
  show: (fn)->
    if fn
      @send "SHOW #{fn}"
    else
      stdout.write "#{@scratch}\n"
      @prompt()

  # The .edit command.
  edit: (fn)->
    if fn
      @send "EDIT #{fn}"
    else
      @editCode @scratch, (err, code)=>
        if err
          stderr.write err
          @prompt()
        else
          @scratch = code
          @send "EXEC #{code}"

  # The .shell command.
  shell: (command)->
    @send "SHELL #{command}"

  # The .help command.
  help: ->
    max = Math.max.apply(null, Object.keys(@commands).map((i)-> i.length))
    for name, desc of @commands
      padded = (name + "        ").substring(0, max)
      stdout.write ".#{padded}  #{desc}\n" 
    @prompt()

  # The .exit command.
  exit: ->
    @socket.end()
    @repl.close()

  editCode: (code, callback)->
    filename = "/tmp/console.#{process.pid}.#{new Date().getTime()}"
    stdin.pause()
    FS.writeFile filename, code, (err)=>
      if err
        stdin.resume()
        callback err
      else
        [cmd, args...] = @editor.trim().match(/(".*?"|\S+)/g).map((arg)-> arg.replace(/^"(.*)"$/, "$1"))
        editor = spawn(cmd, args.concat(filename), customFds: [0,1,2])
        editor.on "exit", (code, err)->
          if code == 0
            FS.readFile filename, (err, code)->
              stdin.resume()
              FS.unlink filename
              callback err, code
          else
            stdout.write err
            stdin.resume()

  # Connect to Sideline server.
  connect: (options)->
    options ||= {}
    @port = options.port || Sideline.PORT
    @host = options.host || Sideline.HOST
    @socket.connect @port, @host
    # Automatically connect/reconnect.
    @socket.on "error", =>
      setTimeout =>
        stdout.write "."
        @socket.connect @port, @host
      , 500
    @socket.on "end", =>
      stdout.write "\rConnection closed, reconnecting (^C to stop) "
      @socket.once "connect", =>
        stdout.write "\rReconnected\n"
        @repl.prompt()
      setTimeout =>
        stdout.write "."
        @socket.connect @port, @host
      , 500
    return



exports.Client = Client

