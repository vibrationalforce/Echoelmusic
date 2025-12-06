import Foundation
import Accelerate
import simd

// MARK: - Hydro-Acoustic Resonator
// Water-based cymatics simulation and acoustic processing
// Reference: Jenny, H. (1967). Cymatics: A Study of Wave Phenomena

/// HydroAcousticResonator: Simulates water-based cymatic patterns
/// Based on fluid dynamics equations and acoustic wave propagation in water
///
/// Scientific Basis:
/// - Speed of sound in water: 1,481 m/s (vs 343 m/s in air)
/// - Water has higher acoustic impedance than air
/// - Cymatic patterns follow Bessel functions of the first kind
/// - Standing wave nodes create visible geometric patterns
final class HydroAcousticResonator {

    // MARK: - Physical Constants

    /// Speed of sound in water at 20°C (m/s)
    static let soundSpeedWater: Double = 1481.0

    /// Speed of sound in air at 20°C (m/s)
    static let soundSpeedAir: Double = 343.0

    /// Water density (kg/m³)
    static let waterDensity: Double = 998.0

    /// Air density (kg/m³)
    static let airDensity: Double = 1.204

    /// Acoustic impedance of water (Pa·s/m)
    static let waterImpedance: Double = 1.48e6

    /// Surface tension of water (N/m)
    static let waterSurfaceTension: Double = 0.0728

    // MARK: - State

    /// Current resonance mode (circular plate modes)
    private(set) var resonanceMode: (m: Int, n: Int) = (0, 1)

    /// Simulated water surface displacement field
    private var surfaceField: [[Double]] = []

    /// Field resolution
    private let fieldSize = 64

    /// Phase accumulator for wave generation
    private var phase: Double = 0

    /// Damping coefficient (energy loss)
    private var damping: Double = 0.02

    /// Current driving frequency
    private(set) var drivingFrequency: Double = 100.0

    // MARK: - Bessel Function Zeros

    /// Zeros of Bessel functions J_m(x) for circular plate vibration modes
    /// These determine the resonant frequencies of circular membranes
    private static let besselZeros: [[Double]] = [
        // m=0: [j_0,1, j_0,2, j_0,3, j_0,4, j_0,5]
        [2.4048, 5.5201, 8.6537, 11.7915, 14.9309],
        // m=1
        [3.8317, 7.0156, 10.1735, 13.3237, 16.4706],
        // m=2
        [5.1356, 8.4172, 11.6198, 14.7960, 17.9598],
        // m=3
        [6.3802, 9.7610, 13.0152, 16.2235, 19.4094],
        // m=4
        [7.5883, 11.0647, 14.3725, 17.6160, 20.8269]
    ]

    // MARK: - Initialization

    init() {
        initializeSurfaceField()
    }

    private func initializeSurfaceField() {
        surfaceField = Array(
            repeating: Array(repeating: 0.0, count: fieldSize),
            count: fieldSize
        )
    }

    // MARK: - Mode Calculation

    /// Calculate resonant frequency for circular plate mode (m, n)
    /// Based on: f_mn = (λ_mn / 2πa) * sqrt(D / ρh)
    /// Where λ_mn is the Bessel function zero
    func resonantFrequency(m: Int, n: Int, plateRadius: Double = 0.1, plateThickness: Double = 0.001) -> Double {
        guard m < Self.besselZeros.count, n > 0, n <= Self.besselZeros[m].count else {
            return 100.0  // Default
        }

        let lambda = Self.besselZeros[m][n - 1]

        // Plate flexural rigidity (simplified for water surface)
        // D = E * h³ / (12 * (1 - ν²))
        // Using effective values for water surface with surface tension
        let effectiveRigidity = Self.waterSurfaceTension * plateThickness

        // Frequency formula
        let frequency = (lambda / (2 * .pi * plateRadius)) *
                       sqrt(effectiveRigidity / (Self.waterDensity * plateThickness))

        return frequency
    }

    /// Get all resonant modes within a frequency range
    func resonantModes(minFreq: Double = 20, maxFreq: Double = 500) -> [(m: Int, n: Int, frequency: Double)] {
        var modes: [(m: Int, n: Int, frequency: Double)] = []

        for m in 0..<Self.besselZeros.count {
            for n in 1...Self.besselZeros[m].count {
                let freq = resonantFrequency(m: m, n: n)
                if freq >= minFreq && freq <= maxFreq {
                    modes.append((m, n, freq))
                }
            }
        }

        return modes.sorted { $0.frequency < $1.frequency }
    }

    // MARK: - Audio Processing

    /// Process audio buffer with hydro-acoustic resonance
    func process(
        buffer: UnsafeMutablePointer<Float>,
        frameCount: Int,
        sampleRate: Double
    ) {
        // Apply water-based acoustic transformation
        for i in 0..<frameCount {
            var sample = Double(buffer[i])

            // 1. Apply acoustic impedance matching (air to water transition)
            sample = applyImpedanceMatching(sample)

            // 2. Apply frequency-dependent absorption (water absorbs high frequencies)
            sample = applyWaterAbsorption(sample, frequency: drivingFrequency)

            // 3. Add cymatic resonance enhancement
            let resonanceBoost = calculateResonanceBoost(phase: phase, mode: resonanceMode)
            sample *= (1.0 + resonanceBoost * 0.2)

            // 4. Apply surface tension ripple effect
            let ripple = calculateSurfaceRipple(phase: phase)
            sample += ripple * 0.05

            // Update phase
            phase += drivingFrequency / sampleRate * 2 * .pi
            if phase > 2 * .pi { phase -= 2 * .pi }

            buffer[i] = Float(sample)
        }

        // Update surface field for visualization
        updateSurfaceField()
    }

    // MARK: - Acoustic Transformations

    /// Apply impedance matching between air and water
    /// Transmission coefficient: T = 4 * Z1 * Z2 / (Z1 + Z2)²
    private func applyImpedanceMatching(_ sample: Double) -> Double {
        let airImpedance = Self.soundSpeedAir * Self.airDensity
        let transmission = 4 * airImpedance * Self.waterImpedance /
                          pow(airImpedance + Self.waterImpedance, 2)

        // Very little energy transmits from air to water (about 0.1%)
        // We simulate the effect but keep signal audible
        let effectiveTransmission = 0.3 + transmission * 10  // Scaled for audibility

        return sample * effectiveTransmission
    }

    /// Apply frequency-dependent water absorption
    /// Water absorbs high frequencies more than low frequencies
    /// α = 2.5 × 10⁻¹¹ × f² (dB/m) approximately
    private func applyWaterAbsorption(_ sample: Double, frequency: Double) -> Double {
        // Simplified absorption model
        let absorptionCoeff = 2.5e-11 * frequency * frequency
        let pathLength = 0.1  // Simulated 10cm water path

        let attenuation = exp(-absorptionCoeff * pathLength * 100)  // Scaled

        // Low-pass filtering effect of water
        let lpfFactor = 1.0 / (1.0 + frequency / 2000.0)

        return sample * attenuation * lpfFactor
    }

    /// Calculate resonance boost for current mode
    private func calculateResonanceBoost(phase: Double, mode: (m: Int, n: Int)) -> Double {
        // Bessel function approximation for mode shape
        let angularTerm = cos(Double(mode.m) * phase)
        let radialTerm = sin(phase * Double(mode.n))

        return angularTerm * radialTerm
    }

    /// Calculate surface tension ripple effect
    private func calculateSurfaceRipple(phase: Double) -> Double {
        // Capillary wave dispersion: ω² = g*k + (σ/ρ)*k³
        // Creates characteristic water ripple sound

        var ripple = 0.0

        // Multiple ripple harmonics
        for harmonic in 1...5 {
            let k = Double(harmonic) * 2 * .pi / 0.1  // Wavenumber
            let capillaryTerm = (Self.waterSurfaceTension / Self.waterDensity) * pow(k, 3)
            let gravityTerm = 9.81 * k

            let omega = sqrt(gravityTerm + capillaryTerm)
            ripple += sin(phase * omega / 1000) / Double(harmonic)
        }

        return ripple * 0.1
    }

    // MARK: - Surface Field Simulation

    /// Update the 2D surface displacement field
    private func updateSurfaceField() {
        let center = fieldSize / 2

        for i in 0..<fieldSize {
            for j in 0..<fieldSize {
                // Polar coordinates from center
                let x = Double(i - center) / Double(center)
                let y = Double(j - center) / Double(center)
                let r = sqrt(x * x + y * y)
                let theta = atan2(y, x)

                guard r <= 1.0 else {
                    surfaceField[i][j] = 0
                    continue
                }

                // Circular plate mode shape: J_m(λ_mn * r) * cos(m * θ)
                let lambda = Self.besselZeros[resonanceMode.m][min(resonanceMode.n - 1, 4)]
                let radialPart = besselJ(order: resonanceMode.m, x: lambda * r)
                let angularPart = cos(Double(resonanceMode.m) * theta)
                let timePart = sin(phase)

                // Apply damping at edges
                let edgeDamping = 1.0 - pow(r, 4)

                surfaceField[i][j] = radialPart * angularPart * timePart * edgeDamping
            }
        }
    }

    /// Bessel function of the first kind (approximation)
    private func besselJ(order m: Int, x: Double) -> Double {
        guard x != 0 else { return m == 0 ? 1.0 : 0.0 }

        // Power series approximation
        var sum = 0.0
        let halfX = x / 2.0

        for k in 0..<20 {
            let numerator = pow(-1, Double(k)) * pow(halfX, Double(2 * k + m))
            let denominator = Double(factorial(k) * factorial(k + m))
            sum += numerator / denominator
        }

        return sum
    }

    private func factorial(_ n: Int) -> Int {
        guard n > 1 else { return 1 }
        return (2...n).reduce(1, *)
    }

    // MARK: - Control Methods

    /// Set the driving frequency
    func setDrivingFrequency(_ frequency: Double) {
        drivingFrequency = frequency

        // Find nearest resonant mode
        let modes = resonantModes(minFreq: frequency * 0.8, maxFreq: frequency * 1.2)
        if let nearestMode = modes.min(by: { abs($0.frequency - frequency) < abs($1.frequency - frequency) }) {
            resonanceMode = (nearestMode.m, nearestMode.n)
        }
    }

    /// Set specific resonance mode
    func setMode(m: Int, n: Int) {
        guard m < Self.besselZeros.count, n > 0, n <= Self.besselZeros[m].count else { return }
        resonanceMode = (m, n)
        drivingFrequency = resonantFrequency(m: m, n: n)
    }

    /// Get current surface field for visualization
    func getSurfaceField() -> [[Double]] {
        return surfaceField
    }

    /// Get normalized surface field as flat array for GPU upload
    func getSurfaceFieldFlat() -> [Float] {
        return surfaceField.flatMap { row in
            row.map { Float($0) }
        }
    }

    // MARK: - Cymatic Pattern Names

    /// Get descriptive name for current mode
    var modeName: String {
        let m = resonanceMode.m
        let n = resonanceMode.n

        // Historical cymatic pattern names
        switch (m, n) {
        case (0, 1): return "Fundamental Circle"
        case (0, 2): return "Concentric Rings"
        case (0, 3): return "Triple Ring"
        case (1, 1): return "Single Nodal Diameter"
        case (1, 2): return "Star Pattern"
        case (2, 1): return "Cross Pattern"
        case (2, 2): return "Four-Point Star"
        case (3, 1): return "Triangle"
        case (3, 2): return "Hexagon"
        case (4, 1): return "Square"
        case (4, 2): return "Octagon"
        default: return "Mode (\(m),\(n))"
        }
    }

    /// Get description of current pattern
    var modeDescription: String {
        """
        Cymatic Pattern: \(modeName)
        Mode: m=\(resonanceMode.m), n=\(resonanceMode.n)
        Resonant Frequency: \(String(format: "%.2f", resonantFrequency(m: resonanceMode.m, n: resonanceMode.n))) Hz
        Driving Frequency: \(String(format: "%.2f", drivingFrequency)) Hz

        This pattern has \(resonanceMode.m) nodal diameters and \(resonanceMode.n) nodal circles.
        """
    }
}


// MARK: - Cymatic Frequency Presets

extension HydroAcousticResonator {

    /// Preset frequencies known to create beautiful cymatic patterns
    static let cymaticPresets: [(name: String, frequency: Double, mode: (m: Int, n: Int))] = [
        ("Water Crystal Base", 24.0, (0, 1)),
        ("Snowflake Pattern", 78.0, (6, 1)),
        ("Flower of Life", 111.0, (5, 2)),
        ("Star of David", 174.0, (6, 2)),
        ("DNA Helix", 528.0, (8, 3)),
        ("Mandala", 396.0, (7, 2)),
        ("Om Vibration", 136.1, (4, 2)),
        ("Heart Resonance", 432.0, (5, 3))
    ]
}


// MARK: - Water Memory Simulation (Masaru Emoto-inspired)

extension HydroAcousticResonator {

    /// Note: This is for artistic/experiential purposes only.
    /// The "water memory" concept lacks scientific validation.
    /// Reference: Emoto, M. (2004). The Hidden Messages in Water
    /// Critical analysis: Radin et al. (2006) - double-blind study

    enum WaterIntention: String, CaseIterable {
        case love = "Love & Gratitude"
        case peace = "Peace"
        case harmony = "Harmony"
        case healing = "Healing"
        case joy = "Joy"
        case truth = "Truth"

        /// Suggested frequency association (artistic interpretation)
        var suggestedFrequency: Double {
            switch self {
            case .love: return 528.0       // "Love frequency"
            case .peace: return 432.0      // Verdi A
            case .harmony: return 639.0    // Solfeggio connection
            case .healing: return 174.0    // Foundation
            case .joy: return 741.0        // Expression
            case .truth: return 852.0      // Intuition
            }
        }

        /// Associated geometric pattern
        var pattern: (m: Int, n: Int) {
            switch self {
            case .love: return (6, 2)      // Hexagonal (flower)
            case .peace: return (4, 2)     // Square (stability)
            case .harmony: return (5, 2)   // Pentagon (phi ratio)
            case .healing: return (3, 2)   // Triangle (trinity)
            case .joy: return (7, 2)       // Heptagon (rainbow)
            case .truth: return (8, 2)     // Octagon (completeness)
            }
        }
    }

    /// Apply intention-based pattern (for experiential/artistic use)
    func applyIntention(_ intention: WaterIntention) {
        let pattern = intention.pattern
        setMode(m: pattern.m, n: pattern.n)
        setDrivingFrequency(intention.suggestedFrequency)

        print("🌊 Water Intention: \(intention.rawValue)")
        print("   Frequency: \(intention.suggestedFrequency) Hz")
        print("   Pattern: \(modeName)")
        print("   ⚠️ Note: This is artistic/experiential, not scientifically validated")
    }
}
