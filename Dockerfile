# Echoelmusic Video Generation - Production Dockerfile
# Multi-stage build for minimal image size

# ============================================================================
# Stage 1: Base with CUDA
# ============================================================================
FROM nvidia/cuda:12.1-cudnn8-runtime-ubuntu22.04 AS base

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.11 \
    python3.11-venv \
    python3-pip \
    ffmpeg \
    libsm6 \
    libxext6 \
    libgl1-mesa-glx \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 echouser
WORKDIR /app

# ============================================================================
# Stage 2: Dependencies
# ============================================================================
FROM base AS dependencies

# Install Python dependencies
COPY requirements.txt requirements-prod.txt ./
RUN pip3 install --no-cache-dir -r requirements-prod.txt

# ============================================================================
# Stage 3: Production
# ============================================================================
FROM dependencies AS production

# Copy application code
COPY --chown=echouser:echouser backend/ ./backend/
COPY --chown=echouser:echouser scripts/ ./scripts/

# Create necessary directories
RUN mkdir -p /app/data/videos /app/data/thumbnails /app/data/cache /app/logs \
    && chown -R echouser:echouser /app

# Switch to non-root user
USER echouser

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# Expose port
EXPOSE 8000

# Default command
CMD ["python3", "-m", "uvicorn", "backend.videogen.layer2_workflow.api:app", \
     "--host", "0.0.0.0", "--port", "8000", "--workers", "4"]
