#!/bin/bash
docker login -u $1 -p $2
docker build -f ~/merlin/tkgonvsphere/Dockerfile -t merlintkgonvsphere ~/merlin/tkgonvsphere/
homepath=$(pwd)
printf "\nStrating merlintkgonvsphere...\n"
docker run -td --rm --net=host -v $homepath/merlin/tkgonvsphere:/root/ -v /var/run/docker.sock:/var/run/docker.sock --name merlintkgonvsphere merlintkgonvsphere
printf "\nDONE...\n"