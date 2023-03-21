
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





select osm_id,
       tags->'maxspeed'::smallint as maxspeed,
       tags
from osm.planet_osm_line
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


