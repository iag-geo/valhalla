
-- STEP 1 - create map matched shape based on edge table indexes
INSERT INTO testing.valhalla_map_match_shape
WITH shape AS (
    SELECT pnt.trip_id,
           pnt.search_radius,
           pnt.gps_accuracy,
           edge.begin_shape_index,
           edge.end_shape_index,
           edge.edge_index,
--            edge.osm_id,
--            edge.names,
           edge.road_class,
--            edge.speed,
--            edge.traversability,
--            edge.use,
           st_makeline(pnt.geom ORDER BY pnt.shape_index) AS geom
    FROM testing.valhalla_map_match_shape_point AS pnt
    INNER JOIN testing.valhalla_map_match_edge AS edge ON pnt.trip_id = edge.trip_id
        AND pnt.search_radius = edge.search_radius
        AND pnt.gps_accuracy = edge.gps_accuracy
        AND pnt.shape_index between begin_shape_index and edge.end_shape_index
    GROUP BY pnt.trip_id,
             pnt.search_radius,
             pnt.gps_accuracy,
             edge.begin_shape_index,
             edge.end_shape_index,
             edge.edge_index,
--              edge.osm_id,
--              edge.names,
             edge.road_class,
--              edge.speed,
--              edge.traversability,
--              edge.use,
             pnt.search_radius,
             pnt.gps_accuracy
)
SELECT shape.trip_id,
       shape.search_radius,
       shape.gps_accuracy,
--        true::boolean as use_segment,
       shape.begin_shape_index,
       shape.end_shape_index,
       shape.edge_index,
--        shape.osm_id,
--        shape.names,
       shape.road_class,
--        shape.speed,
--        shape.traversability,
--        shape.use,
       st_length(shape.geom::geography) AS distance_m,
       shape.geom
FROM shape
;
ANALYSE testing.valhalla_map_match_shape;

-- delete bad map match segments
-- UPDATE testing.valhalla_map_match_shape AS shape
--     SET use_segment = false
-- FROM testing.valhalla_map_match_point as pnt2
DELETE FROM testing.valhalla_map_match_shape AS shape
USING testing.valhalla_map_match_point as pnt2
WHERE shape.trip_id = pnt2.trip_id
    AND shape.search_radius = pnt2.search_radius
    AND shape.gps_accuracy = pnt2.gps_accuracy
    AND shape.edge_index = pnt2.edge_index
    AND pnt2.edge_index > 0
;
ANALYSE testing.valhalla_map_match_shape;


-- STEP 2 - get start and end points of segments to be routed
INSERT INTO testing.valhalla_route_this
WITH trip AS (
    SELECT trip_id,
           search_radius,
           gps_accuracy,
           edge_index AS begin_edge_index,
           lead(edge_index) OVER (PARTITION BY trip_id, search_radius, gps_accuracy ORDER BY edge_index) AS end_edge_index,
           end_shape_index AS begin_shape_index,
           lead(begin_shape_index) OVER (PARTITION BY trip_id, search_radius, gps_accuracy ORDER BY edge_index) AS end_shape_index,
           st_endpoint(geom) as start_geom,
           st_startpoint(lead(geom) OVER (PARTITION BY trip_id, search_radius, gps_accuracy ORDER BY begin_shape_index)) AS end_geom
    FROM testing.valhalla_map_match_shape
--     WHERE use_segment
)
SELECT trip_id,
       search_radius,
       gps_accuracy,
       begin_edge_index + 1 AS begin_edge_index,  -- correct value to edge index(es) to route
       end_edge_index - 1 AS end_edge_index,  -- correct value to edge index(es) to route
       begin_shape_index,
       end_shape_index,
       st_y(start_geom) AS start_lat,
       st_x(start_geom) AS start_lon,
       st_y(end_geom)   AS end_lat,
       st_x(end_geom)   AS end_lon,
       start_geom,
       end_geom
FROM trip
WHERE end_edge_index - begin_edge_index > 1
--     AND trip_id = '9113834E-158F-4328-B5A4-59B3A5D4BEFC'
--   and search_radius = 7.5
--   and gps_accuracy = 7.5
;
ANALYSE testing.valhalla_route_this;


-- select * from testing.valhalla_route_this
-- where search_radius = 15
--   and gps_accuracy = 7.5
-- ;


-- need to add a route at the start if first map matched segment doesn't start at the first waypoint
INSERT INTO testing.valhalla_route_this
WITH pnt AS (
    SELECT trip_id,
           geom
    FROM testing.waypoint
    WHERE point_index = 0
), trip AS (
    SELECT trip_id,
           search_radius,
           gps_accuracy,
           geom
    FROM testing.valhalla_map_match_shape_point
    WHERE shape_index = 0
), merge AS (
    SELECT trip.trip_id,
           search_radius,
           gps_accuracy,
           pnt.geom AS start_geom,
           trip.geom AS end_geom,
           st_distance(pnt.geom::geography, trip.geom::geography) AS distance_m
    FROM pnt
             INNER JOIN trip ON pnt.trip_id = trip.trip_id
)
SELECT trip_id,
       search_radius,
       gps_accuracy,
       -1 AS begin_edge_index,
       -1 AS end_edge_index,
       -1 AS begin_shape_index,
       0 AS end_shape_index,
       st_y(start_geom) AS start_lat,
       st_x(start_geom) AS start_lon,
       st_y(end_geom)   AS end_lat,
       st_x(end_geom)   AS end_lon,
       start_geom,
       end_geom
FROM merge
WHERE distance_m > 50
;
ANALYSE testing.valhalla_route_this;
