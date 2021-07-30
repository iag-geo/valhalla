
-- create map matched shape based on edge table point indexes
DROP TABLE IF EXISTS testing.valhalla_map_match_shape;
CREATE TABLE testing.valhalla_map_match_shape AS
-- INSERT INTO testing.valhalla_map_match_shape
WITH shape AS (
    SELECT pnt.trip_id,
           edge.begin_shape_index,
           edge.end_shape_index,
           pnt.search_radius,
           pnt.gps_accuracy,
           edge.edge_index,
           edge.osm_id,
           edge.names,
           edge.road_class,
           edge.speed,
           edge.traversability,
           edge.use,
           st_makeline(pnt.geom ORDER BY shape_index) AS geom
    FROM testing.valhalla_map_match_shape_point AS pnt
             INNER JOIN testing.valhalla_map_match_edge AS edge ON pnt.trip_id = edge.trip_id
        AND pnt.search_radius = edge.search_radius
        AND pnt.gps_accuracy = edge.gps_accuracy
        AND pnt.shape_index >= edge.begin_shape_index
        AND pnt.shape_index <= edge.end_shape_index
    GROUP BY pnt.trip_id,
             edge.begin_shape_index,
             edge.end_shape_index,
             edge.edge_index,
             edge.osm_id,
             edge.names,
             edge.road_class,
             edge.speed,
             edge.traversability,
             edge.use,
             pnt.search_radius,
             pnt.gps_accuracy
)
SELECT trip_id,
       begin_shape_index,
       end_shape_index,
       search_radius,
       gps_accuracy,
       edge_index,
       osm_id,
       names,
       road_class,
       speed,
       traversability,
       use,
       st_length(geom::geography) AS distance_m,
       geom
FROM shape
;
ANALYSE testing.valhalla_map_match_shape;

ALTER TABLE testing.valhalla_map_match_shape
    ADD CONSTRAINT valhalla_map_match_shape_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy, begin_shape_index);
CREATE INDEX valhalla_map_match_shape_geom_idx ON testing.valhalla_map_match_shape USING gist (geom);
ALTER TABLE testing.valhalla_map_match_shape CLUSTER ON valhalla_map_match_shape_geom_idx;


-- -- create a single linestring
-- WITH pnt AS (
--     SELECT trip_id,
--            search_radius,
--            gps_accuracy,
--            begin_shape_index,
--            end_shape_index,
--            (ST_DumpPoints(geom)).path[1] AS point_id,
--            (ST_DumpPoints(geom)).geom    AS geom
--     FROM testing.valhalla_map_match_shape
-- )
-- SELECT trip_id,
--        search_radius,
--        gps_accuracy,
--        st_makeline(geom ORDER BY begin_shape_index, point_id) AS geom
-- FROM pnt
-- GROUP BY trip_id,
--          search_radius,
--          gps_accuracy
-- ;




-- select * from testing.valhalla_map_match_shape;


-- STEP 1 - get map matched points where the route goes off and back onto the street network
--    and also get the point closest to the map matched route (points aren't necessarily on the line...)
DROP TABLE IF EXISTS testing.temp_line_point;
CREATE TABLE testing.temp_line_point AS
WITH pnt AS (
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
), max_pnt AS (
    SELECT trip_id,
           search_radius,
           gps_accuracy,
           max(point_index) AS point_index
    FROM testing.valhalla_map_match_point
    GROUP BY trip_id,
             search_radius,
             gps_accuracy
-- ), trip as (
--     SELECT trip_id,
--            search_radius,
--            gps_accuracy,
--            st_union(geom) as geom
-- --            st_geometrytype(st_collect(geom))
--     FROM testing.valhalla_map_match_shape
--     GROUP BY trip_id,
--              search_radius,
--              gps_accuracy
) , merge AS (
    SELECT pnt.trip_id,
           pnt.point_index,
           trip.begin_shape_index,
           trip.end_shape_index,
           CASE
               WHEN (pnt.point_index = 0 AND point_type <> 'matched')
                   OR
                    (pnt.point_type = 'matched' AND (pnt.next_point_type <> 'matched' OR pnt.begin_route_discontinuity))
                   THEN 'start'
               ELSE 'end' END                   AS route_point_type,
           pnt.previous_point_type,
           pnt.point_type,
           pnt.next_point_type,
           pnt.search_radius,
           pnt.gps_accuracy,
--            trip.distance_m                      AS trip_distance_m,
           pnt.geom                             AS geom,
           ST_ClosestPoint(trip.geom, pnt.geom) AS trip_point_geom,
           trip.geom                            AS trip_geom
    FROM pnt
             INNER JOIN testing.valhalla_map_match_shape AS trip ON trip.trip_id = pnt.trip_id
        AND trip.search_radius = pnt.search_radius
        AND trip.gps_accuracy = pnt.gps_accuracy
             INNER JOIN max_pnt ON max_pnt.trip_id = pnt.trip_id
        AND max_pnt.search_radius = pnt.search_radius
        AND max_pnt.gps_accuracy = pnt.gps_accuracy
    WHERE (pnt.point_index = 0 AND point_type <> 'matched')                     -- the first trip point -- need to include if not matched
       OR (pnt.point_type = 'matched' AND
           (pnt.next_point_type <> 'matched' OR pnt.begin_route_discontinuity)) -- start points
       OR (pnt.point_index = max_pnt.point_index AND point_type <> 'matched')   -- the last trip point -- need to include if not matched
       OR (pnt.point_type = 'matched' AND
           (pnt.previous_point_type <> 'matched' OR pnt.end_route_discontinuity)) -- end points
), dist AS (
    SELECT *,
           ST_LineLocatePoint(trip_geom, trip_point_geom)          AS trip_point_percent,
           ST_Distance(geom::geography, trip_point_geom::geography) AS trip_point_distance
    FROM merge
    WHERE NOT (coalesce(previous_point_type, 'matched') <> 'matched'
        AND coalesce(next_point_type, 'matched') <> 'matched') -- filter out unwanted, isolated, matched points
), rank AS (
    SELECT row_number() OVER (PARTITION BY trip_id, search_radius, gps_accuracy, point_index
        ORDER BY trip_point_distance) AS rank,
           *
    FROM dist
)
SELECT row_number() OVER (PARTITION BY trip_id, search_radius, gps_accuracy
    ORDER BY point_index, route_point_type) AS row_id,
       *
FROM rank
WHERE rank = 1
;
ANALYSE testing.temp_line_point;



-- -- STEP 2 - calculate bearing, reverse bearing and distance to create a splitting line perpendicular to the trip at each waypoint
-- --   Determine the azimuth based on +/- 90 degrees from trip direction at each waypoint
-- DROP TABLE IF EXISTS temp_line_calc;
-- CREATE TEMPORARY TABLE temp_line_calc AS
-- WITH adjust AS (
--     SELECT *,
--            CASE WHEN trip_point_percent = 1.0 THEN trip_point_percent - 0.00011 ELSE
--                CASE WHEN trip_point_percent = 0.0 THEN trip_point_percent + 0.0001 ELSE trip_point_percent END
--            END AS trip_point_percent_fix
--     FROM testing.temp_line_point
--
-- ), az AS (
--     SELECT *,
--            ST_Azimuth(trip_point_geom,
--                ST_LineInterpolatePoint(trip_geom, trip_point_percent_fix + 0.0001)) + pi() / 2.0 AS line_azimuth
--     FROM adjust
-- --     WHERE trip_point_percent > 0.0
-- --         AND trip_point_percent < 0.9999 -- don't want start or end points of trip
-- ), fix AS ( -- fix azimuth if > 360 degrees (2 x Pi radians)
--     SELECT *,
--            CASE WHEN line_azimuth > pi() * 2.0 THEN line_azimuth - pi() * 2.0 ELSE line_azimuth END AS azimuthAB
--     FROM az
-- )
-- SELECT trip_id,
--        point_index,
--        begin_shape_index,
--        end_shape_index,
--        route_point_type,
--        search_radius,
--        gps_accuracy,
--        trip_point_percent,
--        trip_point_percent_fix,
--        geom,
--        azimuthAB,
--        CASE WHEN azimuthAB >= pi() THEN azimuthAB - pi() ELSE azimuthAB + pi() END AS azimuthBA,
--        ST_Distance(geom, trip_point_geom) + 0.00002 AS dist
-- FROM fix
-- ;
-- ANALYSE temp_line_calc;
--
--
-- -- STEP 3 - create the splitting lines that cross the map matched route
-- DROP TABLE IF EXISTS testing.temp_split_line;
-- CREATE TABLE testing.temp_split_line AS
-- SELECT DISTINCT trip_id,
--                 point_index,
--                 begin_shape_index,
--                 end_shape_index,
--                 route_point_type,
--                 search_radius,
--                 gps_accuracy,
--                 ST_MakeLine(ST_Translate(geom, sin(azimuthBA) * 0.00002, cos(azimuthBA) * 0.00002),
--                     ST_Translate(geom, sin(azimuthAB) * dist, cos(azimuthAB) * dist))::geometry(Linestring, 4326) AS geom
-- FROM temp_line_calc
-- ;
-- ANALYSE testing.temp_split_line;
--

-- select * from testing.temp_line_point;


-- select * from temp_line_calc;
--
-- select * from testing.temp_split_line;
--
--
--
-- -- STEP 4 - split the matched routes into a new table
-- DROP TABLE IF EXISTS testing.temp_split_shape;
-- CREATE TABLE testing.temp_split_shape AS
-- WITH blade AS (
--     SELECT trip_id,
--            search_radius,
--            gps_accuracy,
--            begin_shape_index,
--            st_collect(geom) AS geom
--     FROM testing.temp_split_line
--     GROUP BY trip_id,
--              search_radius,
--              gps_accuracy,
--              begin_shape_index
-- ), split AS (
--     SELECT trip.trip_id,
--            trip.begin_shape_index,
--            trip.end_shape_index,
--            trip.search_radius,
--            trip.gps_accuracy,
--            st_split(trip.geom, blade.geom) AS geom
--     FROM testing.valhalla_map_match_shape AS trip
--     INNER JOIN blade ON trip.trip_id = blade.trip_id
--         AND trip.search_radius = blade.search_radius
--         AND trip.gps_accuracy = blade.gps_accuracy
--         AND trip.begin_shape_index = blade.begin_shape_index
-- ), lines AS (
--     SELECT trip_id,
--            search_radius,
--            gps_accuracy,
--            begin_shape_index,
--            end_shape_index,
--            (ST_Dump(geom)).path[1] AS segment_index,
--            (ST_Dump(geom)).geom    AS geom
--     FROM split
-- )
-- SELECT trip_id,
--        search_radius,
--        gps_accuracy,
--        begin_shape_index,
--        end_shape_index,
--        segment_index,
--        st_length(geom::geography) AS distance_m,
--        st_npoints(geom)           AS point_count,
--        'map match'::text          AS segment_type,
--        geom
-- FROM lines
-- ;
-- ANALYSE testing.temp_split_shape;
--
-- ALTER TABLE testing.temp_split_shape
--     ADD CONSTRAINT temp_split_shape_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy, begin_shape_index, segment_index);
-- CREATE INDEX temp_split_shape_geom_idx ON testing.temp_split_shape USING gist (geom);
-- ALTER TABLE testing.temp_split_shape CLUSTER ON temp_split_shape_geom_idx;


-- STEP 5 - get start and end points of segments to be routed
--   Do this by flattening pairs of start & end points
-- TODO: add not matched trip start and end points
DROP TABLE IF EXISTS testing.temp_route_this;
CREATE TABLE testing.temp_route_this AS
WITH start_trip AS (
    select trip_id,
           begin_shape_index,
           search_radius,
           gps_accuracy,
           st_endpoint(lag(geom) OVER (PARTITION BY trip_id, search_radius, gps_accuracy ORDER BY begin_shape_index)) AS geom
    from testing.valhalla_map_match_shape
), end_trip AS (
    select trip_id,
           begin_shape_index,
           search_radius,
           gps_accuracy,
           st_endpoint(lead(geom) OVER (PARTITION BY trip_id, search_radius, gps_accuracy ORDER BY begin_shape_index)) AS geom
    from testing.valhalla_map_match_shape
), starts AS (
    SELECT pnt.trip_id,
           pnt.search_radius,
           pnt.gps_accuracy,
           pnt.point_index,
           lead(point_index) OVER (PARTITION BY pnt.trip_id, pnt.search_radius, pnt.gps_accuracy ORDER BY pnt.point_index) AS next_point_index,
           pnt.begin_shape_index,
           pnt.route_point_type,
           trip.geom
    FROM testing.temp_line_point AS pnt
             INNER JOIN start_trip AS trip
                        ON pnt.trip_id = trip.trip_id
                            AND pnt.search_radius = trip.search_radius
                            AND pnt.gps_accuracy = trip.gps_accuracy
                            AND pnt.begin_shape_index = trip.begin_shape_index
--     WHERE pnt.route_point_type = 'start'
), ends AS (
    SELECT pnt.trip_id,
           pnt.search_radius,
           pnt.gps_accuracy,
           pnt.point_index,
           lag(point_index) OVER (PARTITION BY pnt.trip_id, pnt.search_radius, pnt.gps_accuracy ORDER BY pnt.point_index) AS previous_point_index,
           pnt.end_shape_index,
           pnt.route_point_type,
           trip.geom
    FROM testing.temp_line_point AS pnt
             INNER JOIN end_trip AS trip
                        ON pnt.trip_id = trip.trip_id
                            AND pnt.search_radius = trip.search_radius
                            AND pnt.gps_accuracy = trip.gps_accuracy
                            AND pnt.begin_shape_index = trip.begin_shape_index
--     WHERE pnt.route_point_type = 'end'
)
-- select * from starts
-- union all
-- select * from ends;
SELECT starts.trip_id,
       starts.search_radius,
       starts.gps_accuracy,
--        row_number()
--        OVER (PARTITION BY starts.trip_id, starts.search_radius, starts.gps_accuracy ORDER BY starts.point_index) *
--        2                  AS segment_index,
       starts.point_index AS start_point_index,
       ends.point_index   AS end_point_index,
       starts.begin_shape_index,
       ends.end_shape_index,
--        st_distance(starts.geom::geography, ends.geom::geography) AS distance_m,
       st_y(starts.geom)  AS start_lat,
       st_x(starts.geom)  AS start_lon,
       st_y(ends.geom)    AS end_lat,
       st_x(ends.geom)    AS end_lon,
       starts.geom        AS start_geom,
       ends.geom          AS end_geom
FROM starts
         INNER JOIN ends ON starts.trip_id = ends.trip_id
            AND starts.search_radius = ends.search_radius
            AND starts.gps_accuracy = ends.gps_accuracy
            AND starts.next_point_index = ends.point_index
            AND starts.point_index = ends.previous_point_index
WHERE starts.route_point_type = 'start'
    AND ends.route_point_type = 'end'
;
ANALYSE testing.temp_route_this;


-- -- STEP 5 - get start and end points of segments to be routed
-- --   Do this by flattening pairs of start & end points
-- DROP TABLE IF EXISTS testing.temp_route_this;
-- CREATE TABLE testing.temp_route_this AS
-- WITH starts AS (
--     SELECT row_id,
--            trip_id,
--            search_radius,
--            gps_accuracy,
--            point_index,
--            geom
--     FROM testing.temp_line_point
--     WHERE route_point_type = 'start'
-- ), ends AS (
--     SELECT row_id,
--            trip_id,
--            search_radius,
--            gps_accuracy,
--            point_index,
--            geom
--     FROM testing.temp_line_point
--     WHERE route_point_type = 'end'
-- )
-- SELECT starts.trip_id,
--        starts.search_radius,
--        starts.gps_accuracy,
--        row_number()
--        OVER (PARTITION BY starts.trip_id, starts.search_radius, starts.gps_accuracy ORDER BY starts.point_index) *
--        2                  AS segment_index,
--        starts.point_index AS start_point_index,
--        ends.point_index   AS end_point_index,
-- --        st_distance(starts.geom::geography, ends.geom::geography) AS distance_m,
--        st_y(starts.geom)  AS start_lat,
--        st_x(starts.geom)  AS start_lon,
--        st_y(ends.geom)    AS end_lat,
--        st_x(ends.geom)    AS end_lon,
--        starts.geom        AS start_geom,
--        ends.geom          AS end_geom
-- FROM starts
--          INNER JOIN ends ON starts.trip_id = ends.trip_id
--     AND starts.search_radius = ends.search_radius
--     AND starts.gps_accuracy = ends.gps_accuracy
--     AND starts.row_id = ends.row_id - 1 -- get sequential pairs of start & end records
-- ;
-- ANALYSE testing.temp_route_this;


-- -- need to adjust segment indexes where first route segment is at the start of the trip
-- WITH fix AS (
--     SELECT trip_id,
--            search_radius,
--            gps_accuracy
--     FROM testing.temp_route_this
--     WHERE start_point_index = 0
-- )
-- UPDATE testing.temp_route_this AS route
-- SET segment_index = segment_index - 2
-- FROM fix
-- WHERE route.trip_id = fix.trip_id
--   AND route.search_radius = fix.search_radius
--   AND route.gps_accuracy = fix.gps_accuracy
-- ;
-- ANALYSE testing.temp_route_this;


-- select trip_id,
--        search_radius,
--        gps_accuracy,
--        segment_index,
--        distance_m,
-- --        point_count,
--        start_lat,
--        start_lon,
--        end_lat,
--        end_lon
-- from testing.temp_route_this;


select trip_id,
       search_radius,
       gps_accuracy,
       start_point_index,
       end_point_index,
       begin_shape_index,
       end_shape_index,
       start_lat,
       start_lon,
       end_lat,
       end_lon,
       start_geom,
       end_geom
from testing.temp_route_this
-- where trip_id = 'F93947BB-AECD-48CC-A0B7-1041DFB28D03'
where search_radius = 7.5
  and gps_accuracy = 7.5
order by trip_id,
         search_radius,
         gps_accuracy,
         start_point_index
;


-- select *
-- from testing.temp_line_point
-- where trip_id = 'F93947BB-AECD-48CC-A0B7-1041DFB28D03'
--   and search_radius = 7.5
--   and gps_accuracy = 15
-- order by point_index
-- ;

-- select row_id,
--        trip_id,
--        point_index,
--        route_point_type,
--        previous_point_type,
--        point_type,
--        next_point_type,
--        search_radius,
--        gps_accuracy,
--        trip_distance_m,
--        geom,
--        trip_point_geom,
--        trip_geom,
--        trip_point_percent
-- from testing.temp_line_point
-- where previous_point_type <> 'matched'
--     and next_point_type <> 'matched'
-- ;


-- DROP TABLE IF EXISTS testing.temp_split_line;
DROP TABLE IF EXISTS temp_line_calc;
-- DROP TABLE IF EXISTS testing.temp_line_point;
