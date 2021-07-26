
-- create tables for Python script to output to

DROP TABLE IF EXISTS testing.valhalla_map_match_shape CASCADE;
CREATE TABLE testing.valhalla_map_match_shape
(
    trip_id text,
    begin_shape_index integer,
    end_shape_index integer,
    search_radius double precision,
    gps_accuracy double precision,
    distance_m float,
    geom geometry(linestring, 4326)
);
ALTER TABLE testing.valhalla_map_match_shape OWNER TO postgres;


DROP TABLE IF EXISTS testing.valhalla_map_match_shape_point CASCADE;
CREATE TABLE testing.valhalla_map_match_shape_point
(
    trip_id text,
    shape_index integer,
    search_radius double precision,
    gps_accuracy double precision,
    geom geometry(point, 4326)
);
ALTER TABLE testing.valhalla_map_match_shape_point OWNER TO postgres;



DROP TABLE IF EXISTS testing.valhalla_map_match_shape_non_pii CASCADE;
CREATE TABLE testing.valhalla_map_match_shape_non_pii
(
    trip_id text,
    search_radius double precision,
    gps_accuracy double precision,
    distance_m float,
    geom geometry(linestring, 4326)
);
ALTER TABLE testing.valhalla_map_match_shape_non_pii OWNER TO postgres;


-- create table for code to output osm_ids for route segments
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
    speed float,
    begin_shape_index integer,
    end_shape_index integer
);
ALTER TABLE testing.valhalla_map_match_edge OWNER TO postgres;


-- create table for code to output osm_ids for route segments
DROP TABLE IF EXISTS testing.valhalla_map_match_point CASCADE;
CREATE TABLE testing.valhalla_map_match_point
(
    trip_id text,
    search_radius double precision,
    gps_accuracy double precision,
    point_index integer,
    distance_from_trace_point float,
    distance_along_edge float,
    begin_route_discontinuity boolean,
    end_route_discontinuity boolean,
    edge_index integer,
    point_type text,
    geom geometry(point, 4326)
);

ALTER TABLE testing.valhalla_map_match_point OWNER TO postgres;


-- create table for code to output failed trip_ids to
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
    start_point_index integer,
    end_point_index integer,
    distance_m float,
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
    start_point_index integer,
    end_point_index integer,
    error_code smallint,
    error text,
    http_status text,
    curl_command text
);
ALTER TABLE testing.valhalla_route_fail OWNER TO postgres;
