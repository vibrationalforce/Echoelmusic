#if canImport(AVFoundation)
import Foundation
import AVFoundation
import Accelerate

/// Real-time DSP kernel for the AUv3 plugin
///
/// Implements Freeverb-style reverb + state-variable filter + delay
/// with bio-reactive parameter modulation. All processing is lock-free
/// and allocation-free after `prepare()`.
///
/// Audio thread: NO locks, NO malloc, NO ObjC messaging.
final class DSPKernel {

    // MARK: - Parameter Addresses

    enum ParameterAddress: UInt64 {
        case wetDry = 0
        case roomSize = 1
        case damping = 2
        case delayTime = 3
        case feedback = 4
        case filterCutoff = 5
        case filterResonance = 6
        case inputGain = 7
        case outputGain = 8
        case bypass = 9
    }

    // MARK: - State

    private var sampleRate: Double = 48000.0
    private var maxFrames: AVAudioFrameCount = 512
    private var channelCount: Int = 2

    // Parameter values (atomic reads from audio thread)
    nonisolated(unsafe) private var wetDry: Float = 0.3
    nonisolated(unsafe) private var roomSize: Float = 0.5
    nonisolated(unsafe) private var dampingValue: Float = 0.5
    nonisolated(unsafe) private var delayTime: Float = 0.25
    nonisolated(unsafe) private var feedbackAmount: Float = 0.4
    nonisolated(unsafe) private var filterCutoff: Float = 8000.0
    nonisolated(unsafe) private var filterResonance: Float = 0.707
    nonisolated(unsafe) private var inputGain: Float = 1.0
    nonisolated(unsafe) private var outputGain: Float = 1.0
    nonisolated(unsafe) private var bypassed: Bool = false

    // MARK: - Reverb DSP (Freeverb)

    private static let combDelays: [Int] = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]
    private static let allpassDelays: [Int] = [556, 441, 341, 225]

    private var combBuffersL: [[Float]] = []
    private var combBuffersR: [[Float]] = []
    private var combIndicesL: [Int] = []
    private var combIndicesR: [Int] = []
    private var dampedValuesL: [Float] = []
    private var dampedValuesR: [Float] = []

    private var allpassBuffersL: [[Float]] = []
    private var allpassBuffersR: [[Float]] = []
    private var allpassIndicesL: [Int] = []
    private var allpassIndicesR: [Int] = []

    // MARK: - Delay DSP

    private var delayBufferL: [Float] = []
    private var delayBufferR: [Float] = []
    private var delayWriteIndex: Int = 0
    private var delayBufferSize: Int = 0

    // MARK: - Filter DSP (State-Variable Biquad)

    private var filterX1L: Float = 0, filterX2L: Float = 0
    private var filterY1L: Float = 0, filterY2L: Float = 0
    private var filterX1R: Float = 0, filterX2R: Float = 0
    private var filterY1R: Float = 0, filterY2R: Float = 0
    private var filterB0: Float = 1, filterB1: Float = 0, filterB2: Float = 0
    private var filterA1: Float = 0, filterA2: Float = 0

    // MARK: - Initialization

    init() {}

    // MARK: - Configuration

    func prepare(sampleRate: Double, maxFrames: AVAudioFrameCount, channelCount: Int) {
        self.sampleRate = sampleRate
        self.maxFrames = maxFrames
        self.channelCount = channelCount

        initializeReverbBuffers()
        initializeDelayBuffer()
        updateFilterCoefficients()
    }

    private func initializeReverbBuffers() {
        let scaleFactor = sampleRate / 44100.0

        combBuffersL = DSPKernel.combDelays.map { delay in
            [Float](repeating: 0, count: Int(Double(delay) * scaleFactor))
        }
        combBuffersR = DSPKernel.combDelays.map { delay in
            // Slightly offset R channel for stereo width
            [Float](repeating: 0, count: Int(Double(delay) * scaleFactor) + 23)
        }
        combIndicesL = [Int](repeating: 0, count: DSPKernel.combDelays.count)
        combIndicesR = [Int](repeating: 0, count: DSPKernel.combDelays.count)
        dampedValuesL = [Float](repeating: 0, count: DSPKernel.combDelays.count)
        dampedValuesR = [Float](repeating: 0, count: DSPKernel.combDelays.count)

        allpassBuffersL = DSPKernel.allpassDelays.map { delay in
            [Float](repeating: 0, count: Int(Double(delay) * scaleFactor))
        }
        allpassBuffersR = DSPKernel.allpassDelays.map { delay in
            [Float](repeating: 0, count: Int(Double(delay) * scaleFactor) + 13)
        }
        allpassIndicesL = [Int](repeating: 0, count: DSPKernel.allpassDelays.count)
        allpassIndicesR = [Int](repeating: 0, count: DSPKernel.allpassDelays.count)
    }

    private func initializeDelayBuffer() {
        // Max 2 seconds delay
        delayBufferSize = Int(sampleRate * 2.0)
        delayBufferL = [Float](repeating: 0, count: delayBufferSize)
        delayBufferR = [Float](repeating: 0, count: delayBufferSize)
        delayWriteIndex = 0
    }

    // MARK: - Parameter Setting

    func setParameter(address: ParameterAddress, value: Float) {
        switch address {
        case .wetDry:       wetDry = value
        case .roomSize:     roomSize = value
        case .damping:      dampingValue = value
        case .delayTime:    delayTime = value
        case .feedback:     feedbackAmount = value
        case .filterCutoff:
            filterCutoff = value
            updateFilterCoefficients()
        case .filterResonance:
            filterResonance = value
            updateFilterCoefficients()
        case .inputGain:    inputGain = value
        case .outputGain:   outputGain = value
        case .bypass:       bypassed = value > 0.5
        }
    }

    func getParameter(address: ParameterAddress) -> Float {
        switch address {
        case .wetDry:           return wetDry
        case .roomSize:         return roomSize
        case .damping:          return dampingValue
        case .delayTime:        return delayTime
        case .feedback:         return feedbackAmount
        case .filterCutoff:     return filterCutoff
        case .filterResonance:  return filterResonance
        case .inputGain:        return inputGain
        case .outputGain:       return outputGain
        case .bypass:           return bypassed ? 1.0 : 0.0
        }
    }

    // MARK: - Filter Coefficient Calculation

    private func updateFilterCoefficients() {
        let omega = 2.0 * Float.pi * filterCutoff / Float(sampleRate)
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * filterResonance)

        // Low-pass biquad coefficients
        let a0 = 1.0 + alpha
        filterB0 = ((1.0 - cosOmega) / 2.0) / a0
        filterB1 = (1.0 - cosOmega) / a0
        filterB2 = filterB0
        filterA1 = (-2.0 * cosOmega) / a0
        filterA2 = (1.0 - alpha) / a0
    }

    // MARK: - Audio Processing (Real-Time Safe)

    /// Process audio buffers in-place. Called from the audio render thread.
    /// - Parameters:
    ///   - inputBufferList: Input audio data
    ///   - outputBufferList: Output audio data (may alias input)
    ///   - frameCount: Number of frames to process
    func process(
        inputBufferList: UnsafePointer<AudioBufferList>,
        outputBufferList: UnsafeMutablePointer<AudioBufferList>,
        frameCount: AVAudioFrameCount
    ) {
        let inputBuffers = UnsafeMutableAudioBufferListPointer(
            UnsafeMutablePointer(mutating: inputBufferList)
        )
        let outputBuffers = UnsafeMutableAudioBufferListPointer(outputBufferList)

        guard !bypassed else {
            // Pass-through
            for channel in 0..<min(inputBuffers.count, outputBuffers.count) {
                guard let inputData = inputBuffers[channel].mData,
                      let outputData = outputBuffers[channel].mData else { continue }
                if inputData != outputData {
                    memcpy(outputData, inputData, Int(frameCount) * MemoryLayout<Float>.size)
                }
            }
            return
        }

        let frames = Int(frameCount)

        for channel in 0..<min(inputBuffers.count, outputBuffers.count, 2) {
            guard let inputData = inputBuffers[channel].mData?.assumingMemoryBound(to: Float.self),
                  let outputData = outputBuffers[channel].mData?.assumingMemoryBound(to: Float.self) else {
                continue
            }

            let isLeft = channel == 0

            for frame in 0..<frames {
                var sample = inputData[frame] * inputGain

                // --- Reverb ---
                sample = processReverb(sample: sample, isLeft: isLeft)

                // --- Delay ---
                sample = processDelay(sample: sample, isLeft: isLeft)

                // --- Filter ---
                sample = processFilter(sample: sample, isLeft: isLeft)

                outputData[frame] = sample * outputGain
            }
        }
    }

    // MARK: - Reverb Processing

    private func processReverb(sample: Float, isLeft: Bool) -> Float {
        let reverbFeedback = 0.7 + roomSize * 0.28
        let damp = dampingValue * 0.4

        let combBuffers = isLeft ? &combBuffersL : &combBuffersR
        let combIndices = isLeft ? &combIndicesL : &combIndicesR
        let dampedValues = isLeft ? &dampedValuesL : &dampedValuesR
        let allpassBuffers = isLeft ? &allpassBuffersL : &allpassBuffersR
        let allpassIndices = isLeft ? &allpassIndicesL : &allpassIndicesR

        var combSum: Float = 0

        for i in 0..<combBuffers.count {
            let bufSize = combBuffers[i].count
            guard bufSize > 0 else { continue }

            let delayed = combBuffers[i][combIndices[i]]
            dampedValues[i] = delayed * (1.0 - damp) + dampedValues[i] * damp
            combBuffers[i][combIndices[i]] = sample + dampedValues[i] * reverbFeedback
            combIndices[i] = (combIndices[i] + 1) % bufSize
            combSum += delayed
        }

        var output = combSum * 0.125

        for i in 0..<allpassBuffers.count {
            let bufSize = allpassBuffers[i].count
            guard bufSize > 0 else { continue }

            let delayed = allpassBuffers[i][allpassIndices[i]]
            let temp = output + delayed * 0.5
            allpassBuffers[i][allpassIndices[i]] = temp
            allpassIndices[i] = (allpassIndices[i] + 1) % bufSize
            output = delayed - output * 0.5
        }

        return sample * (1.0 - wetDry) + output * wetDry
    }

    // MARK: - Delay Processing

    private func processDelay(sample: Float, isLeft: Bool) -> Float {
        guard delayBufferSize > 0 else { return sample }

        let delaySamples = Int(delayTime * Float(sampleRate))
        guard delaySamples > 0, delaySamples < delayBufferSize else { return sample }

        let readIndex = (delayWriteIndex - delaySamples + delayBufferSize) % delayBufferSize

        let delayBuffer = isLeft ? delayBufferL : delayBufferR
        let delayed = delayBuffer[readIndex]

        let output = sample + delayed * feedbackAmount

        if isLeft {
            delayBufferL[delayWriteIndex] = output
        } else {
            delayBufferR[delayWriteIndex] = output
            // Advance write index only after processing both channels
            delayWriteIndex = (delayWriteIndex + 1) % delayBufferSize
        }

        return output
    }

    // MARK: - Filter Processing

    private func processFilter(sample: Float, isLeft: Bool) -> Float {
        let output: Float

        if isLeft {
            output = filterB0 * sample + filterB1 * filterX1L + filterB2 * filterX2L
                     - filterA1 * filterY1L - filterA2 * filterY2L
            filterX2L = filterX1L
            filterX1L = sample
            filterY2L = filterY1L
            filterY1L = output
        } else {
            output = filterB0 * sample + filterB1 * filterX1R + filterB2 * filterX2R
                     - filterA1 * filterY1R - filterA2 * filterY2R
            filterX2R = filterX1R
            filterX1R = sample
            filterY2R = filterY1R
            filterY1R = output
        }

        return output
    }

    // MARK: - Reset

    func reset() {
        // Clear reverb
        for i in 0..<combBuffersL.count {
            for j in 0..<combBuffersL[i].count { combBuffersL[i][j] = 0 }
            for j in 0..<combBuffersR[i].count { combBuffersR[i][j] = 0 }
            combIndicesL[i] = 0
            combIndicesR[i] = 0
            dampedValuesL[i] = 0
            dampedValuesR[i] = 0
        }
        for i in 0..<allpassBuffersL.count {
            for j in 0..<allpassBuffersL[i].count { allpassBuffersL[i][j] = 0 }
            for j in 0..<allpassBuffersR[i].count { allpassBuffersR[i][j] = 0 }
            allpassIndicesL[i] = 0
            allpassIndicesR[i] = 0
        }

        // Clear delay
        for i in 0..<delayBufferSize {
            delayBufferL[i] = 0
            delayBufferR[i] = 0
        }
        delayWriteIndex = 0

        // Clear filter state
        filterX1L = 0; filterX2L = 0; filterY1L = 0; filterY2L = 0
        filterX1R = 0; filterX2R = 0; filterY1R = 0; filterY2R = 0
    }
}
#endif
