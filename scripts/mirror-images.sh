#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${ECR_REGISTRY:-}" ]]; then
  echo "ECR_REGISTRY must be set (e.g. 123456789012.dkr.ecr.us-east-1.amazonaws.com)" >&2
  exit 1
fi

AWS_REGION="${AWS_REGION:-us-east-1}"
NODE_SOURCE="${NODE_SOURCE:-docker.io/library/node:20-alpine}"
NGINX_SOURCE="${NGINX_SOURCE:-docker.io/library/nginx:1.27-alpine}"
NODE_TARGET="${NODE_TARGET:-mirrors/node:20-alpine}"
NGINX_TARGET="${NGINX_TARGET:-mirrors/nginx:1.27-alpine}"

IMAGES=(
  "${NODE_SOURCE}@${NODE_TARGET}"
  "${NGINX_SOURCE}@${NGINX_TARGET}"
)

aws ecr describe-repositories --region "${AWS_REGION}" >/dev/null 2>&1 || true

for mapping in "${IMAGES[@]}"; do
  IFS='@' read -r SRC DEST <<<"${mapping}"
  REPO="${DEST%%:*}"

  if ! aws ecr describe-repositories --repository-names "${REPO}" --region "${AWS_REGION}" >/dev/null 2>&1; then
    aws ecr create-repository --repository-name "${REPO}" --region "${AWS_REGION}" >/dev/null
  fi

  FULL_TARGET="${ECR_REGISTRY}/${DEST}"
  echo "Mirroring ${SRC} -> ${FULL_TARGET}"
  docker pull "${SRC}"
  docker tag "${SRC}" "${FULL_TARGET}"
  docker push "${FULL_TARGET}"
done

