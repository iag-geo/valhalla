#!/usr/bin/env bash

export PATH=/bin:/usr/bin:$PATH # Add /bin and /usr/bin to PATH

# get the directory this script is running from
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

psql -d geo -p 5432 -U postgres -c "CREATE SCHEMA IF NOT EXISTS osm AUTHORIZATION postgres;"
psql -d geo -p 5432 -U postgres -c "CREATE EXTENSION IF NOT EXISTS postgis;"
psql -d geo -p 5432 -U postgres -c "CREATE EXTENSION IF NOT EXISTS hstore;"

cd /Users/$(whoami)/tmp

## "latest" build no longer available - pick the build from 2 days ago to be safe (yesterday's may not exist yet)
FORMATTED_DATE="$(($(date +'%y%m%d') - 2))"
FILE_NAME="australia-${FORMATTED_DATE}.osm.pbf"
#echo ${FILE_NAME}

curl https://download.geofabrik.de/australia-oceania/${FILE_NAME} -o ${FILE_NAME}

brew upgrade osm2pgsql
osm2pgsql -c --latlong --hstore --output-pgsql-schema osm --number-processes 12 -H 127.0.0.1 -P 5432 -U postgres -d geo ${FILE_NAME}

rm ${FILE_NAME}

psql -d geo -p 5432 -U postgres -f ${SCRIPT_DIR}/01_filter_roads.sql
