
-- STEP 1 - create map matched shape based on edge table indexes
INSERT INTO temp_{0}_{1}_{2}_map_match_shape
WITH shape AS (
    SELECT edge.begin_shape_index,
           edge.end_shape_index,
           edge.edge_index,
--            edge.osm_id,
--            edge.names,
           edge.road_class,
--            edge.speed,
--            edge.traversability,
--            edge.use,
           st_makeline(pnt.geom ORDER BY pnt.shape_index) AS geom
    FROM temp_{0}_{1}_{2}_map_match_shape_point AS pnt
    INNER JOIN temp_{0}_{1}_{2}_map_match_edge AS edge
        ON pnt.shape_index between begin_shape_index and edge.end_shape_index
    GROUP BY edge.begin_shape_index,
             edge.end_shape_index,
             edge.edge_index,
--              edge.osm_id,
--              edge.names,
             edge.road_class
--              edge.speed,
--              edge.traversability,
--              edge.use
)
SELECT shape.begin_shape_index,
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
ANALYSE temp_{0}_{1}_{2}_map_match_shape;


-- delete bad map match segments
-- UPDATE temp_{0}_{1}_{2}_map_match_shape AS shape
--     SET use_segment = false
-- FROM temp_{0}_{1}_{2}_map_match_point as pnt2
DELETE FROM temp_{0}_{1}_{2}_map_match_shape AS shape
USING temp_{0}_{1}_{2}_map_match_point as pnt2
WHERE shape.edge_index = pnt2.edge_index
    AND pnt2.edge_index > 0
;
ANALYSE temp_{0}_{1}_{2}_map_match_shape;


-- STEP 2 - get start and end points of segments to be routed
INSERT INTO temp_{0}_{1}_{2}_route_this
WITH trip AS (
    SELECT edge_index AS begin_edge_index,
           lead(edge_index) OVER (ORDER BY edge_index) AS end_edge_index,
           end_shape_index AS begin_shape_index,
           lead(begin_shape_index) OVER (ORDER BY edge_index) AS end_shape_index,
           st_endpoint(geom) as start_geom,
           st_startpoint(lead(geom) OVER (ORDER BY begin_shape_index)) AS end_geom
    FROM temp_{0}_{1}_{2}_map_match_shape
)
SELECT begin_edge_index + 1 AS begin_edge_index,  -- correct value to edge index(es) to route
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
ANALYSE temp_{0}_{1}_{2}_route_this;


-- need to add a route at the start if first map matched segment doesn't start at the first waypoint
INSERT INTO temp_{0}_{1}_{2}_route_this
WITH pnt AS (
    SELECT geom
    FROM testing.waypoint
    WHERE point_index = 0
        AND trip_id = '{3}'
), trip AS (
    SELECT geom
    FROM temp_{0}_{1}_{2}_map_match_shape_point
    WHERE shape_index = 0
), merge AS (
    SELECT pnt.geom AS start_geom,
           trip.geom AS end_geom,
           st_distance(pnt.geom::geography, trip.geom::geography) AS distance_m
    FROM pnt
    CROSS JOIN trip
)
SELECT -1 AS begin_edge_index,
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
ANALYSE temp_{0}_{1}_{2}_route_this;
