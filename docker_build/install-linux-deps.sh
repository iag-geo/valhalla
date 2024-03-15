#!/usr/bin/env bash
# Script for shared dependencies

set -x -o errexit -o pipefail -o nounset

export DEB_BUILD_MAINT_OPTIONS=optimize=+lto

apt-get update --assume-yes
env DEBIAN_FRONTEND=noninteractive apt-get install --yes --quiet \
    build-essential \
    crossbuild-essential-arm64 \
    gcc-aarch64-linux-gnu \
    binutils-aarch64-linux-gnu \
    gnupg2 \
    linux-libc-dev \
    libpthread-stubs0-dev \
    sqlite3 \
    lz4 \
    fonts-hanazono \
    fonts-noto-cjk \
    fonts-noto-hinted \
    fonts-noto-unhinted \
    fonts-unifont \
    libosmium2-dev \
    libboost-program-options-dev \
    libbz2-dev \
    wget

# Now, go through and install the build dependencies
apt-get update --assume-yes
env DEBIAN_FRONTEND=noninteractive apt-get install --yes --quiet \
    autoconf \
    automake \
    ccache \
    clang \
    clang-tidy \
    coreutils \
    curl \
    cmake \
    g++ \
    gcc \
    git \
    jq \
    lcov \
    libasan6 \
    libboost-all-dev \
    libc6-dev \
    libcurl4-openssl-dev \
    libczmq-dev \
    libgeos++-dev \
    libgeos-dev \
    libjsoncpp-dev \
    libluajit-5.1-dev \
    liblz4-dev \
    libprotobuf-dev \
    libspatialite-dev \
    libsqlite3-dev \
    libsqlite3-mod-spatialite \
    libssl-dev \
    libtool \
    libubsan1 \
    libzmq3-dev \
    lld \
    locales \
    make \
    osmium-tool \
    parallel \
    pkg-config \
    protobuf-compiler \
    python3-all-dev \
    python3-shapely \
    python3-pip \
    spatialite-bin \
    unzip \
    zlib1g-dev \
  && apt-get update && apt-get -y upgrade \
  && locale-gen $LANG && update-locale LANG=$LANG \
  && apt-get update && apt-get -y upgrade \
  && rm -rf /var/lib/apt/lists/*

# build prime_server from source
readonly primeserver_dir=/usr/local/src/prime_server
git clone --recurse-submodules https://github.com/kevinkreiser/prime_server $primeserver_dir
pushd $primeserver_dir
./autogen.sh && ./configure LDFLAGS='-pthread' && \
make -j${CONCURRENCY:-$(nproc)} LIBS=-lpthread install && \
popd && \
rm -r $primeserver_dir

# for boost
python3 -m pip install --upgrade "conan<2.0.0" requests shapely