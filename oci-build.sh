#!/bin/bash

################################################################################
# Build a container image.
#
# It can be used for both host and target images, and for local and CI runs.
#
# You need to provide the variant name as a first argument. All other arguments
# are passed to the build command.
#
# Example usage:
#   $ ./oci-build.sh target-debian build_command_argument
#
# Authors:
#   Marek Pikuła <m.pikula@partner.samsung.com>
################################################################################

set -e

CONTEXT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")/container
VARIANT_ENV_DIR=${CONTEXT_DIR}/variants

IMAGE_REGISTRY=${CI_REGISTRY_IMAGE:-${IMAGE_REGISTRY:-registry.gitlab.com/riseproject/rvv-env}}
CACHE_IMAGE=${IMAGE_REGISTRY}/cache
IMAGE_TAG=${IMAGE_TAG:-latest}
VARIANT=${1:-host-patched}
shift

source "${VARIANT_ENV_DIR}/${VARIANT}.env"

CACHE_FROM_ARGS=()
for variant in $(find "${VARIANT_ENV_DIR}" -name *.env); do
  variant=$(basename "${variant%.env}")
  CACHE_FROM_ARGS+=(
    "--cache-from" "type=registry,ref=${CACHE_IMAGE}:${variant}-latest"
    "--cache-from" "type=registry,ref=${CACHE_IMAGE}:${variant}-${IMAGE_TAG}"
  )
done

BUILD_ARGS=()
for arg in BASE_IMAGE BASE_TAG ADDITIONAL_PACKAGES; do
  BUILD_ARGS+=("--build-arg" "$arg=${!arg}")
done

IMAGE_TYPE=type=registry,compression=zstd
CACHE_TO=${IMAGE_TYPE},ref=${CACHE_IMAGE}:${VARIANT}-${IMAGE_TAG},mode=max

${CONTAINER_CMD:-docker} buildx build \
  --pull \
  "${CACHE_FROM_ARGS[@]}" \
  --platform "${PLATFORM}" \
  "${BUILD_ARGS[@]}" \
  --target "${IMAGE_TARGET}" \
  --tag "${IMAGE_REGISTRY}/${VARIANT}:${IMAGE_TAG}" \
  ${CI:+--output ${IMAGE_TYPE}} \
  ${CI:+--push} \
  ${CI:+--cache-to "${CACHE_TO}"} \
  "$@" \
  "${CONTEXT_DIR}"
