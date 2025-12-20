# Echoelmusic Video Generation Pipeline
# Multi-stage Docker build for production deployment
#
# Features:
# - CUDA 12.6 with cuDNN 9
# - Flash Attention 3 support (Hopper GPUs)
# - Optimized for NVIDIA RTX 40/50 series and H100
# - Multi-stage build for smaller final image

# ============================================================
# Stage 1: Builder - Compile dependencies
# ============================================================
FROM nvidia/cuda:12.6.0-devel-ubuntu22.04 AS builder

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    ninja-build \
    git \
    curl \
    wget \
    python3.11 \
    python3.11-dev \
    python3.11-venv \
    python3-pip \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.11 as default
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1 && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Upgrade pip
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Install PyTorch with CUDA 12.6
RUN pip install --no-cache-dir \
    torch==2.4.0+cu126 \
    torchvision==0.19.0+cu126 \
    torchaudio==2.4.0+cu126 \
    --index-url https://download.pytorch.org/whl/cu126

# Install Flash Attention (requires compilation)
# Note: Requires CUDA 12.6+ and SM 80+ (Ampere/Hopper)
RUN pip install --no-cache-dir packaging ninja && \
    pip install --no-cache-dir flash-attn --no-build-isolation

# Copy requirements and install dependencies
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

# ============================================================
# Stage 2: Runtime - Minimal production image
# ============================================================
FROM nvidia/cuda:12.6.0-runtime-ubuntu22.04 AS runtime

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 \
    python3.11-venv \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    ffmpeg \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash videogen

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Set Python path
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONPATH=/app

# Create directories
WORKDIR /app
RUN mkdir -p /app/models /app/output /app/cache /app/logs && \
    chown -R videogen:videogen /app

# Copy application code
COPY --chown=videogen:videogen . /app/videogen

# Environment variables
ENV HF_HOME=/app/cache/huggingface
ENV TORCH_HOME=/app/cache/torch
ENV TRANSFORMERS_CACHE=/app/cache/transformers
ENV VIDEO_OUTPUT_DIR=/app/output
ENV MODEL_CACHE_DIR=/app/models

# CUDA settings
ENV CUDA_DEVICE_ORDER=PCI_BUS_ID
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

# Memory optimization
ENV PYTORCH_CUDA_ALLOC_CONF=max_split_size_mb:512

# Switch to non-root user
USER videogen

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose API port
EXPOSE 8000

# Default command - API server
CMD ["uvicorn", "videogen.layer2_workflow.api:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]

# ============================================================
# Stage 3: Worker - Celery worker for background tasks
# ============================================================
FROM runtime AS worker

# Worker-specific settings
ENV C_FORCE_ROOT=0
ENV CELERY_WORKER_CONCURRENCY=1

# Health check for worker
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD celery -A videogen.layer2_workflow.tasks inspect ping || exit 1

# Run Celery worker
CMD ["celery", "-A", "videogen.layer2_workflow.tasks", "worker", "--loglevel=info", "--concurrency=1", "-Q", "video_generation,video_refinement,video_priority"]
