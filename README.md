### Running locally

    npm install
    coffee src/bridge.coffee

The bridge will connect by default to [http://localhost:3000](http://localhost:3000) with api key `devsite`.

### Installing the latest version to production

    # ssh into your Houm central unit
    $ npm install houmio/houmio-bridge --tag 2.0.1
    $ supervisorctl update
    $ supervisorctl restart houmio-bridge

See https://github.com/houmio/houmio-bridge/releases for releases.
