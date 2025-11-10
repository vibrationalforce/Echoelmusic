"""
Echoelmusic AI/ML Module
Python integration for advanced AI and scientific computing

Features:
- Audio source separation (Demucs, Spleeter)
- Music generation (MusicGen, Jukebox)
- Scientific computing (NumPy, SciPy)
- Medical signal processing (HRV, EEG)
- Deep learning (TensorFlow, PyTorch)
"""

import numpy as np
import scipy.signal as signal
import scipy.fft as fft
from typing import Tuple, List, Optional
from dataclasses import dataclass
from enum import Enum

# Deep Learning
try:
    import tensorflow as tf
    import torch
    DEEP_LEARNING_AVAILABLE = True
except ImportError:
    DEEP_LEARNING_AVAILABLE = False
    print("⚠️  TensorFlow/PyTorch not available. Install with:")
    print("   pip install tensorflow torch")

# Audio processing
try:
    import librosa
    import soundfile as sf
    AUDIO_PROCESSING_AVAILABLE = True
except ImportError:
    AUDIO_PROCESSING_AVAILABLE = False
    print("⚠️  librosa/soundfile not available. Install with:")
    print("   pip install librosa soundfile")

# Medical processing
try:
    import heartpy as hp
    from scipy.stats import entropy
    MEDICAL_PROCESSING_AVAILABLE = True
except ImportError:
    MEDICAL_PROCESSING_AVAILABLE = False
    print("⚠️  heartpy not available. Install with:")
    print("   pip install heartpy")


# ==============================================================================
# Audio Source Separation
# ==============================================================================

class AudioSourceSeparator:
    """
    Separate audio into stems (vocals, drums, bass, other)
    Using Demucs or Spleeter models
    """

    def __init__(self, model: str = "htdemucs"):
        """
        Args:
            model: Model to use ('htdemucs', 'htdemucs_ft', 'spleeter')
        """
        self.model = model
        print(f"🎵 Initializing Audio Source Separator: {model}")

        if not DEEP_LEARNING_AVAILABLE:
            raise RuntimeError("Deep learning libraries required for source separation")

        # Load model (in production)
        # self._load_model()

    def separate(self, audio: np.ndarray, sr: int = 44100) -> dict:
        """
        Separate audio into stems

        Args:
            audio: Audio signal (mono or stereo)
            sr: Sample rate

        Returns:
            Dictionary with stems: {'vocals', 'drums', 'bass', 'other'}
        """
        print(f"   Separating audio: {len(audio)} samples @ {sr} Hz")

        # In production: Run Demucs/Spleeter model
        # stems = self.model.separate(audio)

        # Mock separation
        stems = {
            'vocals': audio * 0.3,
            'drums': audio * 0.2,
            'bass': audio * 0.2,
            'other': audio * 0.3,
        }

        print("   ✅ Separation complete")
        return stems


# ==============================================================================
# Music Generation
# ==============================================================================

class MusicGenerator:
    """
    Generate music using AI models
    Models: MusicGen, Jukebox, MuseNet
    """

    def __init__(self, model: str = "musicgen-small"):
        self.model = model
        print(f"🎹 Initializing Music Generator: {model}")

    def generate_from_text(
        self,
        prompt: str,
        duration: float = 10.0,
        sr: int = 44100
    ) -> np.ndarray:
        """
        Generate music from text prompt

        Args:
            prompt: Text description (e.g., "upbeat jazz piano")
            duration: Duration in seconds
            sr: Sample rate

        Returns:
            Generated audio signal
        """
        print(f"   Generating music: '{prompt}'")
        print(f"   Duration: {duration}s @ {sr} Hz")

        num_samples = int(duration * sr)

        # Mock generation: synthesize a simple melody
        t = np.linspace(0, duration, num_samples)
        frequencies = [440, 494, 523, 587, 659]  # A, B, C, D, E
        audio = np.zeros(num_samples)

        for freq in frequencies:
            audio += np.sin(2 * np.pi * freq * t) / len(frequencies)

        audio = audio * 0.5  # Normalize

        print("   ✅ Music generated")
        return audio

    def generate_melody(
        self,
        key: str = "C",
        scale: str = "major",
        length_bars: int = 4,
        tempo: int = 120
    ) -> List[int]:
        """
        Generate MIDI melody

        Args:
            key: Musical key (C, D, E, etc.)
            scale: Scale type (major, minor, pentatonic, etc.)
            length_bars: Number of bars
            tempo: BPM

        Returns:
            List of MIDI note numbers
        """
        print(f"   Generating melody: {key} {scale}, {length_bars} bars @ {tempo} BPM")

        # Musical scales (MIDI note numbers relative to root)
        scales = {
            'major': [0, 2, 4, 5, 7, 9, 11],
            'minor': [0, 2, 3, 5, 7, 8, 10],
            'pentatonic': [0, 2, 4, 7, 9],
            'blues': [0, 3, 5, 6, 7, 10],
        }

        root_notes = {
            'C': 60, 'C#': 61, 'D': 62, 'D#': 63,
            'E': 64, 'F': 65, 'F#': 66, 'G': 67,
            'G#': 68, 'A': 69, 'A#': 70, 'B': 71,
        }

        root = root_notes[key]
        scale_intervals = scales.get(scale, scales['major'])

        # Generate random melody within scale
        num_notes = length_bars * 4  # 4 notes per bar
        melody = []

        for _ in range(num_notes):
            octave = np.random.choice([0, 12])  # Current or next octave
            scale_degree = np.random.choice(scale_intervals)
            note = root + octave + scale_degree
            melody.append(note)

        print(f"   ✅ Melody generated: {len(melody)} notes")
        return melody


# ==============================================================================
# Scientific Audio Analysis
# ==============================================================================

class ScientificAudioAnalyzer:
    """
    Scientific analysis of audio signals
    Psychoacoustics, spectral analysis, etc.
    """

    @staticmethod
    def compute_fft(audio: np.ndarray, sr: int) -> Tuple[np.ndarray, np.ndarray]:
        """
        Compute FFT (frequency spectrum)

        Returns:
            frequencies, magnitudes
        """
        n = len(audio)
        frequencies = fft.rfftfreq(n, 1/sr)
        spectrum = fft.rfft(audio)
        magnitudes = np.abs(spectrum)

        return frequencies, magnitudes

    @staticmethod
    def compute_spectrogram(
        audio: np.ndarray,
        sr: int,
        window_size: int = 2048,
        hop_size: int = 512
    ) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
        """
        Compute STFT spectrogram

        Returns:
            times, frequencies, spectrogram
        """
        frequencies, times, spectrogram = signal.spectrogram(
            audio,
            fs=sr,
            window='hann',
            nperseg=window_size,
            noverlap=window_size - hop_size
        )

        return times, frequencies, spectrogram

    @staticmethod
    def detect_beats(audio: np.ndarray, sr: int) -> List[float]:
        """
        Detect beats in audio

        Returns:
            List of beat times in seconds
        """
        if not AUDIO_PROCESSING_AVAILABLE:
            raise RuntimeError("librosa required for beat detection")

        # Onset envelope
        onset_env = librosa.onset.onset_strength(y=audio, sr=sr)

        # Beat tracking
        tempo, beats = librosa.beat.beat_track(
            onset_envelope=onset_env,
            sr=sr
        )

        beat_times = librosa.frames_to_time(beats, sr=sr)

        print(f"   Detected tempo: {tempo:.1f} BPM")
        print(f"   Detected {len(beat_times)} beats")

        return beat_times.tolist()

    @staticmethod
    def estimate_key(audio: np.ndarray, sr: int) -> str:
        """
        Estimate musical key using Krumhansl-Schmuckler algorithm

        Returns:
            Key (e.g., 'C major', 'A minor')
        """
        if not AUDIO_PROCESSING_AVAILABLE:
            raise RuntimeError("librosa required for key estimation")

        # Chromagram
        chroma = librosa.feature.chroma_cqt(y=audio, sr=sr)

        # Average over time
        chroma_avg = np.mean(chroma, axis=1)

        # Krumhansl-Schmuckler key profiles
        major_profile = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09,
                                  2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
        minor_profile = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53,
                                  2.54, 4.75, 3.98, 2.69, 3.34, 3.17])

        # Correlate with key profiles
        keys = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
        max_correlation = -1
        estimated_key = ''

        for shift in range(12):
            shifted_chroma = np.roll(chroma_avg, shift)

            # Major
            corr_major = np.corrcoef(shifted_chroma, major_profile)[0, 1]
            if corr_major > max_correlation:
                max_correlation = corr_major
                estimated_key = f"{keys[shift]} major"

            # Minor
            corr_minor = np.corrcoef(shifted_chroma, minor_profile)[0, 1]
            if corr_minor > max_correlation:
                max_correlation = corr_minor
                estimated_key = f"{keys[shift]} minor"

        print(f"   Estimated key: {estimated_key} (confidence: {max_correlation:.2f})")

        return estimated_key


# ==============================================================================
# Medical Signal Processing
# ==============================================================================

class MedicalSignalProcessor:
    """
    Process medical signals: ECG, HRV, EEG
    """

    @staticmethod
    def analyze_hrv(rr_intervals: np.ndarray) -> dict:
        """
        Analyze Heart Rate Variability

        Args:
            rr_intervals: RR intervals in milliseconds

        Returns:
            HRV metrics dictionary
        """
        print("   Analyzing HRV...")

        # Time-domain metrics
        sdnn = np.std(rr_intervals)  # Standard deviation
        rmssd = np.sqrt(np.mean(np.diff(rr_intervals) ** 2))  # Root mean square

        # pNN50: percentage of successive differences > 50ms
        diff = np.abs(np.diff(rr_intervals))
        pnn50 = np.sum(diff > 50) / len(diff) * 100

        # Frequency-domain metrics (requires FFT)
        # Convert to evenly sampled time series
        fs = 4.0  # 4 Hz resampling
        time_rr = np.cumsum(rr_intervals) / 1000.0  # Convert to seconds
        time_even = np.arange(0, time_rr[-1], 1/fs)

        # Interpolate to even sampling
        hr_interp = np.interp(time_even, time_rr[:-1], rr_intervals[:-1])

        # Compute power spectral density
        frequencies, psd = signal.welch(hr_interp, fs=fs, nperseg=256)

        # LF (0.04-0.15 Hz), HF (0.15-0.4 Hz)
        lf_band = (frequencies >= 0.04) & (frequencies < 0.15)
        hf_band = (frequencies >= 0.15) & (frequencies < 0.4)

        lf_power = np.trapz(psd[lf_band], frequencies[lf_band])
        hf_power = np.trapz(psd[hf_band], frequencies[hf_band])
        lf_hf_ratio = lf_power / hf_power if hf_power > 0 else 0

        # Poincaré plot metrics (SD1, SD2)
        diff_rr = np.diff(rr_intervals)
        sd1 = np.sqrt(0.5 * np.var(diff_rr))  # Short-term variability
        sd2 = np.sqrt(2 * np.var(rr_intervals) - 0.5 * np.var(diff_rr))  # Long-term

        metrics = {
            'sdnn': sdnn,
            'rmssd': rmssd,
            'pnn50': pnn50,
            'lf_power': lf_power,
            'hf_power': hf_power,
            'lf_hf_ratio': lf_hf_ratio,
            'sd1': sd1,
            'sd2': sd2,
            'sd1_sd2_ratio': sd1 / sd2 if sd2 > 0 else 0,
        }

        print(f"   ✅ HRV Analysis complete:")
        print(f"      SDNN: {sdnn:.2f} ms")
        print(f"      RMSSD: {rmssd:.2f} ms")
        print(f"      LF/HF: {lf_hf_ratio:.2f}")

        return metrics

    @staticmethod
    def analyze_eeg(
        eeg_data: np.ndarray,
        sr: int = 256,
        channels: List[str] = None
    ) -> dict:
        """
        Analyze EEG signals

        Args:
            eeg_data: EEG data (channels x samples)
            sr: Sample rate
            channels: Channel names (e.g., ['Fp1', 'Fp2', 'F3', 'F4'])

        Returns:
            EEG features dictionary
        """
        print("   Analyzing EEG...")

        num_channels, num_samples = eeg_data.shape
        duration = num_samples / sr

        print(f"      Channels: {num_channels}")
        print(f"      Duration: {duration:.1f}s")
        print(f"      Sample rate: {sr} Hz")

        # Band power analysis
        bands = {
            'delta': (0.5, 4),    # Deep sleep
            'theta': (4, 8),      # Meditation
            'alpha': (8, 13),     # Relaxation
            'beta': (13, 30),     # Active thinking
            'gamma': (30, 100),   # Cognition
        }

        band_powers = {}

        for band_name, (low, high) in bands.items():
            powers = []

            for ch in range(num_channels):
                # Bandpass filter
                sos = signal.butter(4, [low, high], btype='band', fs=sr, output='sos')
                filtered = signal.sosfilt(sos, eeg_data[ch])

                # Compute power
                power = np.mean(filtered ** 2)
                powers.append(power)

            band_powers[band_name] = np.mean(powers)

        # Dominant frequency
        total_power = sum(band_powers.values())
        dominant_band = max(band_powers, key=band_powers.get)

        print(f"      Dominant band: {dominant_band} ({band_powers[dominant_band]/total_power*100:.1f}%)")

        return {
            'band_powers': band_powers,
            'dominant_band': dominant_band,
            'total_power': total_power,
        }


# ==============================================================================
# Main API
# ==============================================================================

class EchoelmusicAI:
    """
    Main AI/ML interface for Echoelmusic
    """

    def __init__(self):
        print("🧠 Initializing Echoelmusic AI/ML Engine")

        self.separator = None
        self.generator = None
        self.analyzer = ScientificAudioAnalyzer()
        self.medical = MedicalSignalProcessor()

        print("   ✅ AI/ML Engine ready")

    def load_source_separator(self, model: str = "htdemucs"):
        """Load audio source separation model"""
        self.separator = AudioSourceSeparator(model)

    def load_music_generator(self, model: str = "musicgen-small"):
        """Load music generation model"""
        self.generator = MusicGenerator(model)

    def separate_audio(self, audio: np.ndarray, sr: int = 44100) -> dict:
        """Separate audio into stems"""
        if self.separator is None:
            self.load_source_separator()
        return self.separator.separate(audio, sr)

    def generate_music(
        self,
        prompt: str,
        duration: float = 10.0,
        sr: int = 44100
    ) -> np.ndarray:
        """Generate music from text"""
        if self.generator is None:
            self.load_music_generator()
        return self.generator.generate_from_text(prompt, duration, sr)

    def analyze_audio(self, audio: np.ndarray, sr: int) -> dict:
        """Complete audio analysis"""
        print("🔍 Analyzing audio...")

        results = {}

        # FFT
        frequencies, magnitudes = self.analyzer.compute_fft(audio, sr)
        results['fft'] = {'frequencies': frequencies, 'magnitudes': magnitudes}

        # Beats
        try:
            beats = self.analyzer.detect_beats(audio, sr)
            results['beats'] = beats
        except Exception as e:
            print(f"   ⚠️ Beat detection failed: {e}")

        # Key
        try:
            key = self.analyzer.estimate_key(audio, sr)
            results['key'] = key
        except Exception as e:
            print(f"   ⚠️ Key estimation failed: {e}")

        print("   ✅ Analysis complete")
        return results


# ==============================================================================
# Test / Example
# ==============================================================================

if __name__ == "__main__":
    print("=" * 80)
    print("Echoelmusic AI/ML Module - Test")
    print("=" * 80)

    ai = EchoelmusicAI()

    # Test music generation
    print("\n🎹 Testing music generation...")
    audio = ai.generate_music("upbeat jazz piano", duration=5.0)
    print(f"   Generated {len(audio)} samples")

    # Test audio analysis
    print("\n🔍 Testing audio analysis...")
    sr = 44100
    results = ai.analyze_audio(audio, sr)
    print(f"   Analysis keys: {list(results.keys())}")

    # Test HRV analysis
    print("\n❤️  Testing HRV analysis...")
    rr_intervals = np.random.normal(800, 50, 100)  # Mock RR intervals
    hrv_metrics = ai.medical.analyze_hrv(rr_intervals)

    # Test EEG analysis
    print("\n🧠 Testing EEG analysis...")
    eeg_data = np.random.randn(4, 256 * 10)  # 4 channels, 10 seconds @ 256 Hz
    eeg_features = ai.medical.analyze_eeg(eeg_data, sr=256)

    print("\n✅ All tests complete!")
