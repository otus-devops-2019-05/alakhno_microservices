# alakhno_microservices

[![Build Status](https://travis-ci.com/otus-devops-2019-05/alakhno_microservices.svg?branch=master)](https://travis-ci.com/otus-devops-2019-05/alakhno_microservices)

# ДЗ - Занятие 16

## 1. Dockerfile Linter

Линтер проверяет докерфайлы на следование [рекомендуемым практикам](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/):

 ```shell script
 docker run --rm -i hadolint/hadolint < Dockerfile
```

## 2. Запуск приложения

Создаём docker-host и подключаемся к нему:
```shell script
export GOOGLE_PROJECT=<id проекта>

docker-machine create --driver google \
  --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts \
  --google-machine-type n1-standard-1 \
  --google-zone europe-west1-b \
  docker-host

eval $(docker-machine env docker-host)
```

Собираем образы с сервисами:
```shell script
docker build -t alakhno88/post:1.0 ./post-py
docker build -t alakhno88/comment:1.0 ./comment
docker build -t alakhno88/ui:1.0 ./ui
```

Создаём сеть для приложения:
```shell script
docker network create reddit
```

Зарускаем контейнеры с приложением:
```shell script
docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db mongo:latest
docker run -d --network=reddit --network-alias=post alakhno88/post:1.0
docker run -d --network=reddit --network-alias=comment alakhno88/comment:1.0
docker run -d --network=reddit -p 9292:9292 alakhno88/ui:1.0
```

## 3. Запуск контейнеров с другими сетевыми алиасами

```shell script
docker run -d --network=reddit \
    --network-alias=post2_db \
    --network-alias=comment2_db \
    mongo:latest

docker run -d --network=reddit \
    --network-alias=post2 \
    -e "POST_DATABASE_HOST=post2_db" \
    alakhno88/post:1.0

docker run -d --network=reddit \
    --network-alias=comment2 \
    -e "COMMENT_DATABASE_HOST=comment2_db" \
    alakhno88/comment:1.0

docker run -d --network=reddit \
    -p 9292:9292 \
    -e "POST_SERVICE_HOST=post2" \
    -e "COMMENT_SERVICE_HOST=comment2" \
    alakhno88/ui:1.0
```

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
export GOOGLE_PROJECT=<id проекта>

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
## 4. Повторение из демо на лекции

**PID namespace (изоляция процессов)**

Заходим на созданный docker-host
```shell script
gcloud compute ssh root@docker-host
```

Запускаем контейнер и смотрим PID'ы процессов в namespace'е контейнера.
Процессы хоста при этом не видны.
```shell script
root@docker-host:~# docker run --rm -it ubuntu:latest bash
root@e17558fd9ec5:/# sleep 1000 &
[1] 12
root@e17558fd9ec5:/# ps auxf
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.8  0.0  18508  3452 pts/0    Ss   10:24   0:00 bash
root        12  0.0  0.0   4532   848 pts/0    S    10:25   0:00 sleep 1000
root        13  0.0  0.0  34400  2996 pts/0    R+   10:25   0:00 ps auxf
```

Те же процессы bash и sleep в namespace'е хоста видны, но имеют другие PID'ы.
```shell script
root@docker-host:~# ps auxf
...
root      4597  0.1  1.2 562292 46176 ?        Ssl  10:21   0:00 /usr/bin/containerd
root      6154  0.0  0.1 108756  5252 ?        Sl   10:24   0:00  \_ containerd-shim -namespace moby -workdir /var/lib/containerd/io.containerd.runtime.v1.linux/moby/e17558fd9ec58414b9e8491f265598f23af3c6
root      6185  0.1  0.0  18508  3452 pts/0    Ss+  10:24   0:00      \_ bash
root      6256  0.0  0.0   4532   848 pts/0    S    10:25   0:00          \_ sleep 1000

root@docker-host:~# pstree 4597
containerd─┬─containerd-shim─┬─bash───sleep
           │                 └─10*[{containerd-shim}]
           └─8*[{containerd}]
```

**net namespace (изоляция сети)**

Создаём первый контейнер и смотрим в его net namespace сетевые интерфейсы.
У eth0 адрес 172.17.0.2.
```shell script
root@docker-host:~# docker run --rm -it ubuntu:latest bash
root@2cc4fef2d0d6:/# apt update
root@2cc4fef2d0d6:/# apt install net-tools
root@2cc4fef2d0d6:/# ifconfig
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.17.0.2  netmask 255.255.0.0  broadcast 172.17.255.255
        ether 02:42:ac:11:00:02  txqueuelen 0  (Ethernet)
        RX packets 786  bytes 17253056 (17.2 MB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 443  bytes 33651 (33.6 KB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
...
```

Создаём второй контейнер и смотрим в его net namespace сетевые интерфейсы.
У eth0 адрес 172.17.0.3.
```shell script
root@docker-host:~# docker run --rm -it ubuntu:latest bash
root@5d52bcc7ba20:/# apt update
root@5d52bcc7ba20:/# apt install net-tools
root@5d52bcc7ba20:/# ifconfig
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.17.0.3  netmask 255.255.0.0  broadcast 172.17.255.255
        ether 02:42:ac:11:00:03  txqueuelen 0  (Ethernet)
        RX packets 788  bytes 17253136 (17.2 MB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 439  bytes 33387 (33.3 KB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
...
```

В net namespace хоста docker-host при этом видны мост docker0 той же подсети
с адресом 172.17.0.1 и два виртуальных ethernet'а vethab1c06b и vethc34c69e,
через которые идёт общение с интерфейсами eth0 контейнеров.
```shell script
root@docker-host:~# ifconfig
docker0   Link encap:Ethernet  HWaddr 02:42:80:f9:6e:c5  
          inet addr:172.17.0.1  Bcast:172.17.255.255  Mask:255.255.0.0
          inet6 addr: fe80::42:80ff:fef9:6ec5/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:882 errors:0 dropped:0 overruns:0 frame:0
          TX packets:1571 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:54690 (54.6 KB)  TX bytes:34505886 (34.5 MB)
...

vethab1c06b Link encap:Ethernet  HWaddr 96:12:de:69:a5:99  
          inet6 addr: fe80::9412:deff:fe69:a599/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:439 errors:0 dropped:0 overruns:0 frame:0
          TX packets:789 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:33387 (33.3 KB)  TX bytes:17253206 (17.2 MB)

vethc34c69e Link encap:Ethernet  HWaddr 72:82:fe:20:b4:cf  
          inet6 addr: fe80::7082:feff:fe20:b4cf/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:443 errors:0 dropped:0 overruns:0 frame:0
          TX packets:789 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:0 
          RX bytes:33651 (33.6 KB)  TX bytes:17253238 (17.2 MB)
```

Соответствие между мостом docker0 и виртуальными ethernet'ами контейнеров
можно посмотреть следующим образом:
```shell script
root@docker-host:~# brctl show docker0
bridge name	bridge id		STP enabled	interfaces
docker0		8000.024280f96ec5	no		vethab1c06b
							vethc34c69e
```

**Указание PID namespace при запуске контейнера**

По умолчанию при запуске контейнера создаётся отдельный PID namespace.
Поэтому следующая команда покажет только процесс htop с PID=1:
```shell script
docker run --rm -ti tehbilly/htop
```

При помощи параметра `--pid host` можно запустить контейнер с PID namespace
хоста, - тогда из контейнера будет доступ к процессам на хосте:
```shell script
docker run --rm --pid host -ti tehbilly/htop
```
## 5. Работа с Docker Hub

Собираем образ:
```shell script
 docker build -t reddit:latest .
```

Логинимся и загружаем образ на Docker Hub:
```shell script
docker login
docker tag reddit:latest alakhno88/otus-reddit:1.0
docker push alakhno88/otus-reddit:1.0
```

Запускаем контейнер на основе образа:
```shell script
 docker run --name reddit -d -p 9292:9292 alakhno88/otus-reddit:1.0
```
## 6. Поднятие инстансов с помощью Terraform

В `docker-monolith/infra/terraform/main.tf` описана конфигурация для поднятия
заданного количества инстансов и правила файервола для открытия порта 9292, на
котором работает приложение.

```shell script
cd docker-monolith/infra/terraform
terraform init
terraform apply -var 'instance_count=2'
```
## 7. Плейбуки Ansible для уставноки докера и запуска образа приложения

Установка докера и деплой приложения

```shell script
cd docker-monolith/infra/ansible
ansible-playbook playbooks/install_docker.yml
ansible-playbook playbooks/deploy_app.yml
```

## 8. Шаблон Packer для образа с установленным Docker

Собираем образ docker-base с установленным Docker:
```shell script
cd docker-monolith/infra
packer build -var-file=packer/variables.json packer/docker.json
```
Создаём пару инстансов на основе собранного образа:
```shell script
cd docker-monolith/infra/terraform
terraform apply -var 'instance_image=docker-base' -var 'instance_count=2'
```

Деплоим приложение на созданные инстансы:
```shell script
cd docker-monolith/infra/ansible
ansible-playbook playbooks/deploy_app.yml
```
