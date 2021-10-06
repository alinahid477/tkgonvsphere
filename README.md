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