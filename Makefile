all: build-all push-all

build-all: build-comment build-post build-ui build-prometheus build-alertmanager

push-all: push-comment push-post push-ui push-prometheus push-alertmanager

comment: build-comment push-comment

build-comment:
	docker build -t $(USER_NAME)/comment -f src/comment/Dockerfile src/comment/

push-comment:
	docker push $(USER_NAME)/comment

post: build-post push-post

build-post:
	docker build -t $(USER_NAME)/post -f src/post-py/Dockerfile src/post-py/

push-post:
	docker push $(USER_NAME)/post

ui: build-ui push-ui

build-ui:
	docker build -t $(USER_NAME)/ui -f src/ui/Dockerfile src/ui/

push-ui:
	docker push $(USER_NAME)/ui

prometheus: build-prometheus push-prometheus

build-prometheus:
	docker build -t $(USER_NAME)/prometheus -f monitoring/prometheus/Dockerfile monitoring/prometheus/

push-prometheus:
	docker push $(USER_NAME)/prometheus

alertmanager: build-alertmanager push-alertmanager

build-alertmanager:
	docker build -t $(USER_NAME)/alertmanager -f monitoring/alertmanager/Dockerfile monitoring/alertmanager/

push-alertmanager:
	docker push $(USER_NAME)/alertmanager
