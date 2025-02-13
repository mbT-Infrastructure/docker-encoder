#!/usr/bin/env bash
set -e -o pipefail

BUILD_ARGUMENTS=()
BUILDER_EXPORT_ARCHIVE="${BUILDER_EXPORT_ARCHIVE:-true}"
DEPENDENCIES=(docker zstd)
UPDATE_BASE=false
PLATFORMS=(linux/amd64 linux/arm64)
REGISTRY_USER="madebytimo"
APPLICATION_NAME="encoder"

# help message
for ARGUMENT in "$@"; do
    if [ "$ARGUMENT" == "-h" ] || [ "$ARGUMENT" == "--help" ]; then
        echo "usage: $(basename "$0") [ARGUMENT]"
        echo "Builds the docker image from the Dockerfile."
        echo "ARGUMENT can be"
        echo "--platform PLATFORM Build only for specified platform."
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
docker pull --quiet "$BASE_IMAGE"
BASE_IMAGE_DATE="$(docker image inspect --format="{{ .Created }}" "$BASE_IMAGE" \
    | sed 's|^\([^T ]*\)[T ].*$|\1|')"
echo "Base image is $BASE_IMAGE from $BASE_IMAGE_DATE"
IMAGE="${REGISTRY_USER}/${APPLICATION_NAME}"
if [[ "$UPDATE_BASE" == true ]]; then
    docker pull "$IMAGE"
    PUSHED_IMAGE_DATE="$(docker image inspect --format="{{ .Created }}" "$IMAGE" \
        | sed 's|^\([^T ]*\)[T ].*$|\1|')"
    echo "Last pushed image is from $PUSHED_IMAGE_DATE"
    if [[ "$BASE_IMAGE_DATE" < "$PUSHED_IMAGE_DATE" ]]; then
        echo "Used base image is up to date"
        exit;
    fi
fi

PLATFORMS_STRING="${PLATFORMS[*]}"
BUILD_ARGUMENTS+=(--platform "${PLATFORMS_STRING// /,}")
if [[ "$BUILDER_EXPORT_ARCHIVE" == true ]]; then
    OUTPUT_FILE="builds/${IMAGE//"/"/-}-${VERSION}-oci.tar"
    BUILD_ARGUMENTS+=(--output \
    "type=oci,dest=${OUTPUT_FILE},compression=zstd,compression-level=19,force-compression=true")
fi

docker buildx build "${BUILD_ARGUMENTS[@]}" \
    --tag "${IMAGE}:latest" --tag "${IMAGE}:${VERSION}" \
    --tag "${IMAGE}:${VERSION}-base-${BASE_IMAGE_DATE}" .

if [[ "$BUILDER_EXPORT_ARCHIVE" == true ]]; then
    docker pull --quiet quay.io/skopeo/stable > /dev/null
    rm -f builds/.temp-docker-archive.tar
    for PLATFORM in "${PLATFORMS[@]}"; do
        docker run --interactive --rm --volume "${PWD}/builds:/builds" \
            quay.io/skopeo/stable copy --additional-tag "${IMAGE}:latest" --additional-tag \
            "${IMAGE}:${VERSION}" --additional-tag "${IMAGE}:${VERSION}-base-${BASE_IMAGE_DATE}" \
            --override-arch "${PLATFORM#*/}" --quiet "oci-archive:${OUTPUT_FILE}:latest" \
            "docker-archive:builds/.temp-docker-archive.tar"
        zstd -19 --force --quiet -T0 builds/.temp-docker-archive.tar \
            -o "${OUTPUT_FILE%oci.tar}${PLATFORM#*/}.tar.zst"
        rm -f builds/.temp-docker-archive.tar
    done
fi
