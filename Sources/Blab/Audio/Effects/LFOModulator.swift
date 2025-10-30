import Foundation
import Accelerate

/// Low Frequency Oscillator (LFO) for parameter modulation
///
/// **Scientific Basis:**
/// - Vibrato rates: 4-8 Hz optimal for musical expressiveness (Gabrielsson, 1988)
/// - Tremolo perception: Linear amplitude mod < 5 Hz sounds like pulsing (Zwicker & Fastl, 2007)
/// - Pink noise (1/f) more musical than white noise (Voss & Clarke, 1975)
/// - Chaos theory: Lorenz attractor for organic, non-repetitive modulation
///
/// **References:**
/// - Gabrielsson, A. (1988). Timing in music performance
/// - Roads, C. (1996). Computer Music Tutorial (pp. 209-234)
/// - De Poli, G. (1983). A tutorial on digital sound synthesis techniques
final class LFOModulator: @unchecked Sendable {

    // MARK: - Waveform Types

    /// LFO waveform shapes
    enum Waveform: String, Codable, CaseIterable {
        case sine          // Smooth, natural modulation (most musical)
        case triangle      // Linear ramp up/down
        case sawUp         // Rising sawtooth (ramping up)
        case sawDown       // Falling sawtooth (ramping down)
        case square        // Binary on/off (tremolo/trill effect)
        case random        // Smooth random (pink noise filtered)
        case sampleHold    // Stepped random (stepped changes)
        case chaos         // Lorenz attractor (organic non-repetitive)

        var description: String {
            switch self {
            case .sine: return "Sine (smooth, natural)"
            case .triangle: return "Triangle (linear)"
            case .sawUp: return "Sawtooth Up (ramp rise)"
            case .sawDown: return "Sawtooth Down (ramp fall)"
            case .square: return "Square (binary switch)"
            case .random: return "Random (smooth noise)"
            case .sampleHold: return "Sample & Hold (stepped)"
            case .chaos: return "Chaos (Lorenz attractor)"
            }
        }

        /// Typical use cases
        var usageExample: String {
            switch self {
            case .sine: return "Vibrato, slow filter sweeps"
            case .triangle: return "Linear fades, simple modulation"
            case .sawUp: return "Rising pitch glides, crescendos"
            case .sawDown: return "Falling pitch glides, decrescendos"
            case .square: return "Tremolo, hard panning, trills"
            case .random: return "Organic texture, natural variation"
            case .sampleHold: return "Retro sequencer, stepped arpeggios"
            case .chaos: return "Unpredictable, evolving textures"
            }
        }
    }

    // MARK: - Sync Mode

    /// LFO synchronization mode
    enum SyncMode: String, Codable {
        case freeRunning   // Independent of tempo
        case tempoSync     // Locked to BPM (musical divisions)
        case breathSync    // Synchronized to breathing rate

        var description: String {
            switch self {
            case .freeRunning: return "Free-running (Hz)"
            case .tempoSync: return "Tempo-synced (BPM)"
            case .breathSync: return "Breath-synced (bio)"
            }
        }
    }

    // MARK: - Properties

    /// Current waveform
    var waveform: Waveform {
        didSet { if waveform != oldValue { resetPhase() } }
    }

    /// LFO frequency in Hz (0.01 - 20.0 Hz)
    /// Typical ranges:
    /// - Vibrato: 4-8 Hz
    /// - Tremolo: 3-6 Hz
    /// - Slow sweeps: 0.1-1 Hz
    var frequency: Float {
        didSet { frequency = max(0.01, min(20.0, frequency)) }
    }

    /// Modulation depth (0.0 - 1.0)
    var depth: Float {
        didSet { depth = max(0.0, min(1.0, depth)) }
    }

    /// Phase offset (0.0 - 1.0, where 1.0 = 360°)
    var phaseOffset: Float {
        didSet { phaseOffset = fmod(phaseOffset, 1.0) }
    }

    /// Sync mode
    var syncMode: SyncMode = .freeRunning

    /// Tempo (BPM) for tempo-sync mode
    var tempo: Float = 120.0 {
        didSet { tempo = max(20.0, min(300.0, tempo)) }
    }

    /// Breathing rate (breaths per minute) for breath-sync mode
    var breathingRate: Float = 15.0 {
        didSet { breathingRate = max(4.0, min(30.0, breathingRate)) }
    }

    // MARK: - Internal State

    private var sampleRate: Float
    private var phase: Float = 0.0              // Current phase (0.0 - 1.0)
    private var phaseIncrement: Float = 0.0     // Phase delta per sample

    // Random/Noise state
    private var randomValue: Float = 0.0
    private var targetRandomValue: Float = 0.0
    private var randomSmoothingFactor: Float = 0.995

    // Sample & Hold state
    private var sampleHoldValue: Float = 0.0
    private var lastSamplePhase: Float = 0.0

    // Chaos state (Lorenz attractor)
    private var chaosX: Float = 1.0
    private var chaosY: Float = 0.0
    private var chaosZ: Float = 0.0
    private let sigma: Float = 10.0      // Prandtl number
    private let rho: Float = 28.0        // Rayleigh number
    private let beta: Float = 8.0 / 3.0  // Aspect ratio

    // MARK: - Initialization

    init(frequency: Float = 1.0, sampleRate: Float = 48000.0) {
        self.frequency = frequency
        self.sampleRate = sampleRate
        self.waveform = .sine
        self.depth = 1.0
        self.phaseOffset = 0.0
        updatePhaseIncrement()
    }

    // MARK: - Phase Management

    /// Reset phase to start (with phase offset)
    func resetPhase() {
        phase = phaseOffset
        lastSamplePhase = 0.0

        // Re-seed chaos
        chaosX = 1.0
        chaosY = 0.0
        chaosZ = 0.0
    }

    /// Update phase increment based on current settings
    private func updatePhaseIncrement() {
        let effectiveFrequency: Float

        switch syncMode {
        case .freeRunning:
            effectiveFrequency = frequency

        case .tempoSync:
            // Convert BPM to Hz (assuming quarter note divisions)
            effectiveFrequency = tempo / 60.0

        case .breathSync:
            // Convert breaths/min to Hz
            effectiveFrequency = breathingRate / 60.0
        }

        phaseIncrement = effectiveFrequency / sampleRate
    }

    // MARK: - Audio Processing

    /// Process next sample
    /// - Returns: Modulation value (bipolar: -1.0 to +1.0, or unipolar: 0.0 to 1.0 depending on waveform)
    func process() -> Float {
        updatePhaseIncrement()

        // Generate waveform
        let rawValue: Float
        switch waveform {
        case .sine:
            rawValue = sin(phase * 2.0 * .pi)

        case .triangle:
            rawValue = abs(fmod(phase + 0.25, 1.0) * 4.0 - 2.0) - 1.0

        case .sawUp:
            rawValue = fmod(phase, 1.0) * 2.0 - 1.0

        case .sawDown:
            rawValue = 1.0 - fmod(phase, 1.0) * 2.0

        case .square:
            rawValue = fmod(phase, 1.0) < 0.5 ? -1.0 : 1.0

        case .random:
            rawValue = processRandom()

        case .sampleHold:
            rawValue = processSampleHold()

        case .chaos:
            rawValue = processChaos()
        }

        // Advance phase
        phase += phaseIncrement
        if phase >= 1.0 {
            phase -= 1.0
        }

        // Apply depth (scaled to bipolar -depth to +depth)
        return rawValue * depth
    }

    /// Get unipolar output (0.0 to 1.0)
    /// Useful for amplitude modulation, filter cutoff, etc.
    func processUnipolar() -> Float {
        let bipolar = process()
        return (bipolar + 1.0) * 0.5 * depth
    }

    // MARK: - Waveform Generators

    /// Generate smooth random modulation (pink-noise-like)
    private func processRandom() -> Float {
        // Smooth interpolation to new random target
        if abs(randomValue - targetRandomValue) < 0.01 {
            targetRandomValue = Float.random(in: -1.0...1.0)
        }
        randomValue = randomValue * randomSmoothingFactor + targetRandomValue * (1.0 - randomSmoothingFactor)
        return randomValue
    }

    /// Generate stepped random modulation (sample & hold)
    private func processSampleHold() -> Float {
        let currentPhase = fmod(phase, 1.0)

        // Update value when phase crosses zero
        if currentPhase < lastSamplePhase {
            sampleHoldValue = Float.random(in: -1.0...1.0)
        }
        lastSamplePhase = currentPhase

        return sampleHoldValue
    }

    /// Generate chaotic modulation using Lorenz attractor
    /// Lorenz system: dx/dt = σ(y-x), dy/dt = x(ρ-z)-y, dz/dt = xy-βz
    private func processChaos() -> Float {
        let dt: Float = 0.01

        // Update Lorenz equations
        let dx = sigma * (chaosY - chaosX)
        let dy = chaosX * (rho - chaosZ) - chaosY
        let dz = chaosX * chaosY - beta * chaosZ

        chaosX += dx * dt
        chaosY += dy * dt
        chaosZ += dz * dt

        // Normalize X coordinate to -1...1 range (typical X range: -20...20)
        let normalized = chaosX / 20.0
        return max(-1.0, min(1.0, normalized))
    }

    // MARK: - Buffer Processing

    /// Process entire buffer with LFO modulation
    /// - Parameters:
    ///   - buffer: Input/output buffer
    ///   - frameCount: Number of frames
    ///   - bipolar: If true, uses bipolar (-1 to 1), else unipolar (0 to 1)
    func processBuffer(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int, bipolar: Bool = false) {
        for i in 0..<frameCount {
            let modulation = bipolar ? process() : processUnipolar()
            buffer[i] *= (1.0 + modulation)  // Multiply by modulated gain
        }
    }

    /// Get modulation curve for visualization
    /// - Parameter samples: Number of samples to generate
    /// - Returns: Array of LFO values
    func getWaveformPreview(samples: Int = 512) -> [Float] {
        let savedPhase = phase
        resetPhase()

        var preview = [Float](repeating: 0.0, count: samples)
        for i in 0..<samples {
            preview[i] = processUnipolar()
        }

        phase = savedPhase
        return preview
    }

    // MARK: - Modulation Presets

    /// Common LFO presets for musical applications
    enum Preset {
        case vibrato       // Classic vocal/string vibrato (5-7 Hz sine)
        case tremolo       // Amplitude pulsing (4-6 Hz sine)
        case slowSweep     // Filter sweep (0.2-0.5 Hz triangle)
        case fastTrill     // Rapid alternation (8-12 Hz square)
        case organicDrift  // Slow random drift (0.1-0.3 Hz random)
        case steppedArp    // Retro sequencer (2-4 Hz sample&hold)
        case chaosTexture  // Unpredictable evolution (1-2 Hz chaos)
        case breathSync    // Breathing-synchronized (0.2-0.4 Hz sine)

        var parameters: (waveform: Waveform, frequency: Float, depth: Float) {
            switch self {
            case .vibrato:
                return (.sine, 6.0, 0.3)
            case .tremolo:
                return (.sine, 5.0, 0.5)
            case .slowSweep:
                return (.triangle, 0.3, 0.7)
            case .fastTrill:
                return (.square, 10.0, 1.0)
            case .organicDrift:
                return (.random, 0.2, 0.4)
            case .steppedArp:
                return (.sampleHold, 3.0, 0.8)
            case .chaosTexture:
                return (.chaos, 1.5, 0.6)
            case .breathSync:
                return (.sine, 0.25, 0.8)  // 15 breaths/min = 0.25 Hz
            }
        }
    }

    /// Apply preset
    func applyPreset(_ preset: Preset) {
        let params = preset.parameters
        waveform = params.waveform
        frequency = params.frequency
        depth = params.depth

        if preset == .breathSync {
            syncMode = .breathSync
        } else {
            syncMode = .freeRunning
        }
    }

    // MARK: - Bio-feedback Integration

    /// Modulate LFO rate based on HRV coherence
    /// - Parameter coherence: HRV coherence (0-100)
    /// - Note: High coherence → slower, deeper modulation (relaxed state)
    func modulateWithCoherence(_ coherence: Double) {
        let normalized = Float(max(0.0, min(100.0, coherence))) / 100.0

        // High coherence → slower frequency, deeper modulation
        if syncMode == .freeRunning {
            frequency = 0.5 + (1.0 - normalized) * 5.0  // 5.5 Hz (agitated) → 0.5 Hz (calm)
        }
        depth = 0.3 + normalized * 0.7  // 30% → 100%
    }

    /// Synchronize LFO to breathing phase
    /// - Parameter phase: Breathing cycle phase (0.0-1.0)
    func syncToBreathingPhase(_ phase: Double) {
        if syncMode == .breathSync {
            self.phase = Float(phase)
        }
    }

    /// Modulate based on heart rate variability
    /// - Parameter hrvRMSSD: RMSSD value (ms)
    /// - Note: Higher HRV → more organic, slower modulation
    func modulateWithHRV(_ hrvRMSSD: Double) {
        let normalized = Float(min(100.0, max(0.0, hrvRMSSD))) / 100.0

        // High HRV → prefer organic waveforms
        if normalized > 0.6 && waveform == .sine {
            waveform = .random
        }

        randomSmoothingFactor = 0.99 + normalized * 0.009  // 0.99 → 0.999 (smoother)
    }
}

// MARK: - Codable Conformance

extension LFOModulator: Codable {
    enum CodingKeys: String, CodingKey {
        case waveform, frequency, depth, phaseOffset
        case syncMode, tempo, breathingRate, sampleRate
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let sampleRate = try container.decode(Float.self, forKey: .sampleRate)
        let frequency = try container.decode(Float.self, forKey: .frequency)
        self.init(frequency: frequency, sampleRate: sampleRate)

        self.waveform = try container.decode(Waveform.self, forKey: .waveform)
        self.depth = try container.decode(Float.self, forKey: .depth)
        self.phaseOffset = try container.decode(Float.self, forKey: .phaseOffset)
        self.syncMode = try container.decode(SyncMode.self, forKey: .syncMode)
        self.tempo = try container.decode(Float.self, forKey: .tempo)
        self.breathingRate = try container.decode(Float.self, forKey: .breathingRate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(waveform, forKey: .waveform)
        try container.encode(frequency, forKey: .frequency)
        try container.encode(depth, forKey: .depth)
        try container.encode(phaseOffset, forKey: .phaseOffset)
        try container.encode(syncMode, forKey: .syncMode)
        try container.encode(tempo, forKey: .tempo)
        try container.encode(breathingRate, forKey: .breathingRate)
        try container.encode(sampleRate, forKey: .sampleRate)
    }
}

// MARK: - CustomStringConvertible

extension LFOModulator: CustomStringConvertible {
    var description: String {
        let freqStr = String(format: "%.2f Hz", frequency)
        let depthStr = String(format: "%.0f%%", depth * 100)
        return "LFO: \(waveform.rawValue) @ \(freqStr), Depth: \(depthStr), Mode: \(syncMode.rawValue)"
    }
}

// MARK: - Modulation Targets

/// Helper for common modulation targets
extension LFOModulator {

    /// Apply LFO to filter cutoff frequency
    /// - Parameters:
    ///   - baseCutoff: Base cutoff frequency (Hz)
    ///   - range: Modulation range (Hz)
    /// - Returns: Modulated cutoff frequency
    func modulateFilterCutoff(baseCutoff: Float, range: Float) -> Float {
        let modulation = processUnipolar()
        return baseCutoff + (modulation - 0.5) * range
    }

    /// Apply LFO to amplitude (tremolo)
    /// - Parameter baseAmplitude: Base amplitude (0.0-1.0)
    /// - Returns: Modulated amplitude
    func modulateAmplitude(baseAmplitude: Float) -> Float {
        let modulation = processUnipolar()
        return baseAmplitude * modulation
    }

    /// Apply LFO to pitch (vibrato)
    /// - Parameters:
    ///   - basePitch: Base pitch (Hz)
    ///   - cents: Modulation range in cents (100 cents = 1 semitone)
    /// - Returns: Modulated pitch
    func modulatePitch(basePitch: Float, cents: Float) -> Float {
        let modulation = process()  // Bipolar
        let semitones = (cents / 100.0) * modulation
        return basePitch * pow(2.0, semitones / 12.0)
    }

    /// Apply LFO to stereo pan
    /// - Returns: Pan value (-1.0 = full left, +1.0 = full right)
    func modulatePan() -> Float {
        return process()  // Bipolar -1 to +1
    }
}
