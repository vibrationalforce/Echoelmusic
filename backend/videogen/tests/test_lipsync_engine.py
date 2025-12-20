"""
Tests for Lip-Sync Engine - Super Genius AI Feature #5
"""

import pytest
import numpy as np

from ..layer3_genius.lipsync_engine import (
    Viseme,
    Expression,
    Phoneme,
    VisemeKeyframe,
    LipSyncTrack,
    AudioAnalysis,
    AudioAnalyzer,
    VisemeGenerator,
    LipSyncConfig,
    LipSyncEngine,
    get_lipsync_engine,
    generate_lipsync_from_audio,
    PHONEME_TO_VISEME,
)


class TestViseme:
    """Tests for Viseme enum."""

    def test_all_visemes_defined(self):
        """Test all required visemes are defined."""
        required = ['NEUTRAL', 'PP', 'FF', 'AA', 'EE', 'OO', 'SILENCE']
        for viseme in required:
            assert hasattr(Viseme, viseme)


class TestPhoneme:
    """Tests for Phoneme class."""

    def test_phoneme_creation(self):
        """Test creating a phoneme."""
        phoneme = Phoneme(
            phoneme='AA',
            start_time=0.0,
            end_time=0.1,
            confidence=0.95
        )

        assert phoneme.phoneme == 'AA'
        assert phoneme.duration == 0.1

    def test_phoneme_duration(self):
        """Test phoneme duration calculation."""
        phoneme = Phoneme('test', 1.0, 2.5)
        assert phoneme.duration == 1.5


class TestVisemeKeyframe:
    """Tests for VisemeKeyframe class."""

    def test_keyframe_creation(self):
        """Test creating a keyframe."""
        kf = VisemeKeyframe(
            viseme=Viseme.AA,
            time=0.5,
            intensity=0.8,
            expression=Expression.HAPPY,
            expression_intensity=0.6
        )

        assert kf.viseme == Viseme.AA
        assert kf.time == 0.5
        assert kf.intensity == 0.8


class TestLipSyncTrack:
    """Tests for LipSyncTrack class."""

    def test_track_creation(self):
        """Test creating a track."""
        keyframes = [
            VisemeKeyframe(Viseme.NEUTRAL, 0.0, 0.0),
            VisemeKeyframe(Viseme.AA, 0.5, 1.0),
            VisemeKeyframe(Viseme.NEUTRAL, 1.0, 0.0),
        ]
        track = LipSyncTrack(keyframes=keyframes, duration=1.0, fps=24)

        assert len(track.keyframes) == 3
        assert track.duration == 1.0

    def test_get_keyframe_at(self):
        """Test getting interpolated keyframe."""
        keyframes = [
            VisemeKeyframe(Viseme.NEUTRAL, 0.0, 0.0),
            VisemeKeyframe(Viseme.AA, 1.0, 1.0),
        ]
        track = LipSyncTrack(keyframes=keyframes, duration=1.0)

        # At midpoint
        kf = track.get_keyframe_at(0.5)
        assert kf.intensity == pytest.approx(0.5, rel=0.2)

    def test_to_frame_keyframes(self):
        """Test conversion to per-frame keyframes."""
        keyframes = [
            VisemeKeyframe(Viseme.NEUTRAL, 0.0, 0.0),
            VisemeKeyframe(Viseme.AA, 1.0, 1.0),
        ]
        track = LipSyncTrack(keyframes=keyframes, duration=1.0, fps=24)

        frames = track.to_frame_keyframes()
        assert len(frames) == 24


class TestAudioAnalyzer:
    """Tests for AudioAnalyzer class."""

    def setup_method(self):
        self.analyzer = AudioAnalyzer(sample_rate=16000)

    def test_analyze_silent_audio(self):
        """Test analyzing silent audio."""
        audio = np.zeros(16000)  # 1 second of silence

        analysis = self.analyzer.analyze(audio)

        assert isinstance(analysis, AudioAnalysis)
        assert analysis.duration == 1.0
        assert not analysis.has_speech

    def test_analyze_with_speech(self):
        """Test analyzing audio with simulated speech."""
        # Generate audio with varying amplitude
        t = np.linspace(0, 1, 16000)
        audio = np.sin(2 * np.pi * 440 * t) * np.abs(np.sin(2 * np.pi * 2 * t))

        analysis = self.analyzer.analyze(audio)

        assert analysis.duration == 1.0
        assert len(analysis.phonemes) > 0

    def test_energy_envelope(self):
        """Test energy envelope computation."""
        audio = np.random.randn(16000) * 0.1

        analysis = self.analyzer.analyze(audio)

        assert analysis.energy_envelope is not None
        assert len(analysis.energy_envelope) > 0


class TestVisemeGenerator:
    """Tests for VisemeGenerator class."""

    def setup_method(self):
        self.generator = VisemeGenerator(smoothing=0.3)

    def test_generate_from_analysis(self):
        """Test generating visemes from analysis."""
        phonemes = [
            Phoneme('AA', 0.0, 0.2, 1.0),
            Phoneme('', 0.2, 0.3, 1.0),
            Phoneme('EE', 0.3, 0.5, 1.0),
        ]
        analysis = AudioAnalysis(
            phonemes=phonemes,
            duration=0.5,
            sample_rate=16000,
            has_speech=True
        )

        track = self.generator.generate(analysis)

        assert isinstance(track, LipSyncTrack)
        assert track.duration == 0.5
        assert len(track.keyframes) >= 3


class TestPhonemeToVisemeMapping:
    """Tests for phoneme to viseme mapping."""

    def test_bilabial_mapping(self):
        """Test bilabial phoneme mapping."""
        assert PHONEME_TO_VISEME['P'] == Viseme.PP
        assert PHONEME_TO_VISEME['B'] == Viseme.PP
        assert PHONEME_TO_VISEME['M'] == Viseme.PP

    def test_labiodental_mapping(self):
        """Test labiodental phoneme mapping."""
        assert PHONEME_TO_VISEME['F'] == Viseme.FF
        assert PHONEME_TO_VISEME['V'] == Viseme.FF

    def test_vowel_mapping(self):
        """Test vowel phoneme mapping."""
        assert PHONEME_TO_VISEME['AA'] == Viseme.AA
        assert PHONEME_TO_VISEME['EE'] == Viseme.EE
        assert PHONEME_TO_VISEME['OO'] == Viseme.OO


class TestLipSyncEngine:
    """Tests for LipSyncEngine class."""

    def setup_method(self):
        self.engine = LipSyncEngine()

    @pytest.mark.asyncio
    async def test_generate_lipsync(self):
        """Test generating lip sync from audio."""
        # Generate test audio
        t = np.linspace(0, 1, 16000)
        audio = np.sin(2 * np.pi * 440 * t) * 0.5

        track = await self.engine.generate_lipsync(audio)

        assert isinstance(track, LipSyncTrack)
        assert track.duration > 0

    @pytest.mark.asyncio
    async def test_generate_lipsync_with_expression(self):
        """Test generating with specific expression."""
        audio = np.random.randn(16000) * 0.3

        track = await self.engine.generate_lipsync(
            audio,
            expression=Expression.HAPPY
        )

        # All keyframes should have HAPPY expression
        for kf in track.keyframes:
            assert kf.expression == Expression.HAPPY

    def test_apply_to_video(self):
        """Test applying lip sync to video frames."""
        frames = np.random.randint(0, 255, (24, 480, 640, 3), dtype=np.uint8)
        keyframes = [
            VisemeKeyframe(Viseme.NEUTRAL, 0.0, 0.0),
            VisemeKeyframe(Viseme.AA, 0.5, 1.0),
            VisemeKeyframe(Viseme.NEUTRAL, 1.0, 0.0),
        ]
        track = LipSyncTrack(keyframes=keyframes, duration=1.0, fps=24)

        result = self.engine.apply_to_video(
            frames,
            track,
            face_region=(200, 150, 240, 300)
        )

        assert result.shape == frames.shape

    def test_get_viseme_shapes(self):
        """Test getting viseme shape parameters."""
        shapes = self.engine.get_viseme_shapes()

        assert len(shapes) == len(Viseme)
        assert 'neutral' in shapes
        assert 'jaw_open' in shapes['neutral']


class TestGlobalLipSyncEngine:
    """Tests for global lip sync engine."""

    def test_get_lipsync_engine_singleton(self):
        """Test singleton pattern."""
        engine1 = get_lipsync_engine()
        engine2 = get_lipsync_engine()
        assert engine1 is engine2

    @pytest.mark.asyncio
    async def test_generate_lipsync_from_audio_convenience(self):
        """Test convenience function."""
        audio = np.random.randn(16000) * 0.3
        track = await generate_lipsync_from_audio(audio)
        assert isinstance(track, LipSyncTrack)
