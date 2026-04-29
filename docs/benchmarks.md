# Benchmarks

Hardware:

- AMD Radeon RX 9070 XT
- `gfx1201`

Software:

- ROCm `7.12.0a20260204`
- PyTorch `2.9.1+rocm7.12.0a20260204`
- vLLM `v0.16.0rc0`
- Docker with `/dev/kfd` and `/dev/dri`

Validated FP8 model:

- `Qwen/Qwen3-8B-FP8`

Startup observations:

- vLLM resolved architecture as `Qwen3ForCausalLM`.
- vLLM selected `quantization=fp8`.
- ROCm backend selected Triton Attention.
- Model loading took about `9.43 GiB` VRAM.
- Available KV cache memory was about `2.79 GiB` with `--max-model-len 8192`.
- GPU KV cache size was `20,288 tokens`.

Measured throughput:

| Concurrency | Output tokens per request | Aggregate output tokens | Wall time | Aggregate generation throughput |
| --- | ---: | ---: | ---: | ---: |
| 1 | 512 | 512 | ~19.4s | ~26.4 tok/s |
| 4 | 512 | 2048 | ~22.3s | ~92 tok/s |
| 8 | 512 | 4096 | ~21.9s | ~186.9 tok/s |

vLLM internal logs reported generation throughput around `188 tok/s` during the 8-concurrency run.

Small model observation:

- Qwen 0.5B-class model reached about `1000+ tok/s` aggregate at 8 concurrent requests.

These numbers are not a general promise. They are a snapshot from one host and one stack.
