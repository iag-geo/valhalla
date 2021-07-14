
-- chop the first and last streets off the route plus one point each end
insert into testing.valhalla_map_match_shape_non_pii
with edge as (
    SELECT trip_id,
           osm_id,
           min(begin_shape_index) as min_point_index,
           max(end_shape_index) as max_point_index
    FROM testing.valhalla_map_match_edge
    WHERE trip_id not in (select trip_id from testing.valhalla_map_match_shape_non_pii)
    GROUP BY trip_id,
             osm_id
), mm as (
    select trip_id,
           min(max_point_index) + 3 as max_start_point_index,
           max(min_point_index) - 1 as min_end_point_index
    from edge
    group by trip_id
), pnt as (
    select trip_id,
           (ST_DumpPoints(geom)).geom as geom,
           (ST_DumpPoints(geom)).path[1] as point_index
    from testing.valhalla_map_match_shape
), trips as (
    select mm.trip_id,
           st_makeline(pnt.geom order by pnt.point_index) as geom
    from mm
             inner join pnt on mm.trip_id = pnt.trip_id
        and pnt.point_index > max_start_point_index
        and pnt.point_index < min_end_point_index
    group by mm.trip_id
)
select trip_id,
       st_length(geom::geography),
       geom
from trips
;
analyse testing.valhalla_map_match_shape_non_pii;
