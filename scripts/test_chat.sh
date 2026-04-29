#!/usr/bin/env bash
set -euo pipefail

MODEL="${1:-Qwen/Qwen3-8B-FP8}"
PORT="${PORT:-8000}"

curl -sS "http://127.0.0.1:${PORT}/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d "{
    \"model\": \"${MODEL}\",
    \"messages\": [
      {
        \"role\": \"user\",
        \"content\": \"Answer in one short sentence: is vLLM running on the GPU?\"
      }
    ],
    \"max_tokens\": 64,
    \"temperature\": 0
  }"
echo
