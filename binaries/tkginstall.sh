#!/bin/bash

unset TKG_ADMIN_EMAIL

returnOrexit()
{
    echo '=> Terminating sshuttle process by signal (SIGINT, SIGTERM, SIGKILL, EXIT)'
    killall -9 sshuttle ssh
    iptables --flush
    sleep 2
    iptables --flush
    sleep 1
    echo "=> *DONE*"
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
    then
        return
    else
        exit
    fi
}

unset COMPLETE
unset BASTION_HOST
unset BASTION_USERNAME
unset VSPHERE_IP
unset VSPHERE_USERNAME
unset VSPHERE_PASSWORD
unset TKG_ADMIN_EMAIL
unset NSX_ALB_IP
unset NSX_ALB_DOMAIN_NAME

export $(cat /root/.env | xargs)



printf "\n***************************************************"
printf "\n********** Starting *******************************"
printf "\n***************************************************"



if [ -z "$COMPLETE" ]
then

    printf "\n\n\n"
    
    while [[ -z $TKG_ADMIN_EMAIL ]]; do
        printf "\nTKG_ADMIN_EMAIL not set in the .env file."
        printf "\nPlease add TKG_ADMIN_EMAIL={email} in the .env file"
        printf "\nReplace {email} with an appropriate value"
        printf "\n"
        if [[ $SILENTMODE == 'y' ]]
        then
            returnOrexit
        fi
        isexists=$(cat /root/.env | grep -w TKG_ADMIN_EMAIL)
        if [[ -z $isexists ]]
        then
            printf "\nTKG_ADMIN_EMAIL=" >> /root/.env
        fi
        while true; do
            read -p "Confirm to continue? [y/n] " yn
            case $yn in
                [Yy]* ) printf "\nyou confirmed yes\n"; break;;
                [Nn]* ) printf "\n\nYou said no. \n\nQuiting...\n\n"; returnOrexit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
        export $(cat /root/.env | xargs)
    done

    while [[ -n $BASTION_HOST && -z $VSPHERE_DOMAIN_NAME ]]; do
        printf "\nVSPHERE_DOMAIN_NAME not set in the .env file."
        printf "\nPlease add VSPHERE_DOMAIN_NAME={domain.name} in the .env file"
        printf "\nReplace {domain.name} with the domain name of the VSPHERE Contoller"
        printf "\n"
        if [[ $SILENTMODE == 'y' ]]
        then
            returnOrexit
        fi
        isexists=$(cat /root/.env | grep -w VSPHERE_DOMAIN_NAME)
        if [[ -z $isexists ]]
        then
            printf "\nVSPHERE_DOMAIN_NAME=" >> /root/.env
        fi
        while true; do
            read -p "Confirm to continue? [y/n] " yn
            case $yn in
                [Yy]* ) printf "\nyou confirmed yes\n"; break;;
                [Nn]* ) printf "\n\nYou said no. \n\nQuiting...\n\n"; returnOrexit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
        export $(cat /root/.env | xargs)
    done

    while [[ -n $BASTION_HOST && -z $NSX_ALB_IP ]]; do
        printf "\nNSX_ALB_ENDPOINT not set in the .env file."
        printf "\nPlease add NSX_ALB_IP={ip address} in the .env file"
        printf "\nReplace {ip address} with the ip address of the NSX ALB Contoller IP address"
        printf "\n"
        if [[ $SILENTMODE == 'y' ]]
        then
            returnOrexit
        fi
        isexists=$(cat /root/.env | grep -w NSX_ALB_IP)
        if [[ -z $isexists ]]
        then
            printf "\nNSX_ALB_ENDPOINT=" >> /root/.env
        fi
        while true; do
            read -p "Confirm to continue? [y/n] " yn
            case $yn in
                [Yy]* ) printf "\nyou confirmed yes\n"; break;;
                [Nn]* ) printf "\n\nYou said no. \n\nQuiting...\n\n"; returnOrexit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
        export $(cat /root/.env | xargs)
    done

    while [[ -n $BASTION_HOST && -z $NSX_ALB_DOMAIN_NAME ]]; do
        printf "\nNSX_ALB_DOMAIN_NAME not set in the .env file."
        printf "\nPlease add NSX_ALB_DOMAIN_NAME={your.nsxalb.domain.name} in the .env file"
        printf "\nReplace {your.nsxalb.domain.name} with the domain name of the NSX ALB Contoller"
        printf "\n"
        if [[ $SILENTMODE == 'y' ]]
        then
            returnOrexit
        fi
        isexists=$(cat /root/.env | grep -w NSX_ALB_DOMAIN_NAME)
        if [[ -z $isexists ]]
        then
            printf "\nNSX_ALB_DOMAIN_NAME=" >> /root/.env
        fi
        while true; do
            read -p "Confirm to continue? [y/n] " yn
            case $yn in
                [Yy]* ) printf "\nyou confirmed yes\n"; break;;
                [Nn]* ) printf "\n\nYou said no. \n\nQuiting...\n\n"; returnOrexit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
        export $(cat /root/.env | xargs)
    done


    while [[ -n $BASTION_HOST && -z $K8S_VIP_SUBNET ]]; do
        printf "\nK8S_VIP_SUBNET not set in the .env file."
        printf "\nPlease add K8S_VIP_SUBNET={ip subnet} in the .env file"
        printf "\nReplace {ip subnet} with the ip subnet configured for k8s front end network in AVI"
        printf "\n"
        if [[ $SILENTMODE == 'y' ]]
        then
            returnOrexit
        fi
        isexists=$(cat /root/.env | grep -w K8S_VIP_SUBNET)
        if [[ -z $isexists ]]
        then
            printf "\nK8S_VIP_SUBNET=" >> /root/.env
        fi
        while true; do
            read -p "Confirm to continue? [y/n] " yn
            case $yn in
                [Yy]* ) printf "\nyou confirmed yes\n"; break;;
                [Nn]* ) printf "\n\nYou said no. \n\nQuiting...\n\n"; returnOrexit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
        export $(cat /root/.env | xargs)
    done


    if [[ -n $BASTION_HOST ]]
    then
        echo "=> Bastion host detected."

        chmod 0600 /root/.ssh/*
        cp /root/.ssh/sshuttleconfig /root/.ssh/ssh_config
        mv /etc/ssh/ssh_config /etc/ssh/ssh_config-default
        ln -s /root/ssh/ssh_config /etc/ssh/ssh_config

        printf "\n\n\n"
        echo "=> Establishing sshuttle with remote $BASTION_USERNAME@$BASTION_HOST...."
        
        DOCKER_IP=$(ip -o -f inet addr show | awk '/scope global/ {print $2,$4}' | grep docker | awk '{print $2}')
        echo "=> DOCKER_IP=$DOCKER_IP"
        if [[ -n $DOCKER_IP ]]
        then
            EXCLUDE_DOCKER_IP="-x $DOCKER_IP"
        else
            EXCLUDE_DOCKER_IP=''
        fi
        
        NSX_ALB_SUBNET_IP=$(echo $NSX_ALB_IP | awk -F"." '{print $1"."$2"."$3".0"}')
        NSX_ALB_SUBNET=$NSX_ALB_SUBNET_IP/24

        DNS_SERVER_SUBNET=''
        DNS_SERVER_SUBNET_IP=$(echo $DNS_SERVER_ENDPOINT | awk -F"." '{print $1"."$2"."$3".0"}')
        if [[ $DNS_SERVER_SUBNET_IP != $NSX_ALB_SUBNET_IP ]]
        then
            DNS_SERVER_SUBNET=$DNS_SERVER_SUBNET_IP/24
        fi

        VSPHERE_SUBNET_IP=$(echo $VSPHERE_IP | awk -F"." '{print $1"."$2"."$3".0"}')
        if [[ $VSPHERE_SUBNET_IP != $NSX_ALB_SUBNET_IP && $VSPHERE_SUBNET_IP != $DNS_SERVER_SUBNET_IP ]]
        then
            VSPHERE_SUBNET_IP=$VSPHERE_SUBNET/24
        fi
        

        sshuttle --dns --python python2 -D -r $BASTION_USERNAME@$BASTION_HOST $K8S_VIP_SUBNET $NSX_ALB_SUBNET $DNS_SERVER_SUBNET $VSPHERE_SUBNET --disable-ipv6 -x 127.0.0.1/24 $EXCLUDE_DOCKER_IP -v
        
        sleep 3

        while true; do
            read -p "Confirm to continue? [y/n] " yn
            case $yn in
                [Yy]* ) printf "\nyou confirmed yes\n"; break;;
                [Nn]* ) printf "\n\nYou said no. \n\nQuiting...\n\n"; returnOrexit;;
                * ) echo "Please answer yes or no.";;
            esac
        done

        printf "\nLaunching CoreDNS adjust...\n"
        cd /root/binaries
        ./adjustdns.sh &
        cd ~

        printf "\n=> DONE."

        printf "\n\n\n"
    fi


    


    isexists=$(ls .ssh/tkg_rsa.pub)
    if [[ -z $isexists ]]
    then
        printf "\n\n\nexecuting ssh-keygen for email $TKG_ADMIN_EMAIL...\n"
        ssh-keygen -f ~/.ssh/tkg_rsa -t rsa -b 4096 -C "$TKG_ADMIN_EMAIL"
        ssh-add ~/.ssh/tkg_rsa
    fi
    

    printf "\n\n\n Here's your public key in ~/.ssh/tkg_rsa.pub:\n"
    cat ~/.ssh/tkg_rsa.pub   

    if [[ -n $MANAGEMENT_CLUSTER_CONFIG_FILE ]]
    then
        printf "\nLaunching management cluster create using $MANAGEMENT_CLUSTER_CONFIG_FILE...\n"
        tanzu management-cluster create --file $MANAGEMENT_CLUSTER_CONFIG_FILE -v 9
    else
        printf "\nLaunching management cluster create using UI...\n"
        tanzu management-cluster create --ui -y -v 9 --browser none
    fi
    
    # --bind 100.64.0.2:8080

    ISPINNIPED=$(kubectl get svc -n pinniped-supervisor | grep pinniped-supervisor)

    if [[ ! -z "$ISPINNIPED" ]]
    then
        printf "\n\n\nBelow is details of the service for the auth callback url. Update your OIDC/LDAP callback accordingly.\n"
        kubectl get svc -n pinniped-supervisor
        printf "\nDocumentation: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-mgmt-clusters-configure-id-mgmt.html\n"
    fi

    printf "\n\n\nDone. Marking as commplete.\n\n\n"
    printf "\nCOMPLETE=YES" >> /root/.env
else
    printf "\n\n\n Already marked as complete in the .env. If this is not desired then remove the 'COMPLETE=yes' from the .env file.\n"
fi

printf "\n\n\nRUN ~/binaries/tkgworkloadwizard.sh --help to start creating workload clusters.\n\n\n"