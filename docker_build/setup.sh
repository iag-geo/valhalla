#!/usr/bin/env bash
set -o nounset
set -o errexit
set -o pipefail

set -e

### create required directories in shared volume
SHARED_VOLUME=vol_valhalla

echo "creating directories..."

mkdir -p $SHARED_VOLUME && cd $SHARED_VOLUME
mkdir -p valhalla_tiles
mkdir -p conf

# echo "downloading OSM data..."
OSM_FILE_URL="http://download.geofabrik.de/australia-oceania/australia-latest.osm.pbf"
OSM_FILE_NEW="osm_latest.osm.pbf"

# download data
wget --no-verbose \
    --show-progress \
    --progress=bar:force:noscroll \
    "$OSM_FILE_URL" \
    -O "$OSM_FILE_NEW"

echo "creating config..."
valhalla_build_config \
    --mjolnir-tile-dir ${PWD}/valhalla_tiles \
    --mjolnir-tile-extract ${PWD}/valhalla_tiles.tar \
    --mjolnir-timezone ${PWD}/valhalla_tiles/timezones.sqlite \
    --mjolnir-admin ${PWD}/valhalla_tiles/admins.sqlite \
    > ${PWD}/conf/valhalla.json

#    --mjolnir-traffic-extract ${PWD}/valhalla_traffic.tar \

echo "building timezones..."
valhalla_build_timezones > ${PWD}/valhalla_tiles/timezones.sqlite

echo "building admin areas..."
valhalla_build_admins --config ${PWD}/conf/valhalla.json "$OSM_FILE_NEW"

echo "building tiles..."
valhalla_build_tiles -c ${PWD}/conf/valhalla.json "$OSM_FILE_NEW"

echo "building tile index..."
valhalla_build_extract -c ${PWD}/conf/valhalla.json

echo "starting server..."
# run on n number of cores
valhalla_service ${PWD}/conf/valhalla.json 1

# # if needed, keep container running for debugging
# while true; do sleep 1; done;


## 1. Download OSM data
## 2. create Valhalla config file
## 3. build OSM tilesets and supporting databases
#RUN cd /valhalla \
#    && wget http://download.geofabrik.de/australia-oceania/australia-latest.osm.pbf \
#    && valhalla_build_config \
#        --mjolnir-tile-dir ${PWD}/valhalla_tiles \
#        --mjolnir-tile-extract ${PWD}/valhalla_tiles.tar \
#        --mjolnir-timezone ${PWD}/timezones.sqlite \
#        --mjolnir-admin ${PWD}/admins.sqlite > ${PWD}/conf/valhalla.json \
#         | tee ${PWD}/logs/valhalla_build_config.log \
#    && valhalla_build_timezones > ${PWD}/timezones.sqlite | tee ${PWD}/logs/valhalla_build_timezones.log \
#    && valhalla_build_admins --config ${PWD}/conf/valhalla.json australia-latest.osm.pbf | tee ${PWD}/logs/valhalla_build_admins.log\
#    && valhalla_build_tiles --config ${PWD}/conf/valhalla.json australia-latest.osm.pbf | tee ${PWD}/logs/valhalla_build_tiles.log\
#    && find valhalla_tiles | sort -n | tar -cf "valhalla_tiles.tar" --no-recursion -T - \
#    && rm -r ${PWD}/valhalla_tiles \
#    && rm -r australia-latest.osm.pbf

