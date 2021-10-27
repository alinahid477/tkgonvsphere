#!/bin/bash
export $(cat /root/.env | xargs)



printf "\nPreparing $BASTION_USERNAME@$BASTION_HOST for merlin\n"

isexist=$(ssh -i .ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'ls -l merlin/tkgonvsphere')
if [[ -z $isexist ]]
then
    printf "\nCreating directory 'merlin' in $BASTION_USERNAME@$BASTION_HOST home dir"
    ssh -i .ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'mkdir -p merlin/tkgonvsphere/binaries'
fi

printf "\nGetting remote files list from $BASTION_USERNAME@$BASTION_HOST\n"
ssh -i .ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'ls ~/merlin/tkgonvsphere/binaries' > /tmp/bastionhostbinaries.txt
ssh -i .ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'ls -a ~/merlin/tkgonvsphere/' > /tmp/bastionhosthomefiles.txt

isexist=$(cat /tmp/bastionhostbinaries.txt | grep -w "tanzu-cli-bundle-linux-amd64.tar$")
if [[ -z $isexist ]]
then
    printf "\nUploading tanzu-cli-bundle-linux-amd64.tar\n"
    scp ~/binaries/tanzu-cli-bundle-linux-amd64.tar $BASTION_USERNAME@$BASTION_HOST:~/merlin/tkgonvsphere/binaries/
fi

isexist=$(cat /tmp/bastionhostbinaries.txt | grep -w "bastionhostinit.sh$")
if [[ -z $isexist ]]
then
    printf "\nUploading bastionhostinit.sh\n"
    scp ~/binaries/bastionhostinit.sh $BASTION_USERNAME@$BASTION_HOST:~/merlin/tkgonvsphere/binaries/
fi

isexist=$(cat /tmp/bastionhosthomefiles.txt | grep -w "bastionhostrun.sh$")
if [[ -z $isexist ]]
then
    printf "\nUploading bastionhostrun.sh\n"
    scp ~/binaries/bastionhostrun.sh $BASTION_USERNAME@$BASTION_HOST:~/merlin/tkgonvsphere/
fi

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

if [[ -n $MANAGEMENT_CLUSTER_CONFIG_FILE ]]
then
    printf "\nUploading $MANAGEMENT_CLUSTER_CONFIG_FILE\n"
    scp $MANAGEMENT_CLUSTER_CONFIG_FILE $BASTION_USERNAME@$BASTION_HOST:~/merlin/tkgonvsphere/
fi


printf "\nStarting remote docker with tanzu cli...\n"
ssh -i .ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'chmod +x ~/merlin/tkgonvsphere/bastionhostrun.sh && merlin/tkgonvsphere/bastionhostrun.sh '$DOCKERHUB_USERNAME $DOCKERHUB_PASSWORD


while true; do
    read -p "Confirm to continue? [y] " yn
    case $yn in
        [Yy]* ) printf "\nyou confirmed yes\n"; break;;
        * ) echo "Please answer y when you are ready.";;
    esac
done

printf "\nCreating remote context...\n"
isexist=$(docker context ls | grep "bastionhostdocker$")
if [[ -z $isexist ]]
then
    docker context create bastionhostdocker  --docker "host=ssh://$BASTION_USERNAME@$BASTION_HOST"
fi

printf "\nUsing remote context...\n"
export DOCKER_CONTEXT='bastionhostdocker'

printf "\nChecking remote context...\n"
docker ps

printf "\nStarting tanzu in remote context...\n"
if [[ -n $MANAGEMENT_CLUSTER_CONFIG_FILE ]]
then
    # homepath=$(ssh -i .ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'pwd')
    filename=$(echo $MANAGEMENT_CLUSTER_CONFIG_FILE| rev | awk -v FS='/' '{print $1}' | rev)
    printf "\nLaunching management cluster create using $MANAGEMENT_CLUSTER_CONFIG_FILE...\n"
    docker exec -idt merlintkgonvsphere bash -c "cd ~ ; tanzu management-cluster create --file /home/user/$filename -v 9"
else
    printf "\nLaunching management cluster create using UI...\n"
    docker exec -idt merlintkgonvsphere bash -c "cd ~ ; tanzu management-cluster create --ui -y -v 9 --browser none"
fi

chmod 0600 /root/.ssh/*
cp /root/.ssh/sshuttleconfig /root/.ssh/ssh_config
mv /etc/ssh/ssh_config /etc/ssh/ssh_config-default
ln -s /root/ssh/ssh_config /etc/ssh/ssh_config

printf "\n\n\n"
echo "=> Establishing sshuttle with remote $BASTION_USERNAME@$BASTION_HOST...."
sshuttle --dns --python python2 -D -r $BASTION_USERNAME@$BASTION_HOST 0/0 -x $BASTION_HOST/32 --disable-ipv6 --listen 0.0.0.0:0
echo "=> DONE."


printf "\n\n\n Here's your public key in ~/.ssh/id_rsa.pub:\n"
cat ~/.ssh/tkg_rsa.pub
printf "\n\n\nAccess installation UI at http://127.0.0.1:8080"


containercreated='n'
containerdeleted='n'
dobreak='n'
count=1
while [[ $dobreak == 'n' && $count -lt 30 ]]; do
    sleep 2m
    printf "\nChecking progres...\n"
    ((count=count+1))
    if [[ $containercreated == 'n' ]]
    then
        printf "Checking bootstrap cluster created..."
        isexist=$(docker container ls | grep "projects.registry.vmware.com/tkg/kind/node" || printf "")
        if [[ -n $isexist ]]
        then
            containercreated='y'
            count=1
            printf "YES"
        else
            printf "NO"
        fi
        printf "\n"
    else
        if [[ $containerdeleted == 'n' ]]
        then
            printf "Checking bootstrap cluster uploaded..."
            isexist=$(docker container ls | grep "projects.registry.vmware.com/tkg/kind/node" || printf "")
            if [[ -z $isexist ]]
            then
                containerdeleted='y'
                count=1
                printf "YES"
            else
                printf "NO"
            fi
            printf "\n"
        fi
    fi
    if [[ $containercreated == 'y' && $containerdeleted == 'y' ]]
    then
        sleep 3
        printf "\nTKG management cluster should have been deployed...\n"
        count=100
        dobreak='y'
    fi
done

printf "\n==> TGK management cluster deployed -->> DONE.\n"
printf "\nWaiting 30s before clean up...\n"
sleep 30

printf "\n==> Start merlin cleanup process....\n"

printf "\nStopping sshuttle...\n"
sshuttlepid=$(ps aux | grep "/usr/bin/sshuttle --dns" | awk 'FNR == 1 {print $2}')
kill $sshuttlepid
printf "==> DONE\n"
sleep 2

printf "\nDownloading management cluster configs...\n"
cd ~
mkdir -p .config/tanzu/tkg/clusterconfigs
filename=$(docker exec merlintkgonvsphere ls ~/.config/tanzu/tkg/clusterconfigs/ || printf "")
count=1
while [[ -z $filename && $count -lt 5 ]]; do
    printf "failed getting filename. retrying in 5s...\n"
    sleep 5
    filename=$(docker exec merlintkgonvsphere ls ~/.config/tanzu/tkg/clusterconfigs/ || printf "")
    ((count=count+1))
done
sleep 1
error='n'
docker exec merlintkgonvsphere cat ~/.config/tanzu/tkg/clusterconfigs/$filename > ~/.config/tanzu/tkg/clusterconfigs/$filename || error='y'
count=1
while [[ $error == 'y' && $count -lt 5 ]]; do
    printf "failed downloading. retrying in 5s...\n"
    sleep 5
    error='n'
    docker exec merlintkgonvsphere cat ~/.config/tanzu/tkg/clusterconfigs/$filename > ~/.config/tanzu/tkg/clusterconfigs/$filename || error='y'
    ((count=count+1))
done

sleep 1
error='n'
docker exec merlintkgonvsphere cat ~/.config/tanzu/tkg/cluster-config.yaml > ~/.config/tanzu/tkg/cluster-config.yaml || error='y'
count=1
while [[ $error == 'y' && $count -lt 5 ]]; do
    printf "failed downloading. retrying in 5s...\n"
    sleep 5
    error='n'
    docker exec merlintkgonvsphere cat ~/.config/tanzu/tkg/cluster-config.yaml > ~/.config/tanzu/tkg/cluster-config.yaml || error='y'
    ((count=count+1))
done

sleep 1
error='n'
docker exec merlintkgonvsphere cat ~/.config/tanzu/tkg/features.json > ~/.config/tanzu/tkg/features.json || error='y'
count=1
while [[ $error == 'y' && $count -lt 5 ]]; do
    printf "failed downloading. retrying in 5s...\n"
    sleep 5
    error='n'
    docker exec merlintkgonvsphere cat ~/.config/tanzu/tkg/features.json > ~/.config/tanzu/tkg/features.json || error='y'
    ((count=count+1))
done

sleep 1
error='n'
docker exec merlintkgonvsphere cat ~/.kube/config > ~/.kube/config || error='y'
count=1
while [[ $error == 'y' && $count -lt 5 ]]; do
    printf "failed downloading kubeconfig. retrying in 5s...\n"
    sleep 5
    error='n'
    docker exec merlintkgonvsphere cat ~/.kube/config > ~/.kube/ || error='y'
    ((count=count+1))
done
# scp -r $BASTION_USERNAME@$BASTION_HOST:~/merlin/tkgonvsphere/.config/tanzu/tkg/clusterconfigs ~/.config/tanzu/tkg/
printf "==> DONE\n"
sleep 2
# sleep 10
# tanzu cluster list
# tanzu cluster kubeconfig get  --admin


while true; do
    read -p "Confirm to continue? [y] " yn
    case $yn in
        [Yy]* ) printf "\nyou confirmed yes\n"; break;;
        * ) echo "Please answer y when you are ready.";;
    esac
done


printf "\nCleanup bastion host...\n"
sleep 2
error='n'
docker exec merlintkgonvsphere rm -r ~/.cache/ ~/.config/ ~/.local/ ~/.kube-tkg/ ~/.kube/ || error='y'
count=1
while [[ $error == 'y' && $count -lt 5 ]]; do
    printf "failed. retrying in 5s...\n"
    sleep 5
    error='n'
    docker exec merlintkgonvsphere rm -r ~/.cache/ ~/.config/ ~/.local/ ~/.kube-tkg/ ~/.kube/ || error='y'
    ((count=count+1))
done
printf "\nRemoved temporary files..."

sleep 2
containerid=$(docker ps -aqf "name=^merlintkgonvsphere$" || printf "")
count=1
while [[ -z $containerid && $count -lt 5 ]]; do
    printf "failed. retrying in 5s...\n"
    sleep 5
    containerid=$(docker ps -aqf "name=^merlintkgonvsphere$" || printf "")
    ((count=count+1))
done
error='n'
docker container stop $containerid || error='y' 
count=1
while [[ $error == 'y' && $count -lt 5 ]]; do
    printf "failed. retrying in 5s...\n"
    sleep 5
    error='n'
    docker container stop $containerid || error='y' 
    ((count=count+1))
done
printf "\nStopped container..."
docker container rm $containerid
sleep 2
docker container rm $(docker container ls --all -q)
printf "\nRemoved container image..."
sleep 2
docker volume prune -f
printf "\nFreeing up space..."
sleep 2
docker rmi -f $(docker images -f "dangling=true" -q)
sleep 2
docker rmi -f $(docker images -q)
printf "\nRemoved images..."
sleep 2
ssh -i .ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'rm -r ~/merlin/tkgonvsphere'
printf "\nRemoved files..."
printf "\n==> DONE\n"

printf "\n==> Cleanup process complete....\n"

# printf "\nStarting sshuttle...\n"
# sshuttle --dns --python python2 -D -r $BASTION_USERNAME@$BASTION_HOST 0/0 -x $BASTION_HOST/32 --disable-ipv6 --listen 0.0.0.0:0