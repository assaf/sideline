# Sideline, a CoffeeScript shell for your server

Use Sideline in development to troubleshoot bugs, munge data, live-edit
functions, test code snippets.

Connect Sideline over SSH to troubleshoot production instance.

Run Sideline in standalone mode and use your model objects to mess with
the database.


## Connect to a Web Server

Have your Web server accept connections from Sideline clients, for example, for Express:

    Sideline = require("sideline")

    server.configure "development", ->
      Sideline.with(server: server).listen()

Connect to the running server and do stuff:

    $ sideline
    > server.settings.env
    'development'
    > server.routes.routes.post.map (r)-> r.path
    [ '/signin', '/signup', '/v1/push', '/upload' ]
    > server.settings.cache = false
    false

Things you will always find in the context:

    console
    global
    process
    module
    setTimeout/clearTimeout
    setInterval/clearInterval
    sideline
    require

And of course `_` to hold the result of the last statement.

You can also add objects to the global context by calling
`sideline.with(<object>)`.


## Scratch pad

Need to try things out that don't fit conveniently in one line?  Use the scratchpad:

    $ sideline
    > .show

    > .edit
    1
    > .show
    c = "foo:bar:baz"
    c.split().length

The `.edit` command opens a text editor and runs the code when you close
the editor.  The `.show` command shows you the contents of the
scratchpad.

You can also use `.edit` and `.show` to edit actual functions:

    $ sideline
    > f = -> "before"
    [Function]
    > .show f
    f = ->
      "before"
    > .edit f
    > f()
    'after'
    > .show f
    f = ->
      "after"

Sideline uses the editor specified in the `SIDELINE_EDITOR` or `EDITOR`
environment variable.

If you like using Vim, you may want to set the environment variable to
`vim --nofork -c "set syntax=coffee"`.

Use the `.help` command to see a list of all available commands.


## Run a standalone console

You can run Sideline as standaline console by having the server and
client running in the same process.  For example:

    #!/usr/bin/env coffee
    app = require("config/app")
    Sideline = require("sideline")
    Sideline.with(app: app).connect()


## Using Sideline in production

By default Sideline listens on port 8090 to localhost.  You can use SSH
to tunnel into a server running with Sideline, e.g.:

    $ ssh myapp.com -D 8090
    $ sideline
    >


## License

Sideline is copyright of [Assaf Arkin](http://labnotes.org), released
under the MIT License

