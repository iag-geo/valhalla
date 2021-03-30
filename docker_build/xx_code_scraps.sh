
# 1. build image
#setproxy
cd /Users/$(whoami)/git/iag_geo/valhalla/docker_build
docker build --tag iag-geo/valhalla:3.1.0 .

# 2. run container
docker run --name=valhalla --publish=8002:8002 iag-geo/valhalla:3.1.0

# 3. test a URL
curl http://localhost:8002/route \
--data '{"locations":[{"lat":-33.85,"lon":151.13,"type":"break","city":"Leichhardt","state":"NSW"},{"lat":-33.85,"lon":151.16,"type":"break","city":"Sydney","state":"NSW"}],"costing":"auto","directions_options":{"units":"kilometres"}}' | jq '.'
