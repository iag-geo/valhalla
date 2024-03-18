# valhalla
Scripts for setting up & running the Valhalla routing engine with OpenStreetMap (OSM) data.

## docker_build

Builds a [Docker image](https://hub.docker.com/r/minus34/valhalla) with the latest OSM data for Australia (can easily be changed to embed any OSM data).

There are also some old scripts for deploying Valhlla with AU data using Kubernetes on an AWS EC2 instance or locally on Mac.

## map_matching

A [Python script](./map_matching) for recreating trajectories using a combination of map matching & routing (for areas of poor GPS data).

Requires Postgres with PostGIS.
