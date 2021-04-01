#!/usr/bin/env bash

INSTANCE_ID="i-006c4ccd68ed9a206"

SSH_CONFIG="${HOME}/.ssh/aws-sandbox-config"

INSTANCE_IP_ADDRESS=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} | \
python3 -c "import sys, json; print(json.load(sys.stdin)['Reservations'][0]['Instances'][0]['PrivateIpAddress'])")

# get directory this script is running from
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

echo "----------------------------------------------------------------------------------------------------------------"

# copy scripts to remote
scp -F ${SSH_CONFIG} -o StrictHostKeyChecking=no ${SCRIPT_DIR}/remote_setup.sh ecs-user@${INSTANCE_ID}:~/


ssh -F ${SSH_CONFIG} ${INSTANCE_ID}


scp -F ${SSH_CONFIG} ${SCRIPT_DIR}/../*/*.py hadoop@${INSTANCE_ID}:~/
scp -F ${SSH_CONFIG} ${SCRIPT_DIR}/../*/*.sql hadoop@${INSTANCE_ID}:~/

echo "----------------------------------------------------------------------------------------------------------------"


# port forward Spark UI web site
ssh -F ${SSH_CONFIG} -fNL 8002:${INSTANCE_IP_ADDRESS}:8002 ${INSTANCE_ID}









