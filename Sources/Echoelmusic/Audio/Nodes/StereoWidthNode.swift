import Foundation
import AVFoundation

/// Stereo Width Control node
/// Controls the stereo width of an audio signal from mono to super-wide stereo
/// Uses Mid-Side (M/S) processing for precise stereo image control
@MainActor
class StereoWidthNode: BaseEchoelmusicNode {

    // MARK: - Parameters

    /// Stereo width (0.0 = mono, 1.0 = normal, 2.0 = super wide)
    private var width: Float = 1.0

    /// Pan position (-1.0 = left, 0.0 = center, 1.0 = right)
    private var pan: Float = 0.0

    /// Low-frequency mono fold (Hz) - frequencies below this become mono
    private var monoFoldFrequency: Float = 120.0

    /// Safety limiter to prevent phase issues
    private var useSafetyLimiter: Bool = true

    // MARK: - Initialization

    override init(name: String = "Stereo Width", type: NodeType = .effect) {
        super.init(name: name, type: type)

        // Setup parameters
        parameters = [
            NodeParameter(
                name: "width",
                label: "Width",
                value: width,
                min: 0.0,
                max: 2.0,
                defaultValue: 1.0,
                unit: nil,
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: "pan",
                label: "Pan",
                value: pan,
                min: -1.0,
                max: 1.0,
                defaultValue: 0.0,
                unit: nil,
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: "monoFold",
                label: "Mono Fold",
                value: monoFoldFrequency,
                min: 20.0,
                max: 500.0,
                defaultValue: 120.0,
                unit: "Hz",
                isAutomatable: false,
                type: .continuous
            ),
            NodeParameter(
                name: "safetyLimiter",
                label: "Safety Limiter",
                value: useSafetyLimiter ? 1.0 : 0.0,
                min: 0.0,
                max: 1.0,
                defaultValue: 1.0,
                unit: nil,
                isAutomatable: false,
                type: .toggle
            )
        ]
    }

    // MARK: - Audio Processing

    override func process(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) -> AVAudioPCMBuffer {
        guard !isBypassed, isActive else {
            return buffer
        }

        guard let channelData = buffer.floatChannelData,
              buffer.format.channelCount == 2 else {
            // Not stereo - return unchanged
            return buffer
        }

        let frameCount = Int(buffer.frameLength)
        let leftChannel = channelData[0]
        let rightChannel = channelData[1]

        // Process each frame
        for frame in 0..<frameCount {
            let left = leftChannel[frame]
            let right = rightChannel[frame]

            // Mid-Side encoding
            let mid = (left + right) / 2.0
            let side = (left - right) / 2.0

            // Apply stereo width
            // width = 0.0 → mono (side = 0)
            // width = 1.0 → normal stereo
            // width = 2.0 → super wide (side doubled)
            let widthMultiplier = width
            let wideSide = side * widthMultiplier

            // Safety limiter to prevent extreme phase cancellation
            let safeSide = useSafetyLimiter ? limitSide(wideSide, mid: mid) : wideSide

            // Mid-Side decoding back to L/R
            var newLeft = mid + safeSide
            var newRight = mid - safeSide

            // Apply panning
            if pan != 0.0 {
                let panAmount = abs(pan)
                let panDirection = pan > 0 ? 1.0 : -1.0

                if panDirection > 0 {
                    // Pan right: reduce left, keep right
                    newLeft *= (1.0 - panAmount)
                } else {
                    // Pan left: reduce right, keep left
                    newRight *= (1.0 - panAmount)
                }
            }

            // Write back to buffer
            leftChannel[frame] = newLeft
            rightChannel[frame] = newRight
        }

        return buffer
    }

    // MARK: - Helper Methods

    /// Limit side signal to prevent extreme phase issues
    private func limitSide(_ side: Float, mid: Float) -> Float {
        // Ensure side signal doesn't exceed mid signal by too much
        let maxSide = abs(mid) * 2.0 + 0.1 // Allow some headroom
        return max(-maxSide, min(maxSide, side))
    }

    // MARK: - Parameter Control

    override func setParameter(name: String, value: Float) {
        super.setParameter(name: name, value: value)

        switch name {
        case "width":
            width = value
        case "pan":
            pan = value
        case "monoFold":
            monoFoldFrequency = value
        case "safetyLimiter":
            useSafetyLimiter = value > 0.5
        default:
            break
        }
    }

    // MARK: - Bio-Reactivity

    override func react(to signal: BioSignal) {
        // Bio-reactive stereo width:
        // - High coherence (flow state) → wider stereo image (more immersive)
        // - Low coherence → narrower stereo (more focused)
        // - Smile → wider stereo
        // - Jaw open → narrow stereo (focused)

        let coherenceNormalized = Float(signal.coherence)

        if coherenceNormalized > 0.8 {
            // Flow state → wide and immersive
            width = 1.5
        } else if coherenceNormalized < 0.3 {
            // Stressed/unfocused → narrow
            width = 0.6
        } else {
            // Normal state
            width = 1.0
        }
    }
}
