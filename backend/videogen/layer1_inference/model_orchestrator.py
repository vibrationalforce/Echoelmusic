"""
Multi-Model Orchestrator - Super Genius AI Feature #1

Dynamically selects and routes generation requests to the optimal model
based on prompt complexity, available VRAM, and quality requirements.

Features:
- Automatic model selection based on prompt analysis
- VRAM-aware model loading/unloading
- Quality-speed tradeoff optimization
- Model warm-up and caching
- Fallback chain for graceful degradation
"""

import asyncio
import torch
import hashlib
import re
from dataclasses import dataclass, field
from enum import Enum
from typing import Dict, List, Optional, Tuple, Any, Callable
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)


class ModelTier(str, Enum):
    """Model quality tiers for different use cases."""
    ULTRA = "ultra"      # Wan2.2-T2V-14B - Highest quality
    HIGH = "high"        # Wan2.2-T2V-7B - High quality, faster
    STANDARD = "standard" # Wan2.2-T2V-1.3B - Balanced
    FAST = "fast"        # Lightweight model - Speed priority
    PREVIEW = "preview"  # Fastest, lowest quality for previews


class ComplexityLevel(str, Enum):
    """Prompt complexity classification."""
    SIMPLE = "simple"           # Single object, static scene
    MODERATE = "moderate"       # Multiple objects, simple motion
    COMPLEX = "complex"         # Complex scene, multiple motions
    ULTRA_COMPLEX = "ultra"     # Cinematic, multiple characters


@dataclass
class ModelProfile:
    """Profile describing a model's capabilities and requirements."""
    name: str
    tier: ModelTier
    model_path: str
    vram_required_gb: float
    max_resolution: Tuple[int, int]
    max_frames: int
    supports_i2v: bool
    supports_controlnet: bool
    average_speed: float  # seconds per frame
    quality_score: float  # 0-1 quality rating
    warmup_time: float   # seconds to load

    # Optional features
    supports_lora: bool = True
    supports_tea_cache: bool = True
    supports_tiled_vae: bool = True
    precision: str = "bf16"


@dataclass
class PromptAnalysis:
    """Analysis results for a generation prompt."""
    complexity: ComplexityLevel
    estimated_objects: int
    has_motion: bool
    motion_complexity: float  # 0-1
    scene_transitions: int
    character_count: int
    requires_consistency: bool
    cinematic_level: float  # 0-1
    detail_level: float  # 0-1
    recommended_tier: ModelTier

    # Keyword analysis
    action_keywords: List[str] = field(default_factory=list)
    style_keywords: List[str] = field(default_factory=list)
    quality_keywords: List[str] = field(default_factory=list)


@dataclass
class OrchestrationDecision:
    """Decision output from the orchestrator."""
    selected_model: ModelProfile
    fallback_models: List[ModelProfile]
    reason: str
    estimated_time: float
    estimated_quality: float
    config_overrides: Dict[str, Any]
    warnings: List[str] = field(default_factory=list)


@dataclass
class ModelState:
    """Runtime state of a loaded model."""
    profile: ModelProfile
    is_loaded: bool
    load_time: datetime
    last_used: datetime
    generation_count: int
    average_latency: float
    error_count: int

    @property
    def idle_time(self) -> timedelta:
        return datetime.now() - self.last_used


class PromptAnalyzer:
    """Analyzes prompts to determine complexity and requirements."""

    # Keyword patterns for complexity detection
    ACTION_KEYWORDS = {
        "simple": ["standing", "sitting", "looking", "static", "still"],
        "moderate": ["walking", "running", "moving", "turning", "waving"],
        "complex": ["dancing", "fighting", "flying", "transforming", "morphing"],
        "ultra": ["explosion", "crowd", "battle", "chase", "orchestra"]
    }

    STYLE_KEYWORDS = {
        "cinematic": ["cinematic", "movie", "film", "hollywood", "blockbuster"],
        "artistic": ["artistic", "painting", "abstract", "surreal", "dreamlike"],
        "realistic": ["realistic", "photorealistic", "real", "lifelike", "natural"],
        "anime": ["anime", "manga", "cartoon", "animated", "2d"]
    }

    QUALITY_KEYWORDS = [
        "8k", "4k", "hdr", "high quality", "detailed", "masterpiece",
        "professional", "premium", "best quality", "ultra detailed"
    ]

    MOTION_KEYWORDS = [
        "moving", "walking", "running", "dancing", "flying", "spinning",
        "jumping", "falling", "exploding", "transforming", "flowing"
    ]

    def analyze(self, prompt: str) -> PromptAnalysis:
        """Analyze a prompt for complexity and requirements."""
        prompt_lower = prompt.lower()

        # Detect action keywords
        action_keywords = []
        action_level = "simple"
        for level, keywords in self.ACTION_KEYWORDS.items():
            for keyword in keywords:
                if keyword in prompt_lower:
                    action_keywords.append(keyword)
                    if self._complexity_order(level) > self._complexity_order(action_level):
                        action_level = level

        # Detect style keywords
        style_keywords = []
        for style, keywords in self.STYLE_KEYWORDS.items():
            for keyword in keywords:
                if keyword in prompt_lower:
                    style_keywords.append(keyword)

        # Detect quality keywords
        quality_keywords = [kw for kw in self.QUALITY_KEYWORDS if kw in prompt_lower]

        # Estimate object count (simple heuristic)
        object_patterns = [
            r'\b(a|an|the|one|two|three|four|five|multiple|several|many)\s+\w+',
        ]
        estimated_objects = 1
        for pattern in object_patterns:
            matches = re.findall(pattern, prompt_lower)
            if matches:
                estimated_objects = max(estimated_objects, len(matches))

        # Detect motion
        has_motion = any(kw in prompt_lower for kw in self.MOTION_KEYWORDS)
        motion_complexity = sum(1 for kw in self.MOTION_KEYWORDS if kw in prompt_lower) / len(self.MOTION_KEYWORDS)

        # Detect scene transitions
        transition_words = ["then", "after", "before", "next", "followed by", "transforms into"]
        scene_transitions = sum(1 for tw in transition_words if tw in prompt_lower)

        # Character detection
        character_words = ["person", "man", "woman", "character", "people", "crowd", "group"]
        character_count = sum(1 for cw in character_words if cw in prompt_lower)

        # Cinematic level
        cinematic_level = len([kw for kw in self.STYLE_KEYWORDS.get("cinematic", []) if kw in prompt_lower]) / 5

        # Detail level based on quality keywords
        detail_level = min(1.0, len(quality_keywords) / 5)

        # Determine complexity
        complexity = self._determine_complexity(
            action_level, estimated_objects, has_motion,
            scene_transitions, character_count
        )

        # Requires consistency check
        requires_consistency = character_count > 1 or scene_transitions > 0

        # Recommend tier
        recommended_tier = self._recommend_tier(
            complexity, detail_level, cinematic_level, has_motion
        )

        return PromptAnalysis(
            complexity=complexity,
            estimated_objects=estimated_objects,
            has_motion=has_motion,
            motion_complexity=motion_complexity,
            scene_transitions=scene_transitions,
            character_count=character_count,
            requires_consistency=requires_consistency,
            cinematic_level=cinematic_level,
            detail_level=detail_level,
            recommended_tier=recommended_tier,
            action_keywords=action_keywords,
            style_keywords=style_keywords,
            quality_keywords=quality_keywords
        )

    def _complexity_order(self, level: str) -> int:
        order = {"simple": 0, "moderate": 1, "complex": 2, "ultra": 3}
        return order.get(level, 0)

    def _determine_complexity(
        self,
        action_level: str,
        objects: int,
        has_motion: bool,
        transitions: int,
        characters: int
    ) -> ComplexityLevel:
        score = self._complexity_order(action_level)

        if objects > 5:
            score += 1
        if has_motion:
            score += 1
        if transitions > 2:
            score += 1
        if characters > 2:
            score += 1

        if score >= 4:
            return ComplexityLevel.ULTRA_COMPLEX
        elif score >= 3:
            return ComplexityLevel.COMPLEX
        elif score >= 1:
            return ComplexityLevel.MODERATE
        else:
            return ComplexityLevel.SIMPLE

    def _recommend_tier(
        self,
        complexity: ComplexityLevel,
        detail_level: float,
        cinematic_level: float,
        has_motion: bool
    ) -> ModelTier:
        # Base tier from complexity
        tier_map = {
            ComplexityLevel.SIMPLE: ModelTier.STANDARD,
            ComplexityLevel.MODERATE: ModelTier.HIGH,
            ComplexityLevel.COMPLEX: ModelTier.HIGH,
            ComplexityLevel.ULTRA_COMPLEX: ModelTier.ULTRA
        }
        base_tier = tier_map[complexity]

        # Upgrade for quality requirements
        if detail_level > 0.6 or cinematic_level > 0.4:
            if base_tier == ModelTier.STANDARD:
                return ModelTier.HIGH
            elif base_tier == ModelTier.HIGH:
                return ModelTier.ULTRA

        return base_tier


class ModelOrchestrator:
    """
    Orchestrates model selection and management for optimal generation.

    Features:
    - Dynamic model selection based on prompt analysis
    - VRAM-aware model management
    - Automatic fallback chains
    - Model warming and caching
    """

    # Default model profiles
    DEFAULT_PROFILES: List[ModelProfile] = [
        ModelProfile(
            name="wan2.2-t2v-14b",
            tier=ModelTier.ULTRA,
            model_path="Wan-AI/Wan2.2-T2V-14B",
            vram_required_gb=24.0,
            max_resolution=(1920, 1080),
            max_frames=129,
            supports_i2v=True,
            supports_controlnet=True,
            average_speed=8.0,
            quality_score=1.0,
            warmup_time=60.0
        ),
        ModelProfile(
            name="wan2.2-t2v-7b",
            tier=ModelTier.HIGH,
            model_path="Wan-AI/Wan2.2-T2V-7B",
            vram_required_gb=16.0,
            max_resolution=(1280, 720),
            max_frames=97,
            supports_i2v=True,
            supports_controlnet=True,
            average_speed=5.0,
            quality_score=0.85,
            warmup_time=40.0
        ),
        ModelProfile(
            name="wan2.2-t2v-1.3b",
            tier=ModelTier.STANDARD,
            model_path="Wan-AI/Wan2.2-T2V-1.3B",
            vram_required_gb=8.0,
            max_resolution=(1280, 720),
            max_frames=81,
            supports_i2v=True,
            supports_controlnet=True,
            average_speed=2.0,
            quality_score=0.7,
            warmup_time=20.0
        ),
        ModelProfile(
            name="wan2.1-t2v-fast",
            tier=ModelTier.FAST,
            model_path="Wan-AI/Wan2.1-T2V-Fast",
            vram_required_gb=6.0,
            max_resolution=(854, 480),
            max_frames=49,
            supports_i2v=False,
            supports_controlnet=False,
            average_speed=1.0,
            quality_score=0.5,
            warmup_time=10.0,
            supports_lora=False
        ),
        ModelProfile(
            name="preview-model",
            tier=ModelTier.PREVIEW,
            model_path="preview/fast-preview",
            vram_required_gb=4.0,
            max_resolution=(512, 288),
            max_frames=25,
            supports_i2v=False,
            supports_controlnet=False,
            average_speed=0.3,
            quality_score=0.3,
            warmup_time=5.0,
            supports_lora=False,
            supports_tea_cache=False
        )
    ]

    def __init__(
        self,
        custom_profiles: Optional[List[ModelProfile]] = None,
        max_loaded_models: int = 2,
        unload_idle_after_seconds: int = 300,
        prefer_quality: bool = True
    ):
        self.profiles = custom_profiles or self.DEFAULT_PROFILES
        self.max_loaded_models = max_loaded_models
        self.unload_idle_after = timedelta(seconds=unload_idle_after_seconds)
        self.prefer_quality = prefer_quality

        self.prompt_analyzer = PromptAnalyzer()
        self.model_states: Dict[str, ModelState] = {}
        self._lock = asyncio.Lock()

        # Sort profiles by quality (or speed if not preferring quality)
        self.profiles.sort(
            key=lambda p: p.quality_score if prefer_quality else -p.average_speed,
            reverse=True
        )

        logger.info(f"ModelOrchestrator initialized with {len(self.profiles)} profiles")

    def get_available_vram(self) -> float:
        """Get available GPU VRAM in GB."""
        if not torch.cuda.is_available():
            return 0.0

        try:
            device = torch.cuda.current_device()
            total = torch.cuda.get_device_properties(device).total_memory
            allocated = torch.cuda.memory_allocated(device)
            cached = torch.cuda.memory_reserved(device)

            # Available = Total - Allocated - Some buffer for operations
            available = (total - allocated - cached) / (1024**3)
            return max(0.0, available - 2.0)  # 2GB buffer
        except Exception as e:
            logger.warning(f"Failed to get VRAM: {e}")
            return 0.0

    def get_total_vram(self) -> float:
        """Get total GPU VRAM in GB."""
        if not torch.cuda.is_available():
            return 0.0

        try:
            device = torch.cuda.current_device()
            total = torch.cuda.get_device_properties(device).total_memory
            return total / (1024**3)
        except Exception:
            return 0.0

    def _get_compatible_models(
        self,
        required_vram: float,
        needs_i2v: bool = False,
        needs_controlnet: bool = False,
        needs_lora: bool = False,
        min_resolution: Optional[Tuple[int, int]] = None,
        min_frames: Optional[int] = None
    ) -> List[ModelProfile]:
        """Get list of models compatible with requirements."""
        available_vram = self.get_available_vram()
        compatible = []

        for profile in self.profiles:
            # VRAM check
            if profile.vram_required_gb > available_vram:
                continue

            # Feature checks
            if needs_i2v and not profile.supports_i2v:
                continue
            if needs_controlnet and not profile.supports_controlnet:
                continue
            if needs_lora and not profile.supports_lora:
                continue

            # Resolution check
            if min_resolution:
                if (profile.max_resolution[0] < min_resolution[0] or
                    profile.max_resolution[1] < min_resolution[1]):
                    continue

            # Frame count check
            if min_frames and profile.max_frames < min_frames:
                continue

            compatible.append(profile)

        return compatible

    async def select_model(
        self,
        prompt: str,
        width: int = 1280,
        height: int = 720,
        num_frames: int = 49,
        use_i2v: bool = False,
        use_controlnet: bool = False,
        use_lora: bool = False,
        force_tier: Optional[ModelTier] = None,
        prefer_speed: bool = False
    ) -> OrchestrationDecision:
        """
        Select the optimal model for a generation request.

        Args:
            prompt: The generation prompt
            width: Target width
            height: Target height
            num_frames: Number of frames to generate
            use_i2v: Whether image-to-video is needed
            use_controlnet: Whether ControlNet is needed
            use_lora: Whether LoRA is needed
            force_tier: Force a specific model tier
            prefer_speed: Prefer speed over quality

        Returns:
            OrchestrationDecision with selected model and configuration
        """
        async with self._lock:
            # Analyze prompt
            analysis = self.prompt_analyzer.analyze(prompt)
            warnings = []

            # Get compatible models
            compatible = self._get_compatible_models(
                required_vram=0,  # Will check later
                needs_i2v=use_i2v,
                needs_controlnet=use_controlnet,
                needs_lora=use_lora,
                min_resolution=(width, height),
                min_frames=num_frames
            )

            if not compatible:
                # No fully compatible model, try with reduced requirements
                warnings.append("No model fully meets requirements, using fallback")
                compatible = self._get_compatible_models(
                    required_vram=0,
                    needs_i2v=use_i2v
                )

            if not compatible:
                # Ultimate fallback
                compatible = [self.profiles[-1]]  # Preview model
                warnings.append("Using preview model as fallback")

            # Filter by tier if forced
            if force_tier:
                tier_models = [m for m in compatible if m.tier == force_tier]
                if tier_models:
                    compatible = tier_models
                else:
                    warnings.append(f"Requested tier {force_tier} not available")

            # Sort by preference (quality or speed)
            if prefer_speed:
                compatible.sort(key=lambda m: m.average_speed)
            else:
                compatible.sort(key=lambda m: m.quality_score, reverse=True)

            # Select primary and fallbacks
            selected = compatible[0]
            fallbacks = compatible[1:3] if len(compatible) > 1 else []

            # Generate config overrides based on analysis
            config_overrides = self._generate_config_overrides(
                analysis, selected, width, height, num_frames
            )

            # Build reason
            reason = self._build_selection_reason(analysis, selected)

            # Estimate time and quality
            estimated_time = selected.average_speed * num_frames
            estimated_quality = selected.quality_score

            # Adjust for complexity
            if analysis.complexity == ComplexityLevel.ULTRA_COMPLEX:
                estimated_time *= 1.3
            elif analysis.complexity == ComplexityLevel.COMPLEX:
                estimated_time *= 1.1

            decision = OrchestrationDecision(
                selected_model=selected,
                fallback_models=fallbacks,
                reason=reason,
                estimated_time=estimated_time,
                estimated_quality=estimated_quality,
                config_overrides=config_overrides,
                warnings=warnings
            )

            logger.info(f"Selected model: {selected.name} ({reason})")
            return decision

    def _generate_config_overrides(
        self,
        analysis: PromptAnalysis,
        model: ModelProfile,
        width: int,
        height: int,
        num_frames: int
    ) -> Dict[str, Any]:
        """Generate configuration overrides based on analysis."""
        overrides = {}

        # TeaCache settings
        if model.supports_tea_cache:
            if analysis.complexity == ComplexityLevel.SIMPLE:
                overrides["tea_cache_threshold"] = 0.15  # More aggressive
            elif analysis.complexity == ComplexityLevel.ULTRA_COMPLEX:
                overrides["tea_cache_threshold"] = 0.05  # More conservative
            else:
                overrides["tea_cache_threshold"] = 0.1

        # Tiled VAE for high resolutions
        if model.supports_tiled_vae and width * height > 1280 * 720:
            overrides["use_tiled_vae"] = True
            overrides["vae_tile_size"] = 512

        # Guidance scale based on detail level
        if analysis.detail_level > 0.6:
            overrides["guidance_scale"] = 9.0
        elif analysis.detail_level < 0.3:
            overrides["guidance_scale"] = 6.0

        # Inference steps
        if analysis.cinematic_level > 0.5:
            overrides["num_inference_steps"] = 50
        elif analysis.complexity == ComplexityLevel.SIMPLE:
            overrides["num_inference_steps"] = 30

        # Motion bucket for I2V
        if analysis.has_motion:
            if analysis.motion_complexity > 0.5:
                overrides["motion_bucket_id"] = 200
            else:
                overrides["motion_bucket_id"] = 127
        else:
            overrides["motion_bucket_id"] = 50

        return overrides

    def _build_selection_reason(
        self,
        analysis: PromptAnalysis,
        model: ModelProfile
    ) -> str:
        """Build a human-readable reason for model selection."""
        reasons = []

        reasons.append(f"Complexity: {analysis.complexity.value}")

        if analysis.cinematic_level > 0.3:
            reasons.append("cinematic style")

        if analysis.requires_consistency:
            reasons.append("requires character consistency")

        if analysis.has_motion:
            reasons.append(f"motion level: {analysis.motion_complexity:.0%}")

        reasons.append(f"quality score: {model.quality_score:.0%}")

        return ", ".join(reasons)

    async def preload_model(self, tier: ModelTier) -> bool:
        """Preload a model of the specified tier."""
        models = [m for m in self.profiles if m.tier == tier]
        if not models:
            logger.warning(f"No model found for tier {tier}")
            return False

        model = models[0]

        # Check VRAM
        if model.vram_required_gb > self.get_available_vram():
            logger.warning(f"Not enough VRAM to preload {model.name}")
            return False

        # Mark as loaded (actual loading happens in inference layer)
        self.model_states[model.name] = ModelState(
            profile=model,
            is_loaded=True,
            load_time=datetime.now(),
            last_used=datetime.now(),
            generation_count=0,
            average_latency=model.average_speed,
            error_count=0
        )

        logger.info(f"Preloaded model: {model.name}")
        return True

    async def cleanup_idle_models(self) -> List[str]:
        """Unload models that have been idle too long."""
        unloaded = []

        async with self._lock:
            for name, state in list(self.model_states.items()):
                if state.is_loaded and state.idle_time > self.unload_idle_after:
                    # Mark for unloading
                    state.is_loaded = False
                    unloaded.append(name)
                    logger.info(f"Unloaded idle model: {name}")

        return unloaded

    def record_generation(
        self,
        model_name: str,
        latency: float,
        success: bool
    ):
        """Record generation metrics for a model."""
        if model_name not in self.model_states:
            return

        state = self.model_states[model_name]
        state.last_used = datetime.now()
        state.generation_count += 1

        if success:
            # Update rolling average latency
            state.average_latency = (
                state.average_latency * 0.9 + latency * 0.1
            )
        else:
            state.error_count += 1

    def get_model_stats(self) -> Dict[str, Any]:
        """Get statistics for all tracked models."""
        stats = {}

        for name, state in self.model_states.items():
            stats[name] = {
                "tier": state.profile.tier.value,
                "is_loaded": state.is_loaded,
                "generation_count": state.generation_count,
                "average_latency": state.average_latency,
                "error_rate": state.error_count / max(1, state.generation_count),
                "idle_seconds": state.idle_time.total_seconds()
            }

        return stats

    def get_recommended_tier_for_vram(self, vram_gb: Optional[float] = None) -> ModelTier:
        """Get the recommended model tier for available VRAM."""
        vram = vram_gb or self.get_available_vram()

        if vram >= 24:
            return ModelTier.ULTRA
        elif vram >= 16:
            return ModelTier.HIGH
        elif vram >= 8:
            return ModelTier.STANDARD
        elif vram >= 6:
            return ModelTier.FAST
        else:
            return ModelTier.PREVIEW


# Singleton instance
_orchestrator: Optional[ModelOrchestrator] = None


def get_orchestrator() -> ModelOrchestrator:
    """Get the global orchestrator instance."""
    global _orchestrator
    if _orchestrator is None:
        _orchestrator = ModelOrchestrator()
    return _orchestrator


async def select_optimal_model(
    prompt: str,
    width: int = 1280,
    height: int = 720,
    num_frames: int = 49,
    **kwargs
) -> OrchestrationDecision:
    """Convenience function to select optimal model."""
    orchestrator = get_orchestrator()
    return await orchestrator.select_model(
        prompt, width, height, num_frames, **kwargs
    )
