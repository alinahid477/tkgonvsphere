# tkgonvsphere



```
docker build . -t tkgonvsphere
docker run -it --rm --net=host --dns=192.168.110.10 --dns=127.0.0.53 --dns-search=localdomain -v ${PWD}:/root/ -v /var/run/docker.sock:/var/run/docker.sock --name tkgonvsphere tkgonvsphere /bin/bash 
```


```
tanzu management-cluster create --file /root/.config/tanzu/tkg/clusterconfigs/adb3ttltn4.yaml -v 6
```



kubectl -n kube-system rollout restart deployment coredns


kubectl get nodes -o jsonpath='{ $.items[0].status.addresses[?(@.type=="InternalIP")].address }' | awk -F"." '{print $1"."$2"."$3".1"}'
kubectl rollout status deployments coredns -n kube-system | grep success

https://stackoverflow.com/questions/54091002/docker-how-to-redirect-a-ip-within-a-container-to-another-ip

sshuttle -D -r ubuntu@10.79.156.23 192.168.0.0/16


## Important
Where is cert and private key of vSphere
- Get public key:  root@vcsa-01a [ /usr/lib/vmware-vmafd/bin ]# ./vecs-cli entry list --store MACHINE_SSL_CERT
- Get private-key: root@vcsa-01a [ /usr/lib/vmware-vmafd/bin ]# ./vecs-cli entry getkey --store MACHINE_SSL_CERT --alias __MACHINE_CERT
Where is cert and private key for NSXALB
- This is something that you can generate in the AVI controller itself at Templates > Security > SSL/TSL Certificates > Create New
- Then download the cert and privatekey
- ALSO, add the cert entry in the Administration > Settings > Access Settings (Edit) > SSL/TLS Certificate field