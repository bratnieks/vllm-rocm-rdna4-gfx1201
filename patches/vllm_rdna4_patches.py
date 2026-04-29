#!/usr/bin/env python3
"""
vLLM RDNA4 / gfx1201 compatibility patches.

Observed issue:
- In containers on RDNA4, amdsmi can fail to initialize.
- torch.cuda.device_count() may report 0 during vLLM platform detection.
- HIP can still see the device and GPU execution works.

This script patches the pinned vLLM checkout to prefer HIP-based discovery and
to use PYTORCH_ROCM_ARCH as the GCN arch fallback.
"""
import os
import shutil


def patch_platform_detection():
    path = "/app/vllm/vllm/platforms/__init__.py"
    with open(path) as f:
        lines = f.readlines()

    new_lines = []
    skip = False
    patched = False

    for i, line in enumerate(lines):
        if "def rocm_platform_plugin" in line and not skip:
            skip = True
            patched = True
            new_lines.extend([
                "def rocm_platform_plugin() -> str | None:\n",
                "    logger.debug(\"Checking if ROCm platform is available.\")\n",
                "    try:\n",
                "        import ctypes\n",
                "        hip = ctypes.CDLL(\"libamdhip64.so\")\n",
                "        count = ctypes.c_int()\n",
                "        result = hip.hipGetDeviceCount(ctypes.byref(count))\n",
                "        if result == 0 and count.value > 0:\n",
                "            logger.debug(\"ROCm platform available via HIP.\")\n",
                "            return \"vllm.platforms.rocm.RocmPlatform\"\n",
                "        logger.debug(\"ROCm not available via HIP\")\n",
                "    except Exception as e:\n",
                "        logger.debug(\"ROCm not available: \" + str(e))\n",
                "    return None\n",
            ])
            continue

        if skip:
            if line.strip() == "":
                if i + 1 < len(lines) and lines[i + 1] and not lines[i + 1][0].isspace():
                    skip = False
                    new_lines.append("\n")
            elif not line[0].isspace():
                skip = False
                new_lines.append(line)
            continue

        new_lines.append(line)

    with open(path, "w") as f:
        f.writelines(new_lines)

    return patched


def patch_gcn_arch_fallback():
    path = "/app/vllm/vllm/platforms/rocm.py"
    with open(path) as f:
        content = f.read()

    if "\nimport os\n" not in content:
        content = content.replace("import logging\n", "import logging\nimport os\n", 1)

    old_block = (
        "    except Exception as e:\n"
        "        logger.debug(\"Failed to get GCN arch via amdsmi: %s\", e)\n"
        "        logger.warning_once(\n"
        "            \"Failed to get GCN arch via amdsmi, falling back to torch.cuda. \"\n"
        "            \"This will initialize CUDA and may cause \"\n"
        "            \"issues if CUDA_VISIBLE_DEVICES is not set yet.\"\n"
        "        )\n"
        "    # Ultimate fallback: use torch.cuda (will initialize CUDA)\n"
        "    return torch.cuda.get_device_properties(\"cuda\").gcnArchName"
    )
    new_block = (
        "    except Exception as e:\n"
        "        logger.debug(\"Failed to get GCN arch via amdsmi: %s\", e)\n"
        "    arch_env = os.environ.get(\"PYTORCH_ROCM_ARCH\", \"\")\n"
        "    if arch_env:\n"
        "        logger.info(\"Using PYTORCH_ROCM_ARCH=%s for GCN arch\", arch_env)\n"
        "        return arch_env\n"
        "    logger.warning(\n"
        "        \"Failed to get GCN arch via amdsmi, falling back to torch.cuda. \"\n"
        "        \"This will initialize CUDA and may cause \"\n"
        "        \"issues if CUDA_VISIBLE_DEVICES is not set yet.\"\n"
        "    )\n"
        "    return torch.cuda.get_device_properties(\"cuda\").gcnArchName"
    )

    patched = old_block in content
    content = content.replace(old_block, new_block)

    with open(path, "w") as f:
        f.write(content)

    return patched


def patch_torch_device_count():
    path = "/app/vllm/vllm/platforms/rocm.py"
    with open(path) as f:
        content = f.read()

    marker = "_GCN_ARCH = _get_gcn_arch()"
    patch_code = (
        "_GCN_ARCH = _get_gcn_arch()\n"
        "\n"
        "def _patch_torch_device_count():\n"
        "    import torch\n"
        "    if torch.cuda.device_count() == 0:\n"
        "        try:\n"
        "            import ctypes\n"
        "            hip = ctypes.CDLL(\"libamdhip64.so\")\n"
        "            count = ctypes.c_int()\n"
        "            result = hip.hipGetDeviceCount(ctypes.byref(count))\n"
        "            if result == 0 and count.value > 0:\n"
        "                n = count.value\n"
        "                torch.cuda.device_count = lambda: n\n"
        "                if hasattr(torch, \"accelerator\"):\n"
        "                    torch.accelerator.device_count = lambda: n\n"
        "                logger.info(\"Patched torch device_count to %d via HIP\", n)\n"
        "        except Exception as e:\n"
        "            logger.debug(\"HIP device_count patch failed: %s\", e)\n"
        "\n"
        "_patch_torch_device_count()\n"
    )

    patched = marker in content
    content = content.replace(marker, patch_code, 1)

    with open(path, "w") as f:
        f.write(content)

    return patched


def clear_pycache():
    for directory in [
        "/app/vllm/vllm/platforms/__pycache__",
        "/app/vllm/vllm/v1/worker/__pycache__",
    ]:
        if os.path.exists(directory):
            shutil.rmtree(directory)


if __name__ == "__main__":
    p1 = patch_platform_detection()
    p2 = patch_gcn_arch_fallback()
    p3 = patch_torch_device_count()
    clear_pycache()
    print(f"Platform detection via HIP: {'PATCHED' if p1 else 'FAILED'}")
    print(f"GCN arch env fallback: {'PATCHED' if p2 else 'FAILED'}")
    print(f"torch device_count via HIP: {'PATCHED' if p3 else 'FAILED'}")
