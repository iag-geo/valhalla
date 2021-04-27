#!/usr/bin/env bash


SECONDS=0*

echo "----------------------------------------------------------------------------------------------------------------"
echo " Start time : $(date)"

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

echo "Instance ${INSTANCE_ID} created"
aws ec2 wait instance-exists --instance-ids ${INSTANCE_ID}

INSTANCE_STATE="pending"

# wait for instance to fire up
while [ $INSTANCE_STATE != "running" ]; do
    sleep 5
    INSTANCE_STATE=$(aws ec2 describe-instance-status --instance-id | \
    python3 -c "import sys, json; print(json.load(sys.stdin)['InstanceStatuses'][0]['InstanceState']['Name'])")
    echo "  - Instance status : ${INSTANCE_STATE}"
done

INSTANCE_IP_ADDRESS=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} | \
python3 -c "import sys, json; print(json.load(sys.stdin)['Reservations'][0]['Instances'][0]['PrivateIpAddress'])")
#echo "IP address : ${INSTANCE_IP_ADDRESS}"

# waiting for SSH to start
INSTANCE_READY=''
while [ ! $INSTANCE_READY ]; do
    echo "  - Waiting for ready status"
    sleep 5
    set +e
    OUT=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -o BatchMode=yes ec2-user@$INSTANCE_ID 2>&1 | grep "Permission denied" )
    [[ $? = 0 ]] && INSTANCE_READY='ready'
    set -e
done

echo "----------------------------------------------------------------------------------------------------------------"

# Non-SSM - copy config file to remote
scp -i ${AWS_PEM_FILE} -o StrictHostKeyChecking=no ${SCRIPT_DIR}/remote_setup.sh ec2-user@${INSTANCE_IP_ADDRESS}:~/

echo "----------------------------------------------------------------------------------------------------------------"
echo " Start remote setup"
echo "----------------------------------------------------------------------------------------------------------------"

# run remote setup script, remotely
ssh -i ${AWS_PEM_FILE} ec2-user@${INSTANCE_ID} ". ./remote_setup.sh"

echo "----------------------------------------------------------------------------------------------------------------"

duration=$SECONDS

echo "End time : $(date)"
echo "Docker + Kubernetes install took $((duration / 60)) mins"
echo "----------------------------------------------------------------------------------------------------------------"
echo "Instance ID : ${INSTANCE_ID}"
echo "Public IP Address : ${INSTANCE_IP_ADDRESS}"
echo "----------------------------------------------------------------------------------------------------------------"

## SSM - login
#ssh -F ${SSH_CONFIG} ${INSTANCE_ID}

# Non-SSM - login
#ssh -i ${AWS_PEM_FILE} ec2-user@${INSTANCE_IP_ADDRESS}

#scp -F ${SSH_CONFIG} ${SCRIPT_DIR}/*/*.py hadoop@${INSTANCE_ID}:~/

## SSM - port forward Valhalla APIs
#ssh -F ${SSH_CONFIG} -fNL 31870:${INSTANCE_IP_ADDRESS}:30702 ${INSTANCE_ID}

# Non-SSM - port forward Valhalla APIs
##ssh -i ${AWS_PEM_FILE} -fNL 31870:${INSTANCE_IP_ADDRESS}:30702 ${INSTANCE_ID}


#curl http://${INSTANCE_IP_ADDRESS}:32060/route \
#--data '{"locations":[{"lat":-33.85,"lon":151.13,"type":"break","city":"Leichhardt","state":"NSW"},{"lat":-33.85,"lon":151.16,"type":"break","city":"Sydney","state":"NSW"}],"costing":"auto","directions_options":{"units":"kilometres"}}' | jq '.'




#aws configservice get-resource-config-history --resource-type AWS::EC2::Instance --resource-id i-0d5bf0e4c94ecec94

