import Foundation

/// Bio-signal data for bio-reactive audio processing
/// Represents biometric measurements that can modulate audio parameters
public struct BioSignal: Sendable {

    /// Heart rate variability (ms)
    public var hrv: Double

    /// Heart rate (BPM)
    public var heartRate: Double

    /// HRV coherence score (0-100, HeartMath algorithm)
    public var coherence: Double

    /// Respiratory rate (breaths per minute)
    public var respiratoryRate: Double?

    /// Audio level (0.0 - 1.0)
    public var audioLevel: Float

    /// Voice pitch (Hz)
    public var voicePitch: Float

    /// Custom extensible data
    public var customData: [String: String]

    public init(
        hrv: Double = 0,
        heartRate: Double = 60,
        coherence: Double = 50,
        respiratoryRate: Double? = nil,
        audioLevel: Float = 0,
        voicePitch: Float = 0,
        customData: [String: String] = [:]
    ) {
        self.hrv = hrv
        self.heartRate = heartRate
        self.coherence = coherence
        self.respiratoryRate = respiratoryRate
        self.audioLevel = audioLevel
        self.voicePitch = voicePitch
        self.customData = customData
    }
}
