
-- STEP 1 - get map matched points where the route goes off and back onto the street network
--    and also get the point closest to the map matched route (points aren't necessarily on the line...)
DROP TABLE IF EXISTS temp_line_point;
CREATE TEMPORARY TABLE temp_line_point AS
WITH trip AS (
    SELECT trip_id,
           search_radius,
           gps_accuracy,
           distance_m,
           geom
--            ST_OffsetCurve(geom, 0.00001, 'quad_segs=0 join=bevel') AS geom
    FROM testing.valhalla_map_match_shape
), pnt AS (
    SELECT trip_id,
           search_radius,
           gps_accuracy,
           point_index,
           begin_route_discontinuity,
           end_route_discontinuity,
           lag(point_type)
               OVER (PARTITION BY trip_id, search_radius, gps_accuracy ORDER BY point_index) AS previous_point_type,
           point_type,
           lead(point_type)
               OVER (PARTITION BY trip_id, search_radius, gps_accuracy ORDER BY point_index) AS next_point_type,
           geom
    FROM testing.valhalla_map_match_point
), pnt2 AS (
    SELECT row_number()
        OVER (PARTITION BY pnt.trip_id, pnt.search_radius, pnt.gps_accuracy ORDER BY pnt.point_index) AS row_id,
           pnt.trip_id,
           pnt.point_index,
           CASE
               WHEN (pnt.point_type = 'matched' AND (pnt.next_point_type <> 'matched' OR pnt.begin_route_discontinuity))
                   THEN 'start'
               ELSE 'end' END                   AS route_point_type,
           pnt.search_radius,
           pnt.gps_accuracy,
           trip.distance_m                      AS trip_distance_m,
           pnt.geom                             AS geomA,
           ST_ClosestPoint(trip.geom, pnt.geom) AS trip_point_geom,
           trip.geom                            AS trip_geom
    FROM pnt
    INNER JOIN trip ON trip.trip_id = pnt.trip_id
        AND trip.search_radius = pnt.search_radius
        AND trip.gps_accuracy = pnt.gps_accuracy
    WHERE (pnt.point_type = 'matched' AND
           (pnt.next_point_type <> 'matched' OR pnt.begin_route_discontinuity)) -- start points
       OR (pnt.point_type = 'matched' AND
           (pnt.previous_point_type <> 'matched' OR pnt.end_route_discontinuity)) -- end points
)
SELECT *,
       ST_LineLocatePoint(trip_geom, trip_point_geom) AS trip_point_percent
FROM pnt2

;
ANALYSE temp_line_point;


-- select *
-- from temp_line_point
-- where trip_id = 'F93947BB-AECD-48CC-A0B7-1041DFB28D03'
-- --   and search_radius = 7.5
-- --   and gps_accuracy = 7.5
-- --   and st_equals(geomA, geomB)
-- order by trip_point_percent
-- ;

-- STEP 2 - calculate bearing, reverse bearing and distance to create a splitting line perpendicular to the trip at each waypoint
--   Determine the azimuth based on +/- 90 degrees from trip direction at each waypoint
DROP TABLE IF EXISTS temp_line_calc;
CREATE TEMPORARY TABLE temp_line_calc AS
WITH az AS (
    SELECT *,
           ST_Azimuth(trip_point_geom,
               ST_LineInterpolatePoint(trip_geom, trip_point_percent + 0.0001)) + pi() / 2.0 AS line_azimuth
    FROM temp_line_point
    WHERE trip_point_percent > 0.0
        AND trip_point_percent < 0.9999 -- don't want start or end points
), fix AS ( -- fix azimuth if > 360 degrees (2xPi radians)
    SELECT *,
           CASE WHEN line_azimuth > pi() * 2.0 THEN line_azimuth - pi() * 2.0 ELSE line_azimuth END AS azimuthAB
    FROM az
)
SELECT trip_id,
       point_index,
       route_point_type,
       search_radius,
       gps_accuracy,
       geomA AS geom,
       azimuthAB,
       CASE WHEN azimuthAB >= pi() THEN azimuthAB - pi() ELSE azimuthAB + pi() END AS azimuthBA,
       ST_Distance(geomA, trip_point_geom) + 0.00002 AS dist
FROM fix
;
ANALYSE temp_line_calc;


-- STEP 3 - create the splitting lines that cross the map matched route
DROP TABLE IF EXISTS testing.temp_split_line;
CREATE TABLE testing.temp_split_line AS
SELECT DISTINCT trip_id,
                point_index,
                route_point_type,
                search_radius,
                gps_accuracy,
                ST_MakeLine(ST_Translate(geom, sin(azimuthBA) * 0.00002, cos(azimuthBA) * 0.00002),
                    ST_Translate(geom, sin(azimuthAB) * dist, cos(azimuthAB) * dist))::geometry(Linestring, 4326) AS geom
FROM temp_line_calc
;
ANALYSE testing.temp_split_line;


-- STEP 4 - split the matched routes into a new table
DROP TABLE IF EXISTS testing.temp_split_shape;
CREATE TABLE testing.temp_split_shape AS
WITH blade AS (
    SELECT trip_id,
           search_radius,
           gps_accuracy,
           st_collect(geom) AS geom
    FROM testing.temp_split_line
    GROUP BY trip_id,
             search_radius,
             gps_accuracy
), split AS (
    SELECT trip.trip_id,
           trip.search_radius,
           trip.gps_accuracy,
           st_split(trip.geom, blade.geom) AS geom
    FROM testing.valhalla_map_match_shape AS trip
    INNER JOIN blade ON trip.trip_id = blade.trip_id
        AND trip.search_radius = blade.search_radius
        AND trip.gps_accuracy = blade.gps_accuracy
), lines AS (
    SELECT trip_id,
           search_radius,
           gps_accuracy,
           (ST_Dump(geom)).path[1] AS segment_index,
           (ST_Dump(geom)).geom    AS geom
    FROM split
)
SELECT trip_id,
       search_radius,
       gps_accuracy,
       segment_index,
       st_length(geom::geography) AS distance_m,
       st_npoints(geom) AS point_count,
       'map match'::text AS segment_type,
       geom
FROM lines
;
ANALYSE testing.temp_split_shape;

ALTER TABLE testing.temp_split_shape
    ADD CONSTRAINT temp_split_shape_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy, segment_index);
CREATE INDEX temp_split_shape_geom_idx ON testing.temp_split_shape USING gist (geom);
ALTER TABLE testing.temp_split_shape CLUSTER ON temp_split_shape_geom_idx;


-- -- testing
-- SELECT * FROM testing.temp_split_shape
-- WHERE trip_id = 'F93947BB-AECD-48CC-A0B7-1041DFB28D03'
--   and search_radius = 60
-- ;



-- New STEP 5 - add start and end records to temp_points where start or end isn't map matched.
--  then add to route input table



-- STEP 5 - get start and end points of segments to be routed


-- need to add

select *
from temp_line_point
order by trip_id,
         search_radius,
         gps_accuracy,
         point_index
;

select *
from testing.temp_split_line
order by trip_id,
         search_radius,
         gps_accuracy;



DROP TABLE IF EXISTS testing.temp_route_this;
CREATE TABLE testing.temp_route_this AS
WITH pnt AS (
    SELECT trip_id,
           search_radius,
           gps_accuracy,
           segment_index,
           distance_m,
           point_count,
           st_startpoint(geom) AS start_geom,
           st_endpoint(geom)   AS end_geom
    FROM testing.temp_split_shape
)
SELECT *,
       st_y(start_geom) AS start_lat,
       st_x(start_geom) AS start_lon,
       st_y(end_geom) AS end_lat,
       st_x(end_geom) AS end_lon
FROM pnt
;
ANALYSE testing.temp_route_this;


-- add start segments that aren't map matched (causes the entire route to be missing the first segment)
INSERT INTO testing.temp_route_this
WITH pnt AS (
    SELECT trip_id,
           geom
    FROM testing.waypoint
    WHERE point_index = 0
), merge AS (
    SELECT pnt.trip_id,
           search_radius,
           gps_accuracy,
           0::integer AS segment_index,
           st_distance(pnt.geom::geography, st_startpoint(shp.geom)::geography) AS distance_m,
           2::integer AS point_count,
           pnt.geom                                                             AS start_geom,
           st_startpoint(shp.geom)                                              AS end_geom
    FROM testing.valhalla_map_match_shape AS shp
             INNER JOIN pnt ON shp.trip_id = pnt.trip_id
)
SELECT *,
       st_y(start_geom) AS start_lat,
       st_x(start_geom) AS start_lon,
       st_y(end_geom) AS end_lat,
       st_x(end_geom) AS end_lon
FROM merge
WHERE distance_m > 50.0
;
ANALYSE testing.temp_route_this;


-- add end segments that aren't map matched (causes the entire route to be missing the last segment)
INSERT INTO testing.temp_route_this
WITH the_end AS (
    SELECT trip_id,
           max(point_index) AS point_index
    FROM testing.waypoint
    GROUP BY trip_id
), pnt AS (
    SELECT way.trip_id,
           way.geom
--            way.point_index
    FROM testing.waypoint as way
    INNER JOIN the_end ON way.trip_id = the_end.trip_id
        AND way.point_index = the_end.point_index
), merge AS (
    SELECT pnt.trip_id,
           search_radius,
           gps_accuracy,
--            point_index,
           999999::integer                                                    AS segment_index,
           st_distance(pnt.geom::geography, st_endpoint(shp.geom)::geography) AS distance_m,
           2::integer                                                         AS point_count,
           st_endpoint(shp.geom)                                              AS start_geom,
           pnt.geom                                                           AS end_geom
    FROM testing.valhalla_map_match_shape AS shp
             INNER JOIN pnt ON shp.trip_id = pnt.trip_id
)
SELECT *,
       st_y(start_geom) AS start_lat,
       st_x(start_geom) AS start_lon,
       st_y(end_geom) AS end_lat,
       st_x(end_geom) AS end_lon
FROM merge
WHERE distance_m > 50.0
;
ANALYSE testing.temp_route_this;


-- DROP TABLE IF EXISTS testing.temp_split_line;
DROP TABLE IF EXISTS temp_line_calc;
DROP TABLE IF EXISTS temp_line_point;
