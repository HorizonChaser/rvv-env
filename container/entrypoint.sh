#!/bin/bash

################################################################################
# Create user environment in a container allowing to dynamically accommodate to
# local user ID and group ID.
#
# Authors:
#   Marek Pikuła <m.pikula@partner.samsung.com>
################################################################################

set -e

# LOCAL_USER_ID and LOCAL_GROUP_ID should be set in env.
CONTAINER_USERNAME=${LOCAL_USER_NAME:-oci}
CONTAINER_UID=${LOCAL_USER_ID:-9001}
CONTAINER_GID=${LOCAL_GROUP_ID:-9001}

if id "${CONTAINER_USERNAME}" &>/dev/null; then
    echo "User already exists, skipping user environment creation."
else
    # Create a user with a selected UID/GID pair.
    groupadd -g "${CONTAINER_GID}" "${CONTAINER_USERNAME}"
    useradd \
        -o -m \
        --shell /bin/bash \
        -u "${CONTAINER_UID}" \
        -g "${CONTAINER_GID}" \
        "${CONTAINER_USERNAME}" 2>/dev/null

    # Add the user to sudoers.
    mkdir -p /etc/sudoers.d
    echo "${CONTAINER_USERNAME}" ALL=\(ALL\) NOPASSWD: ALL > "/etc/sudoers.d/${CONTAINER_USERNAME}"
    chmod 0440 "/etc/sudoers.d/${CONTAINER_USERNAME}"

    # Ensure that container storage is set to the user.
    if [ -d "/var/lib/containers/${CONTAINER_UID}" ]; then
        chown "${CONTAINER_UID}:${CONTAINER_UID}" "/var/lib/containers/${CONTAINER_UID}"
    fi

    # Set "HOME" ENV variable for user's home directory
    export HOME=/home/${CONTAINER_USERNAME}
fi

# Ensure that work directory is marked as safe for git.
if command -v git &>/dev/null; then
    git config --global --add safe.directory /work
fi

# Ensure that the container's hostname resolves to localhost
# (for `--network host`).
echo 127.0.0.1 "${HOSTNAME}" >> /etc/hosts

# Execute gosu process to drop shell to the target user.
exec gosu "${CONTAINER_USERNAME}" "$@"
