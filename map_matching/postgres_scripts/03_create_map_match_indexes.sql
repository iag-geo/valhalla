
-- add indexes to Valhalla map match output tables

-- ALTER TABLE temp_{0}_{1}_{2}_map_match_shape_non_pii
--     ADD CONSTRAINT valhalla_map_match_shape_non_pii_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy);
-- CREATE INDEX valhalla_map_match_shape_non_pii_geom_idx ON temp_{0}_{1}_{2}_map_match_shape_non_pii USING gist (geom);
-- ALTER TABLE temp_{0}_{1}_{2}_map_match_shape_non_pii CLUSTER ON valhalla_map_match_shape_non_pii_geom_idx;

CREATE INDEX valhalla_map_match_shape_point_combo_idx ON temp_{0}_{1}_{2}_map_match_shape_point
    USING btree (trip_id, search_radius, gps_accuracy, shape_index);
-- CREATE INDEX valhalla_map_match_shape_point_trip_edge_id_idx
--     ON temp_{0}_{1}_{2}_map_match_shape_point USING btree (trip_id, edge_index);
CREATE INDEX valhalla_map_match_shape_point_geom_idx ON temp_{0}_{1}_{2}_map_match_shape_point USING gist (geom);
ALTER TABLE temp_{0}_{1}_{2}_map_match_shape_point CLUSTER ON valhalla_map_match_shape_point_combo_idx;

-- CREATE INDEX valhalla_map_match_edge_trip_id_idx ON temp_{0}_{1}_{2}_map_match_edge USING btree (trip_id);
CREATE INDEX valhalla_map_match_edge_combo_idx ON temp_{0}_{1}_{2}_map_match_edge
    USING btree (trip_id, search_radius, gps_accuracy, begin_shape_index, end_shape_index);
-- CREATE INDEX valhalla_map_match_edge_osm_id_idx ON temp_{0}_{1}_{2}_map_match_edge USING btree (osm_id);
-- CREATE INDEX valhalla_map_match_edge_trip_edge_id_idx
--     ON temp_{0}_{1}_{2}_map_match_edge USING btree (trip_id, edge_index);
ALTER TABLE temp_{0}_{1}_{2}_map_match_edge CLUSTER ON valhalla_map_match_edge_combo_idx;

-- CREATE INDEX valhalla_map_match_point_trip_id_idx ON temp_{0}_{1}_{2}_map_match_point USING btree (trip_id);
CREATE INDEX valhalla_map_match_point_combo_idx ON temp_{0}_{1}_{2}_map_match_point
    USING btree (trip_id, search_radius, gps_accuracy, edge_index);
-- CREATE INDEX valhalla_map_match_point_trip_edge_id_idx
--     ON temp_{0}_{1}_{2}_map_match_point USING btree (trip_id, edge_index);
CREATE INDEX valhalla_map_match_point_geom_idx ON temp_{0}_{1}_{2}_map_match_point USING gist (geom);
ALTER TABLE temp_{0}_{1}_{2}_map_match_point CLUSTER ON valhalla_map_match_point_combo_idx;

ALTER TABLE temp_{0}_{1}_{2}_map_match_fail
    ADD CONSTRAINT valhalla_map_match_fail_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy);









