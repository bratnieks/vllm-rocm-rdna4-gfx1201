# FP8 Notes

FP8 can mean different things depending on the model, runtime, and kernel path.

## Real FP8

"Real FP8" usually means:

- The checkpoint stores weights in an FP8-oriented format.
- The runtime recognizes the model as FP8 quantized.
- Matrix multiplication paths use FP8 kernels where supported.
- The GPU/compiler stack has tuned kernels for the target device.

## Fake Or Partial FP8

"Fake FP8" or partial FP8 can happen when:

- Weights are distributed in an FP8-labeled format but some operations dequantize to BF16/FP16.
- The runtime falls back to generic kernels.
- The target GPU lacks tuned configs for specific matrix shapes.
- KV cache, attention, sampling, or non-GEMM operations remain in other dtypes.

This setup validated that vLLM loads `Qwen/Qwen3-8B-FP8` with:

- `quantization=fp8`
- `dtype=torch.bfloat16`
- ROCm Triton Attention backend

The logs also showed warnings like:

```text
Using default W8A8 Block FP8 kernel config. Performance might be sub-optimal!
Config file not found ... device_name=AMD_Radeon_RX_9070_XT,dtype=fp8_w8a8
```

That warning matters. It means the model can run, but the RDNA4/gfx1201 FP8 path is not fully tuned.

## Practical Interpretation

For this repository:

- "FP8 works" means vLLM can load and serve the validated FP8 checkpoint on RX 9070 XT.
- It does not mean every op is native FP8.
- It does not mean the throughput is optimal.
- It does not mean every FP8 checkpoint will load.

Use logs and benchmarks when comparing model formats.
