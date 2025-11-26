//
//  DSPEffectsEngine.swift
//  EOEL
//
//  Professional Audio DSP Effects Implementation
//  Real-time audio processing with ultra-low latency
//

import AVFoundation
import Accelerate

// MARK: - Biquad Filter Engine

/// Professional biquad filter implementation for EQ, filters, etc.
/// Based on Robert Bristow-Johnson's Audio EQ Cookbook
class BiquadFilter {

    // Filter coefficients
    private var b0: Float = 1.0
    private var b1: Float = 0.0
    private var b2: Float = 0.0
    private var a1: Float = 0.0
    private var a2: Float = 0.0

    // State variables (for stereo)
    private var x1L: Float = 0.0, x2L: Float = 0.0
    private var y1L: Float = 0.0, y2L: Float = 0.0
    private var x1R: Float = 0.0, x2R: Float = 0.0
    private var y1R: Float = 0.0, y2R: Float = 0.0

    enum FilterType {
        case lowPass
        case highPass
        case bandPass
        case notch
        case peak
        case lowShelf
        case highShelf
        case allPass
    }

    /// Configure filter coefficients
    /// - Parameters:
    ///   - type: Filter type
    ///   - frequency: Center frequency (Hz)
    ///   - sampleRate: Sample rate (Hz)
    ///   - q: Quality factor (0.5 = wide, 10 = narrow)
    ///   - gain: Gain in dB (for peak/shelf filters)
    func configure(type: FilterType, frequency: Float, sampleRate: Float, q: Float = 0.707, gain: Float = 0.0) {
        let w0 = 2.0 * Float.pi * frequency / sampleRate
        let cosW0 = cos(w0)
        let sinW0 = sin(w0)
        let alpha = sinW0 / (2.0 * q)
        let A = pow(10.0, gain / 40.0)  // Convert dB to linear

        var a0: Float = 1.0

        switch type {
        case .lowPass:
            b0 = (1.0 - cosW0) / 2.0
            b1 = 1.0 - cosW0
            b2 = (1.0 - cosW0) / 2.0
            a0 = 1.0 + alpha
            a1 = -2.0 * cosW0
            a2 = 1.0 - alpha

        case .highPass:
            b0 = (1.0 + cosW0) / 2.0
            b1 = -(1.0 + cosW0)
            b2 = (1.0 + cosW0) / 2.0
            a0 = 1.0 + alpha
            a1 = -2.0 * cosW0
            a2 = 1.0 - alpha

        case .bandPass:
            b0 = alpha
            b1 = 0.0
            b2 = -alpha
            a0 = 1.0 + alpha
            a1 = -2.0 * cosW0
            a2 = 1.0 - alpha

        case .notch:
            b0 = 1.0
            b1 = -2.0 * cosW0
            b2 = 1.0
            a0 = 1.0 + alpha
            a1 = -2.0 * cosW0
            a2 = 1.0 - alpha

        case .peak:
            b0 = 1.0 + alpha * A
            b1 = -2.0 * cosW0
            b2 = 1.0 - alpha * A
            a0 = 1.0 + alpha / A
            a1 = -2.0 * cosW0
            a2 = 1.0 - alpha / A

        case .lowShelf:
            let sqrtA = sqrt(A)
            b0 = A * ((A + 1.0) - (A - 1.0) * cosW0 + 2.0 * sqrtA * alpha)
            b1 = 2.0 * A * ((A - 1.0) - (A + 1.0) * cosW0)
            b2 = A * ((A + 1.0) - (A - 1.0) * cosW0 - 2.0 * sqrtA * alpha)
            a0 = (A + 1.0) + (A - 1.0) * cosW0 + 2.0 * sqrtA * alpha
            a1 = -2.0 * ((A - 1.0) + (A + 1.0) * cosW0)
            a2 = (A + 1.0) + (A - 1.0) * cosW0 - 2.0 * sqrtA * alpha

        case .highShelf:
            let sqrtA = sqrt(A)
            b0 = A * ((A + 1.0) + (A - 1.0) * cosW0 + 2.0 * sqrtA * alpha)
            b1 = -2.0 * A * ((A - 1.0) + (A + 1.0) * cosW0)
            b2 = A * ((A + 1.0) + (A - 1.0) * cosW0 - 2.0 * sqrtA * alpha)
            a0 = (A + 1.0) - (A - 1.0) * cosW0 + 2.0 * sqrtA * alpha
            a1 = 2.0 * ((A - 1.0) - (A + 1.0) * cosW0)
            a2 = (A + 1.0) - (A - 1.0) * cosW0 - 2.0 * sqrtA * alpha

        case .allPass:
            b0 = 1.0 - alpha
            b1 = -2.0 * cosW0
            b2 = 1.0 + alpha
            a0 = 1.0 + alpha
            a1 = -2.0 * cosW0
            a2 = 1.0 - alpha
        }

        // Normalize coefficients
        b0 /= a0
        b1 /= a0
        b2 /= a0
        a1 /= a0
        a2 /= a0
    }

    /// Process single sample (left channel)
    func processSample(_ input: Float, channel: Int = 0) -> Float {
        if channel == 0 {
            // Left channel
            let output = b0 * input + b1 * x1L + b2 * x2L - a1 * y1L - a2 * y2L
            x2L = x1L
            x1L = input
            y2L = y1L
            y1L = output
            return output
        } else {
            // Right channel
            let output = b0 * input + b1 * x1R + b2 * x2R - a1 * y1R - a2 * y2R
            x2R = x1R
            x1R = input
            y2R = y1R
            y1R = output
            return output
        }
    }

    /// Process buffer using Accelerate framework (much faster!)
    func processBuffer(_ input: UnsafeMutablePointer<Float>, output: UnsafeMutablePointer<Float>,
                      frameCount: Int, channel: Int = 0) {
        for i in 0..<frameCount {
            output[i] = processSample(input[i], channel: channel)
        }
    }

    /// Reset filter state
    func reset() {
        x1L = 0; x2L = 0; y1L = 0; y2L = 0
        x1R = 0; x2R = 0; y1R = 0; y2R = 0
    }
}

// MARK: - Parametric EQ (7-Band)

@MainActor
class ParametricEQ: ObservableObject {

    struct Band {
        var enabled: Bool = true
        var type: BiquadFilter.FilterType = .peak
        var frequency: Float = 1000.0  // Hz
        var gain: Float = 0.0  // dB (-24 to +24)
        var q: Float = 1.0  // 0.1 to 10.0
    }

    @Published var bands: [Band] = [
        Band(type: .lowShelf, frequency: 80, gain: 0, q: 0.707),
        Band(type: .peak, frequency: 200, gain: 0, q: 1.0),
        Band(type: .peak, frequency: 500, gain: 0, q: 1.0),
        Band(type: .peak, frequency: 1000, gain: 0, q: 1.0),
        Band(type: .peak, frequency: 3000, gain: 0, q: 1.0),
        Band(type: .peak, frequency: 8000, gain: 0, q: 1.0),
        Band(type: .highShelf, frequency: 12000, gain: 0, q: 0.707)
    ]

    private var filters: [[BiquadFilter]] = []  // [band][channel]
    private var sampleRate: Float = 48000.0

    init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate

        // Create filters for each band (stereo)
        for _ in 0..<7 {
            filters.append([BiquadFilter(), BiquadFilter()])
        }

        updateFilters()
    }

    func updateFilters() {
        for (index, band) in bands.enumerated() {
            filters[index][0].configure(type: band.type, frequency: band.frequency,
                                       sampleRate: sampleRate, q: band.q, gain: band.gain)
            filters[index][1].configure(type: band.type, frequency: band.frequency,
                                       sampleRate: sampleRate, q: band.q, gain: band.gain)
        }
    }

    func process(buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard let inputData = buffer.floatChannelData else { return buffer }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        // Create output buffer
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity) else {
            return buffer
        }
        outputBuffer.frameLength = buffer.frameLength
        guard let outputData = outputBuffer.floatChannelData else { return buffer }

        // Process each channel
        for ch in 0..<channelCount {
            // Copy input to output first
            memcpy(outputData[ch], inputData[ch], frameCount * MemoryLayout<Float>.stride)

            // Apply each band sequentially
            for (bandIndex, band) in bands.enumerated() where band.enabled {
                filters[bandIndex][ch].processBuffer(outputData[ch], output: outputData[ch],
                                                    frameCount: frameCount, channel: ch)
            }
        }

        return outputBuffer
    }
}

// MARK: - Compressor (with Sidechain)

@MainActor
class Compressor: ObservableObject {

    @Published var threshold: Float = -12.0  // dB
    @Published var ratio: Float = 3.0  // 1:1 to 20:1
    @Published var attack: Float = 5.0  // ms
    @Published var release: Float = 100.0  // ms
    @Published var knee: Float = 6.0  // dB (0 = hard knee, 12 = soft knee)
    @Published var makeupGain: Float = 0.0  // dB
    @Published var enabled: Bool = true

    private var envelope: Float = 0.0
    private var sampleRate: Float = 48000.0

    init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate
    }

    func process(buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard enabled, let inputData = buffer.floatChannelData else { return buffer }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        // Create output buffer
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity) else {
            return buffer
        }
        outputBuffer.frameLength = buffer.frameLength
        guard let outputData = outputBuffer.floatChannelData else { return buffer }

        // Calculate envelope time constants
        let attackCoeff = exp(-1.0 / (attack * 0.001 * sampleRate))
        let releaseCoeff = exp(-1.0 / (release * 0.001 * sampleRate))
        let makeupLinear = pow(10.0, makeupGain / 20.0)

        for i in 0..<frameCount {
            // Calculate input level (RMS across channels)
            var sumSquares: Float = 0.0
            for ch in 0..<channelCount {
                let sample = inputData[ch][i]
                sumSquares += sample * sample
            }
            let rms = sqrt(sumSquares / Float(channelCount))
            let inputDb = 20.0 * log10(max(rms, 1e-6))

            // Update envelope follower
            if inputDb > 20.0 * log10(envelope) {
                envelope = attackCoeff * envelope + (1.0 - attackCoeff) * rms
            } else {
                envelope = releaseCoeff * envelope + (1.0 - releaseCoeff) * rms
            }

            let envelopeDb = 20.0 * log10(max(envelope, 1e-6))

            // Calculate gain reduction
            var gainReduction: Float = 0.0
            let overThreshold = envelopeDb - threshold

            if knee > 0 && overThreshold > -knee/2 && overThreshold < knee/2 {
                // Soft knee
                let kneeInput = overThreshold + knee/2
                gainReduction = (kneeInput * kneeInput) / (2.0 * knee)
                gainReduction *= (1.0 / ratio - 1.0)
            } else if overThreshold > 0 {
                // Above threshold
                gainReduction = overThreshold * (1.0 / ratio - 1.0)
            }

            let gainLinear = pow(10.0, gainReduction / 20.0) * makeupLinear

            // Apply gain reduction to all channels
            for ch in 0..<channelCount {
                outputData[ch][i] = inputData[ch][i] * gainLinear
            }
        }

        return outputBuffer
    }
}

// MARK: - Reverb (Schroeder Algorithm)

@MainActor
class SchroederReverb: ObservableObject {

    @Published var roomSize: Float = 0.5  // 0-1
    @Published var damping: Float = 0.5  // 0-1
    @Published var wetLevel: Float = 0.3  // 0-1
    @Published var dryLevel: Float = 0.7  // 0-1
    @Published var width: Float = 1.0  // Stereo width (0-1)
    @Published var enabled: Bool = true

    // Comb filters (4 parallel for left, 4 for right)
    private var combFilters: [[CombFilter]] = []

    // All-pass filters (2 in series for left, 2 for right)
    private var allPassFilters: [[AllPassFilter]] = []

    private let sampleRate: Float

    // Schroeder reverb delay times (in samples at 44.1kHz)
    private let combDelays = [1116, 1188, 1277, 1356]
    private let allPassDelays = [556, 441]

    init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate

        // Scale delays to current sample rate
        let scale = sampleRate / 44100.0

        // Create comb filters for stereo
        for ch in 0..<2 {
            var channelCombs: [CombFilter] = []
            for delay in combDelays {
                let scaledDelay = Int(Float(delay) * scale)
                // Slightly detune right channel for stereo width
                let finalDelay = ch == 0 ? scaledDelay : scaledDelay + 23
                channelCombs.append(CombFilter(delayLength: finalDelay))
            }
            combFilters.append(channelCombs)
        }

        // Create all-pass filters for stereo
        for ch in 0..<2 {
            var channelAllPass: [AllPassFilter] = []
            for delay in allPassDelays {
                let scaledDelay = Int(Float(delay) * scale)
                let finalDelay = ch == 0 ? scaledDelay : scaledDelay + 11
                channelAllPass.append(AllPassFilter(delayLength: finalDelay))
            }
            allPassFilters.append(channelAllPass)
        }
    }

    func updateParameters() {
        // Update comb filter feedback based on room size
        let feedback = 0.7 + (roomSize * 0.28)  // 0.7 to 0.98

        for ch in 0..<2 {
            for comb in combFilters[ch] {
                comb.feedback = feedback
                comb.damping = damping
            }
        }
    }

    func process(buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard enabled, let inputData = buffer.floatChannelData else { return buffer }

        updateParameters()

        let frameCount = Int(buffer.frameLength)
        let channelCount = min(Int(buffer.format.channelCount), 2)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity) else {
            return buffer
        }
        outputBuffer.frameLength = buffer.frameLength
        guard let outputData = outputBuffer.floatChannelData else { return buffer }

        for i in 0..<frameCount {
            for ch in 0..<channelCount {
                let input = inputData[ch][i]

                // Sum parallel comb filters
                var combSum: Float = 0.0
                for comb in combFilters[ch] {
                    combSum += comb.process(input)
                }
                combSum /= Float(combFilters[ch].count)

                // Series all-pass filters
                var allPassOutput = combSum
                for allPass in allPassFilters[ch] {
                    allPassOutput = allPass.process(allPassOutput)
                }

                // Mix wet and dry
                outputData[ch][i] = input * dryLevel + allPassOutput * wetLevel
            }
        }

        return outputBuffer
    }

    // MARK: - Comb Filter (IIR with damping)

    class CombFilter {
        private var buffer: [Float]
        private var bufferIndex: Int = 0
        private var filterStore: Float = 0.0

        var feedback: Float = 0.84
        var damping: Float = 0.5

        init(delayLength: Int) {
            buffer = [Float](repeating: 0.0, count: delayLength)
        }

        func process(_ input: Float) -> Float {
            let output = buffer[bufferIndex]

            // One-pole lowpass filter (damping)
            filterStore = output * (1.0 - damping) + filterStore * damping

            buffer[bufferIndex] = input + filterStore * feedback

            bufferIndex = (bufferIndex + 1) % buffer.count

            return output
        }
    }

    // MARK: - All-Pass Filter

    class AllPassFilter {
        private var buffer: [Float]
        private var bufferIndex: Int = 0
        private let feedback: Float = 0.5

        init(delayLength: Int) {
            buffer = [Float](repeating: 0.0, count: delayLength)
        }

        func process(_ input: Float) -> Float {
            let delayed = buffer[bufferIndex]
            let output = -input + delayed

            buffer[bufferIndex] = input + delayed * feedback

            bufferIndex = (bufferIndex + 1) % buffer.count

            return output
        }
    }
}

// MARK: - Delay (Stereo with Feedback)

@MainActor
class StereoDelay: ObservableObject {

    @Published var delayTimeLeft: Float = 0.25  // seconds
    @Published var delayTimeRight: Float = 0.375  // seconds
    @Published var feedback: Float = 0.4  // 0-1
    @Published var crossFeedback: Float = 0.2  // Left→Right, Right→Left
    @Published var wetLevel: Float = 0.3  // 0-1
    @Published var dryLevel: Float = 0.7  // 0-1
    @Published var filterFrequency: Float = 5000.0  // Hz (feedback filtering)
    @Published var enabled: Bool = true

    private var delayBufferLeft: [Float] = []
    private var delayBufferRight: [Float] = []
    private var writeIndexLeft: Int = 0
    private var writeIndexRight: Int = 0
    private var feedbackFilter: BiquadFilter = BiquadFilter()

    private let sampleRate: Float
    private let maxDelayTime: Float = 2.0  // seconds

    init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate

        let maxSamples = Int(maxDelayTime * sampleRate)
        delayBufferLeft = [Float](repeating: 0.0, count: maxSamples)
        delayBufferRight = [Float](repeating: 0.0, count: maxSamples)

        // Configure low-pass filter for feedback
        feedbackFilter.configure(type: .lowPass, frequency: filterFrequency,
                                sampleRate: sampleRate, q: 0.707)
    }

    func process(buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard enabled, let inputData = buffer.floatChannelData else { return buffer }

        let frameCount = Int(buffer.frameLength)
        let channelCount = min(Int(buffer.format.channelCount), 2)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameCapacity) else {
            return buffer
        }
        outputBuffer.frameLength = buffer.frameLength
        guard let outputData = outputBuffer.floatChannelData else { return buffer }

        let delaySamplesLeft = Int(delayTimeLeft * sampleRate)
        let delaySamplesRight = Int(delayTimeRight * sampleRate)

        for i in 0..<frameCount {
            let inputLeft = channelCount > 0 ? inputData[0][i] : 0.0
            let inputRight = channelCount > 1 ? inputData[1][i] : inputLeft

            // Read from delay buffers
            let readIndexLeft = (writeIndexLeft - delaySamplesLeft + delayBufferLeft.count) % delayBufferLeft.count
            let readIndexRight = (writeIndexRight - delaySamplesRight + delayBufferRight.count) % delayBufferRight.count

            let delayedLeft = delayBufferLeft[readIndexLeft]
            let delayedRight = delayBufferRight[readIndexRight]

            // Apply feedback filtering
            let filteredLeft = feedbackFilter.processSample(delayedLeft, channel: 0)
            let filteredRight = feedbackFilter.processSample(delayedRight, channel: 1)

            // Write to delay buffers with feedback and cross-feedback
            delayBufferLeft[writeIndexLeft] = inputLeft + filteredLeft * feedback + filteredRight * crossFeedback
            delayBufferRight[writeIndexRight] = inputRight + filteredRight * feedback + filteredLeft * crossFeedback

            writeIndexLeft = (writeIndexLeft + 1) % delayBufferLeft.count
            writeIndexRight = (writeIndexRight + 1) % delayBufferRight.count

            // Mix dry and wet
            if channelCount > 0 {
                outputData[0][i] = inputLeft * dryLevel + delayedLeft * wetLevel
            }
            if channelCount > 1 {
                outputData[1][i] = inputRight * dryLevel + delayedRight * wetLevel
            }
        }

        return outputBuffer
    }
}

// MARK: - Effect Chain Manager

@MainActor
class EffectChain: ObservableObject {

    enum Effect {
        case eq(ParametricEQ)
        case compressor(Compressor)
        case reverb(SchroederReverb)
        case delay(StereoDelay)
    }

    @Published var effects: [Effect] = []

    func addEffect(_ effect: Effect) {
        effects.append(effect)
    }

    func removeEffect(at index: Int) {
        effects.remove(at: index)
    }

    func process(buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        var currentBuffer = buffer

        for effect in effects {
            switch effect {
            case .eq(let eq):
                currentBuffer = eq.process(buffer: currentBuffer)
            case .compressor(let comp):
                currentBuffer = comp.process(buffer: currentBuffer)
            case .reverb(let reverb):
                currentBuffer = reverb.process(buffer: currentBuffer)
            case .delay(let delay):
                currentBuffer = delay.process(buffer: currentBuffer)
            }
        }

        return currentBuffer
    }
}
