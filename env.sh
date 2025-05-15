#!/bin/bash

SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[0]}")")

SCRIPTS_SUBDIR="scripts"
SCRIPTS_PATH="${SCRIPT_DIR}/${SCRIPTS_SUBDIR}"

if [[ ":${PATH}:" != *":${SCRIPTS_PATH}:"* ]]; then
  PATH="${SCRIPTS_PATH}:${PATH}"
  export PATH
else
  :
fi

WORK_SUBDIR="work"
WORK_DIR_PATH="${SCRIPT_DIR}/${WORK_SUBDIR}/"

if [ ! -d "${WORK_DIR_PATH}" ]; then
  mkdir -p "${WORK_DIR_PATH}"
fi

export WORK_DIR="${WORK_DIR_PATH}"

export IMAGE_VARIANT_TARGET="target-ubuntu"
echo -e "Using ${IMAGE_VARIANT_TARGET} as the default image variant for target containers.\nRemove the line 24 from env.sh to use the default debian variant.\n"

# remove all temp vars
unset SCRIPT_DIR SCRIPTS_SUBDIR SCRIPTS_PATH WORK_SUBDIR WORK_DIR_PATH