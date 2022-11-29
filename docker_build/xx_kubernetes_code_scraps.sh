#!/usr/bin/env bash

# list all taints on nodes - could cause pods to never start (aka make them "unschedulable")
kubectl get nodes -o json | jq '.items[].spec.taints'

## remove "unschedulable" taint - WARNING - current version of docker desktop replaces this taint automatically
#kubectl taint node docker-desktop node.kubernetes.io/unschedulable:NoSchedule-


# delete Valhalla pods, service and deployment
kubectl get pods --no-headers=true | awk '/valhalla/{print $1}' | xargs kubectl delete pod
kubectl delete service -l app=valhalla
kubectl delete deployment -l app=valhalla


# check status
kubectl describe services/valhalla

kubectl get deployments
kubectl get pods -o wide

kubectl describe deployment
kubectl get pods -l app=valhalla
kubectl get services -l app=valhalla

# get pod names
kubectl get pods -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'

# change service label
kubectl label pod $POD_NAME app=valhalla

# update image in pod on the fly (without down time) - will be "successful" even if image doesn't exist or work
kubectl set image deployments/valhalla valhalla=minus34/valhalla:latest

# roll back image update changes if images don't exist or don't work
kubectl rollout undo deployments/valhalla


# create proxy to access app in pod (NOT required if service is created i.e. exposed)
kubectl proxy

#kubectl logs

# look at pod log
POD_NAME="valhalla-66699c4b79-wvmz7"
kubectl describe pod ${POD_NAME} ./describe_pod.txt




# create Bash session inside pod
kubectl exec -ti $POD_NAME bash

# test Valhalla URL - requires jq ( brew install jq)
curl http://${INSTANCE_IP_ADDRESS}:8002/route \
--data '{"locations":[{"lat":-33.85,"lon":151.13,"type":"break","city":"Leichhardt","state":"NSW"},{"lat":-33.85,"lon":151.16,"type":"break","city":"Sydney","state":"NSW"}],"costing":"auto","directions_options":{"units":"kilometres"}}' | jq '.'

#curl http://localhost:8002/route \
#--data '{"locations":[{"lat":-33.85,"lon":151.13,"type":"break","city":"Leichhardt","state":"NSW"},{"lat":-33.85,"lon":151.16,"type":"break","city":"Sydney","state":"NSW"}],"costing":"auto","directions_options":{"units":"kilometres"}}' | jq '.'

curl http://10.107.166.0:8002/route \
--data '{"locations":[{"lat":-33.85,"lon":151.13,"type":"break","city":"Leichhardt","state":"NSW"},{"lat":-33.85,"lon":151.16,"type":"break","city":"Sydney","state":"NSW"}],"costing":"auto","directions_options":{"units":"kilometres"}}' | jq '.'

curl http://10.180.64.92:8002/route \
--data '{"locations":[{"lat":-33.85,"lon":151.13,"type":"break","city":"Leichhardt","state":"NSW"},{"lat":-33.85,"lon":151.16,"type":"break","city":"Sydney","state":"NSW"}],"costing":"auto","directions_options":{"units":"kilometres"}}' | jq '.'



