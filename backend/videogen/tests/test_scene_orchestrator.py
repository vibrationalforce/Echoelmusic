"""
Tests for Scene Orchestrator - Super Genius AI Feature #2
"""

import pytest
import asyncio
import numpy as np

from ..layer3_genius.scene_orchestrator import (
    TransitionType,
    SceneType,
    MoodType,
    SceneElement,
    SceneDefinition,
    Timeline,
    SceneBreakdown,
    PromptSceneParser,
    TransitionPlanner,
    ConsistencyManager,
    SceneOrchestrator,
    get_scene_orchestrator,
    breakdown_complex_prompt,
)


class TestPromptSceneParser:
    """Tests for PromptSceneParser class."""

    def setup_method(self):
        self.parser = PromptSceneParser()

    def test_single_scene(self):
        """Test parsing a single scene prompt."""
        prompt = "A person walking in a park"
        scenes = self.parser.parse(prompt)

        assert len(scenes) == 1
        assert scenes[0]['prompt'] == prompt

    def test_multi_scene_with_then(self):
        """Test parsing with 'then' separator."""
        prompt = "A cat sleeping, then waking up and stretching"
        scenes = self.parser.parse(prompt)

        assert len(scenes) >= 2

    def test_multi_scene_with_cut(self):
        """Test parsing with 'cut to' separator."""
        prompt = "A hero stands ready. Cut to the villain approaching."
        scenes = self.parser.parse(prompt)

        assert len(scenes) >= 2

    def test_scene_type_detection(self):
        """Test scene type detection."""
        prompt = "Wide shot establishing the city"
        scenes = self.parser.parse(prompt)

        # First scene with establishing keywords should be ESTABLISHING
        assert scenes[0]['scene_type'] in [SceneType.ESTABLISHING, SceneType.ACTION]

    def test_mood_detection(self):
        """Test mood detection."""
        prompt = "A tense suspenseful scene in a dark alley"
        scenes = self.parser.parse(prompt)

        assert scenes[0]['mood'] == MoodType.TENSE

    def test_camera_movement_detection(self):
        """Test camera movement detection."""
        prompt = "Pan left across the landscape, then zoom in on the castle"
        scenes = self.parser.parse(prompt)

        assert any(s.get('camera_movement') is not None for s in scenes)


class TestTransitionPlanner:
    """Tests for TransitionPlanner class."""

    def setup_method(self):
        self.planner = TransitionPlanner()

    def test_action_to_reaction_transition(self):
        """Test transition between action and reaction scenes."""
        scene_from = SceneDefinition(
            scene_id="s1",
            prompt="Hero strikes",
            scene_type=SceneType.ACTION,
            mood=MoodType.EXCITING,
            duration_frames=48,
            elements=[]
        )
        scene_to = SceneDefinition(
            scene_id="s2",
            prompt="Villain reacts",
            scene_type=SceneType.REACTION,
            mood=MoodType.TENSE,
            duration_frames=48,
            elements=[]
        )

        transition, duration = self.planner.plan_transition(scene_from, scene_to)

        assert transition == TransitionType.CUT
        assert duration == 0  # Cuts have no duration

    def test_establishing_to_action_transition(self):
        """Test transition from establishing to action."""
        scene_from = SceneDefinition(
            scene_id="s1",
            prompt="City overview",
            scene_type=SceneType.ESTABLISHING,
            mood=MoodType.NEUTRAL,
            duration_frames=48,
            elements=[]
        )
        scene_to = SceneDefinition(
            scene_id="s2",
            prompt="Chase begins",
            scene_type=SceneType.ACTION,
            mood=MoodType.EXCITING,
            duration_frames=48,
            elements=[]
        )

        transition, duration = self.planner.plan_transition(scene_from, scene_to)

        assert transition == TransitionType.CROSSFADE
        assert duration > 0

    def test_mysterious_mood_transition(self):
        """Test transition with mysterious mood."""
        scene_from = SceneDefinition(
            scene_id="s1",
            prompt="Scene one",
            scene_type=SceneType.ACTION,
            mood=MoodType.NEUTRAL,
            duration_frames=48,
            elements=[]
        )
        scene_to = SceneDefinition(
            scene_id="s2",
            prompt="Mysterious reveal",
            scene_type=SceneType.ACTION,
            mood=MoodType.MYSTERIOUS,
            duration_frames=48,
            elements=[]
        )

        transition, duration = self.planner.plan_transition(scene_from, scene_to)

        assert transition == TransitionType.FADE_BLACK


class TestConsistencyManager:
    """Tests for ConsistencyManager class."""

    def setup_method(self):
        self.manager = ConsistencyManager()

    def test_register_character(self):
        """Test character registration."""
        self.manager.register_character("Hero", "A brave warrior with a sword")

        embedding = self.manager.get_character_embedding("Hero")
        assert embedding is not None
        assert len(embedding) == 512

    def test_register_style(self):
        """Test style registration."""
        self.manager.register_style("cinematic")

        embedding = self.manager.get_style_embedding("cinematic")
        assert embedding is not None

    def test_embedding_consistency(self):
        """Test that embeddings are consistent."""
        self.manager.register_character("Test", "Test description")

        emb1 = self.manager.get_character_embedding("Test")
        emb2 = self.manager.get_character_embedding("Test")

        assert np.allclose(emb1, emb2)

    def test_consistency_score(self):
        """Test consistency score computation."""
        embeddings = [
            self.manager._generate_deterministic_embedding("test1"),
            self.manager._generate_deterministic_embedding("test1"),  # Same
            self.manager._generate_deterministic_embedding("test2"),  # Different
        ]

        score = self.manager.compute_consistency_score(embeddings)
        assert 0 <= score <= 1


class TestSceneOrchestrator:
    """Tests for SceneOrchestrator class."""

    def setup_method(self):
        self.orchestrator = SceneOrchestrator()

    @pytest.mark.asyncio
    async def test_breakdown_simple_prompt(self):
        """Test breaking down a simple prompt."""
        breakdown = await self.orchestrator.breakdown_prompt(
            "A person walking in the park"
        )

        assert isinstance(breakdown, SceneBreakdown)
        assert len(breakdown.timeline.scenes) >= 1
        assert breakdown.timeline.total_frames > 0

    @pytest.mark.asyncio
    async def test_breakdown_complex_prompt(self):
        """Test breaking down a complex multi-scene prompt."""
        prompt = """
        A hero stands on a cliff overlooking the city.
        Then the camera zooms in on their face.
        Cut to the villain in their lair.
        The hero leaps into action.
        """
        breakdown = await self.orchestrator.breakdown_prompt(prompt)

        assert len(breakdown.timeline.scenes) >= 3
        assert len(breakdown.suggested_transitions) == len(breakdown.timeline.scenes) - 1

    @pytest.mark.asyncio
    async def test_breakdown_with_duration(self):
        """Test breakdown with specified duration."""
        breakdown = await self.orchestrator.breakdown_prompt(
            "Scene one. Then scene two.",
            total_duration_seconds=10.0
        )

        # Duration should be close to 10 seconds
        assert abs(breakdown.timeline.duration_seconds - 10.0) < 1.0

    @pytest.mark.asyncio
    async def test_breakdown_with_beat_sync(self):
        """Test breakdown with beat synchronization."""
        beat_times = [0.0, 0.5, 1.0, 1.5, 2.0]
        breakdown = await self.orchestrator.breakdown_prompt(
            "Scene one. Then scene two.",
            beat_times=beat_times
        )

        # At least some scenes should be beat-aligned
        assert any(s.beat_aligned for s in breakdown.timeline.scenes)

    @pytest.mark.asyncio
    async def test_character_detection(self):
        """Test character detection in prompts."""
        breakdown = await self.orchestrator.breakdown_prompt(
            "John walks towards Mary. Then they both look at Peter."
        )

        assert len(breakdown.detected_characters) >= 2

    def test_timeline_summary(self):
        """Test timeline summary generation."""
        scenes = [
            SceneDefinition(
                scene_id="s1",
                prompt="Test",
                scene_type=SceneType.ACTION,
                mood=MoodType.NEUTRAL,
                duration_frames=48,
                elements=[]
            )
        ]
        breakdown = SceneBreakdown(
            timeline=Timeline(scenes=scenes, total_frames=48),
            raw_segments=["Test"],
            detected_characters=[],
            detected_locations=[],
            suggested_transitions=[],
            consistency_hints={}
        )

        summary = self.orchestrator.get_timeline_summary(breakdown)

        assert summary['total_scenes'] == 1
        assert summary['total_frames'] == 48
        assert 'scenes' in summary


class TestGlobalSceneOrchestrator:
    """Tests for global scene orchestrator."""

    def test_get_scene_orchestrator_singleton(self):
        """Test singleton pattern."""
        orch1 = get_scene_orchestrator()
        orch2 = get_scene_orchestrator()
        assert orch1 is orch2

    @pytest.mark.asyncio
    async def test_breakdown_complex_prompt_convenience(self):
        """Test convenience function."""
        breakdown = await breakdown_complex_prompt("A simple scene")
        assert isinstance(breakdown, SceneBreakdown)
