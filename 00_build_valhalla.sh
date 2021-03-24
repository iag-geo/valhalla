
# DO NOT EDIT
VALHALLA_HOME_DIR="${HOME}/git/valhalla"

. ~/.bash_profile

cd ${HOME}

## install dependencies (autoconf automake zmq czmq are required by prime_server)
#brew install automake cmake libtool protobuf-c boost-python3 libspatialite pkg-config sqlite3 jq curl wget czmq lz4 spatialite-tools unzip luajit autoconf zmq
##brew upgrade automake cmake libtool protobuf-c boost-python3 libspatialite pkg-config sqlite3 jq curl wget czmq lz4 spatialite-tools unzip luajit autoconf zmq
#
#curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | bash
#
## following packages are needed for running Linux compatible scripts
#brew install bash coreutils binutils
##brew upgrade bash coreutils binutils
#
## Update your PATH env variable to include /usr/local/opt/binutils/bin:/usr/local/opt/coreutils/libexec/gnubin
#echo 'export PATH="/usr/local/opt/binutils/bin:/usr/local/opt/coreutils/libexec/gnubin:$PATH"' >> ~/.bash_profile
#source ~/.bash_profile

# download and build prime_server
mkdir ${HOME}/git/kevinkreiser
cd ${HOME}/git/kevinkreiser
git clone https://github.com/kevinkreiser/prime_server.git

cd prime_server

# dont forget submodules
git submodule update --init --recursive
# standard autotools:
./autogen.sh
./configure
make test -j8
sudo make install



# download Valhalla source code
cd ${VALHALLA_HOME_DIR}
git clone --recurse-submodules https://github.com/valhalla/valhalla.git

#cd ${HOME}
#wget https://github.com/valhalla/valhalla/archive/refs/tags/3.1.0.tar.gz
#tar -xzf 3.1.0.tar.gz
#rm 3.1.0.tar.gz

# build
cd valhalla

cd ..
sudo rm -r build
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(sysctl -n hw.physicalcpu)
sudo make install