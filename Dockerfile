# syntax=docker/dockerfile:1-labs
ARG AMDGPU_FAMILY=gfx120X-all
ARG GPU_ARCH=gfx1201
ARG ROCM_VERSION=7.12.0a20260204
ARG TORCH_VERSION=2.9.1+rocm7.12.0a20260204
ARG TORCHVISION_VERSION=0.24.0+rocm7.12.0a20260204
ARG TORCHAUDIO_VERSION=2.9.0+rocm7.12.0a20260204
ARG VLLM_REF=v0.16.0rc0
ARG FLASH_ATTN_REF=enable-ck-gfx12
ARG TRANSFORMERS_VERSION=5.7.0

FROM ubuntu:24.04 AS base

ENV PYTHONUNBUFFERED=1
ARG AMDGPU_FAMILY
ARG GPU_ARCH
ARG ROCM_VERSION
ARG TORCH_VERSION
ARG TORCHVISION_VERSION
ARG TORCHAUDIO_VERSION
ARG VLLM_REF
ARG FLASH_ATTN_REF
ARG TRANSFORMERS_VERSION

SHELL ["/bin/bash", "-l", "-c"]
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    libatomic1 \
    libgomp1 \
    libdrm-dev \
    libnuma-dev \
    ninja-build \
    wget && \
    rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

RUN uv venv --python 3.12 /app/.venv && \
    echo "source /app/.venv/bin/activate" > /root/.bash_profile

ENV PATH="/app/.venv/bin:${PATH}"

RUN uv pip install \
    --index-url https://rocm.nightlies.amd.com/v2/${AMDGPU_FAMILY}/ \
    "rocm[libraries, devel]==${ROCM_VERSION}" && \
    uv pip install \
    --index-url https://rocm.nightlies.amd.com/v2/${AMDGPU_FAMILY}/ \
    "torch==${TORCH_VERSION}" \
    "torchvision==${TORCHVISION_VERSION}" \
    "torchaudio==${TORCHAUDIO_VERSION}"

RUN mkdir -p /opt/rocm-${ROCM_VERSION} && \
    wget https://rocm.nightlies.amd.com/tarball/therock-dist-linux-${AMDGPU_FAMILY}-${ROCM_VERSION}.tar.gz && \
    tar xzf ./therock-dist-linux-${AMDGPU_FAMILY}-${ROCM_VERSION}.tar.gz -C /opt/rocm-${ROCM_VERSION} && \
    rm therock-dist-linux-${AMDGPU_FAMILY}-${ROCM_VERSION}.tar.gz && \
    ln -s /opt/rocm-${ROCM_VERSION} /opt/rocm

ENV ROCM_PATH=/opt/rocm
ENV LD_LIBRARY_PATH=${ROCM_PATH}/lib
ENV DEVICE_LIB_PATH=${ROCM_PATH}/llvm/amdgcn/bitcode
ENV HIP_DEVICE_LIB_PATH=${ROCM_PATH}/llvm/amdgcn/bitcode
ENV FLASH_ATTENTION_TRITON_AMD_ENABLE=TRUE
ENV PYTORCH_ROCM_ARCH=${GPU_ARCH}
ENV PATH=${ROCM_PATH}/bin:${ROCM_PATH}/llvm/bin:${PATH}
ENV CC=${ROCM_PATH}/llvm/bin/clang
ENV CXX=${ROCM_PATH}/llvm/bin/clang++
ENV HIPCC=${ROCM_PATH}/bin/hipcc
ENV VLLM_TARGET_DEVICE=rocm
ENV GPU_TARGETS=${GPU_ARCH}
ENV AMDGPU_TARGETS=${GPU_ARCH}
ENV CMAKE_ARGS="-DGPU_TARGETS=${GPU_ARCH} -DAMDGPU_TARGETS=${GPU_ARCH} -DCMAKE_HIP_ARCHITECTURES=${GPU_ARCH}"
ENV MAX_JOBS=8
ENV CMAKE_BUILD_PARALLEL_LEVEL=8
ENV Torch_DIR="/app/.venv/lib/python3.12/site-packages/torch/share/cmake/Torch"

RUN cp /root/.bash_profile /root/.bashrc

# PyTorch nightly CMake files can contain hardcoded TheRock build-server paths.
# Build libdrm-compatible include paths so vLLM ROCm extension builds can resolve them.
RUN mkdir -p /therock/output/build/third-party/sysdeps/linux/libdrm/build/stage/lib/rocm_sysdeps/lib/pkgconfig && \
    mkdir -p /therock/output/build/third-party/sysdeps/linux/libdrm/build/stage/lib/rocm_sysdeps/include && \
    cp -r /usr/include/libdrm /therock/output/build/third-party/sysdeps/linux/libdrm/build/stage/lib/rocm_sysdeps/include/ && \
    cp /usr/include/xf86drm*.h /therock/output/build/third-party/sysdeps/linux/libdrm/build/stage/lib/rocm_sysdeps/include/

RUN --security=insecure git clone https://github.com/vllm-project/vllm.git /app/vllm && \
    cd /app/vllm && \
    git checkout ${VLLM_REF} && \
    python use_existing_torch.py && \
    uv pip install --upgrade numba scipy cmake setuptools_scm && \
    uv pip install "numpy<2" && \
    uv pip install -r requirements/rocm.txt && \
    python setup.py develop && \
    uv pip install --upgrade "transformers==${TRANSFORMERS_VERSION}" && \
    uv pip install /opt/rocm/share/amd_smi

COPY patches/vllm_rdna4_patches.py /tmp/vllm_rdna4_patches.py
RUN python /tmp/vllm_rdna4_patches.py

RUN git clone https://github.com/hyoon1/flash-attention.git /app/flash-attention && \
    cd /app/flash-attention && \
    git checkout ${FLASH_ATTN_REF} && \
    FLASH_ATTENTION_TRITON_AMD_ENABLE=TRUE python setup.py install

ENTRYPOINT ["/app/.venv/bin/vllm", "serve"]
