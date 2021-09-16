#!/bin/bash

unset TKG_ADMIN_EMAIL

returnOrexit()
{
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
    then
        return
    else
        exit
    fi
}

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



    while [[ -n $BASTION_HOST && -z $NSX_ALB_ENDPOINT ]]; do
        printf "\nNSX_ALB_ENDPOINT not set in the .env file."
        printf "\nPlease add NSX_ALB_ENDPOINT={ip address} in the .env file"
        printf "\nReplace {ip address} with the ip address of the NSX ALB Contoller IP address"
        printf "\n"
        if [[ $SILENTMODE == 'y' ]]
        then
            returnOrexit
        fi
        isexists=$(cat /root/.env | grep -w NSX_ALB_ENDPOINT)
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

    if [[ -n $BASTION_HOST ]]
    then
        printf "\n\n\ncreating tunnel 4430:$NSX_ALB_ENDPOINT:443 $BASTION_USERNAME@$BASTION_HOST...\n"
        ssh -i /root/.ssh/id_rsa -4 -fNT -L 8443:$NSX_ALB_ENDPOINT:443 $BASTION_USERNAME@$BASTION_HOST
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

    printf "\n\n"
    if [[ -n $BASTION_HOST ]]
    then
        printf "\nSince you are using bastion host to connect to your private cluster, this docker environment is now configured with appropriate tunnels."
        printf "\nYou must use the below details in the wizard UI for management cluster provisioning...\n"
        echo -e "\tVCENTER SERVER: 127.0.0.1"
        echo -e "\tCONTROLLER HOST (for NSX ALB): 127.0.0.1:444"
    fi
    
    printf "\nLaunching management cluster create UI...\n"
    


    tanzu management-cluster create --ui -y -v 8 --browser none

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