#!/bin/bash

install_tanzu_plugin()
{
    printf "\nChecking tanzu unpacked...\n\n"
    isexists=$(ls /tmp/tanzu | grep -w "cli$")
    if [[ -z $isexists ]]
    then
        printf "\nError: Bundle ~/binaries/tanzu-cli-bundle-linux-amd64.tar not found. Exiting..\n"
        exit        
    fi
    cd ~
    printf "\ntanzu plugin install...\n"
    tanzu plugin install --local /tmp/tanzu/cli all
}

ISINSTALLED=$(tanzu management-cluster --help)
if [[ $ISINSTALLED == *@("unknown"|"does not exist")* ]]
then
    printf "\n\ntanzu plugin management-cluster not found. installing...\n\n"
    install_tanzu_plugin
    printf "\n\n"
fi

tanzu plugin list

tail -f /dev/null