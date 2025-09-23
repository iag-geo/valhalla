-- select *
-- from osm.planet_osm_line
-- WHERE highway = 'primary'
-- ;


DROP TABLE IF EXISTS osm.osm_road CASCADE;
CREATE TABLE osm.osm_road AS
SELECT osm_id,
       name,
       oneway,
       highway AS type,
       ref,
       tags->'network'::text as network,
       tunnel,
       bridge,
       junction,
       tags->'maxspeed'::text as maxspeed,
       sum(st_length(way::geography)) as length,
       st_union(st_transform(way, 4326)) AS geom,
       st_union(st_transform(way, 4326))::geography AS geog
FROM osm.planet_osm_line
WHERE highway IS NOT NULL
  AND highway NOT IN (
                     '',
                     'footway',
                     'steps',
                     'cycleway',
                     'proposed',
                     'construction',
                     'path',
                     'track',
                     'pedestrian',
                     'bus_guideway',
                     'bridleway',
                     'corridor',
                     'abandoned',
                     'raceway',
                     'escape',
                     'tree_row',
                     'crossing',
                     'platform',
                     'planned',
                     'bus_stop',
                     'rest_area',
                     'disused',
                     '*',
                     'co',
                     'driveway',
                     'elevator',
                     'no',
                     'none',
                     'services',
                     'traffic_island',
                     'trail',
                     'street_lamp'
--                      'yes'

    )
group by osm_id,
         name,
         oneway,
         highway,
         maxspeed,
         tunnel,
         bridge,
         junction,
         ref,
         network
;

ANALYZE osm.osm_road;

ALTER TABLE osm.osm_road ADD PRIMARY KEY (osm_id);
CREATE INDEX osm_road_type_idx ON osm.osm_road USING btree (type);

CREATE INDEX osm_road_geom_idx ON osm.osm_road USING GIST (geom);
CREATE INDEX osm_road_geog_idx ON osm.osm_road USING GIST (geog);
ALTER TABLE osm.osm_road CLUSTER ON osm_road_geom_idx;


-- create GeoJSON view of roads
DROP VIEW IF EXISTS osm.vw_osm_road_geojson;
CREATE VIEW osm.vw_osm_road_geojson AS
select osm_id,
       name,
       oneway,
       type,
       ref,
       network,
       tunnel,
       bridge,
       junction,
       maxspeed,
       length,
       st_asgeojson(geog) as geog
from osm.osm_road
;



-- create view of main roads
DROP VIEW IF EXISTS osm.vw_osm_main_road;
CREATE VIEW osm.vw_osm_main_road AS
select * from osm.osm_road
where type in ('motorway',
               'motorway_link',
               'trunk',
               'trunk_link',
               'primary',
               'primary_link',
               'secondary',
               'secondary_link')
--                'tertiary',
--                'tertiary_link')
;


DROP TABLE IF EXISTS osm.osm_railway;
CREATE TABLE osm.osm_railway AS
SELECT osm_id,
       name,
       oneway,
       railway AS type,
       tunnel,
       bridge,
       sum(st_length(way::geography)) as length,
       st_union(st_transform(way, 4326)) AS geom,
       st_union(st_transform(way, 4326))::geography AS geog
FROM osm.planet_osm_line
WHERE railway IS NOT NULL
    AND osm_id NOT IN (SELECT osm_id FROM osm.osm_road)
group by osm_id,
         name,
         oneway,
         railway,
         tunnel,
         bridge
;

ANALYZE osm.osm_railway;

ALTER TABLE osm.osm_railway ADD PRIMARY KEY (osm_id);
CREATE INDEX osm_railway_type_idx ON osm.osm_railway USING btree (type);

CREATE INDEX osm_railway_geom_idx ON osm.osm_railway USING GIST (geom);
CREATE INDEX osm_railway_geog_idx ON osm.osm_railway USING GIST (geog);
ALTER TABLE osm.osm_railway CLUSTER ON osm_railway_geom_idx;

--
-- select type, count(*) from osm.osm_railway
-- GROUP BY type
-- ORDER BY type;

-- select count(*) from osm.osm_road;


-- select highway, count(*) from osm.planet_osm_line
-- GROUP BY highway
-- ORDER BY highway;


-- select *
-- from osm.planet_osm_line
-- where osm_id =358797491;



