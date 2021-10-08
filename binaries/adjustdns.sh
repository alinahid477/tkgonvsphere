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


printf "\n\n\n\n"
printf "********Starting DNS Adjustment*************"


export $(cat /root/.env | xargs)


printf "\n******Get kubeconfig in .kube-tkg/tmp...\n"
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
printf "\n\n\n\n"
printf "\n******--kubeconfig=$kubeconfig...\n"


sleep 1m

printf "\n\n\n\n"
printf "\n******Checking if coredns is ready...\n"

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

printf "\n\n\n\n"
printf "\n*******Retrieving VM_LOCAL ip...\n"

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

printf "\n\n\n\n"
printf "\n*******VM_LOCAL_IP=$VM_LOCAL_IP\n"


printf "\n\n\n\n"
printf "\n*****Configuring Coredns******...\n"

printf "\n\n\n\n"
printf "\n*****Generating corednsconfig for $NSX_ALB_DOMAIN_NAME and $VSPHERE_DOMAIN_NAME...\n"
awk -v old="NSX_ALB_IP" -v new="$VM_LOCAL_IP" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/binaries/dns/corednsconfigmap.yaml > /tmp/corednsconfigmap.nsxalb-ip
sleep 1
awk -v old="nsxalb.local" -v new="$NSX_ALB_DOMAIN_NAME" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' /tmp/corednsconfigmap.nsxalb-ip > /tmp/corednsconfigmap.nsxalb
sleep 1
awk -v old="VSPHERE_IP" -v new="$VM_LOCAL_IP" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' /tmp/corednsconfigmap.nsxalb > /tmp/corednsconfigmap.vsphere-ip
sleep 1
awk -v old="vsphere.local" -v new="$VSPHERE_DOMAIN_NAME" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' /tmp/corednsconfigmap.vsphere-ip > /tmp/corednsconfigmap.yaml
sleep 1

printf "\n\n\n\n"
printf "\n*****Adjusting coredns for $NSX_ALB_DOMAIN_NAME and $VSPHERE_DOMAIN_NAME....\n"
kubectl apply -f /tmp/corednsconfigmap.yaml --kubeconfig=$kubeconfig
sleep 3
kubectl -n kube-system rollout restart deployment coredns --kubeconfig=$kubeconfig
sleep 3
printf "\n\n\n\n"
printf "\n******Coredns configure complete*****\n"


printf "\n\n\n\n"
printf "\n*****Configuring Webserver******...\n"

fuser -k 8443/tcp
fuser -k 9443/tcp

printf "\n\n\n\n"
printf "\n*****Adjust host...\n"
isexist=$(cat /etc/hosts | grep "$VSPHERE_DOMAIN_NAME$")
if [[ -z $isexist ]]
then
    printf "\nMapping to hosts $VSPHERE_DOMAIN_NAME..."
    printf "\n$VM_LOCAL_IP       $VSPHERE_DOMAIN_NAME" >> /etc/hosts
fi
isexist=$(cat /etc/hosts | grep "$NSX_ALB_DOMAIN_NAME$")
if [[ -z $isexist ]]
then
    printf "\nMapping to hosts $NSX_ALB_DOMAIN_NAME..."
    printf "\n$VM_LOCAL_IP     $NSX_ALB_DOMAIN_NAME" >> /etc/hosts
fi
sleep 1

printf "\n\n\n\n"
printf "\n*******Creating webserver host file according to VSPHERE_DOMAIN_NAME $VSPHERE_DOMAIN_NAME"
awk -v old="VM_LOCAL_IP" -v new="$VM_LOCAL_IP" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/binaries/dns/vsphere.local > /tmp/vsphere.local
awk -v old="vsphere.local" -v new="$VSPHERE_DOMAIN_NAME" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' /tmp/vsphere.local > ~/binaries/dns/$VSPHERE_DOMAIN_NAME
sleep 1

printf "\n\n\n\n"
printf "\n*******Creating webserver host file according to NSX_ALB_DOMAIN_NAME $NSX_ALB_DOMAIN_NAME"
awk -v old="VM_LOCAL_IP" -v new="$VM_LOCAL_IP" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' ~/binaries/dns/nsxalb.local > /tmp/nsxalb.local
awk -v old="nsxalb.local" -v new="$NSX_ALB_DOMAIN_NAME" 's=index($0,old){$0=substr($0,1,s-1) new substr($0,s+length(old))} 1' /tmp/nsxalb.local > ~/binaries/dns/$NSX_ALB_DOMAIN_NAME
sleep 1

printf "\n\n\n\n"
printf "\n*******removing nginx default...\n"
rm /etc/nginx/sites-available/default
rm /etc/nginx/sites-enabled/default
sleep 1

printf "\n\n\n\n"
printf "\n*******Adding custom default...\n"
cp ~/binaries/dns/default /etc/nginx/sites-available/
chmod 755 /etc/nginx/sites-available/default
ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/
sleep 1

printf "\n\n\n\n"
printf "\n*******Adding $NSX_ALB_DOMAIN_NAME to nginx...\n"
cp ~/binaries/dns/$NSX_ALB_DOMAIN_NAME /etc/nginx/sites-available/
chmod 755 /etc/nginx/sites-available/$NSX_ALB_DOMAIN_NAME
ln -s /etc/nginx/sites-available/$NSX_ALB_DOMAIN_NAME /etc/nginx/sites-enabled/
sleep 1

printf "\n\n\n\n"
printf "\n*******Adding $VSPHERE_DOMAIN_NAME to nginx...\n"
cp ~/binaries/dns/$VSPHERE_DOMAIN_NAME /etc/nginx/sites-available/
chmod 755 /etc/nginx/sites-available/$VSPHERE_DOMAIN_NAME
ln -s /etc/nginx/sites-available/$VSPHERE_DOMAIN_NAME /etc/nginx/sites-enabled/
sleep 1

printf "\n\n\n\n"
printf "\n*******Equip with cert for tls...\n"
cp ~/binaries/dns/nsxalbcert.key /etc/nginx/
cp ~/binaries/dns/nsxalbcert.crt /etc/nginx/
sleep 1
chmod 755 /etc/nginx/nsxalbcert.key
chmod 755 /etc/nginx/nsxalbcert.crt
sleep 1
cp ~/binaries/dns/vspherecert.key /etc/nginx/
cp ~/binaries/dns/vspherecert.crt /etc/nginx/
sleep 1
chmod 755 /etc/nginx/vspherecert.key
chmod 755 /etc/nginx/vspherecert.crt
sleep 1

printf "\n\n\n\n"
printf "\n*******Start...\n"
fuser -k 443/tcp
sleep 1
service nginx start
sleep 1

printf "\n\n\n\n"
printf "\n*******creating tunnel $VM_LOCAL_IP:8443:$NSX_ALB_IP:443 $BASTION_USERNAME@$BASTION_HOST...\n"
ssh -i /root/.ssh/id_rsa -4 -fNT -L $VM_LOCAL_IP:8443:$NSX_ALB_IP:443 $BASTION_USERNAME@$BASTION_HOST
sleep 1
printf "\n\n\n\n"
printf "\n*******creating tunnel $VM_LOCAL_IP:9443:$VSPHERE_IP:443 $BASTION_USERNAME@$BASTION_HOST...\n"
ssh -i /root/.ssh/id_rsa -4 -fNT -L $VM_LOCAL_IP:9443:$VSPHERE_IP:443 $BASTION_USERNAME@$BASTION_HOST

printf "\n\n\n\n"
printf "\n******Webserver configure complete*****\n"

sleep 60

printf "\n\n\n\n"
printf "\n*******Checking ako status...\n"
akostatus=$(kubectl get pods -n avi-system ako-0 -o jsonpath="{.status.phase}" --kubeconfig=$kubeconfig)
count=1
while [[ $akostatus != "Running" && $count -lt 60 ]]; do
    printf "\n\n\n\n"
    printf "\n*******ako status: $akostatus. Retrying in 30s..."
    sleep 30
    akostatus=$(kubectl get pods -n avi-system ako-0 -o jsonpath="{.status.phase}" --kubeconfig=$kubeconfig)
    ((count=count+1))
done
printf "\n\n\n\n"
printf "\n*******Final ako status: $akostatus.\n"
kubectl get pods -n avi-system --kubeconfig=$kubeconfig

# fuser -k 443/tcp
# sleep 1
# printf "\n\n\ncreating tunnel $VM_LOCAL_IP:443:$VSPHERE_IP:443 $BASTION_USERNAME@$BASTION_HOST...\n"
# ssh -i /root/.ssh/id_rsa -4 -fNT -L $VM_LOCAL_IP:443:$VSPHERE_IP:443 $BASTION_USERNAME@$BASTION_HOST
printf "\n\n\n\n"
printf "\n**********DONE DNS Adjustment***********\n"
printf "\n\n\n\n"

