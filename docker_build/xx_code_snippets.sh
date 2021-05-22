#!/usr/bin/env bash

cd /Users/hugh.saalmans/git/iag_geo/valhalla/docker_build

# note: --squash is still an experimental docker feature (removes intermediate layers from final image)
docker build --squash --tag minus34/valhalla:latest --tag minus34/valhalla:3.1.1 .

docker run --name=valhalla --publish=8002:8002 minus34/valhalla:latest


curl http://localhost:8002/route \
--data '{"locations":[{"lat":-33.85,"lon":151.13,"type":"break","city":"Leichhardt","state":"NSW"},{"lat":-33.85,"lon":151.16,"type":"break","city":"Sydney","state":"NSW"}],"costing":"auto","directions_options":{"units":"kilometres"}}' | jq '.'
