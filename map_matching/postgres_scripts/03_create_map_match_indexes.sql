
-- add indexes to Valhalla map match output tables
ALTER TABLE testing.valhalla_map_match_shape
    ADD CONSTRAINT valhalla_map_match_shape_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy);
CREATE INDEX valhalla_map_match_shape_geom_idx ON testing.valhalla_map_match_shape USING gist (geom);
ALTER TABLE testing.valhalla_map_match_shape CLUSTER ON valhalla_map_match_shape_geom_idx;

ALTER TABLE testing.valhalla_map_match_shape_non_pii
    ADD CONSTRAINT valhalla_map_match_shape_non_pii_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy);
CREATE INDEX valhalla_map_match_shape_non_pii_geom_idx ON testing.valhalla_map_match_shape_non_pii USING gist (geom);
ALTER TABLE testing.valhalla_map_match_shape_non_pii CLUSTER ON valhalla_map_match_shape_non_pii_geom_idx;

CREATE INDEX valhalla_map_match_edge_trip_id_idx ON testing.valhalla_map_match_edge USING btree (trip_id);
CREATE INDEX valhalla_map_match_edge_search_radius_idx
    ON testing.valhalla_map_match_edge USING btree (search_radius, gps_accuracy);
CREATE INDEX valhalla_map_match_edge_osm_id_idx ON testing.valhalla_map_match_edge USING btree (osm_id);
CREATE INDEX valhalla_map_match_edge_trip_edge_id_idx
    ON testing.valhalla_map_match_edge USING btree (trip_id, edge_index);
ALTER TABLE testing.valhalla_map_match_edge CLUSTER ON valhalla_map_match_edge_trip_edge_id_idx;

CREATE INDEX valhalla_map_match_point_trip_id_idx ON testing.valhalla_map_match_point USING btree (trip_id);
CREATE INDEX valhalla_map_match_point_search_radius_idx
    ON testing.valhalla_map_match_point USING btree (search_radius, gps_accuracy);
CREATE INDEX valhalla_map_match_point_trip_edge_id_idx
    ON testing.valhalla_map_match_point USING btree (trip_id, edge_index);
CREATE INDEX valhalla_map_match_point_geom_idx ON testing.valhalla_map_match_point USING gist (geom);
ALTER TABLE testing.valhalla_map_match_point CLUSTER ON valhalla_map_match_point_geom_idx;

ALTER TABLE testing.valhalla_map_match_fail
    ADD CONSTRAINT valhalla_map_match_fail_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy);
