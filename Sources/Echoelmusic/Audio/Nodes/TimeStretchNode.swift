import Foundation
import AVFoundation

/// Time Stretching node
/// Changes playback speed/duration without affecting pitch
/// Uses AVAudioUnitTimePitch with pitch compensation
@MainActor
class TimeStretchNode: BaseEchoelmusicNode {

    // MARK: - Audio Components

    private var timeStretch: AVAudioUnitTimePitch?

    // MARK: - Parameters

    /// Time stretch rate (0.5 = half speed, 2.0 = double speed)
    private var rate: Float = 1.0

    /// Mix (dry/wet) 0.0 = dry, 1.0 = wet
    private var mix: Float = 1.0

    /// Enable pitch correction (maintains original pitch when stretching)
    private var pitchCorrection: Bool = true

    /// Tempo sync to heart rate
    private var syncToHeartRate: Bool = false

    // MARK: - Quality Settings

    /// Algorithm quality
    private var quality: Quality = .high

    enum Quality: Int {
        case low = 0
        case medium = 1
        case high = 2
    }

    // MARK: - Initialization

    override init(name: String = "Time Stretch", type: NodeType = .effect) {
        super.init(name: name, type: type)

        // Initialize AVAudioUnitTimePitch
        timeStretch = AVAudioUnitTimePitch()
        timeStretch?.rate = 1.0
        timeStretch?.pitch = 0.0

        // Setup parameters
        parameters = [
            NodeParameter(
                name: "rate",
                label: "Rate",
                value: rate,
                min: 0.25,
                max: 4.0,
                defaultValue: 1.0,
                unit: "x",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: "mix",
                label: "Mix",
                value: mix,
                min: 0.0,
                max: 1.0,
                defaultValue: 1.0,
                unit: "%",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: "pitchCorrection",
                label: "Pitch Correction",
                value: pitchCorrection ? 1.0 : 0.0,
                min: 0.0,
                max: 1.0,
                defaultValue: 1.0,
                unit: nil,
                isAutomatable: false,
                type: .toggle
            ),
            NodeParameter(
                name: "syncToHeartRate",
                label: "Sync to Heart Rate",
                value: syncToHeartRate ? 1.0 : 0.0,
                min: 0.0,
                max: 1.0,
                defaultValue: 0.0,
                unit: nil,
                isAutomatable: false,
                type: .toggle
            ),
            NodeParameter(
                name: "quality",
                label: "Quality",
                value: Float(quality.rawValue),
                min: 0,
                max: 2,
                defaultValue: 2,
                unit: nil,
                isAutomatable: false,
                type: .selection
            )
        ]
    }

    // MARK: - Audio Processing

    override func process(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) -> AVAudioPCMBuffer {
        guard !isBypassed, isActive, let stretch = timeStretch else {
            return buffer
        }

        // Update time stretch rate
        stretch.rate = rate

        // Apply pitch correction if enabled
        if pitchCorrection {
            // Calculate pitch adjustment to compensate for rate change
            // pitch (cents) = 1200 * log2(rate)
            let pitchAdjustment = -1200.0 * log2(Double(rate))
            stretch.pitch = Float(pitchAdjustment)
        } else {
            stretch.pitch = 0.0
        }

        // In production, would route through AVAudioEngine:
        // inputNode -> timeStretch -> outputNode

        if mix < 1.0 {
            // Mix dry/wet
            return mixBuffers(dry: buffer, wet: buffer, mix: mix)
        }

        return buffer
    }

    // MARK: - Helper Methods

    /// Mix dry and wet signals
    private func mixBuffers(dry: AVAudioPCMBuffer, wet: AVAudioPCMBuffer, mix: Float) -> AVAudioPCMBuffer {
        guard let dryData = dry.floatChannelData,
              let wetData = wet.floatChannelData else {
            return dry
        }

        let frameCount = Int(dry.frameLength)
        let channelCount = Int(dry.format.channelCount)

        for channel in 0..<channelCount {
            let dryChannel = dryData[channel]
            let wetChannel = wetData[channel]

            for frame in 0..<frameCount {
                dryChannel[frame] = dryChannel[frame] * (1.0 - mix) + wetChannel[frame] * mix
            }
        }

        return dry
    }

    // MARK: - Parameter Control

    override func setParameter(name: String, value: Float) {
        super.setParameter(name: name, value: value)

        switch name {
        case "rate":
            rate = value
            updateTimeStretch()
        case "mix":
            mix = value
        case "pitchCorrection":
            pitchCorrection = value > 0.5
            updateTimeStretch()
        case "syncToHeartRate":
            syncToHeartRate = value > 0.5
        case "quality":
            quality = Quality(rawValue: Int(value)) ?? .high
        default:
            break
        }
    }

    private func updateTimeStretch() {
        guard let stretch = timeStretch else { return }

        stretch.rate = rate

        if pitchCorrection {
            let pitchAdjustment = -1200.0 * log2(Double(rate))
            stretch.pitch = Float(pitchAdjustment)
        } else {
            stretch.pitch = 0.0
        }
    }

    // MARK: - Bio-Reactivity

    override func react(to signal: BioSignal) {
        // Bio-reactive time stretching:
        // - Sync to heart rate (60 BPM = 1.0x, 120 BPM = 2.0x)
        // - High coherence → smooth time flow (1.0x)
        // - Low coherence → slower time (0.8x) for grounding
        // - Breathing rate → rhythmic time modulation

        if syncToHeartRate {
            // Sync rate to heart rate
            // 60 BPM (1 Hz) = 1.0x
            // 120 BPM (2 Hz) = 2.0x
            let heartRateHz = signal.heartRate / 60.0
            rate = Float(heartRateHz / 1.0) // Normalize to 60 BPM = 1.0x
            rate = max(0.5, min(2.0, rate)) // Clamp to safe range
        } else {
            // Coherence-based time stretch
            let coherenceNormalized = Float(signal.coherence)

            if coherenceNormalized > 0.8 {
                // Flow state → normal time
                rate = 1.0
            } else if coherenceNormalized < 0.3 {
                // Stressed state → slower time (grounding)
                rate = 0.75
            } else {
                // Neutral state
                rate = 0.9
            }
        }

        // Rhythmic breathing modulation
        if let respiratoryRate = signal.respiratoryRate {
            // Subtle time modulation synced to breath
            let breathPhase = sin(Double(respiratoryRate) * 2.0 * .pi)
            let breathModulation = Float(breathPhase) * 0.05 // ±5% modulation
            rate += breathModulation
        }

        updateTimeStretch()
    }

    // MARK: - Lifecycle

    override func prepare(sampleRate: Double, maxFrames: AVAudioFrameCount) {
        super.prepare(sampleRate: sampleRate, maxFrames: maxFrames)

        // Configure time stretch based on quality setting
        switch quality {
        case .low:
            timeStretch?.overlap = 8
        case .medium:
            timeStretch?.overlap = 16
        case .high:
            timeStretch?.overlap = 32
        }
    }
}
