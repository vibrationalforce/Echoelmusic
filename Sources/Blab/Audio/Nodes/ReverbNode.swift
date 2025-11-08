import Foundation
import AVFoundation

/// Reverb effect node with bio-reactive parameters
/// HRV Coherence → Reverb Wetness (higher coherence = more reverb = spacious feeling)
@MainActor
class ReverbNode: BaseBlabNode {

    // MARK: - AVAudioUnit Reverb

    private let reverbUnit: AVAudioUnitReverb

    // MARK: - DSP State

    // Multi-tap delay lines for reverb (Schroeder-style)
    private var combDelays: [[Float]] = []  // 4 comb filters per channel
    private var combIndices: [[Int]] = [[0,0,0,0], [0,0,0,0]]
    private var combDelayTimes: [Int] = [1116, 1188, 1277, 1356]  // Prime numbers for diffusion
    private var allpassDelays: [[Float]] = []  // 2 allpass filters per channel
    private var allpassIndices: [[Int]] = [[0,0], [0,0]]
    private var allpassDelayTimes: [Int] = [225, 556]
    private var currentSampleRate: Double = 44100.0

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

    override func process(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) -> AVAudioPCMBuffer {
        // If bypassed, return original buffer
        guard !isBypassed, isActive else {
            return buffer
        }

        // Get reverb parameters
        guard let wetDry = getParameter(name: Params.wetDry) else {
            return buffer
        }

        // Process audio buffer (in-place)
        guard let channelData = buffer.floatChannelData else {
            return buffer
        }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        let wetGain = wetDry / 100.0
        let dryGain = 1.0 - wetGain
        let combGain: Float = 0.85  // Feedback for comb filters
        let allpassGain: Float = 0.5

        for channel in 0..<min(channelCount, 2) {
            let channelDataPtr = channelData[channel]

            for frame in 0..<frameLength {
                let input = channelDataPtr[frame]

                // Parallel comb filters
                var combSum: Float = 0.0
                for i in 0..<4 {
                    let delayTime = combDelayTimes[i]
                    let bufferIndex = i
                    let readIdx = combIndices[channel][i]

                    if readIdx < combDelays[channel * 4 + bufferIndex].count {
                        let delayed = combDelays[channel * 4 + bufferIndex][readIdx]
                        combSum += delayed

                        // Write with feedback
                        let toWrite = input + combGain * delayed
                        combDelays[channel * 4 + bufferIndex][readIdx] = toWrite

                        // Advance index
                        combIndices[channel][i] = (readIdx + 1) % delayTime
                    }
                }
                combSum *= 0.25  // Average 4 combs

                // Serial allpass filters for diffusion
                var allpassOut = combSum
                for i in 0..<2 {
                    let delayTime = allpassDelayTimes[i]
                    let bufferIndex = i
                    let readIdx = allpassIndices[channel][i]

                    if readIdx < allpassDelays[channel * 2 + bufferIndex].count {
                        let delayed = allpassDelays[channel * 2 + bufferIndex][readIdx]

                        // Allpass: output = -input + delayed
                        let output = -allpassGain * allpassOut + delayed

                        // Write: input + gain * delayed
                        allpassDelays[channel * 2 + bufferIndex][readIdx] = allpassOut + allpassGain * delayed

                        // Advance index
                        allpassIndices[channel][i] = (readIdx + 1) % delayTime

                        allpassOut = output
                    }
                }

                // Mix dry and wet
                let output = dryGain * input + wetGain * allpassOut

                // Write output
                channelDataPtr[frame] = output
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
        currentSampleRate = sampleRate

        // Scale delay times based on sample rate (designed for 44.1kHz)
        let scale = sampleRate / 44100.0
        let scaledCombTimes = combDelayTimes.map { Int(Double($0) * scale) }
        let scaledAllpassTimes = allpassDelayTimes.map { Int(Double($0) * scale) }

        // Allocate comb delay buffers (4 per channel, 2 channels)
        combDelays = []
        for channel in 0..<2 {
            for delayTime in scaledCombTimes {
                combDelays.append(Array(repeating: 0.0, count: delayTime))
            }
        }
        combIndices = [[0,0,0,0], [0,0,0,0]]

        // Allocate allpass delay buffers (2 per channel, 2 channels)
        allpassDelays = []
        for channel in 0..<2 {
            for delayTime in scaledAllpassTimes {
                allpassDelays.append(Array(repeating: 0.0, count: delayTime))
            }
        }
        allpassIndices = [[0,0], [0,0]]

        print("🎵 ReverbNode prepared: Schroeder reverb with 4 combs + 2 allpass")
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
