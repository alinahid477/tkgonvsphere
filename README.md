# tkgonvsphere



```
docker build . -t tkgonvsphere
docker run -it --rm --net=host -v ${PWD}:/root/ -v /var/run/docker.sock:/var/run/docker.sock --name tkgonvsphere tkgonvsphere /bin/bash 
```