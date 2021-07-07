
-- STEP 1 - get map matched points and the point closest to the map matched route (points aren't on the line)
DROP TABLE IF EXISTS temp_line_points;
CREATE TEMPORARY TABLE temp_line_points AS
SELECT DISTINCT pnt.trip_id,
                pnt.point_index,
                pnt.search_radius,
                pnt.point_type,
                pnt.geom AS geomA,
                ST_ClosestPoint(trip.geom, pnt.geom) AS geomB
FROM testing.valhalla_point AS pnt
    INNER JOIN testing.valhalla_shape as trip ON trip.trip_id = pnt.trip_id
    AND trip.search_radius = pnt.search_radius
WHERE pnt.point_type = 'matched'
;
ANALYSE temp_line_points;

-- STEP 2 - calc bearing, reverse bearing and distance for extending a line beyond the 2 points we're interested in
DROP TABLE IF EXISTS temp_line_calcs;
CREATE TEMPORARY TABLE temp_line_calcs AS
SELECT trip_id,
       point_index,
       search_radius,
       point_type,
       geomA AS geom,
       ST_Azimuth(geomA, geomB) AS azimuthAB,
       ST_Azimuth(geomB, geomA) AS azimuthBA,
       ST_Distance(geomA, geomB) + 0.00001 AS dist
FROM temp_line_points
;
ANALYSE temp_line_calcs;

-- STEP 3 - create a line that crosses the map matched route using maths YEAH! (to be used to split the matched routes)
DROP TABLE IF EXISTS testing.temp_split_lines;
CREATE TABLE testing.temp_split_lines AS
SELECT DISTINCT trip_id,
                point_index,
                search_radius,
                point_type,
                ST_MakeLine(ST_Translate(geom, sin(azimuthBA) * 0.00001, cos(azimuthBA) * 0.00001),
                    ST_Translate(geom, sin(azimuthAB) * dist, cos(azimuthAB) * dist))::geometry(Linestring, 4326) AS geom
FROM temp_line_calcs
;
ANALYSE testing.temp_split_lines;

DROP TABLE IF EXISTS temp_line_calcs;
DROP TABLE IF EXISTS temp_line_points;

-- STEP 4 - split the matched routes into a new table
DROP TABLE IF EXISTS testing.temp_split_shape;
CREATE TABLE testing.temp_split_shape AS
SELECT blade.trip_id,
       blade.point_index,
       blade.search_radius,
       blade.point_type,
       (ST_Dump(st_split(trip.geom, blade.geom))).geom as geom
from testing.valhalla_shape as trip
inner join testing.temp_split_lines as blade on trip.trip_id = blade.trip_id
    and trip.search_radius = blade.search_radius
    AND st_intersects(blade.geom, trip.geom)
;
ANALYSE testing.temp_split_shape;

-- ALTER TABLE testing.temp_split_shape ADD CONSTRAINT temp_split_shape_pkey PRIMARY KEY (trip_id, point_index, search_radius);
CREATE INDEX temp_split_shape_geom_idx ON testing.temp_split_shape USING gist (geom);
ALTER TABLE testing.temp_split_shape CLUSTER ON temp_split_shape_geom_idx;


select * from testing.temp_split_shape
where trip_id = 'F93947BB-AECD-48CC-A0B7-1041DFB28D03'
  and search_radius = 60
order by point_index
;





drop table if exists testing.temp_split_shape cascade;
create table testing.temp_split_shape as
with pnt as (
    select *
    from testing.valhalla_point
    where point_type = 'matched'
)
select trip.trip_id,
       pnt.point_index,
       trip.search_radius,
       pnt.point_type,
       trip.distance,
       st_split(trip.geom, ST_Snap(pnt.geom, trip.geom, 0.0001)) as geom
from testing.valhalla_shape as trip
inner join pnt on trip.trip_id = pnt.trip_id
and trip.search_radius = pnt.search_radius
;

alter table testing.temp_split_shape add constraint temp_split_shape_pkey primary key (trip_id, point_index, search_radius);
create index temp_split_shape_geom_idx on testing.temp_split_shape using gist (geom);
ALTER TABLE testing.temp_split_shape CLUSTER ON temp_split_shape_geom_idx;


select * from testing.temp_split_shape
where trip_id = 'F93947BB-AECD-48CC-A0B7-1041DFB28D03'
  and search_radius = 60
order by point_index
;


