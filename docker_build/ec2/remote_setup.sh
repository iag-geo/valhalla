#!/usr/bin/env bash

SECONDS=0*

echo "-------------------------------------------------------------------------"
echo " Start time : $(date)"

echo "-------------------------------------------------------------------------"
echo " Set temp local environment vars"
echo "-------------------------------------------------------------------------"

DOCKER_IMAGE="minus34/valhalla:latest"

#export no_proxy="localhost,127.0.0.1/32,192.168.49.2/32, 10.180.64.8/32,10.96.0.0/12,192.168.99.0/24,192.168.39.0/24"
#export http_proxy="http://nonprod-proxy.csg.iagcloud.net:8080"
#export https_proxy=${http_proxy}
#export HTTP_PROXY=${http_proxy}
#export HTTPS_PROXY=${http_proxy}
#export NO_PROXY=${no_proxy}

echo "-------------------------------------------------------------------------"
echo " Install OS updates and packages"
echo "-------------------------------------------------------------------------"

sudo yum -y update
sudo yum -y install tmux  # to enable logging out of the remote server while running a long job

echo "-------------------------------------------------------------------------"
echo " Install Kubernetes"
echo "-------------------------------------------------------------------------"

curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

kubectl version --client

echo "-------------------------------------------------------------------------"
echo " Install Docker"
echo "-------------------------------------------------------------------------"

sudo yum -y install docker

## OPTIONAL - create config file for the docker daemon if going through a proxy
#sudo mkdir -p /etc/systemd/system/docker.service.d
#sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf > /dev/null <<EOT
#[Service]
#Environment="HTTP_PROXY=${http_proxy}"
#Environment="HTTPS_PROXY=${https_proxy}"
#Environment="NO_PROXY=${no_proxy}"
#EOT

# start service and set it to start on boot
sudo usermod -a -G docker ec2-user && newgrp docker
#sudo service docker start
sudo systemctl enable docker.service
sudo systemctl start docker

## restart docker
#sudo systemctl daemon-reload
#sudo systemctl restart docker

docker version

echo "-------------------------------------------------------------------------"
echo " Install and start Minikube"
echo "-------------------------------------------------------------------------"

curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x minikube
sudo mv minikube /usr/local/bin/

# get all the Docker images need for Kubernetes server and start the k8s node
#minikube start --driver=docker --docker-env HTTP_PROXY=${http_proxy} --docker-env HTTPS_PROXY=${http_proxy} --docker-env NO_PROXY=${no_proxy}
minikube start --driver=docker

# all good?
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
# get the k8s node port number
export NODE_PORT=$(kubectl get services/valhalla -o go-template='{{(index .spec.ports 0).nodePort}}')

echo "nodePort = ${NODE_PORT}"

#echo "-------------------------------------------------------------------------"
#echo " Remove proxy"
#echo "-------------------------------------------------------------------------"
#
#unset http_proxy
#unset HTTP_PROXY
#unset https_proxy
#unset HTTPS_PROXY
#unset no_proxy
#unset NO_PROXY

echo "----------------------------------------------------------------------------------------------------------------"

cd ~ || exit

duration=$SECONDS

echo " End time : $(date)"
echo " Docker + Kubernetes install took $((duration / 60)) mins"
echo "----------------------------------------------------------------------------------------------------------------"
