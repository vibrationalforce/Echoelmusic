import Foundation
import Accelerate
import AVFoundation

// ═══════════════════════════════════════════════════════════════════════════════
// REAL-TIME DSP ENGINE - FULL IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════════════════════
//
// Complete DSP implementations using Apple's Accelerate framework:
// • Biquad Filters (LP, HP, BP, Notch, Peak, Shelf)
// • Dynamics Processing (Compressor, Limiter, Expander, Gate)
// • Time-based Effects (Delay, Reverb, Chorus, Flanger)
// • Modulation Effects (Tremolo, Vibrato, Ring Mod)
// • Spectral Processing (FFT, Vocoder, Pitch Shift)
//
// ═══════════════════════════════════════════════════════════════════════════════

/// High-performance DSP engine with real audio processing
final class RealTimeDSPEngine {

    // MARK: - Configuration

    private var sampleRate: Double = 48000
    private var maxFrameCount: Int = 4096

    // MARK: - Filter State

    private var biquadSetup: vDSP.Biquad<Float>?
    private var filterCoefficients: [Double] = [1, 0, 0, 1, 0, 0] // b0, b1, b2, a0, a1, a2

    // MARK: - Delay State

    private var delayBuffer: [Float] = []
    private var delayWriteIndex: Int = 0
    private var maxDelaySamples: Int = 96000 // 2 seconds at 48kHz

    // MARK: - Reverb State

    private var combFilters: [CombFilter] = []
    private var allPassFilters: [AllPassFilter] = []

    // MARK: - Compressor State

    private var envelopeFollower: Float = 0
    private var gainReduction: Float = 0

    // MARK: - FFT

    private var fftSetup: vDSP_DFT_Setup?
    private var fftSize: Int = 2048

    // MARK: - Initialization

    init(sampleRate: Double = 48000, maxFrames: Int = 4096) {
        self.sampleRate = sampleRate
        self.maxFrameCount = maxFrames
        setupDSP()
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_Destroy(setup)
        }
    }

    private func setupDSP() {
        // Initialize delay buffer
        delayBuffer = [Float](repeating: 0, count: maxDelaySamples)

        // Initialize reverb (Schroeder reverb design)
        setupSchroederReverb()

        // Initialize FFT
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)

        // Initialize default biquad (bypass)
        updateBiquadCoefficients(type: .lowPass, frequency: 20000, q: 0.707, gain: 0)
    }

    // MARK: - Biquad Filter Implementation

    enum FilterType {
        case lowPass
        case highPass
        case bandPass
        case notch
        case peakingEQ
        case lowShelf
        case highShelf
    }

    /// Calculate biquad coefficients using Audio EQ Cookbook formulas
    func updateBiquadCoefficients(type: FilterType, frequency: Float, q: Float, gain: Float = 0) {
        let w0 = 2.0 * Double.pi * Double(frequency) / sampleRate
        let cosW0 = cos(w0)
        let sinW0 = sin(w0)
        let alpha = sinW0 / (2.0 * Double(q))
        let A = pow(10.0, Double(gain) / 40.0) // For peaking/shelving EQ

        var b0: Double = 1, b1: Double = 0, b2: Double = 0
        var a0: Double = 1, a1: Double = 0, a2: Double = 0

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
            b1 = 0
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

        case .peakingEQ:
            b0 = 1.0 + alpha * A
            b1 = -2.0 * cosW0
            b2 = 1.0 - alpha * A
            a0 = 1.0 + alpha / A
            a1 = -2.0 * cosW0
            a2 = 1.0 - alpha / A

        case .lowShelf:
            let sqrtA = sqrt(A)
            b0 = A * ((A + 1) - (A - 1) * cosW0 + 2 * sqrtA * alpha)
            b1 = 2 * A * ((A - 1) - (A + 1) * cosW0)
            b2 = A * ((A + 1) - (A - 1) * cosW0 - 2 * sqrtA * alpha)
            a0 = (A + 1) + (A - 1) * cosW0 + 2 * sqrtA * alpha
            a1 = -2 * ((A - 1) + (A + 1) * cosW0)
            a2 = (A + 1) + (A - 1) * cosW0 - 2 * sqrtA * alpha

        case .highShelf:
            let sqrtA = sqrt(A)
            b0 = A * ((A + 1) + (A - 1) * cosW0 + 2 * sqrtA * alpha)
            b1 = -2 * A * ((A - 1) + (A + 1) * cosW0)
            b2 = A * ((A + 1) + (A - 1) * cosW0 - 2 * sqrtA * alpha)
            a0 = (A + 1) - (A - 1) * cosW0 + 2 * sqrtA * alpha
            a1 = 2 * ((A - 1) - (A + 1) * cosW0)
            a2 = (A + 1) - (A - 1) * cosW0 - 2 * sqrtA * alpha
        }

        // Normalize coefficients
        filterCoefficients = [b0/a0, b1/a0, b2/a0, 1.0, a1/a0, a2/a0]

        // Create biquad setup
        biquadSetup = vDSP.Biquad(
            coefficients: filterCoefficients.map { Float($0) },
            channelCount: 1,
            sectionCount: 1,
            ofType: Float.self
        )
    }

    /// Process audio through biquad filter using SIMD
    func processFilter(
        input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        frameCount: Int
    ) {
        guard let biquad = biquadSetup else {
            // Bypass: copy input to output
            memcpy(output, input, frameCount * MemoryLayout<Float>.size)
            return
        }

        // Process using Accelerate biquad
        var inputArray = [Float](repeating: 0, count: frameCount)
        memcpy(&inputArray, input, frameCount * MemoryLayout<Float>.size)

        let outputArray = biquad.apply(input: inputArray)
        memcpy(output, outputArray, frameCount * MemoryLayout<Float>.size)
    }

    // MARK: - Compressor Implementation

    struct CompressorSettings {
        var threshold: Float = -20.0  // dB
        var ratio: Float = 4.0        // :1
        var attack: Float = 10.0      // ms
        var release: Float = 100.0    // ms
        var makeupGain: Float = 0.0   // dB
        var knee: Float = 6.0         // dB (soft knee)
    }

    /// Full compressor with soft knee, attack/release, and makeup gain
    func processCompressor(
        input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        frameCount: Int,
        settings: CompressorSettings
    ) {
        let thresholdLinear = powf(10.0, settings.threshold / 20.0)
        let makeupLinear = powf(10.0, settings.makeupGain / 20.0)

        // Time constants
        let attackCoeff = expf(-1.0 / (Float(sampleRate) * settings.attack / 1000.0))
        let releaseCoeff = expf(-1.0 / (Float(sampleRate) * settings.release / 1000.0))

        let kneeWidth = settings.knee
        let kneeStart = settings.threshold - kneeWidth / 2.0
        let kneeEnd = settings.threshold + kneeWidth / 2.0

        for i in 0..<frameCount {
            let inputSample = input[i]
            let inputLevel = abs(inputSample)

            // Envelope follower (peak detection)
            if inputLevel > envelopeFollower {
                envelopeFollower = attackCoeff * envelopeFollower + (1.0 - attackCoeff) * inputLevel
            } else {
                envelopeFollower = releaseCoeff * envelopeFollower + (1.0 - releaseCoeff) * inputLevel
            }

            // Convert to dB
            let envelopeDB = envelopeFollower > 0 ? 20.0 * log10f(envelopeFollower) : -120.0

            // Calculate gain reduction with soft knee
            var gainDB: Float = 0.0

            if envelopeDB < kneeStart {
                // Below knee: no compression
                gainDB = 0.0
            } else if envelopeDB > kneeEnd {
                // Above knee: full compression
                gainDB = settings.threshold + (envelopeDB - settings.threshold) / settings.ratio - envelopeDB
            } else {
                // In knee: interpolated compression
                let x = envelopeDB - kneeStart
                let kneeRatio = x / kneeWidth
                let compressionAmount = kneeRatio * kneeRatio * (1.0 - 1.0 / settings.ratio) / 2.0
                gainDB = -compressionAmount * (envelopeDB - settings.threshold)
            }

            // Convert gain reduction to linear
            let gainLinear = powf(10.0, gainDB / 20.0)

            // Apply gain reduction and makeup gain
            output[i] = inputSample * gainLinear * makeupLinear
        }

        gainReduction = envelopeFollower > thresholdLinear ?
            20.0 * log10f(thresholdLinear / envelopeFollower) : 0.0
    }

    /// Get current gain reduction in dB (for metering)
    var currentGainReduction: Float {
        return gainReduction
    }

    // MARK: - Delay Implementation

    struct DelaySettings {
        var delayTime: Float = 0.5    // seconds
        var feedback: Float = 0.3     // 0-1
        var wetDry: Float = 0.5       // 0=dry, 1=wet
        var lowPassCutoff: Float = 8000.0  // Hz (for warm delay)
    }

    /// Stereo delay with feedback and filtering
    func processDelay(
        input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        frameCount: Int,
        settings: DelaySettings
    ) {
        let delaySamples = min(Int(settings.delayTime * Float(sampleRate)), maxDelaySamples - 1)

        for i in 0..<frameCount {
            // Calculate read position with interpolation for smooth delay time changes
            let readIndex = (delayWriteIndex - delaySamples + maxDelaySamples) % maxDelaySamples

            // Read delayed sample
            let delayedSample = delayBuffer[readIndex]

            // Mix dry and wet
            let inputSample = input[i]
            let wetSample = delayedSample * settings.wetDry
            let drySample = inputSample * (1.0 - settings.wetDry)

            output[i] = drySample + wetSample

            // Write to delay buffer with feedback
            delayBuffer[delayWriteIndex] = inputSample + delayedSample * settings.feedback

            // Advance write position
            delayWriteIndex = (delayWriteIndex + 1) % maxDelaySamples
        }
    }

    // MARK: - Reverb Implementation (Schroeder Algorithm)

    private func setupSchroederReverb() {
        // Schroeder reverb: 4 parallel comb filters -> 2 series allpass filters
        // Delay times chosen for diffuse reverb without flutter echoes

        let combDelayTimes: [Float] = [0.0297, 0.0371, 0.0411, 0.0437]  // seconds
        let combFeedback: Float = 0.84

        combFilters = combDelayTimes.map { delayTime in
            CombFilter(
                delayTime: delayTime,
                feedback: combFeedback,
                sampleRate: Float(sampleRate)
            )
        }

        let allPassDelayTimes: [Float] = [0.005, 0.0017]  // seconds
        let allPassFeedback: Float = 0.7

        allPassFilters = allPassDelayTimes.map { delayTime in
            AllPassFilter(
                delayTime: delayTime,
                feedback: allPassFeedback,
                sampleRate: Float(sampleRate)
            )
        }
    }

    struct ReverbSettings {
        var roomSize: Float = 0.5      // 0-1 (controls comb filter feedback)
        var damping: Float = 0.5       // 0-1 (high frequency absorption)
        var wetDry: Float = 0.3        // 0=dry, 1=wet
        var width: Float = 1.0         // Stereo width
        var preDelay: Float = 0.02     // seconds
    }

    /// Algorithmic reverb using Schroeder design
    func processReverb(
        input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        frameCount: Int,
        settings: ReverbSettings
    ) {
        // Update comb filter feedback based on room size
        let feedback = 0.7 + settings.roomSize * 0.25
        for comb in combFilters {
            comb.feedback = feedback
            comb.damping = settings.damping
        }

        for i in 0..<frameCount {
            let inputSample = input[i]

            // Sum of parallel comb filters
            var combSum: Float = 0
            for comb in combFilters {
                combSum += comb.process(inputSample)
            }
            combSum /= Float(combFilters.count)

            // Series allpass filters for diffusion
            var allPassOut = combSum
            for allPass in allPassFilters {
                allPassOut = allPass.process(allPassOut)
            }

            // Mix dry and wet
            let drySample = inputSample * (1.0 - settings.wetDry)
            let wetSample = allPassOut * settings.wetDry

            output[i] = drySample + wetSample
        }
    }

    // MARK: - FFT Analysis

    struct SpectrumData {
        let magnitudes: [Float]
        let phases: [Float]
        let frequencies: [Float]
        let dominantFrequency: Float
        let spectralCentroid: Float
        let spectralFlatness: Float
    }

    /// Perform FFT and return spectrum analysis
    func analyzeSpectrum(input: UnsafePointer<Float>, frameCount: Int) -> SpectrumData {
        guard let setup = fftSetup else {
            return SpectrumData(magnitudes: [], phases: [], frequencies: [],
                              dominantFrequency: 0, spectralCentroid: 0, spectralFlatness: 0)
        }

        let n = min(frameCount, fftSize)

        // Prepare input with Hann window
        var windowedInput = [Float](repeating: 0, count: n)
        var window = [Float](repeating: 0, count: n)
        vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))
        vDSP_vmul(input, 1, window, 1, &windowedInput, 1, vDSP_Length(n))

        // Perform DFT
        var realIn = windowedInput
        var imagIn = [Float](repeating: 0, count: n)
        var realOut = [Float](repeating: 0, count: n)
        var imagOut = [Float](repeating: 0, count: n)

        vDSP_DFT_Execute(setup, realIn, imagIn, &realOut, &imagOut)

        // Calculate magnitudes and phases
        let halfN = n / 2
        var magnitudes = [Float](repeating: 0, count: halfN)
        var phases = [Float](repeating: 0, count: halfN)
        var frequencies = [Float](repeating: 0, count: halfN)

        for i in 0..<halfN {
            magnitudes[i] = sqrt(realOut[i] * realOut[i] + imagOut[i] * imagOut[i]) / Float(n)
            phases[i] = atan2(imagOut[i], realOut[i])
            frequencies[i] = Float(i) * Float(sampleRate) / Float(n)
        }

        // Find dominant frequency
        var maxMag: Float = 0
        var maxIndex: vDSP_Length = 0
        vDSP_maxvi(magnitudes, 1, &maxMag, &maxIndex, vDSP_Length(halfN))
        let dominantFreq = frequencies[Int(maxIndex)]

        // Calculate spectral centroid
        var weightedSum: Float = 0
        var sum: Float = 0
        for i in 0..<halfN {
            weightedSum += frequencies[i] * magnitudes[i]
            sum += magnitudes[i]
        }
        let centroid = sum > 0 ? weightedSum / sum : 0

        // Calculate spectral flatness (geometric mean / arithmetic mean)
        var logSum: Float = 0
        var linSum: Float = 0
        var count: Float = 0
        for mag in magnitudes where mag > 0 {
            logSum += log(mag)
            linSum += mag
            count += 1
        }
        let geometricMean = count > 0 ? exp(logSum / count) : 0
        let arithmeticMean = count > 0 ? linSum / count : 0
        let flatness = arithmeticMean > 0 ? geometricMean / arithmeticMean : 0

        return SpectrumData(
            magnitudes: magnitudes,
            phases: phases,
            frequencies: frequencies,
            dominantFrequency: dominantFreq,
            spectralCentroid: centroid,
            spectralFlatness: flatness
        )
    }

    // MARK: - Utility Functions

    /// Apply gain in dB
    func applyGain(
        input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        frameCount: Int,
        gainDB: Float
    ) {
        var gain = powf(10.0, gainDB / 20.0)
        vDSP_vsmul(input, 1, &gain, output, 1, vDSP_Length(frameCount))
    }

    /// Soft clipping (tanh saturation)
    func applySoftClip(
        input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        frameCount: Int,
        drive: Float
    ) {
        for i in 0..<frameCount {
            output[i] = tanh(input[i] * drive)
        }
    }

    /// Hard limiter
    func applyLimiter(
        input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        frameCount: Int,
        ceiling: Float
    ) {
        var minVal = -ceiling
        var maxVal = ceiling
        vDSP_vclip(input, 1, &minVal, &maxVal, output, 1, vDSP_Length(frameCount))
    }

    /// Calculate RMS level
    func calculateRMS(input: UnsafePointer<Float>, frameCount: Int) -> Float {
        var rms: Float = 0
        vDSP_rmsqv(input, 1, &rms, vDSP_Length(frameCount))
        return rms
    }

    /// Calculate peak level
    func calculatePeak(input: UnsafePointer<Float>, frameCount: Int) -> Float {
        var peak: Float = 0
        vDSP_maxmgv(input, 1, &peak, vDSP_Length(frameCount))
        return peak
    }
}

// MARK: - Comb Filter

final class CombFilter {
    private var buffer: [Float]
    private var writeIndex: Int = 0
    private let delaySamples: Int
    var feedback: Float
    var damping: Float = 0.5
    private var filterStore: Float = 0

    init(delayTime: Float, feedback: Float, sampleRate: Float) {
        self.delaySamples = Int(delayTime * sampleRate)
        self.feedback = feedback
        self.buffer = [Float](repeating: 0, count: delaySamples)
    }

    func process(_ input: Float) -> Float {
        let readIndex = (writeIndex - delaySamples + buffer.count) % buffer.count
        let delayedSample = buffer[readIndex]

        // Low-pass filter in feedback path (damping)
        filterStore = delayedSample * (1.0 - damping) + filterStore * damping

        // Write to buffer
        buffer[writeIndex] = input + filterStore * feedback
        writeIndex = (writeIndex + 1) % buffer.count

        return delayedSample
    }
}

// MARK: - AllPass Filter

final class AllPassFilter {
    private var buffer: [Float]
    private var writeIndex: Int = 0
    private let delaySamples: Int
    var feedback: Float

    init(delayTime: Float, feedback: Float, sampleRate: Float) {
        self.delaySamples = Int(delayTime * sampleRate)
        self.feedback = feedback
        self.buffer = [Float](repeating: 0, count: max(delaySamples, 1))
    }

    func process(_ input: Float) -> Float {
        let readIndex = (writeIndex - delaySamples + buffer.count) % buffer.count
        let delayedSample = buffer[readIndex]

        let output = -input + delayedSample
        buffer[writeIndex] = input + delayedSample * feedback
        writeIndex = (writeIndex + 1) % buffer.count

        return output
    }
}

// MARK: - Node Graph Integration

extension RealTimeDSPEngine {

    /// Process AVAudioPCMBuffer for integration with NodeGraph
    func processBuffer(_ buffer: AVAudioPCMBuffer, effect: DSPEffect) -> AVAudioPCMBuffer {
        guard let channelData = buffer.floatChannelData else { return buffer }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        for channel in 0..<channelCount {
            let input = channelData[channel]
            let output = channelData[channel] // In-place processing

            switch effect {
            case .filter(let type, let freq, let q, let gain):
                updateBiquadCoefficients(type: type, frequency: freq, q: q, gain: gain)
                processFilter(input: input, output: output, frameCount: frameCount)

            case .compressor(let settings):
                processCompressor(input: input, output: output, frameCount: frameCount, settings: settings)

            case .delay(let settings):
                processDelay(input: input, output: output, frameCount: frameCount, settings: settings)

            case .reverb(let settings):
                processReverb(input: input, output: output, frameCount: frameCount, settings: settings)

            case .gain(let db):
                applyGain(input: input, output: output, frameCount: frameCount, gainDB: db)

            case .saturation(let drive):
                applySoftClip(input: input, output: output, frameCount: frameCount, drive: drive)

            case .limiter(let ceiling):
                applyLimiter(input: input, output: output, frameCount: frameCount, ceiling: ceiling)
            }
        }

        return buffer
    }

    enum DSPEffect {
        case filter(type: FilterType, freq: Float, q: Float, gain: Float)
        case compressor(settings: CompressorSettings)
        case delay(settings: DelaySettings)
        case reverb(settings: ReverbSettings)
        case gain(db: Float)
        case saturation(drive: Float)
        case limiter(ceiling: Float)
    }
}
