import Foundation
import Accelerate

/// BioSync Mode - Natural Body Resonance Audio System
///
/// Generates audio that represents how your body would resonate if you could
/// hear and see its vibrations. No synthetic binaural beats - only natural
/// acoustic resonance based on biometric data.
///
/// Scientific foundations:
/// - Respiratory sinus arrhythmia (RSA) - heart-breathing coupling
/// - HRV resonance frequency (~0.1 Hz / 6 breaths per minute)
/// - Natural acoustic resonance (string/membrane physics)
/// - Psychoacoustic principles (critical bands, masking)
///
/// References:
/// - Lehrer et al. (2003) "Heart rate variability biofeedback"
/// - Vaschillo et al. (2006) "Resonance in the cardiovascular system"
/// - Fletcher & Rossing (1998) "The Physics of Musical Instruments"
@MainActor
class BioSyncMode: ObservableObject {

    // MARK: - High-Precision Parameters

    /// Current tempo with microsecond precision (BPM)
    /// Mapped from heart rate with smooth interpolation
    @Published var tempo: Double = 60.0 {
        didSet {
            updateResonanceParameters()
        }
    }

    /// Base frequency in Hz with millihertz precision
    /// Allows microtonal adjustments (cents)
    @Published var baseFrequency: Double = 440.0 {
        didSet {
            updateHarmonicSeries()
        }
    }

    /// Tuning offset in cents (-100 to +100 = one semitone)
    /// Allows precise microtonal adjustments
    @Published var tuningCents: Double = 0.0 {
        didSet {
            updateHarmonicSeries()
        }
    }

    /// Key/root note (MIDI note number with decimal precision)
    /// 60.0 = middle C, 60.5 = quarter tone above middle C
    @Published var rootNote: Double = 60.0 {
        didSet {
            baseFrequency = midiNoteToFrequency(rootNote)
        }
    }

    // MARK: - Resonance Parameters

    /// Q-factor for resonance (higher = more sustained, ringing)
    /// Derived from HRV coherence
    @Published var resonanceQ: Double = 10.0

    /// Damping ratio (ζ) - how quickly vibrations decay
    /// ζ < 1: underdamped (ringing), ζ = 1: critical, ζ > 1: overdamped
    @Published var dampingRatio: Double = 0.05

    /// Resonance mode - type of natural vibration
    @Published var resonanceMode: ResonanceMode = .string

    // MARK: - Body Resonance State

    /// Current body resonance state computed from biometrics
    @Published private(set) var bodyResonance: BodyResonanceState = BodyResonanceState()

    /// Harmonic series based on current frequency
    @Published private(set) var harmonicSeries: [HarmonicComponent] = []

    // MARK: - Constants

    /// Reference tuning (A4 = 440 Hz by default)
    private let referenceA4: Double = 440.0

    /// Schumann resonance fundamental (Earth-ionosphere cavity)
    /// Used as a natural reference, not for mystical purposes
    static let schumannFundamental: Double = 7.83

    /// HRV resonance frequency (~0.1 Hz = 6 breaths/minute)
    /// This is the frequency at which cardiovascular system resonates
    static let hrvResonanceFrequency: Double = 0.1

    // MARK: - Initialization

    init() {
        updateHarmonicSeries()
        updateResonanceParameters()
    }

    // MARK: - High-Precision Frequency Conversion

    /// Convert MIDI note number to frequency with microtonal precision
    /// Formula: f = 440 × 2^((n-69)/12) with cents offset
    func midiNoteToFrequency(_ note: Double) -> Double {
        let centsOffset = tuningCents / 100.0  // Convert cents to semitones
        let totalSemitones = note - 69.0 + centsOffset
        return referenceA4 * pow(2.0, totalSemitones / 12.0)
    }

    /// Convert frequency to MIDI note number with decimal precision
    func frequencyToMidiNote(_ frequency: Double) -> Double {
        return 69.0 + 12.0 * log2(frequency / referenceA4)
    }

    /// Get frequency with specific cents offset from base
    func frequencyWithCents(_ cents: Double) -> Double {
        return baseFrequency * pow(2.0, cents / 1200.0)
    }

    // MARK: - Tempo Precision

    /// Tempo in milliseconds per beat (high precision)
    var millisecondsPerBeat: Double {
        return 60000.0 / tempo
    }

    /// Tempo in samples per beat at given sample rate
    func samplesPerBeat(sampleRate: Double) -> Double {
        return sampleRate * 60.0 / tempo
    }

    /// Convert tempo to frequency (beats per second)
    var tempoFrequency: Double {
        return tempo / 60.0
    }

    // MARK: - Bio-to-Resonance Mapping

    /// Update resonance from biometric data
    /// Maps body signals to natural acoustic resonance parameters
    func updateFromBiometrics(
        heartRate: Double,           // BPM
        hrv: Double,                 // ms (RMSSD or SDNN)
        coherence: Double,           // 0-100 score
        respirationRate: Double? = nil  // breaths per minute
    ) {
        // Map heart rate to tempo with smooth interpolation
        // Uses cardiac coherence research: optimal range 55-75 BPM for relaxation
        let normalizedHR = (heartRate - 40.0) / 120.0  // Normalize to 0-1 range
        tempo = 40.0 + normalizedHR * 140.0  // Map to 40-180 BPM range

        // Map HRV to resonance Q-factor
        // Higher HRV = higher Q = more sustained resonance
        // Based on: higher HRV indicates better autonomic flexibility
        let normalizedHRV = min(hrv / 100.0, 1.0)  // Normalize HRV (typical range 20-100ms)
        resonanceQ = 5.0 + normalizedHRV * 45.0  // Q from 5 to 50

        // Map coherence to damping ratio
        // Higher coherence = lower damping = longer sustain
        let normalizedCoherence = coherence / 100.0
        dampingRatio = 0.2 - normalizedCoherence * 0.18  // From 0.2 (low coherence) to 0.02 (high)

        // Calculate body resonance state
        calculateBodyResonance(
            heartRate: heartRate,
            hrv: hrv,
            coherence: coherence,
            respirationRate: respirationRate
        )
    }

    /// Calculate the body's resonance state
    private func calculateBodyResonance(
        heartRate: Double,
        hrv: Double,
        coherence: Double,
        respirationRate: Double?
    ) {
        var state = BodyResonanceState()

        // Cardiac frequency (heart beats per second)
        state.cardiacFrequency = heartRate / 60.0

        // HRV modulation frequency
        // The frequency at which HRV oscillates (typically 0.04-0.4 Hz)
        state.hrvModulationFrequency = BioSyncMode.hrvResonanceFrequency

        // Respiratory frequency
        if let respRate = respirationRate {
            state.respiratoryFrequency = respRate / 60.0
        } else {
            // Estimate from HRV (respiratory sinus arrhythmia)
            // Optimal RSA occurs around 0.1 Hz (6 breaths/min)
            state.respiratoryFrequency = 0.1
        }

        // Calculate resonance coupling
        // How well heart and breath are synchronized
        let cardiacPeriod = 1.0 / state.cardiacFrequency
        let respiratoryPeriod = 1.0 / state.respiratoryFrequency
        let ratio = cardiacPeriod / respiratoryPeriod

        // Coupling strength based on simple integer ratios
        // 4:1, 5:1, 6:1 heart:breath ratios indicate good coupling
        let nearestInteger = round(ratio)
        let deviation = abs(ratio - nearestInteger)
        state.couplingStrength = max(0, 1.0 - deviation * 2.0)

        // Overall coherence score
        state.overallCoherence = (coherence / 100.0 + state.couplingStrength) / 2.0

        self.bodyResonance = state
    }

    // MARK: - Harmonic Series Generation

    /// Update the harmonic series based on current frequency
    private func updateHarmonicSeries() {
        let effectiveFrequency = frequencyWithCents(tuningCents)
        var harmonics: [HarmonicComponent] = []

        // Generate natural harmonic series (partials)
        // Based on Fourier analysis of natural vibrating systems
        for n in 1...16 {
            let harmonic = HarmonicComponent(
                number: n,
                frequency: effectiveFrequency * Double(n),
                // Natural amplitude decay: 1/n for ideal string
                amplitude: 1.0 / Double(n),
                // Phase relationship
                phase: 0.0
            )
            harmonics.append(harmonic)
        }

        self.harmonicSeries = harmonics
    }

    /// Update resonance parameters
    private func updateResonanceParameters() {
        // Calculate derived resonance parameters
        let bandwidth = baseFrequency / resonanceQ
        let decayTime = resonanceQ / (Double.pi * baseFrequency)

        // Store for visualization
        bodyResonance.resonanceBandwidth = bandwidth
        bodyResonance.decayTime = decayTime
    }

    // MARK: - Natural Resonance Audio Generation

    /// Generate resonance audio buffer
    /// Creates natural acoustic resonance, NOT synthetic binaural beats
    func generateResonanceBuffer(
        sampleRate: Double,
        frameCount: Int
    ) -> [Float] {
        var buffer = [Float](repeating: 0, count: frameCount)
        let effectiveFrequency = frequencyWithCents(tuningCents)

        switch resonanceMode {
        case .string:
            generateStringResonance(
                buffer: &buffer,
                frequency: effectiveFrequency,
                sampleRate: sampleRate
            )

        case .membrane:
            generateMembraneResonance(
                buffer: &buffer,
                frequency: effectiveFrequency,
                sampleRate: sampleRate
            )

        case .tube:
            generateTubeResonance(
                buffer: &buffer,
                frequency: effectiveFrequency,
                sampleRate: sampleRate
            )

        case .plate:
            generatePlateResonance(
                buffer: &buffer,
                frequency: effectiveFrequency,
                sampleRate: sampleRate
            )
        }

        // Apply body resonance modulation
        applyBodyModulation(buffer: &buffer, sampleRate: sampleRate)

        return buffer
    }

    /// Generate string-like resonance (guitar, piano, voice box)
    private func generateStringResonance(
        buffer: inout [Float],
        frequency: Double,
        sampleRate: Double
    ) {
        // Use Karplus-Strong inspired synthesis with natural harmonics
        let period = sampleRate / frequency

        for i in 0..<buffer.count {
            let t = Double(i) / sampleRate
            var sample: Double = 0

            // Sum harmonics with natural decay
            for harmonic in harmonicSeries {
                let harmonicDecay = exp(-t * harmonic.frequency / (resonanceQ * 10.0))
                let phase = 2.0 * Double.pi * harmonic.frequency * t + harmonic.phase
                sample += harmonic.amplitude * harmonicDecay * sin(phase)
            }

            buffer[i] = Float(sample * 0.3)  // Scale to prevent clipping
        }
    }

    /// Generate membrane resonance (drum head, eardrum model)
    private func generateMembraneResonance(
        buffer: inout [Float],
        frequency: Double,
        sampleRate: Double
    ) {
        // Circular membrane modes (Bessel function zeros)
        let besselZeros: [Double] = [2.405, 3.832, 5.136, 5.520, 6.380, 7.016]
        let fundamentalMode = besselZeros[0]

        for i in 0..<buffer.count {
            let t = Double(i) / sampleRate
            var sample: Double = 0

            for (index, zero) in besselZeros.enumerated() {
                let modeFreq = frequency * zero / fundamentalMode
                let decay = exp(-t * modeFreq / (resonanceQ * 5.0))
                let amplitude = 1.0 / (Double(index) + 1.0)
                sample += amplitude * decay * sin(2.0 * Double.pi * modeFreq * t)
            }

            buffer[i] = Float(sample * 0.3)
        }
    }

    /// Generate tube/pipe resonance (breath, wind instruments)
    private func generateTubeResonance(
        buffer: inout [Float],
        frequency: Double,
        sampleRate: Double
    ) {
        // Open tube: all harmonics
        // Closed tube: odd harmonics only
        for i in 0..<buffer.count {
            let t = Double(i) / sampleRate
            var sample: Double = 0

            // Use odd harmonics for closed tube (like vocal tract)
            for n in stride(from: 1, through: 15, by: 2) {
                let harmonicFreq = frequency * Double(n)
                let decay = exp(-t * harmonicFreq / (resonanceQ * 8.0))
                let amplitude = 1.0 / Double(n)
                sample += amplitude * decay * sin(2.0 * Double.pi * harmonicFreq * t)
            }

            buffer[i] = Float(sample * 0.4)
        }
    }

    /// Generate plate resonance (body, ribcage as resonating plate)
    private func generatePlateResonance(
        buffer: inout [Float],
        frequency: Double,
        sampleRate: Double
    ) {
        // Plate modes are non-harmonic (unlike strings)
        // Mode frequencies proportional to (m² + n²) for rectangular plate
        let modeRatios: [Double] = [1.0, 1.594, 2.136, 2.5, 2.917, 3.0]

        for i in 0..<buffer.count {
            let t = Double(i) / sampleRate
            var sample: Double = 0

            for (index, ratio) in modeRatios.enumerated() {
                let modeFreq = frequency * ratio
                let decay = exp(-t * modeFreq / (resonanceQ * 6.0))
                let amplitude = 1.0 / (Double(index) + 1.0)
                sample += amplitude * decay * sin(2.0 * Double.pi * modeFreq * t)
            }

            buffer[i] = Float(sample * 0.35)
        }
    }

    /// Apply body-derived modulation to the audio
    private func applyBodyModulation(buffer: inout [Float], sampleRate: Double) {
        // Modulate amplitude based on cardiac rhythm
        // Creates natural "breathing" of the sound
        let cardiacPeriod = 1.0 / bodyResonance.cardiacFrequency
        let respiratoryPeriod = 1.0 / bodyResonance.respiratoryFrequency

        for i in 0..<buffer.count {
            let t = Double(i) / sampleRate

            // Cardiac modulation (subtle pulse)
            let cardiacMod = 1.0 + 0.05 * sin(2.0 * Double.pi * t / cardiacPeriod)

            // Respiratory modulation (breathing envelope)
            let respMod = 1.0 + 0.1 * sin(2.0 * Double.pi * t / respiratoryPeriod)

            // HRV modulation (slow variation)
            let hrvMod = 1.0 + 0.02 * sin(2.0 * Double.pi * bodyResonance.hrvModulationFrequency * t)

            buffer[i] *= Float(cardiacMod * respMod * hrvMod)
        }
    }

    // MARK: - Visualization Data

    /// Get visualization data for body resonance
    func getVisualizationData(sampleCount: Int) -> BodyResonanceVisualization {
        var vis = BodyResonanceVisualization()

        // Generate waveform representing body resonance
        vis.waveform = (0..<sampleCount).map { i in
            let t = Double(i) / Double(sampleCount)
            let cardiac = sin(2.0 * Double.pi * bodyResonance.cardiacFrequency * t * 10.0)
            let respiratory = sin(2.0 * Double.pi * bodyResonance.respiratoryFrequency * t * 10.0)
            return Float(cardiac * 0.3 + respiratory * 0.7)
        }

        // Generate harmonic spectrum
        vis.harmonicSpectrum = harmonicSeries.map { Float($0.amplitude) }

        // Resonance envelope
        vis.resonanceEnvelope = (0..<sampleCount).map { i in
            let t = Double(i) / Double(sampleCount) * 2.0  // 2 seconds
            return Float(exp(-t / bodyResonance.decayTime))
        }

        return vis
    }
}

// MARK: - Supporting Types

/// Natural resonance mode
enum ResonanceMode: String, CaseIterable, Codable {
    case string = "String"       // Guitar, piano, voice
    case membrane = "Membrane"   // Drum, heartbeat
    case tube = "Tube"          // Breath, wind
    case plate = "Plate"        // Body as resonating plate

    var description: String {
        switch self {
        case .string: return "String vibration (like vocal cords)"
        case .membrane: return "Membrane vibration (like heartbeat)"
        case .tube: return "Air column (like breathing)"
        case .plate: return "Plate vibration (like ribcage)"
        }
    }
}

/// Single harmonic component
struct HarmonicComponent {
    let number: Int
    let frequency: Double
    let amplitude: Double
    let phase: Double
}

/// Current body resonance state
struct BodyResonanceState {
    var cardiacFrequency: Double = 1.0        // Hz (heart beats per second)
    var respiratoryFrequency: Double = 0.25   // Hz (breaths per second)
    var hrvModulationFrequency: Double = 0.1  // Hz (HRV oscillation)
    var couplingStrength: Double = 0.5        // Heart-breath coupling (0-1)
    var overallCoherence: Double = 0.5        // Overall body coherence (0-1)
    var resonanceBandwidth: Double = 44.0     // Hz
    var decayTime: Double = 0.1               // seconds
}

/// Visualization data for body resonance
struct BodyResonanceVisualization {
    var waveform: [Float] = []
    var harmonicSpectrum: [Float] = []
    var resonanceEnvelope: [Float] = []
}

// MARK: - High-Precision Key/Scale System

extension BioSyncMode {

    /// Musical scale with microtonal support
    enum MicrotonalScale: String, CaseIterable {
        case equal12 = "12-TET"           // Standard equal temperament
        case just = "Just Intonation"     // Pure intervals
        case pythagorean = "Pythagorean"  // Based on perfect fifths
        case meantone = "Meantone"        // Renaissance tuning
        case equal24 = "24-TET"           // Quarter tones
        case equal53 = "53-TET"           // Turkish/Arabic microtones

        /// Get scale degrees in cents from root
        var degrees: [Double] {
            switch self {
            case .equal12:
                return [0, 100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100]
            case .just:
                // Major scale in just intonation
                return [0, 112, 204, 316, 386, 498, 590, 702, 814, 884, 996, 1088]
            case .pythagorean:
                return [0, 90, 204, 294, 408, 498, 612, 702, 792, 906, 996, 1110]
            case .meantone:
                // Quarter-comma meantone
                return [0, 76, 193, 310, 386, 503, 579, 697, 773, 890, 1007, 1083]
            case .equal24:
                return stride(from: 0.0, to: 1200.0, by: 50.0).map { $0 }
            case .equal53:
                return stride(from: 0.0, to: 1200.0, by: 22.64).map { $0 }
            }
        }
    }

    /// Set key with high precision
    /// - Parameters:
    ///   - note: MIDI note number (can be fractional for microtones)
    ///   - scale: Scale type for harmonic relationships
    func setKey(note: Double, scale: MicrotonalScale = .equal12) {
        rootNote = note
        // Recalculate harmonic series based on scale
        updateHarmonicSeriesForScale(scale)
    }

    /// Update harmonics for specific scale
    private func updateHarmonicSeriesForScale(_ scale: MicrotonalScale) {
        let effectiveFrequency = frequencyWithCents(tuningCents)
        var harmonics: [HarmonicComponent] = []

        let degrees = scale.degrees
        for (index, cents) in degrees.enumerated() {
            let freq = effectiveFrequency * pow(2.0, cents / 1200.0)
            harmonics.append(HarmonicComponent(
                number: index + 1,
                frequency: freq,
                amplitude: 1.0 / Double(index + 1),
                phase: 0.0
            ))
        }

        self.harmonicSeries = harmonics
    }

    /// Get frequency for scale degree with precise cents offset
    func frequencyForDegree(_ degree: Int, scale: MicrotonalScale, centsOffset: Double = 0) -> Double {
        let degrees = scale.degrees
        guard degree < degrees.count else { return baseFrequency }

        let totalCents = degrees[degree] + centsOffset + tuningCents
        return baseFrequency * pow(2.0, totalCents / 1200.0)
    }
}
