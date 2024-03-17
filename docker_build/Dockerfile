FROM ghcr.io/valhalla/valhalla:latest
#FROM valhalla/valhalla:run-latest

RUN apt update

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