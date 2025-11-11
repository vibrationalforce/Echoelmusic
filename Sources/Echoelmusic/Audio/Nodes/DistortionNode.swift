import Foundation
import AVFoundation

/// Distortion audio effect node
/// Provides multiple distortion types: soft clip, hard clip, waveshaping, bit crushing
@MainActor
class DistortionNode: BaseEchoelmusicNode {

    // MARK: - Audio Components

    private var distortionEffect: AVAudioUnitDistortion?

    // MARK: - Parameters

    /// Distortion amount (0.0 - 100.0)
    private var amount: Float = 50.0

    /// Distortion type
    private var distortionType: DistortionType = .softClip

    /// Pre-gain (dB)
    private var preGain: Float = 0.0

    /// Output gain (dB)
    private var outputGain: Float = -6.0

    /// Mix (dry/wet) 0.0 = dry, 1.0 = wet
    private var mix: Float = 1.0

    // MARK: - Distortion Types

    enum DistortionType: Int {
        case softClip = 0
        case hardClip = 1
        case waveshaping = 2
        case bitCrushing = 3
        case overdrive = 4
        case fuzz = 5
    }

    // MARK: - Initialization

    override init(name: String = "Distortion", type: NodeType = .effect) {
        super.init(name: name, type: type)

        // Initialize AVAudioUnitDistortion
        distortionEffect = AVAudioUnitDistortion()
        distortionEffect?.loadFactoryPreset(.drumsBitBrush) // Default preset

        // Setup parameters
        parameters = [
            NodeParameter(
                name: "amount",
                label: "Amount",
                value: amount,
                min: 0.0,
                max: 100.0,
                defaultValue: 50.0,
                unit: "%",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: "type",
                label: "Type",
                value: Float(distortionType.rawValue),
                min: 0,
                max: 5,
                defaultValue: 0,
                unit: nil,
                isAutomatable: false,
                type: .selection
            ),
            NodeParameter(
                name: "preGain",
                label: "Pre-Gain",
                value: preGain,
                min: -20.0,
                max: 20.0,
                defaultValue: 0.0,
                unit: "dB",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: "outputGain",
                label: "Output Gain",
                value: outputGain,
                min: -40.0,
                max: 0.0,
                defaultValue: -6.0,
                unit: "dB",
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
            )
        ]
    }

    // MARK: - Audio Processing

    override func process(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) -> AVAudioPCMBuffer {
        guard !isBypassed, isActive, let effect = distortionEffect else {
            return buffer
        }

        // Apply distortion (simplified - in real implementation would use AVAudioEngine routing)
        // This is a conceptual implementation showing the signal flow

        // Apply pre-gain
        applyGain(to: buffer, gainDB: preGain)

        // Apply distortion algorithm based on type
        switch distortionType {
        case .softClip:
            applySoftClip(to: buffer, amount: amount / 100.0)
        case .hardClip:
            applyHardClip(to: buffer, threshold: 1.0 - (amount / 100.0))
        case .waveshaping:
            applyWaveshaping(to: buffer, amount: amount / 100.0)
        case .bitCrushing:
            applyBitCrushing(to: buffer, bits: Int(16 - (amount / 100.0 * 12)))
        case .overdrive:
            applyOverdrive(to: buffer, drive: amount / 100.0)
        case .fuzz:
            applyFuzz(to: buffer, intensity: amount / 100.0)
        }

        // Apply output gain
        applyGain(to: buffer, gainDB: outputGain)

        return buffer
    }

    // MARK: - Distortion Algorithms

    private func applySoftClip(to buffer: AVAudioPCMBuffer, amount: Float) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        for channel in 0..<channelCount {
            let data = channelData[channel]
            for frame in 0..<frameCount {
                let sample = data[frame]
                // Soft clipping using tanh
                let clipped = tanh(sample * (1.0 + amount * 5.0))
                data[frame] = clipped * (1.0 - amount) + sample * amount
            }
        }
    }

    private func applyHardClip(to buffer: AVAudioPCMBuffer, threshold: Float) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        for channel in 0..<channelCount {
            let data = channelData[channel]
            for frame in 0..<frameCount {
                let sample = data[frame]
                // Hard clipping
                data[frame] = max(-threshold, min(threshold, sample))
            }
        }
    }

    private func applyWaveshaping(to buffer: AVAudioPCMBuffer, amount: Float) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        for channel in 0..<channelCount {
            let data = channelData[channel]
            for frame in 0..<frameCount {
                let sample = data[frame]
                // Waveshaping using Chebyshev polynomial
                let shaped = sample - (pow(sample, 3) / 3.0) * amount
                data[frame] = shaped
            }
        }
    }

    private func applyBitCrushing(to buffer: AVAudioPCMBuffer, bits: Int) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let levels = Float(1 << bits)

        for channel in 0..<channelCount {
            let data = channelData[channel]
            for frame in 0..<frameCount {
                let sample = data[frame]
                // Bit reduction
                let crushed = floor(sample * levels) / levels
                data[frame] = crushed
            }
        }
    }

    private func applyOverdrive(to buffer: AVAudioPCMBuffer, drive: Float) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        for channel in 0..<channelCount {
            let data = channelData[channel]
            for frame in 0..<frameCount {
                let sample = data[frame]
                // Asymmetric soft clipping (overdrive character)
                let driven = sample * (1.0 + drive * 10.0)
                let overdriven = (2.0 / .pi) * atan(driven)
                data[frame] = overdriven
            }
        }
    }

    private func applyFuzz(to buffer: AVAudioPCMBuffer, intensity: Float) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        for channel in 0..<channelCount {
            let data = channelData[channel]
            for frame in 0..<frameCount {
                let sample = data[frame]
                // Extreme clipping with sign preservation
                let fuzzed = sample > 0 ? min(1.0, sample * (1.0 + intensity * 100.0)) : max(-1.0, sample * (1.0 + intensity * 100.0))
                data[frame] = fuzzed
            }
        }
    }

    private func applyGain(to buffer: AVAudioPCMBuffer, gainDB: Float) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let gain = pow(10.0, gainDB / 20.0) // Convert dB to linear

        for channel in 0..<channelCount {
            let data = channelData[channel]
            for frame in 0..<frameCount {
                data[frame] *= gain
            }
        }
    }

    // MARK: - Parameter Control

    override func setParameter(name: String, value: Float) {
        super.setParameter(name: name, value: value)

        switch name {
        case "amount":
            amount = value
        case "type":
            distortionType = DistortionType(rawValue: Int(value)) ?? .softClip
        case "preGain":
            preGain = value
        case "outputGain":
            outputGain = value
        case "mix":
            mix = value
        default:
            break
        }
    }

    // MARK: - Bio-Reactivity

    override func react(to signal: BioSignal) {
        // Bio-reactive distortion:
        // - Low HRV (stress) → more aggressive distortion
        // - High coherence → smoother distortion

        if signal.hrv < 30 {
            // Stressed state → harder distortion
            distortionType = .hardClip
            amount = 70.0
        } else if signal.coherence > 0.8 {
            // Flow state → warm overdrive
            distortionType = .overdrive
            amount = 40.0
        }
    }
}
