
-- create tables for Python script to output to

drop table if exists testing.valhalla_shape cascade;
create table testing.valhalla_shape
(
    trip_id text,
    search_radius smallint,
    distance float,
    geom geometry(linestring, 4326)
);
alter table testing.valhalla_shape owner to postgres;


drop table if exists testing.valhalla_shape_non_pii cascade;
create table testing.valhalla_shape_non_pii
(
    trip_id text,
    search_radius smallint,
    distance float,
    geom geometry(linestring, 4326)
);
alter table testing.valhalla_shape_non_pii owner to postgres;


-- create table for code to output osm_ids for route segments
drop table if exists testing.valhalla_edge cascade;
create table testing.valhalla_edge
(
    trip_id text,
    search_radius smallint,
    edge_index integer,
    osm_id integer,
    names text[],
    road_class text,
    speed float,
    begin_shape_index integer,
    end_shape_index integer
);
alter table testing.valhalla_edge owner to postgres;


-- create table for code to output osm_ids for route segments
drop table if exists testing.valhalla_point cascade;
create table testing.valhalla_point
(
    trip_id text,
    search_radius smallint,
    point_index integer,
    distance_from_trace_point float,
    distance_along_edge float,
    begin_route_discontinuity boolean,
    end_route_discontinuity boolean,
    edge_index integer,
    point_type text,
    geom geometry(point, 4326)
);

alter table testing.valhalla_point owner to postgres;


-- create table for code to output failed trip_ids to
drop table if exists testing.valhalla_fail cascade;
create table testing.valhalla_fail
(
    trip_id text,
    search_radius smallint,
    error_code smallint,
    error text,
    http_status text,
    curl_command text
);
alter table testing.valhalla_fail owner to postgres;
