

drop table if exists testing.temp_split_shape cascade;
create table testing.temp_split_shape as
with pnt as (
    select *
    from testing.valhalla_point
    where point_type = 'matched'
)
select trip.trip_id,
       pnt.point_index,
       trip.search_radius,
       pnt.point_type,
       trip.distance,
       st_split(trip.geom, ST_Snap(pnt.geom, trip.geom, 0.0001)) as geom
from testing.valhalla_shape as trip
inner join pnt on trip.trip_id = pnt.trip_id
and trip.search_radius = pnt.search_radius
;

alter table testing.temp_split_shape add constraint temp_split_shape_pkey primary key (trip_id, point_index, search_radius);
create index temp_split_shape_geom_idx on testing.temp_split_shape using gist (geom);
ALTER TABLE testing.temp_split_shape CLUSTER ON temp_split_shape_geom_idx;


select * from testing.temp_split_shape
where trip_id = 'F93947BB-AECD-48CC-A0B7-1041DFB28D03'
  and search_radius = 60
order by point_index
;


