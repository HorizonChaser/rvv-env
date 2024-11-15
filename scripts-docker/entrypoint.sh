#!/bin/bash

################################################################################
# Create user environment in Docker allowing to dynamically accommodate to local
# user ID and group ID.
#
# Authors:
#   Marek Pikuła <m.pikula@partner.samsung.com>
################################################################################

set -e

# LOCAL_USER_ID and LOCAL_GROUP_ID should be set in env.
DOCKER_USERNAME=${LOCAL_USER_NAME:-docker}
DOCKER_UID=${LOCAL_USER_ID:-9001}
DOCKER_GID=${LOCAL_GROUP_ID:-9001}

if id "${DOCKER_USERNAME}" &>/dev/null; then
    echo "User already exists, skipping user environment creation."
else
    # Create user called "docker" with selected UID/GID pair.
    groupadd -g "${DOCKER_GID}" "${DOCKER_USERNAME}"
    useradd --shell /bin/bash -u "${DOCKER_UID}" -g "${DOCKER_GID}" -o -m "${DOCKER_USERNAME}" 2> /dev/null

    # Add Docker user to sudoers.
    echo "${DOCKER_USERNAME}" ALL=\(ALL\) NOPASSWD: ALL > "/etc/sudoers.d/${DOCKER_USERNAME}"
    chmod 0440 "/etc/sudoers.d/${DOCKER_USERNAME}"

    # Set "HOME" ENV variable for user's home directory
    export HOME=/home/${DOCKER_USERNAME}
fi

git config --global --add safe.directory /work

# Execute gosu process to drop shell to the target user.
exec gosu "${DOCKER_USERNAME}" "$@"
