import Foundation
import AVFoundation

/// ADSR Envelope Generator with psychoacoustically optimized curves
///
/// **Scientific Basis:**
/// - Exponential curves match human loudness perception (Fletcher-Munson curves)
/// - Logarithmic release mimics natural acoustic decay
/// - Attack times < 10ms perceived as instantaneous (Fastl & Zwicker, 2007)
/// - Optimal decay range: 50-500ms for musical expressiveness
///
/// **References:**
/// - Fastl, H., & Zwicker, E. (2007). Psychoacoustics: Facts and Models
/// - Roads, C. (1996). The Computer Music Tutorial (pp. 115-139)
/// - Smith, J.O. (2010). Physical Audio Signal Processing
final class ADSREnvelope: @unchecked Sendable {

    // MARK: - Curve Types

    /// Envelope curve shape (affects perceptual quality)
    enum CurveType: String, Codable, CaseIterable {
        case linear       // Simple linear ramp
        case exponential  // Natural attack/decay (default for most instruments)
        case logarithmic  // Smooth fade-out (ideal for release)
        case sCurve       // Sigmoid-based smooth transition

        var description: String {
            switch self {
            case .linear: return "Linear (constant rate)"
            case .exponential: return "Exponential (natural perception)"
            case .logarithmic: return "Logarithmic (smooth fade)"
            case .sCurve: return "S-Curve (smooth acceleration)"
            }
        }
    }

    // MARK: - Envelope State

    enum State {
        case idle
        case attack
        case decay
        case sustain
        case release
    }

    // MARK: - Properties

    /// Current envelope state
    private(set) var state: State = .idle

    /// Current envelope amplitude (0.0 - 1.0)
    private(set) var currentLevel: Float = 0.0

    /// Attack time in seconds (0.001 - 5.0s)
    var attackTime: Float {
        didSet { attackTime = max(0.001, min(5.0, attackTime)) }
    }

    /// Decay time in seconds (0.001 - 5.0s)
    var decayTime: Float {
        didSet { decayTime = max(0.001, min(5.0, decayTime)) }
    }

    /// Sustain level (0.0 - 1.0)
    var sustainLevel: Float {
        didSet { sustainLevel = max(0.0, min(1.0, sustainLevel)) }
    }

    /// Release time in seconds (0.001 - 10.0s)
    var releaseTime: Float {
        didSet { releaseTime = max(0.001, min(10.0, releaseTime)) }
    }

    /// Curve type for attack phase
    var attackCurve: CurveType

    /// Curve type for decay phase
    var decayCurve: CurveType

    /// Curve type for release phase
    var releaseCurve: CurveType

    // MARK: - Internal State

    private var sampleRate: Float
    private var currentSample: Int = 0
    private var releaseStartLevel: Float = 0.0

    // Curve smoothing parameters (prevent zipper noise)
    private let minOutput: Float = 0.0001  // -80 dB
    private let expCurveFactor: Float = 5.0 // Exponential steepness

    // MARK: - Initialization

    /// Initialize ADSR with default values (typical synthesizer envelope)
    /// - Parameter sampleRate: Audio sample rate (typically 48000 Hz)
    init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate

        // Default values based on psychoacoustic research
        self.attackTime = 0.01      // 10ms (perceived as instant)
        self.decayTime = 0.1        // 100ms (natural decay)
        self.sustainLevel = 0.7     // 70% (-3 dB)
        self.releaseTime = 0.3      // 300ms (natural release)

        // Optimal curve types for natural sound
        self.attackCurve = .exponential    // Fast rise, smooth peak
        self.decayCurve = .exponential     // Natural decay
        self.releaseCurve = .logarithmic   // Smooth fade-out
    }

    // MARK: - Control Methods

    /// Trigger envelope (start attack phase)
    func trigger() {
        state = .attack
        currentSample = 0
    }

    /// Release envelope (start release phase)
    func release() {
        guard state != .idle && state != .release else { return }
        state = .release
        releaseStartLevel = currentLevel
        currentSample = 0
    }

    /// Force envelope to idle state
    func reset() {
        state = .idle
        currentLevel = 0.0
        currentSample = 0
    }

    /// Check if envelope is active (not idle)
    var isActive: Bool {
        state != .idle
    }

    // MARK: - Audio Processing

    /// Process next sample (call once per audio sample)
    /// - Returns: Current envelope level (0.0 - 1.0)
    func process() -> Float {
        switch state {
        case .idle:
            currentLevel = 0.0

        case .attack:
            let attackSamples = Int(attackTime * sampleRate)
            if currentSample >= attackSamples {
                state = .decay
                currentSample = 0
                currentLevel = 1.0
            } else {
                let progress = Float(currentSample) / Float(attackSamples)
                currentLevel = applyCurve(progress, type: attackCurve)
                currentSample += 1
            }

        case .decay:
            let decaySamples = Int(decayTime * sampleRate)
            if currentSample >= decaySamples {
                state = .sustain
                currentLevel = sustainLevel
            } else {
                let progress = Float(currentSample) / Float(decaySamples)
                currentLevel = 1.0 - (1.0 - sustainLevel) * applyCurve(progress, type: decayCurve)
                currentSample += 1
            }

        case .sustain:
            currentLevel = sustainLevel

        case .release:
            let releaseSamples = Int(releaseTime * sampleRate)
            if currentSample >= releaseSamples {
                state = .idle
                currentLevel = 0.0
            } else {
                let progress = Float(currentSample) / Float(releaseSamples)
                currentLevel = releaseStartLevel * (1.0 - applyCurve(progress, type: releaseCurve))
                currentSample += 1
            }
        }

        return currentLevel
    }

    /// Process audio buffer with envelope
    /// - Parameters:
    ///   - buffer: Input/output audio buffer
    ///   - frameCount: Number of frames to process
    func processBuffer(_ buffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        for i in 0..<frameCount {
            let envelope = process()
            buffer[i] *= envelope
        }
    }

    // MARK: - Curve Shaping Functions

    /// Apply curve shaping to linear progress (0.0 - 1.0)
    /// - Parameters:
    ///   - progress: Linear progress (0.0 - 1.0)
    ///   - type: Curve type
    /// - Returns: Shaped output (0.0 - 1.0)
    private func applyCurve(_ progress: Float, type: CurveType) -> Float {
        let p = max(0.0, min(1.0, progress)) // Clamp to [0, 1]

        switch type {
        case .linear:
            return p

        case .exponential:
            // Exponential: y = (e^(kx) - 1) / (e^k - 1)
            // Matches logarithmic loudness perception
            let k = expCurveFactor
            return (exp(k * p) - 1.0) / (exp(k) - 1.0)

        case .logarithmic:
            // Logarithmic: y = log(1 + kx) / log(1 + k)
            // Smooth fade-out (perceived as linear volume decrease)
            let k = expCurveFactor
            return log(1.0 + k * p) / log(1.0 + k)

        case .sCurve:
            // Sigmoid S-curve: y = 1 / (1 + e^(-k(x - 0.5)))
            // Smooth acceleration and deceleration
            let k: Float = 10.0
            let normalized = 1.0 / (1.0 + exp(-k * (p - 0.5)))
            let min = 1.0 / (1.0 + exp(k * 0.5))
            let max = 1.0 / (1.0 + exp(-k * 0.5))
            return (normalized - min) / (max - min)
        }
    }

    // MARK: - Presets

    /// Factory presets based on common synthesis applications
    enum Preset {
        case instant      // No envelope (immediate on/off)
        case percussive   // Fast attack, no sustain (drums)
        case plucked      // Fast attack, medium decay (guitar, harp)
        case bowed        // Slow attack, high sustain (strings, voice)
        case pad          // Very slow attack, sustained (ambient pads)
        case breath       // Bio-feedback optimized (breathing-synchronized)

        var parameters: (attack: Float, decay: Float, sustain: Float, release: Float) {
            switch self {
            case .instant:
                return (0.001, 0.001, 1.0, 0.001)
            case .percussive:
                return (0.005, 0.1, 0.0, 0.05)
            case .plucked:
                return (0.01, 0.3, 0.2, 0.2)
            case .bowed:
                return (0.5, 0.2, 0.8, 0.5)
            case .pad:
                return (2.0, 1.0, 0.9, 3.0)
            case .breath:
                // Synchronized with typical breathing rate (12-20 breaths/min)
                // Attack: Inhalation (2-3s), Release: Exhalation (3-4s)
                return (2.5, 0.5, 0.85, 3.5)
            }
        }

        var curves: (attack: CurveType, decay: CurveType, release: CurveType) {
            switch self {
            case .instant:
                return (.linear, .linear, .linear)
            case .percussive:
                return (.exponential, .exponential, .exponential)
            case .plucked:
                return (.exponential, .exponential, .logarithmic)
            case .bowed:
                return (.sCurve, .exponential, .sCurve)
            case .pad:
                return (.logarithmic, .logarithmic, .logarithmic)
            case .breath:
                return (.sCurve, .exponential, .sCurve)
            }
        }
    }

    /// Apply a preset
    func applyPreset(_ preset: Preset) {
        let params = preset.parameters
        let curves = preset.curves

        attackTime = params.attack
        decayTime = params.decay
        sustainLevel = params.sustain
        releaseTime = params.release

        attackCurve = curves.attack
        decayCurve = curves.decay
        releaseCurve = curves.release
    }

    // MARK: - Bio-feedback Integration

    /// Map HRV coherence to envelope parameters
    /// - Parameter coherence: HRV coherence score (0-100)
    /// - Note: High coherence → smoother, longer envelopes (relaxed state)
    func modulateWithCoherence(_ coherence: Double) {
        let normalized = Float(max(0.0, min(100.0, coherence))) / 100.0

        // High coherence → longer, smoother envelopes
        attackTime = 0.01 + normalized * 2.0     // 10ms - 2.01s
        releaseTime = 0.1 + normalized * 4.0     // 100ms - 4.1s

        // High coherence → prefer smooth curves
        if normalized > 0.6 {
            attackCurve = .sCurve
            releaseCurve = .sCurve
        }
    }

    /// Map breathing phase (0.0-1.0) to envelope trigger/release
    /// - Parameter phase: Breathing cycle phase (0.0 = start inhale, 0.5 = start exhale, 1.0 = end cycle)
    func syncWithBreathingPhase(_ phase: Double) {
        let p = Float(phase)

        if p < 0.45 {
            // Inhalation phase (0.0 - 0.45)
            if state == .idle || state == .release {
                trigger()
            }
        } else if p > 0.55 {
            // Exhalation phase (0.55 - 1.0)
            if state == .attack || state == .decay || state == .sustain {
                release()
            }
        }
    }
}

// MARK: - Codable Conformance

extension ADSREnvelope: Codable {
    enum CodingKeys: String, CodingKey {
        case attackTime, decayTime, sustainLevel, releaseTime
        case attackCurve, decayCurve, releaseCurve
        case sampleRate
    }

    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let sampleRate = try container.decode(Float.self, forKey: .sampleRate)
        self.init(sampleRate: sampleRate)

        self.attackTime = try container.decode(Float.self, forKey: .attackTime)
        self.decayTime = try container.decode(Float.self, forKey: .decayTime)
        self.sustainLevel = try container.decode(Float.self, forKey: .sustainLevel)
        self.releaseTime = try container.decode(Float.self, forKey: .releaseTime)

        self.attackCurve = try container.decode(CurveType.self, forKey: .attackCurve)
        self.decayCurve = try container.decode(CurveType.self, forKey: .decayCurve)
        self.releaseCurve = try container.decode(CurveType.self, forKey: .releaseCurve)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(attackTime, forKey: .attackTime)
        try container.encode(decayTime, forKey: .decayTime)
        try container.encode(sustainLevel, forKey: .sustainLevel)
        try container.encode(releaseTime, forKey: .releaseTime)
        try container.encode(attackCurve, forKey: .attackCurve)
        try container.encode(decayCurve, forKey: .decayCurve)
        try container.encode(releaseCurve, forKey: .releaseCurve)
        try container.encode(sampleRate, forKey: .sampleRate)
    }
}

// MARK: - CustomStringConvertible

extension ADSREnvelope: CustomStringConvertible {
    var description: String {
        """
        ADSR Envelope:
          State: \(state)
          Level: \(String(format: "%.2f", currentLevel))
          A: \(String(format: "%.3f", attackTime))s (\(attackCurve.rawValue))
          D: \(String(format: "%.3f", decayTime))s (\(decayCurve.rawValue))
          S: \(String(format: "%.2f", sustainLevel))
          R: \(String(format: "%.3f", releaseTime))s (\(releaseCurve.rawValue))
        """
    }
}
