#!/usr/bin/env bash

SECONDS=0*

echo "----------------------------------------------------------------------------------------------------------------"
echo " Start time : $(date)"

echo "-------------------------------------------------------------------------"
echo " Set temp local environment vars"
echo "----------------------------------------------------------------------------------------------------------------"

AMI_ID="ami-06202e06492f46177"
INSTANCE_TYPE="t2.large"
USER="ec2-user"

# load these AWS variables
#export AWS_KEYPAIR="<name of keypair>"
#export AWS_PEM_FILE="<path to keypair .pem file>"
#export AWS_SECURITY_GROUP="sg-..."
#export AWS_SUBNET="subnet-..."
. ${HOME}/.aws/minus34/minus34_ec2_vars.sh

# script to check instance status
PYTHON_SCRIPT="import sys, json
try:
    print(json.load(sys.stdin)['InstanceStatuses'][0]['InstanceState']['Name'])
except:
    print('pending')"

# get directory this script is running from
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"


# create EC2 instance
INSTANCE_ID=$(aws ec2 run-instances \
--image-id ${AMI_ID} \
--count 1 \
--instance-type ${INSTANCE_TYPE} \
--key-name ${AWS_KEYPAIR} \
--security-group-ids ${AWS_SECURITY_GROUP} \
--subnet-id ${AWS_SUBNET} \
python3 -c "import sys, json; print(json.load(sys.stdin)['Instances'][0]['InstanceId'])")

echo "Instance ${INSTANCE_ID} created"

# WARNING: this doesn't work everytime
aws ec2 wait instance-exists --instance-ids ${INSTANCE_ID}

# wait for instance to fire up
INSTANCE_STATE="pending"
while [ $INSTANCE_STATE != "running" ]; do
    sleep 5
    INSTANCE_STATE=$(aws ec2 describe-instance-status --instance-id  ${INSTANCE_ID} | python3 -c "${PYTHON_SCRIPT}")
    echo "  - Instance status : ${INSTANCE_STATE}"
done

INSTANCE_IP_ADDRESS=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} | \
python3 -c "import sys, json; print(json.load(sys.stdin)['Reservations'][0]['Instances'][0]['PublicIpAddress'])")
echo "  - Public IP address : ${INSTANCE_IP_ADDRESS}"

# save vars to local file
#echo "export SCRIPT_DIR=${SCRIPT_DIR}" > ~/git/temp_ec2_vars.sh
echo "export USER=${USER}" >> ~/git/temp_ec2_vars.sh
echo "export SSH_CONFIG=${SSH_CONFIG}" >> ~/git/temp_ec2_vars.sh
echo "export INSTANCE_ID=${INSTANCE_ID}" >> ~/git/temp_ec2_vars.sh
echo "export INSTANCE_IP_ADDRESS=${INSTANCE_IP_ADDRESS}" >> ~/git/temp_ec2_vars.sh

# waiting for SSH to start
INSTANCE_READY=""
while [ ! $INSTANCE_READY ]; do
    echo "  - Waiting for ready status"
    sleep 5
    set +e
    OUT=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes ${USER}@$INSTANCE_IP_ADDRESS 2>&1 | grep "Permission denied" )
    [[ $? = 0 ]] && INSTANCE_READY='ready'
    set -e
done

echo "----------------------------------------------------------------------------------------------------------------"

# copy config file to remote
scp -i ${AWS_PEM_FILE} -o StrictHostKeyChecking=no ${SCRIPT_DIR}/remote_setup.sh ${USER}@${INSTANCE_IP_ADDRESS}:~/

echo "----------------------------------------------------------------------------------------------------------------"
echo " Start remote setup"
echo "----------------------------------------------------------------------------------------------------------------"

# run remote setup script, remotely, to create a Kubernetes cluster with Valhalla running on 4 replicas
ssh -i ${AWS_PEM_FILE} ${USER}@${INSTANCE_IP_ADDRESS} ". ./remote_setup.sh -r 4"

echo "----------------------------------------------------------------------------------------------------------------"

duration=$SECONDS

echo "End time : $(date)"
echo "Docker + Kubernetes install took $((duration / 60)) mins"
echo "----------------------------------------------------------------------------------------------------------------"
echo "Instance ID : ${INSTANCE_ID}"
echo "Public IP Address : ${INSTANCE_IP_ADDRESS}"
echo "Base Valhalla URL : http://${INSTANCE_IP_ADDRESS}:8002/route"
echo "----------------------------------------------------------------------------------------------------------------"

# remote login
#ssh -i ${AWS_PEM_FILE} ${USER}@${INSTANCE_IP_ADDRESS}

# test Valhalla routing URL (requires jq to be installed: brew install jq)
curl http://${INSTANCE_IP_ADDRESS}:8002/route \
--data '{"locations":[{"lat":-33.85,"lon":151.13,"type":"break","city":"Leichhardt","state":"NSW"},{"lat":-33.85,"lon":151.16,"type":"break","city":"Sydney","state":"NSW"}],"costing":"auto","directions_options":{"units":"kilometres"}}' | jq '.'
