#!/bin/bash
install_tanzu_plugin()
{
    printf "\nChecking tanzu unpacked...\n\n"
    isexists=$(ls /tmp/tanzu | grep -w "cli$")
    if [[ -z $isexists ]]
    then
        printf "\nChecking tanzu cli bundle in ~/binaries...\n"
        isexists=$(ls ~/binaries | grep -w "tanzu-cli-bundle-linux-amd64.tar$")
        if [[ -z $isexists ]]
        then
            printf "\nError: Bundle ~/binaries/tanzu-cli-bundle-linux-amd64.tar not found. Exiting..\n"
            exit
        fi
        printf "\nUnpacking...\n"
        cp ~/binaries/tanzu-cli-bundle-linux-amd64.tar /tmp
        cd /tmp 
        mkdir tanzu
        tar -xvf tanzu-cli-bundle-linux-amd64.tar -C tanzu/
        cd ~
    fi
    cd ~
    tanzu plugin install --local /tmp/tanzu/cli all
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


function bastion_host_tunnel {
    # $1=endpoint url or kubeconfig file
    if [[ -n $BASTION_HOST ]]
    then
        printf "\nBastion host detected."
        printf "\nExtracting server info from kubeconfig...\n"
        sleep 1
        isurl=$(echo $1 | grep -io 'http[s]*://[^"]*')
        if [[ -z $isurl ]]
        then
            kubeconfigfile=$1
            if [[ -z $MANAGEMENT_CLUSTER_ENDPOINT ]]
            then
                serverurl=$(awk '/server/ {print $NF;exit}' $kubeconfigfile | awk -F/ '{print $3}' | awk -F: '{print $1}')
                port=$(awk '/server/ {print $NF;exit}' $kubeconfigfile | awk -F/ '{print $3}' | awk -F: '{print $2}')
            else
                proto="$(echo $MANAGEMENT_CLUSTER_ENDPOINT | grep :// | sed -e's,^\(.*://\).*,\1,g')"
                serverurl="$(echo ${MANAGEMENT_CLUSTER_ENDPOINT/$proto/} | cut -d/ -f1)"
                port="$(echo $serverurl | awk -F: '{print $2}')"
                serverurl="$(echo $serverurl | awk -F: '{print $1}')"
                if [[ $serverurl == 'kubernetes' ]]
                then
                    printf "\nERROR: found MANAGEMENT_CLUSTER_ENDPOINT=$MANAGEMENT_CLUSTER_ENDPOINT. $serverurl is not allowed here.exiting...\n"
                    exit 1
                fi
            fi
            if [[ -z $port ]]
            then
                if [[ -z $proto || $proto == 'http://' ]]
                then
                    port=80
                else 
                    port=443
                fi                    
            fi
            if [[ -n $serverurl && -n $port ]]
            then
                printf "server url: $serverurl\nport: $port\n"
                sleep 1
                printf "\nCreating endpoint Tunnel through bastion $BASTION_USERNAME@$BASTION_HOST ...\n"
                sleep 1
                ssh -i /root/.ssh/id_rsa -4 -fNT -L $port:$serverurl:$port $BASTION_USERNAME@$BASTION_HOST
                ssh -i /root/.ssh/id_rsa -4 -fNT -L 443:$serverurl:443 $BASTION_USERNAME@$BASTION_HOST
                sleep 1
                printf "\n=>Tunnel created.\n"
                if [[ -z $MANAGEMENT_CLUSTER_ENDPOINT ]]
                then
                    printf "\nAdjusting kubeconfig for tunneling...\n"
                    sed -i '0,/'$serverurl'/s//kubernetes/' $kubeconfigfile
                    sleep 1
                    printf "\nMANAGEMENT_CLUSTER_ENDPOINT=$serverurl:$port" >> /root/.env
                fi
            else
                printf "ERROR: Bastion host specified but error in extracting server and port. Exiting..."
                exit 1;
            fi
        else
            if [[ $TUNNEL_AUTH_ENDPOINT_THROUGH_BASTION == 'YES' ]]
            then
                proto="$(echo $1 | grep :// | sed -e's,^\(.*://\).*,\1,g')"
                # remove the protocol
                url="$(echo ${1/$proto/})"
                host="$(echo ${url} | cut -d/ -f1)"
                port="$(echo $host | awk -F: '{print $2}')"
                host="$(echo $host | awk -F: '{print $1}')"
                if [[ -z $port ]]
                then
                    if [[ -z $proto || $proto == 'http://' ]]
                    then
                        port=80
                    else 
                        port=443
                    fi                    
                fi
                printf "\nendpoint url: \n\tproto: $proto\n\thost: $host\n\tport: $port\n"
                sleep 1
                printf "\nCreating endpoint Tunnel through bastion $BASTION_USERNAME@$BASTION_HOST ...\n"
                sleep 1
                ssh -i /root/.ssh/id_rsa -4 -fNT -L $port:$host:$port $BASTION_USERNAME@$BASTION_HOST
                printf "\n=>Tunnel created.\n"
            fi
        fi
    fi
}

printf "\n\nsetting executable permssion to all binaries sh\n\n"
ls -l /root/binaries/*.sh | awk '{print $9}' | xargs chmod +x

chmod 600 /root/.ssh/id_rsa

printf "\n\nChecking TMC ..."
ISTMCEXISTS=$(tmc --help)
sleep 1
if [ -z "$ISTMCEXISTS" ]
then
    printf "\ntmc command does not exist."
    printf "\nChecking for binary presence..."
    IS_TMC_BINARY_EXISTS=$(ls ~/binaries/ | grep tmc)
    sleep 2
    if [ -z "$IS_TMC_BINARY_EXISTS" ]
    then
        printf "\nBinary does not exist in ~/binaries directory."
        printf "\nIf you would like to attach the newly created TKG clusters to TMC then please download tmc binary from https://{orgname}.tmc.cloud.vmware.com/clidownload and place in the ~/binaries directory."
        printf "\nAfter you have placed the binary file you can, additionally, uncomment the tmc relevant lines in the Dockerfile.\n\n"
    else
        printf "\nTMC binary found..."
        printf "\nAdjusting Dockerfile"
        sed -i '/COPY binaries\/tmc \/usr\/local\/bin\//s/^# //' ~/Dockerfile
        sed -i '/RUN chmod +x \/usr\/local\/bin\/tmc/s/^# //' ~/Dockerfile
        sleep 2
        printf "\nDONE..\n"
        printf "\n\nPlease build this docker container again and run.\n"
        exit 1
    fi
else
    printf "\n\ntmc command found.\n\n"
fi

printf "\nChecking Tanzu plugin...\n"

ISINSTALLED=$(tanzu management-cluster --help)
if [[ $ISINSTALLED == *@("unknown"|"does not exist")* ]]
then
    printf "\n\ntanzu plugin management-cluster not found. installing...\n\n"
    install_tanzu_plugin
    printf "\n\n"
fi

ISINSTALLED=$(tanzu cluster --help)
if [[ $ISINSTALLED == *@("unknown"|"does not exist")* ]]
then
    printf "\n\ntanzu plugin cluster not found. installing...\n"
    install_tanzu_plugin
    printf "\n\n"
fi

ISINSTALLED=$(tanzu login --help)
if [[ $ISINSTALLED == *@("unknown"|"does not exist")* ]]
then
    printf "\n\ntanzu plugin login not found. installing...\n"
    install_tanzu_plugin
    printf "\n\n"
fi

ISINSTALLED=$(tanzu kubernetes-release --help)
if [[ $ISINSTALLED == *@("unknown"|"does not exist")* ]]
then
    printf "\n\ntanzu plugin kubernetes-release not found. installing...\n"
    install_tanzu_plugin
    printf "\n\n"
fi

ISINSTALLED=$(tanzu pinniped-auth --help)
if [[ $ISINSTALLED == *@("unknown"|"does not exist")* ]]
then
    printf "\n\ntanzu plugin pinniped-auth not found. installing...\n"
    install_tanzu_plugin
    printf "\n\n"
fi

tanzu plugin list

while true; do
    read -p "Confirm if plugins are installed? [y/n] " yn
    case $yn in
        [Yy]* ) printf "\nyou confirmed yes\n"; break;;
        [Nn]* ) printf "\n\nYou said no. \n\nExiting...\n\n"; exit;;
        * ) echo "Please answer yes or no.";;
    esac
done


export $(cat /root/.env | xargs)

# vsphereHost=$VSPHERE_IP

# if [[ -n $BASTION_HOST ]]
# then
#     printf "\ncreating tunnel...\n"
#     ssh -i /root/.ssh/id_rsa -4 -fNT -L 443:$VSPHERE_IP:443 $BASTION_USERNAME@$BASTION_HOST
#     # ssh -i /root/.ssh/id_rsa -4 -fNT -L 6443:$VSPHERE_IP:6443 $BASTION_USERNAME@$BASTION_HOST
#     vsphereHost=127.0.0.1
# fi
# printf "\n\n\nChecking access to vsphere environment...\n"

# AUTH=$(echo -ne "$VSPHERE_USERNAME:$VSPHERE_PASSWORD" | base64 --wrap 0)

# test=$(curl --insecure --header "Content-Type: application/json" --header "Authorization: Basic $AUTH" --request POST https://$vsphereHost/rest/com/vmware/cis/session)
# test=$(echo $test | jq -c '.value' | tr -d '"')
# echo $test
# if [ -z "$test" ]
# then
#     printf "\n\n\nFailed access check to $VSPHERE_IP for user $VSPHERE_USERNAME.\nFix .env variables and try again.\nExit...\n"
#     exit 1
# else
#     printf "\nAccess Confirmed.\n"
#     fuser -k 443/tcp
# fi

if [[ $COMPLETE == 'YES' ]]
then
    isloggedin='n'
    printf "\nFound marked as complete.\nChecking tanzu config...\n"
    sleep 1
    tanzucontext=$(tanzu config server list -o json | jq '.[].context' | xargs)
    if [[ -n $tanzucontext ]]
    then
        tanzuname=$(tanzu config server list -o json | jq '.[].name' | xargs)
        if [[ -n $tanzuname ]]
        then
            tanzupath=$(tanzu config server list -o json | jq '.[].path' | xargs)
            tanzuendpoint=$(tanzu config server list -o json | jq '.[].endpoint' | xargs)
            if [[ -n $tanzupath ]]
            then
                bastion_host_tunnel $tanzupath
                printf "\nFound \n\tcontext: $tanzucontext \n\tname: $tanzuname \n\tpath: $tanzupath\n.Performing Tanzu login..."
                sleep 1
                tanzu login --kubeconfig $tanzupath --context $tanzucontext --name $tanzuname
                isloggedin='y'
            fi
            if [[ -n $tanzuendpoint ]]
            then
                printf "\nFound \n\tcontext: $tanzucontext \n\tname: $tanzuname \n\tendpoint: $tanzuendpoint\n.Performing Tanzu login..."
                sleep 1
                tanzu login --endpoint $tanzuendpoint --context $tanzucontext --name $tanzuname
                isloggedin='y'
            fi
        fi
    fi

    if [[ $isloggedin == 'n' ]]
    then
        printf "\nTanzu context does not exist. Creating new one...\n"
        sleep 1
        if [[ -z $AUTH_ENPOINT ]]
        then
            printf "\nNO AUTH_ENDPOINT given.\nLooking for kubeconfig...\n"
            sleep 1
            kubeconfigfile=/root/.kube-tkg/config
            isexist=$(ls $kubeconfigfile)
            if [[ -z $isexist ]]
            then
                printf "\nERROR: kubeconfig not found in $kubeconfigfile\nExiting...\n"
                exit 1
            fi
            filename=$(ls -1tc ~/.config/tanzu/tkg/clusterconfigs/ | head -1)
            if [[ -z $filename ]]
            then
                printf "\nERROR: Management cluster config file not found in ~/.config/tanzu/tkg/clusterconfigs/. Exiting...\n"
                exit 1
            fi
            clustername=$(cat ~/.config/tanzu/tkg/clusterconfigs/$filename | awk -F: '$1=="CLUSTER_NAME"{print $2}' | xargs)
            if [[ -z $clustername ]]
            then
                printf "\nERROR: CLUSTER_NAME could not be extracted. Please check file ~/.config/tanzu/tkg/clusterconfigs/$filename. Exiting...\n"
                exit 1
            fi            
            contextname=$(parse_yaml $kubeconfigfile | grep "\@$clustername" | awk -F= '$1=="contexts_name"{print $2}' | xargs)    
            printf "\nfound \n\tCLUSTER_NAME: $clustername\n\tCONTEXT_NAME: $contextname\n"
            sleep 1
            bastion_host_tunnel $kubeconfigfile
            printf "\ntanzu login --kubeconfig $kubeconfigfile --context $contextname --name $clustername ...\n"
            tanzu login --kubeconfig $kubeconfigfile --context $contextname --name $clustername
        else
            printf "\ntanzu login --endpoint $AUTH_ENDPOINT --name $clustername ...\n"
            tanzu login --endpoint $AUTH_ENDPOINT --name $clustername
        fi
    fi
        
fi

printf "\ntanzu connected to below ...\n"
sleep 1
tanzu cluster list --include-management-cluster

printf "\nIs this correct? ...\n"
sleep 1
while true; do
    read -p "Confirm to continue? [y/n] " yn
    case $yn in
        [Yy]* ) printf "\nyou confirmed yes\n"; break;;
        [Nn]* ) printf "\n\nYou said no. \n\nExiting...\n\n"; exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

printf "\nYour available wizards are:\n"
sleep 1
echo -e "\t~/binaries/tkginstall.sh"
echo -e "\t~/binaries/tkgworkloadwizard.sh --help"
echo -e "\t~/binaries/attach_to_tmc.sh --help"

cd ~

/bin/bash