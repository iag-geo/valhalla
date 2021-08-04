
-- create table of routed segments and unrouted, map matched segments
DROP TABLE IF EXISTS testing.temp_valhalla_segments;
CREATE TABLE testing.temp_valhalla_segments AS
SELECT * FROM testing.valhalla_route_shape
;
ANALYSE testing.temp_valhalla_segments;

-- create primary key to ensure uniqueness
ALTER TABLE testing.temp_valhalla_segments
    ADD CONSTRAINT temp_valhalla_segments_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy, begin_edge_index, end_edge_index);

-- CREATE UNIQUE INDEX temp_valhalla_segments_end_shape_index_idx ON testing.temp_valhalla_segments USING btree (trip_id, search_radius, gps_accuracy, end_shape_index);

-- Add map matched segments that haven't been fixed by routed
INSERT INTO testing.temp_valhalla_segments
SELECT temp.trip_id,
       temp.search_radius,
       temp.gps_accuracy,
       temp.edge_index AS begin_edge_index,
       temp.edge_index AS end_edge_index,
       temp.begin_shape_index,
       temp.end_shape_index,
       temp.distance_m,
       st_numpoints(temp.geom) as point_count,
       'map match' AS segment_type,
       temp.geom
FROM testing.valhalla_map_match_shape AS temp
INNER JOIN testing.temp_valhalla_segments AS seg ON seg.trip_id = temp.trip_id
    AND seg.search_radius = temp.search_radius
    AND seg.gps_accuracy = temp.gps_accuracy
    AND temp.edge_index NOT BETWEEN seg.begin_edge_index AND seg.end_edge_index
;
ANALYSE testing.temp_valhalla_segments;

CREATE INDEX temp_valhalla_segments_geom_idx ON testing.temp_valhalla_segments USING gist (geom);
ALTER TABLE testing.temp_valhalla_segments CLUSTER ON temp_valhalla_segments_geom_idx;


-- stitch each route into a single linestring
DROP TABLE IF EXISTS testing.valhalla_final_route CASCADE;
CREATE TABLE testing.valhalla_final_route AS
WITH stats AS (
    SELECT trip_id,
           search_radius,
           gps_accuracy,
           sum(CASE WHEN segment_type = 'map match' THEN 1 ELSE 0 END) AS map_match_segments,
           sum(CASE WHEN segment_type = 'map match' THEN distance_m ELSE 0.0 END) / 1000.0 AS map_match_distance_km,
           sum(CASE WHEN segment_type = 'route' THEN 1 ELSE 0 END) AS route_segments,
           sum(CASE WHEN segment_type = 'route' THEN distance_m ELSE 0.0 END) / 1000.0 AS route_distance_km,
           st_collect(geom ORDER BY begin_edge_index) AS geom
    FROM testing.temp_valhalla_segments
    GROUP BY trip_id,
             search_radius,
             gps_accuracy
)
SELECT trip_id,
       row_number() over (PARTITION BY trip_id ORDER BY (map_match_distance_km + route_distance_km)) AS rank,
       search_radius,
       gps_accuracy,
       map_match_segments + route_segments AS total_segments,
       (map_match_distance_km + route_distance_km)::numeric(8, 3) AS total_distance_km,
       (map_match_distance_km / (map_match_distance_km + route_distance_km) * 100.0)::numeric(4, 1) AS map_match_percent,
       map_match_segments,
       map_match_distance_km::numeric(8, 3) AS map_match_distance_km,
       route_segments,
       route_distance_km::numeric(8, 3) AS route_distance_km,
       0.0::double precision AS rmse_km,
       0::integer AS waypoint_count,
       st_numpoints(geom) as point_count,
       geom
FROM stats
;
ANALYSE testing.valhalla_final_route;

ALTER TABLE testing.valhalla_final_route
    ADD CONSTRAINT valhalla_final_route_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy);
CREATE INDEX valhalla_final_route_geom_idx ON testing.valhalla_final_route USING gist (geom);
ALTER TABLE testing.valhalla_final_route CLUSTER ON valhalla_final_route_geom_idx;


-- Calculate root mean square of distance from each waypoint to the final route
--   As a proxy for reliability of both the input GPS points and the final route
WITH merge AS (
    SELECT trip.trip_id,
           trip.search_radius,
           trip.gps_accuracy,
           st_distance( pnt.geom::geography, ST_ClosestPoint(trip.geom, pnt.geom)::geography) / 1000.0 AS route_point_distance_m
    FROM testing.valhalla_final_route AS trip
    INNER JOIN testing.waypoint AS pnt ON trip.trip_id = pnt.trip_id
), stats AS (
    SELECT trip_id,
           search_radius,
           gps_accuracy,
           sqrt(sum(pow(route_point_distance_m, 2)))::numeric(8, 3) AS rmse_km,
           count(*) as waypoint_count
    FROM merge
    GROUP BY trip_id,
             search_radius,
             gps_accuracy
)
UPDATE testing.valhalla_final_route as route
    SET rmse_km = stats.rmse_km,
        waypoint_count = stats.waypoint_count
FROM stats
WHERE route.trip_id = stats.trip_id
  AND route.search_radius = stats.search_radius
  AND route.gps_accuracy = stats.gps_accuracy
;



DROP VIEW IF EXISTS testing.vw_valhalla_final_route;
CREATE VIEW testing.vw_valhalla_final_route AS
SELECT *
FROM testing.valhalla_final_route
WHERE rank = 1
;





-- DROP TABLE IF EXISTS testing.temp_split_shape;


-- -- 1344 test rows
-- SELECT count(*) FROM testing.temp_split_shape;
-- SELECT count(*) FROM testing.temp_valhalla_segments;



-- select *
-- --        geometrytype(geom)
-- from testing.valhalla_final_route
-- order by trip_id,
--          search_radius,
--          gps_accuracy;
