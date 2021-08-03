
-- TODO: refactor - this is too slow
-- STEP 1 - create map matched shape based on edge table indexes
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
        AND pnt.shape_index between begin_shape_index and edge.end_shape_index
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
SELECT shape.trip_id,
       true::boolean as use_segment,
       shape.begin_shape_index,
       shape.end_shape_index,
       shape.search_radius,
       shape.gps_accuracy,
       shape.edge_index,
       shape.osm_id,
       shape.names,
       shape.road_class,
       shape.speed,
       shape.traversability,
       shape.use,
       st_length(shape.geom::geography) AS distance_m,
       shape.geom
FROM shape
;
ANALYSE testing.valhalla_map_match_shape;

ALTER TABLE testing.valhalla_map_match_shape
    ADD CONSTRAINT valhalla_map_match_shape_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy, edge_index);
CREATE INDEX valhalla_map_match_shape_geom_idx ON testing.valhalla_map_match_shape USING gist (geom);
ALTER TABLE testing.valhalla_map_match_shape CLUSTER ON valhalla_map_match_shape_geom_idx;

-- TODO: change this to delete bad segments after QA is done to confirm this approach works
-- flag bad map match segments
UPDATE testing.valhalla_map_match_shape AS shape
    SET use_segment = false
FROM testing.valhalla_map_match_point as pnt2
WHERE shape.trip_id = pnt2.trip_id
    AND shape.search_radius = pnt2.search_radius
    AND shape.gps_accuracy = pnt2.gps_accuracy
    AND shape.edge_index = pnt2.edge_index
    AND pnt2.edge_index > 0
;
ANALYSE testing.valhalla_map_match_shape;


-- select * from testing.valhalla_map_match_shape
-- where search_radius = 7.5
--   and gps_accuracy = 7.5
--   and trip_id = 'F93947BB-AECD-48CC-A0B7-1041DFB28D03'
-- order by trip_id,
--          search_radius,
--          gps_accuracy,
--          begin_shape_index
-- ;


-- STEP 2 - get start and end points of segments to be routed
-- TODO: add trip start and end points where missing from map match results
DROP TABLE IF EXISTS testing.temp_route_this;
CREATE TABLE testing.temp_route_this AS
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
    WHERE use_segment
)
-- select * from starts
-- union all
-- select * from ends;
SELECT trip_id,
       search_radius,
       gps_accuracy,
       begin_edge_index,
       end_edge_index,
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
;
ANALYSE testing.temp_route_this;


select * from testing.temp_route_this
where begin_shape_index = 212
  and search_radius = 7.5
  and gps_accuracy = 7.5
;



WITH rte AS (
    SELECT trip_id,
           search_radius,
           gps_accuracy,
           start_point_index,
           end_point_index,
           begin_shape_index,
           end_shape_index,
           lead(begin_shape_index) OVER (PARTITION BY trip_id, search_radius, gps_accuracy
               ORDER BY begin_shape_index, end_shape_index) AS next_begin_shape_index,
           lead(end_shape_index) OVER (PARTITION BY trip_id, search_radius, gps_accuracy
        ORDER BY begin_shape_index, end_shape_index) AS next_end_shape_index,
           start_lat,
           start_lon,
           end_lat,
           end_lon,
           lead(end_lat) OVER (PARTITION BY trip_id, search_radius, gps_accuracy
               ORDER BY begin_shape_index, end_shape_index) AS next_end_lat,
           lead(end_lon) OVER (PARTITION BY trip_id, search_radius, gps_accuracy
               ORDER BY begin_shape_index, end_shape_index) AS next_end_lon,
           start_geom,
           end_geom,
           lead(end_geom) OVER (PARTITION BY trip_id, search_radius, gps_accuracy
               ORDER BY begin_shape_index, end_shape_index) AS next_end_geom
    FROM testing.temp_route_this
    where search_radius = 7.5
      and gps_accuracy = 7.5
      and trip_id <> 'F93947BB-AECD-48CC-A0B7-1041DFB28D03'
--       and begin_shape_index = 212
)
SELECT trip_id,
       search_radius,
       gps_accuracy,
--        start_point_index,
--        end_point_index,
       begin_shape_index,
       end_shape_index,
       next_begin_shape_index,
       next_end_shape_index,
       CASE WHEN next_begin_shape_index <= end_shape_index
           AND next_end_shape_index > end_shape_index THEN next_end_shape_index
           ELSE end_shape_index END AS final_end_shape_index,
       start_lat,
       start_lon,
       end_lat,
       end_lon,
       CASE WHEN next_begin_shape_index <= end_shape_index
           AND next_end_shape_index > end_shape_index THEN next_end_lat
            ELSE end_lat END AS final_end_lat,
       CASE WHEN next_begin_shape_index <= end_shape_index
           AND next_end_shape_index > end_shape_index THEN next_end_lon
            ELSE end_lon END AS final_lon
FROM rte
;




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


-- select trip_id,
--        search_radius,
--        gps_accuracy,
--        start_point_index,
--        end_point_index,
--        begin_shape_index,
--        end_shape_index,
--        start_lat,
--        start_lon,
--        end_lat,
--        end_lon,
--        start_geom,
--        end_geom
-- from testing.temp_route_this
-- -- where trip_id = 'F93947BB-AECD-48CC-A0B7-1041DFB28D03'
-- where search_radius = 7.5
--   and gps_accuracy = 7.5
-- order by trip_id,
--          search_radius,
--          gps_accuracy,
--          start_point_index
-- ;


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
