#!/usr/bin/env bash

SECONDS=0*

# ------------------------------------------------------------------------------------------------------------
# 1. build or download image
# ------------------------------------------------------------------------------------------------------------
cd $HOME

#docker build --tag minus34/valhalla:latest .
docker pull minus34/valhalla:latest

# ------------------------------------------------------------------------------------------------------------
# 2. deploy using Kubernetes
# ------------------------------------------------------------------------------------------------------------

kubectl create deployment valhalla --image=minus34/valhalla:latest

# create (i.e. expose) a service
kubectl expose deployment/valhalla --type="NodePort" --port=8002 --target-port=8002

# scale deployment
kubectl scale deployments/valhalla --replicas=4

# wait for service to start
sleep 30

# port forward from Kubernetes to all IPs (to enable external requests over port 8002)
# run in background to allow script to complete
eval "kubectl port-forward service/valhalla 8002:8002 --address=0.0.0.0" &>/dev/null & disown;

# wait for service to start
sleep 30

# test URL
curl http://localhost:8002/route \
--data '{"locations":[{"lat":-33.85,"lon":151.13},{"lat":-33.85,"lon":151.16}],"costing":"auto","directions_options":{"units":"kilometres"}}'

##test URL with JSON formatting (install using "brew install jq")
#curl http://localhost:8002/route \
#--data '{"locations":[{"lat":-33.85,"lon":151.13},{"lat":-33.85,"lon":151.16}],"costing":"auto","directions_options":{"units":"kilometres"}}' | jq '.'


## 2. run container in Docker only
#docker run --name=valhalla --publish=8002:8002 minus34/valhalla:latest
