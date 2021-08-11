
-- map matching output tables

DROP TABLE IF EXISTS temp_{0}_{1}_{2}_map_match_shape_point;
CREATE TABLE temp_{0}_{1}_{2}_map_match_shape_point
(
    trip_id text,
    search_radius double precision,
    gps_accuracy double precision,
    shape_index integer,
    geom geometry(point, 4326)
);
ALTER TABLE temp_{0}_{1}_{2}_map_match_shape_point OWNER TO postgres;


-- DROP TABLE IF EXISTS temp_{0}_{1}_{2}_map_match_shape_non_pii;
-- CREATE TABLE temp_{0}_{1}_{2}_map_match_shape_non_pii
-- (
--     trip_id text,
--     search_radius double precision,
--     gps_accuracy double precision,
--     distance_m double precision,
--     geom geometry(linestring, 4326)
-- );
-- ALTER TABLE temp_{0}_{1}_{2}_map_match_shape_non_pii OWNER TO postgres;


DROP TABLE IF EXISTS temp_{0}_{1}_{2}_map_match_edge;
CREATE TABLE temp_{0}_{1}_{2}_map_match_edge
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
ALTER TABLE temp_{0}_{1}_{2}_map_match_edge OWNER TO postgres;


DROP TABLE IF EXISTS temp_{0}_{1}_{2}_map_match_point;
CREATE TABLE temp_{0}_{1}_{2}_map_match_point
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

ALTER TABLE temp_{0}_{1}_{2}_map_match_point OWNER TO postgres;


DROP TABLE IF EXISTS temp_{0}_{1}_{2}_map_match_fail;
CREATE TABLE temp_{0}_{1}_{2}_map_match_fail
(
    trip_id text,
    search_radius double precision,
    gps_accuracy double precision,
    error_code smallint,
    error text,
    http_status text,
    curl_command text
);
ALTER TABLE temp_{0}_{1}_{2}_map_match_fail OWNER TO postgres;


-- routing outputs

DROP TABLE IF EXISTS temp_{0}_{1}_{2}_route_shape;
CREATE TABLE temp_{0}_{1}_{2}_route_shape
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
ALTER TABLE temp_{0}_{1}_{2}_route_shape OWNER TO postgres;


DROP TABLE IF EXISTS temp_{0}_{1}_{2}_route_fail;
CREATE TABLE temp_{0}_{1}_{2}_route_fail
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
ALTER TABLE temp_{0}_{1}_{2}_route_fail OWNER TO postgres;


-- working (interim) tables

DROP TABLE IF EXISTS temp_{0}_{1}_{2}_map_match_shape;
CREATE TABLE temp_{0}_{1}_{2}_map_match_shape
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
ALTER TABLE temp_{0}_{1}_{2}_map_match_shape OWNER to postgres;


DROP TABLE IF EXISTS temp_{0}_{1}_{2}_route_this;
CREATE TABLE temp_{0}_{1}_{2}_route_this
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
ALTER TABLE temp_{0}_{1}_{2}_route_this OWNER to postgres;


DROP TABLE IF EXISTS temp_{0}_{1}_{2}_segment;
CREATE TABLE temp_{0}_{1}_{2}_segment
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
ALTER TABLE temp_{0}_{1}_{2}_segment OWNER TO postgres;


DROP TABLE IF EXISTS temp_{0}_{1}_{2}_merged_route;
CREATE TABLE temp_{0}_{1}_{2}_merged_route
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
ALTER TABLE temp_{0}_{1}_{2}_merged_route OWNER to postgres;


-- final output

DROP TABLE IF EXISTS temp_{0}_{1}_{2}_final_route;
CREATE TABLE temp_{0}_{1}_{2}_final_route
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
ALTER TABLE temp_{0}_{1}_{2}_final_route OWNER to postgres;












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


-- add indexes to Valhalla route output tables
ALTER TABLE temp_{0}_{1}_{2}_route_shape
    ADD CONSTRAINT valhalla_route_shape_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy, begin_edge_index);
CREATE INDEX valhalla_route_shape_geom_idx ON temp_{0}_{1}_{2}_route_shape USING gist (geom);
ALTER TABLE temp_{0}_{1}_{2}_route_shape CLUSTER ON valhalla_route_shape_geom_idx;

ALTER TABLE temp_{0}_{1}_{2}_route_fail
    ADD CONSTRAINT valhalla_route_fail_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy, begin_edge_index);


ALTER TABLE temp_{0}_{1}_{2}_map_match_shape
    ADD CONSTRAINT valhalla_map_match_shape_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy, edge_index);
CREATE INDEX valhalla_map_match_shape_combo_idx ON temp_{0}_{1}_{2}_map_match_shape USING gist (geom);
CREATE INDEX valhalla_map_match_shape_geom_idx ON temp_{0}_{1}_{2}_map_match_shape
    USING btree (trip_id, search_radius, gps_accuracy);
ALTER TABLE temp_{0}_{1}_{2}_map_match_shape CLUSTER ON valhalla_map_match_shape_pkey;


ALTER TABLE temp_{0}_{1}_{2}_route_this
    ADD CONSTRAINT valhalla_route_this_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy, begin_edge_index);
ALTER TABLE temp_{0}_{1}_{2}_route_this CLUSTER ON valhalla_route_this_pkey;


ALTER TABLE temp_{0}_{1}_{2}_segment
    ADD CONSTRAINT valhalla_segment_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy, begin_edge_index);
CREATE UNIQUE INDEX valhalla_segment_end_shape_index_idx ON temp_{0}_{1}_{2}_segment USING btree (trip_id, search_radius, gps_accuracy, end_edge_index);
CREATE INDEX valhalla_segment_combo_idx ON temp_{0}_{1}_{2}_segment USING btree (trip_id, search_radius, gps_accuracy);
CREATE INDEX valhalla_segment_geom_idx ON temp_{0}_{1}_{2}_segment USING gist (geom);
ALTER TABLE temp_{0}_{1}_{2}_segment CLUSTER ON valhalla_segment_geom_idx;

ALTER TABLE temp_{0}_{1}_{2}_merged_route
    ADD CONSTRAINT valhalla_merged_route_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy);
CREATE INDEX valhalla_merged_route_trip_id_idx ON temp_{0}_{1}_{2}_merged_route USING btree (trip_id);
CREATE INDEX valhalla_merged_route_geom_idx ON temp_{0}_{1}_{2}_merged_route USING gist (geom);
ALTER TABLE temp_{0}_{1}_{2}_merged_route CLUSTER ON valhalla_merged_route_geom_idx;



ALTER TABLE temp_{0}_{1}_{2}_final_route
    ADD CONSTRAINT valhalla_final_route_pkey PRIMARY KEY (trip_id);
CREATE INDEX valhalla_final_route_geom_idx ON temp_{0}_{1}_{2}_final_route USING gist (geom);
ALTER TABLE temp_{0}_{1}_{2}_final_route CLUSTER ON valhalla_final_route_geom_idx;
