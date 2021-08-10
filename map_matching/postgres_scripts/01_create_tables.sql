
-- create tables for Python script to output to

-- map matching output tables

DROP TABLE IF EXISTS testing.valhalla_map_match_shape_point CASCADE;
CREATE TABLE testing.valhalla_map_match_shape_point
(
    trip_id text,
    search_radius double precision,
    gps_accuracy double precision,
    shape_index integer,
    geom geometry(point, 4326)
);
ALTER TABLE testing.valhalla_map_match_shape_point OWNER TO postgres;


-- DROP TABLE IF EXISTS testing.valhalla_map_match_shape_non_pii CASCADE;
-- CREATE TABLE testing.valhalla_map_match_shape_non_pii
-- (
--     trip_id text,
--     search_radius double precision,
--     gps_accuracy double precision,
--     distance_m double precision,
--     geom geometry(linestring, 4326)
-- );
-- ALTER TABLE testing.valhalla_map_match_shape_non_pii OWNER TO postgres;


DROP TABLE IF EXISTS testing.valhalla_map_match_edge CASCADE;
CREATE TABLE testing.valhalla_map_match_edge
(
    trip_id text,
    search_radius double precision,
    gps_accuracy double precision,
    edge_index integer,
    osm_id integer,
    names text[],
    road_class text,
    speed double precision,
    begin_shape_index integer,
    end_shape_index integer,
    traversability text,
    use text
);
ALTER TABLE testing.valhalla_map_match_edge OWNER TO postgres;


DROP TABLE IF EXISTS testing.valhalla_map_match_point CASCADE;
CREATE TABLE testing.valhalla_map_match_point
(
    trip_id text,
    search_radius double precision,
    gps_accuracy double precision,
    point_index integer,
    distance_from_trace_point double precision,
    distance_along_edge double precision,
    begin_route_discontinuity boolean,
    end_route_discontinuity boolean,
    edge_index integer,
    point_type text,
    geom geometry(point, 4326)
);

ALTER TABLE testing.valhalla_map_match_point OWNER TO postgres;


DROP TABLE IF EXISTS testing.valhalla_map_match_fail CASCADE;
CREATE TABLE testing.valhalla_map_match_fail
(
    trip_id text,
    search_radius double precision,
    gps_accuracy double precision,
    error_code smallint,
    error text,
    http_status text,
    curl_command text
);
ALTER TABLE testing.valhalla_map_match_fail OWNER TO postgres;


-- routing outputs

DROP TABLE IF EXISTS testing.valhalla_route_shape CASCADE;
CREATE TABLE testing.valhalla_route_shape
(
    trip_id text,
    search_radius double precision,
    gps_accuracy double precision,
    begin_edge_index integer,
    end_edge_index integer,
    begin_shape_index integer,
    end_shape_index integer,
    distance_m double precision,
    point_count integer,
    segment_type text,
    geom geometry(linestring, 4326)
);
ALTER TABLE testing.valhalla_route_shape OWNER TO postgres;


DROP TABLE IF EXISTS testing.valhalla_route_fail CASCADE;
CREATE TABLE testing.valhalla_route_fail
(
    trip_id text,
    search_radius double precision,
    gps_accuracy double precision,
    begin_edge_index integer,
    end_edge_index integer,
    begin_shape_index integer,
    end_shape_index integer,
    error_code smallint,
    error text,
    http_status text,
    curl_command text
);
ALTER TABLE testing.valhalla_route_fail OWNER TO postgres;


-- working (interim) tables

DROP TABLE IF EXISTS testing.valhalla_map_match_shape CASCADE;
CREATE TABLE testing.valhalla_map_match_shape
(
    trip_id text,
    search_radius double precision,
    gps_accuracy double precision,
    begin_shape_index integer,
    end_shape_index integer,
    edge_index integer,
    road_class text,
    distance_m double precision,
    geom geometry
);
ALTER TABLE testing.valhalla_map_match_shape OWNER to postgres;


DROP TABLE IF EXISTS testing.valhalla_route_this CASCADE;
CREATE TABLE testing.valhalla_route_this
(
    trip_id text,
    search_radius double precision,
    gps_accuracy double precision,
    begin_edge_index integer,
    end_edge_index integer,
    begin_shape_index integer,
    end_shape_index integer,
    start_lat double precision,
    start_lon double precision,
    end_lat double precision,
    end_lon double precision,
    start_geom geometry,
    end_geom geometry
);
ALTER TABLE testing.valhalla_route_this OWNER to postgres;


DROP TABLE IF EXISTS testing.valhalla_segment CASCADE;
CREATE TABLE testing.valhalla_segment
(
    trip_id text,
    search_radius double precision,
    gps_accuracy double precision,
    begin_edge_index integer,
    end_edge_index integer,
    begin_shape_index integer,
    end_shape_index integer,
    distance_m double precision,
    point_count integer,
    segment_type text,
    geom geometry(linestring, 4326)
);
ALTER TABLE testing.valhalla_segment OWNER TO postgres;


DROP TABLE IF EXISTS testing.valhalla_merged_route CASCADE;
CREATE TABLE testing.valhalla_merged_route
(
    trip_id text NOT NULL,
    search_radius double precision NOT NULL,
    gps_accuracy double precision NOT NULL,
    total_segments bigint,
    total_distance_km double precision,
    map_match_percent numeric(4,1),
    map_match_segments bigint,
    map_match_distance_km double precision,
    route_segments bigint,
    route_distance_km double precision,
    rmse_km double precision,
    waypoint_distance_ratio double precision,
    waypoint_count integer,
    point_count integer,
    geom geometry
);
ALTER TABLE testing.valhalla_merged_route OWNER to postgres;


-- final output

DROP TABLE IF EXISTS testing.valhalla_final_route CASCADE;
CREATE TABLE testing.valhalla_final_route
(
    trip_id text NOT NULL,
    search_radius double precision NOT NULL,
    gps_accuracy double precision NOT NULL,
    total_segments bigint,
    total_distance_km double precision,
    map_match_percent numeric(4,1),
    map_match_segments bigint,
    map_match_distance_km double precision,
    route_segments bigint,
    route_distance_km double precision,
    rmse_km double precision,
    waypoint_distance_ratio double precision,
    waypoint_count integer,
    point_count integer,
    geom geometry,
    rank bigint
);
ALTER TABLE testing.valhalla_final_route OWNER to postgres;





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
