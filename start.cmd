@echo off

docker-compose start

set /p domain=<domain
rename "..\..\config\router\%domain%" "%domain%.conf"

docker exec dev_router /usr/sbin/service nginx reload
