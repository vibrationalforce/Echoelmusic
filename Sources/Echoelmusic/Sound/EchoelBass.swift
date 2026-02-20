//
//  EchoelBass.swift
//  Echoelmusic
//
//  Created: February 2026
//  ECHOELBASS — 5-ENGINE MORPHING BASS SYNTHESIZER
//
//  ═══════════════════════════════════════════════════════════════════════════════
//  5 Bass Engines with A/B Morph Crossfade:
//
//  ┌─────────────┐    ┌─────────────┐
//  │  Engine A    │    │  Engine B    │
//  │  (any of 5)  │────│  (any of 5)  │──→ Morph Crossfade ──→ Filter ──→ FX ──→ Out
//  └─────────────┘    └─────────────┘
//
//  Engines:
//  1. 808 Sub    — Sine core + pitch glide + analog saturation (TR-808 style)
//  2. Reese      — Detuned dual-saw + unison + slow phase drift (DnB/Neurofunk)
//  3. Moog       — 4-pole 24dB/oct ladder filter + tanh saturation (Minimoog)
//  4. Acid       — Saw/Square → resonant diode ladder + accent (TB-303 style)
//  5. Growl      — FM + wavefolder + formant filter (dubstep/riddim growl bass)
//
//  Signal Chain:
//  Engine A/B → Morph → Moog Ladder Filter → Drive → Sub Harmonic → Stereo Width → Out
//
//  Bio-Reactive:
//  • Coherence → engine morph position + filter cutoff
//  • Heart rate → vibrato depth
//  • HRV → filter modulation depth
//  • Breath phase → amplitude swell
//  ═══════════════════════════════════════════════════════════════════════════════

import Foundation
import AVFoundation
import Accelerate
import Combine
import SwiftUI

// MARK: - Bass Engine Type

/// The 5 bass synthesis engines available in EchoelBass
public enum BassEngineType: String, CaseIterable, Codable, Sendable {
    case sub808   = "808 Sub"      // Classic 808 sine + pitch glide
    case reese    = "Reese"        // Detuned saw unison (DnB)
    case moog     = "Moog"         // Ladder filter bass (Minimoog)
    case acid     = "Acid"         // TB-303 diode ladder
    case growl    = "Growl"        // FM + wavefolder (dubstep)
}

// MARK: - EchoelBass Configuration

/// Full configuration for the 5-engine morphing bass
public struct EchoelBassConfig: Codable, Equatable {

    // MARK: - Engine Selection

    /// Engine A type
    public var engineA: BassEngineType = .sub808

    /// Engine B type
    public var engineB: BassEngineType = .reese

    /// Morph position (0 = 100% A, 1 = 100% B)
    public var morphPosition: Float = 0.0

    // MARK: - Oscillator

    /// Base tuning in cents (-100 to +100)
    public var tuning: Float = 0.0

    /// Octave shift (-2 to +2)
    public var octave: Int = 0

    /// Sub-oscillator mix (0 = off, 1 = full sub -1 octave)
    public var subOscMix: Float = 0.0

    // MARK: - 808 Engine

    /// Pitch glide enabled
    public var glideEnabled: Bool = true

    /// Pitch glide time in seconds
    public var glideTime: Float = 0.08

    /// Pitch glide range in semitones
    public var glideRange: Float = -12.0

    /// Attack click amount (0-1)
    public var clickAmount: Float = 0.3

    /// Click frequency in Hz
    public var clickFreq: Float = 1200.0

    // MARK: - Reese Engine

    /// Detune amount in cents for Reese unison
    public var reeseDetune: Float = 15.0

    /// Number of unison voices (1-7)
    public var reeseVoices: Int = 3

    /// Phase drift speed
    public var reeseDrift: Float = 0.2

    // MARK: - Moog Engine

    /// Moog ladder filter drive (resonance feedback)
    public var moogDrive: Float = 0.3

    /// Moog oscillator mix (saw vs square, 0=saw, 1=square)
    public var moogWaveform: Float = 0.0

    // MARK: - Acid Engine

    /// Accent amount for TB-303 accent
    public var acidAccent: Float = 0.6

    /// Slide (glide) for acid lines
    public var acidSlide: Bool = true

    /// Acid waveform (0 = saw, 1 = square)
    public var acidWaveform: Float = 0.0

    // MARK: - Growl Engine

    /// FM modulator ratio
    public var growlFMRatio: Float = 1.5

    /// FM depth (modulation index)
    public var growlFMDepth: Float = 0.5

    /// Wavefolder amount
    public var growlFold: Float = 0.3

    /// Formant position (0 = "oo", 0.5 = "ah", 1 = "ee")
    public var growlFormant: Float = 0.0

    // MARK: - Filter (Shared)

    /// Filter cutoff frequency in Hz (20 - 20000)
    public var filterCutoff: Float = 800.0

    /// Filter resonance (0 - 1)
    public var filterResonance: Float = 0.2

    /// Filter envelope amount in Hz
    public var filterEnvAmount: Float = 2000.0

    /// Filter envelope decay in seconds
    public var filterEnvDecay: Float = 0.3

    /// Filter key tracking (0 = none, 1 = full)
    public var filterKeyTrack: Float = 0.5

    // MARK: - Amplitude Envelope

    /// Attack time in seconds
    public var attack: Float = 0.005

    /// Decay time in seconds
    public var decay: Float = 1.5

    /// Sustain level (0-1)
    public var sustain: Float = 0.0

    /// Release time in seconds
    public var release: Float = 0.3

    // MARK: - Effects

    /// Drive/saturation amount (0-1)
    public var drive: Float = 0.2

    /// Output level (0-1)
    public var level: Float = 0.8

    /// Stereo width (0 = mono, 1 = wide)
    public var stereoWidth: Float = 0.0

    /// Vibrato rate in Hz
    public var vibratoRate: Float = 5.0

    /// Vibrato depth in semitones
    public var vibratoDepth: Float = 0.0

    // MARK: - Presets

    public static let classic808 = EchoelBassConfig(
        engineA: .sub808, engineB: .reese, morphPosition: 0.0,
        glideEnabled: true, glideTime: 0.06, glideRange: -12.0,
        clickAmount: 0.25, clickFreq: 1000.0,
        filterCutoff: 400.0, filterResonance: 0.1,
        decay: 1.2, drive: 0.15, level: 0.85
    )

    public static let reeseMonster = EchoelBassConfig(
        engineA: .reese, engineB: .growl, morphPosition: 0.0,
        reeseDetune: 20.0, reeseVoices: 5, reeseDrift: 0.3,
        filterCutoff: 1200.0, filterResonance: 0.3,
        filterEnvAmount: 3000.0, filterEnvDecay: 0.5,
        decay: 2.0, sustain: 0.6, drive: 0.4, level: 0.8
    )

    public static let moogBass = EchoelBassConfig(
        engineA: .moog, engineB: .sub808, morphPosition: 0.0,
        moogDrive: 0.5, moogWaveform: 0.0,
        filterCutoff: 600.0, filterResonance: 0.5,
        filterEnvAmount: 4000.0, filterEnvDecay: 0.2,
        decay: 0.8, sustain: 0.3, drive: 0.2, level: 0.85
    )

    public static let acid303 = EchoelBassConfig(
        engineA: .acid, engineB: .moog, morphPosition: 0.0,
        acidAccent: 0.7, acidSlide: true, acidWaveform: 0.0,
        filterCutoff: 400.0, filterResonance: 0.7,
        filterEnvAmount: 6000.0, filterEnvDecay: 0.15,
        decay: 0.5, sustain: 0.4, drive: 0.3, level: 0.8
    )

    public static let dubstepGrowl = EchoelBassConfig(
        engineA: .growl, engineB: .reese, morphPosition: 0.0,
        growlFMRatio: 2.0, growlFMDepth: 0.7, growlFold: 0.5, growlFormant: 0.3,
        filterCutoff: 1000.0, filterResonance: 0.4,
        filterEnvAmount: 5000.0, filterEnvDecay: 0.4,
        decay: 1.0, sustain: 0.7, drive: 0.5, level: 0.75
    )

    public static let morphSweep = EchoelBassConfig(
        engineA: .sub808, engineB: .growl, morphPosition: 0.5,
        glideEnabled: true, glideTime: 0.1, glideRange: -12.0,
        growlFMRatio: 1.5, growlFMDepth: 0.4, growlFold: 0.2,
        filterCutoff: 600.0, filterResonance: 0.3,
        filterEnvAmount: 3000.0, filterEnvDecay: 0.3,
        decay: 1.5, sustain: 0.2, drive: 0.3, level: 0.8
    )

    public static let bioReactive = EchoelBassConfig(
        engineA: .moog, engineB: .reese, morphPosition: 0.5,
        reeseDetune: 12.0, reeseVoices: 3,
        moogDrive: 0.3,
        filterCutoff: 500.0, filterResonance: 0.4,
        filterEnvAmount: 2000.0, filterEnvDecay: 0.4,
        decay: 2.0, sustain: 0.5, vibratoRate: 5.0, vibratoDepth: 0.1,
        drive: 0.2, level: 0.8
    )
}

// MARK: - Voice State

/// Individual voice for polyphonic EchoelBass
private struct EchoelBassVoice {
    let id: UUID
    var midiNote: Int
    var velocity: Float
    var startTime: Double

    // Oscillator phases (per-engine)
    var phase: Double = 0.0             // Main osc
    var subPhase: Double = 0.0          // Sub osc
    var clickPhase: Double = 0.0        // 808 click
    var reesePhases: [Double] = [0, 0, 0, 0, 0, 0, 0]  // Unison voices
    var reeseDrifts: [Double] = [0, 0, 0, 0, 0, 0, 0]   // Phase drift accumulators
    var fmModPhase: Double = 0.0        // FM modulator phase
    var lfoPhase: Double = 0.0          // LFO for vibrato

    // Envelope state
    var ampEnvelope: Float = 0.0
    var filterEnvelope: Float = 1.0
    var pitchGlideProgress: Float = 0.0
    var isActive: Bool = true
    var isReleasing: Bool = false
    var releaseStartTime: Double = 0.0
    var releaseStartEnvelope: Float = 1.0
    var envStage: EnvStage = .attack

    // Filter state (Moog ladder 4-pole)
    var ladderStage: (Float, Float, Float, Float) = (0, 0, 0, 0)

    enum EnvStage { case attack, decay, sustain, release }
}

// MARK: - EchoelBass Synthesizer

/// EchoelBass — 5-Engine Morphing Bass Synthesizer
/// Professional sub-bass to aggressive growl, with bio-reactive control.
@MainActor
public final class EchoelBass: ObservableObject {

    // MARK: - Singleton

    public static let shared = EchoelBass()

    // MARK: - Published State

    @Published public var config = EchoelBassConfig.classic808
    @Published public var isPlaying: Bool = false
    @Published public var activeVoiceCount: Int = 0
    @Published public var currentNote: Int? = nil
    @Published public var meterLevel: Float = 0.0

    // MARK: - Audio Engine

    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private let sampleRate: Double = 48000.0
    private let maxVoices = 8

    // MARK: - Voice Management

    private var voices: [EchoelBassVoice] = []
    private let voiceLock = NSLock()

    // MARK: - DSP State

    private var currentTime: Double = 0.0
    private var lastMeterUpdate: Double = 0.0
    private var peakLevel: Float = 0.0

    // MARK: - Bio-Reactive

    private var bioCoherence: Float = 0.5
    private var bioHeartRate: Float = 72.0
    private var bioHRV: Float = 50.0
    private var bioBreathPhase: Float = 0.0

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()

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

        do { try engine.start() } catch { }
    }

    // MARK: - Public API

    public func start() {
        guard let engine = audioEngine, !engine.isRunning else { return }
        do { try engine.start(); isPlaying = true } catch { isPlaying = false }
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
            do { try audioEngine?.start() } catch { }
        }

        voiceLock.lock()
        defer { voiceLock.unlock() }

        // Retrigger existing voice on same note
        if let idx = voices.firstIndex(where: { $0.midiNote == note && $0.isActive }) {
            voices[idx].startTime = currentTime
            voices[idx].ampEnvelope = 0.0
            voices[idx].filterEnvelope = 1.0
            voices[idx].pitchGlideProgress = 0.0
            voices[idx].velocity = velocity
            voices[idx].isReleasing = false
            voices[idx].envStage = .attack
            voices[idx].phase = 0.0
            voices[idx].clickPhase = 0.0
            voices[idx].fmModPhase = 0.0
        } else {
            // Voice stealing
            if voices.count >= maxVoices {
                if let oldIdx = voices.indices.min(by: { voices[$0].startTime < voices[$1].startTime }) {
                    voices.remove(at: oldIdx)
                }
            }

            var voice = EchoelBassVoice(id: UUID(), midiNote: note, velocity: velocity, startTime: currentTime)
            // Initialize Reese drift with random phase offsets
            for i in 0..<7 {
                voice.reeseDrifts[i] = Double.random(in: 0..<1.0)
            }
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

    public func setPreset(_ preset: EchoelBassConfig) {
        config = preset
    }

    /// Update bio-reactive parameters from health sensors
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
                let filterEnvElapsed = elapsed
                let filterEnvProgress = min(1.0, filterEnvElapsed / max(cfg.filterEnvDecay, 0.001))
                v.filterEnvelope = 1.0 - filterEnvProgress

                // ─── Pitch Calculation ───
                let baseNote = Float(v.midiNote + cfg.octave * 12)
                let tunedNote = baseNote + cfg.tuning / 100.0
                var baseFreq = 440.0 * pow(2.0, (tunedNote - 69.0) / 12.0)

                // Pitch glide (808/Acid)
                if cfg.glideEnabled && v.pitchGlideProgress < 1.0 {
                    let glideProgress = min(1.0, elapsed / max(cfg.glideTime, 0.001))
                    v.pitchGlideProgress = glideProgress
                    let curved = pow(glideProgress, 0.7)
                    let offset = cfg.glideRange * (1.0 - curved)
                    baseFreq *= pow(2.0, offset / 12.0)
                }

                // Vibrato LFO
                if cfg.vibratoDepth > 0 {
                    let vibratoInc = Double(cfg.vibratoRate) / sampleRate
                    v.lfoPhase += vibratoInc
                    if v.lfoPhase >= 1.0 { v.lfoPhase -= 1.0 }
                    let vib = sin(Float(v.lfoPhase) * 2.0 * Float.pi) * cfg.vibratoDepth
                    baseFreq *= pow(2.0, vib / 12.0)
                }

                let phaseInc = Double(baseFreq) / sampleRate

                // ─── Engine A ───
                let sampleA = renderEngine(type: cfg.engineA, voice: &v, freq: baseFreq, phaseInc: phaseInc, elapsed: elapsed, cfg: cfg, sr: sr, isEngineA: true)

                // ─── Engine B ───
                let sampleB = renderEngine(type: cfg.engineB, voice: &v, freq: baseFreq, phaseInc: phaseInc, elapsed: elapsed, cfg: cfg, sr: sr, isEngineA: false)

                // ─── Morph Crossfade ───
                let morph = cfg.morphPosition
                var sample = sampleA * (1.0 - morph) + sampleB * morph

                // ─── Sub Oscillator ───
                if cfg.subOscMix > 0 {
                    let subInc = phaseInc * 0.5
                    let sub = sin(Float(v.subPhase) * 2.0 * Float.pi)
                    v.subPhase += subInc
                    if v.subPhase >= 1.0 { v.subPhase -= 1.0 }
                    sample = sample * (1.0 - cfg.subOscMix) + sub * cfg.subOscMix
                }

                // ─── Moog Ladder Filter (4-pole, 24dB/oct) ───
                let keyTrackHz = cfg.filterKeyTrack * (baseFreq - 261.63)
                let envHz = cfg.filterEnvAmount * v.filterEnvelope
                let cutoff = min(20000.0, max(20.0, cfg.filterCutoff + envHz + keyTrackHz))

                sample = moogLadderFilter(input: sample, cutoff: cutoff, resonance: cfg.filterResonance, sr: sr, state: &v.ladderStage)

                // ─── Drive/Saturation ───
                if cfg.drive > 0 {
                    sample = tanhSaturation(sample, drive: cfg.drive)
                }

                // ─── Apply Envelope + Velocity ───
                sample *= env * v.velocity * cfg.level

                // ─── Bio-reactive amplitude swell ───
                let breathSwell = 1.0 + (bioBreathPhase - 0.5) * 0.1
                sample *= breathSwell

                // Track peak
                peak = Swift.max(peak, abs(sample))

                // ─── Stereo output ───
                let spread = cfg.stereoWidth * 0.5
                leftBuffer[frame] += sample * (1.0 - spread)
                rightBuffer[frame] += sample * (1.0 + spread)
            }

            voices[voiceIndex] = v
        }

        // Remove finished voices
        for index in voicesToRemove.sorted().reversed() {
            if index < voices.count { voices.remove(at: index) }
        }

        voiceLock.unlock()

        currentTime += Double(frameCount) / sampleRate

        // Meter update (throttled to ~20Hz)
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

    /// Render a single sample from the specified engine type
    private func renderEngine(type: BassEngineType, voice v: inout EchoelBassVoice, freq: Float, phaseInc: Double, elapsed: Float, cfg: EchoelBassConfig, sr: Float, isEngineA: Bool) -> Float {
        switch type {

        case .sub808:
            // ─── 808 Sub: Sine core + pitch glide + click ───
            let osc = sin(Float(v.phase) * 2.0 * Float.pi)
            if isEngineA {
                v.phase += phaseInc
                if v.phase >= 1.0 { v.phase -= 1.0 }
            }
            var sample = osc

            // Attack click
            if cfg.clickAmount > 0 && elapsed < 0.02 {
                let clickEnv = 1.0 - (elapsed / 0.02)
                let clickInc = Double(cfg.clickFreq) / Double(sr)
                let click = sin(Float(v.clickPhase) * 2.0 * Float.pi) * clickEnv * cfg.clickAmount
                if isEngineA {
                    v.clickPhase += clickInc
                }
                sample += click
            }
            return sample

        case .reese:
            // ─── Reese: Detuned saw unison + slow phase drift ───
            let voiceCount = min(cfg.reeseVoices, 7)
            let detuneRange = cfg.reeseDetune / 1200.0  // cents → ratio
            var mix: Float = 0.0

            for i in 0..<voiceCount {
                // Spread detune symmetrically around center
                let detuneOffset: Float
                if voiceCount == 1 {
                    detuneOffset = 0
                } else {
                    detuneOffset = -detuneRange + detuneRange * 2.0 * Float(i) / Float(voiceCount - 1)
                }
                let voiceFreq = freq * (1.0 + detuneOffset)
                let voiceInc = Double(voiceFreq) / Double(sr)

                // Slow drift
                let driftInc = Double(cfg.reeseDrift * 0.1) / Double(sr)
                v.reeseDrifts[i] += driftInc

                // PolyBLEP saw
                var ph = v.reesePhases[i]
                ph += voiceInc
                if ph >= 1.0 { ph -= 1.0 }
                v.reesePhases[i] = ph

                // Naive saw with PolyBLEP correction
                var saw = Float(2.0 * ph - 1.0)
                saw -= polyBLEP(t: Float(ph), dt: Float(voiceInc))
                mix += saw
            }

            return mix / Float(max(1, voiceCount))

        case .moog:
            // ─── Moog: Saw/Square through ladder resonance ───
            v.phase += phaseInc
            if v.phase >= 1.0 { v.phase -= 1.0 }

            let sawVal = Float(2.0 * v.phase - 1.0) - polyBLEP(t: Float(v.phase), dt: Float(phaseInc))

            // Square via subtracted saw one octave up (pulse)
            var ph2 = v.phase + 0.5
            if ph2 >= 1.0 { ph2 -= 1.0 }
            let sqrVal = (Float(v.phase) < 0.5) ? 1.0 : -1.0 as Float

            let wfMix = cfg.moogWaveform
            let sample = sawVal * (1.0 - wfMix) + sqrVal * wfMix

            // Extra resonance drive from Moog engine
            return sample * (1.0 + cfg.moogDrive * 0.5)

        case .acid:
            // ─── Acid (TB-303): Saw/Square + accent ───
            v.phase += phaseInc
            if v.phase >= 1.0 { v.phase -= 1.0 }

            let sawVal = Float(2.0 * v.phase - 1.0) - polyBLEP(t: Float(v.phase), dt: Float(phaseInc))
            let sqrVal: Float = (Float(v.phase) < 0.5) ? 1.0 : -1.0

            let wfMix = cfg.acidWaveform
            var sample = sawVal * (1.0 - wfMix) + sqrVal * wfMix

            // Accent — boost amplitude and filter env on high velocity
            let accent = cfg.acidAccent * v.velocity
            sample *= (1.0 + accent * 0.5)

            return sample

        case .growl:
            // ─── Growl: FM synthesis + wavefolder + formant ───
            let carrierInc = phaseInc
            let modInc = phaseInc * Double(cfg.growlFMRatio)

            // FM modulator
            v.fmModPhase += modInc
            if v.fmModPhase >= 1.0 { v.fmModPhase -= 1.0 }
            let modulator = sin(Float(v.fmModPhase) * 2.0 * Float.pi)

            // FM carrier with modulation
            let fmAmount = cfg.growlFMDepth * 4.0  // Scale for audible FM
            let carrierPhaseOffset = Double(modulator * fmAmount)

            v.phase += carrierInc
            if v.phase >= 1.0 { v.phase -= 1.0 }

            var sample = sin(Float(v.phase + carrierPhaseOffset) * 2.0 * Float.pi)

            // Wavefolder (sine folder for metallic harmonics)
            if cfg.growlFold > 0 {
                let foldGain = 1.0 + cfg.growlFold * 4.0
                sample = sin(sample * foldGain * Float.pi)
            }

            // Simple formant: two resonant peaks
            // "oo" (250/700), "ah" (700/1200), "ee" (300/2500)
            let f = cfg.growlFormant
            let formant1: Float = 250.0 + f * 450.0
            let formant2: Float = 700.0 + f * 1800.0

            // One-pole bandpass approximation at formant frequencies
            let bpCoeff1 = exp(-2.0 * Float.pi * formant1 / sr)
            let bpCoeff2 = exp(-2.0 * Float.pi * formant2 / sr)
            let bp1 = sample * (1.0 - bpCoeff1)
            let bp2 = sample * (1.0 - bpCoeff2)
            sample = (bp1 + bp2) * 0.5

            return sample
        }
    }

    // MARK: - DSP Utilities

    /// PolyBLEP anti-aliasing correction
    private func polyBLEP(t: Float, dt: Float) -> Float {
        var blep: Float = 0.0
        var tVal = t
        // Check discontinuity at 0/1
        if tVal < dt {
            tVal /= dt
            blep = tVal + tVal - tVal * tVal - 1.0
        } else if tVal > 1.0 - dt {
            tVal = (tVal - 1.0) / dt
            blep = tVal * tVal + tVal + tVal + 1.0
        }
        return blep
    }

    /// 4-pole Moog Ladder Filter (24dB/oct, tanh saturation)
    private func moogLadderFilter(input: Float, cutoff: Float, resonance: Float, sr: Float, state: inout (Float, Float, Float, Float)) -> Float {
        // Normalized cutoff (0-1 range, clamped)
        let fc = min(0.99, max(0.001, cutoff / sr * 2.0))
        let g = 1.0 - exp(-2.0 * Float.pi * fc)
        let res = resonance * 4.0  // Resonance scaling for self-oscillation near 1.0

        // Feedback with resonance
        let feedback = res * state.3

        // Input with resonance feedback
        let input_fb = tanh(input - feedback)

        // 4 cascaded one-pole filters with tanh saturation
        state.0 += g * (input_fb - state.0)
        state.1 += g * (state.0 - state.1)
        state.2 += g * (state.1 - state.2)
        state.3 += g * (state.2 - state.3)

        return state.3
    }

    /// tanh soft saturation
    private func tanhSaturation(_ input: Float, drive: Float) -> Float {
        let driven = input * (1.0 + drive * 4.0)
        // Fast tanh approximation
        let x2 = driven * driven
        return driven * (27.0 + x2) / (27.0 + 9.0 * x2)
    }

    /// Standard tanh (used in ladder filter)
    private func tanh(_ x: Float) -> Float {
        if x > 3.0 { return 1.0 }
        if x < -3.0 { return -1.0 }
        let x2 = x * x
        return x * (27.0 + x2) / (27.0 + 9.0 * x2)
    }
}

// MARK: - MIDI Integration

extension EchoelBass {

    public func handleMIDINoteOn(channel: UInt8, note: UInt8, velocity: UInt8) {
        noteOn(note: Int(note), velocity: Float(velocity) / 127.0)
    }

    public func handleMIDINoteOff(channel: UInt8, note: UInt8) {
        noteOff(note: Int(note))
    }

    public func handleMIDICC(channel: UInt8, cc: UInt8, value: UInt8) {
        let v = Float(value) / 127.0
        switch cc {
        case 1:  config.morphPosition = v                                // Mod wheel → morph
        case 74: config.filterCutoff = 20.0 + v * 19980.0              // Brightness → filter
        case 71: config.filterResonance = v                              // Resonance
        case 73: config.attack = 0.001 + v * 0.999                      // Attack
        case 75: config.decay = 0.05 + v * 9.95                         // Decay
        case 91: config.drive = v                                        // Drive
        case 7:  config.level = v                                        // Volume
        case 10: config.stereoWidth = v                                  // Pan → width
        case 5:  config.glideTime = 0.01 + v * 0.49                     // Portamento
        default: break
        }
    }
}

// MARK: - Bio-Reactive Engine Mapping

extension EchoelBass {

    /// Apply bio-reactive modulation to engine parameters
    /// Called periodically (60Hz) from the control loop
    public func applyBioReactiveModulation(coherence: Float, heartRate: Float, hrv: Float, breathPhase: Float) {
        updateBio(coherence: coherence, heartRate: heartRate, hrv: hrv, breathPhase: breathPhase)

        // Coherence → engine morph + filter brightness
        // High coherence = engine A (typically warmer), low = more engine B
        config.morphPosition = 1.0 - min(1.0, max(0.0, coherence))

        // HRV → filter envelope depth (more variable heart = more expressive filter)
        let hrvNorm = min(1.0, hrv / 100.0)
        config.filterEnvAmount = 500.0 + hrvNorm * 5000.0

        // Heart rate → subtle vibrato (faster heart = more vibrato energy)
        let hrNorm = (heartRate - 50.0) / 100.0
        config.vibratoDepth = max(0, hrNorm * 0.15)
        config.vibratoRate = 4.0 + hrNorm * 3.0
    }
}

// MARK: - SwiftUI View

public struct EchoelBassView: View {
    @StateObject private var bass = EchoelBass.shared
    @State private var selectedPreset: String = "808 Sub"

    private let presets: [(String, EchoelBassConfig)] = [
        ("808 Sub", .classic808),
        ("Reese", .reeseMonster),
        ("Moog", .moogBass),
        ("Acid 303", .acid303),
        ("Growl", .dubstepGrowl),
        ("Morph", .morphSweep),
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
                    engineMorphSection
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
                            colors: engineGradient(bass.config.engineA),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Text("BASS")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("EchoelBass")
                    .font(.title2.bold())
                Text("5-Engine Morphing Bass")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Engine indicators
            HStack(spacing: 4) {
                Text(bass.config.engineA.rawValue)
                    .font(.caption2.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(engineColor(bass.config.engineA)))

                Text(String(format: "%.0f%%", (1.0 - bass.config.morphPosition) * 100))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)
            }

            // Level meter
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.gray.opacity(0.2))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(meterColor)
                            .frame(height: geo.size.height * CGFloat(bass.meterLevel))
                    }
                }
                .frame(width: 20, height: 40)
            }
        }
        .padding()
    }

    private var meterColor: Color {
        if bass.meterLevel > 0.9 { return .red }
        if bass.meterLevel > 0.7 { return .orange }
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
                            bass.setPreset(preset)
                        }) {
                            Text(name)
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(selectedPreset == name ? engineColor(preset.engineA) : Color.gray.opacity(0.2))
                                )
                                .foregroundColor(selectedPreset == name ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Engine Morph Section

    private var engineMorphSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Engine Morph")
                .font(.headline)

            // Engine A selector
            HStack {
                Text("A:")
                    .font(.caption.bold())
                    .foregroundColor(engineColor(bass.config.engineA))
                Picker("", selection: $bass.config.engineA) {
                    ForEach(BassEngineType.allCases, id: \.self) { engine in
                        Text(engine.rawValue).tag(engine)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Morph slider
            VStack(spacing: 4) {
                HStack {
                    Text(bass.config.engineA.rawValue)
                        .font(.caption2)
                        .foregroundColor(engineColor(bass.config.engineA))
                    Spacer()
                    Text(String(format: "%.0f%%", bass.config.morphPosition * 100))
                        .font(.caption2.monospacedDigit())
                    Spacer()
                    Text(bass.config.engineB.rawValue)
                        .font(.caption2)
                        .foregroundColor(engineColor(bass.config.engineB))
                }
                Slider(value: $bass.config.morphPosition, in: 0...1)
                    .accentColor(engineColor(bass.config.engineA))
            }

            // Engine B selector
            HStack {
                Text("B:")
                    .font(.caption.bold())
                    .foregroundColor(engineColor(bass.config.engineB))
                Picker("", selection: $bass.config.engineB) {
                    ForEach(BassEngineType.allCases, id: \.self) { engine in
                        Text(engine.rawValue).tag(engine)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.indigo.opacity(0.1))
        )
    }

    // MARK: - Filter Section

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Moog Ladder Filter")
                .font(.headline)

            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("Cutoff")
                        .font(.caption)
                    Slider(value: $bass.config.filterCutoff, in: 20...20000)
                        .tint(.cyan)
                    Text(String(format: "%.0f Hz", bass.config.filterCutoff))
                        .font(.caption2.monospacedDigit())
                }

                VStack(spacing: 4) {
                    Text("Resonance")
                        .font(.caption)
                    Slider(value: $bass.config.filterResonance, in: 0...1)
                        .tint(.cyan)
                    Text(String(format: "%.0f%%", bass.config.filterResonance * 100))
                        .font(.caption2.monospacedDigit())
                }

                VStack(spacing: 4) {
                    Text("Env Amt")
                        .font(.caption)
                    Slider(value: $bass.config.filterEnvAmount, in: 0...10000)
                        .tint(.cyan)
                    Text(String(format: "%.0f Hz", bass.config.filterEnvAmount))
                        .font(.caption2.monospacedDigit())
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
            Text("Envelope")
                .font(.headline)

            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Attack").font(.caption)
                    Slider(value: $bass.config.attack, in: 0.001...1.0).tint(.red)
                    Text(String(format: "%.0fms", bass.config.attack * 1000)).font(.caption2.monospacedDigit())
                }
                VStack(spacing: 4) {
                    Text("Decay").font(.caption)
                    Slider(value: $bass.config.decay, in: 0.05...10.0).tint(.red)
                    Text(String(format: "%.1fs", bass.config.decay)).font(.caption2.monospacedDigit())
                }
                VStack(spacing: 4) {
                    Text("Sustain").font(.caption)
                    Slider(value: $bass.config.sustain, in: 0...1).tint(.red)
                    Text(String(format: "%.0f%%", bass.config.sustain * 100)).font(.caption2.monospacedDigit())
                }
                VStack(spacing: 4) {
                    Text("Release").font(.caption)
                    Slider(value: $bass.config.release, in: 0.01...5.0).tint(.red)
                    Text(String(format: "%.2fs", bass.config.release)).font(.caption2.monospacedDigit())
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
            Text("Output")
                .font(.headline)

            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Drive").font(.caption)
                    Slider(value: $bass.config.drive, in: 0...1).tint(.purple)
                    Text(String(format: "%.0f%%", bass.config.drive * 100)).font(.caption2.monospacedDigit())
                }
                VStack(spacing: 4) {
                    Text("Width").font(.caption)
                    Slider(value: $bass.config.stereoWidth, in: 0...1).tint(.purple)
                    Text(String(format: "%.0f%%", bass.config.stereoWidth * 100)).font(.caption2.monospacedDigit())
                }
                VStack(spacing: 4) {
                    Text("Level").font(.caption)
                    Slider(value: $bass.config.level, in: 0...1).tint(.purple)
                    Text(String(format: "%.0f%%", bass.config.level * 100)).font(.caption2.monospacedDigit())
                }
            }

            // Glide toggle
            HStack {
                Toggle("Pitch Glide", isOn: $bass.config.glideEnabled)
                    .font(.caption)
                if bass.config.glideEnabled {
                    Slider(value: $bass.config.glideTime, in: 0.01...0.5)
                        .frame(width: 100)
                        .tint(.orange)
                    Text(String(format: "%.0fms", bass.config.glideTime * 1000))
                        .font(.caption2.monospacedDigit())
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
            Text("Play")
                .font(.headline)

            HStack(spacing: 4) {
                ForEach([36, 38, 40, 41, 43, 45, 47, 48], id: \.self) { note in
                    Button(action: {}) {
                        Text(noteNameForMIDI(note))
                            .font(.caption2)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(bass.currentNote == note ? engineColor(bass.config.engineA) : Color.gray.opacity(0.2))
                            )
                            .foregroundColor(bass.currentNote == note ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in bass.noteOn(note: note, velocity: 0.8) }
                            .onEnded { _ in bass.noteOff(note: note) }
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }

    // MARK: - Helpers

    private func noteNameForMIDI(_ note: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (note / 12) - 1
        return "\(names[note % 12])\(octave)"
    }

    private func engineColor(_ type: BassEngineType) -> Color {
        switch type {
        case .sub808: return .orange
        case .reese:  return .blue
        case .moog:   return .green
        case .acid:   return .yellow
        case .growl:  return Color(red: 1, green: 0, blue: 1)
        }
    }

    private func engineGradient(_ type: BassEngineType) -> [Color] {
        switch type {
        case .sub808: return [.orange, .red]
        case .reese:  return [.blue, .indigo]
        case .moog:   return [.green, .teal]
        case .acid:   return [.yellow, .orange]
        case .growl:  return [Color(red: 1, green: 0, blue: 1), .purple]
        }
    }
}

// MARK: - Preview

#if DEBUG
struct EchoelBassView_Previews: PreviewProvider {
    static var previews: some View {
        EchoelBassView()
    }
}
#endif
