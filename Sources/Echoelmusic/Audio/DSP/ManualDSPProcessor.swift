import Foundation
import AVFoundation
import Accelerate

/// Manual DSP processor for real-time audio effects
/// Replaces placeholder AVAudioUnit processing with actual DSP
/// Uses vDSP and Accelerate for optimized performance
public class ManualDSPProcessor {

    // MARK: - Filter Processor

    /// Biquad filter coefficients
    private struct BiquadCoefficients {
        var b0: Float = 1.0
        var b1: Float = 0.0
        var b2: Float = 0.0
        var a1: Float = 0.0
        var a2: Float = 0.0
    }

    /// Filter state for left and right channels
    private struct FilterState {
        var x1: Float = 0.0  // Previous input sample 1
        var x2: Float = 0.0  // Previous input sample 2
        var y1: Float = 0.0  // Previous output sample 1
        var y2: Float = 0.0  // Previous output sample 2
    }

    private var filterStateLeft = FilterState()
    private var filterStateRight = FilterState()

    /// Process buffer with low-pass filter
    public func processLowPassFilter(
        _ buffer: AVAudioPCMBuffer,
        cutoffFrequency: Float,
        resonance: Float,
        sampleRate: Double
    ) -> AVAudioPCMBuffer? {

        guard let inputData = buffer.floatChannelData else { return nil }

        // Create output buffer
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: buffer.frameCapacity
        ) else { return nil }

        guard let outputData = outputBuffer.floatChannelData else { return nil }

        let frameLength = Int(buffer.frameLength)
        outputBuffer.frameLength = buffer.frameLength

        // Calculate biquad coefficients for low-pass filter
        let coeffs = calculateLowPassCoefficients(
            cutoffFrequency: cutoffFrequency,
            resonance: resonance,
            sampleRate: Float(sampleRate)
        )

        // Process each channel
        let channelCount = Int(buffer.format.channelCount)

        for channel in 0..<channelCount {
            let input = inputData[channel]
            let output = outputData[channel]

            // Choose filter state
            var state = channel == 0 ? filterStateLeft : filterStateRight

            // Process samples
            for i in 0..<frameLength {
                let x = input[i]

                // Biquad filter equation:
                // y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2] - a1*y[n-1] - a2*y[n-2]
                let y = coeffs.b0 * x + coeffs.b1 * state.x1 + coeffs.b2 * state.x2
                          - coeffs.a1 * state.y1 - coeffs.a2 * state.y2

                output[i] = y

                // Update state
                state.x2 = state.x1
                state.x1 = x
                state.y2 = state.y1
                state.y1 = y
            }

            // Save filter state
            if channel == 0 {
                filterStateLeft = state
            } else {
                filterStateRight = state
            }
        }

        return outputBuffer
    }

    private func calculateLowPassCoefficients(
        cutoffFrequency: Float,
        resonance: Float,
        sampleRate: Float
    ) -> BiquadCoefficients {

        // Normalize frequency
        let omega = 2.0 * .pi * cutoffFrequency / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * resonance)

        // Calculate coefficients
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cosOmega
        let a2 = 1.0 - alpha
        let b0 = (1.0 - cosOmega) / 2.0
        let b1 = 1.0 - cosOmega
        let b2 = (1.0 - cosOmega) / 2.0

        return BiquadCoefficients(
            b0: b0 / a0,
            b1: b1 / a0,
            b2: b2 / a0,
            a1: a1 / a0,
            a2: a2 / a0
        )
    }

    // MARK: - Reverb Processor

    /// Simple comb filter delay line
    private class DelayLine {
        private var buffer: [Float]
        private var writeIndex: Int = 0
        private let size: Int

        init(sizeInSamples: Int) {
            self.size = sizeInSamples
            self.buffer = [Float](repeating: 0.0, count: sizeInSamples)
        }

        func process(_ input: Float, feedback: Float) -> Float {
            let output = buffer[writeIndex]
            buffer[writeIndex] = input + (output * feedback)
            writeIndex = (writeIndex + 1) % size
            return output
        }
    }

    private var reverbDelayLines: [DelayLine] = []

    /// Process buffer with reverb (using Schroeder reverb algorithm)
    public func processReverb(
        _ buffer: AVAudioPCMBuffer,
        wetDryMix: Float,  // 0-100
        roomSize: Float,    // 0-100
        sampleRate: Double
    ) -> AVAudioPCMBuffer? {

        guard let inputData = buffer.floatChannelData else { return nil }

        // Create output buffer
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: buffer.frameCapacity
        ) else { return nil }

        guard let outputData = outputBuffer.floatChannelData else { return nil }

        let frameLength = Int(buffer.frameLength)
        outputBuffer.frameLength = buffer.frameLength

        // Initialize delay lines if needed
        if reverbDelayLines.isEmpty {
            // Schroeder reverb uses 4 comb filters + 2 allpass filters
            let combDelays = [1557, 1617, 1491, 1422]  // Prime numbers for density
            for delay in combDelays {
                reverbDelayLines.append(DelayLine(sizeInSamples: delay))
            }
        }

        let channelCount = Int(buffer.format.channelCount)
        let wetness = wetDryMix / 100.0
        let dryness = 1.0 - wetness
        let feedback = 0.5 + (roomSize / 200.0)  // 0.5 - 1.0

        for channel in 0..<channelCount {
            let input = inputData[channel]
            let output = outputData[channel]

            for i in 0..<frameLength {
                let sample = input[i]

                // Process through comb filters
                var reverbSample: Float = 0.0
                for delayLine in reverbDelayLines {
                    reverbSample += delayLine.process(sample, feedback: feedback)
                }
                reverbSample /= Float(reverbDelayLines.count)

                // Mix wet and dry
                output[i] = (sample * dryness) + (reverbSample * wetness)
            }
        }

        return outputBuffer
    }

    // MARK: - Delay Processor

    private var delayBuffer: [[Float]] = []
    private var delayWriteIndex: Int = 0

    /// Process buffer with delay effect
    public func processDelay(
        _ buffer: AVAudioPCMBuffer,
        delayTime: Float,     // Seconds
        feedback: Float,       // 0-100
        wetDryMix: Float,     // 0-100
        sampleRate: Double
    ) -> AVAudioPCMBuffer? {

        guard let inputData = buffer.floatChannelData else { return nil }

        // Create output buffer
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: buffer.frameCapacity
        ) else { return nil }

        guard let outputData = outputBuffer.floatChannelData else { return nil }

        let frameLength = Int(buffer.frameLength)
        outputBuffer.frameLength = buffer.frameLength

        let channelCount = Int(buffer.format.channelCount)
        let delaySamples = Int(delayTime * Float(sampleRate))
        let wetness = wetDryMix / 100.0
        let dryness = 1.0 - wetness
        let feedbackAmount = feedback / 100.0

        // Initialize delay buffer if needed
        if delayBuffer.isEmpty || delayBuffer[0].count < delaySamples {
            delayBuffer = [[Float]](repeating: [Float](repeating: 0.0, count: delaySamples), count: channelCount)
            delayWriteIndex = 0
        }

        for channel in 0..<channelCount {
            let input = inputData[channel]
            let output = outputData[channel]

            for i in 0..<frameLength {
                let sample = input[i]

                // Read from delay buffer
                let delayedSample = delayBuffer[channel][delayWriteIndex]

                // Write to delay buffer with feedback
                delayBuffer[channel][delayWriteIndex] = sample + (delayedSample * feedbackAmount)

                // Mix wet and dry
                output[i] = (sample * dryness) + (delayedSample * wetness)

                // Advance write index
                delayWriteIndex = (delayWriteIndex + 1) % delaySamples
            }
        }

        return outputBuffer
    }

    // MARK: - Compressor Processor

    /// Simple compressor with attack/release
    public func processCompressor(
        _ buffer: AVAudioPCMBuffer,
        threshold: Float,      // dB
        ratio: Float,          // X:1
        attack: Float,         // milliseconds
        release: Float,        // milliseconds
        sampleRate: Double
    ) -> AVAudioPCMBuffer? {

        guard let inputData = buffer.floatChannelData else { return nil }

        // Create output buffer
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: buffer.frameCapacity
        ) else { return nil }

        guard let outputData = outputBuffer.floatChannelData else { return nil }

        let frameLength = Int(buffer.frameLength)
        outputBuffer.frameLength = buffer.frameLength

        let channelCount = Int(buffer.format.channelCount)

        // Convert threshold to linear
        let thresholdLinear = powf(10.0, threshold / 20.0)

        // Calculate attack and release coefficients
        let attackCoeff = exp(-1.0 / (attack / 1000.0 * Float(sampleRate)))
        let releaseCoeff = exp(-1.0 / (release / 1000.0 * Float(sampleRate)))

        var envelope: Float = 0.0

        for channel in 0..<channelCount {
            let input = inputData[channel]
            let output = outputData[channel]

            for i in 0..<frameLength {
                let sample = input[i]
                let level = abs(sample)

                // Envelope follower
                if level > envelope {
                    envelope = attackCoeff * envelope + (1.0 - attackCoeff) * level
                } else {
                    envelope = releaseCoeff * envelope + (1.0 - releaseCoeff) * level
                }

                // Calculate gain reduction
                var gain: Float = 1.0
                if envelope > thresholdLinear {
                    // Above threshold: apply compression
                    let excessDB = 20.0 * log10(envelope / thresholdLinear)
                    let gainReductionDB = excessDB * (1.0 - 1.0 / ratio)
                    gain = powf(10.0, -gainReductionDB / 20.0)
                }

                output[i] = sample * gain
            }
        }

        return outputBuffer
    }

    // MARK: - Utilities

    /// Copy buffer (for bypass)
    public func copyBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: buffer.format,
            frameCapacity: buffer.frameCapacity
        ) else { return nil }

        outputBuffer.frameLength = buffer.frameLength

        guard let inputData = buffer.floatChannelData,
              let outputData = outputBuffer.floatChannelData else { return nil }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        for channel in 0..<channelCount {
            memcpy(outputData[channel], inputData[channel], frameLength * MemoryLayout<Float>.size)
        }

        return outputBuffer
    }
}
