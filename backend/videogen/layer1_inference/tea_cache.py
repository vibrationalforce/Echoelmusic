"""
TeaCache - Temporal Efficient Attention Cache
==============================================

Optimizes video generation by detecting and skipping redundant
frame computations based on temporal similarity.

Paper: "TeaCache: Temporal Efficient Attention Cache for Video Diffusion"

Key Concepts:
- Frames often have high temporal redundancy
- Skip attention computation for similar frames
- Cache and reuse attention outputs
- Significant speedup (2-3x) with minimal quality loss
"""

import torch
import numpy as np
from typing import Optional, Dict, List, Tuple, Any
from dataclasses import dataclass
import logging

logger = logging.getLogger(__name__)


@dataclass
class CacheEntry:
    """Cached computation state for a frame"""
    step: int
    frame_idx: int
    latent_hash: int
    attention_output: Optional[torch.Tensor] = None
    hidden_state: Optional[torch.Tensor] = None
    similarity_score: float = 0.0


@dataclass
class TeaCacheConfig:
    """Configuration for TeaCache optimization"""
    threshold: float = 0.1  # Similarity threshold (0-1, lower = more aggressive caching)
    adaptive_threshold: bool = True  # Adjust threshold based on denoising step
    max_cached_frames: int = 100  # Maximum frames to keep in cache
    skip_first_steps: int = 3  # Always compute first N steps
    skip_last_steps: int = 3  # Always compute last N steps
    layer_wise_caching: bool = True  # Enable per-layer caching
    use_cosine_similarity: bool = True  # Use full cosine similarity (more accurate)
    cosine_sample_size: int = 10000  # Number of elements to sample for cosine similarity
    use_gpu_similarity: bool = True  # Compute similarity on GPU
    similarity_batch_size: int = 4  # Batch size for similarity computation


class TeaCache:
    """
    Temporal Efficient Attention Cache

    Reduces redundant computations in video diffusion by:
    1. Computing similarity between adjacent frames
    2. Caching attention outputs for similar frames
    3. Reusing cached outputs when similarity is high
    4. Adapting threshold based on denoising step

    Usage:
        tea_cache = TeaCache(num_layers=40, hidden_size=5120)

        for step in range(num_steps):
            if tea_cache.should_compute_frame(step, latents):
                output = model(latents)
                tea_cache.cache_state(step, latents, output)
            else:
                output = tea_cache.get_cached_output(step)
    """

    def __init__(
        self,
        num_layers: int = 40,
        hidden_size: int = 5120,
        max_cached_frames: int = 100,
        adaptive_threshold: bool = True,
        config: Optional[TeaCacheConfig] = None
    ):
        """
        Initialize TeaCache.

        Args:
            num_layers: Number of transformer layers
            hidden_size: Hidden dimension size
            max_cached_frames: Maximum frames to keep in cache
            adaptive_threshold: Adjust threshold based on denoising step
            config: Optional TeaCacheConfig for advanced settings
        """
        self.config = config or TeaCacheConfig(
            max_cached_frames=max_cached_frames,
            adaptive_threshold=adaptive_threshold
        )
        self.num_layers = num_layers
        self.hidden_size = hidden_size
        self.max_cached_frames = self.config.max_cached_frames
        self.adaptive_threshold = self.config.adaptive_threshold

        # Cache storage
        self._cache: Dict[str, CacheEntry] = {}
        self._frame_order: List[str] = []

        # Latent cache for cosine similarity
        self._latent_cache: Dict[str, torch.Tensor] = {}

        # Statistics
        self._cache_hits = 0
        self._cache_misses = 0
        self._total_skipped_frames = 0
        self._similarity_scores: List[float] = []

        # Layer-wise caching
        self._layer_caches: Dict[int, Dict[str, torch.Tensor]] = {
            i: {} for i in range(num_layers)
        }

        logger.info(f"TeaCache initialized: {num_layers} layers, {hidden_size} hidden, cosine_sim={self.config.use_cosine_similarity}")

    def should_compute_frame(
        self,
        step: int,
        latents: torch.Tensor,
        threshold: float = 0.1,
        frame_idx: Optional[int] = None
    ) -> bool:
        """
        Determine if frame computation should be performed.

        Args:
            step: Current denoising step
            latents: Current latent tensor
            threshold: Similarity threshold (0-1, lower = more caching)
            frame_idx: Optional frame index for multi-frame batches

        Returns:
            True if computation needed, False if cached result can be used
        """
        # Always compute first few steps (high noise, high variance)
        if step < 3:
            return True

        # Always compute final steps (refinement phase)
        total_steps = 50  # Assumed, adjust based on scheduler
        if step > total_steps - 3:
            return True

        # Adaptive threshold: be more aggressive in middle steps
        if self.adaptive_threshold:
            step_ratio = step / total_steps
            # Bell curve: cache more in middle, less at start/end
            adaptive_factor = 4 * step_ratio * (1 - step_ratio)
            threshold = threshold * (1 + adaptive_factor)

        # Compute latent hash for cache lookup
        cache_key = self._compute_cache_key(step, latents, frame_idx)

        # Check if we have a similar cached entry
        if cache_key in self._cache:
            entry = self._cache[cache_key]

            # Compute similarity with cached state
            similarity = self._compute_similarity(latents, entry)

            if similarity > (1 - threshold):
                self._cache_hits += 1
                self._total_skipped_frames += 1
                logger.debug(f"Cache HIT: step={step}, similarity={similarity:.3f}")
                return False

        self._cache_misses += 1
        return True

    def cache_state(
        self,
        step: int,
        latents: torch.Tensor,
        attention_output: Optional[torch.Tensor] = None,
        hidden_state: Optional[torch.Tensor] = None,
        frame_idx: Optional[int] = None
    ) -> None:
        """
        Cache the computation state for a frame.

        Args:
            step: Current denoising step
            latents: Latent tensor
            attention_output: Optional attention output to cache
            hidden_state: Optional hidden state to cache
            frame_idx: Optional frame index
        """
        cache_key = self._compute_cache_key(step, latents, frame_idx)

        # Evict old entries if cache is full
        if len(self._cache) >= self.max_cached_frames:
            self._evict_oldest()

        # Store entry
        entry = CacheEntry(
            step=step,
            frame_idx=frame_idx or 0,
            latent_hash=self._hash_tensor(latents),
            attention_output=attention_output.clone() if attention_output is not None else None,
            hidden_state=hidden_state.clone() if hidden_state is not None else None
        )

        self._cache[cache_key] = entry
        self._frame_order.append(cache_key)

        # Store latent for cosine similarity (sampled to reduce memory)
        if self.config.use_cosine_similarity:
            self._latent_cache[cache_key] = self._sample_latent(latents)

        logger.debug(f"Cached state: step={step}, key={cache_key[:16]}...")

    def get_cached_output(
        self,
        step: int,
        frame_idx: Optional[int] = None,
        latents: Optional[torch.Tensor] = None
    ) -> Optional[torch.Tensor]:
        """
        Retrieve cached attention output.

        Args:
            step: Denoising step
            frame_idx: Frame index
            latents: Optional latents for cache key computation

        Returns:
            Cached attention output or None
        """
        if latents is not None:
            cache_key = self._compute_cache_key(step, latents, frame_idx)
        else:
            # Try to find by step and frame_idx
            for key, entry in self._cache.items():
                if entry.step == step and entry.frame_idx == (frame_idx or 0):
                    return entry.attention_output
            return None

        entry = self._cache.get(cache_key)
        return entry.attention_output if entry else None

    def cache_layer_output(
        self,
        layer_idx: int,
        key: str,
        output: torch.Tensor
    ) -> None:
        """Cache output for a specific layer"""
        if layer_idx < self.num_layers:
            self._layer_caches[layer_idx][key] = output.clone()

    def get_layer_output(
        self,
        layer_idx: int,
        key: str
    ) -> Optional[torch.Tensor]:
        """Get cached layer output"""
        if layer_idx < self.num_layers:
            return self._layer_caches[layer_idx].get(key)
        return None

    def _compute_cache_key(
        self,
        step: int,
        latents: torch.Tensor,
        frame_idx: Optional[int]
    ) -> str:
        """Compute cache key from step and latent hash"""
        latent_hash = self._hash_tensor(latents)
        frame_str = f"_f{frame_idx}" if frame_idx is not None else ""
        return f"s{step}{frame_str}_{latent_hash:016x}"

    def _hash_tensor(self, tensor: torch.Tensor) -> int:
        """Compute hash of tensor for cache key"""
        # Use subset of values for fast hashing
        flat = tensor.flatten()
        indices = torch.linspace(0, len(flat) - 1, min(1000, len(flat))).long()
        subset = flat[indices].cpu().numpy()
        return hash(subset.tobytes())

    def _sample_latent(self, latents: torch.Tensor) -> torch.Tensor:
        """
        Sample a subset of latent values for efficient similarity computation.

        Args:
            latents: Full latent tensor

        Returns:
            Sampled and normalized latent vector
        """
        flat = latents.flatten()
        sample_size = min(self.config.cosine_sample_size, len(flat))

        # Use deterministic sampling for reproducibility
        indices = torch.linspace(0, len(flat) - 1, sample_size).long()

        if self.config.use_gpu_similarity and latents.is_cuda:
            sampled = flat[indices]
        else:
            sampled = flat[indices].cpu()

        # L2 normalize for cosine similarity
        norm = torch.norm(sampled, p=2)
        if norm > 0:
            sampled = sampled / norm

        return sampled

    def _compute_similarity(
        self,
        latents: torch.Tensor,
        cached_entry: CacheEntry
    ) -> float:
        """
        Compute similarity between current and cached latents.

        Uses cosine similarity for accurate temporal redundancy detection.

        Args:
            latents: Current latent tensor
            cached_entry: Cached frame entry

        Returns:
            Similarity score between 0.0 and 1.0
        """
        # Fast path: hash-based similarity
        current_hash = self._hash_tensor(latents)
        if current_hash == cached_entry.latent_hash:
            return 1.0

        # Full cosine similarity if enabled
        if self.config.use_cosine_similarity:
            cache_key = f"s{cached_entry.step}_f{cached_entry.frame_idx}_{cached_entry.latent_hash:016x}"

            if cache_key in self._latent_cache:
                cached_latent = self._latent_cache[cache_key]
                current_sampled = self._sample_latent(latents)

                # Ensure same device
                if cached_latent.device != current_sampled.device:
                    cached_latent = cached_latent.to(current_sampled.device)

                # Cosine similarity (vectors are already normalized)
                similarity = torch.dot(current_sampled, cached_latent).item()

                # Store for statistics
                self._similarity_scores.append(similarity)

                # Clamp to valid range
                return max(0.0, min(1.0, similarity))

        return 0.0

    def compute_cosine_similarity_batch(
        self,
        latents_batch: torch.Tensor,
        reference_latent: torch.Tensor
    ) -> torch.Tensor:
        """
        Compute cosine similarity for a batch of latents against a reference.

        Optimized for GPU computation with batched operations.

        Args:
            latents_batch: Batch of latent tensors [B, ...]
            reference_latent: Reference latent tensor

        Returns:
            Tensor of similarity scores [B]
        """
        batch_size = latents_batch.shape[0]

        # Flatten and sample each batch element
        batch_sampled = []
        for i in range(batch_size):
            sampled = self._sample_latent(latents_batch[i])
            batch_sampled.append(sampled)

        # Stack into batch tensor
        batch_tensor = torch.stack(batch_sampled, dim=0)

        # Sample reference
        ref_sampled = self._sample_latent(reference_latent)

        # Ensure same device
        if batch_tensor.device != ref_sampled.device:
            ref_sampled = ref_sampled.to(batch_tensor.device)

        # Batch cosine similarity
        similarities = torch.nn.functional.cosine_similarity(
            batch_tensor,
            ref_sampled.unsqueeze(0),
            dim=1
        )

        return similarities

    def find_most_similar_cached(
        self,
        latents: torch.Tensor,
        step: int,
        top_k: int = 1
    ) -> List[Tuple[str, float]]:
        """
        Find the most similar cached entries to current latents.

        Args:
            latents: Current latent tensor
            step: Current denoising step
            top_k: Number of top matches to return

        Returns:
            List of (cache_key, similarity_score) tuples
        """
        if not self._latent_cache:
            return []

        current_sampled = self._sample_latent(latents)

        similarities = []
        for cache_key, cached_latent in self._latent_cache.items():
            # Ensure same device
            if cached_latent.device != current_sampled.device:
                cached_latent = cached_latent.to(current_sampled.device)

            sim = torch.dot(current_sampled, cached_latent).item()
            similarities.append((cache_key, sim))

        # Sort by similarity (descending)
        similarities.sort(key=lambda x: x[1], reverse=True)

        return similarities[:top_k]

    def _evict_oldest(self) -> None:
        """Evict oldest cache entries"""
        while len(self._cache) >= self.max_cached_frames and self._frame_order:
            oldest_key = self._frame_order.pop(0)
            if oldest_key in self._cache:
                del self._cache[oldest_key]
            if oldest_key in self._latent_cache:
                del self._latent_cache[oldest_key]

    def clear(self) -> None:
        """Clear all cached data"""
        self._cache.clear()
        self._frame_order.clear()
        self._latent_cache.clear()
        self._similarity_scores.clear()
        for layer_cache in self._layer_caches.values():
            layer_cache.clear()

        logger.info("TeaCache cleared")

    def get_statistics(self) -> Dict[str, Any]:
        """Get cache statistics including similarity metrics"""
        total = self._cache_hits + self._cache_misses
        hit_rate = self._cache_hits / total if total > 0 else 0

        # Compute similarity statistics
        similarity_stats = {}
        if self._similarity_scores:
            scores = np.array(self._similarity_scores)
            similarity_stats = {
                "mean_similarity": float(np.mean(scores)),
                "min_similarity": float(np.min(scores)),
                "max_similarity": float(np.max(scores)),
                "std_similarity": float(np.std(scores)),
                "num_comparisons": len(scores),
            }

        return {
            "cache_hits": self._cache_hits,
            "cache_misses": self._cache_misses,
            "hit_rate": hit_rate,
            "total_skipped_frames": self._total_skipped_frames,
            "current_cache_size": len(self._cache),
            "latent_cache_size": len(self._latent_cache),
            "max_cache_size": self.max_cached_frames,
            "cosine_similarity_enabled": self.config.use_cosine_similarity,
            "similarity_stats": similarity_stats,
        }

    def estimate_speedup(self) -> float:
        """Estimate speedup from caching"""
        total = self._cache_hits + self._cache_misses
        if total == 0:
            return 1.0

        # Assume cached frames take 5% of compute time
        cached_cost = 0.05
        hit_rate = self._cache_hits / total

        # Speedup = 1 / (1 - hit_rate * (1 - cached_cost))
        return 1 / (1 - hit_rate * (1 - cached_cost))


class TemporalRedundancyAnalyzer:
    """
    Analyze temporal redundancy in video latents.

    Used for:
    - Determining optimal caching thresholds
    - Identifying keyframes vs redundant frames
    - Adaptive cache sizing
    """

    def __init__(self, window_size: int = 5):
        self.window_size = window_size
        self._similarity_history: List[float] = []

    def analyze_frame_sequence(
        self,
        latents: torch.Tensor
    ) -> Dict[str, any]:
        """
        Analyze temporal redundancy in a sequence of frame latents.

        Args:
            latents: Tensor of shape (batch, frames, channels, height, width)

        Returns:
            Analysis results including redundancy scores
        """
        batch, num_frames, channels, height, width = latents.shape

        similarities = []
        keyframe_indices = [0]  # First frame is always a keyframe

        for i in range(1, num_frames):
            # Compute similarity between adjacent frames
            prev_frame = latents[:, i-1].flatten()
            curr_frame = latents[:, i].flatten()

            # Cosine similarity
            similarity = torch.nn.functional.cosine_similarity(
                prev_frame.unsqueeze(0),
                curr_frame.unsqueeze(0)
            ).item()

            similarities.append(similarity)

            # Detect keyframes (low similarity = scene change)
            if similarity < 0.9:
                keyframe_indices.append(i)

        avg_similarity = np.mean(similarities) if similarities else 1.0
        redundancy_ratio = sum(1 for s in similarities if s > 0.95) / len(similarities) if similarities else 0

        return {
            "average_similarity": avg_similarity,
            "redundancy_ratio": redundancy_ratio,
            "keyframe_indices": keyframe_indices,
            "num_keyframes": len(keyframe_indices),
            "recommended_threshold": self._compute_recommended_threshold(similarities)
        }

    def _compute_recommended_threshold(
        self,
        similarities: List[float]
    ) -> float:
        """Compute recommended caching threshold based on similarity distribution"""
        if not similarities:
            return 0.1

        # Use percentile-based threshold
        sorted_sims = sorted(similarities)
        p25 = sorted_sims[len(sorted_sims) // 4]

        # Threshold should be 1 - p25 (cache frames above 25th percentile similarity)
        return max(0.05, min(0.2, 1 - p25))
