#!/bin/bash

clustername=$1

if [[ -z $clustername ]]
then
    printf "ERROR: failed staring merlin background checker. Empty clustername provided...\n"
    exit 1
fi
configfile=~/workload-clusters/$clustername.yaml
namespacename=$(cat $configfile | sed -r 's/[[:alnum:]]+=/\n&/g' | awk -F: '$1=="NAMESPACE"{print $2}' | xargs)

if [[ -z $namespacename ]]
then
    printf "ERROR: failed staring merlin background checker. Empty namespace name found...\n"
    exit 1
fi

printf "\n=====>\n"
printf "starting background checker for endpoint availability for cluster...\n"
count=1
sleep 7m
while [[ $count -lt 10 ]]; do
    sleep 2m
    printf "\n=====>\n"
    printf "Checking cluster endpoint...\n"
    endpointurl=$(kubectl get svc | grep "^default-${clustername}-" | awk '{print $4}')
    if [[ -n $endpointurl ]]
    then
        endpointport=$(kubectl get svc | grep "^default-merlin1-" | awk '{print $5}' | awk -F: '{print $1}')
        if [[ -n $endpointipport ]]
        then
            printf "endpoint is now available at $endpointurl:$endpointport ...\n"
            printf "establishing tunnel...\n"
            export $(cat /root/.env | xargs)
            fuser -k 6443/tcp
            ssh -i /root/.ssh/id_rsa -4 -fNT -L $endpointport:$endpointurl:$endpointport $BASTION_USERNAME@$BASTION_HOST
            echo "merlin" >> /tmp/background-checker
            printf "==> tunnel done...\n"
            count=10
            break
        fi
    fi
    ((count=count+1))
done
printf "\n=====>background checker DONE\n"