#!/bin/bash
export $(cat /root/.env | xargs)

helpFunction()
{
    printf "\nYou must provide at least one parameter. (-n parameter recommended)\n\n"
    echo "Usage: $0"
    echo -e "\t-n name of cluster to start wizard OR"
    echo -e "\t-f /path/to/configfile"
    exit 1 # Exit script after printing help
}
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
    if [ -z "$clustername" ] 
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


    if [[ -n $BASTION_HOST ]]
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
            echo "\nNo vsphere server ip detected for $VSPHERE_SERVER.\nextracting VSPHERE_SERVER_IP..."
            echo "=> Establishing sshuttle with remote $BASTION_USERNAME@$BASTION_HOST...."
            sshuttle --dns --python python2 -D -r $BASTION_USERNAME@$BASTION_HOST 0/0 -x $BASTION_HOST/32 --disable-ipv6 --listen 0.0.0.0:0
            echo "=> DONE."
            foundvsphereip=$(getent hosts $VSPHERE_SERVER | awk '{ print $1 }')
            sleep 1
            printf "\nStopping sshuttle...\n"
            sshuttlepid=$(ps aux | grep "/usr/bin/sshuttle --dns" | awk 'FNR == 1 {print $2}')
            kill $sshuttlepid
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
        fi
        if [[ -n $VSPHERE_SERVER_IP ]]
        then
            printf "\nestablish tunnel for $VSPHERE_SERVER_IP\n"
            printf "127.0.0.1 $VSPHERE_SERVER\n" >> /etc/hosts
            ssh -i /root/.ssh/id_rsa -4 -fNT -L 443:$VSPHERE_SERVER_IP:443 $BASTION_USERNAME@$BASTION_HOST
            printf "==> DONE.\n"
        else
            echo "\nERROR: When bastion host is enabled you must provide VSPHERE_SERVER_IP\nexiting....\n"
            exit 1
        fi
    fi

    printf "Creating k8s cluster from yaml called ~/workload-clusters/$CLUSTER_NAME.yaml\n\n"
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
       

    printf "\n\n\n"
    printf "*******************\n"
    printf "***COMPLETE.....***\n"
    printf "*******************\n"
    printf "\n\n\n"
fi