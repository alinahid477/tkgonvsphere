#!/bin/bash

unset CLUSTER_NAME
unset CLUSTER_PLAN
unset ENABLE_MHC
unset CLUSTER_CIDR
unset SERVICE_CIDR
unset AVI_CONTROL_PLANE_HA_PROVIDER

while getopts "n:" opt
do
    case $opt in
        n ) clustername="$OPTARG";;
    esac
done

if [ -z "$clustername" ]
then
    printf "\n Error: No cluster name given. Exit..."
    exit 1
else 
    CLUSTER_NAME=$clustername
fi

printf "\n\nLooking for management cluster config at: ~/.config/tanzu/tkg/clusterconfigs/\n"
mgmtconfigfile=$(ls ~/.config/tanzu/tkg/clusterconfigs/ | awk -v i=1 -v j=1 'FNR == i {print $j}')
printf "\n\nFound management cluster config file: $mgmtconfigfile\n"
if [[ ! -z $mgmtconfigfile ]]
then
    mgmtconfigfile=~/.config/tanzu/tkg/clusterconfigs/$mgmtconfigfile 
    echo "" >> ~/workload-clusters/tmp.yaml
    chmod 777 ~/workload-clusters/tmp.yaml
    while IFS=: read -r key val
    do
        if [[ $key == *@("VSPHERE"|"TKG_HTTP_PROXY_ENABLED"|"IDENTITY_MANAGEMENT_TYPE"|"ENABLE_AUDIT_LOGGING"|"INFRASTRUCTURE_PROVIDER")* ]]
        then
            if [[ "$key" != *@("VSPHERE_CONTROL_PLANE_"|"VSPHERE_WORKER_"|"VSPHERE_TLS_THUMBPRINT")* ]]
            then
                printf "$key: $(echo $val | sed 's,^ *,,; s, *$,,')\n" >> ~/workload-clusters/tmp.yaml          
            fi
        fi
        
        if [[ $key == *"CLUSTER_PLAN"* ]]
        then
            CLUSTER_PLAN=$(echo $val | sed 's,^ *,,; s, *$,,')
        fi

        if [[ $key == "ENABLE_MHC" ]]
        then
            ENABLE_MHC=$(echo $val | sed 's,^ *,,; s, *$,,')
        fi

        if [[ $key == "CLUSTER_CIDR" ]]
        then
            CLUSTER_CIDR=$(echo $val | sed 's,^ *,,; s, *$,,')
        fi
        if [[ $key == "SERVICE_CIDR" ]]
        then
            SERVICE_CIDR=$(echo $val | sed 's,^ *,,; s, *$,,')
        fi

        if [[ $key == *"AVI_CONTROL_PLANE_HA_PROVIDER"* ]]
        then
            AVI_CONTROL_PLANE_HA_PROVIDER=$(echo $val | sed 's,^ *,,; s, *$,,')
            # needed to catch this value for the if condition for VSPEHRE_CONTROL_PLANE_ENDPOINT input
            printf "AVI_CONTROL_PLANE_HA_PROVIDER: $AVI_CONTROL_PLANE_HA_PROVIDER\n" >> ~/workload-clusters/tmp.yaml
        fi

        if [[ $key == "VSPHERE_TLS_THUMBPRINT" ]]
        then
            VSPHERE_TLS_THUMBPRINT=$(echo $val | sed 's,^ *,,; s, *$,,')
            # needed to catch this value to chech the below and if present also append VSPHERE_INSECURE: false
            if [[ -n $VSPHERE_TLS_THUMBPRINT ]]
            then
                printf "VSPHERE_TLS_THUMBPRINT: $VSPHERE_TLS_THUMBPRINT\n" >> ~/workload-clusters/tmp.yaml
                printf "VSPHERE_INSECURE: false\n" >> ~/workload-clusters/tmp.yaml
            else
                printf "VSPHERE_INSECURE: true\n" >> ~/workload-clusters/tmp.yaml
            fi
        fi
        # echo "key=$key --- val=$(echo $val | sed 's,^ *,,; s, *$,,')"
    done < "$mgmtconfigfile"

    printf "\ncluster name accepted: $CLUSTER_NAME"
    printf "CLUSTER_NAME: $CLUSTER_NAME\n" >> ~/workload-clusters/tmp.yaml
    printf "\n\n"

    printf "\n\nFew additional input required\n\n"



    # while true; do
    #     read -p "CLUSTER_NAME:(press enter to keep value extracted from parameter \"$clustername\") " inp
    #     if [ -z "$inp" ]
    #     then
    #         CLUSTER_NAME=$clustername
    #     else 
    #         CLUSTER_NAME=$inp
    #     fi
    #     if [ -z "$CLUSTER_NAME" ]
    #     then 
    #         printf "\nThis is a required field.\n"
    #     else
    #         printf "\ncluster name accepted: $CLUSTER_NAME"
    #         printf "CLUSTER_NAME: $CLUSTER_NAME\n" >> ~/workload-clusters/tmp.yaml
    #         break
    #     fi
    # done
    
    vsphere7='y'
    while true; do
        read -p "Are you deploying on vSphere7? [y/n] " yn
        case $yn in
            [Yy]* ) vsphere7='y'; printf "you said yes.\n"; break;;
            [Nn]* ) vsphere7='n'; printf "You said no.\n"; break;;
            * ) echo "Please answer yes[y] or no[n].";;
        esac
    done
    if [[ $vsphere7 == 'y' ]]
    then
        printf "DEPLOY_TKG_ON_VSPHERE7: \"true\"\n" >> ~/workload-clusters/tmp.yaml
    else
        printf "DEPLOY_TKG_ON_VSPHERE7: \"false\"\n" >> ~/workload-clusters/tmp.yaml
    fi
    printf "\n\n"


    read -p "CLUSTER_PLAN:(press enter to keep extracted default \"$CLUSTER_PLAN\") " inp
    if [ -z "$inp" ]
    then
        inp=$CLUSTER_PLAN
    else 
        CLUSTER_PLAN=$inp
    fi
    printf "CLUSTER_PLAN: $inp\n" >> ~/workload-clusters/tmp.yaml
    printf "\n\n"

    CONTROLPLANE_SIZE="small"
    CONTROL_PLANE_MACHINE_COUNT=1
    if [[ $CLUSTER_PLAN == "prod" ]]
    then
        CONTROL_PLANE_MACHINE_COUNT=3
        CONTROLPLANE_SIZE="large"
    fi
    WORKER_SIZE="small"
    WORKER_MACHINE_COUNT=1
    if [[ $CLUSTER_PLAN == "prod" ]]
    then
        WORKER_MACHINE_COUNT=3
        WORKER_SIZE="large"
    fi

    while true; do
        read -p "CONTROL_PLANE_MACHINE_COUNT:(press enter to keep default \"$CONTROL_PLANE_MACHINE_COUNT\") " inp
        if [ -z "$inp" ]
        then
            inp=$CONTROL_PLANE_MACHINE_COUNT
        fi
        if [[ ! $inp =~ ^[0-9]+$ || $inp < 1 ]]
        then
            printf "\nYou must provide a valid value.\n"
        else
            break
        fi
    done
    printf "CONTROL_PLANE_MACHINE_COUNT: $inp\n" >> ~/workload-clusters/tmp.yaml
    printf "\n\n"
    while true; do
        read -p "WORKER_MACHINE_COUNT:(press enter to keep default \"$WORKER_MACHINE_COUNT\") " inp
        if [ -z "$inp" ]
        then
            inp=$WORKER_MACHINE_COUNT
        fi
        if [[ ! $inp =~ ^[0-9]+$ || $inp < 1 ]]
        then
            printf "\nYou must provide a valid value.\n"
        else
            break
        fi
    done
    printf "WORKER_MACHINE_COUNT: $inp\n" >> ~/workload-clusters/tmp.yaml
    printf "\n\n"


    usesize='y'
    printf "Tanzu has below predefined node sizes:\n"
    echo -e "\tSize Name:small, Size:2 CPUs, 4 GB memory, 20 GB disk"
    echo -e "\tSize Name:medium, Size:2 CPUs, 8 GB memory, 40 GB disk"
    echo -e "\tSize Name:large, Size:4 CPUs, 16 GB memory, 40 GB disk"
    echo -e "\tSize Name:extra-large, Size:8 CPUs, 32 GB memory, 80 GB disk"
    while true; do
        printf "\nSelecting y will prompt with size choices."
        printf "\nSelecting n will prompt with custom node configuration options."
        printf "\n"
        read -p "Would you like to use the predfined sizes? [y/n] " yn
        case $yn in
            [Yy]* ) usesize='y'; printf "\nyou said yes.\n"; break;;
            [Nn]* ) usesize='n'; printf "\nYou said no.\n"; break;;
            * ) echo "Please answer yes[y] or no[n].";;
        esac
    done

    if [[ $usesize == 'y' ]]
    then
        read -p "CONTROLPLANE_SIZE:(press enter to keep extracted default \"$CONTROLPLANE_SIZE\") " inp
        if [ -z "$inp" ]
        then
            inp=$CONTROLPLANE_SIZE
        fi
        printf "CONTROLPLANE_SIZE: $inp\n" >> ~/workload-clusters/tmp.yaml
        printf "\n\n"
        read -p "WORKER_SIZE:(press enter to keep extracted default \"$WORKER_SIZE\") " inp
        if [ -z "$inp" ]
        then
            inp=$WORKER_SIZE
        fi
        printf "WORKER_SIZE: $inp\n" >> ~/workload-clusters/tmp.yaml
        printf "\n\n"
    else
        VSPHERE_CONTROL_PLANE_NUM_CPUS=2
        VSPHERE_CONTROL_PLANE_DISK_GIB=20
        VSPHERE_CONTROL_PLANE_MEM_MIB=4096
        if [[ $CLUSTER_PLAN == "prod" ]]
        then
            VSPHERE_CONTROL_PLANE_NUM_CPUS=4
            VSPHERE_CONTROL_PLANE_DISK_GIB=40
            VSPHERE_CONTROL_PLANE_MEM_MIB=16384
        fi
        VSPHERE_WORKER_NUM_CPUS=2
        VSPHERE_WORKER_DISK_GIB=20
        VSPHERE_WORKER_MEM_MIB=4096
        if [[ $CLUSTER_PLAN == "prod" ]]
        then
            VSPHERE_WORKER_NUM_CPUS=4
            VSPHERE_WORKER_DISK_GIB=40
            VSPHERE_WORKER_MEM_MIB=16384
        fi
        while true; do
            read -p "VSPHERE_CONTROL_PLANE_NUM_CPUS:(press enter to keep extracted default \"$VSPHERE_CONTROL_PLANE_NUM_CPUS\") " inp
            if [ -z "$inp" ]
            then
                inp=$VSPHERE_CONTROL_PLANE_NUM_CPUS
            fi
            if [[ ! $inp =~ ^[0-9]+$ || $inp < 1 ]]
            then
                printf "\nYou must provide a valid value.\n"
            else
                break
            fi
        done
        printf "VSPHERE_CONTROL_PLANE_NUM_CPUS: $inp\n" >> ~/workload-clusters/tmp.yaml
        printf "\n\n"

        while true; do
            read -p "VSPHERE_CONTROL_PLANE_DISK_GIB:(press enter to keep extracted default \"$VSPHERE_CONTROL_PLANE_DISK_GIB\") " inp
            if [ -z "$inp" ]
            then
                inp=$VSPHERE_CONTROL_PLANE_DISK_GIB
            fi
            if [[ ! $inp =~ ^[0-9]+$ || $inp < 1 ]]
            then
                printf "\nYou must provide a valid value.\n"
            else
                break
            fi
        done
        printf "VSPHERE_CONTROL_PLANE_DISK_GIB: $inp\n" >> ~/workload-clusters/tmp.yaml
        printf "\n\n"
        
        while true; do
            read -p "VSPHERE_CONTROL_PLANE_MEM_MIB:(press enter to keep extracted default \"$VSPHERE_CONTROL_PLANE_MEM_MIB\") " inp
            if [ -z "$inp" ]
            then
                inp=$VSPHERE_CONTROL_PLANE_MEM_MIB
            fi
            if [[ ! $inp =~ ^[0-9]+$ || $inp < 1 ]]
            then
                printf "\nYou must provide a valid value.\n"
            else
                break
            fi
        done
        printf "VSPHERE_CONTROL_PLANE_MEM_MIB: $inp\n" >> ~/workload-clusters/tmp.yaml
        
        printf "\n\n-----------------------\n\n"

        while true; do
            read -p "VSPHERE_WORKER_NUM_CPUS:(press enter to keep extracted default \"$VSPHERE_WORKER_NUM_CPUS\") " inp
            if [ -z "$inp" ]
            then
                inp=$VSPHERE_WORKER_NUM_CPUS
            fi
            if [[ ! $inp =~ ^[0-9]+$ || $inp < 1 ]]
            then
                printf "\nYou must provide a valid value.\n"
            else
                break
            fi
        done
        printf "VSPHERE_WORKER_NUM_CPUS: $inp\n" >> ~/workload-clusters/tmp.yaml
        printf "\n\n"
        
        while true; do
            read -p "VSPHERE_WORKER_DISK_GIB:(press enter to keep extracted default \"$VSPHERE_WORKER_DISK_GIB\") " inp
            if [ -z "$inp" ]
            then
                inp=$VSPHERE_WORKER_DISK_GIB
            fi
            if [[ ! $inp =~ ^[0-9]+$ || $inp < 1 ]]
            then
                printf "\nYou must provide a valid value.\n"
            else
                break
            fi
        done
        printf "VSPHERE_WORKER_DISK_GIB: $inp\n" >> ~/workload-clusters/tmp.yaml
        printf "\n\n"
        
        while true; do
            read -p "VSPHERE_WORKER_MEM_MIB:(press enter to keep extracted default \"$VSPHERE_WORKER_MEM_MIB\") " inp
            if [ -z "$inp" ]
            then
                inp=$VSPHERE_WORKER_MEM_MIB
            fi
            if [[ ! $inp =~ ^[0-9]+$ || $inp < 1 ]]
            then
                printf "\nYou must provide a valid value.\n"
            else
                break
            fi
        done
        printf "VSPHERE_WORKER_MEM_MIB: $inp\n" >> ~/workload-clusters/tmp.yaml
        printf "\n\n"
    fi


    while true; do
        read -p "Enable Machine Health Check (Default as per management cluster is: $ENABLE_MHC)? [y/n] " yn
        case $yn in
            [Yy]* ) ENABLE_MHC="true"; printf "You said yes.\n"; break;;
            [Nn]* ) ENABLE_MHC="false"; printf "You said no.\n"; break;;
            * ) echo "Please answer yes[y] or no[n].";;
        esac
    done
    if [[ $ENABLE_MHC == "true" ]]
    then
        printf "ENABLE_MHC: \n" >> ~/workload-clusters/tmp.yaml
        printf "ENABLE_MHC_CONTROL_PLANE: true\n" >> ~/workload-clusters/tmp.yaml
        printf "ENABLE_MHC_WORKER_NODE: true\n" >> ~/workload-clusters/tmp.yaml
        printf "MHC_UNKNOWN_STATUS_TIMEOUT: 5m\n" >> ~/workload-clusters/tmp.yaml
        printf "MHC_FALSE_STATUS_TIMEOUT: 12m\n" >> ~/workload-clusters/tmp.yaml
        printf "\n\n"
    fi

    read -p "CLUSTER_CIDR:(press enter to keep extracted default \"$CLUSTER_CIDR\") " inp
    if [ -z "$inp" ]
    then
        inp=$CLUSTER_CIDR
    fi
    printf "CLUSTER_CIDR: $inp\n" >> ~/workload-clusters/tmp.yaml
    printf "\n\n"
    read -p "SERVICE_CIDR:(press enter to keep extracted default \"$SERVICE_CIDR\") " inp
    if [ -z "$inp" ]
    then
        inp=$SERVICE_CIDR
    fi
    printf "SERVICE_CIDR: $inp\n" >> ~/workload-clusters/tmp.yaml
    printf "\n\n"


    if [[ $AVI_CONTROL_PLANE_HA_PROVIDER == 'false' ]]
    then
        printf "\nEnter the IP address of this cluster's endpoint\n"
        while true; do
            read -p "VSPHERE_CONTROL_PLANE_ENDPOINT: " inp
            if [[ -z $inp || ! $inp =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
            then
                printf "\nYou must provide a valid value.\n"
            else
                break
            fi
        done
        printf "VSPHERE_CONTROL_PLANE_ENDPOINT: $inp\n" >> ~/workload-clusters/tmp.yaml
        printf "\n\n"
    else
        printf "VSPHERE_CONTROL_PLANE_ENDPOINT: \n" >> ~/workload-clusters/tmp.yaml
    fi


    usecustomimageregistry='n'
    while true; do
        read -p "Do you have a self-signed image registry (eg:Harbor) that you'd like this cluster to be authorised with? [y/n] " yn
        case $yn in
            [Yy]* ) usecustomimageregistry='y'; printf "\nyou said yes.\n"; break;;
            [Nn]* ) usecustomimageregistry='n'; printf "\nYou said no.\n"; break;;
            * ) echo "Please answer yes[y] or no[n].";;
        esac
    done
    if [[ $usecustomimageregistry == 'y' ]]
    then
        read -p "TKG_CUSTOM_IMAGE_REPOSITORY (IP address or FQDN of your local registry): " inp
        if [ -z "$inp" ]
        then
            inp=$TKG_CUSTOM_IMAGE_REPOSITORY
        fi
        printf "TKG_CUSTOM_IMAGE_REPOSITORY: $inp\n" >> ~/workload-clusters/tmp.yaml
        printf "\n\n"
        printf "If your private Docker registry uses a self-signed certificate, provide the CA certificate in base64 encoded format e.g. base64 -w 0 your-ca.crt\n"
        read -p "TKG_CUSTOM_IMAGE_REPOSITORY_CA_CERTIFICATE: " inp
        if [ -z "$inp" ]
        then
            inp=$TKG_CUSTOM_IMAGE_REPOSITORY_CA_CERTIFICATE
        fi
        printf "TKG_CUSTOM_IMAGE_REPOSITORY_CA_CERTIFICATE: \"$inp\"\n" >> ~/workload-clusters/tmp.yaml
        printf "\n\n"
    else
        printf "\n\n"
    fi


    ENABLE_AUTOSCALER='false'
    while true; do
        read -p "Do you like to enable cluster autoscaler? [y/n] " yn
        case $yn in
            [Yy]* ) ENABLE_AUTOSCALER='true'; printf "you said yes.\n"; break;;
            [Nn]* ) printf "You said no.\n"; break;;
            * ) echo "Please answer yes[y] or no[n].";;
        esac
    done
    if [[ $ENABLE_AUTOSCALER == 'true' ]]
    then
        printf "ENABLE_AUTOSCALER: $ENABLE_AUTOSCALER\n" >> ~/workload-clusters/tmp.yaml

        while true; do
            read -p "AUTOSCALER_MAX_NODES_TOTAL: " inp
            if [[ ! $inp =~ ^[0-9]+$ || $inp < 1 ]]
            then
                printf "\nYou must provide a valid value.\n"
            else
                AUTOSCALER_MAX_NODES_TOTAL=$inp
                break
            fi
        done
        printf "AUTOSCALER_MAX_NODES_TOTAL: $AUTOSCALER_MAX_NODES_TOTAL\n" >> ~/workload-clusters/tmp.yaml
        printf "\n\n"
        while true; do
            read -p "AUTOSCALER_SCALE_DOWN_DELAY_AFTER_ADD (in minutes): " inp
            if [[ ! $inp =~ ^[0-9]+$ || $inp < 1 ]]
            then
                printf "\nYou must provide a valid value.\n"
            else
                AUTOSCALER_SCALE_DOWN_DELAY_AFTER_ADD="${inp}m"
                break                
            fi
        done
        printf "AUTOSCALER_SCALE_DOWN_DELAY_AFTER_ADD: $AUTOSCALER_SCALE_DOWN_DELAY_AFTER_ADD\n" >> ~/workload-clusters/tmp.yaml
        printf "\n\n"
        while true; do
            read -p "AUTOSCALER_SCALE_DOWN_DELAY_AFTER_DELETE (in minutes): " inp
            if [[ ! $inp =~ ^[0-9]+$ || $inp < 1 ]]
            then
                printf "\nYou must provide a valid value.\n"
            else
                AUTOSCALER_SCALE_DOWN_DELAY_AFTER_DELETE="${inp}m"
                break
            fi
        done
        printf "AUTOSCALER_SCALE_DOWN_DELAY_AFTER_DELETE: $AUTOSCALER_SCALE_DOWN_DELAY_AFTER_DELETE\n" >> ~/workload-clusters/tmp.yaml
        printf "\n\n"
        while true; do
            read -p "AUTOSCALER_SCALE_DOWN_DELAY_AFTER_FAILURE (in minutes): " inp
            if [[ ! $inp =~ ^[0-9]+$ || $inp < 1 ]]
            then
                printf "\nYou must provide a valid value.\n"
            else
                AUTOSCALER_SCALE_DOWN_DELAY_AFTER_FAILURE="${inp}m"
                break
            fi
        done
        printf "AUTOSCALER_SCALE_DOWN_DELAY_AFTER_FAILURE: $AUTOSCALER_SCALE_DOWN_DELAY_AFTER_FAILURE\n" >> ~/workload-clusters/tmp.yaml
        printf "\n\n"
        while true; do
            read -p "AUTOSCALER_SCALE_DOWN_UNNEEDED_TIME (in minutes): " inp
            if [[ ! $inp =~ ^[0-9]+$ || $inp < 1 ]]
            then
                printf "\nYou must provide a valid value.\n"
            else
                AUTOSCALER_SCALE_DOWN_UNNEEDED_TIME="${inp}m"
                break
            fi
        done
        printf "AUTOSCALER_SCALE_DOWN_UNNEEDED_TIME: $AUTOSCALER_SCALE_DOWN_UNNEEDED_TIME\n" >> ~/workload-clusters/tmp.yaml
        printf "\n\n"
        while true; do
            read -p "AUTOSCALER_MAX_NODE_PROVISION_TIME (in minutes): " inp
            if [[ ! $inp =~ ^[0-9]+$ || $inp < 1 ]]
            then
                printf "\nYou must provide a valid value.\n"
            else
                AUTOSCALER_MAX_NODE_PROVISION_TIME="${inp}m"
                break
            fi
        done
        printf "AUTOSCALER_MAX_NODE_PROVISION_TIME: $AUTOSCALER_MAX_NODE_PROVISION_TIME\n" >> ~/workload-clusters/tmp.yaml
        printf "\n\n"
    else 
        printf "ENABLE_AUTOSCALER: false\n" >> ~/workload-clusters/tmp.yaml
    fi

    
    printf "\n\n======================\n\n"


    printf "CNI: antrea\n" >> ~/workload-clusters/tmp.yaml
    printf "NAMESPACE: default\n" >> ~/workload-clusters/tmp.yaml
    printf "ENABLE_DEFAULT_STORAGE_CLASS: true\n" >> ~/workload-clusters/tmp.yaml

    printf "Generating\n"
    sleep 1
    mv ~/workload-clusters/tmp.yaml ~/workload-clusters/$CLUSTER_NAME.yaml;
    printf "==> DONE\n"
else
    printf "\n\nNo management cluster config file found.\n\nGENERATION OF TKG WORKLOAD CLUSTER CONFIG FILE FAILED\n\n"
fi