"""
Multi-Shot Scene Orchestrator - Super Genius AI Feature #2

Breaks long-form prompts into coherent multi-shot scenes with:
- Automatic scene detection and splitting
- Character/style consistency across shots
- Smooth transitions between scenes
- Timeline-based editing
- Beat-synchronized scene changes

This enables creation of longer, more complex videos with
narrative structure and cinematic transitions.
"""

import re
import asyncio
import hashlib
from dataclasses import dataclass, field
from enum import Enum
from typing import Dict, List, Optional, Tuple, Any, Union
from datetime import timedelta
import logging
import numpy as np

logger = logging.getLogger(__name__)


class TransitionType(str, Enum):
    """Types of transitions between scenes."""
    CUT = "cut"                    # Hard cut
    CROSSFADE = "crossfade"        # Smooth blend
    FADE_BLACK = "fade_black"      # Fade through black
    FADE_WHITE = "fade_white"      # Fade through white
    WIPE_LEFT = "wipe_left"        # Wipe transition
    WIPE_RIGHT = "wipe_right"
    ZOOM_IN = "zoom_in"            # Zoom transition
    ZOOM_OUT = "zoom_out"
    DISSOLVE = "dissolve"          # Soft dissolve
    MORPH = "morph"                # AI-powered morph


class SceneType(str, Enum):
    """Classification of scene types."""
    ESTABLISHING = "establishing"   # Wide shot, sets location
    ACTION = "action"              # Main action
    REACTION = "reaction"          # Character reaction
    TRANSITION = "transition"      # Transitional scene
    CLOSEUP = "closeup"            # Character closeup
    MONTAGE = "montage"            # Quick sequence
    FINALE = "finale"              # Climactic scene


class MoodType(str, Enum):
    """Mood/atmosphere of a scene."""
    NEUTRAL = "neutral"
    HAPPY = "happy"
    SAD = "sad"
    TENSE = "tense"
    EXCITING = "exciting"
    CALM = "calm"
    MYSTERIOUS = "mysterious"
    ROMANTIC = "romantic"


@dataclass
class SceneElement:
    """An individual element within a scene."""
    element_type: str  # character, object, location, effect
    name: str
    description: str
    importance: float = 0.5  # 0-1 importance for consistency
    position: Optional[Tuple[float, float]] = None  # normalized x,y


@dataclass
class SceneDefinition:
    """Complete definition of a single scene."""
    scene_id: str
    prompt: str
    scene_type: SceneType
    mood: MoodType
    duration_frames: int
    elements: List[SceneElement]

    # Transition settings
    transition_in: TransitionType = TransitionType.CUT
    transition_out: TransitionType = TransitionType.CUT
    transition_duration_frames: int = 12

    # Camera settings
    camera_movement: Optional[str] = None
    focal_point: Optional[Tuple[float, float]] = None

    # Style consistency
    style_embedding: Optional[np.ndarray] = None
    character_embeddings: Dict[str, np.ndarray] = field(default_factory=dict)

    # Audio sync
    beat_aligned: bool = False
    audio_cue: Optional[str] = None

    # Generation overrides
    guidance_scale: Optional[float] = None
    seed: Optional[int] = None


@dataclass
class Timeline:
    """Complete video timeline with multiple scenes."""
    scenes: List[SceneDefinition]
    total_frames: int
    fps: int = 24
    width: int = 1280
    height: int = 720

    # Global settings
    global_style: Optional[str] = None
    global_characters: Dict[str, SceneElement] = field(default_factory=dict)

    @property
    def duration_seconds(self) -> float:
        return self.total_frames / self.fps

    def get_scene_at_frame(self, frame: int) -> Optional[SceneDefinition]:
        """Get the scene at a specific frame number."""
        current_frame = 0
        for scene in self.scenes:
            if current_frame <= frame < current_frame + scene.duration_frames:
                return scene
            current_frame += scene.duration_frames
        return None


@dataclass
class SceneBreakdown:
    """Result of breaking down a complex prompt into scenes."""
    timeline: Timeline
    raw_segments: List[str]
    detected_characters: List[str]
    detected_locations: List[str]
    suggested_transitions: List[TransitionType]
    consistency_hints: Dict[str, str]


class PromptSceneParser:
    """Parses complex prompts into individual scenes."""

    # Markers that indicate scene breaks
    SCENE_MARKERS = [
        r'\bthen\b',
        r'\bafter that\b',
        r'\bnext\b',
        r'\bfollowed by\b',
        r'\bcut to\b',
        r'\bscene:\s*',
        r'\bshot:\s*',
        r'\b--\b',
        r'\|\|',
        r'\n\n+',
    ]

    # Camera movement keywords
    CAMERA_KEYWORDS = {
        "pan left": "pan_left",
        "pan right": "pan_right",
        "tilt up": "tilt_up",
        "tilt down": "tilt_down",
        "zoom in": "zoom_in",
        "zoom out": "zoom_out",
        "dolly": "dolly",
        "tracking shot": "tracking",
        "crane shot": "crane",
        "steadicam": "steadicam",
        "handheld": "handheld",
        "static": "static"
    }

    # Mood keywords
    MOOD_KEYWORDS = {
        MoodType.HAPPY: ["happy", "joyful", "bright", "cheerful", "sunny"],
        MoodType.SAD: ["sad", "melancholy", "dark", "somber", "lonely"],
        MoodType.TENSE: ["tense", "suspenseful", "thriller", "dangerous"],
        MoodType.EXCITING: ["exciting", "action", "dynamic", "energetic"],
        MoodType.CALM: ["calm", "peaceful", "serene", "quiet", "still"],
        MoodType.MYSTERIOUS: ["mysterious", "foggy", "unknown", "enigmatic"],
        MoodType.ROMANTIC: ["romantic", "love", "intimate", "tender"]
    }

    # Scene type keywords
    SCENE_KEYWORDS = {
        SceneType.ESTABLISHING: ["wide shot", "establishing", "landscape", "overview"],
        SceneType.ACTION: ["action", "running", "fighting", "chase"],
        SceneType.REACTION: ["reaction", "responds", "looks at", "surprised"],
        SceneType.CLOSEUP: ["closeup", "close-up", "face", "detail"],
        SceneType.MONTAGE: ["montage", "sequence", "rapid", "quick cuts"],
        SceneType.FINALE: ["finale", "climax", "ending", "final"]
    }

    def parse(
        self,
        prompt: str,
        default_scene_frames: int = 49,
        fps: int = 24
    ) -> List[Dict[str, Any]]:
        """Parse a complex prompt into scene segments."""
        # Combine all markers into one pattern
        combined_pattern = '|'.join(self.SCENE_MARKERS)

        # Split the prompt
        segments = re.split(combined_pattern, prompt, flags=re.IGNORECASE)
        segments = [s.strip() for s in segments if s.strip()]

        if not segments:
            segments = [prompt]

        scenes = []
        for i, segment in enumerate(segments):
            scene_info = self._analyze_segment(segment, i)
            scene_info['duration_frames'] = default_scene_frames
            scene_info['fps'] = fps
            scenes.append(scene_info)

        return scenes

    def _analyze_segment(self, segment: str, index: int) -> Dict[str, Any]:
        """Analyze a single segment for scene properties."""
        segment_lower = segment.lower()

        # Detect scene type
        scene_type = SceneType.ACTION  # default
        for stype, keywords in self.SCENE_KEYWORDS.items():
            if any(kw in segment_lower for kw in keywords):
                scene_type = stype
                break

        # If first scene, likely establishing
        if index == 0 and scene_type == SceneType.ACTION:
            scene_type = SceneType.ESTABLISHING

        # Detect mood
        mood = MoodType.NEUTRAL
        for mtype, keywords in self.MOOD_KEYWORDS.items():
            if any(kw in segment_lower for kw in keywords):
                mood = mtype
                break

        # Detect camera movement
        camera = None
        for keyword, movement in self.CAMERA_KEYWORDS.items():
            if keyword in segment_lower:
                camera = movement
                break

        # Extract potential character names (capitalized words)
        characters = re.findall(r'\b[A-Z][a-z]+\b', segment)
        characters = [c for c in characters if len(c) > 2]

        return {
            'prompt': segment,
            'scene_type': scene_type,
            'mood': mood,
            'camera_movement': camera,
            'characters': characters,
            'index': index
        }


class TransitionPlanner:
    """Plans transitions between scenes."""

    # Transition recommendations based on scene type pairs
    TRANSITION_MATRIX = {
        (SceneType.ESTABLISHING, SceneType.ACTION): TransitionType.CROSSFADE,
        (SceneType.ACTION, SceneType.REACTION): TransitionType.CUT,
        (SceneType.REACTION, SceneType.ACTION): TransitionType.CUT,
        (SceneType.ACTION, SceneType.CLOSEUP): TransitionType.CUT,
        (SceneType.CLOSEUP, SceneType.ACTION): TransitionType.CUT,
        (SceneType.ACTION, SceneType.TRANSITION): TransitionType.CROSSFADE,
        (SceneType.TRANSITION, SceneType.ACTION): TransitionType.CROSSFADE,
        (SceneType.MONTAGE, SceneType.MONTAGE): TransitionType.CUT,
        (SceneType.ACTION, SceneType.FINALE): TransitionType.DISSOLVE,
    }

    # Mood-based adjustments
    MOOD_TRANSITIONS = {
        MoodType.TENSE: TransitionType.CUT,
        MoodType.CALM: TransitionType.DISSOLVE,
        MoodType.MYSTERIOUS: TransitionType.FADE_BLACK,
        MoodType.ROMANTIC: TransitionType.CROSSFADE,
    }

    def plan_transition(
        self,
        scene_from: SceneDefinition,
        scene_to: SceneDefinition,
        beat_sync: bool = False
    ) -> Tuple[TransitionType, int]:
        """
        Plan the transition between two scenes.

        Returns:
            Tuple of (TransitionType, duration_frames)
        """
        # Check the transition matrix first
        key = (scene_from.scene_type, scene_to.scene_type)
        if key in self.TRANSITION_MATRIX:
            transition = self.TRANSITION_MATRIX[key]
        else:
            # Fall back to mood-based
            if scene_to.mood in self.MOOD_TRANSITIONS:
                transition = self.MOOD_TRANSITIONS[scene_to.mood]
            else:
                transition = TransitionType.CUT

        # Determine duration
        if transition == TransitionType.CUT:
            duration = 0
        elif transition in [TransitionType.CROSSFADE, TransitionType.DISSOLVE]:
            duration = 12
        elif transition in [TransitionType.FADE_BLACK, TransitionType.FADE_WHITE]:
            duration = 18
        else:
            duration = 8

        # Beat sync adjustments
        if beat_sync:
            # Snap to beat-aligned frame counts (assuming 24fps, 120bpm = 12 frames/beat)
            beat_frames = 12
            duration = round(duration / beat_frames) * beat_frames

        return transition, duration


class ConsistencyManager:
    """Manages character and style consistency across scenes."""

    def __init__(self):
        self.character_cache: Dict[str, np.ndarray] = {}
        self.style_cache: Dict[str, np.ndarray] = {}
        self.location_cache: Dict[str, np.ndarray] = {}

    def register_character(
        self,
        name: str,
        description: str,
        reference_embedding: Optional[np.ndarray] = None
    ):
        """Register a character for consistency tracking."""
        if reference_embedding is not None:
            self.character_cache[name] = reference_embedding
        else:
            # Generate deterministic embedding from description
            self.character_cache[name] = self._generate_deterministic_embedding(
                f"character:{name}:{description}"
            )

    def register_style(
        self,
        style_name: str,
        embedding: Optional[np.ndarray] = None
    ):
        """Register a style for consistency."""
        if embedding is not None:
            self.style_cache[style_name] = embedding
        else:
            self.style_cache[style_name] = self._generate_deterministic_embedding(
                f"style:{style_name}"
            )

    def get_character_embedding(self, name: str) -> Optional[np.ndarray]:
        """Get the embedding for a character."""
        return self.character_cache.get(name)

    def get_style_embedding(self, name: str) -> Optional[np.ndarray]:
        """Get the embedding for a style."""
        return self.style_cache.get(name)

    def _generate_deterministic_embedding(
        self,
        text: str,
        dim: int = 512
    ) -> np.ndarray:
        """Generate a deterministic embedding from text."""
        # Use hash for determinism
        hash_bytes = hashlib.sha256(text.encode()).digest()

        # Expand to full dimension
        embedding = np.zeros(dim, dtype=np.float32)
        for i in range(dim):
            byte_idx = i % len(hash_bytes)
            embedding[i] = (hash_bytes[byte_idx] / 255.0) * 2 - 1

        # Normalize
        norm = np.linalg.norm(embedding)
        if norm > 0:
            embedding = embedding / norm

        return embedding

    def compute_consistency_score(
        self,
        scene_embeddings: List[np.ndarray]
    ) -> float:
        """Compute consistency score across scene embeddings."""
        if len(scene_embeddings) < 2:
            return 1.0

        # Compute pairwise cosine similarities
        similarities = []
        for i in range(len(scene_embeddings)):
            for j in range(i + 1, len(scene_embeddings)):
                sim = np.dot(scene_embeddings[i], scene_embeddings[j])
                similarities.append(sim)

        return float(np.mean(similarities))


class SceneOrchestrator:
    """
    Main orchestrator for multi-shot scene generation.

    Features:
    - Automatic scene breakdown from complex prompts
    - Transition planning
    - Character/style consistency
    - Timeline management
    - Beat-synchronized scene changes
    """

    def __init__(
        self,
        default_fps: int = 24,
        default_scene_duration: float = 2.0,  # seconds
        maintain_consistency: bool = True
    ):
        self.fps = default_fps
        self.default_scene_frames = int(default_scene_duration * default_fps)
        self.maintain_consistency = maintain_consistency

        self.parser = PromptSceneParser()
        self.transition_planner = TransitionPlanner()
        self.consistency_manager = ConsistencyManager()

        logger.info("SceneOrchestrator initialized")

    async def breakdown_prompt(
        self,
        prompt: str,
        total_duration_seconds: Optional[float] = None,
        width: int = 1280,
        height: int = 720,
        beat_times: Optional[List[float]] = None
    ) -> SceneBreakdown:
        """
        Break down a complex prompt into a multi-scene timeline.

        Args:
            prompt: The complex generation prompt
            total_duration_seconds: Optional total video duration
            width: Video width
            height: Video height
            beat_times: Optional list of beat times for sync

        Returns:
            SceneBreakdown with complete timeline
        """
        # Parse prompt into segments
        raw_scenes = self.parser.parse(prompt, self.default_scene_frames, self.fps)

        if not raw_scenes:
            # Single scene fallback
            raw_scenes = [{
                'prompt': prompt,
                'scene_type': SceneType.ACTION,
                'mood': MoodType.NEUTRAL,
                'camera_movement': None,
                'characters': [],
                'duration_frames': self.default_scene_frames,
                'index': 0
            }]

        # Collect all detected characters
        all_characters = set()
        for scene in raw_scenes:
            all_characters.update(scene.get('characters', []))

        # Register characters for consistency
        for char in all_characters:
            self.consistency_manager.register_character(char, f"Character named {char}")

        # Convert to SceneDefinitions
        scene_definitions = []
        for i, raw_scene in enumerate(raw_scenes):
            scene_id = f"scene_{i:03d}"

            # Create elements from characters
            elements = []
            for char in raw_scene.get('characters', []):
                elements.append(SceneElement(
                    element_type="character",
                    name=char,
                    description=f"Character {char}",
                    importance=0.9
                ))

            scene_def = SceneDefinition(
                scene_id=scene_id,
                prompt=raw_scene['prompt'],
                scene_type=raw_scene['scene_type'],
                mood=raw_scene['mood'],
                duration_frames=raw_scene['duration_frames'],
                elements=elements,
                camera_movement=raw_scene.get('camera_movement')
            )

            # Add character embeddings for consistency
            for char in raw_scene.get('characters', []):
                embedding = self.consistency_manager.get_character_embedding(char)
                if embedding is not None:
                    scene_def.character_embeddings[char] = embedding

            scene_definitions.append(scene_def)

        # Plan transitions
        suggested_transitions = []
        for i in range(len(scene_definitions) - 1):
            transition, duration = self.transition_planner.plan_transition(
                scene_definitions[i],
                scene_definitions[i + 1],
                beat_sync=beat_times is not None
            )
            scene_definitions[i].transition_out = transition
            scene_definitions[i + 1].transition_in = transition
            scene_definitions[i + 1].transition_duration_frames = duration
            suggested_transitions.append(transition)

        # Adjust durations if total duration specified
        if total_duration_seconds:
            total_frames = int(total_duration_seconds * self.fps)
            current_total = sum(s.duration_frames for s in scene_definitions)

            if current_total != total_frames:
                scale = total_frames / current_total
                for scene in scene_definitions:
                    scene.duration_frames = int(scene.duration_frames * scale)

        # Beat alignment
        if beat_times:
            scene_definitions = self._align_to_beats(scene_definitions, beat_times)

        # Calculate final total frames
        total_frames = sum(s.duration_frames for s in scene_definitions)

        # Create timeline
        timeline = Timeline(
            scenes=scene_definitions,
            total_frames=total_frames,
            fps=self.fps,
            width=width,
            height=height,
            global_style=None,
            global_characters={
                char: SceneElement("character", char, f"Character {char}")
                for char in all_characters
            }
        )

        # Build consistency hints
        consistency_hints = {}
        for char in all_characters:
            consistency_hints[char] = f"Maintain consistent appearance for {char}"

        return SceneBreakdown(
            timeline=timeline,
            raw_segments=[s['prompt'] for s in raw_scenes],
            detected_characters=list(all_characters),
            detected_locations=[],
            suggested_transitions=suggested_transitions,
            consistency_hints=consistency_hints
        )

    def _align_to_beats(
        self,
        scenes: List[SceneDefinition],
        beat_times: List[float]
    ) -> List[SceneDefinition]:
        """Align scene boundaries to beat times."""
        if not beat_times:
            return scenes

        # Convert beat times to frames
        beat_frames = [int(t * self.fps) for t in beat_times]

        # Assign scenes to beat boundaries
        current_frame = 0
        beat_idx = 0

        for i, scene in enumerate(scenes):
            # Find the next beat boundary that's close to where this scene should end
            target_end = current_frame + scene.duration_frames

            # Find closest beat
            while beat_idx < len(beat_frames) - 1:
                if beat_frames[beat_idx] >= target_end - 6:  # 6 frame tolerance
                    break
                beat_idx += 1

            if beat_idx < len(beat_frames):
                # Snap to beat
                new_duration = beat_frames[beat_idx] - current_frame
                if new_duration > 12:  # Minimum 12 frames
                    scene.duration_frames = new_duration
                    scene.beat_aligned = True

            current_frame += scene.duration_frames

        return scenes

    async def generate_timeline(
        self,
        breakdown: SceneBreakdown,
        generate_scene_fn: Any  # Callable for actual generation
    ) -> List[np.ndarray]:
        """
        Generate all scenes in a timeline.

        Args:
            breakdown: The scene breakdown
            generate_scene_fn: Async function to generate each scene

        Returns:
            List of generated frame arrays
        """
        all_frames = []
        previous_last_frame = None

        for i, scene in enumerate(breakdown.timeline.scenes):
            logger.info(f"Generating scene {i+1}/{len(breakdown.timeline.scenes)}: {scene.scene_id}")

            # Build generation config
            config = {
                'prompt': scene.prompt,
                'num_frames': scene.duration_frames,
                'width': breakdown.timeline.width,
                'height': breakdown.timeline.height,
                'camera_movement': scene.camera_movement,
            }

            if scene.guidance_scale:
                config['guidance_scale'] = scene.guidance_scale
            if scene.seed:
                config['seed'] = scene.seed

            # Add consistency embeddings
            if scene.character_embeddings:
                config['character_embeddings'] = scene.character_embeddings
            if scene.style_embedding is not None:
                config['style_embedding'] = scene.style_embedding

            # Generate scene
            try:
                frames = await generate_scene_fn(**config)

                # Apply transition from previous scene
                if previous_last_frame is not None and scene.transition_in != TransitionType.CUT:
                    frames = self._apply_transition_in(
                        previous_last_frame,
                        frames,
                        scene.transition_in,
                        scene.transition_duration_frames
                    )

                all_frames.extend(frames)

                # Store last frame for next transition
                if frames:
                    previous_last_frame = frames[-1]

            except Exception as e:
                logger.error(f"Failed to generate scene {scene.scene_id}: {e}")
                # Continue with placeholder frames
                placeholder = np.zeros(
                    (scene.duration_frames, breakdown.timeline.height, breakdown.timeline.width, 3),
                    dtype=np.uint8
                )
                all_frames.extend(list(placeholder))

        return all_frames

    def _apply_transition_in(
        self,
        previous_frame: np.ndarray,
        new_frames: List[np.ndarray],
        transition_type: TransitionType,
        duration_frames: int
    ) -> List[np.ndarray]:
        """Apply a transition to the beginning of a scene."""
        if duration_frames <= 0 or len(new_frames) < duration_frames:
            return new_frames

        result = list(new_frames)

        for i in range(min(duration_frames, len(result))):
            alpha = i / duration_frames  # 0 to 1

            if transition_type == TransitionType.CROSSFADE:
                result[i] = self._blend_frames(previous_frame, result[i], alpha)

            elif transition_type == TransitionType.FADE_BLACK:
                if alpha < 0.5:
                    # Fade previous to black
                    result[i] = self._blend_frames(
                        previous_frame,
                        np.zeros_like(previous_frame),
                        alpha * 2
                    )
                else:
                    # Fade black to new
                    result[i] = self._blend_frames(
                        np.zeros_like(result[i]),
                        result[i],
                        (alpha - 0.5) * 2
                    )

            elif transition_type == TransitionType.FADE_WHITE:
                white = np.ones_like(previous_frame) * 255
                if alpha < 0.5:
                    result[i] = self._blend_frames(previous_frame, white, alpha * 2)
                else:
                    result[i] = self._blend_frames(white, result[i], (alpha - 0.5) * 2)

            elif transition_type == TransitionType.DISSOLVE:
                # Softer blend with noise
                noise = np.random.random(result[i].shape) * 0.1
                blended = self._blend_frames(previous_frame, result[i], alpha)
                result[i] = np.clip(blended + noise * 255, 0, 255).astype(np.uint8)

            elif transition_type == TransitionType.WIPE_LEFT:
                cutoff = int(result[i].shape[1] * alpha)
                result[i][:, :cutoff] = result[i][:, :cutoff]
                result[i][:, cutoff:] = previous_frame[:, cutoff:]

            elif transition_type == TransitionType.WIPE_RIGHT:
                cutoff = int(result[i].shape[1] * (1 - alpha))
                result[i][:, cutoff:] = result[i][:, cutoff:]
                result[i][:, :cutoff] = previous_frame[:, :cutoff]

        return result

    def _blend_frames(
        self,
        frame1: np.ndarray,
        frame2: np.ndarray,
        alpha: float
    ) -> np.ndarray:
        """Blend two frames with alpha."""
        return ((1 - alpha) * frame1 + alpha * frame2).astype(np.uint8)

    def get_timeline_summary(self, breakdown: SceneBreakdown) -> Dict[str, Any]:
        """Get a summary of the timeline."""
        return {
            'total_scenes': len(breakdown.timeline.scenes),
            'total_frames': breakdown.timeline.total_frames,
            'duration_seconds': breakdown.timeline.duration_seconds,
            'fps': breakdown.timeline.fps,
            'resolution': f"{breakdown.timeline.width}x{breakdown.timeline.height}",
            'characters': breakdown.detected_characters,
            'transitions': [t.value for t in breakdown.suggested_transitions],
            'scenes': [
                {
                    'id': s.scene_id,
                    'type': s.scene_type.value,
                    'mood': s.mood.value,
                    'frames': s.duration_frames,
                    'duration': s.duration_frames / breakdown.timeline.fps
                }
                for s in breakdown.timeline.scenes
            ]
        }


# Singleton instance
_orchestrator: Optional[SceneOrchestrator] = None


def get_scene_orchestrator() -> SceneOrchestrator:
    """Get the global scene orchestrator instance."""
    global _orchestrator
    if _orchestrator is None:
        _orchestrator = SceneOrchestrator()
    return _orchestrator


async def breakdown_complex_prompt(
    prompt: str,
    **kwargs
) -> SceneBreakdown:
    """Convenience function to break down a complex prompt."""
    orchestrator = get_scene_orchestrator()
    return await orchestrator.breakdown_prompt(prompt, **kwargs)
