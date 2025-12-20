"""
Echoelmusic Video Generation Backend
State-of-the-Art T2V Pipeline (2025)

Layers:
1. Inference Engine - Wan2.2-T2V-14B with TeaCache, Flash Attention 3
2. Workflow Logic - FastAPI + Redis/Celery async queue
3. Genius Features - LLM prompt expansion, auto-resource detection
4. Deployment - Docker with CUDA 12.6+

8K Mastering:
- Pyramid-Flow for motion consistency
- IP-Adapter-FaceID for character persistence
- Motion bucket control
- FFmpeg grain & sharpness tuning
- Zero-copy GPU transfers
"""

__version__ = "1.0.0"
__author__ = "Echoelmusic"

# Layer 1: Inference Engine
from .layer1_inference import (
    WanVideoGenerator,
    GenerationConfig,
    GenerationResult,
    PrecisionMode,
    TeaCache,
    TeaCacheConfig,
    MemoryManager,
    TiledVAEDecoder,
    NF4Quantizer,
    ZeroCopyTransfer,
    FlashAttention3,
)

# Layer 2: Workflow Logic
from .layer2_workflow import (
    app,
    VideoGenAPI,
    TaskQueue,
    VideoTask,
    TaskResult,
    TaskStatus,
    TaskPriority,
    generate_video_task,
    refine_video_task,
    batch_generate_task,
    VideoRefiner,
    RefineConfig,
)

# Layer 3: Genius Features
from .layer3_genius import (
    PromptExpander,
    VideoGenre,
    ExpandedPrompt,
    ResourceChecker,
    HardwareProfile,
    OptimalConfig,
)

# Layer 4: Deployment & Client
from .client import VideoGenClient, SyncVideoGenClient

__all__ = [
    # Version
    "__version__",
    "__author__",
    # Layer 1
    "WanVideoGenerator",
    "GenerationConfig",
    "GenerationResult",
    "PrecisionMode",
    "TeaCache",
    "TeaCacheConfig",
    "MemoryManager",
    "TiledVAEDecoder",
    "NF4Quantizer",
    "ZeroCopyTransfer",
    "FlashAttention3",
    # Layer 2
    "app",
    "VideoGenAPI",
    "TaskQueue",
    "VideoTask",
    "TaskResult",
    "TaskStatus",
    "TaskPriority",
    "generate_video_task",
    "refine_video_task",
    "batch_generate_task",
    "VideoRefiner",
    "RefineConfig",
    # Layer 3
    "PromptExpander",
    "VideoGenre",
    "ExpandedPrompt",
    "ResourceChecker",
    "HardwareProfile",
    "OptimalConfig",
    # Layer 4
    "VideoGenClient",
    "SyncVideoGenClient",
]
