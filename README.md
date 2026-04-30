# vLLM ROCm RDNA4 FP8 on RX 9070 XT (gfx1201)

This repository provides a reproducible, version-pinned Docker setup for running vLLM on AMD RDNA4 (gfx1201), validated on RX 9070 XT with FP8 models.

It is not a magic RDNA4 patch. It does not modify FP8 kernels, add missing model architecture support, or make unsupported ROCm/vLLM combinations work. The value of this repository is the tested alignment of ROCm, PyTorch, vLLM, Docker runtime flags, and a validated FP8 model that works in practice on gfx1201.

## Tested Stack

Tested hardware:

- AMD Radeon RX 9070 XT
- Arch: `gfx1201`

Tested software:

- ROCm: `7.12.0a20260204`
- Torch: `2.9.1+rocm7.12.0a20260204`
- vLLM: `v0.16.0rc0`
- Transformers: `5.7.0`

Tested models:

- `Qwen/Qwen3-8B-FP8`

## Quick Start

1. Build:

```bash
./scripts/build.sh
```

2. Run:

```bash
./scripts/run.sh Qwen/Qwen3-8B-FP8
```

3. Test:

```bash
./scripts/test_chat.sh Qwen/Qwen3-8B-FP8
```

## Why This Repo Exists

vLLM has AMD support, but RDNA4 is new enough that "supported" does not mean every nightly combination works. ROCm, PyTorch, Triton, vLLM, model architecture support, and Docker device detection can break independently. FP8 adds another layer because a model can load while still taking a slow or poorly tuned path. This repository pins a stack that was verified together on RX 9070 XT. It exists so others can reproduce that working baseline before experimenting.

## How To Verify FP8 Is Actually Working

Signals that the FP8 path is working:

- `Qwen/Qwen3-8B-FP8` uses about 9-10 GB of VRAM, not FP16-class memory.
- Single-request throughput is above 20 tok/s for the 8B model.
- GPU power rises during generation.
- Logs show the ROCm Triton attention backend.

Signals that you may be on a fallback or broken path:

- Generation is very slow.
- VRAM usage looks close to FP16.
- GPU stays cold or mostly idle.
- Throughput is around 1-5 tok/s for the 8B model.

## Benchmarks

Validated on RX 9070 XT:

| Model | Workload | Result |
| --- | --- | --- |
| `Qwen/Qwen3-8B-FP8` | 1 request, 512 output tokens | ~26 tok/s |
| `Qwen/Qwen3-8B-FP8` | 8 concurrent requests, 512 output tokens each | ~186-188 tok/s aggregate |
| `Qwen2.5-0.5B` class model | 8 concurrent requests | ~1000+ tok/s aggregate |

Run the benchmark script:

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

RDNA4 / gfx1201 support is still moving quickly. This setup intentionally pins the ROCm, PyTorch, and vLLM stack that was verified together. Do not change these versions unless you are intentionally testing a new stack:

- `ROCM_VERSION=7.12.0a20260204`
- `TORCH_VERSION=2.9.1+rocm7.12.0a20260204`
- `TORCHVISION_VERSION=0.24.0+rocm7.12.0a20260204`
- `TORCHAUDIO_VERSION=2.9.0+rocm7.12.0a20260204`
- `vLLM tag v0.16.0rc0`
- `TRANSFORMERS_VERSION=5.7.0`

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

- This repository aligns a working stack; it does not add unsupported FP8 kernels.
- It does not add missing vLLM model architecture support.
- `amdsmi` may fail inside containers even when HIP works.
- New model architectures still require matching vLLM support. The image pins `transformers==5.7.0` so configs such as `qwen3_5_moe` are recognized by Transformers, but models whose architecture is `Qwen3_5MoeForConditionalGeneration` still require native vLLM support and may fail with "Model architectures ... are not supported for now."
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
