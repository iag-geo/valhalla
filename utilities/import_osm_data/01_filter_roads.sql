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
       null::smallint as inferred_maxspeed,
       null::text as inference_type,
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

--------------------------------------------------------------------------------------------------------
-- add inferred speed limits
--------------------------------------------------------------------------------------------------------
update osm.osm_road
    set inferred_maxspeed = maxspeed::smallint,
        inference_type = 'maxspeed'
where REGEXP_REPLACE(maxspeed, '[^0-9]', '', 'g') = maxspeed -- ignore records with characters in the speed (e.g. '10 mph')
;

-- -- 7 records - ignore
-- select *
-- from osm.osm_road
-- where inferred_maxspeed is null
--     and maxspeed is not null
-- ;


-- infer speed limit for streets that have one speed limit for all streets touching them (e.g. roundabouts) of the same road classification (type)
-- 114,321 rows affected in 57 m 28 s 160 ms
with good as (
    select osm_id,
           inferred_maxspeed,
           type,
           geom
    from osm.osm_road
    where inferred_maxspeed is not null
--       and type not in ('service', 'unclassified')
), bad as (
    select osm_id,
           inferred_maxspeed,
           type,
           geom
    from osm.osm_road
    where inferred_maxspeed is null
--       and type not in ('service', 'unclassified')
--     limit 1000
), merge as (
    select bad.osm_id,
           bad.type,
           good.inferred_maxspeed,
           count(distinct good.osm_id) as matches
    from bad
    inner join good on bad.type = good.type
        and st_touches(bad.geom, good.geom)
    group by bad.osm_id,
             bad.type,
             good.inferred_maxspeed
), crunch as (
    select osm_id,
           type
    from merge
    group by osm_id,
             type
    having count(*) = 1
), merge2 as (
    select distinct merge.*
    from crunch
    inner join merge on crunch.osm_id = merge.osm_id
)
update osm.osm_road as osm
    set inferred_maxspeed = merge2.inferred_maxspeed,
        inference_type = 'spatial pass 1'
from merge2
where osm.osm_id = merge2.osm_id
;


-- 2nd pass - to get roads that are connected to ones that got picked up in the 1st pass (fixes roundabouts amongst others)
with good as (
    select osm_id,
           inferred_maxspeed,
           type,
           geom
    from osm.osm_road
    where inferred_maxspeed is not null
--       and type not in ('service', 'unclassified')
), bad as (
    select osm_id,
           inferred_maxspeed,
           type,
           geom
    from osm.osm_road
    where inferred_maxspeed is null
--       and type not in ('service', 'unclassified')
--     limit 1000
), merge as (
    select bad.osm_id,
           bad.type,
           good.inferred_maxspeed,
           count(distinct good.osm_id) as matches
    from bad
             inner join good on bad.type = good.type
        and st_touches(bad.geom, good.geom)
    group by bad.osm_id,
             bad.type,
             good.inferred_maxspeed
), crunch as (
    select osm_id,
           type
    from merge
    group by osm_id,
             type
    having count(*) = 1
), merge2 as (
    select distinct merge.*
    from crunch
             inner join merge on crunch.osm_id = merge.osm_id
)
update osm.osm_road as osm
set inferred_maxspeed = merge2.inferred_maxspeed,
    inference_type = 'spatial pass 2'
from merge2
where osm.osm_id = merge2.osm_id
;


-- TODO: add speed limits to _links (not including motorway_links)
-- 3rd pass - to get roads that are connected to ones that got picked up in the 1st pass (fixes roundabouts amongst others)
with good as (
    select osm_id,
           inferred_maxspeed,
           replace(type, '_link', '') as type,
           geom
    from osm.osm_road
    where inferred_maxspeed is not null
), bad as (
    select osm_id,
           inferred_maxspeed,
           replace(type, '_link', '') as type,
           geom
    from osm.osm_road
    where inferred_maxspeed is null
      and type <> 'motorway_link'
      and type like '%_link'
), merge as (
    select bad.osm_id,
           bad.type,
           good.inferred_maxspeed,
           count(distinct good.osm_id) as matches
    from bad
             inner join good on bad.type = good.type
        and st_touches(bad.geom, good.geom)
    group by bad.osm_id,
             bad.type,
             good.inferred_maxspeed
), crunch as (
    select osm_id,
           type
    from merge
    group by osm_id,
             type
    having count(*) = 1
), merge2 as (
    select distinct merge.*
    from crunch
             inner join merge on crunch.osm_id = merge.osm_id
)
update osm.osm_road as osm
set inferred_maxspeed = merge2.inferred_maxspeed,
    inference_type = 'spatial pass 3'
from merge2
where osm.osm_id = merge2.osm_id
;

-- add 50 km/h to residential streets with no speed limit -- 357,085 rows
update osm.osm_road
    set inferred_maxspeed = 50,
        inference_type = 'residential'
where inferred_maxspeed is null
    and type = 'residential'
;


-- -- 872708
-- select inference_type,
--        type,
--        count(*)
-- from osm.osm_road
-- group by inference_type, type
-- order by inference_type, type
-- ;
--
-- -- 98812
-- select count(*)
-- from osm.osm_road
-- where inferred_maxspeed is null
--   and type not in ('service', 'unclassified', 'busway', 'living_street')
-- ;
--
-- select type,
--        count(*)
-- from osm.osm_road
-- where inferred_maxspeed is null
-- group by type
-- order by type
-- ;
--
-- select type,
--        junction,
--        count(*)
-- from osm.osm_road
-- where inferred_maxspeed is null
-- group by type, junction
-- order by type, junction
-- ;



-- and type not in ('service', 'unclassified', 'residential', 'busway', 'living_street')



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
       inferred_maxspeed,
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



