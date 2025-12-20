"""
Layer 3: Genius Features
- Dynamic Prompt Expansion with local LLM
- Auto Resource Check and optimization
- Genre-specific prompt engineering
- Adaptive configuration based on hardware
"""

from .prompt_expander import PromptExpander, VideoGenre, ExpandedPrompt
from .resource_checker import ResourceChecker, HardwareProfile, OptimalConfig

__all__ = [
    "PromptExpander",
    "VideoGenre",
    "ExpandedPrompt",
    "ResourceChecker",
    "HardwareProfile",
    "OptimalConfig"
]
