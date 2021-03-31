#!/usr/bin/env bash

INSTANCE_ID="i-0d5bf0e4c94ecec94"
SSH_CONFIG="${HOME}/.ssh/aws-sandbox-config"

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









