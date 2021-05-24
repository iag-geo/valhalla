#!/usr/bin/env bash

# install dependencies (automake & czmq are required by prime_server)
setproxy
brew install automake cmake libtool protobuf-c boost-python3 libspatialite pkg-config sqlite3 lua jq curl wget czmq lz4 node@10 npm spatialite-tools unzip

#brew upgrade sqlite
#brew upgrade curl
#brew upgrade wget
#brew upgrade lz4

#curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash
#
#nvm use 10 # must use node 8.11.1 and up because of N-API
#npm install --ignore-scripts


curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.34.0/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[[ -s "$NVM_DIR/nvm.sh" ]] && \. "$NVM_DIR/nvm.sh"
nvm install 10.15.0 && nvm use 10.15.0
npm install --ignore-scripts --unsafe-perm=true
ln -s ~/.nvm/versions/node/v10.15.0/include/node/node.h /usr/local/include/node.h
ln -s ~/.nvm/versions/node/v10.15.0/include/node/uv.h /usr/local/include/uv.h
ln -s ~/.nvm/versions/node/v10.15.0/include/node/v8.h /usr/local/include/v8.h




https://github.com/valhalla/valhalla/archive/refs/tags/3.1.1.tar.gz








# following packages are needed for running Linux compatible scripts
brew install bash coreutils binutils


brew install valhalla/valhalla/prime_server

unsetproxy

# Update your PATH env variable to include /usr/local/opt/binutils/bin:/usr/local/opt/coreutils/libexec/gnubin
echo 'export PATH="/usr/local/opt/binutils/bin:/usr/local/opt/coreutils/libexec/gnubin:$PATH"' >> ~/.bash_profile
source ~/.bash_profile
