#!/usr/bin/env bash
set -euo pipefail

REGISTRY="${REGISTRY:-local}"
TAG="${TAG:-latest}"
SERVICES=("frontend" "login" "orders" "payments" "inventory" "catalog")

for svc in "${SERVICES[@]}"; do
  CONTEXT="services/${svc}"
  if [[ "${svc}" == "frontend" ]]; then
    CONTEXT="frontend"
  fi

  IMAGE="${REGISTRY}/ecom-${svc}:${TAG}"
  echo "Building ${IMAGE} from ${CONTEXT}"
  docker build -t "${IMAGE}" "${CONTEXT}"
done

