

-- -- buffer states out & then in to create a ~500-1500m buffer to exclude invalid AU GPS data with
-- -- 11 mins
-- drop table if exists testing.simple_au_bdy_2;
-- create table testing.simple_au_bdy_2 as
-- with bdy as (
--     select st_setsrid(st_buffer(geom::geography, 1000.0, 1)::geometry, 4326) as geom
--     from admin_bdys_202102.state_bdys
-- -- where st_area(geom::geography) > 1000000.0  -- 1 sq km
-- )
-- select st_setsrid(st_buffer(st_union(geom)::geography, -500.0, 1)::geometry, 4326) as geom
-- from bdy
-- ;

-- buffer states out & then in to create a ~500-1500m buffer to exclude invalid AU GPS data with
-- 11 mins
drop table if exists testing.simple_au_bdy_2;
create table testing.simple_au_bdy_2 as
with bdy as (
    select st_setsrid(st_buffer(geom::geography, 300.0, 1)::geometry, 4326) as geom
    from admin_bdys_202102.state_bdys
-- where st_area(geom::geography) > 1000000.0  -- 1 sq km
)
select st_union(geom) as geom
from bdy
;


-- -- split into single polygons and subdivide the complex ones for faster processing
-- drop table if exists testing.simple_au_bdy_2_analysis;
-- create table testing.simple_au_bdy_2_analysis as
-- with bdy as (
--     select (st_dump(geom)).geom as geom
--     from testing.simple_au_bdy_2
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
    select ST_SimplifyPreserveTopology(geom, 0.001) as geom
    from bdy
)
select st_subdivide(geom, 256) as geom
from thin
;



-- 881 sections
select count(*) from testing.simple_au_bdy_2_analysis;
