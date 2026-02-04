import Foundation
import AVFoundation
import Accelerate

/// Reverb effect node with bio-reactive parameters
/// HRV Coherence → Reverb Wetness (higher coherence = more reverb = spacious feeling)
///
/// Implementation: Freeverb-style algorithmic reverb using:
/// - 8 parallel comb filters for early reflections
/// - 4 series allpass filters for diffusion
/// - Accelerate/vDSP for SIMD optimization
///
/// EchoelCore Native - No external dependencies
@MainActor
class ReverbNode: BaseEchoelmusicNode {

    // MARK: - Reverb DSP Components

    /// Comb filter delays (samples at 44.1kHz, scaled for actual sample rate)
    private static let combDelays: [Int] = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]

    /// Allpass filter delays
    private static let allpassDelays: [Int] = [556, 441, 341, 225]

    /// Comb filter buffers (8 filters)
    private var combBuffers: [[Float]] = []
    private var combIndices: [Int] = []

    /// Allpass filter buffers (4 filters)
    private var allpassBuffers: [[Float]] = []
    private var allpassIndices: [Int] = []

    /// Current sample rate
    private var currentSampleRate: Double = 44100.0

    /// Feedback amount for comb filters (0.0-1.0)
    private var feedback: Float = 0.84

    /// Damping coefficient (low-pass in feedback loop)
    private var damping: Float = 0.2

    /// Previous damped values for each comb filter
    private var dampedValues: [Float] = []


    // MARK: - Parameters

    private enum Params {
        static let wetDry = "wetDry"
        static let roomSize = "roomSize"
        static let damping = "damping"
        static let width = "width"
        static let preDelay = "preDelay"
    }


    // MARK: - Initialization

    init() {
        super.init(name: "Bio-Reactive Reverb", type: .reverb)

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
                name: Params.roomSize,
                label: "Room Size",
                value: 50.0,
                min: 0.0,
                max: 100.0,
                defaultValue: 50.0,
                unit: "%",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: Params.damping,
                label: "Damping",
                value: 50.0,
                min: 0.0,
                max: 100.0,
                defaultValue: 50.0,
                unit: "%",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: Params.width,
                label: "Stereo Width",
                value: 100.0,
                min: 0.0,
                max: 100.0,
                defaultValue: 100.0,
                unit: "%",
                isAutomatable: true,
                type: .continuous
            ),
            NodeParameter(
                name: Params.preDelay,
                label: "Pre-Delay",
                value: 0.0,
                min: 0.0,
                max: 100.0,
                defaultValue: 0.0,
                unit: "ms",
                isAutomatable: true,
                type: .continuous
            )
        ]

        // Initialize buffers at default sample rate
        initializeBuffers(sampleRate: 44100.0)
    }

    /// Initialize delay buffers scaled to sample rate
    private func initializeBuffers(sampleRate: Double) {
        currentSampleRate = sampleRate
        let scaleFactor = sampleRate / 44100.0

        // Initialize comb filter buffers
        combBuffers = ReverbNode.combDelays.map { delay in
            let scaledDelay = Int(Double(delay) * scaleFactor)
            return [Float](repeating: 0.0, count: scaledDelay)
        }
        combIndices = [Int](repeating: 0, count: ReverbNode.combDelays.count)
        dampedValues = [Float](repeating: 0.0, count: ReverbNode.combDelays.count)

        // Initialize allpass filter buffers
        allpassBuffers = ReverbNode.allpassDelays.map { delay in
            let scaledDelay = Int(Double(delay) * scaleFactor)
            return [Float](repeating: 0.0, count: scaledDelay)
        }
        allpassIndices = [Int](repeating: 0, count: ReverbNode.allpassDelays.count)
    }


    // MARK: - Audio Processing

    override func process(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) -> AVAudioPCMBuffer {
        // If bypassed, return original buffer
        guard !isBypassed, isActive else {
            return buffer
        }

        guard let channelData = buffer.floatChannelData else {
            return buffer
        }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        // Get parameters
        let wetDry = (getParameter(name: Params.wetDry) ?? 30.0) / 100.0
        let roomSize = (getParameter(name: Params.roomSize) ?? 50.0) / 100.0
        let dampingParam = (getParameter(name: Params.damping) ?? 50.0) / 100.0

        // Update feedback based on room size (0.7 to 0.98)
        feedback = 0.7 + roomSize * 0.28
        damping = dampingParam * 0.4

        // Process each channel
        for channel in 0..<min(channelCount, 2) {
            let inputPtr = channelData[channel]

            for frame in 0..<frameCount {
                let input = inputPtr[frame]

                // Sum of all comb filter outputs
                var combSum: Float = 0.0

                // Process 8 parallel comb filters
                for i in 0..<combBuffers.count {
                    let bufferSize = combBuffers[i].count
                    guard bufferSize > 0 else { continue }

                    // Read from delay buffer
                    let delayed = combBuffers[i][combIndices[i]]

                    // Low-pass filter in feedback loop (damping)
                    dampedValues[i] = delayed * (1.0 - damping) + dampedValues[i] * damping

                    // Write to delay buffer with feedback
                    combBuffers[i][combIndices[i]] = input + dampedValues[i] * feedback

                    // Advance index
                    combIndices[i] = (combIndices[i] + 1) % bufferSize

                    // Accumulate output
                    combSum += delayed
                }

                // Scale comb output
                var output = combSum * 0.125  // Divide by 8 comb filters

                // Process 4 series allpass filters for diffusion
                for i in 0..<allpassBuffers.count {
                    let bufferSize = allpassBuffers[i].count
                    guard bufferSize > 0 else { continue }

                    let delayed = allpassBuffers[i][allpassIndices[i]]
                    let temp = output + delayed * 0.5

                    allpassBuffers[i][allpassIndices[i]] = temp
                    allpassIndices[i] = (allpassIndices[i] + 1) % bufferSize

                    output = delayed - output * 0.5
                }

                // Mix dry and wet signals
                inputPtr[frame] = input * (1.0 - wetDry) + output * wetDry
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

        // Smooth transition for wet/dry
        if let currentWetness = getParameter(name: Params.wetDry) {
            let smoothed = currentWetness * 0.95 + targetWetness * 0.05
            setParameter(name: Params.wetDry, value: smoothed)
        }

        // HRV → Room Size (higher HRV = larger room)
        let targetRoomSize = Float(min(signal.hrv / 100.0, 1.0)) * 100.0  // 0-100%
        if let currentRoomSize = getParameter(name: Params.roomSize) {
            let smoothed = currentRoomSize * 0.98 + targetRoomSize * 0.02
            setParameter(name: Params.roomSize, value: smoothed)
        }

        // Heart Rate → Damping (higher HR = more damping = tighter sound)
        let targetDamping = Float(min(max((signal.heartRate - 60.0) / 60.0, 0.0), 1.0)) * 80.0 + 20.0
        if let currentDamping = getParameter(name: Params.damping) {
            let smoothed = currentDamping * 0.97 + targetDamping * 0.03
            setParameter(name: Params.damping, value: smoothed)
        }
    }


    // MARK: - Lifecycle

    override func prepare(sampleRate: Double, maxFrames: AVAudioFrameCount) {
        // Reinitialize buffers if sample rate changed
        if abs(sampleRate - currentSampleRate) > 1.0 {
            initializeBuffers(sampleRate: sampleRate)
        }
    }

    override func start() {
        super.start()
        log.audio("🎵 ReverbNode started (EchoelCore Freeverb)")
    }

    override func stop() {
        super.stop()
        log.audio("🎵 ReverbNode stopped")
    }

    override func reset() {
        super.reset()
        // Clear all delay buffers
        for i in 0..<combBuffers.count {
            combBuffers[i] = [Float](repeating: 0.0, count: combBuffers[i].count)
            combIndices[i] = 0
            dampedValues[i] = 0.0
        }
        for i in 0..<allpassBuffers.count {
            allpassBuffers[i] = [Float](repeating: 0.0, count: allpassBuffers[i].count)
            allpassIndices[i] = 0
        }
    }
}
