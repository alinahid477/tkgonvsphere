sudo rm -r .cache/ .config/ .local/ .kube-tkg/
containerid=$(docker ps -aqf "name=^tkg-kind")
docker container stop $containerid
docker container rm $containerid
docker volume prune -f