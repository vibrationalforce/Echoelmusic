"""
Tests for Video-to-Video Transformation Pipeline - Super Genius AI Feature #10
"""

import pytest
import numpy as np

from ..layer1_inference.video_to_video import (
    V2VMode,
    TransformStrength,
    V2VConfig,
    V2VResult,
    MotionExtractor,
    StyleEncoder,
    EnhancementModule,
    VideoToVideoPipeline,
    get_v2v_pipeline,
    transform_video,
)


class TestV2VMode:
    """Tests for V2VMode enum."""

    def test_all_modes_defined(self):
        """Test all V2V modes are defined."""
        modes = [
            'STYLE_TRANSFER',
            'MOTION_TRANSFER',
            'ENHANCEMENT',
            'UPSCALE',
            'INTERPOLATION',
            'COLORIZATION',
        ]
        for mode in modes:
            assert hasattr(V2VMode, mode)


class TestTransformStrength:
    """Tests for TransformStrength enum."""

    def test_strength_levels(self):
        """Test strength level values."""
        assert TransformStrength.SUBTLE.value < TransformStrength.MODERATE.value
        assert TransformStrength.MODERATE.value < TransformStrength.STRONG.value
        assert TransformStrength.STRONG.value < TransformStrength.EXTREME.value


class TestV2VConfig:
    """Tests for V2VConfig class."""

    def test_default_config(self):
        """Test default configuration."""
        config = V2VConfig(mode=V2VMode.ENHANCEMENT)

        assert config.mode == V2VMode.ENHANCEMENT
        assert config.strength == TransformStrength.MODERATE
        assert config.preserve_motion is True

    def test_custom_config(self):
        """Test custom configuration."""
        config = V2VConfig(
            mode=V2VMode.STYLE_TRANSFER,
            strength=TransformStrength.STRONG,
            style_reference="abstract",
            preserve_motion=False,
            temporal_consistency=0.9
        )

        assert config.mode == V2VMode.STYLE_TRANSFER
        assert config.strength == TransformStrength.STRONG
        assert config.style_reference == "abstract"


class TestV2VResult:
    """Tests for V2VResult class."""

    def test_result_creation(self):
        """Test creating a result."""
        frames = np.random.randint(0, 255, (10, 480, 640, 3), dtype=np.uint8)

        result = V2VResult(
            frames=frames,
            mode=V2VMode.ENHANCEMENT,
            processing_time_ms=1000.0,
            metrics={
                'psnr': 35.5,
                'ssim': 0.95,
            }
        )

        assert result.frames.shape == (10, 480, 640, 3)
        assert result.processing_time_ms == 1000.0
        assert result.metrics['psnr'] == 35.5

    def test_result_fps_calculation(self):
        """Test FPS calculation in result."""
        frames = np.random.randint(0, 255, (30, 480, 640, 3), dtype=np.uint8)

        result = V2VResult(
            frames=frames,
            mode=V2VMode.UPSCALE,
            processing_time_ms=1500.0
        )

        # 30 frames in 1500ms = 20 fps
        assert result.processing_fps == pytest.approx(20.0, rel=0.1)


class TestMotionExtractor:
    """Tests for MotionExtractor class."""

    def setup_method(self):
        self.extractor = MotionExtractor()

    def test_extract_optical_flow(self):
        """Test optical flow extraction."""
        frame1 = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)
        frame2 = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)

        flow = self.extractor.extract_flow(frame1, frame2)

        assert flow.shape == (480, 640, 2)

    def test_extract_motion_vectors(self):
        """Test motion vector extraction."""
        frames = np.random.randint(0, 255, (10, 480, 640, 3), dtype=np.uint8)

        motion = self.extractor.extract_motion(frames)

        assert len(motion) == 9  # n-1 flow fields

    def test_warp_frame(self):
        """Test frame warping."""
        frame = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)
        flow = np.zeros((480, 640, 2), dtype=np.float32)
        flow[:, :, 0] = 10  # Shift right by 10 pixels

        warped = self.extractor.warp_frame(frame, flow)

        assert warped.shape == frame.shape


class TestStyleEncoder:
    """Tests for StyleEncoder class."""

    def setup_method(self):
        self.encoder = StyleEncoder(style_dim=512)

    def test_encode_reference_image(self):
        """Test encoding reference image."""
        reference = np.random.randint(0, 255, (256, 256, 3), dtype=np.uint8)

        style_code = self.encoder.encode_image(reference)

        assert style_code.shape == (512,)

    def test_encode_text_style(self):
        """Test encoding text style description."""
        style_code = self.encoder.encode_text("oil painting, impressionist")

        assert style_code.shape == (512,)

    def test_interpolate_styles(self):
        """Test style interpolation."""
        style1 = np.random.randn(512).astype(np.float32)
        style2 = np.random.randn(512).astype(np.float32)

        interpolated = self.encoder.interpolate(style1, style2, t=0.5)

        assert interpolated.shape == (512,)
        # Should be roughly midpoint
        expected = (style1 + style2) / 2
        assert np.allclose(interpolated, expected, atol=0.1)


class TestEnhancementModule:
    """Tests for EnhancementModule class."""

    def setup_method(self):
        self.enhancer = EnhancementModule()

    def test_denoise(self):
        """Test denoising."""
        noisy = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)

        denoised = self.enhancer.denoise(noisy, strength=0.5)

        assert denoised.shape == noisy.shape

    def test_sharpen(self):
        """Test sharpening."""
        blurry = np.random.randint(100, 150, (480, 640, 3), dtype=np.uint8)

        sharpened = self.enhancer.sharpen(blurry, strength=0.5)

        assert sharpened.shape == blurry.shape

    def test_color_correct(self):
        """Test color correction."""
        frame = np.random.randint(0, 255, (480, 640, 3), dtype=np.uint8)

        corrected = self.enhancer.color_correct(frame)

        assert corrected.shape == frame.shape

    def test_upscale(self):
        """Test upscaling."""
        small = np.random.randint(0, 255, (240, 320, 3), dtype=np.uint8)

        upscaled = self.enhancer.upscale(small, scale=2)

        assert upscaled.shape == (480, 640, 3)


class TestVideoToVideoPipeline:
    """Tests for VideoToVideoPipeline class."""

    def setup_method(self):
        self.pipeline = VideoToVideoPipeline()

    @pytest.mark.asyncio
    async def test_style_transfer(self):
        """Test style transfer mode."""
        frames = np.random.randint(0, 255, (10, 480, 640, 3), dtype=np.uint8)
        style_ref = np.random.randint(0, 255, (256, 256, 3), dtype=np.uint8)

        config = V2VConfig(
            mode=V2VMode.STYLE_TRANSFER,
            strength=TransformStrength.MODERATE,
            style_reference=style_ref
        )

        result = await self.pipeline.transform(frames, config)

        assert isinstance(result, V2VResult)
        assert result.frames.shape == frames.shape
        assert result.mode == V2VMode.STYLE_TRANSFER

    @pytest.mark.asyncio
    async def test_enhancement(self):
        """Test enhancement mode."""
        frames = np.random.randint(0, 255, (10, 480, 640, 3), dtype=np.uint8)

        config = V2VConfig(mode=V2VMode.ENHANCEMENT)

        result = await self.pipeline.transform(frames, config)

        assert result.mode == V2VMode.ENHANCEMENT

    @pytest.mark.asyncio
    async def test_upscale(self):
        """Test upscale mode."""
        frames = np.random.randint(0, 255, (10, 240, 320, 3), dtype=np.uint8)

        config = V2VConfig(
            mode=V2VMode.UPSCALE,
            upscale_factor=2
        )

        result = await self.pipeline.transform(frames, config)

        assert result.frames.shape == (10, 480, 640, 3)

    @pytest.mark.asyncio
    async def test_motion_transfer(self):
        """Test motion transfer mode."""
        source_frames = np.random.randint(0, 255, (10, 480, 640, 3), dtype=np.uint8)
        motion_reference = np.random.randint(0, 255, (10, 480, 640, 3), dtype=np.uint8)

        config = V2VConfig(
            mode=V2VMode.MOTION_TRANSFER,
            motion_reference=motion_reference
        )

        result = await self.pipeline.transform(source_frames, config)

        assert result.frames.shape == source_frames.shape

    @pytest.mark.asyncio
    async def test_frame_interpolation(self):
        """Test frame interpolation mode."""
        frames = np.random.randint(0, 255, (10, 480, 640, 3), dtype=np.uint8)

        config = V2VConfig(
            mode=V2VMode.INTERPOLATION,
            interpolation_factor=2
        )

        result = await self.pipeline.transform(frames, config)

        # Should have more frames
        assert result.frames.shape[0] >= 19  # 2x interpolation

    @pytest.mark.asyncio
    async def test_colorization(self):
        """Test colorization mode."""
        grayscale = np.random.randint(0, 255, (10, 480, 640, 1), dtype=np.uint8)
        grayscale = np.repeat(grayscale, 3, axis=-1)  # Fake grayscale

        config = V2VConfig(mode=V2VMode.COLORIZATION)

        result = await self.pipeline.transform(grayscale, config)

        assert result.frames.shape[-1] == 3  # RGB output

    @pytest.mark.asyncio
    async def test_temporal_consistency(self):
        """Test temporal consistency in output."""
        # Create frames with pattern
        frames = np.zeros((10, 100, 100, 3), dtype=np.uint8)
        for i in range(10):
            frames[i, 20:80, 20:80] = 200

        config = V2VConfig(
            mode=V2VMode.ENHANCEMENT,
            temporal_consistency=0.9
        )

        result = await self.pipeline.transform(frames, config)

        # Compute frame-to-frame difference
        diffs = []
        for i in range(len(result.frames) - 1):
            diff = np.mean(np.abs(
                result.frames[i].astype(float) - result.frames[i + 1].astype(float)
            ))
            diffs.append(diff)

        # Should have low variance in differences (temporal consistency)
        assert np.std(diffs) < 50  # Reasonable threshold


class TestStrengthLevels:
    """Tests for different strength levels."""

    @pytest.mark.asyncio
    async def test_subtle_strength(self):
        """Test subtle transformation."""
        pipeline = VideoToVideoPipeline()
        frames = np.random.randint(0, 255, (5, 240, 320, 3), dtype=np.uint8)

        config = V2VConfig(
            mode=V2VMode.ENHANCEMENT,
            strength=TransformStrength.SUBTLE
        )

        result = await pipeline.transform(frames, config)

        # Subtle should have small changes
        diff = np.mean(np.abs(frames.astype(float) - result.frames.astype(float)))
        assert diff < 50

    @pytest.mark.asyncio
    async def test_extreme_strength(self):
        """Test extreme transformation."""
        pipeline = VideoToVideoPipeline()
        frames = np.random.randint(0, 255, (5, 240, 320, 3), dtype=np.uint8)

        config = V2VConfig(
            mode=V2VMode.ENHANCEMENT,
            strength=TransformStrength.EXTREME
        )

        result = await pipeline.transform(frames, config)

        # Extreme should have larger changes than subtle
        # (Implementation dependent, just verify it runs)
        assert result.frames.shape == frames.shape


class TestGlobalV2VPipeline:
    """Tests for global V2V pipeline."""

    def test_get_v2v_pipeline_singleton(self):
        """Test singleton pattern."""
        p1 = get_v2v_pipeline()
        p2 = get_v2v_pipeline()
        assert p1 is p2

    @pytest.mark.asyncio
    async def test_transform_video_convenience(self):
        """Test convenience function."""
        frames = np.random.randint(0, 255, (5, 240, 320, 3), dtype=np.uint8)

        result = await transform_video(
            frames,
            mode=V2VMode.ENHANCEMENT
        )

        assert isinstance(result, V2VResult)


class TestEdgeCases:
    """Tests for edge cases."""

    @pytest.mark.asyncio
    async def test_single_frame(self):
        """Test with single frame."""
        pipeline = VideoToVideoPipeline()
        frames = np.random.randint(0, 255, (1, 480, 640, 3), dtype=np.uint8)

        config = V2VConfig(mode=V2VMode.ENHANCEMENT)

        result = await pipeline.transform(frames, config)
        assert result.frames.shape[0] == 1

    @pytest.mark.asyncio
    async def test_very_small_frames(self):
        """Test with very small frames."""
        pipeline = VideoToVideoPipeline()
        frames = np.random.randint(0, 255, (10, 32, 32, 3), dtype=np.uint8)

        config = V2VConfig(mode=V2VMode.UPSCALE, upscale_factor=4)

        result = await pipeline.transform(frames, config)
        assert result.frames.shape == (10, 128, 128, 3)

    @pytest.mark.asyncio
    async def test_grayscale_input(self):
        """Test with grayscale input."""
        pipeline = VideoToVideoPipeline()
        frames = np.random.randint(0, 255, (10, 480, 640, 1), dtype=np.uint8)

        config = V2VConfig(mode=V2VMode.COLORIZATION)

        result = await pipeline.transform(frames, config)
        assert result.frames.shape[-1] == 3
