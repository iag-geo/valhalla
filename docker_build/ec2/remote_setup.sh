#!/bin/bash

# check if proxy server required
while getopts ":p:r:" opt; do
  case $opt in
    p)
      PROXY=$OPTARG
      ;;
    r)
      REPLICAS=$OPTARG
      ;;
  esac
done

if [ -n "${PROXY}" ];
  then
    export no_proxy="192.168.49.2,localhost,127.0.0.1,:11";  # include default minukube IP address
    export http_proxy="$PROXY";
    export https_proxy=${http_proxy};
    export HTTP_PROXY=${http_proxy};
    export HTTPS_PROXY=${http_proxy};
    export NO_PROXY=${no_proxy};

    echo "-------------------------------------------------------------------------";
    echo " Proxy is set to ${http_proxy}";
    echo "-------------------------------------------------------------------------";
fi

echo "-------------------------------------------------------------------------"
echo " Set temp local environment vars"
echo "-------------------------------------------------------------------------"

DOCKER_IMAGE="minus34/valhalla:latest"

echo "-------------------------------------------------------------------------"
echo " Install OS updates and packages"
echo "-------------------------------------------------------------------------"

#sudo yum -y -q update
sudo yum -y -q install tmux jq # to enable logging out of the remote server while running a long job

echo "-------------------------------------------------------------------------"
echo " Install Kubernetes"
echo "-------------------------------------------------------------------------"

curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

echo "-------------------------------------------------------------------------"
echo " kubectl client:"
#kubectl version --client
kubectl version --short

echo "-------------------------------------------------------------------------"
echo " Install Docker"
echo "-------------------------------------------------------------------------"

sudo yum -y -q install docker

# add user to docker group
sudo usermod -a -G docker ec2-user

# set proxy for docker daemon if required
if [ -n "${PROXY}" ];
  then
    sudo mkdir -p /etc/systemd/system/docker.service.d
    echo "[Service]" | sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf >/dev/null
    echo "Environment=\"HTTP_PROXY=${http_proxy}\"" | sudo tee -a /etc/systemd/system/docker.service.d/http-proxy.conf >/dev/null
    echo "Environment=\"HTTPS_PROXY=${https_proxy}\"" | sudo tee -a /etc/systemd/system/docker.service.d/http-proxy.conf >/dev/null
    echo "Environment=\"NO_PROXY=${no_proxy}\"" | sudo tee -a /etc/systemd/system/docker.service.d/http-proxy.conf >/dev/null
fi

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

# remove proxy if set
if [ -n "${PROXY}" ];
  then
    unset http_proxy
    unset HTTP_PROXY
    unset https_proxy
    unset HTTPS_PROXY
    unset no_proxy
    unset NO_PROXY
fi

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
kubectl scale deployments/valhalla --replicas=${REPLICAS}

echo "----------------------------------------------------------------------------------------------------------------"
echo "waiting for service to start (2 mins)..."
sleep 120
echo "----------------------------------------------------------------------------------------------------------------"

# port forward from Kubernetes to all IPs (to enable external requests over port 8002)
# run in background to allow script to complete
pf_cmd="kubectl port-forward service/valhalla 8002:8002 --address=0.0.0.0"
eval "${pf_cmd}" &>/dev/null & disown;

echo "----------------------------------------------------------------------------------------------------------------"
kubectl cluster-info
echo "----------------------------------------------------------------------------------------------------------------"
kubectl get pods
echo "----------------------------------------------------------------------------------------------------------------"
kubectl describe services valhalla
echo "----------------------------------------------------------------------------------------------------------------"
