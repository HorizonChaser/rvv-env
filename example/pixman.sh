#!/bin/bash

################################################################################
# Example usage of the RVV environment.
#
# It creates the target environment, builds Pixman, and starts a debug session.
#
# Authors:
#   Marek Pikuła <m.pikula@partner.samsung.com>
################################################################################

CONTAINER_CMD=${CONTAINER_CMD:-docker}
PIXMAN_GIT=${PIXMAN_GIT:-https://gitlab.freedesktop.org/pixman/pixman.git}
RVVENV_GIT=${RVVENV_GIT:-https://gitlab.com/riseproject/rvv-env.git}
RVVENV_BRANCH=${RVVENV_BRANCH:-main}

set -e
shopt -s expand_aliases

_echo_stage() {
    { set +x; } 2>/dev/null
    echo -e "$(tput bold)\n" "$@" "\n$(tput sgr0)"
    set -x
}
alias echo_stage='{ set +x; } 2>/dev/null; _echo_stage'

echo_stage "Check for an OCI runner:"
${CONTAINER_CMD} version

echo_stage "Prepare the environment:"
git clone "${RVVENV_GIT}" -b "${RVVENV_BRANCH}"
cd rvv-env
source env.sh
export IMAGE_VARIANT_TARGET=target-pixman

echo_stage "Pull the OCI images:"
./oci-pull.sh

echo_stage "Check if the target works:"
target-run uname -a

echo_stage "Build Pixman:"
cd work
host-run git clone "${PIXMAN_GIT}"
cd pixman
target-run meson setup build
target-run meson compile -C build

echo_stage "Start the debug session:"
cd build
target-gdb-rvv test/stress-test &
host-gdb
