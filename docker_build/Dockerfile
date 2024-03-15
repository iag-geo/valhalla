FROM ubuntu@sha256:9ff03c2930fce7e915f3b321c6c601380ffb845140bd36715c44ec31d7ae551e as builder

ARG DEBIAN_FRONTEND=noninteractive
ARG DEB_BUILD_MAINT_OPTIONS=optimize=+lto

ARG CONCURRENCY
ARG BUILDPLATFORM

ENV LANG C.UTF-8
ENV LC_ALL C.UTF-8

# set paths
ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH
ENV LD_LIBRARY_PATH /usr/local/aarch64-linux-gnu:/usr/lib/aarch64-linux-gnu:/usr/local/lib:/lib/aarch64-linux-gnu:/usr/local/lib:/lib/aarch64-linux-gnu:$LD_LIBRARY_PATH

WORKDIR /usr/local/src
COPY ./install-linux-deps.sh /usr/local/src/install-linux-deps.sh
RUN bash /usr/local/src/install-linux-deps.sh
RUN rm -rf /usr/local/src/install-linux-deps.sh

# Get Noto Emoji Regular font, despite it being deprecated by Google
RUN wget https://github.com/googlefonts/noto-emoji/blob/9a5261d871451f9b5183c93483cbd68ed916b1e9/fonts/NotoEmoji-Regular.ttf?raw=true --content-disposition -P /usr/share/fonts/
# For some reason this one is missing in the default packages
RUN wget https://github.com/stamen/terrain-classic/blob/master/fonts/unifont-Medium.ttf?raw=true --content-disposition -P /usr/share/fonts/

# clone valhalla repo and submodules
ARG VALHALLA_BRANCH=3.4.0
RUN git clone --branch $VALHALLA_BRANCH https://github.com/valhalla/valhalla.git

WORKDIR /usr/local/src/valhalla/valhalla
RUN ls -la \
    && git submodule sync \
    && git submodule update --init --recursive
RUN rm -rf build && mkdir build


RUN python3 -m pip install --upgrade "conan<2.0.0" requests

# configure the build with symbols turned on so that crashes can be triaged
WORKDIR /usr/local/src/valhalla/build

# cmake as debug build
RUN CXXFLAGS=-DGEOS_INLINE cmake .. \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_C_COMPILER=/usr/bin/aarch64-linux-gnu-gcc \
  -DCMAKE_THREAD_LIBS_INIT="-lpthread" \
  -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64"

### make
RUN VERBOSE=1 make all -j${CONCURRENCY:-$(nproc)} LIBS=-lpthread
RUN VERBOSE=1 make LIBS=-lpthread install

# we wont leave the source around but we'll drop the commit hash we'll also keep the locales
WORKDIR /usr/local/src
RUN cd valhalla && echo "https://github.com/valhalla/valhalla/tree/$(git rev-parse HEAD)" > ../valhalla_version
RUN for f in valhalla/locales/*.json; do cat ${f} | python3 -c 'import sys; import json; print(json.load(sys.stdin)["posix_locale"])'; done > valhalla_locales
RUN rm -rf valhalla

# the binaries are huge with all the symbols so we strip them but keep the debug there if we need it
WORKDIR /usr/local/bin
RUN for f in valhalla_*; do objcopy --only-keep-debug $f $f.debug; done
RUN tar -cvf valhalla.debug.tar valhalla_*.debug && gzip -9 valhalla.debug.tar
RUN rm -f valhalla_*.debug
RUN strip --strip-debug --strip-unneeded valhalla_* || true
RUN strip /usr/local/lib/libvalhalla.a
RUN strip /usr/lib/python3/dist-packages/valhalla/python_valhalla*.so


####################################################################
FROM ubuntu@sha256:9ff03c2930fce7e915f3b321c6c601380ffb845140bd36715c44ec31d7ae551e as runner

# copy the important stuff from the build stage to the runner image
COPY --from=builder /usr/local /usr/local
COPY --from=builder /usr/lib/python3/dist-packages/valhalla/* /usr/lib/python3/dist-packages/valhalla/

RUN export DEBIAN_FRONTEND=noninteractive && apt update && \
    apt install -y \
      build-essential \
      crossbuild-essential-arm64 \
      gcc-aarch64-linux-gnu \
      binutils-aarch64-linux-gnu \
      dateutils \
      fonts-hanazono \
      fonts-noto-cjk \
      fonts-noto-hinted \
      fonts-noto-unhinted \
      fonts-unifont \
      gnupg2 \
      gdal-bin \
      wget \
      rsyslog

### for arch64 compilation
RUN export DEBIAN_FRONTEND=noninteractive && apt update && \
    apt install -y \
      libasan6 \
      libcurl4 \
      libczmq4 \
      libluajit-5.1-dev \
      libprotobuf-dev \
      libubsan1 \
      libsqlite3-dev \
      libsqlite3-mod-spatialite \
      libzmq5 \
      zlib1g \
      curl \
      gdb-multiarch \
      locales \
      parallel \
      protobuf-compiler \
      python3 \
      python3-distutils \
      python-is-python3 \
      spatialite-bin \
      unzip \
    && apt-get update && apt-get -y upgrade \
    && locale-gen $LANG && update-locale LANG=$LANG \
    && cat /usr/local/src/valhalla_locales | xargs -d '\n' -n1 locale-gen && \
    rm -rf /var/lib/apt/lists/* && \
    \
    # python smoke test
    python3 -c "import valhalla,sys; print(sys.version, valhalla)"


COPY ./setup.sh /setup.sh
RUN chmod +x /setup.sh
CMD ["/bin/bash", "/setup.sh"]












RUN mkdir -p /valhalla/valhalla_tiles /valhalla/conf /valhalla/logs

# copy timezone aliases files
ADD alias_tz.csv /valhalla

# 1. Download OSM data
# 2. create Valhalla config file
# 3. build OSM tilesets and supporting databases
RUN cd /valhalla \
    && wget http://download.geofabrik.de/australia-oceania/australia-latest.osm.pbf \
    && valhalla_build_config \
        --mjolnir-tile-dir ${PWD}/valhalla_tiles \
        --mjolnir-tile-extract ${PWD}/valhalla_tiles.tar \
        --mjolnir-timezone ${PWD}/timezones.sqlite \
        --mjolnir-admin ${PWD}/admins.sqlite > ${PWD}/conf/valhalla.json \
         | tee ${PWD}/logs/valhalla_build_config.log \
    && valhalla_build_timezones > ${PWD}/timezones.sqlite | tee ${PWD}/logs/valhalla_build_timezones.log \
    && valhalla_build_admins --config ${PWD}/conf/valhalla.json australia-latest.osm.pbf | tee ${PWD}/logs/valhalla_build_admins.log\
    && valhalla_build_tiles --config ${PWD}/conf/valhalla.json australia-latest.osm.pbf | tee ${PWD}/logs/valhalla_build_tiles.log\
    && find valhalla_tiles | sort -n | tar -cf "valhalla_tiles.tar" --no-recursion -T - \
    && rm -r ${PWD}/valhalla_tiles \
    && rm -r australia-latest.osm.pbf

#     && valhalla_build_transit --config valhalla.json australia-latest.osm.pbf \

# Default command
CMD valhalla_service /valhalla/conf/valhalla.json 1
