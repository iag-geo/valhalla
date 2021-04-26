#!/usr/bin/env bash

# check if proxy server required
while getopts p: flag
do
    case "${flag}" in
        p) PROXY=${OPTARG};;
    esac
done

if [ -z ${PROXY+x} ];
  then echo "Proxy is unset";
  else
    echo "-------------------------------------------------------------------------"
    echo "Proxy is set to '$PROXY'"
    echo "-------------------------------------------------------------------------"
    export no_proxy="localhost, 127.0.0.1";
    export http_proxy="$PROXY";
    export https_proxy=${http_proxy};
    export HTTP_PROXY=${http_proxy};
    export HTTPS_PROXY=${http_proxy};
    export NO_PROXY=${no_proxy};
fi

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

#  # install NGINX Ingress addon to enable routing to k8s service
#  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.44.0/deploy/static/provider/aws/deploy.yaml

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
EONG

## create deployment based on config file (5 pods)
#kubectl apply -f ~/valhalla-config.yml
#
## create service from deployment
#kubectl expose deployment valhalla --type=NodePort --name=valhalla --port=8002 --target-port=8002

# 2. deploy to a Kubernetes pod
kubectl create deployment valhalla --image=${DOCKER_IMAGE}
# create (i.e. expose) a service
kubectl expose deployment/valhalla --type="NodePort" --port=8002 --target-port=8002
# scale deployment
kubectl scale deployments/valhalla --replicas=4

# wait for service to start
sleep 60

# port forward from Kubernetes to all local IPs (to enable external requests)
kubectl port-forward service/valhalla 8002:8002 --address=0.0.0.0 &

echo "----------------------------------------------------------------------------------------------------------------"
kubectl cluster-info
echo "----------------------------------------------------------------------------------------------------------------"
kubectl get services valhalla
echo "----------------------------------------------------------------------------------------------------------------"
kubectl describe services valhalla
echo "----------------------------------------------------------------------------------------------------------------"

cd ~
