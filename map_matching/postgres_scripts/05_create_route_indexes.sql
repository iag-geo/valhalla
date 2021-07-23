
-- add indexes to Valhalla route output tables
ALTER TABLE testing.valhalla_route_shape
    ADD CONSTRAINT valhalla_route_shape_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy, start_point_index);
CREATE INDEX valhalla_route_shape_geom_idx ON testing.valhalla_route_shape USING gist (geom);
ALTER TABLE testing.valhalla_route_shape CLUSTER ON valhalla_route_shape_geom_idx;

ALTER TABLE testing.valhalla_route_fail
    ADD CONSTRAINT valhalla_route_fail_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy, start_point_index);
