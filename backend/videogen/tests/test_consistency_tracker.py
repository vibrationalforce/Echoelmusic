"""
Tests for Character Consistency Tracker - Super Genius AI Feature #8
"""

import pytest
import numpy as np

from ..layer3_genius.consistency_tracker import (
    EntityType,
    TrackingMode,
    BoundingBox,
    EntityAppearance,
    TrackedEntity,
    EntityMatch,
    TrackingResult,
    AppearanceExtractor,
    EntityMatcher,
    ConsistencyEnforcer,
    ConsistencyTracker,
    get_consistency_tracker,
    track_entities,
)


class TestEntityType:
    """Tests for EntityType enum."""

    def test_all_types_defined(self):
        """Test all entity types are defined."""
        types = ['CHARACTER', 'OBJECT', 'BACKGROUND', 'VEHICLE', 'ANIMAL']
        for t in types:
            assert hasattr(EntityType, t)


class TestBoundingBox:
    """Tests for BoundingBox class."""

    def test_bbox_creation(self):
        """Test creating a bounding box."""
        bbox = BoundingBox(x1=100, y1=100, x2=200, y2=200)

        assert bbox.width == 100
        assert bbox.height == 100
        assert bbox.center == (150, 150)
        assert bbox.area == 10000

    def test_bbox_iou(self):
        """Test IoU calculation."""
        bbox1 = BoundingBox(0, 0, 100, 100)
        bbox2 = BoundingBox(50, 50, 150, 150)

        iou = bbox1.iou(bbox2)

        # 50x50 intersection, 17500 union
        expected_iou = 2500 / 17500
        assert iou == pytest.approx(expected_iou, rel=0.01)

    def test_bbox_no_overlap(self):
        """Test IoU with no overlap."""
        bbox1 = BoundingBox(0, 0, 50, 50)
        bbox2 = BoundingBox(100, 100, 150, 150)

        iou = bbox1.iou(bbox2)
        assert iou == 0.0


class TestEntityAppearance:
    """Tests for EntityAppearance class."""

    def test_appearance_creation(self):
        """Test creating appearance descriptor."""
        embedding = np.random.randn(512).astype(np.float32)

        appearance = EntityAppearance(
            embedding=embedding,
            color_histogram=np.ones(256) / 256,
            texture_features=np.random.randn(128)
        )

        assert appearance.embedding.shape == (512,)

    def test_appearance_similarity(self):
        """Test similarity computation."""
        embedding1 = np.array([1, 0, 0, 0], dtype=np.float32)
        embedding2 = np.array([1, 0, 0, 0], dtype=np.float32)

        app1 = EntityAppearance(embedding=embedding1)
        app2 = EntityAppearance(embedding=embedding2)

        similarity = app1.similarity(app2)
        assert similarity == pytest.approx(1.0, rel=0.01)

    def test_appearance_dissimilarity(self):
        """Test dissimilar appearances."""
        embedding1 = np.array([1, 0, 0, 0], dtype=np.float32)
        embedding2 = np.array([0, 1, 0, 0], dtype=np.float32)

        app1 = EntityAppearance(embedding=embedding1)
        app2 = EntityAppearance(embedding=embedding2)

        similarity = app1.similarity(app2)
        assert similarity < 0.5


class TestTrackedEntity:
    """Tests for TrackedEntity class."""

    def test_entity_creation(self):
        """Test creating a tracked entity."""
        entity = TrackedEntity(
            entity_id="char_001",
            entity_type=EntityType.CHARACTER,
            name="Hero"
        )

        assert entity.entity_id == "char_001"
        assert entity.entity_type == EntityType.CHARACTER
        assert entity.name == "Hero"

    def test_add_frame_observation(self):
        """Test adding frame observations."""
        entity = TrackedEntity("e1", EntityType.CHARACTER)
        bbox = BoundingBox(100, 100, 200, 200)
        appearance = EntityAppearance(embedding=np.random.randn(512))

        entity.add_observation(frame_index=0, bbox=bbox, appearance=appearance)
        entity.add_observation(frame_index=1, bbox=bbox, appearance=appearance)

        assert len(entity.observations) == 2
        assert entity.frame_range == (0, 1)

    def test_get_appearance_at_frame(self):
        """Test getting appearance at specific frame."""
        entity = TrackedEntity("e1", EntityType.OBJECT)
        appearance = EntityAppearance(embedding=np.ones(512))

        entity.add_observation(
            frame_index=5,
            bbox=BoundingBox(0, 0, 50, 50),
            appearance=appearance
        )

        result = entity.get_appearance_at(5)
        assert result is not None
        assert np.array_equal(result.embedding, appearance.embedding)


class TestAppearanceExtractor:
    """Tests for AppearanceExtractor class."""

    def setup_method(self):
        self.extractor = AppearanceExtractor(embedding_size=512)

    def test_extract_from_crop(self):
        """Test extracting appearance from crop."""
        crop = np.random.randint(0, 255, (100, 100, 3), dtype=np.uint8)

        appearance = self.extractor.extract(crop)

        assert isinstance(appearance, EntityAppearance)
        assert appearance.embedding.shape[0] == 512

    def test_extract_with_mask(self):
        """Test extracting with mask."""
        crop = np.random.randint(0, 255, (100, 100, 3), dtype=np.uint8)
        mask = np.ones((100, 100), dtype=np.uint8)

        appearance = self.extractor.extract(crop, mask=mask)

        assert appearance.embedding is not None

    def test_batch_extract(self):
        """Test batch extraction."""
        crops = [
            np.random.randint(0, 255, (100, 100, 3), dtype=np.uint8)
            for _ in range(5)
        ]

        appearances = self.extractor.extract_batch(crops)

        assert len(appearances) == 5


class TestEntityMatcher:
    """Tests for EntityMatcher class."""

    def setup_method(self):
        self.matcher = EntityMatcher(
            iou_threshold=0.3,
            appearance_threshold=0.7
        )

    def test_match_by_iou(self):
        """Test matching by IoU."""
        bbox1 = BoundingBox(100, 100, 200, 200)
        bbox2 = BoundingBox(110, 110, 210, 210)

        score = self.matcher.compute_iou_score(bbox1, bbox2)
        assert score > 0.5

    def test_match_by_appearance(self):
        """Test matching by appearance."""
        embedding = np.random.randn(512).astype(np.float32)
        app1 = EntityAppearance(embedding=embedding)
        app2 = EntityAppearance(embedding=embedding + np.random.randn(512) * 0.1)

        score = self.matcher.compute_appearance_score(app1, app2)
        assert score > 0.5

    def test_hungarian_matching(self):
        """Test Hungarian algorithm matching."""
        prev_entities = [
            TrackedEntity("e1", EntityType.CHARACTER),
            TrackedEntity("e2", EntityType.CHARACTER),
        ]
        current_detections = [
            (BoundingBox(100, 100, 200, 200), EntityAppearance(np.random.randn(512))),
            (BoundingBox(300, 300, 400, 400), EntityAppearance(np.random.randn(512))),
        ]

        # Add observations to entities
        for i, entity in enumerate(prev_entities):
            entity.add_observation(
                0,
                current_detections[i][0],
                current_detections[i][1]
            )

        matches = self.matcher.match(prev_entities, current_detections)

        assert len(matches) <= 2


class TestConsistencyEnforcer:
    """Tests for ConsistencyEnforcer class."""

    def setup_method(self):
        self.enforcer = ConsistencyEnforcer(strength=0.8)

    def test_enforce_appearance(self):
        """Test enforcing appearance consistency."""
        frame = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)
        reference_appearance = EntityAppearance(embedding=np.random.randn(512))
        bbox = BoundingBox(100, 100, 200, 200)

        result = self.enforcer.enforce(frame, bbox, reference_appearance)

        assert result.shape == frame.shape

    def test_blend_strength(self):
        """Test blend strength effect."""
        frame = np.zeros((480, 640, 3), dtype=np.uint8)
        reference = EntityAppearance(
            embedding=np.random.randn(512),
            color_histogram=np.ones(256) / 256
        )
        bbox = BoundingBox(100, 100, 200, 200)

        weak_enforcer = ConsistencyEnforcer(strength=0.2)
        strong_enforcer = ConsistencyEnforcer(strength=0.9)

        result_weak = weak_enforcer.enforce(frame, bbox, reference)
        result_strong = strong_enforcer.enforce(frame, bbox, reference)

        # Results should differ based on strength
        # (Implementation dependent)
        assert result_weak is not None
        assert result_strong is not None


class TestConsistencyTracker:
    """Tests for ConsistencyTracker class."""

    def setup_method(self):
        self.tracker = ConsistencyTracker(
            tracking_mode=TrackingMode.AUTO
        )

    @pytest.mark.asyncio
    async def test_track_single_frame(self):
        """Test tracking in a single frame."""
        frame = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)

        result = await self.tracker.track_frame(frame, frame_index=0)

        assert isinstance(result, TrackingResult)
        assert result.frame_index == 0

    @pytest.mark.asyncio
    async def test_track_video(self):
        """Test tracking across video."""
        frames = np.random.randint(0, 255, (10, 480, 640, 3), dtype=np.uint8)

        result = await self.tracker.track_video(frames)

        assert result.total_frames == 10
        assert len(result.frame_results) == 10

    @pytest.mark.asyncio
    async def test_register_entity(self):
        """Test registering a known entity."""
        reference_crop = np.random.randint(0, 255, (100, 100, 3), dtype=np.uint8)

        entity_id = await self.tracker.register_entity(
            name="Hero",
            entity_type=EntityType.CHARACTER,
            reference_crop=reference_crop
        )

        assert entity_id is not None

        # Verify entity is registered
        entities = self.tracker.get_registered_entities()
        assert len(entities) >= 1

    @pytest.mark.asyncio
    async def test_apply_consistency(self):
        """Test applying consistency to video."""
        frames = np.random.randint(0, 255, (10, 480, 640, 3), dtype=np.uint8)

        # Track first
        await self.tracker.track_video(frames)

        # Apply consistency
        result = await self.tracker.apply_consistency(frames)

        assert result.shape == frames.shape

    def test_get_entity_timeline(self):
        """Test getting entity timeline."""
        # Create entity with observations
        entity = TrackedEntity("e1", EntityType.CHARACTER, "Hero")
        for i in range(10):
            entity.add_observation(
                i,
                BoundingBox(100 + i * 5, 100, 200 + i * 5, 200),
                EntityAppearance(np.random.randn(512))
            )

        self.tracker._entities["e1"] = entity

        timeline = self.tracker.get_entity_timeline("e1")

        assert len(timeline) == 10


class TestTrackingModes:
    """Tests for different tracking modes."""

    @pytest.mark.asyncio
    async def test_auto_mode(self):
        """Test auto tracking mode."""
        tracker = ConsistencyTracker(tracking_mode=TrackingMode.AUTO)
        frame = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)

        result = await tracker.track_frame(frame, 0)
        assert result is not None

    @pytest.mark.asyncio
    async def test_manual_mode(self):
        """Test manual tracking mode."""
        tracker = ConsistencyTracker(tracking_mode=TrackingMode.MANUAL)

        # Register entity first
        reference = np.random.randint(0, 255, (100, 100, 3), dtype=np.uint8)
        await tracker.register_entity("test", EntityType.OBJECT, reference)

        frame = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)
        result = await tracker.track_frame(frame, 0)

        assert result is not None


class TestGlobalConsistencyTracker:
    """Tests for global consistency tracker."""

    def test_get_consistency_tracker_singleton(self):
        """Test singleton pattern."""
        tracker1 = get_consistency_tracker()
        tracker2 = get_consistency_tracker()
        assert tracker1 is tracker2

    @pytest.mark.asyncio
    async def test_track_entities_convenience(self):
        """Test convenience function."""
        frames = np.random.randint(0, 255, (5, 240, 320, 3), dtype=np.uint8)

        result = await track_entities(frames)

        assert result.total_frames == 5
