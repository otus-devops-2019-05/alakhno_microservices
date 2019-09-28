# alakhno_microservices

[![Build Status](https://travis-ci.com/otus-devops-2019-05/alakhno_microservices.svg?branch=master)](https://travis-ci.com/otus-devops-2019-05/alakhno_microservices)

# ДЗ - Занятие 21

## 1. Подготовка окружения

Подготовка окружения:

```shell script
export GOOGLE_PROJECT=<id проекта>

docker-machine create --driver google \
    --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts \
    --google-machine-type n1-standard-1 \
    --google-zone europe-west1-b \
    docker-host

eval $(docker-machine env docker-host)
``` 

Выносим конфигурацию мониторинга из `docker-compose.yml` в `docker-compose-monitoring.yml`:

```shell script
cd docker

# запуск приложений
docker-compose up -d

# запуск мониторинга
docker-compose -f docker-compose-monitoring.yml up -d
```

## 2. Подключение cAdvisor для мониторинга контейнеров

https://github.com/google/cadvisor

В `docker-compose-monitoring.yml` добавляем сервис `cadvisor`:
```yaml
  cadvisor:
    image: google/cadvisor:v0.29.0
    volumes:
      - '/:/rootfs:ro'
      - '/var/run:/var/run:rw'
      - '/sys:/sys:ro'
      - '/var/lib/docker/:/var/lib/docker:ro'
    ports:
      - '8080:8080'
    networks:
      - back-net
      - front-net
```

В конфиг `prometheus.yml` добавляем:
```yaml
  - job_name: 'cadvisor'
    static_configs:
      - targets:
        - 'cadvisor:8080'
```

Пересобираем образ Prometheus:
```shell script
make prometheus
```

Добавляем правило фаервола для cAdvisor:
```shell script
gcloud compute firewall-rules create cadvisor-default --allow tcp:8080
```

Перезапускаем мониторинг:
```shell script
cd docker
docker-compose -f docker-compose-monitoring.yml down
docker-compose -f docker-compose-monitoring.yml up -d
```

cAdvisor доступен по адресу http://<docker-host>:8080

## 3. Визуализация метрик при помощи Grafana

В `docker-compose-monitoring.yml` добавляем сервис `grafana`:

```shell script
  grafana:
    image: grafana/grafana:5.0.0
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=secret
    depends_on:
      - prometheus
    ports:
      - 3000:3000
    networks:
      - back-net
```

Добавляем правило фаервола для Grafana:
```shell script
gcloud compute firewall-rules create grafana-default --allow tcp:3000
```

Grafana доступна по адресу http://<docker-host>:3000

Имопртируем в Grafana дашборд https://grafana.com/grafana/dashboards/893
для мониторинга докера и системы.

## 4. Мониторинг работы приложения

Сервис ui в качестве метрик приложения отдаёт счётчик `ui_request_count`
с количеством приходящих запросов и гистограмму `ui_request_latency_seconds`
с информацией о времени обработки запросов.

Сервис post в качестве метрики приложения отдаёт гистограмму
`post_read_db_seconds` с информацией о времени поиска поста в БД.

В конфиг `prometheus.yml` добавляем сбор информации с сервиса post:
```yaml
  - job_name: 'post'
    static_configs:
      - targets:
        - 'post:5000'
```

Пересобираем образ prometheus и пересоздаём инфраструктуру мониторинга:
```shell script
make prometheus
cd docker
docker-compose -f docker-compose-monitoring.yml down 
docker-compose -f docker-compose-monitoring.yml up -d
```

Через интерфейс Grafana добавил графики по сервису UI для общего количества
запросов в минуту и количества запросов с ошибками в минуту:
- `rate(ui_request_count[1m])`
- `rate(ui_request_count{http_status=~"^[45].*""}[1m])`

Добавим график с 95й процентилью времени ответа на запрос:
`histogram_quantile(0.95, sum(rate(ui_request_response_time_bucket[5m])) by (le))`

## 5. Мониторинг бизнес-логики

Создаём дашборд Business_Logic_Monitoring с графиками количества постов
и комментов за последний час:
- `rate(post_count[1h])`
- `rate(comment_count[1h])`

## 6. Алертинг при помощи Alertmanager

В `monitoring/alertmanager` добавляем `config.yml` для Alertmanager.
Также добавляем `Dockerfile` для сборки образа alertmanager с нашим конфигом.

Собираем образ:
```shell script
cd monitoring/alertmanager
docker build -t $USER_NAME/alertmanager .
```

В `docker-compose-monitoring.yml` добавляем сервис `alertmanager`:

```shell script
  alertmanager:
    image: ${USER_NAME}/alertmanager
    command:
      - '--config.file=/etc/alertmanager/config.yml'
    ports:
      - 9093:9093
    networks:
      - back-net
```

Добавляем файл `monitoring/prometheus/alerts.yml` с правилами алертинга.
Отправляем алерт, если какой-то из сервисов выпал более, чем на одну минуту.

Прописываем копирование `alerts.yml` в `monitoring/prometheus/Dockerfile`.
Добавляем информацию о правилах в конфиг `monitoring/prometheus/prometheus.yml`.

Пересобираем образ prometheus и пересоздаём инфраструктуру мониторинга:
```shell script
make prometheus
cd docker
docker-compose -f docker-compose-monitoring.yml down
docker-compose -f docker-compose-monitoring.yml up -d
```

Добавляем правило фаервола для веб интерфейса alertmanager:
```shell script
gcloud compute firewall-rules create alertmanager-default --allow tcp:9093
```

## 7. Собираем и пушим образы на DockerHub при помощи make

Добавляем в Makefile цели для сборки и пуша docker образа alertmanager.

Собранные образы запушены в репозиторий https://cloud.docker.com/u/alakhno88/

## 8. Передача метрик из Docker в Prometheus

Что почитать:
- https://docs.docker.com/config/thirdparty/prometheus/
- https://medium.com/@basi/docker-swarm-metrics-in-prometheus-e02a6a5745a

Подключаем отдачу метрик в Docker:
```shell script
docker-machine ssh docker-host
sudo vim /etc/docker/daemon.json
{
  "metrics-addr" : "0.0.0.0:9323",
  "experimental" : true
}
sudo service docker restart 
```

Добавляем правило фаервола для внешнего доступа к метрикам:
```shell script
gcloud compute firewall-rules create docker-metrics-default --allow tcp:9323
curl http://$(docker-machine ip docker-host):9323/metrics
```

В конфиг `prometheus.yml` добавляем сбор информации с Docker:
```yaml
  - job_name: 'docker-engine-metrics'
    static_configs:
      - targets:
        - '172.17.0.1:9323'
```
Для доступа к метрикам из Docker используем адрес бриджа docker0 172.17.0.1.

Пересобираем образ prometheus и пересоздаём инфраструктуру мониторинга:
```shell script
make prometheus
cd docker
docker-compose -f docker-compose-monitoring.yml down 
docker-compose -f docker-compose-monitoring.yml up -d
```

Для визуализации метрик docker-engine-metrics в Grafana можно использовать
готовый дашобрд https://grafana.com/grafana/dashboards/1229

Метрик пока значительно меньше, чем в cAdvisor. Сейчас есть только метрики
до docker демону, но нет ничего для мониторинга состояния контейнеров.

# ДЗ - Занятие 20

## 1. Запуск Prometheus

Добавляем правила фаервола для Prometheus и Puma:
```shell script
gcloud compute firewall-rules create prometheus-default --allow tcp:9090
gcloud compute firewall-rules create puma-default --allow tcp:9292
```

Создаём хост:
```shell script
export GOOGLE_PROJECT=<id проекта>

docker-machine create --driver google \
    --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts \
    --google-machine-type n1-standard-1 \
    --google-zone europe-west1-b \
    docker-host

eval $(docker-machine env docker-host)
```

Запускаем Prometheus:
```shell script
docker run --rm -p 9090:9090 -d --name prometheus  prom/prometheus
docker-machine ip docker-host
docker stop prometheus
``` 

## 2. Мониторинг состояния микросервисов

Создаём docker образ для Prometheus с нашим конфигом:
```shell script
cd monitoring/prometheus
export USER_NAME=alakhno88
docker build -t $USER_NAME/prometheus .
```

Собираем образы docker образы микросервисов:
```shell script
for i in ui post-py comment; do cd src/$i; bash docker_build.sh; cd -; done
```

Добавляем в `docker/docker-compose.yml` сервис `prometheus`:
```yaml
services:
  ...
  prometheus:
    image: ${USER_NAME}/prometheus
    ports:
      - '9090:9090'
    volumes:
      - prometheus_data:/prometheus
    networks:
      - back-net
      - front-net
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention=1d'
```

Запускаем микросервисы и Prometheus:
```shell script
cd docker
docker-compose up -d
```

## 3. Сбор метрик хоста

Для сбора метрик хоста и их отдаче в Prometheus можно использовать Node экспортёр:
https://github.com/prometheus/node_exporter

Для этого в `docker-compose.yml` добавляем сервис `node-exporter`:
```yaml
  node-exporter:
    image: prom/node-exporter:v0.15.2
    user: root
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    networks:
      - back-net
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.ignored-mount-points="^/(sys|proc|dev|host|etc)($$|/)"'
```

А в конфиг `prometheus.yml` добавляем:
```yaml
  - job_name: 'node'
    static_configs:
      - targets:
        - 'node-exporter:9100'
```

Пересобираем docker образ Prometheus с обновлённым конфигом и перезапускаем сервисы:
```shell script
cd monitoring/prometheus/
docker build -t $USER_NAME/prometheus .

cd docker
docker-compose down
docker-compose up -d
```

## 4. Пушим образы на DockerHub

```shell script
docker push $USER_NAME/ui
docker push $USER_NAME/comment
docker push $USER_NAME/post
docker push $USER_NAME/prometheus
```

Собранные образы запушены в репозиторий https://cloud.docker.com/u/alakhno88/

## 5. Мониторинг MongoDB

Для мониторинга MongoDB можно использовать экспортёр https://github.com/percona/mongodb_exporter

Собираем docker-образ экспортёра для MongoDB:
```shell script
git clone git@github.com:percona/mongodb_exporter.git
cd mongodb_exporter
docker build -t $USER_NAME/mongodb_exporter .
```

В `docker-compose.yml` добавляем сервис `mongodb-exporter`:
```yaml
  mongodb-exporter:
    image: ${USER_NAME}/mongodb-exporter
    environment:
      - MONGODB_URI=mongodb://mongo_db:27017
    networks:
      - back-net
```
В конфиг `prometheus.yml` добавляем:
```yaml
  - job_name: 'mongodb'
    static_configs:
      - targets:
        - 'mongodb-exporter:9216'
```

Пересобираем docker образ Prometheus с обновлённым конфигом и перезапускаем сервисы:
```shell script
cd monitoring/prometheus/
docker build -t $USER_NAME/prometheus .

cd docker
docker-compose down
docker-compose up -d
```

## 6. Мониторинг сервисов с помощью blackbox экспортера

В `docker-compose.yml` добавляем сервис `mongodb-exporter`:
```yaml
  blackbox-exporter:
    image: prom/blackbox-exporter:v0.15.1
    networks:
      - back-net
      - front-net
```

В конфиг `prometheus.yml` добавляем:
```yaml
  - job_name: 'blackbox-http'
    metrics_path: /probe
    params:
      module:
        - http_2xx
    static_configs:
      - targets:
          - 'comment:9292/healthcheck'
          - 'post:5000/healthcheck'
          - 'ui:9292'
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: blackbox-exporter:9115
```

Пересобираем docker образ Prometheus с обновлённым конфигом и перезапускаем сервисы:
```shell script
cd monitoring/prometheus/
docker build -t $USER_NAME/prometheus .

cd docker
docker-compose down
docker-compose up -d
```

## 7. Makefile для сборки и пуша docker образов

Для сборки образов добавлены цели `build-all`, `build-comment`, `build-post` и `build-prometheus`.

Для пуша образов добавлены цели `push-all`,  `push-comment`, `push-post` и `push-prometheus`.

Чтобы собрать и загрузить на DockerHub все образы надо выполнить:

```shell script
make build-all
make push-all
```

# ДЗ - Занятие 19

## 1. Установка Gitlab CI

Создаём машинку с докером для последующей установки Gitlab CI:
```shell script
export GOOGLE_PROJECT=<id проекта>

docker-machine create --driver google \
  --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts \
  --google-machine-type n1-standard-1 \
  --google-disk-size 100 \
  --google-disk-type pd-standard \
  --google-zone europe-west1-b \
  gitlab-host

eval $(docker-machine env gitlab-host)
```

Устанаваливаем docker-compose и подготавливаем окружение:
```shell script
docker-machine ssh gitlab-host
sudo curl -L "https://github.com/docker/compose/releases/download/1.24.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

sudo mkdir -p /srv/gitlab/config /srv/gitlab/data /srv/gitlab/logs
cd /srv/gitlab/
# Создаём docker-compose.yml, прописывая свой external_url 'http://<YOUR-VM-IP>'
# https://gist.github.com/Nklya/c2ca40a128758e2dc2244beb09caebe1
sudo vim docker-compose.yml
```

Запускаем Gitlab CI:
```shell script
sudo docker-compose up -d
```

Установленный Gitlab будет доступен по адресу машинки gitlab-host.

## 2. Установка и регистрация Gitlab Runner'а

```shell script
docker-machine ssh gitlab-host
sudo usermod -aG docker $USER
docker run -d --name gitlab-runner --restart always \
  -v /srv/gitlab-runner/config:/etc/gitlab-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitlab/gitlab-runner:latest
docker exec -it gitlab-runner gitlab-runner register --run-untagged --locked=false 
```

## 3. Тестируем reddit

Добавим reddit в репозиторий:
```shell script
git clone https://github.com/express42/reddit.git && rm -rf ./reddit/.git
```

В .gitlab-ci.yml:
1. Указываем `image: ruby:2.4.2` для запуска job'ов.
1. Задаём переменную с адресом БД:
    ```yaml
    variables:
      DATABASE_URL: 'mongodb://mongo/user_posts'
    ```
1. Прописываем установку reddit перед запуском job'ов:
    ```yaml
    before_script:
      - cd reddit
      - bundle install
    ```
1. Описываем запуск дополнительного контейнера с БД и запуск тестов:
    ```yaml
    test_unit_job:
      stage: test
      services:
        - mongo:latest
      script:
        - ruby simpletest.rb
    ```

## 4. Работа с окружениями

Добавляем dev-окружение:
```yaml
deploy_dev_job:
  stage: review
  script:
    - echo 'Deploy'
  environment: 
    name: dev
    url: http://dev.example.com
```

Добавляем окружения stage и production:
```yaml
staging:
  stage: stage
  when: manual
  script: 
    - echo 'Deploy'
  environment: 
    name: stage
    url: https://beta.example.com
    
production:
  stage: production
  when: manual
  script: 
    - echo 'Deploy'
  environment: 
    name: production
    url: https://example.com
```

При помощи `only` можно отключить возможность выкатки на stage и production
непротегированных изменений. Должен стоять semver тэг в git, например, 2.4.10:
```yaml
staging:
  stage: stage
  when: manual
  only:
    - /^\d+\.\d+\.\d+/
  ...
```

Изменение без указания тэга запустят пайплайн без job'ов staging и production.
Изменение, помеченное тэгом в git запустит полный пайплайн:
```yaml
git tag 2.4.10
git push gitlab gitlab-ci-1 --tags
```

## 5. Динамические окружения

Выкатка на выделенный стенд для каждой ветки при помощи динамических окружений:
```yaml
branch review:
  stage: review
  script: echo "Deploy to $CI_ENVIRONMENT_SLUG"
  environment: 
    name: branch/$CI_COMMIT_REF_NAME
    url: http://$CI_ENVIRONMENT_SLUG.example.com
  only:
    - branches
  except: 
    - master
```

## 6. Сборка образа с приложением reddit

В папку `reddit` по аналогии с `docker-monolith` добавлены: `Dockerfile`,
`db_config`, `mongod.conf` и `start.sh`. 

Для сборки образа с приложением в документации Gitlab предлагается несколько
подходов: https://docs.gitlab.com/ce/ci/docker/using_docker_build.html

Был использован docker-in-docker c docker executor'ом, который был настроен в
уже зарегистрированном gitlab-runner'е.

При этом пришлось поменять конфигурацию в config.toml раннера, прописав
`privileged = true`. Подробнее в документации:
- https://docs.gitlab.com/runner/executors/docker.html#use-docker-in-docker-with-privileged-mode
- https://docs.gitlab.com/ce/ci/docker/using_docker_build.html#tls-disabled

Образ пушится в реджистри docker.io/alakhno88/otus-reddit.

Значения переменных `CI_REGISTRY_IMAGE`, `CI_REGISTRY_USER` и `CI_REGISTRY_PASSWORD`
задаются в интерфейсе Gitlab в разеделе Setting->CI/CD->Variables.

deploy_dev_job стал иногда падать вот с такой ошибкой: https://gitlab.com/gitlab-org/gitlab-foss/issues/43286
Перезапуск job'а через интерфейс Gitlab помогает.

## 7. Выкатка на dev окружение

Создаём машинку для dev стенда:
```shell script
docker-machine create --driver google \
  --google-machine-image https://www.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/family/ubuntu-1604-lts \
  --google-machine-type n1-standard-1 \
  --google-disk-type pd-standard \
  --google-zone europe-west1-b \
  reddit-dev
```

Устанавливаем Gitlab Runner:
```shell script
docker-machine ssh reddit-dev
curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | sudo bash
sudo apt-get install gitlab-runner
sudo usermod -aG docker gitlab-runner
sudo gitlab-runner register \
  --non-interactive \
  --url "http://<GITLAB-HOST-IP>/" \
  --registration-token "<GITLAB-TOKEN>" \
  --executor "shell" \
  --description "reddit-dev" \
  --tag-list "reddit-dev" \
  --run-untagged="false" \
  --locked="false"
```

Добавляем в deploy_dev_job вызов скрипта для деплоя:
```shell script
deploy_dev_job:
  stage: review
  script:
    - gitlab-ci/deploy.sh
  tags:
    - reddit-dev
```

Чтобы образы не накапливались на хосте, в скрипте прописываем:
```shell script
docker image prune -f
```

Перед запуском контейнера с приложением из нового образа, удаляем старый контейнер:
```shell script
[ "$(docker ps -a | grep reddit)" ] && docker rm -f reddit
docker run -d --restart always -p 9292:9292 --name reddit $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
```
Добавляем флаг `--restart always`, чтобы контейнер с приложением автоматически
перезапускался после остановки (например, при перезагрузке хоста).

## 8. Отправка оповещений в Slack

https://docs.gitlab.com/ee/user/project/integrations/slack.html

Оповещения отправляются в канал https://devops-team-otus.slack.com/messages/CKC30BURZ


# ДЗ - Занятие 17

## 1. None network driver

```shell script
docker run -ti --rm --network none joffotron/docker-net-tools -c ifconfig
```

Внутри контейнера из сетевых интерфейсов существует только loopback.

## 2. Host network driver

```shell script
docker run -ti --rm --network host joffotron/docker-net-tools -c ifconfig
docker-machine ssh docker-host ifconfig
```

Внутри контейнера доступны те же сетевые интерфейсы, что и на хосте.

Если несколько раз запустить контейнер с nginx, то запустится только первый.
Остальные не смогут запуститься, поскольку 80 порт на хосте уже занят.

```shell script
docker run --network host -d nginx
docker run --network host -d nginx
docker ps -a

CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS                      PORTS               NAMES
97663565df90        nginx               "nginx -g 'daemon of…"   11 seconds ago      Exited (1) 7 seconds ago                        cocky_nash
5c0775bda6b3        nginx               "nginx -g 'daemon of…"   48 seconds ago      Up 45 seconds                                   ecstatic_mclean

docker logs 97663565df90
2019/09/17 08:22:59 [emerg] 1#1: bind() to 0.0.0.0:80 failed (98: Address already in use)
nginx: [emerg] bind() to 0.0.0.0:80 failed (98: Address already in use)

docker kill $(docker ps -q)
```

## 3. Docker networks

Запуск контейнера с драйвером none добавляет namespace с уникальным id.
Запуск контейнера с драйвером host добавляет namespace с названием default.

```shell script
docker-machine ssh docker-host
sudo ln -s /var/run/docker/netns /var/run/netns
sudo ip netns

docker run --rm --network none -d nginx
docker run --rm --network host -d nginx
sudo ip netns
default
52888f1a7b95
```

## 4. Bridge network driver

Запускаем все контейнеры в одной bridge сети:
 ```shell script
docker network create reddit --driver bridge
docker run -d --network=reddit --network-alias=post_db --network-alias=comment_db mongo:latest
docker run -d --network=reddit --network-alias=post alakhno88/post:1.0
docker run -d --network=reddit --network-alias=comment  alakhno88/comment:1.0
docker run -d --network=reddit -p 9292:9292 alakhno88/ui:1.0
```

Запускаем контейнеры в двух bridge сетях, чтобы сервис ui не имел доступа к БД:
```shell script
docker network create back_net --subnet=10.0.2.0/24
docker network create front_net --subnet=10.0.1.0/24
docker run -d --network=front_net -p 9292:9292 --name ui  alakhno88/ui:1.0
docker run -d --network=back_net --name comment  alakhno88/comment:1.0
docker run -d --network=back_net --name post  alakhno88/post:1.0
docker run -d --network=back_net --name mongo_db --network-alias=post_db --network-alias=comment_db mongo:latest
docker network connect front_net post
docker network connect front_net comment
```

## 5. Запуск приложения с помощью docker-compose

```shell script
export USER_NAME=alakhno88
docker-compose up -d
docker-compose ps
```

## 6. Доработка docker-compose.yml под кейс с несколькими сетями и алиасами

Для контейнера с БД сетевые алиасы можно указать следующим образом:

```shell script
  mongo_db:
    image: mongo:3.2
    volumes:
      - post_db:/data/db
    networks:
      back-net:
        aliases:
          - post_db
          - comment_db
```

## 7. Параметризация docker-compose.yml

Помимо переменных окружения, docker-compose может подхватывать значения
из [файла .env](https://docs.docker.com/compose/env-file/):

```shell script
cp .env.example .env
docker-compose up -d
```

## 8. Задание базового имени проекта

Базовое имя проекта можно задать при помощи переменной COMPOSE_PROJECT_NAME 
в файле .env ([доки](https://docs.docker.com/compose/env-file/)):

```shell script
COMPOSE_PROJECT_NAME=reddit
```

## 9. Изменение конфигурации при помощи docker-compose.override.yml

Документация: https://docs.docker.com/compose/extends/

Возможность изменять код без пересборки образа можно получить, примонтировав
в контейнер папку с кодом, например:

```shell script
  ui:
    command: ["puma", "--debug", "-w", "2"]
    volumes:
      - type: bind
        source: ./ui
        target: /app
```

При запуске через docker-machine такой способ сходу не работает, поскольку
папка для монтирования в контейнер ищется на docker-host, а не на локальной
машине.

Если запускать docker-compose непосредственно с docker-host, предварительно
скопировав туда код, то работает нормально.

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

## 4. Минимизация размера образа

Собираем образ на основе ruby:2.2-alpine
```shell script
docker build -t alakhno88/ui:3.0 -f ./ui/Dockerfile.1 ./ui
```

При установке пакетов в Alpine-образе используем флаг
[`--no-cache`](https://github.com/gliderlabs/docker-alpine/blob/master/docs/usage.md#disabling-cache):
```
RUN apk add --no-cache build-base
```

В результате размер образа удалось уменьшить до 305Мб:
```shell script
alakhno88/ui        3.0                 06af6a174122        About a minute ago   305MB
alakhno88/ui        2.0                 955b00188c3f        22 minutes ago       405MB
alakhno88/ui        1.0                 6e3493c268fa        44 minutes ago       771MB
```

## 5. Подключение volume к контейнеру с MongoDB

```shell script
docker kill $(docker ps -q)

docker volume create reddit_db
docker run -d --network=reddit \
    --network-alias=post_db \
    --network-alias=comment_db \
    -v reddit_db:/data/db \
    mongo:latest

docker run -d --network=reddit --network-alias=post alakhno88/post:1.0
docker run -d --network=reddit --network-alias=comment alakhno88/comment:1.0
docker run -d --network=reddit -p 9292:9292 alakhno88/ui:3.0
```

После перезапуска контейнеров посты остаются на месте.

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
