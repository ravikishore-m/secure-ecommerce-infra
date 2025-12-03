#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <source-registry> <destination-registry> <repository> <tag> [<dest-tag>]" >&2
  exit 1
fi

SRC_REGISTRY="$1"
DEST_REGISTRY="$2"
REPOSITORY="$3"
SOURCE_TAG="$4"
DEST_TAG="${5:-$4}"

SOURCE_IMAGE="${SRC_REGISTRY}/${REPOSITORY}:${SOURCE_TAG}"
DEST_IMAGE="${DEST_REGISTRY}/${REPOSITORY}:${DEST_TAG}"

echo "Promoting ${SOURCE_IMAGE} -> ${DEST_IMAGE}"
docker pull "${SOURCE_IMAGE}"
docker tag "${SOURCE_IMAGE}" "${DEST_IMAGE}"
docker push "${DEST_IMAGE}"

