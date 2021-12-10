#!/bin/bash

install_tanzu_plugin()
{
    tanzubundlename=''
    printf "\nChecking tanzu bundle...\n\n"
    cd /tmp
    sleep 1
    numberoftarfound=$(find ./*tar* -type f -printf "." | wc -c)
    if [[ $numberoftarfound == 1 ]]
    then
        tanzubundlename=$(find ./*tar* -printf "%f\n")
    fi
    if [[ $numberoftarfound -gt 1 ]]
    then
        printf "\nfound more than 1 bundles..\n"
        find ./*tar* -printf "%f\n"
        printf "Error: only 1 tar file is allowed in ~/binaries dir.\n"
        printf "\n\n"
        exit 1
    fi

    if [[ $numberoftarfound -lt 1 ]]
    then
        printf "\nNo tanzu bundle found. Please place the tanzu bindle in ~/binaries and rebuild again. Exiting...\n"
        exit 1
    fi
    printf "\nTanzu Bundle: $tanzubundlename. Installing..."
    # sleep 1
    # mkdir tanzu
    # tar -xvf $tanzubundlename -C tanzu/

    if [[ $tanzubundlename == "tce"* ]]
    then
        cd /tmp/tanzu/
        tcefolder=$(ls | grep tce)
        cd $tcefolder
        export ALLOW_INSTALL_AS_ROOT=true
        ./install.sh
    else
        cd /tmp/tanzu/cli/core
        versionfolder=$(ls | grep v)
        cd $versionfolder
        install core/$versionfolder/tanzu-core-linux_amd64 /usr/local/bin/tanzu
        tanzu plugin install --local /tmp/tanzu/cli all
    fi
}


printf "\n\nsetting executable permssion to all binaries sh\n\n"
ls -l /root/binaries/*.sh | awk '{print $9}' | xargs chmod +x

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

cd ~
printf "\nChecking Tanzu if plugins are installed ...\n"
ISINSTALLED=$(find ~/.local/share/tanzu-cli/* -printf '%f\n' | grep management-cluster)
if [[ -z $ISINSTALLED ]]
then
    printf "\n\ntanzu plugin management-cluster not found. installing...\n\n"
    install_tanzu_plugin
    printf "\n\n"
fi


ISINSTALLED=$(find ~/.local/share/tanzu-cli/* -printf '%f\n' | grep "tanzu-plugin-cluster$")
if [[ -z $ISINSTALLED ]]
then
    printf "\n\ntanzu plugin cluster not found. installing...\n"
    install_tanzu_plugin
    printf "\n\n"
fi

ISINSTALLED=$(find ~/.local/share/tanzu-cli/* -printf '%f\n' | grep "login$")
if [[ -z $ISINSTALLED ]]
then
    printf "\n\ntanzu plugin login not found. installing...\n"
    install_tanzu_plugin
    printf "\n\n"
fi

ISINSTALLED=$(find ~/.local/share/tanzu-cli/* -printf '%f\n' | grep "kubernetes-release$")
if [[ -z $ISINSTALLED ]]
then
    printf "\n\ntanzu plugin kubernetes-release not found. installing...\n"
    install_tanzu_plugin
    printf "\n\n"
fi

ISINSTALLED=$(find ~/.local/share/tanzu-cli/* -printf '%f\n' | grep "pinniped-auth$")
if [[ $ISINSTALLED == *@("unknown"|"does not exist")* || -z $ISINSTALLED ]]
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

rm /tmp/TANZU_CONNECT >> /dev/null

cd ~
source ~/binaries/tanzu_connect_management.sh

printf "\n\n\nYour available wizards are:\n"
echo -e "\t~/binaries/tkginstall.sh --help"
echo -e "\t~/binaries/tkgworkloadwizard.sh --help"
echo -e "\t~/binaries/tkgconnect.sh --help"

cd ~

/bin/bash
















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