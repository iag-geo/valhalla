#!/usr/bin/env bash

# 1. build image
#setproxy
cd /Users/$(whoami)/git/iag_geo/valhalla/docker_build
docker build --tag iag-geo/valhalla:3.1.0 .

# 2. deploy to a Kubernetes pod
kubectl create deployment valhalla --image=iag-geo/valhalla:3.1.0
# create (i.e. expose) a service
kubectl expose deployment/valhalla --type="NodePort" --port 8002
# scale deployment
kubectl scale deployments/valhalla --replicas=4
# get the K8s node port number
export NODE_PORT=$(kubectl get services/valhalla -o go-template='{{(index .spec.ports 0).nodePort}}')

## 2. run container in Docker only
#docker run --name=valhalla --publish=8002:8002 iag-geo/valhalla:3.1.0

# 3. test a URL
curl http://localhost:${NODE_PORT}/route \
--data '{"locations":[{"lat":-33.85,"lon":151.13,"type":"break","city":"Leichhardt","state":"NSW"},{"lat":-33.85,"lon":151.16,"type":"break","city":"Sydney","state":"NSW"}],"costing":"auto","directions_options":{"units":"kilometres"}}' | jq '.'



# Kubernetes code scraps

# delete all Valhalla pods
kubectl get pods --no-headers=true | awk '/valhalla/{print $1}' | xargs kubectl delete pod

# check status
kubectl describe services/valhalla

kubectl get deployments
kubectl get pods -o wide

kubectl describe deployment
kubectl get pods -l run=valhalla
kubectl get services -l run=valhalla

# get pod names
kubectl get pods -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'

# change service label
kubectl label pod $POD_NAME app=valhalla

# update image in pod on the fly (without down time) - will be "successful" even if image doesn't exist or work
kubectl set image deployments/valhalla valhalla=iag-geo/valhalla:3.1.0

# roll back image update changes if images don't exist or don't work
kubectl rollout undo deployments/valhalla

# delete service (app is still running inside pod!)
kubectl delete service -l run=kubernetes-bootcamp

# create proxy to access app in pod (NOT required if service is created i.e. exposed)
kubectl proxy


#kubectl logs

# create Bash session inside pod
kubectl exec -ti $POD_NAME bash