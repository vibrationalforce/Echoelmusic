"""
Lip-Sync Engine - Super Genius AI Feature #5

Synchronizes character lip movements with audio input.
Enables realistic talking head generation and audio-driven animation.

Features:
- Audio-to-viseme conversion
- Phoneme extraction and timing
- Lip shape blending and interpolation
- Expression control
- Multi-speaker support
"""

import asyncio
import numpy as np
from dataclasses import dataclass, field
from enum import Enum
from typing import Dict, List, Optional, Tuple, Any, Callable
import logging
import hashlib

logger = logging.getLogger(__name__)


class Viseme(str, Enum):
    """
    Standard viseme set for lip shapes.
    Based on the MPEG-4 viseme set.
    """
    NEUTRAL = "neutral"      # Closed mouth, neutral
    PP = "pp"                # p, b, m - closed bilabial
    FF = "ff"                # f, v - labiodental
    TH = "th"                # th - dental fricative
    DD = "dd"                # t, d, n, l - alveolar
    KK = "kk"                # k, g - velar
    CH = "ch"                # ch, j, sh - postalveolar
    SS = "ss"                # s, z - alveolar fricative
    NN = "nn"                # n - nasal
    RR = "rr"                # r - approximant
    AA = "aa"                # a - open vowel
    EE = "ee"                # e, i - front vowel
    II = "ii"                # i - high front vowel
    OO = "oo"                # o - back rounded vowel
    UU = "uu"                # u - high back vowel
    SILENCE = "silence"      # No speech


class Expression(str, Enum):
    """Facial expressions to blend with lip sync."""
    NEUTRAL = "neutral"
    HAPPY = "happy"
    SAD = "sad"
    ANGRY = "angry"
    SURPRISED = "surprised"
    FOCUSED = "focused"


@dataclass
class Phoneme:
    """A single phoneme with timing information."""
    phoneme: str
    start_time: float  # seconds
    end_time: float    # seconds
    confidence: float = 1.0

    @property
    def duration(self) -> float:
        return self.end_time - self.start_time


@dataclass
class VisemeKeyframe:
    """A keyframe for lip animation."""
    viseme: Viseme
    time: float         # seconds
    intensity: float    # 0-1
    expression: Expression = Expression.NEUTRAL
    expression_intensity: float = 0.5


@dataclass
class LipSyncTrack:
    """Complete lip sync track for a video."""
    keyframes: List[VisemeKeyframe]
    duration: float
    fps: int = 24
    speaker_id: Optional[str] = None

    def get_keyframe_at(self, time: float) -> VisemeKeyframe:
        """Get interpolated keyframe at a specific time."""
        if not self.keyframes:
            return VisemeKeyframe(Viseme.NEUTRAL, time, 0.0)

        # Find surrounding keyframes
        prev_kf = self.keyframes[0]
        next_kf = self.keyframes[-1]

        for i, kf in enumerate(self.keyframes):
            if kf.time <= time:
                prev_kf = kf
            if kf.time > time:
                next_kf = kf
                break

        # Interpolate
        if prev_kf.time == next_kf.time:
            return prev_kf

        t = (time - prev_kf.time) / (next_kf.time - prev_kf.time)

        # Use smooth interpolation
        t = self._smooth_step(t)

        # Interpolate intensity
        intensity = prev_kf.intensity * (1 - t) + next_kf.intensity * t
        expr_intensity = prev_kf.expression_intensity * (1 - t) + next_kf.expression_intensity * t

        return VisemeKeyframe(
            viseme=next_kf.viseme if t > 0.5 else prev_kf.viseme,
            time=time,
            intensity=intensity,
            expression=next_kf.expression if t > 0.5 else prev_kf.expression,
            expression_intensity=expr_intensity
        )

    def _smooth_step(self, t: float) -> float:
        """Smooth step function for interpolation."""
        return t * t * (3 - 2 * t)

    def to_frame_keyframes(self) -> List[VisemeKeyframe]:
        """Convert to per-frame keyframes."""
        frame_duration = 1.0 / self.fps
        frames = []

        for i in range(int(self.duration * self.fps)):
            time = i * frame_duration
            frames.append(self.get_keyframe_at(time))

        return frames


@dataclass
class AudioAnalysis:
    """Results of audio analysis for lip sync."""
    phonemes: List[Phoneme]
    duration: float
    sample_rate: int
    has_speech: bool
    speaker_segments: List[Tuple[float, float, str]] = field(default_factory=list)
    energy_envelope: Optional[np.ndarray] = None


# Phoneme to viseme mapping
PHONEME_TO_VISEME: Dict[str, Viseme] = {
    # Bilabials
    'P': Viseme.PP, 'B': Viseme.PP, 'M': Viseme.PP,
    'p': Viseme.PP, 'b': Viseme.PP, 'm': Viseme.PP,

    # Labiodentals
    'F': Viseme.FF, 'V': Viseme.FF,
    'f': Viseme.FF, 'v': Viseme.FF,

    # Dental
    'TH': Viseme.TH, 'DH': Viseme.TH,
    'th': Viseme.TH, 'dh': Viseme.TH,

    # Alveolar
    'T': Viseme.DD, 'D': Viseme.DD, 'N': Viseme.DD, 'L': Viseme.DD,
    't': Viseme.DD, 'd': Viseme.DD, 'n': Viseme.DD, 'l': Viseme.DD,

    # Velar
    'K': Viseme.KK, 'G': Viseme.KK, 'NG': Viseme.KK,
    'k': Viseme.KK, 'g': Viseme.KK, 'ng': Viseme.KK,

    # Postalveolar
    'CH': Viseme.CH, 'JH': Viseme.CH, 'SH': Viseme.CH, 'ZH': Viseme.CH,
    'ch': Viseme.CH, 'jh': Viseme.CH, 'sh': Viseme.CH, 'zh': Viseme.CH,

    # Fricatives
    'S': Viseme.SS, 'Z': Viseme.SS,
    's': Viseme.SS, 'z': Viseme.SS,

    # Approximants
    'R': Viseme.RR, 'W': Viseme.OO, 'Y': Viseme.II,
    'r': Viseme.RR, 'w': Viseme.OO, 'y': Viseme.II,

    # Vowels
    'AA': Viseme.AA, 'AE': Viseme.AA, 'AH': Viseme.AA,
    'AO': Viseme.OO, 'AW': Viseme.AA, 'AY': Viseme.AA,
    'EH': Viseme.EE, 'ER': Viseme.RR, 'EY': Viseme.EE,
    'IH': Viseme.II, 'IY': Viseme.II,
    'OW': Viseme.OO, 'OY': Viseme.OO,
    'UH': Viseme.UU, 'UW': Viseme.UU,

    # Lowercase vowels
    'aa': Viseme.AA, 'ae': Viseme.AA, 'ah': Viseme.AA,
    'ao': Viseme.OO, 'aw': Viseme.AA, 'ay': Viseme.AA,
    'eh': Viseme.EE, 'er': Viseme.RR, 'ey': Viseme.EE,
    'ih': Viseme.II, 'iy': Viseme.II,
    'ow': Viseme.OO, 'oy': Viseme.OO,
    'uh': Viseme.UU, 'uw': Viseme.UU,

    # Silence
    'sil': Viseme.SILENCE, 'sp': Viseme.SILENCE, '': Viseme.SILENCE
}


class AudioAnalyzer:
    """Analyzes audio for lip sync generation."""

    def __init__(self, sample_rate: int = 16000):
        self.sample_rate = sample_rate
        self._asr_model = None  # Lazy load

    def analyze(self, audio: np.ndarray) -> AudioAnalysis:
        """
        Analyze audio and extract phonemes.

        Args:
            audio: Audio waveform as numpy array

        Returns:
            AudioAnalysis with phonemes and timing
        """
        # Ensure correct sample rate (resample if needed)
        if len(audio.shape) > 1:
            audio = audio.mean(axis=1)  # Convert to mono

        duration = len(audio) / self.sample_rate

        # Try to use ASR for phoneme extraction
        phonemes = self._extract_phonemes_fallback(audio, duration)

        # Calculate energy envelope
        energy = self._compute_energy_envelope(audio)

        # Detect speech presence
        has_speech = np.max(energy) > 0.01

        return AudioAnalysis(
            phonemes=phonemes,
            duration=duration,
            sample_rate=self.sample_rate,
            has_speech=has_speech,
            energy_envelope=energy
        )

    def _extract_phonemes_fallback(
        self,
        audio: np.ndarray,
        duration: float
    ) -> List[Phoneme]:
        """
        Fallback phoneme extraction using energy-based approach.

        This generates approximate phonemes based on audio energy.
        For production use, integrate with Whisper or other ASR.
        """
        phonemes = []

        # Compute short-time energy
        frame_size = int(0.025 * self.sample_rate)  # 25ms frames
        hop_size = int(0.010 * self.sample_rate)    # 10ms hop

        if len(audio) < frame_size:
            return phonemes

        num_frames = (len(audio) - frame_size) // hop_size + 1

        for i in range(num_frames):
            start_sample = i * hop_size
            end_sample = start_sample + frame_size
            frame = audio[start_sample:end_sample]

            energy = np.sqrt(np.mean(frame ** 2))

            start_time = start_sample / self.sample_rate
            end_time = end_sample / self.sample_rate

            # Classify based on energy
            if energy < 0.01:
                # Silence
                phoneme = ''
            elif energy < 0.05:
                # Low energy - likely consonant
                phoneme = 's'  # Fricative approximation
            elif energy < 0.15:
                # Medium energy
                phoneme = 'eh'
            else:
                # High energy - open vowel
                phoneme = 'aa'

            phonemes.append(Phoneme(
                phoneme=phoneme,
                start_time=start_time,
                end_time=end_time,
                confidence=0.5
            ))

        # Merge consecutive same phonemes
        merged = []
        for p in phonemes:
            if merged and merged[-1].phoneme == p.phoneme:
                merged[-1] = Phoneme(
                    phoneme=p.phoneme,
                    start_time=merged[-1].start_time,
                    end_time=p.end_time,
                    confidence=(merged[-1].confidence + p.confidence) / 2
                )
            else:
                merged.append(p)

        return merged

    def _compute_energy_envelope(
        self,
        audio: np.ndarray,
        frame_ms: int = 10
    ) -> np.ndarray:
        """Compute energy envelope of audio."""
        frame_size = int(frame_ms * self.sample_rate / 1000)
        num_frames = len(audio) // frame_size

        energy = np.zeros(num_frames)
        for i in range(num_frames):
            frame = audio[i * frame_size:(i + 1) * frame_size]
            energy[i] = np.sqrt(np.mean(frame ** 2))

        # Normalize
        max_energy = np.max(energy)
        if max_energy > 0:
            energy = energy / max_energy

        return energy


class VisemeGenerator:
    """Generates viseme sequences from phonemes."""

    def __init__(self, smoothing: float = 0.3):
        self.smoothing = smoothing

    def generate(
        self,
        analysis: AudioAnalysis,
        fps: int = 24,
        expression: Expression = Expression.NEUTRAL
    ) -> LipSyncTrack:
        """
        Generate a lip sync track from audio analysis.

        Args:
            analysis: Audio analysis with phonemes
            fps: Frame rate for output
            expression: Base expression

        Returns:
            LipSyncTrack with keyframes
        """
        keyframes = []

        # Add initial neutral
        keyframes.append(VisemeKeyframe(
            viseme=Viseme.NEUTRAL,
            time=0.0,
            intensity=0.0,
            expression=expression,
            expression_intensity=0.3
        ))

        # Convert phonemes to visemes
        for phoneme in analysis.phonemes:
            viseme = PHONEME_TO_VISEME.get(phoneme.phoneme, Viseme.NEUTRAL)

            # Calculate intensity based on phoneme type and energy
            if viseme == Viseme.SILENCE:
                intensity = 0.0
            else:
                intensity = min(1.0, phoneme.confidence * 1.2)

            # Add keyframe at phoneme start
            keyframes.append(VisemeKeyframe(
                viseme=viseme,
                time=phoneme.start_time,
                intensity=intensity,
                expression=expression,
                expression_intensity=0.5 if intensity > 0.5 else 0.3
            ))

        # Add final neutral
        keyframes.append(VisemeKeyframe(
            viseme=Viseme.NEUTRAL,
            time=analysis.duration,
            intensity=0.0,
            expression=expression,
            expression_intensity=0.3
        ))

        # Apply smoothing
        keyframes = self._smooth_keyframes(keyframes)

        return LipSyncTrack(
            keyframes=keyframes,
            duration=analysis.duration,
            fps=fps
        )

    def _smooth_keyframes(
        self,
        keyframes: List[VisemeKeyframe]
    ) -> List[VisemeKeyframe]:
        """Apply smoothing to keyframe sequence."""
        if len(keyframes) < 3:
            return keyframes

        smoothed = [keyframes[0]]

        for i in range(1, len(keyframes) - 1):
            prev_kf = keyframes[i - 1]
            curr_kf = keyframes[i]
            next_kf = keyframes[i + 1]

            # Smooth intensity
            smoothed_intensity = (
                prev_kf.intensity * self.smoothing +
                curr_kf.intensity * (1 - 2 * self.smoothing) +
                next_kf.intensity * self.smoothing
            )

            smoothed.append(VisemeKeyframe(
                viseme=curr_kf.viseme,
                time=curr_kf.time,
                intensity=smoothed_intensity,
                expression=curr_kf.expression,
                expression_intensity=curr_kf.expression_intensity
            ))

        smoothed.append(keyframes[-1])
        return smoothed


@dataclass
class LipSyncConfig:
    """Configuration for lip sync generation."""
    sample_rate: int = 16000
    fps: int = 24
    smoothing: float = 0.3
    expression: Expression = Expression.NEUTRAL
    blend_strength: float = 1.0


class LipSyncEngine:
    """
    Main lip sync engine for audio-driven lip animation.

    Features:
    - Audio analysis and phoneme extraction
    - Viseme generation with smoothing
    - Expression blending
    - Multi-speaker support
    """

    def __init__(self, config: Optional[LipSyncConfig] = None):
        self.config = config or LipSyncConfig()
        self.analyzer = AudioAnalyzer(self.config.sample_rate)
        self.viseme_generator = VisemeGenerator(self.config.smoothing)

        logger.info("LipSyncEngine initialized")

    async def generate_lipsync(
        self,
        audio: np.ndarray,
        expression: Optional[Expression] = None
    ) -> LipSyncTrack:
        """
        Generate lip sync track from audio.

        Args:
            audio: Audio waveform
            expression: Optional expression override

        Returns:
            LipSyncTrack with keyframes
        """
        # Analyze audio
        analysis = self.analyzer.analyze(audio)

        if not analysis.has_speech:
            logger.warning("No speech detected in audio")
            return self._generate_silent_track(analysis.duration)

        # Generate visemes
        track = self.viseme_generator.generate(
            analysis,
            fps=self.config.fps,
            expression=expression or self.config.expression
        )

        logger.info(
            f"Generated lip sync track: {len(track.keyframes)} keyframes, "
            f"{track.duration:.2f}s duration"
        )

        return track

    def _generate_silent_track(self, duration: float) -> LipSyncTrack:
        """Generate a silent (neutral) lip sync track."""
        return LipSyncTrack(
            keyframes=[
                VisemeKeyframe(Viseme.NEUTRAL, 0.0, 0.0),
                VisemeKeyframe(Viseme.NEUTRAL, duration, 0.0)
            ],
            duration=duration,
            fps=self.config.fps
        )

    def apply_to_video(
        self,
        video_frames: np.ndarray,
        track: LipSyncTrack,
        face_region: Optional[Tuple[int, int, int, int]] = None
    ) -> np.ndarray:
        """
        Apply lip sync to video frames.

        This is a placeholder for actual lip deformation.
        In production, integrate with a face manipulation model.

        Args:
            video_frames: Video frames [T, H, W, C]
            track: Lip sync track
            face_region: Optional face bounding box (x, y, w, h)

        Returns:
            Modified video frames
        """
        # Get per-frame keyframes
        frame_keyframes = track.to_frame_keyframes()

        # Ensure we have enough keyframes
        num_frames = video_frames.shape[0]
        if len(frame_keyframes) < num_frames:
            # Extend with last keyframe
            while len(frame_keyframes) < num_frames:
                frame_keyframes.append(frame_keyframes[-1])

        modified_frames = video_frames.copy()

        for i in range(num_frames):
            kf = frame_keyframes[i]

            if kf.intensity > 0.1 and face_region is not None:
                # Apply subtle modification based on viseme
                # This is a placeholder - real implementation would use
                # a face manipulation network
                modified_frames[i] = self._apply_viseme_effect(
                    modified_frames[i],
                    kf,
                    face_region
                )

        return modified_frames

    def _apply_viseme_effect(
        self,
        frame: np.ndarray,
        keyframe: VisemeKeyframe,
        face_region: Tuple[int, int, int, int]
    ) -> np.ndarray:
        """Apply viseme effect to a single frame."""
        # Placeholder implementation
        # In production, this would use a neural network for face manipulation

        x, y, w, h = face_region

        # Mouth region (lower third of face)
        mouth_y = y + int(h * 0.6)
        mouth_h = int(h * 0.3)

        # Subtle brightness modulation based on mouth openness
        openness = self._get_mouth_openness(keyframe.viseme)
        if openness > 0:
            mouth_region = frame[mouth_y:mouth_y + mouth_h, x:x + w]
            modulation = 1.0 + (openness * keyframe.intensity * 0.1)
            frame[mouth_y:mouth_y + mouth_h, x:x + w] = np.clip(
                mouth_region * modulation, 0, 255
            ).astype(np.uint8)

        return frame

    def _get_mouth_openness(self, viseme: Viseme) -> float:
        """Get mouth openness for a viseme (0=closed, 1=open)."""
        openness_map = {
            Viseme.NEUTRAL: 0.0,
            Viseme.SILENCE: 0.0,
            Viseme.PP: 0.0,
            Viseme.FF: 0.1,
            Viseme.TH: 0.2,
            Viseme.DD: 0.3,
            Viseme.KK: 0.3,
            Viseme.CH: 0.4,
            Viseme.SS: 0.2,
            Viseme.NN: 0.2,
            Viseme.RR: 0.3,
            Viseme.EE: 0.4,
            Viseme.II: 0.3,
            Viseme.OO: 0.5,
            Viseme.UU: 0.4,
            Viseme.AA: 0.8,
        }
        return openness_map.get(viseme, 0.3)

    def get_viseme_shapes(self) -> Dict[str, Dict[str, float]]:
        """
        Get viseme shape parameters for external use.

        Returns morph target weights for each viseme.
        """
        shapes = {}
        for viseme in Viseme:
            shapes[viseme.value] = {
                'jaw_open': self._get_mouth_openness(viseme),
                'mouth_stretch': 0.5 if viseme in [Viseme.EE, Viseme.II] else 0.0,
                'mouth_pucker': 0.5 if viseme in [Viseme.OO, Viseme.UU] else 0.0,
                'lip_press': 1.0 if viseme == Viseme.PP else 0.0,
                'lip_bite': 1.0 if viseme == Viseme.FF else 0.0,
            }
        return shapes


# Singleton instance
_engine: Optional[LipSyncEngine] = None


def get_lipsync_engine() -> LipSyncEngine:
    """Get the global lip sync engine instance."""
    global _engine
    if _engine is None:
        _engine = LipSyncEngine()
    return _engine


async def generate_lipsync_from_audio(
    audio: np.ndarray,
    **kwargs
) -> LipSyncTrack:
    """Convenience function to generate lip sync from audio."""
    engine = get_lipsync_engine()
    return await engine.generate_lipsync(audio, **kwargs)
