#!/usr/bin/env bash

cd /Users/$(whoami)/tmp

curl https://download.geofabrik.de/australia-oceania/australia-latest.osm.pbf -o australia-latest.osm.pbf

#brew install osm2pgsql
osm2pgsql -c --cache 8096 --latlong --output-pgsql-schema osm --number-processes 8 -H 127.0.0.1 -P 5432 -U postgres -d geo australia-latest.osm.pbf

