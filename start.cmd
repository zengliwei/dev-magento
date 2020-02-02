@echo off

cd /d %~dp0

::::
:: Collect project variables
::
set projectName=%dirName%
for /f "tokens=1,2 delims==" %%i in ( .env ) do (
  if %%i == COMPOSE_PROJECT_NAME (
    set projectName=%%j
  ) else if %%i == DOMAIN (
    set domain=%%j
  ) else if %%i == DB_NAME (
    set dbName=%%j
  ) else if %%i == DB_USER (
    set dbUser=%%j
  ) else if %%i == DB_PSWD (
    set dbPass=%%j
  )
)

::::
:: Start project containers if created, otherwise create them
::
for /f "skip=1" %%c in ( 'docker ps -a --filter "name=%projectName%_web"' ) do (
  if not %%c == '' (
    call :START_PROJECT
    exit
  )
)
call :BUILD_PROJECT
exit


::::
:: Start containers
::
:START_PROJECT

  rename ..\..\config\router\%domain% %domain%.conf
  docker-compose start
  docker exec dev_router /usr/sbin/service nginx reload

goto :EOF


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
  if %hostMappingSet% == 0 (
    echo.>> %SystemRoot%\System32\drivers\etc\hosts
    echo.>> %SystemRoot%\System32\drivers\etc\hosts
    echo 127.0.0.1 %domain%>> %SystemRoot%\System32\drivers\etc\hosts
    echo 127.0.0.1 elastic.%domain%>> %SystemRoot%\System32\drivers\etc\hosts
    echo 127.0.0.1 rabbitmq.%domain%>> %SystemRoot%\System32\drivers\etc\hosts
  )

  ::::
  :: Create proxy config file
  ::
  for /f "tokens=1* delims=:" %%k in ( 'findstr /n .* .\config\proxy.conf' ) do (
    set "line=%%l"
    setLocal enableDelayedExpansion
    if "!line!" == "" (
      echo.>> proxy.conf.tmp
    ) else (
      set line=!line:magento_project_name=%projectName%!
      set line=!line:magento_project_domain=%domain%!
      echo !line!>> proxy.conf.tmp
    )
    endLocal
  )
  move proxy.conf.tmp ..\..\config\router\%domain%

  ::::
  :: Create containers
  ::
  docker-compose up --no-recreate -d

  ::::
  :: Modify config file of phpMyAdmin
  ::
  set phpMyAdminSet=0
  for /f "tokens=1,2 delims==> " %%i in ( 'findstr /c:"%projectName%_mysql" ..\..\config\phpmyadmin\config.user.inc.php' ) do (
    if "%%j" == "'%projectName%_mysql'," set phpMyAdminSet=1
  )
  if %phpMyAdminSet% == 0 (
    echo.>> ..\..\config\phpmyadmin\config.user.inc.php
    echo $cfg['Servers'][] = [>> ..\..\config\phpmyadmin\config.user.inc.php
    echo     'auth_type' =^> 'config',>> ..\..\config\phpmyadmin\config.user.inc.php
    echo     'host'      =^> '%projectName%_mysql',>> ..\..\config\phpmyadmin\config.user.inc.php
    echo     'user'      =^> '%dbUser%',>> ..\..\config\phpmyadmin\config.user.inc.php
    echo     'password'  =^> '%dbPass%'>> ..\..\config\phpmyadmin\config.user.inc.php
    echo ];>> ..\..\config\phpmyadmin\config.user.inc.php
  )

  ::::
  :: Import data
  ::
  for /f %%f in ( 'dir /b src' ) do (
    set "file=%%f"
    setLocal enableDelayedExpansion
    if !file:~-4! == .tar (
      call :COPY_FILE_TO_CONTAINER ".\src" !file! %projectName%_web "/var/www/current"
      docker exec %projectName%_web tar -xvf /var/www/current/!file! -C /var/www/current

    ) else if !file:~-7! == .tar.gz (
      call :COPY_FILE_TO_CONTAINER ".\src" !file! %projectName%_web "/var/www/current"
      docker exec %projectName%_web tar -zxvf /var/www/current/!file! -C /var/www/current
    )
    endLocal
  )

  call :START_PROJECT

goto :EOF


::::
:: Copy file to docker container and make sure it is completely
::
:COPY_FILE_TO_CONTAINER
  set srcDir=%~1&& set fileName=%~2&& set container=%~3&& set distDir=%~4
  for /f "delims=" %%i in ( 'dir /s/b %srcDir%\%fileName%' ) do set fileSize=%%~zi
  docker cp %srcDir%\%fileName% %container%:%distDir%
  :loopCopyFile
  for /f %%s in ( 'docker exec -it %container% wc -c %distDir%/%fileName%' ) do (
    if not %%s == %fileSize% (
      ping -n 3 127.0.0.1>nul
      goto loopCopyFile
    )
  )
goto :EOF