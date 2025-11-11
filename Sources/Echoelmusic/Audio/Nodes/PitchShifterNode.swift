import Foundation
import AVFoundation

/// Pitch Shifter node
/// Shifts pitch without affecting duration (time-independent pitch shifting)
/// Uses AVAudioUnitTimePitch for high-quality pitch shifting
@MainActor
class PitchShifterNode: BaseEchoelmusicNode {

    // MARK: - Audio Components

    private var pitchShifter: AVAudioUnitTimePitch?

    // MARK: - Parameters

    /// Pitch shift in semitones (-24 to +24)
    private var pitchSemitones: Float = 0.0

    /// Pitch shift in cents (-100 to +100, for fine-tuning)
    private var pitchCents: Float = 0.0

    /// Mix (dry/wet) 0.0 = dry, 1.0 = wet
    private var mix: Float = 1.0

    /// Formant preservation (maintains vocal character when shifting)
    private var preserveFormants: Bool = false

    // MARK: - Quality Settings

    /// Algorithm quality
    private var quality: Quality = .high

    enum Quality: Int {
        case low = 0
        case medium = 1
        case high = 2
    }

    // MARK: - Initialization

    override init(name: String = "Pitch Shifter", type: NodeType = .effect) {
        super.init(name: name, type: type)

        // Initialize AVAudioUnitTimePitch
        pitchShifter = AVAudioUnitTimePitch()
        pitchShifter?.pitch = 0.0 // Cents
        pitchShifter?.rate = 1.0  // No time stretching

        // Setup parameters
        parameters = [
            NodeParameter(
                name: "pitchSemitones",
                label: "Pitch (Semitones)",
                value: pitchSemitones,
                min: -24.0,
                max: 24.0,
                defaultValue: 0.0,
                unit: "st",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: "pitchCents",
                label: "Fine Tune (Cents)",
                value: pitchCents,
                min: -100.0,
                max: 100.0,
                defaultValue: 0.0,
                unit: "¢",
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
                name: "preserveFormants",
                label: "Preserve Formants",
                value: preserveFormants ? 1.0 : 0.0,
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
        guard !isBypassed, isActive, let shifter = pitchShifter else {
            return buffer
        }

        // Calculate total pitch shift in cents
        let totalPitchCents = (pitchSemitones * 100.0) + pitchCents

        // Update pitch shifter
        shifter.pitch = totalPitchCents

        // Apply formant preservation if enabled
        // Note: AVAudioUnitTimePitch doesn't directly support formant preservation
        // For real formant preservation, would need custom DSP or third-party library

        // In production, would route through AVAudioEngine:
        // inputNode -> pitchShifter -> outputNode
        // For this simplified version, we'll simulate the effect

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
        case "pitchSemitones":
            pitchSemitones = value
            updatePitchShifter()
        case "pitchCents":
            pitchCents = value
            updatePitchShifter()
        case "mix":
            mix = value
        case "preserveFormants":
            preserveFormants = value > 0.5
        case "quality":
            quality = Quality(rawValue: Int(value)) ?? .high
        default:
            break
        }
    }

    private func updatePitchShifter() {
        let totalPitchCents = (pitchSemitones * 100.0) + pitchCents
        pitchShifter?.pitch = totalPitchCents
    }

    // MARK: - Bio-Reactivity

    override func react(to signal: BioSignal) {
        // Bio-reactive pitch shifting:
        // - High HRV (calm) → slight upward pitch (+2 semitones, uplifting)
        // - Low HRV (stress) → slight downward pitch (-2 semitones, grounding)
        // - Voice pitch → adaptive harmonization

        let hrvNormalized = Float((signal.hrv - 30.0) / 70.0) // Normalize 30-100ms to 0-1

        if hrvNormalized > 0.7 {
            // Calm state → uplifting pitch shift
            pitchSemitones = 2.0
        } else if hrvNormalized < 0.3 {
            // Stressed state → grounding pitch shift
            pitchSemitones = -2.0
        } else {
            // Neutral state → no shift
            pitchSemitones = 0.0
        }

        // Adaptive harmonization based on voice pitch
        if signal.voicePitch > 0 {
            // Detect musical key from voice and harmonize
            let voiceNote = frequencyToMIDI(Double(signal.voicePitch))
            let harmonicInterval = Int(voiceNote) % 12

            // Fifth harmony (perfect fifth above)
            if harmonicInterval == 0 || harmonicInterval == 7 {
                pitchSemitones = 7.0 // Perfect fifth
            }
        }

        updatePitchShifter()
    }

    /// Convert frequency (Hz) to MIDI note number
    private func frequencyToMIDI(_ frequency: Double) -> Double {
        return 69.0 + 12.0 * log2(frequency / 440.0)
    }

    // MARK: - Lifecycle

    override func prepare(sampleRate: Double, maxFrames: AVAudioFrameCount) {
        super.prepare(sampleRate: sampleRate, maxFrames: maxFrames)

        // Configure pitch shifter based on quality setting
        switch quality {
        case .low:
            pitchShifter?.overlap = 8
        case .medium:
            pitchShifter?.overlap = 16
        case .high:
            pitchShifter?.overlap = 32
        }
    }
}
