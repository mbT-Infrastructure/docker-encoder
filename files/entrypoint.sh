#!/usr/bin/env bash
set -e -o pipefail

if [[ -z "$WORKER_ID" ]]; then
    export WORKER_ID="$HOSTNAME"
fi

if [[ -n "$SERVER_URL" ]]; then
    RCLONE_SFTP_USER=${SERVER_URL#sftp://}
    RCLONE_SFTP_USER=${RCLONE_SFTP_USER%@*}
    RCLONE_SFTP_HOST=${SERVER_URL#*@}
    RCLONE_SFTP_HOST=${RCLONE_SFTP_HOST%%:*}
    RCLONE_SFTP_PORT=${SERVER_URL##*:}
    if [[ "$RCLONE_SFTP_PORT" == "$SERVER_URL" ]]; then
        RCLONE_SFTP_PORT="22"
    fi
    echo "$SERVER_KEY" > /dev/shm/ssh-key
    chmod 600 /dev/shm/ssh-key
    RCLONE_SFTP_KEY_FILE="/dev/shm/ssh-key"
    RCLONE_SFTP_KNOWN_HOSTS_FILE=
    if [[ -n "$SERVER_IDENTITY" ]]; then
        echo "* $SERVER_IDENTITY" > /dev/shm/ssh-known-hosts
        chmod 600 /dev/shm/ssh-known-hosts
        RCLONE_SFTP_KNOWN_HOSTS_FILE="/dev/shm/ssh-known-hosts"
    fi
    export RCLONE_SFTP_HOST RCLONE_SFTP_KEY_FILE RCLONE_SFTP_KNOWN_HOSTS_FILE \
        RCLONE_SFTP_PORT RCLONE_SFTP_USER
fi

exec "$@"
