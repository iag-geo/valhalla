#!/usr/bin/env bash

#grab the demos repo and open up the point and click routing sample
#git clone --depth=1 --recurse-submodules --single-branch --branch=gh-pages https://github.com/valhalla/demos.git
#firefox demos/routing/index-internal.html &
#NOTE: set the environment pulldown to 'localhost' to point it at your own server

#start up the server
#cd ~/git/valhalla/valhalla
#./build/valhalla_service valhalla.json 1
~/git/valhalla/valhalla/build/valhalla_service ~/git/valhalla/valhalla/valhalla.json 1

#test URL
#curl http://localhost:8002/route --data '{"locations":[{"lat":47.365109,"lon":8.546824,"type":"break","city":"Zürich","state":"Altstadt"},{"lat":47.108878,"lon":8.394801,"type":"break","city":"6037 Root","state":"Untere Waldstrasse"}],"costing":"auto","directions_options":{"units":"miles"}}' | jq '.'
curl http://localhost:8002/route --data '{"locations":[{"lat":-33.85,"lon":151.13,"type":"break","city":"Leichhardt","state":"NSW"},{"lat":-33.85,"lon":151.16,"type":"break","city":"Sydney","state":"NSW"}],"costing":"auto","directions_options":{"units":"kilometres"}}' | jq '.'

#HAVE FUN!
