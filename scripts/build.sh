#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-vllm-rocm-gfx1201:transformers-upgrade}"
BUILDER="${BUILDER:-}"

args=(
  --allow security.insecure
  -t "$IMAGE_NAME"
  .
)

if [[ -n "$BUILDER" ]]; then
  args=(--builder "$BUILDER" "${args[@]}")
fi

docker buildx build "${args[@]}"
