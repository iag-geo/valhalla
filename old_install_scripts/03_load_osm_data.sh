#!/usr/bin/env bash

cd ~/git/valhalla/valhalla

#download some data and make tiles out of it
#NOTE: you can feed multiple extracts into pbfgraphbuilder
#wget http://download.geofabrik.de/australia-oceania/australia-latest.osm.pbf

#get the config and setup
mkdir -p valhalla_tiles
./scripts/valhalla_build_config \
--mjolnir-tile-dir ${PWD}/valhalla_tiles \
--mjolnir-tile-extract ${PWD}/valhalla_tiles.tar \
--mjolnir-timezone ${PWD}/valhalla_tiles/timezones.sqlite \
--mjolnir-admin ${PWD}/valhalla_tiles/admins.sqlite > valhalla.json

#build routing tiles
#TODO: run valhalla_build_admins?
#./build/valhalla_build_tiles -c valhalla.json switzerland-latest.osm.pbf liechtenstein-latest.osm.pbf
./build/valhalla_build_tiles -c valhalla.json australia-latest.osm.pbf

#tar it up for running the server
find valhalla_tiles | sort -n | tar cf valhalla_tiles.tar --no-recursion -T -
