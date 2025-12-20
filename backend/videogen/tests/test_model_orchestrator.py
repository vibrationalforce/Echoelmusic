"""
Tests for Model Orchestrator - Super Genius AI Feature #1
"""

import pytest
import asyncio
from unittest.mock import patch, MagicMock

from ..layer1_inference.model_orchestrator import (
    ModelTier,
    ComplexityLevel,
    ModelProfile,
    PromptAnalysis,
    OrchestrationDecision,
    PromptAnalyzer,
    ModelOrchestrator,
    get_orchestrator,
    select_optimal_model,
)


class TestPromptAnalyzer:
    """Tests for PromptAnalyzer class."""

    def setup_method(self):
        self.analyzer = PromptAnalyzer()

    def test_simple_prompt_analysis(self):
        """Test analysis of a simple prompt."""
        prompt = "A cat sitting on a couch"
        analysis = self.analyzer.analyze(prompt)

        assert analysis.complexity == ComplexityLevel.SIMPLE
        assert analysis.estimated_objects >= 1
        assert not analysis.has_motion
        assert analysis.scene_transitions == 0

    def test_complex_prompt_analysis(self):
        """Test analysis of a complex prompt."""
        prompt = "A person running through an exploding building, then jumping onto a helicopter"
        analysis = self.analyzer.analyze(prompt)

        assert analysis.complexity in [ComplexityLevel.COMPLEX, ComplexityLevel.ULTRA_COMPLEX]
        assert analysis.has_motion
        assert analysis.scene_transitions >= 1
        assert len(analysis.action_keywords) > 0

    def test_motion_detection(self):
        """Test motion keyword detection."""
        prompt = "A dancer spinning and jumping across the stage"
        analysis = self.analyzer.analyze(prompt)

        assert analysis.has_motion
        assert analysis.motion_complexity > 0
        assert "dancing" in analysis.action_keywords or "jumping" in analysis.action_keywords

    def test_cinematic_detection(self):
        """Test cinematic style detection."""
        prompt = "Cinematic shot of a hero walking in slow motion, movie quality"
        analysis = self.analyzer.analyze(prompt)

        assert analysis.cinematic_level > 0
        assert "cinematic" in analysis.style_keywords or "movie" in analysis.style_keywords

    def test_quality_keywords_detection(self):
        """Test quality keyword detection."""
        prompt = "8k ultra detailed masterpiece of a sunset"
        analysis = self.analyzer.analyze(prompt)

        assert analysis.detail_level > 0
        assert len(analysis.quality_keywords) >= 2

    def test_character_detection(self):
        """Test character count detection."""
        prompt = "A group of people dancing at a party with crowd in background"
        analysis = self.analyzer.analyze(prompt)

        assert analysis.character_count >= 1

    def test_tier_recommendation_simple(self):
        """Test tier recommendation for simple prompts."""
        prompt = "A still image of a mountain"
        analysis = self.analyzer.analyze(prompt)

        assert analysis.recommended_tier in [ModelTier.STANDARD, ModelTier.FAST]

    def test_tier_recommendation_complex(self):
        """Test tier recommendation for complex prompts."""
        prompt = "Cinematic 8k masterpiece of an epic battle scene with explosions"
        analysis = self.analyzer.analyze(prompt)

        assert analysis.recommended_tier in [ModelTier.HIGH, ModelTier.ULTRA]


class TestModelOrchestrator:
    """Tests for ModelOrchestrator class."""

    def setup_method(self):
        self.orchestrator = ModelOrchestrator()

    @pytest.mark.asyncio
    async def test_select_model_simple(self):
        """Test model selection for simple prompt."""
        decision = await self.orchestrator.select_model(
            prompt="A cat on a couch",
            width=1280,
            height=720,
            num_frames=49
        )

        assert isinstance(decision, OrchestrationDecision)
        assert decision.selected_model is not None
        assert decision.estimated_time > 0
        assert decision.estimated_quality > 0

    @pytest.mark.asyncio
    async def test_select_model_with_i2v(self):
        """Test model selection with I2V requirement."""
        decision = await self.orchestrator.select_model(
            prompt="Animate this image",
            width=1280,
            height=720,
            num_frames=49,
            use_i2v=True
        )

        assert decision.selected_model.supports_i2v

    @pytest.mark.asyncio
    async def test_select_model_with_controlnet(self):
        """Test model selection with ControlNet requirement."""
        decision = await self.orchestrator.select_model(
            prompt="Follow the depth map",
            width=1280,
            height=720,
            num_frames=49,
            use_controlnet=True
        )

        assert decision.selected_model.supports_controlnet

    @pytest.mark.asyncio
    async def test_force_tier(self):
        """Test forcing a specific model tier."""
        decision = await self.orchestrator.select_model(
            prompt="Simple test",
            width=1280,
            height=720,
            num_frames=49,
            force_tier=ModelTier.ULTRA
        )

        # Should try to use ULTRA or fall back with warning
        assert decision.selected_model is not None

    @pytest.mark.asyncio
    async def test_prefer_speed(self):
        """Test speed preference."""
        decision_quality = await self.orchestrator.select_model(
            prompt="Test prompt",
            width=1280,
            height=720,
            num_frames=49,
            prefer_speed=False
        )

        decision_speed = await self.orchestrator.select_model(
            prompt="Test prompt",
            width=1280,
            height=720,
            num_frames=49,
            prefer_speed=True
        )

        # Speed preference should result in faster model
        assert decision_speed.estimated_time <= decision_quality.estimated_time

    def test_config_overrides(self):
        """Test that config overrides are generated."""
        analyzer = PromptAnalyzer()
        analysis = analyzer.analyze("8k cinematic masterpiece with complex motion")

        overrides = self.orchestrator._generate_config_overrides(
            analysis,
            self.orchestrator.profiles[0],
            1280, 720, 49
        )

        assert isinstance(overrides, dict)
        # Should have some overrides for complex prompts
        assert len(overrides) > 0

    def test_get_recommended_tier_for_vram(self):
        """Test VRAM-based tier recommendation."""
        # High VRAM
        tier = self.orchestrator.get_recommended_tier_for_vram(30.0)
        assert tier == ModelTier.ULTRA

        # Medium VRAM
        tier = self.orchestrator.get_recommended_tier_for_vram(16.0)
        assert tier == ModelTier.HIGH

        # Low VRAM
        tier = self.orchestrator.get_recommended_tier_for_vram(6.0)
        assert tier == ModelTier.FAST

    def test_model_stats(self):
        """Test model statistics retrieval."""
        stats = self.orchestrator.get_model_stats()
        assert isinstance(stats, dict)


class TestGlobalOrchestrator:
    """Tests for global orchestrator instance."""

    def test_get_orchestrator_singleton(self):
        """Test that get_orchestrator returns singleton."""
        orch1 = get_orchestrator()
        orch2 = get_orchestrator()
        assert orch1 is orch2

    @pytest.mark.asyncio
    async def test_select_optimal_model_convenience(self):
        """Test convenience function."""
        decision = await select_optimal_model(
            prompt="Test prompt",
            width=1280,
            height=720,
            num_frames=49
        )

        assert isinstance(decision, OrchestrationDecision)
