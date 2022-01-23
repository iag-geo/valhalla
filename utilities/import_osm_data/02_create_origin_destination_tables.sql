
-- create tables of OSM polygon and point features (in single tables) based on a theme or feature class

-- AMENITIES

-- create amenities tables for service stations, schools, hospitals, ...
-- add polygons
DROP TABLE IF EXISTS osm.osm_amenity CASCADE;
CREATE TABLE osm.osm_amenity AS
select 'polygon-' || osm_id::text as osm_id,
       name,
       brand,
       operator,
       amenity as type,
       st_collect(st_transform(way, 4326)) as geom
from osm.planet_osm_polygon
where amenity is not null and osm_id > 0
group by osm_id,
         name,
         brand,
         operator,
         amenity;
ALTER TABLE osm.osm_amenity OWNER TO postgres;

-- create temp tables of points and buffers to speed up queries
DROP TABLE IF EXISTS temp_buffers;
CREATE TEMPORARY TABLE temp_buffers AS
select type,
       st_subdivide(st_transform(st_buffer(geom::geography, 5.0)::geometry, 4326), 512) as geom
from osm.osm_amenity;
analyse temp_buffers;
CREATE INDEX temp_buffers_geom_idx ON temp_buffers USING GIST (geom);

DROP TABLE IF EXISTS temp_points;
CREATE TEMPORARY TABLE temp_points AS
SELECT 'point-' || osm_id::text as osm_id,
       name,
       brand,
       operator,
       amenity as type,
       st_transform(way, 4326) as geom
FROM osm.planet_osm_point
WHERE amenity is not null and osm_id > 0;
analyse temp_points;

-- only insert points that aren't within 5m of a polygon
INSERT INTO osm.osm_amenity
with merge as (
    select temp_points.osm_id,
           temp_points.type  as point_type,
           temp_buffers.type as buffer_type
    from temp_points
             inner join temp_buffers on st_intersects(temp_points.geom, temp_buffers.geom)
        and temp_points.type = temp_buffers.type
)
SELECT *
FROM temp_points
WHERE osm_id NOT IN (SELECT osm_id FROM merge)
;

DROP TABLE IF EXISTS temp_points;
DROP TABLE IF EXISTS temp_buffers;

ALTER TABLE osm.osm_amenity ADD PRIMARY KEY (osm_id);
CREATE INDEX osm_amenity_type_idx ON osm.osm_amenity USING btree (type);
CREATE INDEX osm_amenity_geom_idx ON osm.osm_amenity USING GIST (geom);
ALTER TABLE osm.osm_amenity CLUSTER ON osm_amenity_geom_idx;

-- add geography column
ALTER TABLE osm.osm_amenity ADD COLUMN geog geography;
UPDATE osm.osm_amenity SET geog = geom::geography;
CREATE INDEX osm_amenity_geog_idx ON osm.osm_amenity USING GIST (geog);

ANALYSE osm.osm_amenity;

-- create view of schools, universities etc....
DROP VIEW IF EXISTS osm.vw_osm_education;
CREATE VIEW osm.vw_osm_education AS
SELECT * FROM osm.osm_amenity
WHERE type IN ('school', 'kindergarten', 'childcare', 'university');

-- petrol stations
DROP VIEW IF EXISTS osm.vw_osm_fuel;
CREATE VIEW osm.vw_osm_fuel AS
SELECT * FROM osm.osm_amenity
WHERE type = 'fuel';


-- SHOPS

-- add polygons
DROP TABLE IF EXISTS osm.osm_shop CASCADE;
CREATE TABLE osm.osm_shop AS
select 'polygon-' || osm_id::text as osm_id,
       name,
       brand,
       operator,
       shop as type,
       st_collect(st_transform(way, 4326)) as geom
from osm.planet_osm_polygon
where shop is not null and osm_id > 0
    and amenity is null
group by osm_id,
         name,
         brand,
         operator,
         shop;
ALTER TABLE osm.osm_shop OWNER TO postgres;

-- create temp tables of points and buffers to speed up queries
DROP TABLE IF EXISTS temp_buffers;
CREATE TEMPORARY TABLE temp_buffers AS
select type,
       st_subdivide(st_transform(st_buffer(geom::geography, 5.0)::geometry, 4326), 512) as geom
from osm.osm_shop;
analyse temp_buffers;
CREATE INDEX temp_buffers_geom_idx ON temp_buffers USING GIST (geom);

DROP TABLE IF EXISTS temp_points;
CREATE TEMPORARY TABLE temp_points AS
SELECT 'point-' || osm_id::text as osm_id,
       name,
       brand,
       operator,
       shop as type,
       st_transform(way, 4326) as geom
FROM osm.planet_osm_point
WHERE shop is not null and osm_id > 0
  and amenity is null
;
analyse temp_points;

-- only insert points that aren't within 5m of a polygon
INSERT INTO osm.osm_shop
with merge as (
    select temp_points.osm_id,
           temp_points.type  as point_type,
           temp_buffers.type as buffer_type
    from temp_points
             inner join temp_buffers on st_intersects(temp_points.geom, temp_buffers.geom)
        and temp_points.type = temp_buffers.type
)
SELECT *
FROM temp_points
WHERE osm_id NOT IN (SELECT osm_id FROM merge)
;

DROP TABLE IF EXISTS temp_points;
DROP TABLE IF EXISTS temp_buffers;

ALTER TABLE osm.osm_shop ADD PRIMARY KEY (osm_id);
CREATE INDEX osm_shop_type_idx ON osm.osm_shop USING btree (type);
CREATE INDEX osm_shop_geom_idx ON osm.osm_shop USING GIST (geom);
ALTER TABLE osm.osm_shop CLUSTER ON osm_shop_geom_idx;

-- add geography column
ALTER TABLE osm.osm_shop ADD COLUMN geog geography;
UPDATE osm.osm_shop SET geog = geom::geography;
CREATE INDEX osm_shop_geog_idx ON osm.osm_shop USING GIST (geog);

ANALYSE osm.osm_shop;


-- RAILWAY STATIONS

DROP TABLE IF EXISTS osm.osm_railway_station;
CREATE TABLE osm.osm_railway_station AS
with t1 as (
    select osm_id,
           name,
           brand,
           operator,
           public_transport as type,
           false as cbd_station,
           st_transform(way, 4326)              as geom
    from osm.planet_osm_polygon
    where (public_transport in ('station', 'platform') and osm_id > 0
            and coalesce(amenity, '') <> 'ferry_terminal'
            and coalesce(man_made, '') <> 'pier'
            and coalesce(highway, '') <> 'bus_stop')
        or (amenity ='parking' and osm_id > 0
            and lower(name) like '%railway station%')
),t2 as (
    select osm_id,
           name,
           brand,
           operator,
           railway as type,
           false as cbd_station,
           st_transform(way, 4326)     as geom
    from osm.planet_osm_polygon
    where (public_transport in ('station', 'platform') and osm_id > 0
        and coalesce(amenity, '') <> 'ferry_terminal'
        and coalesce(man_made, '') <> 'pier'
        and coalesce(highway, '') <> 'bus_stop')
       or (amenity ='parking' and osm_id > 0
        and lower(name) like '%railway station%')
), uni as (
    select *
    from t1
    union all
    select *
    from t2
), dist as (
    select distinct * from uni
)
select 'polygon-' || osm_id::text as osm_id,
       name,
       brand,
       operator,
       string_agg(type, ', ') as type,
       cbd_station,
       geom
from dist
group by osm_id,
         name,
         brand,
         operator,
         cbd_station,
         geom
;
ALTER TABLE osm.osm_railway_station OWNER TO postgres;

ANALYSE osm.osm_railway_station;

-- create temp tables of points and buffers to speed up queries
DROP TABLE IF EXISTS temp_buffers;
CREATE TEMPORARY TABLE temp_buffers AS
select type,
       st_subdivide(st_transform(st_buffer(geom::geography, 5.0)::geometry, 4326), 512) as geom
from osm.osm_railway_station;
analyse temp_buffers;
CREATE INDEX temp_buffers_geom_idx ON temp_buffers USING GIST (geom);

DROP TABLE IF EXISTS temp_points;
CREATE TABLE temp_points AS
with t1 as (
    select osm_id,
           name,
           brand,
           operator,
           public_transport        as type,
           false                   as cbd_station,
           st_transform(way, 4326) as geom
    from osm.planet_osm_point
    where (public_transport in ('station', 'platform') and osm_id > 0
        and coalesce(amenity, '') <> 'ferry_terminal'
        and coalesce(man_made, '') <> 'pier'
        and coalesce(highway, '') <> 'bus_stop')
       or (amenity ='parking' and osm_id > 0
        and lower(name) like '%railway station%')
),t2 as (
    select osm_id,
           name,
           brand,
           operator,
           railway                 as type,
           false                   as cbd_station,
           st_transform(way, 4326) as geom
    from osm.planet_osm_point
    where (public_transport in ('station', 'platform') and osm_id > 0
        and coalesce(amenity, '') <> 'ferry_terminal'
        and coalesce(man_made, '') <> 'pier'
        and coalesce(highway, '') <> 'bus_stop')
       or (amenity ='parking' and osm_id > 0
        and lower(name) like '%railway station%')
), uni as (
    select *
    from t1
    union all
    select *
    from t2
), dist as (
    select distinct * from uni
)
select 'point-' || osm_id::text as osm_id,
       name,
       brand,
       operator,
       string_agg(type, ', ') as type,
       cbd_station,
       geom
from dist
group by osm_id,
         name,
         brand,
         operator,
         cbd_station,
         geom
;

-- only insert points that aren't within 5m of a polygon
INSERT INTO osm.osm_railway_station
with merge as (
    select temp_points.osm_id
    from temp_points
             inner join temp_buffers on st_intersects(temp_points.geom, temp_buffers.geom)
)
SELECT *
FROM temp_points
WHERE osm_id NOT IN (SELECT osm_id FROM merge)
;

DROP TABLE IF EXISTS temp_points;
DROP TABLE IF EXISTS temp_buffers;

ALTER TABLE osm.osm_railway_station ADD PRIMARY KEY (osm_id);
CREATE INDEX osm_railway_station_type_idx ON osm.osm_railway_station USING btree (type);
CREATE INDEX osm_railway_station_geom_idx ON osm.osm_railway_station USING GIST (geom);
ALTER TABLE osm.osm_railway_station CLUSTER ON osm_railway_station_geom_idx;

-- add geography column
ALTER TABLE osm.osm_railway_station ADD COLUMN geog geography;
UPDATE osm.osm_railway_station SET geog = geom::geography;
CREATE INDEX osm_railway_station_geog_idx ON osm.osm_railway_station USING GIST (geog);

ANALYSE osm.osm_railway_station;

-- flag CBD stations so they can be ignored as driving destinations (low chance of that happening) -- 164
update osm.osm_railway_station as rail
    set cbd_station = true
from admin_bdys_202102.locality_bdys_analysis as loc
where st_intersects(st_transform(rail.geom, 4283), loc.geom)
    and loc.postcode in ('2000', '3000', '4000', '5000', '6000', '7000', '8000');

ANALYSE osm.osm_railway_station;


-- LAND USE

-- add polygons
DROP TABLE IF EXISTS osm.osm_landuse CASCADE;
CREATE TABLE osm.osm_landuse AS
select 'polygon-' || osm_id::text as osm_id,
       name,
       brand,
       operator,
       landuse as type,
       st_collect(st_transform(way, 4326)) as geom
from osm.planet_osm_polygon
where landuse is not null and osm_id > 0
  and osm_id not in (select split_part(osm_id, '-', 2)::bigint from osm.osm_amenity)
  and osm_id not in (select split_part(osm_id, '-', 2)::bigint from osm.osm_shop)
  and osm_id not in (select split_part(osm_id, '-', 2)::bigint from osm.osm_railway_station)
group by osm_id,
         name,
         brand,
         operator,
         landuse;
ALTER TABLE osm.osm_landuse OWNER TO postgres;

-- create temp tables of points and buffers to speed up queries
DROP TABLE IF EXISTS temp_buffers;
CREATE TEMPORARY TABLE temp_buffers AS
select type,
       st_subdivide(st_transform(st_buffer(geom::geography, 5.0)::geometry, 4326), 512) as geom
from osm.osm_landuse;
analyse temp_buffers;
CREATE INDEX temp_buffers_geom_idx ON temp_buffers USING GIST (geom);

DROP TABLE IF EXISTS temp_points;
CREATE TEMPORARY TABLE temp_points AS
SELECT 'point-' || osm_id::text as osm_id,
       name,
       brand,
       operator,
       landuse as type,
       st_transform(way, 4326) as geom
FROM osm.planet_osm_point
WHERE landuse is not null and osm_id > 0
  and osm_id not in (select split_part(osm_id, '-', 2)::bigint from osm.osm_amenity)
  and osm_id not in (select split_part(osm_id, '-', 2)::bigint from osm.osm_shop)
  and osm_id not in (select split_part(osm_id, '-', 2)::bigint from osm.osm_railway_station)
;
analyse temp_points;

-- only insert points that aren't within 5m of a polygon
INSERT INTO osm.osm_landuse
with merge as (
    select temp_points.osm_id,
           temp_points.type  as point_type,
           temp_buffers.type as buffer_type
    from temp_points
             inner join temp_buffers on st_intersects(temp_points.geom, temp_buffers.geom)
        and temp_points.type = temp_buffers.type
)
SELECT *
FROM temp_points
WHERE osm_id NOT IN (SELECT osm_id FROM merge)
;

DROP TABLE IF EXISTS temp_points;
DROP TABLE IF EXISTS temp_buffers;

ALTER TABLE osm.osm_landuse ADD PRIMARY KEY (osm_id);
CREATE INDEX osm_landuse_type_idx ON osm.osm_landuse USING btree (type);
CREATE INDEX osm_landuse_geom_idx ON osm.osm_landuse USING GIST (geom);
ALTER TABLE osm.osm_landuse CLUSTER ON osm_landuse_geom_idx;

-- add geography column
ALTER TABLE osm.osm_landuse ADD COLUMN geog geography;
UPDATE osm.osm_landuse SET geog = geom::geography;
CREATE INDEX osm_landuse_geog_idx ON osm.osm_landuse USING GIST (geog);

ANALYSE osm.osm_landuse;



-- create a set of non-overlapping geoms for all retail/shop polygons
DROP TABLE IF EXISTS osm.osm_retail_polygons;
CREATE TABLE osm.osm_retail_polygons AS
with polys as (
    select geom from osm.osm_shop where geometrytype(geom) in ('POLYGON', 'MULTIPOLYGON')
    union all
    select geom from osm.osm_landuse where type = 'retail'
), dump as (
    select (st_dump(st_union(geom))).geom as geom from polys
)
select row_number() over () as id, geom from dump
;
analyse osm.osm_retail_polygons;

ALTER TABLE osm.osm_retail_polygons ADD PRIMARY KEY (id);
CREATE INDEX osm_retail_polygons_geom_idx ON osm.osm_retail_polygons USING GIST (geom);
ALTER TABLE osm.osm_retail_polygons CLUSTER ON osm_retail_polygons_geom_idx;




-- create table to exclude CADLite property polygons where they represent a road or railway
DROP TABLE IF EXISTS osm.osm_line_filter;
CREATE TABLE osm.osm_line_filter AS
select 'railway'::text as class, * from osm.osm_railway
union
select 'road'::text as class, * from osm.osm_road
;

ANALYZE osm.osm_line_filter;

ALTER TABLE osm.osm_line_filter ADD PRIMARY KEY (osm_id);
CREATE INDEX osm_line_filter_type_idx ON osm.osm_line_filter USING btree (type);

CREATE INDEX osm_line_filter_geom_idx ON osm.osm_line_filter USING GIST (geom);
ALTER TABLE osm.osm_line_filter CLUSTER ON osm_line_filter_geom_idx;






-- select *
-- fromosm.planet_osm_polygon
-- where osm_id = '668646787';


-- select count(*),
--        amenity,
--        shop
-- fromosm.planet_osm_polygon
-- where amenity is not null
--   and shop is not null
-- group by amenity,
--          shop
-- order by amenity,
--          shop
-- ;

