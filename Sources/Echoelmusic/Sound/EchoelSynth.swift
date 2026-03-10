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

public struct EchoelSynthConfig: Codable, Equatable {

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
        attack: 0.8, decay: 1.0, sustain: 0.8, release: 2.0, chorusAmount: 0.5, stereoWidth: 0.8, level: 0.7
    )

    public static let synthBrass = EchoelSynthConfig(
        engine: .analog, analogDetune: 8.0, analogVoices: 5, analogWaveform: 0.3,
        filterCutoff: 1200.0, filterResonance: 0.3, filterEnvAmount: 6000.0, filterEnvDecay: 0.15,
        attack: 0.03, decay: 0.2, sustain: 0.7, release: 0.2, drive: 0.1, level: 0.8
    )

    public static let crystalPluck = EchoelSynthConfig(
        engine: .pluck, pluckDamping: 0.2, pluckDecay: 0.998, pluckBrightness: 1.0, pluckStretch: 0.1,
        filterCutoff: 15000.0, filterResonance: 0.05,
        attack: 0.001, decay: 2.0, sustain: 0.0, release: 0.8, chorusAmount: 0.3, stereoWidth: 0.5, level: 0.75
    )

    public static let retroWavetable = EchoelSynthConfig(
        engine: .wavetable, wtPosition: 0.3, wtModSpeed: 0.5,
        filterCutoff: 4000.0, filterResonance: 0.4, filterEnvAmount: 3000.0, filterEnvDecay: 0.3,
        attack: 0.01, decay: 0.5, sustain: 0.5, release: 0.4, drive: 0.1, level: 0.8
    )

    public static let bioReactive = EchoelSynthConfig(
        engine: .wavetable, wtPosition: 0.5, wtModSpeed: 0.2,
        filterCutoff: 3000.0, filterResonance: 0.3, filterEnvAmount: 3000.0, filterEnvDecay: 0.5,
        attack: 0.1, decay: 0.8, sustain: 0.6, release: 0.8, chorusAmount: 0.3, stereoWidth: 0.4,
        vibratoRate: 5.0, vibratoDepth: 0.1, level: 0.75
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

    nonisolated(unsafe) public static let shared = EchoelSynth()

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

        voiceLock.lock()

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

                // ─── Stereo output with width ───
                let spread = cfg.stereoWidth * 0.5
                let pan = Float(v.midiNote - 60) / 60.0 * spread  // Note-based stereo spread
                leftBuffer[frame] += sample * (1.0 - pan)
                rightBuffer[frame] += sample * (1.0 + pan)
            }

            voices[voiceIndex] = v
        }

        // Remove finished voices
        for index in voicesToRemove.sorted().reversed() {
            if index < voices.count { voices.remove(at: index) }
        }

        voiceLock.unlock()

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

            // FM amount with mod envelope decay
            let fmAmount = cfg.fmDepth * 4.0 * v.fmModEnvelope
            let carrierPhaseOffset = Double(modWithFeedback * fmAmount)

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

            let s0 = wavetableShape(shape: shape0, phase: ph)
            let s1 = wavetableShape(shape: shape1, phase: ph)

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

    private func wavetableShape(shape: Int, phase: Float) -> Float {
        switch shape {
        case 0: // Sine
            return sin(phase)
        case 1: // Triangle
            let t = phase / (2.0 * Float.pi)
            return 4.0 * abs(t - 0.5) - 1.0
        case 2: // Saw
            return phase / Float.pi - 1.0
        case 3: // Square
            return phase < Float.pi ? 1.0 : -1.0
        case 4: // Pulse (25%)
            return phase < Float.pi * 0.5 ? 1.0 : -1.0
        case 5: // Half-rectified sine
            return phase < Float.pi ? sin(phase) : 0.0
        case 6: // Full-rectified sine (abs sine)
            return abs(sin(phase)) * 2.0 - 1.0
        case 7: // Metallic (sine + 3rd + 5th harmonic)
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

// MARK: - SwiftUI View

#if canImport(SwiftUI)
public struct EchoelSynthView: View {
    @Bindable private var synth = EchoelSynth.shared
    @State private var selectedPreset: String = "Lead"

    private let presets: [(String, EchoelSynthConfig)] = [
        ("Lead", .classicLead),
        ("E.Piano", .electricPiano),
        ("Bell", .bellKeys),
        ("Pluck", .pluckedGuitar),
        ("Pad", .warmPad),
        ("Brass", .synthBrass),
        ("Crystal", .crystalPluck),
        ("Retro", .retroWavetable),
        ("Bio", .bioReactive)
    ]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            ScrollView {
                VStack(spacing: 16) {
                    presetSelector
                    engineSection
                    filterSection
                    envelopeSection
                    effectsSection
                    keyboardView
                }
                .padding()
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: engineGradient(synth.config.engine),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Text("SYNTH")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("EchoelSynth")
                    .font(.title2.bold())
                Text("5-Engine Melodic Synthesizer")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Text(synth.config.engine.rawValue)
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(engineColor(synth.config.engine)))
            }

            // Level meter
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(meterColor)
                            .frame(height: geo.size.height * CGFloat(synth.meterLevel))
                    }
                }
                .frame(width: 20, height: 40)
            }
        }
        .padding()
    }

    private var meterColor: Color {
        if synth.meterLevel > 0.9 { return .red }
        if synth.meterLevel > 0.7 { return .orange }
        return .green
    }

    // MARK: - Preset Selector

    private var presetSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preset")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.0) { name, preset in
                        Button(action: {
                            selectedPreset = name
                            synth.setPreset(preset)
                        }) {
                            Text(name)
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(selectedPreset == name ? engineColor(preset.engine) : Color.gray.opacity(0.2))
                                )
                                .foregroundColor(selectedPreset == name ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Engine Section

    private var engineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Engine")
                .font(.headline)

            Picker("Engine", selection: $synth.config.engine) {
                ForEach(SynthEngineType.allCases, id: \.self) { engine in
                    Text(engine.rawValue).tag(engine)
                }
            }
            .pickerStyle(.segmented)

            // Engine-specific controls
            switch synth.config.engine {
            case .analog:
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("Detune").font(.caption)
                        Slider(value: $synth.config.analogDetune, in: 0...50)
                        Text(String(format: "%.0f ct", synth.config.analogDetune)).font(.caption2.monospacedDigit())
                    }
                    VStack(spacing: 4) {
                        Text("Waveform").font(.caption)
                        Slider(value: $synth.config.analogWaveform, in: 0...1)
                        Text(synth.config.analogWaveform < 0.5 ? "Saw" : "Square").font(.caption2)
                    }
                }
            case .fm:
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("Ratio").font(.caption)
                        Slider(value: $synth.config.fmRatio, in: 0.5...8.0)
                        Text(String(format: "%.1f", synth.config.fmRatio)).font(.caption2.monospacedDigit())
                    }
                    VStack(spacing: 4) {
                        Text("Depth").font(.caption)
                        Slider(value: $synth.config.fmDepth, in: 0...2)
                        Text(String(format: "%.1f", synth.config.fmDepth)).font(.caption2.monospacedDigit())
                    }
                }
            case .wavetable:
                VStack(spacing: 4) {
                    Text("Position").font(.caption)
                    Slider(value: $synth.config.wtPosition, in: 0...1)
                    Text(String(format: "%.0f%%", synth.config.wtPosition * 100)).font(.caption2.monospacedDigit())
                }
            case .pluck:
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("Damping").font(.caption)
                        Slider(value: $synth.config.pluckDamping, in: 0...1)
                        Text(String(format: "%.0f%%", synth.config.pluckDamping * 100)).font(.caption2.monospacedDigit())
                    }
                    VStack(spacing: 4) {
                        Text("Brightness").font(.caption)
                        Slider(value: $synth.config.pluckBrightness, in: 0...1)
                        Text(String(format: "%.0f%%", synth.config.pluckBrightness * 100)).font(.caption2.monospacedDigit())
                    }
                }
            case .pad:
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("Spread").font(.caption)
                        Slider(value: $synth.config.padSpread, in: 0...50)
                        Text(String(format: "%.0f ct", synth.config.padSpread)).font(.caption2.monospacedDigit())
                    }
                    VStack(spacing: 4) {
                        Text("Chorus").font(.caption)
                        Slider(value: $synth.config.padChorusDepth, in: 0...1)
                        Text(String(format: "%.0f%%", synth.config.padChorusDepth * 100)).font(.caption2.monospacedDigit())
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(engineColor(synth.config.engine).opacity(0.1))
        )
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Filter").font(.headline)
                Spacer()
                Picker("Mode", selection: $synth.config.filterMode) {
                    ForEach(SynthFilterMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("Cutoff").font(.caption)
                    Slider(value: $synth.config.filterCutoff, in: 20...20000).tint(.cyan)
                    Text(String(format: "%.0f Hz", synth.config.filterCutoff)).font(.caption2.monospacedDigit())
                }
                VStack(spacing: 4) {
                    Text("Resonance").font(.caption)
                    Slider(value: $synth.config.filterResonance, in: 0...1).tint(.cyan)
                    Text(String(format: "%.0f%%", synth.config.filterResonance * 100)).font(.caption2.monospacedDigit())
                }
                VStack(spacing: 4) {
                    Text("Env Amt").font(.caption)
                    Slider(value: $synth.config.filterEnvAmount, in: 0...10000).tint(.cyan)
                    Text(String(format: "%.0f Hz", synth.config.filterEnvAmount)).font(.caption2.monospacedDigit())
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cyan.opacity(0.1))
        )
    }

    // MARK: - Envelope Section

    private var envelopeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Envelope").font(.headline)
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Attack").font(.caption)
                    Slider(value: $synth.config.attack, in: 0.001...2.0).tint(.red)
                    Text(String(format: "%.0fms", synth.config.attack * 1000)).font(.caption2.monospacedDigit())
                }
                VStack(spacing: 4) {
                    Text("Decay").font(.caption)
                    Slider(value: $synth.config.decay, in: 0.05...10.0).tint(.red)
                    Text(String(format: "%.1fs", synth.config.decay)).font(.caption2.monospacedDigit())
                }
                VStack(spacing: 4) {
                    Text("Sustain").font(.caption)
                    Slider(value: $synth.config.sustain, in: 0...1).tint(.red)
                    Text(String(format: "%.0f%%", synth.config.sustain * 100)).font(.caption2.monospacedDigit())
                }
                VStack(spacing: 4) {
                    Text("Release").font(.caption)
                    Slider(value: $synth.config.release, in: 0.01...5.0).tint(.red)
                    Text(String(format: "%.2fs", synth.config.release)).font(.caption2.monospacedDigit())
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
        )
    }

    // MARK: - Effects Section

    private var effectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Output").font(.headline)
            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Drive").font(.caption)
                    Slider(value: $synth.config.drive, in: 0...1).tint(.purple)
                    Text(String(format: "%.0f%%", synth.config.drive * 100)).font(.caption2.monospacedDigit())
                }
                VStack(spacing: 4) {
                    Text("Chorus").font(.caption)
                    Slider(value: $synth.config.chorusAmount, in: 0...1).tint(.purple)
                    Text(String(format: "%.0f%%", synth.config.chorusAmount * 100)).font(.caption2.monospacedDigit())
                }
                VStack(spacing: 4) {
                    Text("Width").font(.caption)
                    Slider(value: $synth.config.stereoWidth, in: 0...1).tint(.purple)
                    Text(String(format: "%.0f%%", synth.config.stereoWidth * 100)).font(.caption2.monospacedDigit())
                }
                VStack(spacing: 4) {
                    Text("Level").font(.caption)
                    Slider(value: $synth.config.level, in: 0...1).tint(.purple)
                    Text(String(format: "%.0f%%", synth.config.level * 100)).font(.caption2.monospacedDigit())
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.1))
        )
    }

    // MARK: - Keyboard

    private var keyboardView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Play").font(.headline)

            // Two octave keyboard C4-B5
            VStack(spacing: 4) {
                // Octave 4
                HStack(spacing: 3) {
                    ForEach([60, 62, 64, 65, 67, 69, 71, 72], id: \.self) { note in
                        keyButton(note: note)
                    }
                }
                // Octave 5
                HStack(spacing: 3) {
                    ForEach([72, 74, 76, 77, 79, 81, 83, 84], id: \.self) { note in
                        keyButton(note: note)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }

    private func keyButton(note: Int) -> some View {
        let isBlack = [1, 3, 6, 8, 10].contains(note % 12)
        return Button(action: {}) {
            Text(noteNameForMIDI(note))
                .font(.caption2)
                .frame(maxWidth: .infinity)
                .frame(height: isBlack ? 45 : 55)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(synth.currentNote == note ? engineColor(synth.config.engine) : (isBlack ? Color.gray.opacity(0.5) : Color.gray.opacity(0.15)))
                )
                .foregroundColor(synth.currentNote == note ? .white : (isBlack ? .white : .primary))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if value.translation == .zero {
                        synth.noteOn(note: note, velocity: 0.8)
                    }
                }
                .onEnded { _ in synth.noteOff(note: note) }
        )
    }

    // MARK: - Helpers

    private func noteNameForMIDI(_ note: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (note / 12) - 1
        return "\(names[note % 12])\(octave)"
    }

    private func engineColor(_ type: SynthEngineType) -> Color {
        switch type {
        case .analog:    return .blue
        case .fm:        return .orange
        case .wavetable: return .green
        case .pluck:     return .teal
        case .pad:       return .indigo
        }
    }

    private func engineGradient(_ type: SynthEngineType) -> [Color] {
        switch type {
        case .analog:    return [.blue, .cyan]
        case .fm:        return [.orange, .yellow]
        case .wavetable: return [.green, .mint]
        case .pluck:     return [.teal, .cyan]
        case .pad:       return [.indigo, .purple]
        }
    }
}
#endif

// MARK: - Preview

#if DEBUG && canImport(SwiftUI)
struct EchoelSynthView_Previews: PreviewProvider {
    static var previews: some View {
        EchoelSynthView()
    }
}
#endif
#endif
