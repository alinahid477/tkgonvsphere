# tkgonvsphere

permission to start.sh script `chmod +x start.sh`


There are 3 ways to run start.sh or start.bat
- **no parameter** --> this will build the container with default name *tkgonvsphere* if image doesnt exist. If *tkgonvsphere* already exist it will run it.
- **parameter 1 {nameofthecontainer}** --> when a name is passed as the first parameter it will build and run container using the name if image does not exist. if the image exist with the name will simply run it.
- **parameter 2 {forcebuild}** --> this will force the build of the container regardless if image exists or not then run it. When parameter 1 is passed along with the parameter 2 *forcebuild* it will build and run using the name passes in the parameter 1. If only *forcebuild* is passed (eg: `./start.sh forcebuild`) then will force build and run using default name *tkgonvsphere*.





# Handy Commands:
```
tanzu management-cluster create --file /root/.config/tanzu/tkg/clusterconfigs/adb3ttltn4.yaml -v 6
```

kubectl -n kube-system rollout restart deployment coredns


kubectl get nodes -o jsonpath='{ $.items[0].status.addresses[?(@.type=="InternalIP")].address }' | awk -F"." '{print $1"."$2"."$3".1"}'
kubectl rollout status deployments coredns -n kube-system | grep success

https://stackoverflow.com/questions/54091002/docker-how-to-redirect-a-ip-within-a-container-to-another-ip

## Important
Where is cert and private key of vSphere
- Get public key:  root@vcsa-01a [ /usr/lib/vmware-vmafd/bin ]# ./vecs-cli entry list --store MACHINE_SSL_CERT
- Get private-key: root@vcsa-01a [ /usr/lib/vmware-vmafd/bin ]# ./vecs-cli entry getkey --store MACHINE_SSL_CERT --alias __MACHINE_CERT
Where is cert and private key for NSXALB
- This is something that you can generate in the AVI controller itself at Templates > Security > SSL/TSL Certificates > Create New
- Then download the cert and privatekey
- ALSO, add the cert entry in the Administration > Settings > Access Settings (Edit) > SSL/TLS Certificate field



kubectl apply -f workload-clusters/corednsconfigmap.yaml
kubectl -n kube-system rollout restart deployment coredns
