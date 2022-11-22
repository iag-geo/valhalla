

-- -- buffer states out & then in to create a ~500-1500m buffer to exclude invalid AU GPS data with
-- -- 11 mins
-- drop table if exists testing.simple_au_bdy;
-- create table testing.simple_au_bdy as
-- with bdy as (
--     select st_setsrid(st_buffer(geom::geography, 5000.0, 4)::geometry(POLYGON), 4326) as geom
--     from admin_bdys_202208.state_bdys
-- -- where st_area(geom::geography) > 1000000.0  -- 1 sq km
-- )
-- select st_setsrid(st_buffer(st_union(geom)::geography, -4500.0, 2)::geometry(MULTIPOLYGON), 4326) as geom
-- from bdy
-- where st_geometrytype(geom) IN ('POLYGON')
-- ;

-- buffer the coastline out & then in to create a ~500-1500m buffer to exclude invalid AU GPS data with
-- 11 mins
drop table if exists testing.simple_au_bdy_2;
create table testing.simple_au_bdy_2 as
with bdy as (
    select st_setsrid(st_buffer(geom::geography, 300.0, 1)::geometry, 4326) as geom
    from admin_bdys_202208.abs_2016_gccsa
-- where st_area(geom::geography) > 1000000.0  -- 1 sq km
)
select st_union(geom) as geom
from bdy
;
ALTER TABLE testing.simple_au_bdy_2 ALTER COLUMN geom type geometry(MultiPolygon, 4326) USING ST_Multi(geom);

-- -- split into single polygons and subdivide the complex ones for faster processing
-- drop table if exists testing.simple_au_bdy_analysis;
-- create table testing.simple_au_bdy_analysis as
-- with bdy as (
--     select (st_dump(geom)).geom as geom
--     from testing.simple_au_bdy
-- )
-- select st_subdivide(geom, 256) as geom
-- from bdy
-- ;


-- split into single polygons, simplify them and subdivide the complex ones for faster processing
drop table if exists testing.simple_au_bdy_2_analysis;
create table testing.simple_au_bdy_2_analysis as
with bdy as (
    select (st_dump(geom)).geom as geom
    from testing.simple_au_bdy_2
), thin as (
    select ST_Simplify(geom, 0.002) as geom
    from bdy
)
select st_subdivide(geom, 256) as geom
from bdy
;



-- 881 sections
select count(*), st_geometrytype(geom) as geom_type
from testing.simple_au_bdy_2_analysis
group by st_geometrytype(geom)
;
