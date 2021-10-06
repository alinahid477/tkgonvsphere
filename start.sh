isexists=$(docker images | grep "\<$1\>")
if [[ -z $isexists || $2 == "forcebuild" ]]
then
    docker build . -t $1
fi
# cd binaries/bind9
# docker network create --subnet=100.64.0.0/16 corp-tanzu-net
# docker build -t bind9 .
# docker run -d --rm --name=dns-server --net=corp-tanzu-net --ip=100.64.0.10 bind9
# docker exec -d dns-server /etc/init.d/bind9 start
# cd ../../
# docker run --rm --publish 100.64.0.10:53:53/udp --net=dns-network --ip 100.64.0.10 --name dnscontainer sameersbn/bind:latest
# docker run -it --rm --net=host --dns=192.168.110.10 --dns=127.0.0.53 --dns-search=localdomain -v ${PWD}:/root/ -v /var/run/docker.sock:/var/run/docker.sock --name $1 $1
# docker run -it --rm --net=corp-tanzu-net --dns=127.0.0.1 --dns=100.64.0.10 --dns=8.8.8.8 --hostname $1 -p 8080:8080 --ip=100.64.0.2 -v ${PWD}:/root/ -v /var/run/docker.sock:/var/run/docker.sock --name $1 $1
docker run -it --rm --net=host --dns=127.0.0.1 --dns=8.8.8.8 -v ${PWD}:/root/ -v /var/run/docker.sock:/var/run/docker.sock --name $1 $1
#docker run -it --rm --dns=100.64.0.10 --net=dns-network -v ${PWD}:/root/ -v /var/run/docker.sock:/var/run/docker.sock --name $1 $1
