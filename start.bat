@ECHO OFF


echo "Unix convert start,..." 

PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& './converter.ps1'"

echo "Unix convert end,..."

set name=%1
set doforcebuild=%2

if "%name%" == "forcebuild" (
    set name=
    set doforcebuild="forcebuild"    
)

if "%name%" == "" (
    echo "assuming default name is: tkgonvsphere"
    set name="tkgonvsphere"
)


set isexists=
FOR /F "delims=" %%i IN ('docker images  ^| findstr /i "%name%"') DO set isexists=%%i

if "%name%" == "%isexists%" (
    echo "docker image name %isexists% already exists. Will avoide build if not forcebuild..."
)

set dobuild=
if "%isexists%" == "" (set dobuild=y)

if "%doforcebuild%" == "forcebuild" (set dobuild=y)
if "%dobuild%" == "y" (docker build . -t %name%)


set currdir=%cd%
docker run -it --rm --net=host --dns=192.168.110.10 --dns=127.0.0.53 --dns-search=localdomain -v %currdir%:/root/ -v /var/run/docker.sock:/var/run/docker.sock --name %name% %name%
PAUSE
