
-- add indexes to Valhalla result tables
alter table testing.valhalla_shape add constraint valhalla_shape_pkey primary key (trip_id, search_radius);
create index valhalla_shape_geom_idx on testing.valhalla_shape using gist (geom);
ALTER TABLE testing.valhalla_shape CLUSTER ON valhalla_shape_geom_idx;

alter table testing.valhalla_shape_non_pii add constraint valhalla_shape_non_pii_pkey primary key (trip_id, search_radius);
create index valhalla_shape_non_pii_geom_idx on testing.valhalla_shape_non_pii using gist (geom);
ALTER TABLE testing.valhalla_shape_non_pii CLUSTER ON valhalla_shape_non_pii_geom_idx;

create index valhalla_edge_trip_id_idx on testing.valhalla_edge using btree (trip_id);
create index valhalla_edge_search_radius_idx on testing.valhalla_edge using btree (search_radius);
create index valhalla_edge_osm_id_idx on testing.valhalla_edge using btree (osm_id);
create index valhalla_edge_trip_edge_id_idx on testing.valhalla_edge using btree (trip_id, edge_index);
ALTER TABLE testing.valhalla_edge CLUSTER ON valhalla_edge_trip_edge_id_idx;

create index valhalla_point_trip_id_idx on testing.valhalla_point using btree (trip_id);
create index valhalla_point_search_radius_idx on testing.valhalla_point using btree (search_radius);
create index valhalla_point_trip_edge_id_idx on testing.valhalla_point using btree (trip_id, edge_index);
create index valhalla_point_geom_idx on testing.valhalla_point using gist (geom);
ALTER TABLE testing.valhalla_point CLUSTER ON valhalla_point_geom_idx;

alter table testing.valhalla_fail add constraint valhalla_fail_pkey primary key (trip_id, search_radius);
