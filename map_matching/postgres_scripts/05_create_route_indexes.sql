
-- add indexes to Valhalla route output tables
alter table testing.valhalla_route_shape add constraint valhalla_route_shape_pkey primary key (trip_id, search_radius, segment_index);
create index valhalla_route_shape_geom_idx on testing.valhalla_route_shape using gist (geom);
ALTER TABLE testing.valhalla_route_shape CLUSTER ON valhalla_route_shape_geom_idx;

alter table testing.valhalla_route_fail add constraint valhalla_route_fail_pkey primary key (trip_id, search_radius, segment_index);
