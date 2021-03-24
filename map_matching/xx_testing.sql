


-- check biggest distance from waypoint to map matched point
select *
from testing.osm_waypoint_point
where distance_from_trace_point is not null
order by distance_from_trace_point desc;


-- Do distance nulls only occur when point is unmatched - yes
-- select point_type,
--        Count(*) as point_count
-- from testing.osm_waypoint_point
-- where distance_from_trace_point is null
-- group by point_type
-- ;


-- create table for analysing map matching - look at how far waypoints moved to the road network
drop table if exists testing.temp_waypoint_point_diff;
create table testing.temp_waypoint_point_diff as
with way as (
    select row_number() over (partition by trip_id order by time_local) - 1 as point_index,
           trip_id,
           geom
    from testing.prod_waypoints
    where trip_id in (...)
)
select way.trip_id,
       way.point_index,
       pnt.point_type,
       pnt.distance_from_trace_point as distance,
       way.geom,
       pnt.geom as matched_geom,
       st_setsrid(st_makeline(way.geom, pnt.geom), 4283) as line_geom
from testing.osm_waypoint_point as pnt
inner join way on pnt.trip_id = way.trip_id
    and pnt.point_index = way.point_index
;
analyse testing.temp_waypoint_point_diff;

create index temp_waypoint_point_diff_trip_id_idx on testing.temp_waypoint_point_diff using btree (trip_id);



-- look for missing shapes -- 0 rows
with edges as (
    select distinct trip_id from testing.osm_waypoint_edge
)
select * from edges
where not exists (select 1 from testing.osm_waypoint_shape as shp where shp.trip_id = edges.trip_id)
;

-- look for missing edges -- 0 rows
with edges as (
    select distinct trip_id from testing.osm_waypoint_edge
)
select shp.trip_id from testing.osm_waypoint_shape as shp
where not exists (select 1 from edges where shp.trip_id = edges.trip_id)
;

-- look for missing points -- 0 rows
with pnt as (
    select distinct trip_id from testing.osm_waypoint_point
)
select shp.trip_id from testing.osm_waypoint_shape as shp
where not exists (select 1 from pnt where shp.trip_id = pnt.trip_id)
;



select * from testing.osm_waypoint_fail;

select count(*) from testing.osm_waypoint_shape;

select *
from testing.osm_waypoint_edge
where trip_id = '...'
order by edge_index
;

-- 11822
select count(*)
from testing.osm_waypoint_point
;


-- drop table planet_osm_roads;
-- drop table planet_osm_line;
-- drop table planet_osm_polygon;
-- drop table planet_osm_point;

select count(*) from testing.osm_waypoint_shape;




select trip_id,
       -- st_astext(ST_Transform(trip_line, 4326)) as geom
       (st_dumppoints(trip_line)).path AS point_num,
       st_x((st_dumppoints(trip_line)).geom) AS longitude,
       st_y((st_dumppoints(trip_line)).geom) AS latitude,
       st_m((st_dumppoints(trip_line)).geom) AS time
from testing.prod_waypoint_trajectories
where ...
order by trip_id, point_num;


select trip_id,
       -- st_astext(ST_Transform(trip_line, 4326)) as geom
       row_number() over (partition by trip_id order by unix_time) AS point_num,
       gps_lon AS longitude,
       gps_lat AS latitude,
       unix_time AS time
from testing.map_points
where ...
  and gps_lat is not null
order by trip_id, unix_time
