#!/usr/bin/env bash
set -euo pipefail

MODEL="${1:-Qwen/Qwen3-8B-FP8}"
IMAGE_NAME="${IMAGE_NAME:-vllm-rocm-gfx1201:transformers-upgrade}"
CONTAINER_NAME="${CONTAINER_NAME:-vllm-gfx1201}"
PORT="${PORT:-8000}"
HF_CACHE="${HF_CACHE:-$PWD/.cache/huggingface}"
RENDER_GID="${RENDER_GID:-992}"
VIDEO_GID="${VIDEO_GID:-44}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-8192}"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.90}"

mkdir -p "$HF_CACHE"

docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

docker run -d --name "$CONTAINER_NAME" \
  --device=/dev/kfd \
  --device=/dev/dri \
  --group-add "$RENDER_GID" \
  --group-add "$VIDEO_GID" \
  --ipc=host \
  --cap-add=SYS_PTRACE \
  --security-opt seccomp=unconfined \
  -p "$PORT:8000" \
  -v "$HF_CACHE:/root/.cache/huggingface" \
  "$IMAGE_NAME" \
  "$MODEL" \
  --host 0.0.0.0 \
  --port 8000 \
  --max-model-len "$MAX_MODEL_LEN" \
  --gpu-memory-utilization "$GPU_MEMORY_UTILIZATION"

echo "Started $CONTAINER_NAME for $MODEL on http://127.0.0.1:$PORT"
