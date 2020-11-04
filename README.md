# Magento development environment with Docker Compose


## Preparedness

- You may need to change the **APT_SOURCE_URL** in `.env` before building.


## Images

- **elasticsearch:7.9.2**
- **kibana:7.9.2**
- **mysql:5.7**
- **redis:latest**
- **varnish:latest**
- custom built image from **rabbitmq:management** with some default config
- custom built image from **php:7.4-fpm** with:
    - php 7.4
    - composer
    - git
    - nginx
    - ssh