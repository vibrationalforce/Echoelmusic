#if canImport(AVFoundation)
//
//  EchoelSynth.swift
//  Echoelmusic
//
//  Created: March 2026
//  ECHOELSYNTH — 5-ENGINE POLYPHONIC MELODIC SYNTHESIZER
//
//  ═══════════════════════════════════════════════════════════════════════════════
//  5 Melodic Engines:
//
//  1. Analog   — Detuned poly saw/square unison (Juno-106 / Prophet-5 style)
//  2. FM       — 2-operator FM synthesis (DX7 electric pianos, bells, mallets)
//  3. Wavetable— Morphing wavetable with 8 shapes (Serum-style)
//  4. Pluck    — Karplus-Strong physical modeling (guitar, harp, marimba)
//  5. Pad      — Supersaw + slow modulation (lush atmospheric pads)
//
//  Signal Chain:
//  Engine → SVF Filter (LP/HP/BP) → Chorus → Drive → Stereo Width → Out
//
//  Bio-Reactive:
//  • Coherence → wavetable morph + filter cutoff
//  • Heart rate → vibrato depth
//  • HRV → filter modulation depth
//  • Breath phase → amplitude swell
//  ═══════════════════════════════════════════════════════════════════════════════

import Foundation
import AVFoundation
import Accelerate

#if canImport(SwiftUI)
import SwiftUI
import Observation
#endif

// MARK: - Synth Engine Type

/// The 5 melodic synthesis engines available in EchoelSynth
public enum SynthEngineType: String, CaseIterable, Codable, Sendable {
    case analog    = "Analog"       // Poly saw/square unison
    case fm        = "FM"           // 2-op FM synthesis
    case wavetable = "Wavetable"    // Morphing wavetable
    case pluck     = "Pluck"        // Karplus-Strong
    case pad       = "Pad"          // Supersaw pad
}

// MARK: - Filter Mode

public enum SynthFilterMode: String, CaseIterable, Codable, Sendable {
    case lowpass  = "LP"
    case highpass = "HP"
    case bandpass = "BP"
}

// MARK: - EchoelSynth Configuration

public struct EchoelSynthConfig: Codable, Equatable, Sendable {

    // MARK: - Engine Selection
    public var engine: SynthEngineType = .analog

    // MARK: - Oscillator
    public var tuning: Float = 0.0          // cents (-100 to +100)
    public var octave: Int = 0              // -2 to +2

    // MARK: - Analog Engine
    public var analogDetune: Float = 12.0   // cents for unison spread
    public var analogVoices: Int = 3        // unison voices (1-5)
    public var analogWaveform: Float = 0.0  // 0=saw, 1=square
    public var analogPWM: Float = 0.5       // pulse width (0.1-0.9)

    // MARK: - FM Engine
    public var fmRatio: Float = 2.0         // modulator:carrier ratio
    public var fmDepth: Float = 0.5         // modulation index
    public var fmFeedback: Float = 0.0      // operator feedback
    public var fmModDecay: Float = 0.3      // mod envelope decay (sec)

    // MARK: - Wavetable Engine
    public var wtPosition: Float = 0.0      // wavetable position (0-1, morphs 8 shapes)
    public var wtModSpeed: Float = 0.0      // LFO speed for position modulation

    // MARK: - Pluck Engine (Karplus-Strong)
    public var pluckDamping: Float = 0.5    // string damping (0=bright, 1=dark)
    public var pluckDecay: Float = 0.995    // feedback coefficient
    public var pluckBrightness: Float = 0.7 // excitation brightness
    public var pluckStretch: Float = 0.0    // allpass stretch factor

    // MARK: - Pad Engine
    public var padSpread: Float = 20.0      // detune spread in cents
    public var padVoiceCount: Int = 7       // supersaw voices
    public var padChorusRate: Float = 0.3   // chorus modulation rate Hz
    public var padChorusDepth: Float = 0.5  // chorus depth

    // MARK: - Filter
    public var filterMode: SynthFilterMode = .lowpass
    public var filterCutoff: Float = 8000.0
    public var filterResonance: Float = 0.2
    public var filterEnvAmount: Float = 2000.0
    public var filterEnvDecay: Float = 0.4
    public var filterKeyTrack: Float = 0.5

    // MARK: - Amplitude Envelope
    public var attack: Float = 0.01
    public var decay: Float = 0.3
    public var sustain: Float = 0.7
    public var release: Float = 0.4

    // MARK: - Effects
    public var drive: Float = 0.0
    public var chorusAmount: Float = 0.0
    public var level: Float = 0.8
    public var stereoWidth: Float = 0.3
    public var vibratoRate: Float = 5.0
    public var vibratoDepth: Float = 0.0

    // MARK: - Presets

    public static let classicLead = EchoelSynthConfig(
        engine: .analog, analogDetune: 15.0, analogVoices: 3, analogWaveform: 0.0,
        filterCutoff: 3000.0, filterResonance: 0.3, filterEnvAmount: 4000.0, filterEnvDecay: 0.2,
        attack: 0.005, decay: 0.3, sustain: 0.6, release: 0.3, drive: 0.15, level: 0.8
    )

    public static let electricPiano = EchoelSynthConfig(
        engine: .fm, fmRatio: 1.0, fmDepth: 0.8, fmFeedback: 0.0, fmModDecay: 0.5,
        filterCutoff: 6000.0, filterResonance: 0.1, filterEnvAmount: 1000.0,
        attack: 0.003, decay: 1.5, sustain: 0.0, release: 0.5, level: 0.75
    )

    public static let bellKeys = EchoelSynthConfig(
        engine: .fm, fmRatio: 3.5, fmDepth: 1.2, fmFeedback: 0.1, fmModDecay: 2.0,
        filterCutoff: 12000.0, filterResonance: 0.05,
        attack: 0.001, decay: 3.0, sustain: 0.0, release: 1.0, level: 0.7
    )

    public static let pluckedGuitar = EchoelSynthConfig(
        engine: .pluck, pluckDamping: 0.4, pluckDecay: 0.997, pluckBrightness: 0.8,
        filterCutoff: 10000.0, filterResonance: 0.1,
        attack: 0.001, decay: 0.5, sustain: 0.0, release: 0.3, level: 0.8
    )

    public static let warmPad = EchoelSynthConfig(
        engine: .pad, padSpread: 25.0, padVoiceCount: 7, padChorusRate: 0.3, padChorusDepth: 0.6,
        filterCutoff: 2000.0, filterResonance: 0.15, filterEnvAmount: 1500.0, filterEnvDecay: 1.0,
        attack: 0.8, decay: 1.0, sustain: 0.8, release: 2.0, chorusAmount: 0.5, level: 0.7, stereoWidth: 0.8
    )

    public static let synthBrass = EchoelSynthConfig(
        engine: .analog, analogDetune: 8.0, analogVoices: 5, analogWaveform: 0.3,
        filterCutoff: 1200.0, filterResonance: 0.3, filterEnvAmount: 6000.0, filterEnvDecay: 0.15,
        attack: 0.03, decay: 0.2, sustain: 0.7, release: 0.2, drive: 0.1, level: 0.8
    )

    public static let crystalPluck = EchoelSynthConfig(
        engine: .pluck, pluckDamping: 0.2, pluckDecay: 0.998, pluckBrightness: 1.0, pluckStretch: 0.1,
        filterCutoff: 15000.0, filterResonance: 0.05,
        attack: 0.001, decay: 2.0, sustain: 0.0, release: 0.8, chorusAmount: 0.3, level: 0.75, stereoWidth: 0.5
    )

    public static let retroWavetable = EchoelSynthConfig(
        engine: .wavetable, wtPosition: 0.3, wtModSpeed: 0.5,
        filterCutoff: 4000.0, filterResonance: 0.4, filterEnvAmount: 3000.0, filterEnvDecay: 0.3,
        attack: 0.01, decay: 0.5, sustain: 0.5, release: 0.4, drive: 0.1, level: 0.8
    )

    public static let bioReactive = EchoelSynthConfig(
        engine: .wavetable, wtPosition: 0.5, wtModSpeed: 0.2,
        filterCutoff: 3000.0, filterResonance: 0.3, filterEnvAmount: 3000.0, filterEnvDecay: 0.5,
        attack: 0.1, decay: 0.8, sustain: 0.6, release: 0.8, chorusAmount: 0.3, level: 0.75, stereoWidth: 0.4,
        vibratoRate: 5.0, vibratoDepth: 0.1
    )
}

// MARK: - Voice State

private struct EchoelSynthVoice {
    let id: UUID
    var midiNote: Int
    var velocity: Float
    var startTime: Double

    // Oscillator phases
    var phase: Double = 0.0
    var unisonPhases: [Double] = [0, 0, 0, 0, 0, 0, 0]
    var unisonDrifts: [Double] = [0, 0, 0, 0, 0, 0, 0]
    var fmModPhase: Double = 0.0
    var lfoPhase: Double = 0.0
    var wtLfoPhase: Double = 0.0

    // Karplus-Strong delay line
    var pluckBuffer: [Float] = []
    var pluckIndex: Int = 0
    var pluckAllpass: Float = 0.0

    // Envelope state
    var ampEnvelope: Float = 0.0
    var filterEnvelope: Float = 1.0
    var fmModEnvelope: Float = 1.0
    var isActive: Bool = true
    var isReleasing: Bool = false
    var releaseStartTime: Double = 0.0
    var releaseStartEnvelope: Float = 1.0
    var envStage: EnvStage = .attack

    // Filter state (SVF)
    var svfIC1eq: Float = 0.0
    var svfIC2eq: Float = 0.0

    // FM parameter smoothing (prevents zipper noise)
    var smoothedFMAmount: Float = 0.0

    // Chorus state
    var chorusPhase: Double = 0.0

    enum EnvStage { case attack, decay, sustain, release }
}

// MARK: - EchoelSynth

/// EchoelSynth — 5-Engine Polyphonic Melodic Synthesizer
/// Covers Lead, Keys, Pad, Pluck — all with real-time AVAudioSourceNode rendering.
@preconcurrency @MainActor
@Observable
public final class EchoelSynth {

    // MARK: - Singleton

    @MainActor public static let shared = EchoelSynth()

    // MARK: - Published State

    public var config = EchoelSynthConfig.classicLead
    public var isPlaying: Bool = false
    public var activeVoiceCount: Int = 0
    public var currentNote: Int? = nil
    public var meterLevel: Float = 0.0

    // MARK: - Audio Engine

    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private let sampleRate: Double = 48000.0
    private let maxVoices = 16

    // MARK: - Voice Management

    private var voices: [EchoelSynthVoice] = []
    private let voiceLock = AudioUnfairLock()

    // MARK: - DSP State

    private var currentTime: Double = 0.0
    private var lastMeterUpdate: Double = 0.0
    private var peakLevel: Float = 0.0

    // MARK: - Bio-Reactive

    private var bioCoherence: Float = 0.5
    private var bioHeartRate: Float = 72.0
    private var bioHRV: Float = 50.0
    private var bioBreathPhase: Float = 0.0

    // MARK: - Initialization

    private init() {
        setupAudioEngine()
    }

    // MARK: - Audio Engine Setup

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine else { return }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)
        guard let audioFormat = format else { return }

        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let leftBuffer = ablPointer[0].mData?.assumingMemoryBound(to: Float.self),
                  let rightBuffer = ablPointer[1].mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            self.renderAudio(leftBuffer: leftBuffer, rightBuffer: rightBuffer, frameCount: Int(frameCount))
            return noErr
        }

        guard let source = sourceNode else { return }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: audioFormat)

        do { try engine.start() } catch { log.error("EchoelSynth: engine start failed - \(error)", category: .audio) }
    }

    // MARK: - Public API

    public func start() {
        guard let engine = audioEngine, !engine.isRunning else { return }
        do { try engine.start(); isPlaying = true } catch { isPlaying = false; log.error("EchoelSynth: start failed - \(error)", category: .audio) }
    }

    public func stop() {
        isPlaying = false
        voiceLock.lock()
        voices.removeAll()
        voiceLock.unlock()
        activeVoiceCount = 0
        currentNote = nil
    }

    public func noteOn(note: Int, velocity: Float = 0.8) {
        if audioEngine?.isRunning != true {
            do { try audioEngine?.start() } catch { log.error("EchoelSynth: noteOn engine start failed - \(error)", category: .audio) }
        }

        voiceLock.lock()
        defer { voiceLock.unlock() }

        // Retrigger existing voice on same note
        if let idx = voices.firstIndex(where: { $0.midiNote == note && $0.isActive }) {
            voices[idx].startTime = currentTime
            voices[idx].ampEnvelope = 0.0
            voices[idx].filterEnvelope = 1.0
            voices[idx].fmModEnvelope = 1.0
            voices[idx].isReleasing = false
            voices[idx].envStage = .attack
            voices[idx].velocity = velocity
            voices[idx].phase = 0.0
            voices[idx].fmModPhase = 0.0
        } else {
            // Voice stealing — oldest first
            if voices.count >= maxVoices {
                if let oldIdx = voices.indices.min(by: { voices[$0].startTime < voices[$1].startTime }) {
                    voices.remove(at: oldIdx)
                }
            }

            var voice = EchoelSynthVoice(id: UUID(), midiNote: note, velocity: velocity, startTime: currentTime)

            // Initialize unison drift
            for i in 0..<7 {
                voice.unisonDrifts[i] = Double.random(in: 0..<1.0)
            }

            // Initialize Karplus-Strong buffer for pluck engine
            let freq = 440.0 * pow(2.0, (Double(note) - 69.0) / 12.0)
            let bufferSize = max(2, Int(sampleRate / freq))
            voice.pluckBuffer = (0..<bufferSize).map { _ in
                // Noise burst excitation shaped by brightness
                Float.random(in: -1.0...1.0)
            }
            voice.pluckIndex = 0

            voices.append(voice)
        }

        isPlaying = true
        currentNote = note
        activeVoiceCount = voices.count
    }

    public func noteOff(note: Int) {
        voiceLock.lock()
        defer { voiceLock.unlock() }

        for i in voices.indices where voices[i].midiNote == note && !voices[i].isReleasing {
            voices[i].isReleasing = true
            voices[i].releaseStartTime = currentTime
            voices[i].releaseStartEnvelope = voices[i].ampEnvelope
            voices[i].envStage = .release
        }
        if currentNote == note { currentNote = nil }
    }

    public func allNotesOff() {
        voiceLock.lock()
        voices.removeAll()
        voiceLock.unlock()
        activeVoiceCount = 0
        currentNote = nil
    }

    public func setPreset(_ preset: EchoelSynthConfig) {
        config = preset
    }

    public func updateBio(coherence: Float, heartRate: Float, hrv: Float, breathPhase: Float) {
        bioCoherence = coherence
        bioHeartRate = heartRate
        bioHRV = hrv
        bioBreathPhase = breathPhase
    }

    // MARK: - Audio Rendering (Real-Time Thread)

    private func renderAudio(leftBuffer: UnsafeMutablePointer<Float>, rightBuffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        let cfg = config

        memset(leftBuffer, 0, frameCount * MemoryLayout<Float>.size)
        memset(rightBuffer, 0, frameCount * MemoryLayout<Float>.size)

        // tryLock: never block the audio thread — output silence if lock is held
        guard voiceLock.try() else { return }

        var voicesToRemove: [Int] = []
        var peak: Float = 0.0
        let sr = Float(sampleRate)

        for voiceIndex in voices.indices {
            var v = voices[voiceIndex]

            for frame in 0..<frameCount {
                let time = currentTime + Double(frame) / sampleRate
                let elapsed = Float(time - v.startTime)
                guard elapsed >= 0 else { continue }

                // ─── Amplitude Envelope (ADSR) ───
                var env: Float
                switch v.envStage {
                case .attack:
                    let attackProgress = elapsed / max(cfg.attack, 0.001)
                    if attackProgress >= 1.0 {
                        env = 1.0
                        v.envStage = .decay
                    } else {
                        env = attackProgress
                    }
                case .decay:
                    let decayElapsed = elapsed - cfg.attack
                    let decayProgress = decayElapsed / max(cfg.decay, 0.001)
                    env = 1.0 - (1.0 - cfg.sustain) * min(1.0, decayProgress)
                    if decayProgress >= 1.0 { v.envStage = .sustain }
                case .sustain:
                    env = cfg.sustain
                case .release:
                    let releaseElapsed = Float(time - v.releaseStartTime)
                    let releaseProgress = min(1.0, releaseElapsed / max(cfg.release, 0.001))
                    env = v.releaseStartEnvelope * (1.0 - releaseProgress)
                }

                if env < 0.0001 && v.envStage == .release {
                    v.isActive = false
                    if !voicesToRemove.contains(voiceIndex) { voicesToRemove.append(voiceIndex) }
                    continue
                }
                v.ampEnvelope = env

                // ─── Filter Envelope ───
                let filterEnvProgress = min(1.0, elapsed / max(cfg.filterEnvDecay, 0.001))
                v.filterEnvelope = 1.0 - filterEnvProgress

                // ─── FM Mod Envelope ───
                let fmEnvProgress = min(1.0, elapsed / max(cfg.fmModDecay, 0.001))
                v.fmModEnvelope = 1.0 - fmEnvProgress

                // ─── Pitch Calculation ───
                let baseNote = Float(v.midiNote + cfg.octave * 12)
                let tunedNote = baseNote + cfg.tuning / 100.0
                var baseFreq = 440.0 * pow(2.0, (tunedNote - 69.0) / 12.0)

                // Vibrato LFO
                if cfg.vibratoDepth > 0 {
                    let vibratoInc = Double(cfg.vibratoRate) / sampleRate
                    v.lfoPhase += vibratoInc
                    if v.lfoPhase >= 1.0 { v.lfoPhase -= 1.0 }
                    let vib = sin(Float(v.lfoPhase) * 2.0 * Float.pi) * cfg.vibratoDepth
                    baseFreq *= pow(2.0, vib / 12.0)
                }

                let phaseInc = Double(baseFreq) / sampleRate

                // ─── Render Engine ───
                var sample = renderEngine(cfg: cfg, voice: &v, freq: baseFreq, phaseInc: phaseInc, elapsed: elapsed, sr: sr)

                // ─── SVF Filter ───
                let keyTrackHz = cfg.filterKeyTrack * (baseFreq - 261.63)
                let envHz = cfg.filterEnvAmount * v.filterEnvelope
                let cutoff = min(20000.0, max(20.0, cfg.filterCutoff + envHz + keyTrackHz))
                sample = svfFilter(input: sample, cutoff: cutoff, resonance: cfg.filterResonance, sr: sr, mode: cfg.filterMode, ic1eq: &v.svfIC1eq, ic2eq: &v.svfIC2eq)

                // ─── Chorus ───
                if cfg.chorusAmount > 0 {
                    v.chorusPhase += Double(cfg.padChorusRate) / sampleRate
                    if v.chorusPhase >= 1.0 { v.chorusPhase -= 1.0 }
                    let chorusMod = sin(Float(v.chorusPhase) * 2.0 * Float.pi) * cfg.chorusAmount * 0.003
                    let detuned = sample * (1.0 + chorusMod)
                    sample = sample * 0.7 + detuned * 0.3
                }

                // ─── Drive ───
                if cfg.drive > 0 {
                    sample = tanhSaturation(sample, drive: cfg.drive)
                }

                // ─── Apply Envelope + Velocity ───
                sample *= env * v.velocity * cfg.level

                // ─── Bio-reactive amplitude swell ───
                let breathSwell = 1.0 + (bioBreathPhase - 0.5) * 0.1
                sample *= breathSwell

                peak = Swift.max(peak, abs(sample))

                // ─── Stereo output with equal-power panning ───
                // cos/sin panning preserves perceived loudness across the stereo field.
                // Linear panning causes a -3dB dip at center — this eliminates that.
                let spread = cfg.stereoWidth * 0.5
                let panNorm = Float(v.midiNote - 60) / 60.0 * spread  // [-1, 1] range
                let theta = (panNorm + 1.0) * 0.5 * Float.pi * 0.5   // [0, π/2]
                leftBuffer[frame] += sample * cos(theta)
                rightBuffer[frame] += sample * sin(theta)
            }

            voices[voiceIndex] = v
        }

        // Remove finished voices
        for index in voicesToRemove.sorted().reversed() {
            if index < voices.count { voices.remove(at: index) }
        }

        voiceLock.unlock()

        // Soft-limiter: prevent digital clipping from polyphonic voice sum
        // 16 voices at level 0.8 can produce amplitude up to 12.8
        let voiceCount = Float(max(1, voices.count))
        let gainComp = 1.0 / sqrt(voiceCount)
        for i in 0..<frameCount {
            let sL = leftBuffer[i] * gainComp
            let sR = rightBuffer[i] * gainComp
            let xL2 = sL * sL
            let xR2 = sR * sR
            leftBuffer[i] = sL * (27.0 + xL2) / (27.0 + 9.0 * xL2)
            rightBuffer[i] = sR * (27.0 + xR2) / (27.0 + 9.0 * xR2)
        }

        currentTime += Double(frameCount) / sampleRate

        // Meter update (~20Hz)
        if currentTime - lastMeterUpdate > 0.05 {
            lastMeterUpdate = currentTime
            peakLevel = peak
            Task { @MainActor in
                self.meterLevel = peak
                self.activeVoiceCount = self.voices.count
                if self.voices.isEmpty { self.isPlaying = false }
            }
        }
    }

    // MARK: - Engine Renderers

    private func renderEngine(cfg: EchoelSynthConfig, voice v: inout EchoelSynthVoice, freq: Float, phaseInc: Double, elapsed: Float, sr: Float) -> Float {
        switch cfg.engine {

        case .analog:
            // ─── Analog: Detuned poly saw/square unison ───
            let voiceCount = min(cfg.analogVoices, 7)
            let detuneRange = cfg.analogDetune / 1200.0
            var mix: Float = 0.0

            for i in 0..<voiceCount {
                let detuneOffset: Float
                if voiceCount == 1 {
                    detuneOffset = 0
                } else {
                    detuneOffset = -detuneRange + detuneRange * 2.0 * Float(i) / Float(voiceCount - 1)
                }
                let voiceFreq = freq * (1.0 + detuneOffset)
                let voiceInc = Double(voiceFreq) / Double(sr)

                // Slow drift for organic movement
                let driftInc = Double(0.1) / Double(sr)
                v.unisonDrifts[i] += driftInc

                var ph = v.unisonPhases[i]
                ph += voiceInc
                if ph >= 1.0 { ph -= 1.0 }
                v.unisonPhases[i] = ph

                // Saw with PolyBLEP
                let saw = Float(2.0 * ph - 1.0) - polyBLEP(t: Float(ph), dt: Float(voiceInc))

                // Square with PolyBLEP (pulse width modulation)
                let pw = cfg.analogPWM
                let sqr: Float = Float(ph) < pw ? 1.0 : -1.0

                // Mix saw/square
                let wfMix = cfg.analogWaveform
                mix += saw * (1.0 - wfMix) + sqr * wfMix
            }

            return mix / Float(max(1, voiceCount))

        case .fm:
            // ─── FM: 2-operator (carrier + modulator) ───
            let modInc = phaseInc * Double(cfg.fmRatio)

            // Modulator with envelope
            v.fmModPhase += modInc
            if v.fmModPhase >= 1.0 { v.fmModPhase -= 1.0 }

            // Self-feedback on modulator
            let modOutput = sin(Float(v.fmModPhase) * 2.0 * Float.pi)
            let feedback = modOutput * cfg.fmFeedback * 0.5

            let modWithFeedback = sin((Float(v.fmModPhase) + feedback) * 2.0 * Float.pi)

            // FM amount with mod envelope decay + parameter smoothing
            // Exponential smoothing prevents zipper noise when fmDepth changes
            let targetFMAmount = cfg.fmDepth * 4.0 * v.fmModEnvelope
            v.smoothedFMAmount += (targetFMAmount - v.smoothedFMAmount) * 0.005
            let carrierPhaseOffset = Double(modWithFeedback * v.smoothedFMAmount)

            v.phase += phaseInc
            if v.phase >= 1.0 { v.phase -= 1.0 }

            return sin(Float(v.phase + carrierPhaseOffset) * 2.0 * Float.pi)

        case .wavetable:
            // ─── Wavetable: 8-shape morph ───
            v.phase += phaseInc
            if v.phase >= 1.0 { v.phase -= 1.0 }

            // Wavetable position modulation
            var wtPos = cfg.wtPosition
            if cfg.wtModSpeed > 0 {
                v.wtLfoPhase += Double(cfg.wtModSpeed) / sampleRate
                if v.wtLfoPhase >= 1.0 { v.wtLfoPhase -= 1.0 }
                wtPos += sin(Float(v.wtLfoPhase) * 2.0 * Float.pi) * 0.2
                wtPos = min(1.0, max(0.0, wtPos))
            }

            // Bio-reactive wavetable morph
            wtPos = min(1.0, max(0.0, wtPos + (bioCoherence - 0.5) * 0.3))

            let ph = Float(v.phase) * 2.0 * Float.pi

            // 8 waveform shapes, morphed by position
            let shapeIndex = wtPos * 7.0
            let shape0 = Int(shapeIndex)
            let shape1 = min(7, shape0 + 1)
            let shapeFrac = shapeIndex - Float(shape0)

            let s0 = wavetableShape(shape: shape0, phase: ph, freq: freq)
            let s1 = wavetableShape(shape: shape1, phase: ph, freq: freq)

            return s0 * (1.0 - shapeFrac) + s1 * shapeFrac

        case .pluck:
            // ─── Pluck: Karplus-Strong physical modeling ───
            guard !v.pluckBuffer.isEmpty else { return 0.0 }

            let bufSize = v.pluckBuffer.count
            let idx = v.pluckIndex % bufSize
            let output = v.pluckBuffer[idx]

            // Averaging low-pass filter (string damping)
            let nextIdx = (idx + 1) % bufSize
            let damping = cfg.pluckDamping
            let averaged = v.pluckBuffer[idx] * (1.0 - damping * 0.5) + v.pluckBuffer[nextIdx] * (damping * 0.5)

            // Allpass stretch for inharmonicity
            let stretched: Float
            if cfg.pluckStretch > 0 {
                let ap = cfg.pluckStretch
                stretched = averaged * (1.0 - ap) + v.pluckAllpass * ap
                v.pluckAllpass = averaged
            } else {
                stretched = averaged
            }

            // Feedback with decay
            v.pluckBuffer[idx] = stretched * cfg.pluckDecay

            v.pluckIndex += 1

            return output

        case .pad:
            // ─── Pad: Supersaw with slow modulation ───
            let voiceCount = min(cfg.padVoiceCount, 7)
            let detuneRange = cfg.padSpread / 1200.0
            var mix: Float = 0.0

            for i in 0..<voiceCount {
                let detuneOffset: Float
                if voiceCount == 1 {
                    detuneOffset = 0
                } else {
                    detuneOffset = -detuneRange + detuneRange * 2.0 * Float(i) / Float(voiceCount - 1)
                }

                // Slow chorus modulation per voice
                let chorusMod = sin(Float(v.unisonDrifts[i]) * 2.0 * Float.pi) * 0.002
                let voiceFreq = freq * (1.0 + detuneOffset + chorusMod)
                let voiceInc = Double(voiceFreq) / Double(sr)

                // Slow drift
                v.unisonDrifts[i] += Double(cfg.padChorusRate * 0.3) / Double(sr) + Double.random(in: -0.00001...0.00001)

                var ph = v.unisonPhases[i]
                ph += voiceInc
                if ph >= 1.0 { ph -= 1.0 }
                v.unisonPhases[i] = ph

                // Saw with PolyBLEP
                let saw = Float(2.0 * ph - 1.0) - polyBLEP(t: Float(ph), dt: Float(voiceInc))
                mix += saw
            }

            return mix / Float(max(1, voiceCount))
        }
    }

    // MARK: - Wavetable Shapes

    /// Band-limited wavetable shapes using additive synthesis
    /// Prevents aliasing by only generating harmonics below Nyquist.
    /// For shapes that are already band-limited (sine, half-rect), uses direct computation.
    private func wavetableShape(shape: Int, phase: Float, freq: Float = 440.0) -> Float {
        let nyquist = Float(sampleRate) * 0.5
        let maxHarmonics = max(1, Int(nyquist / max(1.0, freq)))

        switch shape {
        case 0: // Sine — already band-limited
            return sin(phase)

        case 1: // Triangle — band-limited additive (odd harmonics, alternating sign, 1/n²)
            var sample: Float = 0
            for n in stride(from: 1, through: min(maxHarmonics, 64), by: 2) {
                let sign: Float = ((n / 2) % 2 == 0) ? 1.0 : -1.0
                let nf = Float(n)
                sample += sign * sin(phase * nf) / (nf * nf)
            }
            return sample * (8.0 / (Float.pi * Float.pi))

        case 2: // Saw — band-limited additive (all harmonics, 1/n)
            var sample: Float = 0
            for n in 1...min(maxHarmonics, 64) {
                let nf = Float(n)
                let sign: Float = (n % 2 == 0) ? 1.0 : -1.0
                sample += sign * sin(phase * nf) / nf
            }
            return sample * (2.0 / Float.pi)

        case 3: // Square — band-limited additive (odd harmonics, 1/n)
            var sample: Float = 0
            for n in stride(from: 1, through: min(maxHarmonics, 64), by: 2) {
                let nf = Float(n)
                sample += sin(phase * nf) / nf
            }
            return sample * (4.0 / Float.pi)

        case 4: // Pulse (25%) — band-limited via Fourier series
            var sample: Float = 0
            let duty: Float = 0.25
            for n in 1...min(maxHarmonics, 64) {
                let nf = Float(n)
                sample += sin(Float.pi * nf * duty) * sin(phase * nf) / nf
            }
            return sample * (4.0 / Float.pi)

        case 5: // Half-rectified sine — naturally limited harmonics
            return phase < Float.pi ? sin(phase) : 0.0

        case 6: // Full-rectified sine — band-limited via even harmonics
            // |sin(x)| = 2/π - (4/π) * Σ cos(2nx) / (4n²-1)
            var sample: Float = 2.0 / Float.pi
            let maxEvenHarmonics = max(1, min(maxHarmonics / 2, 32))
            for n in 1...maxEvenHarmonics {
                let nf = Float(n)
                sample -= (4.0 / Float.pi) * cos(phase * 2.0 * nf) / (4.0 * nf * nf - 1.0)
            }
            return sample * Float.pi * 0.5 - 1.0  // Scale to [-1, 1] range

        case 7: // Metallic — already band-limited (only harmonics 1, 3, 5)
            if freq * 5.0 > nyquist {
                // Drop harmonics above Nyquist
                var sample = sin(phase) * 0.6
                if freq * 3.0 < nyquist { sample += sin(phase * 3.0) * 0.25 }
                return sample
            }
            return sin(phase) * 0.6 + sin(phase * 3.0) * 0.25 + sin(phase * 5.0) * 0.15

        default:
            return sin(phase)
        }
    }

    // MARK: - DSP Utilities

    /// SVF (State Variable Filter) — Cytomic/Chamberlin implementation
    private func svfFilter(input: Float, cutoff: Float, resonance: Float, sr: Float, mode: SynthFilterMode, ic1eq: inout Float, ic2eq: inout Float) -> Float {
        let g = tan(Float.pi * min(cutoff, sr * 0.49) / sr)
        let k = 2.0 - 2.0 * resonance  // damping
        let a1 = 1.0 / (1.0 + g * (g + k))
        let a2 = g * a1
        let a3 = g * a2

        let v3 = input - ic2eq
        let v1 = a1 * ic1eq + a2 * v3
        let v2 = ic2eq + a2 * ic1eq + a3 * v3

        ic1eq = 2.0 * v1 - ic1eq
        ic2eq = 2.0 * v2 - ic2eq

        switch mode {
        case .lowpass:  return v2
        case .highpass: return input - k * v1 - v2
        case .bandpass: return v1
        }
    }

    /// PolyBLEP anti-aliasing correction
    private func polyBLEP(t: Float, dt: Float) -> Float {
        var blep: Float = 0.0
        var tVal = t
        if tVal < dt {
            tVal /= dt
            blep = tVal + tVal - tVal * tVal - 1.0
        } else if tVal > 1.0 - dt {
            tVal = (tVal - 1.0) / dt
            blep = tVal * tVal + tVal + tVal + 1.0
        }
        return blep
    }

    /// tanh soft saturation
    private func tanhSaturation(_ input: Float, drive: Float) -> Float {
        let driven = input * (1.0 + drive * 4.0)
        let x2 = driven * driven
        return driven * (27.0 + x2) / (27.0 + 9.0 * x2)
    }
}

// MARK: - MIDI Integration

extension EchoelSynth {

    public func handleMIDINoteOn(channel: UInt8, note: UInt8, velocity: UInt8) {
        noteOn(note: Int(note), velocity: Float(velocity) / 127.0)
    }

    public func handleMIDINoteOff(channel: UInt8, note: UInt8) {
        noteOff(note: Int(note))
    }

    public func handleMIDICC(channel: UInt8, cc: UInt8, value: UInt8) {
        let v = Float(value) / 127.0
        switch cc {
        case 1:  config.wtPosition = v                                    // Mod wheel → wavetable
        case 74: config.filterCutoff = 20.0 + v * 19980.0               // Brightness → filter
        case 71: config.filterResonance = v                               // Resonance
        case 73: config.attack = 0.001 + v * 0.999                       // Attack
        case 75: config.decay = 0.05 + v * 9.95                          // Decay
        case 91: config.drive = v                                         // Drive
        case 7:  config.level = v                                         // Volume
        case 10: config.stereoWidth = v                                   // Pan → width
        default: break
        }
    }
}

// MARK: - Bio-Reactive Engine Mapping

extension EchoelSynth {

    /// Apply bio-reactive modulation — called from control loop (~60Hz)
    public func applyBioReactiveModulation(coherence: Float, heartRate: Float, hrv: Float, breathPhase: Float) {
        updateBio(coherence: coherence, heartRate: heartRate, hrv: hrv, breathPhase: breathPhase)

        // Coherence → filter brightness (high coherence = brighter, more open)
        let coherenceFilter = 2000.0 + min(1.0, max(0.0, coherence)) * 8000.0
        config.filterCutoff = coherenceFilter

        // HRV → filter envelope depth
        let hrvNorm = min(1.0, hrv / 100.0)
        config.filterEnvAmount = 500.0 + hrvNorm * 5000.0

        // Heart rate → vibrato
        let hrNorm = (heartRate - 50.0) / 100.0
        config.vibratoDepth = max(0, hrNorm * 0.15)
        config.vibratoRate = 4.0 + hrNorm * 3.0
    }
}

#endif
