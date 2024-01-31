
-- segments missing speed limits by region type
with osm as (
    select osm_id,
           maxspeed,
           type,
           st_setsrid(st_centroid(geom), 4283) as geom
    from osm.osm_road
), ra_osm as (
    select osm.*,
           ra.ra_name_2021
    from osm
    inner join census_2021_bdys_gda94.ra_2021_aust_gda94 as ra on st_intersects(ra.geom, osm.geom)
), missing as (
    select type,
           ra_name_2021,
        count(distinct osm_id) as missing_osm_id_count
    from ra_osm
    where maxspeed is NULL
        and type not in ('residential', 'unclassified', 'service')
    group by type,
             ra_name_2021
), good as (
    select type,
           ra_name_2021,
           count(distinct osm_id) as good_osm_id_count
    from ra_osm
    where maxspeed is not NULL
        and type not in ('residential', 'unclassified', 'service')
    group by type,
             ra_name_2021
)
select good.type,
       good.ra_name_2021,
       good_osm_id_count,
       missing_osm_id_count
from good
inner join missing on good.type = missing.type
order by missing_osm_id_count desc
;


-- +--------------+------------+
-- |type          |osm_id_count|
-- +--------------+------------+
-- |tertiary      |70050       |
-- |secondary     |30361       |
-- |primary       |11694       |
-- |primary_link  |5640        |
-- |motorway_link |4402        |
-- |trunk_link    |4397        |
-- |trunk         |4115        |
-- |secondary_link|4059        |
-- |tertiary_link |3910        |
-- |motorway      |131         |
-- +--------------+------------+
