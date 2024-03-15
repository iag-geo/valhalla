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
    --mjolnir-traffic-extract ${PWD}/valhalla_traffic.tar \
    --mjolnir-timezone ${PWD}/valhalla_tiles/timezones.sqlite \
    --mjolnir-admin ${PWD}/valhalla_tiles/admins.sqlite \
    > ${PWD}/conf/valhalla.json

echo "building timezones..."
valhalla_build_timezones > ${PWD}/valhalla_tiles/timezones.sqlite

echo "building admin areas..."
valhalla_build_admins --config ${PWD}/conf/valhalla.json "$OSM_FILE_NEW"

echo "building tiles..."
valhalla_build_tiles -c ${PWD}/conf/valhalla.json "$OSM_FILE_NEW"

echo "building tile index..."
valhalla_build_extract -c ${PWD}/conf/valhalla.json -v

echo "starting server..."
# run on n number of cores
valhalla_service ${PWD}/conf/valhalla.json 1

# # if needed, keep container running for debugging
# while true; do sleep 1; done;