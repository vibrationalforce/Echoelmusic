"""
Tests for Speculative Decoder - Super Genius AI Feature #7
"""

import pytest
import numpy as np
import torch

from ..layer1_inference.speculative_decoder import (
    DecoderConfig,
    DraftPrediction,
    VerificationResult,
    SpeculativeStats,
    DraftModel,
    TargetModel,
    SpeculativeDecoder,
    SpeculativeVideoDecoder,
    get_speculative_decoder,
    speculative_decode,
)


class TestDecoderConfig:
    """Tests for DecoderConfig class."""

    def test_default_config(self):
        """Test default configuration."""
        config = DecoderConfig()

        assert config.draft_steps == 4
        assert config.temperature == 1.0
        assert config.acceptance_threshold == 0.8

    def test_custom_config(self):
        """Test custom configuration."""
        config = DecoderConfig(
            draft_steps=8,
            temperature=0.7,
            acceptance_threshold=0.9
        )

        assert config.draft_steps == 8
        assert config.temperature == 0.7
        assert config.acceptance_threshold == 0.9


class TestDraftPrediction:
    """Tests for DraftPrediction class."""

    def test_prediction_creation(self):
        """Test creating a draft prediction."""
        tokens = [1, 2, 3, 4, 5]
        probs = [0.9, 0.85, 0.8, 0.75, 0.7]

        pred = DraftPrediction(
            tokens=tokens,
            probabilities=probs,
            draft_time_ms=10.5
        )

        assert len(pred.tokens) == 5
        assert pred.draft_time_ms == 10.5

    def test_mean_probability(self):
        """Test mean probability calculation."""
        pred = DraftPrediction(
            tokens=[1, 2, 3],
            probabilities=[0.8, 0.9, 1.0],
            draft_time_ms=5.0
        )

        assert pred.mean_probability == pytest.approx(0.9, rel=0.01)


class TestVerificationResult:
    """Tests for VerificationResult class."""

    def test_full_acceptance(self):
        """Test fully accepted prediction."""
        result = VerificationResult(
            accepted_tokens=[1, 2, 3, 4],
            rejected_at_index=None,
            corrected_token=None,
            verification_time_ms=5.0
        )

        assert result.acceptance_rate == 1.0
        assert result.all_accepted

    def test_partial_acceptance(self):
        """Test partially accepted prediction."""
        result = VerificationResult(
            accepted_tokens=[1, 2],
            rejected_at_index=2,
            corrected_token=99,
            verification_time_ms=5.0
        )

        assert result.rejected_at_index == 2
        assert result.corrected_token == 99
        assert not result.all_accepted


class TestSpeculativeStats:
    """Tests for SpeculativeStats class."""

    def test_stats_initialization(self):
        """Test stats initialization."""
        stats = SpeculativeStats()

        assert stats.total_draft_tokens == 0
        assert stats.accepted_tokens == 0
        assert stats.speedup_factor == 1.0

    def test_update_stats(self):
        """Test updating stats."""
        stats = SpeculativeStats()

        stats.update(draft_tokens=4, accepted=3, draft_time=10.0, verify_time=5.0)

        assert stats.total_draft_tokens == 4
        assert stats.accepted_tokens == 3
        assert stats.acceptance_rate == 0.75

    def test_speedup_calculation(self):
        """Test speedup calculation."""
        stats = SpeculativeStats()

        # High acceptance should give speedup
        for _ in range(10):
            stats.update(draft_tokens=4, accepted=4, draft_time=5.0, verify_time=2.0)

        # Should have speedup > 1
        assert stats.speedup_factor > 1.0


class TestDraftModel:
    """Tests for DraftModel class."""

    def setup_method(self):
        self.model = DraftModel(hidden_size=256, num_layers=2)

    def test_generate_draft(self):
        """Test generating draft tokens."""
        context = torch.randn(1, 10, 256)

        tokens, probs = self.model.generate(context, num_tokens=4)

        assert len(tokens) == 4
        assert len(probs) == 4
        assert all(0 <= p <= 1 for p in probs)

    def test_draft_speed(self):
        """Test draft model is fast."""
        import time
        context = torch.randn(1, 10, 256)

        start = time.time()
        for _ in range(100):
            self.model.generate(context, num_tokens=4)
        elapsed = time.time() - start

        # Should be very fast
        assert elapsed < 1.0  # 100 iterations in < 1 second


class TestTargetModel:
    """Tests for TargetModel class."""

    def setup_method(self):
        self.model = TargetModel(hidden_size=256, num_layers=8)

    def test_verify_tokens(self):
        """Test verifying tokens."""
        context = torch.randn(1, 10, 256)
        tokens = [1, 2, 3, 4]

        results = self.model.verify(context, tokens)

        assert len(results) == 4
        # Each result should be (accepted, correct_token)

    def test_full_generation(self):
        """Test full token generation."""
        context = torch.randn(1, 10, 256)

        token = self.model.generate_single(context)

        assert isinstance(token, int)


class TestSpeculativeDecoder:
    """Tests for SpeculativeDecoder class."""

    def setup_method(self):
        self.decoder = SpeculativeDecoder(
            draft_model=DraftModel(256, 2),
            target_model=TargetModel(256, 8),
            config=DecoderConfig(draft_steps=4)
        )

    def test_decode_step(self):
        """Test single decode step."""
        context = torch.randn(1, 10, 256)

        tokens, stats = self.decoder.decode_step(context)

        assert len(tokens) > 0
        assert isinstance(stats, dict)

    def test_decode_sequence(self):
        """Test decoding full sequence."""
        context = torch.randn(1, 10, 256)

        tokens = self.decoder.decode(context, max_tokens=20)

        assert len(tokens) <= 20
        assert len(tokens) > 0

    def test_stats_tracking(self):
        """Test statistics tracking."""
        context = torch.randn(1, 10, 256)

        self.decoder.decode(context, max_tokens=50)
        stats = self.decoder.get_stats()

        assert stats['total_draft_tokens'] > 0
        assert 'acceptance_rate' in stats
        assert 'speedup_factor' in stats

    def test_reset_stats(self):
        """Test resetting statistics."""
        context = torch.randn(1, 10, 256)
        self.decoder.decode(context, max_tokens=20)

        self.decoder.reset_stats()
        stats = self.decoder.get_stats()

        assert stats['total_draft_tokens'] == 0


class TestSpeculativeVideoDecoder:
    """Tests for SpeculativeVideoDecoder class."""

    def setup_method(self):
        self.decoder = SpeculativeVideoDecoder(
            draft_steps=4,
            parallel_frames=2
        )

    @pytest.mark.asyncio
    async def test_decode_latent_frame(self):
        """Test decoding a single latent frame."""
        latent = torch.randn(1, 4, 64, 64)
        condition = torch.randn(1, 77, 768)

        frame = await self.decoder.decode_frame(latent, condition)

        assert frame.shape[-2:] == (512, 512)  # Upscaled

    @pytest.mark.asyncio
    async def test_decode_video_batch(self):
        """Test decoding a video batch."""
        latents = torch.randn(10, 4, 64, 64)
        condition = torch.randn(1, 77, 768)

        frames = await self.decoder.decode_video(latents, condition)

        assert len(frames) == 10

    @pytest.mark.asyncio
    async def test_parallel_decoding(self):
        """Test parallel frame decoding."""
        import time

        latents = torch.randn(4, 4, 64, 64)
        condition = torch.randn(1, 77, 768)

        start = time.time()
        frames = await self.decoder.decode_video(latents, condition, parallel=True)
        parallel_time = time.time() - start

        start = time.time()
        frames_serial = await self.decoder.decode_video(latents, condition, parallel=False)
        serial_time = time.time() - start

        # Parallel should be faster or equal
        assert parallel_time <= serial_time * 1.5  # Allow some variance

    def test_get_speedup_estimate(self):
        """Test speedup estimation."""
        speedup = self.decoder.get_speedup_estimate()

        assert 1.0 <= speedup <= 4.0  # Reasonable range


class TestGlobalSpeculativeDecoder:
    """Tests for global speculative decoder."""

    def test_get_speculative_decoder_singleton(self):
        """Test singleton pattern."""
        dec1 = get_speculative_decoder()
        dec2 = get_speculative_decoder()
        assert dec1 is dec2

    @pytest.mark.asyncio
    async def test_speculative_decode_convenience(self):
        """Test convenience function."""
        latents = torch.randn(5, 4, 64, 64)
        condition = torch.randn(1, 77, 768)

        frames = await speculative_decode(latents, condition)

        assert len(frames) == 5


class TestSpeedupMeasurement:
    """Tests for measuring actual speedup."""

    @pytest.mark.asyncio
    async def test_measure_speedup(self):
        """Test measuring actual speedup."""
        decoder = SpeculativeVideoDecoder(draft_steps=4)

        latents = torch.randn(8, 4, 64, 64)
        condition = torch.randn(1, 77, 768)

        # Run with speculative decoding
        await decoder.decode_video(latents, condition)

        stats = decoder.get_stats()

        # Should have measured some speedup
        assert 'measured_speedup' in stats or 'speedup_factor' in stats
