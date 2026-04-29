# Limitations

This setup is bleeding edge.

## RDNA4 Detection

Inside containers, `amdsmi` can fail even when HIP works. vLLM uses platform detection paths that may rely on `amdsmi` or `torch.cuda.device_count()`.

The patch script works around this by:

- Detecting ROCm through `libamdhip64.so`.
- Using `PYTORCH_ROCM_ARCH=gfx1201` as the GCN arch fallback.
- Monkey-patching `torch.cuda.device_count()` when HIP sees the GPU but Torch reports zero devices during detection.

## vLLM Architecture Support

The pinned vLLM revision supports `Qwen3ForCausalLM`, which is enough for `Qwen/Qwen3-8B-FP8`.

It did not support `Qwen3_5ForConditionalGeneration` during validation, even after updating `transformers`. That blocked `Qwen3.5-9B-FP8` style checkpoints.

## GGUF Is Out Of Scope

This Docker image is for vLLM and Hugging Face model checkpoints.

GGUF quantizations such as `Q2_K`, `IQ2_*`, `Q4_K_M`, and similar should be tested with llama.cpp or Ollama, not this vLLM image.

## Disk Usage

The build is large:

- ROCm/TheRock packages are large.
- vLLM and flash-attention compile from source.
- BuildKit cache can exceed the final image size.
- Model caches can be multiple GB per checkpoint.

Do not commit Docker image tarballs or model weights.

## Production Readiness

This is a reproducibility guide, not a supported production deployment.

Expected risks:

- Nightly package disappearances or reshuffling.
- ROCm ABI/API changes.
- vLLM upstream changes.
- Kernel regressions.
- Model architecture drift.
