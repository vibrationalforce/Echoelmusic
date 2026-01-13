import Foundation
import Accelerate

// MARK: - DSP Effect Protocol

/// Base protocol for all DSP effects
protocol DSPEffect {
    var bypass: Bool { get set }
    mutating func processBlock(buffer: inout [Float], sampleRate: Float)
    mutating func reset()
}

// MARK: - ============================================
// MARK: - DYNAMICS PROCESSORS (1-9)
// MARK: - ============================================

// MARK: - 1. Compressor

/// Standard compressor with threshold, ratio, attack, release, and knee
final class Compressor: DSPEffect {
    // Parameters
    var threshold: Float = -20.0    // dB (-60 to 0)
    var ratio: Float = 4.0          // 1:1 to 20:1
    var attack: Float = 10.0        // ms (0.1 to 100)
    var release: Float = 100.0      // ms (10 to 1000)
    var knee: Float = 6.0           // dB (0 to 12)
    var makeupGain: Float = 0.0     // dB (-12 to 24)
    var bypass: Bool = false

    // State
    private var envelope: Float = 0.0
    private var gainReduction: Float = 0.0

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        let attackCoeff = exp(-1.0 / (attack * 0.001 * sampleRate))
        let releaseCoeff = exp(-1.0 / (release * 0.001 * sampleRate))
        let makeupLinear = pow(10.0, makeupGain / 20.0)

        for i in 0..<buffer.count {
            let inputLevel = abs(buffer[i])

            // Envelope follower
            if inputLevel > envelope {
                envelope = attackCoeff * envelope + (1.0 - attackCoeff) * inputLevel
            } else {
                envelope = releaseCoeff * envelope + (1.0 - releaseCoeff) * inputLevel
            }

            // Convert to dB
            let envelopeDB = 20.0 * log10(max(envelope, 1e-10))

            // Calculate gain reduction with soft knee
            var gr: Float = 0.0
            if envelopeDB > threshold - knee / 2.0 {
                if envelopeDB < threshold + knee / 2.0 {
                    // Soft knee region
                    let x = envelopeDB - threshold + knee / 2.0
                    gr = (1.0 / ratio - 1.0) * x * x / (2.0 * knee)
                } else {
                    // Above knee
                    gr = (threshold - envelopeDB) * (1.0 - 1.0 / ratio)
                }
            }

            gainReduction = gr
            let gain = pow(10.0, gr / 20.0) * makeupLinear
            buffer[i] *= gain
        }
    }

    func reset() {
        envelope = 0.0
        gainReduction = 0.0
    }

    func getGainReduction() -> Float { return gainReduction }
}

// MARK: - 2. FET Compressor (1176-style)

/// Fast FET compressor inspired by UREI 1176
final class FETCompressor: DSPEffect {
    // Parameters
    var input: Float = 0.0          // dB (-12 to 24)
    var output: Float = 0.0         // dB (-24 to 12)
    var attack: Float = 1           // 1-7 (1=fastest ~20us, 7=slowest ~800us)
    var release: Float = 4          // 1-7 (1=fastest ~50ms, 7=slowest ~1.1s)
    var ratio: Float = 4.0          // 4, 8, 12, 20, or "all" (20)
    var bypass: Bool = false

    // State
    private var envelope: Float = 0.0
    private var saturationState: Float = 0.0

    // Attack times in ms (1176-style: fast!)
    private let attackTimes: [Float] = [0.02, 0.08, 0.2, 0.4, 0.5, 0.6, 0.8]
    // Release times in ms
    private let releaseTimes: [Float] = [50, 100, 200, 350, 500, 750, 1100]

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        let attackIdx = max(0, min(6, Int(attack) - 1))
        let releaseIdx = max(0, min(6, Int(release) - 1))
        let attackMs = attackTimes[attackIdx]
        let releaseMs = releaseTimes[releaseIdx]

        let attackCoeff = exp(-1.0 / (attackMs * 0.001 * sampleRate))
        let releaseCoeff = exp(-1.0 / (releaseMs * 0.001 * sampleRate))
        let inputGain = pow(10.0, input / 20.0)
        let outputGain = pow(10.0, output / 20.0)

        // FET characteristic: program-dependent release
        let programReleaseBase: Float = 0.9995

        for i in 0..<buffer.count {
            // Input stage with drive
            var sample = buffer[i] * inputGain

            // FET saturation characteristic
            let satInput = sample * 2.0
            saturationState = saturationState * 0.99 + satInput * 0.01
            sample = tanh(satInput + saturationState * 0.1) * 0.5

            let inputLevel = abs(sample)

            // Program-dependent envelope (FET characteristic)
            let programRelease = pow(programReleaseBase, inputLevel * 1000)
            let effectiveRelease = releaseCoeff * programRelease

            if inputLevel > envelope {
                envelope = attackCoeff * envelope + (1.0 - attackCoeff) * inputLevel
            } else {
                envelope = effectiveRelease * envelope
            }

            // 1176-style compression curve (very aggressive)
            let envelopeDB = 20.0 * log10(max(envelope, 1e-10))
            let threshold: Float = -10.0  // Fixed threshold for 1176-style

            var gr: Float = 0.0
            if envelopeDB > threshold {
                let excess = envelopeDB - threshold
                gr = -excess * (1.0 - 1.0 / ratio)
            }

            let gain = pow(10.0, gr / 20.0) * outputGain
            buffer[i] = sample * gain
        }
    }

    func reset() {
        envelope = 0.0
        saturationState = 0.0
    }
}

// MARK: - 3. Opto Compressor (LA-2A style)

/// Optical compressor with smooth, musical characteristics
final class OptoCompressor: DSPEffect {
    // Parameters
    var peakReduction: Float = 50.0   // 0-100 (amount of compression)
    var gain: Float = 0.0             // dB (-12 to 24)
    var mode: CompressionMode = .compress  // Compress or Limit
    var bypass: Bool = false

    enum CompressionMode {
        case compress  // ~3:1 ratio
        case limit     // ~100:1 ratio
    }

    // State - optical element has slow response
    private var opticalElement: Float = 0.0
    private var attackState: Float = 0.0

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        // LA-2A characteristics: very slow attack/release
        // Attack: 10ms, Release: 60ms (first 50%) + 1-3s (full)
        let attackCoeff = exp(-1.0 / (0.010 * sampleRate))
        let releaseCoeff1 = exp(-1.0 / (0.060 * sampleRate))
        let releaseCoeff2 = exp(-1.0 / (2.0 * sampleRate))

        let ratio: Float = mode == .compress ? 3.0 : 100.0
        let threshold = -30.0 + (100.0 - peakReduction) * 0.3
        let gainLinear = pow(10.0, gain / 20.0)

        for i in 0..<buffer.count {
            let inputLevel = abs(buffer[i])

            // Optical element response (photocell + lamp)
            // Two-stage release characteristic
            if inputLevel > opticalElement {
                attackState = attackCoeff * attackState + (1.0 - attackCoeff) * inputLevel
                opticalElement = attackState
            } else {
                // First stage: fast partial release
                if opticalElement > attackState * 0.5 {
                    opticalElement = releaseCoeff1 * opticalElement
                } else {
                    // Second stage: slow full release
                    opticalElement = releaseCoeff2 * opticalElement
                }
                attackState = opticalElement
            }

            // Soft compression curve (tube + transformer character)
            let envelopeDB = 20.0 * log10(max(opticalElement, 1e-10))
            var gr: Float = 0.0

            if envelopeDB > Float(threshold) {
                let excess = envelopeDB - Float(threshold)
                // Soft knee is inherent to optical design
                let softExcess = excess * excess / (excess + 6.0)
                gr = -softExcess * (1.0 - 1.0 / ratio)
            }

            // Tube warmth (subtle saturation)
            var sample = buffer[i]
            sample = tanh(sample * 1.1) / tanh(1.1)

            let gain = pow(10.0, gr / 20.0) * gainLinear
            buffer[i] = sample * gain
        }
    }

    func reset() {
        opticalElement = 0.0
        attackState = 0.0
    }
}

// MARK: - 4. Multiband Compressor

/// 4-band multiband compressor with crossover filters
final class MultibandCompressor: DSPEffect {
    // Band parameters
    struct BandParams {
        var threshold: Float = -20.0
        var ratio: Float = 3.0
        var attack: Float = 10.0
        var release: Float = 100.0
        var makeupGain: Float = 0.0
        var solo: Bool = false
        var mute: Bool = false
    }

    // Crossover frequencies
    var crossover1: Float = 100.0    // Low/LowMid boundary
    var crossover2: Float = 1000.0   // LowMid/HighMid boundary
    var crossover3: Float = 8000.0   // HighMid/High boundary

    var bands: [BandParams] = [
        BandParams(threshold: -24, ratio: 4.0, attack: 20, release: 200),  // Low
        BandParams(threshold: -20, ratio: 3.0, attack: 10, release: 100),  // LowMid
        BandParams(threshold: -18, ratio: 2.5, attack: 5, release: 80),    // HighMid
        BandParams(threshold: -16, ratio: 2.0, attack: 2, release: 50)     // High
    ]

    var bypass: Bool = false

    // State
    private var envelopes: [Float] = [0, 0, 0, 0]
    private var filterStates: [[Float]] = Array(repeating: [0, 0, 0, 0], count: 4)

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        // Split into 4 bands using Linkwitz-Riley filters
        var bandBuffers: [[Float]] = Array(repeating: [Float](repeating: 0, count: buffer.count), count: 4)

        for i in 0..<buffer.count {
            let sample = buffer[i]

            // Band splitting using cascaded biquads
            let (low, mid, high) = splitSample(sample, sampleRate: sampleRate)
            let (lowMid, highMid) = splitMidSample(mid, sampleRate: sampleRate)

            bandBuffers[0][i] = low
            bandBuffers[1][i] = lowMid
            bandBuffers[2][i] = highMid
            bandBuffers[3][i] = high
        }

        // Process each band
        for bandIdx in 0..<4 {
            processBand(bandIdx: bandIdx, buffer: &bandBuffers[bandIdx], sampleRate: sampleRate)
        }

        // Sum bands
        for i in 0..<buffer.count {
            var sum: Float = 0
            for bandIdx in 0..<4 {
                if !bands[bandIdx].mute {
                    let isSoloed = bands.contains { $0.solo }
                    if !isSoloed || bands[bandIdx].solo {
                        sum += bandBuffers[bandIdx][i]
                    }
                }
            }
            buffer[i] = sum
        }
    }

    private func splitSample(_ sample: Float, sampleRate: Float) -> (low: Float, mid: Float, high: Float) {
        // Simplified crossover (in production use proper LR4 filters)
        let omega1 = 2.0 * Float.pi * crossover1 / sampleRate
        let omega3 = 2.0 * Float.pi * crossover3 / sampleRate

        let lowCoeff = omega1 / (omega1 + 1)
        let highCoeff = 1 / (omega3 + 1)

        filterStates[0][0] = filterStates[0][0] + lowCoeff * (sample - filterStates[0][0])
        let low = filterStates[0][0]

        filterStates[3][0] = filterStates[3][0] + (1 - highCoeff) * (sample - filterStates[3][0])
        let high = sample - filterStates[3][0]

        let mid = sample - low - high
        return (low, mid, high)
    }

    private func splitMidSample(_ sample: Float, sampleRate: Float) -> (lowMid: Float, highMid: Float) {
        let omega2 = 2.0 * Float.pi * crossover2 / sampleRate
        let coeff = omega2 / (omega2 + 1)

        filterStates[1][0] = filterStates[1][0] + coeff * (sample - filterStates[1][0])
        let lowMid = filterStates[1][0]
        let highMid = sample - lowMid
        return (lowMid, highMid)
    }

    private func processBand(bandIdx: Int, buffer: inout [Float], sampleRate: Float) {
        let params = bands[bandIdx]
        let attackCoeff = exp(-1.0 / (params.attack * 0.001 * sampleRate))
        let releaseCoeff = exp(-1.0 / (params.release * 0.001 * sampleRate))
        let makeupLinear = pow(10.0, params.makeupGain / 20.0)

        for i in 0..<buffer.count {
            let inputLevel = abs(buffer[i])

            if inputLevel > envelopes[bandIdx] {
                envelopes[bandIdx] = attackCoeff * envelopes[bandIdx] + (1 - attackCoeff) * inputLevel
            } else {
                envelopes[bandIdx] = releaseCoeff * envelopes[bandIdx]
            }

            let envelopeDB = 20.0 * log10(max(envelopes[bandIdx], 1e-10))
            var gr: Float = 0.0

            if envelopeDB > params.threshold {
                gr = (params.threshold - envelopeDB) * (1.0 - 1.0 / params.ratio)
            }

            let gain = pow(10.0, gr / 20.0) * makeupLinear
            buffer[i] *= gain
        }
    }

    func reset() {
        envelopes = [0, 0, 0, 0]
        filterStates = Array(repeating: [0, 0, 0, 0], count: 4)
    }
}

// MARK: - 5. Brick Wall Limiter

/// True peak brick wall limiter for mastering
final class BrickWallLimiter: DSPEffect {
    // Parameters
    var threshold: Float = -0.3     // dBFS (-12 to 0)
    var ceiling: Float = -0.1       // dBFS (true peak ceiling)
    var release: Float = 100.0      // ms (10 to 1000)
    var lookahead: Float = 5.0      // ms (0 to 10)
    var bypass: Bool = false

    // State
    private var lookaheadBuffer: [Float] = []
    private var gainBuffer: [Float] = []
    private var writePos: Int = 0
    private var gainReduction: Float = 0.0

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        let lookaheadSamples = Int(lookahead * 0.001 * sampleRate)

        // Initialize buffers if needed
        if lookaheadBuffer.count != lookaheadSamples {
            lookaheadBuffer = [Float](repeating: 0, count: max(1, lookaheadSamples))
            gainBuffer = [Float](repeating: 1, count: max(1, lookaheadSamples))
            writePos = 0
        }

        let ceilingLinear = pow(10.0, ceiling / 20.0)
        let thresholdLinear = pow(10.0, threshold / 20.0)
        let releaseCoeff = exp(-1.0 / (release * 0.001 * sampleRate))

        for i in 0..<buffer.count {
            let inputSample = buffer[i]
            let readPos = writePos

            // Calculate required gain for current sample
            let peakLevel = abs(inputSample)
            var requiredGain: Float = 1.0

            if peakLevel > thresholdLinear {
                requiredGain = thresholdLinear / peakLevel
            }

            // True peak detection (4x oversampling approximation)
            let truePeakEstimate = peakLevel * 1.15
            if truePeakEstimate * requiredGain > ceilingLinear {
                requiredGain = ceilingLinear / truePeakEstimate
            }

            // Store gain in lookahead buffer
            gainBuffer[writePos] = requiredGain

            // Find minimum gain in lookahead window (look ahead for peaks)
            var minGain: Float = 1.0
            for j in 0..<lookaheadBuffer.count {
                minGain = min(minGain, gainBuffer[j])
            }

            // Smooth gain changes
            if minGain < gainReduction {
                gainReduction = minGain  // Instant attack
            } else {
                gainReduction = releaseCoeff * gainReduction + (1 - releaseCoeff) * minGain
            }

            // Write input to lookahead buffer
            lookaheadBuffer[writePos] = inputSample
            writePos = (writePos + 1) % lookaheadBuffer.count

            // Output delayed sample with gain
            let delayedSample = lookaheadBuffer[readPos]
            buffer[i] = delayedSample * gainReduction

            // Hard clip safety
            buffer[i] = max(-ceilingLinear, min(ceilingLinear, buffer[i]))
        }
    }

    func reset() {
        lookaheadBuffer = []
        gainBuffer = []
        writePos = 0
        gainReduction = 0.0
    }

    func getGainReduction() -> Float {
        return 20.0 * log10(max(gainReduction, 1e-10))
    }
}

// MARK: - 6. De-Esser

/// Frequency-selective compressor for sibilance control
final class DeEsser: DSPEffect {
    // Parameters
    var threshold: Float = -20.0    // dB (-40 to 0)
    var frequency: Float = 6500.0   // Hz (2000 to 12000)
    var bandwidth: Float = 2.0      // Octaves (0.5 to 4)
    var range: Float = 12.0         // dB max reduction (0 to 24)
    var listenMode: Bool = false    // Monitor detected sibilance
    var bypass: Bool = false

    // State
    private var envelope: Float = 0.0
    private var filterState1: Float = 0.0
    private var filterState2: Float = 0.0

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        // Detection filter coefficients (bandpass around sibilance)
        let omega = 2.0 * Float.pi * frequency / sampleRate
        let q = frequency / (bandwidth * frequency / 2)
        let alpha = sin(omega) / (2.0 * q)

        let b0 = alpha
        let b1: Float = 0.0
        let b2 = -alpha
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cos(omega)
        let a2 = 1.0 - alpha

        // Normalize
        let nb0 = b0 / a0
        let nb1 = b1 / a0
        let nb2 = b2 / a0
        let na1 = a1 / a0
        let na2 = a2 / a0

        let attackCoeff: Float = exp(-1.0 / (0.001 * sampleRate))  // 1ms
        let releaseCoeff: Float = exp(-1.0 / (0.050 * sampleRate))  // 50ms
        let rangeLinear = pow(10.0, -range / 20.0)

        for i in 0..<buffer.count {
            let input = buffer[i]

            // Bandpass filter for sibilance detection
            let detected = nb0 * input + nb1 * filterState1 + nb2 * filterState2
                          - na1 * filterState1 - na2 * filterState2
            filterState2 = filterState1
            filterState1 = detected

            let detectedLevel = abs(detected)

            // Envelope follower
            if detectedLevel > envelope {
                envelope = attackCoeff * envelope + (1 - attackCoeff) * detectedLevel
            } else {
                envelope = releaseCoeff * envelope
            }

            // Calculate gain reduction
            let envelopeDB = 20.0 * log10(max(envelope, 1e-10))
            var gain: Float = 1.0

            if envelopeDB > threshold {
                let excess = envelopeDB - threshold
                let reduction = min(excess, range)
                gain = pow(10.0, -reduction / 20.0)
                gain = max(gain, rangeLinear)
            }

            if listenMode {
                buffer[i] = detected * 4.0  // Boost for monitoring
            } else {
                buffer[i] = input * gain
            }
        }
    }

    func reset() {
        envelope = 0.0
        filterState1 = 0.0
        filterState2 = 0.0
    }
}

// MARK: - 7. Transient Designer

/// Attack and sustain shaping processor
final class TransientDesigner: DSPEffect {
    // Parameters
    var attack: Float = 0.0         // -100 to +100 (soften/enhance)
    var sustain: Float = 0.0        // -100 to +100 (reduce/boost)
    var output: Float = 0.0         // dB (-12 to 12)
    var bypass: Bool = false

    // State
    private var fastEnvelope: Float = 0.0
    private var slowEnvelope: Float = 0.0

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        // Fast envelope for transients (1-5ms)
        let fastAttack = exp(-1.0 / (0.001 * sampleRate))
        let fastRelease = exp(-1.0 / (0.005 * sampleRate))

        // Slow envelope for sustain (50-200ms)
        let slowAttack = exp(-1.0 / (0.020 * sampleRate))
        let slowRelease = exp(-1.0 / (0.200 * sampleRate))

        let attackAmount = attack / 100.0
        let sustainAmount = sustain / 100.0
        let outputGain = pow(10.0, output / 20.0)

        for i in 0..<buffer.count {
            let input = buffer[i]
            let inputLevel = abs(input)

            // Fast envelope (follows transients)
            if inputLevel > fastEnvelope {
                fastEnvelope = fastAttack * fastEnvelope + (1 - fastAttack) * inputLevel
            } else {
                fastEnvelope = fastRelease * fastEnvelope
            }

            // Slow envelope (follows sustain)
            if inputLevel > slowEnvelope {
                slowEnvelope = slowAttack * slowEnvelope + (1 - slowAttack) * inputLevel
            } else {
                slowEnvelope = slowRelease * slowEnvelope
            }

            // Transient detection (difference between fast and slow)
            let transientAmount = max(0, fastEnvelope - slowEnvelope)
            let sustainLevel = slowEnvelope

            // Calculate gain modulation
            var transientGain: Float = 1.0
            var sustainGain: Float = 1.0

            if attackAmount > 0 {
                // Enhance transients
                transientGain = 1.0 + attackAmount * 2.0 * (transientAmount / max(inputLevel, 1e-10))
            } else {
                // Soften transients
                transientGain = 1.0 + attackAmount * (transientAmount / max(inputLevel, 1e-10))
            }

            if sustainAmount > 0 {
                // Boost sustain
                sustainGain = 1.0 + sustainAmount * 0.5 * (sustainLevel / max(inputLevel, 1e-10))
            } else {
                // Reduce sustain
                sustainGain = 1.0 + sustainAmount * 0.5 * (sustainLevel / max(inputLevel, 1e-10))
            }

            let totalGain = transientGain * sustainGain * outputGain
            buffer[i] = input * min(4.0, max(0.1, totalGain))
        }
    }

    func reset() {
        fastEnvelope = 0.0
        slowEnvelope = 0.0
    }
}

// MARK: - 8. Dynamic EQ

/// Frequency-dependent dynamics processor
final class DynamicEQ: DSPEffect {
    struct Band {
        var frequency: Float = 1000.0
        var gain: Float = 0.0           // Target gain in dB
        var q: Float = 1.0
        var threshold: Float = -20.0
        var ratio: Float = 2.0
        var attack: Float = 10.0
        var release: Float = 100.0
        var direction: Direction = .cut

        enum Direction {
            case cut    // Reduce gain when over threshold
            case boost  // Increase gain when over threshold
        }
    }

    var bands: [Band] = []
    var bypass: Bool = false

    // State
    private var envelopes: [Float] = []
    private var filterStates: [[Float]] = []

    init(bandCount: Int = 4) {
        let frequencies: [Float] = [200, 800, 3000, 8000]
        for i in 0..<bandCount {
            bands.append(Band(frequency: frequencies[min(i, frequencies.count - 1)]))
            envelopes.append(0)
            filterStates.append([0, 0, 0, 0])
        }
    }

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        for i in 0..<buffer.count {
            var sample = buffer[i]

            for bandIdx in 0..<bands.count {
                let band = bands[bandIdx]

                // Detection filter
                let detected = applyBandpassFilter(sample, bandIdx: bandIdx, sampleRate: sampleRate)
                let level = abs(detected)

                // Envelope follower
                let attackCoeff = exp(-1.0 / (band.attack * 0.001 * sampleRate))
                let releaseCoeff = exp(-1.0 / (band.release * 0.001 * sampleRate))

                if level > envelopes[bandIdx] {
                    envelopes[bandIdx] = attackCoeff * envelopes[bandIdx] + (1 - attackCoeff) * level
                } else {
                    envelopes[bandIdx] = releaseCoeff * envelopes[bandIdx]
                }

                // Calculate dynamic gain
                let envelopeDB = 20.0 * log10(max(envelopes[bandIdx], 1e-10))
                var dynamicGainDB: Float = 0.0

                if envelopeDB > band.threshold {
                    let excess = envelopeDB - band.threshold
                    let compressed = excess / band.ratio

                    switch band.direction {
                    case .cut:
                        dynamicGainDB = -(excess - compressed)
                    case .boost:
                        dynamicGainDB = band.gain * (1 - exp(-excess / 10.0))
                    }
                }

                // Apply EQ with dynamic gain
                let totalGainDB = band.gain + dynamicGainDB
                sample = applyParametricBand(sample, frequency: band.frequency,
                                            gain: totalGainDB, q: band.q,
                                            sampleRate: sampleRate)
            }

            buffer[i] = sample
        }
    }

    private func applyBandpassFilter(_ input: Float, bandIdx: Int, sampleRate: Float) -> Float {
        let band = bands[bandIdx]
        let omega = 2.0 * Float.pi * band.frequency / sampleRate
        let alpha = sin(omega) / (2.0 * band.q)

        let coeff = alpha / (1 + alpha)
        filterStates[bandIdx][0] = filterStates[bandIdx][0] + coeff * (input - filterStates[bandIdx][0])
        return input - filterStates[bandIdx][0]
    }

    private func applyParametricBand(_ input: Float, frequency: Float, gain: Float,
                                     q: Float, sampleRate: Float) -> Float {
        // Simplified: in production use full biquad
        let gainLinear = pow(10.0, gain / 40.0)
        return input * gainLinear
    }

    func reset() {
        envelopes = [Float](repeating: 0, count: bands.count)
        filterStates = Array(repeating: [0, 0, 0, 0], count: bands.count)
    }
}

// MARK: - 9. Gate

/// Noise gate with hysteresis
final class Gate: DSPEffect {
    // Parameters
    var threshold: Float = -40.0    // dB (-80 to 0)
    var hysteresis: Float = 6.0     // dB (0 to 12)
    var attack: Float = 0.5         // ms (0.01 to 10)
    var hold: Float = 50.0          // ms (0 to 500)
    var release: Float = 100.0      // ms (10 to 2000)
    var range: Float = -80.0        // dB (how much to attenuate when closed)
    var bypass: Bool = false

    // State
    private var envelope: Float = 0.0
    private var gateGain: Float = 0.0
    private var holdCounter: Int = 0
    private var isOpen: Bool = false

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        let openThreshold = pow(10.0, threshold / 20.0)
        let closeThreshold = pow(10.0, (threshold - hysteresis) / 20.0)
        let attackCoeff = exp(-1.0 / (attack * 0.001 * sampleRate))
        let releaseCoeff = exp(-1.0 / (release * 0.001 * sampleRate))
        let holdSamples = Int(hold * 0.001 * sampleRate)
        let rangeLinear = pow(10.0, range / 20.0)

        for i in 0..<buffer.count {
            let inputLevel = abs(buffer[i])

            // Envelope follower
            if inputLevel > envelope {
                envelope = 0.9 * envelope + 0.1 * inputLevel
            } else {
                envelope = 0.9999 * envelope
            }

            // Gate state machine with hysteresis
            if !isOpen && envelope > openThreshold {
                isOpen = true
                holdCounter = holdSamples
            } else if isOpen && envelope < closeThreshold {
                if holdCounter > 0 {
                    holdCounter -= 1
                } else {
                    isOpen = false
                }
            } else if isOpen {
                holdCounter = holdSamples
            }

            // Smooth gate gain
            let targetGain: Float = isOpen ? 1.0 : rangeLinear

            if targetGain > gateGain {
                gateGain = attackCoeff * gateGain + (1 - attackCoeff) * targetGain
            } else {
                gateGain = releaseCoeff * gateGain + (1 - releaseCoeff) * targetGain
            }

            buffer[i] *= gateGain
        }
    }

    func reset() {
        envelope = 0.0
        gateGain = 0.0
        holdCounter = 0
        isOpen = false
    }

    func isGateOpen() -> Bool { return isOpen }
}

// MARK: - ============================================
// MARK: - EQ/FILTER PROCESSORS (10-14)
// MARK: - ============================================

// MARK: - 10. Parametric EQ

/// 8-band fully parametric equalizer
final class ParametricEQ: DSPEffect {
    struct Band {
        var frequency: Float = 1000.0   // Hz (20 to 20000)
        var gain: Float = 0.0           // dB (-18 to 18)
        var q: Float = 1.0              // (0.1 to 10)
        var filterType: FilterType = .peak
        var enabled: Bool = true

        enum FilterType: String, CaseIterable {
            case lowShelf, highShelf, peak, lowPass, highPass, bandPass, notch, allPass
        }
    }

    var bands: [Band] = []
    var bypass: Bool = false

    // State - x/y history for each band
    private var x1: [Float] = []
    private var x2: [Float] = []
    private var y1: [Float] = []
    private var y2: [Float] = []

    init(bandCount: Int = 8) {
        let defaultFreqs: [Float] = [60, 150, 400, 1000, 2500, 6000, 12000, 16000]
        for i in 0..<bandCount {
            bands.append(Band(frequency: defaultFreqs[min(i, defaultFreqs.count - 1)]))
        }
        resetStateArrays()
    }

    private func resetStateArrays() {
        x1 = [Float](repeating: 0, count: bands.count)
        x2 = [Float](repeating: 0, count: bands.count)
        y1 = [Float](repeating: 0, count: bands.count)
        y2 = [Float](repeating: 0, count: bands.count)
    }

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }
        if x1.count != bands.count { resetStateArrays() }

        for i in 0..<buffer.count {
            var sample = buffer[i]

            for bandIdx in 0..<bands.count {
                let band = bands[bandIdx]
                guard band.enabled && abs(band.gain) > 0.01 else { continue }

                let coeffs = calculateCoefficients(band: band, sampleRate: sampleRate)
                sample = processBiquad(sample, bandIdx: bandIdx, coeffs: coeffs)
            }

            buffer[i] = sample
        }
    }

    private func calculateCoefficients(band: Band, sampleRate: Float) -> (b0: Float, b1: Float, b2: Float, a1: Float, a2: Float) {
        let omega = 2.0 * Float.pi * band.frequency / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * band.q)
        let A = pow(10.0, band.gain / 40.0)

        var b0: Float = 0, b1: Float = 0, b2: Float = 0
        var a0: Float = 1, a1: Float = 0, a2: Float = 0

        switch band.filterType {
        case .peak:
            b0 = 1.0 + alpha * A
            b1 = -2.0 * cosOmega
            b2 = 1.0 - alpha * A
            a0 = 1.0 + alpha / A
            a1 = -2.0 * cosOmega
            a2 = 1.0 - alpha / A

        case .lowShelf:
            let sqrtA = sqrt(A)
            let sqrtA2alpha = 2.0 * sqrtA * alpha
            b0 = A * ((A + 1) - (A - 1) * cosOmega + sqrtA2alpha)
            b1 = 2.0 * A * ((A - 1) - (A + 1) * cosOmega)
            b2 = A * ((A + 1) - (A - 1) * cosOmega - sqrtA2alpha)
            a0 = (A + 1) + (A - 1) * cosOmega + sqrtA2alpha
            a1 = -2.0 * ((A - 1) + (A + 1) * cosOmega)
            a2 = (A + 1) + (A - 1) * cosOmega - sqrtA2alpha

        case .highShelf:
            let sqrtA = sqrt(A)
            let sqrtA2alpha = 2.0 * sqrtA * alpha
            b0 = A * ((A + 1) + (A - 1) * cosOmega + sqrtA2alpha)
            b1 = -2.0 * A * ((A - 1) + (A + 1) * cosOmega)
            b2 = A * ((A + 1) + (A - 1) * cosOmega - sqrtA2alpha)
            a0 = (A + 1) - (A - 1) * cosOmega + sqrtA2alpha
            a1 = 2.0 * ((A - 1) - (A + 1) * cosOmega)
            a2 = (A + 1) - (A - 1) * cosOmega - sqrtA2alpha

        case .lowPass:
            b0 = (1.0 - cosOmega) / 2.0
            b1 = 1.0 - cosOmega
            b2 = (1.0 - cosOmega) / 2.0
            a0 = 1.0 + alpha
            a1 = -2.0 * cosOmega
            a2 = 1.0 - alpha

        case .highPass:
            b0 = (1.0 + cosOmega) / 2.0
            b1 = -(1.0 + cosOmega)
            b2 = (1.0 + cosOmega) / 2.0
            a0 = 1.0 + alpha
            a1 = -2.0 * cosOmega
            a2 = 1.0 - alpha

        case .bandPass:
            b0 = alpha
            b1 = 0
            b2 = -alpha
            a0 = 1.0 + alpha
            a1 = -2.0 * cosOmega
            a2 = 1.0 - alpha

        case .notch:
            b0 = 1.0
            b1 = -2.0 * cosOmega
            b2 = 1.0
            a0 = 1.0 + alpha
            a1 = -2.0 * cosOmega
            a2 = 1.0 - alpha

        case .allPass:
            b0 = 1.0 - alpha
            b1 = -2.0 * cosOmega
            b2 = 1.0 + alpha
            a0 = 1.0 + alpha
            a1 = -2.0 * cosOmega
            a2 = 1.0 - alpha
        }

        return (b0/a0, b1/a0, b2/a0, a1/a0, a2/a0)
    }

    private func processBiquad(_ input: Float, bandIdx: Int,
                               coeffs: (b0: Float, b1: Float, b2: Float, a1: Float, a2: Float)) -> Float {
        let output = coeffs.b0 * input + coeffs.b1 * x1[bandIdx] + coeffs.b2 * x2[bandIdx]
                    - coeffs.a1 * y1[bandIdx] - coeffs.a2 * y2[bandIdx]

        x2[bandIdx] = x1[bandIdx]
        x1[bandIdx] = input
        y2[bandIdx] = y1[bandIdx]
        y1[bandIdx] = output

        return output
    }

    func reset() {
        resetStateArrays()
    }
}

// MARK: - 11. Passive EQ (Pultec-style)

/// Pultec-style passive EQ with simultaneous boost and cut
final class PassiveEQ: DSPEffect {
    // Low frequency section
    var lowFrequency: Float = 60.0      // 20, 30, 60, 100 Hz
    var lowBoost: Float = 0.0           // 0-10
    var lowAttenuation: Float = 0.0     // 0-10

    // High frequency section
    var highFrequency: Float = 12000.0  // 3k, 4k, 5k, 8k, 10k, 12k, 16k Hz
    var highBoost: Float = 0.0          // 0-10
    var highBandwidth: Float = 5.0      // 0-10 (sharp to broad)
    var highAttenuation: Float = 0.0    // 0-10
    var highAttenFreq: Float = 5000.0   // 5k, 10k, 20k Hz

    var bypass: Bool = false

    // State
    private var lowBoostState: [Float] = [0, 0]
    private var lowCutState: [Float] = [0, 0]
    private var highBoostState: [Float] = [0, 0]
    private var highCutState: [Float] = [0, 0]

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        for i in 0..<buffer.count {
            var sample = buffer[i]

            // Low frequency boost (inductor-based shelf)
            if lowBoost > 0.1 {
                sample = processLowBoost(sample, sampleRate: sampleRate)
            }

            // Low frequency attenuation
            if lowAttenuation > 0.1 {
                sample = processLowCut(sample, sampleRate: sampleRate)
            }

            // High frequency boost (LC resonant circuit)
            if highBoost > 0.1 {
                sample = processHighBoost(sample, sampleRate: sampleRate)
            }

            // High frequency attenuation (separate shelf)
            if highAttenuation > 0.1 {
                sample = processHighCut(sample, sampleRate: sampleRate)
            }

            buffer[i] = sample
        }
    }

    private func processLowBoost(_ input: Float, sampleRate: Float) -> Float {
        // Pultec low boost: slight resonance at corner frequency
        let omega = 2.0 * Float.pi * lowFrequency / sampleRate
        let gain = lowBoost / 10.0 * 12.0  // Up to 12dB boost
        let q: Float = 0.7  // Pultec has broad Q

        let alpha = sin(omega) / (2.0 * q)
        let A = pow(10.0, gain / 40.0)
        let sqrtA = sqrt(A)

        let b0 = A * ((A + 1) - (A - 1) * cos(omega) + 2 * sqrtA * alpha)
        let b1 = 2 * A * ((A - 1) - (A + 1) * cos(omega))
        let b2 = A * ((A + 1) - (A - 1) * cos(omega) - 2 * sqrtA * alpha)
        let a0 = (A + 1) + (A - 1) * cos(omega) + 2 * sqrtA * alpha
        let a1 = -2 * ((A - 1) + (A + 1) * cos(omega))
        let a2 = (A + 1) + (A - 1) * cos(omega) - 2 * sqrtA * alpha

        let output = (b0/a0) * input + (b1/a0) * lowBoostState[0] + (b2/a0) * lowBoostState[1]
                    - (a1/a0) * lowBoostState[0] - (a2/a0) * lowBoostState[1]

        lowBoostState[1] = lowBoostState[0]
        lowBoostState[0] = output

        return output
    }

    private func processLowCut(_ input: Float, sampleRate: Float) -> Float {
        let omega = 2.0 * Float.pi * lowFrequency / sampleRate
        let gain = -lowAttenuation / 10.0 * 12.0
        let coeff = exp(gain / 20.0 * omega)

        lowCutState[0] = lowCutState[0] + coeff * (input - lowCutState[0])
        return input - (1 - coeff) * lowCutState[0]
    }

    private func processHighBoost(_ input: Float, sampleRate: Float) -> Float {
        let omega = 2.0 * Float.pi * highFrequency / sampleRate
        let gain = highBoost / 10.0 * 12.0
        let q = 0.5 + highBandwidth / 10.0 * 2.0  // Variable bandwidth

        let alpha = sin(omega) / (2.0 * q)
        let A = pow(10.0, gain / 40.0)

        let b0 = 1.0 + alpha * A
        let b1 = -2.0 * cos(omega)
        let b2 = 1.0 - alpha * A
        let a0 = 1.0 + alpha / A
        let a1 = -2.0 * cos(omega)
        let a2 = 1.0 - alpha / A

        let output = (b0/a0) * input + (b1/a0) * highBoostState[0] + (b2/a0) * highBoostState[1]
                    - (a1/a0) * highBoostState[0] - (a2/a0) * highBoostState[1]

        highBoostState[1] = highBoostState[0]
        highBoostState[0] = output

        return output
    }

    private func processHighCut(_ input: Float, sampleRate: Float) -> Float {
        let omega = 2.0 * Float.pi * highAttenFreq / sampleRate
        let gain = -highAttenuation / 10.0 * 12.0
        let coeff = exp(gain / 20.0) * (1 - omega / Float.pi)

        highCutState[0] = highCutState[0] + (1 - coeff) * (input - highCutState[0])
        return highCutState[0]
    }

    func reset() {
        lowBoostState = [0, 0]
        lowCutState = [0, 0]
        highBoostState = [0, 0]
        highCutState = [0, 0]
    }
}

// MARK: - 12. Formant Filter

/// Vowel morphing filter (A/E/I/O/U)
final class FormantFilter: DSPEffect {
    enum Vowel: String, CaseIterable {
        case a, e, i, o, u
    }

    var vowel: Vowel = .a
    var vowelMix: Float = 0.0       // 0-4 for morphing between vowels
    var resonance: Float = 0.7      // 0-1
    var brightness: Float = 0.5     // 0-1
    var bypass: Bool = false

    // Formant frequencies for each vowel (F1, F2, F3)
    private let formants: [Vowel: [Float]] = [
        .a: [800, 1200, 2800],
        .e: [400, 2200, 2800],
        .i: [300, 2300, 3000],
        .o: [500, 900, 2500],
        .u: [350, 700, 2500]
    ]

    // State for 3 bandpass filters
    private var filterStates: [[Float]] = [[0,0,0,0], [0,0,0,0], [0,0,0,0]]

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        let vowels = Vowel.allCases
        let vowelIndex = Int(vowelMix)
        let fraction = vowelMix - Float(vowelIndex)

        let currentVowel = vowels[min(vowelIndex, vowels.count - 1)]
        let nextVowel = vowels[min(vowelIndex + 1, vowels.count - 1)]

        let currentFormants = formants[currentVowel]!
        let nextFormants = formants[nextVowel]!

        // Interpolate formant frequencies
        var targetFormants: [Float] = []
        for i in 0..<3 {
            let freq = currentFormants[i] * (1 - fraction) + nextFormants[i] * fraction
            targetFormants.append(freq * (0.8 + brightness * 0.4))
        }

        for i in 0..<buffer.count {
            let input = buffer[i]
            var output: Float = 0.0

            // Sum 3 resonant bandpass filters
            for f in 0..<3 {
                let filtered = processBandpass(input, formantIndex: f,
                                              frequency: targetFormants[f],
                                              sampleRate: sampleRate)
                // Weight formants (F1 strongest, F3 weakest)
                let weight: Float = [1.0, 0.7, 0.4][f]
                output += filtered * weight
            }

            buffer[i] = output * 0.5  // Normalize
        }
    }

    private func processBandpass(_ input: Float, formantIndex: Int,
                                 frequency: Float, sampleRate: Float) -> Float {
        let omega = 2.0 * Float.pi * frequency / sampleRate
        let q = 5.0 + resonance * 20.0  // High Q for resonant formants
        let alpha = sin(omega) / (2.0 * q)

        let b0 = alpha
        let b1: Float = 0
        let b2 = -alpha
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cos(omega)
        let a2 = 1.0 - alpha

        let state = filterStates[formantIndex]
        let output = (b0/a0) * input + (b1/a0) * state[0] + (b2/a0) * state[1]
                    - (a1/a0) * state[2] - (a2/a0) * state[3]

        filterStates[formantIndex][1] = filterStates[formantIndex][0]
        filterStates[formantIndex][0] = input
        filterStates[formantIndex][3] = filterStates[formantIndex][2]
        filterStates[formantIndex][2] = output

        return output
    }

    func reset() {
        filterStates = [[0,0,0,0], [0,0,0,0], [0,0,0,0]]
    }
}

// MARK: - 13. State Variable Filter

/// Multi-mode state variable filter (LP/HP/BP/Notch/AllPass)
final class StateVariableFilter: DSPEffect {
    enum FilterMode: String, CaseIterable {
        case lowPass, highPass, bandPass, notch, allPass
    }

    var cutoff: Float = 1000.0      // Hz (20 to 20000)
    var resonance: Float = 0.5      // 0-1 (self-oscillation at 1)
    var mode: FilterMode = .lowPass
    var drive: Float = 0.0          // 0-1 (saturation)
    var bypass: Bool = false

    // State
    private var lowPass: Float = 0.0
    private var bandPass: Float = 0.0
    private var highPass: Float = 0.0

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        // Calculate coefficients
        let f = 2.0 * sin(Float.pi * min(cutoff, sampleRate * 0.45) / sampleRate)
        let q = 1.0 - resonance * 0.99  // Avoid division by zero
        let fb = q + q / (1.0 - f)

        for i in 0..<buffer.count {
            var input = buffer[i]

            // Optional drive/saturation
            if drive > 0.01 {
                input = tanh(input * (1.0 + drive * 4.0))
            }

            // SVF algorithm (Hal Chamberlin)
            highPass = input - lowPass - bandPass * fb
            bandPass = bandPass + f * highPass
            lowPass = lowPass + f * bandPass

            // Notch and allpass derived outputs
            let notch = highPass + lowPass
            let allPass = highPass + lowPass - bandPass * fb

            // Select output based on mode
            switch mode {
            case .lowPass:
                buffer[i] = lowPass
            case .highPass:
                buffer[i] = highPass
            case .bandPass:
                buffer[i] = bandPass
            case .notch:
                buffer[i] = notch
            case .allPass:
                buffer[i] = allPass
            }
        }
    }

    func reset() {
        lowPass = 0.0
        bandPass = 0.0
        highPass = 0.0
    }

    /// Get all filter outputs simultaneously (for multimode use)
    func getOutputs() -> (lp: Float, hp: Float, bp: Float, notch: Float) {
        let notch = highPass + lowPass
        return (lowPass, highPass, bandPass, notch)
    }
}

// MARK: - 14. Dynamic Filter

/// Envelope follower controlled filter
final class DynamicFilter: DSPEffect {
    var cutoff: Float = 1000.0      // Base cutoff Hz
    var resonance: Float = 0.5      // 0-1
    var envelopeAmount: Float = 50.0  // Modulation depth (%)
    var attack: Float = 10.0        // ms
    var release: Float = 100.0      // ms
    var direction: Direction = .up  // Filter direction
    var filterType: FilterType = .lowPass
    var bypass: Bool = false

    enum Direction { case up, down }
    enum FilterType { case lowPass, highPass, bandPass }

    // State
    private var envelope: Float = 0.0
    private var svfLow: Float = 0.0
    private var svfBand: Float = 0.0

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        let attackCoeff = exp(-1.0 / (attack * 0.001 * sampleRate))
        let releaseCoeff = exp(-1.0 / (release * 0.001 * sampleRate))
        let modRange = envelopeAmount / 100.0 * 10000.0  // Up to 10kHz modulation

        for i in 0..<buffer.count {
            let input = buffer[i]
            let inputLevel = abs(input)

            // Envelope follower
            if inputLevel > envelope {
                envelope = attackCoeff * envelope + (1 - attackCoeff) * inputLevel
            } else {
                envelope = releaseCoeff * envelope
            }

            // Calculate modulated cutoff
            let modulation = envelope * modRange
            var modulatedCutoff = cutoff

            switch direction {
            case .up:
                modulatedCutoff = cutoff + modulation
            case .down:
                modulatedCutoff = cutoff - modulation
            }

            modulatedCutoff = max(20, min(sampleRate * 0.45, modulatedCutoff))

            // SVF processing
            let f = 2.0 * sin(Float.pi * modulatedCutoff / sampleRate)
            let q = 1.0 - resonance * 0.99
            let fb = q + q / (1.0 - f)

            let highPass = input - svfLow - svfBand * fb
            svfBand = svfBand + f * highPass
            svfLow = svfLow + f * svfBand

            switch filterType {
            case .lowPass:
                buffer[i] = svfLow
            case .highPass:
                buffer[i] = highPass
            case .bandPass:
                buffer[i] = svfBand
            }
        }
    }

    func reset() {
        envelope = 0.0
        svfLow = 0.0
        svfBand = 0.0
    }
}

// MARK: - ============================================
// MARK: - REVERB PROCESSORS (15-19)
// MARK: - ============================================

// MARK: - 15. Convolution Reverb

/// Impulse response based reverb
final class ConvolutionReverb: DSPEffect {
    var mix: Float = 0.3            // 0-1 dry/wet
    var predelay: Float = 0.0       // ms (0 to 100)
    var highCut: Float = 12000.0    // Hz
    var lowCut: Float = 80.0        // Hz
    var bypass: Bool = false

    private var impulseResponse: [Float] = []
    private var irBuffer: [Float] = []
    private var inputBuffer: [Float] = []
    private var outputBuffer: [Float] = []
    private var bufferPosition: Int = 0
    private var fftSize: Int = 0

    init() {
        // Generate default IR (simple exponential decay)
        generateDefaultIR(decay: 2.0, sampleRate: 48000)
    }

    func loadImpulseResponse(_ ir: [Float]) {
        impulseResponse = ir
        setupBuffers()
    }

    func generateDefaultIR(decay: Float, sampleRate: Float) {
        let length = Int(decay * sampleRate)
        impulseResponse = [Float](repeating: 0, count: length)

        // Generate exponential decay with early reflections
        for i in 0..<length {
            let t = Float(i) / sampleRate
            let envelope = exp(-3.0 * t / decay)

            // Add some randomness for diffusion
            let noise = Float.random(in: -1...1)
            impulseResponse[i] = noise * envelope

            // Early reflections
            if i < Int(0.05 * sampleRate) {
                let earlyReflection = sin(Float(i) * 0.1) * exp(-10.0 * t)
                impulseResponse[i] += earlyReflection * 0.3
            }
        }

        setupBuffers()
    }

    private func setupBuffers() {
        guard !impulseResponse.isEmpty else { return }

        // Find next power of 2 for FFT
        fftSize = 1
        while fftSize < impulseResponse.count * 2 {
            fftSize *= 2
        }

        irBuffer = impulseResponse + [Float](repeating: 0, count: fftSize - impulseResponse.count)
        inputBuffer = [Float](repeating: 0, count: fftSize)
        outputBuffer = [Float](repeating: 0, count: fftSize)
        bufferPosition = 0
    }

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass && !impulseResponse.isEmpty else { return }

        // Simplified time-domain convolution for short IRs
        // For production, use overlap-add FFT convolution
        let irLen = min(impulseResponse.count, 4096)  // Limit IR length

        for i in 0..<buffer.count {
            inputBuffer[bufferPosition] = buffer[i]

            var wet: Float = 0.0
            for j in 0..<irLen {
                let readPos = (bufferPosition - j + inputBuffer.count) % inputBuffer.count
                wet += inputBuffer[readPos] * impulseResponse[j]
            }

            // Apply filters
            wet = applyFilters(wet, sampleRate: sampleRate)

            buffer[i] = buffer[i] * (1.0 - mix) + wet * mix
            bufferPosition = (bufferPosition + 1) % inputBuffer.count
        }
    }

    private var hpState: Float = 0
    private var lpState: Float = 0

    private func applyFilters(_ input: Float, sampleRate: Float) -> Float {
        // High-pass filter
        let hpCoeff = exp(-2.0 * Float.pi * lowCut / sampleRate)
        hpState = hpCoeff * (hpState + input)
        let hpOutput = input - hpState

        // Low-pass filter
        let lpCoeff = exp(-2.0 * Float.pi * highCut / sampleRate)
        lpState = lpState + (1 - lpCoeff) * (hpOutput - lpState)

        return lpState
    }

    func reset() {
        inputBuffer = [Float](repeating: 0, count: fftSize)
        outputBuffer = [Float](repeating: 0, count: fftSize)
        bufferPosition = 0
        hpState = 0
        lpState = 0
    }
}

// MARK: - 16. Shimmer Reverb

/// Pitch-shifted reverb tails
final class ShimmerReverb: DSPEffect {
    var mix: Float = 0.3            // 0-1
    var decay: Float = 3.0          // seconds
    var shimmerPitch: Float = 12.0  // semitones (typically octave up)
    var shimmerMix: Float = 0.5     // 0-1 shimmer amount
    var modulation: Float = 0.3     // 0-1
    var highDamp: Float = 0.7       // 0-1 high frequency damping
    var bypass: Bool = false

    // Delay lines for FDN reverb
    private var delayLines: [[Float]] = []
    private var delayLengths: [Int] = [1557, 1617, 1491, 1422, 1277, 1356, 1188, 1116]
    private var delayPositions: [Int] = []
    private var dampFilters: [Float] = []

    // Pitch shifter state
    private var pitchBuffer: [Float] = []
    private var pitchReadPos: Float = 0.0
    private var pitchWritePos: Int = 0

    // Modulation
    private var modPhase: Float = 0.0

    init() {
        setupDelayLines(sampleRate: 48000)
    }

    private func setupDelayLines(sampleRate: Float) {
        let scaleFactor = sampleRate / 48000.0
        delayLines = []
        delayPositions = []
        dampFilters = []

        for length in delayLengths {
            let scaledLength = Int(Float(length) * scaleFactor)
            delayLines.append([Float](repeating: 0, count: scaledLength))
            delayPositions.append(0)
            dampFilters.append(0)
        }

        pitchBuffer = [Float](repeating: 0, count: Int(0.1 * sampleRate))
        pitchReadPos = 0
        pitchWritePos = 0
    }

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        if delayLines.isEmpty { setupDelayLines(sampleRate: sampleRate) }

        let feedback = 1.0 - (1.0 / (decay * sampleRate / Float(delayLengths[0])))
        let pitchRatio = pow(2.0, shimmerPitch / 12.0)
        let modDepth = modulation * 20.0

        for i in 0..<buffer.count {
            let input = buffer[i]
            var reverbOut: Float = 0.0

            // Modulation LFO
            modPhase += 0.3 / sampleRate
            if modPhase > 1.0 { modPhase -= 1.0 }
            let modValue = sin(modPhase * 2.0 * Float.pi)

            // Process FDN
            var delayOutputs: [Float] = []
            for d in 0..<delayLines.count {
                let modOffset = Int(modValue * modDepth) * ((d % 2 == 0) ? 1 : -1)
                let readPos = (delayPositions[d] + modOffset + delayLines[d].count) % delayLines[d].count
                let delayOut = delayLines[d][readPos]

                // High frequency damping
                dampFilters[d] = dampFilters[d] + highDamp * (delayOut - dampFilters[d])
                delayOutputs.append(dampFilters[d])
                reverbOut += dampFilters[d]
            }

            // Householder feedback matrix (simplified)
            for d in 0..<delayLines.count {
                var feedbackSum: Float = input * 0.25
                for od in 0..<delayLines.count {
                    let coeff: Float = (d == od) ? -0.5 : 0.25 / Float(delayLines.count - 1)
                    feedbackSum += delayOutputs[od] * coeff * feedback
                }

                delayLines[d][delayPositions[d]] = feedbackSum
                delayPositions[d] = (delayPositions[d] + 1) % delayLines[d].count
            }

            reverbOut /= Float(delayLines.count)

            // Shimmer: pitch shift the reverb output and feed back
            pitchBuffer[pitchWritePos] = reverbOut
            pitchWritePos = (pitchWritePos + 1) % pitchBuffer.count

            // Granular pitch shift
            let grainSize: Float = 0.02 * sampleRate
            pitchReadPos += pitchRatio
            if pitchReadPos >= Float(pitchBuffer.count) {
                pitchReadPos -= Float(pitchBuffer.count)
            }

            let readIdx = Int(pitchReadPos)
            let frac = pitchReadPos - Float(readIdx)
            let idx0 = readIdx % pitchBuffer.count
            let idx1 = (readIdx + 1) % pitchBuffer.count
            let pitchShifted = pitchBuffer[idx0] * (1 - frac) + pitchBuffer[idx1] * frac

            // Mix shimmer into feedback
            let shimmerSignal = pitchShifted * shimmerMix

            // Final output
            let wet = reverbOut + shimmerSignal * 0.3
            buffer[i] = buffer[i] * (1.0 - mix) + wet * mix
        }
    }

    func reset() {
        for d in 0..<delayLines.count {
            delayLines[d] = [Float](repeating: 0, count: delayLines[d].count)
            delayPositions[d] = 0
            dampFilters[d] = 0
        }
        pitchBuffer = [Float](repeating: 0, count: pitchBuffer.count)
        pitchReadPos = 0
        pitchWritePos = 0
        modPhase = 0
    }
}

// MARK: - 17. Algorithmic Reverb

/// Schroeder/FDN algorithmic reverb
final class AlgorithmicReverb: DSPEffect {
    var mix: Float = 0.3            // 0-1
    var roomSize: Float = 0.7       // 0-1
    var decay: Float = 2.0          // seconds
    var damping: Float = 0.5        // 0-1
    var predelay: Float = 20.0      // ms
    var earlyReflections: Float = 0.5  // 0-1
    var diffusion: Float = 0.7      // 0-1
    var bypass: Bool = false

    // Comb filters (parallel)
    private var combDelays: [[Float]] = []
    private var combPositions: [Int] = []
    private var combFilters: [Float] = []
    private let combLengths: [Int] = [1557, 1617, 1491, 1422]

    // Allpass filters (series)
    private var allpassDelays: [[Float]] = []
    private var allpassPositions: [Int] = []
    private let allpassLengths: [Int] = [225, 556, 441, 341]

    // Predelay
    private var predelayBuffer: [Float] = []
    private var predelayPos: Int = 0

    // Early reflections
    private var erDelays: [[Float]] = []
    private var erPositions: [Int] = []
    private let erTimes: [Float] = [0.013, 0.019, 0.027, 0.031, 0.037, 0.041]
    private let erGains: [Float] = [0.8, 0.7, 0.6, 0.5, 0.4, 0.3]

    init() {
        setupFilters(sampleRate: 48000)
    }

    private func setupFilters(sampleRate: Float) {
        let sizeFactor = 0.5 + roomSize * 1.0

        // Setup comb filters
        combDelays = []
        combPositions = []
        combFilters = []
        for length in combLengths {
            let scaledLength = Int(Float(length) * sizeFactor * sampleRate / 48000)
            combDelays.append([Float](repeating: 0, count: max(1, scaledLength)))
            combPositions.append(0)
            combFilters.append(0)
        }

        // Setup allpass filters
        allpassDelays = []
        allpassPositions = []
        for length in allpassLengths {
            let scaledLength = Int(Float(length) * sizeFactor * sampleRate / 48000)
            allpassDelays.append([Float](repeating: 0, count: max(1, scaledLength)))
            allpassPositions.append(0)
        }

        // Setup predelay
        let predelaySamples = max(1, Int(predelay * 0.001 * sampleRate))
        predelayBuffer = [Float](repeating: 0, count: predelaySamples)
        predelayPos = 0

        // Setup early reflections
        erDelays = []
        erPositions = []
        for time in erTimes {
            let samples = max(1, Int(time * sampleRate))
            erDelays.append([Float](repeating: 0, count: samples))
            erPositions.append(0)
        }
    }

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        if combDelays.isEmpty { setupFilters(sampleRate: sampleRate) }

        let feedback = pow(0.001, 1.0 / (decay * sampleRate / Float(combLengths[0])))
        let dampCoeff = damping

        for i in 0..<buffer.count {
            let input = buffer[i]

            // Predelay
            let predelayed = predelayBuffer[predelayPos]
            predelayBuffer[predelayPos] = input
            predelayPos = (predelayPos + 1) % predelayBuffer.count

            // Early reflections
            var erOutput: Float = 0.0
            for er in 0..<erDelays.count {
                let erOut = erDelays[er][erPositions[er]]
                erDelays[er][erPositions[er]] = input
                erPositions[er] = (erPositions[er] + 1) % erDelays[er].count
                erOutput += erOut * erGains[er]
            }

            // Parallel comb filters
            var combOutput: Float = 0.0
            for c in 0..<combDelays.count {
                let delayed = combDelays[c][combPositions[c]]

                // Lowpass filter in feedback path
                combFilters[c] = combFilters[c] + dampCoeff * (delayed - combFilters[c])

                let feedbackSample = combFilters[c] * feedback + predelayed
                combDelays[c][combPositions[c]] = feedbackSample
                combPositions[c] = (combPositions[c] + 1) % combDelays[c].count

                combOutput += delayed
            }
            combOutput /= Float(combDelays.count)

            // Series allpass filters for diffusion
            var allpassOutput = combOutput
            for a in 0..<allpassDelays.count {
                let delayed = allpassDelays[a][allpassPositions[a]]
                let g = diffusion * 0.7

                let allpassIn = allpassOutput + delayed * g
                allpassDelays[a][allpassPositions[a]] = allpassIn
                allpassPositions[a] = (allpassPositions[a] + 1) % allpassDelays[a].count

                allpassOutput = delayed - allpassIn * g
            }

            // Mix early reflections and late reverb
            let wet = erOutput * earlyReflections + allpassOutput * (1.0 - earlyReflections * 0.5)
            buffer[i] = buffer[i] * (1.0 - mix) + wet * mix
        }
    }

    func reset() {
        for c in 0..<combDelays.count {
            combDelays[c] = [Float](repeating: 0, count: combDelays[c].count)
            combPositions[c] = 0
            combFilters[c] = 0
        }
        for a in 0..<allpassDelays.count {
            allpassDelays[a] = [Float](repeating: 0, count: allpassDelays[a].count)
            allpassPositions[a] = 0
        }
        for er in 0..<erDelays.count {
            erDelays[er] = [Float](repeating: 0, count: erDelays[er].count)
            erPositions[er] = 0
        }
        predelayBuffer = [Float](repeating: 0, count: predelayBuffer.count)
        predelayPos = 0
    }
}

// MARK: - 18. Spring Reverb

/// Spring tank emulation
final class SpringReverb: DSPEffect {
    var mix: Float = 0.3            // 0-1
    var decay: Float = 2.5          // seconds
    var tone: Float = 0.6           // 0-1 (dark to bright)
    var tension: Float = 0.5        // 0-1 (spring tension)
    var drip: Float = 0.3           // 0-1 (characteristic spring sound)
    var bypass: Bool = false

    // Spring simulation delays
    private var springDelays: [[Float]] = []
    private var springPositions: [Int] = []
    private let springLengths: [Int] = [3001, 2801, 2603]  // Prime-ish numbers
    private var allpassStates: [[Float]] = []

    // Chirp/drip effect
    private var dripPhase: Float = 0.0
    private var dripAmount: Float = 0.0

    // Tone control filter
    private var toneFilterState: Float = 0.0

    init() {
        setupSprings(sampleRate: 48000)
    }

    private func setupSprings(sampleRate: Float) {
        springDelays = []
        springPositions = []
        allpassStates = []

        for length in springLengths {
            let scaledLength = Int(Float(length) * sampleRate / 48000)
            springDelays.append([Float](repeating: 0, count: max(1, scaledLength)))
            springPositions.append(0)
            allpassStates.append([0, 0])
        }
    }

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        if springDelays.isEmpty { setupSprings(sampleRate: sampleRate) }

        let feedback = pow(0.001, 1.0 / (decay * sampleRate / Float(springLengths[0])))
        let dispersionAmount = 0.3 + tension * 0.5

        for i in 0..<buffer.count {
            let input = buffer[i]
            var springOut: Float = 0.0

            // Detect transients for drip effect
            let transient = abs(input) - dripAmount
            if transient > 0 {
                dripAmount = abs(input)
            } else {
                dripAmount *= 0.999
            }

            // Process each spring
            for s in 0..<springDelays.count {
                let delayed = springDelays[s][springPositions[s]]

                // Dispersion allpass (frequency-dependent delay)
                let dispersionFreq = 200.0 + Float(s) * 300.0
                let omega = 2.0 * Float.pi * dispersionFreq / sampleRate
                let g = (1.0 - tan(omega * dispersionAmount)) / (1.0 + tan(omega * dispersionAmount))

                let allpassIn = delayed + allpassStates[s][0] * g
                let allpassOut = allpassStates[s][0] - allpassIn * g
                allpassStates[s][0] = allpassIn

                // Spring chirp/drip modulation
                dripPhase += 0.0001 + dripAmount * drip * 0.01
                let chirpMod = sin(dripPhase * 100) * dripAmount * drip * 0.1

                // Write to delay with feedback
                let feedbackSample = input + allpassOut * feedback * (1.0 + chirpMod)
                springDelays[s][springPositions[s]] = feedbackSample
                springPositions[s] = (springPositions[s] + 1) % springDelays[s].count

                springOut += allpassOut
            }

            springOut /= Float(springDelays.count)

            // Tone control (spring tanks have limited bandwidth)
            let toneCoeff = 0.2 + tone * 0.6
            toneFilterState = toneFilterState + toneCoeff * (springOut - toneFilterState)

            buffer[i] = buffer[i] * (1.0 - mix) + toneFilterState * mix
        }
    }

    func reset() {
        for s in 0..<springDelays.count {
            springDelays[s] = [Float](repeating: 0, count: springDelays[s].count)
            springPositions[s] = 0
            allpassStates[s] = [0, 0]
        }
        dripPhase = 0
        dripAmount = 0
        toneFilterState = 0
    }
}

// MARK: - 19. Plate Reverb

/// EMT 140 style plate reverb
final class PlateReverb: DSPEffect {
    var mix: Float = 0.3            // 0-1
    var decay: Float = 2.0          // seconds
    var damping: Float = 0.5        // 0-1
    var predelay: Float = 0.0       // ms
    var lowDamp: Float = 0.3        // 0-1
    var highDamp: Float = 0.6       // 0-1
    var modulation: Float = 0.2     // 0-1
    var bypass: Bool = false

    // FDN for plate simulation
    private var delayLines: [[Float]] = []
    private var delayPositions: [Int] = []
    private let delayLengths: [Int] = [142, 107, 379, 277, 439, 337, 563, 457]
    private var dampingFilters: [[Float]] = []

    // Modulation
    private var modPhase: Float = 0.0

    // Predelay
    private var predelayBuffer: [Float] = []
    private var predelayPos: Int = 0

    // Input diffusion allpasses
    private var inputAllpass: [[Float]] = []
    private var inputAPPos: [Int] = []

    init() {
        setupPlate(sampleRate: 48000)
    }

    private func setupPlate(sampleRate: Float) {
        delayLines = []
        delayPositions = []
        dampingFilters = []

        for length in delayLengths {
            let scaledLength = max(1, Int(Float(length) * sampleRate / 48000 * 10))
            delayLines.append([Float](repeating: 0, count: scaledLength))
            delayPositions.append(0)
            dampingFilters.append([0, 0])  // LP and HP states
        }

        // Predelay
        let pdSamples = max(1, Int(predelay * 0.001 * sampleRate))
        predelayBuffer = [Float](repeating: 0, count: pdSamples)
        predelayPos = 0

        // Input diffusion
        inputAllpass = []
        inputAPPos = []
        let apLengths = [142, 107, 379, 277]
        for length in apLengths {
            let scaled = max(1, Int(Float(length) * sampleRate / 48000))
            inputAllpass.append([Float](repeating: 0, count: scaled))
            inputAPPos.append(0)
        }
    }

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        if delayLines.isEmpty { setupPlate(sampleRate: sampleRate) }

        let feedback = pow(0.001, 1.0 / (decay * sampleRate / 1000))
        let modDepth = modulation * 8.0

        for i in 0..<buffer.count {
            var input = buffer[i]

            // Predelay
            if !predelayBuffer.isEmpty {
                let predelayed = predelayBuffer[predelayPos]
                predelayBuffer[predelayPos] = input
                predelayPos = (predelayPos + 1) % predelayBuffer.count
                input = predelayed
            }

            // Input diffusion (nested allpasses)
            var diffused = input
            for ap in 0..<inputAllpass.count {
                let delayed = inputAllpass[ap][inputAPPos[ap]]
                let g: Float = 0.75

                let apIn = diffused + delayed * g
                inputAllpass[ap][inputAPPos[ap]] = apIn
                inputAPPos[ap] = (inputAPPos[ap] + 1) % inputAllpass[ap].count

                diffused = delayed - apIn * g
            }

            // Modulation LFO
            modPhase += 1.3 / sampleRate
            if modPhase > 1.0 { modPhase -= 1.0 }
            let mod1 = sin(modPhase * 2.0 * Float.pi)
            let mod2 = sin(modPhase * 2.0 * Float.pi * 1.13)

            // Process FDN
            var delayOutputs: [Float] = [Float](repeating: 0, count: delayLines.count)
            for d in 0..<delayLines.count {
                let modOffset = Int(((d % 2 == 0) ? mod1 : mod2) * modDepth)
                let readPos = (delayPositions[d] + modOffset + delayLines[d].count) % delayLines[d].count
                delayOutputs[d] = delayLines[d][readPos]

                // Two-band damping (plate characteristic)
                // Low damping
                dampingFilters[d][0] += lowDamp * 0.3 * (delayOutputs[d] - dampingFilters[d][0])
                // High damping
                dampingFilters[d][1] += highDamp * (delayOutputs[d] - dampingFilters[d][0] - dampingFilters[d][1])

                delayOutputs[d] = dampingFilters[d][0] + dampingFilters[d][1] * (1 - highDamp)
            }

            // Hadamard-like mixing matrix
            for d in 0..<delayLines.count {
                var sum = diffused / 4.0
                for od in 0..<delayLines.count {
                    let sign: Float = ((d + od) % 2 == 0) ? 1.0 : -1.0
                    sum += delayOutputs[od] * sign * feedback / Float(delayLines.count)
                }
                delayLines[d][delayPositions[d]] = sum
                delayPositions[d] = (delayPositions[d] + 1) % delayLines[d].count
            }

            // Output mix
            var plateOut: Float = 0.0
            for d in stride(from: 0, to: delayLines.count, by: 2) {
                plateOut += delayOutputs[d] - delayOutputs[d + 1]
            }
            plateOut /= Float(delayLines.count / 2)

            buffer[i] = buffer[i] * (1.0 - mix) + plateOut * mix
        }
    }

    func reset() {
        for d in 0..<delayLines.count {
            delayLines[d] = [Float](repeating: 0, count: delayLines[d].count)
            delayPositions[d] = 0
            dampingFilters[d] = [0, 0]
        }
        for ap in 0..<inputAllpass.count {
            inputAllpass[ap] = [Float](repeating: 0, count: inputAllpass[ap].count)
            inputAPPos[ap] = 0
        }
        predelayBuffer = [Float](repeating: 0, count: predelayBuffer.count)
        predelayPos = 0
        modPhase = 0
    }
}

// MARK: - ============================================
// MARK: - DELAY PROCESSORS (20-23)
// MARK: - ============================================

// MARK: - 20. Tape Delay

/// Analog tape delay emulation with wow/flutter and saturation
final class TapeDelay: DSPEffect {
    var delayTime: Float = 300.0    // ms (1 to 2000)
    var feedback: Float = 0.4       // 0-1
    var mix: Float = 0.4            // 0-1
    var wow: Float = 0.3            // 0-1 (slow pitch variation)
    var flutter: Float = 0.2        // 0-1 (fast pitch variation)
    var saturation: Float = 0.3     // 0-1 (tape saturation)
    var tapeAge: Float = 0.3        // 0-1 (high frequency loss)
    var bypass: Bool = false

    // Delay buffer
    private var delayBuffer: [Float] = []
    private var writePos: Int = 0

    // Modulation
    private var wowPhase: Float = 0.0
    private var flutterPhase: Float = 0.0

    // Filtering
    private var highCutState: Float = 0.0
    private var dcBlockState: Float = 0.0
    private var lastDCInput: Float = 0.0

    init() {
        delayBuffer = [Float](repeating: 0, count: 96000)  // 2 sec at 48kHz
    }

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        let baseDelaySamples = delayTime * 0.001 * sampleRate
        let wowDepth = wow * 0.02 * sampleRate   // Up to 20ms variation
        let flutterDepth = flutter * 0.001 * sampleRate  // Up to 1ms variation

        for i in 0..<buffer.count {
            let input = buffer[i]

            // Wow (slow ~0.5Hz modulation)
            wowPhase += 0.5 / sampleRate
            if wowPhase > 1.0 { wowPhase -= 1.0 }
            let wowMod = sin(wowPhase * 2.0 * Float.pi) * wowDepth

            // Flutter (fast ~6Hz modulation)
            flutterPhase += 6.0 / sampleRate
            if flutterPhase > 1.0 { flutterPhase -= 1.0 }
            let flutterMod = (sin(flutterPhase * 2.0 * Float.pi) +
                             sin(flutterPhase * 2.0 * Float.pi * 2.3) * 0.5) * flutterDepth

            // Calculate read position with interpolation
            let totalDelay = baseDelaySamples + wowMod + flutterMod
            let readPosFloat = Float(writePos) - totalDelay
            var readPosNorm = readPosFloat
            while readPosNorm < 0 { readPosNorm += Float(delayBuffer.count) }

            let readPos0 = Int(readPosNorm) % delayBuffer.count
            let readPos1 = (readPos0 + 1) % delayBuffer.count
            let frac = readPosNorm - Float(Int(readPosNorm))

            // Linear interpolation for smooth modulation
            let delayed = delayBuffer[readPos0] * (1 - frac) + delayBuffer[readPos1] * frac

            // Tape saturation (soft clipping + harmonics)
            var saturated = delayed
            if saturation > 0.01 {
                let drive = 1.0 + saturation * 3.0
                saturated = tanh(delayed * drive) / tanh(drive)
                // Add even harmonics (tape characteristic)
                saturated += delayed * delayed * saturation * 0.1
            }

            // High frequency loss (tape aging)
            let hfCoeff = 0.3 + tapeAge * 0.6
            highCutState = highCutState + hfCoeff * (saturated - highCutState)
            let filtered = highCutState

            // DC blocking
            dcBlockState = 0.995 * dcBlockState + input - lastDCInput
            lastDCInput = input

            // Write to buffer
            delayBuffer[writePos] = dcBlockState + filtered * feedback
            writePos = (writePos + 1) % delayBuffer.count

            // Output mix
            buffer[i] = input * (1.0 - mix) + filtered * mix
        }
    }

    func reset() {
        delayBuffer = [Float](repeating: 0, count: delayBuffer.count)
        writePos = 0
        wowPhase = 0
        flutterPhase = 0
        highCutState = 0
        dcBlockState = 0
        lastDCInput = 0
    }
}

// MARK: - 21. Ping Pong Delay

/// Stereo bouncing delay
final class PingPongDelay: DSPEffect {
    var delayTime: Float = 250.0    // ms (1 to 2000)
    var feedback: Float = 0.5       // 0-1
    var mix: Float = 0.4            // 0-1
    var spread: Float = 1.0         // 0-1 (stereo width)
    var highCut: Float = 8000.0     // Hz
    var lowCut: Float = 80.0        // Hz
    var pingPongMode: Bool = true   // true = ping-pong, false = stereo
    var bypass: Bool = false

    // Stereo delay buffers
    private var leftBuffer: [Float] = []
    private var rightBuffer: [Float] = []
    private var writePos: Int = 0

    // Filters
    private var lpStateL: Float = 0
    private var lpStateR: Float = 0
    private var hpStateL: Float = 0
    private var hpStateR: Float = 0

    init() {
        let maxSamples = 96000
        leftBuffer = [Float](repeating: 0, count: maxSamples)
        rightBuffer = [Float](repeating: 0, count: maxSamples)
    }

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }
        // Note: For stereo, this processes interleaved L/R or should be called twice
        // This implementation assumes mono input, creates stereo output

        let delaySamples = Int(delayTime * 0.001 * sampleRate)
        let lpCoeff = exp(-2.0 * Float.pi * highCut / sampleRate)
        let hpCoeff = exp(-2.0 * Float.pi * lowCut / sampleRate)

        for i in 0..<buffer.count {
            let input = buffer[i]
            let readPos = (writePos - delaySamples + leftBuffer.count) % leftBuffer.count

            // Read from delay lines
            var delayedL = leftBuffer[readPos]
            var delayedR = rightBuffer[readPos]

            // Apply filters
            lpStateL = lpStateL + (1 - lpCoeff) * (delayedL - lpStateL)
            lpStateR = lpStateR + (1 - lpCoeff) * (delayedR - lpStateR)
            hpStateL = hpCoeff * (hpStateL + lpStateL)
            hpStateR = hpCoeff * (hpStateR + lpStateR)

            delayedL = lpStateL - hpStateL
            delayedR = lpStateR - hpStateR

            // Ping-pong feedback routing
            if pingPongMode {
                // Left feeds right, right feeds left
                leftBuffer[writePos] = input + delayedR * feedback
                rightBuffer[writePos] = delayedL * feedback
            } else {
                // Standard stereo delay
                leftBuffer[writePos] = input + delayedL * feedback
                rightBuffer[writePos] = input + delayedR * feedback
            }

            writePos = (writePos + 1) % leftBuffer.count

            // Mix (output center for mono compatibility)
            let stereoMix = delayedL * (1 - spread * 0.5) + delayedR * spread * 0.5
            buffer[i] = input * (1.0 - mix) + stereoMix * mix
        }
    }

    /// Stereo processing method
    func processBlockStereo(left: inout [Float], right: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        let delaySamples = Int(delayTime * 0.001 * sampleRate)

        for i in 0..<min(left.count, right.count) {
            let inputL = left[i]
            let inputR = right[i]
            let readPos = (writePos - delaySamples + leftBuffer.count) % leftBuffer.count

            let delayedL = leftBuffer[readPos]
            let delayedR = rightBuffer[readPos]

            if pingPongMode {
                leftBuffer[writePos] = inputL + delayedR * feedback
                rightBuffer[writePos] = inputR + delayedL * feedback
            } else {
                leftBuffer[writePos] = inputL + delayedL * feedback
                rightBuffer[writePos] = inputR + delayedR * feedback
            }

            writePos = (writePos + 1) % leftBuffer.count

            left[i] = inputL * (1.0 - mix) + delayedL * mix * spread
            right[i] = inputR * (1.0 - mix) + delayedR * mix * spread
        }
    }

    func reset() {
        leftBuffer = [Float](repeating: 0, count: leftBuffer.count)
        rightBuffer = [Float](repeating: 0, count: rightBuffer.count)
        writePos = 0
        lpStateL = 0; lpStateR = 0
        hpStateL = 0; hpStateR = 0
    }
}

// MARK: - 22. Multi-Tap Delay

/// Up to 8 independent delay taps
final class MultiTapDelay: DSPEffect {
    struct Tap {
        var time: Float = 250.0     // ms
        var level: Float = 0.5      // 0-1
        var pan: Float = 0.0        // -1 to 1
        var feedback: Float = 0.0   // 0-1 (per-tap feedback)
        var enabled: Bool = true
    }

    var taps: [Tap] = []
    var masterFeedback: Float = 0.3   // 0-1 (feedback from last tap)
    var mix: Float = 0.4              // 0-1
    var highCut: Float = 10000.0      // Hz
    var bypass: Bool = false

    // Delay buffer
    private var delayBuffer: [Float] = []
    private var writePos: Int = 0
    private var filterState: Float = 0

    init(tapCount: Int = 4) {
        delayBuffer = [Float](repeating: 0, count: 192000)  // 4 sec at 48kHz

        // Initialize taps with musical timing
        let baseTime: Float = 125.0
        for i in 0..<tapCount {
            var tap = Tap()
            tap.time = baseTime * Float(i + 1)
            tap.level = 1.0 - Float(i) * 0.15
            tap.pan = Float(i % 2) * 0.6 - 0.3  // Alternate L/R
            taps.append(tap)
        }
    }

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        let lpCoeff = exp(-2.0 * Float.pi * highCut / sampleRate)

        for i in 0..<buffer.count {
            let input = buffer[i]
            var tapSum: Float = 0.0
            var lastTapOutput: Float = 0.0

            // Sum all tap outputs
            for tap in taps where tap.enabled {
                let delaySamples = Int(tap.time * 0.001 * sampleRate)
                let readPos = (writePos - delaySamples + delayBuffer.count) % delayBuffer.count

                var tapOutput = delayBuffer[readPos] * tap.level

                // Per-tap feedback (for rhythmic effects)
                if tap.feedback > 0.01 {
                    let fbReadPos = (readPos - delaySamples + delayBuffer.count) % delayBuffer.count
                    tapOutput += delayBuffer[fbReadPos] * tap.feedback * tap.level * 0.5
                }

                tapSum += tapOutput
                lastTapOutput = tapOutput
            }

            // High cut filter
            filterState = filterState + (1 - lpCoeff) * (tapSum - filterState)

            // Write input + master feedback to buffer
            delayBuffer[writePos] = input + lastTapOutput * masterFeedback
            writePos = (writePos + 1) % delayBuffer.count

            buffer[i] = input * (1.0 - mix) + filterState * mix
        }
    }

    func reset() {
        delayBuffer = [Float](repeating: 0, count: delayBuffer.count)
        writePos = 0
        filterState = 0
    }
}

// MARK: - 23. Granular Delay

/// Grain-based delay with pitch and texture control
final class GranularDelay: DSPEffect {
    var delayTime: Float = 300.0    // ms
    var feedback: Float = 0.4       // 0-1
    var mix: Float = 0.4            // 0-1
    var grainSize: Float = 50.0     // ms (10 to 500)
    var grainDensity: Float = 0.5   // 0-1 (sparse to dense)
    var pitch: Float = 0.0          // semitones (-24 to +24)
    var pitchRandom: Float = 0.0    // 0-1 (randomize pitch per grain)
    var spray: Float = 0.0          // 0-1 (randomize read position)
    var reverse: Float = 0.0        // 0-1 (probability of reverse grains)
    var bypass: Bool = false

    // Delay buffer
    private var delayBuffer: [Float] = []
    private var writePos: Int = 0

    // Grain state
    private var grains: [Grain] = []
    private var grainTimer: Float = 0.0

    private struct Grain {
        var readPos: Float
        var readIncrement: Float
        var samplesRemaining: Int
        var windowPos: Float
        var windowIncrement: Float
        var isReverse: Bool
    }

    init() {
        delayBuffer = [Float](repeating: 0, count: 192000)
    }

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        let grainSamples = Int(grainSize * 0.001 * sampleRate)
        let grainInterval = grainSamples / max(1, Int(grainDensity * 8 + 1))
        let basePitchRatio = pow(2.0, pitch / 12.0)
        let delaySamples = delayTime * 0.001 * sampleRate

        for i in 0..<buffer.count {
            let input = buffer[i]

            // Spawn new grains
            grainTimer += 1
            if grainTimer >= Float(grainInterval) {
                grainTimer = 0
                spawnGrain(delaySamples: delaySamples, grainSamples: grainSamples,
                          basePitchRatio: basePitchRatio, sampleRate: sampleRate)
            }

            // Process active grains
            var grainOutput: Float = 0.0
            var activeGrains: [Grain] = []

            for var grain in grains {
                if grain.samplesRemaining > 0 {
                    // Read from delay buffer with interpolation
                    var readIdx = Int(grain.readPos) % delayBuffer.count
                    if readIdx < 0 { readIdx += delayBuffer.count }
                    let nextIdx = (readIdx + 1) % delayBuffer.count
                    let frac = grain.readPos - Float(Int(grain.readPos))

                    let sample = delayBuffer[readIdx] * (1 - frac) + delayBuffer[nextIdx] * frac

                    // Hann window for smooth grain edges
                    let window = 0.5 * (1.0 - cos(grain.windowPos * 2.0 * Float.pi))
                    grainOutput += sample * window

                    // Update grain state
                    if grain.isReverse {
                        grain.readPos -= grain.readIncrement
                    } else {
                        grain.readPos += grain.readIncrement
                    }
                    grain.windowPos += grain.windowIncrement
                    grain.samplesRemaining -= 1

                    activeGrains.append(grain)
                }
            }

            grains = activeGrains

            // Normalize by approximate grain overlap
            let overlap = max(1.0, grainDensity * 4)
            grainOutput /= overlap

            // Write to delay buffer
            delayBuffer[writePos] = input + grainOutput * feedback
            writePos = (writePos + 1) % delayBuffer.count

            buffer[i] = input * (1.0 - mix) + grainOutput * mix
        }
    }

    private func spawnGrain(delaySamples: Float, grainSamples: Int,
                           basePitchRatio: Float, sampleRate: Float) {
        // Calculate read position with spray
        var readPos = Float(writePos) - delaySamples
        if spray > 0.01 {
            let sprayRange = spray * delaySamples * 0.5
            readPos += Float.random(in: -sprayRange...sprayRange)
        }

        // Pitch with randomization
        var pitchRatio = basePitchRatio
        if pitchRandom > 0.01 {
            let randomSemitones = Float.random(in: -12...12) * pitchRandom
            pitchRatio *= pow(2.0, randomSemitones / 12.0)
        }

        // Determine if grain should be reversed
        let isReverse = Float.random(in: 0...1) < reverse

        let grain = Grain(
            readPos: readPos,
            readIncrement: pitchRatio,
            samplesRemaining: grainSamples,
            windowPos: 0,
            windowIncrement: 1.0 / Float(grainSamples),
            isReverse: isReverse
        )

        grains.append(grain)
    }

    func reset() {
        delayBuffer = [Float](repeating: 0, count: delayBuffer.count)
        writePos = 0
        grains = []
        grainTimer = 0
    }
}

// MARK: - ============================================
// MARK: - MODULATION PROCESSORS (24-29)
// MARK: - ============================================

// MARK: - 24. Chorus

/// BBD-style chorus effect
final class Chorus: DSPEffect {
    var rate: Float = 0.5           // Hz (0.1 to 5)
    var depth: Float = 0.5          // 0-1
    var mix: Float = 0.5            // 0-1
    var voices: Int = 2             // 1-4
    var spread: Float = 0.5         // 0-1 (stereo width)
    var feedback: Float = 0.0       // 0-1
    var bypass: Bool = false

    // Delay line
    private var delayBuffer: [Float] = []
    private var writePos: Int = 0
    private let maxDelaySamples = 2048

    // LFO phases for each voice
    private var lfoPhases: [Float] = [0, 0.25, 0.5, 0.75]

    // BBD characteristics
    private var antialiasState: Float = 0

    init() {
        delayBuffer = [Float](repeating: 0, count: maxDelaySamples)
    }

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        let baseDelay: Float = 7.0 * sampleRate / 1000.0  // 7ms base delay
        let modDepth = depth * 5.0 * sampleRate / 1000.0  // Up to 5ms modulation
        let lfoIncrement = rate / sampleRate

        for i in 0..<buffer.count {
            let input = buffer[i]

            // Anti-aliasing filter (BBD characteristic)
            antialiasState = antialiasState + 0.3 * (input - antialiasState)

            // Write to delay
            delayBuffer[writePos] = antialiasState

            var chorusOut: Float = 0.0

            // Process each voice
            for v in 0..<min(voices, 4) {
                // Update LFO
                lfoPhases[v] += lfoIncrement
                if lfoPhases[v] > 1.0 { lfoPhases[v] -= 1.0 }

                // Sine LFO with slight triangular blend
                let lfo = sin(lfoPhases[v] * 2.0 * Float.pi) * 0.9 +
                         (lfoPhases[v] < 0.5 ? lfoPhases[v] * 4 - 1 : 3 - lfoPhases[v] * 4) * 0.1

                // Calculate delay for this voice
                let voiceDelay = baseDelay + lfo * modDepth
                let readPosFloat = Float(writePos) - voiceDelay
                var readPosNorm = readPosFloat
                while readPosNorm < 0 { readPosNorm += Float(delayBuffer.count) }

                // Interpolated read
                let readPos0 = Int(readPosNorm) % delayBuffer.count
                let readPos1 = (readPos0 + 1) % delayBuffer.count
                let frac = readPosNorm - Float(Int(readPosNorm))

                let voiceOut = delayBuffer[readPos0] * (1 - frac) + delayBuffer[readPos1] * frac
                chorusOut += voiceOut
            }

            chorusOut /= Float(voices)

            // Feedback
            if feedback > 0.01 {
                delayBuffer[writePos] += chorusOut * feedback
            }

            writePos = (writePos + 1) % delayBuffer.count

            buffer[i] = input * (1.0 - mix) + chorusOut * mix
        }
    }

    func reset() {
        delayBuffer = [Float](repeating: 0, count: maxDelaySamples)
        writePos = 0
        lfoPhases = [0, 0.25, 0.5, 0.75]
        antialiasState = 0
    }
}

// MARK: - 25. Flanger

/// Through-zero capable flanger
final class Flanger: DSPEffect {
    var rate: Float = 0.2           // Hz (0.01 to 5)
    var depth: Float = 0.7          // 0-1
    var feedback: Float = 0.7       // -1 to 1 (negative for jet sound)
    var mix: Float = 0.5            // 0-1
    var manual: Float = 0.5         // 0-1 (manual delay offset)
    var throughZero: Bool = false   // Enable through-zero flanging
    var bypass: Bool = false

    // Delay lines
    private var delayBuffer: [Float] = []
    private var throughZeroBuffer: [Float] = []
    private var writePos: Int = 0
    private let maxDelaySamples = 1024

    // LFO
    private var lfoPhase: Float = 0.0

    init() {
        delayBuffer = [Float](repeating: 0, count: maxDelaySamples)
        throughZeroBuffer = [Float](repeating: 0, count: maxDelaySamples)
    }

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        let minDelay: Float = 0.1 * sampleRate / 1000.0   // 0.1ms
        let maxDelay: Float = 10.0 * sampleRate / 1000.0  // 10ms
        let manualOffset = manual * (maxDelay - minDelay)
        let lfoIncrement = rate / sampleRate

        for i in 0..<buffer.count {
            let input = buffer[i]

            // Triangle LFO for classic flanger sweep
            lfoPhase += lfoIncrement
            if lfoPhase > 1.0 { lfoPhase -= 1.0 }
            let lfo = lfoPhase < 0.5 ? lfoPhase * 4 - 1 : 3 - lfoPhase * 4

            // Calculate delay time
            let delayRange = (maxDelay - minDelay) * depth
            var delaySamples = minDelay + manualOffset + (lfo + 1) * 0.5 * delayRange

            if throughZero {
                // Through-zero: delay goes through zero point
                delaySamples = manualOffset + lfo * delayRange
            }

            // Write to delay buffer with feedback
            var delayInput = input
            let readPosFloat = Float(writePos) - abs(delaySamples)
            var readPosNorm = readPosFloat
            while readPosNorm < 0 { readPosNorm += Float(delayBuffer.count) }

            let readPos0 = Int(readPosNorm) % delayBuffer.count
            let readPos1 = (readPos0 + 1) % delayBuffer.count
            let frac = readPosNorm - Float(Int(readPosNorm))

            let delayed = delayBuffer[readPos0] * (1 - frac) + delayBuffer[readPos1] * frac

            // Feedback (can be negative for jet/tunnel effect)
            delayInput += delayed * feedback

            delayBuffer[writePos] = delayInput

            // Through-zero mixing
            var flangeOut: Float
            if throughZero && delaySamples < 0 {
                // Invert phase for through-zero
                flangeOut = -delayed
            } else {
                flangeOut = delayed
            }

            writePos = (writePos + 1) % delayBuffer.count

            // Output with comb filtering
            buffer[i] = input * (1.0 - mix) + (input + flangeOut) * 0.5 * mix
        }
    }

    func reset() {
        delayBuffer = [Float](repeating: 0, count: maxDelaySamples)
        throughZeroBuffer = [Float](repeating: 0, count: maxDelaySamples)
        writePos = 0
        lfoPhase = 0
    }
}

// MARK: - 26. Phaser

/// 4/8/12 stage phaser
final class Phaser: DSPEffect {
    var rate: Float = 0.3           // Hz (0.01 to 5)
    var depth: Float = 0.7          // 0-1
    var feedback: Float = 0.6       // 0-1
    var stages: Int = 4             // 2, 4, 6, 8, 10, or 12
    var mix: Float = 0.5            // 0-1
    var centerFreq: Float = 1000.0  // Hz (center of sweep)
    var spread: Float = 0.5         // 0-1 (frequency spread)
    var bypass: Bool = false

    // Allpass filter states
    private var allpassStates: [Float] = []
    private var feedbackSample: Float = 0.0

    // LFO
    private var lfoPhase: Float = 0.0

    init() {
        allpassStates = [Float](repeating: 0, count: 12)
    }

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        let minFreq: Float = 200.0
        let maxFreq: Float = 4000.0
        let lfoIncrement = rate / sampleRate
        let effectiveStages = min(stages, 12)

        for i in 0..<buffer.count {
            let input = buffer[i]

            // Sine LFO
            lfoPhase += lfoIncrement
            if lfoPhase > 1.0 { lfoPhase -= 1.0 }
            let lfo = sin(lfoPhase * 2.0 * Float.pi)

            // Calculate swept frequency
            let sweepRange = (maxFreq - minFreq) * depth
            let sweepFreq = centerFreq + lfo * sweepRange * 0.5

            // Add feedback
            var phaserInput = input + feedbackSample * feedback

            // Process allpass stages
            var phaserOut = phaserInput
            for stage in 0..<effectiveStages {
                // Frequency offset for each stage
                let stageOffset = Float(stage) / Float(effectiveStages) * spread
                let stageFreq = sweepFreq * (1.0 + stageOffset)

                // First-order allpass coefficient
                let omega = 2.0 * Float.pi * stageFreq / sampleRate
                let coeff = (1.0 - tan(omega / 2)) / (1.0 + tan(omega / 2))

                // Allpass filter
                let allpassIn = phaserOut
                phaserOut = coeff * (allpassIn + allpassStates[stage]) - phaserInput
                allpassStates[stage] = allpassIn

                phaserInput = phaserOut  // Chain stages
            }

            // Store for feedback
            feedbackSample = phaserOut

            // Mix dry and wet (notch comb effect)
            buffer[i] = input * (1.0 - mix) + (input + phaserOut) * 0.5 * mix
        }
    }

    func reset() {
        allpassStates = [Float](repeating: 0, count: 12)
        feedbackSample = 0
        lfoPhase = 0
    }
}

// MARK: - 27. Tremolo

/// Amplitude modulation effect
final class Tremolo: DSPEffect {
    var rate: Float = 4.0           // Hz (0.1 to 20)
    var depth: Float = 0.5          // 0-1
    var shape: WaveShape = .sine    // LFO waveform
    var stereoPhase: Float = 0.0    // 0-180 degrees (for stereo tremolo)
    var bypass: Bool = false

    enum WaveShape: String, CaseIterable {
        case sine, triangle, square, sawUp, sawDown
    }

    // LFO
    private var lfoPhase: Float = 0.0

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        let lfoIncrement = rate / sampleRate

        for i in 0..<buffer.count {
            // Update LFO
            lfoPhase += lfoIncrement
            if lfoPhase > 1.0 { lfoPhase -= 1.0 }

            // Generate LFO value based on shape
            let lfo = generateLFO(phase: lfoPhase)

            // Calculate gain (depth controls modulation amount)
            let gain = 1.0 - depth * (1.0 - lfo) * 0.5

            buffer[i] *= gain
        }
    }

    private func generateLFO(phase: Float) -> Float {
        switch shape {
        case .sine:
            return (sin(phase * 2.0 * Float.pi) + 1.0) * 0.5

        case .triangle:
            return phase < 0.5 ? phase * 2 : 2 - phase * 2

        case .square:
            return phase < 0.5 ? 1.0 : 0.0

        case .sawUp:
            return phase

        case .sawDown:
            return 1.0 - phase
        }
    }

    func reset() {
        lfoPhase = 0
    }
}

// MARK: - 28. Ring Modulator

/// Ring modulation effect
final class RingMod: DSPEffect {
    var frequency: Float = 440.0    // Hz (20 to 5000)
    var mix: Float = 0.5            // 0-1
    var shape: WaveShape = .sine    // Modulator waveform
    var lfoRate: Float = 0.0        // Hz (0 = off, modulates carrier freq)
    var lfoDepth: Float = 0.0       // 0-1
    var bypass: Bool = false

    enum WaveShape: String, CaseIterable {
        case sine, triangle, square
    }

    // Oscillator
    private var oscPhase: Float = 0.0
    private var lfoPhase: Float = 0.0

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        for i in 0..<buffer.count {
            let input = buffer[i]

            // LFO modulation of carrier frequency
            var currentFreq = frequency
            if lfoRate > 0.01 {
                lfoPhase += lfoRate / sampleRate
                if lfoPhase > 1.0 { lfoPhase -= 1.0 }
                let lfo = sin(lfoPhase * 2.0 * Float.pi)
                currentFreq = frequency * (1.0 + lfo * lfoDepth)
            }

            // Update carrier oscillator
            oscPhase += currentFreq / sampleRate
            if oscPhase > 1.0 { oscPhase -= 1.0 }

            // Generate carrier based on shape
            var carrier: Float
            switch shape {
            case .sine:
                carrier = sin(oscPhase * 2.0 * Float.pi)
            case .triangle:
                carrier = oscPhase < 0.5 ? oscPhase * 4 - 1 : 3 - oscPhase * 4
            case .square:
                carrier = oscPhase < 0.5 ? 1.0 : -1.0
            }

            // Ring modulation (multiply signals)
            let ringMod = input * carrier

            buffer[i] = input * (1.0 - mix) + ringMod * mix
        }
    }

    func reset() {
        oscPhase = 0
        lfoPhase = 0
    }
}

// MARK: - 29. Rotary Speaker

/// Leslie speaker simulation
final class Rotary: DSPEffect {
    var speed: RotarySpeed = .slow  // Slow/Fast
    var hornLevel: Float = 0.7      // 0-1 (high rotor)
    var drumLevel: Float = 0.5      // 0-1 (low rotor)
    var drive: Float = 0.3          // 0-1 (tube amp overdrive)
    var mix: Float = 0.8            // 0-1
    var bypass: Bool = false

    enum RotarySpeed {
        case stop, slow, fast

        var hornHz: Float {
            switch self {
            case .stop: return 0.0
            case .slow: return 0.8    // ~48 RPM
            case .fast: return 6.7    // ~400 RPM
            }
        }

        var drumHz: Float {
            switch self {
            case .stop: return 0.0
            case .slow: return 0.67   // ~40 RPM
            case .fast: return 5.9    // ~340 RPM
            }
        }
    }

    // Current rotation speeds (for acceleration/deceleration)
    private var currentHornSpeed: Float = 0.0
    private var currentDrumSpeed: Float = 0.0

    // Rotor phases
    private var hornPhase: Float = 0.0
    private var drumPhase: Float = 0.0

    // Delay lines for Doppler effect
    private var hornDelay: [Float] = []
    private var drumDelay: [Float] = []
    private var delayWritePos: Int = 0
    private let maxDelay = 512

    // Crossover filter states
    private var lowpassState: Float = 0.0
    private var highpassState: Float = 0.0

    init() {
        hornDelay = [Float](repeating: 0, count: maxDelay)
        drumDelay = [Float](repeating: 0, count: maxDelay)
    }

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        // Acceleration/deceleration (Leslie characteristic)
        let accelRate: Float = speed == .fast ? 0.002 : 0.001
        let targetHornSpeed = speed.hornHz
        let targetDrumSpeed = speed.drumHz

        currentHornSpeed += (targetHornSpeed - currentHornSpeed) * accelRate
        currentDrumSpeed += (targetDrumSpeed - currentDrumSpeed) * accelRate

        // Crossover frequency (~800Hz)
        let crossoverCoeff: Float = 0.05

        for i in 0..<buffer.count {
            var input = buffer[i]

            // Tube amp drive
            if drive > 0.01 {
                let driveAmount = 1.0 + drive * 4.0
                input = tanh(input * driveAmount) / tanh(driveAmount)
            }

            // Crossover filter (split high/low)
            lowpassState = lowpassState + crossoverCoeff * (input - lowpassState)
            let lowSignal = lowpassState
            let highSignal = input - lowpassState

            // Update rotor phases
            hornPhase += currentHornSpeed / sampleRate
            if hornPhase > 1.0 { hornPhase -= 1.0 }
            drumPhase += currentDrumSpeed / sampleRate
            if drumPhase > 1.0 { drumPhase -= 1.0 }

            // Horn (high frequencies) - faster, more modulation
            let hornMod = sin(hornPhase * 2.0 * Float.pi)
            let hornAM = 1.0 + hornMod * 0.3  // Amplitude modulation
            let hornDelaySamples = 3.0 + hornMod * 2.0  // Doppler

            // Write to horn delay
            hornDelay[delayWritePos] = highSignal * hornAM * hornLevel

            // Read with Doppler
            let hornReadFloat = Float(delayWritePos) - hornDelaySamples
            var hornReadNorm = hornReadFloat
            while hornReadNorm < 0 { hornReadNorm += Float(maxDelay) }
            let hornReadIdx = Int(hornReadNorm) % maxDelay
            let hornOut = hornDelay[hornReadIdx]

            // Drum (low frequencies) - slower, less modulation
            let drumMod = sin(drumPhase * 2.0 * Float.pi)
            let drumAM = 1.0 + drumMod * 0.15
            let drumDelaySamples = 2.0 + drumMod * 1.0

            drumDelay[delayWritePos] = lowSignal * drumAM * drumLevel

            let drumReadFloat = Float(delayWritePos) - drumDelaySamples
            var drumReadNorm = drumReadFloat
            while drumReadNorm < 0 { drumReadNorm += Float(maxDelay) }
            let drumReadIdx = Int(drumReadNorm) % maxDelay
            let drumOut = drumDelay[drumReadIdx]

            delayWritePos = (delayWritePos + 1) % maxDelay

            // Combine rotors
            let rotaryOut = hornOut + drumOut

            buffer[i] = input * (1.0 - mix) + rotaryOut * mix
        }
    }

    func reset() {
        hornDelay = [Float](repeating: 0, count: maxDelay)
        drumDelay = [Float](repeating: 0, count: maxDelay)
        delayWritePos = 0
        hornPhase = 0
        drumPhase = 0
        currentHornSpeed = 0
        currentDrumSpeed = 0
        lowpassState = 0
        highpassState = 0
    }
}

// MARK: - ============================================
// MARK: - PITCH PROCESSORS (30-33)
// MARK: - ============================================

// MARK: - 30. Pitch Correction

/// Auto-tune style pitch correction
final class PitchCorrection: DSPEffect {
    var speed: Float = 0.5          // 0-1 (0=slow/natural, 1=instant)
    var scale: MusicalScale = .chromatic
    var key: Int = 0                // 0-11 (C to B)
    var humanize: Float = 0.2       // 0-1 (random variation)
    var formantPreserve: Bool = true
    var bypass: Bool = false

    enum MusicalScale: String, CaseIterable {
        case chromatic, major, minor, pentatonicMajor, pentatonicMinor, blues

        var intervals: [Int] {
            switch self {
            case .chromatic: return [0,1,2,3,4,5,6,7,8,9,10,11]
            case .major: return [0,2,4,5,7,9,11]
            case .minor: return [0,2,3,5,7,8,10]
            case .pentatonicMajor: return [0,2,4,7,9]
            case .pentatonicMinor: return [0,3,5,7,10]
            case .blues: return [0,3,5,6,7,10]
            }
        }
    }

    // Pitch detection
    private var analysisBuffer: [Float] = []
    private var analysisWritePos: Int = 0
    private let analysisSize = 2048

    // Pitch shifting
    private var shiftBuffer: [Float] = []
    private var shiftReadPos: Float = 0
    private var shiftWritePos: Int = 0
    private let shiftBufferSize = 4096

    // Current state
    private var currentPitch: Float = 0.0
    private var targetPitch: Float = 0.0
    private var currentShiftRatio: Float = 1.0

    init() {
        analysisBuffer = [Float](repeating: 0, count: analysisSize)
        shiftBuffer = [Float](repeating: 0, count: shiftBufferSize)
    }

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        let correctionSpeed = 0.001 + speed * 0.099  // 1ms to 100ms

        for i in 0..<buffer.count {
            let input = buffer[i]

            // Store for pitch analysis
            analysisBuffer[analysisWritePos] = input
            analysisWritePos = (analysisWritePos + 1) % analysisSize

            // Detect pitch periodically
            if analysisWritePos == 0 {
                currentPitch = detectPitch(sampleRate: sampleRate)
                if currentPitch > 50 {
                    targetPitch = findNearestScaleNote(pitch: currentPitch)

                    // Add humanization
                    if humanize > 0.01 {
                        let variation = Float.random(in: -0.5...0.5) * humanize * 0.5
                        targetPitch *= pow(2.0, variation / 12.0)
                    }
                }
            }

            // Calculate pitch shift ratio
            if currentPitch > 50 && targetPitch > 50 {
                let targetRatio = targetPitch / currentPitch
                currentShiftRatio += (targetRatio - currentShiftRatio) * correctionSpeed
            } else {
                currentShiftRatio += (1.0 - currentShiftRatio) * correctionSpeed
            }

            // Pitch shift using granular method
            shiftBuffer[shiftWritePos] = input
            shiftWritePos = (shiftWritePos + 1) % shiftBufferSize

            shiftReadPos += currentShiftRatio
            if shiftReadPos >= Float(shiftBufferSize) {
                shiftReadPos -= Float(shiftBufferSize)
            }

            // Interpolated read with crossfade for smooth output
            let readIdx = Int(shiftReadPos) % shiftBufferSize
            let frac = shiftReadPos - Float(Int(shiftReadPos))
            let nextIdx = (readIdx + 1) % shiftBufferSize

            var output = shiftBuffer[readIdx] * (1 - frac) + shiftBuffer[nextIdx] * frac

            // Simple formant preservation (shift formants back)
            if formantPreserve && abs(currentShiftRatio - 1.0) > 0.01 {
                // Apply inverse filter to preserve formant structure
                output = preserveFormants(output, shiftRatio: currentShiftRatio)
            }

            buffer[i] = output
        }
    }

    private func detectPitch(sampleRate: Float) -> Float {
        // Autocorrelation pitch detection
        var maxCorrelation: Float = 0
        var detectedPeriod: Int = 0

        let minPeriod = Int(sampleRate / 800)  // Max 800 Hz
        let maxPeriod = Int(sampleRate / 80)   // Min 80 Hz

        for period in minPeriod..<min(maxPeriod, analysisSize / 2) {
            var correlation: Float = 0
            for j in 0..<analysisSize - period {
                correlation += analysisBuffer[j] * analysisBuffer[j + period]
            }

            if correlation > maxCorrelation {
                maxCorrelation = correlation
                detectedPeriod = period
            }
        }

        if detectedPeriod > 0 && maxCorrelation > 0.1 {
            return sampleRate / Float(detectedPeriod)
        }
        return 0
    }

    private func findNearestScaleNote(pitch: Float) -> Float {
        // Convert pitch to MIDI note
        let midiNote = 12.0 * log2(pitch / 440.0) + 69.0
        let noteInOctave = Int(midiNote.rounded()) % 12
        let octave = Int(midiNote.rounded()) / 12

        // Find nearest scale note
        let keyAdjusted = (noteInOctave - key + 12) % 12
        var nearestInterval = scale.intervals[0]
        var minDistance = 12

        for interval in scale.intervals {
            let distance = abs(keyAdjusted - interval)
            let wrapDistance = min(distance, 12 - distance)
            if wrapDistance < minDistance {
                minDistance = wrapDistance
                nearestInterval = interval
            }
        }

        let targetNote = Float(octave * 12 + (nearestInterval + key) % 12)
        return 440.0 * pow(2.0, (targetNote - 69.0) / 12.0)
    }

    private var formantFilterState: Float = 0

    private func preserveFormants(_ input: Float, shiftRatio: Float) -> Float {
        // Simplified formant preservation using inverse filtering
        let filterCoeff = min(0.9, max(0.1, 1.0 / shiftRatio))
        formantFilterState = formantFilterState + filterCoeff * (input - formantFilterState)
        return formantFilterState
    }

    func reset() {
        analysisBuffer = [Float](repeating: 0, count: analysisSize)
        shiftBuffer = [Float](repeating: 0, count: shiftBufferSize)
        analysisWritePos = 0
        shiftReadPos = 0
        shiftWritePos = 0
        currentPitch = 0
        targetPitch = 0
        currentShiftRatio = 1.0
        formantFilterState = 0
    }
}

// MARK: - 31. Harmonizer

/// Intelligent harmony generator
final class Harmonizer: DSPEffect {
    var interval1: Float = 0.0      // Semitones (-24 to +24)
    var interval2: Float = 0.0      // Second voice
    var level1: Float = 0.7         // 0-1
    var level2: Float = 0.5         // 0-1
    var detune: Float = 0.0         // Cents (-50 to +50)
    var mix: Float = 0.5            // 0-1
    var intelligentMode: Bool = false // Scale-aware harmonies
    var scale: PitchCorrection.MusicalScale = .major
    var key: Int = 0
    var bypass: Bool = false

    // Pitch shifter buffers
    private var buffer1: [Float] = []
    private var buffer2: [Float] = []
    private var writePos: Int = 0
    private var readPos1: Float = 0
    private var readPos2: Float = 0
    private let bufferSize = 8192

    // Crossfade for glitch-free shifting
    private var grainPhase1: Float = 0
    private var grainPhase2: Float = 0

    init() {
        buffer1 = [Float](repeating: 0, count: bufferSize)
        buffer2 = [Float](repeating: 0, count: bufferSize)
    }

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        let ratio1 = pow(2.0, (interval1 + detune / 100.0) / 12.0)
        let ratio2 = pow(2.0, (interval2 - detune / 100.0) / 12.0)
        let grainSize: Float = 0.020 * sampleRate  // 20ms grains

        for i in 0..<buffer.count {
            let input = buffer[i]

            // Write to buffers
            buffer1[writePos] = input
            buffer2[writePos] = input

            // Voice 1
            var voice1: Float = 0
            if abs(interval1) > 0.01 && level1 > 0.01 {
                voice1 = readWithGrain(buffer: buffer1, readPos: &readPos1,
                                       grainPhase: &grainPhase1, ratio: ratio1,
                                       grainSize: grainSize)
            }

            // Voice 2
            var voice2: Float = 0
            if abs(interval2) > 0.01 && level2 > 0.01 {
                voice2 = readWithGrain(buffer: buffer2, readPos: &readPos2,
                                       grainPhase: &grainPhase2, ratio: ratio2,
                                       grainSize: grainSize)
            }

            writePos = (writePos + 1) % bufferSize

            // Mix voices
            let wet = voice1 * level1 + voice2 * level2
            buffer[i] = input * (1.0 - mix) + (input + wet) * 0.5 * mix
        }
    }

    private func readWithGrain(buffer: [Float], readPos: inout Float,
                               grainPhase: inout Float, ratio: Float,
                               grainSize: Float) -> Float {
        // Two overlapping grains for smooth output
        let grain1Pos = readPos
        let grain2Pos = readPos + grainSize / 2

        grainPhase += 1.0 / grainSize
        if grainPhase > 1.0 { grainPhase -= 1.0 }

        // Hann window
        let window1 = 0.5 * (1.0 - cos(grainPhase * 2.0 * Float.pi))
        let window2 = 0.5 * (1.0 - cos((grainPhase + 0.5).truncatingRemainder(dividingBy: 1.0) * 2.0 * Float.pi))

        // Read samples
        func readSample(pos: Float) -> Float {
            var p = pos
            while p < 0 { p += Float(bufferSize) }
            let idx = Int(p) % bufferSize
            let nextIdx = (idx + 1) % bufferSize
            let frac = p - Float(Int(p))
            return buffer[idx] * (1 - frac) + buffer[nextIdx] * frac
        }

        let sample1 = readSample(pos: grain1Pos)
        let sample2 = readSample(pos: grain2Pos)

        // Update read position
        readPos += ratio
        if readPos >= Float(bufferSize) {
            readPos -= Float(bufferSize)
        } else if readPos < 0 {
            readPos += Float(bufferSize)
        }

        return sample1 * window1 + sample2 * window2
    }

    func reset() {
        buffer1 = [Float](repeating: 0, count: bufferSize)
        buffer2 = [Float](repeating: 0, count: bufferSize)
        writePos = 0
        readPos1 = 0
        readPos2 = 0
        grainPhase1 = 0
        grainPhase2 = 0
    }
}

// MARK: - 32. Vocoder

/// 16-band carrier/modulator vocoder
final class Vocoder: DSPEffect {
    var bands: Int = 16             // 8, 16, or 32
    var highFreq: Float = 8000.0    // Hz (top of range)
    var lowFreq: Float = 100.0      // Hz (bottom of range)
    var attack: Float = 5.0         // ms
    var release: Float = 50.0       // ms
    var carrierType: CarrierType = .sawtooth
    var carrierFreq: Float = 110.0  // Hz (for oscillator carrier)
    var sibilanceBoost: Float = 0.3 // 0-1 (preserve consonants)
    var bypass: Bool = false

    enum CarrierType {
        case sawtooth, pulse, noise, external
    }

    // Analysis filterbank (modulator)
    private var modulatorFilters: [[Float]] = []
    private var modulatorEnvelopes: [Float] = []

    // Synthesis filterbank (carrier)
    private var carrierFilters: [[Float]] = []

    // Carrier oscillator
    private var carrierPhase: Float = 0

    // Sibilance detector
    private var sibilanceEnvelope: Float = 0

    init() {
        setupFilterbank()
    }

    private func setupFilterbank() {
        modulatorFilters = Array(repeating: [0, 0, 0, 0], count: bands)
        modulatorEnvelopes = [Float](repeating: 0, count: bands)
        carrierFilters = Array(repeating: [0, 0, 0, 0], count: bands)
    }

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        if modulatorFilters.count != bands { setupFilterbank() }

        let attackCoeff = exp(-1.0 / (attack * 0.001 * sampleRate))
        let releaseCoeff = exp(-1.0 / (release * 0.001 * sampleRate))

        // Calculate band frequencies (logarithmic spacing)
        var bandFreqs: [Float] = []
        let logLow = log(lowFreq)
        let logHigh = log(highFreq)
        for b in 0..<bands {
            let logFreq = logLow + (logHigh - logLow) * Float(b) / Float(bands - 1)
            bandFreqs.append(exp(logFreq))
        }

        for i in 0..<buffer.count {
            let modulator = buffer[i]  // Voice input (modulator)

            // Generate carrier signal
            var carrier: Float
            switch carrierType {
            case .sawtooth:
                carrierPhase += carrierFreq / sampleRate
                if carrierPhase > 1.0 { carrierPhase -= 1.0 }
                carrier = carrierPhase * 2.0 - 1.0

            case .pulse:
                carrierPhase += carrierFreq / sampleRate
                if carrierPhase > 1.0 { carrierPhase -= 1.0 }
                carrier = carrierPhase < 0.5 ? 1.0 : -1.0

            case .noise:
                carrier = Float.random(in: -1...1)

            case .external:
                carrier = modulator  // Use modulator as carrier too
            }

            // Sibilance detection (high frequency energy)
            let sibilance = abs(modulator) * (modulator * modulator > 0.01 ? 1.0 : 0.0)
            if sibilance > sibilanceEnvelope {
                sibilanceEnvelope = 0.9 * sibilanceEnvelope + 0.1 * sibilance
            } else {
                sibilanceEnvelope *= 0.99
            }

            var output: Float = 0.0

            // Process each band
            for b in 0..<bands {
                let freq = bandFreqs[b]
                let q: Float = 5.0 + Float(b) * 0.5  // Tighter Q at high frequencies

                // Analyze modulator band
                let modulatorBand = bandpassFilter(modulator, bandIndex: b,
                                                   freq: freq, q: q,
                                                   filters: &modulatorFilters,
                                                   sampleRate: sampleRate)

                // Envelope follower
                let level = abs(modulatorBand)
                if level > modulatorEnvelopes[b] {
                    modulatorEnvelopes[b] = attackCoeff * modulatorEnvelopes[b] + (1 - attackCoeff) * level
                } else {
                    modulatorEnvelopes[b] = releaseCoeff * modulatorEnvelopes[b]
                }

                // Filter carrier with same band
                let carrierBand = bandpassFilter(carrier, bandIndex: b,
                                                freq: freq, q: q,
                                                filters: &carrierFilters,
                                                sampleRate: sampleRate)

                // Apply modulator envelope to carrier
                output += carrierBand * modulatorEnvelopes[b] * 4.0
            }

            // Add sibilance (unprocessed high frequencies)
            output += modulator * sibilanceEnvelope * sibilanceBoost * 2.0

            buffer[i] = output
        }
    }

    private func bandpassFilter(_ input: Float, bandIndex: Int,
                               freq: Float, q: Float,
                               filters: inout [[Float]],
                               sampleRate: Float) -> Float {
        let omega = 2.0 * Float.pi * freq / sampleRate
        let alpha = sin(omega) / (2.0 * q)

        let b0 = alpha
        let b2 = -alpha
        let a0 = 1.0 + alpha
        let a1 = -2.0 * cos(omega)
        let a2 = 1.0 - alpha

        let output = (b0/a0) * input + (b2/a0) * filters[bandIndex][1]
                    - (a1/a0) * filters[bandIndex][2] - (a2/a0) * filters[bandIndex][3]

        filters[bandIndex][1] = filters[bandIndex][0]
        filters[bandIndex][0] = input
        filters[bandIndex][3] = filters[bandIndex][2]
        filters[bandIndex][2] = output

        return output
    }

    func reset() {
        setupFilterbank()
        carrierPhase = 0
        sibilanceEnvelope = 0
    }
}

// MARK: - 33. Doubler

/// ADT (Automatic Double Tracking) effect
final class Doubler: DSPEffect {
    var delay: Float = 20.0         // ms (10 to 50)
    var depth: Float = 0.5          // 0-1 (modulation depth)
    var rate: Float = 0.5           // Hz (modulation rate)
    var detune: Float = 5.0         // Cents
    var mix: Float = 0.5            // 0-1
    var stereo: Bool = true         // Spread doubles
    var bypass: Bool = false

    // Delay buffer
    private var delayBuffer: [Float] = []
    private var writePos: Int = 0
    private let maxDelaySamples = 4096

    // Modulation
    private var modPhase: Float = 0

    // Pitch shift state
    private var pitchBuffer: [Float] = []
    private var pitchReadPos: Float = 0

    init() {
        delayBuffer = [Float](repeating: 0, count: maxDelaySamples)
        pitchBuffer = [Float](repeating: 0, count: maxDelaySamples)
    }

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        let baseDelaySamples = delay * 0.001 * sampleRate
        let modDepth = depth * 5.0 * 0.001 * sampleRate  // Up to 5ms modulation
        let pitchRatio = pow(2.0, detune / 1200.0)  // Cents to ratio

        for i in 0..<buffer.count {
            let input = buffer[i]

            // Write to delay buffer
            delayBuffer[writePos] = input

            // Modulation for natural variation
            modPhase += rate / sampleRate
            if modPhase > 1.0 { modPhase -= 1.0 }
            let modulation = sin(modPhase * 2.0 * Float.pi) * modDepth

            // Read from delay with modulation
            let delaySamples = baseDelaySamples + modulation
            let readPosFloat = Float(writePos) - delaySamples
            var readPosNorm = readPosFloat
            while readPosNorm < 0 { readPosNorm += Float(delayBuffer.count) }

            let readIdx = Int(readPosNorm) % delayBuffer.count
            let nextIdx = (readIdx + 1) % delayBuffer.count
            let frac = readPosNorm - Float(Int(readPosNorm))

            let delayed = delayBuffer[readIdx] * (1 - frac) + delayBuffer[nextIdx] * frac

            // Apply subtle pitch shift
            pitchBuffer[writePos] = delayed
            pitchReadPos += pitchRatio
            if pitchReadPos >= Float(pitchBuffer.count) {
                pitchReadPos -= Float(pitchBuffer.count)
            }

            let pitchIdx = Int(pitchReadPos) % pitchBuffer.count
            let pitchNextIdx = (pitchIdx + 1) % pitchBuffer.count
            let pitchFrac = pitchReadPos - Float(Int(pitchReadPos))
            let doubled = pitchBuffer[pitchIdx] * (1 - pitchFrac) + pitchBuffer[pitchNextIdx] * pitchFrac

            writePos = (writePos + 1) % delayBuffer.count

            // Mix
            buffer[i] = input * (1.0 - mix) + (input + doubled) * 0.5 * mix
        }
    }

    func reset() {
        delayBuffer = [Float](repeating: 0, count: maxDelaySamples)
        pitchBuffer = [Float](repeating: 0, count: maxDelaySamples)
        writePos = 0
        modPhase = 0
        pitchReadPos = 0
    }
}

// MARK: - ============================================
// MARK: - DISTORTION PROCESSORS (34-38)
// MARK: - ============================================

// MARK: - 34. Preamp

/// Tube preamp saturation
final class Preamp: DSPEffect {
    var drive: Float = 0.5          // 0-1
    var tone: Float = 0.5           // 0-1 (dark to bright)
    var output: Float = 0.0         // dB (-12 to 12)
    var tubeType: TubeType = .tube12AX7
    var bypass: Bool = false

    enum TubeType: String, CaseIterable {
        case tube12AX7   // High gain, detailed
        case tube12AT7   // Lower gain, cleaner
        case tube6L6     // Power tube, warm
        case tubeEL34    // British, midrange
    }

    // Filter states
    private var highpassState: Float = 0
    private var lowpassState: Float = 0

    // Tube state (for asymmetric clipping)
    private var tubeState: Float = 0

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        let driveAmount = 1.0 + drive * 20.0  // Up to 20x gain
        let outputGain = pow(10.0, output / 20.0)

        // Tube characteristics
        let (asymmetry, hardness, warmth) = tubeCharacteristics()

        for i in 0..<buffer.count {
            var sample = buffer[i]

            // Input high-pass (coupling capacitor)
            highpassState = 0.995 * highpassState + sample
            sample = sample - 0.995 * highpassState

            // Apply drive
            sample *= driveAmount

            // Tube saturation with asymmetry
            let positiveClip = tanh(sample * hardness) / hardness
            let negativeClip = tanh(sample * hardness * asymmetry) / (hardness * asymmetry)
            sample = sample > 0 ? positiveClip : negativeClip

            // Add even harmonics (tube warmth)
            tubeState = tubeState * 0.9 + sample * 0.1
            sample += tubeState * tubeState * warmth * 0.2

            // Tone control
            let toneCoeff = 0.2 + tone * 0.6
            lowpassState = lowpassState + toneCoeff * (sample - lowpassState)
            sample = lowpassState * tone + sample * (1 - tone * 0.5)

            // Output level
            buffer[i] = sample * outputGain
        }
    }

    private func tubeCharacteristics() -> (asymmetry: Float, hardness: Float, warmth: Float) {
        switch tubeType {
        case .tube12AX7:
            return (0.85, 1.2, 0.3)   // Slight asymmetry, medium hardness
        case .tube12AT7:
            return (0.9, 0.8, 0.2)    // More symmetric, softer
        case .tube6L6:
            return (0.8, 0.9, 0.5)    // More asymmetric, warm
        case .tubeEL34:
            return (0.75, 1.0, 0.4)   // Strong asymmetry, midrange
        }
    }

    func reset() {
        highpassState = 0
        lowpassState = 0
        tubeState = 0
    }
}

// MARK: - 35. Saturation

/// Multi-mode saturation (tape/tube/transistor)
final class Saturation: DSPEffect {
    var drive: Float = 0.5          // 0-1
    var mode: SaturationMode = .tape
    var mix: Float = 1.0            // 0-1
    var output: Float = 0.0         // dB
    var bypass: Bool = false

    enum SaturationMode: String, CaseIterable {
        case tape       // Soft, warm compression
        case tube       // Asymmetric, harmonics
        case transistor // Hard, aggressive
        case fuzz       // Extreme clipping
    }

    // State for different modes
    private var tapeState: Float = 0
    private var biasState: Float = 0

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        let driveAmount = 0.5 + drive * 4.0
        let outputGain = pow(10.0, output / 20.0)

        for i in 0..<buffer.count {
            let dry = buffer[i]
            var wet = dry * driveAmount

            switch mode {
            case .tape:
                // Tape saturation: soft clipping + compression + hysteresis
                let hysteresis = tapeState * 0.1
                wet = wet + hysteresis
                wet = tanh(wet * 0.8) / 0.8  // Soft saturation

                // High frequency loss under saturation
                tapeState = tapeState * 0.95 + wet * 0.05

                // Bias (adds even harmonics)
                biasState = biasState * 0.99 + wet * wet * 0.01
                wet += biasState * drive * 0.1

            case .tube:
                // Tube: asymmetric with even harmonics
                let asymmetry: Float = 0.3
                if wet > 0 {
                    wet = tanh(wet)
                } else {
                    wet = tanh(wet * (1 + asymmetry)) / (1 + asymmetry)
                }

                // Add second harmonic
                wet += wet * wet * drive * 0.15

            case .transistor:
                // Transistor: harder clipping, odd harmonics
                wet = wet / (1 + abs(wet))  // Soft clip
                wet = max(-1, min(1, wet * 1.5))  // Harder limit

                // Add odd harmonics (3rd, 5th)
                let cubic = wet * wet * wet
                wet = wet * 0.8 + cubic * 0.2

            case .fuzz:
                // Fuzz: extreme clipping with gating
                let gateThreshold: Float = 0.02
                if abs(wet) < gateThreshold {
                    wet = 0  // Gate low signals
                } else {
                    // Hard asymmetric clipping
                    wet = wet > 0 ? min(1, wet * 2) : max(-0.8, wet * 2)
                }

                // Octave-up artifact
                wet += abs(wet) * wet * 0.3
            }

            buffer[i] = dry * (1 - mix) + wet * mix * outputGain
        }
    }

    func reset() {
        tapeState = 0
        biasState = 0
    }
}

// MARK: - 36. Bit Crusher

/// Sample rate and bit depth reduction
final class BitCrusher: DSPEffect {
    var bitDepth: Float = 8.0       // 1-16 bits
    var sampleRateReduction: Float = 1.0  // 1-100 (divisor)
    var dither: Float = 0.0         // 0-1 (noise before quantization)
    var mix: Float = 1.0            // 0-1
    var bypass: Bool = false

    // Sample and hold state
    private var holdSample: Float = 0
    private var holdCounter: Int = 0

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        let bits = max(1, min(16, Int(bitDepth)))
        let levels = Float(1 << bits)
        let reduction = max(1, Int(sampleRateReduction))

        for i in 0..<buffer.count {
            let dry = buffer[i]

            // Sample rate reduction (sample and hold)
            holdCounter += 1
            if holdCounter >= reduction {
                holdCounter = 0

                var sample = dry

                // Add dither
                if dither > 0.01 {
                    let ditherNoise = Float.random(in: -1...1) * dither / levels
                    sample += ditherNoise
                }

                // Bit depth reduction (quantization)
                sample = round(sample * levels) / levels
                holdSample = sample
            }

            buffer[i] = dry * (1 - mix) + holdSample * mix
        }
    }

    func reset() {
        holdSample = 0
        holdCounter = 0
    }
}

// MARK: - 37. LoFi

/// Vinyl/tape degradation effect
final class LoFi: DSPEffect {
    var vinyl: Float = 0.5          // 0-1 (crackle, noise, wow)
    var tape: Float = 0.5           // 0-1 (hiss, saturation, roll-off)
    var filterCutoff: Float = 8000  // Hz (high cut)
    var noise: Float = 0.2          // 0-1
    var wow: Float = 0.3            // 0-1 (pitch wobble)
    var bypass: Bool = false

    // Vinyl state
    private var crackleTimer: Float = 0
    private var wowPhase: Float = 0

    // Tape state
    private var lowpassState: Float = 0
    private var highpassState: Float = 0
    private var saturationState: Float = 0

    // Pitch wobble buffer
    private var wobbleBuffer: [Float] = []
    private var wobbleWritePos: Int = 0
    private var wobbleReadPos: Float = 0
    private let wobbleBufferSize = 4096

    init() {
        wobbleBuffer = [Float](repeating: 0, count: wobbleBufferSize)
    }

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        let lpCoeff = exp(-2.0 * Float.pi * filterCutoff / sampleRate)

        for i in 0..<buffer.count {
            var sample = buffer[i]

            // === TAPE PROCESSING ===
            if tape > 0.01 {
                // Tape saturation
                let tapeWarm = tanh(sample * (1 + tape * 2)) / (1 + tape * 2)
                saturationState = saturationState * 0.95 + tapeWarm * 0.05
                sample = tapeWarm + saturationState * tape * 0.1

                // Tape hiss (filtered noise)
                let hiss = Float.random(in: -1...1) * tape * noise * 0.05
                highpassState = 0.95 * highpassState + hiss
                sample += hiss - 0.95 * highpassState

                // High frequency roll-off
                lowpassState = lowpassState + (1 - lpCoeff * tape) * (sample - lowpassState)
                sample = lowpassState
            }

            // === VINYL PROCESSING ===
            if vinyl > 0.01 {
                // Wow (slow pitch variation)
                wobbleBuffer[wobbleWritePos] = sample
                wowPhase += 0.5 / sampleRate
                if wowPhase > 1.0 { wowPhase -= 1.0 }

                let wowMod = sin(wowPhase * 2.0 * Float.pi) * wow * 10.0
                wobbleReadPos += 1.0 + wowMod / sampleRate * 100
                if wobbleReadPos >= Float(wobbleBufferSize) {
                    wobbleReadPos -= Float(wobbleBufferSize)
                }
                if wobbleReadPos < 0 {
                    wobbleReadPos += Float(wobbleBufferSize)
                }

                let readIdx = Int(wobbleReadPos) % wobbleBufferSize
                sample = wobbleBuffer[readIdx]

                wobbleWritePos = (wobbleWritePos + 1) % wobbleBufferSize

                // Vinyl crackle
                crackleTimer -= 1
                if crackleTimer <= 0 {
                    crackleTimer = Float.random(in: 100...5000) / vinyl
                    if Float.random(in: 0...1) < vinyl * 0.3 {
                        // Pop/crackle
                        let crackle = Float.random(in: 0.1...0.5) * (Float.random(in: 0...1) > 0.5 ? 1 : -1)
                        sample += crackle * vinyl
                    }
                }

                // Surface noise
                sample += Float.random(in: -1...1) * vinyl * noise * 0.02
            }

            buffer[i] = sample
        }
    }

    func reset() {
        crackleTimer = 0
        wowPhase = 0
        lowpassState = 0
        highpassState = 0
        saturationState = 0
        wobbleBuffer = [Float](repeating: 0, count: wobbleBufferSize)
        wobbleWritePos = 0
        wobbleReadPos = 0
    }
}

// MARK: - 38. Wave Folder

/// Waveshaping with folding
final class WaveFolder: DSPEffect {
    var folds: Float = 2.0          // 1-8 (number of folds)
    var symmetry: Float = 0.0       // -1 to 1 (asymmetric folding)
    var drive: Float = 0.5          // 0-1
    var lowpass: Float = 1.0        // 0-1 (post-filter)
    var mix: Float = 1.0            // 0-1
    var bypass: Bool = false

    // Antialiasing state
    private var oversampleState: [Float] = [0, 0, 0, 0]
    private var lowpassState: Float = 0

    func processBlock(buffer: inout [Float], sampleRate: Float) {
        guard !bypass else { return }

        let driveAmount = 1.0 + drive * 8.0
        let lpCoeff = lowpass * 0.5

        for i in 0..<buffer.count {
            let dry = buffer[i]
            var wet = dry * driveAmount

            // Apply asymmetry (DC offset before folding)
            wet += symmetry * 0.5

            // Wave folding
            wet = foldWave(wet, folds: folds)

            // Remove DC offset
            wet -= symmetry * 0.3

            // Simple oversampling (2x) for antialiasing
            let prev = oversampleState[0]
            oversampleState[0] = wet
            let interpolated = (prev + wet) * 0.5
            let foldedInterp = foldWave(interpolated, folds: folds)
            wet = (wet + foldedInterp) * 0.5

            // Post lowpass filter
            lowpassState = lowpassState + lpCoeff * (wet - lowpassState)
            wet = lowpassState * lowpass + wet * (1 - lowpass * 0.7)

            buffer[i] = dry * (1 - mix) + wet * mix
        }
    }

    private func foldWave(_ input: Float, folds: Float) -> Float {
        var sample = input

        // Multiple folding stages
        for _ in 0..<Int(folds) {
            // Fold at +/- 1
            if sample > 1.0 {
                sample = 2.0 - sample
            } else if sample < -1.0 {
                sample = -2.0 - sample
            }
        }

        // Fractional fold (smooth transition)
        let fractionalFold = folds - Float(Int(folds))
        if fractionalFold > 0.01 {
            let softFolded = sin(sample * Float.pi * 0.5)
            sample = sample * (1 - fractionalFold) + softFolded * fractionalFold
        }

        return max(-1, min(1, sample))
    }

    func reset() {
        oversampleState = [0, 0, 0, 0]
        lowpassState = 0
    }
}
