import Foundation
import Accelerate
import AVFoundation

// MARK: - Neve-Inspired DSP Processors
// Inspired by Rupert Neve Designs mastering hardware
// MBT (Master Buss Transformer), Portico, Shelford series
//
// Key characteristics:
// - Transformer saturation (even harmonics)
// - Inductor-based EQ resonance
// - Feedback compressor topology
// - Musical "silk" top-end

/// Neve-style Master Buss Transformer emulation
/// Inspired by RND MBT - adds harmonic richness and cohesion
///
/// Features:
/// - Even harmonic generation (2nd, 4th)
/// - Transformer hysteresis modeling
/// - Low-frequency thickening
/// - High-frequency "silk" smoothing
/// - Drive control for saturation amount
@MainActor
class NeveTransformerSaturation {

    // MARK: - Parameters

    /// Drive amount (0-100%)
    var drive: Float = 30.0

    /// Texture control - blend between clean and saturated
    var texture: Float = 50.0

    /// Silk mode - HF smoothing (Neve signature)
    var silk: Float = 50.0

    /// Silk frequency (red vs blue mode)
    enum SilkMode: String, CaseIterable {
        case red = "Red"    // Lower frequency rolloff (warmer)
        case blue = "Blue"  // Higher frequency rolloff (brighter)
    }
    var silkMode: SilkMode = .red

    private let sampleRate: Float

    // State variables for hysteresis
    private var prevInput: Float = 0.0
    private var dcBlockerState: Float = 0.0

    init(sampleRate: Float = 48000) {
        self.sampleRate = sampleRate
    }

    // MARK: - Processing

    func process(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)

        let driveLinear = drive / 100.0 * 1.5 + 0.5  // 0.5 to 2.0
        let textureBlend = texture / 100.0
        let silkAmount = silk / 100.0

        for i in 0..<input.count {
            let sample = input[i]

            // 1. Input stage with transformer loading
            let loaded = transformerLoading(sample, drive: driveLinear)

            // 2. Hysteresis saturation (transformer core)
            let saturated = transformerHysteresis(loaded, drive: driveLinear)

            // 3. Even harmonic generation (2nd + 4th)
            let withHarmonics = addEvenHarmonics(saturated, amount: driveLinear * 0.5)

            // 4. Silk high-frequency processing
            let silked = applySilk(withHarmonics, amount: silkAmount)

            // 5. DC blocking
            let dcBlocked = dcBlock(silked)

            // 6. Texture blend (dry/wet)
            output[i] = sample * (1.0 - textureBlend) + dcBlocked * textureBlend

            prevInput = sample
        }

        return output
    }

    // MARK: - Transformer Modeling

    /// Simulates transformer input loading (impedance interaction)
    private func transformerLoading(_ input: Float, drive: Float) -> Float {
        // Transformers add subtle compression at high levels
        let threshold: Float = 0.7
        if abs(input) > threshold {
            let excess = abs(input) - threshold
            let compressed = threshold + excess * 0.7  // Gentle limiting
            return input > 0 ? compressed : -compressed
        }
        return input
    }

    /// Hysteresis modeling - magnetic core saturation
    /// Creates smooth, musical saturation characteristic of Neve transformers
    private func transformerHysteresis(_ input: Float, drive: Float) -> Float {
        // Simplified hysteresis using waveshaping with memory
        let alpha: Float = 0.15 * drive  // Hysteresis amount

        // Blend current and previous input for hysteresis effect
        let smoothed = input * (1.0 - alpha) + prevInput * alpha

        // Soft saturation curve (more musical than hard clipping)
        // Uses polynomial approximation of tube/transformer character
        let x = smoothed * drive
        let saturated: Float

        if abs(x) < 1.0 {
            // Polynomial soft clipping for small signals
            saturated = x - (x * x * x) / 3.0
        } else {
            // Asymptotic approach to +/- 2/3 for large signals
            saturated = x > 0 ? 2.0/3.0 : -2.0/3.0
        }

        return saturated / drive * 1.5  // Normalize output
    }

    /// Adds even harmonics (2nd + 4th) - signature of transformer saturation
    /// Odd harmonics (3rd, 5th) = harsh, Even harmonics = warm
    private func addEvenHarmonics(_ input: Float, amount: Float) -> Float {
        // 2nd harmonic: frequency doubling
        let second = input * input * 0.5  // x² creates 2nd harmonic

        // 4th harmonic: frequency quadrupling
        let fourth = input * input * input * input * 0.125  // x⁴ creates 4th

        // Blend harmonics with dry signal
        // Even harmonics add warmth without harshness
        return input + (second + fourth) * amount * 0.3
    }

    /// Neve "Silk" circuit - HF saturation/smoothing
    /// Red = warmer (lower corner), Blue = brighter (higher corner)
    private func applySilk(_ input: Float, amount: Float) -> Float {
        guard amount > 0.01 else { return input }

        // Corner frequency based on silk mode
        let cornerFreq: Float = silkMode == .red ? 8000.0 : 12000.0

        // Simple 1-pole lowpass for silk smoothing
        let omega = 2.0 * Float.pi * cornerFreq / sampleRate
        let alpha = omega / (omega + 1.0)

        // State variable filter approximation
        let filtered = alpha * input + (1.0 - alpha) * prevInput

        // Blend original with silk-processed
        return input * (1.0 - amount * 0.5) + filtered * amount * 0.5
    }

    /// DC blocking filter to remove offset from saturation
    private func dcBlock(_ input: Float) -> Float {
        let alpha: Float = 0.995  // High-pass corner ~10Hz at 48kHz
        let output = input - dcBlockerState
        dcBlockerState = input - output * alpha
        return output
    }
}


// MARK: - Neve-Style Inductor EQ

/// Neve 1073-inspired inductor EQ
/// Inductor-based EQ has natural resonance and phase characteristics
/// that digital EQ doesn't replicate without explicit modeling
///
/// Features:
/// - Fixed frequency bands (classic Neve selections)
/// - Inductor resonance modeling
/// - Proportional-Q behavior
/// - Musical shelving curves
@MainActor
class NeveInductorEQ {

    // MARK: - Band Parameters

    /// Low shelf frequencies (Hz) - classic 1073 selections
    enum LowFreq: Float, CaseIterable {
        case hz35 = 35.0
        case hz60 = 60.0
        case hz110 = 110.0
        case hz220 = 220.0
    }

    /// High shelf frequencies (Hz)
    enum HighFreq: Float, CaseIterable {
        case khz12 = 12000.0
        case khz16 = 16000.0
    }

    /// Mid peak frequencies (Hz) - 1073 style
    enum MidFreq: Float, CaseIterable {
        case hz360 = 360.0
        case hz700 = 700.0
        case hz1k6 = 1600.0
        case hz3k2 = 3200.0
        case hz4k8 = 4800.0
        case hz7k2 = 7200.0
    }

    // Current settings
    var lowFreq: LowFreq = .hz110
    var lowGain: Float = 0.0  // dB (-16 to +16)

    var midFreq: MidFreq = .hz1k6
    var midGain: Float = 0.0  // dB (-18 to +18)

    var highFreq: HighFreq = .khz12
    var highGain: Float = 0.0  // dB (-16 to +16)

    /// Inductor resonance amount (0-100%)
    var resonance: Float = 30.0

    private let sampleRate: Float

    // Filter states
    private var lowState: [Float] = [0, 0]
    private var midState: [Float] = [0, 0]
    private var highState: [Float] = [0, 0]

    init(sampleRate: Float = 48000) {
        self.sampleRate = sampleRate
    }

    // MARK: - Processing

    func process(_ input: [Float]) -> [Float] {
        var output = input

        // Apply each band
        if abs(lowGain) > 0.1 {
            output = applyLowShelf(output)
        }

        if abs(midGain) > 0.1 {
            output = applyMidPeak(output)
        }

        if abs(highGain) > 0.1 {
            output = applyHighShelf(output)
        }

        return output
    }

    // MARK: - Inductor EQ Bands

    private func applyLowShelf(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)

        let freq = lowFreq.rawValue
        let A = pow(10.0, lowGain / 40.0)
        let omega = 2.0 * Float.pi * freq / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)

        // Inductor resonance adds Q boost at corner
        let baseQ: Float = 0.707
        let resonanceBoost = 1.0 + (resonance / 100.0) * 0.5
        let Q = baseQ * resonanceBoost

        let alpha = sinOmega / (2.0 * Q)
        let sqrtA = sqrt(A)

        // Low shelf coefficients
        let a0 = (A + 1) + (A - 1) * cosOmega + 2 * sqrtA * alpha
        let b0 = A * ((A + 1) - (A - 1) * cosOmega + 2 * sqrtA * alpha) / a0
        let b1 = 2 * A * ((A - 1) - (A + 1) * cosOmega) / a0
        let b2 = A * ((A + 1) - (A - 1) * cosOmega - 2 * sqrtA * alpha) / a0
        let a1 = -2 * ((A - 1) + (A + 1) * cosOmega) / a0
        let a2 = ((A + 1) + (A - 1) * cosOmega - 2 * sqrtA * alpha) / a0

        // Process with state
        for i in 0..<input.count {
            let x0 = input[i]
            let y0 = b0 * x0 + b1 * lowState[0] + b2 * lowState[1]
                   - a1 * output[max(0, i-1)] - a2 * output[max(0, i-2)]
            output[i] = y0
            lowState[1] = lowState[0]
            lowState[0] = x0
        }

        return output
    }

    private func applyMidPeak(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)

        let freq = midFreq.rawValue
        let A = pow(10.0, midGain / 40.0)
        let omega = 2.0 * Float.pi * freq / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)

        // Proportional-Q: bandwidth stays constant as gain changes
        // This is characteristic of Neve inductor EQ
        let Q: Float = 1.5 + (resonance / 100.0) * 1.0

        let alpha = sinOmega / (2.0 * Q)

        // Peak EQ coefficients
        let a0 = 1.0 + alpha / A
        let b0 = (1.0 + alpha * A) / a0
        let b1 = (-2.0 * cosOmega) / a0
        let b2 = (1.0 - alpha * A) / a0
        let a1 = (-2.0 * cosOmega) / a0
        let a2 = (1.0 - alpha / A) / a0

        for i in 0..<input.count {
            let x0 = input[i]
            let y0 = b0 * x0 + b1 * midState[0] + b2 * midState[1]
                   - a1 * output[max(0, i-1)] - a2 * output[max(0, i-2)]
            output[i] = y0
            midState[1] = midState[0]
            midState[0] = x0
        }

        return output
    }

    private func applyHighShelf(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)

        let freq = highFreq.rawValue
        let A = pow(10.0, highGain / 40.0)
        let omega = 2.0 * Float.pi * freq / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)

        let baseQ: Float = 0.707
        let resonanceBoost = 1.0 + (resonance / 100.0) * 0.3
        let Q = baseQ * resonanceBoost

        let alpha = sinOmega / (2.0 * Q)
        let sqrtA = sqrt(A)

        // High shelf coefficients
        let a0 = (A + 1) - (A - 1) * cosOmega + 2 * sqrtA * alpha
        let b0 = A * ((A + 1) + (A - 1) * cosOmega + 2 * sqrtA * alpha) / a0
        let b1 = -2 * A * ((A - 1) + (A + 1) * cosOmega) / a0
        let b2 = A * ((A + 1) + (A - 1) * cosOmega - 2 * sqrtA * alpha) / a0
        let a1 = 2 * ((A - 1) - (A + 1) * cosOmega) / a0
        let a2 = ((A + 1) - (A - 1) * cosOmega - 2 * sqrtA * alpha) / a0

        for i in 0..<input.count {
            let x0 = input[i]
            let y0 = b0 * x0 + b1 * highState[0] + b2 * highState[1]
                   - a1 * output[max(0, i-1)] - a2 * output[max(0, i-2)]
            output[i] = y0
            highState[1] = highState[0]
            highState[0] = x0
        }

        return output
    }
}


// MARK: - Neve-Style Feedback Compressor

/// Neve 33609-inspired feedback compressor
/// Feedback topology creates more musical, program-dependent compression
///
/// Features:
/// - Feedback detection topology
/// - 6 fixed attack times, 6 fixed release times (like 33609)
/// - Soft knee characteristic
/// - Link for stereo operation
/// - Recovery control
@MainActor
class NeveFeedbackCompressor {

    // MARK: - 33609-Style Fixed Times

    /// Fixed attack times (ms) - matches 33609
    enum AttackTime: Float, CaseIterable {
        case fast1 = 1.5
        case fast2 = 3.0
        case medium1 = 6.0
        case medium2 = 12.0
        case slow1 = 24.0
        case slow2 = 48.0
    }

    /// Fixed release times (ms) - matches 33609
    enum ReleaseTime: Float, CaseIterable {
        case fast1 = 100.0
        case fast2 = 200.0
        case medium1 = 400.0
        case medium2 = 800.0
        case slow1 = 1200.0
        case auto = 0.0  // Program-dependent
    }

    // Parameters
    var threshold: Float = -10.0  // dB
    var ratio: Float = 2.0  // 1.5:1, 2:1, 3:1, 4:1, 6:1 (33609 settings)
    var attack: AttackTime = .medium1
    var release: ReleaseTime = .medium1
    var makeupGain: Float = 0.0  // dB

    /// Recovery control - how fast compressor "breathes"
    var recovery: Float = 50.0  // 0-100%

    /// Stereo link mode
    var stereoLink: Bool = true

    private let sampleRate: Float
    private var envelope: Float = 0.0
    private var gainReduction: Float = 0.0

    // Auto-release state
    private var peakHold: Float = 0.0
    private var autoReleaseEnv: Float = 0.0

    init(sampleRate: Float = 48000) {
        self.sampleRate = sampleRate
    }

    // MARK: - Processing

    func process(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)

        let attackMs = attack.rawValue
        let releaseMs = release == .auto ? calculateAutoRelease() : release.rawValue

        // Time constants
        let attackCoeff = exp(-1.0 / (sampleRate * attackMs / 1000.0))
        let releaseCoeff = exp(-1.0 / (sampleRate * releaseMs / 1000.0))

        // Makeup gain
        let makeupLinear = pow(10.0, makeupGain / 20.0)

        for i in 0..<input.count {
            let sample = input[i]

            // FEEDBACK TOPOLOGY: detect AFTER gain reduction
            // This is key difference from feed-forward compressors
            let outputEstimate = sample * pow(10.0, -gainReduction / 20.0)
            let detectedLevel = abs(outputEstimate)

            // Envelope follower with attack/release
            if detectedLevel > envelope {
                envelope = attackCoeff * envelope + (1.0 - attackCoeff) * detectedLevel
            } else {
                envelope = releaseCoeff * envelope + (1.0 - releaseCoeff) * detectedLevel
            }

            // Convert to dB
            let envelopedB = 20.0 * log10(max(envelope, 1e-10))

            // Soft knee gain computer (33609 has gentle knee)
            let kneeWidth: Float = 6.0  // dB
            var newGainReduction: Float = 0.0

            if envelopedB > threshold - kneeWidth / 2 {
                if envelopedB < threshold + kneeWidth / 2 {
                    // In knee region
                    let x = envelopedB - threshold + kneeWidth / 2
                    newGainReduction = (1.0 - 1.0/ratio) * x * x / (2.0 * kneeWidth)
                } else {
                    // Above knee
                    newGainReduction = (envelopedB - threshold) * (1.0 - 1.0/ratio)
                }
            }

            // Apply recovery control (smoothing on GR changes)
            let recoveryFactor = 0.5 + recovery / 200.0  // 0.5 to 1.0
            gainReduction = gainReduction * recoveryFactor + newGainReduction * (1.0 - recoveryFactor)

            // Apply gain reduction and makeup
            let gainLinear = pow(10.0, -gainReduction / 20.0) * makeupLinear
            output[i] = sample * gainLinear

            // Update auto-release state
            if release == .auto {
                updateAutoRelease(detectedLevel)
            }
        }

        return output
    }

    // MARK: - Auto Release (Program-Dependent)

    private func calculateAutoRelease() -> Float {
        // Auto release: fast for transients, slow for sustained material
        // Adapts between 100ms and 1200ms based on signal
        let baseRelease: Float = 200.0
        let slowRelease: Float = 1200.0

        // Use peak hold ratio to determine program density
        let density = min(autoReleaseEnv / max(peakHold, 0.001), 1.0)

        return baseRelease + density * (slowRelease - baseRelease)
    }

    private func updateAutoRelease(_ level: Float) {
        // Track peak
        if level > peakHold {
            peakHold = level
        } else {
            peakHold *= 0.9999  // Slow decay
        }

        // Track average
        autoReleaseEnv = autoReleaseEnv * 0.999 + level * 0.001
    }

    /// Get current gain reduction for metering
    func getGainReduction() -> Float {
        return gainReduction
    }
}


// MARK: - Complete Neve Mastering Chain

/// Complete Neve-style mastering chain
/// Combines: Transformer → EQ → Compressor → Final Transformer
/// Inspired by professional Neve mastering setups
@MainActor
class NeveMasteringChain {

    let inputTransformer: NeveTransformerSaturation
    let eq: NeveInductorEQ
    let compressor: NeveFeedbackCompressor
    let outputTransformer: NeveTransformerSaturation

    /// Chain bypass
    var bypassed: Bool = false

    /// Individual section bypasses
    var inputTransformerBypassed: Bool = false
    var eqBypassed: Bool = false
    var compressorBypassed: Bool = false
    var outputTransformerBypassed: Bool = false

    init(sampleRate: Float = 48000) {
        inputTransformer = NeveTransformerSaturation(sampleRate: sampleRate)
        eq = NeveInductorEQ(sampleRate: sampleRate)
        compressor = NeveFeedbackCompressor(sampleRate: sampleRate)
        outputTransformer = NeveTransformerSaturation(sampleRate: sampleRate)

        // Default mastering settings
        setupMasteringDefaults()
    }

    private func setupMasteringDefaults() {
        // Input transformer: subtle warmth
        inputTransformer.drive = 25.0
        inputTransformer.texture = 40.0
        inputTransformer.silk = 30.0
        inputTransformer.silkMode = .blue

        // EQ: gentle mastering curve
        eq.lowFreq = .hz60
        eq.lowGain = 1.5  // Subtle low-end warmth
        eq.midFreq = .hz3k2
        eq.midGain = 0.0  // Flat mids
        eq.highFreq = .khz16
        eq.highGain = 1.0  // Air
        eq.resonance = 25.0

        // Compressor: gentle glue
        compressor.threshold = -8.0
        compressor.ratio = 2.0
        compressor.attack = .medium1
        compressor.release = .auto
        compressor.makeupGain = 2.0
        compressor.recovery = 60.0

        // Output transformer: final polish
        outputTransformer.drive = 20.0
        outputTransformer.texture = 30.0
        outputTransformer.silk = 40.0
        outputTransformer.silkMode = .red  // Warmer output
    }

    // MARK: - Processing

    func process(_ input: [Float]) -> [Float] {
        guard !bypassed else { return input }

        var signal = input

        // 1. Input transformer (color + warmth)
        if !inputTransformerBypassed {
            signal = inputTransformer.process(signal)
        }

        // 2. Inductor EQ (tone shaping)
        if !eqBypassed {
            signal = eq.process(signal)
        }

        // 3. Feedback compressor (dynamics)
        if !compressorBypassed {
            signal = compressor.process(signal)
        }

        // 4. Output transformer (final glue)
        if !outputTransformerBypassed {
            signal = outputTransformer.process(signal)
        }

        return signal
    }

    // MARK: - Presets

    /// Warm analog mastering preset
    func applyWarmPreset() {
        inputTransformer.drive = 35.0
        inputTransformer.silk = 40.0
        inputTransformer.silkMode = .red

        eq.lowGain = 2.0
        eq.highGain = 0.5

        compressor.ratio = 1.5
        compressor.attack = .slow1

        outputTransformer.drive = 30.0
    }

    /// Transparent mastering preset
    func applyTransparentPreset() {
        inputTransformer.drive = 15.0
        inputTransformer.texture = 25.0

        eq.lowGain = 0.0
        eq.highGain = 0.0

        compressor.ratio = 1.5
        compressor.threshold = -6.0

        outputTransformer.drive = 15.0
    }

    /// Punchy/aggressive preset
    func applyPunchyPreset() {
        inputTransformer.drive = 45.0
        inputTransformer.texture = 60.0

        eq.lowGain = 3.0
        eq.midGain = 1.5
        eq.highGain = 2.0

        compressor.ratio = 4.0
        compressor.attack = .fast2
        compressor.recovery = 40.0

        outputTransformer.drive = 40.0
    }
}
