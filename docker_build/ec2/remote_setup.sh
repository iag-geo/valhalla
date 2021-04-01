#!/usr/bin/env bash

SECONDS=0*

echo "-------------------------------------------------------------------------"
echo " Start time : $(date)"

echo "-------------------------------------------------------------------------"
echo " Set temp local environment vars"
echo "-------------------------------------------------------------------------"

DOCKER_IMAGE="iag-geo/valhalla:latest"

export no_proxy="localhost,127.0.0.1/32,192.168.49.2/32, 10.180.64.8/32,10.96.0.0/12,192.168.99.0/24,192.168.39.0/24"
export http_proxy="http://nonprod-proxy.csg.iagcloud.net:8080"
export https_proxy=${http_proxy}
export HTTP_PROXY=${http_proxy}
export HTTPS_PROXY=${http_proxy}
export NO_PROXY=${no_proxy}

echo "-------------------------------------------------------------------------"
echo " Install OS updates and packages"
echo "-------------------------------------------------------------------------"

sudo yum -q -y update
sudo yum -q -y install tmux  # to enable logging out of the remote server while running a long job

echo "-------------------------------------------------------------------------"
echo " Install Kubernetes"
echo "-------------------------------------------------------------------------"

curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

echo "-------------------------------------------------------------------------"
echo " Install Docker"
echo "-------------------------------------------------------------------------"

sudo yum -q -y install docker
#sudo amazon-linux-extras install docker

## create Docker config file with proxy settings for the client
#mkdir ~/.docker
#cat >> ~/.docker/config.json <<EOL
#{
# "proxies":
# {
#   "default":
#   {
#     "httpProxy": "${http_proxy}",
#     "httpsProxy": "${http_proxy}",
#     "noProxy": "${no_proxy}"
#   }
# }
#}
#EOL

# create config file for the docker daemon
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf > /dev/null <<EOT
[Service]
Environment="HTTP_PROXY=${http_proxy}"
Environment="HTTPS_PROXY=${https_proxy}"
Environment="NO_PROXY=${no_proxy}"
EOT

# start service and set it to start on boot
sudo service docker start
sudo usermod -a -G docker ec2-user && newgrp docker
sudo systemctl enable docker.service

## restart docker
sudo systemctl daemon-reload
sudo systemctl restart docker

# need git to download Valhalla repo
sudo yum -q -y install git

echo "-------------------------------------------------------------------------"
echo " Install and start Minikube"
echo "-------------------------------------------------------------------------"

#yum -q -y install conntrack

curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x minikube
sudo mv minikube /usr/local/bin/

# get all the Docker images need for Kubernetes server and start the k8s node
minikube start --driver=docker --docker-env HTTP_PROXY=${http_proxy} --docker-env HTTPS_PROXY=${http_proxy} --docker-env NO_PROXY=${no_proxy}

# all good?
minikube status

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
