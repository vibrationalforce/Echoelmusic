import Foundation
import AVFoundation

/// Reverb effect node with bio-reactive parameters
/// HRV Coherence → Reverb Wetness (higher coherence = more reverb = spacious feeling)
@MainActor
class ReverbNode: BaseBlabNode {

    // MARK: - AVAudioUnit Reverb

    private let reverbUnit: AVAudioUnitReverb


    // MARK: - Parameters

    private enum Params {
        static let wetDry = "wetDry"
        static let smallRoomSize = "smallRoomSize"
        static let mediumRoomSize = "mediumRoomSize"
        static let largeRoomSize = "largeRoomSize"
    }


    // MARK: - Initialization

    init() {
        self.reverbUnit = AVAudioUnitReverb()

        super.init(name: "Bio-Reactive Reverb", type: .effect)

        // Setup parameters
        parameters = [
            NodeParameter(
                name: Params.wetDry,
                label: "Wet/Dry Mix",
                value: 30.0,
                min: 0.0,
                max: 100.0,
                defaultValue: 30.0,
                unit: "%",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: Params.smallRoomSize,
                label: "Small Room Size",
                value: 0.0,
                min: 0.0,
                max: 100.0,
                defaultValue: 0.0,
                unit: "%",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: Params.mediumRoomSize,
                label: "Medium Room Size",
                value: 50.0,
                min: 0.0,
                max: 100.0,
                defaultValue: 50.0,
                unit: "%",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: Params.largeRoomSize,
                label: "Large Room Size",
                value: 0.0,
                min: 0.0,
                max: 100.0,
                defaultValue: 0.0,
                unit: "%",
                isAutomatable: true,
                type: .continuous
            )
        ]

        // Configure reverb
        reverbUnit.wetDryMix = 30.0  // 30% wet
        reverbUnit.loadFactoryPreset(.mediumHall)
    }


    // MARK: - Audio Processing

    // MARK: - Reverb State

    private var delayBuffer: [[Float]] = []
    private var delayIndices: [Int] = []
    private let delaySizes = [1557, 1617, 1491, 1422, 1277, 1356, 1188, 1116]  // Prime numbers for natural reverb

    override func process(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) -> AVAudioPCMBuffer {
        // If bypassed, return original buffer
        guard !isBypassed, isActive else {
            return buffer
        }

        // Apply reverb parameters
        if let wetDry = getParameter(name: Params.wetDry) {
            reverbUnit.wetDryMix = wetDry
        }

        // Simple reverb using multiple delay lines (Schroeder reverb)
        guard let channelData = buffer.floatChannelData else { return buffer }
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        // Initialize delay buffers if needed
        if delayBuffer.isEmpty {
            delayBuffer = delaySizes.map { Array(repeating: Float(0), count: $0) }
            delayIndices = Array(repeating: 0, count: delaySizes.count)
        }

        if let wetDryMix = getParameter(name: Params.wetDry) {
            let wet = wetDryMix / 100.0
            let dry = 1.0 - wet
            let decay: Float = 0.5  // Reverb decay factor

            for channel in 0..<channelCount {
                let samples = UnsafeMutablePointer<Float>(channelData[channel])

                for frame in 0..<frameCount {
                    var reverbSample: Float = 0.0

                    // Sum all delay lines
                    for (i, delaySize) in delaySizes.enumerated() {
                        let delayedSample = delayBuffer[i][delayIndices[i]]
                        reverbSample += delayedSample

                        // Write to delay line with feedback
                        delayBuffer[i][delayIndices[i]] = samples[frame] + delayedSample * decay

                        // Increment delay index
                        delayIndices[i] = (delayIndices[i] + 1) % delaySize
                    }

                    // Mix wet and dry
                    reverbSample *= Float(wet) / Float(delaySizes.count)
                    samples[frame] = samples[frame] * Float(dry) + reverbSample
                }
            }
        }

        return buffer
    }


    // MARK: - Bio-Reactivity

    override func react(to signal: BioSignal) {
        // HRV Coherence → Reverb Wetness
        // 0-40: Low coherence (stressed) → Dry (10-30% wet)
        // 40-60: Medium coherence → Medium (30-50% wet)
        // 60-100: High coherence (flow state) → Wet (50-80% wet)

        let coherence = signal.coherence

        let targetWetness: Float
        if coherence < 40 {
            // Stressed: less reverb
            targetWetness = 10.0 + Float(coherence / 40.0) * 20.0  // 10-30%
        } else if coherence < 60 {
            // Transitional: medium reverb
            targetWetness = 30.0 + Float((coherence - 40.0) / 20.0) * 20.0  // 30-50%
        } else {
            // Flow state: more reverb (spacious, expansive feeling)
            targetWetness = 50.0 + Float((coherence - 60.0) / 40.0) * 30.0  // 50-80%
        }

        // Smooth transition
        if let currentWetness = getParameter(name: Params.wetDry) {
            let smoothed = currentWetness * 0.95 + targetWetness * 0.05
            setParameter(name: Params.wetDry, value: smoothed)
        }

        // HRV → Room Size (higher HRV = larger room)
        let targetRoomSize = Float(min(signal.hrv / 100.0, 1.0)) * 100.0  // 0-100%
        if let currentRoomSize = getParameter(name: Params.mediumRoomSize) {
            let smoothed = currentRoomSize * 0.98 + targetRoomSize * 0.02
            setParameter(name: Params.mediumRoomSize, value: smoothed)
        }
    }


    // MARK: - Lifecycle

    override func prepare(sampleRate: Double, maxFrames: AVAudioFrameCount) {
        // Reverb is always ready (uses AVAudioUnitReverb)
    }

    override func start() {
        super.start()
        print("🎵 ReverbNode started")
    }

    override func stop() {
        super.stop()
        print("🎵 ReverbNode stopped")
    }
}
