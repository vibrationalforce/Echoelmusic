import Foundation
import Accelerate

/// Moog-Style Bass Synthesizer
///
/// Authentic recreation of classic Moog bass sounds, inspired by:
/// - Minimoog Model D (1970) - The original bass monster
/// - Moog Taurus (1975) - Dedicated bass pedal synth
/// - Moog Sub 37 (2014) - Modern interpretation
///
/// The Moog sound is characterized by:
/// - Rich, harmonically complex oscillators
/// - The legendary 4-pole (24dB/oct) transistor ladder filter
/// - Thick unison/detune capabilities
/// - Smooth, musical envelope curves
///
/// Technical specifications:
/// - 3 oscillators with multiple waveforms
/// - Classic Moog 4-pole transistor ladder filter
/// - 2 ADSR envelopes (amplitude + filter)
/// - Sub-oscillator for extra weight
/// - Glide (portamento) with variable time
///
/// References:
/// - "Analog Days" by Trevor Pinch and Frank Trocco
/// - Moog Minimoog Model D Service Manual
/// - Bob Moog's filter patent (US3475623A, 1969)
@MainActor
class MoogBassSynth: ObservableObject {

    // MARK: - Published Parameters

    // Oscillator 1
    @Published var osc1Waveform: Waveform = .sawtooth
    @Published var osc1Octave: Int = 0  // -2 to +2
    @Published var osc1Level: Double = 1.0

    // Oscillator 2
    @Published var osc2Waveform: Waveform = .sawtooth
    @Published var osc2Octave: Int = 0
    @Published var osc2Detune: Double = 0.0  // Cents (-100 to +100)
    @Published var osc2Level: Double = 0.7

    // Oscillator 3
    @Published var osc3Waveform: Waveform = .sawtooth
    @Published var osc3Octave: Int = -1  // Often used as sub
    @Published var osc3Detune: Double = 0.0
    @Published var osc3Level: Double = 0.5

    // Sub Oscillator (one octave below osc1)
    @Published var subOscLevel: Double = 0.3
    @Published var subOscWaveform: SubWaveform = .square

    // Noise
    @Published var noiseLevel: Double = 0.0

    // Filter
    @Published var filterCutoff: Double = 1000.0  // Hz (20-20000)
    @Published var filterResonance: Double = 0.3  // 0-1 (self-osc at ~0.95)
    @Published var filterEnvAmount: Double = 0.5  // 0-1
    @Published var filterKeyTrack: Double = 0.5   // 0-1

    // Filter Envelope
    @Published var filterAttack: Double = 10.0    // ms
    @Published var filterDecay: Double = 200.0    // ms
    @Published var filterSustain: Double = 0.3    // 0-1
    @Published var filterRelease: Double = 200.0  // ms

    // Amp Envelope
    @Published var ampAttack: Double = 5.0        // ms
    @Published var ampDecay: Double = 100.0       // ms
    @Published var ampSustain: Double = 0.8       // 0-1
    @Published var ampRelease: Double = 150.0     // ms

    // Glide (Portamento)
    @Published var glideTime: Double = 0.0        // ms (0 = off)
    @Published var glideMode: GlideMode = .always

    // Master
    @Published var masterVolume: Double = 0.7

    // MARK: - Types

    enum Waveform: String, CaseIterable {
        case triangle = "Triangle"
        case sawtoothUp = "Sawtooth"
        case sawtoothDown = "Saw Down"
        case square = "Square"
        case pulse25 = "Pulse 25%"
        case pulse10 = "Pulse 10%"
    }

    enum SubWaveform: String, CaseIterable {
        case sine = "Sine"
        case square = "Square"
        case pulse = "Pulse"
    }

    enum GlideMode: String, CaseIterable {
        case off = "Off"
        case always = "Always"
        case legato = "Legato Only"
    }

    // MARK: - Internal State

    private var sampleRate: Double = 48000.0

    // Oscillator phases
    private var osc1Phase: Double = 0.0
    private var osc2Phase: Double = 0.0
    private var osc3Phase: Double = 0.0
    private var subOscPhase: Double = 0.0
    private var noiseState: UInt32 = 22222  // LFSR seed

    // Current/target frequency for glide
    private var currentFrequency: Double = 110.0
    private var targetFrequency: Double = 110.0
    private var glideIncrement: Double = 0.0

    // Filter state (4 poles)
    private var filterStages: [Double] = [0, 0, 0, 0]
    private var filterDelay: [Double] = [0, 0, 0, 0]

    // Envelopes
    private var filterEnv = ADSREnvelope()
    private var ampEnv = ADSREnvelope()

    // Note tracking
    private var noteOn: Bool = false
    private var currentNote: Int = 48
    private var velocity: Double = 1.0
    private var legatoActive: Bool = false

    // MARK: - ADSR Envelope

    struct ADSREnvelope {
        enum Stage { case idle, attack, decay, sustain, release }

        var stage: Stage = .idle
        var value: Double = 0.0
        var attackRate: Double = 0.0
        var decayRate: Double = 0.0
        var sustainLevel: Double = 0.0
        var releaseRate: Double = 0.0

        mutating func trigger() {
            stage = .attack
        }

        mutating func release() {
            if stage != .idle {
                stage = .release
            }
        }

        mutating func process() -> Double {
            switch stage {
            case .idle:
                value = 0.0
            case .attack:
                value += attackRate
                if value >= 1.0 {
                    value = 1.0
                    stage = .decay
                }
            case .decay:
                value -= decayRate
                if value <= sustainLevel {
                    value = sustainLevel
                    stage = .sustain
                }
            case .sustain:
                value = sustainLevel
            case .release:
                value -= releaseRate
                if value <= 0.0 {
                    value = 0.0
                    stage = .idle
                }
            }
            return value
        }

        mutating func configure(attack: Double, decay: Double, sustain: Double, release: Double, sampleRate: Double) {
            // Convert ms to rate per sample
            attackRate = 1.0 / max(1.0, attack * sampleRate / 1000.0)
            decayRate = (1.0 - sustain) / max(1.0, decay * sampleRate / 1000.0)
            sustainLevel = sustain
            releaseRate = sustain / max(1.0, release * sampleRate / 1000.0)
        }
    }

    // MARK: - Initialization

    init(sampleRate: Double = 48000.0) {
        self.sampleRate = sampleRate
        updateEnvelopeRates()
    }

    // MARK: - Note Control

    func noteOnEvent(midiNote: Int, velocity: Float = 1.0) {
        let wasPlaying = noteOn || ampEnv.stage != .idle
        let newFrequency = midiNoteToFrequency(midiNote)

        self.velocity = Double(velocity)
        self.currentNote = midiNote
        self.noteOn = true

        // Handle glide
        let shouldGlide: Bool
        switch glideMode {
        case .off:
            shouldGlide = false
        case .always:
            shouldGlide = glideTime > 0
        case .legato:
            shouldGlide = glideTime > 0 && wasPlaying
        }

        if shouldGlide && wasPlaying {
            targetFrequency = newFrequency
            let glideSamples = glideTime * sampleRate / 1000.0
            glideIncrement = (targetFrequency - currentFrequency) / max(1, glideSamples)
            legatoActive = true
        } else {
            currentFrequency = newFrequency
            targetFrequency = newFrequency
            glideIncrement = 0.0
            legatoActive = false

            // Reset phases on new note (non-legato)
            osc1Phase = 0.0
            osc2Phase = 0.0
            osc3Phase = 0.0
            subOscPhase = 0.0
        }

        // Update envelopes
        updateEnvelopeRates()
        filterEnv.trigger()
        ampEnv.trigger()
    }

    func noteOffEvent() {
        noteOn = false
        filterEnv.release()
        ampEnv.release()
    }

    private func updateEnvelopeRates() {
        filterEnv.configure(
            attack: filterAttack,
            decay: filterDecay,
            sustain: filterSustain,
            release: filterRelease,
            sampleRate: sampleRate
        )
        ampEnv.configure(
            attack: ampAttack,
            decay: ampDecay,
            sustain: ampSustain,
            release: ampRelease,
            sampleRate: sampleRate
        )
    }

    // MARK: - Audio Rendering

    func render(frameCount: Int) -> [Float] {
        var output = [Float](repeating: 0, count: frameCount)

        for i in 0..<frameCount {
            // Update glide
            if glideIncrement != 0 {
                currentFrequency += glideIncrement
                if (glideIncrement > 0 && currentFrequency >= targetFrequency) ||
                   (glideIncrement < 0 && currentFrequency <= targetFrequency) {
                    currentFrequency = targetFrequency
                    glideIncrement = 0
                }
            }

            // Calculate frequencies for each oscillator
            let osc1Freq = currentFrequency * pow(2.0, Double(osc1Octave))
            let osc2Freq = currentFrequency * pow(2.0, Double(osc2Octave)) * pow(2.0, osc2Detune / 1200.0)
            let osc3Freq = currentFrequency * pow(2.0, Double(osc3Octave)) * pow(2.0, osc3Detune / 1200.0)
            let subFreq = currentFrequency * 0.5  // One octave below

            // Generate oscillators
            let osc1Out = generateOscillator(&osc1Phase, frequency: osc1Freq, waveform: osc1Waveform) * osc1Level
            let osc2Out = generateOscillator(&osc2Phase, frequency: osc2Freq, waveform: osc2Waveform) * osc2Level
            let osc3Out = generateOscillator(&osc3Phase, frequency: osc3Freq, waveform: osc3Waveform) * osc3Level
            let subOut = generateSubOscillator(&subOscPhase, frequency: subFreq) * subOscLevel
            let noiseOut = generateNoise() * noiseLevel

            // Mix oscillators
            var mixed = osc1Out + osc2Out + osc3Out + subOut + noiseOut

            // Soft clip the mixer (Moog mixer has gentle saturation)
            mixed = tanh(mixed * 0.7) / 0.7

            // Process envelopes
            let filterEnvValue = filterEnv.process()
            let ampEnvValue = ampEnv.process()

            // Calculate filter cutoff with modulation
            let keyTrackAmount = (Double(currentNote) - 60.0) / 60.0 * filterKeyTrack
            let envModulation = filterEnvValue * filterEnvAmount * 8000.0  // Up to 8kHz modulation
            let modulatedCutoff = filterCutoff * (1.0 + keyTrackAmount) + envModulation
            let clampedCutoff = max(20.0, min(modulatedCutoff, sampleRate * 0.45))

            // Apply Moog ladder filter
            let filtered = moogLadderFilter(mixed, cutoff: clampedCutoff)

            // Apply VCA
            let amplified = filtered * ampEnvValue * velocity

            output[i] = Float(amplified * masterVolume)
        }

        return output
    }

    // MARK: - Oscillator Generation

    private func generateOscillator(_ phase: inout Double, frequency: Double, waveform: Waveform) -> Double {
        let phaseInc = frequency / sampleRate
        phase += phaseInc
        if phase >= 1.0 { phase -= 1.0 }

        switch waveform {
        case .triangle:
            return 4.0 * abs(phase - 0.5) - 1.0
        case .sawtoothUp:
            return polyBlepSaw(phase: phase, inc: phaseInc)
        case .sawtoothDown:
            return -polyBlepSaw(phase: phase, inc: phaseInc)
        case .square:
            return polyBlepPulse(phase: phase, inc: phaseInc, width: 0.5)
        case .pulse25:
            return polyBlepPulse(phase: phase, inc: phaseInc, width: 0.25)
        case .pulse10:
            return polyBlepPulse(phase: phase, inc: phaseInc, width: 0.10)
        }
    }

    private func generateSubOscillator(_ phase: inout Double, frequency: Double) -> Double {
        let phaseInc = frequency / sampleRate
        phase += phaseInc
        if phase >= 1.0 { phase -= 1.0 }

        switch subOscWaveform {
        case .sine:
            return sin(phase * 2.0 * .pi)
        case .square:
            return phase < 0.5 ? 1.0 : -1.0
        case .pulse:
            return phase < 0.25 ? 1.0 : -1.0
        }
    }

    private func generateNoise() -> Double {
        // Simple white noise using LFSR
        noiseState = noiseState &* 1664525 &+ 1013904223
        return Double(Int32(bitPattern: noiseState)) / Double(Int32.max)
    }

    // MARK: - PolyBLEP Anti-aliasing

    private func polyBlepSaw(phase: Double, inc: Double) -> Double {
        var value = 2.0 * phase - 1.0
        if phase < inc {
            let t = phase / inc
            value -= t + t - t * t - 1.0
        } else if phase > 1.0 - inc {
            let t = (phase - 1.0) / inc
            value -= t * t + t + t + 1.0
        }
        return value
    }

    private func polyBlepPulse(phase: Double, inc: Double, width: Double) -> Double {
        var value = phase < width ? 1.0 : -1.0

        // First edge
        if phase < inc {
            value += polyBlepResidual(t: phase / inc)
        } else if phase > 1.0 - inc {
            value -= polyBlepResidual(t: (phase - 1.0) / inc + 1.0)
        }

        // Second edge at pulse width
        if phase > width - inc && phase < width {
            value -= polyBlepResidual(t: (phase - width) / inc + 1.0)
        } else if phase > width && phase < width + inc {
            value += polyBlepResidual(t: (phase - width) / inc)
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

    private func moogLadderFilter(_ input: Double, cutoff: Double) -> Double {
        // Huovilainen's improved Moog ladder filter model
        let fc = cutoff / sampleRate
        let f = fc * 1.16
        let fb = filterResonance * 4.0 * (1.0 - 0.15 * f * f)

        // Feedback
        let inputWithFB = input - fb * filterStages[3]

        // 4 cascaded one-pole filters with nonlinear saturation
        filterStages[0] += f * (tanh(inputWithFB) - tanh(filterStages[0]))
        filterStages[1] += f * (tanh(filterStages[0]) - tanh(filterStages[1]))
        filterStages[2] += f * (tanh(filterStages[1]) - tanh(filterStages[2]))
        filterStages[3] += f * (tanh(filterStages[2]) - tanh(filterStages[3]))

        return filterStages[3]
    }

    // MARK: - Utility

    private func midiNoteToFrequency(_ note: Int) -> Double {
        return 440.0 * pow(2.0, Double(note - 69) / 12.0)
    }
}

// MARK: - Presets

extension MoogBassSynth {

    enum Preset: String, CaseIterable {
        case classicMoog = "Classic Moog"
        case taurusBass = "Taurus Bass"
        case fatSaw = "Fat Saw"
        case subBass = "Sub Bass"
        case punchyBass = "Punchy Bass"
        case acidMoog = "Acid Moog"
        case warmPad = "Warm Pad Bass"
        case modernSub = "Modern Sub"

        var description: String {
            switch self {
            case .classicMoog: return "The quintessential Minimoog bass"
            case .taurusBass: return "Moog Taurus pedal sound"
            case .fatSaw: return "Thick detuned sawtooth"
            case .subBass: return "Deep sine-based sub"
            case .punchyBass: return "Percussive attack bass"
            case .acidMoog: return "Resonant squelchy bass"
            case .warmPad: return "Filtered pad bass"
            case .modernSub: return "Clean modern sub bass"
            }
        }
    }

    func loadPreset(_ preset: Preset) {
        switch preset {
        case .classicMoog:
            osc1Waveform = .sawtoothUp; osc1Octave = 0; osc1Level = 1.0
            osc2Waveform = .sawtoothUp; osc2Octave = 0; osc2Detune = 7; osc2Level = 0.7
            osc3Waveform = .square; osc3Octave = -1; osc3Detune = 0; osc3Level = 0.5
            subOscLevel = 0.3; filterCutoff = 800; filterResonance = 0.3
            filterEnvAmount = 0.4; filterAttack = 5; filterDecay = 150; filterSustain = 0.4; filterRelease = 100

        case .taurusBass:
            osc1Waveform = .square; osc1Octave = -1; osc1Level = 1.0
            osc2Waveform = .sawtoothUp; osc2Octave = -1; osc2Detune = 5; osc2Level = 0.6
            osc3Level = 0.0; subOscLevel = 0.5
            filterCutoff = 400; filterResonance = 0.2; filterEnvAmount = 0.3

        case .fatSaw:
            osc1Waveform = .sawtoothUp; osc1Octave = 0; osc1Level = 1.0
            osc2Waveform = .sawtoothUp; osc2Octave = 0; osc2Detune = 12; osc2Level = 1.0
            osc3Waveform = .sawtoothUp; osc3Octave = 0; osc3Detune = -10; osc3Level = 1.0
            subOscLevel = 0.2; filterCutoff = 1200; filterResonance = 0.1

        case .subBass:
            osc1Level = 0.0; osc2Level = 0.0; osc3Level = 0.0
            subOscWaveform = .sine; subOscLevel = 1.0
            filterCutoff = 200; filterResonance = 0.0; filterEnvAmount = 0.1

        case .punchyBass:
            osc1Waveform = .sawtoothUp; osc1Octave = 0; osc1Level = 1.0
            osc2Waveform = .square; osc2Octave = -1; osc2Level = 0.5
            filterCutoff = 600; filterResonance = 0.4
            filterEnvAmount = 0.7; filterAttack = 0; filterDecay = 80; filterSustain = 0.2
            ampAttack = 0; ampDecay = 50; ampSustain = 0.7

        case .acidMoog:
            osc1Waveform = .sawtoothUp; osc1Octave = 0; osc1Level = 1.0
            osc2Level = 0.0; osc3Level = 0.0
            filterCutoff = 300; filterResonance = 0.8; filterEnvAmount = 0.9
            filterAttack = 0; filterDecay = 120; filterSustain = 0.1

        case .warmPad:
            osc1Waveform = .triangle; osc1Octave = 0; osc1Level = 0.8
            osc2Waveform = .sawtoothUp; osc2Octave = 0; osc2Detune = 5; osc2Level = 0.5
            filterCutoff = 500; filterResonance = 0.2
            filterAttack = 100; filterDecay = 500; filterSustain = 0.6
            ampAttack = 50; ampDecay = 200; ampSustain = 0.9; ampRelease = 300

        case .modernSub:
            osc1Waveform = .triangle; osc1Octave = -1; osc1Level = 0.5
            osc2Level = 0.0; osc3Level = 0.0
            subOscWaveform = .sine; subOscLevel = 1.0
            filterCutoff = 150; filterResonance = 0.0; filterEnvAmount = 0.05
        }
    }
}
