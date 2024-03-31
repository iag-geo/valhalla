#!/usr/bin/env bash

# 1. go to Dockerfile directory
cd /Users/$(whoami)/git/iag_geo/valhalla/docker_build

# 2. launch buildx
docker buildx create --name valhalla_builder --use
docker buildx inspect --bootstrap

# 3. build and push images
docker buildx build --platform linux/amd64,linux/arm64 --tag minus34/valhalla:latest . --push

## 4. clean up Docker locally - note: this could accidentally destroy your resources
#echo 'y' | docker system prune

# run a container in the background
docker run --detach --publish=8002:8002 minus34/valhalla:latest

# test URL
sleep 30
curl http://localhost:8002/route --data '{"locations":[{"lat":-33.8799,"lon":151.1437, "radius":5},{"lat":-33.8679,"lon":151.12123, "radius":5}],"costing":"auto","directions_options":{"units":"kilometres"}}'


##test URL with JSON formatting (install using "brew install jq")
#curl http://localhost:8002/route \
#--data '{"locations":[{"lat":-33.85,"lon":151.13},{"lat":-33.85,"lon":151.16}],"costing":"auto","directions_options":{"units":"kilometres"}}' | jq '.'

#curl http://localhost:8002/route \
#--data '{"locations":[{"lat":-33.8799,"lon":151.1437},{"lat":-33.8679,"lon":151.12123}],"costing":"auto","directions_options":{"units":"kilometres"}}'
