
# install dependencies (automake & czmq are required by prime_server)
brew install automake cmake libtool protobuf-c libspatialite pkg-config sqlite3 jq curl wget czmq lz4 spatialite-tools unzip luajit
# following packages are needed for running Linux compatible scripts
brew install bash coreutils binutils

export PATH=/usr/local/opt/binutils/bin:/usr/local/opt/coreutils/libexec/gnubin:$PATH

mkdir -p /Users/$(whoami)/valhalla_build
cd /Users/$(whoami)/valhalla_build

#build prime_server
git clone --recurse-submodules https://github.com/kevinkreiser/prime_server.git
cd prime_server

git submodule update --init --recursive
# standard autotools:
./autogen.sh
./configure
make test -j8
sudo make install

# build valhalla
cd ..
git clone --recurse-submodules --branch 3.4.0 https://github.com/valhalla/valhalla.git

# copy files to where valhalla will be built
mkdir -p /Users/$(whoami)/valhalla_build/valhalla/valhalla
cp -r /Users/$(whoami)/valhalla_build/prime_server/prime_server/ /Users/$(whoami)/valhalla_build/valhalla/valhalla/prime_server/

cd valhalla
cmake -B build -DCMAKE_BUILD_TYPE=Release
make -C build -j$(sysctl -n hw.physicalcpu)
sudo make -C build install

# FAIL