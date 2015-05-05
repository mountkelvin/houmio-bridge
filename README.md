### Running locally

    npm install
    coffee src/bridge.coffee

The bridge will connect by default to [http://localhost:3000](http://localhost:3000) with api key `devsite`.

### Installing for production (with supervisor)

    npm install houmio/houmio-bridge --tag 2.0.0
    supervisorctl update
    supervisorctl restart houmio-bridge

where `2.0.0` is the version.
