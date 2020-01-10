@echo off

docker-compose stop

set /p domain=<domain
rename "..\..\config\router\%domain%.conf" "%domain%"

docker exec dev_router /usr/sbin/service nginx reload
