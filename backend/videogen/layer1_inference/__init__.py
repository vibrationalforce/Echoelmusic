"""
Layer 1: Inference Engine
- Wan2.2-T2V-14B model inference
- TeaCache for redundancy-free frame computation
- Flash Attention 3 for memory efficiency
- Tiled VAE Decoding for 4K output
- NF4 Quantization for consumer GPUs
- Zero-Copy GPU transfers
"""

from .wan_inference import (
    WanVideoGenerator,
    GenerationConfig,
    GenerationResult,
    PrecisionMode,
    VideoResolution,
    GenerationMode,
    I2VConfig,
)
from .tea_cache import TeaCache, TeaCacheConfig, TemporalRedundancyAnalyzer
from .memory_manager import (
    MemoryManager,
    TiledVAEDecoder,
    NF4Quantizer,
    ZeroCopyTransfer,
    MemoryStats,
    OffloadStrategy,
)
from .attention import FlashAttention3Wrapper as FlashAttention3
from .lora_controlnet import (
    LoRAType,
    ControlNetType,
    LoRAConfig,
    ControlNetConfig,
    IPAdapterConfig,
    LoRAManager,
    ControlNetManager,
    IPAdapterManager,
    AdapterHook,
)

__all__ = [
    # Inference
    "WanVideoGenerator",
    "GenerationConfig",
    "GenerationResult",
    "PrecisionMode",
    "VideoResolution",
    "GenerationMode",
    "I2VConfig",
    # TeaCache
    "TeaCache",
    "TeaCacheConfig",
    "TemporalRedundancyAnalyzer",
    # Memory Management
    "MemoryManager",
    "MemoryStats",
    "TiledVAEDecoder",
    "NF4Quantizer",
    "ZeroCopyTransfer",
    "OffloadStrategy",
    # Attention
    "FlashAttention3",
    # LoRA/ControlNet
    "LoRAType",
    "ControlNetType",
    "LoRAConfig",
    "ControlNetConfig",
    "IPAdapterConfig",
    "LoRAManager",
    "ControlNetManager",
    "IPAdapterManager",
    "AdapterHook",
]
