#!/bin/bash

returnOrexit()
{
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
    then
        return
    else
        exit
    fi
}

sleep 3m

export $(cat /root/.env | xargs)

printf "\nGet kubeconfig in .kube-tkg/tmp...\n"
kubeconfig=$(ls -1 /root/.kube-tkg/tmp/ | awk 'FNR == 1 {print $1}')
count=1
while [[ -z $kubeconfig && $count -lt 60 ]]; do
    sleep 30
    kubeconfig=$(ls -1 /root/.kube-tkg/tmp/ | awk 'FNR == 1 {print $1}')
    ((count=count+1))
done

if [[ -z $kubeconfig ]]
then
    printf "\n\n\n\n*******\nERROR:Kubeconfig find timed out. DNS adjust quiting...\n**************\n\n\n\n"
    returnOrexit
fi

kubeconfig=/root/.kube-tkg/tmp/$kubeconfig
printf "\n--kubeconfig=$kubeconfig...\n"


sleep 1m

printf "\nChecking if coredns is ready...\n"

isexists=$(kubectl rollout status deployments coredns -n kube-system --kubeconfig=$kubeconfig | grep success)
count=1
while [[ -z $isexists && $count -lt 60 ]]; do
    sleep 30
    isexists=$(kubectl rollout status deployments coredns -n kube-system --kubeconfig=$kubeconfig | grep success)
    ((count=count+1))
done

if [[ -z $isexists ]]
then
    printf "\n\n\n\n*******\nERROR:CoreDNS deployment check timed out. DNS adjust quiting...\n**************\n\n\n\n"
    returnOrexit
fi


printf "\nRetrieving VM_LOCAL ip...\n"

VM_LOCAL_IP=$(kubectl get nodes -o jsonpath='{ $.items[0].status.addresses[?(@.type=="InternalIP")].address }' --kubeconfig=$kubeconfig | awk -F"." '{print $1"."$2"."$3".1"}')
count=1
while [[ -z $VM_LOCAL_IP && $count -lt 60 ]]; do
    sleep 30
    VM_LOCAL_IP=$(kubectl get nodes -o jsonpath='{ $.items[0].status.addresses[?(@.type=="InternalIP")].address }' --kubeconfig=$kubeconfig | awk -F"." '{print $1"."$2"."$3".1"}')
    ((count=count+1))
done

if [[ -z $VM_LOCAL_IP ]]
then
    printf "\n\n\n\n*******\nERROR:VM_LOCAL_IP could not be retrieved. DNS adjust quiting...\n**************\n\n\n\n"
    returnOrexit
fi

printf "\nVM_LOCAL_IP=$VM_LOCAL_IP\n"

awk -v old="VM_LOCAL_IP" -v new="$VM_LOCAL_IP" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/binaries/dns/corednsconfigmap.yaml > /tmp/corednsconfigmap.tmp
sleep 1
awk -v old="nsxalb.local" -v new="$NSX_ALB_DOMAIN_NAME" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' /tmp/corednsconfigmap.tmp > /tmp/corednsconfigmap.yaml
sleep 1

kubectl apply -f /tmp/corednsconfigmap.yaml --kubeconfig=$kubeconfig
sleep 3

kubectl -n kube-system rollout restart deployment coredns --kubeconfig=$kubeconfig
sleep 3

# service nginx stop
# sleep 2

# fuser -k 443/tcp
# sleep 1

# printf "\n\n\ncreating tunnel 443:$NSX_ALB_ENDPOINT:443 $BASTION_USERNAME@$BASTION_HOST...\n"
# ssh -i /root/.ssh/id_rsa -4 -fNT -L $VM_LOCAL_IP:443:$NSX_ALB_ENDPOINT:443 $BASTION_USERNAME@$BASTION_HOST

sleep 90

printf "\n\n\n\n"

printf "\nChecking ako status...\n"
akostatus=$(kubectl get pods -n avi-system ako-0 -o jsonpath="{.status.phase}" --kubeconfig=$kubeconfig)
count=1
while [[ $akostatus != "Running" && $count -lt 60 ]]; do
    printf "\nako status: $akostatus. Retrying in 30s..."
    sleep 30
    akostatus=$(kubectl get pods -n avi-system ako-0 -o jsonpath="{.status.phase}" --kubeconfig=$kubeconfig)
    ((count=count+1))
done
printf "\n\n"
kubectl get pods -n avi-system --kubeconfig=$kubeconfig

printf "\nDONE.\n"
printf "\n\n\n\n"

