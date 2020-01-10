# Magento development environment with Docker Compose


## Preparedness

- You may need to change the **APT_SOURCE_URL** in `.env` before building.


## Images

- **mysql:5.7**
- **redis:latest**
- custom built image from **php:7.2-fpm** with:
    - php 7.2
    - nginx
    - ssh
