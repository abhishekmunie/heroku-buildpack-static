Heroku buildpack: Static
============================

This is a [Heroku buildpack](http://devcenter.heroku.com/articles/buildpack) which serves static files using nginx.

Usage
-----

Example usage:

    $ ls -R *
    _static.yml   		       img.png                    text.txt
    ...

    $ heroku create --stack cedar --buildpack https://github.com/abhishekmunie/heroku-buildpack-static.git
    ...

    $ git push heroku master
    ...
    -----> Heroku receiving push
    -----> Fetching custom buildpack... cloning with git...done
    -----> Static app detected
    -----> Creating default nginx configuration...done
    -----> Fetching nginx binaries
    -----> Vendoring nginx 1.0.14
    -----> Discovering process types
           Procfile declares types      -> (none)
           Default types for Static -> web
    ...

The buildpack will detect your app as Static if it has the file `_static.yml` in the `root`. At present `_static.yml` doesn't support any configuration.
You can set custom nginx config as described for [heroku-buildpack-nginx](https://github.com/abhishekmunie/heroku-buildpack-nginx).

Hacking
-------

To modify this buildpack, fork it on Github. Push up changes to your fork, then
create a test app with `--buildpack <your-github-url>` and push to it.

This buildpack simply creating default nginx configuration for static site
and uses [heroku-buildpack-nginx](https://github.com/abhishekmunie/heroku-buildpack-nginx) to create nginx server.