
FROM valhalla/valhalla:run-latest

RUN mkdir -p /data/valhalla/transit

# 1. Download OSM data
# 2. create Valhalla config file
# 3. build OSM tilesets and supporting databases
RUN cd /data/valhalla \
    && wget http://download.geofabrik.de/australia-oceania/australia-latest.osm.pbf \
    && valhalla_build_config \
           --mjolnir-tile-dir /data/valhalla \
           --mjolnir-transit-dir /data/valhalla/transit \
           --mjolnir-timezone /data/valhalla/tz_world.sqlite \
           --mjolnir-admin /data/valhalla/admin.sqlite > valhalla.json \
    && valhalla_build_timezones > /data/valhalla/tz_world.sqlite \
    && valhalla_build_admins --config valhalla.json australia-latest.osm.pbf \
    && valhalla_build_transit --config valhalla.json australia-latest.osm.pbf \
    && valhalla_build_tiles --config valhalla.json australia-latest.osm.pbf \
    && rm -r australia-latest.osm.pbf
#
#            --mjolnir-tile-extract /data/valhalla/tiles.tar \
#
#     "admin": "/data/valhalla/admin.sqlite",
#     "tile_dir": "/data/valhalla",
#     "tile_extract": "/data/valhalla/tiles.tar",
#     "timezone": "/data/valhalla/tz_world.sqlite",
#     "traffic_extract": "/data/valhalla/traffic.tar",
#     "transit_dir": "/data/valhalla/transit",


# RUN valhalla_build_transit --config valhalla.json australia-latest.osm.pbf \

ADD alias_tz.csv /data/valhalla

# Default command
CMD valhalla_service /data/valhalla/valhalla.json 1
