@echo off
setLocal enableDelayedExpansion

cd /d %~dp0

::::
:: Get project folder name and goto the project directory
::
set projectDir=%cd%
cd ..
set parentDir=%cd%
for /f %%f in ( 'dir /b %parentDir%' ) do (
  if %parentDir%\%%f == %projectDir% (
    set dirName=%%f
  )
)
cd %dirName%

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
for /f "skip=1" %%c in ( 'docker ps -a --filter "name=%dirName%_web"' ) do (
  if not %%c == '' goto START_PROJECT
)
goto CREATE_CONTAINERS


::::
:: Start containers
::
:START_PROJECT
rename ..\..\config\router\%domain% %domain%.conf
docker-compose start
docker exec dev_router /usr/sbin/service nginx reload
exit


::::
:: Create containers
::
:CREATE_CONTAINERS
for /f "delims=" %%l in ( proxy.conf ) do (
  set var=%%l
  set var=!var:magento_project_name=%projectName%!
  set var=!var:magento_project_domain=%domain%!
  echo !var! >> proxy.conf.tmp
)
move proxy.conf.tmp ..\..\config\router\%domain%
docker-compose up --no-recreate -d
goto START_PROJECT