#!/bin/bash
mkdir logs
install_tanzu_plugin()
{
    tanzubundlename=''
    printf "\nChecking tanzu bundle...\n\n" >> logs/bastioninitlog.log
    cd /tmp
    sleep 1
    numberoftarfound=$(find /tmp/*.tar* -type f -printf "." | wc -c)
    if [[ $numberoftarfound -lt 1 ]]
    then
        printf "\nNo tanzu bundle found. Please place the tanzu bindle in ~/binaries and rebuild again. Exiting...\n" >> logs/bastioninitlog.log
        exit 1
    fi
    if [[ $numberoftarfound == 1 ]]
    then
        tanzubundlename=$(find /tmp/*.tar* -printf "%f\n")
        printf "\n\nTanzu Bundle: $tanzubundlename.\n\n"
    else
        printf "\n\nError: Found more than 1 tar file. Please ensure only 1 tanzu tar file exists in binaries directory.\n\n"
        exit 1
    fi
    

    
    printf "\nTanzu Bundle: $tanzubundlename. Installing..." >> logs/bastioninitlog.log
    # sleep 1
    # mkdir tanzu
    # tar -xvf $tanzubundlename -C tanzu/

    if [[ $tanzubundlename == "tce"* ]]
    then
        cd /tmp/tanzu/
        tcefolder=$(ls | grep tce)
        cd $tcefolder
        export ALLOW_INSTALL_AS_ROOT=true
        ./install.sh
    else
        cd /tmp/tanzu/cli/core
        versionfolder=$(ls | grep v)
        cd $versionfolder
        install /tmp/tanzu/cli/core/$versionfolder/tanzu-core-linux_amd64 /usr/local/bin/tanzu
        tanzu plugin install --local /tmp/tanzu/cli all
    fi    

    cd ~
}

ISINSTALLED=$(find ~/.local/share/tanzu-cli/* -printf '%f\n' | grep management-cluster)
if [[ -z $ISINSTALLED ]]
then
    printf "\n\ntanzu plugin management-cluster not found. installing...\n\n" >> logs/bastioninitlog.log
    install_tanzu_plugin
    printf "\n\n"
fi

tanzu plugin list

tail -f /dev/null