#!/usr/bin/env bash

# TODO: create EC2 instance using AWS CLI - MUST set IAM role to developer

INSTANCE_ID="i-0b36078d360236a44"

SSH_CONFIG="${HOME}/.ssh/aws-sandbox-config"

INSTANCE_IP_ADDRESS=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} | \
python3 -c "import sys, json; print(json.load(sys.stdin)['Reservations'][0]['Instances'][0]['PrivateIpAddress'])")

# get directory this script is running from
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "----------------------------------------------------------------------------------------------------------------"

# copy scripts to remote
#scp -F ${SSH_CONFIG} -o StrictHostKeyChecking=no /Users/s57405/git/iag_geo/valhalla/docker_build/ec2/remote_setup.sh ec2-user@${INSTANCE_ID}:~/
scp -F ${SSH_CONFIG} -o StrictHostKeyChecking=no ${SCRIPT_DIR}/remote_setup.sh ec2-user@${INSTANCE_ID}:~/

# login
ssh -F ${SSH_CONFIG} ${INSTANCE_ID}

#scp -F ${SSH_CONFIG} ${SCRIPT_DIR}/*/*.py hadoop@${INSTANCE_ID}:~/

echo "----------------------------------------------------------------------------------------------------------------"

# port forward Valhalla APIs
#ssh -F ${SSH_CONFIG} -fNL 30702:${INSTANCE_IP_ADDRESS}:30702 ${INSTANCE_ID}

#aws configservice get-resource-config-history --resource-type AWS::EC2::Instance --resource-id i-0d5bf0e4c94ecec94