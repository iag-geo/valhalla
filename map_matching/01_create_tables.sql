
-- create tables for Python script to output to

drop table if exists testing.valhalla_shape cascade;
create table testing.valhalla_shape
(
    trip_id text,
    distance float,
    geom geometry(linestring, 4283)
);
alter table testing.valhalla_shape owner to postgres;


drop table if exists testing.valhalla_shape_non_pii cascade;
create table testing.valhalla_shape_non_pii
(
    trip_id text,
    distance float,
    geom geometry(linestring, 4283)
);
alter table testing.valhalla_shape_non_pii owner to postgres;


-- create table for code to output osm_ids for route segments
drop table if exists testing.valhalla_edge cascade;
create table testing.valhalla_edge
(
    trip_id text,
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
    point_index integer,
    distance_from_trace_point float,
    distance_along_edge float,
    begin_route_discontinuity boolean,
    end_route_discontinuity boolean,
    edge_index integer,
    point_type text,
    geom geometry(point, 4283)
);

alter table testing.valhalla_point owner to postgres;


-- create table for code to output failed trip_ids to
drop table if exists testing.valhalla_fail cascade;
create table testing.valhalla_fail
(
    trip_id text,
    error_code integer,
    error text,
    http_status text,
    curl_command text
);
alter table testing.valhalla_fail owner to postgres;


-- -- Only show trajectories that don't leave the road network
-- drop view if exists testing.vw_valhalla_trajectories;
-- create view testing.vw_valhalla_trajectories as
-- with point as (
--     select trip_id,
--            count(*) as point_count,
--            sum(case when edge_index = 0 then 1 else 0 end) as no_edge_index_count,
--            sum(case when begin_route_discontinuity then 1 else 0 end) +
--            sum(case when end_route_discontinuity then 1 else 0 end) as discontinuity_count
--     from testing.valhalla_point
--     group by trip_id
--     order by discontinuty_count desc
-- ), edge as (
--     select trip_id,
--            count(*) as edge_count,
--            sum(case when names is null then 1 else 0 end) as unnamed_edge_count,
--            sum(case when speed is null then 1 else 0 end) as no_speed_edge_count
--     from testing.valhalla_edge
--     group by trip_id
-- )
-- select sum.trip_id,
--        sum.user_id,
--        sum.start_time_utc,
--        point.point_count,
--        point.no_edge_index_count,
--        point.discontinuity_count,
--        edge.edge_count,
--        edge.unnamed_edge_count,
--        edge.no_speed_edge_count,
--        sum.trip_line as cmt_geom,
--        traj.geom as vha_geom
-- from testing.valhalla_shape as traj
--          inner join point on traj.trip_id = point.trip_id
--          inner join edge on traj.trip_id = edge.trip_id
--          inner join testing.prod_waypoint_trajectories as sum on traj.trip_id = sum.trip_id;


-- indexes
alter table testing.valhalla_shape add constraint valhalla_shape_pkey primary key (trip_id);
create index valhalla_shape_geom_idx on testing.valhalla_shape using gist (geom);
ALTER TABLE testing.valhalla_shape CLUSTER ON valhalla_shape_geom_idx;

alter table testing.valhalla_shape_non_pii add constraint valhalla_shape_non_pii_pkey primary key (trip_id);
create index valhalla_shape_non_pii_geom_idx on testing.valhalla_shape_non_pii using gist (geom);
ALTER TABLE testing.valhalla_shape_non_pii CLUSTER ON valhalla_shape_non_pii_geom_idx;

create index valhalla_edge_trip_id_idx on testing.valhalla_edge using btree (trip_id);
create index valhalla_edge_osm_id_idx on testing.valhalla_edge using btree (osm_id);
create index valhalla_edge_trip_edge_id_idx on testing.valhalla_edge using btree (trip_id, edge_index);
ALTER TABLE testing.valhalla_edge CLUSTER ON valhalla_edge_trip_edge_id_idx;

create index valhalla_point_trip_id_idx on testing.valhalla_point using btree (trip_id);
create index valhalla_point_trip_edge_id_idx on testing.valhalla_point using btree (trip_id, edge_index);
create index valhalla_point_geom_idx on testing.valhalla_point using gist (geom);
ALTER TABLE testing.valhalla_point CLUSTER ON valhalla_point_geom_idx;

alter table testing.valhalla_fail add constraint valhalla_fail_pkey primary key (trip_id);
