#!/bin/bash

################################################################################
# Run a command in a containerized environment.
#
# If used as symlink, the symlink's name determines the functionality (like all
# the symlinks in `scripts`).
#
# If executed within the `rvv-env` or `work` directory, it translates the
# current working directory to be consistent in the containerized environment.
#
# Example usage:
#   $ ./oci-run.sh binary-under-test with arguments
#
# Authors:
#   Marek Pikuła <m.pikula@partner.samsung.com>
################################################################################

set -e

ENV_ROOT=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
WORK_DIR=${WORK_DIR:-${ENV_ROOT}/work}

CONTAINER_CMD=${CONTAINER_CMD:-docker}

IMAGE_REGISTRY=${IMAGE_REGISTRY:-registry.gitlab.com/riseproject/rvv-env}
IMAGE_TAG=${IMAGE_TAG:-latest}

QEMU_GDB_PORT=${QEMU_GDB_PORT:-1234}

# If executing in the `rvv-env` or `work` directory, translate the current work
# directory to the directory within the container environment. Prioritize
# `work`, as it might be in `rvv-env` as well.
if [[ $PWD/ = ${WORK_DIR}/* ]]; then
    CONTAINER_WORK_DIR=/work/${PWD//${WORK_DIR}/}
elif [[ $PWD/ = ${ENV_ROOT}/* ]]; then
    CONTAINER_WORK_DIR=/rvv-env/${PWD//${ENV_ROOT}/}
else
    CONTAINER_WORK_DIR=/work
fi

# Set environment for the wrapper scripts.
BASENAME=$(basename "$0")

# Check if running for target.
if [[ "${BASENAME}" =~ ^target- ]]; then
    PLATFORM=linux/riscv64
    IMAGE_VARIANT=${IMAGE_VARIANT_TARGET:-target-debian}

    # Check if running a wrapper with `-rvv` suffix.
    if [[ "${BASENAME}" =~ -rvv$ ]]; then
        RVV_ENABLE=true
    fi

    # Set QEMU CPU string.
    QEMU_CPU=rv64,v=${RVV_ENABLE:-false},vext_spec=${RVV_SPEC:-v1.0},vlen=${RVV_VLEN:-256},elen=${RVV_ELEN:-64}${QEMU_CPU_EXTRA:+,${QEMU_CPU_EXTRA}}

    # Ensure that binfmt is configured for RISC-V.
    BINFMT_RISCV=/proc/sys/fs/binfmt_misc/qemu-riscv64
    if ! [ -f "${BINFMT_RISCV}" ]; then
        echo "
Binfmt is not configured for RISC-V. The target container will not work. Please
consult the section *QEMU and binfmt* in README to enable it.
"
        exit 1
    fi

    # Ensure that binfmt C flag is set to allow running sudo.
    if ! (grep flags "${BINFMT_RISCV}" | grep C &>/dev/null); then
        echo "
C flag is not enabled for RISC-V binfmt, which will prevent you from using sudo
in the container. Please consult the section *QEMU and binfmt* in README to
enable it.
"
    fi
else
    # By default, run the host image.
    IMAGE_VARIANT=${IMAGE_VARIANT_HOST:-host-patched}
fi

# Set an interactive TTY mode for the container if already in a TTY context.
if tty -s; then
    INTERACTIVE_ARGS=("-it")
fi

function container_run() {
    # Save runner arguments starting with a dash to include them before image
    # name (which is positional). The rest will be used as a command and its
    # arguments.
    RUN_ARGS=()
    while [[ $# -gt 0 && "$1" == -* ]]; do
        RUN_ARGS+=("$1")
        shift
    done

    # Fallback to shell if no arguments are given.
    if [ $# -eq 0 ]; then
        COMMAND=${SHELL}
    else
        COMMAND=$1
        shift
    fi

    LOCAL_USER_ID=$(id -u)
    LOCAL_GROUP_ID=$(id -g)

    # Ensure that the local directories mounted as volumes are owned by the
    # local user in the context of Podman.
    UNSHARE_CHOWN="${CONTAINER_CMD} unshare chown"

    unshare_cleanup() {
        set +e
        ${UNSHARE_CHOWN} 0:0 "${ENV_ROOT}"
        ${UNSHARE_CHOWN} 0:0 "${WORK_DIR}"
        set -e
    }

    if [ "${CONTAINER_CMD}" == "podman" ]; then
        trap unshare_cleanup ERR
        ${UNSHARE_CHOWN} "${LOCAL_USER_ID}:${LOCAL_GROUP_ID}" "${ENV_ROOT}"
        ${UNSHARE_CHOWN} "${LOCAL_USER_ID}:${LOCAL_GROUP_ID}" "${WORK_DIR}"
    fi

    ${CONTAINER_CMD} run \
        -e "LOCAL_USER_NAME=$(whoami)" \
        -e "LOCAL_USER_ID=${LOCAL_USER_ID}" \
        -e "LOCAL_GROUP_ID=${LOCAL_GROUP_ID}" \
        -e "QEMU_CPU=${QEMU_CPU}" \
        -v "${WORK_DIR}:/work" \
        -v "${ENV_ROOT}:/rvv-env" \
        -w "${CONTAINER_WORK_DIR}" \
        --network host \
        --hostname "${IMAGE_VARIANT}" \
        ${PLATFORM:+--platform ${PLATFORM}} \
        "${INTERACTIVE_ARGS[@]}" \
        "${RUN_ARGS[@]}" \
        "${IMAGE_REGISTRY}/${IMAGE_VARIANT}:${IMAGE_TAG}" \
        "${COMMAND}" \
        "$@"

    if [ "${CONTAINER_CMD}" == "podman" ]; then
        unshare_cleanup
    fi
}

if [[ "${BASENAME}" =~ ^host-gdb$ ]]; then
    container_run \
        --rm \
        riscv64-unknown-linux-gnu-gdb \
            -ex "set sysroot target:/" \
            -ex "target remote :${QEMU_GDB_PORT}" \
            "$@"
elif [[ "${BASENAME}" =~ ^target-gdb ]]; then
    # Run detached container without GDB so that entrypoint script bootstraps
    # the environment.
    CONTAINER_NAME=$(
        container_run \
            --detach \
            --rm \
            bash -c "while true; do sleep 1; done"
    )

    container_cleanup() {
        ${CONTAINER_CMD} kill "${CONTAINER_NAME}" &>/dev/null
    }

    trap container_cleanup ERR
    ${CONTAINER_CMD} exec \
        "${INTERACTIVE_ARGS[@]}" \
        --env="QEMU_GDB=${QEMU_GDB_PORT}" \
        "${CONTAINER_NAME}" \
        "$@"
    container_cleanup
else
    container_run \
        --rm \
        --env="QEMU_CPU=${QEMU_CPU}" \
        "$@"
fi
