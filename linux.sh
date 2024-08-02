#!/bin/bash
token=$1
PCC_URL=$2
PCC_SAN=$3

if command -v kubeadm
then
    echo "This instance runs on kubernetes cluster. Installation still not supported"
else
    if sudo docker ps > /dev/null; then args=""; else args="--install-host"; fi
    curl -sSL -k --header "authorization: Bearer $token" -X POST ${PCC_URL}/api/v1/scripts/defender.sh | sudo bash -s -- -c "${PCC_SAN}" -m -u $args
fi