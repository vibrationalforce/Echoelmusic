import Foundation
import AVFoundation
import Accelerate

/// Advanced DSP Processing Suite
///
/// Professional audio processing tools:
/// - Noise Gate: Reduce background noise
/// - De-Esser: Reduce sibilance (harsh s/sh sounds)
/// - Limiter: Prevent clipping/distortion
/// - Compressor: Dynamic range control
/// - EQ: Frequency shaping
///
/// Usage:
/// ```swift
/// let dsp = AdvancedDSP()
/// dsp.enableNoiseGate(threshold: -40, ratio: 4.0)
/// dsp.enableDeEsser(frequency: 7000, threshold: -15)
/// dsp.enableLimiter(threshold: -1.0)
/// dsp.process(audioBuffer: buffer)
/// ```
@available(iOS 15.0, *)
public class AdvancedDSP {

    // MARK: - Configuration

    /// Noise Gate Settings
    public struct NoiseGateSettings {
        public var enabled: Bool = false
        public var threshold: Float = -40.0  // dB
        public var ratio: Float = 4.0        // Reduction ratio (4:1)
        public var attack: Float = 0.001     // seconds
        public var release: Float = 0.100    // seconds

        public init(enabled: Bool = false, threshold: Float = -40.0, ratio: Float = 4.0,
                   attack: Float = 0.001, release: Float = 0.100) {
            self.enabled = enabled
            self.threshold = threshold
            self.ratio = ratio
            self.attack = attack
            self.release = release
        }
    }

    /// De-Esser Settings
    public struct DeEsserSettings {
        public var enabled: Bool = false
        public var frequency: Float = 7000   // Hz (sibilant range: 5-10 kHz)
        public var bandwidth: Float = 2000   // Hz
        public var threshold: Float = -15.0  // dB
        public var ratio: Float = 3.0        // Reduction ratio

        public init(enabled: Bool = false, frequency: Float = 7000, bandwidth: Float = 2000,
                   threshold: Float = -15.0, ratio: Float = 3.0) {
            self.enabled = enabled
            self.frequency = frequency
            self.bandwidth = bandwidth
            self.threshold = threshold
            self.ratio = ratio
        }
    }

    /// Limiter Settings
    public struct LimiterSettings {
        public var enabled: Bool = false
        public var threshold: Float = -1.0   // dB
        public var release: Float = 0.050    // seconds
        public var lookahead: Float = 0.005  // seconds

        public init(enabled: Bool = false, threshold: Float = -1.0,
                   release: Float = 0.050, lookahead: Float = 0.005) {
            self.enabled = enabled
            self.threshold = threshold
            self.release = release
            self.lookahead = lookahead
        }
    }

    /// Compressor Settings
    public struct CompressorSettings {
        public var enabled: Bool = false
        public var threshold: Float = -20.0  // dB
        public var ratio: Float = 3.0        // Compression ratio (3:1)
        public var attack: Float = 0.005     // seconds
        public var release: Float = 0.100    // seconds
        public var makeupGain: Float = 0.0   // dB

        public init(enabled: Bool = false, threshold: Float = -20.0, ratio: Float = 3.0,
                   attack: Float = 0.005, release: Float = 0.100, makeupGain: Float = 0.0) {
            self.enabled = enabled
            self.threshold = threshold
            self.ratio = ratio
            self.attack = attack
            self.release = release
            self.makeupGain = makeupGain
        }
    }

    // MARK: - Properties

    public var noiseGate = NoiseGateSettings()
    public var deEsser = DeEsserSettings()
    public var limiter = LimiterSettings()
    public var compressor = CompressorSettings()

    // Internal state
    private var sampleRate: Double = 48000.0
    private var gateEnvelope: Float = 0.0
    private var limiterEnvelope: Float = 0.0
    private var compressorEnvelope: Float = 0.0

    // De-Esser filter state
    private var deEsserFilter: BandpassFilter?

    // MARK: - Initialization

    public init(sampleRate: Double = 48000.0) {
        self.sampleRate = sampleRate
        self.deEsserFilter = BandpassFilter(sampleRate: sampleRate)
    }

    // MARK: - Enable/Disable

    public func enableNoiseGate(threshold: Float = -40.0, ratio: Float = 4.0) {
        noiseGate.enabled = true
        noiseGate.threshold = threshold
        noiseGate.ratio = ratio
        print("[DSP] ✅ Noise Gate enabled (threshold: \(threshold)dB, ratio: \(ratio):1)")
    }

    public func disableNoiseGate() {
        noiseGate.enabled = false
        print("[DSP] ❌ Noise Gate disabled")
    }

    public func enableDeEsser(frequency: Float = 7000, threshold: Float = -15.0) {
        deEsser.enabled = true
        deEsser.frequency = frequency
        deEsser.threshold = threshold
        print("[DSP] ✅ De-Esser enabled (freq: \(frequency)Hz, threshold: \(threshold)dB)")
    }

    public func disableDeEsser() {
        deEsser.enabled = false
        print("[DSP] ❌ De-Esser disabled")
    }

    public func enableLimiter(threshold: Float = -1.0) {
        limiter.enabled = true
        limiter.threshold = threshold
        print("[DSP] ✅ Limiter enabled (threshold: \(threshold)dB)")
    }

    public func disableLimiter() {
        limiter.enabled = false
        print("[DSP] ❌ Limiter disabled")
    }

    public func enableCompressor(threshold: Float = -20.0, ratio: Float = 3.0, makeupGain: Float = 0.0) {
        compressor.enabled = true
        compressor.threshold = threshold
        compressor.ratio = ratio
        compressor.makeupGain = makeupGain
        print("[DSP] ✅ Compressor enabled (threshold: \(threshold)dB, ratio: \(ratio):1, makeup: \(makeupGain)dB)")
    }

    public func disableCompressor() {
        compressor.enabled = false
        print("[DSP] ❌ Compressor disabled")
    }

    // MARK: - Processing

    /// Process audio buffer through DSP chain
    public func process(audioBuffer: AVAudioPCMBuffer) {
        guard let channelData = audioBuffer.floatChannelData else { return }

        let frameCount = Int(audioBuffer.frameLength)
        let channelCount = Int(audioBuffer.format.channelCount)

        // Process each channel
        for channel in 0..<channelCount {
            let samples = channelData[channel]

            // DSP Chain:
            // 1. Noise Gate (remove noise)
            if noiseGate.enabled {
                processNoiseGate(samples: samples, frameCount: frameCount)
            }

            // 2. De-Esser (reduce sibilance)
            if deEsser.enabled {
                processDeEsser(samples: samples, frameCount: frameCount)
            }

            // 3. Compressor (dynamic range)
            if compressor.enabled {
                processCompressor(samples: samples, frameCount: frameCount)
            }

            // 4. Limiter (prevent clipping) - ALWAYS LAST
            if limiter.enabled {
                processLimiter(samples: samples, frameCount: frameCount)
            }
        }
    }

    // MARK: - Noise Gate

    private func processNoiseGate(samples: UnsafeMutablePointer<Float>, frameCount: Int) {
        let thresholdLinear = dbToLinear(noiseGate.threshold)
        let attackCoeff = exp(-1.0 / (Float(sampleRate) * noiseGate.attack))
        let releaseCoeff = exp(-1.0 / (Float(sampleRate) * noiseGate.release))

        for i in 0..<frameCount {
            let inputLevel = abs(samples[i])

            // Envelope follower
            if inputLevel > gateEnvelope {
                gateEnvelope = inputLevel + attackCoeff * (gateEnvelope - inputLevel)
            } else {
                gateEnvelope = inputLevel + releaseCoeff * (gateEnvelope - inputLevel)
            }

            // Calculate gain reduction
            var gain: Float = 1.0
            if gateEnvelope < thresholdLinear {
                // Below threshold: reduce by ratio
                gain = 1.0 / noiseGate.ratio
            }

            // Apply gain
            samples[i] *= gain
        }
    }

    // MARK: - De-Esser

    private func processDeEsser(samples: UnsafeMutablePointer<Float>, frameCount: Int) {
        guard let filter = deEsserFilter else { return }

        // Configure bandpass filter to isolate sibilant frequencies
        filter.configure(
            centerFrequency: deEsser.frequency,
            bandwidth: deEsser.bandwidth
        )

        let thresholdLinear = dbToLinear(deEsser.threshold)

        for i in 0..<frameCount {
            // Extract sibilant content
            let sibilantSignal = filter.process(sample: samples[i])
            let sibilantLevel = abs(sibilantSignal)

            // If sibilance exceeds threshold, reduce it
            if sibilantLevel > thresholdLinear {
                // Calculate gain reduction for sibilant component
                let excess = sibilantLevel / thresholdLinear
                let reduction = 1.0 - (excess - 1.0) / deEsser.ratio

                // Apply reduction to original signal in sibilant band
                samples[i] *= max(reduction, 0.1)  // Never reduce more than 90%
            }
        }
    }

    // MARK: - Compressor

    private func processCompressor(samples: UnsafeMutablePointer<Float>, frameCount: Int) {
        let thresholdLinear = dbToLinear(compressor.threshold)
        let attackCoeff = exp(-1.0 / (Float(sampleRate) * compressor.attack))
        let releaseCoeff = exp(-1.0 / (Float(sampleRate) * compressor.release))
        let makeupGainLinear = dbToLinear(compressor.makeupGain)

        for i in 0..<frameCount {
            let inputLevel = abs(samples[i])

            // Envelope follower
            if inputLevel > compressorEnvelope {
                compressorEnvelope = inputLevel + attackCoeff * (compressorEnvelope - inputLevel)
            } else {
                compressorEnvelope = inputLevel + releaseCoeff * (compressorEnvelope - inputLevel)
            }

            // Calculate gain reduction
            var gain: Float = 1.0
            if compressorEnvelope > thresholdLinear {
                // Above threshold: compress by ratio
                let excess = compressorEnvelope / thresholdLinear
                gain = thresholdLinear / compressorEnvelope * pow(excess, 1.0 / compressor.ratio)
            }

            // Apply gain + makeup gain
            samples[i] *= gain * makeupGainLinear
        }
    }

    // MARK: - Limiter

    private func processLimiter(samples: UnsafeMutablePointer<Float>, frameCount: Int) {
        let thresholdLinear = dbToLinear(limiter.threshold)
        let releaseCoeff = exp(-1.0 / (Float(sampleRate) * limiter.release))

        for i in 0..<frameCount {
            let inputLevel = abs(samples[i])

            // Peak detection with fast attack
            if inputLevel > limiterEnvelope {
                limiterEnvelope = inputLevel  // Instant attack
            } else {
                limiterEnvelope = inputLevel + releaseCoeff * (limiterEnvelope - inputLevel)
            }

            // Brick wall limiting
            var gain: Float = 1.0
            if limiterEnvelope > thresholdLinear {
                gain = thresholdLinear / limiterEnvelope
            }

            // Apply gain
            samples[i] *= gain
        }
    }

    // MARK: - Utility

    private func dbToLinear(_ db: Float) -> Float {
        return pow(10.0, db / 20.0)
    }

    private func linearToDb(_ linear: Float) -> Float {
        return 20.0 * log10(max(linear, 1e-10))
    }

    // MARK: - Presets

    public enum Preset: String, CaseIterable {
        case bypass = "Bypass"
        case podcast = "Podcast"
        case vocals = "Vocals"
        case broadcast = "Broadcast"
        case mastering = "Mastering"

        public var description: String {
            switch self {
            case .bypass: return "No processing"
            case .podcast: return "Optimized for podcast recording"
            case .vocals: return "Professional vocal processing"
            case .broadcast: return "Broadcasting standards"
            case .mastering: return "Final mastering chain"
            }
        }
    }

    public func applyPreset(_ preset: Preset) {
        // Disable all
        noiseGate.enabled = false
        deEsser.enabled = false
        compressor.enabled = false
        limiter.enabled = false

        switch preset {
        case .bypass:
            // All disabled
            break

        case .podcast:
            enableNoiseGate(threshold: -45, ratio: 6.0)
            enableDeEsser(frequency: 6500, threshold: -12)
            enableCompressor(threshold: -18, ratio: 3.0, makeupGain: 6.0)
            enableLimiter(threshold: -1.0)

        case .vocals:
            enableNoiseGate(threshold: -50, ratio: 8.0)
            enableDeEsser(frequency: 7000, threshold: -15)
            enableCompressor(threshold: -15, ratio: 4.0, makeupGain: 8.0)
            enableLimiter(threshold: -0.5)

        case .broadcast:
            enableNoiseGate(threshold: -40, ratio: 10.0)
            enableDeEsser(frequency: 6000, threshold: -10)
            enableCompressor(threshold: -12, ratio: 5.0, makeupGain: 10.0)
            enableLimiter(threshold: -1.0)

        case .mastering:
            enableCompressor(threshold: -10, ratio: 2.5, makeupGain: 3.0)
            enableLimiter(threshold: -0.1)
        }

        print("[DSP] ✅ Applied preset: \(preset.rawValue)")
    }
}

// MARK: - Bandpass Filter

/// Simple bandpass filter for de-esser
class BandpassFilter {
    private var sampleRate: Double
    private var centerFrequency: Float = 7000
    private var bandwidth: Float = 2000

    // Filter state
    private var x1: Float = 0
    private var x2: Float = 0
    private var y1: Float = 0
    private var y2: Float = 0

    // Filter coefficients
    private var b0: Float = 0
    private var b1: Float = 0
    private var b2: Float = 0
    private var a1: Float = 0
    private var a2: Float = 0

    init(sampleRate: Double) {
        self.sampleRate = sampleRate
        calculateCoefficients()
    }

    func configure(centerFrequency: Float, bandwidth: Float) {
        self.centerFrequency = centerFrequency
        self.bandwidth = bandwidth
        calculateCoefficients()
    }

    private func calculateCoefficients() {
        let omega = 2.0 * Float.pi * centerFrequency / Float(sampleRate)
        let bw = bandwidth / Float(sampleRate)
        let alpha = sin(omega) * sinh(log(2.0) / 2.0 * bw * omega / sin(omega))

        let cosOmega = cos(omega)

        // Bandpass filter coefficients
        b0 = alpha
        b1 = 0
        b2 = -alpha
        a1 = -2 * cosOmega
        a2 = 1 - alpha

        // Normalize
        let a0 = 1 + alpha
        b0 /= a0
        b1 /= a0
        b2 /= a0
        a1 /= a0
        a2 /= a0
    }

    func process(sample: Float) -> Float {
        // Direct Form II implementation
        let output = b0 * sample + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2

        // Update state
        x2 = x1
        x1 = sample
        y2 = y1
        y1 = output

        return output
    }

    func reset() {
        x1 = 0
        x2 = 0
        y1 = 0
        y2 = 0
    }
}
