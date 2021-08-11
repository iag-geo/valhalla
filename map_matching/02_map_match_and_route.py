
# TODO: look at using valhalla IDs for road segments
#   - WARNING: IDs are transient and will change between OSM data versions

# TODO: Avoid using latest Valhalla version until Edge ID issue is resolved -- check if fixed in 3.1.3 (?)

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
# must be integers (these are used to name temp tables # TODO: get rid of this limitation
search_radii = [None, 5, 10, 15, 30, 60]
# search_radii = [7.5]
iteration_count = pow(len(search_radii), 2)

# number of CPUs to use in processing (defaults to local CPU count)
cpu_count = multiprocessing.cpu_count()

# create postgres connect string
pg_connect_string = "dbname=geo host=localhost port=5432 user=postgres password=password"

# create postgres connection pool
pg_pool = psycopg2.pool.SimpleConnectionPool(1, cpu_count, pg_connect_string)

# TODO: make these runtime arguments

# valhalla URLs
valhalla_base_url = "http://localhost:8002/"
map_matching_url = valhalla_base_url + "trace_attributes"
routing_url = valhalla_base_url + "route"

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

    # recreate interim & output tables and index them
    # TODO: improve indexing to avoid slow inserts
    sql_file = os.path.join(runtime_directory, "postgres_scripts", "01_create_tables.sql")
    sql = open(sql_file, "r").read()
    pg_cur.execute(sql)

    # # create indexes on interim & output tables
    # sql_file = os.path.join(runtime_directory, "postgres_scripts", "03_create_map_match_indexes.sql")
    # sql = open(sql_file, "r").read()
    # pg_cur.execute(sql)

    logger.info("\t - interim & output tables recreated with indexes: {}".format(datetime.now() - start_time))
    start_time = datetime.now()

    # --------------------------------------------------------------------------------------

    # get trajectory data from postgres
    job_list = get_trajectories(pg_cur)
    job_count = len(job_list)

    logger.info("Got {} trajectories, starting map matching with {} sets of parameters : {}"
                .format(len(job_list), iteration_count, datetime.now() - start_time))
    start_time = datetime.now()

    # for each trajectory:
    #   1. map match each waypoint using Valhalla with multiple combinations of search distance & GPS accuracy
    #   2. get map matched segments and determine which unmatched segment needs routing
    #   3. route unmatched segments using Valhalla
    #   4. stitch map matched and routed segments together
    #   5. output the best route for each trajectory
    mp_pool = multiprocessing.Pool(cpu_count)
    mp_results = mp_pool.imap_unordered(map_match_and_route_trajectory, job_list)
    mp_pool.close()
    mp_pool.join()

    # check parallel processing results
    for mp_result in mp_results:
        if mp_result is not None:
            print("WARNING: multiprocessing error : {}".format(mp_result))

    logger.info("\t - all trajectories map matched & routed: {}".format(datetime.now() - start_time))
    start_time = datetime.now()

    # update stats on final tables
    pg_cur.execute("ANALYSE testing.valhalla_segment")
    pg_cur.execute("ANALYSE testing.valhalla_merged_route")
    pg_cur.execute("ANALYSE testing.valhalla_final_route")

    # output best routes and create indexes ON output tables
    sql_file = os.path.join(runtime_directory, "postgres_scripts", "08_create_indexes.sql")
    sql = open(sql_file, "r").read()
    pg_cur.execute(sql)

    logger.info("\t - best routes output & indexes created : {}".format(datetime.now() - start_time))
    start_time = datetime.now()

    # get routing table counts
    pg_cur.execute("SELECT count(*) FROM testing.valhalla_segment WHERE segment_type = 'route'")
    routing_count = pg_cur.fetchone()[0]
    pg_cur.execute("SELECT count(*) FROM testing.valhalla_segment WHERE segment_type = 'map match'")
    map_matching_count = pg_cur.fetchone()[0]
    pg_cur.execute("SELECT count(*) FROM testing.valhalla_merged_route")
    merged_route_count = pg_cur.fetchone()[0]
    # pg_cur.execute("SELECT count(*) FROM testing.valhalla_map_match_fail")
    # fail_map_match_count = pg_cur.fetchone()[0]
    # pg_cur.execute("SELECT count(*) FROM testing.valhalla_route_fail")
    # fail_route_count = pg_cur.fetchone()[0]
    pg_cur.execute("SELECT count(*) FROM testing.valhalla_final_route")
    final_route_count = pg_cur.fetchone()[0]
    missing_trip_count = job_count - final_route_count

    # TODO: add failures to final table
    logger.info("\t - routing results")
    logger.info("\t\t - {:,} segments map matched".format(map_matching_count))
    logger.info("\t\t - {:,} segments routed".format(routing_count))
    logger.info("\t\t - {:,} final routes created".format(final_route_count))
    # if fail_route_count > 0:
    #     logger.warning("\t\t - {:,} segments FAILED".format(fail_route_count))
    if missing_trip_count > 0:
        logger.warning("{:,} results missing".format(missing_trip_count))
    else:
        logger.info("no results missing")

    # close postgres connection
    pg_cur.close()
    pg_pool.putconn(pg_conn)


def get_trajectories(pg_cur):
    if use_timestamps:
        sql = """SELECT row_number() over () AS gid,
                        {0} AS trip_id,
                        count(*) AS point_count,
                        jsonb_agg(jsonb_build_object('lat', {2}, 'lon', {3}, 'time', {4}) ORDER BY {1}) AS input_points 
                 FROM {5}
                 GROUP BY {0}""" \
            .format(trajectory_id_field, point_index_field, lat_field, lon_field, time_field, input_table)
    else:
        sql = """SELECT row_number() over () AS gid,
                        {0} AS trip_id,
                        count(*) AS point_count,
                        jsonb_agg(jsonb_build_object('lat', {2}, 'lon', {3}) ORDER BY {1}) AS input_points 
                 FROM {4}
                 -- WHERE trip_id = '9113834E-158F-4328-B5A4-59B3A5D4BEFC'
                 WHERE trip_id = 'F93947BB-AECD-48CC-A0B7-1041DFB28D03'
                     OR trip_id = '918E16D3-709F-44DE-8D9B-78F8C6981122'
                 GROUP BY {0}""" \
            .format(trajectory_id_field, point_index_field, lat_field, lon_field, input_table)
    pg_cur.execute(sql)

    return pg_cur.fetchall()


def map_match_and_route_trajectory(job):
    start_time = datetime.now()

    # get postgres connection from pool
    pg_conn = pg_pool.getconn()
    pg_conn.autocommit = True
    pg_cur = pg_conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

    # trajectory data
    job_id = job["gid"]  # the id used for all temp tables (trip ID is too long
    trip_id = job["trip_id"]
    # point_count = job["point_count"]
    input_points = job["input_points"]

    # process for every combination of GPS accuracy and search radius to determine the best route
    for gps_accuracy in search_radii:
        # fix None values for search radius and gps_accuracy (can't be NULL in a database primary key)
        if gps_accuracy is None:
            gps_accuracy = 9999

        for search_radius in search_radii:
            if search_radius is None:
                search_radius = 9999

            # STEP 1 - create temp tables
            sql_file = os.path.join(runtime_directory, "postgres_scripts", "01_create_temp_tables.sql")
            sql = open(sql_file, "r").read().format(job_id, search_radius, gps_accuracy)
            pg_cur.execute(sql)

            # print("{} : {} : {} : tables created : {}"
            #             .format(trip_id, search_radius, gps_accuracy, datetime.now() - start_time))
            # start_time = datetime.now()

            # STEP 2 - map matching
            map_match_trajectory(pg_cur, job_id, input_points, search_radius, gps_accuracy)

            # print("{} : {} : {} : map matching done : {}"
            #             .format(trip_id, search_radius, gps_accuracy, datetime.now() - start_time))
            # start_time = datetime.now()

            # STEP 3 - get unmatched trajectory segments to route
            sql_file = os.path.join(runtime_directory, "postgres_scripts", "04_split_routes.sql")
            sql = open(sql_file, "r").read().format(job_id, search_radius, gps_accuracy, trip_id)
            pg_cur.execute(sql)

            # STEP 4 - create job list for routing and process
            sql = """SELECT begin_edge_index,
                            end_edge_index,
                            begin_shape_index,
                            end_shape_index,
                            start_lat,
                            start_lon,
                            end_lat,
                            end_lon
                     FROM temp_{}_{}_{}_route_this""".format(job_id, search_radius, gps_accuracy)
            pg_cur.execute(sql)
            route_job_list = pg_cur.fetchall()

            # print("{} : {} : {} : routing input created : {}"
            #             .format(trip_id, search_radius, gps_accuracy, datetime.now() - start_time))
            # start_time = datetime.now()

            for route_job in route_job_list:
                route_trajectory(pg_cur, job_id, search_radius, gps_accuracy, route_job)

            # print("{} : {} : {} : routing done : {}"
            #             .format(trip_id, search_radius, gps_accuracy, datetime.now() - start_time))
            # start_time = datetime.now()

            # STEP 4 - stitch map matched and routed segments into continuous trajectories
            sql_file = os.path.join(runtime_directory, "postgres_scripts", "06_stitch_routes.sql")
            sql = open(sql_file, "r").read().format(job_id, search_radius, gps_accuracy, trip_id)
            pg_cur.execute(sql)

    print("{} : done : {}".format(trip_id, datetime.now() - start_time))
    start_time = datetime.now()

    # clean up
    pg_cur.close()
    pg_pool.putconn(pg_conn)


def map_match_trajectory(pg_cur, job_id, input_points, search_radius, gps_accuracy):
    # add parameters and trajectory to request
    # TODO: this could be done better, instead of evaluating parameters dict every request
    request_dict = get_map_matching_parameters(search_radius, gps_accuracy)
    request_dict["shape"] = input_points

    # convert request data to JSON string
    json_payload = json.dumps(request_dict)

    # get a route
    try:
        r = requests.post(map_matching_url, data=json_payload)
    except Exception as e:
        # if complete failure - Valhalla has possibly crashed
        return "Valhalla routing failure ON trajectory {} : {}".format(job_id, e)

    # add results to lists of shape, edge and point dicts for insertion into postgres
    if r.status_code == 200:
        response_dict = r.json()

        # DEBUGGING
        response_file = open(os.path.join(Path.home(), "tmp", "valhalla_response.json"), "w")
        response_file.writelines(json.dumps(response_dict))
        response_file.close()

        # output matched route geometry
        shape = response_dict.get("shape")

        if shape is not None:
            # construct postgis geometry string for insertion into postgres
            shape_coords = decode(shape)  # decode Google encoded polygon
            # point_list = list()

            shape_index = 0

            if len(shape_coords) > 1:
                for coords in shape_coords:
                    # point = "{} {}".format(coords[0], coords[1])
                    # point_list.append(point)

                    geom_string = "ST_SetSRID(ST_MakePoint({},{}), 4326)".format(coords[0], coords[1])

                    # print(geom_string)

                    # insert each point into valhalla_map_match_shape_point table
                    point_sql = """insert into temp_{}_{}_{}_map_match_shape_point
                                     values ({}, {})""" \
                        .format(job_id, search_radius, gps_accuracy, shape_index, geom_string)
                    pg_cur.execute(point_sql)

                    shape_index += 1
            else:
                fail_sql = """insert into temp_{}_{}_{}_map_match_fail (error) 
                                  values ('{}')""" \
                    .format(job_id, search_radius, gps_accuracy, "Linestring only has one point")
                pg_cur.execute(fail_sql)

        # output edge information
        edges = response_dict.get("edges")

        if edges is not None:
            edge_sql_list = list()
            edge_index = 0

            for edge in edges:
                edge["osm_id"] = edge.pop("way_id")
                edge["edge_index"] = edge_index

                # bug in Valhalla(?) - occasionally returns empty dict "{}" for "sign" attribute
                if edge.get("sign") is not None:
                    edge.pop("sign", None)

                columns = list(edge.keys())
                values = [edge[column] for column in columns]

                insert_statement = "INSERT INTO temp_{}_{}_{}_map_match_edge (%s) VALUES %s" \
                    .format(job_id, search_radius, gps_accuracy)
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
                # get only matched points for use in the next iteration
                if point["type"] == "matched":
                    matched_point = dict()
                    matched_point["point_index"] = point_index
                    matched_point["lat"] = point["lat"]
                    matched_point["lon"] = point["lon"]
                    matched_point["distance"] = point["distance_from_trace_point"]
                    matched_points.append(matched_point)

                # alter point dict for input into Postgres
                point["point_type"] = point.pop("type")
                point[point_index_field] = point_index
                point["geom"] = "st_setsrid(st_makepoint({},{}),4326)" \
                    .format(point["lon"], point["lat"])

                # drop coordinates to save table space
                point.pop("lat", None)
                point.pop("lon", None)

                columns = list(point.keys())
                values = [point[column] for column in columns]

                insert_statement = "INSERT INTO temp_{}_{}_{}_map_match_point (%s) VALUES %s" \
                    .format(job_id, search_radius, gps_accuracy)
                sql = pg_cur.mogrify(insert_statement, (AsIs(','.join(columns)), tuple(values))) \
                    .decode("utf-8")
                sql = sql.replace("'st_setsrid(", "st_setsrid(").replace(",4326)'", ",4326)")
                point_sql_list.append(sql)

                point_index += 1

            # insert all points in a single go
            pg_cur.execute(";".join(point_sql_list))
    else:
        # get error
        e = json.loads(r.content)

        curl_command = 'curl --header "Content-Type: application/json" --request POST --data \'\'{}\'\' {}' \
            .format(json_payload, map_matching_url)

        sql = "insert into temp_{}_{}_{}_map_match_fail values ({}, '{}', '{}', '{}')" \
            .format(job_id, search_radius, gps_accuracy, e["error_code"], e["error"],
                    str(e["status_code"]) + ":" + e["status"], curl_command)
        pg_cur.execute(sql)

    # update table stats
    pg_cur.execute("ANALYSE temp_{0}_{1}_{2}_map_match_edge".format(job_id, search_radius, gps_accuracy))
    pg_cur.execute("ANALYSE temp_{0}_{1}_{2}_map_match_shape_point".format(job_id, search_radius, gps_accuracy))
    pg_cur.execute("ANALYSE temp_{0}_{1}_{2}_map_match_point".format(job_id, search_radius, gps_accuracy))
    pg_cur.execute("ANALYSE temp_{0}_{1}_{2}_map_match_fail".format(job_id, search_radius, gps_accuracy))


def route_trajectory(pg_cur, job_id, search_radius, gps_accuracy, job):

    # get inputs
    begin_edge_index = int(job["begin_edge_index"])
    end_edge_index = int(job["end_edge_index"])
    begin_shape_index = int(job["begin_shape_index"])
    end_shape_index = int(job["end_shape_index"])

    start_location = dict()
    start_location["lat"] = job["start_lat"]
    start_location["lon"] = job["start_lon"]
    # start_location["rank_candidates"] = False  # allows the best road to be chosen, not necessarily the closest road
    # # if segment is the start of the route - double the radius to enable a wider search for a road
    # if begin_edge_index == 0:
    # start_location["radius"] = search_radius
    # else:
    #     start_location["radius"] = search_radius

    end_location = dict()
    end_location["lat"] = job["end_lat"]
    end_location["lon"] = job["end_lon"]
    # end_location["rank_candidates"] = False
    # # if segment is the end of the route - double the radius to enable a wider search for a road
    # if begin_edge_index == 0:
    # end_location["radius"] = search_radius
    # else:
    #     end_location["radius"] = search_radius

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
        return "Valhalla routing failure ON trajectory {} : {}".format(job_id, e)

    # add results to lists of shape, edge and point dicts for insertion into postgres
    if r.status_code == 200:
        response_dict = r.json()

        # # DEBUGGING
        # if begin_edge_index == 81 and search_radius == 60:
        #     with open(os.path.join(Path.home(), "tmp", "valhalla_response.json"), "w") as response_file:
        #         json.dump(response_dict, response_file, indent=4, sort_keys=True)

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
                        point_count += 1

                    geom_string = "ST_GeomFromText('LINESTRING("
                    geom_string += ",".join(point_list)
                    geom_string += ")', 4326)"

                    # if end_edge_index - begin_edge_index > 1:
                    #     segment_type = "map match"
                    # else:
                    segment_type = "route"

                    shape_sql = """insert into temp_{}_{}_{}_route_shape
                                         values ({}, {}, {}, {}, {}, {}, '{}', {})""" \
                        .format(job_id, search_radius, gps_accuracy, begin_edge_index, end_edge_index,
                                begin_shape_index, end_shape_index, distance_m, point_count, segment_type, geom_string)
                    pg_cur.execute(shape_sql)
                else:
                    fail_sql = """insert into temp_{}_{}_{}_route_fail (job_id, search_radius, gps_accuracy, 
                                          begin_edge_index, end_edge_index, begin_shape_index, end_shape_index, error)
                                      values ({}, {}, {}, '{}')""" \
                        .format(job_id, search_radius, gps_accuracy, begin_edge_index, end_edge_index,
                                begin_shape_index, end_shape_index, "Linestring only has one point")
                    pg_cur.execute(fail_sql)

    else:
        # get error
        e = json.loads(r.content)

        curl_command = 'curl --header "Content-Type: application/json" --request POST --data \'\'{}\'\' {}' \
            .format(json_payload, routing_url)

        # TODO: insert final fail rows into permenant table

        sql = "insert into temp_{}_{}_{}_route_fail values ({}, {}, {}, {}, '{}', '{}', '{}')" \
            .format(job_id, search_radius, gps_accuracy, begin_edge_index, end_edge_index,
                    begin_shape_index, end_shape_index,
                    e["error_code"], e["error"], str(e["status_code"]) + ":" + e["status"], curl_command)

        pg_cur.execute(sql)


# edit these to taste
def get_map_matching_parameters(search_radius, gps_accuracy):

    request_dict = dict()

    request_dict["costing"] = "auto"
    request_dict["directions_options"] = {"units": "kilometres"}
    # request_dict["shape_match"] = "map_snap"  # seems to be an inferior matching algorithm
    request_dict["shape_match"] = "walk_or_snap"

    if search_radius != 9999 or gps_accuracy != 9999:
        request_dict["trace_options"] = dict()

        if search_radius != 9999:
            request_dict["trace_options"]["search_radius"] = search_radius

        if gps_accuracy != 9999:
            request_dict["trace_options"]["gps_accuracy"] = gps_accuracy

    # # test parameters - yet to do anything
    # request_dict["breakage_distance"] = 6000
    # request_dict["interpolation_distance"] = 6000

    if use_timestamps:
        request_dict["use_timestamps"] = "true"

    request_dict["filters"] = {"attributes": ["edge.way_id",
                                              "edge.names",
                                              "edge.road_class",
                                              "edge.speed",
                                              "edge.begin_shape_index",
                                              "edge.end_shape_index",
                                              "edge.traversability",
                                              "edge.use",
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


# edit these to taste
def get_routing_parameters():

    request_dict = dict()

    request_dict["costing"] = "auto"
    request_dict["units"] = "kilometres"

    # TODO: add more parameters/constraints here (if required)

    return request_dict


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
