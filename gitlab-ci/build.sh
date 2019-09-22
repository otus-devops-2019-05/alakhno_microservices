#!/bin/bash

set -e

echo 'Building'
cd reddit
docker build --tag $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA --tag $CI_REGISTRY_IMAGE:latest .
echo $CI_REGISTRY_PASSWORD | docker login -u $CI_REGISTRY_USER --password-stdin
docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_SHA
docker push $CI_REGISTRY_IMAGE:latest
