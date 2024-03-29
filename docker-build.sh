#!/usr/bin/env bash
set -e

BUILD_ARGUMENTS=()
DEPENDENCIES=(docker)
UPDATE_BASE=false
REGISTRY_USER="madebytimo"
REPOSIITORY_NAME="docker-encoder"

# help message
for ARGUMENT in "$@"; do
    if [ "$ARGUMENT" == "-h" ] || [ "$ARGUMENT" == "--help" ]; then
        echo "usage: $(basename "$0") [ARGUMENT]"
        echo "Builds the docker image from the Dockerfile."
        echo "ARGUMENT can be"
        echo "--platform [amd64|arm64|arm] build only specified platform"
        echo "--push push the build"
        echo "--update-base only build if newer base image available"
        exit
    fi
done

# check dependencies
for CMD in "${DEPENDENCIES[@]}"; do
    if [[ -z "$(which "$CMD")" ]]; then
        echo "\"${CMD}\" is missing!"
        exit 1
    fi
done

# check arguments
while [[ -n "$1" ]]; do
    if [[ "$1" = "--platform" ]]; then
        shift
        BUILD_ARGUMENTS+=("--set" "default.platform=$1")
    elif [[ "$1" = "--update-base" ]]; then
        UPDATE_BASE=true
    elif [[ "$1" = "--push" ]]; then
        BUILD_ARGUMENTS+=("--push")
    else
        echo "Unknown argument: \"$1\""
        exit 1
    fi
    shift
done

BASE_IMAGE="$(tac Dockerfile | grep --max-count=1 "FROM" | cut -d" " -f2)"
docker pull "$BASE_IMAGE"
BASE_IMAGE_DATE="$(docker image inspect --format="{{ .Created }}" "$BASE_IMAGE" | cut -d "T" -f1)"
echo "Base image is $BASE_IMAGE from $BASE_IMAGE_DATE"
IMAGE="${REGISTRY_USER}/${REPOSIITORY_NAME#docker-}"
if [[ "$UPDATE_BASE" == true ]]; then
    docker pull "$IMAGE"
    PUSHED_IMAGE_DATE="$(docker image inspect --format="{{ .Created }}" "$IMAGE" | cut -d "T" -f1)"
    echo "Last pushed image is from $PUSHED_IMAGE_DATE"
    if [[ "$BASE_IMAGE_DATE" < "$PUSHED_IMAGE_DATE" ]]; then
        echo "Used base image is up to date"
        exit;
    fi
fi
VERSION="$(cat Version.txt)"

export BASE_IMAGE BASE_IMAGE_DATE IMAGE VERSION
docker buildx bake --file docker-bake.hcl "${BUILD_ARGUMENTS[@]}"
