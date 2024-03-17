
# install dependencies (automake & czmq are required by prime_server)
brew install automake cmake libtool protobuf-c libspatialite pkg-config sqlite3 jq curl wget czmq lz4 spatialite-tools unzip luajit
# following packages are needed for running Linux compatible scripts
brew install bash coreutils binutils
# Update your PATH env variable to include /usr/local/opt/binutils/bin:/usr/local/opt/coreutils/libexec/gnubin


build prime_server
git clone --recurse-submodules https://github.com/kevinkreiser/prime_server.git

cmake -B build -DCMAKE_BUILD_TYPE=Release
make -C build -j$(sysctl -n hw.physicalcpu)
sudo make -C build install

# copy files to where valhalla will be built
mkdir -p /Users/$(whoami)/valhalla_build/valhalla/valhalla
cp -r /Users/$(whoami)/valhalla_build/prime_server/prime_server/ /Users/$(whoami)/valhalla_build/valhalla/valhalla/prime_server/

# build valhalla
git clone --recurse-submodules https://github.com/valhalla/valhalla.git

cmake -B build -DCMAKE_BUILD_TYPE=Release
make -C build -j$(sysctl -n hw.physicalcpu)
sudo make -C build install

# FAIL