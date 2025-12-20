"""
Character Consistency Tracker - Super Genius AI Feature #8

Tracks and maintains character consistency across video frames
and multi-shot scenes.

Features:
- Face/body embedding extraction
- Cross-frame identity matching
- Appearance preservation
- Style consistency
- Multi-character tracking
"""

import asyncio
import hashlib
import numpy as np
from dataclasses import dataclass, field
from enum import Enum
from typing import Dict, List, Optional, Tuple, Any, Set
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


class TrackingState(str, Enum):
    """State of a tracked entity."""
    ACTIVE = "active"
    OCCLUDED = "occluded"
    LOST = "lost"
    REIDENTIFIED = "reidentified"


class EntityType(str, Enum):
    """Types of trackable entities."""
    CHARACTER = "character"
    FACE = "face"
    BODY = "body"
    OBJECT = "object"
    STYLE = "style"


@dataclass
class BoundingBox:
    """A bounding box for an entity."""
    x: float  # Top-left x (normalized 0-1)
    y: float  # Top-left y (normalized 0-1)
    width: float
    height: float

    @property
    def center(self) -> Tuple[float, float]:
        return (self.x + self.width / 2, self.y + self.height / 2)

    @property
    def area(self) -> float:
        return self.width * self.height

    def iou(self, other: 'BoundingBox') -> float:
        """Compute Intersection over Union."""
        x1 = max(self.x, other.x)
        y1 = max(self.y, other.y)
        x2 = min(self.x + self.width, other.x + other.width)
        y2 = min(self.y + self.height, other.y + other.height)

        if x2 <= x1 or y2 <= y1:
            return 0.0

        intersection = (x2 - x1) * (y2 - y1)
        union = self.area + other.area - intersection

        return intersection / union if union > 0 else 0.0


@dataclass
class EntityAppearance:
    """Appearance descriptor for an entity."""
    embedding: np.ndarray  # Visual embedding
    color_histogram: Optional[np.ndarray] = None
    texture_features: Optional[np.ndarray] = None
    pose_keypoints: Optional[np.ndarray] = None

    def similarity(self, other: 'EntityAppearance') -> float:
        """Compute similarity with another appearance."""
        # Cosine similarity of embeddings
        dot = np.dot(self.embedding, other.embedding)
        norm1 = np.linalg.norm(self.embedding)
        norm2 = np.linalg.norm(other.embedding)

        if norm1 == 0 or norm2 == 0:
            return 0.0

        return float(dot / (norm1 * norm2))


@dataclass
class TrackedEntity:
    """A tracked entity across frames."""
    entity_id: str
    entity_type: EntityType
    name: Optional[str] = None
    description: Optional[str] = None

    # Tracking state
    state: TrackingState = TrackingState.ACTIVE
    first_frame: int = 0
    last_frame: int = 0
    frames_visible: int = 0
    frames_occluded: int = 0

    # Appearance
    reference_appearance: Optional[EntityAppearance] = None
    appearance_history: List[EntityAppearance] = field(default_factory=list)

    # Position history
    bbox_history: Dict[int, BoundingBox] = field(default_factory=dict)

    # Confidence
    confidence: float = 1.0

    def update_appearance(self, appearance: EntityAppearance, frame: int):
        """Update entity appearance."""
        self.appearance_history.append(appearance)

        # Keep recent history
        if len(self.appearance_history) > 30:
            self.appearance_history.pop(0)

        # Update reference with exponential moving average
        if self.reference_appearance is None:
            self.reference_appearance = appearance
        else:
            alpha = 0.1
            self.reference_appearance.embedding = (
                (1 - alpha) * self.reference_appearance.embedding +
                alpha * appearance.embedding
            )

        self.last_frame = frame
        self.frames_visible += 1

    def get_average_appearance(self) -> Optional[EntityAppearance]:
        """Get averaged appearance from history."""
        if not self.appearance_history:
            return self.reference_appearance

        embeddings = np.stack([a.embedding for a in self.appearance_history])
        avg_embedding = np.mean(embeddings, axis=0)

        # Normalize
        norm = np.linalg.norm(avg_embedding)
        if norm > 0:
            avg_embedding = avg_embedding / norm

        return EntityAppearance(embedding=avg_embedding)


@dataclass
class ConsistencyScore:
    """Score for entity consistency across frames."""
    entity_id: str
    overall_score: float
    appearance_score: float
    temporal_score: float
    spatial_score: float
    issues: List[str] = field(default_factory=list)


@dataclass
class ConsistencyConfig:
    """Configuration for consistency tracking."""
    embedding_dim: int = 512
    similarity_threshold: float = 0.7
    max_frames_occluded: int = 30
    max_tracking_distance: float = 0.3
    use_appearance_model: bool = True
    multi_scale_matching: bool = True


class AppearanceExtractor:
    """Extracts appearance features from images."""

    def __init__(self, embedding_dim: int = 512):
        self.embedding_dim = embedding_dim
        self._model = None

    def extract(
        self,
        image: np.ndarray,
        bbox: Optional[BoundingBox] = None
    ) -> EntityAppearance:
        """
        Extract appearance from image.

        Args:
            image: Input image [H, W, C]
            bbox: Optional bounding box to crop

        Returns:
            EntityAppearance descriptor
        """
        if bbox is not None:
            h, w = image.shape[:2]
            x1 = int(bbox.x * w)
            y1 = int(bbox.y * h)
            x2 = int((bbox.x + bbox.width) * w)
            y2 = int((bbox.y + bbox.height) * h)
            image = image[y1:y2, x1:x2]

        # Extract embedding
        embedding = self._compute_embedding(image)

        # Extract color histogram
        color_hist = self._compute_color_histogram(image)

        return EntityAppearance(
            embedding=embedding,
            color_histogram=color_hist
        )

    def _compute_embedding(self, image: np.ndarray) -> np.ndarray:
        """Compute visual embedding."""
        # Placeholder - in production, use CLIP or similar
        # Use deterministic hash-based embedding for consistency

        # Downsample for efficiency
        if image.size > 0:
            h, w = image.shape[:2]
            small = image[::max(1, h // 8), ::max(1, w // 8)]
        else:
            small = image

        # Create deterministic embedding from image data
        img_bytes = small.tobytes()
        hash_bytes = hashlib.sha256(img_bytes).digest()

        embedding = np.zeros(self.embedding_dim, dtype=np.float32)
        for i in range(self.embedding_dim):
            idx = i % len(hash_bytes)
            embedding[i] = (hash_bytes[idx] / 255.0) * 2 - 1

        # Add image statistics
        if image.size > 0:
            mean = np.mean(image, axis=(0, 1))
            std = np.std(image, axis=(0, 1))
            for i in range(min(3, len(mean))):
                embedding[i] = mean[i] / 128 - 1
                embedding[i + 3] = std[i] / 64 - 1

        # Normalize
        norm = np.linalg.norm(embedding)
        if norm > 0:
            embedding = embedding / norm

        return embedding

    def _compute_color_histogram(
        self,
        image: np.ndarray,
        bins: int = 16
    ) -> np.ndarray:
        """Compute color histogram."""
        if image.size == 0:
            return np.zeros(bins * 3)

        hist = []
        for c in range(min(3, image.shape[-1] if len(image.shape) > 2 else 1)):
            channel = image[..., c] if len(image.shape) > 2 else image
            h, _ = np.histogram(channel, bins=bins, range=(0, 255))
            hist.extend(h / (h.sum() + 1e-6))

        return np.array(hist, dtype=np.float32)


class EntityMatcher:
    """Matches entities across frames."""

    def __init__(self, config: ConsistencyConfig):
        self.config = config

    def match(
        self,
        current_entities: List[Tuple[BoundingBox, EntityAppearance]],
        tracked_entities: List[TrackedEntity]
    ) -> Dict[int, str]:
        """
        Match detected entities to tracked entities.

        Args:
            current_entities: List of (bbox, appearance) tuples
            tracked_entities: List of tracked entities

        Returns:
            Dict mapping detection index to entity_id
        """
        if not current_entities or not tracked_entities:
            return {}

        # Compute similarity matrix
        n_current = len(current_entities)
        n_tracked = len(tracked_entities)
        similarity = np.zeros((n_current, n_tracked))

        for i, (bbox, appearance) in enumerate(current_entities):
            for j, entity in enumerate(tracked_entities):
                if entity.reference_appearance is None:
                    continue

                # Appearance similarity
                app_sim = appearance.similarity(entity.reference_appearance)

                # Spatial similarity (if bbox available)
                spatial_sim = 0.0
                if entity.bbox_history:
                    last_frame = max(entity.bbox_history.keys())
                    last_bbox = entity.bbox_history[last_frame]
                    iou = bbox.iou(last_bbox)
                    spatial_sim = iou

                # Combined similarity
                similarity[i, j] = 0.7 * app_sim + 0.3 * spatial_sim

        # Greedy matching (could use Hungarian algorithm for optimal)
        matches = {}
        used_tracks = set()

        for _ in range(min(n_current, n_tracked)):
            if similarity.max() < self.config.similarity_threshold:
                break

            i, j = np.unravel_index(similarity.argmax(), similarity.shape)
            if j not in used_tracks:
                matches[i] = tracked_entities[j].entity_id
                used_tracks.add(j)
                similarity[i, :] = -1
                similarity[:, j] = -1

        return matches


class ConsistencyTracker:
    """
    Main consistency tracking system.

    Tracks characters and objects across frames,
    maintaining appearance consistency.
    """

    def __init__(self, config: Optional[ConsistencyConfig] = None):
        self.config = config or ConsistencyConfig()
        self.extractor = AppearanceExtractor(self.config.embedding_dim)
        self.matcher = EntityMatcher(self.config)

        self.entities: Dict[str, TrackedEntity] = {}
        self._next_id = 0
        self._current_frame = 0

        logger.info("ConsistencyTracker initialized")

    def register_entity(
        self,
        entity_type: EntityType,
        reference_image: np.ndarray,
        name: Optional[str] = None,
        description: Optional[str] = None,
        bbox: Optional[BoundingBox] = None
    ) -> str:
        """
        Register a new entity to track.

        Args:
            entity_type: Type of entity
            reference_image: Reference image
            name: Optional name
            description: Optional description
            bbox: Optional bounding box in reference

        Returns:
            Entity ID
        """
        entity_id = f"entity_{self._next_id:04d}"
        self._next_id += 1

        # Extract appearance
        appearance = self.extractor.extract(reference_image, bbox)

        entity = TrackedEntity(
            entity_id=entity_id,
            entity_type=entity_type,
            name=name,
            description=description,
            reference_appearance=appearance,
            first_frame=self._current_frame,
            last_frame=self._current_frame
        )

        if bbox:
            entity.bbox_history[self._current_frame] = bbox

        self.entities[entity_id] = entity
        logger.info(f"Registered entity: {entity_id} ({name or entity_type.value})")

        return entity_id

    async def process_frame(
        self,
        frame: np.ndarray,
        detections: Optional[List[Tuple[BoundingBox, EntityType]]] = None,
        frame_index: Optional[int] = None
    ) -> Dict[str, BoundingBox]:
        """
        Process a frame for consistency tracking.

        Args:
            frame: Video frame
            detections: Optional detected entities (bbox, type)
            frame_index: Optional frame index

        Returns:
            Dict mapping entity_id to bbox
        """
        if frame_index is not None:
            self._current_frame = frame_index
        else:
            self._current_frame += 1

        # If no detections provided, use full frame for each entity
        if detections is None:
            # Try to match against known entities
            return await self._match_known_entities(frame)

        # Extract appearances for detections
        current_entities = []
        for bbox, entity_type in detections:
            appearance = self.extractor.extract(frame, bbox)
            current_entities.append((bbox, appearance))

        # Match to tracked entities
        active_entities = [e for e in self.entities.values()
                         if e.state != TrackingState.LOST]

        matches = self.matcher.match(current_entities, active_entities)

        # Update matched entities
        result = {}
        matched_ids = set()

        for det_idx, entity_id in matches.items():
            bbox, appearance = current_entities[det_idx]
            entity = self.entities[entity_id]

            entity.update_appearance(appearance, self._current_frame)
            entity.bbox_history[self._current_frame] = bbox
            entity.state = TrackingState.ACTIVE

            result[entity_id] = bbox
            matched_ids.add(entity_id)

        # Handle unmatched detections (create new entities)
        for i, (bbox, appearance) in enumerate(current_entities):
            if i not in matches:
                entity_type = detections[i][1]
                entity_id = self.register_entity(
                    entity_type, frame, bbox=bbox
                )
                result[entity_id] = bbox

        # Handle unmatched tracked entities (occluded)
        for entity in active_entities:
            if entity.entity_id not in matched_ids:
                entity.frames_occluded += 1
                if entity.frames_occluded > self.config.max_frames_occluded:
                    entity.state = TrackingState.LOST
                else:
                    entity.state = TrackingState.OCCLUDED

        return result

    async def _match_known_entities(
        self,
        frame: np.ndarray
    ) -> Dict[str, BoundingBox]:
        """Match frame against known entities (no detection)."""
        result = {}

        # For each active entity, try to find it
        for entity in self.entities.values():
            if entity.state == TrackingState.LOST:
                continue

            if entity.reference_appearance is None:
                continue

            # Extract appearance from frame
            frame_appearance = self.extractor.extract(frame)

            # Compare similarity
            sim = frame_appearance.similarity(entity.reference_appearance)

            if sim >= self.config.similarity_threshold:
                # Entity likely present
                entity.state = TrackingState.ACTIVE
                entity.frames_visible += 1
                entity.last_frame = self._current_frame

                # Use last known bbox or full frame
                if entity.bbox_history:
                    last_bbox = entity.bbox_history[max(entity.bbox_history.keys())]
                    result[entity.entity_id] = last_bbox
                else:
                    result[entity.entity_id] = BoundingBox(0, 0, 1, 1)

        return result

    def get_entity_embedding(self, entity_id: str) -> Optional[np.ndarray]:
        """Get the current embedding for an entity."""
        entity = self.entities.get(entity_id)
        if entity and entity.reference_appearance:
            return entity.reference_appearance.embedding
        return None

    def get_consistency_scores(self) -> List[ConsistencyScore]:
        """Get consistency scores for all entities."""
        scores = []

        for entity in self.entities.values():
            if entity.state == TrackingState.LOST:
                continue

            # Compute appearance consistency
            if len(entity.appearance_history) >= 2:
                similarities = []
                ref = entity.reference_appearance
                for app in entity.appearance_history:
                    similarities.append(app.similarity(ref))
                appearance_score = float(np.mean(similarities))
            else:
                appearance_score = 1.0

            # Compute temporal consistency
            if entity.frames_visible > 0:
                temporal_score = 1.0 - (
                    entity.frames_occluded /
                    (entity.frames_visible + entity.frames_occluded)
                )
            else:
                temporal_score = 0.0

            # Compute spatial consistency (bbox stability)
            if len(entity.bbox_history) >= 2:
                bboxes = list(entity.bbox_history.values())
                movements = []
                for i in range(1, len(bboxes)):
                    dx = bboxes[i].center[0] - bboxes[i-1].center[0]
                    dy = bboxes[i].center[1] - bboxes[i-1].center[1]
                    movements.append(np.sqrt(dx**2 + dy**2))
                avg_movement = np.mean(movements)
                spatial_score = max(0, 1.0 - avg_movement * 10)
            else:
                spatial_score = 1.0

            # Overall score
            overall = 0.5 * appearance_score + 0.3 * temporal_score + 0.2 * spatial_score

            # Identify issues
            issues = []
            if appearance_score < 0.7:
                issues.append("Appearance inconsistency detected")
            if temporal_score < 0.7:
                issues.append("Frequent occlusions")
            if spatial_score < 0.7:
                issues.append("Erratic movement")

            scores.append(ConsistencyScore(
                entity_id=entity.entity_id,
                overall_score=overall,
                appearance_score=appearance_score,
                temporal_score=temporal_score,
                spatial_score=spatial_score,
                issues=issues
            ))

        return scores

    def apply_consistency_guidance(
        self,
        prompt: str,
        entity_id: Optional[str] = None
    ) -> str:
        """
        Enhance prompt with consistency guidance.

        Args:
            prompt: Original prompt
            entity_id: Optional specific entity

        Returns:
            Enhanced prompt
        """
        if entity_id:
            entities = [self.entities.get(entity_id)]
        else:
            entities = list(self.entities.values())

        guidance_parts = []
        for entity in entities:
            if entity is None or entity.state == TrackingState.LOST:
                continue

            if entity.name:
                guidance_parts.append(f"maintain consistent appearance for {entity.name}")

            if entity.description:
                guidance_parts.append(entity.description)

        if guidance_parts:
            guidance = ", ".join(guidance_parts)
            return f"{prompt}. {guidance}"

        return prompt

    def reset(self):
        """Reset all tracking."""
        self.entities.clear()
        self._next_id = 0
        self._current_frame = 0


# Singleton instance
_tracker: Optional[ConsistencyTracker] = None


def get_consistency_tracker() -> ConsistencyTracker:
    """Get the global consistency tracker instance."""
    global _tracker
    if _tracker is None:
        _tracker = ConsistencyTracker()
    return _tracker


async def track_entity_consistency(
    frames: List[np.ndarray],
    entity_id: Optional[str] = None
) -> List[ConsistencyScore]:
    """Convenience function to track consistency across frames."""
    tracker = get_consistency_tracker()

    for i, frame in enumerate(frames):
        await tracker.process_frame(frame, frame_index=i)

    return tracker.get_consistency_scores()
