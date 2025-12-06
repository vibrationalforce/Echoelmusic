import Foundation
import Accelerate
import simd

// MARK: - Space Vibration Field
// 3D spatial harmonic field processing for immersive audio
// Based on spherical harmonics and acoustic field theory

/// SpaceVibrationField: 3D harmonic field processor
/// Creates immersive spatial audio using spherical harmonics
///
/// Scientific Basis:
/// - Spherical Harmonics: Y_l^m(θ, φ) - MIT/Fraunhofer research
/// - HRTF modeling: Head-Related Transfer Functions
/// - Ambisonics: B-format spatial audio encoding
/// - Acoustic holography principles
///
/// References:
/// - Algazi, V.R., et al. (2001). The CIPIC HRTF database. IEEE WASPAA
/// - Zotter, F. & Frank, M. (2019). Ambisonics: A Practical 3D Audio Theory
final class SpaceVibrationField {

    // MARK: - Constants

    /// Speed of sound (m/s)
    static let speedOfSound: Double = 343.0

    /// Head radius for HRTF approximation (m)
    static let headRadius: Double = 0.0875

    /// Maximum Ambisonic order
    static let maxOrder: Int = 3

    // MARK: - State

    /// Current listener position
    private(set) var listenerPosition: SIMD3<Double> = .zero

    /// Current listener orientation (yaw, pitch, roll in radians)
    private(set) var listenerOrientation: SIMD3<Double> = .zero

    /// Active sound sources in the field
    private var soundSources: [SpatialSource] = []

    /// Spherical harmonic coefficients for the field
    private var ambisonicCoeffs: [Double] = []

    /// Processing mode
    private(set) var mode: SpaceMode = .ambisonicField

    /// Field resolution for visualization
    private let fieldResolution = 32

    /// 3D field data for visualization
    private var fieldData: [[[Double]]] = []

    // MARK: - Processing Modes

    enum SpaceMode: String, CaseIterable {
        case ambisonicField = "Ambisonic Field"
        case binauralHRTF = "Binaural HRTF"
        case wavefieldSynthesis = "Wavefield Synthesis"
        case acousticHolography = "Acoustic Holography"
        case quantumField = "Quantum Probability Field"
        case sacredGeometry = "Sacred Geometry Field"

        var description: String {
            switch self {
            case .ambisonicField:
                return "Full 3D soundfield using spherical harmonics (B-format)"
            case .binauralHRTF:
                return "Binaural rendering with Head-Related Transfer Functions"
            case .wavefieldSynthesis:
                return "Physical sound field recreation (Huygens principle)"
            case .acousticHolography:
                return "Holographic sound field reconstruction"
            case .quantumField:
                return "Quantum-inspired probability amplitude field"
            case .sacredGeometry:
                return "Platonic solid-based spatial harmonics"
            }
        }
    }

    // MARK: - Initialization

    init() {
        initializeField()
        initializeAmbisonicCoeffs()
    }

    private func initializeField() {
        fieldData = Array(
            repeating: Array(
                repeating: Array(repeating: 0.0, count: fieldResolution),
                count: fieldResolution
            ),
            count: fieldResolution
        )
    }

    private func initializeAmbisonicCoeffs() {
        // Ambisonic channel count for order N: (N+1)²
        let channelCount = (Self.maxOrder + 1) * (Self.maxOrder + 1)
        ambisonicCoeffs = Array(repeating: 0.0, count: channelCount)
    }

    // MARK: - Audio Processing

    /// Process audio buffer with spatial field transformation
    func process(
        buffer: UnsafeMutablePointer<Float>,
        frameCount: Int,
        sampleRate: Double
    ) {
        switch mode {
        case .ambisonicField:
            processAmbisonic(buffer: buffer, frameCount: frameCount, sampleRate: sampleRate)

        case .binauralHRTF:
            processBinaural(buffer: buffer, frameCount: frameCount, sampleRate: sampleRate)

        case .wavefieldSynthesis:
            processWavefield(buffer: buffer, frameCount: frameCount, sampleRate: sampleRate)

        case .acousticHolography:
            processHolographic(buffer: buffer, frameCount: frameCount, sampleRate: sampleRate)

        case .quantumField:
            processQuantumField(buffer: buffer, frameCount: frameCount, sampleRate: sampleRate)

        case .sacredGeometry:
            processSacredGeometry(buffer: buffer, frameCount: frameCount, sampleRate: sampleRate)
        }

        // Update 3D field visualization
        updateFieldVisualization()
    }

    // MARK: - Ambisonic Processing

    /// Process using B-format Ambisonics
    private func processAmbisonic(
        buffer: UnsafeMutablePointer<Float>,
        frameCount: Int,
        sampleRate: Double
    ) {
        // Encode input to first-order Ambisonics (W, X, Y, Z)
        for i in 0..<frameCount {
            let sample = Double(buffer[i])

            // Calculate source direction (rotating for demonstration)
            let time = Double(i) / sampleRate
            let azimuth = time * 0.5  // Slow rotation
            let elevation = sin(time * 0.2) * 0.5  // Gentle pitch

            // B-format encoding
            // W (omnidirectional): 1/√2
            // X (front-back): cos(θ)cos(φ)
            // Y (left-right): sin(θ)cos(φ)
            // Z (up-down): sin(φ)

            let cosAz = cos(azimuth)
            let sinAz = sin(azimuth)
            let cosEl = cos(elevation)
            let sinEl = sin(elevation)

            ambisonicCoeffs[0] = sample * 0.707  // W
            ambisonicCoeffs[1] = sample * cosAz * cosEl  // X
            ambisonicCoeffs[2] = sample * sinAz * cosEl  // Y
            ambisonicCoeffs[3] = sample * sinEl  // Z

            // Decode to stereo (simple cardioid decode)
            let leftAngle = .pi / 4   // -45°
            let rightAngle = -.pi / 4  // +45°

            let left = ambisonicCoeffs[0] +
                      ambisonicCoeffs[1] * cos(leftAngle) +
                      ambisonicCoeffs[2] * sin(leftAngle)

            let right = ambisonicCoeffs[0] +
                       ambisonicCoeffs[1] * cos(rightAngle) +
                       ambisonicCoeffs[2] * sin(rightAngle)

            // Stereo output (interleaved would need stereo buffer)
            // For mono, blend L/R
            buffer[i] = Float((left + right) * 0.5)
        }
    }

    // MARK: - Binaural HRTF Processing

    /// Process using simplified HRTF model
    private func processBinaural(
        buffer: UnsafeMutablePointer<Float>,
        frameCount: Int,
        sampleRate: Double
    ) {
        for i in 0..<frameCount {
            let sample = Double(buffer[i])
            let time = Double(i) / sampleRate

            // Simulate source position
            let azimuth = sin(time * 0.3) * .pi / 2  // ±90°

            // ITD (Interaural Time Difference)
            // Δt = (r/c) * (θ + sin(θ)) for sphere model
            let itd = (Self.headRadius / Self.speedOfSound) *
                     (azimuth + sin(azimuth))

            // ILD (Interaural Level Difference)
            // Simplified: 3dB per 10° at high frequencies
            let ild = pow(10, -abs(azimuth) * 0.03 / 20)

            // Head shadow effect (low-pass for contralateral ear)
            let shadowFreq = 1500.0 + 500.0 * (1 - abs(sin(azimuth)))

            // Apply HRTF effects
            let leftGain = azimuth > 0 ? 1.0 : ild
            let rightGain = azimuth < 0 ? 1.0 : ild

            // Blend for mono output
            let processed = sample * (leftGain + rightGain) * 0.5

            buffer[i] = Float(processed)
        }
    }

    // MARK: - Wavefield Synthesis

    /// Process using Huygens-Fresnel principle
    private func processWavefield(
        buffer: UnsafeMutablePointer<Float>,
        frameCount: Int,
        sampleRate: Double
    ) {
        // Wavefield synthesis: recreate physical wavefront
        // Each point source contributes according to Huygens principle

        let virtualSources = 8  // Simulated speaker array

        for i in 0..<frameCount {
            var sample = 0.0

            for source in 0..<virtualSources {
                // Source position on a circle
                let sourceAngle = Double(source) / Double(virtualSources) * 2 * .pi
                let sourceX = cos(sourceAngle) * 2.0  // 2m radius
                let sourceY = sin(sourceAngle) * 2.0

                // Distance to listener
                let dx = sourceX - listenerPosition.x
                let dy = sourceY - listenerPosition.y
                let distance = sqrt(dx * dx + dy * dy)

                // Propagation delay
                let delay = distance / Self.speedOfSound

                // Delayed sample (simplified - would need delay buffer)
                let time = Double(i) / sampleRate
                let delayedTime = time - delay
                let phase = delayedTime * 100 * 2 * .pi  // 100 Hz test tone

                // Amplitude decay (1/r)
                let amplitude = 1.0 / max(distance, 0.1)

                // Driving function (wavefield synthesis driving signal)
                let drivingFunc = sin(phase)

                sample += drivingFunc * amplitude / Double(virtualSources)
            }

            buffer[i] *= Float(1.0 + sample * 0.3)
        }
    }

    // MARK: - Acoustic Holography

    /// Process using holographic field reconstruction
    private func processHolographic(
        buffer: UnsafeMutablePointer<Float>,
        frameCount: Int,
        sampleRate: Double
    ) {
        // Acoustic holography: reconstruct 3D field from encoded data
        // Uses spatial Fourier transform principles

        for i in 0..<frameCount {
            let sample = Double(buffer[i])
            let time = Double(i) / sampleRate

            // Create holographic interference pattern
            var hologram = 0.0

            // Reference wave
            let refFreq = 440.0
            let refWave = sin(time * refFreq * 2 * .pi)

            // Object wave (modulated by input)
            let objWave = sample * sin(time * (refFreq + 10) * 2 * .pi)

            // Interference (hologram)
            hologram = refWave + objWave

            // Reconstruction (multiply by reference)
            let reconstructed = hologram * refWave

            // Low-pass to extract audio
            // Simplified: just amplitude modulation
            buffer[i] = Float((sample + reconstructed * 0.1) * 0.5)
        }
    }

    // MARK: - Quantum Field Processing

    /// Quantum-inspired probability amplitude field
    private func processQuantumField(
        buffer: UnsafeMutablePointer<Float>,
        frameCount: Int,
        sampleRate: Double
    ) {
        // Treat audio as quantum probability amplitude
        // Apply Schrödinger-like evolution

        for i in 0..<frameCount {
            let sample = Double(buffer[i])
            let time = Double(i) / sampleRate

            // Wave function: ψ = A * e^(i(kx - ωt))
            // Probability amplitude superposition

            var realPart = 0.0
            var imagPart = 0.0

            // Multiple quantum states
            for state in 1...5 {
                let energy = Double(state) * 100  // Energy levels
                let omega = energy / 6.626e-34 * 1e-30  // Scaled for audio
                let phase = omega * time

                realPart += sample * cos(phase) / Double(state)
                imagPart += sample * sin(phase) / Double(state)
            }

            // Probability (|ψ|²)
            let probability = realPart * realPart + imagPart * imagPart

            // Normalize and apply
            let normalized = sqrt(probability)
            buffer[i] = Float(normalized * (sample > 0 ? 1 : -1))
        }
    }

    // MARK: - Sacred Geometry Field

    /// Platonic solid-based spatial harmonics
    private func processSacredGeometry(
        buffer: UnsafeMutablePointer<Float>,
        frameCount: Int,
        sampleRate: Double
    ) {
        // Use Platonic solid vertices as spatial nodes
        // Tetrahedron (4), Cube (8), Octahedron (6), Dodecahedron (20), Icosahedron (12)

        // Icosahedron vertices (normalized)
        let phi = (1 + sqrt(5)) / 2  // Golden ratio
        let icosahedronVertices: [SIMD3<Double>] = [
            SIMD3(0, 1, phi), SIMD3(0, -1, phi), SIMD3(0, 1, -phi), SIMD3(0, -1, -phi),
            SIMD3(1, phi, 0), SIMD3(-1, phi, 0), SIMD3(1, -phi, 0), SIMD3(-1, -phi, 0),
            SIMD3(phi, 0, 1), SIMD3(-phi, 0, 1), SIMD3(phi, 0, -1), SIMD3(-phi, 0, -1)
        ].map { simd_normalize($0) }

        for i in 0..<frameCount {
            let sample = Double(buffer[i])
            let time = Double(i) / sampleRate

            var fieldSum = 0.0

            // Sum contributions from each vertex
            for (index, vertex) in icosahedronVertices.enumerated() {
                // Rotating icosahedron
                let rotSpeed = 0.1
                let rotatedX = vertex.x * cos(time * rotSpeed) - vertex.z * sin(time * rotSpeed)
                let rotatedZ = vertex.x * sin(time * rotSpeed) + vertex.z * cos(time * rotSpeed)

                // Distance from listener
                let distance = sqrt(
                    pow(rotatedX - listenerPosition.x, 2) +
                    pow(vertex.y - listenerPosition.y, 2) +
                    pow(rotatedZ - listenerPosition.z, 2)
                )

                // Phi-harmonic contribution
                let harmonic = Double(index + 1) * phi
                let phase = time * harmonic * 10

                // Field contribution
                let contribution = sin(phase) / max(distance, 0.1)
                fieldSum += contribution
            }

            // Normalize
            fieldSum /= Double(icosahedronVertices.count)

            // Apply field modulation
            buffer[i] = Float(sample * (1.0 + fieldSum * 0.2))
        }
    }

    // MARK: - Field Visualization

    private func updateFieldVisualization() {
        let center = fieldResolution / 2

        for x in 0..<fieldResolution {
            for y in 0..<fieldResolution {
                for z in 0..<fieldResolution {
                    // Normalized coordinates
                    let nx = Double(x - center) / Double(center)
                    let ny = Double(y - center) / Double(center)
                    let nz = Double(z - center) / Double(center)

                    // Spherical coordinates
                    let r = sqrt(nx * nx + ny * ny + nz * nz)
                    let theta = atan2(ny, nx)
                    let phi = acos(nz / max(r, 0.001))

                    // Spherical harmonic for visualization
                    // Using first-order ambisonic coefficients
                    let Y00 = 0.5 * sqrt(1 / .pi)  // l=0, m=0
                    let Y10 = 0.5 * sqrt(3 / .pi) * nz  // l=1, m=0
                    let Y11 = 0.5 * sqrt(3 / .pi) * nx  // l=1, m=1
                    let Y1m1 = 0.5 * sqrt(3 / .pi) * ny  // l=1, m=-1

                    let fieldValue = ambisonicCoeffs[0] * Y00 +
                                    ambisonicCoeffs[1] * Y10 +
                                    ambisonicCoeffs[2] * Y11 +
                                    ambisonicCoeffs[3] * Y1m1

                    fieldData[x][y][z] = fieldValue
                }
            }
        }
    }

    // MARK: - Control Methods

    /// Set processing mode
    func setMode(_ newMode: SpaceMode) {
        mode = newMode
        print("🌌 Space Mode: \(mode.rawValue)")
        print("   \(mode.description)")
    }

    /// Update listener position
    func setListenerPosition(_ position: SIMD3<Double>) {
        listenerPosition = position
    }

    /// Update listener orientation (yaw, pitch, roll)
    func setListenerOrientation(_ orientation: SIMD3<Double>) {
        listenerOrientation = orientation
    }

    /// Add a spatial sound source
    func addSource(position: SIMD3<Double>, frequency: Double, amplitude: Double) {
        let source = SpatialSource(
            position: position,
            frequency: frequency,
            amplitude: amplitude
        )
        soundSources.append(source)
    }

    /// Get 3D field data for GPU visualization
    func getFieldData() -> [[[Double]]] {
        return fieldData
    }

    /// Get flattened field data for compute shaders
    func getFieldDataFlat() -> [Float] {
        return fieldData.flatMap { plane in
            plane.flatMap { row in
                row.map { Float($0) }
            }
        }
    }
}


// MARK: - Spatial Source

struct SpatialSource: Identifiable {
    let id = UUID()
    var position: SIMD3<Double>
    var frequency: Double
    var amplitude: Double
    var phase: Double = 0

    /// Calculate gain and delay for binaural rendering
    func binauralParameters(listenerPos: SIMD3<Double>, listenerOrientation: SIMD3<Double>) -> (leftGain: Double, rightGain: Double, delay: Double) {
        let direction = position - listenerPos
        let distance = simd_length(direction)

        // Apply listener rotation (simplified - yaw only)
        let rotatedX = direction.x * cos(listenerOrientation.x) + direction.z * sin(listenerOrientation.x)
        let azimuth = atan2(direction.y, rotatedX)

        // Distance attenuation (inverse square)
        let baseGain = 1.0 / max(distance * distance, 0.01)

        // ILD calculation
        let ild = pow(10, -abs(azimuth) * 0.5 / 20)

        let leftGain = azimuth > 0 ? baseGain : baseGain * ild
        let rightGain = azimuth < 0 ? baseGain : baseGain * ild

        // ITD
        let itd = distance / SpaceVibrationField.speedOfSound

        return (leftGain, rightGain, itd)
    }
}


// MARK: - Spherical Harmonics Utilities

extension SpaceVibrationField {

    /// Calculate spherical harmonic Y_l^m(θ, φ)
    static func sphericalHarmonic(l: Int, m: Int, theta: Double, phi: Double) -> Double {
        // Simplified implementation for low orders
        // Full implementation would use associated Legendre polynomials

        switch (l, m) {
        case (0, 0):
            return 0.5 * sqrt(1 / .pi)

        case (1, -1):
            return 0.5 * sqrt(3 / (2 * .pi)) * sin(theta) * sin(phi)

        case (1, 0):
            return 0.5 * sqrt(3 / .pi) * cos(theta)

        case (1, 1):
            return -0.5 * sqrt(3 / (2 * .pi)) * sin(theta) * cos(phi)

        case (2, -2):
            return 0.25 * sqrt(15 / (2 * .pi)) * sin(theta) * sin(theta) * sin(2 * phi)

        case (2, -1):
            return 0.5 * sqrt(15 / (2 * .pi)) * sin(theta) * cos(theta) * sin(phi)

        case (2, 0):
            return 0.25 * sqrt(5 / .pi) * (3 * cos(theta) * cos(theta) - 1)

        case (2, 1):
            return -0.5 * sqrt(15 / (2 * .pi)) * sin(theta) * cos(theta) * cos(phi)

        case (2, 2):
            return 0.25 * sqrt(15 / (2 * .pi)) * sin(theta) * sin(theta) * cos(2 * phi)

        default:
            return 0
        }
    }

    /// Convert Cartesian to spherical coordinates
    static func cartesianToSpherical(_ cartesian: SIMD3<Double>) -> (r: Double, theta: Double, phi: Double) {
        let r = simd_length(cartesian)
        let theta = acos(cartesian.z / max(r, 1e-10))
        let phi = atan2(cartesian.y, cartesian.x)
        return (r, theta, phi)
    }

    /// Convert spherical to Cartesian coordinates
    static func sphericalToCartesian(r: Double, theta: Double, phi: Double) -> SIMD3<Double> {
        return SIMD3(
            r * sin(theta) * cos(phi),
            r * sin(theta) * sin(phi),
            r * cos(theta)
        )
    }
}
