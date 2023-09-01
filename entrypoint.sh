#!/usr/bin/env bash
set -e

mkdir --parents /media/encoder/input/crop/
mkdir --parents /media/encoder/input/low-quality/crop/
mkdir --parents /media/encoder/output
mkdir --parents /media/workdir

if [[ -z "$WORKER_ID" ]]; then
    export WORKER_ID="$SRANDOM"
fi

exec "$@"
