# Changelog

### Version 1.2.0  2011-09-06

Added `.expand` command that lists all the properties of an object
including the chain of prototype.

Try this:

    $ sideline --self
    > .expand require("./lib/sideline")


You can now run Sideline in standalone mode using `--self` command line
option.

Please don't use `sideline.with` (reserved word), use `sideline.using`
instead.

Fixed Sideline not showing which port it's listening on.


### Version 1.1.0  2011-09-02

Added persistent history, stored in `~/.sideline_hist`.


### Version 1.0.2  2011-09-01

Switched default port to 1973. Just because.


### Version 1.0.1  2011-09-01

Fix to work around typo in js2coffee's package.json.


### Version 1.0.0  2011-08-31

First release.  Woot!

