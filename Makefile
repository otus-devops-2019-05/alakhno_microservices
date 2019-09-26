build-all: build-comment build-post build-ui build-prometheus

build-comment:
	docker build -t $(USER_NAME)/comment -f src/comment/Dockerfile src/comment/

build-post:
	docker build -t $(USER_NAME)/post -f src/post-py/Dockerfile src/post-py/

build-ui:
	docker build -t $(USER_NAME)/ui -f src/ui/Dockerfile src/ui/

build-prometheus:
	docker build -t $(USER_NAME)/prometheus -f monitoring/prometheus/Dockerfile monitoring/prometheus/

push-all: push-comment push-post push-ui push-prometheus

push-comment:
	docker push $(USER_NAME)/comment

push-post:
	docker push $(USER_NAME)/post

push-ui:
	docker push $(USER_NAME)/ui

push-prometheus:
	docker push $(USER_NAME)/prometheus
