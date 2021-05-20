
FROM valhalla/valhalla:run-latest

# 1. Download OSM data
# 2. create Valhalla config file
# 3. build OSM tilesets and supporting databases
WORKDIR /build
ENV WORKDIR=/build DATADIR=/data/valhalla VALHALLA_CONFIG=/build/valhalla.json
RUN mkdir -p ${WORKDIR} ${DATADIR}/valhalla_tiles \
    && cd ${WORKDIR} \
    && wget http://download.geofabrik.de/australia-oceania/australia-latest.osm.pbf \
    && valhalla_build_config --mjolnir-tile-dir ${DATADIR}/valhalla_tiles \
           --mjolnir-tile-extract ${DATADIR}/valhalla_tiles.tar \
           --mjolnir-timezone ${DATADIR}/tz_world.sqlite \
           --mjolnir-admin ${DATADIR}/admin.sqlite > ${VALHALLA_CONFIG} \
    && valhalla_build_timezones > ${DATADIR}/tz_world.sqlite \
    && valhalla_build_admins --config ${VALHALLA_CONFIG} ${WORKDIR}/australia-latest.osm.pbf \
    && valhalla_build_tiles --config ${VALHALLA_CONFIG} ${WORKDIR}/australia-latest.osm.pbf \
    && rm -r ${WORKDIR}/australia-latest.osm.pbf

# RUN valhalla_build_transit --config ${VALHALLA_CONFIG} ${WORKDIR}/australia-latest.osm.pbf \

ADD alias_tz.csv ${WORKDIR}

# Default command
CMD valhalla_service ${VALHALLA_CONFIG} 1
