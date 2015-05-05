### Running locally

    npm install
    coffee src/bridge.coffee

The bridge will connect by default to [http://localhost:3000](http://localhost:3000) with api key `devsite`.

### Installing for production (with supervisor)

    npm install houmio/houmio-bridge --tag <release>
    supervisorctl update
    supervisorctl restart houmio-bridge

See https://github.com/houmio/houmio-bridge/releases for releases.
