#!/usr/bin/env bash
set -euo pipefail

REGISTRY="${REGISTRY:-local}"
TAG="${TAG:-latest}"
SERVICES=("frontend" "login" "orders" "payments" "inventory" "catalog")
NODE_BASE_IMAGE="${NODE_BASE_IMAGE:-public.ecr.aws/docker/library/node:20-alpine}"
NGINX_BASE_IMAGE="${NGINX_BASE_IMAGE:-public.ecr.aws/nginx/nginx:1.27-alpine}"

for svc in "${SERVICES[@]}"; do
  CONTEXT="services/${svc}"
  if [[ "${svc}" == "frontend" ]]; then
    CONTEXT="frontend"
  fi

  IMAGE="${REGISTRY}/ecom-${svc}:${TAG}"
  echo "Building ${IMAGE} from ${CONTEXT}"
  docker build \
    --build-arg BASE_IMAGE="${NODE_BASE_IMAGE}" \
    --build-arg NODE_BASE_IMAGE="${NODE_BASE_IMAGE}" \
    --build-arg NGINX_BASE_IMAGE="${NGINX_BASE_IMAGE}" \
    -t "${IMAGE}" "${CONTEXT}"
done

