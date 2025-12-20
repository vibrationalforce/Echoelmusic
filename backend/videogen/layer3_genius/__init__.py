"""
Layer 3: Genius Features
- Dynamic Prompt Expansion with local LLM
- Auto Resource Check and optimization
- Genre-specific prompt engineering
- Adaptive configuration based on hardware
- Style Morphing (inspired by Minimal Audio)
- Stream Browser for cloud content discovery
- Audio-Reactive Video Generation (S2V)
- Video Warp Effects System
- Multi-Shot Scene Orchestration
- Lip-Sync Engine
- Video Inpainting
- Character Consistency Tracking
"""

from .prompt_expander import PromptExpander, VideoGenre, ExpandedPrompt
from .resource_checker import ResourceChecker, HardwareProfile, OptimalConfig
from .style_morph import (
    VisualStyle,
    MorphConfig,
    MultiStyleBlend,
    StyleMorpher,
    style_morpher,
    MORPH_PRESETS,
)
from .stream_browser import (
    ContentCategory,
    SortOrder,
    StreamContent,
    StreamFilter,
    StreamBrowser,
    stream_browser,
)
from .audio_reactive import (
    AudioFeature,
    VideoParameter,
    ModulationRoute,
    S2VConfig,
    S2V_PRESETS,
    AudioAnalysis,
    AudioAnalyzer,
    audio_analyzer,
    S2VModulator,
)
from .warp_effects import (
    WarpCategory,
    WarpType,
    WarpKeyframe,
    WarpEffect,
    WarpChain,
    WarpProcessor,
    warp_processor,
    WARP_PRESETS,
)
from .scene_orchestrator import (
    TransitionType,
    SceneType,
    MoodType,
    SceneElement,
    SceneDefinition,
    Timeline,
    SceneBreakdown,
    SceneOrchestrator,
    get_scene_orchestrator,
    breakdown_complex_prompt,
)
from .lipsync_engine import (
    Viseme,
    Expression,
    Phoneme,
    VisemeKeyframe,
    LipSyncTrack,
    LipSyncConfig,
    LipSyncEngine,
    get_lipsync_engine,
    generate_lipsync_from_audio,
)
from .video_inpainting import (
    InpaintMode,
    BlendMode,
    MaskFrame,
    InpaintRegion,
    InpaintResult,
    InpaintConfig,
    VideoInpainter,
    get_video_inpainter,
    inpaint_video,
)
from .consistency_tracker import (
    TrackingState,
    EntityType,
    BoundingBox,
    EntityAppearance,
    TrackedEntity,
    ConsistencyScore,
    ConsistencyConfig,
    ConsistencyTracker,
    get_consistency_tracker,
    track_entity_consistency,
)

__all__ = [
    # Prompt Expansion
    "PromptExpander",
    "VideoGenre",
    "ExpandedPrompt",
    # Resource Management
    "ResourceChecker",
    "HardwareProfile",
    "OptimalConfig",
    # Style Morphing
    "VisualStyle",
    "MorphConfig",
    "MultiStyleBlend",
    "StyleMorpher",
    "style_morpher",
    "MORPH_PRESETS",
    # Stream Browser
    "ContentCategory",
    "SortOrder",
    "StreamContent",
    "StreamFilter",
    "StreamBrowser",
    "stream_browser",
    # Audio-Reactive (S2V)
    "AudioFeature",
    "VideoParameter",
    "ModulationRoute",
    "S2VConfig",
    "S2V_PRESETS",
    "AudioAnalysis",
    "AudioAnalyzer",
    "audio_analyzer",
    "S2VModulator",
    # Warp Effects
    "WarpCategory",
    "WarpType",
    "WarpKeyframe",
    "WarpEffect",
    "WarpChain",
    "WarpProcessor",
    "warp_processor",
    "WARP_PRESETS",
    # Scene Orchestration
    "TransitionType",
    "SceneType",
    "MoodType",
    "SceneElement",
    "SceneDefinition",
    "Timeline",
    "SceneBreakdown",
    "SceneOrchestrator",
    "get_scene_orchestrator",
    "breakdown_complex_prompt",
    # Lip-Sync
    "Viseme",
    "Expression",
    "Phoneme",
    "VisemeKeyframe",
    "LipSyncTrack",
    "LipSyncConfig",
    "LipSyncEngine",
    "get_lipsync_engine",
    "generate_lipsync_from_audio",
    # Video Inpainting
    "InpaintMode",
    "BlendMode",
    "MaskFrame",
    "InpaintRegion",
    "InpaintResult",
    "InpaintConfig",
    "VideoInpainter",
    "get_video_inpainter",
    "inpaint_video",
    # Consistency Tracking
    "TrackingState",
    "EntityType",
    "BoundingBox",
    "EntityAppearance",
    "TrackedEntity",
    "ConsistencyScore",
    "ConsistencyConfig",
    "ConsistencyTracker",
    "get_consistency_tracker",
    "track_entity_consistency",
]
