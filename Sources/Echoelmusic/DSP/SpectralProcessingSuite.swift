//
//  SpectralProcessingSuite.swift
//  Echoelmusic
//
//  Advanced spectral processing effects
//  Spectral Freeze, Gate, Shift, Blur, and Morph
//
//  Created by Echoelmusic Team
//  Copyright © 2026 Echoelmusic. All rights reserved.
//

import Foundation
import Accelerate

// MARK: - Spectral Frame

/// Represents a single spectral frame (magnitude and phase)
public struct SpectralFrame {
    public var magnitudes: [Float]
    public var phases: [Float]

    public init(size: Int) {
        magnitudes = [Float](repeating: 0, count: size)
        phases = [Float](repeating: 0, count: size)
    }
}

// MARK: - Base Spectral Processor

/// Base class for FFT-based spectral processing
public class SpectralProcessor {

    // MARK: - Properties

    public let fftSize: Int
    public let hopSize: Int

    internal var fftSetup: FFTSetup?
    internal var window: [Float]
    internal var realBuffer: [Float]
    internal var imagBuffer: [Float]
    internal var outputBuffer: [Float]
    internal let log2n: vDSP_Length

    // Overlap-add buffers
    internal var overlapBuffer: [Float]
    internal var inputAccumulator: [Float]
    internal var inputPosition: Int = 0

    // MARK: - Initialization

    public init(fftSize: Int = 2048, hopSize: Int = 512) {
        self.fftSize = fftSize
        self.hopSize = hopSize
        self.log2n = vDSP_Length(log2(Float(fftSize)))

        // Create FFT setup
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))

        // Create Hann window
        self.window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        // Allocate buffers
        self.realBuffer = [Float](repeating: 0, count: fftSize / 2)
        self.imagBuffer = [Float](repeating: 0, count: fftSize / 2)
        self.outputBuffer = [Float](repeating: 0, count: fftSize)
        self.overlapBuffer = [Float](repeating: 0, count: fftSize)
        self.inputAccumulator = [Float](repeating: 0, count: fftSize * 2)
    }

    deinit {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    // MARK: - FFT Operations

    /// Perform forward FFT and extract magnitude/phase
    internal func forwardFFT(_ input: [Float]) -> SpectralFrame {
        guard let fftSetup = fftSetup else { return SpectralFrame(size: fftSize / 2) }

        var frame = SpectralFrame(size: fftSize / 2)

        // Apply window
        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(input, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        // Pack for FFT
        var splitComplex = DSPSplitComplex(realp: &realBuffer, imagp: &imagBuffer)
        windowed.withUnsafeBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexPtr in
                vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
            }
        }

        // Forward FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))

        // Extract magnitude and phase
        for i in 0..<(fftSize / 2) {
            let real = realBuffer[i]
            let imag = imagBuffer[i]
            frame.magnitudes[i] = sqrt(real * real + imag * imag)
            frame.phases[i] = atan2(imag, real)
        }

        return frame
    }

    /// Perform inverse FFT from magnitude/phase
    internal func inverseFFT(_ frame: SpectralFrame) -> [Float] {
        guard let fftSetup = fftSetup else { return [Float](repeating: 0, count: fftSize) }

        // Convert magnitude/phase back to real/imag
        for i in 0..<(fftSize / 2) {
            realBuffer[i] = frame.magnitudes[i] * cos(frame.phases[i])
            imagBuffer[i] = frame.magnitudes[i] * sin(frame.phases[i])
        }

        var splitComplex = DSPSplitComplex(realp: &realBuffer, imagp: &imagBuffer)

        // Inverse FFT
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Inverse))

        // Unpack
        var output = [Float](repeating: 0, count: fftSize)
        output.withUnsafeMutableBufferPointer { ptr in
            ptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexPtr in
                vDSP_ztoc(&splitComplex, 1, complexPtr, 2, vDSP_Length(fftSize / 2))
            }
        }

        // Scale
        var scale = 1.0 / Float(fftSize)
        vDSP_vsmul(output, 1, &scale, &output, 1, vDSP_Length(fftSize))

        // Apply window for overlap-add
        vDSP_vmul(output, 1, window, 1, &output, 1, vDSP_Length(fftSize))

        return output
    }
}

// MARK: - Spectral Freeze

/// Freezes the frequency content at a moment in time
public final class SpectralFreeze: SpectralProcessor {

    // MARK: - Properties

    /// Frozen spectral frame
    private var frozenFrame: SpectralFrame?

    /// Freeze amount (0 = no freeze, 1 = full freeze)
    public var freezeAmount: Float = 0.0

    /// Whether freeze is engaged
    public var isEngaged: Bool = false

    /// Smoothing for freeze transitions
    public var transitionSmoothing: Float = 0.95

    // MARK: - Processing

    /// Process audio buffer
    public func process(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)

        // Accumulate input
        inputAccumulator.replaceSubrange(inputPosition..<inputPosition + input.count, with: input)
        inputPosition += input.count

        // Process when we have enough samples
        while inputPosition >= fftSize {
            // Get frame
            let frame = Array(inputAccumulator[0..<fftSize])

            // Forward FFT
            var spectral = forwardFFT(frame)

            // Apply freeze
            if isEngaged {
                if frozenFrame == nil {
                    // Capture frozen frame
                    frozenFrame = spectral
                } else {
                    // Blend with frozen frame
                    for i in 0..<(fftSize / 2) {
                        spectral.magnitudes[i] = (1 - freezeAmount) * spectral.magnitudes[i] +
                                                  freezeAmount * (frozenFrame?.magnitudes[i] ?? 0)
                        spectral.phases[i] = (1 - freezeAmount) * spectral.phases[i] +
                                             freezeAmount * (frozenFrame?.phases[i] ?? 0)
                    }
                }
            } else {
                frozenFrame = nil
            }

            // Inverse FFT
            let processed = inverseFFT(spectral)

            // Overlap-add
            vDSP_vadd(overlapBuffer, 1, processed, 1, &overlapBuffer, 1, vDSP_Length(fftSize))

            // Output hop
            let outputStart = min(output.count, output.count - (inputPosition - fftSize))
            for i in 0..<hopSize where outputStart + i < output.count {
                output[outputStart + i] = overlapBuffer[i]
            }

            // Shift overlap buffer
            for i in 0..<(fftSize - hopSize) {
                overlapBuffer[i] = overlapBuffer[i + hopSize]
            }
            for i in (fftSize - hopSize)..<fftSize {
                overlapBuffer[i] = 0
            }

            // Shift input accumulator
            for i in 0..<(inputPosition - hopSize) {
                inputAccumulator[i] = inputAccumulator[i + hopSize]
            }
            inputPosition -= hopSize
        }

        return output
    }

    /// Engage freeze at current moment
    public func engage() {
        isEngaged = true
    }

    /// Release freeze
    public func release() {
        isEngaged = false
        frozenFrame = nil
    }
}

// MARK: - Spectral Gate

/// Frequency-selective gating based on magnitude threshold
public final class SpectralGate: SpectralProcessor {

    // MARK: - Properties

    /// Threshold in dB (bins below this are gated)
    public var thresholdDB: Float = -40.0

    /// Ratio (how much to reduce below threshold)
    public var ratio: Float = 0.1

    /// Attack time in seconds
    public var attack: Float = 0.01

    /// Release time in seconds
    public var release: Float = 0.1

    /// Frequency range (normalized 0-1)
    public var frequencyRange: ClosedRange<Float> = 0.0...1.0

    // Per-bin envelope followers
    private var envelopes: [Float]

    // MARK: - Initialization

    public override init(fftSize: Int = 2048, hopSize: Int = 512) {
        self.envelopes = [Float](repeating: 0, count: fftSize / 2)
        super.init(fftSize: fftSize, hopSize: hopSize)
    }

    // MARK: - Processing

    public func process(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)

        inputAccumulator.replaceSubrange(inputPosition..<inputPosition + input.count, with: input)
        inputPosition += input.count

        while inputPosition >= fftSize {
            let frame = Array(inputAccumulator[0..<fftSize])
            var spectral = forwardFFT(frame)

            let threshold = powf(10.0, thresholdDB / 20.0)
            let sampleRate: Float = 44100.0
            let hopSeconds = Float(hopSize) / sampleRate
            let attackCoeff = exp(-hopSeconds / attack)
            let releaseCoeff = exp(-hopSeconds / release)

            // Calculate frequency bin range
            let binCount = fftSize / 2
            let lowBin = Int(frequencyRange.lowerBound * Float(binCount))
            let highBin = Int(frequencyRange.upperBound * Float(binCount))

            // Apply gate per bin
            for i in 0..<binCount {
                let magnitude = spectral.magnitudes[i]

                // Update envelope follower
                if magnitude > envelopes[i] {
                    envelopes[i] = attackCoeff * envelopes[i] + (1 - attackCoeff) * magnitude
                } else {
                    envelopes[i] = releaseCoeff * envelopes[i] + (1 - releaseCoeff) * magnitude
                }

                // Apply gate only in frequency range
                if i >= lowBin && i <= highBin {
                    if envelopes[i] < threshold {
                        spectral.magnitudes[i] *= ratio
                    }
                }
            }

            let processed = inverseFFT(spectral)
            vDSP_vadd(overlapBuffer, 1, processed, 1, &overlapBuffer, 1, vDSP_Length(fftSize))

            for i in 0..<hopSize {
                if i < output.count {
                    output[i] = overlapBuffer[i]
                }
            }

            for i in 0..<(fftSize - hopSize) {
                overlapBuffer[i] = overlapBuffer[i + hopSize]
            }
            for i in (fftSize - hopSize)..<fftSize {
                overlapBuffer[i] = 0
            }

            for i in 0..<(inputPosition - hopSize) {
                inputAccumulator[i] = inputAccumulator[i + hopSize]
            }
            inputPosition -= hopSize
        }

        return output
    }
}

// MARK: - Spectral Shift

/// Shift frequency content up or down
public final class SpectralShift: SpectralProcessor {

    // MARK: - Properties

    /// Shift amount in semitones
    public var shiftSemitones: Float = 0.0

    /// Fine tune in cents
    public var fineTuneCents: Float = 0.0

    /// Formant preservation (0 = none, 1 = full)
    public var formantPreservation: Float = 0.0

    // Phase vocoder state
    private var lastPhases: [Float]
    private var sumPhases: [Float]

    // MARK: - Initialization

    public override init(fftSize: Int = 2048, hopSize: Int = 512) {
        self.lastPhases = [Float](repeating: 0, count: fftSize / 2)
        self.sumPhases = [Float](repeating: 0, count: fftSize / 2)
        super.init(fftSize: fftSize, hopSize: hopSize)
    }

    // MARK: - Processing

    public func process(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)

        inputAccumulator.replaceSubrange(inputPosition..<inputPosition + input.count, with: input)
        inputPosition += input.count

        // Calculate shift ratio
        let totalCents = shiftSemitones * 100.0 + fineTuneCents
        let shiftRatio = powf(2.0, totalCents / 1200.0)

        while inputPosition >= fftSize {
            let frame = Array(inputAccumulator[0..<fftSize])
            var spectral = forwardFFT(frame)

            // Store original for formant preservation
            let originalMagnitudes = spectral.magnitudes

            // Shift bins
            var shiftedMagnitudes = [Float](repeating: 0, count: fftSize / 2)
            var shiftedPhases = [Float](repeating: 0, count: fftSize / 2)

            for i in 0..<(fftSize / 2) {
                let newBin = Float(i) * shiftRatio
                let newBinInt = Int(newBin)
                let frac = newBin - Float(newBinInt)

                if newBinInt >= 0 && newBinInt < fftSize / 2 - 1 {
                    // Linear interpolation for magnitude
                    shiftedMagnitudes[newBinInt] += spectral.magnitudes[i] * (1 - frac)
                    shiftedMagnitudes[newBinInt + 1] += spectral.magnitudes[i] * frac

                    // Phase needs proper vocoder treatment
                    let expectedPhase = lastPhases[i] + 2.0 * Float.pi * Float(i) * Float(hopSize) / Float(fftSize)
                    var phaseDiff = spectral.phases[i] - expectedPhase

                    // Wrap to -pi..pi
                    while phaseDiff > Float.pi { phaseDiff -= 2 * Float.pi }
                    while phaseDiff < -Float.pi { phaseDiff += 2 * Float.pi }

                    let trueFreq = Float(i) + phaseDiff * Float(fftSize) / (2.0 * Float.pi * Float(hopSize))
                    let shiftedFreq = trueFreq * shiftRatio
                    let shiftedPhase = sumPhases[newBinInt] + 2.0 * Float.pi * shiftedFreq * Float(hopSize) / Float(fftSize)

                    shiftedPhases[newBinInt] = shiftedPhase
                }
            }

            // Store phases for next frame
            lastPhases = spectral.phases
            sumPhases = shiftedPhases

            // Apply formant preservation
            if formantPreservation > 0 {
                // Calculate spectral envelope (smoothed magnitude)
                var envelope = [Float](repeating: 0, count: fftSize / 2)
                let smoothingWidth = 10

                for i in 0..<(fftSize / 2) {
                    var sum: Float = 0
                    var count = 0
                    for j in max(0, i - smoothingWidth)..<min(fftSize / 2, i + smoothingWidth) {
                        sum += originalMagnitudes[j]
                        count += 1
                    }
                    envelope[i] = count > 0 ? sum / Float(count) : 0
                }

                // Apply envelope to shifted magnitudes
                for i in 0..<(fftSize / 2) {
                    let shiftedEnvelope = shiftedMagnitudes[i] > 0 ? envelope[i] / max(0.001, shiftedMagnitudes[i]) : 1.0
                    let blended = (1 - formantPreservation) + formantPreservation * shiftedEnvelope
                    shiftedMagnitudes[i] *= blended
                }
            }

            spectral.magnitudes = shiftedMagnitudes
            spectral.phases = shiftedPhases

            let processed = inverseFFT(spectral)
            vDSP_vadd(overlapBuffer, 1, processed, 1, &overlapBuffer, 1, vDSP_Length(fftSize))

            for i in 0..<hopSize where i < output.count {
                output[i] = overlapBuffer[i]
            }

            for i in 0..<(fftSize - hopSize) {
                overlapBuffer[i] = overlapBuffer[i + hopSize]
            }
            for i in (fftSize - hopSize)..<fftSize {
                overlapBuffer[i] = 0
            }

            for i in 0..<(inputPosition - hopSize) {
                inputAccumulator[i] = inputAccumulator[i + hopSize]
            }
            inputPosition -= hopSize
        }

        return output
    }
}

// MARK: - Spectral Blur

/// Smooths spectral content over time for ambient/pad effects
public final class SpectralBlur: SpectralProcessor {

    // MARK: - Properties

    /// Blur amount (0 = none, 1 = full)
    public var blurAmount: Float = 0.5

    /// Temporal smoothing (frames to average)
    public var temporalSmoothing: Int = 8

    /// Frequency smoothing (bins to average)
    public var frequencySmoothing: Int = 4

    // Frame history for temporal blur
    private var frameHistory: [SpectralFrame] = []

    // MARK: - Processing

    public func process(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)

        inputAccumulator.replaceSubrange(inputPosition..<inputPosition + input.count, with: input)
        inputPosition += input.count

        while inputPosition >= fftSize {
            let frame = Array(inputAccumulator[0..<fftSize])
            var spectral = forwardFFT(frame)

            // Add to history
            frameHistory.append(spectral)
            if frameHistory.count > temporalSmoothing {
                frameHistory.removeFirst()
            }

            // Temporal blur (average across frames)
            var blurredMagnitudes = [Float](repeating: 0, count: fftSize / 2)
            for historyFrame in frameHistory {
                for i in 0..<(fftSize / 2) {
                    blurredMagnitudes[i] += historyFrame.magnitudes[i]
                }
            }
            if !frameHistory.isEmpty {
                let scale = 1.0 / Float(frameHistory.count)
                for i in 0..<(fftSize / 2) {
                    blurredMagnitudes[i] *= scale
                }
            }

            // Frequency blur (average across bins)
            var freqBlurred = [Float](repeating: 0, count: fftSize / 2)
            for i in 0..<(fftSize / 2) {
                var sum: Float = 0
                var count = 0
                for j in max(0, i - frequencySmoothing)..<min(fftSize / 2, i + frequencySmoothing + 1) {
                    sum += blurredMagnitudes[j]
                    count += 1
                }
                freqBlurred[i] = count > 0 ? sum / Float(count) : 0
            }

            // Blend with original
            for i in 0..<(fftSize / 2) {
                spectral.magnitudes[i] = (1 - blurAmount) * spectral.magnitudes[i] + blurAmount * freqBlurred[i]
            }

            let processed = inverseFFT(spectral)
            vDSP_vadd(overlapBuffer, 1, processed, 1, &overlapBuffer, 1, vDSP_Length(fftSize))

            for i in 0..<hopSize where i < output.count {
                output[i] = overlapBuffer[i]
            }

            for i in 0..<(fftSize - hopSize) {
                overlapBuffer[i] = overlapBuffer[i + hopSize]
            }
            for i in (fftSize - hopSize)..<fftSize {
                overlapBuffer[i] = 0
            }

            for i in 0..<(inputPosition - hopSize) {
                inputAccumulator[i] = inputAccumulator[i + hopSize]
            }
            inputPosition -= hopSize
        }

        return output
    }

    /// Clear blur history
    public func clearHistory() {
        frameHistory.removeAll()
    }
}

// MARK: - Spectral Morph

/// Morphs between two spectral sources
public final class SpectralMorph: SpectralProcessor {

    // MARK: - Properties

    /// Morph position (0 = source A, 1 = source B)
    public var morphPosition: Float = 0.5

    /// Morph mode
    public var morphMode: MorphMode = .linear

    public enum MorphMode: String, CaseIterable {
        case linear = "Linear"
        case logarithmic = "Logarithmic"
        case crossfade = "Crossfade"
        case spectralEnvelope = "Spectral Envelope"
    }

    // Second source frame
    private var sourceBFrame: SpectralFrame?

    // MARK: - Processing

    /// Set source B from audio
    public func setSourceB(_ samples: [Float]) {
        guard samples.count >= fftSize else { return }
        sourceBFrame = forwardFFT(Array(samples.prefix(fftSize)))
    }

    /// Set source B from spectral frame directly
    public func setSourceB(_ frame: SpectralFrame) {
        sourceBFrame = frame
    }

    public func process(_ input: [Float]) -> [Float] {
        guard let sourceB = sourceBFrame else {
            return input  // No morphing without source B
        }

        var output = [Float](repeating: 0, count: input.count)

        inputAccumulator.replaceSubrange(inputPosition..<inputPosition + input.count, with: input)
        inputPosition += input.count

        while inputPosition >= fftSize {
            let frame = Array(inputAccumulator[0..<fftSize])
            var sourceA = forwardFFT(frame)

            // Morph between sources
            var morphed = SpectralFrame(size: fftSize / 2)

            for i in 0..<(fftSize / 2) {
                switch morphMode {
                case .linear:
                    morphed.magnitudes[i] = (1 - morphPosition) * sourceA.magnitudes[i] + morphPosition * sourceB.magnitudes[i]
                    morphed.phases[i] = (1 - morphPosition) * sourceA.phases[i] + morphPosition * sourceB.phases[i]

                case .logarithmic:
                    let logA = log(max(0.0001, sourceA.magnitudes[i]))
                    let logB = log(max(0.0001, sourceB.magnitudes[i]))
                    morphed.magnitudes[i] = exp((1 - morphPosition) * logA + morphPosition * logB)
                    morphed.phases[i] = (1 - morphPosition) * sourceA.phases[i] + morphPosition * sourceB.phases[i]

                case .crossfade:
                    // Equal power crossfade
                    let gainA = cos(morphPosition * Float.pi / 2)
                    let gainB = sin(morphPosition * Float.pi / 2)
                    morphed.magnitudes[i] = gainA * sourceA.magnitudes[i] + gainB * sourceB.magnitudes[i]
                    morphed.phases[i] = (1 - morphPosition) * sourceA.phases[i] + morphPosition * sourceB.phases[i]

                case .spectralEnvelope:
                    // Preserve source A's envelope, use source B's fine structure
                    let envelopeA = sourceA.magnitudes[i]
                    let envelopeB = sourceB.magnitudes[i]
                    let ratio = envelopeA > 0.0001 ? sourceB.magnitudes[i] / envelopeA : 1.0
                    morphed.magnitudes[i] = (1 - morphPosition) * sourceA.magnitudes[i] + morphPosition * (sourceA.magnitudes[i] * ratio)
                    morphed.phases[i] = (1 - morphPosition) * sourceA.phases[i] + morphPosition * sourceB.phases[i]
                }
            }

            let processed = inverseFFT(morphed)
            vDSP_vadd(overlapBuffer, 1, processed, 1, &overlapBuffer, 1, vDSP_Length(fftSize))

            for i in 0..<hopSize where i < output.count {
                output[i] = overlapBuffer[i]
            }

            for i in 0..<(fftSize - hopSize) {
                overlapBuffer[i] = overlapBuffer[i + hopSize]
            }
            for i in (fftSize - hopSize)..<fftSize {
                overlapBuffer[i] = 0
            }

            for i in 0..<(inputPosition - hopSize) {
                inputAccumulator[i] = inputAccumulator[i + hopSize]
            }
            inputPosition -= hopSize
        }

        return output
    }
}

// MARK: - Unified Spectral Suite

/// Unified interface for all spectral processing
public final class SpectralProcessingSuite {

    public let freeze: SpectralFreeze
    public let gate: SpectralGate
    public let shift: SpectralShift
    public let blur: SpectralBlur
    public let morph: SpectralMorph

    /// Active processor chain
    public var activeProcessors: [SpectralProcessorType] = []

    public enum SpectralProcessorType {
        case freeze
        case gate
        case shift
        case blur
        case morph
    }

    public init(fftSize: Int = 2048, hopSize: Int = 512) {
        self.freeze = SpectralFreeze(fftSize: fftSize, hopSize: hopSize)
        self.gate = SpectralGate(fftSize: fftSize, hopSize: hopSize)
        self.shift = SpectralShift(fftSize: fftSize, hopSize: hopSize)
        self.blur = SpectralBlur(fftSize: fftSize, hopSize: hopSize)
        self.morph = SpectralMorph(fftSize: fftSize, hopSize: hopSize)
    }

    /// Process audio through active processors
    public func process(_ input: [Float]) -> [Float] {
        var output = input

        for processor in activeProcessors {
            switch processor {
            case .freeze:
                output = freeze.process(output)
            case .gate:
                output = gate.process(output)
            case .shift:
                output = shift.process(output)
            case .blur:
                output = blur.process(output)
            case .morph:
                output = morph.process(output)
            }
        }

        return output
    }
}
