#!/bin/bash

REGISTRY=registry.gitlab.com/riseproject/rvv-env
IMAGE_VARIANT=${IMAGE_VARIANT:-patched}
DOCKER_TAG=${DOCKER_TAG:-latest}

docker pull "${REGISTRY}/${IMAGE_VARIANT}:${DOCKER_TAG}"
