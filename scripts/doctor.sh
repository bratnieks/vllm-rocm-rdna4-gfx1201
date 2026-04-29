#!/usr/bin/env bash
set -euo pipefail

echo "== Devices =="
ls -l /dev/kfd /dev/dri || true

echo
echo "== Groups =="
getent group render || true
getent group video || true

echo
echo "== Docker =="
docker version --format 'Client {{.Client.Version}} / Server {{.Server.Version}}'

echo
echo "== ROCm from container =="
IMAGE_NAME="${IMAGE_NAME:-vllm-rocm-gfx1201:patchset}"
docker run --rm \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add "${RENDER_GID:-992}" \
  --group-add "${VIDEO_GID:-44}" \
  "$IMAGE_NAME" \
  --help >/dev/null

echo "Container can start vLLM entrypoint."
