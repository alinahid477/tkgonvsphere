#!/bin/bash
export $(cat /root/.env | xargs)

returnOrexit()
{
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
    then
        return
    else
        exit
    fi
}


configfile=$1

if [[ -z $configfile ]]
then
    printf "\nERROR: No config file argument passed to bastion host subprocess..."
    exit
fi


isexist=$(ls ~/.ssh/id_rsa)
if [[ -z $isexist ]]
then
    printf "\nERROR: Failed. id_rsa file must exist in .ssh directory..."
    printf "\nPlease ensure to place id_rsa file in .ssh directory and the id_rsa.pub in .ssh of $BASTION_USERNAME@$BASTION_HOST"
    exit
fi

if [[ -z $MANAGEMENT_CLUSTER_ENDPOINT ]]
then
    printf "\nERROR: bastion host detected BUT MANAGEMENT_CLUSTER_ENDPOINT is missing from .env file..."
    printf "\nPlease add MANAGEMENT_CLUSTER_ENDPOINT in the .env file and try again..."
    exit 1
fi

printf "\nChecking Docker on $BASTION_USERNAME@$BASTION_HOST...\n"
isexist=$(ssh -i .ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'docker --version')
if [[ -z $isexist ]]
then
    printf "\nERROR: Failed. Docker not installed on bastion host..."
    printf "\nPlease install docker on host $BASTION_HOST to continue..."
    exit 1
else
    printf "\nDocker found: $isexist"
fi

printf "\nPreparing $BASTION_USERNAME@$BASTION_HOST for merlin\n"
isexist=$(ssh -i ~/.ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'ls -l merlin/tkgonvsphere/workload-clusters')
if [[ -z $isexist ]]
then
    printf "\nCreating directory 'merlin/tkgonvsphere/workload-clusters' in $BASTION_USERNAME@$BASTION_HOST home dir"
    ssh -i .ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'mkdir -p merlin/tkgonvsphere/workload-clusters; mkdir -p merlin/tkgonvsphere/.config/tanzu; mkdir -p merlin/tkgonvsphere/.kube-tkg; mkdir -p merlin/tkgonvsphere/.kube; mkdir -p merlin/tkgonvsphere/binaries; mkdir -p merlin/tkgonvsphere/.ssh'
fi

printf "\nGetting remote files list from $BASTION_USERNAME@$BASTION_HOST\n"
ssh -i .ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'ls ~/merlin/tkgonvsphere/binaries/' > /tmp/bastionhostbinaries.txt
ssh -i .ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'ls ~/merlin/tkgonvsphere/' > /tmp/bastionhosthomefiles.txt
ssh -i .ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'ls ~/merlin/tkgonvsphere/.ssh/' >> /tmp/bastionhosthomefiles.txt
ssh -i .ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'ls ~/merlin/tkgonvsphere/.config/tanzu/' >> /tmp/bastionhosthomefiles.txt
ssh -i .ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'ls ~/merlin/tkgonvsphere/.kube-tkg/' >> /tmp/bastionhosthomefiles.txt


tanzubundlename=''
printf "\nChecking tanzu bundle...\n\n"
sleep 1
numberoftarfound=$(find ~/binaries/*.tar* -type f -printf "." | wc -c)
if [[ $numberoftarfound -lt 1 ]]
then
    printf "\nNo tanzu bundle found. Please place the tanzu bindle in ~/binaries and rebuild again. Exiting...\n"
    exit 1
fi
if [[ $numberoftarfound == 1 ]]
then
    tanzubundlename=$(find ~/binaries/*.tar* -printf "%f\n")
    printf "\n\nTanzu Bundle: $tanzubundlename.\n\n"
else
    printf "\n\nError: Found more than 1 tar file. Please ensure only 1 tanzu tar file exists in binaries directory.\n\n"
    exit 1
fi

cd ~

printf "\nUploading $configfile\n"
scp $configfile $BASTION_USERNAME@$BASTION_HOST:~/merlin/tkgonvsphere/workload-clusters/

printf "\nChecking remote ~/merlin/tkgonvsphere/.config/tanzu/config.yaml..."
isexist=$(cat /tmp/bastionhosthomefiles.txt | grep -w "config.yaml$")
if [[ -z $isexist ]]
then
    printf "\nUploading .config/tanzu/config.yaml\n"
    scp ~/.config/tanzu/config.yaml $BASTION_USERNAME@$BASTION_HOST:~/merlin/tkgonvsphere/.config/tanzu/
fi

printf "\nChecking remote ~/merlin/tkgonvsphere/.kube-tkg/config..."
isexist=$(cat /tmp/bastionhosthomefiles.txt | grep -w "config$")
if [[ -z $isexist ]]
then
    isexist=$(ls ~/.kube-tkg/config.remote)
    if [[ -z $isexist ]]
    then
        printf "\nAdjusting ~/.kube-tkg/config for remote..."
        proto="$(echo $MANAGEMENT_CLUSTER_ENDPOINT | grep :// | sed -e's,^\(.*://\).*,\1,g')"
        serverurl="$(echo ${MANAGEMENT_CLUSTER_ENDPOINT/$proto/} | cut -d/ -f1)"
        port="$(echo $serverurl | awk -F: '{print $2}')"
        serverurl="$(echo $serverurl | awk -F: '{print $1}')"
        cp ~/.kube-tkg/config ~/.kube-tkg/config.remote
        sed -i '0,/kubernetes/s//'$serverurl'/' ~/.kube-tkg/config.remote
    fi
    
    printf "\nUploading .kube-tkg/config and .kube/config\n"
    scp ~/.kube-tkg/config.remote $BASTION_USERNAME@$BASTION_HOST:~/merlin/tkgonvsphere/.kube-tkg/config
    scp ~/.kube-tkg/config.remote $BASTION_USERNAME@$BASTION_HOST:~/merlin/tkgonvsphere/.kube/config
fi

printf "\nChecking remote ~/merlin/tkgonvsphere/binaries/$tanzubundlename..."
isexist=$(cat /tmp/bastionhostbinaries.txt | grep -w $tanzubundlename)
if [[ -z $isexist ]]
then
    printf "\nUploading $tanzubundlename\n"
    scp ~/binaries/$tanzubundlename $BASTION_USERNAME@$BASTION_HOST:~/merlin/tkgonvsphere/binaries/
fi

printf "\nChecking remote ~/merlin/tkgonvsphere/binaries/bastionhostinit.sh..."
isexist=$(cat /tmp/bastionhostbinaries.txt | grep -w "bastionhostinit.sh$")
if [[ -z $isexist ]]
then
    printf "\nUploading bastionhostinit.sh\n"
    scp ~/binaries/bastionhostinit.sh $BASTION_USERNAME@$BASTION_HOST:~/merlin/tkgonvsphere/binaries/
fi

printf "\nChecking remote ~/merlin/tkgonvsphere/binaries/bastionhostrun.sh..."
isexist=$(cat /tmp/bastionhosthomefiles.txt | grep -w "bastionhostrun.sh$")
if [[ -z $isexist ]]
then
    printf "\nUploading bastionhostrun.sh\n"
    scp ~/binaries/bastionhostrun.sh $BASTION_USERNAME@$BASTION_HOST:~/merlin/tkgonvsphere/
fi

printf "\nChecking remote ~/merlin/tkgonvsphere/Dockerfile..."
isexist=$(cat /tmp/bastionhosthomefiles.txt | grep -w "Dockerfile$")
if [[ -z $isexist ]]
then
    printf "\nUploading Dockerfile\n"
    scp ~/binaries/Dockerfile $BASTION_USERNAME@$BASTION_HOST:~/merlin/tkgonvsphere/
fi

isexist=$(cat /tmp/bastionhosthomefiles.txt | grep -w "dockerignore$")
if [[ -z $isexist ]]
then
    printf "\nUploading .dockerignore\n"
    scp ~/binaries/.dockerignore $BASTION_USERNAME@$BASTION_HOST:~/merlin/tkgonvsphere/
fi

isexist=$(ls ~/.ssh/tkg_rsa)
isexistidrsa=$(cat /tmp/bastionhosthomefiles.txt | grep -w "id_rsa$")
if [[ -n $isexist && -z $isexistidrsa ]]
then
    printf "\nUploading .ssh/tkg_rsa\n"
    scp ~/.ssh/tkg_rsa $BASTION_USERNAME@$BASTION_HOST:~/merlin/tkgonvsphere/.ssh/id_rsa
fi

isexist=$(docker context ls | grep "bastionhostdocker$")
if [[ -z $isexist ]]
then
    printf "\nCreating remote context...\n"
    docker context create bastionhostdocker  --docker "host=ssh://$BASTION_USERNAME@$BASTION_HOST"
else
    printf "\nremote context exists. Re-Using...\n"
fi

printf "\nUsing remote context...\n"
export DOCKER_CONTEXT='bastionhostdocker'

printf "\nWaiting 3s before checking remote container...\n"
sleep 3

printf "\nChecking remote context for running container named merlintkgonvsphere...\n"
docker ps
isexist=$(docker ps --filter "name=merlintkgonvsphere" --format "{{.Names}}")
if [[ -z $isexist ]]
then
    unset DOCKER_CONTEXT
    printf "\nmerlintkgonvsphere not running.\nStarting remote docker with tanzu cli...\n"
    ssh -i .ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'chmod +x ~/merlin/tkgonvsphere/bastionhostrun.sh && merlin/tkgonvsphere/bastionhostrun.sh '$DOCKERHUB_USERNAME $DOCKERHUB_PASSWORD
fi

while true; do
    read -p "Did the above command ran successfully? Confirm to continue? [yn] " yn
    case $yn in
        [Yy]* ) printf "\nyou confirmed yes\n"; break;;
        [Nn]* ) printf "\nyou said no\n"; exit 1;;
        * ) echo "Please answer y or n.";;
    esac
done

printf "\nUsing remote context...\n"
export DOCKER_CONTEXT='bastionhostdocker'

printf "\nWaiting 3s before checking remote container...\n"
sleep 3

printf "\nChecking remote context for container started with name merlintkgonvsphere...\n"
docker ps
isexist=$(docker ps --filter "name=merlintkgonvsphere" --format "{{.Names}}")
if [[ -z $isexist ]]
then
    count=1
    while [[ -z $isexist && $count -lt 4 ]]; do
        printf "\nContainer not running... Retrying in 5s"
        sleep 5
        isexist=$(docker ps --filter "name=merlintkgonvsphere" --format "{{.Names}}")
        ((count=count+1))
    done
fi
if [[ -z $isexist ]]
then
    printf "\nERROR: Remote container merlintkgonvsphere not running."
    printf "\nUnable to proceed further. Please check merling directory in your bastion host."
    exit
else
    printf "\nmerlintkgonvsphere is running successfully."
fi

printf "\nPerforming ssh-add...\n"
docker exec -idt merlintkgonvsphere bash -c "cd ~ ; ssh-add ~/.ssh/id_rsa"

printf "\nStarting tanzu cluster create in remote context...\n"
docker exec -it merlintkgonvsphere bash -c "cd ~ ; tanzu cluster create  --file $configfile -v 9"


printf "\n==> TGK cluster deployed -->> DONE.\n"
printf "\nWaiting 3s before clean up...\n"
sleep 3

printf "\n==> Start merlin cleanup process....\n"

printf "\nStopping bastion's docker...\n"
sleep 1
docker container stop merlintkgonvsphere || error='y' 
count=1
while [[ $error == 'y' && $count -lt 5 ]]; do
    printf "failed. retrying in 5s...\n"
    sleep 5
    error='n'
    docker container stop merlintkgonvsphere || error='y' 
    ((count=count+1))
done
printf "\nStopped container..."

sleep 2

printf "\nYou can choose to NOT remove the docker images in the remote jump/bastion host."
printf "\nThis will speed up the process to create workload cluster using this wizard next time."
printf "\nIf you remove the remote docker images it will free up spaces."
printf "\nIf you have enough disk space in the bastion host it is recommended to NOT remove remote docker images."
printf "\n"
sleep 2
isremoveremoteimages='n'
while true; do
    read -p "Would you like to remove remote docker images? [yn]: " yn
    case $yn in
        [Yy]* ) isremoveremoteimages='y'; printf "\nyou confirmed yes\n"; break;;
        [Nn]* ) printf "\nyou said no.\n"; break;;
        * ) echo "Please answer y or n to proceed...";;
    esac
done
if [[ $isremoveremoteimages == 'y' ]]
then
    printf "\nRemoving volumes..."
    sleep 1
    docker volume prune -f
    sleep 2
    printf "\nRemoving images..."
    sleep 1
    docker image rm merlintkgonvsphere:latest 
    docker rmi -f $(docker images -f "dangling=true" -q)
fi

unset DOCKER_CONTEXT

echo $configfile > /tmp/bastionhostsuccessful

printf "\n==> Bastion Host Workload COMPLETE\n"