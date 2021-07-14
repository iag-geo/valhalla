
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

-- -- 1344 test rows
-- SELECT count(*) FROM testing.temp_split_shape;
-- SELECT count(*) FROM testing.valhalla_segments;

-- DROP TABLE IF EXISTS testing.temp_split_shape;