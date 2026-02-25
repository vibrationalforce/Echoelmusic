//
//  EchoelBeat.swift
//  Echoelmusic
//
//  Created: February 2026
//  PROFESSIONAL DRUM MACHINE + HIHAT SYNTH ENGINE
//  λ∞ Ralph Wiggum Lambda Loop Mode — Maximum Quality Control
//
//  ═══════════════════════════════════════════════════════════════════════════════
//  FEATURES:
//  • 16 drum pad slots (pre-rendered from SynthPresetLibrary's 65+ presets)
//  • Real-time 808 HiHat synthesis (6 square oscillators → SVF BPF → HPF → VCA)
//  • Roll sequencer (1/8 to 1/64 + triplets, velocity/pitch ramps)
//  • Dirty delay (interpolated circular buffer + saturation + LP feedback filter)
//  • 16-step sequencer with sample-accurate timing from audio render callback
//  • 12 genre kits via SynthPresetLibrary
//  • 5 trap producer presets (Metro Boomin, Southside, London On Da Track, etc.)
//  • Bio-reactive pattern morphing
//
//  DSP CHAIN:
//  DrumSlots (pre-rendered) ─┐
//  HiHat Synth (real-time) ──┤→ Mix → DirtyDelay → Stereo Out
//  Roll Engine ──────────────┘
//
//  HiHat Signal Path (authentic TR-808):
//  6 Square Osc (non-harmonic) → SVF Bandpass → One-Pole HPF → Exp Decay VCA
//  ═══════════════════════════════════════════════════════════════════════════════

import Foundation
import AVFoundation
import Accelerate
import Combine

#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Drum Slot (Pre-Rendered from SynthPresetLibrary)

/// A pre-rendered drum sound loaded from the SynthPresetLibrary's 65+ parametric presets.
/// Each slot holds the fully rendered audio data — zero-allocation playback on the audio thread.
public struct DrumSlot: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var audioData: [Float]
    public var sampleRate: Float
    public var midiNote: Int
    public var category: String

    public init(name: String, audioData: [Float], sampleRate: Float, midiNote: Int, category: String = "") {
        self.id = UUID()
        self.name = name
        self.audioData = audioData
        self.sampleRate = sampleRate
        self.midiNote = midiNote
        self.category = category
    }
}

// MARK: - Beat Step Sequencer Types

/// A single step in a beat pattern track
public struct BeatStep: Codable, Sendable {
    public var isActive: Bool = false
    public var velocity: Float = 0.8
    public var probability: Float = 1.0

    public init(isActive: Bool = false, velocity: Float = 0.8, probability: Float = 1.0) {
        self.isActive = isActive
        self.velocity = velocity
        self.probability = probability
    }
}

/// A complete drum pattern with multiple tracks (one per drum slot)
public struct BeatPattern: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var tracks: [[BeatStep]]  // [trackIndex][stepIndex]
    public var stepCount: Int

    public init(name: String, trackCount: Int = 16, stepCount: Int = 16) {
        self.id = UUID()
        self.name = name
        self.stepCount = stepCount
        self.tracks = (0..<trackCount).map { _ in
            (0..<stepCount).map { _ in BeatStep() }
        }
    }

    /// Toggle a step on/off
    public mutating func toggle(track: Int, step: Int) {
        guard track < tracks.count, step < stepCount else { return }
        tracks[track][step].isActive.toggle()
    }

    /// Classic four-on-the-floor pattern
    public static func fourOnFloor(trackCount: Int = 16) -> BeatPattern {
        var pattern = BeatPattern(name: "Four on Floor", trackCount: trackCount)
        if trackCount > 0 {
            for step in stride(from: 0, to: 16, by: 4) { pattern.tracks[0][step].isActive = true }
        }
        if trackCount > 1 {
            pattern.tracks[1][4].isActive = true
            pattern.tracks[1][12].isActive = true
        }
        if trackCount > 2 {
            for step in stride(from: 0, to: 16, by: 2) { pattern.tracks[2][step].isActive = true }
        }
        return pattern
    }

    /// Classic breakbeat pattern
    public static func breakbeat(trackCount: Int = 16) -> BeatPattern {
        var pattern = BeatPattern(name: "Breakbeat", trackCount: trackCount)
        if trackCount > 0 {
            for s in [0, 6, 10] where s < 16 { pattern.tracks[0][s].isActive = true }
        }
        if trackCount > 1 {
            for s in [4, 12] where s < 16 { pattern.tracks[1][s].isActive = true }
        }
        if trackCount > 2 {
            for s in stride(from: 0, to: 16, by: 2) { pattern.tracks[2][s].isActive = true }
        }
        return pattern
    }

    /// Trap-style pattern with hihat rolls
    public static func trap(trackCount: Int = 16) -> BeatPattern {
        var pattern = BeatPattern(name: "Trap", trackCount: trackCount)
        if trackCount > 0 {
            for s in [0, 7, 10] where s < 16 { pattern.tracks[0][s].isActive = true }
        }
        if trackCount > 1 {
            for s in [4, 12] where s < 16 { pattern.tracks[1][s].isActive = true }
        }
        if trackCount > 2 {
            for s in 0..<16 {
                pattern.tracks[2][s].isActive = true
                pattern.tracks[2][s].velocity = (s % 2 == 0) ? 0.9 : 0.5
            }
        }
        return pattern
    }

    /// DnB roller pattern (170+ BPM)
    public static func dnbRoller(trackCount: Int = 16) -> BeatPattern {
        var pattern = BeatPattern(name: "DnB Roller", trackCount: trackCount)
        if trackCount > 0 {
            for s in [0, 10] where s < 16 { pattern.tracks[0][s].isActive = true }
        }
        if trackCount > 1 {
            for s in [4, 12] where s < 16 { pattern.tracks[1][s].isActive = true }
        }
        if trackCount > 2 {
            for s in 0..<16 { pattern.tracks[2][s].isActive = true }
        }
        return pattern
    }
}

// MARK: - HiHat Mode

public enum HiHatMode: String, CaseIterable, Sendable {
    case closed = "Closed"
    case open = "Open"
    case pedal = "Pedal"

    var decayTime: Float {
        switch self {
        case .closed: return 0.05    // 50ms — tight
        case .open:   return 0.4     // 400ms — sizzle
        case .pedal:  return 0.12    // 120ms — foot chick
        }
    }
}

// MARK: - Roll Division

public enum RollDivision: String, CaseIterable, Sendable {
    case eighth              = "1/8"
    case sixteenth           = "1/16"
    case thirtysecond        = "1/32"
    case sixtyfourth         = "1/64"
    case eighthTriplet       = "1/8T"
    case sixteenthTriplet    = "1/16T"
    case thirtysecondTriplet = "1/32T"

    /// Number of triggers per beat (quarter note)
    var stepsPerBeat: Float {
        switch self {
        case .eighth:              return 2.0
        case .sixteenth:           return 4.0
        case .thirtysecond:        return 8.0
        case .sixtyfourth:         return 16.0
        case .eighthTriplet:       return 3.0
        case .sixteenthTriplet:    return 6.0
        case .thirtysecondTriplet: return 12.0
        }
    }
}

// MARK: - Velocity Ramp

public enum VelocityRamp: String, CaseIterable, Sendable {
    case flat         = "Flat"
    case crescendo    = "Crescendo"
    case decrescendo  = "Decrescendo"
    case vShape       = "V-Shape"
    case random       = "Random"

    /// Returns velocity (0-1) for a normalized position (0-1) within the roll
    func velocity(at position: Float) -> Float {
        switch self {
        case .flat:         return 0.8
        case .crescendo:    return 0.3 + position * 0.7
        case .decrescendo:  return 1.0 - position * 0.7
        case .vShape:
            let mid = abs(position - 0.5) * 2.0
            return 0.3 + mid * 0.7
        case .random:       return Float.random(in: 0.4...1.0)
        }
    }
}

// MARK: - Pitch Ramp

public enum PitchRamp: String, CaseIterable, Sendable {
    case none       = "None"
    case rising     = "Rising"
    case falling    = "Falling"
    case riseAndFall = "Rise+Fall"

    /// Frequency multiplier at a normalized position (0-1) within the roll
    func multiplier(at position: Float) -> Float {
        switch self {
        case .none: return 1.0
        case .rising: return 0.8 + position * 0.7
        case .falling: return 1.5 - position * 0.7
        case .riseAndFall:
            if position < 0.5 {
                return 0.8 + position * 2.0 * 0.7
            } else {
                return 1.5 - (position - 0.5) * 2.0 * 0.7
            }
        }
    }
}

// MARK: - Dirty Delay Configuration

public struct DirtyDelayConfig: Codable, Sendable {
    public var delayTime: Float = 0.188     // seconds (≈ 3/16 note at 140 BPM)
    public var feedback: Float = 0.45       // 0 – 0.95
    public var saturation: Float = 0.3      // 0 – 1
    public var filterCutoff: Float = 4000   // Hz (LP on feedback path)
    public var mix: Float = 0.25            // dry/wet
    public var isEnabled: Bool = false

    public static let clean = DirtyDelayConfig(
        delayTime: 0.188, feedback: 0.35, saturation: 0.1,
        filterCutoff: 6000, mix: 0.2, isEnabled: true)

    public static let dirty = DirtyDelayConfig(
        delayTime: 0.214, feedback: 0.55, saturation: 0.6,
        filterCutoff: 3000, mix: 0.3, isEnabled: true)

    public static let heavy = DirtyDelayConfig(
        delayTime: 0.25, feedback: 0.7, saturation: 0.8,
        filterCutoff: 2000, mix: 0.4, isEnabled: true)
}

// MARK: - Trap Presets

public enum TrapPreset: String, CaseIterable, Sendable {
    case metroBoomin     = "Metro Boomin"
    case southside       = "Southside"
    case londonOnDaTrack = "London On Da Track"
    case piWon           = "Pi'erre Bourne"
    case wheezy          = "Wheezy"

    var bpm: Float {
        switch self {
        case .metroBoomin:     return 140
        case .southside:       return 138
        case .londonOnDaTrack: return 142
        case .piWon:           return 150
        case .wheezy:          return 136
        }
    }

    var rollDivision: RollDivision {
        switch self {
        case .metroBoomin:     return .sixteenth
        case .southside:       return .thirtysecond
        case .londonOnDaTrack: return .sixteenth
        case .piWon:           return .thirtysecond
        case .wheezy:          return .sixtyfourth
        }
    }

    var velocityRamp: VelocityRamp {
        switch self {
        case .metroBoomin:     return .crescendo
        case .southside:       return .flat
        case .londonOnDaTrack: return .crescendo
        case .piWon:           return .decrescendo
        case .wheezy:          return .crescendo
        }
    }

    var pitchRamp: PitchRamp {
        switch self {
        case .metroBoomin:     return .none
        case .southside:       return .none
        case .londonOnDaTrack: return .rising
        case .piWon:           return .falling
        case .wheezy:          return .rising
        }
    }

    var delay: DirtyDelayConfig {
        switch self {
        case .metroBoomin:     return .clean
        case .southside:       return .dirty
        case .londonOnDaTrack: return .clean
        case .piWon:           return DirtyDelayConfig(
            delayTime: 0.15, feedback: 0.3, saturation: 0.15,
            filterCutoff: 5000, mix: 0.2, isEnabled: true)
        case .wheezy:          return .heavy
        }
    }

    var swing: Float {
        switch self {
        case .metroBoomin:     return 0
        case .southside:       return 0
        case .londonOnDaTrack: return 15
        case .piWon:           return 5
        case .wheezy:          return 0
        }
    }

    var hihatDecayMultiplier: Float {
        switch self {
        case .metroBoomin:     return 0.8   // crisp
        case .southside:       return 1.2   // aggressive
        case .londonOnDaTrack: return 1.0   // balanced
        case .piWon:           return 0.7   // tight
        case .wheezy:          return 1.5   // washy
        }
    }
}

// MARK: - HiHat Voice (Real-Time DSP State)

/// Per-voice state for real-time 808 hihat synthesis.
/// Uses 6 square wave oscillators at non-harmonic frequencies (authentic TR-808 cymbal circuit).
private struct HiHatVoice {
    var isActive: Bool = true
    var mode: HiHatMode = .closed
    var velocity: Float = 0.8
    var pitchMultiplier: Float = 1.0

    // 6 oscillator phases (TR-808 non-harmonic ratios)
    var phases: (Float, Float, Float, Float, Float, Float) = (0, 0, 0, 0, 0, 0)

    // SVF bandpass state
    var bpS1: Float = 0
    var bpS2: Float = 0
    var bpCutoff: Float = 10000   // Bandpass center frequency
    var bpResonance: Float = 0.3

    // One-pole HPF state
    var hpZ1: Float = 0
    var hpCutoff: Float = 5000    // High-pass cutoff

    // Exponential decay envelope
    var envelope: Float = 1.0
    var decayRate: Float = 0.9998 // Per-sample decay coefficient

    /// Calculate decay rate from decay time in seconds
    static func decayCoefficient(for decayTime: Float, sampleRate: Float) -> Float {
        guard decayTime > 0 && sampleRate > 0 else { return 0.999 }
        // envelope = decayRate^(decayTime * sampleRate) = 0.001
        // decayRate = exp(ln(0.001) / (decayTime * sampleRate))
        return exp(-6.9078 / (decayTime * sampleRate))
    }
}

// MARK: - Drum Playback Voice

private struct DrumPlayback {
    var slotIndex: Int
    var position: Int = 0
    var velocity: Float = 1.0
    var isActive: Bool = true
}

// MARK: - Roll State

private struct RollState {
    var isActive: Bool = false
    var division: RollDivision = .sixteenth
    var velocityRamp: VelocityRamp = .flat
    var pitchRamp: PitchRamp = .none
    var triggerCount: Int = 0
    var maxTriggers: Int = 8
    var sampleCounter: Int = 0
    var samplesPerTrigger: Int = 0
}

// MARK: - Dirty Delay DSP

/// Interpolated circular-buffer delay line with saturation + LP feedback filter.
private struct DirtyDelay {
    private var buffer: [Float]
    private var writePos: Int = 0
    private var filterZ1: Float = 0

    init(maxDelaySamples: Int = 96000) {
        buffer = [Float](repeating: 0, count: maxDelaySamples)
    }

    mutating func process(_ input: Float, sampleRate: Float, config: DirtyDelayConfig) -> Float {
        let delaySamples = config.delayTime * sampleRate
        let readPosFloat = Float(writePos) - delaySamples
        let readPosInt = Int(readPosFloat)
        let frac = readPosFloat - Float(readPosInt)

        // Wrap indices for circular buffer
        let bufLen = buffer.count
        let idx0 = ((readPosInt % bufLen) + bufLen) % bufLen
        let idx1 = (((readPosInt + 1) % bufLen) + bufLen) % bufLen

        // Linear interpolation for fractional delay (click-free)
        let delayed = buffer[idx0] * (1.0 - frac) + buffer[idx1] * frac

        // Soft saturation on feedback path (tanh approximation)
        let driven = delayed * (1.0 + config.saturation * 3.0)
        let x2 = driven * driven
        let saturated = driven * (27.0 + x2) / (27.0 + 9.0 * x2)

        // One-pole LP filter on feedback
        let fc = Swift.min(config.filterCutoff, sampleRate * 0.49)
        let coeff = exp(-2.0 * Float.pi * fc / sampleRate)
        filterZ1 = saturated * (1.0 - coeff) + filterZ1 * coeff

        // Write input + filtered feedback into delay line
        let fb = Swift.min(config.feedback, 0.95)
        buffer[writePos] = input + filterZ1 * fb
        writePos = (writePos + 1) % bufLen

        // Dry/wet mix
        return input * (1.0 - config.mix) + delayed * config.mix
    }

    mutating func clear() {
        for i in buffer.indices { buffer[i] = 0 }
        filterZ1 = 0
        writePos = 0
    }
}

// MARK: - EchoelBeat Drum Machine

/// Professional drum machine with real-time 808 hihat synthesis, roll sequencer,
/// dirty delay, trap presets, and SynthPresetLibrary integration.
@MainActor
public final class EchoelBeat: ObservableObject {

    public static let shared = EchoelBeat()

    // ── Published State ──

    @Published public var drumSlots: [DrumSlot] = []
    @Published public var currentKit: String = "None"
    @Published public var bpm: Float = 140
    @Published public var swing: Float = 0
    @Published public var masterLevel: Float = 0.8
    @Published public var meterLevel: Float = 0.0

    // HiHat
    @Published public var hihatMode: HiHatMode = .closed
    @Published public var hihatDecayMultiplier: Float = 1.0
    @Published public var hihatTone: Float = 0.5          // 0 = dark, 1 = bright (controls BPF center)

    // Roll
    @Published public var rollDivision: RollDivision = .sixteenth
    @Published public var rollVelocityRamp: VelocityRamp = .crescendo
    @Published public var rollPitchRamp: PitchRamp = .none

    // Delay
    @Published public var delayConfig: DirtyDelayConfig = DirtyDelayConfig()

    // Sequencer
    @Published public var sequencerPattern: BeatPattern = BeatPattern(name: "Default")
    @Published public var sequencerStep: Int = 0
    @Published public var isSequencerPlaying: Bool = false

    // ── Audio Engine ──

    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private let sampleRate: Double = 48000.0
    private let voiceLock = NSLock()

    // ── DSP State (audio thread) ──

    private var drumPlaybacks: [DrumPlayback] = []
    private var hihatVoices: [HiHatVoice] = []
    private var rollState = RollState()
    private var dirtyDelay = DirtyDelay()
    private var currentTime: Double = 0.0

    // Sample-accurate sequencer state
    private var seqGlobalSamplePos: Int = 0
    private var seqLastStep: Int = -1
    private var isSeqRunning: Bool = false

    private let maxDrumPlaybacks = 32
    private let maxHiHatVoices = 8

    // ── TR-808 HiHat Oscillator Frequencies ──
    // Original Roland TR-808 cymbal circuit: 6 square waves at non-harmonic ratios
    private static let hihatOscFreqs: [Float] = [
        204.68, 298.00, 366.14, 517.16, 538.58, 612.00
    ]

    // MARK: - Initialization

    private init() {
        setupAudioEngine()
    }

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        guard let engine = audioEngine,
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else { return }

        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, abl -> OSStatus in
            guard let self = self else { return noErr }
            let ablPtr = UnsafeMutableAudioBufferListPointer(abl)
            guard let left = ablPtr[0].mData?.assumingMemoryBound(to: Float.self),
                  let right = ablPtr[1].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            self.renderAudio(left: left, right: right, frameCount: Int(frameCount))
            return noErr
        }

        guard let src = sourceNode else { return }
        engine.attach(src)
        engine.connect(src, to: engine.mainMixerNode, format: format)
        do { try engine.start() } catch { /* retry on first trigger */ }
    }

    private func ensureEngineRunning() {
        guard audioEngine?.isRunning != true else { return }
        do { try audioEngine?.start() } catch { }
    }

    // MARK: - Public API — Drum Pads

    /// Trigger a drum slot by index
    public func triggerDrum(slotIndex: Int, velocity: Float = 0.8) {
        guard slotIndex < drumSlots.count else { return }
        ensureEngineRunning()

        voiceLock.lock()
        defer { voiceLock.unlock() }

        drumPlaybacks.removeAll { !$0.isActive }
        if drumPlaybacks.count >= maxDrumPlaybacks { drumPlaybacks.removeFirst() }
        drumPlaybacks.append(DrumPlayback(slotIndex: slotIndex, velocity: velocity))
    }

    /// Trigger drum by MIDI note (GM drum map: C1 = 36)
    public func triggerDrumByNote(_ note: Int, velocity: Float = 0.8) {
        if let idx = drumSlots.firstIndex(where: { $0.midiNote == note }) {
            triggerDrum(slotIndex: idx, velocity: velocity)
        }
    }

    // MARK: - Public API — HiHat Synth

    /// Trigger a real-time synthesized 808 hihat
    public func triggerHiHat(mode: HiHatMode? = nil, velocity: Float = 0.8, pitchMultiplier: Float = 1.0) {
        ensureEngineRunning()
        let hatMode = mode ?? hihatMode
        let decayTime = hatMode.decayTime * hihatDecayMultiplier

        voiceLock.lock()
        defer { voiceLock.unlock() }

        // Closed hat chokes open hat (authentic 808 behavior)
        if hatMode == .closed || hatMode == .pedal {
            for i in hihatVoices.indices where hihatVoices[i].mode == .open {
                hihatVoices[i].isActive = false
            }
        }

        hihatVoices.removeAll { !$0.isActive }
        if hihatVoices.count >= maxHiHatVoices { hihatVoices.removeFirst() }

        var voice = HiHatVoice()
        voice.mode = hatMode
        voice.velocity = velocity
        voice.pitchMultiplier = pitchMultiplier
        voice.decayRate = HiHatVoice.decayCoefficient(for: decayTime, sampleRate: Float(sampleRate))

        // Tone control: shift bandpass center (5 kHz dark → 14 kHz bright)
        voice.bpCutoff = 5000 + hihatTone * 9000
        voice.hpCutoff = 3000 + hihatTone * 4000

        hihatVoices.append(voice)
    }

    // MARK: - Public API — Roll Engine

    /// Start a hihat roll with current settings
    public func startRoll(triggers: Int = 8) {
        ensureEngineRunning()

        voiceLock.lock()
        defer { voiceLock.unlock() }

        let beatsPerSecond = Double(bpm) / 60.0
        let triggersPerSecond = beatsPerSecond * Double(rollDivision.stepsPerBeat)
        let samplesPerTrigger = Int(sampleRate / triggersPerSecond)

        rollState = RollState(
            isActive: true,
            division: rollDivision,
            velocityRamp: rollVelocityRamp,
            pitchRamp: rollPitchRamp,
            maxTriggers: triggers,
            samplesPerTrigger: samplesPerTrigger
        )
    }

    /// Stop any active roll
    public func stopRoll() {
        voiceLock.lock()
        rollState.isActive = false
        voiceLock.unlock()
    }

    // MARK: - Public API — Sequencer

    public func startSequencer() {
        guard !isSequencerPlaying else { return }
        ensureEngineRunning()

        voiceLock.lock()
        seqGlobalSamplePos = 0
        seqLastStep = -1
        isSeqRunning = true
        voiceLock.unlock()

        isSequencerPlaying = true
    }

    public func stopSequencer() {
        voiceLock.lock()
        isSeqRunning = false
        voiceLock.unlock()

        isSequencerPlaying = false
        sequencerStep = 0
    }

    // MARK: - Public API — Kits & Presets

    /// Load a drum kit from SynthPresetLibrary by genre
    public func loadDrumKit(genre: SynthPresetLibrary.GenreKit) {
        let library = SynthPresetLibrary.shared
        let presetList = library.drumPresets(for: genre)
        let sr = Float(sampleRate)

        var newSlots: [DrumSlot] = []
        for (i, preset) in presetList.prefix(16).enumerated() {
            let audio = library.renderDrumHit(preset, targetSampleRate: sr)
            newSlots.append(DrumSlot(
                name: preset.name, audioData: audio, sampleRate: sr,
                midiNote: 36 + i, category: preset.tags.first ?? ""))
        }

        voiceLock.lock()
        drumPlaybacks.removeAll()
        voiceLock.unlock()

        drumSlots = newSlots
        currentKit = genre.rawValue
        sequencerPattern = BeatPattern(name: genre.rawValue, trackCount: drumSlots.count)
    }

    /// Apply a trap producer preset
    public func applyTrapPreset(_ preset: TrapPreset) {
        bpm = preset.bpm
        swing = preset.swing
        rollDivision = preset.rollDivision
        rollVelocityRamp = preset.velocityRamp
        rollPitchRamp = preset.pitchRamp
        delayConfig = preset.delay
        hihatDecayMultiplier = preset.hihatDecayMultiplier
    }

    // MARK: - Audio Rendering (Real-Time Thread)

    private func renderAudio(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frameCount: Int) {
        memset(left, 0, frameCount * MemoryLayout<Float>.size)
        memset(right, 0, frameCount * MemoryLayout<Float>.size)

        let level = masterLevel
        let dlyCfg = delayConfig
        let sr = Float(sampleRate)

        voiceLock.lock()

        // Snapshot drum slots (value-type COW)
        let slots = drumSlots

        var peak: Float = 0.0

        for frame in 0..<frameCount {
            var sample: Float = 0.0

            // ── 1. Sample-Accurate Sequencer ──
            if isSeqRunning {
                let beatDuration = sampleRate * 60.0 / Double(bpm)
                let stepDuration = beatDuration / 4.0 // 16th notes
                seqGlobalSamplePos += 1

                let rawStep = Int(Double(seqGlobalSamplePos) / stepDuration)
                let step = rawStep % Swift.max(1, sequencerPattern.stepCount)

                if step != seqLastStep {
                    seqLastStep = step
                    processSequencerStep(step, slots: slots)
                }
            }

            // ── 2. Roll Engine ──
            if rollState.isActive {
                rollState.sampleCounter += 1
                if rollState.sampleCounter >= rollState.samplesPerTrigger {
                    rollState.sampleCounter = 0

                    let position = Float(rollState.triggerCount) / Float(Swift.max(1, rollState.maxTriggers - 1))
                    let vel = rollState.velocityRamp.velocity(at: position)
                    let pitch = rollState.pitchRamp.multiplier(at: position)

                    // Fire hihat
                    var voice = HiHatVoice()
                    voice.mode = hihatMode
                    voice.velocity = vel
                    voice.pitchMultiplier = pitch
                    voice.decayRate = HiHatVoice.decayCoefficient(
                        for: hihatMode.decayTime * hihatDecayMultiplier, sampleRate: sr)
                    voice.bpCutoff = 5000 + hihatTone * 9000
                    voice.hpCutoff = 3000 + hihatTone * 4000

                    if hihatVoices.count < maxHiHatVoices {
                        hihatVoices.append(voice)
                    }

                    rollState.triggerCount += 1
                    if rollState.triggerCount >= rollState.maxTriggers {
                        rollState.isActive = false
                    }
                }
            }

            // ── 3. Mix Drum Slot Playbacks ──
            for dpIdx in drumPlaybacks.indices {
                guard drumPlaybacks[dpIdx].isActive else { continue }
                let si = drumPlaybacks[dpIdx].slotIndex
                guard si < slots.count else { drumPlaybacks[dpIdx].isActive = false; continue }
                let pos = drumPlaybacks[dpIdx].position
                if pos < slots[si].audioData.count {
                    sample += slots[si].audioData[pos] * drumPlaybacks[dpIdx].velocity
                    drumPlaybacks[dpIdx].position += 1
                } else {
                    drumPlaybacks[dpIdx].isActive = false
                }
            }

            // ── 4. Render HiHat Voices ──
            for hhIdx in hihatVoices.indices {
                guard hihatVoices[hhIdx].isActive else { continue }
                sample += renderHiHatSample(&hihatVoices[hhIdx], sampleRate: sr)
            }

            // ── 5. Dirty Delay ──
            if dlyCfg.isEnabled {
                sample = dirtyDelay.process(sample, sampleRate: sr, config: dlyCfg)
            }

            // ── 6. Output ──
            sample *= level
            peak = Swift.max(peak, abs(sample))
            left[frame] = sample
            right[frame] = sample
        }

        // Cleanup finished voices
        drumPlaybacks.removeAll { !$0.isActive }
        hihatVoices.removeAll { !$0.isActive }

        voiceLock.unlock()

        currentTime += Double(frameCount) / sampleRate

        // Throttled meter + step UI update
        Task { @MainActor in
            self.meterLevel = peak
            if self.isSeqRunning {
                self.sequencerStep = self.seqLastStep
            }
        }
    }

    // MARK: - HiHat DSP (per-sample)

    /// Render one sample of 808 hihat: 6 square osc → SVF BPF → HPF → VCA
    private func renderHiHatSample(_ voice: inout HiHatVoice, sampleRate sr: Float) -> Float {
        // ── Square Wave Oscillator Bank (TR-808 metallic noise) ──
        var metallic: Float = 0.0
        let freqs = Self.hihatOscFreqs
        let pm = voice.pitchMultiplier

        // Unrolled for performance (6 oscillators)
        func advanceOsc(_ phase: inout Float, freq: Float) -> Float {
            let inc = freq * pm / sr
            phase += inc
            if phase >= 1.0 { phase -= 1.0 }
            return phase < 0.5 ? 1.0 : -1.0
        }

        metallic += advanceOsc(&voice.phases.0, freq: freqs[0])
        metallic += advanceOsc(&voice.phases.1, freq: freqs[1])
        metallic += advanceOsc(&voice.phases.2, freq: freqs[2])
        metallic += advanceOsc(&voice.phases.3, freq: freqs[3])
        metallic += advanceOsc(&voice.phases.4, freq: freqs[4])
        metallic += advanceOsc(&voice.phases.5, freq: freqs[5])
        metallic *= (1.0 / 6.0)

        // ── SVF Bandpass Filter ──
        let bpG = tan(.pi * Swift.min(voice.bpCutoff, sr * 0.49) / sr)
        let bpK = 2.0 - 2.0 * voice.bpResonance
        let hp = (metallic - (bpK + bpG) * voice.bpS1 - voice.bpS2) / (1.0 + bpK * bpG + bpG * bpG)
        let bp = bpG * hp + voice.bpS1
        let lp = bpG * bp + voice.bpS2
        voice.bpS1 = bpG * hp + bp
        voice.bpS2 = bpG * bp + lp

        var filtered = bp  // bandpass output

        // ── One-Pole HPF ──
        let hpCoeff = exp(-2.0 * Float.pi * voice.hpCutoff / sr)
        let hpIn = filtered
        filtered = hpIn - voice.hpZ1
        voice.hpZ1 = hpIn * (1.0 - hpCoeff) + voice.hpZ1 * hpCoeff

        // ── Exponential Decay VCA ──
        voice.envelope *= voice.decayRate
        if voice.envelope < 0.001 {
            voice.isActive = false
            return 0
        }

        return filtered * voice.envelope * voice.velocity
    }

    // MARK: - Sequencer Step Processing (audio thread)

    private func processSequencerStep(_ step: Int, slots: [DrumSlot]) {
        for (trackIdx, track) in sequencerPattern.tracks.enumerated() {
            guard step < track.count else { continue }
            let beatStep = track[step]
            guard beatStep.isActive else { continue }
            guard Float.random(in: 0...1) <= beatStep.probability else { continue }

            // Trigger the appropriate sound
            if trackIdx < slots.count {
                drumPlaybacks.removeAll { !$0.isActive }
                if drumPlaybacks.count < maxDrumPlaybacks {
                    drumPlaybacks.append(DrumPlayback(
                        slotIndex: trackIdx, velocity: beatStep.velocity))
                }
            }
        }
    }

    // MARK: - MIDI

    public func handleMIDINoteOn(channel: UInt8, note: UInt8, velocity: UInt8) {
        let vel = Float(velocity) / 127.0
        let n = Int(note)

        if let idx = drumSlots.firstIndex(where: { $0.midiNote == n }) {
            triggerDrum(slotIndex: idx, velocity: vel)
        } else if n >= 42 && n <= 46 {
            // GM hihat range: 42=closed, 44=pedal, 46=open
            let mode: HiHatMode = n == 42 ? .closed : (n == 44 ? .pedal : .open)
            triggerHiHat(mode: mode, velocity: vel)
        }
    }

    // MARK: - Bio-Reactive

    public func updateBioParameters(coherence: Float, energy: Float) {
        // High coherence → tighter, more structured patterns
        // Low coherence → looser, more random
        hihatDecayMultiplier = 0.7 + (1.0 - coherence) * 0.8
        delayConfig.feedback = 0.2 + (1.0 - coherence) * 0.4
    }
}

// MARK: - EchoelBeatView

#if canImport(SwiftUI)
public struct EchoelBeatView: View {
    @ObservedObject private var beat = EchoelBeat.shared

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                kitSelector
                drumPads
                hihatSection
                rollSection
                delaySection
                trapPresets
                sequencerGrid
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
    }

    // ── Header ──

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("EchoelBeat")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Drum Machine + HiHat Synth")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            Spacer()

            // BPM
            VStack {
                Text(String(format: "%.0f BPM", beat.bpm))
                    .font(.caption.monospacedDigit().bold())
                    .foregroundColor(.cyan)
                Slider(value: $beat.bpm, in: 60...200, step: 1)
                    .frame(width: 100)
                    .tint(.cyan)
            }

            // Transport
            Button(action: {
                beat.isSequencerPlaying ? beat.stopSequencer() : beat.startSequencer()
            }) {
                Image(systemName: beat.isSequencerPlaying ? "stop.fill" : "play.fill")
                    .font(.title3)
                    .foregroundColor(beat.isSequencerPlaying ? .red : .green)
            }
            .buttonStyle(.plain)
        }
    }

    // ── Kit Selector ──

    private var kitSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SynthPresetLibrary.GenreKit.allCases, id: \.rawValue) { genre in
                    Button(genre.rawValue) { beat.loadDrumKit(genre: genre) }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(
                            beat.currentKit == genre.rawValue ? Color.cyan : Color.gray.opacity(0.3)))
                        .foregroundColor(beat.currentKit == genre.rawValue ? .black : .white)
                        .buttonStyle(.plain)
                }
            }
        }
    }

    // ── Drum Pads (4x4) ──

    private var drumPads: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)
        return LazyVGrid(columns: cols, spacing: 4) {
            ForEach(Array(beat.drumSlots.prefix(16).enumerated()), id: \.element.id) { idx, slot in
                Button(action: { beat.triggerDrum(slotIndex: idx) }) {
                    Text(String(slot.name.prefix(7)))
                        .font(.system(size: 10, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: 8)
                            .fill(padColor(slot.category)))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // ── HiHat Section ──

    private var hihatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HiHat Synth (808)")
                .font(.caption.bold())
                .foregroundColor(.cyan)
            HStack(spacing: 12) {
                ForEach(HiHatMode.allCases, id: \.rawValue) { mode in
                    Button(action: { beat.triggerHiHat(mode: mode) }) {
                        Text(mode.rawValue)
                            .font(.caption2.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 8)
                                .fill(Color.cyan.opacity(mode == beat.hihatMode ? 0.8 : 0.3)))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tone").font(.system(size: 9)).foregroundColor(.gray)
                    Slider(value: $beat.hihatTone, in: 0...1).frame(width: 80).tint(.cyan)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
    }

    // ── Roll Section ──

    private var rollSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Roll Engine")
                    .font(.caption.bold())
                    .foregroundColor(.orange)
                Spacer()
                Button("ROLL") { beat.startRoll(triggers: 8) }
                    .font(.caption2.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.orange))
                    .foregroundColor(.black)
                    .buttonStyle(.plain)
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Division").font(.system(size: 9)).foregroundColor(.gray)
                    Picker("", selection: $beat.rollDivision) {
                        ForEach(RollDivision.allCases, id: \.rawValue) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.menu).tint(.orange)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Velocity").font(.system(size: 9)).foregroundColor(.gray)
                    Picker("", selection: $beat.rollVelocityRamp) {
                        ForEach(VelocityRamp.allCases, id: \.rawValue) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.menu).tint(.orange)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Pitch").font(.system(size: 9)).foregroundColor(.gray)
                    Picker("", selection: $beat.rollPitchRamp) {
                        ForEach(PitchRamp.allCases, id: \.rawValue) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.menu).tint(.orange)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
    }

    // ── Delay Section ──

    private var delaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Dirty Delay")
                    .font(.caption.bold())
                    .foregroundColor(.purple)
                Spacer()
                Toggle("", isOn: $beat.delayConfig.isEnabled).labelsHidden().tint(.purple)
            }
            if beat.delayConfig.isEnabled {
                HStack(spacing: 12) {
                    paramSlider("Time", value: $beat.delayConfig.delayTime, range: 0.05...0.5, color: .purple)
                    paramSlider("FB", value: $beat.delayConfig.feedback, range: 0...0.95, color: .purple)
                    paramSlider("Sat", value: $beat.delayConfig.saturation, range: 0...1, color: .purple)
                    paramSlider("Mix", value: $beat.delayConfig.mix, range: 0...0.8, color: .purple)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
    }

    // ── Trap Presets ──

    private var trapPresets: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trap Presets")
                .font(.caption.bold())
                .foregroundColor(.yellow)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TrapPreset.allCases, id: \.rawValue) { preset in
                        Button(preset.rawValue) { beat.applyTrapPreset(preset) }
                            .font(.caption2)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color.yellow.opacity(0.3)))
                            .foregroundColor(.yellow)
                            .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
    }

    // ── Step Sequencer Grid ──

    private var sequencerGrid: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Step Sequencer")
                .font(.caption.bold())
                .foregroundColor(.white)

            if !beat.drumSlots.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    VStack(spacing: 2) {
                        // Step numbers
                        HStack(spacing: 2) {
                            Text("").frame(width: 56)
                            ForEach(0..<16, id: \.self) { s in
                                Text("\(s+1)")
                                    .font(.system(size: 7).monospacedDigit())
                                    .frame(width: 22, height: 12)
                                    .foregroundColor(beat.sequencerStep == s && beat.isSequencerPlaying
                                                     ? .cyan : .gray)
                            }
                        }
                        // Tracks
                        ForEach(Array(beat.drumSlots.prefix(8).enumerated()), id: \.element.id) { ti, slot in
                            HStack(spacing: 2) {
                                Text(String(slot.name.prefix(7)))
                                    .font(.system(size: 8, weight: .medium))
                                    .frame(width: 56, alignment: .trailing)
                                    .foregroundColor(.gray)
                                    .lineLimit(1)

                                ForEach(0..<16, id: \.self) { si in
                                    let active = ti < beat.sequencerPattern.tracks.count
                                        && si < beat.sequencerPattern.stepCount
                                        && beat.sequencerPattern.tracks[ti][si].isActive

                                    Button { beat.sequencerPattern.toggle(track: ti, step: si) } label: {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(active ? padColor(slot.category) : Color.gray.opacity(0.15))
                                            .frame(width: 22, height: 22)
                                            .overlay(Group {
                                                if beat.sequencerStep == si && beat.isSequencerPlaying {
                                                    RoundedRectangle(cornerRadius: 2).stroke(Color.white, lineWidth: 1)
                                                }
                                            })
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
    }

    // ── Helpers ──

    private func paramSlider(_ label: String, value: Binding<Float>, range: ClosedRange<Float>, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.system(size: 9)).foregroundColor(.gray)
            Slider(value: value, in: range).frame(width: 60).tint(color)
        }
    }

    private func padColor(_ cat: String) -> Color {
        switch cat {
        case "kick": return .red.opacity(0.7)
        case "snare", "clap": return .orange.opacity(0.7)
        case "hihat", "closed", "open", "ride", "crash", "pedal": return .cyan.opacity(0.7)
        case "tom", "floor", "mid", "high": return .blue.opacity(0.7)
        default: return .purple.opacity(0.7)
        }
    }
}
#endif

// MARK: - Preview

#if DEBUG && canImport(SwiftUI)
struct EchoelBeatView_Previews: PreviewProvider {
    static var previews: some View {
        EchoelBeatView()
    }
}
#endif
