


# TODO: look at using valhalla IDs for road segments
#   - WARNING: IDs are transient and will change between OSM data versions

# TODO: Avoid using latest Valhalla version until Edge ID issue is resolved

# TODO: account for large gaps in waypoints due to GPS/data missing
#  need to route these, not map match them - causes weird routes

import json
import logging
import multiprocessing
import os
import psycopg2  # need to install psycopg2 package
import psycopg2.extras
import requests
# import sys

from datetime import datetime
from pathlib import Path
from psycopg2 import pool
from psycopg2.extensions import AsIs

# this directory
runtime_directory = os.path.dirname(os.path.realpath(__file__))

# six degrees of precision used in Valhalla encoded polyline (DO NOT EDIT)
inverse_precision = 1.0 / 1e6

# set of search radii to use in map matching
# will iterate over these and select good matches as they increase; to get the best route possible
search_radii = [10, 20, 30, 40, 50, 60, 70]
# search_radii = [70]
iteration_count = len(search_radii)

# number of CPUs to use in processing (defaults to local CPU count)
cpu_count = multiprocessing.cpu_count()

# create postgres connect string
pg_connect_string = "dbname=geo host=localhost port=5432 user=postgres password=password"

# create postgres connection pool
pg_pool = psycopg2.pool.SimpleConnectionPool(1, cpu_count, pg_connect_string)

# TODO: make these runtime arguments

# valhalla URLs
valhalla_base_url = "http://localhost:8002/"
map_matching_url =  valhalla_base_url + "trace_attributes"
routing_url =  valhalla_base_url + "route"

# input GPS points table
input_table = "testing.waypoint"

# Does data have timestamps
use_timestamps = False

# latitude field
lat_field = "latitude"

# longitude field
lon_field = "longitude"

# timestamp field
time_field = "time_utc"

# point_index_field
point_index_field = "point_index"

# trajectory_id field
trajectory_id_field = "trip_id"

# # file path to SQL file the create non-PII trajectories geoms
# non_pii_sql_file = os.path.join(os.path.dirname(os.path.realpath(__file__)), "07_create_non_pii_trips_table.sql")


def main():
    start_time = datetime.now()

    # get postgres connection & dictionary cursor (returns rows as dicts)
    pg_conn = pg_pool.getconn()
    pg_conn.autocommit = True
    pg_cur = pg_conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

    # --------------------------------------------------------------------------------------
    # WARNING: drops and recreates output tables
    # --------------------------------------------------------------------------------------

    # optional: recreate output tables
    sql_file = os.path.join(runtime_directory, "postgres_scripts", "01_create_tables.sql")
    sql = open(sql_file, "r").read()
    pg_cur.execute(sql)

    logger.info("\t - output tables recreated : {}".format(datetime.now() - start_time))
    start_time = datetime.now()

    # --------------------------------------------------------------------------------------

    # get trajectory data from postgres
    if use_timestamps:
        sql = """SELECT {0},
                        count(*) AS point_count,
                        jsonb_agg(jsonb_build_object('lat', {2}, 'lon', {3}, 'time', {4}) ORDER BY {1}) AS points 
                 FROM {5} WHERE trip_id = 'F93947BB-AECD-48CC-A0B7-1041DFB28D03'
                 GROUP BY {0}""" \
            .format(trajectory_id_field, point_index_field, lat_field, lon_field, time_field, input_table)
    else:
        sql = """SELECT {0},
                        count(*) AS point_count,
                        jsonb_agg(jsonb_build_object('lat', {2}, 'lon', {3}) ORDER BY {1}) AS points 
                 FROM {4} WHERE trip_id = 'F93947BB-AECD-48CC-A0B7-1041DFB28D03'
                 GROUP BY {0}""" \
            .format(trajectory_id_field, point_index_field, lat_field, lon_field, input_table)

    pg_cur.execute(sql)
    job_list = pg_cur.fetchall()
    job_count = len(job_list)

    logger.info("Got {} trips to route, starting routing : {}"
                .format(len(job_list), datetime.now() - start_time))
    start_time = datetime.now()

    # for each trajectory - send a map match request to Valhalla using multiprocessing
    mp_pool = multiprocessing.Pool(cpu_count)
    mp_results = mp_pool.imap_unordered(route_trajectory, job_list)
    mp_pool.close()
    mp_pool.join()

    # check parallel processing results
    for mp_result in mp_results:
        if mp_result is not None:
            print("WARNING: multiprocessing error : {}".format(mp_result))

    logger.info("\t - all segments routed : {}".format(datetime.now() - start_time))
    start_time = datetime.now()

    # update stats ON route tables
    pg_cur.execute("ANALYSE testing.valhalla_route_shape")
    pg_cur.execute("ANALYSE testing.valhalla_route_fail")
    logger.info("\t - tables analysed : {}".format(datetime.now() - start_time))
    start_time = datetime.now()

    # optional: create indexes ON output tables
    try:
        sql_file = os.path.join(runtime_directory, "postgres_scripts", "05_create_route_indexes.sql")
        sql = open(sql_file, "r").read()
        pg_cur.execute(sql)

        logger.info("\t - indexes created : {}".format(datetime.now() - start_time))
        start_time = datetime.now()
    except:
        # meh!
        pass

    # get routing table counts
    pg_cur.execute("SELECT count(*) FROM testing.valhalla_route_shape")
    traj_route_count = pg_cur.fetchone()[0]
    pg_cur.execute("SELECT count(*) FROM testing.valhalla_route_fail")
    fail_route_count = pg_cur.fetchone()[0]

    logger.info("\t - routing results")
    logger.info("\t\t - {:,} trips routed".format(traj_route_count))
    if fail_route_count > 0:
        logger.warning("\t\t - {:,} trips FAILED".format(fail_route_count))

    # # stitch results together
    # sql_file = os.path.join(runtime_directory, "postgres_scripts", "06_stitch_routes.sql")
    # sql = open(sql_file, "r").read()
    # pg_cur.execute(sql)

    # close postgres connection
    pg_cur.close()
    pg_pool.putconn(pg_conn)


# edit these to taste
def get_routing_parameters():

    request_dict = dict()

    request_dict["costing"] = "auto"
    request_dict["units"] = "kilometres"

    # TODO: add more parameters/constraints here if required

    return request_dict


def route_trajectory(job):
    # get postgres connection from pool
    pg_conn = pg_pool.getconn()
    pg_conn.autocommit = True
    pg_cur = pg_conn.cursor()

    # get inputs
    traj_id = job[0]
    search_radius = job[1]
    segment_index = job[2]

    start_location = dict()
    start_location["lat"] = job[3]
    start_location["lon"] = job[4]
    start_location["radius"] = 300
    start_location["rank_candidates"] = False  # allows the best road to be chosen, not necessarily the closest road

    end_location = dict()
    end_location["lat"] = job[5]
    end_location["lon"] = job[6]
    end_location["radius"] = 300
    end_location["rank_candidates"] = False

    # add parameters and start & end points to request
    input_points = list()
    input_points.append(start_location)
    input_points.append(end_location)

    # TODO: this could be done better, instead of evaluating this every request
    request_dict = get_routing_parameters()
    request_dict["locations"] = input_points

    # convert request data to JSON string
    json_payload = json.dumps(request_dict)

    # get a route
    try:
        r = requests.post(routing_url, data=json_payload)
    except Exception as e:
        # if complete failure - Valhalla has possibly crashed
        return "Valhalla routing failure ON trajectory {} : {}".format(traj_id, e)

    # add results to lists of shape, edge and point dicts for insertion into postgres
    if r.status_code == 200:
        response_dict = r.json()

        # DEBUGGING
        if segment_index == 81 and search_radius == 60:
            with open(os.path.join(Path.home(), "tmp", "valhalla_response.json"), "w") as response_file:
                json.dump(response_dict, response_file, indent=4, sort_keys=True)

        # output matched route geometry
        legs = response_dict.get("trip")["legs"]

        if legs is not None and len(legs) > 0:
            # for each route leg - construct postgis geometry string for insertion into postgres
            for leg in legs:
                distance_m = float(leg["summary"]["length"]) * 1000.0
                shape_coords = decode(leg["shape"])  # decode Google encoded polygon
                point_list = list()

                if len(shape_coords) > 1:
                    point_count = 0

                    for coords in shape_coords:
                        point_list.append("{} {}".format(coords[0], coords[1]))
                        point_count +=1

                    geom_string = "ST_GeomFromText('LINESTRING("
                    geom_string += ",".join(point_list)
                    geom_string += ")', 4326)"

                    segment_type = "route"

                    shape_sql = """insert into testing.valhalla_route_shape
                                         values ('{}', {}, {}, {}, {}, '{}', {})""" \
                        .format(traj_id, search_radius, segment_index, distance_m,
                                point_count, segment_type, geom_string)
                    pg_cur.execute(shape_sql)
                else:
                    fail_sql = """insert into testing.valhalla_route_fail (trip_id, search_radius, segment_index, error)
                                      values ('{}', {}, {}, '{}')""" \
                        .format(traj_id, search_radius, segment_index, "Linestring only has one point")
                    pg_cur.execute(fail_sql)

    else:
        # get error
        e = json.loads(r.content)

        curl_command = 'curl --header "Content-Type: application/json" --request POST --data \'\'{}\'\' {}' \
            .format(json_payload, routing_url)

        sql = "insert into testing.valhalla_route_fail values ('{}', {}, {}, '{}', '{}', '{}')" \
            .format(traj_id, search_radius, segment_index, e["error_code"], e["error"],
                    str(e["status_code"]) + ":" + e["status"], curl_command)

        pg_cur.execute(sql)

    # clean up
    pg_cur.close()
    pg_pool.putconn(pg_conn)


# decode a Google encoded polyline string
def decode(encoded):
    decoded = []
    previous = [0, 0]
    i = 0

    # for each byte
    while i < len(encoded):
        # for each coord (lat, lon)
        ll = [0, 0]
        for j in [0, 1]:
            shift = 0
            byte = 0x20

            # keep decoding bytes until you have this coord
            while byte >= 0x20:
                byte = ord(encoded[i]) - 63
                i += 1
                ll[j] |= (byte & 0x1f) << shift
                shift += 5

            # get the final value adding the previous offset and remember it for the next
            ll[j] = previous[j] + (~(ll[j] >> 1) if ll[j] & 1 else (ll[j] >> 1))
            previous[j] = ll[j]

        # scale by the precision, chop off long coords and flip the positions so the coords
        # are the database friendly lon, lat format
        decoded.append([float('%.6f' % (ll[1] * inverse_precision)), float('%.6f' % (ll[0] * inverse_precision))])

    # hand back the list of coordinates
    return decoded


def get_id_list(pg_cur, id_field, table_name):
    pg_cur.execute("SELECT {} FROM {}".format(id_field, table_name))
    rows = pg_cur.fetchall()

    output_list = list()

    for row in rows:
        output_list.append(row[0])

    return output_list


if __name__ == '__main__':
    full_start_time = datetime.now()

    # set logger
    log_file = os.path.abspath(__file__).replace(".py", ".log")
    logging.basicConfig(filename=log_file, level=logging.DEBUG, format="%(asctime)s %(message)s",
                        datefmt="%m/%d/%Y %I:%M:%S %p")

    logger = logging.getLogger()
    logger.setLevel(logging.INFO)

    # setup logger to write to screen as well as writing to log file
    # define a Handler which writes INFO messages or higher to the sys.stderr
    console = logging.StreamHandler()
    console.setLevel(logging.INFO)
    # set a format which is simpler for console use
    formatter = logging.Formatter('%(name)-12s: %(levelname)-8s %(message)s')
    # tell the handler to use this format
    console.setFormatter(formatter)
    # add the handler to the root logger
    logging.getLogger('').addHandler(console)

    task_name = "Map match & route waypoints to OSM"
    system_name = "iag_geo"

    logger.info("{} started : {}".format(task_name, datetime.now()))

    main()

    time_taken = datetime.now() - full_start_time
    logger.info("{} finished : {}".format(task_name, time_taken))
