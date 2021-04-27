
import json
import logging
import os
import psycopg2  # need to install psycopg2-binary package
import psycopg2.extras
import requests
import sys

from datetime import datetime
from psycopg2.extensions import AsIs
# from pypac import pac_context_for_url
# from requests.auth import HTTPProxyAuth

# six degrees of precision in Valhalla
inv = 1.0 / 1e6

# max number of points to insert into Postgres
log_interval = 1000000

# http_proxy_auth = HTTPProxyAuth(user, pwd)

# valhalla server
valhalla_server_url = "http://localhost:8002/trace_attributes"

# file path to SQl dfile the create non-PII trip geoms
non_pii_sql_file = os.path.join(os.path.dirname(os.path.realpath(__file__)), "02_create_non_pii_trips_table.sql")


def main():
    start_time = datetime.now()

    # create local postgres connect strings
    local_pg_connect_string = "dbname=geo host=localhost port=5432 user=postgres password=password"

    # create local PG connection
    local_pg_conn = psycopg2.connect(local_pg_connect_string)
    local_pg_conn.autocommit = True
    local_pg_cur = local_pg_conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

    # only add missing trips
    new_list = get_id_list(local_pg_cur, "distinct trip_id", "testing.waypoint")
    old_list = get_id_list(local_pg_cur, "trip_id", "testing.osm_waypoint_shape")
    fail_list = get_id_list(local_pg_cur, "trip_id", "testing.osm_waypoint_fail")
    temp_new_list = list(set(new_list).difference(old_list))
    new_trip_id_set = set(temp_new_list).difference(fail_list)

    new_trip_id_list = list(new_trip_id_set)
    # new_trip_id_list = [..., ...]
    # new_trip_id_list = list(new_trip_id_set)[:1000]

    logger.info("Need to process {} trips : {}".format(len(new_trip_id_list), datetime.now() - start_time))
    start_time = datetime.now()

    # TODO: account for large gaps in waypoints due to GPS/data missing
    #  need to route these manually - causes weird routes

    # get waypoints
    sql = """select row_number() over (partition by trip_id order by time_local) - 1 as point_index,
                    trip_id,
                    st_y(geom) AS lat,
                    st_x(geom) AS lon,
                    st_m(geom) AS time
             from testing.waypoint
             order by trip_id, time_local"""\
        .format(tuple(new_trip_id_list)).replace(",)", ")")

    local_pg_cur.execute(sql)

    rows = local_pg_cur.fetchall()

    # fix to get the last trip processed
    # TODO: fix the looping mechanism to process the first and last trip without this bodge fix
    rows.append([0, -1, 0, 0, 1.0])

    # # empty output tables
    # local_pg_cur.execute("truncate table testing.osm_waypoint_shape")
    # local_pg_cur.execute("truncate table testing.osm_waypoint_shape_non_pii")
    # local_pg_cur.execute("truncate table testing.osm_waypoint_edge")
    # # local_pg_cur.execute("truncate table testing.osm_waypoint_point")
    # local_pg_cur.execute("truncate table testing.osm_waypoint_fail")

    # local_pg_cur.execute("delete from testing.osm_waypoint_shape where trip_id = ...")
    # local_pg_cur.execute("delete from testing.osm_waypoint_edge where trip_id = ...")
    # local_pg_cur.execute("delete from testing.osm_waypoint_point where trip_id = ...")
    # local_pg_cur.execute("delete from testing.osm_waypoint_fail where trip_id = ...")

    # local_pg_cur.execute("delete from testing.osm_waypoint_shape where trip_id in {}"
    #                      .format(tuple(new_trip_id_list)))
    # local_pg_cur.execute("delete from testing.osm_waypoint_edge where trip_id in {}"
    #                      .format(tuple(new_trip_id_list)))
    # local_pg_cur.execute("delete from testing.osm_waypoint_point where trip_id in {}"
    #                      .format(tuple(new_trip_id_list)))
    # local_pg_cur.execute("delete from testing.osm_waypoint_fail where trip_id in {}"
    #                      .format(tuple(new_trip_id_list)))

    request_dict = dict()
    request_dict["costing"] = "auto"
    request_dict["directions_options"] = {"units": "kilometres"}
    request_dict["shape_match"] = "map_snap"
    request_dict["trace_options"] = {"search_radius": 65}
    # , "search_radius": 100
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

    i = 0
    point_count = 0
    fail_count = 0
    trip_count = 0

    log_point = log_interval
    num_rows = len(rows)

    input_point_list = list()
    trip_id = None

    shape_sql_list = list()
    edge_sql_list = list()
    point_sql_list = list()

    logger.info("Got trajectories, ready to map match : {}".format(datetime.now() - start_time))
    start_time = datetime.now()
    map_match_start_time = datetime.now()

    # for each trajectory - send a map match request to Valhalla (use authenticated proxy if required)
    # TODO: use multiprocessing to really fire up the map matching
    # with pac_context_for_url(valhalla_server_url, proxy_auth=http_proxy_auth):
    for row in rows:
        point_count += 1
        point_num = int(row[0])

        # new trip id - process the current trip
        if point_num == 0 and trip_id is not None:
            i += 1

            # add trajectory to request
            request_dict["shape"] = input_point_list

            json_payload = json.dumps(request_dict)

            # get a route
            try:
                r = requests.post(valhalla_server_url, data=json_payload)
            except Exception as e:
                # if complete failure - Valhalla has most likely crashed - exit
                logger.fatal("Valhalla routing failure on trip {} : {} : {} : EXITING..."
                             .format(trip_id, e, datetime.now() - start_time))
                return False

            # add results to lists of shape, edge and point dicts for bulk insertion into Postgres
            if r.status_code == 200:
                response_dict = r.json()

                # output matched route geometry
                shape = response_dict.get("shape")

                if shape is not None:
                    # construct postgis geometry string for insertion into postgres
                    shape_coords = decode(shape)  # Google encoded polygon decode
                    point_list = list()

                    for coords in shape_coords:
                        point_list.append("{} {}".format(coords[0], coords[1]))

                    geom_string = "st_transform(ST_GeomFromText('LINESTRING("
                    geom_string += ",".join(point_list)
                    geom_string += ")', 4326), 4283)"

                    sql = """insert into testing.osm_waypoint_shape
                                 values ('{0}', st_length({1}::geography), {1})"""\
                        .format(trip_id, geom_string)
                    shape_sql_list.append(sql)

                trip_count += 1

                # output edge information
                edges = response_dict.get("edges")

                if edges is not None:
                    edge_index = 0

                    for edge in edges:
                        edge["trip_id"] = trip_id
                        edge["osm_id"] = edge.pop("way_id")
                        edge["edge_index"] = edge_index

                        # bug in Valhalla(?) - occasionally returns empty dict "{}" for "sign" attribute
                        if edge.get("sign") is not None:
                            edge.pop("sign", None)

                        columns = list(edge.keys())
                        values = [edge[column] for column in columns]

                        insert_statement = "INSERT INTO testing.osm_waypoint_edge (%s) VALUES %s"
                        sql = local_pg_cur.mogrify(insert_statement, (AsIs(','.join(columns)), tuple(values))) \
                            .decode("utf-8")
                        edge_sql_list.append(sql)

                        edge_index += 1

                # output point data
                points = response_dict.get("matched_points")

                if points is not None:
                    point_index = 0

                    for point in points:
                        point["trip_id"] = trip_id
                        point["point_type"] = point.pop("type")
                        point["point_index"] = point_index
                        point["geom"] = "st_setsrid(st_makepoint({},{}),4283)"\
                            .format(point["lon"], point["lat"])

                        # drop coordinates to save table space
                        point.pop("lat", None)
                        point.pop("lon", None)

                        columns = list(point.keys())
                        values = [point[column] for column in columns]

                        insert_statement = "INSERT INTO testing.osm_waypoint_point (%s) VALUES %s"
                        sql = local_pg_cur.mogrify(insert_statement, (AsIs(','.join(columns)), tuple(values))) \
                            .decode("utf-8")
                        sql = sql.replace("'st_setsrid(", "st_setsrid(").replace(",4283)'", ",4283)")
                        point_sql_list.append(sql)

                        point_index += 1

                if point_count > log_point:
                    logger.info("\t - points map matched : {}".format(datetime.now() - start_time))

                    # Insert data into Postgres in bulk
                    insert_data(local_pg_cur, edge_sql_list, point_sql_list, shape_sql_list)

                    percent_done = float(point_count) / float(num_rows) * 100.0
                    logger.info("{:.1f}% complete ({} successful : {} failed: {})"
                                .format(percent_done, trip_count, fail_count, datetime.now() - start_time))
                    start_time = datetime.now()

                    # reset insert statement lists
                    shape_sql_list = list()
                    edge_sql_list = list()
                    point_sql_list = list()

                    log_point += log_interval
            else:
                fail_count += 1

                # get error
                e = json.loads(r.content)

                curl_command = 'curl --header "Content-Type: application/json" --request POST --data \'\'{}\'\' {}'\
                    .format(json_payload, valhalla_server_url)

                sql = "insert into testing.osm_waypoint_fail values ('{}', {}, '{}', '{}', '{}')"\
                    .format(trip_id, e["error_code"], e["error"],
                            str(e["status_code"]) + ":" + e["status"], curl_command)
                local_pg_cur.execute(sql)

            input_point_list = list()

        trip_id = row[1]

        # add to list of input points
        coords_dict = dict()
        coords_dict["lat"] = float(row[2])
        coords_dict["lon"] = float(row[3])
        coords_dict["time"] = float(row[4])

        input_point_list.append(coords_dict)

    logger.info("\t - points map matched : {}".format(datetime.now() - start_time))

    if len(shape_sql_list) > 0:
        # insert_data(local_pg_cur, edge_sql_list, shape_sql_list)
        insert_data(local_pg_cur, edge_sql_list, point_sql_list, shape_sql_list)

    logger.info("100% complete ({} successful : {} failed: {}"
                .format(trip_count, fail_count, datetime.now() - start_time))

    # update stats on tables
    local_pg_cur.execute("analyse testing.osm_waypoint_edge")
    local_pg_cur.execute("analyse testing.osm_waypoint_shape")
    local_pg_cur.execute("analyse testing.osm_waypoint_point")
    logger.info("\t - tables analysed : {}".format(datetime.now() - start_time))
    start_time = datetime.now()

    # sql = open(non_pii_sql_file, "r").read()
    # local_pg_cur.execute(sql)
    # logger.info("\t - non-pii trips created : {}".format(datetime.now() - start_time))

    logger.info("{} trips processed in {}".format(trip_count, datetime.now() - map_match_start_time))
    logger.warning("{} trips failed".format(fail_count))

    # don't need DB connections anymore
    local_pg_cur.close()
    local_pg_conn.close()

    return True


def insert_data(local_pg_cur, edge_sql_list, point_sql_list, shape_sql_list):
    start_time = datetime.now()

    # insert all shapes in a single go
    local_pg_cur.execute(";".join(shape_sql_list))
    logger.info("\t - inserted {} shapes : {}".format(len(shape_sql_list), datetime.now() - start_time))
    start_time = datetime.now()

    # insert all edges in a single go
    local_pg_cur.execute(";".join(edge_sql_list))
    logger.info("\t - inserted {} edges : {}".format(len(edge_sql_list), datetime.now() - start_time))
    # start_time = datetime.now()

    # insert all points in a single go
    local_pg_cur.execute(";".join(point_sql_list))
    logger.info("\t - inserted {} points : {}".format(len(point_sql_list), datetime.now() - start_time))


# decode a Google encoded polyline string
def decode(encoded):
    decoded = []
    previous = [0,0]
    i = 0

    # for each byte
    while i < len(encoded):
        # for each coord (lat, lon)
        ll = [0,0]
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

        # scale by the precision and chop off long coords also flip the positions so
        # its the far more standard lon,lat instead of lat,lon
        decoded.append([float('%.6f' % (ll[1] * inv)), float('%.6f' % (ll[0] * inv))])

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

    result = main()

    time_taken = datetime.now() - full_start_time
    logger.info("{} finished : {}".format(task_name, time_taken))
