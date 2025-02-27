#!/bin/bash

################################################################################
# Pull container images for host and target.
#
# You can select host and target image variants by setting the following
# environment variables: IMAGE_VARIANT_HOST, IMAGE_VARIANT_TARGET.
#
# Authors:
#   Marek Pikuła <m.pikula@partner.samsung.com>
################################################################################

IMAGE_REGISTRY=${IMAGE_REGISTRY:-registry.gitlab.com/riseproject/rvv-env}
IMAGE_VARIANT_HOST=${IMAGE_VARIANT_HOST:-host-patched}
IMAGE_VARIANT_TARGET=${IMAGE_VARIANT_TARGET:-target-debian}
IMAGE_TAG=${IMAGE_TAG:-latest}

CONTAINER_CMD=${CONTAINER_CMD:-docker}
${CONTAINER_CMD} pull "${IMAGE_REGISTRY}/${IMAGE_VARIANT_HOST}:${IMAGE_TAG}"
${CONTAINER_CMD} pull --platform linux/riscv64 "${IMAGE_REGISTRY}/${IMAGE_VARIANT_TARGET}:${IMAGE_TAG}"
