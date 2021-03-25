
# Dockerfile adapted from https://github.com/interline-io/valhalla-docker
#
# MIT License:
#    Unless otherwise indicated:
#
#    Copyright Interline Technologies LLC
#
#    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
#    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
#    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


# Dockerfile to build Valhalla in stage 1, 
#   then build our image by pulling out 
#   the compiled Valhalla binaries from stage 1.

# #####################################
# ############ STAGE 1 ################
# #####################################

FROM ubuntu:18.04

ARG VALHALLA_VERSION=3.1.0
ARG VALHALLA_REPO=https://github.com/valhalla/valhalla.git
ARG PRIME_SERVER_TAG=0.7.0
ARG VALHALLA_VERSION
ARG VALHALLA_REPO
ARG PRIME_SERVER_TAG

# Install base packages
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    autoconf \
    automake \
    build-essential \
    cmake \
    curl \
    g++ \
    gcc \
    git \
    jq \
    lcov \
    libboost-all-dev \
    libboost-python-dev \
    libbz2-dev \
    libcurl4-openssl-dev \
    libczmq-dev \
    libexpat1-dev \
    libgeos++-dev \
    libgeos-dev \
    libluajit-5.1-dev \
    liblz4-dev \
    libspatialite-dev \
    libsqlite3-dev \
    libsqlite3-mod-spatialite \
    libprotobuf-dev \
    libprotobuf-lite10 \
    libtool \
    libzmq3-dev \
    make \
    osmctools \
    osmosis \
    parallel \
    pkg-config \
    protobuf-compiler \
    python-all-dev \
    python-pip \
    python-virtualenv \
    software-properties-common \
    spatialite-bin \
    vim-common \
    wget \
    zlib1g-dev

RUN mkdir -p /src && cd /src

# prime_server
RUN git clone -v --branch ${PRIME_SERVER_TAG} https://github.com/kevinkreiser/prime_server.git && (cd prime_server && git submodule update --init --recursive && mkdir -p build && cd build && cmake .. && make -j2 install)

# valhalla
RUN git clone https://github.com/valhalla/valhalla.git && (cd valhalla && git checkout tags/${VALHALLA_VERSION} -b build && git submodule update --init --recursive && mkdir -p build && cd build && cmake .. -DPKG_CONFIG_PATH=/usr/local/lib/pkgconfig -DCMAKE_BUILD_TYPE=Release -DENABLE_NODE_BINDINGS=OFF && make -j2 install) && rm -rf /src

# #####################################
# ############ STAGE 2 ################
# #####################################

FROM ubuntu:18.04
ARG VALHALLA_VERSION
ARG VALHALLA_CONCURRENCY=1

# Copy ARG to ENV
ENV VALHALLA_VERSION=${VALHALLA_VERSION}
ENV VALHALLA_CONCURRENCY=${VALHALLA_CONCURRENCY}

# Utilities needed
RUN apt-get update && apt-get install --no-install-recommends -y apt-transport-https curl libcurl4 ca-certificates gnupg && rm -rf /var/lib/apt/lists/*

# Install apt packages packages
RUN apt-get update && apt-get install --no-install-recommends -y \
    libboost-python1.65.1 \
    libboost-filesystem1.65.1 \
    libboost-iostreams1.65.1 \
    libboost-regex1.65.1 \
    libboost-thread1.65.1 \
    libboost-program-options1.65.1 \
    libluajit-5.1-2 \
    libprotoc10 \
    libprotobuf-lite10 \
    libzmq5 \
    libczmq4 \
    libsqlite3-mod-spatialite \
    python-pip \
    python-virtualenv \
    spatialite-bin \
    jo \
    jq \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Copy previous installs
COPY --from=0 /usr/local /usr/local

# Fix things
ENV LD_LIBRARY_PATH "${LD_LIBRARY_PATH}:/usr/local/lib"
RUN ln -s /usr/lib/x86_64-linux-gnu/mod_spatialite.so.7.1.0 /usr/lib/x86_64-linux-gnu/mod_spatialite

# Setup and download OSM data
WORKDIR /build
ENV WORKDIR=/build DATADIR=/data/valhalla VALHALLA_CONFIG=/build/valhalla.json
RUN mkdir -p ${WORKDIR} ${DATADIR}/valhalla_tiles \
    && cd ${WORKDIR} \
    && wget http://download.geofabrik.de/australia-oceania/australia-latest.osm.pbf

# create Valhalla config file
RUN valhalla_build_config --mjolnir-tile-dir ${DATADIR}/valhalla_tiles \
           --mjolnir-tile-extract ${DATADIR}/valhalla_tiles.tar \
           --mjolnir-timezone ${DATADIR}/tz_world.sqlite \
           --mjolnir-admin ${DATADIR}/admin.sqlite > ${VALHALLA_CONFIG}

# build OSM tilesets and supported databases
RUN valhalla_build_timezones > ${DATADIR}/tz_world.sqlite \
    && valhalla_build_admins --config ${VALHALLA_CONFIG} ${WORKDIR}/australia-latest.osm.pbf \
    && valhalla_build_tiles --config ${VALHALLA_CONFIG} ${WORKDIR}/australia-latest.osm.pbf

RUN valhalla_build_transit --config ${VALHALLA_CONFIG} ${WORKDIR}/australia-latest.osm.pbf \

#    && valhalla_build_config > ${VALHALLA_CONFIG} \

ADD alias_tz.csv ${WORKDIR}

# Default command
CMD valhalla_service ${VALHALLA_CONFIG} ${VALHALLA_CONCURRENCY}