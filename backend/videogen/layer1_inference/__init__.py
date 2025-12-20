"""
Layer 1: Inference Engine
- Wan2.2-T2V-14B model inference
- TeaCache for redundancy-free frame computation
- Flash Attention 3 for memory efficiency
- Tiled VAE Decoding for 4K output
- NF4 Quantization for consumer GPUs
- Zero-Copy GPU transfers
- Multi-Model Orchestration
- Batch Inference Pipeline
- Speculative Decoding
- Video-to-Video Transformation
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
from .model_orchestrator import (
    ModelTier,
    ComplexityLevel,
    ModelProfile,
    PromptAnalysis,
    OrchestrationDecision,
    PromptAnalyzer,
    ModelOrchestrator,
    get_orchestrator,
    select_optimal_model,
)
from .batch_inference import (
    BatchPriority,
    BatchStatus,
    BatchItem,
    Batch,
    BatchConfig,
    BatchProcessor,
    get_batch_processor,
    submit_batch_generation,
)
from .speculative_decoder import (
    SpeculationStrategy,
    SpeculationConfig,
    SpeculationStats,
    SpeculativeDecoder,
    SpeculativeVideoDecoder,
    get_speculative_decoder,
    get_speculative_video_decoder,
)
from .video_to_video import (
    V2VMode,
    StructurePreservation,
    V2VConfig,
    V2VInput,
    V2VOutput,
    VideoToVideoPipeline,
    StyleTransferPipeline,
    EnhancementPipeline,
    get_v2v_pipeline,
    transform_video,
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
    # Model Orchestration
    "ModelTier",
    "ComplexityLevel",
    "ModelProfile",
    "PromptAnalysis",
    "OrchestrationDecision",
    "PromptAnalyzer",
    "ModelOrchestrator",
    "get_orchestrator",
    "select_optimal_model",
    # Batch Inference
    "BatchPriority",
    "BatchStatus",
    "BatchItem",
    "Batch",
    "BatchConfig",
    "BatchProcessor",
    "get_batch_processor",
    "submit_batch_generation",
    # Speculative Decoding
    "SpeculationStrategy",
    "SpeculationConfig",
    "SpeculationStats",
    "SpeculativeDecoder",
    "SpeculativeVideoDecoder",
    "get_speculative_decoder",
    "get_speculative_video_decoder",
    # Video-to-Video
    "V2VMode",
    "StructurePreservation",
    "V2VConfig",
    "V2VInput",
    "V2VOutput",
    "VideoToVideoPipeline",
    "StyleTransferPipeline",
    "EnhancementPipeline",
    "get_v2v_pipeline",
    "transform_video",
]
