#!/usr/bin/env bash

echo "-------------------------------------------------------------------------"
echo " Set temp local environment vars"
echo "-------------------------------------------------------------------------"

DOCKER_IMAGE="minus34/valhalla:latest"

echo "-------------------------------------------------------------------------"
echo " Install OS updates and packages"
echo "-------------------------------------------------------------------------"

sudo yum -y -q update
sudo yum -y -q install tmux  # to enable logging out of the remote server while running a long job

echo "-------------------------------------------------------------------------"
echo " Install Kubernetes"
echo "-------------------------------------------------------------------------"

curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

echo "-------------------------------------------------------------------------"
kubectl version --client

echo "-------------------------------------------------------------------------"
echo " Install Docker"
echo "-------------------------------------------------------------------------"

sudo yum -y -q install docker

# add user to docker group
sudo usermod -a -G docker ec2-user

# change user group, start docker service, install and start minikube (a Kubernetes server) whilst docker group active
newgrp docker <<EONG
  sudo systemctl enable docker.service
  sudo systemctl start docker

  echo "-------------------------------------------------------------------------"
  docker version

  echo "-------------------------------------------------------------------------"
  echo " Install and start Minikube"
  echo "-------------------------------------------------------------------------"

  curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
  chmod +x minikube
  sudo mv minikube /usr/local/bin/

  # get all the Docker images needed for Kubernetes server and start the k8s node
  minikube start --driver=docker
EONG

# all good?
echo "-------------------------------------------------------------------------"
echo " minikube status"
echo "-------------------------------------------------------------------------"

minikube status

echo "-------------------------------------------------------------------------"
echo " Download and setup Valhalla image"
echo "-------------------------------------------------------------------------"

# 1. download the image
docker pull ${DOCKER_IMAGE}

# 2. deploy to a Kubernetes pod
kubectl create deployment valhalla --image=${DOCKER_IMAGE}
# create (i.e. expose) a service
kubectl expose deployment/valhalla --type="NodePort" --port 8002
# scale deployment
kubectl scale deployments/valhalla --replicas=4

# wait for containers to scale
sleep 15

# get the k8s node port number
export NODE_PORT=$(kubectl get services/valhalla -o go-template='{{(index .spec.ports 0).nodePort}}')

#kubectl port-forward deployment/valhalla 8002:${NODE_PORT}

echo "----------------------------------------------------------------------------------------------------------------"
echo "Kubernetes Valhalla nodePort = ${NODE_PORT}"
echo "----------------------------------------------------------------------------------------------------------------"
kubectl cluster-info
echo "----------------------------------------------------------------------------------------------------------------"
kubectl get services
echo "----------------------------------------------------------------------------------------------------------------"
kubectl get deployments
echo "----------------------------------------------------------------------------------------------------------------"

cd ~ || exit
