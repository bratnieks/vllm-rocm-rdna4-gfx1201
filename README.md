# vLLM ROCm RDNA4 FP8 on RX 9070 XT (gfx1201)

Reproducible notes and Docker assets for running vLLM on AMD RDNA4 / gfx1201 with ROCm nightly packages and FP8 models.

This repository documents a tested bleeding-edge setup for:

- GPU: AMD Radeon RX 9070 XT
- GPU arch: `gfx1201`
- ROCm: `7.12.0a20260204`
- PyTorch: `2.9.1+rocm7.12.0a20260204`
- vLLM: `v0.16.0rc0`
- Validated model: `Qwen/Qwen3-8B-FP8`

The target audience is people who are comfortable with Docker, ROCm nightlies, and unstable GPU software stacks.

## What Works

- vLLM imports and serves models through the OpenAI-compatible API.
- `Qwen/Qwen3-8B-FP8` loads with vLLM FP8 quantization on RX 9070 XT.
- vLLM uses the ROCm Triton attention backend.
- RDNA4 container detection issues are patched around with HIP-based device discovery.

Observed benchmark on RX 9070 XT:

| Model | Workload | Result |
| --- | --- | --- |
| `Qwen/Qwen3-8B-FP8` | 1 request, 512 output tokens | ~26 tok/s |
| `Qwen/Qwen3-8B-FP8` | 4 concurrent requests, 512 output tokens each | ~92 tok/s aggregate |
| `Qwen/Qwen3-8B-FP8` | 8 concurrent requests, 512 output tokens each | ~186-188 tok/s aggregate |
| small Qwen 0.5B class model | 8 concurrent requests | ~1000+ tok/s aggregate |

## Quick Start

Build:

```bash
./scripts/build.sh
```

Run the validated FP8 model:

```bash
./scripts/run.sh Qwen/Qwen3-8B-FP8
```

Smoke test:

```bash
./scripts/test_chat.sh Qwen/Qwen3-8B-FP8
```

Benchmark:

```bash
./scripts/benchmark.js Qwen/Qwen3-8B-FP8
```

The API is exposed at:

```text
http://127.0.0.1:8000/v1/chat/completions
```

## Host Requirements

- Linux host with working AMDGPU kernel stack.
- Docker with access to `/dev/kfd` and `/dev/dri`.
- User allowed to run Docker.
- RX 9070 XT or another RDNA4 card using `gfx1201`.
- Enough disk space. The Docker image is large, and BuildKit cache can be much larger than the final image.

Device check:

```bash
ls -l /dev/kfd /dev/dri
getent group render
getent group video
```

The default scripts use group IDs `992` for `render` and `44` for `video`, matching the validated host. Override them if your system differs:

```bash
RENDER_GID=$(getent group render | cut -d: -f3) \
VIDEO_GID=$(getent group video | cut -d: -f3) \
./scripts/run.sh Qwen/Qwen3-8B-FP8
```

## Why These Pins

RDNA4 / gfx1201 support is still moving quickly. This setup intentionally pins the ROCm, PyTorch, and vLLM stack that was verified together:

- `ROCM_VERSION=7.12.0a20260204`
- `TORCH_VERSION=2.9.1+rocm7.12.0a20260204`
- `TORCHVISION_VERSION=0.24.0+rocm7.12.0a20260204`
- `TORCHAUDIO_VERSION=2.9.0+rocm7.12.0a20260204`
- `vLLM tag v0.16.0rc0`

Later nightlies may work better or worse. Treat upgrades as experiments, not routine maintenance.

## FP8: Real, Fake, And Practical Meaning

See [docs/fp8.md](docs/fp8.md).

Short version:

- This setup validates vLLM loading FP8 checkpoint formats and running FP8 quantized paths where vLLM/ROCm support them.
- Some FP8 paths may use fallback kernels or default configs on RDNA4.
- Logs can include warnings such as missing tuned W8A8 FP8 kernel configs for `AMD_Radeon_RX_9070_XT`.
- "FP8 model" does not automatically mean every operation is native FP8 hardware throughput end-to-end.

## Known Limitations

See [docs/limitations.md](docs/limitations.md).

Important limitations:

- vLLM RDNA4 detection still needs local patches.
- `amdsmi` may fail inside containers even when HIP works.
- Some newer architectures, such as `Qwen3_5ForConditionalGeneration`, may not be registered in this pinned vLLM.
- GGUF/Q2 models are not handled by this vLLM image. Use llama.cpp/Ollama for GGUF.
- This is not a supported production stack.

## Repository Layout

```text
.
├── Dockerfile
├── patches/
│   └── vllm_rdna4_patches.py
├── scripts/
│   ├── benchmark.js
│   ├── build.sh
│   ├── doctor.sh
│   ├── run.sh
│   ├── stop.sh
│   └── test_chat.sh
├── configs/
│   ├── docker-compose.yml
│   └── env.example
└── docs/
    ├── benchmarks.md
    ├── fp8.md
    ├── limitations.md
    └── troubleshooting.md
```

## Credits

This setup follows the community RDNA4/vLLM patch direction from:

- `bluefalcon13/vllm-rocm`
- `sleeepss/vllm-rdna4-container-patches`
- vLLM upstream
- ROCm / TheRock nightly packages

The Dockerfile in this repository is deliberately explicit so the stack can be audited and reproduced.
