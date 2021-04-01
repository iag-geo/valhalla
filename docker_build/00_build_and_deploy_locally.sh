#!/usr/bin/env bash

SECONDS=0*

# 1. build image
cd $HOME
docker build --tag iag-geo/valhalla:3.1.0 .

# 2. deploy to a Kubernetes pod
kubectl create deployment valhalla --image=iag-geo/valhalla:latest
# create (i.e. expose) a service
kubectl expose deployment/valhalla --type="NodePort" --port 8002
# scale deployment
kubectl scale deployments/valhalla --replicas=4
# get the k8s node port number
export NODE_PORT=$(kubectl get services/valhalla -o go-template='{{(index .spec.ports 0).nodePort}}')

## 2. run container in Docker only
#docker run --name=valhalla --publish=8002:8002 iag-geo/valhalla:3.1.0

# 3. test a URL
curl http://localhost:${NODE_PORT}/route \
--data '{"locations":[{"lat":-33.85,"lon":151.13,"type":"break","city":"Leichhardt","state":"NSW"},{"lat":-33.85,"lon":151.16,"type":"break","city":"Sydney","state":"NSW"}],"costing":"auto","directions_options":{"units":"kilometres"}}' | jq '.'
