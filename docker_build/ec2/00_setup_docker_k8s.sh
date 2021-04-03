#!/usr/bin/env bash

echo "----------------------------------------------------------------------------------------------------------------"

#SSH_CONFIG="${HOME}/.ssh/aws-sandbox-config"

# get directory this script is running from
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# load AWS variables
. ${HOME}/.aws/ec2_vars.sh
#. ${SCRIPT_DIR}/ec2_vars.sh

# create EC2 instance
INSTANCE_ID=$(aws ec2 run-instances --image-id ami-06202e06492f46177 --count 1 --instance-type t2.large --key-name ${AWS_KEYPAIR} --security-group-ids ${AWS_SECURITY_GROUP} --subnet-id ${AWS_SUBNET} | \
python3 -c "import sys, json; print(json.load(sys.stdin)['Instances'][0]['InstanceId'])")

# waiting for instance to start
echo "Instance ${INSTANCE_ID} created - waiting for startup"
aws ec2 wait instance-exists --instance-ids ${INSTANCE_ID}
sleep 30

#INSTANCE_IP_ADDRESS=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} | \
#python3 -c "import sys, json; print(json.load(sys.stdin)['Reservations'][0]['Instances'][0]['PrivateIpAddress'])")
INSTANCE_IP_ADDRESS=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} | \
python3 -c "import sys, json; print(json.load(sys.stdin)['Reservations'][0]['Instances'][0]['PublicIpAddress'])")

## waiting for instance to start
echo "Got IP address : ${INSTANCE_IP_ADDRESS}"
#sleep 30

echo "----------------------------------------------------------------------------------------------------------------"

## SSM - copy scripts to remote
#scp -F ${SSH_CONFIG} -o StrictHostKeyChecking=no /Users/s57405/git/iag_geo/valhalla/docker_build/ec2/remote_setup.sh ec2-user@${INSTANCE_ID}:~/

# Non-SSM - copy scripts to remote
#scp -F ${SSH_CONFIG} -o StrictHostKeyChecking=no ${SCRIPT_DIR}/remote_setup.sh ec2-user@${INSTANCE_ID}:~/
scp -i ${AWS_PEM_FILE} -o StrictHostKeyChecking=no ${SCRIPT_DIR}/remote_setup.sh ec2-user@${INSTANCE_IP_ADDRESS}:~/

echo "----------------------------------------------------------------------------------------------------------------"

## SSM - login
#ssh -F ${SSH_CONFIG} ${INSTANCE_ID}

# Non-SSM - login
ssh -i ${AWS_PEM_FILE} ec2-user@${INSTANCE_IP_ADDRESS}

#scp -F ${SSH_CONFIG} ${SCRIPT_DIR}/*/*.py hadoop@${INSTANCE_ID}:~/

## SSM - port forward Valhalla APIs
#ssh -F ${SSH_CONFIG} -fNL 31870:${INSTANCE_IP_ADDRESS}:30702 ${INSTANCE_ID}

# Non-SSM - port forward Valhalla APIs
##ssh -i ${AWS_PEM_FILE} -fNL 31870:${INSTANCE_IP_ADDRESS}:30702 ${INSTANCE_ID}

#aws configservice get-resource-config-history --resource-type AWS::EC2::Instance --resource-id i-0d5bf0e4c94ecec94