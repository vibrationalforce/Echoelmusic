import Foundation

// MARK: - Classic Analog Hardware Emulations
// Cross-Platform Support: iOS 15+, macOS 12+, watchOS 8+, tvOS 15+, visionOS 1+
// Android: See android/app/src/main/kotlin/com/echoelmusic/dsp/ClassicAnalogEmulations.kt
// High-end studio equipment emulation with simplified controls
//
// Supported Hardware Styles:
// 🇬🇧 SSL - Solid State Logic (4000E/G Bus Compressor)
// 🇺🇸 API - All-Pass Input (2500 Bus Compressor)
// 🇺🇸 Pultec - EQP-1A Passive EQ
// 🇺🇸 Fairchild - 670 Tube Limiter
// 🇺🇸 LA-2A - Teletronix Optical Compressor
// 🇺🇸 1176 - UREI FET Limiter
// 🇺🇸 Manley - Vari-Mu & Massive Passive
// 🇬🇧 Chandler - Curve Bender

// MARK: - Unified Analog Console

/// Easy-access console for switching between classic analog emulations
/// One-knob simplicity with expert mode for detailed control
@MainActor
class AnalogConsole {

    /// Available analog hardware styles
    enum HardwareStyle: String, CaseIterable {
        case ssl = "SSL"
        case api = "API"
        case neve = "Neve"
        case pultec = "Pultec"
        case fairchild = "Fairchild"
        case la2a = "LA-2A"
        case urei1176 = "1176"
        case manley = "Manley"

        var fullName: String {
            switch self {
            case .ssl: return "SSL 4000G Bus Compressor"
            case .api: return "API 2500 Stereo Compressor"
            case .neve: return "Neve 33609/MBT"
            case .pultec: return "Pultec EQP-1A"
            case .fairchild: return "Fairchild 670"
            case .la2a: return "Teletronix LA-2A"
            case .urei1176: return "UREI 1176LN"
            case .manley: return "Manley Vari-Mu"
            }
        }

        var category: Category {
            switch self {
            case .ssl, .api, .neve, .fairchild, .la2a, .urei1176, .manley:
                return .compressor
            case .pultec:
                return .equalizer
            }
        }

        enum Category {
            case compressor
            case equalizer
        }

        var color: String {
            switch self {
            case .ssl: return "Blue"      // SSL blue
            case .api: return "Black"     // API black/orange
            case .neve: return "Blue"     // Neve blue
            case .pultec: return "Cream"  // Pultec cream
            case .fairchild: return "Gray" // Fairchild gray
            case .la2a: return "Silver"   // LA-2A silver
            case .urei1176: return "Black" // 1176 blackface
            case .manley: return "Gold"    // Manley gold
            }
        }
    }

    // Current selected hardware
    var currentStyle: HardwareStyle = .ssl {
        didSet { updateProcessor() }
    }

    // MARK: - Simple Controls (One-Knob Mode)

    /// Main "Character" knob (0-100%)
    /// Maps to the most impactful parameter for each unit
    var character: Float = 50.0 {
        didSet { updateParameters() }
    }

    /// Output level (0-100%)
    var output: Float = 50.0

    /// Mix (dry/wet) for parallel processing
    var mix: Float = 100.0

    /// Bypass
    var bypassed: Bool = false

    // MARK: - Internal Processors

    private var sslCompressor: SSLBusCompressor
    private var apiCompressor: APIBusCompressor
    private var pultecEQ: PultecEQP1A
    private var fairchildLimiter: FairchildLimiter
    private var la2aCompressor: LA2ACompressor
    private var urei1176: UREI1176Limiter
    private var manleyVariMu: ManleyVariMu

    private let sampleRate: Float

    init(sampleRate: Float = 48000) {
        self.sampleRate = sampleRate

        sslCompressor = SSLBusCompressor(sampleRate: sampleRate)
        apiCompressor = APIBusCompressor(sampleRate: sampleRate)
        pultecEQ = PultecEQP1A(sampleRate: sampleRate)
        fairchildLimiter = FairchildLimiter(sampleRate: sampleRate)
        la2aCompressor = LA2ACompressor(sampleRate: sampleRate)
        urei1176 = UREI1176Limiter(sampleRate: sampleRate)
        manleyVariMu = ManleyVariMu(sampleRate: sampleRate)
    }

    // MARK: - Processing

    func process(_ input: [Float]) -> [Float] {
        guard !bypassed else { return input }

        var processed: [Float]

        switch currentStyle {
        case .ssl:
            processed = sslCompressor.process(input)
        case .api:
            processed = apiCompressor.process(input)
        case .neve:
            // Use existing Neve from NeveInspiredDSP
            processed = input // Placeholder - integrate with NeveMasteringChain
        case .pultec:
            processed = pultecEQ.process(input)
        case .fairchild:
            processed = fairchildLimiter.process(input)
        case .la2a:
            processed = la2aCompressor.process(input)
        case .urei1176:
            processed = urei1176.process(input)
        case .manley:
            processed = manleyVariMu.process(input)
        }

        // Apply output and mix
        let outputGain = pow(10.0, (output - 50.0) / 50.0 * 12.0 / 20.0)
        let wetAmount = mix / 100.0

        var output = [Float](repeating: 0, count: input.count)
        for i in 0..<input.count {
            let wet = processed[i] * outputGain
            output[i] = input[i] * (1.0 - wetAmount) + wet * wetAmount
        }

        return output
    }

    // MARK: - Parameter Mapping

    private func updateProcessor() {
        updateParameters()
    }

    private func updateParameters() {
        // Map "character" knob to each unit's primary parameter
        let normalized = character / 100.0

        switch currentStyle {
        case .ssl:
            // Character → Ratio + Threshold combo
            sslCompressor.threshold = -30.0 + normalized * 25.0  // -30 to -5
            sslCompressor.ratio = 2.0 + normalized * 8.0  // 2:1 to 10:1

        case .api:
            // Character → Thrust + Tone
            apiCompressor.thrust = normalized > 0.5
            apiCompressor.tone = normalized * 100.0

        case .neve:
            break  // Handled externally

        case .pultec:
            // Character → Low boost + High boost
            pultecEQ.lowBoost = normalized * 10.0
            pultecEQ.highBoost = normalized * 8.0 * 0.7
            pultecEQ.highAtten = normalized * 3.0 * 0.3  // Subtle shelving

        case .fairchild:
            // Character → Threshold + Time constant
            fairchildLimiter.inputGain = normalized * 10.0
            fairchildLimiter.timeConstant = Int(normalized * 5) + 1  // 1-6

        case .la2a:
            // Character → Peak reduction
            la2aCompressor.peakReduction = normalized * 100.0
            la2aCompressor.gain = 30.0 + normalized * 30.0

        case .urei1176:
            // Character → Input + Ratio
            urei1176.inputDrive = normalized * 60.0
            let ratioIndex = Int(normalized * 4)  // 0-4
            urei1176.ratio = [4.0, 8.0, 12.0, 20.0, 100.0][min(ratioIndex, 4)]

        case .manley:
            // Character → Threshold + compression amount
            manleyVariMu.threshold = -20.0 + normalized * 15.0
            manleyVariMu.compression = normalized * 70.0
        }
    }

    /// Get current gain reduction for metering
    func getGainReduction() -> Float {
        switch currentStyle {
        case .ssl: return sslCompressor.gainReduction
        case .api: return apiCompressor.gainReduction
        case .fairchild: return fairchildLimiter.gainReduction
        case .la2a: return la2aCompressor.gainReduction
        case .urei1176: return urei1176.gainReduction
        case .manley: return manleyVariMu.gainReduction
        default: return 0.0
        }
    }
}


// MARK: - SSL 4000G Bus Compressor

/// SSL 4000G-style bus compressor
/// Clean, punchy, "glue" compression
/// The sound of modern mixing
@MainActor
class SSLBusCompressor {

    // Parameters matching SSL front panel
    var threshold: Float = -15.0  // dBFS
    var ratio: Float = 4.0  // 2, 4, 10 (SSL classic ratios)
    var attack: Float = 10.0  // 0.1, 0.3, 1, 3, 10, 30 ms
    var release: Float = 300.0  // 0.1, 0.3, 0.6, 1.2, Auto
    var makeupGain: Float = 0.0  // dB
    var autoRelease: Bool = false  // Program-dependent

    private(set) var gainReduction: Float = 0.0

    private let sampleRate: Float
    private var envelope: Float = 0.0

    init(sampleRate: Float = 48000) {
        self.sampleRate = sampleRate
    }

    func process(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)

        let attackCoeff = exp(-1.0 / (sampleRate * attack / 1000.0))
        let releaseCoeff = exp(-1.0 / (sampleRate * release / 1000.0))
        let makeupLinear = pow(10.0, makeupGain / 20.0)

        var maxGR: Float = 0.0

        for i in 0..<input.count {
            let inputLevel = abs(input[i])

            // VCA-style detection (SSL characteristic)
            if inputLevel > envelope {
                envelope = attackCoeff * envelope + (1.0 - attackCoeff) * inputLevel
            } else {
                let releaseTime = autoRelease ? calculateAutoRelease(inputLevel) : releaseCoeff
                envelope = releaseTime * envelope + (1.0 - releaseTime) * inputLevel
            }

            // Convert to dB
            let envDB = 20.0 * log10(max(envelope, 1e-10))

            // SSL-style hard knee compression
            var gr: Float = 0.0
            if envDB > threshold {
                gr = (envDB - threshold) * (1.0 - 1.0/ratio)
            }

            maxGR = min(maxGR, -gr)

            // Apply gain
            let gainLinear = pow(10.0, -gr / 20.0) * makeupLinear
            output[i] = input[i] * gainLinear
        }

        gainReduction = maxGR
        return output
    }

    private func calculateAutoRelease(_ level: Float) -> Float {
        // Program-dependent: faster for transients, slower for sustained
        let fast: Float = exp(-1.0 / (sampleRate * 0.1 / 1000.0))
        let slow: Float = exp(-1.0 / (sampleRate * 1.2 / 1000.0))

        // Blend based on level
        return level > 0.5 ? fast : slow
    }
}


// MARK: - API 2500 Bus Compressor

/// API 2500-style compressor
/// Punchy, aggressive, with "Thrust" circuit
/// Famous for drums and mix bus
@MainActor
class APIBusCompressor {

    var threshold: Float = -10.0
    var ratio: Float = 4.0  // 1.5, 2, 3, 4, 6, 10
    var attack: Float = 10.0  // 0.03, 0.1, 0.3, 1, 3, 10, 30 ms
    var release: Float = 300.0  // 0.05, 0.1, 0.25, 0.5, 1, 2 sec

    /// Thrust circuit - adds punch by shaping the sidechain
    var thrust: Bool = true

    /// Tone control (0-100) - shapes compression character
    var tone: Float = 50.0  // 0 = old, 100 = new

    /// Detection: Hard (punchy) or Soft (smooth)
    var hardKnee: Bool = true

    /// Feed-forward (new) or Feedback (old) topology
    var feedForward: Bool = true

    private(set) var gainReduction: Float = 0.0

    private let sampleRate: Float
    private var envelope: Float = 0.0
    private var thrustFilter: Float = 0.0

    init(sampleRate: Float = 48000) {
        self.sampleRate = sampleRate
    }

    func process(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)

        let attackCoeff = exp(-1.0 / (sampleRate * attack / 1000.0))
        let releaseCoeff = exp(-1.0 / (sampleRate * release))

        var maxGR: Float = 0.0

        for i in 0..<input.count {
            var detectSignal = input[i]

            // Thrust circuit: high-pass sidechain for more punch
            if thrust {
                let thrustCoeff: Float = 0.95  // ~150Hz high-pass
                thrustFilter = thrustCoeff * thrustFilter + (1.0 - thrustCoeff) * input[i]
                detectSignal = input[i] - thrustFilter
            }

            let inputLevel = abs(detectSignal)

            // Envelope with attack/release
            if inputLevel > envelope {
                envelope = attackCoeff * envelope + (1.0 - attackCoeff) * inputLevel
            } else {
                envelope = releaseCoeff * envelope + (1.0 - releaseCoeff) * inputLevel
            }

            let envDB = 20.0 * log10(max(envelope, 1e-10))

            // Calculate gain reduction
            var gr: Float = 0.0
            if hardKnee {
                // API hard knee
                if envDB > threshold {
                    gr = (envDB - threshold) * (1.0 - 1.0/ratio)
                }
            } else {
                // Soft knee
                let knee: Float = 6.0
                if envDB > threshold - knee/2 {
                    if envDB < threshold + knee/2 {
                        let x = envDB - threshold + knee/2
                        gr = x * x / (2 * knee) * (1.0 - 1.0/ratio)
                    } else {
                        gr = (envDB - threshold) * (1.0 - 1.0/ratio)
                    }
                }
            }

            // Tone shapes the compression character
            let toneAmount = tone / 100.0
            gr = gr * (0.7 + toneAmount * 0.6)  // More aggressive at high tone

            maxGR = min(maxGR, -gr)

            let gainLinear = pow(10.0, -gr / 20.0)
            output[i] = input[i] * gainLinear
        }

        gainReduction = maxGR
        return output
    }
}


// MARK: - Pultec EQP-1A Passive EQ

/// Pultec EQP-1A tube passive EQ emulation
/// Famous "boost and cut" low-end trick
/// Smooth, musical high frequencies
@MainActor
class PultecEQP1A {

    // Low frequency section
    var lowFreq: Float = 60.0  // 20, 30, 60, 100 Hz
    var lowBoost: Float = 0.0  // 0-10 (boost amount)
    var lowAtten: Float = 0.0  // 0-10 (cut amount)

    // High frequency section
    var highFreq: Float = 12000.0  // 3k, 4k, 5k, 8k, 10k, 12k, 16k Hz
    var highBoost: Float = 0.0  // 0-10
    var highBandwidth: Float = 5.0  // Q control
    var highAtten: Float = 0.0  // 5k, 10k, 20k shelf cut

    // Tube saturation
    var tubeOutput: Float = 5.0  // 0-10

    private let sampleRate: Float

    // Filter states
    private var lowBoostState: [Float] = [0, 0]
    private var lowAttenState: [Float] = [0, 0]
    private var highBoostState: [Float] = [0, 0]
    private var highAttenState: [Float] = [0, 0]

    init(sampleRate: Float = 48000) {
        self.sampleRate = sampleRate
    }

    func process(_ input: [Float]) -> [Float] {
        var output = input

        // Low frequency boost (inductor-based resonant boost)
        if lowBoost > 0.1 {
            output = applyLowBoost(output)
        }

        // Low frequency attenuation (separate from boost - Pultec trick!)
        if lowAtten > 0.1 {
            output = applyLowAtten(output)
        }

        // High frequency boost (tube-driven)
        if highBoost > 0.1 {
            output = applyHighBoost(output)
        }

        // High frequency attenuation (passive shelf)
        if highAtten > 0.1 {
            output = applyHighAtten(output)
        }

        // Tube saturation stage
        if tubeOutput > 0.1 {
            output = applyTubeSaturation(output)
        }

        return output
    }

    private func applyLowBoost(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)

        let A = pow(10.0, lowBoost * 1.5 / 20.0)  // Up to +15dB
        let omega = 2.0 * Float.pi * lowFreq / sampleRate
        let Q: Float = 0.7 + lowBoost * 0.1  // Resonant boost

        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * Q)
        let sqrtA = sqrt(A)

        // Low shelf boost coefficients
        let a0 = (A + 1) + (A - 1) * cosOmega + 2 * sqrtA * alpha
        let b0 = A * ((A + 1) - (A - 1) * cosOmega + 2 * sqrtA * alpha) / a0
        let b1 = 2 * A * ((A - 1) - (A + 1) * cosOmega) / a0
        let b2 = A * ((A + 1) - (A - 1) * cosOmega - 2 * sqrtA * alpha) / a0
        let a1 = -2 * ((A - 1) + (A + 1) * cosOmega) / a0
        let a2 = ((A + 1) + (A - 1) * cosOmega - 2 * sqrtA * alpha) / a0

        for i in 0..<input.count {
            let x0 = input[i]
            let y0 = b0 * x0 + b1 * lowBoostState[0] + b2 * lowBoostState[1]
                   - a1 * (i > 0 ? output[i-1] : 0) - a2 * (i > 1 ? output[i-2] : 0)
            output[i] = y0
            lowBoostState[1] = lowBoostState[0]
            lowBoostState[0] = x0
        }

        return output
    }

    private func applyLowAtten(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)

        // Pultec cut is at a DIFFERENT frequency than boost
        // This creates the famous "Pultec trick" curve
        let attenFreq = lowFreq * 1.5  // Cut is higher than boost freq

        let A = pow(10.0, -lowAtten * 1.0 / 20.0)  // Up to -10dB
        let omega = 2.0 * Float.pi * attenFreq / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / 2.0

        // Low shelf cut
        let sqrtA = sqrt(A)
        let a0 = (A + 1) + (A - 1) * cosOmega + 2 * sqrtA * alpha
        let b0 = A * ((A + 1) - (A - 1) * cosOmega + 2 * sqrtA * alpha) / a0
        let b1 = 2 * A * ((A - 1) - (A + 1) * cosOmega) / a0
        let b2 = A * ((A + 1) - (A - 1) * cosOmega - 2 * sqrtA * alpha) / a0
        let a1 = -2 * ((A - 1) + (A + 1) * cosOmega) / a0
        let a2 = ((A + 1) + (A - 1) * cosOmega - 2 * sqrtA * alpha) / a0

        for i in 0..<input.count {
            let x0 = input[i]
            let y0 = b0 * x0 + b1 * lowAttenState[0] + b2 * lowAttenState[1]
                   - a1 * (i > 0 ? output[i-1] : 0) - a2 * (i > 1 ? output[i-2] : 0)
            output[i] = y0
            lowAttenState[1] = lowAttenState[0]
            lowAttenState[0] = x0
        }

        return output
    }

    private func applyHighBoost(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)

        let A = pow(10.0, highBoost * 1.6 / 20.0)  // Up to +16dB
        let omega = 2.0 * Float.pi * highFreq / sampleRate
        let Q = 0.5 + highBandwidth * 0.3  // Bandwidth control

        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * Q)

        // Peak boost (Pultec high boost is a resonant peak)
        let a0 = 1.0 + alpha / A
        let b0 = (1.0 + alpha * A) / a0
        let b1 = (-2.0 * cosOmega) / a0
        let b2 = (1.0 - alpha * A) / a0
        let a1 = (-2.0 * cosOmega) / a0
        let a2 = (1.0 - alpha / A) / a0

        for i in 0..<input.count {
            let x0 = input[i]
            let y0 = b0 * x0 + b1 * highBoostState[0] + b2 * highBoostState[1]
                   - a1 * (i > 0 ? output[i-1] : 0) - a2 * (i > 1 ? output[i-2] : 0)
            output[i] = y0
            highBoostState[1] = highBoostState[0]
            highBoostState[0] = x0
        }

        return output
    }

    private func applyHighAtten(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)

        let A = pow(10.0, -highAtten * 1.0 / 20.0)
        let attenFreq: Float = 10000.0  // Fixed shelving frequency
        let omega = 2.0 * Float.pi * attenFreq / sampleRate

        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let sqrtA = sqrt(A)
        let alpha = sinOmega / 2.0

        // High shelf cut
        let a0 = (A + 1) - (A - 1) * cosOmega + 2 * sqrtA * alpha
        let b0 = A * ((A + 1) + (A - 1) * cosOmega + 2 * sqrtA * alpha) / a0
        let b1 = -2 * A * ((A - 1) + (A + 1) * cosOmega) / a0
        let b2 = A * ((A + 1) + (A - 1) * cosOmega - 2 * sqrtA * alpha) / a0
        let a1 = 2 * ((A - 1) - (A + 1) * cosOmega) / a0
        let a2 = ((A + 1) - (A - 1) * cosOmega - 2 * sqrtA * alpha) / a0

        for i in 0..<input.count {
            let x0 = input[i]
            let y0 = b0 * x0 + b1 * highAttenState[0] + b2 * highAttenState[1]
                   - a1 * (i > 0 ? output[i-1] : 0) - a2 * (i > 1 ? output[i-2] : 0)
            output[i] = y0
            highAttenState[1] = highAttenState[0]
            highAttenState[0] = x0
        }

        return output
    }

    private func applyTubeSaturation(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)

        let drive = tubeOutput / 10.0 * 0.5 + 0.5  // 0.5 to 1.0

        for i in 0..<input.count {
            let x = input[i] * drive

            // Tube saturation: asymmetric soft clipping
            // Tubes add primarily 2nd harmonic (even)
            if x >= 0 {
                output[i] = x / (1.0 + x * 0.3)  // Positive half softer
            } else {
                output[i] = x / (1.0 - x * 0.2)  // Negative half less soft
            }

            output[i] /= drive * 0.9  // Compensate gain
        }

        return output
    }
}


// MARK: - Fairchild 670 Limiter

/// Fairchild 670 tube limiter emulation
/// The "holy grail" of vintage compression
/// Variable-mu tube compression with 6 time constants
@MainActor
class FairchildLimiter {

    var inputGain: Float = 5.0  // 0-10 (drives the tubes)
    var threshold: Float = 10.0  // 0-10 (sets limiting point)
    var timeConstant: Int = 3  // 1-6 (attack/release combos)

    private(set) var gainReduction: Float = 0.0

    private let sampleRate: Float
    private var envelope: Float = 0.0
    private var tubeState: Float = 0.0

    // Fairchild time constants (attack ms, release ms)
    private let timeConstants: [(Float, Float)] = [
        (0.2, 300),     // 1: Fast attack, medium release
        (0.2, 800),     // 2: Fast attack, slow release
        (0.4, 2000),    // 3: Medium attack, very slow
        (0.4, 5000),    // 4: Medium attack, program release
        (0.8, 2000),    // 5: Slow attack, slow release
        (0.8, 10000)    // 6: Slowest - mastering
    ]

    init(sampleRate: Float = 48000) {
        self.sampleRate = sampleRate
    }

    func process(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)

        let (attackMs, releaseMs) = timeConstants[min(timeConstant - 1, 5)]
        let attackCoeff = exp(-1.0 / (sampleRate * attackMs / 1000.0))
        let releaseCoeff = exp(-1.0 / (sampleRate * releaseMs / 1000.0))

        let inputDrive = pow(10.0, inputGain / 20.0)
        let thresholdLinear = pow(10.0, -(10.0 - threshold) * 2.0 / 20.0)

        var maxGR: Float = 0.0

        for i in 0..<input.count {
            // Input stage with tube saturation
            var driven = input[i] * inputDrive
            driven = tubeSaturation(driven)

            let level = abs(driven)

            // Variable-mu envelope (tube compression characteristic)
            // The compression ratio increases with level (variable-mu behavior)
            if level > envelope {
                envelope = attackCoeff * envelope + (1.0 - attackCoeff) * level
            } else {
                envelope = releaseCoeff * envelope + (1.0 - releaseCoeff) * level
            }

            // Variable-mu gain reduction
            // More level = more compression (natural tube behavior)
            var gr: Float = 0.0
            if envelope > thresholdLinear {
                let excess = envelope / thresholdLinear
                // Variable ratio: starts soft, gets harder
                let dynamicRatio = 2.0 + log10(excess) * 4.0
                gr = 20.0 * log10(excess) * (1.0 - 1.0/dynamicRatio)
            }

            // Smooth GR changes (tube inertia)
            tubeState = tubeState * 0.99 + gr * 0.01
            gr = tubeState

            maxGR = min(maxGR, -gr)

            // Apply gain reduction
            let gainLinear = pow(10.0, -gr / 20.0)
            output[i] = driven * gainLinear / inputDrive
        }

        gainReduction = maxGR
        return output
    }

    private func tubeSaturation(_ input: Float) -> Float {
        // Variable-mu tube saturation (6386 tubes)
        let x = input * 1.5

        if abs(x) < 0.5 {
            return x  // Linear region
        } else {
            // Soft saturation
            return x > 0 ?
                0.5 + (x - 0.5) / (1.0 + abs(x - 0.5)) :
                -0.5 + (x + 0.5) / (1.0 + abs(x + 0.5))
        }
    }
}


// MARK: - LA-2A Optical Compressor

/// Teletronix LA-2A optical compressor emulation
/// Smooth, program-dependent compression
/// Famous for vocals and bass
@MainActor
class LA2ACompressor {

    /// Peak reduction (main compression control)
    var peakReduction: Float = 50.0  // 0-100

    /// Output gain
    var gain: Float = 50.0  // 0-100

    /// Compress/Limit mode
    var limitMode: Bool = false

    private(set) var gainReduction: Float = 0.0

    private let sampleRate: Float
    private var opticalCell: Float = 0.0  // T4B opto-cell state

    init(sampleRate: Float = 48000) {
        self.sampleRate = sampleRate
    }

    func process(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)

        let reductionAmount = peakReduction / 100.0
        let outputGain = pow(10.0, (gain - 50.0) / 50.0 * 20.0 / 20.0)

        // LA-2A optical cell time constants
        // Attack: very fast for transients, then slow
        // Release: program-dependent (1-7 seconds typical)
        let fastAttack: Float = 0.0001  // Near-instant
        let slowAttack: Float = 0.01
        let release: Float = 0.06  // ~60ms per step, accumulates

        var maxGR: Float = 0.0

        for i in 0..<input.count {
            let level = abs(input[i])

            // T4B optical cell behavior
            // Fast attack for peaks, slow release, program-dependent
            if level > opticalCell {
                // Two-stage attack: instant then slow
                let attackSpeed = level > opticalCell * 1.5 ? fastAttack : slowAttack
                opticalCell = opticalCell * (1.0 - attackSpeed) + level * attackSpeed
            } else {
                // Program-dependent release (slower for louder signals)
                let releaseSpeed = release / (1.0 + opticalCell * 5.0)
                opticalCell = opticalCell * (1.0 - releaseSpeed) + level * releaseSpeed
            }

            // Compression curve (opto-cell is naturally soft)
            let threshold = 0.1 + (1.0 - reductionAmount) * 0.8
            var gr: Float = 0.0

            if opticalCell > threshold {
                let excess = opticalCell - threshold

                if limitMode {
                    // Limit mode: harder knee, higher ratio
                    gr = excess * 10.0  // ~10:1
                } else {
                    // Compress mode: soft knee, ~3:1
                    gr = excess * 3.0
                }
            }

            maxGR = min(maxGR, -gr * 20.0)

            let gainLinear = pow(10.0, -gr / 20.0) * outputGain
            output[i] = input[i] * gainLinear
        }

        gainReduction = maxGR
        return output
    }
}


// MARK: - UREI 1176 FET Limiter

/// UREI 1176LN FET limiter emulation
/// Fast, punchy, aggressive compression
/// Famous for drums, vocals, guitars
@MainActor
class UREI1176Limiter {

    var inputDrive: Float = 30.0  // 0-60 (input gain)
    var outputLevel: Float = 30.0  // 0-60 (output gain)
    var attack: Float = 4.0  // 1-7 (inverse: 1 = slow, 7 = fast)
    var release: Float = 4.0  // 1-7 (inverse: 1 = slow, 7 = fast)
    var ratio: Float = 4.0  // 4, 8, 12, 20, All (∞)

    private(set) var gainReduction: Float = 0.0

    private let sampleRate: Float
    private var envelope: Float = 0.0
    private var fetState: Float = 0.0

    // 1176 attack times (inverse knob - 7 is fastest!)
    private let attackTimes: [Float] = [0.8, 0.4, 0.2, 0.1, 0.05, 0.025, 0.02]
    // 1176 release times
    private let releaseTimes: [Float] = [1100, 800, 500, 300, 150, 80, 50]

    init(sampleRate: Float = 48000) {
        self.sampleRate = sampleRate
    }

    func process(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)

        let attackIdx = min(Int(attack) - 1, 6)
        let releaseIdx = min(Int(release) - 1, 6)

        let attackMs = attackTimes[attackIdx]
        let releaseMs = releaseTimes[releaseIdx]

        let attackCoeff = exp(-1.0 / (sampleRate * attackMs / 1000.0))
        let releaseCoeff = exp(-1.0 / (sampleRate * releaseMs / 1000.0))

        let inputGain = pow(10.0, inputDrive / 60.0 * 30.0 / 20.0)
        let outputGain = pow(10.0, (outputLevel - 30.0) / 60.0 * 30.0 / 20.0)

        // 1176 is all-button mode when ratio > 20 (famous "nuke" setting)
        let actualRatio = ratio > 20 ? 100.0 : ratio

        var maxGR: Float = 0.0

        for i in 0..<input.count {
            // Input stage with FET coloration
            var driven = input[i] * inputGain
            driven = fetColoration(driven)

            let level = abs(driven)

            // Fast FET envelope follower
            if level > envelope {
                envelope = attackCoeff * envelope + (1.0 - attackCoeff) * level
            } else {
                envelope = releaseCoeff * envelope + (1.0 - releaseCoeff) * level
            }

            // 1176 has a fixed threshold (around -10dBu internal)
            let threshold: Float = 0.3
            var gr: Float = 0.0

            if envelope > threshold {
                let envDB = 20.0 * log10(envelope / threshold)
                gr = envDB * (1.0 - 1.0/actualRatio)
            }

            // FET limiting characteristic (gets more aggressive with gain)
            gr = gr * (1.0 + inputDrive / 100.0)

            maxGR = min(maxGR, -gr)

            let gainLinear = pow(10.0, -gr / 20.0) * outputGain
            output[i] = driven * gainLinear / inputGain
        }

        gainReduction = maxGR
        return output
    }

    private func fetColoration(_ input: Float) -> Float {
        // FET transistor coloration (adds odd harmonics)
        // 1176 has distinctive "bite" from the FET input stage
        let x = input * 1.2

        if abs(x) < 0.7 {
            // Add subtle 3rd harmonic in linear region
            return x + x * x * x * 0.05
        } else {
            // FET limiting
            return x > 0 ?
                0.7 + (x - 0.7) * 0.3 :
                -0.7 + (x + 0.7) * 0.3
        }
    }
}


// MARK: - Manley Vari-Mu Compressor

/// Manley Vari-Mu tube compressor emulation
/// Smooth, musical mastering compression
/// Variable-mu (6386 tubes) design
@MainActor
class ManleyVariMu {

    var threshold: Float = -10.0  // dB
    var compression: Float = 50.0  // 0-100 (amount)
    var attack: Float = 25.0  // Fast (5ms) to Slow (70ms)
    var recovery: Float = 50.0  // Fast to Slow
    var outputGain: Float = 0.0  // dB

    /// HP sidechain filter (removes low-end pumping)
    var hpfEnabled: Bool = true
    var hpfFreq: Float = 100.0  // Hz

    /// Link mode for stereo
    var linked: Bool = true

    private(set) var gainReduction: Float = 0.0

    private let sampleRate: Float
    private var envelope: Float = 0.0
    private var hpfState: Float = 0.0

    init(sampleRate: Float = 48000) {
        self.sampleRate = sampleRate
    }

    func process(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)

        // Attack: 5ms to 70ms
        let attackMs = 5.0 + (attack / 100.0) * 65.0
        // Recovery: 200ms to 8 seconds
        let releaseMs = 200.0 + (recovery / 100.0) * 7800.0

        let attackCoeff = exp(-1.0 / (sampleRate * attackMs / 1000.0))
        let releaseCoeff = exp(-1.0 / (sampleRate * releaseMs / 1000.0))

        let thresholdLinear = pow(10.0, threshold / 20.0)
        let outputLinear = pow(10.0, outputGain / 20.0)
        let compressionAmount = compression / 100.0

        var maxGR: Float = 0.0

        for i in 0..<input.count {
            var detectSignal = input[i]

            // HP sidechain filter
            if hpfEnabled {
                let alpha = exp(-2.0 * Float.pi * hpfFreq / sampleRate)
                hpfState = alpha * hpfState + (1.0 - alpha) * input[i]
                detectSignal = input[i] - hpfState
            }

            let level = abs(detectSignal)

            // Tube envelope follower (slower, more musical)
            if level > envelope {
                envelope = attackCoeff * envelope + (1.0 - attackCoeff) * level
            } else {
                envelope = releaseCoeff * envelope + (1.0 - releaseCoeff) * level
            }

            // Variable-mu compression characteristic
            // Ratio increases with level (starts ~1.5:1, ends ~10:1)
            var gr: Float = 0.0

            if envelope > thresholdLinear {
                let excess = 20.0 * log10(envelope / thresholdLinear)

                // Variable ratio curve
                let dynamicRatio = 1.5 + excess * 0.3 * compressionAmount
                gr = excess * (1.0 - 1.0/dynamicRatio) * compressionAmount
            }

            // Tube smoothing
            gr = min(gr, 20.0)  // Max 20dB GR

            maxGR = min(maxGR, -gr)

            let gainLinear = pow(10.0, -gr / 20.0) * outputLinear
            output[i] = input[i] * gainLinear
        }

        gainReduction = maxGR
        return output
    }
}
