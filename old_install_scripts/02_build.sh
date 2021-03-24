#!/usr/bin/env bash

# clone Valhalla repo
cd ~/git
mkdir valhalla
cd valhalla
git clone --recurse-submodules https://github.com/valhalla/valhalla.git
cd valhalla

setproxy

# if you wanted to enable node bindings
npm install --ignore-scripts

# build prime_server
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release \
-DGEOS_INCLUDE_DIR:PATH=/usr/local \
-DGEOS_LIB:FILEPATH=/usr/local \
-DGEOS_LIBRARY:STRING=/usr/local/lib/libgeos.dylib;/usr/local/lib/libgeos_c.dylib

#-DPYTHON_EXECUTABLE=/Library/Frameworks/Python.framework/Versions/3.7/bin/python \
#-DPYTHON_INCLUDE_DIR=/Library/Frameworks/Python.framework/Versions/3.7/include/python3.7m \
#-DPYTHON_LIBRARY=/Library/Frameworks/Python.framework/Versions/3.7/lib/libpython3.7m.dylib

# -DENABLE_DATA_TOOLS=On -DENABLE_SERVICES=On -DBUILD_SHARED_LIBS=On

make -j$(sysctl -n hw.physicalcpu)
sudo make install

unsetproxy
