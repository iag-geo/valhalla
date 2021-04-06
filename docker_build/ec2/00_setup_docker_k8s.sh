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

# waiting for instance to start
echo "Instance ${INSTANCE_ID} created"
aws ec2 wait instance-exists --instance-ids ${INSTANCE_ID}
#sleep 30

#INSTANCE_IP_ADDRESS=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} | \
#python3 -c "import sys, json; print(json.load(sys.stdin)['Reservations'][0]['Instances'][0]['PrivateIpAddress'])")
INSTANCE_IP_ADDRESS=$(aws ec2 describe-instances --instance-ids ${INSTANCE_ID} | \
python3 -c "import sys, json; print(json.load(sys.stdin)['Reservations'][0]['Instances'][0]['PublicIpAddress'])")

## waiting for instance to start
echo "Got IP address : ${INSTANCE_IP_ADDRESS} - waiting 30 seconds for instance to finish startup"
sleep 30

echo "----------------------------------------------------------------------------------------------------------------"

## Non-SSM - copy config file to remote
#scp -i ${AWS_PEM_FILE} -o StrictHostKeyChecking=no ${SCRIPT_DIR}/valhalla-config.yml ec2-user@${INSTANCE_IP_ADDRESS}:~/

# SSM - copy config file to remote
#scp -F ${SSH_CONFIG} -o StrictHostKeyChecking=no ${SCRIPT_DIR}/valhalla-config.yml ec2-user@${INSTANCE_ID}:~/

echo "----------------------------------------------------------------------------------------------------------------"

# run remote setup script
ssh  -i ${AWS_PEM_FILE} -o StrictHostKeyChecking=no ec2-user@${INSTANCE_IP_ADDRESS} "bash -s" < ${SCRIPT_DIR}/remote_setup.sh

## port forward from Kubernetes to all local IPs (to enable external requests)
#ssh  -i ${AWS_PEM_FILE} ec2-user@${INSTANCE_IP_ADDRESS} "kubectl port-forward service/valhalla 8002:8002 --address=0.0.0.0 &"

echo "----------------------------------------------------------------------------------------------------------------"

duration=$SECONDS

echo " End time : $(date)"
echo " Docker + Kubernetes install took $((duration / 60)) mins"
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

