#!/usr/bin/env bash

# ------------------------------------------------------------------------------------------------------------
# RUNTIME ARGUMENTS
# ------------------------------------------------------------------------------------------------------------
#  -r : remove existing kubernetes Valhalla cluster
#  -d : download the Valhalla image from Docker Hub instead of building locally
# ------------------------------------------------------------------------------------------------------------

SECONDS=0*

# get directory this script is running from
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# delete Valhalla pods, service and deployment (use command line argument) '-y'
if [ "$1" = "-r" ]; then
  echo "------------------------------------------------------------------------------------------------------------"
  echo " removing kubernetes Valhalla cluster"
  echo "------------------------------------------------------------------------------------------------------------"
  kubectl get pods --no-headers=true | awk '/valhalla/{print $1}' | xargs kubectl delete pod
  kubectl delete service -l app=valhalla
  kubectl delete deployment -l app=valhalla
fi

if [ "$1" = "-d" ]; then
  echo "------------------------------------------------------------------------------------------------------------"
  echo " 2. downloading image"
  echo "------------------------------------------------------------------------------------------------------------"
  docker pull minus34/valhalla:latest
else
  echo "------------------------------------------------------------------------------------------------------------"
  echo " 2. building new image"
  echo "------------------------------------------------------------------------------------------------------------"

  # 1. go to Dockerfile directory
  cd ${SCRIPT_DIR}

  # 2. build the image
  # note: --squash is still an experimental docker feature (removes intermediate layers from final image)
  docker build --squash --tag minus34/valhalla:latest --no-cache .

  ### 3. run a container
  #docker run --name=valhalla --publish=8002:8002 minus34/valhalla:latest

  # 4. push to Docker Hub
  docker push minus34/valhalla:latest

  # 4. clean up Docker locally - warning: this could accidentally destroy other Docker images
  echo 'y' | docker system prune

fi

echo "------------------------------------------------------------------------------------------------------------"
echo " 3. deploy locally using Kubernetes"
echo "------------------------------------------------------------------------------------------------------------"

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
