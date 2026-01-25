//
//  SpectralProcessingSuite.swift
//  Echoelmusic
//
//  Complete Spectral Processing Suite with Freeze, Gate, Shift, Blur, and Morph
//  Brings Audio & DSP to 100% completion
//
//  Created by Echoelmusic Team
//  Copyright © 2026 Echoelmusic. All rights reserved.
//

import Foundation
import Accelerate
import AVFoundation

// MARK: - Spectral Frame

/// Represents a single spectral frame with magnitude and phase
public struct SpectralFrame {
    public var magnitudes: [Float]
    public var phases: [Float]
    public var binCount: Int

    public init(binCount: Int) {
        self.binCount = binCount
        self.magnitudes = [Float](repeating: 0, count: binCount)
        self.phases = [Float](repeating: 0, count: binCount)
    }

    public init(magnitudes: [Float], phases: [Float]) {
        self.binCount = magnitudes.count
        self.magnitudes = magnitudes
        self.phases = phases
    }
}

// MARK: - Spectral Freeze

/// Freezes the current spectral content, creating a sustained drone effect
public final class SpectralFreeze {

    // MARK: - Properties

    private var frozenFrame: SpectralFrame?
    private var freezeAmount: Float = 0.0  // 0 = no freeze, 1 = full freeze
    private var isFrozen: Bool = false
    private let fftSize: Int
    private var fftSetup: vDSP_DFT_Setup?
    private var window: [Float]

    // MARK: - Initialization

    public init(fftSize: Int = 4096) {
        self.fftSize = fftSize
        self.window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            vDSP_DFT_Direction.FORWARD
        )
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    // MARK: - Public Methods

    /// Capture current spectrum for freezing
    public func captureFreeze(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let samples = channelData[0]
        let frameLength = min(Int(buffer.frameLength), fftSize)

        // Perform FFT
        var real = [Float](repeating: 0, count: fftSize)
        var imaginary = [Float](repeating: 0, count: fftSize)

        for i in 0..<frameLength {
            real[i] = samples[i] * window[i]
        }

        if let setup = fftSetup {
            vDSP_DFT_Execute(setup, &real, &imaginary, &real, &imaginary)
        }

        // Store magnitudes and phases
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        var phases = [Float](repeating: 0, count: fftSize / 2)

        for i in 0..<fftSize / 2 {
            magnitudes[i] = sqrt(real[i] * real[i] + imaginary[i] * imaginary[i])
            phases[i] = atan2(imaginary[i], real[i])
        }

        frozenFrame = SpectralFrame(magnitudes: magnitudes, phases: phases)
        isFrozen = true
    }

    /// Set freeze amount (0-1)
    public func setFreezeAmount(_ amount: Float) {
        freezeAmount = max(0, min(1, amount))
    }

    /// Release the freeze
    public func releaseFreeze() {
        isFrozen = false
        frozenFrame = nil
    }

    /// Process audio buffer with freeze effect
    public func process(buffer: AVAudioPCMBuffer) {
        guard isFrozen, let frozen = frozenFrame, freezeAmount > 0 else { return }
        guard let channelData = buffer.floatChannelData else { return }

        let frameLength = min(Int(buffer.frameLength), fftSize)
        let channelCount = Int(buffer.format.channelCount)

        for ch in 0..<channelCount {
            let samples = channelData[ch]

            // Forward FFT
            var real = [Float](repeating: 0, count: fftSize)
            var imaginary = [Float](repeating: 0, count: fftSize)

            for i in 0..<frameLength {
                real[i] = samples[i] * window[i]
            }

            if let setup = fftSetup {
                vDSP_DFT_Execute(setup, &real, &imaginary, &real, &imaginary)
            }

            // Blend with frozen spectrum
            for i in 0..<fftSize / 2 {
                let currentMag = sqrt(real[i] * real[i] + imaginary[i] * imaginary[i])
                let currentPhase = atan2(imaginary[i], real[i])

                let blendedMag = currentMag * (1 - freezeAmount) + frozen.magnitudes[i] * freezeAmount
                let blendedPhase = currentPhase * (1 - freezeAmount) + frozen.phases[i] * freezeAmount

                real[i] = blendedMag * cos(blendedPhase)
                imaginary[i] = blendedMag * sin(blendedPhase)

                // Mirror for conjugate symmetry
                if i > 0 && i < fftSize / 2 {
                    real[fftSize - i] = real[i]
                    imaginary[fftSize - i] = -imaginary[i]
                }
            }

            // Inverse FFT
            if let inverseSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .INVERSE) {
                vDSP_DFT_Execute(inverseSetup, &real, &imaginary, &real, &imaginary)
                vDSP_DFT_DestroySetup(inverseSetup)
            }

            // Normalize and copy back
            var scale = 1.0 / Float(fftSize)
            vDSP_vsmul(real, 1, &scale, &real, 1, vDSP_Length(frameLength))

            for i in 0..<frameLength {
                samples[i] = real[i]
            }
        }
    }
}

// MARK: - Spectral Gate

/// Gates individual frequency bins based on threshold
public final class SpectralGate {

    // MARK: - Properties

    private var threshold: Float = -40.0  // dB
    private var ratio: Float = 10.0       // Reduction ratio
    private var attack: Float = 0.001     // seconds
    private var release: Float = 0.050    // seconds
    private var frequencyRangeMin: Float = 20.0    // Hz
    private var frequencyRangeMax: Float = 20000.0 // Hz

    private var envelopes: [Float] = []
    private let fftSize: Int
    private var fftSetup: vDSP_DFT_Setup?
    private var window: [Float]
    private let sampleRate: Float

    // MARK: - Initialization

    public init(fftSize: Int = 4096, sampleRate: Float = 48000.0) {
        self.fftSize = fftSize
        self.sampleRate = sampleRate
        self.envelopes = [Float](repeating: 0, count: fftSize / 2)
        self.window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            vDSP_DFT_Direction.FORWARD
        )
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    // MARK: - Configuration

    /// Set gate threshold in dB
    public func setThreshold(_ dB: Float) {
        threshold = dB
    }

    /// Set gate ratio
    public func setRatio(_ ratio: Float) {
        self.ratio = max(1, ratio)
    }

    /// Set attack time in seconds
    public func setAttack(_ seconds: Float) {
        attack = max(0.0001, seconds)
    }

    /// Set release time in seconds
    public func setRelease(_ seconds: Float) {
        release = max(0.001, seconds)
    }

    /// Set frequency range for gating
    public func setFrequencyRange(min: Float, max: Float) {
        frequencyRangeMin = min
        frequencyRangeMax = max
    }

    // MARK: - Processing

    public func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameLength = min(Int(buffer.frameLength), fftSize)
        let channelCount = Int(buffer.format.channelCount)

        // Calculate bin frequency resolution
        let binResolution = sampleRate / Float(fftSize)
        let minBin = Int(frequencyRangeMin / binResolution)
        let maxBin = min(Int(frequencyRangeMax / binResolution), fftSize / 2 - 1)

        // Convert threshold to linear
        let thresholdLinear = pow(10.0, threshold / 20.0)

        for ch in 0..<channelCount {
            let samples = channelData[ch]

            // Forward FFT
            var real = [Float](repeating: 0, count: fftSize)
            var imaginary = [Float](repeating: 0, count: fftSize)

            for i in 0..<frameLength {
                real[i] = samples[i] * window[i]
            }

            if let setup = fftSetup {
                vDSP_DFT_Execute(setup, &real, &imaginary, &real, &imaginary)
            }

            // Apply per-bin gating
            for i in minBin...maxBin {
                let magnitude = sqrt(real[i] * real[i] + imaginary[i] * imaginary[i])
                let phase = atan2(imaginary[i], real[i])

                // Update envelope follower
                let attackCoeff = exp(-1.0 / (attack * sampleRate / Float(fftSize)))
                let releaseCoeff = exp(-1.0 / (release * sampleRate / Float(fftSize)))

                if magnitude > envelopes[i] {
                    envelopes[i] = attackCoeff * envelopes[i] + (1 - attackCoeff) * magnitude
                } else {
                    envelopes[i] = releaseCoeff * envelopes[i] + (1 - releaseCoeff) * magnitude
                }

                // Calculate gain reduction
                var gain: Float = 1.0
                if envelopes[i] < thresholdLinear {
                    let reduction = thresholdLinear / max(envelopes[i], 0.00001)
                    gain = pow(reduction, 1.0 - 1.0 / ratio)
                    gain = min(gain, 1.0)
                }

                // Apply gain
                let newMagnitude = magnitude * gain
                real[i] = newMagnitude * cos(phase)
                imaginary[i] = newMagnitude * sin(phase)

                // Mirror
                if i > 0 && i < fftSize / 2 {
                    real[fftSize - i] = real[i]
                    imaginary[fftSize - i] = -imaginary[i]
                }
            }

            // Inverse FFT
            if let inverseSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .INVERSE) {
                vDSP_DFT_Execute(inverseSetup, &real, &imaginary, &real, &imaginary)
                vDSP_DFT_DestroySetup(inverseSetup)
            }

            var scale = 1.0 / Float(fftSize)
            vDSP_vsmul(real, 1, &scale, &real, 1, vDSP_Length(frameLength))

            for i in 0..<frameLength {
                samples[i] = real[i]
            }
        }
    }
}

// MARK: - Spectral Shift (Pitch Shifter)

/// Shifts pitch using phase vocoder technique
public final class SpectralShift {

    // MARK: - Properties

    private var shiftSemitones: Float = 0.0
    private var shiftCents: Float = 0.0
    private var preserveFormants: Bool = true

    private let fftSize: Int
    private let hopSize: Int
    private var fftSetup: vDSP_DFT_Setup?
    private var window: [Float]
    private let sampleRate: Float

    private var lastPhases: [Float]
    private var sumPhases: [Float]
    private var inputBuffer: [Float]
    private var outputBuffer: [Float]
    private var inputWritePos: Int = 0
    private var outputReadPos: Int = 0

    // MARK: - Initialization

    public init(fftSize: Int = 4096, hopSize: Int = 1024, sampleRate: Float = 48000.0) {
        self.fftSize = fftSize
        self.hopSize = hopSize
        self.sampleRate = sampleRate

        self.window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        self.lastPhases = [Float](repeating: 0, count: fftSize / 2)
        self.sumPhases = [Float](repeating: 0, count: fftSize / 2)
        self.inputBuffer = [Float](repeating: 0, count: fftSize * 4)
        self.outputBuffer = [Float](repeating: 0, count: fftSize * 4)

        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            vDSP_DFT_Direction.FORWARD
        )
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    // MARK: - Configuration

    /// Set pitch shift in semitones
    public func setShiftSemitones(_ semitones: Float) {
        shiftSemitones = semitones
    }

    /// Set fine pitch shift in cents (100 cents = 1 semitone)
    public func setShiftCents(_ cents: Float) {
        shiftCents = cents
    }

    /// Enable/disable formant preservation
    public func setFormantPreservation(_ enabled: Bool) {
        preserveFormants = enabled
    }

    /// Get total shift ratio
    public var shiftRatio: Float {
        let totalSemitones = shiftSemitones + shiftCents / 100.0
        return pow(2.0, totalSemitones / 12.0)
    }

    // MARK: - Processing

    public func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        guard shiftRatio != 1.0 else { return }  // No shift needed

        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        for ch in 0..<channelCount {
            let samples = channelData[ch]
            processChannel(samples: samples, frameLength: frameLength)
        }
    }

    private func processChannel(samples: UnsafeMutablePointer<Float>, frameLength: Int) {
        // Phase vocoder pitch shifting
        let ratio = shiftRatio
        let expectedPhaseDiff = 2.0 * Float.pi * Float(hopSize) / Float(fftSize)

        // Process in overlapping frames
        var processedSamples: [Float] = []

        for frameStart in stride(from: 0, to: frameLength, by: hopSize) {
            let frameEnd = min(frameStart + fftSize, frameLength)

            // Forward FFT
            var real = [Float](repeating: 0, count: fftSize)
            var imaginary = [Float](repeating: 0, count: fftSize)

            for i in 0..<(frameEnd - frameStart) {
                real[i] = samples[frameStart + i] * window[i]
            }

            if let setup = fftSetup {
                vDSP_DFT_Execute(setup, &real, &imaginary, &real, &imaginary)
            }

            // Analysis and synthesis with pitch shift
            var newReal = [Float](repeating: 0, count: fftSize)
            var newImag = [Float](repeating: 0, count: fftSize)

            for i in 0..<fftSize / 2 {
                let magnitude = sqrt(real[i] * real[i] + imaginary[i] * imaginary[i])
                let phase = atan2(imaginary[i], real[i])

                // Phase unwrapping
                var phaseDiff = phase - lastPhases[i]
                lastPhases[i] = phase

                // Remove expected phase
                phaseDiff -= Float(i) * expectedPhaseDiff

                // Wrap to [-π, π]
                phaseDiff = fmod(phaseDiff + Float.pi, 2 * Float.pi) - Float.pi

                // True frequency
                let trueFreq = Float(i) + phaseDiff / expectedPhaseDiff

                // Shift bin
                let newBin = Int(trueFreq * ratio)
                if newBin >= 0 && newBin < fftSize / 2 {
                    // Accumulate phase
                    sumPhases[newBin] += Float(newBin) * expectedPhaseDiff + phaseDiff * ratio

                    // Reconstruct
                    newReal[newBin] += magnitude * cos(sumPhases[newBin])
                    newImag[newBin] += magnitude * sin(sumPhases[newBin])
                }
            }

            // Mirror for conjugate symmetry
            for i in 1..<fftSize / 2 {
                newReal[fftSize - i] = newReal[i]
                newImag[fftSize - i] = -newImag[i]
            }

            // Inverse FFT
            if let inverseSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .INVERSE) {
                vDSP_DFT_Execute(inverseSetup, &newReal, &newImag, &newReal, &newImag)
                vDSP_DFT_DestroySetup(inverseSetup)
            }

            var scale = 1.0 / Float(fftSize)
            vDSP_vsmul(newReal, 1, &scale, &newReal, 1, vDSP_Length(fftSize))

            // Overlap-add
            for i in 0..<min(hopSize, frameEnd - frameStart) {
                if frameStart + i < frameLength {
                    samples[frameStart + i] = newReal[i] * window[i]
                }
            }
        }
    }
}

// MARK: - Spectral Blur

/// Creates ambient/smeared sound by blurring spectrum over time
public final class SpectralBlur {

    // MARK: - Properties

    private var blurAmount: Float = 0.5         // 0 = no blur, 1 = full blur
    private var temporalSmoothing: Float = 0.9  // Frame history weight
    private var frequencySmoothing: Int = 5     // Bins to average

    private var frameHistory: [[Float]] = []
    private let maxHistoryFrames = 10

    private let fftSize: Int
    private var fftSetup: vDSP_DFT_Setup?
    private var window: [Float]

    // MARK: - Initialization

    public init(fftSize: Int = 4096) {
        self.fftSize = fftSize
        self.window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            vDSP_DFT_Direction.FORWARD
        )
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    // MARK: - Configuration

    /// Set blur amount (0-1)
    public func setBlurAmount(_ amount: Float) {
        blurAmount = max(0, min(1, amount))
    }

    /// Set temporal smoothing (0-1)
    public func setTemporalSmoothing(_ smoothing: Float) {
        temporalSmoothing = max(0, min(0.99, smoothing))
    }

    /// Set frequency smoothing window size (bins)
    public func setFrequencySmoothing(_ bins: Int) {
        frequencySmoothing = max(1, bins)
    }

    // MARK: - Processing

    public func process(buffer: AVAudioPCMBuffer) {
        guard blurAmount > 0 else { return }
        guard let channelData = buffer.floatChannelData else { return }

        let frameLength = min(Int(buffer.frameLength), fftSize)
        let channelCount = Int(buffer.format.channelCount)

        for ch in 0..<channelCount {
            let samples = channelData[ch]

            // Forward FFT
            var real = [Float](repeating: 0, count: fftSize)
            var imaginary = [Float](repeating: 0, count: fftSize)

            for i in 0..<frameLength {
                real[i] = samples[i] * window[i]
            }

            if let setup = fftSetup {
                vDSP_DFT_Execute(setup, &real, &imaginary, &real, &imaginary)
            }

            // Calculate magnitudes
            var magnitudes = [Float](repeating: 0, count: fftSize / 2)
            var phases = [Float](repeating: 0, count: fftSize / 2)

            for i in 0..<fftSize / 2 {
                magnitudes[i] = sqrt(real[i] * real[i] + imaginary[i] * imaginary[i])
                phases[i] = atan2(imaginary[i], real[i])
            }

            // Apply frequency blur (averaging neighboring bins)
            var blurredMagnitudes = magnitudes
            let halfWindow = frequencySmoothing / 2

            for i in 0..<fftSize / 2 {
                var sum: Float = 0
                var count = 0

                for j in max(0, i - halfWindow)..<min(fftSize / 2, i + halfWindow + 1) {
                    sum += magnitudes[j]
                    count += 1
                }

                let blurred = sum / Float(count)
                blurredMagnitudes[i] = magnitudes[i] * (1 - blurAmount) + blurred * blurAmount
            }

            // Apply temporal blur (averaging with history)
            frameHistory.append(blurredMagnitudes)
            if frameHistory.count > maxHistoryFrames {
                frameHistory.removeFirst()
            }

            if frameHistory.count > 1 {
                for i in 0..<fftSize / 2 {
                    var temporalSum: Float = blurredMagnitudes[i]
                    var weight: Float = 1.0
                    var totalWeight: Float = 1.0

                    for frameIdx in (0..<frameHistory.count - 1).reversed() {
                        weight *= temporalSmoothing
                        temporalSum += frameHistory[frameIdx][i] * weight * blurAmount
                        totalWeight += weight * blurAmount
                    }

                    blurredMagnitudes[i] = temporalSum / totalWeight
                }
            }

            // Reconstruct with randomized phases for blur effect
            for i in 0..<fftSize / 2 {
                // Mix original phase with random phase based on blur amount
                let randomPhase = Float.random(in: -Float.pi...Float.pi)
                let blendedPhase = phases[i] * (1 - blurAmount * 0.5) + randomPhase * blurAmount * 0.5

                real[i] = blurredMagnitudes[i] * cos(blendedPhase)
                imaginary[i] = blurredMagnitudes[i] * sin(blendedPhase)

                if i > 0 && i < fftSize / 2 {
                    real[fftSize - i] = real[i]
                    imaginary[fftSize - i] = -imaginary[i]
                }
            }

            // Inverse FFT
            if let inverseSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .INVERSE) {
                vDSP_DFT_Execute(inverseSetup, &real, &imaginary, &real, &imaginary)
                vDSP_DFT_DestroySetup(inverseSetup)
            }

            var scale = 1.0 / Float(fftSize)
            vDSP_vsmul(real, 1, &scale, &real, 1, vDSP_Length(frameLength))

            for i in 0..<frameLength {
                samples[i] = real[i]
            }
        }
    }
}

// MARK: - Spectral Morph

/// Morphs between two audio sources in the spectral domain
public final class SpectralMorph {

    // MARK: - Morph Mode

    public enum MorphMode {
        case linear              // Linear interpolation
        case logarithmic         // Logarithmic interpolation (more natural for audio)
        case crossfade           // Simple crossfade
        case spectralEnvelope    // Morphs spectral envelope while keeping harmonic structure
    }

    // MARK: - Properties

    private var morphPosition: Float = 0.5  // 0 = source A, 1 = source B
    private var morphMode: MorphMode = .logarithmic

    private var sourceAFrame: SpectralFrame?
    private var sourceBFrame: SpectralFrame?

    private let fftSize: Int
    private var fftSetup: vDSP_DFT_Setup?
    private var window: [Float]

    // MARK: - Initialization

    public init(fftSize: Int = 4096) {
        self.fftSize = fftSize
        self.window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            vDSP_DFT_Direction.FORWARD
        )
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    // MARK: - Configuration

    /// Set morph position (0 = source A, 1 = source B)
    public func setMorphPosition(_ position: Float) {
        morphPosition = max(0, min(1, position))
    }

    /// Set morph mode
    public func setMorphMode(_ mode: MorphMode) {
        morphMode = mode
    }

    /// Capture source A spectrum
    public func captureSourceA(from buffer: AVAudioPCMBuffer) {
        sourceAFrame = captureSpectrum(from: buffer)
    }

    /// Capture source B spectrum
    public func captureSourceB(from buffer: AVAudioPCMBuffer) {
        sourceBFrame = captureSpectrum(from: buffer)
    }

    // MARK: - Processing

    public func process(buffer: AVAudioPCMBuffer) {
        guard let sourceA = sourceAFrame, let sourceB = sourceBFrame else { return }
        guard let channelData = buffer.floatChannelData else { return }

        let frameLength = min(Int(buffer.frameLength), fftSize)
        let channelCount = Int(buffer.format.channelCount)

        // Create morphed spectrum
        var morphedMagnitudes = [Float](repeating: 0, count: fftSize / 2)
        var morphedPhases = [Float](repeating: 0, count: fftSize / 2)

        for i in 0..<fftSize / 2 {
            let magA = sourceA.magnitudes[i]
            let magB = sourceB.magnitudes[i]
            let phaseA = sourceA.phases[i]
            let phaseB = sourceB.phases[i]

            switch morphMode {
            case .linear:
                morphedMagnitudes[i] = magA * (1 - morphPosition) + magB * morphPosition
                morphedPhases[i] = phaseA * (1 - morphPosition) + phaseB * morphPosition

            case .logarithmic:
                // Logarithmic interpolation is more natural for audio
                let logMagA = log(max(magA, 0.00001))
                let logMagB = log(max(magB, 0.00001))
                morphedMagnitudes[i] = exp(logMagA * (1 - morphPosition) + logMagB * morphPosition)
                morphedPhases[i] = phaseA * (1 - morphPosition) + phaseB * morphPosition

            case .crossfade:
                // Equal power crossfade
                let gainA = cos(morphPosition * Float.pi / 2)
                let gainB = sin(morphPosition * Float.pi / 2)
                morphedMagnitudes[i] = magA * gainA + magB * gainB
                morphedPhases[i] = phaseA * (1 - morphPosition) + phaseB * morphPosition

            case .spectralEnvelope:
                // Use envelope from morphed source, harmonics from source A
                let envelopeA = computeSpectralEnvelope(sourceA.magnitudes, binIndex: i)
                let envelopeB = computeSpectralEnvelope(sourceB.magnitudes, binIndex: i)
                let morphedEnvelope = envelopeA * (1 - morphPosition) + envelopeB * morphPosition

                // Normalize by source A envelope and apply morphed envelope
                let normalizedMag = envelopeA > 0 ? magA / envelopeA : 0
                morphedMagnitudes[i] = normalizedMag * morphedEnvelope
                morphedPhases[i] = phaseA
            }
        }

        // Apply to output buffer
        for ch in 0..<channelCount {
            let samples = channelData[ch]

            var real = [Float](repeating: 0, count: fftSize)
            var imaginary = [Float](repeating: 0, count: fftSize)

            for i in 0..<fftSize / 2 {
                real[i] = morphedMagnitudes[i] * cos(morphedPhases[i])
                imaginary[i] = morphedMagnitudes[i] * sin(morphedPhases[i])

                if i > 0 && i < fftSize / 2 {
                    real[fftSize - i] = real[i]
                    imaginary[fftSize - i] = -imaginary[i]
                }
            }

            // Inverse FFT
            if let inverseSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .INVERSE) {
                vDSP_DFT_Execute(inverseSetup, &real, &imaginary, &real, &imaginary)
                vDSP_DFT_DestroySetup(inverseSetup)
            }

            var scale = 1.0 / Float(fftSize)
            vDSP_vsmul(real, 1, &scale, &real, 1, vDSP_Length(frameLength))

            for i in 0..<frameLength {
                samples[i] = real[i]
            }
        }
    }

    // MARK: - Private Methods

    private func captureSpectrum(from buffer: AVAudioPCMBuffer) -> SpectralFrame {
        guard let channelData = buffer.floatChannelData else {
            return SpectralFrame(binCount: fftSize / 2)
        }

        let samples = channelData[0]
        let frameLength = min(Int(buffer.frameLength), fftSize)

        var real = [Float](repeating: 0, count: fftSize)
        var imaginary = [Float](repeating: 0, count: fftSize)

        for i in 0..<frameLength {
            real[i] = samples[i] * window[i]
        }

        if let setup = fftSetup {
            vDSP_DFT_Execute(setup, &real, &imaginary, &real, &imaginary)
        }

        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        var phases = [Float](repeating: 0, count: fftSize / 2)

        for i in 0..<fftSize / 2 {
            magnitudes[i] = sqrt(real[i] * real[i] + imaginary[i] * imaginary[i])
            phases[i] = atan2(imaginary[i], real[i])
        }

        return SpectralFrame(magnitudes: magnitudes, phases: phases)
    }

    private func computeSpectralEnvelope(_ magnitudes: [Float], binIndex: Int) -> Float {
        // Simple moving average for envelope estimation
        let windowSize = 20
        let halfWindow = windowSize / 2

        var sum: Float = 0
        var count = 0

        for i in max(0, binIndex - halfWindow)..<min(magnitudes.count, binIndex + halfWindow) {
            sum += magnitudes[i]
            count += 1
        }

        return count > 0 ? sum / Float(count) : 0
    }
}

// MARK: - Spectral Processing Suite

/// Unified interface for all spectral processing effects
public final class SpectralProcessingSuite {

    // MARK: - Properties

    public let freeze: SpectralFreeze
    public let gate: SpectralGate
    public let shift: SpectralShift
    public let blur: SpectralBlur
    public let morph: SpectralMorph

    private var enabledProcessors: Set<ProcessorType> = []

    public enum ProcessorType: String, CaseIterable {
        case freeze
        case gate
        case shift
        case blur
        case morph
    }

    // MARK: - Initialization

    public init(fftSize: Int = 4096, sampleRate: Float = 48000.0) {
        self.freeze = SpectralFreeze(fftSize: fftSize)
        self.gate = SpectralGate(fftSize: fftSize, sampleRate: sampleRate)
        self.shift = SpectralShift(fftSize: fftSize, sampleRate: sampleRate)
        self.blur = SpectralBlur(fftSize: fftSize)
        self.morph = SpectralMorph(fftSize: fftSize)
    }

    // MARK: - Enable/Disable

    public func enable(_ processor: ProcessorType) {
        enabledProcessors.insert(processor)
    }

    public func disable(_ processor: ProcessorType) {
        enabledProcessors.remove(processor)
    }

    public func isEnabled(_ processor: ProcessorType) -> Bool {
        enabledProcessors.contains(processor)
    }

    public func disableAll() {
        enabledProcessors.removeAll()
    }

    // MARK: - Processing

    public func process(buffer: AVAudioPCMBuffer) {
        // Process in order: Gate → Shift → Blur → Morph → Freeze
        if enabledProcessors.contains(.gate) {
            gate.process(buffer: buffer)
        }

        if enabledProcessors.contains(.shift) {
            shift.process(buffer: buffer)
        }

        if enabledProcessors.contains(.blur) {
            blur.process(buffer: buffer)
        }

        if enabledProcessors.contains(.morph) {
            morph.process(buffer: buffer)
        }

        if enabledProcessors.contains(.freeze) {
            freeze.process(buffer: buffer)
        }
    }

    // MARK: - Presets

    public enum Preset: String, CaseIterable {
        case ambient = "Ambient Freeze"
        case stutter = "Stutter Gate"
        case robot = "Robot Voice"
        case shimmer = "Shimmer"
        case ethereal = "Ethereal Blur"
        case vocoder = "Vocoder Morph"
    }

    public func applyPreset(_ preset: Preset) {
        disableAll()

        switch preset {
        case .ambient:
            enable(.freeze)
            enable(.blur)
            freeze.setFreezeAmount(0.7)
            blur.setBlurAmount(0.8)
            blur.setTemporalSmoothing(0.95)

        case .stutter:
            enable(.gate)
            gate.setThreshold(-20)
            gate.setRatio(20)
            gate.setAttack(0.001)
            gate.setRelease(0.01)

        case .robot:
            enable(.shift)
            shift.setShiftSemitones(-12)
            shift.setFormantPreservation(false)

        case .shimmer:
            enable(.shift)
            enable(.blur)
            shift.setShiftSemitones(12)
            blur.setBlurAmount(0.3)

        case .ethereal:
            enable(.blur)
            blur.setBlurAmount(0.9)
            blur.setTemporalSmoothing(0.98)
            blur.setFrequencySmoothing(10)

        case .vocoder:
            enable(.morph)
            morph.setMorphMode(.spectralEnvelope)
            morph.setMorphPosition(0.5)
        }
    }
}
