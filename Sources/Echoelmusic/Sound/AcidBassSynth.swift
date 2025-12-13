import Foundation
import Accelerate

/// TB-303 Style Acid Bass Synthesizer
///
/// Authentic recreation of the Roland TB-303 Bass Line synthesizer.
/// The 303's unique sound comes from its specific filter design and
/// accent/slide behavior that creates the classic "acid" sound.
///
/// Technical specifications (based on original hardware analysis):
/// - Single VCO: Sawtooth or Square wave
/// - 4-pole (24dB/oct) lowpass filter with resonance
/// - VCA with accent circuit
/// - Slide (portamento) between notes
/// - Unique envelope generator behavior
///
/// References:
/// - "Secrets of the Bass Line" - Robin Whittle's 303 analysis
/// - "Devil Fish" TB-303 modifications documentation
/// - Roland TB-303 Service Manual
@MainActor
class AcidBassSynth: ObservableObject {

    // MARK: - Published Parameters

    /// Waveform selection
    @Published var waveform: Waveform = .sawtooth

    /// Filter cutoff frequency (Hz) - Range: 30-5000 Hz
    @Published var cutoff: Double = 500.0 {
        didSet { updateFilterCoefficients() }
    }

    /// Filter resonance (0-1, self-oscillation at ~0.95)
    @Published var resonance: Double = 0.5 {
        didSet { updateFilterCoefficients() }
    }

    /// Envelope modulation depth (0-1)
    @Published var envMod: Double = 0.5

    /// Envelope decay time (ms) - Range: 16-3000ms (original: 16-3000)
    @Published var decay: Double = 200.0

    /// Accent amount (0-1) - The 303's secret sauce
    @Published var accent: Double = 0.5

    /// Slide time (ms) - Portamento between notes
    @Published var slideTime: Double = 60.0

    /// Distortion/Overdrive (0-1)
    @Published var distortion: Double = 0.0

    /// Master volume (0-1)
    @Published var volume: Double = 0.7

    // MARK: - Waveform Type

    enum Waveform: String, CaseIterable {
        case sawtooth = "Sawtooth"
        case square = "Square"
    }

    // MARK: - Internal State

    private var sampleRate: Double = 48000.0
    private var phase: Double = 0.0
    private var currentFrequency: Double = 110.0
    private var targetFrequency: Double = 110.0
    private var slideIncrement: Double = 0.0

    // Filter state (4-pole Moog ladder style)
    private var filterState: [Double] = [0, 0, 0, 0]
    private var filterCoeffs: FilterCoefficients = FilterCoefficients()

    // Envelope state
    private var envelopeValue: Double = 0.0
    private var envelopeStage: EnvelopeStage = .idle
    private var envelopeDecayRate: Double = 0.0

    // Accent state
    private var accentActive: Bool = false
    private var currentAccent: Double = 0.0

    // VCA state
    private var vcaLevel: Double = 0.0

    // MARK: - Filter Coefficients

    struct FilterCoefficients {
        var g: Double = 0.0      // Cutoff coefficient
        var k: Double = 0.0      // Resonance coefficient
        var a: [Double] = [0, 0, 0, 0, 0]  // Stage coefficients
    }

    enum EnvelopeStage {
        case idle
        case attack
        case decay
    }

    // MARK: - Initialization

    init(sampleRate: Double = 48000.0) {
        self.sampleRate = sampleRate
        updateFilterCoefficients()
    }

    // MARK: - Note Control

    /// Trigger a note with optional accent and slide
    func noteOn(midiNote: Int, velocity: Float = 1.0, accent: Bool = false, slide: Bool = false) {
        let newFrequency = midiNoteToFrequency(midiNote)

        if slide && envelopeStage != .idle {
            // Slide to new note
            targetFrequency = newFrequency
            let slideSamples = slideTime * sampleRate / 1000.0
            slideIncrement = (targetFrequency - currentFrequency) / slideSamples
        } else {
            // Immediate note change
            currentFrequency = newFrequency
            targetFrequency = newFrequency
            slideIncrement = 0.0
            phase = 0.0
        }

        // Accent handling (303's unique accent circuit)
        accentActive = accent
        if accent {
            currentAccent = self.accent
        } else {
            currentAccent = 0.0
        }

        // Start envelope
        envelopeStage = .attack
        envelopeValue = 1.0

        // Calculate decay rate
        let decaySamples = decay * sampleRate / 1000.0
        envelopeDecayRate = 1.0 / decaySamples
    }

    /// Release note
    func noteOff() {
        // 303 has no sustain - envelope just continues decay
        // Only affects VCA, not filter envelope
    }

    // MARK: - Audio Generation

    /// Generate audio buffer
    func render(frameCount: Int) -> [Float] {
        var output = [Float](repeating: 0, count: frameCount)

        for i in 0..<frameCount {
            // Slide (portamento)
            if abs(currentFrequency - targetFrequency) > 0.01 {
                currentFrequency += slideIncrement
                if slideIncrement > 0 && currentFrequency > targetFrequency {
                    currentFrequency = targetFrequency
                } else if slideIncrement < 0 && currentFrequency < targetFrequency {
                    currentFrequency = targetFrequency
                }
            }

            // Oscillator
            let phaseIncrement = currentFrequency / sampleRate
            phase += phaseIncrement
            if phase >= 1.0 { phase -= 1.0 }

            var oscOutput: Double
            switch waveform {
            case .sawtooth:
                // Band-limited sawtooth using PolyBLEP
                oscOutput = polyBlepSaw(phase: phase, increment: phaseIncrement)
            case .square:
                // Band-limited square using PolyBLEP
                oscOutput = polyBlepSquare(phase: phase, increment: phaseIncrement)
            }

            // Update envelope
            updateEnvelope()

            // Filter with envelope modulation
            // 303's unique behavior: accent increases env mod AND resonance
            let accentEnvBoost = accentActive ? (1.0 + currentAccent * 0.5) : 1.0
            let accentResBoost = accentActive ? (1.0 + currentAccent * 0.3) : 1.0

            let envModAmount = envMod * envelopeValue * accentEnvBoost
            let modulatedCutoff = cutoff * (1.0 + envModAmount * 4.0)  // 303 has ~4 octave sweep
            let modulatedResonance = min(0.98, resonance * accentResBoost)

            // Update filter for modulated cutoff
            updateFilterCoefficientsRT(cutoff: modulatedCutoff, resonance: modulatedResonance)

            // Apply 4-pole ladder filter
            let filtered = applyLadderFilter(oscOutput)

            // Apply distortion (optional, for modern acid sounds)
            var distorted = filtered
            if distortion > 0.0 {
                distorted = applyDistortion(filtered, amount: distortion)
            }

            // VCA (303's VCA is tied to envelope)
            let vcaEnv = envelopeStage != .idle ? 1.0 : 0.0
            let accentVCABoost = accentActive ? (1.0 + currentAccent * 0.3) : 1.0

            output[i] = Float(distorted * vcaEnv * accentVCABoost * volume)
        }

        return output
    }

    // MARK: - PolyBLEP Anti-Aliasing

    private func polyBlepSaw(phase: Double, increment: Double) -> Double {
        var value = 2.0 * phase - 1.0  // Raw sawtooth

        // Apply PolyBLEP to discontinuity
        let t = phase / increment
        if phase < increment {
            let t2 = t * t
            value -= 2.0 * t2 - 2.0 * t + 1.0
        } else if phase > 1.0 - increment {
            let t2 = (t - 1.0 / increment)
            let t3 = t2 * t2
            value += 2.0 * t3 + 2.0 * t2 + 1.0
        }

        return value
    }

    private func polyBlepSquare(phase: Double, increment: Double) -> Double {
        var value = phase < 0.5 ? 1.0 : -1.0  // Raw square

        // Apply PolyBLEP to both edges
        let t1 = phase / increment
        if phase < increment {
            value += polyBlepResidual(t: t1)
        } else if phase > 1.0 - increment {
            value -= polyBlepResidual(t: (phase - 1.0) / increment + 1.0)
        }

        // Second edge at 0.5
        if phase > 0.5 - increment && phase < 0.5 {
            value -= polyBlepResidual(t: (phase - 0.5) / increment + 1.0)
        } else if phase > 0.5 && phase < 0.5 + increment {
            value += polyBlepResidual(t: (phase - 0.5) / increment)
        }

        return value
    }

    private func polyBlepResidual(t: Double) -> Double {
        if t < 1.0 {
            return t + t - t * t - 1.0
        } else {
            let t2 = t - 1.0
            return t2 * t2 + t2 + t2
        }
    }

    // MARK: - Moog Ladder Filter

    private func updateFilterCoefficients() {
        updateFilterCoefficientsRT(cutoff: cutoff, resonance: resonance)
    }

    private func updateFilterCoefficientsRT(cutoff: Double, resonance: Double) {
        // Moog ladder filter coefficient calculation
        let fc = min(cutoff, sampleRate * 0.45)  // Limit to Nyquist
        let g = tan(.pi * fc / sampleRate)

        // Resonance compensation (303 has specific resonance behavior)
        let k = 4.0 * resonance

        filterCoeffs.g = g
        filterCoeffs.k = k
    }

    private func applyLadderFilter(_ input: Double) -> Double {
        let g = filterCoeffs.g
        let k = filterCoeffs.k

        // 4-stage ladder filter with feedback
        let g1 = g / (1.0 + g)

        // Calculate feedback
        let feedback = k * (filterState[3] - input * 0.5)

        // Process through 4 stages
        let stage0Input = input - feedback
        filterState[0] += g1 * (tanh(stage0Input) - tanh(filterState[0]))
        filterState[1] += g1 * (tanh(filterState[0]) - tanh(filterState[1]))
        filterState[2] += g1 * (tanh(filterState[1]) - tanh(filterState[2]))
        filterState[3] += g1 * (tanh(filterState[2]) - tanh(filterState[3]))

        return filterState[3]
    }

    // MARK: - Envelope

    private func updateEnvelope() {
        switch envelopeStage {
        case .idle:
            break
        case .attack:
            // 303 has very fast attack (~3ms)
            envelopeValue = 1.0
            envelopeStage = .decay
        case .decay:
            envelopeValue -= envelopeDecayRate
            if envelopeValue <= 0.0 {
                envelopeValue = 0.0
                envelopeStage = .idle
            }
        }
    }

    // MARK: - Distortion

    private func applyDistortion(_ input: Double, amount: Double) -> Double {
        // Soft saturation (tube-style)
        let drive = 1.0 + amount * 10.0
        let driven = input * drive
        return tanh(driven) / tanh(drive)  // Normalized
    }

    // MARK: - Utility

    private func midiNoteToFrequency(_ note: Int) -> Double {
        return 440.0 * pow(2.0, Double(note - 69) / 12.0)
    }
}

// MARK: - Preset System

extension AcidBassSynth {

    enum Preset: String, CaseIterable {
        case classic303 = "Classic 303"
        case acidSquelch = "Acid Squelch"
        case deepBass = "Deep Bass"
        case resonantLead = "Resonant Lead"
        case hardAcid = "Hard Acid"
        case softBubble = "Soft Bubble"

        var settings: PresetSettings {
            switch self {
            case .classic303:
                return PresetSettings(waveform: .sawtooth, cutoff: 400, resonance: 0.6, envMod: 0.5, decay: 200, accent: 0.5, distortion: 0.0)
            case .acidSquelch:
                return PresetSettings(waveform: .sawtooth, cutoff: 300, resonance: 0.85, envMod: 0.8, decay: 150, accent: 0.8, distortion: 0.1)
            case .deepBass:
                return PresetSettings(waveform: .square, cutoff: 200, resonance: 0.3, envMod: 0.3, decay: 400, accent: 0.3, distortion: 0.0)
            case .resonantLead:
                return PresetSettings(waveform: .sawtooth, cutoff: 800, resonance: 0.9, envMod: 0.6, decay: 100, accent: 0.7, distortion: 0.2)
            case .hardAcid:
                return PresetSettings(waveform: .sawtooth, cutoff: 350, resonance: 0.95, envMod: 0.9, decay: 80, accent: 0.9, distortion: 0.4)
            case .softBubble:
                return PresetSettings(waveform: .square, cutoff: 600, resonance: 0.7, envMod: 0.4, decay: 300, accent: 0.4, distortion: 0.0)
            }
        }
    }

    struct PresetSettings {
        let waveform: Waveform
        let cutoff: Double
        let resonance: Double
        let envMod: Double
        let decay: Double
        let accent: Double
        let distortion: Double
    }

    func loadPreset(_ preset: Preset) {
        let s = preset.settings
        waveform = s.waveform
        cutoff = s.cutoff
        resonance = s.resonance
        envMod = s.envMod
        decay = s.decay
        accent = s.accent
        distortion = s.distortion
    }
}
