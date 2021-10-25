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

printf "\nStarting remote docker with tanzu cli...\n"
# homepath=$(ssh -i .ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'pwd')
ssh -i .ssh/id_rsa $BASTION_USERNAME@$BASTION_HOST 'chmod +x ~/merlin/tkgonvsphere/bastionhostrun.sh && merlin/tkgonvsphere/bastionhostrun.sh '$DOCKERHUB_USERNAME $DOCKERHUB_PASSWORD


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
docker exec -idt merlintkgonvsphere bash -c "cd ~ ; tanzu management-cluster create --ui -y -v 9 --browser none"

printf "\nStarting sshuttle...\n"
sshuttle --dns --python python2 -D -r $BASTION_USERNAME@$BASTION_HOST 0/0 --disable-ipv6 --listen 0.0.0.0:0

