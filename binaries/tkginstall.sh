#!/bin/bash

unset TKG_ADMIN_EMAIL
unset MANAGEMENT_CLUSTER_CONFIG_FILE
unset COMPLETE
unset BASTION_HOST
unset BASTION_USERNAME

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


unset TKG_ADMIN_EMAIL

export $(cat /root/.env | xargs)


printf "\n***************************************************"
printf "\n********** Starting *******************************"
printf "\n***************************************************"



if [[ -z $COMPLETE || $COMPLETE == 'NO' ]]
then

    printf "\n\n\n"
    
    isexists=$(ls .ssh/tkg_rsa.pub)
    if [[ -z $isexists ]]
    then
        while [[ -z $TKG_ADMIN_EMAIL ]]; do
            printf "\nTKG_ADMIN_EMAIL not set in the .env file."
            printf "\n"
            if [[ $SILENTMODE == 'y' ]]
            then
                returnOrexit
            fi
            while true; do
                read -p "TKG_ADMIN_EMAIL: " inp
                if [ -z "$inp" ]
                then
                    printf "\nThis is required.\n"
                else 
                    TKG_ADMIN_EMAIL=$inp
                    break;
                fi
            done        
            printf "\nTKG_ADMIN_EMAIL=$TKG_ADMIN_EMAIL" >> /root/.env
            
            export $(cat /root/.env | xargs)
        done
        printf "\n\n\nexecuting ssh-keygen for email $TKG_ADMIN_EMAIL...\n"
        ssh-keygen -f ~/.ssh/tkg_rsa -t rsa -b 4096 -C "$TKG_ADMIN_EMAIL"
    else 
        isexists=$(ls .ssh/tkg_rsa)
        if [[ -z $isexists ]]
        then
            printf "\n\nERROR: found tkg_rsa.pub in the .ssh dir BUT did not find private key to add named tkg_rsa."
            printf "\n\tPlease remove the tkg_rsa.pub to re-create key pair OR provide private key tkg_rsa file"
            printf "\n\tQuiting..."
            returnOrexit
        fi
    fi

    if [[ -n $BASTION_HOST ]]
    then
        echo "=> Bastion host detected."

        # printf "\n\nPerforming ssh-add ~/.ssh/id_rsa ...\n"
        # eval `ssh-agent -s`
        # ssh-add /root/.ssh/id_rsa
        # printf "\nADDED.\n"

        source /root/binaries/bastionhostmanagementsetup.sh
    else
        printf "\n\n\n Here's your public key in ~/.ssh/id_rsa.pub:\n"
        cat ~/.ssh/tkg_rsa.pub

        if [[ -n $MANAGEMENT_CLUSTER_CONFIG_FILE ]]
        then
            printf "\nLaunching management cluster create using $MANAGEMENT_CLUSTER_CONFIG_FILE...\n"
            tanzu management-cluster create --file $MANAGEMENT_CLUSTER_CONFIG_FILE -v 9
        else
            printf "\nLaunching management cluster create using UI...\n"
            tanzu management-cluster create --ui -y -v 9 --browser none
        fi
    fi   


    # ISPINNIPED=$(kubectl get svc -n pinniped-supervisor | grep pinniped-supervisor)

    # if [[ ! -z "$ISPINNIPED" ]]
    # then
    #     printf "\n\n\nBelow is details of the service for the auth callback url. Update your OIDC/LDAP callback accordingly.\n"
    #     kubectl get svc -n pinniped-supervisor
    #     printf "\nDocumentation: https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.3/vmware-tanzu-kubernetes-grid-13/GUID-mgmt-clusters-configure-id-mgmt.html\n"
    # fi

    printf "\n\n\nDone. Marking as commplete.\n\n\n"
    sed -i '/COMPLETE/d' .env
    printf "\nCOMPLETE=YES" >> /root/.env
else
    printf "\n\n\n Already marked as complete in the .env. If this is not desired then remove the 'COMPLETE=yes' from the .env file.\n"
fi

printf "\n\n\nRUN ~/binaries/tkgworkloadwizard.sh --help to start creating workload clusters.\n\n\n"