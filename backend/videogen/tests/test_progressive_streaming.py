"""
Tests for Progressive Frame Streaming - Super Genius AI Feature #4
"""

import pytest
import asyncio
import numpy as np
import json
from datetime import datetime

from ..layer2_workflow.progressive_output import (
    StreamQuality,
    StreamEventType,
    StreamConfig,
    StreamEvent,
    GenerationProgress,
    FrameEncoder,
    AdaptiveQualityController,
    FrameCache,
    ProgressiveOutputStream,
    WebSocketStreamHandler,
    get_progressive_stream,
)


class TestStreamEvent:
    """Tests for StreamEvent class."""

    def test_event_creation(self):
        """Test creating a stream event."""
        event = StreamEvent(
            event_type=StreamEventType.FRAME_AVAILABLE,
            frame_index=0,
            progress=0.5
        )

        assert event.event_type == StreamEventType.FRAME_AVAILABLE
        assert event.frame_index == 0
        assert event.progress == 0.5

    def test_event_to_json(self):
        """Test JSON serialization."""
        event = StreamEvent(
            event_type=StreamEventType.PROGRESS_UPDATE,
            progress=0.5,
            eta_seconds=10.0
        )

        json_str = event.to_json()
        data = json.loads(json_str)

        assert data['event'] == 'progress_update'
        assert data['progress'] == 0.5
        assert data['eta_seconds'] == 10.0

    def test_event_with_frame_data(self):
        """Test event with frame data."""
        frame_data = b'\x00\x01\x02\x03'
        event = StreamEvent(
            event_type=StreamEventType.FRAME_AVAILABLE,
            frame_index=0,
            frame_data=frame_data,
            quality=StreamQuality.PREVIEW
        )

        json_str = event.to_json()
        data = json.loads(json_str)

        assert 'frame_data' in data
        assert data['quality'] == 'preview'


class TestGenerationProgress:
    """Tests for GenerationProgress class."""

    def test_progress_calculation(self):
        """Test progress calculation."""
        progress = GenerationProgress(total_frames=100)
        progress.completed_frames = 50

        assert progress.progress == 0.5

    def test_eta_calculation(self):
        """Test ETA calculation."""
        progress = GenerationProgress(total_frames=100)
        progress.completed_frames = 50
        progress.frame_times = [0.1, 0.1, 0.1, 0.1, 0.1]  # 0.1s per frame

        eta = progress.eta_seconds
        assert eta == pytest.approx(5.0, rel=0.1)  # 50 frames * 0.1s

    def test_add_frame(self):
        """Test adding a frame."""
        progress = GenerationProgress(total_frames=100)
        progress.started_at = datetime.now()

        progress.add_frame()
        progress.add_frame()

        assert progress.completed_frames == 2


class TestFrameEncoder:
    """Tests for FrameEncoder class."""

    def setup_method(self):
        self.encoder = FrameEncoder(jpeg_quality=75)

    def test_encode_frame(self):
        """Test encoding a frame."""
        frame = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)

        encoded = self.encoder.encode(frame, StreamQuality.PREVIEW)

        assert len(encoded) > 0
        assert isinstance(encoded, bytes)

    def test_quality_sizes(self):
        """Test that higher quality = larger size."""
        frame = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)

        thumbnail = self.encoder.encode(frame, StreamQuality.THUMBNAIL)
        preview = self.encoder.encode(frame, StreamQuality.PREVIEW)
        standard = self.encoder.encode(frame, StreamQuality.STANDARD)

        # Higher quality should generally be larger
        assert len(thumbnail) <= len(preview) <= len(standard)


class TestAdaptiveQualityController:
    """Tests for AdaptiveQualityController class."""

    def setup_method(self):
        self.controller = AdaptiveQualityController(
            initial_quality=StreamQuality.PREVIEW
        )

    def test_initial_quality(self):
        """Test initial quality."""
        assert self.controller.get_current_quality() == StreamQuality.PREVIEW

    def test_quality_upgrade_on_fast_network(self):
        """Test quality upgrade when network is fast."""
        # Simulate fast network: small frames, quick sends
        for _ in range(20):
            self.controller.record_send(1000, 0.001)  # 1KB in 1ms = 1MB/s

        quality = self.controller.get_current_quality()
        # Should upgrade from PREVIEW
        assert quality in [StreamQuality.STANDARD, StreamQuality.HIGH]

    def test_quality_downgrade_on_slow_network(self):
        """Test quality downgrade when network is slow."""
        self.controller.current_quality = StreamQuality.HIGH

        # Simulate slow network: large frames, slow sends
        for _ in range(20):
            self.controller.record_send(100000, 2.0)  # 100KB in 2s = 50KB/s

        quality = self.controller.get_current_quality()
        # Should downgrade
        assert quality in [StreamQuality.PREVIEW, StreamQuality.THUMBNAIL]


class TestFrameCache:
    """Tests for FrameCache class."""

    def setup_method(self):
        self.cache = FrameCache(max_frames=10)

    def test_store_and_get(self):
        """Test storing and retrieving frames."""
        data = b'\x00\x01\x02\x03'
        self.cache.store(0, StreamQuality.PREVIEW, data)

        retrieved = self.cache.get(0, StreamQuality.PREVIEW)
        assert retrieved == data

    def test_get_missing(self):
        """Test getting missing frame."""
        result = self.cache.get(999, StreamQuality.PREVIEW)
        assert result is None

    def test_eviction(self):
        """Test frame eviction when cache is full."""
        # Fill cache beyond limit
        for i in range(15):
            self.cache.store(i, StreamQuality.PREVIEW, b'data')

        # First frames should be evicted
        assert self.cache.get(0, StreamQuality.PREVIEW) is None
        assert self.cache.get(14, StreamQuality.PREVIEW) is not None

    def test_quality_fallback(self):
        """Test quality fallback."""
        self.cache.store(0, StreamQuality.HIGH, b'high_quality')

        # Request lower quality, should fall back to higher
        result = self.cache.get(0, StreamQuality.PREVIEW)
        assert result == b'high_quality'


class TestProgressiveOutputStream:
    """Tests for ProgressiveOutputStream class."""

    def setup_method(self):
        self.stream = ProgressiveOutputStream()

    @pytest.mark.asyncio
    async def test_start_generation(self):
        """Test starting a generation session."""
        await self.stream.start_generation(
            session_id="test_session",
            total_frames=100,
            width=1280,
            height=720,
            fps=24
        )

        info = self.stream.get_session_info("test_session")
        assert info is not None
        assert info['total_frames'] == 100

    @pytest.mark.asyncio
    async def test_emit_frame(self):
        """Test emitting a frame."""
        await self.stream.start_generation(
            "test_session", 100, 1280, 720
        )

        frame = np.random.randint(0, 255, (720, 1280, 3), dtype=np.uint8)
        await self.stream.emit_frame("test_session", 0, frame)

        info = self.stream.get_session_info("test_session")
        assert info['completed_frames'] == 1

    @pytest.mark.asyncio
    async def test_emit_progress(self):
        """Test emitting progress update."""
        await self.stream.start_generation(
            "test_session", 100, 1280, 720
        )

        await self.stream.emit_progress("test_session", 0.5, "Halfway done")

        # Should not raise

    @pytest.mark.asyncio
    async def test_complete_generation(self):
        """Test completing a generation."""
        await self.stream.start_generation(
            "test_session", 100, 1280, 720
        )

        await self.stream.complete_generation(
            "test_session",
            success=True,
            result_url="http://example.com/video.mp4"
        )

        # Session should be cleaned up
        info = self.stream.get_session_info("test_session")
        assert info is None

    @pytest.mark.asyncio
    async def test_frame_cache_retrieval(self):
        """Test retrieving cached frames."""
        await self.stream.start_generation(
            "test_session", 100, 1280, 720
        )

        frame = np.random.randint(0, 255, (720, 1280, 3), dtype=np.uint8)
        await self.stream.emit_frame("test_session", 0, frame)

        cached = await self.stream.get_cached_frame(0, StreamQuality.STANDARD)
        assert cached is not None


class TestGlobalProgressiveStream:
    """Tests for global progressive stream."""

    def test_get_progressive_stream_singleton(self):
        """Test singleton pattern."""
        stream1 = get_progressive_stream()
        stream2 = get_progressive_stream()
        assert stream1 is stream2
