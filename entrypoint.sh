#!/usr/bin/env bash
set -e

mkdir --parents /media/encoder/input
mkdir --parents /media/encoder/output
mkdir --parents /media/workdir

exec "$@"