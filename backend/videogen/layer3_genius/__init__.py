"""
Layer 3: Genius Features
- Dynamic Prompt Expansion with local LLM
- Auto Resource Check and optimization
- Genre-specific prompt engineering
- Adaptive configuration based on hardware
- Style Morphing (inspired by Minimal Audio)
- Stream Browser for cloud content discovery
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
]
