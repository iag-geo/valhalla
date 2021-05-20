#!/usr/bin/env bash

cd /Users/hugh.saalmans/git/iag_geo/valhalla/docker_build

docker build --tag minus34/valhalla:latest --tag minus34/valhalla:3.1.1 .

docker run --name=valhalla --publish=8002:8002 minus34/valhalla:latest