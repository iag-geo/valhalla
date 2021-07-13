
-- add indexes to Valhalla map match output tables
alter table testing.valhalla_map_match_shape add constraint valhalla_map_match_shape_pkey primary key (trip_id, search_radius);
create index valhalla_map_match_shape_geom_idx on testing.valhalla_map_match_shape using gist (geom);
ALTER TABLE testing.valhalla_map_match_shape CLUSTER ON valhalla_map_match_shape_geom_idx;

alter table testing.valhalla_map_match_shape_non_pii add constraint valhalla_map_match_shape_non_pii_pkey primary key (trip_id, search_radius);
create index valhalla_map_match_shape_non_pii_geom_idx on testing.valhalla_map_match_shape_non_pii using gist (geom);
ALTER TABLE testing.valhalla_map_match_shape_non_pii CLUSTER ON valhalla_map_match_shape_non_pii_geom_idx;

create index valhalla_map_match_edge_trip_id_idx on testing.valhalla_map_match_edge using btree (trip_id);
create index valhalla_map_match_edge_search_radius_idx on testing.valhalla_map_match_edge using btree (search_radius);
create index valhalla_map_match_edge_osm_id_idx on testing.valhalla_map_match_edge using btree (osm_id);
create index valhalla_map_match_edge_trip_edge_id_idx on testing.valhalla_map_match_edge using btree (trip_id, edge_index);
ALTER TABLE testing.valhalla_map_match_edge CLUSTER ON valhalla_map_match_edge_trip_edge_id_idx;

create index valhalla_map_match_point_trip_id_idx on testing.valhalla_map_match_point using btree (trip_id);
create index valhalla_map_match_point_search_radius_idx on testing.valhalla_map_match_point using btree (search_radius);
create index valhalla_map_match_point_trip_edge_id_idx on testing.valhalla_map_match_point using btree (trip_id, edge_index);
create index valhalla_map_match_point_geom_idx on testing.valhalla_map_match_point using gist (geom);
ALTER TABLE testing.valhalla_map_match_point CLUSTER ON valhalla_map_match_point_geom_idx;

alter table testing.valhalla_map_match_fail add constraint valhalla_map_match_fail_pkey primary key (trip_id, search_radius);
