
-- create table of routed segments and unrouted, map matched segments
INSERT INTO testing.valhalla_segment
SELECT * FROM testing.valhalla_route_shape
WHERE trip_id = '{0}'
;
ANALYSE testing.valhalla_segment;

-- Add map matched segments that haven't been fixed by routed
INSERT INTO testing.valhalla_segment
SELECT trip_id,
       search_radius,
       gps_accuracy,
       edge_index AS begin_edge_index,
       edge_index AS end_edge_index,
       begin_shape_index,
       end_shape_index,
       distance_m,
       st_npoints(geom) as point_count,
       'map match' AS segment_type,
       geom
FROM testing.valhalla_map_match_shape
WHERE trip_id = '{0}'
ON CONFLICT (trip_id, search_radius, gps_accuracy, begin_edge_index) DO NOTHING
;
ANALYSE testing.valhalla_segment;


-- stitch each route into a single linestring
INSERT INTO testing.valhalla_merged_route
WITH stats AS (
    SELECT trip_id,
           search_radius,
           gps_accuracy,
           sum(CASE WHEN segment_type = 'map match' THEN 1 ELSE 0 END) AS map_match_segments,
           sum(CASE WHEN segment_type = 'map match' THEN distance_m ELSE 0.0 END) / 1000.0 AS map_match_distance_km,
           sum(CASE WHEN segment_type = 'route' THEN 1 ELSE 0 END) AS route_segments,
           sum(CASE WHEN segment_type = 'route' THEN distance_m ELSE 0.0 END) / 1000.0 AS route_distance_km,
           st_collect(geom ORDER BY begin_edge_index) AS geom
    FROM testing.valhalla_segment
    WHERE trip_id = '{0}'
    GROUP BY trip_id,
             search_radius,
             gps_accuracy
)
SELECT trip_id,
       search_radius,
       gps_accuracy,
       map_match_segments + route_segments AS total_segments,
       map_match_distance_km + route_distance_km AS total_distance_km,
       (map_match_distance_km / (map_match_distance_km + route_distance_km) * 100.0)::numeric(4, 1) AS map_match_percent,
       map_match_segments,
       map_match_distance_km,
       route_segments,
       route_distance_km,
       0.0::double precision AS rmse_km,
       0.0::double precision AS waypoint_distance_ratio,
       0::integer AS waypoint_count,
       st_npoints(geom) as point_count,
       geom
FROM stats
;
ANALYSE testing.valhalla_merged_route;


-- create temp table of waypoint stats per trip
DROP TABLE IF EXISTS temp_waypoint_stats CASCADE;
CREATE TEMPORARY TABLE temp_waypoint_stats AS
SELECT trip_id,
       count(*) as waypoint_count,
       st_length(st_makeline(geom order by point_index)::geography) / 1000.0 AS waypoint_distance_km
FROM testing.waypoint
WHERE trip_id = '{0}'
GROUP BY trip_id
;
ANALYSE temp_waypoint_stats;

ALTER TABLE temp_waypoint_stats
    ADD CONSTRAINT temp_waypoint_stats_pkey PRIMARY KEY (trip_id);


-- Add waypoint stats to compare with final routes
UPDATE testing.valhalla_merged_route as route
    SET waypoint_count = stats.waypoint_count,
        waypoint_distance_ratio = route.total_distance_km / stats.waypoint_distance_km
FROM temp_waypoint_stats AS stats
WHERE route.trip_id = stats.trip_id
  AND route.trip_id = '{0}'
;
ANALYSE testing.valhalla_merged_route;

DROP TABLE temp_waypoint_stats;


-- Calculate RMSE in km for waypoints versus the closest point on the final route
--   ...as a proxy for reliability of both the input GPS points and the final route
WITH merge AS (
    SELECT trip.trip_id,
           trip.search_radius,
           trip.gps_accuracy,
           st_distance( pnt.geom::geography, ST_ClosestPoint(trip.geom, pnt.geom)::geography) / 1000.0 AS route_point_distance_km
    FROM testing.valhalla_merged_route AS trip
    INNER JOIN testing.waypoint AS pnt ON trip.trip_id = pnt.trip_id
    WHERE trip.trip_id = '{0}'
), stats AS (
    SELECT trip_id,
           search_radius,
           gps_accuracy,
           sqrt(sum(pow(route_point_distance_km, 2)))::numeric(8, 3) AS rmse_km
    FROM merge
    GROUP BY trip_id,
             search_radius,
             gps_accuracy
)
UPDATE testing.valhalla_merged_route as route
    SET rmse_km = stats.rmse_km
FROM stats
WHERE route.trip_id = stats.trip_id
  AND route.search_radius = stats.search_radius
  AND route.gps_accuracy = stats.gps_accuracy
;
ANALYSE testing.valhalla_merged_route;


-- insert "best result" for each trip -- in reality, no guarantee this route is good (due to GPS issues)
INSERT INTO testing.valhalla_final_route
WITH ranked AS (
    SELECT *,
           row_number() over (PARTITION BY trip_id ORDER BY total_distance_km) AS rank
    FROM testing.valhalla_merged_route
    WHERE rmse_km < 2.0
      AND trip_id = '{0}'
)
SELECT *
FROM ranked
WHERE rank = 1
;
