

# 1. build image
cd /Users/s57405/git/iag_geo/valhalla/docker_build
docker build --tag iag-geo/valhalla:3.1.0 .

# 2. run container


# 3. log into container (default folder is /build)


# 4. download OSM data and create tiles
#mkdir -p valhalla_tiles
/usr/local/bin/valhalla_build_tiles -c /build/valhalla.json /build/australia-latest.osm.pbf


