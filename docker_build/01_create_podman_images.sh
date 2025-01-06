#!/usr/bin/env bash

#brew install podman

# go to Dockerfile directory
cd /Users/$(whoami)/git/iag_geo/valhalla/docker_build

echo "---------------------------------------------------------------------------------------------------------------------"
echo "initialise podman - warning: this could accidentally destroy other images"
echo "---------------------------------------------------------------------------------------------------------------------"

echo 'y' | podman system prune --all
podman machine stop
echo 'y' | podman machine rm
podman machine init --cpus 10 --memory 16384 --disk-size=64  # memory in Mb, disk size in Gb
podman machine start
podman login -u ${DOCKER_USER} -p ${DOCKER_PASSWORD} docker.io/minus34

echo "---------------------------------------------------------------------------------------------------------------------"
echo "build valhalla images"
echo "---------------------------------------------------------------------------------------------------------------------"

# build images
podman manifest create localhost/valhalla
podman build --platform linux/amd64,linux/arm64/v8 --manifest localhost/valhalla .

echo "---------------------------------------------------------------------------------------------------------------------"
echo "push images to Docker Hub"
echo "---------------------------------------------------------------------------------------------------------------------"

podman manifest push localhost/valhalla docker://docker.io/minus34/valhalla:latest
podman manifest push localhost/valhalla docker://docker.io/minus34/valhalla:$(date +%Y%m%d)

echo "---------------------------------------------------------------------------------------------------------------------"
echo "run container"
echo "---------------------------------------------------------------------------------------------------------------------"

# run a container in the background
podman run --detach --publish=8002:8002 minus34/valhalla:latest

# test image with a simple route
echo "---------------------------------------------------------------------------------------------------------------------"
echo "create simple test route"
echo "---------------------------------------------------------------------------------------------------------------------"

sleep 30
curl http://localhost:8002/route --data '{"locations":[{"lat":-33.8799,"lon":151.1437, "radius":5},{"lat":-33.8679,"lon":151.12123, "radius":5}],"costing":"auto","directions_options":{"units":"kilometres"}}'

##test URL with JSON formatting (install using "brew install jq")
#curl http://localhost:8002/route \
#--data '{"locations":[{"lat":-33.85,"lon":151.13},{"lat":-33.85,"lon":151.16}],"costing":"auto","directions_options":{"units":"kilometres"}}' | jq '.'

#curl http://localhost:8002/route \
#--data '{"locations":[{"lat":-33.8799,"lon":151.1437},{"lat":-33.8679,"lon":151.12123}],"costing":"auto","directions_options":{"units":"kilometres"}}'

echo ""
echo "---------------------------------------------------------------------------------------------------------------------"
echo "clean up podman locally - warning: this could accidentally destroy other images"
echo "---------------------------------------------------------------------------------------------------------------------"

# clean up
echo 'y' | podman system prune --all
podman machine stop
echo 'y' | podman machine rm
