#!/usr/bin/env bash

# 1. go to Dockerfile directory
cd /Users/hugh.saalmans/git/iag_geo/valhalla/docker_build

# 2. build the image
# note: --squash is still an experimental docker feature (removes intermediate layers from final image)
docker build --squash --tag minus34/valhalla:latest --no-cache .

# 3. run a container
docker run --name=valhalla --publish=8002:8002 minus34/valhalla:latest

# 4. push to Docker Hub
docker push minus34/valhalla:latest

# 4. clean up Docker locally - note: this could accidentally destroy your resources
docker system prune


# 5. test URL
curl http://localhost:8002/route \
--data '{"locations":[{"lat":-33.85,"lon":151.13,"type":"break","city":"Leichhardt","state":"NSW"},{"lat":-33.85,"lon":151.16,"type":"break","city":"Sydney","state":"NSW"}],"costing":"auto","directions_options":{"units":"kilometres"}}' | jq '.'
