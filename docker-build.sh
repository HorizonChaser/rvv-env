#!/bin/bash

REGISTRY=registry.gitlab.com/riseproject/rvv-env
IMAGE_VARIANT=${IMAGE_VARIANT:-patched}
DOCKER_TAG=${DOCKER_TAG:-latest}

docker build . --pull \
    --cache-from "${REGISTRY}/cache/${IMAGE_VARIANT}:${DOCKER_TAG}" \
    -t "${REGISTRY}/${IMAGE_VARIANT}:${DOCKER_TAG}"
