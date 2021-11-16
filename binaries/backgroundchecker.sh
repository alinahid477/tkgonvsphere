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
printf "starting background checker for endpoint availability of cluster $clustername...\n"
printf "=====>\n\n"
count=1
startEndpointCheck='n'
while [[ $startEndpointCheck == 'n' && $count -lt 20 ]]; do
    sleep 3m
    printf "\n=====>\n"
    printf "Checking cluster readiness for ${clustername}...\n"
    workersStatus=$(tanzu clusters list -o json | jq -r '.[] | select(.name=="'$clustername'") | .workers')
    printf "workers status: $workersStatus\n"
    if [[ -n $workersStatus && $workersStatus != 'null' ]]
    then
        workersCreated=$(echo $workersStatus | awk -F/ '{print $1}')
        workersDesired=$(echo $workersStatus | awk -F/ '{print $2}')
        if [[ $workersCreated == $workersDesired ]]
        then
            startEndpointCheck='y'
            printf "desired workers status achieved: $workersStatus\n"
        else
            sleep 1m
        fi
    else
        sleep 2m
    fi
    ((count=count+1))
done
if [[ $startEndpointCheck == 'n' ]]
then
    printf "======>\n"
    printf "ERROR: Background checker failed to validate that if the tanzu cluster $clustername ever achieved running state..."
    printf "======>\n"
    exit 1
fi
count=1
while [[ $startEndpointCheck == 'y' && $count -lt 20 ]]; do
    printf "\n=====>\n"
    printf "Checking cluster endpoint for ${clustername}...\n"
    endpointurl=$(kubectl get svc | grep ^default-${clustername}- | awk '{print $4}')
    printf "endpointurl: $endpointurl\n"
    if [[ -n $endpointurl ]]
    then
        endpointport=$(kubectl get svc | grep ^default-${clustername}- | awk '{print $5}' | awk -F: '{print $1}')
        printf "endpointport: $endpointport\n"
        if [[ -n $endpointport ]]
        then
            printf "endpoint is now available at $endpointurl:$endpointport ...\n"
            printf "establishing tunnel...\n"
            export $(cat /root/.env | xargs)
            fuser -k 6443/tcp
            ssh -i /root/.ssh/id_rsa -4 -fNT -L $endpointport:$endpointurl:$endpointport $BASTION_USERNAME@$BASTION_HOST
            echo $clustername > /tmp/background-checker
            printf "==> tunnel done...\n"
            count=11
            printf "\n=====>background checker COMPLETE\n"
            exit 1
        fi
    fi
    sleep 1m
    ((count=count+1))
done
printf "\n=====>background checker DONE\n"