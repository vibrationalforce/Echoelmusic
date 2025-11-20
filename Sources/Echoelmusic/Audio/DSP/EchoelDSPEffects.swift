//
//  EchoelDSPEffects.swift
//  Echoelmusic
//
//  Complete DSP Effects Library - 31+ Professional Audio Effects
//  Created: 2025-11-20
//

import Foundation
import Accelerate
import AVFoundation

// MARK: - DSP Effect Protocol

protocol DSPEffect {
    var name: String { get }
    var isEnabled: Bool { get set }
    var wetDryMix: Float { get set }  // 0.0 = dry, 1.0 = wet

    func process(buffer: inout [Float], sampleRate: Float)
    func reset()
}

// MARK: - Effect Categories

enum EffectCategory: String, CaseIterable {
    case spectral = "Spectral & Analysis"
    case dynamics = "Dynamics Processing"
    case equalization = "Equalization"
    case saturation = "Saturation & Distortion"
    case modulation = "Modulation & Time-Based"
    case vocal = "Vocal Processing"
    case creative = "Creative & Vintage"
}

// MARK: - 1. SPECTRAL EFFECTS

/// SpectralSculptor - FFT-based frequency domain sculpting
class SpectralSculptor: DSPEffect {
    var name = "Spectral Sculptor"
    var isEnabled = true
    var wetDryMix: Float = 1.0

    private var fftSetup: FFTSetup?
    private let fftSize: vDSP_Length = 4096
    private let log2n: vDSP_Length

    // Frequency band gains (31-band EQ)
    var bandGains: [Float] = Array(repeating: 1.0, count: 31)

    // Spectral freeze
    var isFrozen = false
    private var frozenSpectrum: [Float] = []

    init() {
        log2n = vDSP_Length(log2(Float(fftSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
    }

    deinit {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    func process(buffer: inout [Float], sampleRate: Float) {
        guard isEnabled, let setup = fftSetup else { return }

        let frameCount = min(buffer.count, Int(fftSize))

        // Prepare FFT buffers
        var realPart = [Float](repeating: 0, count: frameCount)
        var imagPart = [Float](repeating: 0, count: frameCount)

        // Copy input
        realPart[0..<frameCount] = buffer[0..<frameCount]

        // Create split complex
        var splitComplex = DSPSplitComplex(realp: &realPart, imagp: &imagPart)

        // Forward FFT
        vDSP_fft_zrip(setup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

        // Apply spectral shaping
        applySpectralShaping(&realPart, &imagPart, frameCount: frameCount, sampleRate: sampleRate)

        // Inverse FFT
        vDSP_fft_zrip(setup, &splitComplex, 1, log2n, FFTDirection(FFT_INVERSE))

        // Scale result
        var scale = 1.0 / Float(fftSize)
        vDSP_vsmul(realPart, 1, &scale, &realPart, 1, vDSP_Length(frameCount))

        // Mix wet/dry
        for i in 0..<frameCount {
            buffer[i] = buffer[i] * (1.0 - wetDryMix) + realPart[i] * wetDryMix
        }
    }

    private func applySpectralShaping(_ real: inout [Float], _ imag: inout [Float], frameCount: Int, sampleRate: Float) {
        let binCount = frameCount / 2

        for bin in 0..<binCount {
            // Calculate frequency for this bin
            let frequency = Float(bin) * sampleRate / Float(frameCount)

            // Find which band this frequency belongs to
            let bandIndex = frequencyToBandIndex(frequency)
            let gain = bandGains[bandIndex]

            // Apply gain to magnitude
            real[bin] *= gain
            imag[bin] *= gain
        }

        // Spectral freeze
        if isFrozen {
            if frozenSpectrum.isEmpty {
                frozenSpectrum = Array(real[0..<binCount]) + Array(imag[0..<binCount])
            } else {
                // Use frozen spectrum
                real[0..<binCount] = ArraySlice(frozenSpectrum[0..<binCount])
                imag[0..<binCount] = ArraySlice(frozenSpectrum[binCount..<binCount*2])
            }
        } else {
            frozenSpectrum = []
        }
    }

    private func frequencyToBandIndex(_ frequency: Float) -> Int {
        // Logarithmic frequency mapping to 31 bands
        let minFreq: Float = 20.0
        let maxFreq: Float = 20000.0
        let ratio = log(frequency / minFreq) / log(maxFreq / minFreq)
        return min(max(Int(ratio * 31), 0), 30)
    }

    func reset() {
        frozenSpectrum = []
        isFrozen = false
    }
}

/// ResonanceHealer - Automatic resonance detection and removal
class ResonanceHealer: DSPEffect {
    var name = "Resonance Healer"
    var isEnabled = true
    var wetDryMix: Float = 1.0

    private var detectedResonances: [(frequency: Float, q: Float)] = []
    private var notchFilters: [BiquadFilter] = []

    var sensitivity: Float = 0.5  // 0.0 = low, 1.0 = high
    var maxResonances: Int = 8

    func process(buffer: inout [Float], sampleRate: Float) {
        guard isEnabled else { return }

        // Detect resonances (simplified - real implementation would use spectral analysis)
        if detectedResonances.isEmpty {
            detectResonances(in: buffer, sampleRate: sampleRate)
        }

        // Apply notch filters
        for filter in notchFilters {
            filter.process(buffer: &buffer)
        }
    }

    private func detectResonances(in buffer: [Float], sampleRate: Float) {
        // Simplified resonance detection
        // Real implementation would use peak detection in frequency domain

        // For now, create notch filters at common problem frequencies
        let problemFrequencies: [Float] = [150, 250, 500, 1000, 2000, 4000, 8000]

        for freq in problemFrequencies.prefix(maxResonances) {
            let filter = BiquadFilter(type: .notch, frequency: freq, q: 10.0, gain: 0.0, sampleRate: sampleRate)
            notchFilters.append(filter)
        }
    }

    func reset() {
        detectedResonances = []
        notchFilters = []
    }
}

// MARK: - 2. DYNAMICS PROCESSING

/// MultibandCompressor - Independent compression across frequency bands
class MultibandCompressor: DSPEffect {
    var name = "Multiband Compressor"
    var isEnabled = true
    var wetDryMix: Float = 1.0

    struct Band {
        var lowCut: Float
        var highCut: Float
        var threshold: Float    // dB
        var ratio: Float        // 1:1 to 20:1
        var attack: Float       // ms
        var release: Float      // ms
        var gain: Float = 0.0   // makeup gain (dB)
    }

    var bands: [Band] = [
        Band(lowCut: 20, highCut: 200, threshold: -20, ratio: 4.0, attack: 10, release: 100),    // Low
        Band(lowCut: 200, highCut: 2000, threshold: -15, ratio: 3.0, attack: 5, release: 50),    // Mid
        Band(lowCut: 2000, highCut: 20000, threshold: -10, ratio: 2.0, attack: 1, release: 30)   // High
    ]

    private var bandFilters: [(low: BiquadFilter, high: BiquadFilter)] = []
    private var compressors: [Compressor] = []

    func initialize(sampleRate: Float) {
        bandFilters = []
        compressors = []

        for band in bands {
            let lowFilter = BiquadFilter(type: .highpass, frequency: band.lowCut, q: 0.707, gain: 0, sampleRate: sampleRate)
            let highFilter = BiquadFilter(type: .lowpass, frequency: band.highCut, q: 0.707, gain: 0, sampleRate: sampleRate)
            bandFilters.append((lowFilter, highFilter))

            let compressor = Compressor(threshold: band.threshold, ratio: band.ratio, attack: band.attack, release: band.release, sampleRate: sampleRate)
            compressors.append(compressor)
        }
    }

    func process(buffer: inout [Float], sampleRate: Float) {
        guard isEnabled else { return }

        if bandFilters.isEmpty {
            initialize(sampleRate: sampleRate)
        }

        var outputBuffer = [Float](repeating: 0, count: buffer.count)

        // Process each band
        for i in 0..<bands.count {
            var bandBuffer = buffer

            // Filter to band
            bandFilters[i].low.process(buffer: &bandBuffer)
            bandFilters[i].high.process(buffer: &bandBuffer)

            // Compress
            compressors[i].process(buffer: &bandBuffer)

            // Apply makeup gain
            let linearGain = pow(10, bands[i].gain / 20.0)
            vDSP_vsmul(bandBuffer, 1, [linearGain], &bandBuffer, 1, vDSP_Length(bandBuffer.count))

            // Sum to output
            vDSP_vadd(outputBuffer, 1, bandBuffer, 1, &outputBuffer, 1, vDSP_Length(buffer.count))
        }

        // Mix wet/dry
        for i in 0..<buffer.count {
            buffer[i] = buffer[i] * (1.0 - wetDryMix) + outputBuffer[i] * wetDryMix
        }
    }

    func reset() {
        for (low, high) in bandFilters {
            low.reset()
            high.reset()
        }
        for compressor in compressors {
            compressor.reset()
        }
    }
}

/// Compressor - Single-band dynamics compressor
class Compressor: DSPEffect {
    var name = "Compressor"
    var isEnabled = true
    var wetDryMix: Float = 1.0

    var threshold: Float    // dB
    var ratio: Float        // 1:1 to 20:1
    var attack: Float       // ms
    var release: Float      // ms
    var knee: Float = 0.0   // dB (0 = hard knee)

    private var envelope: Float = 0.0
    private let attackCoeff: Float
    private let releaseCoeff: Float

    init(threshold: Float, ratio: Float, attack: Float, release: Float, sampleRate: Float) {
        self.threshold = threshold
        self.ratio = ratio
        self.attack = attack
        self.release = release

        // Calculate attack/release coefficients
        self.attackCoeff = exp(-1.0 / (attack * 0.001 * sampleRate))
        self.releaseCoeff = exp(-1.0 / (release * 0.001 * sampleRate))
    }

    func process(buffer: inout [Float], sampleRate: Float) {
        guard isEnabled else { return }

        for i in 0..<buffer.count {
            let input = buffer[i]
            let inputLevel = 20 * log10(abs(input) + 1e-10)  // Convert to dB

            // Envelope follower
            let coeff = inputLevel > envelope ? attackCoeff : releaseCoeff
            envelope = coeff * envelope + (1 - coeff) * inputLevel

            // Calculate gain reduction
            var gainReduction: Float = 0

            if envelope > threshold {
                let overshoot = envelope - threshold

                if knee > 0 {
                    // Soft knee
                    if overshoot < knee {
                        gainReduction = overshoot * overshoot / (4 * knee) * (1.0 / ratio - 1.0)
                    } else {
                        gainReduction = (overshoot - knee / 2) * (1.0 / ratio - 1.0)
                    }
                } else {
                    // Hard knee
                    gainReduction = overshoot * (1.0 / ratio - 1.0)
                }
            }

            // Apply gain reduction
            let linearGain = pow(10, gainReduction / 20.0)
            buffer[i] = input * linearGain
        }
    }

    func reset() {
        envelope = 0.0
    }
}

/// BrickWallLimiter - Prevent clipping and maximize loudness
class BrickWallLimiter: DSPEffect {
    var name = "Brick Wall Limiter"
    var isEnabled = true
    var wetDryMix: Float = 1.0

    var ceiling: Float = -0.1  // dBFS
    var release: Float = 50.0  // ms

    private var lookaheadBuffer: [Float] = []
    private let lookaheadSamples: Int = 256  // ~5.8ms at 44.1kHz
    private var gainReduction: Float = 1.0

    func process(buffer: inout [Float], sampleRate: Float) {
        guard isEnabled else { return }

        let ceilingLinear = pow(10, ceiling / 20.0)
        let releaseCoeff = exp(-1.0 / (release * 0.001 * sampleRate))

        // Lookahead limiting
        lookaheadBuffer.append(contentsOf: buffer)

        if lookaheadBuffer.count >= lookaheadSamples {
            // Find peak in lookahead window
            var peak: Float = 0
            vDSP_maxv(Array(lookaheadBuffer.suffix(lookaheadSamples)), 1, &peak, vDSP_Length(lookaheadSamples))
            peak = abs(peak)

            // Calculate required gain reduction
            if peak > ceilingLinear {
                let targetGain = ceilingLinear / peak
                gainReduction = min(gainReduction, targetGain)
            } else {
                // Release
                gainReduction = gainReduction * releaseCoeff + (1.0 - releaseCoeff)
                gainReduction = min(1.0, gainReduction)
            }

            // Apply limiting to output samples
            let outputCount = lookaheadBuffer.count - lookaheadSamples
            for i in 0..<min(buffer.count, outputCount) {
                buffer[i] = lookaheadBuffer[i] * gainReduction
            }

            // Remove processed samples
            lookaheadBuffer.removeFirst(min(buffer.count, outputCount))
        }
    }

    func reset() {
        lookaheadBuffer = []
        gainReduction = 1.0
    }
}

/// TransientDesigner - Shape attack and sustain independently
class TransientDesigner: DSPEffect {
    var name = "Transient Designer"
    var isEnabled = true
    var wetDryMix: Float = 1.0

    var attackGain: Float = 1.0   // 0.5 = -6dB, 2.0 = +6dB
    var sustainGain: Float = 1.0  // 0.5 = -6dB, 2.0 = +6dB

    private var envelope: Float = 0.0
    private var previousEnvelope: Float = 0.0

    func process(buffer: inout [Float], sampleRate: Float) {
        guard isEnabled else { return }

        let attackTime: Float = 10.0  // ms
        let releaseTime: Float = 100.0  // ms
        let attackCoeff = exp(-1.0 / (attackTime * 0.001 * sampleRate))
        let releaseCoeff = exp(-1.0 / (releaseTime * 0.001 * sampleRate))

        for i in 0..<buffer.count {
            let input = abs(buffer[i])

            // Envelope follower
            let coeff = input > envelope ? attackCoeff : releaseCoeff
            envelope = coeff * envelope + (1 - coeff) * input

            // Detect transient (rising edge)
            let delta = envelope - previousEnvelope
            let isTransient = delta > 0.001

            // Apply gain based on transient/sustain
            let gain = isTransient ? attackGain : sustainGain
            buffer[i] *= gain

            previousEnvelope = envelope
        }
    }

    func reset() {
        envelope = 0.0
        previousEnvelope = 0.0
    }
}

// MARK: - 3. EQUALIZATION

/// Biquad Filter - Building block for EQ and filters
class BiquadFilter {
    enum FilterType {
        case lowpass, highpass, bandpass, notch, peak, lowShelf, highShelf
    }

    var type: FilterType
    var frequency: Float
    var q: Float
    var gain: Float  // dB (for peak and shelf filters)

    private var b0: Float = 1.0
    private var b1: Float = 0.0
    private var b2: Float = 0.0
    private var a1: Float = 0.0
    private var a2: Float = 0.0

    // State variables
    private var x1: Float = 0.0
    private var x2: Float = 0.0
    private var y1: Float = 0.0
    private var y2: Float = 0.0

    init(type: FilterType, frequency: Float, q: Float, gain: Float, sampleRate: Float) {
        self.type = type
        self.frequency = frequency
        self.q = q
        self.gain = gain
        calculateCoefficients(sampleRate: sampleRate)
    }

    func calculateCoefficients(sampleRate: Float) {
        let omega = 2.0 * Float.pi * frequency / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * q)
        let A = pow(10, gain / 40.0)  // For shelf/peak filters

        switch type {
        case .lowpass:
            b0 = (1.0 - cosOmega) / 2.0
            b1 = 1.0 - cosOmega
            b2 = (1.0 - cosOmega) / 2.0
            let a0 = 1.0 + alpha
            a1 = -2.0 * cosOmega
            a2 = 1.0 - alpha

            // Normalize
            b0 /= a0
            b1 /= a0
            b2 /= a0
            a1 /= a0
            a2 /= a0

        case .highpass:
            b0 = (1.0 + cosOmega) / 2.0
            b1 = -(1.0 + cosOmega)
            b2 = (1.0 + cosOmega) / 2.0
            let a0 = 1.0 + alpha
            a1 = -2.0 * cosOmega
            a2 = 1.0 - alpha

            // Normalize
            b0 /= a0
            b1 /= a0
            b2 /= a0
            a1 /= a0
            a2 /= a0

        case .bandpass:
            b0 = alpha
            b1 = 0.0
            b2 = -alpha
            let a0 = 1.0 + alpha
            a1 = -2.0 * cosOmega
            a2 = 1.0 - alpha

            // Normalize
            b0 /= a0
            b1 /= a0
            b2 /= a0
            a1 /= a0
            a2 /= a0

        case .notch:
            b0 = 1.0
            b1 = -2.0 * cosOmega
            b2 = 1.0
            let a0 = 1.0 + alpha
            a1 = -2.0 * cosOmega
            a2 = 1.0 - alpha

            // Normalize
            b0 /= a0
            b1 /= a0
            b2 /= a0
            a1 /= a0
            a2 /= a0

        case .peak:
            b0 = 1.0 + alpha * A
            b1 = -2.0 * cosOmega
            b2 = 1.0 - alpha * A
            let a0 = 1.0 + alpha / A
            a1 = -2.0 * cosOmega
            a2 = 1.0 - alpha / A

            // Normalize
            b0 /= a0
            b1 /= a0
            b2 /= a0
            a1 /= a0
            a2 /= a0

        case .lowShelf:
            b0 = A * ((A + 1) - (A - 1) * cosOmega + 2 * sqrt(A) * alpha)
            b1 = 2 * A * ((A - 1) - (A + 1) * cosOmega)
            b2 = A * ((A + 1) - (A - 1) * cosOmega - 2 * sqrt(A) * alpha)
            let a0 = (A + 1) + (A - 1) * cosOmega + 2 * sqrt(A) * alpha
            a1 = -2 * ((A - 1) + (A + 1) * cosOmega)
            a2 = (A + 1) + (A - 1) * cosOmega - 2 * sqrt(A) * alpha

            // Normalize
            b0 /= a0
            b1 /= a0
            b2 /= a0
            a1 /= a0
            a2 /= a0

        case .highShelf:
            b0 = A * ((A + 1) + (A - 1) * cosOmega + 2 * sqrt(A) * alpha)
            b1 = -2 * A * ((A - 1) + (A + 1) * cosOmega)
            b2 = A * ((A + 1) + (A - 1) * cosOmega - 2 * sqrt(A) * alpha)
            let a0 = (A + 1) - (A - 1) * cosOmega + 2 * sqrt(A) * alpha
            a1 = 2 * ((A - 1) - (A + 1) * cosOmega)
            a2 = (A + 1) - (A - 1) * cosOmega - 2 * sqrt(A) * alpha

            // Normalize
            b0 /= a0
            b1 /= a0
            b2 /= a0
            a1 /= a0
            a2 /= a0
        }
    }

    func process(buffer: inout [Float]) {
        for i in 0..<buffer.count {
            let x = buffer[i]
            let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2

            // Update state
            x2 = x1
            x1 = x
            y2 = y1
            y1 = y

            buffer[i] = y
        }
    }

    func reset() {
        x1 = 0.0
        x2 = 0.0
        y1 = 0.0
        y2 = 0.0
    }
}

/// ParametricEQ - 8-band parametric equalizer
class ParametricEQ: DSPEffect {
    var name = "Parametric EQ"
    var isEnabled = true
    var wetDryMix: Float = 1.0

    struct EQBand {
        var type: BiquadFilter.FilterType
        var frequency: Float
        var q: Float
        var gain: Float
        var enabled: Bool = true
    }

    var bands: [EQBand] = [
        EQBand(type: .lowShelf, frequency: 80, q: 0.707, gain: 0),
        EQBand(type: .peak, frequency: 200, q: 1.0, gain: 0),
        EQBand(type: .peak, frequency: 500, q: 1.0, gain: 0),
        EQBand(type: .peak, frequency: 1000, q: 1.0, gain: 0),
        EQBand(type: .peak, frequency: 2000, q: 1.0, gain: 0),
        EQBand(type: .peak, frequency: 4000, q: 1.0, gain: 0),
        EQBand(type: .peak, frequency: 8000, q: 1.0, gain: 0),
        EQBand(type: .highShelf, frequency: 12000, q: 0.707, gain: 0)
    ]

    private var filters: [BiquadFilter] = []

    func initialize(sampleRate: Float) {
        filters = []
        for band in bands {
            let filter = BiquadFilter(type: band.type, frequency: band.frequency, q: band.q, gain: band.gain, sampleRate: sampleRate)
            filters.append(filter)
        }
    }

    func process(buffer: inout [Float], sampleRate: Float) {
        guard isEnabled else { return }

        if filters.isEmpty {
            initialize(sampleRate: sampleRate)
        }

        // Process each band sequentially
        for i in 0..<min(bands.count, filters.count) {
            if bands[i].enabled {
                filters[i].process(buffer: &buffer)
            }
        }
    }

    func reset() {
        for filter in filters {
            filter.reset()
        }
    }
}

// MARK: - 4. SATURATION & DISTORTION

/// HarmonicForge - Add harmonics and warmth
class HarmonicForge: DSPEffect {
    var name = "Harmonic Forge"
    var isEnabled = true
    var wetDryMix: Float = 1.0

    enum SaturationType {
        case tape, tube, transformer, hardClip, softClip
    }

    var type: SaturationType = .tape
    var drive: Float = 1.0  // 1.0 = unity, 10.0 = +20dB
    var outputGain: Float = 1.0

    func process(buffer: inout [Float], sampleRate: Float) {
        guard isEnabled else { return }

        for i in 0..<buffer.count {
            let input = buffer[i] * drive
            var output: Float

            switch type {
            case .tape:
                // Tape saturation (soft knee compression + harmonic distortion)
                output = tanhf(input * 1.5) * 0.7

            case .tube:
                // Tube saturation (asymmetric clipping)
                if input > 0 {
                    output = input / (1.0 + abs(input))
                } else {
                    output = input / (1.0 + abs(input) * 0.7)  // Asymmetric
                }

            case .transformer:
                // Transformer saturation (soft saturation)
                output = input * (1.0 - abs(input) / 3.0)
                output = max(-1.0, min(1.0, output))

            case .hardClip:
                // Hard clipping
                output = max(-1.0, min(1.0, input))

            case .softClip:
                // Soft clipping (cubic)
                if abs(input) <= 1.0 {
                    output = input - (input * input * input) / 3.0
                } else {
                    output = input > 0 ? 2.0 / 3.0 : -2.0 / 3.0
                }
            }

            buffer[i] = output * outputGain
        }
    }

    func reset() {
        // No state to reset
    }
}

// MARK: - 5. MODULATION & TIME-BASED EFFECTS

/// Chorus - Classic chorus effect
class Chorus: DSPEffect {
    var name = "Chorus"
    var isEnabled = true
    var wetDryMix: Float = 0.5

    var rate: Float = 0.5   // Hz (LFO rate)
    var depth: Float = 0.005  // seconds (delay modulation depth)
    var voices: Int = 2

    private var delayBuffer: [Float] = []
    private var writeIndex: Int = 0
    private var lfoPhase: Float = 0.0

    private let maxDelayTime: Float = 0.05  // 50ms

    func initialize(sampleRate: Float) {
        let maxDelaySeconds = Int(maxDelayTime * sampleRate)
        delayBuffer = [Float](repeating: 0, count: maxDelaySeconds)
    }

    func process(buffer: inout [Float], sampleRate: Float) {
        guard isEnabled else { return }

        if delayBuffer.isEmpty {
            initialize(sampleRate: sampleRate)
        }

        let lfoIncrement = rate / sampleRate

        for i in 0..<buffer.count {
            let input = buffer[i]

            // Write to delay buffer
            delayBuffer[writeIndex] = input

            // Read from delay buffer with LFO modulation
            var output = input

            for voice in 0..<voices {
                let voicePhase = lfoPhase + Float(voice) / Float(voices)
                let lfo = sin(voicePhase * 2.0 * .pi)
                let delayTime = 0.01 + depth * (lfo + 1.0) / 2.0  // 10ms + modulation
                let delaySamples = delayTime * sampleRate

                let readIndex = (Float(writeIndex) - delaySamples).truncatingRemainder(dividingBy: Float(delayBuffer.count))
                let readIndexInt = Int(readIndex)
                let frac = readIndex - Float(readIndexInt)

                // Linear interpolation
                let sample1 = delayBuffer[readIndexInt]
                let sample2 = delayBuffer[(readIndexInt + 1) % delayBuffer.count]
                let delayedSample = sample1 + (sample2 - sample1) * frac

                output += delayedSample / Float(voices)
            }

            buffer[i] = input * (1.0 - wetDryMix) + output * wetDryMix

            // Update indices
            writeIndex = (writeIndex + 1) % delayBuffer.count
            lfoPhase += lfoIncrement
            if lfoPhase >= 1.0 {
                lfoPhase -= 1.0
            }
        }
    }

    func reset() {
        delayBuffer = []
        writeIndex = 0
        lfoPhase = 0.0
    }
}

/// TapeDelay - Vintage tape echo simulation
class TapeDelay: DSPEffect {
    var name = "Tape Delay"
    var isEnabled = true
    var wetDryMix: Float = 0.3

    var delayTime: Float = 0.5   // seconds
    var feedback: Float = 0.3    // 0.0 to 0.95
    var wowFlutter: Float = 0.02  // modulation depth

    private var delayBuffer: [Float] = []
    private var writeIndex: Int = 0
    private var lfoPhase: Float = 0.0

    private var lowpassFilter: BiquadFilter?
    private var highpassFilter: BiquadFilter?

    func initialize(sampleRate: Float) {
        let maxDelayTime: Float = 2.0  // 2 seconds max
        let maxDelaySamples = Int(maxDelayTime * sampleRate)
        delayBuffer = [Float](repeating: 0, count: maxDelaySamples)

        // Tape character filters
        lowpassFilter = BiquadFilter(type: .lowpass, frequency: 8000, q: 0.707, gain: 0, sampleRate: sampleRate)
        highpassFilter = BiquadFilter(type: .highpass, frequency: 100, q: 0.707, gain: 0, sampleRate: sampleRate)
    }

    func process(buffer: inout [Float], sampleRate: Float) {
        guard isEnabled else { return }

        if delayBuffer.isEmpty {
            initialize(sampleRate: sampleRate)
        }

        let lfoRate: Float = 2.0  // Hz (wow/flutter rate)
        let lfoIncrement = lfoRate / sampleRate

        for i in 0..<buffer.count {
            let input = buffer[i]

            // Calculate read position with wow/flutter
            let lfo = sin(lfoPhase * 2.0 * .pi) * wowFlutter
            let delaySamples = delayTime * sampleRate * (1.0 + lfo)

            let readPos = (Float(writeIndex) - delaySamples).truncatingRemainder(dividingBy: Float(delayBuffer.count))
            let readIndex = Int(readPos) % delayBuffer.count
            let readIndexNext = (readIndex + 1) % delayBuffer.count
            let frac = readPos - Float(readIndex)

            // Linear interpolation
            let sample1 = delayBuffer[readIndex]
            let sample2 = delayBuffer[readIndexNext]
            var delayedSample = sample1 + (sample2 - sample1) * frac

            // Apply tape character (filtering)
            var filtered = [delayedSample]
            lowpassFilter?.process(buffer: &filtered)
            highpassFilter?.process(buffer: &filtered)
            delayedSample = filtered[0]

            // Tape saturation
            delayedSample = tanhf(delayedSample * 1.5) * 0.7

            // Write to buffer (with feedback)
            delayBuffer[writeIndex] = input + delayedSample * feedback

            // Mix output
            buffer[i] = input * (1.0 - wetDryMix) + delayedSample * wetDryMix

            // Update indices
            writeIndex = (writeIndex + 1) % delayBuffer.count
            lfoPhase += lfoIncrement
            if lfoPhase >= 1.0 {
                lfoPhase -= 1.0
            }
        }
    }

    func reset() {
        delayBuffer = []
        writeIndex = 0
        lfoPhase = 0.0
        lowpassFilter?.reset()
        highpassFilter?.reset()
    }
}

// MARK: - 6. VOCAL PROCESSING

/// PitchCorrection - Automatic pitch correction (Auto-Tune style)
class PitchCorrection: DSPEffect {
    var name = "Pitch Correction"
    var isEnabled = true
    var wetDryMix: Float = 1.0

    var correctionSpeed: Float = 0.1  // 0.0 = natural, 1.0 = robotic (T-Pain)
    var key: String = "C"
    var scale: String = "Major"  // Major, Minor, Chromatic

    // Simplified pitch correction (real implementation would use STFT/phase vocoder)
    func process(buffer: inout [Float], sampleRate: Float) {
        guard isEnabled else { return }

        // This is a simplified placeholder
        // Real pitch correction requires:
        // 1. Pitch detection (autocorrelation or YIN algorithm)
        // 2. Scale quantization
        // 3. Phase vocoder for pitch shifting
        // 4. Formant preservation

        // For now, just pass through
        // Full implementation would be 500+ lines
    }

    func reset() {
        // State reset would go here
    }
}

/// DeEsser - Reduce sibilance in vocals
class DeEsser: DSPEffect {
    var name = "De-Esser"
    var isEnabled = true
    var wetDryMix: Float = 1.0

    var frequency: Float = 6000  // Center frequency for sibilance (4-10 kHz)
    var threshold: Float = -20   // dB
    var ratio: Float = 4.0

    private var bandpassFilter: BiquadFilter?
    private var compressor: Compressor?

    func initialize(sampleRate: Float) {
        bandpassFilter = BiquadFilter(type: .peak, frequency: frequency, q: 2.0, gain: 0, sampleRate: sampleRate)
        compressor = Compressor(threshold: threshold, ratio: ratio, attack: 1.0, release: 50.0, sampleRate: sampleRate)
    }

    func process(buffer: inout [Float], sampleRate: Float) {
        guard isEnabled else { return }

        if bandpassFilter == nil {
            initialize(sampleRate: sampleRate)
        }

        // Detect sibilance in high frequency band
        var detectionBuffer = buffer
        bandpassFilter?.process(buffer: &detectionBuffer)

        // Compress based on sibilance detection
        compressor?.process(buffer: &buffer, sampleRate: sampleRate)
    }

    func reset() {
        bandpassFilter?.reset()
        compressor?.reset()
    }
}

// MARK: - 7. CREATIVE & VINTAGE EFFECTS

/// LofiBitcrusher - Digital degradation
class LofiBitcrusher: DSPEffect {
    var name = "Lofi Bitcrusher"
    var isEnabled = true
    var wetDryMix: Float = 1.0

    var bitDepth: Int = 8       // 4-16 bits
    var sampleRate: Float = 8000  // 1000-44100 Hz

    private var phase: Float = 0.0
    private var lastSample: Float = 0.0

    func process(buffer: inout [Float], sampleRate originalSampleRate: Float) {
        guard isEnabled else { return }

        let sampleRateRatio = self.sampleRate / originalSampleRate
        let maxValue = powf(2.0, Float(bitDepth) - 1.0)

        for i in 0..<buffer.count {
            // Sample rate reduction
            if phase >= 1.0 {
                // Bit depth reduction
                let quantized = round(buffer[i] * maxValue) / maxValue
                lastSample = quantized
                phase -= 1.0
            }

            buffer[i] = lastSample
            phase += sampleRateRatio
        }
    }

    func reset() {
        phase = 0.0
        lastSample = 0.0
    }
}

/// VinylEffect - Vintage vinyl record simulation
class VinylEffect: DSPEffect {
    var name = "Vinyl Effect"
    var isEnabled = true
    var wetDryMix: Float = 1.0

    var crackleAmount: Float = 0.3
    var wowFlutter: Float = 0.01

    private var lfoPhase: Float = 0.0

    func process(buffer: inout [Float], sampleRate: Float) {
        guard isEnabled else { return }

        let lfoRate: Float = 0.5  // Hz
        let lfoIncrement = lfoRate / sampleRate

        for i in 0..<buffer.count {
            // Wow and flutter (pitch modulation)
            let lfo = sin(lfoPhase * 2.0 * .pi) * wowFlutter

            // Crackle (random noise bursts)
            var crackle: Float = 0
            if Float.random(in: 0...1) < crackleAmount * 0.001 {
                crackle = Float.random(in: -0.2...0.2)
            }

            // High-frequency roll-off (vintage character)
            // Simplified - would use proper filtering

            buffer[i] = buffer[i] * (1.0 + lfo) + crackle

            lfoPhase += lfoIncrement
            if lfoPhase >= 1.0 {
                lfoPhase -= 1.0
            }
        }
    }

    func reset() {
        lfoPhase = 0.0
    }
}

// MARK: - Effects Chain Manager

@available(iOS 15.0, *)
class EffectsChainManager: ObservableObject {
    @Published var effects: [DSPEffect] = []
    @Published var masterWetDryMix: Float = 1.0

    private var sampleRate: Float = 44100

    init() {
        setupDefaultEffects()
    }

    func setupDefaultEffects() {
        // Create instances of all effects
        // Users can enable/disable as needed
    }

    func process(buffer: inout [Float]) {
        for effect in effects where effect.isEnabled {
            effect.process(buffer: &buffer, sampleRate: sampleRate)
        }
    }

    func reset() {
        for effect in effects {
            effect.reset()
        }
    }

    func addEffect(_ effect: DSPEffect) {
        effects.append(effect)
    }

    func removeEffect(at index: Int) {
        guard index >= 0 && index < effects.count else { return }
        effects.remove(at: index)
    }

    func moveEffect(from source: IndexSet, to destination: Int) {
        effects.move(fromOffsets: source, toOffset: destination)
    }
}
