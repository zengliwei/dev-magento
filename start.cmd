@echo off
setLocal enableDelayedExpansion

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
  for /f "tokens=1* delims=:" %%k in ( ./config/proxy.conf ) do (
    set line=%%l
    if "%%l" == "" (
      echo.>> proxy.conf.tmp
    ) else (
      set var=!var:magento_project_name=%projectName%!
      set var=!var:magento_project_domain=%domain%!
      echo !line!>> proxy.conf.tmp
    )
  )
  move proxy.conf.tmp ..\..\config\router\%domain%

  ::::
  :: Rebuild Varnish config file
  ::
  for /f "tokens=1* delims=:" %%k in ( 'findstr /n .* .\config\varnish\default.vcl' ) do (
    set line=%%l
    if "%%l" == "" (
      echo.>> default.vcl.tmp
    ) else (
      if "%%l" == "    .host = "127.0.0.1";" (
        set line=!line:127.0.0.1=%projectName%_varnish!
      )
      echo !line!>> default.vcl.tmp
    )
  )
  move default.vcl.tmp ./config/varnish/default.vcl

  ::::
  :: Create containers
  ::
  docker-compose up --no-recreate -d

  ::::
  :: Modify config file of phpMyAdmin
  ::
  echo.>> ..\..\config\phpmyadmin\config.user.inc.php
  echo $cfg['Servers'][] = [>> ..\..\config\phpmyadmin\config.user.inc.php
  echo     'auth_type' =^> 'config',>> ..\..\config\phpmyadmin\config.user.inc.php
  echo     'host'      =^> '%projectName%_mysql',>> ..\..\config\phpmyadmin\config.user.inc.php
  echo     'user'      =^> '%dbUser%',>> ..\..\config\phpmyadmin\config.user.inc.php
  echo     'password'  =^> '%dbPass%'>> ..\..\config\phpmyadmin\config.user.inc.php
  echo ];>> ..\..\config\phpmyadmin\config.user.inc.php

  ::::
  :: Import data
  ::
  for /f %%f in ( 'dir /b src' ) do (
    set file=%%f
    if !file:~-4! == .tar (
      :: Make sure the source file is completely copied to container before import
      for /f "delims=" %%i in ( 'dir /s/b .\src\!file!' ) do set fileSize=%%~zi
      docker cp .\src\!file! %projectName%_web:/var/www/current/
      :loopCopyTarFile
      for /f %%s in ( 'docker exec -it %projectName%_web wc -c /var/www/current/!file!' ) do (
        if not %%s == !fileSize! (
          ping -n 3 127.0.0.1>nul
          goto loopCopyTarFile
        )
      )
      docker exec %projectName%_web tar -xvf /var/www/current/!file! -C /var/www/current

    ) else if !file:~-7! == .tar.gz (
      :: Make sure the source file is completely copied to container before import
      for /f "delims=" %%i in ( 'dir /s/b .\src\!file!' ) do set fileSize=%%~zi
      docker cp .\src\!file! %projectName%_web:/var/www/current/
      :loopCopyTarGzFile
      for /f %%s in ( 'docker exec -it %projectName%_web wc -c /var/www/current/!file!' ) do (
        if not %%s == !fileSize! (
          ping -n 3 127.0.0.1>nul
          goto loopCopyTarGzFile
        )
      )
      docker exec %projectName%_web tar -zxvf /var/www/current/!file! -C /var/www/current
    )
  )

  call :START_PROJECT

goto :EOF