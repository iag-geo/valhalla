
-- create temp table of street segment centroids to get their remoteness region
drop table if exists temp_osm;
create temporary table temp_osm as
select osm_id,
       maxspeed,
       type,
       st_setsrid(st_centroid(geom), 4283) as geom
from osm.osm_road
where type not in ('residential', 'unclassified', 'service', 'living_street', 'busway')
;
create index temp_osm_geom_gist on temp_osm using gist (geom);


-- segments missing speed limits by region type
with ra_osm as (
    select temp_osm.*,
           ra.ra_name_2021 as region
    from temp_osm
    inner join census_2021_bdys_gda94.ra_2021_aust_gda94 as ra
        on st_intersects(ra.geom, temp_osm.geom)
    where ra.ra_name_2021 = 'Major Cities of Australia'
), missing as (
    select type,
           region,
        count(distinct osm_id) as missing_osm_id_count
    from ra_osm
    where maxspeed is NULL
    group by type,
             region
), good as (
    select type,
           region,
           count(distinct osm_id) as good_osm_id_count
    from ra_osm
    where maxspeed is not NULL
    group by type,
             region
)
select good.region,
       good.type,
       good_osm_id_count,
       missing_osm_id_count
from good
inner join missing on good.type = missing.type
    and good.region = missing.region
-- order by region,
--          type
order by missing_osm_id_count desc
;


-- +-------------------------+--------------+-----------------+--------------------+
-- |region                   |type          |good_osm_id_count|missing_osm_id_count|
-- +-------------------------+--------------+-----------------+--------------------+
-- |Major Cities of Australia|tertiary      |38408            |37117               |
-- |Major Cities of Australia|secondary     |37826            |13206               |
-- |Major Cities of Australia|primary       |45777            |6113                |
-- |Major Cities of Australia|primary_link  |1863             |4888                |
-- |Major Cities of Australia|trunk_link    |1659             |3011                |
-- |Major Cities of Australia|motorway_link |7076             |2990                |
-- |Major Cities of Australia|secondary_link|954              |2656                |
-- |Major Cities of Australia|tertiary_link |644              |2639                |
-- |Major Cities of Australia|trunk         |29006            |1248                |
-- |Major Cities of Australia|motorway      |7482             |116                 |
-- +-------------------------+--------------+-----------------+--------------------+

