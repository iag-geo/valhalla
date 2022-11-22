# valhalla
Scripts for setting up & running the Valhalla routing engine with OpenStreetMap (OSM) data.

## docker_build

Deploy Valhalla with the latest OSM data for Australia using Kubernetes on an AWS EC2 instance; ready to roll! (can easily be changed to embed any region's OSM data)

Also contains a script for building & deploying locally on Mac.

## map_matching

A [Python script](./map_matching) for recreating trajectories using a combination of map matching & routing (for areas of poosr GPS data).

Requires Postgres with PostGIS.

## old_install_scripts

NOT WORKING ON CURRENT VERSION OF VALHALLA - scripts for building and installing Valhalla locally on Mac.
