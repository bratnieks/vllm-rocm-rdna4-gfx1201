#!/usr/bin/env bash
set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-vllm-gfx1201}"
docker rm -f "$CONTAINER_NAME"
