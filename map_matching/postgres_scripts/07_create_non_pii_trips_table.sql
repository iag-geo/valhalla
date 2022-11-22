
-- chop the first and last streets off the route plus one point each end
insert into temp_{0}_{1}_{2}_map_match_shape_non_pii
with edge AS (
    SELECT trip_id,
           osm_id,
           min(begin_shape_index) AS min_point_index,
           max(end_shape_index) AS max_point_index
    FROM temp_{0}_{1}_{2}_map_match_edge
    WHERE trip_id not in (SELECT trip_id FROM temp_{0}_{1}_{2}_map_match_shape_non_pii)
    GROUP BY trip_id,
             osm_id
), mm AS (
    SELECT trip_id,
           min(max_point_index) + 3 AS max_start_point_index,
           max(min_point_index) - 1 AS min_end_point_index
    FROM edge
    group by trip_id
), pnt AS (
    SELECT trip_id,
           (ST_DumpPoints(geom)).geom AS geom,
           (ST_DumpPoints(geom)).path[1] AS point_index
    FROM temp_{0}_{1}_{2}_map_match_shape
), trips AS (
    SELECT mm.trip_id,
           st_makeline(pnt.geom order by pnt.point_index) AS geom
    FROM mm
             inner join pnt ON mm.trip_id = pnt.trip_id
        and pnt.point_index > max_start_point_index
        and pnt.point_index < min_end_point_index
    group by mm.trip_id
)
SELECT trip_id,
       st_length(geom::geography),
       geom
FROM trips
;
analyse temp_{0}_{1}_{2}_map_match_shape_non_pii;
