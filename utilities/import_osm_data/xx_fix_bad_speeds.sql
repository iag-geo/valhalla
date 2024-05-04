

-- -- fix bad speeds
-- update osm.osm_road set maxspeed = '20' where maxspeed = '10 mph';
-- update osm.osm_road set maxspeed = '60' where maxspeed = '35 mph';
-- update osm.osm_road set maxspeed = '70' where maxspeed = '40 mph';
-- update osm.osm_road set maxspeed = '100' where maxspeed = '60 mph';
-- update osm.osm_road set maxspeed = '100' where maxspeed = '65 mph';
-- update osm.osm_road set maxspeed = '110' where maxspeed = '70 mph';
-- update osm.osm_road set maxspeed = '110' where maxspeed = '75 mph';
-- update osm.osm_road set maxspeed = '60' where maxspeed = '35 mph';
-- update osm.osm_road set maxspeed = null where maxspeed in ('AU:urban', 'unknown');
-- update osm.osm_road set maxspeed = split_part(maxspeed, ';', 1) where maxspeed like '%;%';


with speed as (
    select maxspeed,
           count(*) as road_count
    from osm.osm_road
    group by maxspeed
    order by maxspeed
)
select rd.*
from osm.osm_road as rd
inner join speed on rd.maxspeed = speed.maxspeed
where speed.road_count <= 10
order by rd.maxspeed
;


select type,
       avg(maxspeed::integer)::integer as avg_max_speed
from osm.osm_road
group by type
order by avg_max_speed desc
;
