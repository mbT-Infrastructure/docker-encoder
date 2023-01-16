#!/usr/bin/env bash
set -e

BASE_IMAGE="$(tac Dockerfile | grep --max-count=1 "FROM" | cut -d" " -f2)"
docker pull "$BASE_IMAGE"
BASE_IMAGE_DATE="$(docker image inspect --format="{{ .Created }}" "$BASE_IMAGE" | cut -d "T" -f1)"
echo "Base is $BASE_IMAGE from $BASE_IMAGE_DATE"
export BASE_IMAGE BASE_IMAGE_DATE
docker buildx bake -f docker-bake.hcl $@