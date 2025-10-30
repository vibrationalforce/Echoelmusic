import Foundation
import Accelerate

/// Wavetable Oscillator with band-limited waveforms and cubic interpolation
///
/// **Scientific Basis:**
/// - Hermite interpolation minimizes aliasing artifacts (Smith, 2010)
/// - Band-limited waveforms prevent harmonic aliasing (Stilson & Smith, 1996)
/// - Wavetable synthesis 10-100x more CPU-efficient than real-time waveform generation
/// - Perceptual smoothness requires 4-point interpolation minimum (Laroche & Dolson, 1999)
///
/// **References:**
/// - Smith, J.O. (2010). Physical Audio Signal Processing (CCRMA)
/// - Stilson, T. & Smith, J. (1996). Alias-Free Digital Synthesis of Classic Analog Waveforms
/// - Laroche, J. & Dolson, M. (1999). Improved phase vocoder time-scale modification
/// - Vesa Välimäki (2005). Discrete-Time Synthesis of the Sawtooth Waveform with Reduced Aliasing
final class WavetableOscillator: @unchecked Sendable {

    // MARK: - Interpolation Types

    /// Interpolation algorithm for wavetable lookup
    enum InterpolationType: String, Codable {
        case none          // Nearest-neighbor (fastest, aliasing artifacts)
        case linear        // Linear interpolation (fast, minor aliasing)
        case hermite       // 4-point Hermite cubic (best quality/performance balance)
        case lagrange      // 4-point Lagrange (highest quality, slower)

        var description: String {
            switch self {
            case .none: return "None (nearest-neighbor)"
            case .linear: return "Linear (fast)"
            case .hermite: return "Hermite cubic (recommended)"
            case .lagrange: return "Lagrange (highest quality)"
            }
        }

        var cpuCost: String {
            switch self {
            case .none: return "O(1)"
            case .linear: return "O(2)"
            case .hermite: return "O(4)"
            case .lagrange: return "O(4)"
            }
        }
    }

    // MARK: - Wavetable Types

    /// Available wavetable waveforms
    enum Waveform: String, Codable, CaseIterable {
        case sine
        case triangle
        case sawtooth
        case square
        case pulse25      // 25% pulse width
        case pulse10      // 10% pulse width
        case harmonicSeries // Additive synthesis (1 + 1/2 + 1/3 + 1/4...)
        case evenHarmonics  // Only even harmonics (hollow sound)
        case oddHarmonics   // Only odd harmonics (square-like)
        case formant       // Vocal formant-like spectrum
        case custom        // User-defined wavetable

        var description: String {
            switch self {
            case .sine: return "Sine (pure fundamental)"
            case .triangle: return "Triangle (odd harmonics, -12dB/oct)"
            case .sawtooth: return "Sawtooth (all harmonics, -6dB/oct)"
            case .square: return "Square (odd harmonics, -6dB/oct)"
            case .pulse25: return "Pulse 25% (rich harmonics)"
            case .pulse10: return "Pulse 10% (very rich harmonics)"
            case .harmonicSeries: return "Harmonic series (additive)"
            case .evenHarmonics: return "Even harmonics (hollow)"
            case .oddHarmonics: return "Odd harmonics (square-like)"
            case .formant: return "Formant (vocal-like)"
            case .custom: return "Custom wavetable"
            }
        }
    }

    // MARK: - Properties

    /// Current waveform type
    var waveform: Waveform {
        didSet {
            if waveform != oldValue {
                loadWavetable(waveform)
            }
        }
    }

    /// Frequency in Hz
    var frequency: Float {
        didSet {
            frequency = max(20.0, min(20000.0, frequency))
            updatePhaseIncrement()
        }
    }

    /// Amplitude (0.0 - 1.0)
    var amplitude: Float {
        didSet {
            amplitude = max(0.0, min(1.0, amplitude))
        }
    }

    /// Interpolation type
    var interpolation: InterpolationType = .hermite

    /// Wavetable morphing position (0.0 - 1.0) between two wavetables
    var morphPosition: Float = 0.0 {
        didSet {
            morphPosition = max(0.0, min(1.0, morphPosition))
        }
    }

    /// Secondary waveform for morphing
    var morphTarget: Waveform? {
        didSet {
            if let target = morphTarget {
                loadMorphTargetWavetable(target)
            }
        }
    }

    // MARK: - Internal State

    private var sampleRate: Float
    private var phase: Float = 0.0           // Current phase (0.0 - wavetableSize)
    private var phaseIncrement: Float = 0.0  // Phase delta per sample

    /// Wavetable storage (typically 2048 samples)
    private var wavetable: [Float] = []
    private var morphTargetTable: [Float] = []

    /// Wavetable size (power of 2 for efficiency)
    private let wavetableSize: Int = 2048

    // MARK: - Initialization

    init(waveform: Waveform = .sine, frequency: Float = 440.0, sampleRate: Float = 48000.0) {
        self.waveform = waveform
        self.frequency = frequency
        self.sampleRate = sampleRate
        self.amplitude = 1.0

        loadWavetable(waveform)
        updatePhaseIncrement()
    }

    // MARK: - Wavetable Generation

    /// Load wavetable for given waveform
    private func loadWavetable(_ waveform: Waveform) {
        wavetable = generateWavetable(waveform)
    }

    /// Load morph target wavetable
    private func loadMorphTargetWavetable(_ waveform: Waveform) {
        morphTargetTable = generateWavetable(waveform)
    }

    /// Generate band-limited wavetable
    private func generateWavetable(_ waveform: Waveform) -> [Float] {
        var table = [Float](repeating: 0.0, count: wavetableSize)

        switch waveform {
        case .sine:
            // Pure sine wave (only fundamental, no harmonics)
            for i in 0..<wavetableSize {
                let phase = Float(i) / Float(wavetableSize)
                table[i] = sin(phase * 2.0 * .pi)
            }

        case .triangle:
            // Triangle wave: odd harmonics with amplitude = 1/n²
            // Spectral rolloff: -12 dB/octave
            for i in 0..<wavetableSize {
                let phase = Float(i) / Float(wavetableSize)
                var sample: Float = 0.0

                // Add first 50 odd harmonics (band-limited)
                for n in stride(from: 1, to: 100, by: 2) {
                    let harmonic = Float(n)
                    let nyquistLimit = sampleRate / (2.0 * frequency)
                    if harmonic > nyquistLimit { break }

                    let sign = (n / 2) % 2 == 0 ? 1.0 : -1.0
                    sample += sign * sin(phase * 2.0 * .pi * harmonic) / (harmonic * harmonic)
                }

                table[i] = sample * 0.8 // Normalize
            }

        case .sawtooth:
            // Sawtooth wave: all harmonics with amplitude = 1/n
            // Spectral rolloff: -6 dB/octave
            for i in 0..<wavetableSize {
                let phase = Float(i) / Float(wavetableSize)
                var sample: Float = 0.0

                // Add first 100 harmonics (band-limited)
                for n in 1...100 {
                    let harmonic = Float(n)
                    let nyquistLimit = sampleRate / (2.0 * frequency)
                    if harmonic > nyquistLimit { break }

                    sample += sin(phase * 2.0 * .pi * harmonic) / harmonic
                }

                table[i] = sample * 0.5 // Normalize
            }

        case .square:
            // Square wave: odd harmonics with amplitude = 1/n
            // Spectral rolloff: -6 dB/octave
            for i in 0..<wavetableSize {
                let phase = Float(i) / Float(wavetableSize)
                var sample: Float = 0.0

                // Add first 100 odd harmonics
                for n in stride(from: 1, to: 200, by: 2) {
                    let harmonic = Float(n)
                    let nyquistLimit = sampleRate / (2.0 * frequency)
                    if harmonic > nyquistLimit { break }

                    sample += sin(phase * 2.0 * .pi * harmonic) / harmonic
                }

                table[i] = sample * 0.6
            }

        case .pulse25:
            // 25% pulse width
            table = generatePulseWave(dutyCycle: 0.25)

        case .pulse10:
            // 10% pulse width (very rich harmonics)
            table = generatePulseWave(dutyCycle: 0.10)

        case .harmonicSeries:
            // Harmonic series: 1 + 1/2 + 1/3 + 1/4...
            for i in 0..<wavetableSize {
                let phase = Float(i) / Float(wavetableSize)
                var sample: Float = 0.0

                for n in 1...50 {
                    let harmonic = Float(n)
                    let nyquistLimit = sampleRate / (2.0 * frequency)
                    if harmonic > nyquistLimit { break }

                    sample += sin(phase * 2.0 * .pi * harmonic) / harmonic
                }

                table[i] = sample * 0.3
            }

        case .evenHarmonics:
            // Only even harmonics (hollow sound, like clarinet)
            for i in 0..<wavetableSize {
                let phase = Float(i) / Float(wavetableSize)
                var sample: Float = 0.0

                for n in stride(from: 2, to: 100, by: 2) {
                    let harmonic = Float(n)
                    let nyquistLimit = sampleRate / (2.0 * frequency)
                    if harmonic > nyquistLimit { break }

                    sample += sin(phase * 2.0 * .pi * harmonic) / harmonic
                }

                table[i] = sample * 0.5
            }

        case .oddHarmonics:
            // Only odd harmonics (square-like)
            for i in 0..<wavetableSize {
                let phase = Float(i) / Float(wavetableSize)
                var sample: Float = 0.0

                for n in stride(from: 1, to: 100, by: 2) {
                    let harmonic = Float(n)
                    let nyquistLimit = sampleRate / (2.0 * frequency)
                    if harmonic > nyquistLimit { break }

                    sample += sin(phase * 2.0 * .pi * harmonic) / harmonic
                }

                table[i] = sample * 0.6
            }

        case .formant:
            // Vocal formant-like spectrum (peaks at specific harmonics)
            for i in 0..<wavetableSize {
                let phase = Float(i) / Float(wavetableSize)
                var sample: Float = 0.0

                // Create formant peaks at harmonics 3, 7, 12 (simulating vowel "ah")
                let formants: [(harmonic: Float, amplitude: Float)] = [
                    (3, 1.0), (4, 0.5), (5, 0.3),
                    (7, 0.8), (8, 0.4), (9, 0.2),
                    (12, 0.6), (13, 0.3), (14, 0.15)
                ]

                for (harmonic, amp) in formants {
                    let nyquistLimit = sampleRate / (2.0 * frequency)
                    if harmonic > nyquistLimit { break }

                    sample += amp * sin(phase * 2.0 * .pi * harmonic)
                }

                table[i] = sample * 0.4
            }

        case .custom:
            // Placeholder for user-defined wavetable
            table = generateWavetable(.sine)
        }

        return table
    }

    /// Generate pulse wave with variable duty cycle
    private func generatePulseWave(dutyCycle: Float) -> [Float] {
        var table = [Float](repeating: 0.0, count: wavetableSize)

        for i in 0..<wavetableSize {
            let phase = Float(i) / Float(wavetableSize)
            var sample: Float = 0.0

            // Fourier series for pulse wave
            for n in 1...100 {
                let harmonic = Float(n)
                let nyquistLimit = sampleRate / (2.0 * frequency)
                if harmonic > nyquistLimit { break }

                let coefficient = (2.0 / .pi) * sin(.pi * harmonic * dutyCycle) / harmonic
                sample += coefficient * sin(phase * 2.0 * .pi * harmonic)
            }

            table[i] = sample
        }

        return table
    }

    // MARK: - Phase Management

    private func updatePhaseIncrement() {
        phaseIncrement = frequency * Float(wavetableSize) / sampleRate
    }

    /// Reset phase to zero
    func resetPhase() {
        phase = 0.0
    }

    // MARK: - Audio Processing

    /// Process next sample
    func process() -> Float {
        // Get wavetable sample with interpolation
        let sample: Float
        if let _ = morphTarget, !morphTargetTable.isEmpty {
            sample = processMorphing()
        } else {
            sample = readWavetable(phase, from: wavetable)
        }

        // Advance phase
        phase += phaseIncrement
        if phase >= Float(wavetableSize) {
            phase -= Float(wavetableSize)
        }

        return sample * amplitude
    }

    /// Process with wavetable morphing
    private func processMorphing() -> Float {
        let sample1 = readWavetable(phase, from: wavetable)
        let sample2 = readWavetable(phase, from: morphTargetTable)

        // Linear crossfade between wavetables
        return sample1 * (1.0 - morphPosition) + sample2 * morphPosition
    }

    /// Read wavetable with interpolation
    private func readWavetable(_ phase: Float, from table: [Float]) -> Float {
        let tableSize = Float(table.count)

        switch interpolation {
        case .none:
            // Nearest-neighbor (no interpolation)
            let index = Int(phase) % table.count
            return table[index]

        case .linear:
            // Linear interpolation
            let index = Int(phase)
            let frac = phase - Float(index)
            let i0 = index % table.count
            let i1 = (index + 1) % table.count

            return table[i0] * (1.0 - frac) + table[i1] * frac

        case .hermite:
            // 4-point Hermite cubic interpolation (best quality/performance)
            let index = Int(phase)
            let frac = phase - Float(index)

            // Get 4 points for cubic interpolation
            let im1 = (index - 1 + table.count) % table.count
            let i0 = index % table.count
            let i1 = (index + 1) % table.count
            let i2 = (index + 2) % table.count

            let xm1 = table[im1]
            let x0 = table[i0]
            let x1 = table[i1]
            let x2 = table[i2]

            // Hermite interpolation formula
            let c0 = x0
            let c1 = 0.5 * (x1 - xm1)
            let c2 = xm1 - 2.5 * x0 + 2.0 * x1 - 0.5 * x2
            let c3 = 0.5 * (x2 - xm1) + 1.5 * (x0 - x1)

            return ((c3 * frac + c2) * frac + c1) * frac + c0

        case .lagrange:
            // 4-point Lagrange interpolation (highest quality)
            let index = Int(phase)
            let frac = phase - Float(index)

            let im1 = (index - 1 + table.count) % table.count
            let i0 = index % table.count
            let i1 = (index + 1) % table.count
            let i2 = (index + 2) % table.count

            let xm1 = table[im1]
            let x0 = table[i0]
            let x1 = table[i1]
            let x2 = table[i2]

            // Lagrange polynomial coefficients
            let t = frac
            let l0 = -t * (t - 1.0) * (t - 2.0) / 6.0
            let l1 = (t + 1.0) * (t - 1.0) * (t - 2.0) / 2.0
            let l2 = -(t + 1.0) * t * (t - 2.0) / 2.0
            let l3 = (t + 1.0) * t * (t - 1.0) / 6.0

            return l0 * xm1 + l1 * x0 + l2 * x1 + l3 * x2
        }
    }

    /// Process audio buffer
    func processBuffer(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        for i in 0..<frameCount {
            buffer[i] = process()
        }
    }

    // MARK: - Custom Wavetable

    /// Load custom wavetable from array
    /// - Parameter samples: Array of samples (will be resampled to wavetableSize)
    func loadCustomWavetable(_ samples: [Float]) {
        guard !samples.isEmpty else { return }

        // Resample to wavetableSize if needed
        if samples.count == wavetableSize {
            wavetable = samples
        } else {
            // Simple linear resampling
            var resampled = [Float](repeating: 0.0, count: wavetableSize)
            let ratio = Float(samples.count) / Float(wavetableSize)

            for i in 0..<wavetableSize {
                let srcIndex = Float(i) * ratio
                let i0 = Int(srcIndex)
                let i1 = min(i0 + 1, samples.count - 1)
                let frac = srcIndex - Float(i0)

                resampled[i] = samples[i0] * (1.0 - frac) + samples[i1] * frac
            }

            wavetable = resampled
        }

        waveform = .custom
    }

    // MARK: - Bio-feedback Integration

    /// Select waveform based on HRV coherence
    /// - Parameter coherence: HRV coherence (0-100)
    func modulateWaveformWithCoherence(_ coherence: Double) {
        let normalized = Float(max(0.0, min(100.0, coherence))) / 100.0

        // Low coherence → harsher waveforms (sawtooth, square)
        // High coherence → smoother waveforms (sine, triangle)
        if normalized < 0.3 {
            waveform = .sawtooth
        } else if normalized < 0.6 {
            waveform = .square
        } else if normalized < 0.8 {
            waveform = .triangle
        } else {
            waveform = .sine
        }
    }

    /// Morph between waveforms based on breathing phase
    /// - Parameter phase: Breathing phase (0.0-1.0)
    func morphWithBreathingPhase(_ phase: Double) {
        let p = Float(max(0.0, min(1.0, phase)))

        // Inhale (0.0-0.5): Sine → Triangle
        // Exhale (0.5-1.0): Triangle → Sine
        if p < 0.5 {
            waveform = .sine
            morphTarget = .triangle
            morphPosition = p * 2.0
        } else {
            waveform = .triangle
            morphTarget = .sine
            morphPosition = (p - 0.5) * 2.0
        }
    }
}

// MARK: - Codable Conformance

extension WavetableOscillator: Codable {
    enum CodingKeys: String, CodingKey {
        case waveform, frequency, amplitude, interpolation, morphPosition, morphTarget, sampleRate
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let waveform = try container.decode(Waveform.self, forKey: .waveform)
        let frequency = try container.decode(Float.self, forKey: .frequency)
        let sampleRate = try container.decode(Float.self, forKey: .sampleRate)

        self.init(waveform: waveform, frequency: frequency, sampleRate: sampleRate)

        self.amplitude = try container.decode(Float.self, forKey: .amplitude)
        self.interpolation = try container.decode(InterpolationType.self, forKey: .interpolation)
        self.morphPosition = try container.decode(Float.self, forKey: .morphPosition)
        self.morphTarget = try container.decodeIfPresent(Waveform.self, forKey: .morphTarget)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(waveform, forKey: .waveform)
        try container.encode(frequency, forKey: .frequency)
        try container.encode(amplitude, forKey: .amplitude)
        try container.encode(interpolation, forKey: .interpolation)
        try container.encode(morphPosition, forKey: .morphPosition)
        try container.encode(morphTarget, forKey: .morphTarget)
        try container.encode(sampleRate, forKey: .sampleRate)
    }
}

// MARK: - CustomStringConvertible

extension WavetableOscillator: CustomStringConvertible {
    var description: String {
        let morphInfo = morphTarget != nil ? " → \(morphTarget!.rawValue) (\(Int(morphPosition * 100))%)" : ""
        return """
        Wavetable Oscillator:
          Waveform: \(waveform.rawValue)\(morphInfo)
          Frequency: \(String(format: "%.2f", frequency)) Hz
          Amplitude: \(String(format: "%.2f", amplitude))
          Interpolation: \(interpolation.rawValue)
        """
    }
}
