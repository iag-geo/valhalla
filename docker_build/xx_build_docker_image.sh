#!/usr/bin/env bash

# 1. go to valhalla.dockerfile directory
cd /Users/$(whoami)/git/iag_geo/valhalla/docker_build

# 2. build the image
#docker build --platform linux/arm64 --tag minus34/valhalla:latest .
docker build --platform linux/amd64 --tag minus34/valhalla:latest .


## 3. push to Docker Hub
docker push minus34/valhalla:latest

# 4. clean up Docker locally - note: this could accidentally destroy your resources
echo 'y' | docker system prune


# run a container in the background
docker run --detach --publish=8002:8002 minus34/valhalla:latest
#docker run --platform linux/amd64 --detach --publish=8002:8002 minus34/valhalla:latest


# test URL
curl http://localhost:8002/route --data '{"locations":[{"lat":-33.8799,"lon":151.1437, "radius":5},{"lat":-33.8679,"lon":151.12123, "radius":5}],"costing":"auto","directions_options":{"units":"kilometres"}}'


##test URL with JSON formatting (install using "brew install jq")
#curl http://localhost:8002/route \
#--data '{"locations":[{"lat":-33.85,"lon":151.13},{"lat":-33.85,"lon":151.16}],"costing":"auto","directions_options":{"units":"kilometres"}}' | jq '.'


#curl http://localhost:8002/route \
#--data '{"locations":[{"lat":-33.8799,"lon":151.1437},{"lat":-33.8679,"lon":151.12123}],"costing":"auto","directions_options":{"units":"kilometres"}}'
