#!/bin/bash

################################################################################
# Run a command in the Docker environment.
#
# If used as symlink, the symlink's name is used as the command executed within
# the Docker environment (like all the symlinks in `scripts-host`).
#
# If executed within the `target` directory, it translates the current working
# directory to be consistent in the Docker environment.
#
# Example usage:
#   $ docker-run binary-under-test with arguments
#
# Authors:
#   Marek Pikuła <m.pikula@partner.samsung.com>
################################################################################

ENV_ROOT=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
TARGET_DIR=${ENV_ROOT}/target

REGISTRY=registry.gitlab.com/riseproject/rvv-env
IMAGE_VARIANT=${IMAGE_VARIANT:-patched}
DOCKER_TAG=${DOCKER_TAG:-latest}
IMAGE_NAME=${REGISTRY}/${IMAGE_VARIANT}:${DOCKER_TAG}

# If executing in the `target` directory, translate the current work directory
# to the directory within the Docker environment.
if [[ $PWD/ = ${TARGET_DIR}/* ]]; then WORK_DIR=${PWD//${ENV_ROOT}/}/; fi

# Check if running a wrapper script.
if [[ "$0" =~ docker-run(|\.sh)$ ]]; then
    COMMAND=${1:-${SHELL}}
    shift
else
    COMMAND=$(basename "$0")
fi

docker run -it --rm \
    -e LOCAL_USER_NAME="$(whoami)" \
    -e LOCAL_USER_ID="$(id -u)" \
    -e LOCAL_GROUP_ID="$(id -g)" \
    -e RVV_VLEN="${RVV_VLEN:-256}" \
    -v "${TARGET_DIR}:/target" \
    ${WORK_DIR:+-w ${WORK_DIR}} \
    "${IMAGE_NAME}" "${COMMAND}" "$@"
