import Foundation
import Accelerate

// MARK: - EchoelQuant — Quantum Wavefunction Synthesizer
// Sound generation based on the time-dependent Schrödinger equation (TDSE).
// Uses Split-Step Fourier method for real-time numerical simulation.
//
// Architecture:
//   1. State vector ψ: complex-valued array (real + imaginary parts)
//   2. Hamilton operator Ĥ = kinetic energy + potential energy
//   3. Split-Step Fourier: V-step in position space, T-step in momentum space via FFT
//   4. Audio extraction via observables (Re(ψ), |ψ|², phase-to-stereo)
//
// Features:
//   - 6 potential types (infinite well, harmonic, double well, periodic, custom, free)
//   - 4 output modes (real part, probability density, phase-to-stereo, expectation value)
//   - Unison mode (up to 16 stacked voices with detune and stereo spread)
//   - Entanglement coupling between instances
//   - Superposition blend between two potential types
//   - Wavefunction collapse trigger for transient percussion
//
// References:
//   - Schrödinger, E. (1926) "Quantisierung als Eigenwertproblem"
//   - Feit, Fleck, Steiger (1982) "Solution of the Schrödinger equation by a spectral method"

/// EchoelQuant — Quantum Wavefunction Synthesizer
/// Generates audio from Schrödinger equation simulation with unison stacking
public final class EchoelQuant: @unchecked Sendable {

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

    // MARK: - Unison

    /// Number of unison voices (1 = off, 2-16 = stacked)
    public var unisonVoices: Int = 1 {
        didSet {
            unisonVoices = max(1, min(16, unisonVoices))
            rebuildUnisonDetune()
        }
    }

    /// Unison detune amount in cents (0-100)
    public var unisonDetune: Float = 25.0 {
        didSet { rebuildUnisonDetune() }
    }

    /// Unison stereo spread (0 = mono, 1 = full width)
    public var unisonSpread: Float = 0.8

    /// Per-voice frequency multipliers for unison detune
    private var unisonFrequencyMultipliers: [Float] = [1.0]

    /// Per-voice stereo pan positions (-1 = left, +1 = right)
    private var unisonPanPositions: [Float] = [0.0]

    /// Additional unison voice states (voice 0 is the main psi)
    private var unisonPsiReal: [[Float]] = []
    private var unisonPsiImag: [[Float]] = []

    // MARK: - Superposition

    /// Secondary potential type for superposition blending
    public var superpositionPotential: PotentialType? = nil

    /// Blend amount between primary and secondary potential (0 = primary, 1 = secondary)
    public var superpositionBlend: Float = 0.0 {
        didSet { rebuildPotential() }
    }

    // MARK: - Collapse

    /// Whether a collapse has been triggered (creates transient)
    private var collapseTriggered: Bool = false

    /// Collapse position (normalized -1 to 1)
    private var collapsePosition: Float = 0

    /// Collapse width (how localized the measurement is)
    private var collapseWidth: Float = 0.1

    // MARK: - Entanglement

    /// Coupled second oscillator for entanglement simulation
    private var entangledPartner: EchoelQuant?

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

    /// Initialize EchoelQuant synthesizer
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

    // MARK: - Unison Setup

    /// Rebuild unison frequency multipliers and pan positions
    private func rebuildUnisonDetune() {
        let count = unisonVoices
        var multipliers = [Float](repeating: 1.0, count: count)
        var pans = [Float](repeating: 0.0, count: count)

        if count > 1 {
            let detuneRange = unisonDetune // cents
            for i in 0..<count {
                // Spread detune evenly from -detuneRange to +detuneRange
                let t = Float(i) / Float(count - 1) // 0 to 1
                let centOffset = -detuneRange + t * 2.0 * detuneRange
                multipliers[i] = pow(2.0, centOffset / 1200.0)

                // Stereo spread: alternate left/right, centered voices at center
                let panT = (t - 0.5) * 2.0 // -1 to 1
                pans[i] = panT * unisonSpread
            }
        }

        unisonFrequencyMultipliers = multipliers
        unisonPanPositions = pans

        // Resize unison voice buffers (voice 0 is main psi)
        let extraVoices = max(0, count - 1)
        while unisonPsiReal.count < extraVoices {
            unisonPsiReal.append([Float](repeating: 0, count: gridSize))
            unisonPsiImag.append([Float](repeating: 0, count: gridSize))
        }
        while unisonPsiReal.count > extraVoices {
            unisonPsiReal.removeLast()
            unisonPsiImag.removeLast()
        }

        // Re-excite unison voices with their detuned frequencies
        for v in 0..<extraVoices {
            let voiceFreq = frequency * multipliers[v + 1]
            for i in 0..<gridSize {
                unisonPsiReal[v][i] = 0
                unisonPsiImag[v][i] = 0
            }
            // Mini-excite for this voice
            let x0: Float = 0
            let sigma = excitationWidth * spatialExtent
            let sigmaSq = sigma * sigma
            let norm = 1.0 / sqrt(sigma * sqrt(.pi))
            let momentum = voiceFreq * 0.1
            for i in 0..<gridSize {
                let x = xGrid[i]
                let dxx = x - x0
                let envelope = norm * excitationAmplitude * exp(-dxx * dxx / (2.0 * sigmaSq))
                let phase = momentum * x
                unisonPsiReal[v][i] += envelope * cos(phase)
                unisonPsiImag[v][i] += envelope * sin(phase)
            }
            // Normalize this voice
            var normSq: Float = 0
            for i in 0..<gridSize {
                normSq += unisonPsiReal[v][i] * unisonPsiReal[v][i] + unisonPsiImag[v][i] * unisonPsiImag[v][i]
            }
            normSq *= dx
            if normSq > 1e-30 {
                let scale = 1.0 / sqrt(normSq)
                vDSP.multiply(scale, unisonPsiReal[v], result: &unisonPsiReal[v])
                vDSP.multiply(scale, unisonPsiImag[v], result: &unisonPsiImag[v])
            }
        }
    }

    // MARK: - Potential Construction

    /// Rebuild the potential energy field based on current parameters
    private func rebuildPotential() {
        buildPotentialForType(potentialType, into: &potential)

        // Superposition blending
        if let secondaryType = superpositionPotential, superpositionBlend > 0 {
            var secondaryPotential = [Float](repeating: 0, count: gridSize)
            buildPotentialForType(secondaryType, into: &secondaryPotential)
            let blend = superpositionBlend
            let invBlend = 1.0 - blend
            for i in 0..<gridSize {
                potential[i] = potential[i] * invBlend + secondaryPotential[i] * blend
            }
        }

        // Add absorbing boundary conditions
        let boundaryWidth = Float(gridSize) * 0.1
        for i in 0..<gridSize {
            let distFromEdge = min(Float(i), Float(gridSize - 1 - i))
            if distFromEdge < boundaryWidth {
                let absorption = damping * pow(1.0 - distFromEdge / boundaryWidth, 2)
                potential[i] += absorption * 1e4
            }
        }

        // Precompute potential phase factors: exp(-i V Δt / (2ℏ))
        let halfDt = dt * 0.5
        for i in 0..<gridSize {
            let phase = -potential[i] * halfDt
            potentialPhaseReal[i] = cos(phase)
            potentialPhaseImag[i] = sin(phase)
        }

        // Precompute kinetic phase factors: exp(-i k² Δt / (2m))
        for i in 0..<gridSize {
            let kSq = kGrid[i] * kGrid[i]
            let phase = -0.5 * kSq * dt
            kineticPhaseReal[i] = cos(phase)
            kineticPhaseImag[i] = sin(phase)
        }
    }

    /// Build potential for a specific type into target array
    private func buildPotentialForType(_ type: PotentialType, into target: inout [Float]) {
        let omega = 2.0 * Float.pi * frequency / sampleRate * 10.0

        switch type {
        case .infiniteWell:
            let wellWidth = spatialExtent * 0.6 / potentialStrength
            for i in 0..<gridSize {
                let x = xGrid[i]
                target[i] = abs(x) > wellWidth / 2.0 ? 1e6 : 0
            }

        case .harmonicOscillator:
            let k = omega * omega * potentialStrength
            for i in 0..<gridSize {
                let x = xGrid[i]
                target[i] = 0.5 * k * x * x
            }

        case .doubleWell:
            let a = potentialStrength * 2.0
            let b = 1.0 / potentialStrength
            for i in 0..<gridSize {
                let x = xGrid[i]
                let xsq = x * x
                target[i] = a * (xsq - b) * (xsq - b)
            }

        case .periodic:
            let period = spatialExtent / (4.0 * potentialStrength)
            for i in 0..<gridSize {
                let x = xGrid[i]
                target[i] = potentialStrength * 100.0 * cos(2.0 * .pi * x / period)
            }

        case .custom:
            break

        case .free:
            for i in 0..<gridSize {
                target[i] = 0
            }
        }
    }

    // MARK: - Excitation

    /// Excite the wavefunction with a Gaussian wave packet
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

        // Re-excite unison voices
        if unisonVoices > 1 {
            rebuildUnisonDetune()
        }
    }

    /// Set custom potential (for user-drawn barriers)
    public func setCustomPotential(_ values: [Float]) {
        guard values.count == gridSize else { return }
        potentialType = .custom
        let maxV = potentialStrength * 500.0
        for i in 0..<gridSize {
            potential[i] = values[i] * maxV
        }
        let halfDt = dt * 0.5
        for i in 0..<gridSize {
            let phase = -potential[i] * halfDt
            potentialPhaseReal[i] = cos(phase)
            potentialPhaseImag[i] = sin(phase)
        }
    }

    // MARK: - Wavefunction Collapse

    /// Trigger a wavefunction collapse — creates a sharp transient
    /// The wavefunction localizes to a position, then re-spreads
    /// - Parameters:
    ///   - position: Collapse position (-1 to 1)
    ///   - width: Collapse width (0.01 = very sharp, 0.5 = broad)
    public func collapse(at position: Float = 0, width: Float = 0.1) {
        let x0 = position * spatialExtent / 2.0
        let sigma = width * spatialExtent
        let sigmaSq = sigma * sigma

        // Project wavefunction onto localized Gaussian (measurement)
        var newNormSq: Float = 0
        for i in 0..<gridSize {
            let x = xGrid[i]
            let dxx = x - x0
            let measurement = exp(-dxx * dxx / (2.0 * sigmaSq))
            psiReal[i] *= measurement
            psiImag[i] *= measurement
            newNormSq += psiReal[i] * psiReal[i] + psiImag[i] * psiImag[i]
        }

        // Renormalize
        newNormSq *= dx
        if newNormSq > 1e-30 {
            let scale = 1.0 / sqrt(newNormSq)
            vDSP.multiply(scale, psiReal, result: &psiReal)
            vDSP.multiply(scale, psiImag, result: &psiImag)
        }
    }

    // MARK: - Superposition

    /// Set up superposition between two potential types
    /// Creates morphing between two quantum worlds
    public func setSuperposition(primary: PotentialType, secondary: PotentialType, blend: Float = 0.5) {
        self.potentialType = primary
        self.superpositionPotential = secondary
        self.superpositionBlend = max(0, min(1, blend))
    }

    // MARK: - Split-Step Fourier Evolution

    /// Advance the wavefunction by one time step using Split-Step Fourier
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

    /// Step a unison voice (simplified — shares kinetic/potential phases)
    private func stepUnisonVoice(_ voiceIndex: Int) {
        guard voiceIndex < unisonPsiReal.count else { return }

        for i in 0..<gridSize {
            let r = unisonPsiReal[voiceIndex][i]
            let im = unisonPsiImag[voiceIndex][i]
            let pr = potentialPhaseReal[i]
            let pi = potentialPhaseImag[i]
            unisonPsiReal[voiceIndex][i] = r * pr - im * pi
            unisonPsiImag[voiceIndex][i] = r * pi + im * pr
        }

        unisonPsiReal[voiceIndex].withUnsafeMutableBufferPointer { realBuf in
            unisonPsiImag[voiceIndex].withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(
                    realp: realBuf.baseAddress!,
                    imagp: imagBuf.baseAddress!
                )
                fftSetup?.forward(input: &split, output: &split)
            }
        }

        let scale = 1.0 / Float(gridSize)
        vDSP.multiply(scale, unisonPsiReal[voiceIndex], result: &unisonPsiReal[voiceIndex])
        vDSP.multiply(scale, unisonPsiImag[voiceIndex], result: &unisonPsiImag[voiceIndex])

        for i in 0..<gridSize {
            let r = unisonPsiReal[voiceIndex][i]
            let im = unisonPsiImag[voiceIndex][i]
            let kr = kineticPhaseReal[i]
            let ki = kineticPhaseImag[i]
            unisonPsiReal[voiceIndex][i] = r * kr - im * ki
            unisonPsiImag[voiceIndex][i] = r * ki + im * kr
        }

        unisonPsiReal[voiceIndex].withUnsafeMutableBufferPointer { realBuf in
            unisonPsiImag[voiceIndex].withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(
                    realp: realBuf.baseAddress!,
                    imagp: imagBuf.baseAddress!
                )
                fftSetup?.inverse(input: &split, output: &split)
            }
        }

        for i in 0..<gridSize {
            let r = unisonPsiReal[voiceIndex][i]
            let im = unisonPsiImag[voiceIndex][i]
            let pr = potentialPhaseReal[i]
            let pi = potentialPhaseImag[i]
            unisonPsiReal[voiceIndex][i] = r * pr - im * pi
            unisonPsiImag[voiceIndex][i] = r * pi + im * pr
        }
    }

    // MARK: - FFT Operations

    private func forwardFFT() {
        psiReal.withUnsafeMutableBufferPointer { realBuf in
            psiImag.withUnsafeMutableBufferPointer { imagBuf in
                var split = DSPSplitComplex(
                    realp: realBuf.baseAddress!,
                    imagp: imagBuf.baseAddress!
                )
                fftSetup?.forward(input: &split, output: &split)
            }
        }

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

    // MARK: - Complex Arithmetic

    private func complexMultiply(
        aReal: [Float], aImag: [Float],
        bReal: [Float], bImag: [Float],
        outReal: inout [Float], outImag: inout [Float]
    ) {
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

    /// Set up entanglement with another EchoelQuant instance
    public func entangle(with partner: EchoelQuant, coupling: Float = 0.3) {
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

    private func applyEntanglementCoupling(partner: EchoelQuant) {
        let coupling = entanglementCoupling
        guard coupling > 0 else { return }

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

        let voiceGain = 1.0 / sqrt(Float(unisonVoices))

        for frame in 0..<frameCount {
            // Advance main voice
            for _ in 0..<stepsPerSample {
                step()
            }

            // Advance unison voices
            for v in 0..<unisonPsiReal.count {
                for _ in 0..<stepsPerSample {
                    stepUnisonVoice(v)
                }
            }

            // Mix all voices
            var left: Float = 0
            var right: Float = 0

            // Main voice (voice 0)
            let mainSample = extractSampleFromState(psiReal: psiReal, psiImag: psiImag)
            let mainPan = unisonPanPositions[0]
            left += mainSample * voiceGain * (1.0 - max(0, mainPan))
            right += mainSample * voiceGain * (1.0 + min(0, mainPan))

            // Unison voices
            for v in 0..<unisonPsiReal.count {
                let voiceSample = extractSampleFromState(psiReal: unisonPsiReal[v], psiImag: unisonPsiImag[v])
                let pan = unisonPanPositions[v + 1]
                left += voiceSample * voiceGain * (1.0 - max(0, pan))
                right += voiceSample * voiceGain * (1.0 + min(0, pan))
            }

            if stereo {
                buffer[frame * 2] = left
                buffer[frame * 2 + 1] = right
            } else {
                buffer[frame] = (left + right) * 0.5
            }
        }
    }

    // MARK: - Observable Extraction

    /// Extract a mono sample from a given wavefunction state
    private func extractSampleFromState(psiReal: [Float], psiImag: [Float]) -> Float {
        switch outputMode {
        case .realPart:
            return extractRealPartFrom(psiReal: psiReal)
        case .probabilityDensity:
            return extractProbabilityDensityFrom(psiReal: psiReal, psiImag: psiImag)
        case .phaseToStereo:
            let (l, r) = extractPhaseToStereoFrom(psiReal: psiReal, psiImag: psiImag)
            return (l + r) * 0.5
        case .expectationValue:
            return extractExpectationValueFrom(psiReal: psiReal, psiImag: psiImag)
        }
    }

    private func extractRealPartFrom(psiReal: [Float]) -> Float {
        var sum: Float = 0
        let center = gridSize / 2
        let window = gridSize / 4
        for i in (center - window)..<(center + window) {
            let fade = 1.0 - abs(Float(i - center)) / Float(window)
            sum += psiReal[i] * fade
        }
        return sum * dx * 2.0
    }

    private func extractProbabilityDensityFrom(psiReal: [Float], psiImag: [Float]) -> Float {
        var sum: Float = 0
        let center = gridSize / 2
        let window = gridSize / 4
        for i in (center - window)..<(center + window) {
            let prob = psiReal[i] * psiReal[i] + psiImag[i] * psiImag[i]
            let fade = 1.0 - abs(Float(i - center)) / Float(window)
            sum += prob * fade
        }
        return (sum * dx * 4.0) - 0.5
    }

    private func extractPhaseToStereoFrom(psiReal: [Float], psiImag: [Float]) -> (left: Float, right: Float) {
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

    private func extractExpectationValueFrom(psiReal: [Float], psiImag: [Float]) -> Float {
        var sum: Float = 0
        for i in 0..<gridSize {
            let prob = psiReal[i] * psiReal[i] + psiImag[i] * psiImag[i]
            sum += xGrid[i] * prob
        }
        return sum * dx / spatialExtent
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
        var kineticEnergy: Float = 0
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

        var potentialEnergy: Float = 0
        for i in 0..<gridSize {
            let prob = psiReal[i] * psiReal[i] + psiImag[i] * psiImag[i]
            potentialEnergy += potential[i] * prob
        }
        potentialEnergy *= dx

        return kineticEnergy + potentialEnergy
    }

    /// Get coherence metric
    public func getCoherence() -> Float {
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
        let maxVariance = (spatialExtent * spatialExtent) / 12.0
        return max(0, min(1, 1.0 - sqrt(max(0, variance)) / sqrt(maxVariance)))
    }

    // MARK: - Reset

    /// Reset wavefunction to ground state
    public func reset() {
        for i in 0..<gridSize {
            psiReal[i] = 0
            psiImag[i] = 0
        }
        for v in 0..<unisonPsiReal.count {
            for i in 0..<gridSize {
                unisonPsiReal[v][i] = 0
                unisonPsiImag[v][i] = 0
            }
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
