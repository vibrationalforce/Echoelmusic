import Foundation
import AVFoundation

/// Zentrale Audio-Konstanten für konsistente Konfiguration
/// Eliminiert Magic Numbers und ermöglicht einfache Anpassung
///
/// EVIDENCE-BASED DESIGN (2026)
/// All frequency values based on peer-reviewed research where available.
/// Evidence levels noted using Oxford CEBM scale (1a-5).
///
/// References:
/// - HRV: Scientific Reports 2025, HeartMath Institute
/// - Binaural: PMC Systematic Review 2023, MDPI Meta-Analysis 2024
/// - Breathing: PubMed systematic reviews on resonance frequency
public enum AudioConstants {

    // MARK: - Sample Rates

    /// System-Sample-Rate (dynamisch)
    public static var systemSampleRate: Double {
        AVAudioSession.sharedInstance().sampleRate
    }

    /// Preferred Sample Rate für Aufnahmen (Pro Audio Standard)
    public static let preferredSampleRate: Double = 48000.0

    // MARK: - Buffer Sizes

    /// Ultra-Low Latency (~2.67ms @ 48kHz) - für Live-Performance
    public static let ultraLowLatencyBuffer: AVAudioFrameCount = 128

    /// Low Latency (~5.33ms @ 48kHz) - Standard für Bio-Reactive
    public static let lowLatencyBuffer: AVAudioFrameCount = 256

    /// Normal (~10.67ms @ 48kHz) - für normale Wiedergabe
    public static let normalBuffer: AVAudioFrameCount = 512

    /// High Quality (~21.33ms @ 48kHz) - für Aufnahme/Export
    public static let highQualityBuffer: AVAudioFrameCount = 1024

    /// Synthesis Buffer - für Instrument-Synthese
    public static let synthesisBuffer: AVAudioFrameCount = 4096

    // MARK: - Carrier Frequencies

    /// Standard Carrier Frequency (440 Hz - A4, ISO 16)
    /// Internationally standardized concert pitch
    public static let standardCarrierFrequency: Float = 440.0

    /// Alternative Carrier (432 Hz)
    /// NOTE: No scientific evidence for "healing" properties.
    /// Included for user preference only. Evidence: NONE
    public static let alternativeCarrierFrequency: Float = 432.0

    // MARK: - Brainwave Frequencies (EEG-Based)

    /// Brainwave Beat Frequencies
    /// These are EEG-measured frequency bands, NOT claimed therapeutic effects.
    /// Evidence for external entrainment: MIXED (PMC10198548)
    public enum Brainwave {
        /// Delta (0.5-4 Hz) - Associated with deep sleep
        /// Evidence for entrainment: LIMITED
        public static let delta: Float = 2.0
        public static let deltaRange: ClosedRange<Float> = 0.5...4.0

        /// Theta (4-8 Hz) - Associated with drowsiness, memory encoding
        /// Evidence for entrainment: MODERATE
        public static let theta: Float = 6.0
        public static let thetaRange: ClosedRange<Float> = 4.0...8.0

        /// Alpha (8-12 Hz) - Associated with relaxed wakefulness
        /// Evidence for entrainment: MODERATE (most replicated)
        /// Peak individual alpha frequency typically ~10 Hz
        public static let alpha: Float = 10.0
        public static let alphaRange: ClosedRange<Float> = 8.0...12.0

        /// Beta (12-30 Hz) - Associated with active thinking
        /// Evidence for entrainment: MIXED
        public static let beta: Float = 20.0
        public static let betaRange: ClosedRange<Float> = 12.0...30.0

        /// Gamma (30-100 Hz) - Associated with high-level cognition
        /// Evidence for entrainment: EMERGING (40 Hz research ongoing)
        /// Reference: Nature Scientific Reports 2020 (attentional blink)
        public static let gamma: Float = 40.0
        public static let gammaRange: ClosedRange<Float> = 30.0...100.0
    }

    // MARK: - HRV & Breathing (STRONG Evidence)

    /// HRV Coherence based on HeartMath research
    /// Evidence: STRONG (500+ peer-reviewed studies)
    /// Reference: Scientific Reports 2025 (1.8M sessions)
    public enum HRVCoherence {
        /// Low coherence threshold
        public static let low: Double = 40.0
        /// Medium coherence threshold
        public static let medium: Double = 60.0
        /// High coherence threshold
        public static let high: Double = 80.0

        /// Optimal coherence frequency (0.1 Hz = 6 breaths/min)
        /// Evidence: STRONG - Cardiovascular resonance frequency
        /// Reference: HeartMath, multiple RCTs
        public static let optimalFrequencyHz: Double = 0.1
    }

    /// Breathing rates with scientific support
    /// Evidence: STRONG (multiple RCTs, meta-analyses)
    public enum Breathing {
        /// Optimal resonance breathing (5.5-6 breaths/min)
        /// Reference: PubMed 24380741, PMC10412682
        public static let resonanceBreathsPerMinute: Double = 5.5

        /// Standard coherence breathing (6 breaths/min = 0.1 Hz)
        public static let coherenceBreathsPerMinute: Double = 6.0

        /// Inhale duration at resonance (seconds)
        public static let inhaleDuration: Double = 5.0

        /// Exhale duration at resonance (seconds)
        public static let exhaleDuration: Double = 5.5

        /// Breath cycle at resonance (seconds)
        public static let cycleDuration: Double = 10.5
    }

    // MARK: - Amplitude Ranges

    /// Default amplitude for audio features
    public static let defaultAmplitude: Float = 0.3

    /// Minimum amplitude
    public static let minAmplitude: Float = 0.0

    /// Maximum safe amplitude (hearing protection, WHO guidelines)
    public static let maxSafeAmplitude: Float = 0.6

    /// Binaural beat amplitude (subtle, background)
    public static let binauralAmplitude: Float = 0.25

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
