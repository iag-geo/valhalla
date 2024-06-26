#!/usr/bin/env bash

# get the directory this script is running from
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

psql -d geo -p 5432 -U postgres -c "CREATE SCHEMA IF NOT EXISTS osm AUTHORIZATION postgres;"
psql -d geo -p 5432 -U postgres -c "CREATE EXTENSION IF NOT EXISTS postgis;"
psql -d geo -p 5432 -U postgres -c "CREATE EXTENSION IF NOT EXISTS hstore;"

cd /Users/$(whoami)/tmp

curl https://download.geofabrik.de/australia-oceania/australia-latest.osm.pbf -o australia-latest.osm.pbf

brew upgrade osm2pgsql
osm2pgsql -c --cache 8096 --latlong --hstore --output-pgsql-schema osm --number-processes 12 -H 127.0.0.1 -P 5432 -U postgres -d geo australia-latest.osm.pbf

rm australia-latest.osm.pbf

psql -d geo -p 5432 -U postgres -f ${SCRIPT_DIR}/01_filter_roads.sql
