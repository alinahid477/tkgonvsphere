#!/bin/bash

returnOrexit()
{
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
    then
        return
    else
        exit
    fi
}

helpFunction()
{
    printf "\nYou must provide at least one parameter. (-n parameter recommended)\n\n"
    echo "Usage: $0"
    echo -e "\t-n name of cluster to start wizard OR"
    echo -e "\t-f /path/to/configfile"
    exit 1 # Exit script after printing help
}

export $(cat /root/.env | xargs)

isexist=$(ls /tmp/TANZU_CONNECT)
if [[ -n $isexist ]]
then
    export $(cat /tmp/TANZU_CONNECT | xargs)
fi

if [[ -z $TANZU_CONNECT ]]
then
    source ~/binaries/tanzu_connect.sh
    sleep 2
    isexist=$(ls /tmp/TANZU_CONNECT)
    if [[ -z $isexist ]]
    then
        exit
    fi
fi



unset configfile
unset clustername
while getopts "f:n:" opt
do
    case $opt in
        f ) configfile="$OPTARG" ;;
        n ) clustername="$OPTARG";;
        ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
    esac
done

if [ -z "$configfile" ] 
then
    printf "no config file path.\n"
    if [[ -z $clustername ]] 
    then
        printf "no clustername given.\n"
        helpFunction
    else 
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
        source $SCRIPT_DIR/generate_workload_cluster_config.sh -n $clustername
    fi
fi

if [[ -n $clustername ]]
then
    ISCONFIGEXIST=$(ls ~/workload-clusters/ | grep $clustername)
    if [[ ! -z "$ISCONFIGEXIST" ]]
    then
        configfile=~/workload-clusters/$clustername.yaml
    fi    
else 
    ISCONFIGEXIST=$(ls $configfile)
fi


# echo "is ... $ISCONFIGEXIST"
if [ -z "$ISCONFIGEXIST" ]
then
    unset configfile    
fi

if [ -z "$configfile" ]
then
    printf "\n\nNo configfile found.\n\n";
    exit;
else
    printf "\n\nconfigfile: $configfile"

    CLUSTER_NAME=$(cat $configfile | sed -r 's/[[:alnum:]]+=/\n&/g' | awk -F: '$1=="CLUSTER_NAME"{print $2}' | xargs)
    CLUSTER_PLAN=$(cat $configfile | sed -r 's/[[:alnum:]]+=/\n&/g' | awk -F: '$1=="CLUSTER_PLAN"{print $2}' | xargs)
    CONTROL_PLANE_MACHINE_COUNT=$(cat $configfile | sed -r 's/[[:alnum:]]+=/\n&/g' | awk -F: '$1=="CONTROL_PLANE_MACHINE_COUNT"{print $2}' | xargs)
    WORKER_MACHINE_COUNT=$(cat $configfile | sed -r 's/[[:alnum:]]+=/\n&/g' | awk -F: '$1=="WORKER_MACHINE_COUNT"{print $2}' | xargs)
    VSPHERE_SERVER=$(cat $configfile | sed -r 's/[[:alnum:]]+=/\n&/g' | awk -F: '$1=="VSPHERE_SERVER"{print $2}' | xargs)
    printf "\n below information were extracted from the file supplied:\n"
    printf "\nCLUSTER_NAME=$CLUSTER_NAME"
    printf "\nCLUSTER_PLAN=$CLUSTER_PLAN"
    printf "\nCONTROL_PLANE_MACHINE_COUNT=$CONTROL_PLANE_MACHINE_COUNT"
    printf "\nWORKER_MACHINE_COUNT=$WORKER_MACHINE_COUNT"
    printf "\nVSPHERE_SERVER=$VSPHERE_SERVER"
    printf "\n\n\n"
    while true; do
        read -p "Confirm if the information is correct? [y/n] " yn
        case $yn in
            [Yy]* ) confirmation='yes'; printf "\nyou confirmed yes\n"; break;;
            [Nn]* ) printf "\n\nYou said no. \n\nExiting...\n\n"; exit;;
            * ) echo "Please answer yes or no.";;
        esac
    done
fi

if [[ ! -z $confirmation ]]
then
    printf "\n\n\n"
    printf "*********************************************\n"
    printf "*** starting tkg k8s cluster provision...****\n"
    printf "*********************************************\n"
    printf "\n\n\n"

    sed -i '$ d' $configfile

    doshuttle='n'
    if [[ -n $BASTION_HOST && $doshuttle == 'n' ]]
    then
        printf "\n\nBastion host detected\n"
        sleep 1
        if [[ $VSPHERE_SERVER =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+[\:0-9]*$ && -z $VSPHERE_SERVER_IP ]]
        then
            echo "\nVSPHERE_SERVER=$VSPHERE_SERVER is an ip.\nGoing to use this for VSPHERE_SERVER_IP..."
            foundvsphereip=$VSPHERE_SERVER
        fi
        if [[ -z $foundvsphereip && -z $VSPHERE_SERVER_IP ]]
        then
            printf "\nNo vsphere server ip detected for $VSPHERE_SERVER.\nextracting VSPHERE_SERVER_IP..."
            echo "=> Establishing sshuttle with remote $BASTION_USERNAME@$BASTION_HOST...."
            sshuttle --dns --python python2 -D -r $BASTION_USERNAME@$BASTION_HOST 0/0 -x $BASTION_HOST/32 --disable-ipv6 --listen 0.0.0.0:0
            echo "=> DONE."
            printf "\nextracting VSPHERE_SERVER_IP...\n"
            foundvsphereip=$(getent hosts $VSPHERE_SERVER | awk '{ print $1 }')
            sleep 1
            printf "\n$foundvsphereip\n"
            sleep 1
            echo "=> DONE."
            printf "\nStopping sshuttle...\n"
            sshuttlepid=$(ps aux | grep "/usr/bin/sshuttle --dns" | awk 'FNR == 1 {print $2}')
            kill $sshuttlepid
            sleep 1
            printf "==> DONE\n"
        fi
        if [[ -z $foundvsphereip && -z $VSPHERE_SERVER_IP ]]
        then
            echo "\nFailed to extract VSPHERE_SERVER_IP for $VSPHERE_SERVER.\nrequire user input..."
            while true; do
                read -p "VSPHERE_SERVER_IP: " inp
                if [ -z "$inp" ]
                then
                    printf "\nYou must provide a valid value.\n"
                else 
                    foundvsphereip=$inp
                    break
                fi
            done
        fi
        if [[ -n $foundvsphereip && -z $VSPHERE_SERVER_IP ]]
        then
            VSPHERE_SERVER_IP=$foundvsphereip
            echo "\nrecording VSPHERE_SERVER_IP=$VSPHERE_SERVER in .env file\n"
            printf "\nVSPHERE_SERVER_IP=$VSPHERE_SERVER_IP" >> /root/.env
            sleep 1
        fi
        if [[ -n $VSPHERE_SERVER_IP ]]
        then
            printf "\nestablish tunnel for $VSPHERE_SERVER_IP on 443\n"
            sleep 1
            printf "127.0.0.1 $VSPHERE_SERVER\n" >> /etc/hosts
            ssh -i /root/.ssh/id_rsa -4 -fNT -L 443:$VSPHERE_SERVER_IP:443 $BASTION_USERNAME@$BASTION_HOST
            printf "==> DONE.\n"
            sleep 1
        else
            echo "\nERROR: When bastion host is enabled you must provide VSPHERE_SERVER_IP\nexiting....\n"
            exit 1
        fi
    fi

    printf "Creating k8s cluster from yaml called ~/workload-clusters/$CLUSTER_NAME.yaml\n\n"
    sleep 2
    tanzu cluster create  --file $configfile -v 9 #--tkr $TKR_VERSION # --dry-run > ~/workload-clusters/$CLUSTER_NAME-dryrun.yaml
    printf "\n\nDONE.\n\n\n"

    # printf "applying ~/workload-clusters/$CLUSTER_NAME-dryrun.yaml\n\n"
    # kubectl apply -f ~/workload-clusters/$CLUSTER_NAME-dryrun.yaml
    # printf "\n\nDONE.\n\n\n"

    printf "\nWaiting 1 mins to complete cluster create\n"
    sleep 1m
    printf "\n\nDONE.\n\n\n"

    printf "\nGetting cluster info\n"
    tanzu cluster kubeconfig get $CLUSTER_NAME --admin
    printf "\n\nDONE.\n\n\n"

    fuser -k 443/tcp
       

    if [[ -n $BASTION_HOST ]]
    then
        printf "\nBastion host detected...\n"
        printf "\nAdjusting kubeconfig for $CLUSTER_NAME to work with bastion host...\n"
        endpointipport=$(kubectl config view -o jsonpath='{.clusters[?(@.name == "'$CLUSTER_NAME'")].cluster.server}')
        printf "\n\n$endpointipport\n\n"
        proto="$(echo $endpointipport | grep :// | sed -e's,^\(.*://\).*,\1,g')"
        serverurl="$(echo ${endpointipport/$proto/} | cut -d/ -f1)"
        port="$(echo $serverurl | awk -F: '{print $2}')"
        serverurl="$(echo $serverurl | awk -F: '{print $1}')"
        if [[ -n $endpointipport ]]
        then
            printf "\nAdjusting kubeconfig for $CLUSTER_NAME for tunneling...\n"
            sed -i '0,/'$serverurl'/s//kubernetes/' /root/.kube/config
            sleep 1
            keyname=$(echo "$CLUSTER_NAME"_CLUSTER_ENDPOINT)
            printf "\n$keyname=$serverurl:$port" >> /root/.env
        else
            printf "\nERROR: Adjusting kubeconfig for $CLUSTER_NAME. Please manually change the cluster endpoint to domain name 'kubernetes'...\n"
        fi
    fi

    printf "\n\n\n"
    printf "*******************\n"
    printf "***COMPLETE.....***\n"
    printf "*******************\n"
    printf "\n\n\n"
fi