

-- copy mapmatch & routing results to permanent table
DROP TABLE IF EXISTS carbar.mm_routes_202105;
CREATE TABLE carbar.mm_routes_202105 AS
SELECT * FROM testing.valhalla_final_route
;
ANALYSE carbar.mm_routes_202105;

-- create primary key to ensure uniqueness
ALTER TABLE carbar.mm_routes_202105
    ADD CONSTRAINT mm_routes_202105_pkey PRIMARY KEY (trip_id, search_radius, gps_accuracy);

CREATE INDEX mm_routes_202105_geom_idx ON carbar.mm_routes_202105 USING gist (geom);
ALTER TABLE carbar.mm_routes_202105 CLUSTER ON mm_routes_202105_geom_idx;



select count(*)
from testing.valhalla_segment
;

select *
from testing.valhalla_merged_route
;


select count(*)
from testing.valhalla_final_route
-- where rmse_km >= 0.5  -- 164
-- where rmse_km >= 0.7  -- 120
where search_radius = gps_accuracy  -- 254
;



select *
from testing.valhalla_map_match_fail;

select *
from testing.valhalla_route_fail;



drop table if exists testing.valhalla_final_route_baseline;
create table testing.valhalla_final_route_baseline as
select *
from testing.valhalla_final_route
;

drop table if exists testing.valhalla_segment_baseline;
create table testing.valhalla_segment_baseline as
select *
from testing.valhalla_segment
;





select distinct trip_id from testing.waypoint;






select *
from testing.valhalla_map_match_point
where trip_id = '9113834E-158F-4328-B5A4-59B3A5D4BEFC'
  and search_radius = 7.5
  and gps_accuracy = 7.5
order by point_index
;

select *
from testing.valhalla_map_match_shape
where trip_id = '9113834E-158F-4328-B5A4-59B3A5D4BEFC'
  and search_radius = 7.5
  and gps_accuracy = 7.5
order by begin_shape_index
;


select *
from testing.valhalla_route_this
where trip_id = '9113834E-158F-4328-B5A4-59B3A5D4BEFC'
  and search_radius = 7.5
  and gps_accuracy = 7.5
order by begin_edge_index
;

select *
from testing.valhalla_segment
where trip_id = '9113834E-158F-4328-B5A4-59B3A5D4BEFC'
  and search_radius = 7.5
  and gps_accuracy = 7.5
order by begin_edge_index
;


select *
from testing.valhalla_map_match_fail;


-- get counts of search radius and gps accuracy in map matching + routing results
select search_radius,
       gps_accuracy,
       count(*) as trip_count
from testing.valhalla_final_route
group by search_radius,
         gps_accuracy
order by search_radius,
         gps_accuracy
;

-- get counts of search radius and gps accuracy in map matching + routing results
select search_radius,
       gps_accuracy,
       count(*) as trip_count
from testing.valhalla_map_match_fail
group by search_radius,
         gps_accuracy
order by search_radius,
         gps_accuracy
;


-- select count(distinct trip_id)
select *
from testing.valhalla_final_route
-- where trip_id = '4C6B2C40-BC74-4EB2-8081-C9085CCC5A29'
where trip_id = 'F93947BB-AECD-48CC-A0B7-1041DFB28D03'
order by total_distance_km
;

select *
from testing.vw_valhalla_final_route
where rmse_km < 1.0
order by rmse_km desc
;

select count(*) from testing.waypoint



select *
from testing.valhalla_map_match_edge
where search_radius = 7.5
  and gps_accuracy = 7.5
order by begin_shape_index
;


select *
from testing.valhalla_map_match_point
where search_radius = 15
  and gps_accuracy = 15
  and trip_id <> 'F93947BB-AECD-48CC-A0B7-1041DFB28D03'
order by point_index
;



select *
from testing.valhalla_route_this
where trip_id = 'F93947BB-AECD-48CC-A0B7-1041DFB28D03'
and search_radius = 7.5
and gps_accuracy = 7.5
order by segment_index desc
;

select *
from testing.valhalla_route_shape
where trip_id = 'F93947BB-AECD-48CC-A0B7-1041DFB28D03'
  and search_radius = 7.5
  and gps_accuracy = 7.5
;

select *
from testing.valhalla_segment
where trip_id = 'F93947BB-AECD-48CC-A0B7-1041DFB28D03'
  and search_radius = 7.5
  and gps_accuracy = 7.5
;



select *
from testing.valhalla_route_fail;

select *
from testing.valhalla_route_shape;



select count(*) from testing.waypoint
where trip_id = 'F93947BB-AECD-48CC-A0B7-1041DFB28D03'


SELECT *
FROM testing.valhalla_route_this
;


-- look at edges that aren't a street segment
SELECT *
FROM testing.valhalla_map_match_edge
where trip_id = 'F93947BB-AECD-48CC-A0B7-1041DFB28D03'
  and search_radius = 60
order by edge_index;





-- -- Only show trajectories that don't leave the road network
-- drop view if exists testing.vw_valhalla_trajectories;
-- create view testing.vw_valhalla_trajectories as
-- with point AS (
--     SELECT trip_id,
--            count(*) AS point_count,
--            sum(case when edge_index = 0 then 1 else 0 end) AS no_edge_index_count,
--            sum(case when begin_route_discontinuity then 1 else 0 end) +
--            sum(case when end_route_discontinuity then 1 else 0 end) AS discontinuity_count
--     FROM testing.valhalla_map_match_point
--     group by trip_id
--     order by discontinuty_count desc
-- ), edge AS (
--     SELECT trip_id,
--            count(*) AS edge_count,
--            sum(case when names is null then 1 else 0 end) AS unnamed_edge_count,
--            sum(case when speed is null then 1 else 0 end) AS no_speed_edge_count
--     FROM testing.valhalla_map_match_edge
--     group by trip_id
-- )
-- SELECT sum.trip_id,
--        sum.user_id,
--        sum.start_time_utc,
--        point.point_count,
--        point.no_edge_index_count,
--        point.discontinuity_count,
--        edge.edge_count,
--        edge.unnamed_edge_count,
--        edge.no_speed_edge_count,
--        sum.trip_line AS cmt_geom,
--        traj.geom AS vha_geom
-- FROM testing.valhalla_map_match_shape AS traj
--          inner join point ON traj.trip_id = point.trip_id
--          inner join edge ON traj.trip_id = edge.trip_id
--          inner join testing.prod_waypoint_trajectories AS sum ON traj.trip_id = sum.trip_id;


-- check biggest distance from waypoint to map matched point
SELECT *
FROM testing.osm_waypoint_point
where distance_from_trace_point is not null
order by distance_from_trace_point desc;


-- Do distance nulls only occur when point is unmatched - yes
-- SELECT point_type,
--        Count(*) AS point_count
-- FROM testing.osm_waypoint_point
-- WHERE distance_from_trace_point is null
-- group by point_type
-- ;


-- create table for analysing map matching - look at how far waypoints moved to the road network
DROP TABLE IF EXISTS testing.temp_waypoint_point_diff;
CREATE TABLE testing.temp_waypoint_point_diff as
with way AS (
    SELECT row_number() over (partition by trip_id order by time_local) - 1 AS point_index,
           trip_id,
           geom
    FROM testing.prod_waypoints
    WHERE trip_id in (...)
)
SELECT way.trip_id,
       way.point_index,
       pnt.point_type,
       pnt.distance_from_trace_point AS distance,
       way.geom,
       pnt.geom AS matched_geom,
       st_setsrid(st_makeline(way.geom, pnt.geom), 4283) AS line_geom
FROM testing.osm_waypoint_point AS pnt
inner join way ON pnt.trip_id = way.trip_id
    and pnt.point_index = way.point_index
;
analyse testing.temp_waypoint_point_diff;

CREATE INDEX temp_waypoint_point_diff_trip_id_idx ON testing.temp_waypoint_point_diff USING btree (trip_id);



-- look for missing shapes -- 0 rows
with edges AS (
    SELECT distinct trip_id FROM testing.osm_waypoint_edge
)
SELECT * FROM edges
where not exists (SELECT 1 FROM testing.osm_waypoint_shape AS shp WHERE shp.trip_id = edges.trip_id)
;

-- look for missing edges -- 0 rows
with edges AS (
    SELECT distinct trip_id FROM testing.osm_waypoint_edge
)
SELECT shp.trip_id FROM testing.osm_waypoint_shape AS shp
where not exists (SELECT 1 FROM edges WHERE shp.trip_id = edges.trip_id)
;

-- look for missing points -- 0 rows
with pnt AS (
    SELECT distinct trip_id FROM testing.osm_waypoint_point
)
SELECT shp.trip_id FROM testing.osm_waypoint_shape AS shp
where not exists (SELECT 1 FROM pnt WHERE shp.trip_id = pnt.trip_id)
;



SELECT * FROM testing.osm_waypoint_fail;

SELECT count(*) FROM testing.osm_waypoint_shape;

SELECT *
FROM testing.osm_waypoint_edge
where trip_id = '...'
order by edge_index
;

-- 11822
SELECT count(*)
FROM testing.osm_waypoint_point
;


-- drop table planet_osm_roads;
-- drop table planet_osm_line;
-- drop table planet_osm_polygon;
-- drop table planet_osm_point;

SELECT count(*) FROM testing.osm_waypoint_shape;




SELECT trip_id,
       -- st_astext(ST_Transform(trip_line, 4326)) AS geom
       (st_dumppoints(trip_line)).path AS point_num,
       st_x((st_dumppoints(trip_line)).geom) AS longitude,
       st_y((st_dumppoints(trip_line)).geom) AS latitude,
       st_m((st_dumppoints(trip_line)).geom) AS time
FROM testing.prod_waypoint_trajectories
where ...
order by trip_id, point_num;


SELECT trip_id,
       -- st_astext(ST_Transform(trip_line, 4326)) AS geom
       row_number() over (partition by trip_id order by unix_time) AS point_num,
       gps_lon AS longitude,
       gps_lat AS latitude,
       unix_time AS time
FROM testing.map_points
where ...
  and gps_lat is not null
order by trip_id, unix_time
