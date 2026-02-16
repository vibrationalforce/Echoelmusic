import Foundation
import Accelerate

// MARK: - Quantum Wavefunction Synthesizer
// Sound generation based on the time-dependent Schrödinger equation (TDSE).
// Uses Split-Step Fourier method for real-time numerical simulation.
//
// Architecture:
//   1. State vector ψ: complex-valued array (real + imaginary parts)
//   2. Hamilton operator Ĥ = kinetic energy + potential energy
//   3. Split-Step Fourier: V-step in position space, T-step in momentum space via FFT
//   4. Audio extraction via observables (Re(ψ), |ψ|², phase-to-stereo)
//
// References:
//   - Schrödinger, E. (1926) "Quantisierung als Eigenwertproblem"
//   - Feit, Fleck, Steiger (1982) "Solution of the Schrödinger equation by a spectral method"

/// Quantum Wavefunction Synthesizer — generates audio from Schrödinger equation simulation
public final class QuantumWavefunctionSynth: @unchecked Sendable {

    // MARK: - Types

    /// How the wavefunction is mapped to audio output
    public enum OutputMode: String, CaseIterable, Sendable {
        /// Real part of ψ(x,t) as amplitude — most "musical"
        case realPart = "Real Part"
        /// Probability density |ψ(x,t)|² — octave-rich, harmonics
        case probabilityDensity = "Probability Density"
        /// Real → Left, Imaginary → Right — extreme stereo width
        case phaseToStereo = "Phase-to-Stereo"
        /// Expectation value of position ⟨x⟩ — smooth, tonal
        case expectationValue = "Expectation Value"
    }

    /// Potential barrier type for the simulation
    public enum PotentialType: String, CaseIterable, Sendable {
        /// Infinite square well (particle in a box)
        case infiniteWell = "Infinite Well"
        /// Harmonic oscillator (quadratic potential)
        case harmonicOscillator = "Harmonic Oscillator"
        /// Double well (two minima — tunneling)
        case doubleWell = "Double Well"
        /// Periodic (crystal lattice — band structure)
        case periodic = "Periodic"
        /// User-drawn arbitrary potential
        case custom = "Custom"
        /// No potential (free particle)
        case free = "Free"
    }

    // MARK: - Configuration

    /// Number of spatial grid points (must be power of 2 for FFT)
    public let gridSize: Int

    /// Spatial extent of simulation domain
    public let spatialExtent: Float

    /// Sample rate for audio output
    public let sampleRate: Float

    /// Number of simulation steps per audio sample
    public let stepsPerSample: Int

    // MARK: - State

    /// Real part of wavefunction ψ
    private var psiReal: [Float]

    /// Imaginary part of wavefunction ψ
    private var psiImag: [Float]

    /// Potential energy field V(x)
    private var potential: [Float]

    /// Spatial grid positions
    private let xGrid: [Float]

    /// Momentum grid (for FFT step)
    private let kGrid: [Float]

    /// Grid spacing Δx
    private let dx: Float

    /// Momentum spacing Δk
    private let dk: Float

    /// Time step Δt
    private var dt: Float

    /// Current simulation time
    private var time: Float = 0

    // MARK: - FFT Setup (Accelerate)

    private let fftSetup: vDSP.FFT<DSPSplitComplex>?
    private let log2n: vDSP_Length

    // MARK: - Parameters

    /// Output mode
    public var outputMode: OutputMode = .realPart

    /// Potential type
    public var potentialType: PotentialType = .harmonicOscillator {
        didSet { rebuildPotential() }
    }

    /// Potential strength (controls barrier height / well depth)
    public var potentialStrength: Float = 1.0 {
        didSet { rebuildPotential() }
    }

    /// Fundamental frequency (Hz) — controls pitch via potential width
    public var frequency: Float = 220.0 {
        didSet { rebuildPotential() }
    }

    /// Damping coefficient (absorbing boundary conditions)
    public var damping: Float = 0.001

    /// Excitation amplitude for Gaussian wave packets
    public var excitationAmplitude: Float = 1.0

    /// Excitation width (σ of Gaussian)
    public var excitationWidth: Float = 0.05

    // MARK: - Entanglement

    /// Coupled second oscillator for entanglement simulation
    private var entangledPartner: QuantumWavefunctionSynth?

    /// Entanglement coupling strength (0 = independent, 1 = fully coupled)
    public var entanglementCoupling: Float = 0.0

    // MARK: - Scratch Buffers

    private var scratchReal: [Float]
    private var scratchImag: [Float]
    private var potentialPhaseReal: [Float]
    private var potentialPhaseImag: [Float]
    private var kineticPhaseReal: [Float]
    private var kineticPhaseImag: [Float]

    // MARK: - Init

    /// Initialize quantum wavefunction synthesizer
    /// - Parameters:
    ///   - gridSize: Spatial grid points (power of 2, default 1024)
    ///   - sampleRate: Audio sample rate (default 48000)
    ///   - stepsPerSample: Simulation steps per audio sample (default 4)
    public init(gridSize: Int = 1024, sampleRate: Float = 48000.0, stepsPerSample: Int = 4) {
        // Ensure power of 2
        let n = max(64, gridSize)
        let log2 = vDSP_Length(Foundation.log2(Float(n)))
        self.gridSize = 1 << Int(log2)
        self.log2n = log2
        self.sampleRate = sampleRate
        self.stepsPerSample = stepsPerSample
        self.spatialExtent = 10.0

        // Grid spacing
        self.dx = spatialExtent / Float(self.gridSize)
        self.dk = (2.0 * .pi) / spatialExtent

        // Time step (stability: dt < dx² / 2 for explicit methods)
        self.dt = 0.5 * dx * dx

        // Position grid: -L/2 to +L/2
        var x = [Float](repeating: 0, count: self.gridSize)
        let halfL = spatialExtent / 2.0
        for i in 0..<self.gridSize {
            x[i] = -halfL + Float(i) * dx
        }
        self.xGrid = x

        // Momentum grid (FFT-ordered: 0..N/2-1, -N/2..-1)
        var k = [Float](repeating: 0, count: self.gridSize)
        let halfN = self.gridSize / 2
        for i in 0..<self.gridSize {
            if i <= halfN {
                k[i] = Float(i) * dk
            } else {
                k[i] = Float(i - self.gridSize) * dk
            }
        }
        self.kGrid = k

        // State vectors
        self.psiReal = [Float](repeating: 0, count: self.gridSize)
        self.psiImag = [Float](repeating: 0, count: self.gridSize)
        self.potential = [Float](repeating: 0, count: self.gridSize)

        // Scratch buffers
        self.scratchReal = [Float](repeating: 0, count: self.gridSize)
        self.scratchImag = [Float](repeating: 0, count: self.gridSize)
        self.potentialPhaseReal = [Float](repeating: 0, count: self.gridSize)
        self.potentialPhaseImag = [Float](repeating: 0, count: self.gridSize)
        self.kineticPhaseReal = [Float](repeating: 0, count: self.gridSize)
        self.kineticPhaseImag = [Float](repeating: 0, count: self.gridSize)

        // FFT setup
        self.fftSetup = vDSP.FFT(log2n: log2n, radix: .radix2, ofType: DSPSplitComplex.self)

        // Build initial potential and excite
        rebuildPotential()
        excite(position: 0, momentum: Float(frequency) * 0.1)
    }

    // MARK: - Potential Construction

    /// Rebuild the potential energy field based on current parameters
    private func rebuildPotential() {
        let omega = 2.0 * Float.pi * frequency / sampleRate * 10.0

        switch potentialType {
        case .infiniteWell:
            // Particle in a box: V=0 inside, V=∞ at boundaries
            let wellWidth = spatialExtent * 0.6 / potentialStrength
            for i in 0..<gridSize {
                let x = xGrid[i]
                potential[i] = abs(x) > wellWidth / 2.0 ? 1e6 : 0
            }

        case .harmonicOscillator:
            // V(x) = ½mω²x²
            let k = omega * omega * potentialStrength
            for i in 0..<gridSize {
                let x = xGrid[i]
                potential[i] = 0.5 * k * x * x
            }

        case .doubleWell:
            // V(x) = a(x²-b)² — double minimum for tunneling
            let a = potentialStrength * 2.0
            let b = 1.0 / potentialStrength
            for i in 0..<gridSize {
                let x = xGrid[i]
                let xsq = x * x
                potential[i] = a * (xsq - b) * (xsq - b)
            }

        case .periodic:
            // V(x) = V₀ cos(2πx/a) — Kronig-Penney style
            let period = spatialExtent / (4.0 * potentialStrength)
            for i in 0..<gridSize {
                let x = xGrid[i]
                potential[i] = potentialStrength * 100.0 * cos(2.0 * .pi * x / period)
            }

        case .custom:
            // Custom potential is set externally, don't overwrite
            break

        case .free:
            // No potential
            for i in 0..<gridSize {
                potential[i] = 0
            }
        }

        // Add absorbing boundary conditions (complex absorbing potential)
        let boundaryWidth = Float(gridSize) * 0.1
        for i in 0..<gridSize {
            let distFromEdge = min(Float(i), Float(gridSize - 1 - i))
            if distFromEdge < boundaryWidth {
                let absorption = damping * pow(1.0 - distFromEdge / boundaryWidth, 2)
                potential[i] += absorption * 1e4
            }
        }

        // Precompute potential phase factors: exp(-i V Δt / (2ℏ))
        // Using ℏ = 1 (natural units)
        let halfDt = dt * 0.5
        for i in 0..<gridSize {
            let phase = -potential[i] * halfDt
            potentialPhaseReal[i] = cos(phase)
            potentialPhaseImag[i] = sin(phase)
        }

        // Precompute kinetic phase factors: exp(-i k² Δt / (2m))
        // Using m = 1
        for i in 0..<gridSize {
            let kSq = kGrid[i] * kGrid[i]
            let phase = -0.5 * kSq * dt
            kineticPhaseReal[i] = cos(phase)
            kineticPhaseImag[i] = sin(phase)
        }
    }

    // MARK: - Excitation

    /// Excite the wavefunction with a Gaussian wave packet
    /// Like plucking a string — injects energy into the simulation
    /// - Parameters:
    ///   - position: Center position (-1 to 1, normalized)
    ///   - momentum: Initial momentum (controls initial pitch direction)
    public func excite(position: Float = 0, momentum: Float = 5.0) {
        let x0 = position * spatialExtent / 2.0
        let sigma = excitationWidth * spatialExtent
        let sigmaSq = sigma * sigma
        let norm = 1.0 / sqrt(sigma * sqrt(.pi))

        for i in 0..<gridSize {
            let x = xGrid[i]
            let dx = x - x0
            let envelope = norm * excitationAmplitude * exp(-dx * dx / (2.0 * sigmaSq))
            let phase = momentum * x
            psiReal[i] += envelope * cos(phase)
            psiImag[i] += envelope * sin(phase)
        }

        normalize()
    }

    /// Set custom potential (for user-drawn barriers)
    /// - Parameter values: Potential values (gridSize elements, 0-1 normalized)
    public func setCustomPotential(_ values: [Float]) {
        guard values.count == gridSize else { return }
        potentialType = .custom
        let maxV = potentialStrength * 500.0
        for i in 0..<gridSize {
            potential[i] = values[i] * maxV
        }
        // Re-precompute phase factors
        let halfDt = dt * 0.5
        for i in 0..<gridSize {
            let phase = -potential[i] * halfDt
            potentialPhaseReal[i] = cos(phase)
            potentialPhaseImag[i] = sin(phase)
        }
    }

    // MARK: - Split-Step Fourier Evolution

    /// Advance the wavefunction by one time step using Split-Step Fourier
    /// 1. Half-step potential in position space: ψ *= exp(-iVΔt/2ℏ)
    /// 2. FFT to momentum space
    /// 3. Full kinetic step: ψ̃ *= exp(-ik²Δt/2m)
    /// 4. iFFT back to position space
    /// 5. Half-step potential: ψ *= exp(-iVΔt/2ℏ)
    private func step() {
        // --- Half-step potential (position space) ---
        complexMultiply(
            aReal: psiReal, aImag: psiImag,
            bReal: potentialPhaseReal, bImag: potentialPhaseImag,
            outReal: &psiReal, outImag: &psiImag
        )

        // --- FFT to momentum space ---
        forwardFFT()

        // --- Full kinetic step (momentum space) ---
        complexMultiply(
            aReal: psiReal, aImag: psiImag,
            bReal: kineticPhaseReal, bImag: kineticPhaseImag,
            outReal: &psiReal, outImag: &psiImag
        )

        // --- iFFT back to position space ---
        inverseFFT()

        // --- Half-step potential (position space) ---
        complexMultiply(
            aReal: psiReal, aImag: psiImag,
            bReal: potentialPhaseReal, bImag: potentialPhaseImag,
            outReal: &psiReal, outImag: &psiImag
        )

        // --- Entanglement coupling ---
        if entanglementCoupling > 0, let partner = entangledPartner {
            applyEntanglementCoupling(partner: partner)
        }

        time += dt
    }

    // MARK: - FFT Operations

    private func forwardFFT() {
        // Copy state to scratch, apply FFT in-place
        psiReal.withUnsafeMutableBufferPointer { realBuf in
            psiImag.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(
                    realp: realBuf.baseAddress!,
                    imagp: imagBuf.baseAddress!
                )
                fftSetup?.forward(input: &split, output: &split)
            }
        }

        // Normalize by 1/N
        let scale = 1.0 / Float(gridSize)
        vDSP.multiply(scale, psiReal, result: &psiReal)
        vDSP.multiply(scale, psiImag, result: &psiImag)
    }

    private func inverseFFT() {
        psiReal.withUnsafeMutableBufferPointer { realBuf in
            psiImag.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(
                    realp: realBuf.baseAddress!,
                    imagp: imagBuf.baseAddress!
                )
                fftSetup?.inverse(input: &split, output: &split)
            }
        }
    }

    // MARK: - Complex Arithmetic (Vectorized)

    /// Element-wise complex multiplication using Accelerate
    private func complexMultiply(
        aReal: [Float], aImag: [Float],
        bReal: [Float], bImag: [Float],
        outReal: inout [Float], outImag: inout [Float]
    ) {
        // (a + bi)(c + di) = (ac - bd) + (ad + bc)i
        // Use scratch buffers to avoid aliasing issues
        vDSP.multiply(aReal, bReal, result: &scratchReal)       // ac
        vDSP.multiply(aImag, bImag, result: &scratchImag)       // bd
        vDSP.subtract(scratchImag, scratchReal, result: &scratchReal) // ac - bd (wrong order!)

        // Fix: vDSP.subtract(b, a) = a - b, so swap
        // Actually: result[i] = scratchReal[i] - scratchImag[i]
        // Let's just be explicit
        for i in 0..<gridSize {
            let ac = aReal[i] * bReal[i]
            let bd = aImag[i] * bImag[i]
            let ad = aReal[i] * bImag[i]
            let bc = aImag[i] * bReal[i]
            outReal[i] = ac - bd
            outImag[i] = ad + bc
        }
    }

    // MARK: - Normalization

    /// Normalize wavefunction so ∫|ψ|²dx = 1
    private func normalize() {
        var normSq: Float = 0
        for i in 0..<gridSize {
            normSq += psiReal[i] * psiReal[i] + psiImag[i] * psiImag[i]
        }
        normSq *= dx
        guard normSq > 1e-30 else { return }
        let scale = 1.0 / sqrt(normSq)
        vDSP.multiply(scale, psiReal, result: &psiReal)
        vDSP.multiply(scale, psiImag, result: &psiImag)
    }

    // MARK: - Entanglement

    /// Set up entanglement with another quantum synth instance
    /// Coupling creates cross-Kerr-like interaction between the two systems
    public func entangle(with partner: QuantumWavefunctionSynth, coupling: Float = 0.3) {
        self.entangledPartner = partner
        self.entanglementCoupling = coupling
        partner.entangledPartner = self
        partner.entanglementCoupling = coupling
    }

    /// Disentangle from partner
    public func disentangle() {
        entangledPartner?.entangledPartner = nil
        entangledPartner?.entanglementCoupling = 0
        entangledPartner = nil
        entanglementCoupling = 0
    }

    /// Apply cross-Kerr-like entanglement coupling
    /// The probability density of A modulates the potential of B and vice versa
    private func applyEntanglementCoupling(partner: QuantumWavefunctionSynth) {
        let coupling = entanglementCoupling
        guard coupling > 0 else { return }

        // Compute |ψ_partner|² as effective potential modulation
        for i in 0..<gridSize {
            let probDensity = partner.psiReal[i] * partner.psiReal[i]
                            + partner.psiImag[i] * partner.psiImag[i]
            let phase = -coupling * probDensity * dt
            let cosP = cos(phase)
            let sinP = sin(phase)
            let r = psiReal[i]
            let im = psiImag[i]
            psiReal[i] = r * cosP - im * sinP
            psiImag[i] = r * sinP + im * cosP
        }
    }

    // MARK: - Audio Generation

    /// Generate audio samples from the quantum simulation
    /// - Parameters:
    ///   - buffer: Output buffer to fill (mono or stereo interleaved)
    ///   - frameCount: Number of frames to generate
    ///   - stereo: If true, generates stereo (2 channels interleaved)
    public func render(buffer: inout [Float], frameCount: Int, stereo: Bool = false) {
        let channelCount = stereo ? 2 : 1
        let totalSamples = frameCount * channelCount

        guard buffer.count >= totalSamples else { return }

        for frame in 0..<frameCount {
            // Advance simulation
            for _ in 0..<stepsPerSample {
                step()
            }

            // Extract audio from wavefunction
            switch outputMode {
            case .realPart:
                // Sum real part as audio sample
                let sample = extractRealPart()
                if stereo {
                    buffer[frame * 2] = sample
                    buffer[frame * 2 + 1] = sample
                } else {
                    buffer[frame] = sample
                }

            case .probabilityDensity:
                // |ψ|² — rich in harmonics (octave doubling)
                let sample = extractProbabilityDensity()
                if stereo {
                    buffer[frame * 2] = sample
                    buffer[frame * 2 + 1] = sample
                } else {
                    buffer[frame] = sample
                }

            case .phaseToStereo:
                // Real → Left, Imaginary → Right
                let (left, right) = extractPhaseToStereo()
                if stereo {
                    buffer[frame * 2] = left
                    buffer[frame * 2 + 1] = right
                } else {
                    buffer[frame] = (left + right) * 0.5  // Mono downmix
                }

            case .expectationValue:
                // ⟨x⟩ — expectation value of position
                let sample = extractExpectationValue()
                if stereo {
                    buffer[frame * 2] = sample
                    buffer[frame * 2 + 1] = sample
                } else {
                    buffer[frame] = sample
                }
            }
        }
    }

    // MARK: - Observable Extraction

    /// Extract audio from the real part of ψ
    private func extractRealPart() -> Float {
        // Weighted sum of Re(ψ) centered on the well
        var sum: Float = 0
        let center = gridSize / 2
        let window = gridSize / 4
        for i in (center - window)..<(center + window) {
            let fade = 1.0 - abs(Float(i - center)) / Float(window)
            sum += psiReal[i] * fade
        }
        return sum * dx * 2.0
    }

    /// Extract audio from probability density |ψ|²
    private func extractProbabilityDensity() -> Float {
        var sum: Float = 0
        let center = gridSize / 2
        let window = gridSize / 4
        for i in (center - window)..<(center + window) {
            let prob = psiReal[i] * psiReal[i] + psiImag[i] * psiImag[i]
            let fade = 1.0 - abs(Float(i - center)) / Float(window)
            sum += prob * fade
        }
        // Remove DC offset (probability is always positive)
        return (sum * dx * 4.0) - 0.5
    }

    /// Extract stereo from phase: Re(ψ) → L, Im(ψ) → R
    private func extractPhaseToStereo() -> (left: Float, right: Float) {
        var sumReal: Float = 0
        var sumImag: Float = 0
        let center = gridSize / 2
        let window = gridSize / 4
        for i in (center - window)..<(center + window) {
            let fade = 1.0 - abs(Float(i - center)) / Float(window)
            sumReal += psiReal[i] * fade
            sumImag += psiImag[i] * fade
        }
        return (sumReal * dx * 2.0, sumImag * dx * 2.0)
    }

    /// Extract audio from expectation value ⟨x⟩ = ∫ x |ψ|² dx
    private func extractExpectationValue() -> Float {
        var sum: Float = 0
        for i in 0..<gridSize {
            let prob = psiReal[i] * psiReal[i] + psiImag[i] * psiImag[i]
            sum += xGrid[i] * prob
        }
        return sum * dx / spatialExtent  // Normalize to [-0.5, 0.5]
    }

    // MARK: - Wavefunction State Access

    /// Get current probability density |ψ(x)|² for visualization
    public func getProbabilityDensity() -> [Float] {
        var result = [Float](repeating: 0, count: gridSize)
        for i in 0..<gridSize {
            result[i] = psiReal[i] * psiReal[i] + psiImag[i] * psiImag[i]
        }
        return result
    }

    /// Get current real part of ψ for visualization
    public func getRealPart() -> [Float] {
        return psiReal
    }

    /// Get current potential V(x) for visualization
    public func getPotential() -> [Float] {
        return potential
    }

    /// Get total energy ⟨Ĥ⟩ of the system
    public func getTotalEnergy() -> Float {
        // Kinetic energy via momentum space
        var kineticEnergy: Float = 0
        // Copy state for FFT
        var tmpReal = psiReal
        var tmpImag = psiImag

        tmpReal.withUnsafeMutableBufferPointer { realBuf in
            tmpImag.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(
                    realp: realBuf.baseAddress!,
                    imagp: imagBuf.baseAddress!
                )
                fftSetup?.forward(input: &split, output: &split)
            }
        }

        let scale = 1.0 / Float(gridSize)
        for i in 0..<gridSize {
            let kSq = kGrid[i] * kGrid[i]
            let probK = (tmpReal[i] * tmpReal[i] + tmpImag[i] * tmpImag[i]) * scale * scale
            kineticEnergy += 0.5 * kSq * probK
        }
        kineticEnergy *= dk

        // Potential energy via position space
        var potentialEnergy: Float = 0
        for i in 0..<gridSize {
            let prob = psiReal[i] * psiReal[i] + psiImag[i] * psiImag[i]
            potentialEnergy += potential[i] * prob
        }
        potentialEnergy *= dx

        return kineticEnergy + potentialEnergy
    }

    /// Get coherence metric (how "quantum" the state is — spread of wavefunction)
    public func getCoherence() -> Float {
        // Use position uncertainty Δx as coherence metric
        var meanX: Float = 0
        var meanX2: Float = 0
        for i in 0..<gridSize {
            let prob = psiReal[i] * psiReal[i] + psiImag[i] * psiImag[i]
            meanX += xGrid[i] * prob
            meanX2 += xGrid[i] * xGrid[i] * prob
        }
        meanX *= dx
        meanX2 *= dx
        let variance = meanX2 - meanX * meanX
        // Normalize: small uncertainty = high coherence
        let maxVariance = (spatialExtent * spatialExtent) / 12.0  // Uniform distribution variance
        return max(0, min(1, 1.0 - sqrt(max(0, variance)) / sqrt(maxVariance)))
    }

    // MARK: - Reset

    /// Reset wavefunction to ground state
    public func reset() {
        for i in 0..<gridSize {
            psiReal[i] = 0
            psiImag[i] = 0
        }
        time = 0
    }

    /// Reset and re-excite with default parameters
    public func restart() {
        reset()
        rebuildPotential()
        excite(position: 0, momentum: Float(frequency) * 0.1)
    }
}
