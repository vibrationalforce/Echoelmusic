"""
Tests for Video Inpainting - Super Genius AI Feature #6
"""

import pytest
import numpy as np

from ..layer3_genius.video_inpainting import (
    InpaintMode,
    BlendMode,
    MaskFrame,
    InpaintRegion,
    InpaintResult,
    InpaintConfig,
    MaskTracker,
    FrameInpainter,
    VideoInpainter,
    get_video_inpainter,
    inpaint_video,
)


class TestInpaintMode:
    """Tests for InpaintMode enum."""

    def test_all_modes_defined(self):
        """Test all inpaint modes are defined."""
        modes = ['REMOVE', 'REPLACE', 'BLEND', 'BACKGROUND', 'EXTEND']
        for mode in modes:
            assert hasattr(InpaintMode, mode)


class TestMaskFrame:
    """Tests for MaskFrame class."""

    def test_mask_frame_creation(self):
        """Test creating a mask frame."""
        mask = np.zeros((480, 640), dtype=np.uint8)
        mask[100:200, 100:200] = 255

        mf = MaskFrame(frame_index=0, mask=mask, confidence=0.95)

        assert mf.frame_index == 0
        assert mf.mask.shape == (480, 640)
        assert mf.confidence == 0.95


class TestInpaintRegion:
    """Tests for InpaintRegion class."""

    def test_region_creation(self):
        """Test creating an inpaint region."""
        mask = np.zeros((480, 640), dtype=np.uint8)
        mask_frames = [MaskFrame(0, mask)]

        region = InpaintRegion(
            region_id="object_1",
            mode=InpaintMode.REMOVE,
            mask_frames=mask_frames,
            feather_radius=10
        )

        assert region.region_id == "object_1"
        assert region.mode == InpaintMode.REMOVE
        assert len(region.mask_frames) == 1


class TestMaskTracker:
    """Tests for MaskTracker class."""

    def setup_method(self):
        self.tracker = MaskTracker()

    def test_propagate_initial_mask(self):
        """Test propagating an initial mask."""
        frame = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)
        mask = np.zeros((480, 640), dtype=np.uint8)
        mask[100:200, 100:200] = 255

        result = self.tracker.propagate_mask(frame, mask)

        assert result.shape == mask.shape
        assert np.array_equal(result, mask)

    def test_propagate_without_mask(self):
        """Test propagating without explicit mask."""
        frame1 = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)
        mask = np.zeros((480, 640), dtype=np.uint8)
        mask[100:200, 100:200] = 255

        # Set initial mask
        self.tracker.propagate_mask(frame1, mask)

        # Propagate to next frame
        frame2 = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)
        result = self.tracker.propagate_mask(frame2)

        assert result.shape == mask.shape
        # Should have some non-zero pixels (propagated mask)


class TestFrameInpainter:
    """Tests for FrameInpainter class."""

    def setup_method(self):
        self.config = InpaintConfig()
        self.inpainter = FrameInpainter(self.config)

    def test_inpaint_remove(self):
        """Test remove inpainting."""
        frame = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)
        mask = np.zeros((480, 640), dtype=np.uint8)
        mask[100:200, 100:200] = 255

        result = self.inpainter.inpaint(frame, mask, InpaintMode.REMOVE)

        assert result.shape == frame.shape

    def test_inpaint_replace(self):
        """Test replace inpainting."""
        frame = np.zeros((480, 640, 3), dtype=np.uint8)
        replacement = np.ones((480, 640, 3), dtype=np.uint8) * 255
        mask = np.zeros((480, 640), dtype=np.uint8)
        mask[100:200, 100:200] = 255

        result = self.inpainter.inpaint(
            frame, mask, InpaintMode.REPLACE, replacement
        )

        # Masked region should be closer to replacement
        assert result[150, 150, 0] > 100

    def test_inpaint_blend(self):
        """Test blend inpainting."""
        frame = np.zeros((480, 640, 3), dtype=np.uint8)
        overlay = np.ones((480, 640, 3), dtype=np.uint8) * 128
        mask = np.ones((480, 640), dtype=np.uint8) * 255

        result = self.inpainter.inpaint(
            frame, mask, InpaintMode.BLEND, overlay
        )

        # Should be blended
        assert 0 < result[100, 100, 0] < 255


class TestVideoInpainter:
    """Tests for VideoInpainter class."""

    def setup_method(self):
        self.inpainter = VideoInpainter()

    @pytest.mark.asyncio
    async def test_inpaint_single_region(self):
        """Test inpainting a single region."""
        frames = np.random.randint(0, 255, (10, 480, 640, 3), dtype=np.uint8)
        mask = np.zeros((480, 640), dtype=np.uint8)
        mask[100:200, 100:200] = 255

        region = InpaintRegion(
            region_id="test",
            mode=InpaintMode.REMOVE,
            mask_frames=[MaskFrame(0, mask)]
        )

        result = await self.inpainter.inpaint(frames, [region])

        assert isinstance(result, InpaintResult)
        assert result.frames.shape == frames.shape
        assert result.regions_processed == 1

    @pytest.mark.asyncio
    async def test_inpaint_multiple_regions(self):
        """Test inpainting multiple regions."""
        frames = np.random.randint(0, 255, (10, 480, 640, 3), dtype=np.uint8)

        mask1 = np.zeros((480, 640), dtype=np.uint8)
        mask1[50:100, 50:100] = 255

        mask2 = np.zeros((480, 640), dtype=np.uint8)
        mask2[300:400, 300:400] = 255

        regions = [
            InpaintRegion("r1", InpaintMode.REMOVE, [MaskFrame(0, mask1)]),
            InpaintRegion("r2", InpaintMode.REMOVE, [MaskFrame(0, mask2)]),
        ]

        result = await self.inpainter.inpaint(frames, regions)

        assert result.regions_processed == 2

    def test_create_mask_from_bbox(self):
        """Test creating mask from bounding box."""
        mask = self.inpainter.create_mask_from_bbox(
            height=480,
            width=640,
            bbox=(100, 100, 200, 200),
            feather=False
        )

        assert mask.shape == (480, 640)
        assert mask[200, 200] == 255  # Inside bbox
        assert mask[0, 0] == 0  # Outside bbox

    def test_create_mask_from_points(self):
        """Test creating mask from polygon points."""
        points = [(100, 100), (200, 100), (200, 200), (100, 200)]

        mask = self.inpainter.create_mask_from_points(
            height=480,
            width=640,
            points=points
        )

        assert mask.shape == (480, 640)


class TestGlobalVideoInpainter:
    """Tests for global video inpainter."""

    def test_get_video_inpainter_singleton(self):
        """Test singleton pattern."""
        inp1 = get_video_inpainter()
        inp2 = get_video_inpainter()
        assert inp1 is inp2

    @pytest.mark.asyncio
    async def test_inpaint_video_convenience(self):
        """Test convenience function."""
        frames = np.random.randint(0, 255, (5, 240, 320, 3), dtype=np.uint8)
        mask = np.zeros((240, 320), dtype=np.uint8)
        mask[50:100, 50:100] = 255

        result = await inpaint_video(
            frames,
            [InpaintRegion("test", InpaintMode.REMOVE, [MaskFrame(0, mask)])]
        )

        assert isinstance(result, InpaintResult)
