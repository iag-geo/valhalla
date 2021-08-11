
-- add indexes to Valhalla output tables

-- ALTER TABLE testing.valhalla_map_match_shape_non_pii
--     ADD CONSTRAINT valhalla_map_match_shape_non_pii_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy);
-- CREATE INDEX valhalla_map_match_shape_non_pii_geom_idx ON testing.valhalla_map_match_shape_non_pii USING gist (geom);
-- ALTER TABLE testing.valhalla_map_match_shape_non_pii CLUSTER ON valhalla_map_match_shape_non_pii_geom_idx;

CREATE INDEX valhalla_map_match_shape_point_combo_idx ON testing.valhalla_map_match_shape_point
    USING btree (trip_id, search_radius, gps_accuracy, shape_index);
-- CREATE INDEX valhalla_map_match_shape_point_trip_edge_id_idx
--     ON testing.valhalla_map_match_shape_point USING btree (trip_id, edge_index);
CREATE INDEX valhalla_map_match_shape_point_geom_idx ON testing.valhalla_map_match_shape_point USING gist (geom);
ALTER TABLE testing.valhalla_map_match_shape_point CLUSTER ON valhalla_map_match_shape_point_combo_idx;

-- CREATE INDEX valhalla_map_match_edge_trip_id_idx ON testing.valhalla_map_match_edge USING btree (trip_id);
CREATE INDEX valhalla_map_match_edge_combo_idx ON testing.valhalla_map_match_edge
    USING btree (trip_id, search_radius, gps_accuracy, begin_shape_index, end_shape_index);
-- CREATE INDEX valhalla_map_match_edge_osm_id_idx ON testing.valhalla_map_match_edge USING btree (osm_id);
-- CREATE INDEX valhalla_map_match_edge_trip_edge_id_idx
--     ON testing.valhalla_map_match_edge USING btree (trip_id, edge_index);
ALTER TABLE testing.valhalla_map_match_edge CLUSTER ON valhalla_map_match_edge_combo_idx;

-- CREATE INDEX valhalla_map_match_point_trip_id_idx ON testing.valhalla_map_match_point USING btree (trip_id);
CREATE INDEX valhalla_map_match_point_combo_idx ON testing.valhalla_map_match_point
    USING btree (trip_id, search_radius, gps_accuracy, edge_index);
-- CREATE INDEX valhalla_map_match_point_trip_edge_id_idx
--     ON testing.valhalla_map_match_point USING btree (trip_id, edge_index);
CREATE INDEX valhalla_map_match_point_geom_idx ON testing.valhalla_map_match_point USING gist (geom);
ALTER TABLE testing.valhalla_map_match_point CLUSTER ON valhalla_map_match_point_combo_idx;

ALTER TABLE testing.valhalla_map_match_fail
    ADD CONSTRAINT valhalla_map_match_fail_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy);


-- add indexes to Valhalla route output tables
ALTER TABLE testing.valhalla_route_shape
    ADD CONSTRAINT valhalla_route_shape_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy, begin_edge_index);
CREATE INDEX valhalla_route_shape_geom_idx ON testing.valhalla_route_shape USING gist (geom);
ALTER TABLE testing.valhalla_route_shape CLUSTER ON valhalla_route_shape_geom_idx;

ALTER TABLE testing.valhalla_route_fail
    ADD CONSTRAINT valhalla_route_fail_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy, begin_edge_index);


ALTER TABLE testing.valhalla_map_match_shape
    ADD CONSTRAINT valhalla_map_match_shape_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy, edge_index);
CREATE INDEX valhalla_map_match_shape_combo_idx ON testing.valhalla_map_match_shape USING gist (geom);
CREATE INDEX valhalla_map_match_shape_geom_idx ON testing.valhalla_map_match_shape
    USING btree (trip_id, search_radius, gps_accuracy);
ALTER TABLE testing.valhalla_map_match_shape CLUSTER ON valhalla_map_match_shape_pkey;


ALTER TABLE testing.valhalla_route_this
    ADD CONSTRAINT valhalla_route_this_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy, begin_edge_index);
ALTER TABLE testing.valhalla_route_this CLUSTER ON valhalla_route_this_pkey;


ALTER TABLE testing.valhalla_segment
    ADD CONSTRAINT valhalla_segment_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy, begin_edge_index);
CREATE UNIQUE INDEX valhalla_segment_end_shape_index_idx ON testing.valhalla_segment USING btree (trip_id, search_radius, gps_accuracy, end_edge_index);
CREATE INDEX valhalla_segment_combo_idx ON testing.valhalla_segment USING btree (trip_id, search_radius, gps_accuracy);
CREATE INDEX valhalla_segment_geom_idx ON testing.valhalla_segment USING gist (geom);
ALTER TABLE testing.valhalla_segment CLUSTER ON valhalla_segment_geom_idx;

ALTER TABLE testing.valhalla_merged_route
    ADD CONSTRAINT valhalla_merged_route_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy);
CREATE INDEX valhalla_merged_route_trip_id_idx ON testing.valhalla_merged_route USING btree (trip_id);
CREATE INDEX valhalla_merged_route_geom_idx ON testing.valhalla_merged_route USING gist (geom);
ALTER TABLE testing.valhalla_merged_route CLUSTER ON valhalla_merged_route_geom_idx;



ALTER TABLE testing.valhalla_final_route
    ADD CONSTRAINT valhalla_final_route_pkey PRIMARY KEY (trip_id);
CREATE INDEX valhalla_final_route_geom_idx ON testing.valhalla_final_route USING gist (geom);
ALTER TABLE testing.valhalla_final_route CLUSTER ON valhalla_final_route_geom_idx;
