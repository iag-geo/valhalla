
-- STEP 1 - get map matched points and the point closest to the map matched route (points aren't ON the line)
DROP TABLE IF EXISTS temp_line_point;
CREATE TEMPORARY TABLE temp_line_point AS
SELECT DISTINCT pnt.trip_id,
                pnt.point_index,
                pnt.search_radius,
                pnt.point_type,
                pnt.geom AS geomA,
                ST_ClosestPoint(trip.geom, pnt.geom) AS geomB
FROM testing.valhalla_map_match_point AS pnt
    INNER JOIN testing.valhalla_map_match_shape AS trip ON trip.trip_id = pnt.trip_id
    AND trip.search_radius = pnt.search_radius
WHERE pnt.point_type = 'matched'
;
ANALYSE temp_line_point;

-- STEP 2 - calc bearing, reverse bearing and distance for extending a line beyond the 2 points we're interested in
DROP TABLE IF EXISTS temp_line_calc;
CREATE TEMPORARY TABLE temp_line_calc AS
SELECT trip_id,
       point_index,
       search_radius,
       point_type,
       geomA AS geom,
       ST_Azimuth(geomA, geomB) AS azimuthAB,
       ST_Azimuth(geomB, geomA) AS azimuthBA,
       ST_Distance(geomA, geomB) + 0.00001 AS dist
FROM temp_line_point
;
ANALYSE temp_line_calc;

-- STEP 3 - create a line that crosses the map matched route (to be used to split the matched routes)
DROP TABLE IF EXISTS testing.temp_split_line;
CREATE TABLE testing.temp_split_line AS
SELECT DISTINCT trip_id,
                point_index,
                search_radius,
                point_type,
                ST_MakeLine(ST_Translate(geom, sin(azimuthBA) * 0.00001, cos(azimuthBA) * 0.00001),
                    ST_Translate(geom, sin(azimuthAB) * dist, cos(azimuthAB) * dist))::geometry(Linestring, 4326) AS geom
FROM temp_line_calc
;
ANALYSE testing.temp_split_line;

DROP TABLE IF EXISTS temp_line_calc;
DROP TABLE IF EXISTS temp_line_point;

-- STEP 4 - split the matched routes into a new table
DROP TABLE IF EXISTS testing.temp_split_shape;
CREATE TABLE testing.temp_split_shape AS
WITH blade AS (
    SELECT trip_id,
           search_radius,
           st_collect(geom) AS geom
    FROM testing.temp_split_line
    GROUP BY trip_id,
             search_radius
), split AS (
    SELECT trip.trip_id,
           trip.search_radius,
           st_split(trip.geom, blade.geom) AS geom
    FROM testing.valhalla_map_match_shape AS trip
             INNER JOIN blade ON trip.trip_id = blade.trip_id
        AND trip.search_radius = blade.search_radius
), lines AS (
    SELECT trip_id,
           search_radius,
           (ST_Dump(geom)).path[1] AS segment_index,
           (ST_Dump(geom)).geom    AS geom
    FROM split
)
SELECT trip_id,
       search_radius,
       segment_index,
       st_length(geom::geography) AS distance_m,
       st_npoints(geom) AS point_count,
       'map match'::text AS segment_type,
       geom
FROM lines
;
ANALYSE testing.temp_split_shape;

ALTER TABLE testing.temp_split_shape
    ADD CONSTRAINT temp_split_shape_pkey PRIMARY KEY (trip_id, search_radius, segment_index);
CREATE INDEX temp_split_shape_geom_idx ON testing.temp_split_shape USING gist (geom);
ALTER TABLE testing.temp_split_shape CLUSTER ON temp_split_shape_geom_idx;

-- -- testing
-- SELECT * FROM testing.temp_split_shape
-- WHERE trip_id = 'F93947BB-AECD-48CC-A0B7-1041DFB28D03'
--   and search_radius = 60
-- ;

-- STEP 5 - get start and end points of segments that need to be routed (length > 1km)
-- TODO: allow for the possible(?) scenario where 2 routes are done back to back, when 1 long one should be created.
--   Check for end point = the next start point
DROP TABLE IF EXISTS testing.temp_route_this;
CREATE TABLE testing.temp_route_this AS
WITH pnt AS (
    SELECT trip_id,
           search_radius,
           segment_index,
           distance_m,
           point_count,
           st_startpoint(geom) AS start_geom,
           st_endpoint(geom)   AS end_geom
    FROM testing.temp_split_shape
    WHERE distance_m > 400.0
)
SELECT *,
       st_y(start_geom) AS start_lat,
       st_x(start_geom) AS start_lon,
       st_y(end_geom) AS end_lat,
       st_x(end_geom) AS end_lon
FROM pnt
;
ANALYSE testing.temp_route_this;


DROP TABLE IF EXISTS temp_split_line;

