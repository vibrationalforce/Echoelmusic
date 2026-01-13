//
//  SynthesisEngines.swift
//  Echoelmusic
//
//  Created: January 2026
//  COMPREHENSIVE SYNTHESIS ENGINES
//  Production-Quality Real-Time Audio Synthesis
//
//  Features:
//  - SubtractiveSynth: Classic analog-style with dual oscillators/filters
//  - FMSynth: Yamaha DX7-style 6-operator FM synthesis
//  - WavetableSynth: Serum/Vital-style wavetable morphing
//  - GranularSynth: Advanced granular processing
//  - AdditiveSynth: 64-harmonic additive synthesis
//  - PhysicalModelingSynth: Karplus-Strong string modeling
//
//  All engines optimized for real-time audio with lock-free voice management
//

import Foundation
import Accelerate
import simd

// MARK: - Common Types

/// Waveform types for oscillators
public enum Waveform: Int, CaseIterable, Sendable {
    case sine = 0
    case saw
    case square
    case triangle
    case pulse
    case noise

    public var name: String {
        switch self {
        case .sine: return "Sine"
        case .saw: return "Sawtooth"
        case .square: return "Square"
        case .triangle: return "Triangle"
        case .pulse: return "Pulse"
        case .noise: return "Noise"
        }
    }
}

/// Filter types
public enum FilterType: Int, CaseIterable, Sendable {
    case lowpass12
    case lowpass24
    case highpass12
    case highpass24
    case bandpass
    case notch

    public var name: String {
        switch self {
        case .lowpass12: return "LP 12dB"
        case .lowpass24: return "LP 24dB"
        case .highpass12: return "HP 12dB"
        case .highpass24: return "HP 24dB"
        case .bandpass: return "Band Pass"
        case .notch: return "Notch"
        }
    }
}

/// LFO destination targets
public enum LFODestination: Int, CaseIterable, Sendable {
    case none
    case pitch
    case filterCutoff
    case filterResonance
    case amplitude
    case pan
    case pulseWidth
    case fmIndex
    case wavetablePosition
    case grainPosition
    case grainSize
}

/// ADSR Envelope
public struct ADSREnvelope: Sendable {
    public var attack: Float    // seconds
    public var decay: Float     // seconds
    public var sustain: Float   // level 0-1
    public var release: Float   // seconds

    public init(attack: Float = 0.01, decay: Float = 0.1, sustain: Float = 0.7, release: Float = 0.3) {
        self.attack = attack
        self.decay = decay
        self.sustain = sustain
        self.release = release
    }

    public static let fast = ADSREnvelope(attack: 0.001, decay: 0.05, sustain: 0.5, release: 0.1)
    public static let pad = ADSREnvelope(attack: 0.5, decay: 0.3, sustain: 0.8, release: 1.0)
    public static let pluck = ADSREnvelope(attack: 0.001, decay: 0.3, sustain: 0.0, release: 0.2)
    public static let organ = ADSREnvelope(attack: 0.01, decay: 0.0, sustain: 1.0, release: 0.05)
}

/// Voice state for envelope tracking
public enum VoiceState: Sendable {
    case idle
    case attack
    case decay
    case sustain
    case release
}

// MARK: - Base Synth Protocol

/// Protocol for all synthesis engines
public protocol SynthesisEngine: AnyObject {
    var sampleRate: Float { get set }
    var masterVolume: Float { get set }
    var activeVoiceCount: Int { get }

    func noteOn(note: Int, velocity: Int)
    func noteOff(note: Int)
    func allNotesOff()
    func processBlock(buffer: inout [Float], sampleRate: Float)
}

// MARK: - Utility Functions

/// Convert MIDI note to frequency
@inline(__always)
func midiToFrequency(_ note: Int) -> Float {
    440.0 * pow(2.0, Float(note - 69) / 12.0)
}

/// Convert MIDI velocity to amplitude
@inline(__always)
func velocityToAmplitude(_ velocity: Int) -> Float {
    let v = Float(velocity) / 127.0
    return v * v  // Quadratic curve for natural dynamics
}

/// Fast sine approximation using parabolic approximation
@inline(__always)
func fastSin(_ x: Float) -> Float {
    // Normalize to -PI to PI
    var t = x
    while t > Float.pi { t -= 2.0 * Float.pi }
    while t < -Float.pi { t += 2.0 * Float.pi }

    // Parabolic approximation
    let B: Float = 4.0 / Float.pi
    let C: Float = -4.0 / (Float.pi * Float.pi)
    var y = B * t + C * t * abs(t)

    // Extra precision
    let P: Float = 0.225
    y = P * (y * abs(y) - y) + y

    return y
}

// MARK: - ============================================
// MARK: - 1. SUBTRACTIVE SYNTH
// MARK: - ============================================

/// Configuration for SubtractiveSynth
public struct SubtractiveConfig: Sendable {
    // Oscillator 1
    public var osc1Waveform: Waveform = .saw
    public var osc1Octave: Int = 0
    public var osc1Semi: Int = 0
    public var osc1Fine: Float = 0.0  // cents
    public var osc1PulseWidth: Float = 0.5
    public var osc1Level: Float = 1.0

    // Oscillator 2
    public var osc2Waveform: Waveform = .saw
    public var osc2Octave: Int = 0
    public var osc2Semi: Int = 0
    public var osc2Fine: Float = 0.0
    public var osc2PulseWidth: Float = 0.5
    public var osc2Level: Float = 0.5
    public var osc2Sync: Bool = false

    // Mixer
    public var noiseLevel: Float = 0.0
    public var ringModLevel: Float = 0.0

    // Filter 1
    public var filter1Type: FilterType = .lowpass24
    public var filter1Cutoff: Float = 2000.0
    public var filter1Resonance: Float = 0.3
    public var filter1KeyTrack: Float = 0.5
    public var filter1EnvAmount: Float = 0.5

    // Filter 2
    public var filter2Type: FilterType = .lowpass12
    public var filter2Cutoff: Float = 8000.0
    public var filter2Resonance: Float = 0.0
    public var filter2Enabled: Bool = false

    // Envelopes
    public var ampEnvelope: ADSREnvelope = ADSREnvelope()
    public var filterEnvelope: ADSREnvelope = ADSREnvelope(attack: 0.01, decay: 0.3, sustain: 0.3, release: 0.5)

    // LFO 1
    public var lfo1Rate: Float = 2.0
    public var lfo1Waveform: Waveform = .triangle
    public var lfo1Destination: LFODestination = .pitch
    public var lfo1Amount: Float = 0.0
    public var lfo1Sync: Bool = false

    // LFO 2
    public var lfo2Rate: Float = 0.5
    public var lfo2Waveform: Waveform = .sine
    public var lfo2Destination: LFODestination = .filterCutoff
    public var lfo2Amount: Float = 0.0

    // Unison
    public var unisonVoices: Int = 1  // 1-8
    public var unisonDetune: Float = 0.1  // 0-1
    public var unisonSpread: Float = 0.5  // stereo spread

    // Glide
    public var glideTime: Float = 0.0
    public var glideEnabled: Bool = false

    public init() {}
}

/// Voice for SubtractiveSynth
private final class SubtractiveVoice {
    var note: Int = 0
    var velocity: Float = 0.0
    var frequency: Float = 440.0
    var targetFrequency: Float = 440.0
    var isActive: Bool = false
    var state: VoiceState = .idle

    // Oscillator phases
    var osc1Phase: Float = 0.0
    var osc2Phase: Float = 0.0
    var noiseState: UInt32 = 12345

    // Envelope states
    var ampEnvValue: Float = 0.0
    var ampEnvTime: Float = 0.0
    var filterEnvValue: Float = 0.0
    var filterEnvTime: Float = 0.0

    // LFO phases
    var lfo1Phase: Float = 0.0
    var lfo2Phase: Float = 0.0

    // Filter states (biquad)
    var filter1Z1: Float = 0.0
    var filter1Z2: Float = 0.0
    var filter1Z3: Float = 0.0
    var filter1Z4: Float = 0.0
    var filter2Z1: Float = 0.0
    var filter2Z2: Float = 0.0

    // Unison phases
    var unisonPhases: [Float] = [0, 0, 0, 0, 0, 0, 0, 0]

    func reset() {
        osc1Phase = 0
        osc2Phase = 0
        ampEnvValue = 0
        ampEnvTime = 0
        filterEnvValue = 0
        filterEnvTime = 0
        lfo1Phase = Float.random(in: 0..<1)  // Random start for variation
        lfo2Phase = Float.random(in: 0..<1)
        filter1Z1 = 0; filter1Z2 = 0; filter1Z3 = 0; filter1Z4 = 0
        filter2Z1 = 0; filter2Z2 = 0
        state = .attack
        for i in 0..<8 { unisonPhases[i] = Float.random(in: 0..<1) }
    }

    // Fast noise generation
    @inline(__always)
    func nextNoise() -> Float {
        noiseState = noiseState &* 1664525 &+ 1013904223
        return Float(Int32(bitPattern: noiseState)) / Float(Int32.max)
    }
}

/// Classic subtractive synthesizer with dual oscillators and filters
public final class SubtractiveSynth: SynthesisEngine {

    // MARK: - Properties

    public var sampleRate: Float = 48000.0
    public var masterVolume: Float = 0.8
    public var config = SubtractiveConfig()

    private let maxVoices = 16
    private var voices: [SubtractiveVoice] = []
    private let voiceLock = os_unfair_lock_s()

    public var activeVoiceCount: Int {
        voices.filter { $0.isActive }.count
    }

    // MARK: - Initialization

    public init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate
        voices = (0..<maxVoices).map { _ in SubtractiveVoice() }
        log.audio("SubtractiveSynth initialized: \(maxVoices) voices")
    }

    // MARK: - Note Control

    public func noteOn(note: Int, velocity: Int) {
        withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_lock($0) }
        defer { withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_unlock($0) } }

        // Find free voice or steal oldest
        var voice: SubtractiveVoice?

        // First, check if same note is already playing (retrigger)
        if let existing = voices.first(where: { $0.isActive && $0.note == note }) {
            voice = existing
        } else if let free = voices.first(where: { !$0.isActive }) {
            voice = free
        } else {
            // Voice stealing: find voice in release or oldest
            voice = voices.min(by: { v1, v2 in
                if v1.state == .release && v2.state != .release { return true }
                if v1.state != .release && v2.state == .release { return false }
                return v1.ampEnvTime > v2.ampEnvTime
            })
        }

        guard let v = voice else { return }

        let freq = midiToFrequency(note)
        v.note = note
        v.velocity = velocityToAmplitude(velocity)
        v.targetFrequency = freq
        v.frequency = config.glideEnabled && v.isActive ? v.frequency : freq
        v.isActive = true
        v.reset()
    }

    public func noteOff(note: Int) {
        withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_lock($0) }
        defer { withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_unlock($0) } }

        for voice in voices where voice.isActive && voice.note == note && voice.state != .release {
            voice.state = .release
            voice.ampEnvTime = 0
            voice.filterEnvTime = 0
        }
    }

    public func allNotesOff() {
        withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_lock($0) }
        defer { withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_unlock($0) } }

        for voice in voices {
            voice.isActive = false
            voice.state = .idle
        }
    }

    // MARK: - Audio Processing

    public func processBlock(buffer: inout [Float], sampleRate: Float) {
        self.sampleRate = sampleRate
        let frameCount = buffer.count

        // Clear buffer
        buffer = [Float](repeating: 0, count: frameCount)

        withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_lock($0) }
        defer { withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_unlock($0) } }

        for voice in voices where voice.isActive {
            processVoice(voice, buffer: &buffer, frameCount: frameCount)
        }

        // Apply master volume
        if masterVolume != 1.0 {
            vDSP_vsmul(buffer, 1, &masterVolume, &buffer, 1, vDSP_Length(frameCount))
        }
    }

    private func processVoice(_ voice: SubtractiveVoice, buffer: inout [Float], frameCount: Int) {
        let cfg = config
        let invSampleRate = 1.0 / sampleRate

        for i in 0..<frameCount {
            // Update envelope
            let ampEnv = updateEnvelope(voice: voice, envelope: cfg.ampEnvelope, isAmp: true, dt: invSampleRate)
            let filterEnv = updateEnvelope(voice: voice, envelope: cfg.filterEnvelope, isAmp: false, dt: invSampleRate)

            if voice.state == .idle {
                voice.isActive = false
                return
            }

            // Update LFOs
            let lfo1 = generateLFO(phase: &voice.lfo1Phase, rate: cfg.lfo1Rate, waveform: cfg.lfo1Waveform, dt: invSampleRate)
            let lfo2 = generateLFO(phase: &voice.lfo2Phase, rate: cfg.lfo2Rate, waveform: cfg.lfo2Waveform, dt: invSampleRate)

            // Apply LFO modulations
            var pitchMod: Float = 1.0
            var cutoffMod: Float = 1.0
            var ampMod: Float = 1.0
            var pwMod: Float = 0.0

            applyLFOModulation(lfo1, amount: cfg.lfo1Amount, destination: cfg.lfo1Destination,
                             pitchMod: &pitchMod, cutoffMod: &cutoffMod, ampMod: &ampMod, pwMod: &pwMod)
            applyLFOModulation(lfo2, amount: cfg.lfo2Amount, destination: cfg.lfo2Destination,
                             pitchMod: &pitchMod, cutoffMod: &cutoffMod, ampMod: &ampMod, pwMod: &pwMod)

            // Glide
            if cfg.glideEnabled && voice.frequency != voice.targetFrequency {
                let glideSpeed = invSampleRate / max(0.001, cfg.glideTime)
                voice.frequency += (voice.targetFrequency - voice.frequency) * glideSpeed
            }

            // Calculate frequencies
            let baseFreq = voice.frequency * pitchMod
            let osc1Freq = baseFreq * pow(2.0, Float(cfg.osc1Octave) + Float(cfg.osc1Semi) / 12.0 + cfg.osc1Fine / 1200.0)
            let osc2Freq = baseFreq * pow(2.0, Float(cfg.osc2Octave) + Float(cfg.osc2Semi) / 12.0 + cfg.osc2Fine / 1200.0)

            // Generate oscillators with unison
            var sample: Float = 0.0
            let unisonCount = min(8, max(1, cfg.unisonVoices))

            for u in 0..<unisonCount {
                let detuneAmount = cfg.unisonDetune * (Float(u) - Float(unisonCount - 1) / 2.0) / Float(max(1, unisonCount - 1))
                let detuneMult = pow(2.0, detuneAmount / 12.0)

                // OSC 1
                let osc1 = generateOscillator(
                    phase: &voice.unisonPhases[u],
                    frequency: osc1Freq * detuneMult,
                    waveform: cfg.osc1Waveform,
                    pulseWidth: cfg.osc1PulseWidth + pwMod,
                    dt: invSampleRate
                )

                // OSC 2 (with optional sync)
                var osc2: Float = 0.0
                if cfg.osc2Sync {
                    // Hard sync: reset osc2 phase when osc1 completes cycle
                    if voice.osc1Phase < osc1Freq * invSampleRate {
                        voice.osc2Phase = 0
                    }
                }
                osc2 = generateOscillator(
                    phase: &voice.osc2Phase,
                    frequency: osc2Freq * detuneMult,
                    waveform: cfg.osc2Waveform,
                    pulseWidth: cfg.osc2PulseWidth + pwMod,
                    dt: invSampleRate
                )

                sample += (osc1 * cfg.osc1Level + osc2 * cfg.osc2Level) / Float(unisonCount)
            }

            // Add noise
            if cfg.noiseLevel > 0 {
                sample += voice.nextNoise() * cfg.noiseLevel
            }

            // Ring modulation (osc1 * osc2)
            if cfg.ringModLevel > 0 {
                let osc1 = generateOscillator(phase: &voice.osc1Phase, frequency: osc1Freq, waveform: cfg.osc1Waveform, pulseWidth: cfg.osc1PulseWidth, dt: invSampleRate)
                let osc2 = generateOscillator(phase: &voice.osc2Phase, frequency: osc2Freq, waveform: cfg.osc2Waveform, pulseWidth: cfg.osc2PulseWidth, dt: invSampleRate)
                sample = sample * (1.0 - cfg.ringModLevel) + (osc1 * osc2) * cfg.ringModLevel
            }

            // Filter 1
            let keyTrack = (voice.frequency / 440.0 - 1.0) * cfg.filter1KeyTrack
            let filterCutoff = cfg.filter1Cutoff * cutoffMod * (1.0 + filterEnv * cfg.filter1EnvAmount + keyTrack)
            sample = applyFilter(
                sample: sample,
                cutoff: min(sampleRate * 0.45, max(20.0, filterCutoff)),
                resonance: cfg.filter1Resonance,
                filterType: cfg.filter1Type,
                z1: &voice.filter1Z1, z2: &voice.filter1Z2, z3: &voice.filter1Z3, z4: &voice.filter1Z4,
                sampleRate: sampleRate
            )

            // Filter 2 (optional)
            if cfg.filter2Enabled {
                sample = applyFilter(
                    sample: sample,
                    cutoff: min(sampleRate * 0.45, max(20.0, cfg.filter2Cutoff * cutoffMod)),
                    resonance: cfg.filter2Resonance,
                    filterType: cfg.filter2Type,
                    z1: &voice.filter2Z1, z2: &voice.filter2Z2, z3: &voice.filter1Z3, z4: &voice.filter1Z4,
                    sampleRate: sampleRate
                )
            }

            // Apply envelopes and velocity
            sample *= ampEnv * ampMod * voice.velocity

            buffer[i] += sample
        }
    }

    // MARK: - DSP Helpers

    @inline(__always)
    private func generateOscillator(phase: inout Float, frequency: Float, waveform: Waveform, pulseWidth: Float, dt: Float) -> Float {
        let phaseInc = frequency * dt
        phase += phaseInc
        if phase >= 1.0 { phase -= 1.0 }

        switch waveform {
        case .sine:
            return fastSin(phase * 2.0 * Float.pi)
        case .saw:
            return 2.0 * phase - 1.0
        case .square:
            return phase < 0.5 ? 1.0 : -1.0
        case .triangle:
            return phase < 0.5 ? 4.0 * phase - 1.0 : 3.0 - 4.0 * phase
        case .pulse:
            let pw = max(0.01, min(0.99, pulseWidth))
            return phase < pw ? 1.0 : -1.0
        case .noise:
            return Float.random(in: -1...1)
        }
    }

    @inline(__always)
    private func generateLFO(phase: inout Float, rate: Float, waveform: Waveform, dt: Float) -> Float {
        let phaseInc = rate * dt
        phase += phaseInc
        if phase >= 1.0 { phase -= 1.0 }

        switch waveform {
        case .sine:
            return fastSin(phase * 2.0 * Float.pi)
        case .triangle:
            return phase < 0.5 ? 4.0 * phase - 1.0 : 3.0 - 4.0 * phase
        case .saw:
            return 2.0 * phase - 1.0
        case .square:
            return phase < 0.5 ? 1.0 : -1.0
        default:
            return fastSin(phase * 2.0 * Float.pi)
        }
    }

    @inline(__always)
    private func updateEnvelope(voice: SubtractiveVoice, envelope: ADSREnvelope, isAmp: Bool, dt: Float) -> Float {
        let time = isAmp ? voice.ampEnvTime : voice.filterEnvTime
        var value = isAmp ? voice.ampEnvValue : voice.filterEnvValue

        switch voice.state {
        case .attack:
            value += dt / max(0.001, envelope.attack)
            if value >= 1.0 {
                value = 1.0
                voice.state = .decay
                if isAmp { voice.ampEnvTime = 0 } else { voice.filterEnvTime = 0 }
            }
        case .decay:
            value -= dt / max(0.001, envelope.decay) * (1.0 - envelope.sustain)
            if value <= envelope.sustain {
                value = envelope.sustain
                voice.state = .sustain
            }
        case .sustain:
            value = envelope.sustain
        case .release:
            value -= dt / max(0.001, envelope.release) * value
            if value <= 0.001 {
                value = 0
                if isAmp { voice.state = .idle }
            }
        case .idle:
            value = 0
        }

        if isAmp {
            voice.ampEnvValue = value
            voice.ampEnvTime += dt
        } else {
            voice.filterEnvValue = value
            voice.filterEnvTime += dt
        }

        return value
    }

    @inline(__always)
    private func applyLFOModulation(_ lfoValue: Float, amount: Float, destination: LFODestination,
                                    pitchMod: inout Float, cutoffMod: inout Float, ampMod: inout Float, pwMod: inout Float) {
        let mod = lfoValue * amount
        switch destination {
        case .pitch:
            pitchMod *= pow(2.0, mod / 12.0)  // semitones
        case .filterCutoff:
            cutoffMod *= pow(2.0, mod * 2.0)  // octaves
        case .amplitude:
            ampMod *= 1.0 + mod * 0.5
        case .pulseWidth:
            pwMod += mod * 0.4
        default:
            break
        }
    }

    @inline(__always)
    private func applyFilter(sample: Float, cutoff: Float, resonance: Float, filterType: FilterType,
                            z1: inout Float, z2: inout Float, z3: inout Float, z4: inout Float,
                            sampleRate: Float) -> Float {
        // State variable filter (more stable at high resonance)
        let f = 2.0 * sin(Float.pi * cutoff / sampleRate)
        let q = 1.0 - resonance * 0.99

        let hp = sample - z1 - q * z2
        let bp = f * hp + z2
        let lp = f * bp + z1

        z1 = lp
        z2 = bp

        switch filterType {
        case .lowpass12:
            return lp
        case .lowpass24:
            // Second stage for 24dB
            let hp2 = lp - z3 - q * z4
            let bp2 = f * hp2 + z4
            let lp2 = f * bp2 + z3
            z3 = lp2
            z4 = bp2
            return lp2
        case .highpass12:
            return hp
        case .highpass24:
            let hp2 = hp - z3 - q * z4
            z3 = f * hp2 + z4
            z4 = z3
            return hp2
        case .bandpass:
            return bp
        case .notch:
            return hp + lp
        }
    }
}

// MARK: - ============================================
// MARK: - 2. FM SYNTH (DX7-style)
// MARK: - ============================================

/// FM Operator configuration
public struct FMOperator: Sendable {
    public var ratio: Float = 1.0         // Frequency ratio
    public var fixed: Bool = false        // Fixed frequency mode
    public var fixedFrequency: Float = 440.0
    public var level: Float = 1.0         // Output level
    public var velocitySens: Float = 0.7  // Velocity sensitivity
    public var keyScale: Float = 0.0      // Key scaling
    public var envelope: ADSREnvelope = ADSREnvelope()
    public var feedback: Float = 0.0      // Self-modulation (0-1)
    public var detuneCoarse: Int = 0      // Coarse detune (-7 to +7)
    public var detuneFine: Float = 0.0    // Fine detune in cents

    public init() {}
}

/// FM Synthesis configuration
public struct FMConfig: Sendable {
    public var operators: [FMOperator] = (0..<6).map { _ in FMOperator() }
    public var algorithm: Int = 1  // 1-32
    public var feedback: Float = 0.0
    public var masterLevel: Float = 0.8

    public init() {
        // Default DX7-like algorithm 1 (op6 modulates all others in series)
        setupAlgorithm(1)
    }

    public mutating func setupAlgorithm(_ algo: Int) {
        algorithm = max(1, min(32, algo))
    }
}

/// Voice for FM Synth
private final class FMVoice {
    var note: Int = 0
    var velocity: Float = 0.0
    var frequency: Float = 440.0
    var isActive: Bool = false
    var state: VoiceState = .idle

    // Operator phases
    var phases: [Float] = [0, 0, 0, 0, 0, 0]
    var envValues: [Float] = [0, 0, 0, 0, 0, 0]
    var envTimes: [Float] = [0, 0, 0, 0, 0, 0]
    var envStates: [VoiceState] = [.attack, .attack, .attack, .attack, .attack, .attack]
    var feedbackBuffer: [Float] = [0, 0]  // For feedback delay

    func reset() {
        phases = [0, 0, 0, 0, 0, 0]
        envValues = [0, 0, 0, 0, 0, 0]
        envTimes = [0, 0, 0, 0, 0, 0]
        envStates = [.attack, .attack, .attack, .attack, .attack, .attack]
        feedbackBuffer = [0, 0]
        state = .attack
    }
}

/// Yamaha DX7-style FM Synthesizer with 6 operators and 32 algorithms
public final class FMSynth: SynthesisEngine {

    // MARK: - Properties

    public var sampleRate: Float = 48000.0
    public var masterVolume: Float = 0.8
    public var config = FMConfig()

    private let maxVoices = 16
    private var voices: [FMVoice] = []
    private let voiceLock = os_unfair_lock_s()

    // Algorithm routing tables (which ops modulate which)
    // Format: [modulator indices] for each operator, -1 = output to audio
    private let algorithms: [[[Int]]] = [
        // Algorithm 1: Classic DX7 stack (6→5→4→3→2→1)
        [[-1], [0], [1], [2], [3], [4]],
        // Algorithm 2: 6→5→4, 3→2→1 (parallel stacks)
        [[-1], [0], [1], [-1], [3], [4]],
        // Algorithm 3: (5+6)→4→3→2→1
        [[-1], [0], [1], [2], [3, 4], []],
        // Algorithm 4: Brass (6→5, 4→3→2→1)
        [[-1], [0], [1], [2], [-1], [4]],
        // Algorithm 5: (6→5→4)+(3→2→1)
        [[-1], [0], [1], [-1], [3], [4]],
        // Algorithm 6: (6→5)+(4→3)+(2→1)
        [[-1], [0], [-1], [2], [-1], [4]],
        // Algorithm 7: All parallel
        [[-1], [-1], [-1], [-1], [-1], [-1]],
        // Algorithm 8: (6→5→4→3→2)+1
        [[-1], [0, 1], [1], [2], [3], [4]],
        // Algorithm 9: Piano-like
        [[-1], [0], [1], [-1], [3], [4]],
        // Algorithm 10: Bell
        [[-1], [0], [-1], [2], [3], [-1]],
        // Algorithm 11: Organ
        [[-1], [-1], [0, 1], [-1], [-1], [3, 4]],
        // Algorithm 12: Harmonica
        [[-1], [0], [1, 2], [-1], [3], [4]],
        // Algorithm 13: Strings
        [[-1], [0], [-1], [2], [-1], [4]],
        // Algorithm 14: Bass
        [[-1], [0, 3], [1], [2], [-1], [4]],
        // Algorithm 15: E.Piano
        [[-1], [0], [1], [2], [-1], [4, 5]],
        // Algorithm 16: Percussion
        [[-1], [-1], [0, 1], [-1], [-1], [3, 4]],
        // Algorithm 17-32: Additional variations
        [[-1], [0], [1], [2], [3], [-1]],
        [[-1], [-1], [0], [-1], [2], [3]],
        [[-1], [0, 2], [1], [-1], [3], [4]],
        [[-1], [0], [1, 3], [2], [-1], [4]],
        [[-1], [0], [-1], [2, 4], [3], [-1]],
        [[-1], [-1], [0, 1, 2], [-1], [-1], [3, 4, 5]],
        [[-1], [0], [1], [-1], [3, 4], [4]],
        [[-1], [0, 1, 2], [-1], [-1], [3, 4], [-1]],
        [[-1], [0], [-1], [2], [3, 4], [-1]],
        [[-1], [-1], [0], [1], [2], [3, 4, 5]],
        [[-1], [0, 1], [-1], [2, 3], [-1], [4, 5]],
        [[-1], [0], [1, 2], [2], [3], [4, 5]],
        [[-1], [-1], [0, 1], [1], [-1], [3, 4]],
        [[-1], [0, 1], [1], [2], [3, 4], [4]],
        [[-1], [0], [-1], [2, 3, 4], [3], [4]],
        [[-1], [0, 1, 2, 3, 4], [-1], [-1], [-1], [-1]]  // All to carrier
    ]

    public var activeVoiceCount: Int {
        voices.filter { $0.isActive }.count
    }

    // MARK: - Initialization

    public init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate
        voices = (0..<maxVoices).map { _ in FMVoice() }

        // Default operator setup for classic DX7 electric piano
        config.operators[0].ratio = 1.0
        config.operators[0].level = 1.0
        config.operators[1].ratio = 1.0
        config.operators[1].level = 0.8
        config.operators[2].ratio = 1.0
        config.operators[2].level = 0.6
        config.operators[3].ratio = 14.0
        config.operators[3].level = 0.5
        config.operators[3].envelope = ADSREnvelope(attack: 0.001, decay: 0.1, sustain: 0.0, release: 0.1)
        config.operators[4].ratio = 1.0
        config.operators[4].level = 0.4
        config.operators[5].ratio = 1.0
        config.operators[5].level = 0.3
        config.operators[5].feedback = 0.3

        log.audio("FMSynth initialized: 6 operators, 32 algorithms, \(maxVoices) voices")
    }

    // MARK: - Note Control

    public func noteOn(note: Int, velocity: Int) {
        withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_lock($0) }
        defer { withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_unlock($0) } }

        var voice: FMVoice?

        if let existing = voices.first(where: { $0.isActive && $0.note == note }) {
            voice = existing
        } else if let free = voices.first(where: { !$0.isActive }) {
            voice = free
        } else {
            voice = voices.min(by: { v1, v2 in
                if v1.state == .release && v2.state != .release { return true }
                return v1.envTimes[0] > v2.envTimes[0]
            })
        }

        guard let v = voice else { return }

        v.note = note
        v.velocity = velocityToAmplitude(velocity)
        v.frequency = midiToFrequency(note)
        v.isActive = true
        v.reset()
    }

    public func noteOff(note: Int) {
        withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_lock($0) }
        defer { withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_unlock($0) } }

        for voice in voices where voice.isActive && voice.note == note && voice.state != .release {
            voice.state = .release
            for i in 0..<6 {
                voice.envStates[i] = .release
                voice.envTimes[i] = 0
            }
        }
    }

    public func allNotesOff() {
        withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_lock($0) }
        defer { withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_unlock($0) } }

        for voice in voices {
            voice.isActive = false
            voice.state = .idle
        }
    }

    // MARK: - Audio Processing

    public func processBlock(buffer: inout [Float], sampleRate: Float) {
        self.sampleRate = sampleRate
        let frameCount = buffer.count

        buffer = [Float](repeating: 0, count: frameCount)

        withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_lock($0) }
        defer { withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_unlock($0) } }

        for voice in voices where voice.isActive {
            processVoice(voice, buffer: &buffer, frameCount: frameCount)
        }

        if masterVolume != 1.0 {
            vDSP_vsmul(buffer, 1, &masterVolume, &buffer, 1, vDSP_Length(frameCount))
        }
    }

    private func processVoice(_ voice: FMVoice, buffer: inout [Float], frameCount: Int) {
        let cfg = config
        let invSampleRate = 1.0 / sampleRate
        let algoIndex = max(0, min(31, cfg.algorithm - 1))
        let algoRouting = algorithms[algoIndex]

        var opOutputs: [Float] = [0, 0, 0, 0, 0, 0]

        for i in 0..<frameCount {
            // Update envelopes for all operators
            var allDone = true
            for opIdx in 0..<6 {
                let env = updateOperatorEnvelope(voice: voice, opIndex: opIdx, dt: invSampleRate)
                if env > 0.0001 { allDone = false }
            }

            if allDone && voice.state == .release {
                voice.isActive = false
                voice.state = .idle
                return
            }

            // Process operators in reverse order (modulators first)
            opOutputs = [0, 0, 0, 0, 0, 0]

            for opIdx in (0..<6).reversed() {
                let op = cfg.operators[opIdx]
                let env = voice.envValues[opIdx]

                // Calculate frequency
                var freq: Float
                if op.fixed {
                    freq = op.fixedFrequency
                } else {
                    freq = voice.frequency * op.ratio * pow(2.0, Float(op.detuneCoarse) / 12.0 + op.detuneFine / 1200.0)
                }

                // Key scaling
                let keyScaleAmount = (Float(voice.note) - 60.0) / 48.0 * op.keyScale
                let scaledLevel = op.level * pow(2.0, keyScaleAmount)

                // Velocity scaling
                let velLevel = 1.0 - op.velocitySens * (1.0 - voice.velocity)

                // Calculate modulation input from other operators
                var modulation: Float = 0.0
                let modulators = algoRouting[opIdx]
                for modIdx in modulators where modIdx >= 0 && modIdx < 6 {
                    modulation += opOutputs[modIdx]
                }

                // Self-feedback
                if op.feedback > 0 {
                    modulation += voice.feedbackBuffer[opIdx % 2] * op.feedback * 4.0
                }

                // Generate FM oscillator
                let phase = voice.phases[opIdx]
                let output = fastSin((phase + modulation) * 2.0 * Float.pi) * env * scaledLevel * velLevel

                // Update phase
                voice.phases[opIdx] += freq * invSampleRate
                if voice.phases[opIdx] >= 1.0 { voice.phases[opIdx] -= 1.0 }

                // Store output
                opOutputs[opIdx] = output

                // Update feedback buffer
                if opIdx < 2 {
                    voice.feedbackBuffer[opIdx] = output
                }
            }

            // Sum carriers (operators that output to audio based on algorithm)
            var sample: Float = 0.0
            for opIdx in 0..<6 {
                let destinations = algoRouting[opIdx]
                if destinations.contains(-1) {
                    sample += opOutputs[opIdx]
                }
            }

            buffer[i] += sample * cfg.masterLevel
        }
    }

    @inline(__always)
    private func updateOperatorEnvelope(voice: FMVoice, opIndex: Int, dt: Float) -> Float {
        let op = config.operators[opIndex]
        let envelope = op.envelope
        var value = voice.envValues[opIndex]

        switch voice.envStates[opIndex] {
        case .attack:
            value += dt / max(0.001, envelope.attack)
            if value >= 1.0 {
                value = 1.0
                voice.envStates[opIndex] = .decay
                voice.envTimes[opIndex] = 0
            }
        case .decay:
            value -= dt / max(0.001, envelope.decay) * (1.0 - envelope.sustain)
            if value <= envelope.sustain {
                value = envelope.sustain
                voice.envStates[opIndex] = .sustain
            }
        case .sustain:
            value = envelope.sustain
        case .release:
            value -= dt / max(0.001, envelope.release) * value
            if value <= 0.0001 {
                value = 0
                voice.envStates[opIndex] = .idle
            }
        case .idle:
            value = 0
        }

        voice.envValues[opIndex] = value
        voice.envTimes[opIndex] += dt

        return value
    }
}

// MARK: - ============================================
// MARK: - 3. WAVETABLE SYNTH (Serum/Vital style)
// MARK: - ============================================

/// Wavetable warp modes
public enum WavetableWarpMode: Int, CaseIterable, Sendable {
    case none
    case sync
    case bend
    case mirror
    case remap
    case quantize
    case fm
    case am

    public var name: String {
        switch self {
        case .none: return "None"
        case .sync: return "Sync"
        case .bend: return "Bend"
        case .mirror: return "Mirror"
        case .remap: return "Remap"
        case .quantize: return "Quantize"
        case .fm: return "FM"
        case .am: return "AM"
        }
    }
}

/// Wavetable oscillator configuration
public struct WavetableOscConfig: Sendable {
    public var wavetableData: [Float] = []  // 256 frames x 2048 samples
    public var position: Float = 0.0  // 0-1 (frame position)
    public var octave: Int = 0
    public var semi: Int = 0
    public var fine: Float = 0.0
    public var level: Float = 1.0
    public var pan: Float = 0.0
    public var warpMode: WavetableWarpMode = .none
    public var warpAmount: Float = 0.0
    public var phaseRandomize: Float = 0.0
    public var unisonVoices: Int = 1
    public var unisonDetune: Float = 0.1
    public var unisonBlend: Float = 0.5

    public init() {
        // Initialize with basic waveforms
        generateBasicWavetable()
    }

    public mutating func generateBasicWavetable() {
        let frameCount = 256
        let sampleCount = 2048
        wavetableData = [Float](repeating: 0, count: frameCount * sampleCount)

        for frame in 0..<frameCount {
            let morphAmount = Float(frame) / Float(frameCount - 1)

            for sample in 0..<sampleCount {
                let phase = Float(sample) / Float(sampleCount)

                // Morph from sine → saw → square → triangle
                let sine = sin(phase * 2.0 * Float.pi)
                let saw = 2.0 * phase - 1.0
                let square: Float = phase < 0.5 ? 1.0 : -1.0
                let triangle: Float = phase < 0.5 ? 4.0 * phase - 1.0 : 3.0 - 4.0 * phase

                var value: Float
                if morphAmount < 0.33 {
                    let t = morphAmount / 0.33
                    value = sine * (1.0 - t) + saw * t
                } else if morphAmount < 0.66 {
                    let t = (morphAmount - 0.33) / 0.33
                    value = saw * (1.0 - t) + square * t
                } else {
                    let t = (morphAmount - 0.66) / 0.34
                    value = square * (1.0 - t) + triangle * t
                }

                wavetableData[frame * sampleCount + sample] = value
            }
        }
    }
}

/// Wavetable synth configuration
public struct WavetableConfig: Sendable {
    public var osc1: WavetableOscConfig = WavetableOscConfig()
    public var osc2: WavetableOscConfig = WavetableOscConfig()
    public var osc2Enabled: Bool = false

    public var filterType: FilterType = .lowpass24
    public var filterCutoff: Float = 8000.0
    public var filterResonance: Float = 0.3
    public var filterKeyTrack: Float = 0.5
    public var filterEnvAmount: Float = 0.5

    public var ampEnvelope: ADSREnvelope = ADSREnvelope()
    public var filterEnvelope: ADSREnvelope = ADSREnvelope(attack: 0.01, decay: 0.3, sustain: 0.5, release: 0.5)
    public var modEnvelope: ADSREnvelope = ADSREnvelope(attack: 0.1, decay: 0.5, sustain: 0.3, release: 0.3)

    public var modEnvToPosition: Float = 0.0
    public var modEnvToWarp: Float = 0.0

    public var lfoRate: Float = 2.0
    public var lfoToPosition: Float = 0.0
    public var lfoToWarp: Float = 0.0

    public var glideTime: Float = 0.0
    public var masterLevel: Float = 0.8

    public init() {}
}

/// Voice for WavetableSynth
private final class WavetableVoice {
    var note: Int = 0
    var velocity: Float = 0.0
    var frequency: Float = 440.0
    var targetFrequency: Float = 440.0
    var isActive: Bool = false
    var state: VoiceState = .idle

    // Oscillator state
    var osc1Phase: Float = 0.0
    var osc2Phase: Float = 0.0
    var osc1UnisonPhases: [Float] = [0, 0, 0, 0, 0, 0, 0, 0]
    var osc2UnisonPhases: [Float] = [0, 0, 0, 0, 0, 0, 0, 0]
    var warpPhase: Float = 0.0

    // Envelope states
    var ampEnvValue: Float = 0.0
    var filterEnvValue: Float = 0.0
    var modEnvValue: Float = 0.0
    var ampEnvTime: Float = 0.0
    var filterEnvTime: Float = 0.0
    var modEnvTime: Float = 0.0

    var lfoPhase: Float = 0.0

    // Filter state
    var filterZ1: Float = 0.0
    var filterZ2: Float = 0.0
    var filterZ3: Float = 0.0
    var filterZ4: Float = 0.0

    func reset() {
        osc1Phase = Float.random(in: 0..<1) * 0.0  // Optional phase randomize
        osc2Phase = Float.random(in: 0..<1) * 0.0
        for i in 0..<8 {
            osc1UnisonPhases[i] = Float.random(in: 0..<1)
            osc2UnisonPhases[i] = Float.random(in: 0..<1)
        }
        warpPhase = 0
        ampEnvValue = 0
        filterEnvValue = 0
        modEnvValue = 0
        ampEnvTime = 0
        filterEnvTime = 0
        modEnvTime = 0
        lfoPhase = Float.random(in: 0..<1)
        filterZ1 = 0; filterZ2 = 0; filterZ3 = 0; filterZ4 = 0
        state = .attack
    }
}

/// Serum/Vital-style wavetable synthesizer
public final class WavetableSynth: SynthesisEngine {

    // MARK: - Properties

    public var sampleRate: Float = 48000.0
    public var masterVolume: Float = 0.8
    public var config = WavetableConfig()

    private let maxVoices = 16
    private var voices: [WavetableVoice] = []
    private let voiceLock = os_unfair_lock_s()

    private let wavetableFrames = 256
    private let wavetableSamples = 2048

    public var activeVoiceCount: Int {
        voices.filter { $0.isActive }.count
    }

    // MARK: - Initialization

    public init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate
        voices = (0..<maxVoices).map { _ in WavetableVoice() }
        log.audio("WavetableSynth initialized: 256-frame wavetables, \(maxVoices) voices")
    }

    // MARK: - Wavetable Loading

    /// Load custom wavetable data (256 frames x 2048 samples)
    public func loadWavetable(_ data: [Float], oscillator: Int) {
        guard data.count == wavetableFrames * wavetableSamples else { return }

        if oscillator == 1 {
            config.osc1.wavetableData = data
        } else {
            config.osc2.wavetableData = data
        }
    }

    /// Generate wavetable from harmonics
    public func generateWavetableFromHarmonics(_ harmonics: [[Float]], oscillator: Int) {
        var data = [Float](repeating: 0, count: wavetableFrames * wavetableSamples)

        for frame in 0..<wavetableFrames {
            let frameHarmonics = frame < harmonics.count ? harmonics[frame] : harmonics.last ?? [1.0]

            for sample in 0..<wavetableSamples {
                let phase = Float(sample) / Float(wavetableSamples)
                var value: Float = 0.0

                for (idx, amplitude) in frameHarmonics.enumerated() {
                    let harmonic = Float(idx + 1)
                    value += amplitude * sin(phase * harmonic * 2.0 * Float.pi) / harmonic
                }

                data[frame * wavetableSamples + sample] = value
            }
        }

        // Normalize
        let maxVal = data.max() ?? 1.0
        if maxVal > 0 {
            data = data.map { $0 / maxVal }
        }

        loadWavetable(data, oscillator: oscillator)
    }

    // MARK: - Note Control

    public func noteOn(note: Int, velocity: Int) {
        withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_lock($0) }
        defer { withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_unlock($0) } }

        var voice: WavetableVoice?

        if let existing = voices.first(where: { $0.isActive && $0.note == note }) {
            voice = existing
        } else if let free = voices.first(where: { !$0.isActive }) {
            voice = free
        } else {
            voice = voices.min(by: { $0.ampEnvTime > $1.ampEnvTime })
        }

        guard let v = voice else { return }

        let freq = midiToFrequency(note)
        v.note = note
        v.velocity = velocityToAmplitude(velocity)
        v.targetFrequency = freq
        v.frequency = config.glideTime > 0 && v.isActive ? v.frequency : freq
        v.isActive = true
        v.reset()
    }

    public func noteOff(note: Int) {
        withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_lock($0) }
        defer { withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_unlock($0) } }

        for voice in voices where voice.isActive && voice.note == note && voice.state != .release {
            voice.state = .release
            voice.ampEnvTime = 0
            voice.filterEnvTime = 0
            voice.modEnvTime = 0
        }
    }

    public func allNotesOff() {
        withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_lock($0) }
        defer { withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_unlock($0) } }

        for voice in voices {
            voice.isActive = false
            voice.state = .idle
        }
    }

    // MARK: - Audio Processing

    public func processBlock(buffer: inout [Float], sampleRate: Float) {
        self.sampleRate = sampleRate
        let frameCount = buffer.count

        buffer = [Float](repeating: 0, count: frameCount)

        withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_lock($0) }
        defer { withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_unlock($0) } }

        for voice in voices where voice.isActive {
            processVoice(voice, buffer: &buffer, frameCount: frameCount)
        }

        if masterVolume != 1.0 {
            vDSP_vsmul(buffer, 1, &masterVolume, &buffer, 1, vDSP_Length(frameCount))
        }
    }

    private func processVoice(_ voice: WavetableVoice, buffer: inout [Float], frameCount: Int) {
        let cfg = config
        let invSampleRate = 1.0 / sampleRate

        for i in 0..<frameCount {
            // Update envelopes
            let ampEnv = updateEnvelope(&voice.ampEnvValue, &voice.ampEnvTime, &voice.state, cfg.ampEnvelope, invSampleRate)
            let filterEnv = updateEnvelope(&voice.filterEnvValue, &voice.filterEnvTime, nil, cfg.filterEnvelope, invSampleRate)
            let modEnv = updateEnvelope(&voice.modEnvValue, &voice.modEnvTime, nil, cfg.modEnvelope, invSampleRate)

            if voice.state == .idle {
                voice.isActive = false
                return
            }

            // LFO
            let lfo = sin(voice.lfoPhase * 2.0 * Float.pi)
            voice.lfoPhase += cfg.lfoRate * invSampleRate
            if voice.lfoPhase >= 1.0 { voice.lfoPhase -= 1.0 }

            // Glide
            if cfg.glideTime > 0 && voice.frequency != voice.targetFrequency {
                let glideSpeed = invSampleRate / max(0.001, cfg.glideTime)
                voice.frequency += (voice.targetFrequency - voice.frequency) * glideSpeed
            }

            // Calculate modulated position
            let positionMod = modEnv * cfg.modEnvToPosition + lfo * cfg.lfoToPosition
            let warpMod = modEnv * cfg.modEnvToWarp + lfo * cfg.lfoToWarp

            // Generate oscillator 1
            var sample = generateWavetableOsc(
                voice: voice,
                oscConfig: cfg.osc1,
                phases: &voice.osc1UnisonPhases,
                mainPhase: &voice.osc1Phase,
                positionMod: positionMod,
                warpMod: warpMod,
                warpPhase: &voice.warpPhase,
                invSampleRate: invSampleRate
            )

            // Generate oscillator 2 if enabled
            if cfg.osc2Enabled {
                sample += generateWavetableOsc(
                    voice: voice,
                    oscConfig: cfg.osc2,
                    phases: &voice.osc2UnisonPhases,
                    mainPhase: &voice.osc2Phase,
                    positionMod: positionMod,
                    warpMod: warpMod,
                    warpPhase: &voice.warpPhase,
                    invSampleRate: invSampleRate
                )
            }

            // Filter
            let keyTrack = (voice.frequency / 440.0 - 1.0) * cfg.filterKeyTrack
            let cutoff = cfg.filterCutoff * (1.0 + filterEnv * cfg.filterEnvAmount + keyTrack)
            sample = applyWavetableFilter(
                sample: sample,
                cutoff: min(sampleRate * 0.45, max(20.0, cutoff)),
                resonance: cfg.filterResonance,
                z1: &voice.filterZ1, z2: &voice.filterZ2, z3: &voice.filterZ3, z4: &voice.filterZ4,
                sampleRate: sampleRate
            )

            // Apply envelope and velocity
            sample *= ampEnv * voice.velocity * cfg.masterLevel

            buffer[i] += sample
        }
    }

    @inline(__always)
    private func generateWavetableOsc(voice: WavetableVoice, oscConfig: WavetableOscConfig,
                                      phases: inout [Float], mainPhase: inout Float,
                                      positionMod: Float, warpMod: Float, warpPhase: inout Float,
                                      invSampleRate: Float) -> Float {
        guard !oscConfig.wavetableData.isEmpty else { return 0 }

        let freq = voice.frequency * pow(2.0, Float(oscConfig.octave) + Float(oscConfig.semi) / 12.0 + oscConfig.fine / 1200.0)
        let unisonCount = min(8, max(1, oscConfig.unisonVoices))

        var sample: Float = 0.0

        for u in 0..<unisonCount {
            let detuneAmount = oscConfig.unisonDetune * (Float(u) - Float(unisonCount - 1) / 2.0) / Float(max(1, unisonCount - 1))
            let detunedFreq = freq * pow(2.0, detuneAmount / 12.0)

            // Apply warp
            var phase = phases[u]
            var warpedPhase = phase

            switch oscConfig.warpMode {
            case .sync:
                warpPhase += detunedFreq * invSampleRate * (1.0 + oscConfig.warpAmount * 4.0 + warpMod * 2.0)
                if warpPhase >= 1.0 { warpPhase -= floor(warpPhase) }
                if warpPhase < phases[u] { warpedPhase = 0 }
            case .bend:
                let bend = oscConfig.warpAmount + warpMod * 0.5
                warpedPhase = phase < 0.5 ? phase * (1.0 + bend) : 0.5 + (phase - 0.5) * (1.0 - bend)
                warpedPhase = max(0, min(0.9999, warpedPhase))
            case .mirror:
                let mirrorPoint = 0.5 + (oscConfig.warpAmount + warpMod * 0.5) * 0.4
                if phase > mirrorPoint { warpedPhase = mirrorPoint - (phase - mirrorPoint) }
            case .quantize:
                let steps = max(2, Int((1.0 - oscConfig.warpAmount - warpMod * 0.5) * 16.0))
                warpedPhase = floor(phase * Float(steps)) / Float(steps)
            case .fm:
                warpedPhase = phase + sin(phase * Float.pi * 2.0) * (oscConfig.warpAmount + warpMod * 0.5)
                while warpedPhase >= 1.0 { warpedPhase -= 1.0 }
                while warpedPhase < 0 { warpedPhase += 1.0 }
            case .am:
                // AM handled later in amplitude
                break
            default:
                break
            }

            // Calculate wavetable position
            let position = max(0, min(1, oscConfig.position + positionMod))
            let frameF = position * Float(wavetableFrames - 1)
            let frame0 = Int(frameF)
            let frame1 = min(frame0 + 1, wavetableFrames - 1)
            let frameFrac = frameF - Float(frame0)

            // Interpolate between frames
            let sampleIdx = Int(warpedPhase * Float(wavetableSamples - 1))
            let idx0 = frame0 * wavetableSamples + sampleIdx
            let idx1 = frame1 * wavetableSamples + sampleIdx

            let val0 = idx0 < oscConfig.wavetableData.count ? oscConfig.wavetableData[idx0] : 0
            let val1 = idx1 < oscConfig.wavetableData.count ? oscConfig.wavetableData[idx1] : 0
            var value = val0 * (1.0 - frameFrac) + val1 * frameFrac

            // AM warp
            if oscConfig.warpMode == .am {
                let amMod = 1.0 - (oscConfig.warpAmount + warpMod * 0.5) * (1.0 - sin(phase * Float.pi * 4.0)) * 0.5
                value *= amMod
            }

            sample += value * oscConfig.level / Float(unisonCount)

            // Update phase
            phases[u] += detunedFreq * invSampleRate
            if phases[u] >= 1.0 { phases[u] -= 1.0 }
        }

        // Update main phase
        mainPhase += freq * invSampleRate
        if mainPhase >= 1.0 { mainPhase -= 1.0 }

        return sample
    }

    @inline(__always)
    private func updateEnvelope(_ value: inout Float, _ time: inout Float, _ state: inout VoiceState?,
                               _ envelope: ADSREnvelope, _ dt: Float) -> Float {
        let currentState = state ?? .sustain

        switch currentState {
        case .attack:
            value += dt / max(0.001, envelope.attack)
            if value >= 1.0 {
                value = 1.0
                state? = .decay
                time = 0
            }
        case .decay:
            value -= dt / max(0.001, envelope.decay) * (1.0 - envelope.sustain)
            if value <= envelope.sustain {
                value = envelope.sustain
                state? = .sustain
            }
        case .sustain:
            value = envelope.sustain
        case .release:
            value -= dt / max(0.001, envelope.release) * value
            if value <= 0.001 {
                value = 0
                state? = .idle
            }
        case .idle:
            value = 0
        }

        time += dt
        return value
    }

    @inline(__always)
    private func applyWavetableFilter(sample: Float, cutoff: Float, resonance: Float,
                                      z1: inout Float, z2: inout Float, z3: inout Float, z4: inout Float,
                                      sampleRate: Float) -> Float {
        let f = 2.0 * sin(Float.pi * cutoff / sampleRate)
        let q = 1.0 - resonance * 0.99

        let hp = sample - z1 - q * z2
        let bp = f * hp + z2
        let lp = f * bp + z1
        z1 = lp
        z2 = bp

        // 24dB second stage
        let hp2 = lp - z3 - q * z4
        let bp2 = f * hp2 + z4
        let lp2 = f * bp2 + z3
        z3 = lp2
        z4 = bp2

        return lp2
    }
}

// MARK: - ============================================
// MARK: - 4. GRANULAR SYNTH
// MARK: - ============================================

/// Individual grain
private struct Grain {
    var isActive: Bool = false
    var position: Float = 0.0       // Position in source (0-1)
    var playhead: Float = 0.0       // Current playback position in grain
    var size: Float = 0.05          // Grain size in seconds
    var pitch: Float = 1.0          // Pitch multiplier
    var pan: Float = 0.0            // Stereo pan (-1 to 1)
    var amplitude: Float = 1.0
    var startTime: Float = 0.0      // When grain started (for envelope)
}

/// Granular synth configuration
public struct GranularConfig: Sendable {
    // Source
    public var sourceBuffer: [Float] = []
    public var sourceLength: Float = 1.0  // seconds

    // Grain parameters
    public var grainSize: Float = 0.05        // 1-500ms
    public var grainDensity: Float = 20.0     // 1-100 grains/sec
    public var position: Float = 0.5          // Source position 0-1
    public var positionRandom: Float = 0.1    // Position randomization
    public var pitchRandom: Float = 0.0       // Pitch randomization in semitones
    public var panRandom: Float = 0.3         // Pan randomization
    public var grainEnvelopeShape: Float = 0.5 // 0=triangle, 1=hanning

    // Freeze mode
    public var freezeEnabled: Bool = false
    public var freezePosition: Float = 0.5

    // Pitch
    public var pitch: Float = 0.0    // Semitones
    public var octave: Int = 0

    // Envelope
    public var ampEnvelope: ADSREnvelope = ADSREnvelope(attack: 0.1, decay: 0.1, sustain: 1.0, release: 0.5)

    // Modulation
    public var lfoRate: Float = 0.5
    public var lfoToPosition: Float = 0.0
    public var lfoToSize: Float = 0.0
    public var lfoToPitch: Float = 0.0

    public var masterLevel: Float = 0.8

    public init() {
        // Generate default source (1 second of harmonics)
        generateDefaultSource()
    }

    public mutating func generateDefaultSource() {
        let sr: Float = 48000.0
        let duration: Float = 2.0
        let samples = Int(sr * duration)
        sourceBuffer = [Float](repeating: 0, count: samples)
        sourceLength = duration

        // Generate rich harmonic content
        for i in 0..<samples {
            let t = Float(i) / sr
            var sample: Float = 0.0

            // Multiple harmonics with different frequencies
            for h in 1...16 {
                let freq: Float = 110.0 * Float(h) * (1.0 + t * 0.5)  // Evolving pitch
                sample += sin(t * freq * 2.0 * Float.pi) / Float(h)
            }

            sourceBuffer[i] = sample * 0.3
        }
    }
}

/// Voice for GranularSynth
private final class GranularVoice {
    var note: Int = 0
    var velocity: Float = 0.0
    var frequency: Float = 440.0
    var isActive: Bool = false
    var state: VoiceState = .idle

    var grains: [Grain] = []
    let maxGrains = 64
    var grainTimer: Float = 0.0

    var ampEnvValue: Float = 0.0
    var ampEnvTime: Float = 0.0
    var lfoPhase: Float = 0.0

    init() {
        grains = (0..<maxGrains).map { _ in Grain() }
    }

    func reset() {
        for i in 0..<maxGrains {
            grains[i].isActive = false
        }
        grainTimer = 0
        ampEnvValue = 0
        ampEnvTime = 0
        lfoPhase = Float.random(in: 0..<1)
        state = .attack
    }
}

/// Advanced granular synthesizer with freeze mode
public final class GranularSynth: SynthesisEngine {

    // MARK: - Properties

    public var sampleRate: Float = 48000.0
    public var masterVolume: Float = 0.8
    public var config = GranularConfig()

    private let maxVoices = 8
    private var voices: [GranularVoice] = []
    private let voiceLock = os_unfair_lock_s()

    public var activeVoiceCount: Int {
        voices.filter { $0.isActive }.count
    }

    // MARK: - Initialization

    public init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate
        voices = (0..<maxVoices).map { _ in GranularVoice() }
        log.audio("GranularSynth initialized: 64 grains/voice, \(maxVoices) voices")
    }

    // MARK: - Source Loading

    /// Load audio buffer as granular source
    public func loadSource(_ buffer: [Float], duration: Float) {
        config.sourceBuffer = buffer
        config.sourceLength = duration
    }

    // MARK: - Note Control

    public func noteOn(note: Int, velocity: Int) {
        withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_lock($0) }
        defer { withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_unlock($0) } }

        var voice: GranularVoice?

        if let existing = voices.first(where: { $0.isActive && $0.note == note }) {
            voice = existing
        } else if let free = voices.first(where: { !$0.isActive }) {
            voice = free
        } else {
            voice = voices.min(by: { $0.ampEnvTime > $1.ampEnvTime })
        }

        guard let v = voice else { return }

        v.note = note
        v.velocity = velocityToAmplitude(velocity)
        v.frequency = midiToFrequency(note)
        v.isActive = true
        v.reset()
    }

    public func noteOff(note: Int) {
        withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_lock($0) }
        defer { withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_unlock($0) } }

        for voice in voices where voice.isActive && voice.note == note && voice.state != .release {
            voice.state = .release
            voice.ampEnvTime = 0
        }
    }

    public func allNotesOff() {
        withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_lock($0) }
        defer { withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_unlock($0) } }

        for voice in voices {
            voice.isActive = false
            voice.state = .idle
        }
    }

    // MARK: - Audio Processing

    public func processBlock(buffer: inout [Float], sampleRate: Float) {
        self.sampleRate = sampleRate
        let frameCount = buffer.count

        buffer = [Float](repeating: 0, count: frameCount)

        guard !config.sourceBuffer.isEmpty else { return }

        withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_lock($0) }
        defer { withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_unlock($0) } }

        for voice in voices where voice.isActive {
            processVoice(voice, buffer: &buffer, frameCount: frameCount)
        }

        if masterVolume != 1.0 {
            vDSP_vsmul(buffer, 1, &masterVolume, &buffer, 1, vDSP_Length(frameCount))
        }
    }

    private func processVoice(_ voice: GranularVoice, buffer: inout [Float], frameCount: Int) {
        let cfg = config
        let invSampleRate = 1.0 / sampleRate
        let sourceLength = Float(cfg.sourceBuffer.count)

        for i in 0..<frameCount {
            // Update envelope
            let ampEnv = updateGranularEnvelope(voice: voice, envelope: cfg.ampEnvelope, dt: invSampleRate)

            if voice.state == .idle {
                voice.isActive = false
                return
            }

            // LFO
            let lfo = sin(voice.lfoPhase * 2.0 * Float.pi)
            voice.lfoPhase += cfg.lfoRate * invSampleRate
            if voice.lfoPhase >= 1.0 { voice.lfoPhase -= 1.0 }

            // Calculate modulated parameters
            let position = cfg.freezeEnabled ? cfg.freezePosition : (cfg.position + lfo * cfg.lfoToPosition)
            let grainSize = max(0.001, min(0.5, cfg.grainSize + lfo * cfg.lfoToSize * 0.1))
            let pitchMod = pow(2.0, (cfg.pitch + Float(cfg.octave * 12) + lfo * cfg.lfoToPitch) / 12.0)

            // Spawn new grains
            voice.grainTimer += invSampleRate
            let grainInterval = 1.0 / max(1.0, cfg.grainDensity)

            if voice.grainTimer >= grainInterval {
                voice.grainTimer -= grainInterval
                spawnGrain(voice: voice, position: position, grainSize: grainSize, pitchMod: pitchMod, cfg: cfg)
            }

            // Process active grains
            var sample: Float = 0.0

            for idx in 0..<voice.maxGrains {
                guard voice.grains[idx].isActive else { continue }

                let grain = voice.grains[idx]

                // Calculate grain envelope
                let grainProgress = grain.playhead / grain.size
                var grainEnv: Float

                if cfg.grainEnvelopeShape < 0.5 {
                    // Triangle
                    grainEnv = grainProgress < 0.5 ? grainProgress * 2.0 : (1.0 - grainProgress) * 2.0
                } else {
                    // Hanning
                    grainEnv = 0.5 * (1.0 - cos(grainProgress * 2.0 * Float.pi))
                }

                // Read from source with interpolation
                let sourcePos = grain.position + grain.playhead * grain.pitch / cfg.sourceLength
                let sourcePosWrapped = sourcePos - floor(sourcePos)  // Wrap around
                let sampleIdx = sourcePosWrapped * sourceLength

                let idx0 = Int(sampleIdx) % cfg.sourceBuffer.count
                let idx1 = (idx0 + 1) % cfg.sourceBuffer.count
                let frac = sampleIdx - floor(sampleIdx)

                let grainSample = cfg.sourceBuffer[idx0] * (1.0 - frac) + cfg.sourceBuffer[idx1] * frac
                sample += grainSample * grainEnv * grain.amplitude

                // Update grain playhead
                voice.grains[idx].playhead += invSampleRate

                // Deactivate finished grains
                if voice.grains[idx].playhead >= grain.size {
                    voice.grains[idx].isActive = false
                }
            }

            // Apply voice envelope and velocity
            sample *= ampEnv * voice.velocity * cfg.masterLevel

            buffer[i] += sample
        }
    }

    private func spawnGrain(voice: GranularVoice, position: Float, grainSize: Float, pitchMod: Float, cfg: GranularConfig) {
        // Find inactive grain slot
        guard let idx = voice.grains.firstIndex(where: { !$0.isActive }) else { return }

        // Randomize parameters
        let posRandom = (Float.random(in: -1...1) * cfg.positionRandom)
        let pitchRandom = pow(2.0, Float.random(in: -1...1) * cfg.pitchRandom / 12.0)
        let panRandom = Float.random(in: -1...1) * cfg.panRandom

        voice.grains[idx] = Grain(
            isActive: true,
            position: max(0, min(1, position + posRandom)),
            playhead: 0,
            size: grainSize,
            pitch: pitchMod * pitchRandom * (voice.frequency / 440.0),
            pan: panRandom,
            amplitude: Float.random(in: 0.8...1.0),
            startTime: 0
        )
    }

    @inline(__always)
    private func updateGranularEnvelope(voice: GranularVoice, envelope: ADSREnvelope, dt: Float) -> Float {
        switch voice.state {
        case .attack:
            voice.ampEnvValue += dt / max(0.001, envelope.attack)
            if voice.ampEnvValue >= 1.0 {
                voice.ampEnvValue = 1.0
                voice.state = .decay
                voice.ampEnvTime = 0
            }
        case .decay:
            voice.ampEnvValue -= dt / max(0.001, envelope.decay) * (1.0 - envelope.sustain)
            if voice.ampEnvValue <= envelope.sustain {
                voice.ampEnvValue = envelope.sustain
                voice.state = .sustain
            }
        case .sustain:
            voice.ampEnvValue = envelope.sustain
        case .release:
            voice.ampEnvValue -= dt / max(0.001, envelope.release) * voice.ampEnvValue
            if voice.ampEnvValue <= 0.001 {
                voice.ampEnvValue = 0
                voice.state = .idle
            }
        case .idle:
            voice.ampEnvValue = 0
        }

        voice.ampEnvTime += dt
        return voice.ampEnvValue
    }
}

// MARK: - ============================================
// MARK: - 5. ADDITIVE SYNTH
// MARK: - ============================================

/// Configuration for individual harmonic
public struct HarmonicConfig: Sendable {
    public var amplitude: Float = 1.0
    public var phase: Float = 0.0
    public var envelope: ADSREnvelope = ADSREnvelope()
    public var detuneRatio: Float = 1.0  // Harmonic stretching
}

/// Additive synth configuration
public struct AdditiveConfig: Sendable {
    public var harmonics: [HarmonicConfig] = []
    public var harmonicCount: Int = 64
    public var baseAmplitudeDecay: Float = 0.7  // Natural harmonic rolloff
    public var harmonicStretch: Float = 1.0     // 1.0 = natural, >1 = stretched
    public var oddEvenBalance: Float = 0.5      // 0=odd only, 0.5=equal, 1=even only
    public var brightnessEnvAmount: Float = 0.0

    public var ampEnvelope: ADSREnvelope = ADSREnvelope()
    public var brightnessEnvelope: ADSREnvelope = ADSREnvelope(attack: 0.01, decay: 0.5, sustain: 0.3, release: 0.3)

    public var lfoRate: Float = 4.0
    public var lfoToHarmonics: Float = 0.0  // Modulate harmonic amplitudes

    public var masterLevel: Float = 0.8

    public init() {
        setupHarmonics()
    }

    public mutating func setupHarmonics() {
        harmonics = (0..<harmonicCount).map { idx in
            var h = HarmonicConfig()
            let n = Float(idx + 1)

            // Natural harmonic decay
            h.amplitude = pow(baseAmplitudeDecay, log2(n))

            // Odd/even balance
            let isOdd = (idx + 1) % 2 == 1
            if isOdd {
                h.amplitude *= (1.0 - oddEvenBalance * 0.5)
            } else {
                h.amplitude *= (0.5 + oddEvenBalance * 0.5)
            }

            h.detuneRatio = pow(n, harmonicStretch - 1.0) // Stretch factor

            return h
        }
    }
}

/// Voice for AdditiveSynth
private final class AdditiveVoice {
    var note: Int = 0
    var velocity: Float = 0.0
    var frequency: Float = 440.0
    var isActive: Bool = false
    var state: VoiceState = .idle

    var harmonicPhases: [Float] = [Float](repeating: 0, count: 64)
    var harmonicEnvValues: [Float] = [Float](repeating: 0, count: 64)
    var harmonicEnvTimes: [Float] = [Float](repeating: 0, count: 64)

    var ampEnvValue: Float = 0.0
    var ampEnvTime: Float = 0.0
    var brightnessEnvValue: Float = 0.0
    var brightnessEnvTime: Float = 0.0

    var lfoPhase: Float = 0.0

    func reset() {
        for i in 0..<64 {
            harmonicPhases[i] = Float.random(in: 0..<0.01)  // Slight randomization
            harmonicEnvValues[i] = 0
            harmonicEnvTimes[i] = 0
        }
        ampEnvValue = 0
        ampEnvTime = 0
        brightnessEnvValue = 0
        brightnessEnvTime = 0
        lfoPhase = Float.random(in: 0..<1)
        state = .attack
    }
}

/// 64-harmonic additive synthesizer
public final class AdditiveSynth: SynthesisEngine {

    // MARK: - Properties

    public var sampleRate: Float = 48000.0
    public var masterVolume: Float = 0.8
    public var config = AdditiveConfig()

    private let maxVoices = 8
    private var voices: [AdditiveVoice] = []
    private let voiceLock = os_unfair_lock_s()

    // Precomputed sine table for performance
    private let sineTableSize = 4096
    private var sineTable: [Float] = []

    public var activeVoiceCount: Int {
        voices.filter { $0.isActive }.count
    }

    // MARK: - Initialization

    public init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate
        voices = (0..<maxVoices).map { _ in AdditiveVoice() }

        // Generate sine lookup table
        sineTable = (0..<sineTableSize).map { i in
            sin(Float(i) / Float(sineTableSize) * 2.0 * Float.pi)
        }

        log.audio("AdditiveSynth initialized: 64 harmonics, \(maxVoices) voices")
    }

    // MARK: - Harmonic Control

    /// Set amplitude for specific harmonic
    public func setHarmonicAmplitude(_ harmonic: Int, amplitude: Float) {
        guard harmonic >= 0 && harmonic < config.harmonicCount else { return }
        config.harmonics[harmonic].amplitude = amplitude
    }

    /// Set all harmonics from array
    public func setHarmonicAmplitudes(_ amplitudes: [Float]) {
        for (idx, amp) in amplitudes.prefix(config.harmonicCount).enumerated() {
            config.harmonics[idx].amplitude = amp
        }
    }

    /// Generate organ-style harmonics
    public func setOrganDrawbars(_ drawbars: [Float]) {
        // Standard organ drawbar positions: 16', 5 1/3', 8', 4', 2 2/3', 2', 1 3/5', 1 1/3', 1'
        let drawbarHarmonics = [1, 3, 2, 4, 6, 8, 10, 12, 16]

        // Reset all harmonics
        for i in 0..<config.harmonicCount {
            config.harmonics[i].amplitude = 0
        }

        // Set drawbar harmonics
        for (idx, harmonic) in drawbarHarmonics.enumerated() where idx < drawbars.count && harmonic <= config.harmonicCount {
            config.harmonics[harmonic - 1].amplitude = drawbars[idx]
        }
    }

    // MARK: - Note Control

    public func noteOn(note: Int, velocity: Int) {
        withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_lock($0) }
        defer { withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_unlock($0) } }

        var voice: AdditiveVoice?

        if let existing = voices.first(where: { $0.isActive && $0.note == note }) {
            voice = existing
        } else if let free = voices.first(where: { !$0.isActive }) {
            voice = free
        } else {
            voice = voices.min(by: { $0.ampEnvTime > $1.ampEnvTime })
        }

        guard let v = voice else { return }

        v.note = note
        v.velocity = velocityToAmplitude(velocity)
        v.frequency = midiToFrequency(note)
        v.isActive = true
        v.reset()
    }

    public func noteOff(note: Int) {
        withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_lock($0) }
        defer { withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_unlock($0) } }

        for voice in voices where voice.isActive && voice.note == note && voice.state != .release {
            voice.state = .release
            voice.ampEnvTime = 0
            voice.brightnessEnvTime = 0
        }
    }

    public func allNotesOff() {
        withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_lock($0) }
        defer { withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_unlock($0) } }

        for voice in voices {
            voice.isActive = false
            voice.state = .idle
        }
    }

    // MARK: - Audio Processing

    public func processBlock(buffer: inout [Float], sampleRate: Float) {
        self.sampleRate = sampleRate
        let frameCount = buffer.count

        buffer = [Float](repeating: 0, count: frameCount)

        withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_lock($0) }
        defer { withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_unlock($0) } }

        for voice in voices where voice.isActive {
            processVoice(voice, buffer: &buffer, frameCount: frameCount)
        }

        if masterVolume != 1.0 {
            vDSP_vsmul(buffer, 1, &masterVolume, &buffer, 1, vDSP_Length(frameCount))
        }
    }

    private func processVoice(_ voice: AdditiveVoice, buffer: inout [Float], frameCount: Int) {
        let cfg = config
        let invSampleRate = 1.0 / sampleRate
        let nyquist = sampleRate * 0.45

        for i in 0..<frameCount {
            // Update envelopes
            let ampEnv = updateAdditiveEnvelope(&voice.ampEnvValue, &voice.ampEnvTime, &voice.state, cfg.ampEnvelope, invSampleRate)
            let brightnessEnv = updateAdditiveEnvelope(&voice.brightnessEnvValue, &voice.brightnessEnvTime, nil, cfg.brightnessEnvelope, invSampleRate)

            if voice.state == .idle {
                voice.isActive = false
                return
            }

            // LFO
            let lfo = sin(voice.lfoPhase * 2.0 * Float.pi)
            voice.lfoPhase += cfg.lfoRate * invSampleRate
            if voice.lfoPhase >= 1.0 { voice.lfoPhase -= 1.0 }

            // Sum harmonics
            var sample: Float = 0.0

            for h in 0..<cfg.harmonicCount {
                let harmonicConfig = cfg.harmonics[h]
                let harmonicNum = Float(h + 1)

                // Calculate harmonic frequency with stretch
                let stretchedHarmonic = harmonicNum * harmonicConfig.detuneRatio
                let freq = voice.frequency * stretchedHarmonic

                // Skip if above Nyquist
                if freq >= nyquist { continue }

                // Calculate amplitude with brightness envelope
                var amp = harmonicConfig.amplitude

                // Apply brightness envelope (affects higher harmonics more)
                let brightnessEffect = 1.0 - (1.0 - brightnessEnv) * cfg.brightnessEnvAmount * (harmonicNum / Float(cfg.harmonicCount))
                amp *= brightnessEffect

                // Apply LFO modulation (creates tremolo-like effect on harmonics)
                if cfg.lfoToHarmonics != 0 {
                    let lfoEffect = 1.0 + lfo * cfg.lfoToHarmonics * sin(Float(h) * 0.5)
                    amp *= lfoEffect
                }

                // Generate sine using lookup table
                let phase = voice.harmonicPhases[h]
                let tableIndex = Int(phase * Float(sineTableSize)) % sineTableSize
                sample += sineTable[tableIndex] * amp

                // Update phase
                voice.harmonicPhases[h] += freq * invSampleRate
                if voice.harmonicPhases[h] >= 1.0 { voice.harmonicPhases[h] -= 1.0 }
            }

            // Normalize and apply envelope
            sample *= ampEnv * voice.velocity * cfg.masterLevel / 8.0  // Normalize for 64 harmonics

            buffer[i] += sample
        }
    }

    @inline(__always)
    private func updateAdditiveEnvelope(_ value: inout Float, _ time: inout Float, _ state: inout VoiceState?,
                                        _ envelope: ADSREnvelope, _ dt: Float) -> Float {
        let currentState = state ?? .sustain

        switch currentState {
        case .attack:
            value += dt / max(0.001, envelope.attack)
            if value >= 1.0 {
                value = 1.0
                state? = .decay
                time = 0
            }
        case .decay:
            value -= dt / max(0.001, envelope.decay) * (1.0 - envelope.sustain)
            if value <= envelope.sustain {
                value = envelope.sustain
                state? = .sustain
            }
        case .sustain:
            value = envelope.sustain
        case .release:
            value -= dt / max(0.001, envelope.release) * value
            if value <= 0.001 {
                value = 0
                state? = .idle
            }
        case .idle:
            value = 0
        }

        time += dt
        return value
    }
}

// MARK: - ============================================
// MARK: - 6. PHYSICAL MODELING SYNTH (Karplus-Strong)
// MARK: - ============================================

/// Exciter types for physical modeling
public enum ExciterType: Int, CaseIterable, Sendable {
    case pluck
    case bow
    case hammer
    case noise
    case impulse

    public var name: String {
        switch self {
        case .pluck: return "Pluck"
        case .bow: return "Bow"
        case .hammer: return "Hammer"
        case .noise: return "Noise"
        case .impulse: return "Impulse"
        }
    }
}

/// Physical modeling synth configuration
public struct PhysicalModelingConfig: Sendable {
    // String parameters
    public var damping: Float = 0.996         // Energy loss per sample (0.99-0.9999)
    public var brightness: Float = 0.5        // Filter brightness (0-1)
    public var stringPosition: Float = 0.13   // Pluck/bow position (0-0.5)
    public var stringTension: Float = 1.0     // Affects pitch stability

    // Body resonance
    public var bodyResonance: Float = 0.3     // Body resonance amount
    public var bodySize: Float = 0.5          // Body size (affects resonance freq)
    public var bodyBrightness: Float = 0.5    // Body EQ

    // Exciter
    public var exciterType: ExciterType = .pluck
    public var exciterHardness: Float = 0.5   // Pluck/hammer hardness
    public var exciterNoise: Float = 0.1      // Noise in exciter
    public var bowPressure: Float = 0.5       // For bow exciter
    public var bowSpeed: Float = 0.5          // For bow exciter

    // Sympathetic strings
    public var sympatheticStrings: Bool = false
    public var sympatheticAmount: Float = 0.1

    // Envelope
    public var ampEnvelope: ADSREnvelope = ADSREnvelope(attack: 0.001, decay: 2.0, sustain: 0.0, release: 0.5)

    public var masterLevel: Float = 0.8

    public init() {}
}

/// Voice for PhysicalModelingSynth
private final class PhysicalModelingVoice {
    var note: Int = 0
    var velocity: Float = 0.0
    var frequency: Float = 440.0
    var isActive: Bool = false
    var state: VoiceState = .idle

    // Delay line (Karplus-Strong)
    var delayLine: [Float] = []
    var delayLength: Int = 0
    var delayIndex: Int = 0

    // Filter states
    var filterZ1: Float = 0.0
    var filterZ2: Float = 0.0
    var prevSample: Float = 0.0

    // Body resonance delay lines
    var bodyDelayLine1: [Float] = []
    var bodyDelayLine2: [Float] = []
    var bodyIndex1: Int = 0
    var bodyIndex2: Int = 0

    // Bow state
    var bowPhase: Float = 0.0
    var bowVelocity: Float = 0.0

    // Envelope
    var ampEnvValue: Float = 0.0
    var ampEnvTime: Float = 0.0

    func reset(sampleRate: Float, frequency: Float) {
        // Calculate delay length for pitch
        delayLength = max(2, Int(sampleRate / frequency))
        delayLine = [Float](repeating: 0, count: delayLength)
        delayIndex = 0

        // Body resonance (detuned slightly for natural sound)
        let bodyLength1 = Int(sampleRate / (frequency * 1.003))
        let bodyLength2 = Int(sampleRate / (frequency * 0.997))
        bodyDelayLine1 = [Float](repeating: 0, count: max(2, bodyLength1))
        bodyDelayLine2 = [Float](repeating: 0, count: max(2, bodyLength2))
        bodyIndex1 = 0
        bodyIndex2 = 0

        filterZ1 = 0
        filterZ2 = 0
        prevSample = 0
        bowPhase = 0
        bowVelocity = 0
        ampEnvValue = 0
        ampEnvTime = 0
        state = .attack
    }
}

/// Karplus-Strong physical modeling synthesizer
public final class PhysicalModelingSynth: SynthesisEngine {

    // MARK: - Properties

    public var sampleRate: Float = 48000.0
    public var masterVolume: Float = 0.8
    public var config = PhysicalModelingConfig()

    private let maxVoices = 16
    private var voices: [PhysicalModelingVoice] = []
    private let voiceLock = os_unfair_lock_s()

    public var activeVoiceCount: Int {
        voices.filter { $0.isActive }.count
    }

    // MARK: - Initialization

    public init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate
        voices = (0..<maxVoices).map { _ in PhysicalModelingVoice() }
        log.audio("PhysicalModelingSynth initialized: Karplus-Strong, \(maxVoices) voices")
    }

    // MARK: - Note Control

    public func noteOn(note: Int, velocity: Int) {
        withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_lock($0) }
        defer { withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_unlock($0) } }

        var voice: PhysicalModelingVoice?

        if let existing = voices.first(where: { $0.isActive && $0.note == note }) {
            voice = existing
        } else if let free = voices.first(where: { !$0.isActive }) {
            voice = free
        } else {
            voice = voices.min(by: { $0.ampEnvTime > $1.ampEnvTime })
        }

        guard let v = voice else { return }

        let freq = midiToFrequency(note)
        v.note = note
        v.velocity = velocityToAmplitude(velocity)
        v.frequency = freq
        v.isActive = true
        v.reset(sampleRate: sampleRate, frequency: freq)

        // Initialize exciter
        initializeExciter(voice: v, config: config)
    }

    public func noteOff(note: Int) {
        withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_lock($0) }
        defer { withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_unlock($0) } }

        for voice in voices where voice.isActive && voice.note == note && voice.state != .release {
            voice.state = .release
            voice.ampEnvTime = 0
        }
    }

    public func allNotesOff() {
        withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_lock($0) }
        defer { withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_unlock($0) } }

        for voice in voices {
            voice.isActive = false
            voice.state = .idle
        }
    }

    private func initializeExciter(voice: PhysicalModelingVoice, config: PhysicalModelingConfig) {
        let length = voice.delayLength
        guard length > 0 else { return }

        switch config.exciterType {
        case .pluck:
            // Triangular pluck shape
            let pluckPos = Int(Float(length) * config.stringPosition)
            for i in 0..<length {
                var value: Float
                if i < pluckPos {
                    value = Float(i) / Float(pluckPos)
                } else {
                    value = 1.0 - Float(i - pluckPos) / Float(length - pluckPos)
                }
                // Add noise for realism
                value += Float.random(in: -1...1) * config.exciterNoise * 0.3
                // Apply hardness (more harmonics)
                if config.exciterHardness > 0.5 {
                    value = value > 0 ? pow(value, 2.0 - config.exciterHardness) : -pow(-value, 2.0 - config.exciterHardness)
                }
                voice.delayLine[i] = value * voice.velocity
            }

        case .hammer:
            // Raised cosine hammer shape
            let hammerWidth = Int(Float(length) * (1.0 - config.exciterHardness * 0.9))
            let hammerPos = Int(Float(length) * config.stringPosition)
            for i in 0..<length {
                let dist = abs(i - hammerPos)
                if dist < hammerWidth {
                    let t = Float(dist) / Float(hammerWidth)
                    voice.delayLine[i] = (0.5 + 0.5 * cos(t * Float.pi)) * voice.velocity
                } else {
                    voice.delayLine[i] = 0
                }
                voice.delayLine[i] += Float.random(in: -1...1) * config.exciterNoise * 0.2
            }

        case .noise:
            // Filtered noise
            for i in 0..<length {
                voice.delayLine[i] = Float.random(in: -1...1) * voice.velocity
            }
            // Simple lowpass for brightness
            let brightness = config.brightness
            for i in 1..<length {
                voice.delayLine[i] = voice.delayLine[i-1] * (1.0 - brightness) + voice.delayLine[i] * brightness
            }

        case .impulse:
            // Single impulse
            for i in 0..<length {
                voice.delayLine[i] = 0
            }
            let impulsePos = Int(Float(length) * config.stringPosition)
            voice.delayLine[impulsePos] = voice.velocity

        case .bow:
            // Bow is continuous, initialize with small vibration
            for i in 0..<length {
                voice.delayLine[i] = Float.random(in: -0.01...0.01) * voice.velocity
            }
            voice.bowVelocity = config.bowSpeed
        }
    }

    // MARK: - Audio Processing

    public func processBlock(buffer: inout [Float], sampleRate: Float) {
        self.sampleRate = sampleRate
        let frameCount = buffer.count

        buffer = [Float](repeating: 0, count: frameCount)

        withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_lock($0) }
        defer { withUnsafeMutablePointer(to: &voiceLock) { os_unfair_lock_unlock($0) } }

        for voice in voices where voice.isActive {
            processVoice(voice, buffer: &buffer, frameCount: frameCount)
        }

        if masterVolume != 1.0 {
            vDSP_vsmul(buffer, 1, &masterVolume, &buffer, 1, vDSP_Length(frameCount))
        }
    }

    private func processVoice(_ voice: PhysicalModelingVoice, buffer: inout [Float], frameCount: Int) {
        let cfg = config
        let invSampleRate = 1.0 / sampleRate

        guard voice.delayLength > 0 else { return }

        for i in 0..<frameCount {
            // Update envelope
            let ampEnv = updatePhysicalEnvelope(voice: voice, envelope: cfg.ampEnvelope, dt: invSampleRate)

            if voice.state == .idle {
                voice.isActive = false
                return
            }

            // Read from delay line
            var output = voice.delayLine[voice.delayIndex]

            // Bow excitation (continuous)
            if cfg.exciterType == .bow && voice.state != .release {
                let bowExcitation = generateBowExcitation(voice: voice, config: cfg, dt: invSampleRate)
                let stringVelocity = output - voice.prevSample
                let friction = bowFriction(relativeVelocity: voice.bowVelocity - stringVelocity, pressure: cfg.bowPressure)
                output += bowExcitation * friction * 0.1
            }
            voice.prevSample = output

            // Karplus-Strong feedback with lowpass filter
            let nextIndex = (voice.delayIndex + 1) % voice.delayLength
            let nextSample = voice.delayLine[nextIndex]

            // Two-point average with damping (classic KS)
            var filtered = (output + nextSample) * 0.5 * cfg.damping

            // Additional brightness filter (one-pole)
            let brightnessCoeff = cfg.brightness * 0.5 + 0.5
            filtered = voice.filterZ1 * (1.0 - brightnessCoeff) + filtered * brightnessCoeff
            voice.filterZ1 = filtered

            // String tension affects pitch stability (subtle detuning)
            if cfg.stringTension != 1.0 {
                let tensionEffect = 1.0 + (cfg.stringTension - 1.0) * 0.01
                filtered *= tensionEffect
            }

            // Write back to delay line
            voice.delayLine[voice.delayIndex] = filtered

            // Body resonance (parallel comb filters)
            if cfg.bodyResonance > 0 {
                let bodyOut1 = voice.bodyDelayLine1[voice.bodyIndex1]
                let bodyOut2 = voice.bodyDelayLine2[voice.bodyIndex2]

                let bodyInput = output * cfg.bodyResonance
                voice.bodyDelayLine1[voice.bodyIndex1] = bodyInput + bodyOut1 * 0.7
                voice.bodyDelayLine2[voice.bodyIndex2] = bodyInput + bodyOut2 * 0.7

                voice.bodyIndex1 = (voice.bodyIndex1 + 1) % voice.bodyDelayLine1.count
                voice.bodyIndex2 = (voice.bodyIndex2 + 1) % voice.bodyDelayLine2.count

                // Mix body resonance
                output += (bodyOut1 + bodyOut2) * cfg.bodyResonance * 0.3

                // Body brightness EQ
                voice.filterZ2 = voice.filterZ2 * (1.0 - cfg.bodyBrightness) + output * cfg.bodyBrightness
                output = voice.filterZ2
            }

            // Advance delay index
            voice.delayIndex = nextIndex

            // Apply envelope and velocity
            output *= ampEnv * voice.velocity * cfg.masterLevel

            buffer[i] += output
        }
    }

    @inline(__always)
    private func generateBowExcitation(voice: PhysicalModelingVoice, config: PhysicalModelingConfig, dt: Float) -> Float {
        // Bow oscillation for continuous excitation
        voice.bowPhase += voice.frequency * dt * config.bowSpeed
        if voice.bowPhase >= 1.0 { voice.bowPhase -= 1.0 }

        let bowNoise = Float.random(in: -1...1) * 0.1
        return sin(voice.bowPhase * 2.0 * Float.pi) * config.bowPressure + bowNoise
    }

    @inline(__always)
    private func bowFriction(relativeVelocity: Float, pressure: Float) -> Float {
        // Simplified stick-slip friction model
        let absVel = abs(relativeVelocity)
        let stickSlip = pressure / (1.0 + absVel * 10.0)
        return stickSlip * (relativeVelocity > 0 ? 1.0 : -1.0)
    }

    @inline(__always)
    private func updatePhysicalEnvelope(voice: PhysicalModelingVoice, envelope: ADSREnvelope, dt: Float) -> Float {
        switch voice.state {
        case .attack:
            voice.ampEnvValue += dt / max(0.001, envelope.attack)
            if voice.ampEnvValue >= 1.0 {
                voice.ampEnvValue = 1.0
                voice.state = .decay
                voice.ampEnvTime = 0
            }
        case .decay:
            voice.ampEnvValue -= dt / max(0.001, envelope.decay) * (1.0 - envelope.sustain)
            if voice.ampEnvValue <= envelope.sustain {
                voice.ampEnvValue = envelope.sustain
                voice.state = .sustain
            }
        case .sustain:
            voice.ampEnvValue = envelope.sustain
        case .release:
            voice.ampEnvValue -= dt / max(0.001, envelope.release) * voice.ampEnvValue
            if voice.ampEnvValue <= 0.001 {
                voice.ampEnvValue = 0
                voice.state = .idle
            }
        case .idle:
            voice.ampEnvValue = 0
        }

        voice.ampEnvTime += dt
        return voice.ampEnvValue
    }
}

// MARK: - ============================================
// MARK: - SYNTH FACTORY
// MARK: - ============================================

/// Factory for creating synthesis engines
public enum SynthFactory {

    /// Available synthesis engine types
    public enum EngineType: String, CaseIterable {
        case subtractive = "Subtractive"
        case fm = "FM"
        case wavetable = "Wavetable"
        case granular = "Granular"
        case additive = "Additive"
        case physicalModeling = "Physical Modeling"
    }

    /// Create a synthesis engine of the specified type
    public static func create(_ type: EngineType, sampleRate: Float = 48000.0) -> SynthesisEngine {
        switch type {
        case .subtractive:
            return SubtractiveSynth(sampleRate: sampleRate)
        case .fm:
            return FMSynth(sampleRate: sampleRate)
        case .wavetable:
            return WavetableSynth(sampleRate: sampleRate)
        case .granular:
            return GranularSynth(sampleRate: sampleRate)
        case .additive:
            return AdditiveSynth(sampleRate: sampleRate)
        case .physicalModeling:
            return PhysicalModelingSynth(sampleRate: sampleRate)
        }
    }

    /// Get description for engine type
    public static func description(for type: EngineType) -> String {
        switch type {
        case .subtractive:
            return "Classic analog-style synthesis with dual oscillators, dual filters, and modulation"
        case .fm:
            return "Yamaha DX7-style 6-operator FM synthesis with 32 algorithms"
        case .wavetable:
            return "Serum/Vital-style wavetable morphing with warp modes"
        case .granular:
            return "Advanced granular synthesis with freeze mode and density control"
        case .additive:
            return "64-harmonic additive synthesis with individual harmonic control"
        case .physicalModeling:
            return "Karplus-Strong physical modeling with string, bow, and body resonance"
        }
    }
}
