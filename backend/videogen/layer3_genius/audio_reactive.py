"""
Audio-Reactive Video Generation (S2V)
=====================================

Sound-to-Video generation with beat detection, spectrum analysis,
and audio-driven parameter modulation.

Inspired by Minimal Audio's modulation system and audio processing.

Features:
- Beat detection and tempo sync
- Spectrum analysis (bass, mids, highs)
- Envelope followers for dynamics
- Audio-to-video parameter mapping
- BPM-synced motion and cuts
"""

import numpy as np
import torch
from typing import Optional, Dict, Any, List, Tuple, Callable, Union
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
import logging

logger = logging.getLogger(__name__)


class AudioFeature(str, Enum):
    """Audio features for video modulation"""
    BEAT = "beat"
    TEMPO = "tempo"
    BASS = "bass"  # Low frequencies (20-250 Hz)
    MIDS = "mids"  # Mid frequencies (250-4000 Hz)
    HIGHS = "highs"  # High frequencies (4000-20000 Hz)
    ENERGY = "energy"  # Overall loudness
    ONSET = "onset"  # Transient detection
    PITCH = "pitch"  # Fundamental frequency
    SPECTRAL_CENTROID = "spectral_centroid"  # Brightness
    SPECTRAL_FLUX = "spectral_flux"  # Rate of spectral change


class VideoParameter(str, Enum):
    """Video parameters that can be modulated"""
    ZOOM = "zoom"
    PAN_X = "pan_x"
    PAN_Y = "pan_y"
    ROTATION = "rotation"
    BRIGHTNESS = "brightness"
    CONTRAST = "contrast"
    SATURATION = "saturation"
    HUE_SHIFT = "hue_shift"
    MOTION_SPEED = "motion_speed"
    BLUR = "blur"
    STYLE_MORPH = "style_morph"
    CUT_PROBABILITY = "cut_probability"


@dataclass
class ModulationRoute:
    """Maps an audio feature to a video parameter"""
    source: AudioFeature
    target: VideoParameter
    amount: float = 1.0  # Modulation depth
    offset: float = 0.0  # Base value offset
    smoothing: float = 0.1  # Temporal smoothing (0-1)
    invert: bool = False  # Invert the modulation
    threshold: float = 0.0  # Minimum value to trigger
    attack: float = 0.01  # Attack time in seconds
    release: float = 0.1  # Release time in seconds


@dataclass
class S2VConfig:
    """Configuration for Sound-to-Video generation"""
    audio_path: Optional[str] = None
    audio_data: Optional[np.ndarray] = None
    sample_rate: int = 44100

    # Tempo settings
    auto_detect_bpm: bool = True
    manual_bpm: Optional[float] = None
    sync_to_beat: bool = True

    # Analysis settings
    hop_length: int = 512
    n_fft: int = 2048
    n_mels: int = 128

    # Modulation routes
    routes: List[ModulationRoute] = field(default_factory=list)

    # Presets
    use_preset: Optional[str] = None  # "energetic", "chill", "cinematic"


# Modulation presets
S2V_PRESETS = {
    "energetic": [
        ModulationRoute(AudioFeature.BEAT, VideoParameter.ZOOM, amount=0.3),
        ModulationRoute(AudioFeature.BASS, VideoParameter.MOTION_SPEED, amount=0.5),
        ModulationRoute(AudioFeature.ENERGY, VideoParameter.SATURATION, amount=0.4),
        ModulationRoute(AudioFeature.ONSET, VideoParameter.CUT_PROBABILITY, amount=0.8),
    ],
    "chill": [
        ModulationRoute(AudioFeature.MIDS, VideoParameter.BRIGHTNESS, amount=0.2, smoothing=0.3),
        ModulationRoute(AudioFeature.SPECTRAL_CENTROID, VideoParameter.HUE_SHIFT, amount=0.3),
        ModulationRoute(AudioFeature.ENERGY, VideoParameter.BLUR, amount=0.2, invert=True),
    ],
    "cinematic": [
        ModulationRoute(AudioFeature.BASS, VideoParameter.ZOOM, amount=0.15, smoothing=0.2),
        ModulationRoute(AudioFeature.ENERGY, VideoParameter.CONTRAST, amount=0.3),
        ModulationRoute(AudioFeature.ONSET, VideoParameter.CUT_PROBABILITY, amount=0.5, threshold=0.7),
        ModulationRoute(AudioFeature.SPECTRAL_FLUX, VideoParameter.MOTION_SPEED, amount=0.4),
    ],
    "psychedelic": [
        ModulationRoute(AudioFeature.BASS, VideoParameter.ZOOM, amount=0.5),
        ModulationRoute(AudioFeature.MIDS, VideoParameter.ROTATION, amount=0.3),
        ModulationRoute(AudioFeature.HIGHS, VideoParameter.HUE_SHIFT, amount=0.8),
        ModulationRoute(AudioFeature.SPECTRAL_CENTROID, VideoParameter.SATURATION, amount=0.6),
        ModulationRoute(AudioFeature.BEAT, VideoParameter.STYLE_MORPH, amount=0.4),
    ],
}


@dataclass
class AudioAnalysis:
    """Results of audio analysis"""
    duration: float
    sample_rate: int
    bpm: float
    beat_times: np.ndarray
    beat_frames: np.ndarray

    # Per-frame features
    bass: np.ndarray
    mids: np.ndarray
    highs: np.ndarray
    energy: np.ndarray
    onsets: np.ndarray
    spectral_centroid: np.ndarray
    spectral_flux: np.ndarray

    # Metadata
    num_frames: int
    frame_rate: float


class AudioAnalyzer:
    """
    Analyzes audio for video synchronization.

    Extracts tempo, beats, and spectral features for modulation.
    """

    def __init__(self, sample_rate: int = 44100, hop_length: int = 512):
        self.sample_rate = sample_rate
        self.hop_length = hop_length

    def analyze(
        self,
        audio: np.ndarray,
        target_fps: int = 24
    ) -> AudioAnalysis:
        """
        Analyze audio and extract features.

        Args:
            audio: Audio waveform (mono or stereo)
            target_fps: Target video frame rate

        Returns:
            AudioAnalysis with all extracted features
        """
        # Convert to mono if stereo
        if len(audio.shape) > 1:
            audio = np.mean(audio, axis=1)

        duration = len(audio) / self.sample_rate
        num_frames = int(duration * target_fps)

        logger.info(f"Analyzing audio: {duration:.2f}s, {num_frames} frames @ {target_fps}fps")

        # Detect tempo and beats
        bpm, beat_times = self._detect_beats(audio)

        # Convert beat times to frame indices
        beat_frames = (beat_times * target_fps).astype(int)
        beat_frames = beat_frames[beat_frames < num_frames]

        # Extract spectral features
        bass, mids, highs = self._extract_frequency_bands(audio, num_frames)
        energy = self._extract_energy(audio, num_frames)
        onsets = self._detect_onsets(audio, num_frames)
        spectral_centroid = self._extract_spectral_centroid(audio, num_frames)
        spectral_flux = self._extract_spectral_flux(audio, num_frames)

        return AudioAnalysis(
            duration=duration,
            sample_rate=self.sample_rate,
            bpm=bpm,
            beat_times=beat_times,
            beat_frames=beat_frames,
            bass=bass,
            mids=mids,
            highs=highs,
            energy=energy,
            onsets=onsets,
            spectral_centroid=spectral_centroid,
            spectral_flux=spectral_flux,
            num_frames=num_frames,
            frame_rate=target_fps,
        )

    def _detect_beats(self, audio: np.ndarray) -> Tuple[float, np.ndarray]:
        """Detect tempo and beat positions"""
        try:
            import librosa
            tempo, beat_frames = librosa.beat.beat_track(
                y=audio,
                sr=self.sample_rate,
                hop_length=self.hop_length
            )
            beat_times = librosa.frames_to_time(
                beat_frames,
                sr=self.sample_rate,
                hop_length=self.hop_length
            )
            return float(tempo), beat_times
        except ImportError:
            # Fallback: simple energy-based beat detection
            return self._simple_beat_detection(audio)

    def _simple_beat_detection(self, audio: np.ndarray) -> Tuple[float, np.ndarray]:
        """Simple beat detection without librosa"""
        # Compute energy envelope
        frame_size = self.hop_length
        num_frames = len(audio) // frame_size
        energy = np.array([
            np.sum(audio[i*frame_size:(i+1)*frame_size]**2)
            for i in range(num_frames)
        ])

        # Normalize
        energy = energy / (np.max(energy) + 1e-8)

        # Find peaks (beats)
        threshold = 0.5
        peaks = []
        for i in range(1, len(energy) - 1):
            if energy[i] > threshold and energy[i] > energy[i-1] and energy[i] > energy[i+1]:
                peaks.append(i)

        beat_times = np.array(peaks) * frame_size / self.sample_rate

        # Estimate BPM from beat intervals
        if len(beat_times) > 1:
            intervals = np.diff(beat_times)
            avg_interval = np.median(intervals)
            bpm = 60.0 / avg_interval if avg_interval > 0 else 120.0
        else:
            bpm = 120.0

        return bpm, beat_times

    def _extract_frequency_bands(
        self,
        audio: np.ndarray,
        num_frames: int
    ) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
        """Extract bass, mids, and highs energy"""
        try:
            import librosa
            # Compute spectrogram
            S = np.abs(librosa.stft(audio, hop_length=self.hop_length))
            freqs = librosa.fft_frequencies(sr=self.sample_rate)

            # Define frequency bands
            bass_mask = freqs < 250
            mids_mask = (freqs >= 250) & (freqs < 4000)
            highs_mask = freqs >= 4000

            # Sum energy in each band
            bass = np.sum(S[bass_mask, :], axis=0)
            mids = np.sum(S[mids_mask, :], axis=0)
            highs = np.sum(S[highs_mask, :], axis=0)

            # Resample to target frames
            bass = self._resample_feature(bass, num_frames)
            mids = self._resample_feature(mids, num_frames)
            highs = self._resample_feature(highs, num_frames)

            # Normalize
            bass = bass / (np.max(bass) + 1e-8)
            mids = mids / (np.max(mids) + 1e-8)
            highs = highs / (np.max(highs) + 1e-8)

            return bass, mids, highs
        except ImportError:
            # Fallback: return uniform values
            return (
                np.ones(num_frames) * 0.5,
                np.ones(num_frames) * 0.5,
                np.ones(num_frames) * 0.5,
            )

    def _extract_energy(self, audio: np.ndarray, num_frames: int) -> np.ndarray:
        """Extract RMS energy per frame"""
        frame_size = len(audio) // num_frames
        energy = np.array([
            np.sqrt(np.mean(audio[i*frame_size:(i+1)*frame_size]**2))
            for i in range(num_frames)
        ])
        return energy / (np.max(energy) + 1e-8)

    def _detect_onsets(self, audio: np.ndarray, num_frames: int) -> np.ndarray:
        """Detect onset strength per frame"""
        try:
            import librosa
            onset_env = librosa.onset.onset_strength(
                y=audio,
                sr=self.sample_rate,
                hop_length=self.hop_length
            )
            onsets = self._resample_feature(onset_env, num_frames)
            return onsets / (np.max(onsets) + 1e-8)
        except ImportError:
            return self._extract_energy(audio, num_frames)

    def _extract_spectral_centroid(self, audio: np.ndarray, num_frames: int) -> np.ndarray:
        """Extract spectral centroid (brightness)"""
        try:
            import librosa
            centroid = librosa.feature.spectral_centroid(
                y=audio,
                sr=self.sample_rate,
                hop_length=self.hop_length
            )[0]
            centroid = self._resample_feature(centroid, num_frames)
            return centroid / (np.max(centroid) + 1e-8)
        except ImportError:
            return np.ones(num_frames) * 0.5

    def _extract_spectral_flux(self, audio: np.ndarray, num_frames: int) -> np.ndarray:
        """Extract spectral flux (rate of change)"""
        try:
            import librosa
            S = np.abs(librosa.stft(audio, hop_length=self.hop_length))
            flux = np.sqrt(np.sum(np.diff(S, axis=1)**2, axis=0))
            flux = np.concatenate([[0], flux])
            flux = self._resample_feature(flux, num_frames)
            return flux / (np.max(flux) + 1e-8)
        except ImportError:
            return np.ones(num_frames) * 0.5

    def _resample_feature(self, feature: np.ndarray, target_length: int) -> np.ndarray:
        """Resample feature array to target length"""
        if len(feature) == target_length:
            return feature
        indices = np.linspace(0, len(feature) - 1, target_length)
        return np.interp(indices, np.arange(len(feature)), feature)


class S2VModulator:
    """
    Modulates video parameters based on audio analysis.

    Applies audio features to video generation parameters with
    configurable modulation routes, smoothing, and envelopes.
    """

    def __init__(self, config: S2VConfig):
        self.config = config
        self.analyzer = AudioAnalyzer(
            sample_rate=config.sample_rate,
            hop_length=config.hop_length
        )
        self.analysis: Optional[AudioAnalysis] = None
        self._smoothed_values: Dict[VideoParameter, float] = {}

    def analyze_audio(self, target_fps: int = 24) -> AudioAnalysis:
        """Analyze the configured audio"""
        if self.config.audio_data is not None:
            audio = self.config.audio_data
        elif self.config.audio_path:
            audio = self._load_audio(self.config.audio_path)
        else:
            raise ValueError("No audio source configured")

        self.analysis = self.analyzer.analyze(audio, target_fps)

        # Override BPM if manually specified
        if self.config.manual_bpm:
            self.analysis.bpm = self.config.manual_bpm

        logger.info(f"Audio analyzed: BPM={self.analysis.bpm:.1f}, {len(self.analysis.beat_times)} beats")
        return self.analysis

    def _load_audio(self, path: str) -> np.ndarray:
        """Load audio from file"""
        try:
            import librosa
            audio, _ = librosa.load(path, sr=self.config.sample_rate, mono=True)
            return audio
        except ImportError:
            # Fallback: try scipy
            from scipy.io import wavfile
            sr, audio = wavfile.read(path)
            if len(audio.shape) > 1:
                audio = np.mean(audio, axis=1)
            audio = audio.astype(np.float32) / 32768.0
            return audio

    def get_routes(self) -> List[ModulationRoute]:
        """Get modulation routes (from preset or config)"""
        if self.config.use_preset and self.config.use_preset in S2V_PRESETS:
            return S2V_PRESETS[self.config.use_preset]
        return self.config.routes

    def get_modulation(self, frame_idx: int) -> Dict[VideoParameter, float]:
        """
        Get modulated parameter values for a specific frame.

        Args:
            frame_idx: Video frame index

        Returns:
            Dict of parameter values
        """
        if self.analysis is None:
            raise RuntimeError("Audio not analyzed. Call analyze_audio() first.")

        if frame_idx >= self.analysis.num_frames:
            frame_idx = self.analysis.num_frames - 1

        modulation = {}

        for route in self.get_routes():
            # Get source feature value
            source_value = self._get_feature_value(route.source, frame_idx)

            # Apply threshold
            if source_value < route.threshold:
                source_value = 0.0

            # Apply inversion
            if route.invert:
                source_value = 1.0 - source_value

            # Apply smoothing (simple exponential smoothing)
            prev_value = self._smoothed_values.get(route.target, source_value)
            alpha = 1.0 - route.smoothing
            smoothed = alpha * source_value + (1 - alpha) * prev_value
            self._smoothed_values[route.target] = smoothed

            # Apply amount and offset
            final_value = route.offset + smoothed * route.amount

            modulation[route.target] = final_value

        return modulation

    def _get_feature_value(self, feature: AudioFeature, frame_idx: int) -> float:
        """Get the value of an audio feature at a frame"""
        if feature == AudioFeature.BEAT:
            # Check if this frame is near a beat
            return 1.0 if frame_idx in self.analysis.beat_frames else 0.0
        elif feature == AudioFeature.TEMPO:
            return self.analysis.bpm / 200.0  # Normalize to ~0-1
        elif feature == AudioFeature.BASS:
            return float(self.analysis.bass[frame_idx])
        elif feature == AudioFeature.MIDS:
            return float(self.analysis.mids[frame_idx])
        elif feature == AudioFeature.HIGHS:
            return float(self.analysis.highs[frame_idx])
        elif feature == AudioFeature.ENERGY:
            return float(self.analysis.energy[frame_idx])
        elif feature == AudioFeature.ONSET:
            return float(self.analysis.onsets[frame_idx])
        elif feature == AudioFeature.SPECTRAL_CENTROID:
            return float(self.analysis.spectral_centroid[frame_idx])
        elif feature == AudioFeature.SPECTRAL_FLUX:
            return float(self.analysis.spectral_flux[frame_idx])
        return 0.0

    def get_beat_synced_keyframes(self) -> List[int]:
        """Get frame indices that should be keyframes (on beats)"""
        if self.analysis is None:
            return []
        return self.analysis.beat_frames.tolist()

    def generate_motion_curve(
        self,
        parameter: VideoParameter,
        num_frames: int
    ) -> np.ndarray:
        """
        Generate a complete motion curve for a parameter.

        Args:
            parameter: Video parameter
            num_frames: Number of frames

        Returns:
            Array of parameter values
        """
        curve = np.zeros(num_frames)

        for i in range(num_frames):
            modulation = self.get_modulation(i)
            curve[i] = modulation.get(parameter, 0.0)

        return curve


# Global analyzer instance
audio_analyzer = AudioAnalyzer()


__all__ = [
    # Enums
    "AudioFeature",
    "VideoParameter",
    # Config
    "ModulationRoute",
    "S2VConfig",
    "S2V_PRESETS",
    # Analysis
    "AudioAnalysis",
    "AudioAnalyzer",
    "audio_analyzer",
    # Modulation
    "S2VModulator",
]
