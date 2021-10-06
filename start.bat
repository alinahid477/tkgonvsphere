@ECHO OFF
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& './converter.ps1'"
set isexists=
FOR /F "delims=" %%i IN ('docker images  ^| findstr /i "%1"') DO set "isexists=%%i"
echo "%isexists%"

set dobuild=
if "%isexists%" == "" (set dobuild=y)
set param2=%2
if NOT "%param2%"=="%param2:forcebuild=%" (set dobuild=y)
if "%dobuild%" == "y" (docker build . -t %1)

set currdir=%cd%
docker run -it --rm --net=host --dns=192.168.110.10 --dns=127.0.0.53 --dns-search=localdomain -v %currdir%:/root/ -v /var/run/docker.sock:/var/run/docker.sock --name %1 %1
PAUSE
