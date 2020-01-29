@echo off
setLocal enableDelayedExpansion

cd /d %~dp0

::::
:: Collect project name and domain
::
set projectName=%dirName%
for /f "tokens=1,2 delims==" %%i in ( .env ) do (
  if %%i == COMPOSE_PROJECT_NAME (
    set projectName=%%j
  ) else if %%i == DOMAIN (
    set domain=%%j
  )
)

::::
:: Start project containers if created, otherwise create them
::
for /f "skip=1" %%c in ( 'docker ps -a --filter "name=%projectName%_web"' ) do (
  if not %%c == '' goto START_PROJECT
)
goto BUILD_PROJECT


::::
:: Start containers
::
:START_PROJECT
rename ..\..\config\router\%domain% %domain%.conf
docker-compose start
docker exec dev_router /usr/sbin/service nginx reload
exit


::::
:: Build project
::
:BUILD_PROJECT

::::
:: Add host mapping
::
set hostMappingSet=0
for /f "tokens=1,2" %%i in ( %SystemRoot%\System32\drivers\etc\hosts ) do (
  if %%j == %domain% set hostMappingSet=1
)
if %hostMappingSet% == 1 exit
echo. >> %SystemRoot%\System32\drivers\etc\hosts
echo. >> %SystemRoot%\System32\drivers\etc\hosts
echo 127.0.0.1 %domain% >> %SystemRoot%\System32\drivers\etc\hosts
echo 127.0.0.1 elastic.%domain% >> %SystemRoot%\System32\drivers\etc\hosts
echo 127.0.0.1 rabbitmq.%domain% >> %SystemRoot%\System32\drivers\etc\hosts

::::
:: Create proxy config file
::
for /f "delims=" %%l in ( proxy.conf ) do (
  set var=%%l
  set var=!var:magento_project_name=%projectName%!
  set var=!var:magento_project_domain=%domain%!
  echo !var! >> proxy.conf.tmp
)
move proxy.conf.tmp ..\..\config\router\%domain%

::::
:: Create containers
::
docker-compose up --no-recreate -d

goto START_PROJECT