import Foundation
import AVFoundation
import os.log

// ═══════════════════════════════════════════════════════════════════════════════
// ECHOELMUSIC AUDIO CONSTANTS & CONFIGURATION
// ═══════════════════════════════════════════════════════════════════════════════
//
// Centralized configuration for all audio, MIDI, visual, and system parameters.
// Eliminates magic numbers and hardcoded values throughout the codebase.
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Unified Logger

/// Centralized logging system using os.log for production-quality logging
/// Replaces all print() statements for proper log level management
enum EchoelLogger {

    private static let subsystem = "com.echoelmusic"

    // Category-specific loggers
    static let audio = Logger(subsystem: subsystem, category: "Audio")
    static let midi = Logger(subsystem: subsystem, category: "MIDI")
    static let bio = Logger(subsystem: subsystem, category: "Bio")
    static let visual = Logger(subsystem: subsystem, category: "Visual")
    static let spatial = Logger(subsystem: subsystem, category: "Spatial")
    static let system = Logger(subsystem: subsystem, category: "System")
    static let network = Logger(subsystem: subsystem, category: "Network")
    static let performance = Logger(subsystem: subsystem, category: "Performance")
    static let healing = Logger(subsystem: subsystem, category: "SelfHealing")
    static let quantum = Logger(subsystem: subsystem, category: "Quantum")
    static let gesture = Logger(subsystem: subsystem, category: "Gesture")
    static let recording = Logger(subsystem: subsystem, category: "Recording")

    /// Log info message (production-safe)
    static func info(_ message: String, category: Logger = system) {
        category.info("\(message, privacy: .public)")
    }

    /// Log debug message (development only - compiled out in release)
    static func debug(_ message: String, category: Logger = system) {
        #if DEBUG
        category.debug("🔍 \(message, privacy: .public)")
        #endif
    }

    /// Log warning message
    static func warning(_ message: String, category: Logger = system) {
        category.warning("⚠️ \(message, privacy: .public)")
    }

    /// Log error message
    static func error(_ message: String, category: Logger = system) {
        category.error("❌ \(message, privacy: .public)")
    }

    /// Log critical error
    static func critical(_ message: String, category: Logger = system) {
        category.critical("🚨 \(message, privacy: .public)")
    }

    /// Log success message
    static func success(_ message: String, category: Logger = system) {
        category.info("✅ \(message, privacy: .public)")
    }

    /// Log with custom emoji
    static func log(_ emoji: String, _ message: String, category: Logger = system) {
        category.info("\(emoji) \(message, privacy: .public)")
    }
}

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

    /// Healing Carrier Frequency (432 Hz - "Natürliche Frequenz")
    static let healingCarrierFrequency: Float = 432.0

    /// Standard Carrier Frequency (440 Hz - A4)
    static let standardCarrierFrequency: Float = 440.0

    /// Brainwave Beat Frequencies
    enum Brainwave {
        /// Delta (2 Hz) - Tiefschlaf, Heilung
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

    /// Default Amplitude für Binaural Beats
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

// MARK: - MIDI Constants

/// Centralized MIDI configuration constants
enum MIDIConstants {

    // MARK: - Channel Limits

    /// Maximum MIDI channel (0-15)
    static let maxChannel: UInt8 = 15

    /// Maximum MIDI note (0-127)
    static let maxNote: UInt8 = 127

    /// Maximum MIDI velocity (0-127 for MIDI 1.0)
    static let maxVelocity: UInt8 = 127

    /// Maximum CC value (0-127 for MIDI 1.0)
    static let maxCCValue: UInt8 = 127

    // MARK: - MPE Configuration

    /// Default MPE member channels
    static let defaultMPEMemberChannels: Int = 15

    /// Default pitch bend range in semitones
    static let defaultPitchBendSemitones: Int = 48

    /// Maximum pitch bend range in semitones
    static let maxPitchBendSemitones: Int = 96

    // MARK: - Common CC Numbers

    enum CC {
        static let modWheel: UInt8 = 1
        static let breathController: UInt8 = 2
        static let volume: UInt8 = 7
        static let pan: UInt8 = 10
        static let expression: UInt8 = 11
        static let sustainPedal: UInt8 = 64
        static let resonance: UInt8 = 71
        static let releaseTime: UInt8 = 72
        static let attackTime: UInt8 = 73
        static let brightness: UInt8 = 74
        static let allSoundOff: UInt8 = 120
        static let allNotesOff: UInt8 = 123
    }

    // MARK: - Validation

    /// Validate MIDI channel
    static func isValidChannel(_ channel: UInt8) -> Bool {
        channel <= maxChannel
    }

    /// Validate MIDI note
    static func isValidNote(_ note: UInt8) -> Bool {
        note <= maxNote
    }

    /// Clamp velocity to valid range (0.0-1.0)
    static func clampVelocity(_ velocity: Float) -> Float {
        velocity.clamped(to: 0.0...1.0)
    }

    /// Clamp pitch bend to valid range (-1.0 to 1.0)
    static func clampPitchBend(_ bend: Float) -> Float {
        bend.clamped(to: -1.0...1.0)
    }
}

// MARK: - Control Loop Constants

/// Centralized control loop configuration
enum ControlLoopConstants {

    /// Target frequency for UnifiedControlHub (Hz)
    static let unifiedControlFrequency: Double = 60.0

    /// Target frequency for EchoelUniversalCore (Hz)
    static let universalCoreFrequency: Double = 120.0

    /// Target frequency for SelfHealingEngine rapid check (Hz)
    static let selfHealingRapidFrequency: Double = 10.0

    /// Target frequency for SelfHealingEngine deep analysis (Hz)
    static let selfHealingDeepFrequency: Double = 1.0

    /// Bio-parameter mapping update frequency (Hz)
    static let bioParameterUpdateFrequency: Double = 10.0

    /// Frequency tolerance for isRunningAtTarget (Hz)
    static let frequencyTolerance: Double = 5.0

    /// Calculate interval from frequency
    static func interval(forFrequency frequency: Double) -> TimeInterval {
        1.0 / frequency
    }
}

// MARK: - Visual Constants

/// Centralized visual configuration constants
enum VisualConstants {

    /// Target frame rate
    static let targetFrameRate: Float = 60.0

    /// Minimum frame rate
    static let minFrameRate: Float = 30.0

    /// Maximum frame rate (ProMotion)
    static let maxFrameRate: Float = 120.0

    /// Default visual quality (0-1)
    static let defaultVisualQuality: Float = 1.0

    /// Emergency visual quality
    static let emergencyVisualQuality: Float = 0.3

    /// Default visual complexity (0-1)
    static let defaultVisualComplexity: Float = 1.0
}

// MARK: - Bio Constants

/// Centralized biofeedback configuration constants
enum BioConstants {

    /// Optimal resting heart rate (BPM)
    static let optimalHeartRate: Float = 60.0

    /// Normal HRV range (ms)
    static let normalHRVRange: ClosedRange<Float> = 20.0...100.0

    /// High coherence threshold
    static let highCoherenceThreshold: Double = 60.0

    /// Low coherence threshold
    static let lowCoherenceThreshold: Double = 40.0

    /// Default breathing rate (breaths per minute)
    static let defaultBreathingRate: Float = 6.0

    /// Bio sample tolerance multiplier
    static let defaultBioSampleTolerance: Float = 1.0

    /// Maximum bio sample tolerance
    static let maxBioSampleTolerance: Float = 5.0
}

// MARK: - System Constants

/// Centralized system configuration constants
enum SystemConstants {

    /// Maximum healing events to retain
    static let maxHealingEvents: Int = 1000

    /// Optimal streak threshold for flow state
    static let optimalStreakForFlow: Int = 20

    /// Optimal streak threshold for ultra flow state
    static let optimalStreakForUltraFlow: Int = 100

    /// CPU usage threshold for degraded health
    static let cpuDegradedThreshold: Float = 0.8

    /// CPU usage threshold for critical health
    static let cpuCriticalThreshold: Float = 0.95

    /// Memory usage threshold for degraded health
    static let memoryDegradedThreshold: Float = 0.8

    /// Memory usage threshold for critical health
    static let memoryCriticalThreshold: Float = 0.95

    /// Memory cleanup interval (seconds)
    static let memoryCleanupInterval: TimeInterval = 30.0

    /// Error prediction history size
    static let errorPredictionHistorySize: Int = 20

    /// AI suggestion auto-apply confidence threshold
    static let aiAutoApplyConfidenceThreshold: Float = 0.8
}

// MARK: - Network Constants

/// Centralized network configuration constants
enum NetworkConstants {

    /// Default sync frequency (Hz)
    static let defaultSyncFrequency: Float = 60.0

    /// Minimum sync frequency (Hz)
    static let minSyncFrequency: Float = 5.0

    /// Default sync precision
    static let defaultSyncPrecision: Float = 0.5

    /// Maximum sync precision
    static let maxSyncPrecision: Float = 1.0

    /// DMX Art-Net port
    static let artNetPort: UInt16 = 6454

    /// OSC default port
    static let oscDefaultPort: UInt16 = 8000
}

// MARK: - Float Extension for Clamping

extension Float {
    /// Clamp value to specified range
    func clamped(to range: ClosedRange<Float>) -> Float {
        max(range.lowerBound, min(range.upperBound, self))
    }
}

extension Double {
    /// Clamp value to specified range
    func clamped(to range: ClosedRange<Double>) -> Double {
        max(range.lowerBound, min(range.upperBound, self))
    }
}
