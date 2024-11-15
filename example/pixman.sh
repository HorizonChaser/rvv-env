#!/bin/bash

################################################################################
# Example usage of the RVV environment.
#
# It creates the target environment, builds Pixman, and starts a debug session.
#
# Authors:
#   Marek Pikuła <m.pikula@partner.samsung.com>
################################################################################

set -e
shopt -s expand_aliases

_echo_stage() {
    { set +x; } 2>/dev/null
    echo -e "$(tput bold)\n" "$@" "\n$(tput sgr0)"
    set -x
}
alias echo_stage='{ set +x; } 2>/dev/null; _echo_stage'

echo_stage "Check for Docker:"
docker version

echo_stage "Prepare environment:"
git clone https://gitlab.com/riseproject/rvv-env.git
cd rvv-env
source env.sh

echo_stage "Pull the Docker image:"
./docker-pull.sh

echo_stage "Prepare target rootfs:"
target-prepare-rootfs
target-run uname -a

echo_stage "Build Pixman:"
cd target/work
docker-run git clone https://gitlab.freedesktop.org/pixman/pixman.git
cd pixman
target-run meson setup build
target-run meson compile -C build

echo_stage "Start the debug session:"
cd build
target-gdb-rvv test/stress-test
