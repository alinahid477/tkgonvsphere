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

function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

export $(cat /root/.env | xargs)

isexist=$(ls /tmp/TANZU_CONNECT)
if [[ -n $isexist ]]
then
    export $(cat /tmp/TANZU_CONNECT | xargs)
fi

if [[ -z $TANZU_CONNECT ]]
then
    source ~/binaries/tanzu_connect_management.sh
    sleep 2
    isexist=$(ls /tmp/TANZU_CONNECT)
    if [[ -z $isexist ]]
    then
        exit
    fi
fi

if [[ -n $BASTION_HOST && -n $MANAGEMENT_CLUSTER_ENDPOINT ]]
then
    isexist=$(ls ~/.kube/config)
    if [[ -n $isexist && ! $MANAGEMENT_CLUSTER_ENDPOINT =~ "kubernetes:" ]]
    then
        isexist=$(parse_yaml ~/.kube/config | grep "$MANAGEMENT_CLUSTER_ENDPOINT" | awk -F= '$1=="clusters__server" {print $2}' | xargs)
        if [[ -n $isexist ]]
        then
            printf "\nBastion host detected, but kubeconfig file contains $MANAGEMENT_CLUSTER_ENDPOINT\nAdjusting kubeconfig....\n"
            proto="$(echo $MANAGEMENT_CLUSTER_ENDPOINT | grep :// | sed -e's,^\(.*://\).*,\1,g')"
            serverurl="$(echo ${MANAGEMENT_CLUSTER_ENDPOINT/$proto/} | cut -d/ -f1)"
            port="$(echo $serverurl | awk -F: '{print $2}')"
            serverurl="$(echo $serverurl | awk -F: '{print $1}')"
            sed -i '0,/'$serverurl'/s//kubernetes/' ~/.kube/config
            sleep 1
            printf "\n==> Done.\n"
        fi
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
        while true; do
            read -p "Review generated file ~/workload-clusters/$clustername.yaml and confirm or modify in the file and confirm to proceed further? [y/n] " yn
            case $yn in
                [Yy]* ) printf "\nyou confirmed yes\n"; break;;
                [Nn]* ) printf "\n\nYou said no. \n\nExiting...\n\n"; exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
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
    VSPHERE_CONTROL_PLANE_ENDPOINT=$(cat $configfile | sed -r 's/[[:alnum:]]+=/\n&/g' | awk -F: '$1=="VSPHERE_CONTROL_PLANE_ENDPOINT"{print $2}' | xargs)
    
    printf "\n below information were extracted from the file supplied:\n"
    printf "\nCLUSTER_NAME=$CLUSTER_NAME"
    printf "\nCLUSTER_PLAN=$CLUSTER_PLAN"
    printf "\nCONTROL_PLANE_MACHINE_COUNT=$CONTROL_PLANE_MACHINE_COUNT"
    printf "\nWORKER_MACHINE_COUNT=$WORKER_MACHINE_COUNT"
    printf "\nVSPHERE_SERVER=$VSPHERE_SERVER"
    if [[ -n $VSPEHRE_CONTROL_PLANE_ENDPOINT ]]
    then
        printf "\nVSPEHRE_CONTROL_PLANE_ENDPOINT=$VSPEHRE_CONTROL_PLANE_ENDPOINT"
    fi
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
            printf "\nVSPHERE_SERVER=$VSPHERE_SERVER is an ip.\nGoing to use this for VSPHERE_SERVER_IP..."
            foundvsphereip=$VSPHERE_SERVER
        fi
        if [[ -z $foundvsphereip && -z $VSPHERE_SERVER_IP ]]
        then
            printf "\nNo vsphere server ip detected for $VSPHERE_SERVER.\nextracting VSPHERE_SERVER_IP...\n"
            echo "=> Establishing sshuttle with remote $BASTION_USERNAME@$BASTION_HOST...."
            sleep 1
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
            printf "\nFailed to extract VSPHERE_SERVER_IP for $VSPHERE_SERVER.\nrequire user input..."
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
            printf "\nrecording VSPHERE_SERVER_IP=$VSPHERE_SERVER in .env file\n"
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
    if [[ -n $BASTION_HOST ]]
    then
        cd ~
        ./binaries/backgroundchecker.sh $CLUSTER_NAME &
    fi    
    tanzu cluster create  --file $configfile -v 9 #--tkr $TKR_VERSION # --dry-run > ~/workload-clusters/$CLUSTER_NAME-dryrun.yaml
    printf "\n\nDONE.\n\n\n"

    # printf "applying ~/workload-clusters/$CLUSTER_NAME-dryrun.yaml\n\n"
    # kubectl apply -f ~/workload-clusters/$CLUSTER_NAME-dryrun.yaml
    # printf "\n\nDONE.\n\n\n"


    if [[ -n $BASTION_HOST ]]
    then
        printf "\nWaiting for background checker to finish\n"
        isexist=$(cat /tmp/background-checker | grep "$CLUSTER_NAME")
        count=1
        while [[ -z $isexist && $count -lt 6 ]]; do
            sleep 30 #(background checker sleeps for 2m. Hence 30*5=180=2m30s is max wait time)
            printf "\nWaiting for background process signal (retry #$count of 6)..."
            isexist=$(cat /tmp/background-checker | grep "$CLUSTER_NAME")
            ((count=count+1))
        done
        printf "\n===>Finished waiting.\n"
        fuser -k 6443/tcp
        if [[ -z $MANAGEMENT_CLUSTER_ENDPOINT ]]
        then
            kubeconfigfile=~/.kube-tkg/config
            serverurl=$(awk '/server/ {print $NF;exit}' $kubeconfigfile | awk -F/ '{print $3}' | awk -F: '{print $1}')
            port=$(awk '/server/ {print $NF;exit}' $kubeconfigfile | awk -F/ '{print $3}' | awk -F: '{print $2}')
        else
            proto="$(echo $MANAGEMENT_CLUSTER_ENDPOINT | grep :// | sed -e's,^\(.*://\).*,\1,g')"
            serverurl="$(echo ${MANAGEMENT_CLUSTER_ENDPOINT/$proto/} | cut -d/ -f1)"
            port="$(echo $serverurl | awk -F: '{print $2}')"
            serverurl="$(echo $serverurl | awk -F: '{print $1}')"
            if [[ -z $port ]]
            then
                if [[ -z $proto || $proto == 'http://' ]]
                then
                    port=80
                else 
                    port=443
                fi                    
            fi
            if [[ $serverurl != 'kubernetes' && -n $serverurl && -n $port ]]
            then
                printf "\nCreating endpoint Tunnel $port:$serverurl:$port through bastion $BASTION_USERNAME@$BASTION_HOST ...\n"
                ssh -i /root/.ssh/id_rsa -4 -fNT -L $port:$serverurl:$port $BASTION_USERNAME@$BASTION_HOST
                sleep 1
                printf "\n=>Tunnel created.\n"
            fi
        fi
        printf "\n\nDONE.\n\n\n"
    else 
        printf "\nWaiting 40s...\n"
        sleep 40
        printf "\n\nDONE.\n\n\n"
    fi
    

    printf "\nGetting cluster info\n"
    tanzu cluster kubeconfig get $CLUSTER_NAME --admin
    printf "\n\nDONE.\n\n\n" 

    if [[ -n $BASTION_HOST ]]
    then
        printf "\nStopping tunnel on 443 for $VSPHERE_SERVER_IP for $VSPHERE_SERVER...\n"
        fuser -k 443/tcp
        printf "==>DONE\n"
        printf "\nAdjusting kubeconfig for $CLUSTER_NAME to work with bastion host...\n"
        sleep 1
        endpointipport=$(kubectl config view -o jsonpath='{.clusters[?(@.name == "'$CLUSTER_NAME'")].cluster.server}')
        printf "==>extracted endpoint: $endpointipport\n"
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
        printf "==>DONE\n"
        printf "\n\n================\n"
        printf "in order to use kubectl for $CLUSTER_NAME you must run '~/binaries/tanzu_connect.sh -n $CLUSTER_NAME' to establish tunnel for its endpoint $serverurl"
        printf "\n================\n\n"
    fi

    printf "\n\n\n"
    printf "*******************\n"
    printf "***COMPLETE.....***\n"
    printf "*******************\n"
    printf "\n\n\n"
fi