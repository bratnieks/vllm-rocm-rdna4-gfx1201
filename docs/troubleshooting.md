# Troubleshooting

## `rocminfo` Does Not Show `gfx1201`

Fix the host ROCm/AMDGPU stack first. The container cannot expose a GPU that the host driver does not enumerate correctly.

## `torch.cuda.is_available()` Is False

Check that the container has both `/dev/kfd` and `/dev/dri`, plus the correct `render` and `video` group IDs.

## vLLM Does Not Import

Do not mix package versions. Rebuild with the pinned Dockerfile and avoid upgrading ROCm, Torch, NumPy, or vLLM inside the container.

## The Model Runs Slowly

Check for FP8 fallback symptoms: high VRAM usage, low GPU power, and throughput around 1-5 tok/s. The validated `Qwen/Qwen3-8B-FP8` path should be much faster on RX 9070 XT.

## Container Missing `/dev/kfd` Or `/dev/dri`

Run with `--device=/dev/kfd --device=/dev/dri` or use `scripts/run.sh`, which includes the required device mappings.
