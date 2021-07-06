
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
from psycopg2 import pool
from psycopg2.extensions import AsIs

# this directory
sql_directory = os.path.dirname(os.path.realpath(__file__))

# six degrees of precision used in Valhalla encoded polyline (DO NOT EDIT)
inverse_precision = 1.0 / 1e6

# set of serach radii to use in map matching
# will iterate over these and select good matches as they increase; to get the best route possible
search_radii = [10, 20, 30, 40, 50, 60]

# number of CPUs to use in processing (defaults to local CPU count)
cpu_count = multiprocessing.cpu_count()

# create postgres connect string
pg_connect_string = "dbname=geo host=localhost port=5432 user=postgres password=password"

# create postgres connection pool
pg_pool = psycopg2.pool.SimpleConnectionPool(1, cpu_count, pg_connect_string)

# TODO: make these runtime arguments

# valhalla map matching server
valhalla_server_url = "http://localhost:8002/trace_attributes"

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
# non_pii_sql_file = os.path.join(os.path.dirname(os.path.realpath(__file__)), "02_create_non_pii_trips_table.sql")


def main():
    start_time = datetime.now()

    # get postgres connection & dictionary cursor (returns rows as dicts)
    pg_conn = pg_pool.getconn()
    pg_conn.autocommit = True
    pg_cur = pg_conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

    # --------------------------------------------------------------------------------------
    # WARNING: deletes all routing results
    # --------------------------------------------------------------------------------------

    # optional: recreate output tables
    sql_file = os.path.join(sql_directory, "01_create_tables.sql")
    sql = open(sql_file, "r").read()
    pg_cur.execute(sql)

    logger.info("\t - output tables recreated : {}".format(datetime.now() - start_time))
    start_time = datetime.now()

    # --------------------------------------------------------------------------------------

    # get trajectory data from postgres
    if use_timestamps:
        sql = """SELECT {0},
                        count(*) as point_count,
                        jsonb_agg(jsonb_build_object('lat', {2}, 'lon', {3}, 'time', {4}) ORDER BY {1}) AS points 
                 FROM {5}
                 GROUP BY {0}""" \
            .format(trajectory_id_field, point_index_field, lat_field, lon_field, time_field, input_table)
    else:
        sql = """SELECT {0},
                        count(*) as point_count,
                        jsonb_agg(jsonb_build_object('lat', {2}, 'lon', {3}) ORDER BY {1}) AS points 
                 FROM {4}
                 GROUP BY {0}""" \
            .format(trajectory_id_field, point_index_field, lat_field, lon_field, input_table)

    pg_cur.execute(sql)
    job_list = pg_cur.fetchall()
    job_count = len(job_list)

    logger.info("Got {} trajectories, starting map matching : {}".format(len(job_list), datetime.now() - start_time))
    start_time = datetime.now()

    # for each trajectory - send a map match request to Valhalla using multiprocessing
    mp_pool = multiprocessing.Pool(cpu_count)
    mp_results = mp_pool.imap_unordered(map_match_trajectory, job_list)
    mp_pool.close()
    mp_pool.join()

    # check parallel processing results
    for mp_result in mp_results:
        if mp_result is not None:
            print("WARNING: multiprocessing error : {}".format(mp_result))

    logger.info("\t - all trajectories map matched : {}".format(datetime.now() - start_time))
    start_time = datetime.now()

    # # create anonymous trajectories
    # sql = open(non_pii_sql_file, "r").read()
    # pg_cur.execute(sql)
    # logger.info("\t - non-pii trajectories created : {}".format(datetime.now() - start_time))

    # update stats on tables
    pg_cur.execute("ANALYSE testing.valhalla_edge")
    pg_cur.execute("ANALYSE testing.valhalla_shape")
    pg_cur.execute("ANALYSE testing.valhalla_point")
    pg_cur.execute("ANALYSE testing.valhalla_fail")
    logger.info("\t - tables analysed : {}".format(datetime.now() - start_time))
    start_time = datetime.now()

    # optional: create indexes on output tables
    try:
        sql_file = os.path.join(sql_directory, "03_create_indexes.sql")
        sql = open(sql_file, "r").read()
        pg_cur.execute(sql)

        logger.info("\t - indexes created : {}".format(datetime.now() - start_time))
    except:
        # meh!
        pass

    # get table counts
    pg_cur.execute("SELECT count(*) FROM testing.valhalla_shape")
    traj_count = pg_cur.fetchone()[0]
    pg_cur.execute("SELECT count(*) FROM testing.valhalla_edge")
    edge_count = pg_cur.fetchone()[0]
    pg_cur.execute("SELECT count(*) FROM testing.valhalla_point")
    point_count = pg_cur.fetchone()[0]
    pg_cur.execute("SELECT count(*) FROM testing.valhalla_fail")
    fail_count = pg_cur.fetchone()[0]

    # close postgres connection
    pg_cur.close()
    pg_pool.putconn(pg_conn)

    logger.info("Row counts")
    logger.info("\t - {:,} input trajectories".format(job_count))
    logger.info("\t - {:,} map matched trajectories".format(traj_count))
    logger.info("\t\t - {:,} edges".format(edge_count))
    logger.info("\t\t - {:,} points".format(point_count))
    logger.warning("\t - {:,} trajectories FAILED".format(fail_count))


# edit these to taste
def get_map_matching_parameters(search_radius):

    request_dict = dict()

    request_dict["costing"] = "auto"
    request_dict["directions_options"] = {"units": "kilometres"}
    request_dict["shape_match"] = "walk_or_snap"
    request_dict["trace_options"] = {"search_radius": search_radius}

    if use_timestamps:
        request_dict["use_timestamps"] = "true"

    request_dict["filters"] = {"attributes": ["edge.way_id",
                                              "edge.names",
                                              "edge.road_class",
                                              "edge.speed",
                                              "edge.begin_shape_index",
                                              "edge.end_shape_index",
                                              "matched.point",
                                              "matched.type",
                                              "matched.edge_index",
                                              "matched.begin_route_discontinuity",
                                              "matched.end_route_discontinuity",
                                              "matched.distance_along_edge",
                                              "matched.distance_from_trace_point",
                                              "shape"],
                               "action": "include"}

    return request_dict


def map_match_trajectory(job):
    # get postgres connection from pool
    pg_conn = pg_pool.getconn()
    pg_conn.autocommit = True
    pg_cur = pg_conn.cursor()

    # trajectory ID
    traj_id = job[0]
    # traj_point_count = job[1]

    input_points = job[2]

    # add point_index to points to enable iteration
    input_points_with_index = [{**e, "point_index": i} for i, e in enumerate(input_points)]

    # add parameters and trajectory to request
    # TODO: this could be done better, instead of evaluating this every request
    request_dict = get_map_matching_parameters(20)
    request_dict["shape"] = input_points

    # convert request data to JSON string
    json_payload = json.dumps(request_dict)

    # get a route
    try:
        r = requests.post(valhalla_server_url, data=json_payload)
    except Exception as e:
        # if complete failure - Valhalla has possibly crashed
        return "Valhalla routing failure on trajectory {} : {}".format(traj_id, e)

    # add results to lists of shape, edge and point dicts for insertion into postgres
    if r.status_code == 200:
        response_dict = r.json()

        # # DEBUGGING
        # response_file = open("/Users/s57405/tmp/valhalla_response.json", "w")
        # response_file.writelines(json.dumps(response_dict))
        # response_file.close()

        # output matched route geometry
        shape = response_dict.get("shape")

        if shape is not None:
            # construct postgis geometry string for insertion into postgres
            shape_coords = decode(shape)  # decode Google encoded polygon
            point_list = list()

            if len(shape_coords) > 1:
                for coords in shape_coords:
                    point_list.append("{} {}".format(coords[0], coords[1]))

                geom_string = "ST_GeomFromText('LINESTRING("
                geom_string += ",".join(point_list)
                geom_string += ")', 4326)"

                shape_sql = """insert into testing.valhalla_shape
                                     values ('{0}', st_length({1}::geography), {1})""" \
                    .format(traj_id, geom_string)
                pg_cur.execute(shape_sql)
            else:
                fail_sql = "insert into testing.valhalla_fail (trip_id, error) values ('{}', '{}')" \
                    .format(traj_id, "Linestring only has one point")
                pg_cur.execute(fail_sql)

        # output edge information
        edges = response_dict.get("edges")

        if edges is not None:
            edge_sql_list = list()
            edge_index = 0

            for edge in edges:
                edge[trajectory_id_field] = traj_id
                edge["osm_id"] = edge.pop("way_id")
                edge["edge_index"] = edge_index

                # bug in Valhalla(?) - occasionally returns empty dict "{}" for "sign" attribute
                if edge.get("sign") is not None:
                    edge.pop("sign", None)

                columns = list(edge.keys())
                values = [edge[column] for column in columns]

                insert_statement = "INSERT INTO testing.valhalla_edge (%s) VALUES %s"
                sql = pg_cur.mogrify(insert_statement, (AsIs(','.join(columns)), tuple(values))).decode("utf-8")
                edge_sql_list.append(sql)

                edge_index += 1

            # insert all edges in a single go
            pg_cur.execute(";".join(edge_sql_list))

        # output point data
        points = response_dict.get("matched_points")

        matched_points = list()

        if points is not None:
            point_sql_list = list()
            point_index = 0

            for point in points:
                # get matched points for use in the next iteration
                matched_point = dict()
                matched_point["traj_id"] = traj_id
                matched_point["point_index"] = point_index
                matched_point["lat"] = point["lat"]
                matched_point["lon"] = point["lon"]
                matched_points.append(matched_point)

                # alter point dict for input into Postgres
                point[trajectory_id_field] = traj_id
                point["point_type"] = point.pop("type")
                point[point_index_field] = point_index
                point["geom"] = "st_setsrid(st_makepoint({},{}),4326)" \
                    .format(point["lon"], point["lat"])

                # drop coordinates to save table space
                point.pop("lat", None)
                point.pop("lon", None)

                columns = list(point.keys())
                values = [point[column] for column in columns]

                insert_statement = "INSERT INTO testing.valhalla_point (%s) VALUES %s"
                sql = pg_cur.mogrify(insert_statement, (AsIs(','.join(columns)), tuple(values))) \
                    .decode("utf-8")
                sql = sql.replace("'st_setsrid(", "st_setsrid(").replace(",4326)'", ",4326)")
                point_sql_list.append(sql)

                point_index += 1

            # insert all points in a single go
            pg_cur.execute(";".join(point_sql_list))


        # add input points that couldn't be matched to the matched points dictionary as the input into the next interation


    else:
        # get error
        e = json.loads(r.content)

        curl_command = 'curl --header "Content-Type: application/json" --request POST --data \'\'{}\'\' {}' \
            .format(json_payload, valhalla_server_url)

        sql = "insert into testing.valhalla_fail values ('{}', {}, '{}', '{}', '{}')" \
            .format(traj_id, e["error_code"], e["error"], str(e["status_code"]) + ":" + e["status"], curl_command)

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
    pg_cur.execute("select {} from {}".format(id_field, table_name))
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

    task_name = "Map match waypoints to OSM"
    system_name = "iag_geo"

    logger.info("{} started : {}".format(task_name, datetime.now()))

    main()

    time_taken = datetime.now() - full_start_time
    logger.info("{} finished : {}".format(task_name, time_taken))
