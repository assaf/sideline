# Sideline, a CoffeeScript shell for your server

Use Sideline in development to troubleshoot bugs, munge data, live-edit
functions, test code snippets.

Connect Sideline over SSH to troubleshoot production instance.

Run Sideline in standalone mode and use model objects to mess with the
database.

Sideline talks CoffeeScript.


## Add a shell to your Web server

With Express you could:

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

Things you will always find in the global scope:

    console
    global
    process
    module
    setTimeout/clearTimeout
    setInterval/clearInterval
    sideline
    require
    _

The `_` property hold the result of the last statement.

Use `sideline.with()` to add more properties to the global scope.


## Edit code snippets with the scratchpad

The `.edit` command opens a text editor, and runs the code when you’re
done:

    $ sideline
    > .show

    > .edit
    1
    > .show
    c = "foo:bar:baz"
    c.split().length

Use `.show` to see the contents of the scratchpad.

You can also use `.edit` and `.show` to edit functions:

    $ sideline
    > .show foo.bar
    foo.bar = ->
      "before"
    > .edit foo.bar
    > foo.bar()
    'after'
    > .show foo.bar
    foo.bar = ->
      "after"

Sideline uses the editor from the `SIDELINE_EDITOR` or `EDITOR`
environment variable.

For example, for Vim you would want to use: `vim --nofork -c "set
syntax=coffee"`.

See more commands by typing `.help`.


## Add an application shell

You can run Sideline as standalone shell by connecting to itself:

    #!/usr/bin/env coffee
    app = require("config/app")
    Sideline = require("sideline")
    Sideline.with(app: app).connect()

Sideline defaults to port 1973, but when used in this way will upgrade
to port 1974.


## Teleporting into production

Use your SSH access to tunnel into production instance:

    $ ssh -f -L 1973:localhost:1973 -N awesome.do.ma.in
    $ sideline
    >


## License

Sideline is copyright of [Assaf Arkin](http://labnotes.org), released
under the MIT License

