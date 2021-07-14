
-- create table of routed segments and unrouted, map matched segments
DROP TABLE IF EXISTS testing.valhalla_segments;
CREATE TABLE testing.valhalla_segments AS
SELECT * FROM testing.valhalla_route_shape
;
ANALYSE testing.valhalla_segments;

-- create primary key to ensure uniqueness
ALTER TABLE testing.valhalla_segments
    ADD CONSTRAINT valhalla_segments_pkey PRIMARY KEY (trip_id, search_radius, segment_index);

-- Add map matched segments that haven't been fixed by routed
INSERT INTO testing.valhalla_segments
SELECT * FROM testing.temp_split_shape AS temp
WHERE NOT EXISTS(
        SELECT trip_id,
               search_radius,
               segment_index
        FROM testing.valhalla_segments AS seg
        WHERE seg.trip_id = temp.trip_id
          AND seg.search_radius = temp.search_radius
          AND seg.segment_index = temp.segment_index
    )
;
ANALYSE testing.valhalla_segments;

CREATE INDEX valhalla_segments_geom_idx ON testing.valhalla_segments USING gist (geom);
ALTER TABLE testing.valhalla_segments CLUSTER ON valhalla_segments_geom_idx;


-- add new start point to a route segment where Valhalla used a different start point to the previous map matched end point
WITH seg AS (
    SELECT trip_id,
           search_radius,
           segment_index,
           distance_m,
           point_count,
           segment_type,
           st_endpoint(lag(geom) OVER (PARTITION BY trip_id, search_radius ORDER BY segment_index)) as previous_end_geom,
           st_startpoint(geom) as start_geom
    FROM testing.valhalla_segments
)
UPDATE testing.valhalla_segments as rte
    SET geom = st_addpoint(rte.geom, seg.previous_end_geom, 0),
        distance_m = st_length(st_addpoint(rte.geom, seg.previous_end_geom, 0)::geography),
        point_count = rte.point_count + 1
FROM seg
WHERE rte.trip_id = seg.trip_id
  AND rte.search_radius = seg.search_radius
  AND rte.segment_index = seg.segment_index
  AND seg.segment_type = 'route'
;
ANALYSE testing.valhalla_segments;


-- stitch each route into a single linestring
DROP TABLE IF EXISTS testing.valhalla_final_routes;
CREATE TABLE testing.valhalla_final_routes AS
WITH seg AS (
    SELECT trip_id,
           search_radius,
           st_union(geom ORDER BY segment_index) AS geom
    FROM testing.valhalla_segments
    GROUP BY trip_id,
             search_radius
)
SELECT trip_id,
       search_radius,
       st_length(geom::geography) AS distance_m,
       geom
FROM seg
;
ANALYSE testing.valhalla_final_routes;

ALTER TABLE testing.valhalla_final_routes
    ADD CONSTRAINT valhalla_final_routes_pkey PRIMARY KEY (trip_id, search_radius);
CREATE INDEX valhalla_final_routes_geom_idx ON testing.valhalla_final_routes USING gist (geom);
ALTER TABLE testing.valhalla_final_routes CLUSTER ON valhalla_final_routes_geom_idx;


-- -- 1344 test rows
-- SELECT count(*) FROM testing.temp_split_shape;
-- SELECT count(*) FROM testing.valhalla_segments;

-- DROP TABLE IF EXISTS testing.temp_split_shape;

select *,
       geometrytype(geom)
from testing.valhalla_final_routes
order by trip_id,
         search_radius;




-- -- add interpolated segments where a route segment used a different start point to the prevsious map matched end point
-- INSERT INTO testing.valhalla_segments
-- WITH seg AS (
--     SELECT trip_id,
--            search_radius,
--            segment_index,
--            distance_m,
--            point_count,
--            segment_type,
--            st_endpoint(lag(geom) OVER (PARTITION BY trip_id, search_radius ORDER BY segment_index)) as previous_end_geom,
--            st_startpoint(geom) as start_geom,
--     FROM testing.valhalla_segments
-- )
-- SELECT trip_id,
--        search_radius,
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








