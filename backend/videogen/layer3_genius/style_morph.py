"""
Style Morphing System
=====================

Inspired by Minimal Audio's morphing filter system.
Enables smooth transitions between visual styles during generation.

Features:
- Interpolate between any two visual styles
- Multi-style blending with weighted contributions
- Temporal morphing (style changes over video duration)
- Preset style combinations
"""

import numpy as np
import torch
from typing import Optional, Dict, Any, List, Tuple, Union
from dataclasses import dataclass, field
from enum import Enum
import logging

logger = logging.getLogger(__name__)


class VisualStyle(str, Enum):
    """Available visual styles for morphing"""
    CINEMATIC = "cinematic"
    ANIME = "anime"
    REALISTIC = "realistic"
    ARTISTIC = "artistic"
    DOCUMENTARY = "documentary"
    MUSIC_VIDEO = "music_video"
    ABSTRACT = "abstract"
    NATURE = "nature"
    SCIFI = "scifi"
    FANTASY = "fantasy"
    NOIR = "noir"
    VINTAGE = "vintage"
    NEON = "neon"
    WATERCOLOR = "watercolor"
    OIL_PAINTING = "oil_painting"
    SKETCH = "sketch"


# Style embedding vectors (placeholder - in production, use CLIP or learned embeddings)
STYLE_EMBEDDINGS: Dict[str, np.ndarray] = {}


@dataclass
class MorphConfig:
    """Configuration for style morphing"""
    source_style: VisualStyle
    target_style: VisualStyle
    morph_amount: float = 0.5  # 0.0 = source, 1.0 = target
    morph_curve: str = "linear"  # linear, ease_in, ease_out, ease_in_out
    temporal_morph: bool = False  # Change over time
    temporal_start: float = 0.0  # Start morph amount
    temporal_end: float = 1.0  # End morph amount


@dataclass
class MultiStyleBlend:
    """Multi-style blending configuration"""
    styles: List[VisualStyle]
    weights: List[float]  # Must sum to 1.0

    def __post_init__(self):
        if len(self.styles) != len(self.weights):
            raise ValueError("Styles and weights must have same length")
        total = sum(self.weights)
        if abs(total - 1.0) > 0.01:
            # Normalize weights
            self.weights = [w / total for w in self.weights]


class StyleMorpher:
    """
    Morphs between visual styles for video generation.

    Inspired by Minimal Audio's 50+ filter morphing system.

    Usage:
        morpher = StyleMorpher()

        # Simple morph
        prompt = morpher.morph_prompt(
            "a forest scene",
            source=VisualStyle.REALISTIC,
            target=VisualStyle.ANIME,
            amount=0.7
        )

        # Temporal morph (changes over video duration)
        prompts = morpher.temporal_morph(
            "a city skyline",
            config=MorphConfig(
                source_style=VisualStyle.REALISTIC,
                target_style=VisualStyle.NEON,
                temporal_morph=True,
                temporal_start=0.0,
                temporal_end=1.0
            ),
            num_frames=49
        )
    """

    # Style prompt modifiers
    STYLE_MODIFIERS = {
        VisualStyle.CINEMATIC: "cinematic lighting, film grain, dramatic shadows, 35mm film, anamorphic lens",
        VisualStyle.ANIME: "anime style, cel shading, vibrant colors, dynamic lines, japanese animation",
        VisualStyle.REALISTIC: "photorealistic, natural lighting, high detail, 8k photography",
        VisualStyle.ARTISTIC: "artistic interpretation, painterly, expressive brushstrokes, creative",
        VisualStyle.DOCUMENTARY: "documentary style, natural footage, observational, authentic",
        VisualStyle.MUSIC_VIDEO: "music video aesthetic, stylized, rhythmic editing, bold colors",
        VisualStyle.ABSTRACT: "abstract visuals, geometric patterns, non-representational, experimental",
        VisualStyle.NATURE: "nature documentary, BBC Earth style, stunning landscapes, wildlife",
        VisualStyle.SCIFI: "science fiction, futuristic, cyberpunk elements, neon lights, technology",
        VisualStyle.FANTASY: "fantasy world, magical atmosphere, ethereal lighting, mystical",
        VisualStyle.NOIR: "film noir, high contrast, black and white, shadows, detective aesthetic",
        VisualStyle.VINTAGE: "vintage film, retro colors, 1970s aesthetic, nostalgic, warm tones",
        VisualStyle.NEON: "neon lights, cyberpunk city, glowing colors, night scene, synthwave",
        VisualStyle.WATERCOLOR: "watercolor painting, soft edges, flowing colors, artistic, delicate",
        VisualStyle.OIL_PAINTING: "oil painting, rich textures, classical art, museum quality",
        VisualStyle.SKETCH: "pencil sketch, hand-drawn, line art, illustration, artistic",
    }

    def __init__(self):
        self._embedding_cache: Dict[str, torch.Tensor] = {}

    def morph_prompt(
        self,
        base_prompt: str,
        source: VisualStyle,
        target: VisualStyle,
        amount: float = 0.5
    ) -> str:
        """
        Create a morphed prompt between two styles.

        Args:
            base_prompt: Original content prompt
            source: Starting style
            target: Target style
            amount: Morph amount (0.0 = source, 1.0 = target)

        Returns:
            Modified prompt with blended style
        """
        amount = max(0.0, min(1.0, amount))

        source_mod = self.STYLE_MODIFIERS.get(source, "")
        target_mod = self.STYLE_MODIFIERS.get(target, "")

        if amount < 0.2:
            # Mostly source
            style_text = source_mod
        elif amount > 0.8:
            # Mostly target
            style_text = target_mod
        else:
            # Blend both
            source_weight = 1.0 - amount
            target_weight = amount

            # Select keywords based on weights
            source_keywords = source_mod.split(", ")
            target_keywords = target_mod.split(", ")

            # Take proportional keywords from each
            num_source = max(1, int(len(source_keywords) * source_weight))
            num_target = max(1, int(len(target_keywords) * target_weight))

            selected = source_keywords[:num_source] + target_keywords[:num_target]
            style_text = ", ".join(selected)

        return f"{base_prompt}, {style_text}"

    def temporal_morph(
        self,
        base_prompt: str,
        config: MorphConfig,
        num_frames: int
    ) -> List[str]:
        """
        Create prompts that morph over time (per-frame).

        Args:
            base_prompt: Base content prompt
            config: Morph configuration
            num_frames: Number of video frames

        Returns:
            List of prompts, one per frame
        """
        if not config.temporal_morph:
            # Static morph
            morphed = self.morph_prompt(
                base_prompt,
                config.source_style,
                config.target_style,
                config.morph_amount
            )
            return [morphed] * num_frames

        prompts = []
        for i in range(num_frames):
            t = i / max(1, num_frames - 1)  # 0.0 to 1.0

            # Apply easing curve
            t = self._apply_curve(t, config.morph_curve)

            # Interpolate morph amount
            amount = config.temporal_start + t * (config.temporal_end - config.temporal_start)

            prompt = self.morph_prompt(
                base_prompt,
                config.source_style,
                config.target_style,
                amount
            )
            prompts.append(prompt)

        return prompts

    def multi_style_blend(
        self,
        base_prompt: str,
        blend: MultiStyleBlend
    ) -> str:
        """
        Blend multiple styles with weighted contributions.

        Args:
            base_prompt: Base content prompt
            blend: Multi-style configuration

        Returns:
            Blended prompt
        """
        all_keywords = []

        for style, weight in zip(blend.styles, blend.weights):
            modifier = self.STYLE_MODIFIERS.get(style, "")
            keywords = modifier.split(", ")

            # Select keywords proportional to weight
            num_keywords = max(1, int(len(keywords) * weight * 2))
            all_keywords.extend(keywords[:num_keywords])

        # Remove duplicates while preserving order
        seen = set()
        unique_keywords = []
        for kw in all_keywords:
            if kw not in seen:
                seen.add(kw)
                unique_keywords.append(kw)

        style_text = ", ".join(unique_keywords[:8])  # Limit to 8 keywords
        return f"{base_prompt}, {style_text}"

    def _apply_curve(self, t: float, curve: str) -> float:
        """Apply easing curve to interpolation"""
        if curve == "linear":
            return t
        elif curve == "ease_in":
            return t * t
        elif curve == "ease_out":
            return 1 - (1 - t) * (1 - t)
        elif curve == "ease_in_out":
            return 3 * t * t - 2 * t * t * t
        return t

    def get_style_embedding(
        self,
        style: VisualStyle,
        device: str = "cuda"
    ) -> torch.Tensor:
        """
        Get CLIP embedding vector for a visual style.

        Production-ready implementation:
        - Uses OpenAI CLIP model when available
        - Falls back to sentence-transformers
        - Ultimate fallback to deterministic embeddings

        Args:
            style: Visual style
            device: Target device

        Returns:
            Style embedding tensor [1, 768]
        """
        cache_key = f"{style.value}_{device}"

        if cache_key in self._embedding_cache:
            return self._embedding_cache[cache_key]

        # Get style description text
        style_text = self.STYLE_MODIFIERS.get(style, style.value)

        # Try CLIP model
        embedding = self._compute_clip_embedding(style_text, device)

        self._embedding_cache[cache_key] = embedding
        return embedding

    def _compute_clip_embedding(
        self,
        text: str,
        device: str = "cuda"
    ) -> torch.Tensor:
        """
        Compute CLIP text embedding for style description.

        Uses multiple fallback strategies for robustness.
        """
        # Strategy 1: OpenAI CLIP
        try:
            import clip
            model, _ = clip.load("ViT-L/14", device=device)
            tokens = clip.tokenize([text]).to(device)
            with torch.no_grad():
                embedding = model.encode_text(tokens)
                embedding = embedding / embedding.norm(dim=-1, keepdim=True)
            logger.debug(f"CLIP embedding computed for: {text[:50]}...")
            return embedding.float()
        except Exception as e:
            logger.debug(f"OpenAI CLIP not available: {e}")

        # Strategy 2: Sentence Transformers
        try:
            from sentence_transformers import SentenceTransformer
            model = SentenceTransformer('clip-ViT-L-14')
            embedding = model.encode([text], convert_to_tensor=True)
            embedding = embedding.to(device)
            embedding = embedding / embedding.norm(dim=-1, keepdim=True)
            logger.debug(f"SentenceTransformer embedding computed")
            return embedding.float()
        except Exception as e:
            logger.debug(f"SentenceTransformers not available: {e}")

        # Strategy 3: Transformers CLIP
        try:
            from transformers import CLIPTextModel, CLIPTokenizer
            tokenizer = CLIPTokenizer.from_pretrained("openai/clip-vit-large-patch14")
            model = CLIPTextModel.from_pretrained("openai/clip-vit-large-patch14").to(device)
            inputs = tokenizer([text], return_tensors="pt", padding=True, truncation=True)
            inputs = {k: v.to(device) for k, v in inputs.items()}
            with torch.no_grad():
                outputs = model(**inputs)
                embedding = outputs.last_hidden_state.mean(dim=1)
                embedding = embedding / embedding.norm(dim=-1, keepdim=True)
            logger.debug(f"Transformers CLIP embedding computed")
            return embedding.float()
        except Exception as e:
            logger.debug(f"Transformers CLIP not available: {e}")

        # Strategy 4: Deterministic hash-based embedding (always works)
        logger.info("Using deterministic embedding fallback")
        return self._deterministic_embedding(text, device)

    def _deterministic_embedding(self, text: str, device: str) -> torch.Tensor:
        """
        Create deterministic embedding from text hash.

        Ensures consistent embeddings without ML models.
        Different texts produce different, stable embeddings.
        """
        import hashlib

        # Create deterministic seed from text
        text_hash = hashlib.sha256(text.encode()).hexdigest()
        seed = int(text_hash[:8], 16)

        # Generate reproducible random embedding
        torch.manual_seed(seed)
        embedding = torch.randn(1, 768, device=device)

        # Normalize
        embedding = embedding / embedding.norm(dim=-1, keepdim=True)

        return embedding.float()

    def morph_embeddings(
        self,
        source_embedding: torch.Tensor,
        target_embedding: torch.Tensor,
        amount: float
    ) -> torch.Tensor:
        """
        Interpolate between two embeddings in latent space.

        Uses spherical linear interpolation (slerp) for better results.

        Args:
            source_embedding: Source style embedding
            target_embedding: Target style embedding
            amount: Interpolation amount (0.0 to 1.0)

        Returns:
            Interpolated embedding
        """
        # Normalize
        source_norm = source_embedding / source_embedding.norm()
        target_norm = target_embedding / target_embedding.norm()

        # Compute angle
        dot = (source_norm * target_norm).sum()
        dot = torch.clamp(dot, -1.0, 1.0)

        theta = torch.acos(dot)

        if theta.abs() < 1e-6:
            # Very similar, use linear
            return source_embedding * (1 - amount) + target_embedding * amount

        # Slerp
        sin_theta = torch.sin(theta)
        s0 = torch.sin((1 - amount) * theta) / sin_theta
        s1 = torch.sin(amount * theta) / sin_theta

        return source_embedding * s0 + target_embedding * s1


# Preset morph combinations
MORPH_PRESETS = {
    "day_to_night": MorphConfig(
        source_style=VisualStyle.NATURE,
        target_style=VisualStyle.NEON,
        temporal_morph=True,
        temporal_start=0.0,
        temporal_end=1.0,
        morph_curve="ease_in_out"
    ),
    "real_to_anime": MorphConfig(
        source_style=VisualStyle.REALISTIC,
        target_style=VisualStyle.ANIME,
        morph_amount=0.7
    ),
    "modern_to_vintage": MorphConfig(
        source_style=VisualStyle.CINEMATIC,
        target_style=VisualStyle.VINTAGE,
        temporal_morph=True,
        morph_curve="ease_out"
    ),
    "reality_to_fantasy": MorphConfig(
        source_style=VisualStyle.DOCUMENTARY,
        target_style=VisualStyle.FANTASY,
        morph_amount=0.6
    ),
}


# Global morpher instance
style_morpher = StyleMorpher()


__all__ = [
    "VisualStyle",
    "MorphConfig",
    "MultiStyleBlend",
    "StyleMorpher",
    "style_morpher",
    "MORPH_PRESETS",
]
