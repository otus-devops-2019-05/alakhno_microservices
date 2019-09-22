#!/bin/bash

set -e

echo 'Deploy'
echo $CI_REGISTRY_PASSWORD | docker login -u $CI_REGISTRY_USER --password-stdin
docker pull $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
[ "$(docker ps -a | grep reddit)" ] && docker rm -f reddit
docker run -d --restart always -p 9292:9292 --name reddit $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
