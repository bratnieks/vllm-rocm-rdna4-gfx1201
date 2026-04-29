# Troubleshooting

## No ROCm-Capable Device

Check host devices:

```bash
ls -l /dev/kfd /dev/dri
```

Run the container with:

```bash
--device=/dev/kfd --device=/dev/dri --group-add render --group-add video
```

If group names do not work with Docker on your system, use numeric group IDs:

```bash
getent group render
getent group video
```

## `torch.cuda.device_count()` Reports 0

This is one of the RDNA4 container issues this repository patches.

Check that:

- `PYTORCH_ROCM_ARCH=gfx1201` is set.
- The patch script ran during the image build.
- `/dev/kfd` and `/dev/dri` are passed through.

## `amdsmi` Fails

This can happen inside containers on the validated stack. It does not necessarily mean HIP execution is broken.

The patch avoids using `amdsmi` as the only source of truth.

## `Qwen3.5` Models Do Not Load

The pinned vLLM revision may not register newer model architectures. During validation, a Qwen3.5 9B FP8 model failed with unsupported `Qwen3_5ForConditionalGeneration`.

Options:

- Use a supported architecture such as `Qwen/Qwen3-8B-FP8`.
- Rebuild with newer vLLM and accept that the ROCm/RDNA4 patch may need updates.

## FP8 Warning About Missing Kernel Config

Example:

```text
Using default W8A8 Block FP8 kernel config. Performance might be sub-optimal!
```

This means vLLM is using a default FP8 kernel configuration for RX 9070 XT. The model can still run, but performance may not be optimal.

## Docker Build Runs Out Of Disk

Use an external BuildKit state directory or a Docker data-root with enough space. Do not export/import large image tarballs unless necessary.

Example pattern:

```bash
docker buildx create --name rdna4_builder --use
BUILDER=rdna4_builder ./scripts/build.sh
```

## Hugging Face Cache On exFAT

Hugging Face cache uses symlinks by default. exFAT does not support them properly.

The cache still works but may use more space and print warnings. Prefer ext4/xfs for model caches when possible.
