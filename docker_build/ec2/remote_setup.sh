#!/usr/bin/env bash

SECONDS=0*

echo "-------------------------------------------------------------------------"
echo " Start time : $(date)"

echo "-------------------------------------------------------------------------"
echo " Set temp local environment vars"
echo "-------------------------------------------------------------------------"

DOCKER_IMAGE="iag-geo/valhalla:latest"

export no_proxy="auiag.corp,169.254.169.254,localhost,127.0.0.1,10.180.64.8,10.96.0.0/12,192.168.99.0/24,192.168.39.0/24"
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

#sudo yum -q -y install docker
sudo amazon-linux-extras uninstall docker
sudo service docker start
sudo usermod -a -G docker ec2-user && newgrp docker
#sudo usermod -aG docker $USER && newgrp docker

# set to start on boot
#sudo chkconfig docker on
sudo systemctl enable docker.service

# need git to download Valhalla repo
sudo yum -q -y install git

echo "-------------------------------------------------------------------------"
echo " Install Minikube"
echo "-------------------------------------------------------------------------"

yum -q -y install conntrack

curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x minikube
sudo mv minikube /usr/local/bin/







## download Apache Sedona source code
#wget -q -e use_proxy=yes --no-check-certificate \
#https://github.com/apache/incubator-sedona/archive/sedona-1.0.0-incubating-rc1.tar.gz
#tar xzf sedona-1.0.0-incubating-rc1.tar.gz
#rm sedona-1.0.0-incubating-rc1.tar.gz
#
## copy maven files from S3 for faster build process
#mkdir ~/.m2/repository
#aws s3 sync --quiet s3://maven-downloads/sedona-1.0.0/repository ~/.m2/repository
#
## Build it
#cd ${SEDONA_INSTALL_DIR} || exit
#mvn clean install -DskipTests -Dgeotools \
#-Dmaven.wagon.http.ssl.insecure=true \
#-Dmaven.wagon.http.ssl.allowall=true \
#-Dmaven.wagon.http.ssl.ignore.validity.dates=true
#
## Copy Sedona Python adapter JAR to Spark folder
#sudo cp ${SEDONA_INSTALL_DIR}/python-adapter/target/sedona-python-adapter-3.0_2.12-1.0.0-incubating.jar ${SPARK_HOME}/jars

echo "-------------------------------------------------------------------------"
echo " Install OS & Python updates and packages"
echo "-------------------------------------------------------------------------"

sudo yum -q -y update
sudo yum -q -y install tmux  # to enable logging out of the remote server while running a long job

# update package installers
python -m pip install --user --upgrade pip
python -m pip install --user --upgrade setuptools

# install AWS packages
pip install --user awscli
pip install --user boto3

##install jupyter notebook
#pip install --user jupyter
#export PATH="/home/hadoop/.local/bin:$PATH"

echo "-------------------------------------------------------------------------"
echo " install Apache Sedona"
echo "-------------------------------------------------------------------------"

## Install Apache Sedona package
#cd ${SEDONA_INSTALL_DIR}/python || exit
#python setup.py install --user

# step 1 - install from pip
pip install --user apache-sedona

# step 2 - add Sedona Python adapter JAR to Spark JAR files

# download unofficial shaded Sedona python adapter JAR with GeoTools embedded
# Note: Apache Sedona has an Apache license, GeoTools' license is LGPL
wget -q -e use_proxy=yes --no-check-certificate \
https://s3-ap-southeast-2.amazonaws.com/minus34.com/opensource/sedona-python-adapter-3.0_2.12-${SEDONA_VERSION}-incubating.jar
sudo mv sedona-python-adapter-3.0_2.12-${SEDONA_VERSION}-incubating.jar ${SPARK_HOME}/jars/

echo "-------------------------------------------------------------------------"
echo "Verify Sedona version"
echo "-------------------------------------------------------------------------"

# confirm version of Sedona installed
pip list | grep "sedona"

echo "-------------------------------------------------------------------------"
echo " Setup Spark"
echo "-------------------------------------------------------------------------"

echo "JAVA_HOME=${JAVA_HOME}" | sudo tee /etc/environment
echo "SPARK_HOME=${SPARK_HOME}" | sudo tee -a /etc/environment
echo "HADOOP_HOME=${HADOOP_HOME}" | sudo tee -a /etc/environment

# reduce Spark logging to warnings and above (i.e no INFO or DEBUG messages)
sudo cp $SPARK_HOME/conf/log4j.properties.template $SPARK_HOME/conf/log4j.properties
sudo sed -i -e "s/log4j.rootCategory=INFO, console/log4j.rootCategory=WARN, console/g" $SPARK_HOME/conf/log4j.properties

echo "-------------------------------------------------------------------------"
echo " Remove proxy"
echo "-------------------------------------------------------------------------"

unset http_proxy
unset HTTP_PROXY
unset https_proxy
unset HTTPS_PROXY
unset no_proxy
unset NO_PROXY

echo "----------------------------------------------------------------------------------------------------------------"

cd ~ || exit

duration=$SECONDS

echo " End time : $(date)"
echo " Apache Sedona install took $((duration / 60)) mins"
echo "----------------------------------------------------------------------------------------------------------------"
