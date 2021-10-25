sshuttlepid=$(ps aux | grep "/usr/bin/sshuttle --dns" | awk 'FNR == 1 {print $2}')
kill $sshuttlepid
containerid=$(docker ps -aqf "name=^merlintkgonvsphere$")
docker container stop $containerid
docker container rm $containerid
docker container rm $(docker container ls --all -q)
docker volume prune -f
docker rmi -f $(docker images -f "dangling=true" -q)
docker rmi -f $(docker images -q)