# alakhno_microservices

[![Build Status](https://travis-ci.com/otus-devops-2019-05/alakhno_microservices.svg?branch=master)](https://travis-ci.com/otus-devops-2019-05/alakhno_microservices)

# ДЗ - Занятие 15

## 1. Первоначальная настройка репозитория

1. Добавлен шаблон описания PR в .github/PULL_REQUEST_TEMPLATE.md
1. Доблена интеграция канала Slack с репозиторием при помощи команды-сообщения:
    ```
    /github subscribe Otus-DevOps-2019-05/alakhno_microservices commits:all
    ```
1. Настроена интеграция с TravisCI.

## 2. Сравнение контейнеров и образов

Список образов
```shell script
docker images
```

Список запущенных контенеров
```shell script
docker ps --format "table {{.ID}}\t{{.Image}}\t{{.CreatedAt}}\t{{.Names}}"
```

Сравниваем контейнер с образом:
```shell script
docker inspect <u_container_id>
docker inspect <u_image_id>
```
## 3. Работа с docker-machine в GCE

Создание хоста в GCE
```shell script
docker-machine create --driver google \
  --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts \
  --google-machine-type n1-standard-1 \
  --google-zone europe-west1-b \
  docker-host
```

Вывод списка хостов
```shell script
docker-machine ls
```

Переключение на хост по имени
```shell script
eval $(docker-machine env docker-host)
```

Переключение на локальный докер
```shell script
eval $(docker-machine env --unset)
```

Удаление хоста по имени
```shell script
docker-machine rm docker-host
```
