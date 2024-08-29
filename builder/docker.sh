#!/usr/bin/env bash
set -e

BUILD_ARGUMENTS=()
DEPENDENCIES=(docker)
UPDATE_BASE=false
PLATFORMS=(amd64 arm64)
REGISTRY_USER="madebytimo"
APPLICATION_NAME="encoder"

# help message
for ARGUMENT in "$@"; do
    if [ "$ARGUMENT" == "-h" ] || [ "$ARGUMENT" == "--help" ]; then
        echo "usage: $(basename "$0") [ARGUMENT]"
        echo "Builds the docker image from the Dockerfile."
        echo "ARGUMENT can be"
        echo "--platform [amd64|arm64|arm] Build only for specified platform."
        echo "--publish Push the build."
        echo "--update-base Only build if newer base image is available."
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
        PLATFORMS=("$1")
    elif [[ "$1" = "--update-base" ]]; then
        UPDATE_BASE=true
    elif [[ "$1" = "--publish" ]]; then
        BUILD_ARGUMENTS+=("--push")
    fi
    shift
done

PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VERSION="$(cat Version.txt)"

cd "$PROJECT_DIR"
mkdir --parents builds

BASE_IMAGE="$(tac Dockerfile | grep --max-count=1 "^FROM" | cut -d" " -f2)"
docker pull "$BASE_IMAGE"
BASE_IMAGE_DATE="$(docker image inspect --format="{{ .Created }}" "$BASE_IMAGE" | cut -d "T" -f1)"
echo "Base image is $BASE_IMAGE from $BASE_IMAGE_DATE"
IMAGE="${REGISTRY_USER}/${APPLICATION_NAME}"
if [[ "$UPDATE_BASE" == true ]]; then
    docker pull "$IMAGE"
    PUSHED_IMAGE_DATE="$(docker image inspect --format="{{ .Created }}" "$IMAGE" | cut -d "T" -f1)"
    echo "Last pushed image is from $PUSHED_IMAGE_DATE"
    if [[ "$BASE_IMAGE_DATE" < "$PUSHED_IMAGE_DATE" ]]; then
        echo "Used base image is up to date"
        exit;
    fi
fi

PLATFORMS_STRING="${PLATFORMS[*]}"
BUILD_ARGUMENTS+=(--platform "${PLATFORMS_STRING// /,}")
OUTPUT_FILE="builds/${IMAGE//"/"/-}-${VERSION}-oci.tar"

docker buildx build "${BUILD_ARGUMENTS[@]}" --output \
    "type=oci,dest=${OUTPUT_FILE},compression=zstd,compression-level=19,force-compression=true" \
    --tag "${IMAGE}:latest" --tag "${IMAGE}:${VERSION}" \
    --tag "${IMAGE}:${VERSION}-base-${BASE_IMAGE_DATE}" .
