
-- create table of routed segments and unrouted, map matched segments
DROP TABLE IF EXISTS testing.valhalla_segments;
CREATE TABLE testing.valhalla_segments AS
SELECT * FROM testing.valhalla_route_shape
;
ANALYSE testing.valhalla_segments;

-- create primary key to ensure uniqueness
ALTER TABLE testing.valhalla_segments
    ADD CONSTRAINT valhalla_segments_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy, segment_index);

-- Add map matched segments that haven't been fixed by routed
INSERT INTO testing.valhalla_segments
SELECT * FROM testing.temp_split_shape AS temp
WHERE NOT EXISTS(
        SELECT trip_id,
               search_radius,
               gps_accuracy,
               segment_index
        FROM testing.valhalla_segments AS seg
        WHERE seg.trip_id = temp.trip_id
          AND seg.search_radius = temp.search_radius
          AND seg.gps_accuracy = temp.gps_accuracy
          AND seg.segment_index = temp.segment_index
    )
;
ANALYSE testing.valhalla_segments;

CREATE INDEX valhalla_segments_geom_idx ON testing.valhalla_segments USING gist (geom);
ALTER TABLE testing.valhalla_segments CLUSTER ON valhalla_segments_geom_idx;


-- -- add new start point to a route segment where Valhalla used a different start point to the previous map matched end point
-- WITH seg AS (
--     SELECT trip_id,
--            search_radius,
--            gps_accuracy,
--            segment_index,
--            distance_m,
--            point_count,
--            segment_type,
--            st_endpoint(lag(geom) OVER (PARTITION BY trip_id, search_radius, gps_accuracy ORDER BY segment_index))
--                AS previous_end_geom
--     FROM testing.valhalla_segments
-- )
-- UPDATE testing.valhalla_segments as rte
--     SET geom = st_addpoint(rte.geom, seg.previous_end_geom, 0),
--         distance_m = st_length(st_addpoint(rte.geom, seg.previous_end_geom, 0)::geography),
--         point_count = rte.point_count + 1
-- FROM seg
-- WHERE rte.trip_id = seg.trip_id
--   AND rte.search_radius = seg.search_radius
--   AND rte.gps_accuracy = seg.gps_accuracy
--   AND rte.segment_index = seg.segment_index
--   AND seg.segment_type = 'route'
--   AND seg.segment_index > 0
-- ;
-- ANALYSE testing.valhalla_segments;
--
--
-- -- add new end point to a route segment where Valhalla used a different end point to the next map matched start point
-- WITH seg AS (
--     SELECT trip_id,
--            search_radius,
--            gps_accuracy,
--            segment_index,
--            distance_m,
--            point_count,
--            segment_type,
--            st_startpoint(lead(geom) OVER (PARTITION BY trip_id, search_radius, gps_accuracy ORDER BY segment_index))
--                AS next_start_geom
--     FROM testing.valhalla_segments
-- )
-- UPDATE testing.valhalla_segments as rte
-- SET geom = st_addpoint(rte.geom, seg.next_start_geom),
--     distance_m = st_length(st_addpoint(rte.geom, seg.next_start_geom)::geography),
--     point_count = rte.point_count + 1
-- FROM seg
-- WHERE rte.trip_id = seg.trip_id
--   AND rte.search_radius = seg.search_radius
--   AND rte.gps_accuracy = seg.gps_accuracy
--   AND rte.segment_index = seg.segment_index
--   AND seg.segment_type = 'route'
--   AND seg.segment_index < 999999
-- ;
-- ANALYSE testing.valhalla_segments;


-- stitch each route into a single linestring
-- remove duplicate points by grouping them by ~1m
-- TODO: merge into single linestrings?
-- TODO: fix gaps between map match and route segments
DROP TABLE IF EXISTS testing.valhalla_final_route;
CREATE TABLE testing.valhalla_final_route AS
WITH stats AS (
    SELECT trip_id,
           search_radius,
           gps_accuracy,
           sum(CASE WHEN segment_type = 'map match' THEN 1 ELSE 0 END) AS map_match_segments,
           sum(CASE WHEN segment_type = 'map match' THEN distance_m ELSE 0.0 END) / 1000.0 AS map_match_distance_km,
           sum(CASE WHEN segment_type = 'route' THEN 1 ELSE 0 END) AS route_segments,
           sum(CASE WHEN segment_type = 'route' THEN distance_m ELSE 0.0 END) / 1000.0 AS route_distance_km
    FROM testing.valhalla_segments
    GROUP BY trip_id,
             search_radius,
             gps_accuracy
), pnt AS (
    SELECT trip_id,
           search_radius,
           gps_accuracy,
           segment_index,
           (ST_DumpPoints(geom)).path[1] AS point_id,
           (ST_DumpPoints(geom)).geom AS geom
    FROM testing.valhalla_segments
), pnt2 AS (
    SELECT row_number() OVER (PARTITION BY trip_id ORDER BY segment_index, point_id) AS point_index,
           *
    FROM pnt
), pnt3 AS (
    SELECT max(point_index) AS point_index,
           trip_id,
           search_radius,
           gps_accuracy,
           st_centroid(st_collect(geom)) AS geom
    FROM pnt2
    GROUP BY trip_id,
             search_radius,
             gps_accuracy,
             st_y(geom)::numeric(7, 5),
             st_x(geom)::numeric(8, 5)
)
SELECT stats.trip_id,
       stats.search_radius,
       stats.gps_accuracy,
       map_match_segments,
       map_match_distance_km,
       route_segments,
       route_distance_km,
       st_setsrid(st_makeline(pnt3.geom ORDER BY point_index), 4326) AS geom
FROM stats
INNER JOIN pnt3 ON stats.trip_id = pnt3.trip_id
    AND stats.search_radius = pnt3.search_radius
    AND stats.gps_accuracy = pnt3.gps_accuracy
GROUP BY stats.trip_id,
         stats.search_radius,
         stats.gps_accuracy,
         map_match_segments,
         map_match_distance_km,
         route_segments,
         route_distance_km
;
ANALYSE testing.valhalla_final_route;

ALTER TABLE testing.valhalla_final_route
    ADD CONSTRAINT valhalla_final_route_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy);
CREATE INDEX valhalla_final_route_geom_idx ON testing.valhalla_final_route USING gist (geom);
ALTER TABLE testing.valhalla_final_route CLUSTER ON valhalla_final_route_geom_idx;


-- -- 1344 test rows
-- SELECT count(*) FROM testing.temp_split_shape;
-- SELECT count(*) FROM testing.valhalla_segments;

-- DROP TABLE IF EXISTS testing.temp_split_shape;

-- select *,
--        geometrytype(geom)
-- from testing.valhalla_final_route
-- order by trip_id,
--          search_radius,
--          gps_accuracy;




-- -- add interpolated segments where a route segment used a different start point to the prevsious map matched end point
-- INSERT INTO testing.valhalla_segments
-- WITH seg AS (
--     SELECT trip_id,
--            search_radius,
--            gps_accuracy,
--            segment_index,
--            distance_m,
--            point_count,
--            segment_type,
--            st_endpoint(lag(geom) OVER (PARTITION BY trip_id, search_radius, gps_accuracy ORDER BY segment_index)) as previous_end_geom,
--            st_startpoint(geom) as start_geom,
--     FROM testing.valhalla_segments
-- )
-- SELECT trip_id,
--        search_radius,
--        gps_accuracy,
--        segment_index + 99999 AS segment_index,
--        st_distance(previous_end_geom::geography, start_geom::geography) AS distance_m,
--        2 AS point_count,
--        'interpolated' AS segment_type,
--        st_setsrid(st_makeLine(previous_end_geom,start_geom), 4326) AS geom
-- FROM seg
-- WHERE segment_type = 'route'
--   AND NOT st_equals(previous_end_geom, start_geom)
-- ;
-- ANALYSE testing.valhalla_segments;
