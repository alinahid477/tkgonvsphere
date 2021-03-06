# tkgonvsphere

***This repo is a part of Merlin initiative (https://github.com/alinahid477/merlin)***

<img src="images/logo.png" alt="Tanzu Kubernetes Grid Wizard (for TKGm on vsphere)" width=200 height=210/>

**The aim is to simplify and quick start with TKGm.**

The official documentation of Tanzu Kubernetes Grid (https://docs.vmware.com/en/VMware-Tanzu-Kubernetes-Grid/1.4/vmware-tanzu-kubernetes-grid-14/GUID-index.html) contains a detailed way of provisioning management and workload clusters which requires several plugins installed lots for file manipulations and files may conflict if they are not organised properly.

This docker container is a bootstrapped way for achieving the same but a lot simpler. eg: You don't need to install anything on your host machine. Infact, you dont need to install anything. This bootstrapped docker takes care of all the installation prerequisits. It also helps with organising the files location (eg: Per management cluster and all of its workload cluster you can have one instance of this docker.)

The bootstrap environment (once built and run using ./start.sh or start.bat) comes with the below pre-installed binaries and some handy wizards to create management and workload clusters


- kubectl
- Tanzu CLI
- **Tanzu Wizards**
    - *tkginstall* -->  lets you deploy TKG management cluster.
    - *tkgworkload* -->  Wizard like command line UI that helps/simplifies the generation of config file for workload cluster and uses tanzu cli to deploy it.
    - *tkgconnect* --> used to connect existing cluster under tanzu

# Prequisites

## .env file

rename .env.sample to .env file. `mv .env.sample .env`

- **BASTION_HOST**=(optional, if you are using a jumphost or bastion host only then ip address or fqdn of the jumphost or bastionhost)
- **BASTION_USERNAME**=(optional, if you are using a jumphost or bastion host only then username of the jumphost or bastionhost)
- **DOCKERHUB_USERNAME**=(optional, needed only if you are using bastion host)
- **DOCKERHUB_PASSWORD**=(optional, needed only if you are using bastion host)
- **AUTH_ENDPOINT**=leave empty
- **TUNNEL_AUTH_ENDPOINT_THROUGH_BASTION**=NO

## id_rsa file (optional)

If using bastion host then you must place the file named "id_rsa" (must be called id_rsa) in the .ssh directory.

## Tanzu Bundle

***Place the Tanzu bundle tar file in binaries directory (only 1 of the below).***

- **Tanzu Community Edition**: 
    - Download from here --> https://tanzucommunityedition.io/download/. 
    - Download the linux version.

**OR**

- **Tanzu enterprise edition**: Download from here
    - Login into https://my.vmware.com
    - Download cli from here: https://my.vmware.com/en/web/vmware/downloads/info/slug/infrastructure_operations_management/vmware_tanzu_kubernetes_grid/1_x
    - Select version 1.4.0
    - Download the linux version.

## Run

permission to start.sh script `chmod +x start.sh`


There are 3 ways to run start.sh or start.bat
- **no parameter** --> this will build the container with default name *tkgonvsphere* if image doesnt exist. If *tkgonvsphere* already exist it will run it.
- **parameter 1 {nameofthecontainer}** --> when a name is passed as the first parameter it will build and run container using the name if image does not exist. if the image exist with the name will simply run it.
- **parameter 2 {forcebuild}** --> this will force the build of the container regardless if image exists or not then run it. When parameter 1 is passed along with the parameter 2 *forcebuild* it will build and run using the name passes in the parameter 1. If only *forcebuild* is passed (eg: `./start.sh forcebuild`) then will force build and run using default name *tkgonvsphere*.


# That's it

Enjoy Merlin


# TO DO
- Add functionality to install packages (currently this is only available on vsphere-with-tanzu-wizard https://github.com/alinahid477/vsphere-with-tanzu-wizard)
- TMC integration --> This feature in this wizard will be available when TMC will start to support 1.4


# Handy Commands:
```
tanzu management-cluster create --file /root/.config/tanzu/tkg/clusterconfigs/adb3ttltn4.yaml -v 6
```

`kubectl -n kube-system rollout restart deployment coredns`

```
kubectl get nodes -o jsonpath='{ $.items[0].status.addresses[?(@.type=="InternalIP")].address }' | awk -F"." '{print $1"."$2"."$3".1"}'
kubectl rollout status deployments coredns -n kube-system | grep success
```

https://stackoverflow.com/questions/54091002/docker-how-to-redirect-a-ip-within-a-container-to-another-ip


Where is cert and private key of vSphere
- Get public key:  root@vcsa-01a [ /usr/lib/vmware-vmafd/bin ]# ./vecs-cli entry list --store MACHINE_SSL_CERT
- Get private-key: root@vcsa-01a [ /usr/lib/vmware-vmafd/bin ]# ./vecs-cli entry getkey --store MACHINE_SSL_CERT --alias __MACHINE_CERT
Where is cert and private key for NSXALB
- This is something that you can generate in the AVI controller itself at Templates > Security > SSL/TSL Certificates > Create New
- Then download the cert and privatekey
- ALSO, add the cert entry in the Administration > Settings > Access Settings (Edit) > SSL/TLS Certificate field


`kubectl apply -f workload-clusters/corednsconfigmap.yaml`

`kubectl -n kube-system rollout restart deployment coredns`

