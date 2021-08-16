


-- 14 mins
drop table if exists testing.simple_au_bdy;
create table testing.simple_au_bdy as
with bdy as (
    select st_setsrid(st_buffer(geom::geography, 5000.0, 4)::geometry, 4326) as geom
    from admin_bdys_202102.state_bdys
-- where st_area(geom::geography) > 1000000.0  -- 1 sq km
)
select st_setsrid(st_buffer(st_union(geom)::geography, -4500.0, 4)::geometry, 4326) as geom
from bdy
;

drop table if exists testing.simple_au_bdy_analysis;
create table testing.simple_au_bdy_analysis as
select st_subdivide(geom, 256) as geom
from testing.simple_au_bdy
;
