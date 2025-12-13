import Foundation
import Accelerate

/// Resonance Physics Engine
///
/// Models physical resonance phenomena based on oscillator physics.
/// Provides accurate frequency response, Q-factor analysis, and damping calculations.
///
/// Physics Foundation:
/// A driven damped harmonic oscillator follows:
///   m(d²x/dt²) + γ(dx/dt) + kx = F₀cos(ωt)
///
/// Where:
/// - m = mass
/// - γ = damping coefficient
/// - k = spring constant
/// - ω₀ = √(k/m) = natural frequency
/// - Q = m*ω₀/γ = quality factor
///
/// References:
/// - French, A.P. (1971) "Vibrations and Waves"
/// - Pain, H.J. (2005) "The Physics of Vibrations and Waves"
@MainActor
class ResonancePhysicsEngine: ObservableObject {

    // MARK: - Published State

    @Published var resonantFrequency: Float = 440.0
    @Published var qFactor: Float = 10.0
    @Published var dampingRatio: Float = 0.05

    // MARK: - Resonator Model

    /// Physical resonator state
    struct ResonatorState {
        var position: Float = 0
        var velocity: Float = 0
        var energy: Float = 0
    }

    private var state = ResonatorState()
    private let sampleRate: Float = 48000

    // MARK: - Q-Factor Physics

    /// Q-factor (Quality Factor) determines resonance sharpness
    /// Q = f₀ / Δf where Δf is the -3dB bandwidth
    /// Higher Q = sharper resonance, longer decay
    struct QFactorAnalysis {
        let qFactor: Float
        let bandwidth: Float        // Hz at -3dB
        let decayTime: Float        // Time to -60dB (seconds)
        let peakGain: Float         // dB at resonance
        let dampingRatio: Float     // ζ = 1/(2Q)

        var isUnderdamped: Bool { dampingRatio < 1.0 }
        var isCriticallyDamped: Bool { abs(dampingRatio - 1.0) < 0.01 }
        var isOverdamped: Bool { dampingRatio > 1.0 }

        var dampingDescription: String {
            if isUnderdamped { return "Underdamped (oscillatory decay)" }
            if isCriticallyDamped { return "Critically damped (fastest non-oscillatory)" }
            return "Overdamped (slow exponential decay)"
        }
    }

    /// Calculate Q-factor analysis for given parameters
    func analyzeQFactor(frequency: Float, q: Float) -> QFactorAnalysis {
        let bandwidth = frequency / q
        let dampingRatio = 1.0 / (2.0 * q)

        // Decay time to -60dB: τ = Q / (π * f₀) for underdamped
        // -60dB = 20*log10(e^(-t/τ)) → t = τ * ln(1000) ≈ 6.9τ
        let tau = q / (.pi * frequency)
        let decayTime = 6.9 * tau

        // Peak gain at resonance for driven oscillator
        // G(f₀) = Q for high-Q resonators
        let peakGain = 20.0 * log10(q)

        return QFactorAnalysis(
            qFactor: q,
            bandwidth: bandwidth,
            decayTime: decayTime,
            peakGain: peakGain,
            dampingRatio: dampingRatio
        )
    }

    // MARK: - Frequency Response

    /// Calculate magnitude response of resonator at given frequency
    /// H(ω) = 1 / √[(1 - (ω/ω₀)²)² + (ω/(Q*ω₀))²]
    func magnitudeResponse(atFrequency f: Float) -> Float {
        let f0 = resonantFrequency
        let ratio = f / f0
        let ratioSquared = ratio * ratio

        let denominator = sqrt(
            pow(1.0 - ratioSquared, 2) +
            pow(ratio / qFactor, 2)
        )

        return 1.0 / denominator
    }

    /// Calculate phase response in radians
    /// φ(ω) = -arctan((ω/ω₀) / (Q * (1 - (ω/ω₀)²)))
    func phaseResponse(atFrequency f: Float) -> Float {
        let f0 = resonantFrequency
        let ratio = f / f0
        let ratioSquared = ratio * ratio

        let numerator = ratio / qFactor
        let denominator = 1.0 - ratioSquared

        // Handle resonance point (denominator → 0)
        if abs(denominator) < 0.0001 {
            return ratio > 1 ? .pi : 0
        }

        return -atan(numerator / denominator)
    }

    /// Generate complete frequency response curve
    func frequencyResponseCurve(
        fromFrequency: Float = 20,
        toFrequency: Float = 20000,
        pointCount: Int = 512
    ) -> [(frequency: Float, magnitude: Float, phase: Float)] {
        var response: [(Float, Float, Float)] = []

        let logMin = log10(fromFrequency)
        let logMax = log10(toFrequency)

        for i in 0..<pointCount {
            let logF = logMin + (logMax - logMin) * Float(i) / Float(pointCount - 1)
            let f = pow(10, logF)

            let mag = magnitudeResponse(atFrequency: f)
            let magDB = 20.0 * log10(mag)
            let phase = phaseResponse(atFrequency: f)

            response.append((f, magDB, phase))
        }

        return response
    }

    // MARK: - Impulse Response

    /// Generate impulse response of the resonator
    /// For underdamped: h(t) = (ω₀/Q) * e^(-ω₀t/(2Q)) * sin(ω_d*t)
    /// where ω_d = ω₀ * √(1 - 1/(4Q²)) is the damped frequency
    func impulseResponse(durationSeconds: Float = 0.5) -> [Float] {
        let numSamples = Int(durationSeconds * sampleRate)
        var response = [Float](repeating: 0, count: numSamples)

        let omega0 = 2.0 * .pi * resonantFrequency
        let dampingCoeff = omega0 / (2.0 * qFactor)

        // Check if underdamped
        let discriminant = 1.0 - 1.0 / (4.0 * qFactor * qFactor)

        if discriminant > 0 {
            // Underdamped - oscillatory decay
            let omegaD = omega0 * sqrt(discriminant)

            for i in 0..<numSamples {
                let t = Float(i) / sampleRate
                let envelope = exp(-dampingCoeff * t)
                let oscillation = sin(omegaD * t)
                response[i] = (omega0 / qFactor) * envelope * oscillation
            }
        } else if discriminant < 0 {
            // Overdamped - exponential decay
            let sqrtTerm = sqrt(-discriminant)
            let lambda1 = dampingCoeff * (1.0 + sqrtTerm)
            let lambda2 = dampingCoeff * (1.0 - sqrtTerm)

            for i in 0..<numSamples {
                let t = Float(i) / sampleRate
                response[i] = (exp(-lambda1 * t) - exp(-lambda2 * t)) / (2.0 * sqrtTerm)
            }
        } else {
            // Critically damped
            for i in 0..<numSamples {
                let t = Float(i) / sampleRate
                response[i] = omega0 * omega0 * t * exp(-dampingCoeff * t)
            }
        }

        // Normalize
        let maxVal = response.max() ?? 1.0
        if maxVal > 0 {
            for i in 0..<numSamples {
                response[i] /= maxVal
            }
        }

        return response
    }

    // MARK: - Resonator Simulation

    /// Process audio through the resonator filter
    /// Uses trapezoidal integration (bilinear transform) for stability
    func processAudio(_ input: [Float]) -> [Float] {
        var output = [Float](repeating: 0, count: input.count)

        let omega0 = 2.0 * .pi * resonantFrequency
        let alpha = omega0 / (2.0 * qFactor)

        // Bilinear transform coefficients
        let K = tan(.pi * resonantFrequency / sampleRate)
        let K2 = K * K
        let norm = 1.0 / (1.0 + K / qFactor + K2)

        let a0: Float = K2 * norm
        let a1: Float = 2.0 * a0
        let a2: Float = a0
        let b1: Float = 2.0 * (K2 - 1.0) * norm
        let b2: Float = (1.0 - K / qFactor + K2) * norm

        // Filter state
        var x1: Float = 0, x2: Float = 0
        var y1: Float = 0, y2: Float = 0

        for i in 0..<input.count {
            let x0 = input[i]
            let y0 = a0 * x0 + a1 * x1 + a2 * x2 - b1 * y1 - b2 * y2

            output[i] = y0

            x2 = x1; x1 = x0
            y2 = y1; y1 = y0
        }

        return output
    }

    // MARK: - Sympathetic Resonance

    /// Calculate sympathetic resonance amplitude between two frequencies
    /// Based on frequency ratio and Q-factor overlap
    func sympatheticResonanceStrength(
        sourceFrequency: Float,
        targetResonantFrequency: Float,
        targetQ: Float
    ) -> Float {
        // Use the magnitude response of target at source frequency
        let originalF0 = resonantFrequency
        let originalQ = qFactor

        resonantFrequency = targetResonantFrequency
        qFactor = targetQ

        let response = magnitudeResponse(atFrequency: sourceFrequency)

        // Restore original values
        resonantFrequency = originalF0
        qFactor = originalQ

        return response
    }

    /// Find harmonic relationships that would excite sympathetic resonance
    func findSympatheticHarmonics(
        forFundamental f0: Float,
        withResonator resonatorF0: Float,
        resonatorQ: Float,
        harmonicCount: Int = 16
    ) -> [(harmonic: Int, strength: Float)] {
        var results: [(Int, Float)] = []

        for n in 1...harmonicCount {
            let harmonicFreq = f0 * Float(n)
            let strength = sympatheticResonanceStrength(
                sourceFrequency: harmonicFreq,
                targetResonantFrequency: resonatorF0,
                targetQ: resonatorQ
            )

            // Only include significant resonance (> -20dB)
            if strength > 0.1 {
                results.append((n, strength))
            }
        }

        return results.sorted { $0.1 > $1.1 }
    }

    // MARK: - Mode Analysis

    /// Analyze coupled resonator modes (e.g., string + body)
    struct CoupledModeAnalysis {
        let modes: [(frequency: Float, qFactor: Float, amplitude: Float)]
        let couplingStrength: Float
        let beatFrequency: Float?
    }

    func analyzeCoupledModes(
        mode1Frequency: Float, mode1Q: Float,
        mode2Frequency: Float, mode2Q: Float,
        couplingCoefficient: Float
    ) -> CoupledModeAnalysis {
        // For weak coupling, modes split by: Δf ≈ κ * √(f₁*f₂)
        let splitting = couplingCoefficient * sqrt(mode1Frequency * mode2Frequency)

        // New coupled frequencies
        let avgFreq = (mode1Frequency + mode2Frequency) / 2.0
        let newF1 = avgFreq - splitting / 2.0
        let newF2 = avgFreq + splitting / 2.0

        // Effective Q decreases with coupling
        let avgQ = (mode1Q + mode2Q) / 2.0
        let coupledQ = avgQ / (1.0 + couplingCoefficient)

        // Beat frequency if modes are close
        var beatFreq: Float? = nil
        if abs(mode1Frequency - mode2Frequency) < 50 {
            beatFreq = abs(newF1 - newF2)
        }

        return CoupledModeAnalysis(
            modes: [
                (newF1, coupledQ, 1.0 - couplingCoefficient / 2),
                (newF2, coupledQ, 1.0 - couplingCoefficient / 2)
            ],
            couplingStrength: couplingCoefficient,
            beatFrequency: beatFreq
        )
    }
}

// MARK: - Material Properties Database

extension ResonancePhysicsEngine {

    /// Physical properties of common resonating materials
    struct MaterialProperties {
        let name: String
        let density: Float           // kg/m³
        let youngsModulus: Float     // Pa (N/m²)
        let speedOfSound: Float      // m/s
        let dampingFactor: Float     // internal friction coefficient

        /// Calculate typical Q-factor for this material
        var typicalQ: Float {
            // Q ≈ 1 / (2 * dampingFactor) for internal damping
            return 1.0 / (2.0 * dampingFactor)
        }
    }

    static let materials: [String: MaterialProperties] = [
        "steel": MaterialProperties(
            name: "Steel",
            density: 7850,
            youngsModulus: 200e9,
            speedOfSound: 5000,
            dampingFactor: 0.0005
        ),
        "aluminum": MaterialProperties(
            name: "Aluminum",
            density: 2700,
            youngsModulus: 70e9,
            speedOfSound: 5100,
            dampingFactor: 0.001
        ),
        "brass": MaterialProperties(
            name: "Brass",
            density: 8500,
            youngsModulus: 100e9,
            speedOfSound: 3500,
            dampingFactor: 0.002
        ),
        "wood_spruce": MaterialProperties(
            name: "Spruce (tonewood)",
            density: 400,
            youngsModulus: 10e9,
            speedOfSound: 5000,
            dampingFactor: 0.01
        ),
        "glass": MaterialProperties(
            name: "Glass",
            density: 2500,
            youngsModulus: 70e9,
            speedOfSound: 5500,
            dampingFactor: 0.0002
        ),
        "nylon": MaterialProperties(
            name: "Nylon (string)",
            density: 1150,
            youngsModulus: 3e9,
            speedOfSound: 1600,
            dampingFactor: 0.03
        )
    ]

    /// Calculate resonant frequency of a string
    /// f = (1/2L) * √(T/μ) where T = tension, μ = linear density
    static func stringResonance(
        length: Float,       // meters
        tension: Float,      // Newtons
        linearDensity: Float // kg/m
    ) -> Float {
        return (1.0 / (2.0 * length)) * sqrt(tension / linearDensity)
    }

    /// Calculate resonant frequency of a tube (open-open)
    /// f_n = n * c / (2L)
    static func openTubeResonance(
        length: Float,       // meters
        harmonic: Int = 1,   // 1 = fundamental
        speedOfSound: Float = 343 // m/s at 20°C
    ) -> Float {
        return Float(harmonic) * speedOfSound / (2.0 * length)
    }

    /// Calculate resonant frequency of a tube (closed-open)
    /// f_n = (2n-1) * c / (4L) - only odd harmonics
    static func closedTubeResonance(
        length: Float,
        harmonic: Int = 1,   // 1, 2, 3... → f₁, f₃, f₅...
        speedOfSound: Float = 343
    ) -> Float {
        let n = 2 * harmonic - 1  // 1, 3, 5...
        return Float(n) * speedOfSound / (4.0 * length)
    }
}
