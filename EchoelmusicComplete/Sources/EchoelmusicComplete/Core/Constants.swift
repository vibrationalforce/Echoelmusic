// Constants.swift
// App-wide configuration constants

import Foundation

public enum AppConstants {
    // MARK: - App Info
    public static let appName = "Echoelmusic"
    public static let version = "1.0.0"
    public static let build = "1"

    // MARK: - Audio
    public static let sampleRate: Double = 44100
    public static let bufferSize: Int = 256
    public static let defaultVolume: Float = 0.7
    public static let baseFrequency: Float = 432.0  // A4 natural tuning

    // MARK: - Biofeedback
    public static let bioUpdateRate: Double = 1.0  // Hz
    public static let hrvBufferSize: Int = 120     // ~60 seconds at 60 BPM
    public static let coherenceSmoothing: Double = 0.3

    // MARK: - Visualization
    public static let visualUpdateRate: Double = 60.0  // FPS
    public static let particleCount: Int = 100
    public static let mandalaLayers: Int = 3

    // MARK: - OSC
    public static let oscSendPort: UInt16 = 8000
    public static let oscReceivePort: UInt16 = 9000
    public static let oscAddressPrefix = "/echoelmusic"

    // MARK: - Performance
    public static let maxCPUPercent: Double = 25.0
    public static let maxMemoryMB: Int = 150
    public static let targetLatencyMs: Double = 10.0
}

// MARK: - Audio Frequencies

public enum AudioFrequencies {
    // Brainwave entrainment frequencies (scientifically grounded)
    public static let delta: Float = 2.0    // Deep sleep, regeneration
    public static let theta: Float = 6.0    // Meditation, creativity
    public static let alpha: Float = 10.0   // Relaxation, learning
    public static let beta: Float = 20.0    // Focus, alertness
    public static let gamma: Float = 40.0   // Peak cognition (MIT GENUS research)

    // Standard tuning (ISO 16)
    public static let a4Standard: Float = 440.0
    public static let a4Verdi: Float = 432.0  // Historical preference, no scientific basis

    // Carrier frequencies for binaural
    public static let binauralCarrier: Float = 200.0

    // Schumann resonance (Earth's natural EM frequency - for reference only)
    public static let schumannResonance: Float = 7.83
}

// MARK: - Health Disclaimer

public enum HealthDisclaimer {
    public static let short = """
    This app is for relaxation and creativity only. \
    NOT a medical device.
    """

    public static let full = """
    IMPORTANT HEALTH DISCLAIMER

    Echoelmusic is designed for relaxation, creativity, and general wellness purposes only.

    This application:
    • Is NOT a medical device
    • Does NOT provide medical advice
    • Should NOT be used to diagnose, treat, cure, or prevent any disease
    • Is NOT a substitute for professional medical care

    The biometric readings (heart rate, HRV, coherence) are for informational and creative purposes only. Always consult a qualified healthcare provider for any health concerns.

    If you experience any discomfort during use, stop immediately and consult a medical professional.

    © 2026 Echoelmusic - For relaxation and creativity only.
    """

    public static let binaural = """
    Multidimensional Brainwave Entrainment should not be used while driving or operating machinery. \
    If you have epilepsy or are prone to seizures, consult a doctor before use.
    """
}
