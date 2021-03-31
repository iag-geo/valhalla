#!/usr/bin/env bash

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