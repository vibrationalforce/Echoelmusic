import Foundation
import AVFoundation

/// Zentrale Audio-Konstanten für konsistente Konfiguration
/// Eliminiert Magic Numbers und ermöglicht einfache Anpassung
enum AudioConstants {

    // MARK: - Sample Rates

    /// System-Sample-Rate (dynamisch)
    static var systemSampleRate: Double {
        AVAudioSession.sharedInstance().sampleRate
    }

    /// Preferred Sample Rate für Aufnahmen
    static let preferredSampleRate: Double = 48000.0

    // MARK: - Buffer Sizes

    /// Ultra-Low Latency (~2.67ms @ 48kHz) - für Live-Performance
    static let ultraLowLatencyBuffer: AVAudioFrameCount = 128

    /// Low Latency (~5.33ms @ 48kHz) - Standard für Bio-Reactive
    static let lowLatencyBuffer: AVAudioFrameCount = 256

    /// Normal (~10.67ms @ 48kHz) - für normale Wiedergabe
    static let normalBuffer: AVAudioFrameCount = 512

    /// High Quality (~21.33ms @ 48kHz) - für Aufnahme/Export
    static let highQualityBuffer: AVAudioFrameCount = 1024

    /// Synthesis Buffer - für Instrument-Synthese
    static let synthesisBuffer: AVAudioFrameCount = 4096

    // MARK: - Binaural Beat Frequencies

    /// Traditional Carrier Frequency (432 Hz - kulturell als "entspannend" angesehen)
    /// HINWEIS: Keine wissenschaftlich belegten "Heilungseffekte". Subjektive Präferenz.
    static let traditionalCarrierFrequency: Float = 432.0

    /// Standard Carrier Frequency (440 Hz - A4, ISO 16)
    static let standardCarrierFrequency: Float = 440.0

    /// Brainwave Beat Frequencies (EEG-basiert, wissenschaftlich messbar)
    enum Brainwave {
        /// Delta (2 Hz) - Tiefschlaf, Regeneration (EEG-validiert)
        static let delta: Float = 2.0
        /// Theta (6 Hz) - Meditation, Kreativität
        static let theta: Float = 6.0
        /// Alpha (10 Hz) - Entspannung, Lernen
        static let alpha: Float = 10.0
        /// Beta (20 Hz) - Fokus, Wachheit
        static let beta: Float = 20.0
        /// Gamma (40 Hz) - Peak Awareness
        static let gamma: Float = 40.0
    }

    // MARK: - HRV Thresholds

    /// HRV Coherence Thresholds für Bio-Reactive Anpassung
    enum HRVThresholds {
        /// Niedrige Coherence (Stress)
        static let low: Double = 40.0
        /// Mittlere Coherence (Übergang)
        static let medium: Double = 60.0
        /// Hohe Coherence (Flow State)
        static let high: Double = 80.0
    }

    // MARK: - Amplitude Ranges

    /// Default Amplitude für Multidimensional Brainwave Entrainment
    static let defaultBinauralAmplitude: Float = 0.3

    /// Minimum Amplitude
    static let minAmplitude: Float = 0.0

    /// Maximum safe Amplitude (Gehörschutz)
    static let maxSafeAmplitude: Float = 0.6

    // MARK: - Performance Thresholds

    /// Exponential Moving Average Smoothing Factors
    enum Smoothing {
        /// FPS Smoothing (90% old, 10% new)
        static let fps: Double = 0.9
        /// CPU/GPU Usage Smoothing (80% old, 20% new)
        static let usage: Double = 0.8
        /// Bio-Data Smoothing (70% old, 30% new)
        static let bioData: Double = 0.7
    }

    /// Memory Thresholds
    enum Memory {
        /// Max Cache Size (100 MB)
        static let maxCacheSize: Int = 100 * 1024 * 1024
        /// Memory Pressure Threshold (80%)
        static let pressureThreshold: Float = 0.8
        /// Warning Threshold (70%)
        static let warningThreshold: Float = 0.7
    }

    // MARK: - Thread Configuration

    /// Audio Thread Priority Computation Percent
    static let audioThreadComputationPercent: Double = 0.75

    /// Audio Thread Constraint Percent
    static let audioThreadConstraintPercent: Double = 0.95

    // MARK: - Voice Polyphony

    /// Maximum simultane Voices für Synthesizer
    static let maxPolyphony: Int = 16

    /// Voice Stealing Threshold
    static let voiceStealingThreshold: Int = 14
}

// MARK: - Convenience Extensions

extension AVAudioFormat {
    /// Standard stereo format mit System-Sample-Rate
    static var standardStereo: AVAudioFormat? {
        AVAudioFormat(
            standardFormatWithSampleRate: AudioConstants.systemSampleRate,
            channels: 2
        )
    }

    /// Standard mono format mit System-Sample-Rate
    static var standardMono: AVAudioFormat? {
        AVAudioFormat(
            standardFormatWithSampleRate: AudioConstants.systemSampleRate,
            channels: 1
        )
    }
}
