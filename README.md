### Running locally

    npm install
    coffee src/bridge.coffee

The bridge will connect by default to [http://localhost:3000](http://localhost:3000) with api key `devsite`.

### Installing the latest version to production

    # ssh into your Houm central unit
    $ npm install houmio/houmio-bridge --tag 2.0.1
    # ^ takes a while, be patient
    $ supervisorctl update
    $ supervisorctl restart houmio-bridge

[Fing](http://www.overlooksoft.com/fing) is a nice tool for listing the IP and MAC addresses of the network you are in.

See https://github.com/houmio/houmio-bridge/releases for releases.
