
-- required for tags (including maxspeed) on roads
CREATE EXTENSION hstore;


select count(*) -- 2556697
from osm.planet_osm_line;


select osm_id,
       count(*) as cnt
from osm.osm_shop
group by osm_id
having count(*) > 1;



-- test amenities
select type, count(*) as cnt
from osm.osm_amenity
group by type
order by cnt desc;

-- hospital


-- test land use
select type, count(*) as cnt
from osm.osm_landuse
group by type
order by cnt desc;

select st_geometrytype(geom), count(*) as cnt
from osm.osm_landuse
group by st_geometrytype(geom);



select * from osm.planet_osm_point
where osm_id = 6698621181;












-- select * from osm.osm_railway_station_polygons
-- where type like '%, %';



-- select * from osm.osm_railway_station_polygons;


-- public_transport
-- platform
-- station



-- select type,
--        count(*) as cnt
-- from osm.osm_shop_polygons
-- group by type
-- order by cnt desc;



select *
from   osm.planet_osm_polygon
where amenity is not null;





select tags->'maxspeed' as maxspeed,
       count(*)
from osm.planet_osm_line
WHERE highway IS NOT NULL
  AND highway NOT IN (
                      '',
                      'footway',
                      'steps',
                      'cycleway',
                      'proposed',
                      'construction',
                      'path',
                      'track',
                      'pedestrian',
                      'bus_guideway',
                      'bridleway',
                      'corridor',
                      'abandoned',
                      'raceway',
                      'escape',
                      'tree_row',
                      'crossing',
                      'platform',
                      'planned',
                      'bus_stop',
                      'rest_area',
                      'disused',
                      '*',
                      'co',
                      'driveway',
                      'elevator',
                      'no',
                      'none',
                      'services',
                      'traffic_island',
                      'trail'
--                      'yes'

    )
group by maxspeed
order by maxspeed
;


select *
from osm.planet_osm_line
where osm_id = 181733096
;


-- distances of roads with/without speed limits
select type,
       count(*) as row_count,
       sum(case when maxspeed is null then 1 else 0 end) as no_speed_row_count,
       sum(case when maxspeed is not null then 1 else 0 end) as speed_row_count,
       (sum(length) / 1000.0)::numeric(10,1) as length,
       (sum(case when maxspeed is null then length else 0.0 end) / 1000.0)::numeric(10,1) as no_speed_length,
       (sum(case when maxspeed is not null then length else 0.0 end) / 1000.0)::numeric(10,1) as speed_length
from osm.osm_road
group by type
order by type
;


-- select osm_id,
--        name,
--        operator,
--        landuse,
--        way as geom
-- from osm.planet_osm_polygon
-- where man_made is not null;
--
--
-- select count(*) as cnt,
--        service,
--        shop
-- from osm.planet_osm_polygon
-- group by service,
--          shop
-- order by service,
--          shop;
--
--
--
--
-- select count(*) from osm.osm_shop_points; -- 30948
-- select count(*) from osm.osm_shop_polygons; -- 14023
--
-- select count(*) from osm.osm_amenity_points; -- 117718
-- select count(*) from osm.osm_amenity_polygons; -- 87587


