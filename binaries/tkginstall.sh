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

unset COMPLETE
unset BASTION_HOST
unset BASTION_USERNAME
unset VSPHERE_ENDPOINT
unset VSPHERE_USERNAME
unset VSPHERE_PASSWORD
unset TKG_ADMIN_EMAIL
unset NSX_ALB_ENDPOINT
unset CONTROL_PLANE_ENDPOINT


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


    while [[ -n $BASTION_HOST && -z $CONTROL_PLANE_ENDPOINT ]]; do
        printf "\nSince we're tunneling here we need to create a tunnel for 6443 to connect to CONTROL_PLANE_ENDPOINT."
        printf "\nCONTROL_PLANE_ENDPOINT not set in the .env file."
        printf "\nPlease add CONTROL_PLANE_ENDPOINT={ip address} in the .env file"
        printf "\nReplace {ip address} with the ip address of the CONTROL PLANE IP address of the management cluster"
        printf "\n"
        if [[ $SILENTMODE == 'y' ]]
        then
            returnOrexit
        fi
        isexists=$(cat /root/.env | grep -w CONTROL_PLANE_ENDPOINT)
        if [[ -z $isexists ]]
        then
            printf "\nCONTROL_PLANE_ENDPOINT=" >> /root/.env
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
        # printf "\n\n\nAdding nameserver..."
        # isexist=$(cat /etc/resolv.conf | grep '^nameserver 127.0.0.1$')
        # if [[ -z $isexist ]]
        # then
        #     # sed -i '/^nameserver.*/i nameserver 127.0.0.1' /etc/resolv.conf
        #     printf "nameserver 127.0.0.1" >> /etc/resolvconf/resolv.conf.d/head
        # fi
        # printf "\nDONE."

        fuser -k 443/tcp
        sleep 1
        printf "\n\n\ncreating tunnel 8443:$NSX_ALB_ENDPOINT:443 $BASTION_USERNAME@$BASTION_HOST...\n"
        ssh -i /root/.ssh/id_rsa -4 -fNT -L 8443:$NSX_ALB_ENDPOINT:443 $BASTION_USERNAME@$BASTION_HOST
        printf "DONE."
        printf "\n\n\ncreating tunnel 9443:$VSPHERE_ENDPOINT:443 $BASTION_USERNAME@$BASTION_HOST...\n"
        ssh -i /root/.ssh/id_rsa -4 -fNT -L 9443:$VSPHERE_ENDPOINT:443 $BASTION_USERNAME@$BASTION_HOST
        printf "\nDONE."
        printf "\n\n\ncreating tunnel 6443:$CONTROL_PLANE_ENDPOINT:6443 $BASTION_USERNAME@$BASTION_HOST...\n"
        ssh -i /root/.ssh/id_rsa -4 -fNT -L 6443:$CONTROL_PLANE_ENDPOINT:6443 $BASTION_USERNAME@$BASTION_HOST
        printf "\nDONE."
        # printf "\n\n\ncreating tunnel 53:$DNS_SERVER_ENDPOINT:53 $BASTION_USERNAME@$BASTION_HOST...\n"
        # ssh -i /root/.ssh/id_rsa -4 -fNT -L 53:$DNS_SERVER_ENDPOINT:53 $BASTION_USERNAME@$BASTION_HOST
        # printf "\nDONE."

        isexist=$(cat /etc/hosts | grep "vsphere.local$")
        if [[ -z $isexist ]]
        then
            printf "\nMapping to vsphere.local..."
            printf "\n127.0.0.1       vsphere.local" >> /etc/hosts
        fi

        isexist=$(cat /etc/hosts | grep "nsxalb.local$")
        if [[ -z $isexist ]]
        then
            printf "\nMapping to nsxalb.local..."
            printf "\n127.0.0.1     nsxalb.local" >> /etc/hosts
        fi

        isexist=$(cat /etc/hosts | grep "kubevip.local$")
        if [[ -z $isexist ]]
        then
            printf "\n127.0.0.1     kubevip.local" >> /etc/hosts
        fi
        
        printf "\nremoving default...\n"
        rm /etc/nginx/sites-available/default
        rm /etc/nginx/sites-enabled/default
        sleep 1

        printf "\nAdding custom default...\n"
        cp ~/binaries/dns/default /etc/nginx/sites-available/
        chmod 755 /etc/nginx/sites-available/default
        ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/
        sleep 1

        printf "\nAdding others...\n"
        cp ~/binaries/dns/nsxalb.local /etc/nginx/sites-available/
        chmod 755 /etc/nginx/sites-available/nsxalb.local
        cp ~/binaries/dns/vsphere.local /etc/nginx/sites-available/
        chmod 755 /etc/nginx/sites-available/vsphere.local
        cp ~/binaries/dns/kubevip.local /etc/nginx/sites-available/
        chmod 755 /etc/nginx/sites-available/kubevip.local
        ln -s /etc/nginx/sites-available/nsxalb.local /etc/nginx/sites-enabled/
        ln -s /etc/nginx/sites-available/vsphere.local /etc/nginx/sites-enabled/
        ln -s /etc/nginx/sites-available/kubevip.local /etc/nginx/sites-enabled/
        sleep 1
        cp ~/binaries/dns/cert.key /etc/nginx/
        cp ~/binaries/dns/cert.crt /etc/nginx/
        sleep 1
        chmod 755 /etc/nginx/cert.key
        chmod 755 /etc/nginx/cert.crt
        sleep 1
        service nginx start
        sleep 2
        # ssh -i /root/.ssh/id_rsa -4 -fNT -L 6443:$NSX_ALB_ENDPOINT:6443 $BASTION_USERNAME@$BASTION_HOST
    fi


    # while true; do
    #     read -p "Confirm to continue? [y/n] " yn
    #     case $yn in
    #         [Yy]* ) printf "\nyou confirmed yes\n"; break;;
    #         [Nn]* ) printf "\n\nYou said no. \n\nQuiting...\n\n"; returnOrexit;;
    #         * ) echo "Please answer yes or no.";;
    #     esac
    # done


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
        echo -e "\tVCENTER SERVER: vsphere.local"
        # echo -e "\tCONTROL PLANE ENDPOINT (for NSX ALB): kubevip.local"
        echo -e "\tNSX ALB CONTROLLER HOST (for NSX ALB): nsxalb.local"
    fi
    
    printf "\nLaunching management cluster create UI...\n"
    


    tanzu management-cluster create --ui -y -v 9 --browser none 
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