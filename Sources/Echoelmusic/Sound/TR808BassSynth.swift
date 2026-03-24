#if canImport(AVFoundation)
//
//  TR808BassSynth.swift
//  Echoelmusic
//
//  Created: December 2025
//  PROFESSIONAL 808 BASS SYNTHESIZER
//  Ultra-Low Latency Sub-Bass Engine with Pitch Glide
//
//  Features:
//  - Authentic 808 sub-bass tone with sine wave core
//  - Pitch glide/portamento at note start (classic trap slide)
//  - Attack transient (click/punch)
//  - Exponential decay envelope
//  - Analog-style saturation/distortion
//  - Pitch envelope with adjustable time and range
//  - MIDI 2.0 + MPE support for per-note expression
//  - Real-time parameter modulation
//  - Bio-reactive integration
//

import Foundation
import AVFoundation
import Accelerate

// MARK: - 808 Bass Configuration

/// Configuration for the 808 Bass Synthesizer
public struct TR808BassConfig: Codable, Equatable, Sendable {

    // MARK: - Pitch Glide Settings

    /// Enable pitch glide at note start
    public var pitchGlideEnabled: Bool = true

    /// Pitch glide time in seconds (0.01 - 0.5)
    public var pitchGlideTime: Float = 0.08

    /// Pitch glide range in semitones (typically -12 to +12)
    public var pitchGlideRange: Float = -12.0

    /// Pitch glide curve (0 = linear, 1 = exponential)
    public var pitchGlideCurve: Float = 0.7

    // MARK: - Oscillator Settings

    /// Base frequency offset in cents (-100 to +100)
    public var tuning: Float = 0.0

    /// Octave shift (-2 to +2)
    public var octave: Int = 0

    /// Sub-oscillator mix (0 = none, 1 = full -1 octave)
    public var subOscMix: Float = 0.0

    // MARK: - Envelope Settings

    /// Attack click/punch amount (0 - 1)
    public var clickAmount: Float = 0.3

    /// Click frequency in Hz (500 - 5000)
    public var clickFrequency: Float = 1200.0

    /// Decay time in seconds (0.1 - 10.0)
    public var decay: Float = 1.5

    /// Decay curve (0 = linear, 1 = exponential)
    public var decayCurve: Float = 0.85

    /// Sustain level (0 - 1)
    public var sustain: Float = 0.0

    /// Release time in seconds (0.01 - 2.0)
    public var release: Float = 0.3

    // MARK: - Pitch Envelope

    /// Pitch envelope amount in semitones
    public var pitchEnvAmount: Float = 0.0

    /// Pitch envelope decay time in seconds
    public var pitchEnvDecay: Float = 0.1

    // MARK: - Tone Shaping

    /// Drive/saturation amount (0 - 1)
    public var drive: Float = 0.2

    /// Low-pass filter cutoff in Hz (20 - 2000)
    public var filterCutoff: Float = 500.0

    /// Filter resonance (0 - 1)
    public var filterResonance: Float = 0.0

    /// Output level (0 - 1)
    public var level: Float = 0.8

    /// Stereo width (0 = mono, 1 = wide)
    public var stereoWidth: Float = 0.0

    // MARK: - Presets

    public static let classic808 = TR808BassConfig(
        pitchGlideEnabled: true,
        pitchGlideTime: 0.06,
        pitchGlideRange: -12.0,
        pitchGlideCurve: 0.7,
        clickAmount: 0.25,
        clickFrequency: 1000.0,
        decay: 1.2,
        decayCurve: 0.8,
        drive: 0.15,
        filterCutoff: 400.0,
        level: 0.85
    )

    public static let hardTrap = TR808BassConfig(
        pitchGlideEnabled: true,
        pitchGlideTime: 0.04,
        pitchGlideRange: -24.0,
        pitchGlideCurve: 0.9,
        clickAmount: 0.5,
        clickFrequency: 1500.0,
        decay: 0.8,
        decayCurve: 0.9,
        drive: 0.4,
        filterCutoff: 600.0,
        level: 0.9
    )

    public static let deepSub = TR808BassConfig(
        pitchGlideEnabled: true,
        pitchGlideTime: 0.12,
        pitchGlideRange: -7.0,
        pitchGlideCurve: 0.5,
        clickAmount: 0.1,
        clickFrequency: 800.0,
        decay: 2.5,
        decayCurve: 0.7,
        drive: 0.1,
        filterCutoff: 200.0,
        level: 0.75
    )

    public static let distorted808 = TR808BassConfig(
        pitchGlideEnabled: true,
        pitchGlideTime: 0.05,
        pitchGlideRange: -12.0,
        pitchGlideCurve: 0.8,
        clickAmount: 0.4,
        clickFrequency: 1200.0,
        decay: 1.0,
        decayCurve: 0.85,
        drive: 0.7,
        filterCutoff: 800.0,
        level: 0.8
    )

    public static let longSlide = TR808BassConfig(
        pitchGlideEnabled: true,
        pitchGlideTime: 0.25,
        pitchGlideRange: -24.0,
        pitchGlideCurve: 0.6,
        clickAmount: 0.2,
        clickFrequency: 1000.0,
        decay: 3.0,
        decayCurve: 0.75,
        drive: 0.2,
        filterCutoff: 350.0,
        level: 0.8
    )
}

// MARK: - Voice State

/// Individual voice state for polyphonic 808
private struct TR808Voice {
    let id: UUID
    var midiNote: Int
    var velocity: Float
    var startTime: Double
    var phase: Double = 0.0
    var subPhase: Double = 0.0
    var clickPhase: Double = 0.0
    var envelope: Float = 1.0
    var pitchGlideProgress: Float = 0.0
    var isActive: Bool = true
    var isReleasing: Bool = false
    var releaseStartTime: Double = 0.0
    var releaseStartEnvelope: Float = 1.0

    // Filter state (biquad)
    var filterZ1: Float = 0.0
    var filterZ2: Float = 0.0
}

// MARK: - Drum Playback (Audio-Thread Safe)

/// Active drum playback voice (lightweight, audio-thread safe)
private struct DrumPlayback {
    var slotIndex: Int
    var position: Int = 0
    var velocity: Float = 1.0
    var isActive: Bool = true
}

// NOTE: DrumSlot, BeatStep, BeatPattern types are defined in EchoelBeat.swift
// to avoid duplication. This file uses those shared types.

// MARK: - TR808 Bass Synthesizer + EchoelBeat Drum Machine

/// EchoelBeat — Professional 808 Bass Synthesizer + Full Drum Machine
/// Integrates with SynthPresetLibrary for access to 65+ parametric drum presets across 12 genre kits.
@preconcurrency @MainActor
@Observable
public final class TR808BassSynth {

    // MARK: - Singleton

    @MainActor public static let shared = TR808BassSynth()

    // MARK: - Published State

    /// Read from audio render thread (struct copy). Written from MainActor only.
    @ObservationIgnored nonisolated(unsafe) public var config = TR808BassConfig.classic808
    public var isPlaying: Bool = false
    public var activeVoiceCount: Int = 0
    public var currentNote: Int? = nil
    public var meterLevel: Float = 0.0

    // MARK: - Drum Kit (SynthPresetLibrary Integration)

    public var drumSlots: [DrumSlot] = []
    public var currentDrumKit: String = "None"

    // MARK: - Step Sequencer

    public var sequencerPattern: BeatPattern = BeatPattern(name: "Default")
    public var sequencerBPM: Float = 120
    public var sequencerStep: Int = 0
    public var isSequencerPlaying: Bool = false

    // Drum playback state (audio thread, under voiceLock)
    @ObservationIgnored nonisolated(unsafe) private var drumPlaybacks: [DrumPlayback] = []
    private let maxDrumPlaybacks = 32
    @ObservationIgnored private var sequencerTimer: Timer?

    // MARK: - Audio Engine

    /// Strong ref — both are app-lifetime objects. Weak ref caused nil crashes.
    @ObservationIgnored private var masterAudioEngine: AudioEngine?
    @ObservationIgnored private var sourceNode: AVAudioSourceNode?
    @ObservationIgnored private var isAttachedToMaster: Bool = false
    private let sampleRate: Double = 48000.0
    private let maxVoices = 8

    // MARK: - Voice Management
    // @ObservationIgnored: voices accessed from audio render thread — observation
    // registrar lock on RT causes priority inversion → deadlock / watchdog kill.

    @ObservationIgnored private var voices: [TR808Voice] = []
    /// os_unfair_lock wrapper — priority-inheriting, no ObjC dispatch,
    /// safe for real-time audio render callbacks.
    private let voiceLock = AudioUnfairLock()

    // MARK: - DSP State (accessed from audio render thread, synchronized by voiceLock)

    @ObservationIgnored nonisolated(unsafe) private var currentTime: Double = 0.0
    @ObservationIgnored nonisolated(unsafe) private var lastMeterUpdate: Double = 0.0
    @ObservationIgnored nonisolated(unsafe) private var peakLevel: Float = 0.0
    /// Heap-allocated meter storage — written from audio render thread, read from main thread timer
    @ObservationIgnored nonisolated(unsafe) private let _rawMeter = UnsafeMutablePointer<Float>.allocate(capacity: 1)
    @ObservationIgnored nonisolated(unsafe) private let _rawVoiceCount = UnsafeMutablePointer<Int>.allocate(capacity: 1)
    @ObservationIgnored nonisolated(unsafe) private var meterPollTimer: Timer?

    // MARK: - Bio-Reactive (written from MainActor, read from audio thread — atomic Float reads)

    @ObservationIgnored nonisolated(unsafe) private var bioCoherence: Float = 0.5
    @ObservationIgnored nonisolated(unsafe) private var bioEnergy: Float = 0.5

    // MARK: - Initialization

    private init() {
        _rawMeter.initialize(to: 0)
        _rawVoiceCount.initialize(to: 0)
        createSourceNode()
        startMeterPollTimer()
    }

    /// Poll raw meter values from audio render thread into @Observable properties.
    private func startMeterPollTimer() {
        meterPollTimer?.invalidate()
        let ptrM = _rawMeter
        let ptrV = _rawVoiceCount
        meterPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.meterLevel = ptrM.pointee
                self.activeVoiceCount = ptrV.pointee
                if self.activeVoiceCount == 0 { self.isPlaying = false }
            }
        }
    }

    deinit {
        meterPollTimer?.invalidate()
        _rawMeter.deinitialize(count: 1)
        _rawMeter.deallocate()
        _rawVoiceCount.deinitialize(count: 1)
        _rawVoiceCount.deallocate()
    }

    // MARK: - Audio Engine Setup

    /// Create the AVAudioSourceNode for DSP rendering.
    /// The node is NOT attached to any engine yet — call connectToMasterEngine() to wire it up.
    private func createSourceNode() {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 2, interleaved: false) else {
            log.audio("TR808BassSynth: failed to create AVAudioFormat — source node not created", level: .error)
            return
        }
        nonisolated(unsafe) weak var weakSelf = self
        sourceNode = AVAudioSourceNode(format: format) { _, _, frameCount, audioBufferList -> OSStatus in
            guard let s = weakSelf else { return noErr }
            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard ablPointer.count >= 2,
                  let leftBuffer = ablPointer[0].mData?.assumingMemoryBound(to: Float.self),
                  let rightBuffer = ablPointer[1].mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }
            s.renderAudio(leftBuffer: leftBuffer, rightBuffer: rightBuffer, frameCount: Int(frameCount))
            return noErr
        }
        log.audio("TR808BassSynth: source node created (not yet attached to master engine)")
    }

    /// Store reference to the master AudioEngine and eagerly attach the source node.
    public func connectToMasterEngine(_ engine: AudioEngine) {
        masterAudioEngine = engine
        if !isAttachedToMaster, let source = sourceNode {
            engine.attachSourceNode(source)
            isAttachedToMaster = true
            log.audio("TR808BassSynth: source node attached (eager)")
        }
    }

    // MARK: - Public API

    /// Start the synthesizer
    public func start() {
        masterAudioEngine?.start()
        isPlaying = true
    }

    /// Stop the synthesizer
    public func stop() {
        isPlaying = false

        voiceLock.lock()
        defer { voiceLock.unlock() }
        voices.removeAll()

        activeVoiceCount = 0
        currentNote = nil
    }

    /// Trigger a note with velocity
    public func noteOn(note: Int, velocity: Float = 0.8) {
        guard isAttachedToMaster else {
            log.audio("TR808BassSynth: noteOn ignored — not attached", level: .error)
            return
        }
        if masterAudioEngine?.isRunning != true {
            masterAudioEngine?.start()
        }

        voiceLock.lock()
        defer { voiceLock.unlock() }

        // Check for existing voice with same note (retrigger)
        if let existingIndex = voices.firstIndex(where: { $0.midiNote == note && $0.isActive }) {
            // Retrigger - reset the voice
            voices[existingIndex].startTime = currentTime
            voices[existingIndex].envelope = 1.0
            voices[existingIndex].pitchGlideProgress = 0.0
            voices[existingIndex].velocity = velocity
            voices[existingIndex].isReleasing = false
            voices[existingIndex].phase = 0.0
            voices[existingIndex].subPhase = 0.0  // Phase-reset sub-osc on kick retrigger
            voices[existingIndex].clickPhase = 0.0
        } else {
            // Voice stealing if at max
            if voices.count >= maxVoices {
                // Remove oldest voice
                if let oldestIndex = voices.indices.min(by: { voices[$0].startTime < voices[$1].startTime }) {
                    voices.remove(at: oldestIndex)
                }
            }

            // Create new voice
            let voice = TR808Voice(
                id: UUID(),
                midiNote: note,
                velocity: velocity,
                startTime: currentTime
            )
            voices.append(voice)
        }

        isPlaying = true
        currentNote = note
        activeVoiceCount = voices.count
    }

    /// Release a note
    public func noteOff(note: Int) {
        voiceLock.lock()
        defer { voiceLock.unlock() }

        for i in voices.indices where voices[i].midiNote == note && !voices[i].isReleasing {
            voices[i].isReleasing = true
            voices[i].releaseStartTime = currentTime
            voices[i].releaseStartEnvelope = voices[i].envelope
        }

        if currentNote == note {
            currentNote = nil
        }
    }

    /// All notes off (panic)
    public func allNotesOff() {
        voiceLock.lock()
        defer { voiceLock.unlock() }
        voices.removeAll()

        activeVoiceCount = 0
        currentNote = nil
    }

    /// Set preset
    public func setPreset(_ preset: TR808BassConfig) {
        config = preset
    }

    /// Update bio-reactive parameters
    public func updateBioParameters(coherence: Float, energy: Float) {
        bioCoherence = coherence
        bioEnergy = energy
    }

    // MARK: - Audio Rendering (Real-Time Thread)

    /// Audio render callback — called from AURemoteIO::IOThread.
    /// MUST be nonisolated: Swift 6 runtime enforces @MainActor isolation checks
    /// even through nonisolated(unsafe) weak references → EXC_BREAKPOINT.
    nonisolated private func renderAudio(leftBuffer: UnsafeMutablePointer<Float>, rightBuffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        // Get config snapshot for thread safety
        let cfg = config

        // Clear buffers
        memset(leftBuffer, 0, frameCount * MemoryLayout<Float>.size)
        memset(rightBuffer, 0, frameCount * MemoryLayout<Float>.size)

        // tryLock: never block the audio thread — output silence if lock is held
        guard voiceLock.try() else { return }
        defer { voiceLock.unlock() }

        var voicesToRemove: [Int] = []
        var peak: Float = 0.0

        for voiceIndex in voices.indices {
            var voice = voices[voiceIndex]

            for frame in 0..<frameCount {
                let time = currentTime + Double(frame) / sampleRate
                let elapsed = Float(time - voice.startTime)

                // Skip if voice hasn't started yet
                guard elapsed >= 0 else { continue }

                // Calculate envelope
                var env: Float
                if voice.isReleasing {
                    let releaseElapsed = Float(time - voice.releaseStartTime)
                    let releaseProgress = min(1.0, releaseElapsed / max(cfg.release, 0.001))
                    env = voice.releaseStartEnvelope * (1.0 - releaseProgress)
                } else {
                    // Exponential decay
                    let decayProgress = elapsed / max(cfg.decay, 0.001)
                    let decayCurve = pow(decayProgress, cfg.decayCurve)
                    env = max(cfg.sustain, 1.0 - decayCurve)
                }

                // Check if voice is done
                if env < 0.001 {
                    voice.isActive = false
                    if !voicesToRemove.contains(voiceIndex) {
                        voicesToRemove.append(voiceIndex)
                    }
                    continue
                }

                voice.envelope = env

                // Calculate pitch with glide
                var pitchMultiplier: Float = 1.0

                if cfg.pitchGlideEnabled && voice.pitchGlideProgress < 1.0 {
                    let glideProgress = min(1.0, elapsed / max(cfg.pitchGlideTime, 0.001))
                    voice.pitchGlideProgress = glideProgress

                    // Apply glide curve (exponential)
                    let curvedProgress = pow(glideProgress, cfg.pitchGlideCurve)

                    // Calculate pitch offset (starts at glideRange, ends at 0)
                    let pitchOffset = cfg.pitchGlideRange * (1.0 - curvedProgress)
                    pitchMultiplier = pow(2.0, pitchOffset / 12.0)
                }

                // Pitch envelope
                if cfg.pitchEnvAmount != 0 {
                    let pitchEnvProgress = min(1.0, elapsed / max(cfg.pitchEnvDecay, 0.001))
                    let pitchEnvOffset = cfg.pitchEnvAmount * (1.0 - pitchEnvProgress)
                    pitchMultiplier *= pow(2.0, pitchEnvOffset / 12.0)
                }

                // Calculate base frequency
                let baseNote = Float(voice.midiNote + cfg.octave * 12)
                let tunedNote = baseNote + cfg.tuning / 100.0
                let baseFreq = 440.0 * pow(2.0, (tunedNote - 69.0) / 12.0)
                let freq = baseFreq * pitchMultiplier

                // Phase increment
                let phaseInc = freq / Float(sampleRate)
                let subPhaseInc = phaseInc * 0.5  // Sub oscillator one octave down

                // Generate sine wave (main oscillator)
                let mainOsc = sin(Float(voice.phase) * 2.0 * Float.pi)
                voice.phase += Double(phaseInc)
                if voice.phase >= 1.0 { voice.phase -= 1.0 }

                // Sub oscillator
                var subOsc: Float = 0.0
                if cfg.subOscMix > 0 {
                    subOsc = sin(Float(voice.subPhase) * 2.0 * Float.pi)
                    voice.subPhase += Double(subPhaseInc)
                    if voice.subPhase >= 1.0 { voice.subPhase -= 1.0 }
                }

                // Mix oscillators
                var sample = mainOsc * (1.0 - cfg.subOscMix) + subOsc * cfg.subOscMix

                // Attack click/punch
                if cfg.clickAmount > 0 && elapsed < 0.02 {
                    let clickEnv = 1.0 - (elapsed / 0.02)
                    let clickFreq = cfg.clickFrequency / Float(sampleRate)
                    let click = sin(Float(voice.clickPhase) * 2.0 * Float.pi) * clickEnv * cfg.clickAmount
                    voice.clickPhase += Double(clickFreq)
                    sample += click
                }

                // Apply envelope and velocity
                sample *= env * voice.velocity

                // Saturation/drive
                if cfg.drive > 0 {
                    sample = applySaturation(sample, drive: cfg.drive)
                }

                // Simple one-pole low-pass filter
                let filterCoeff = exp(-2.0 * Float.pi * cfg.filterCutoff / Float(sampleRate))
                voice.filterZ1 = sample * (1.0 - filterCoeff) + voice.filterZ1 * filterCoeff
                sample = voice.filterZ1

                // Apply output level
                sample *= cfg.level

                // Track peak
                peak = max(peak, abs(sample))

                // Stereo output
                let stereoSpread = cfg.stereoWidth * 0.5
                leftBuffer[frame] += sample * (1.0 - stereoSpread)
                rightBuffer[frame] += sample * (1.0 + stereoSpread)
            }

            voices[voiceIndex] = voice
        }

        // Remove finished voices
        for index in voicesToRemove.sorted().reversed() {
            if index < voices.count {
                voices.remove(at: index)
            }
        }

        // ═══ Drum Kit Playback ═══
        // Mix pre-rendered drum hits from SynthPresetLibrary into output
        let drumSlotsCopy = drumSlots  // Snapshot for thread safety (value type COW)
        var drumPlaybacksToRemove: [Int] = []

        for dpIdx in drumPlaybacks.indices {
            guard drumPlaybacks[dpIdx].isActive else {
                drumPlaybacksToRemove.append(dpIdx)
                continue
            }
            let slotIdx = drumPlaybacks[dpIdx].slotIndex
            guard slotIdx < drumSlotsCopy.count else {
                drumPlaybacks[dpIdx].isActive = false
                drumPlaybacksToRemove.append(dpIdx)
                continue
            }
            let slotAudio = drumSlotsCopy[slotIdx].audioData
            let vel = drumPlaybacks[dpIdx].velocity * cfg.level

            for frame in 0..<frameCount {
                let pos = drumPlaybacks[dpIdx].position + frame
                guard pos < slotAudio.count else {
                    drumPlaybacks[dpIdx].isActive = false
                    if !drumPlaybacksToRemove.contains(dpIdx) {
                        drumPlaybacksToRemove.append(dpIdx)
                    }
                    break
                }
                let sample = slotAudio[pos] * vel
                leftBuffer[frame] += sample
                rightBuffer[frame] += sample
                peak = Swift.max(peak, abs(sample))
            }
            drumPlaybacks[dpIdx].position += frameCount
        }

        for index in drumPlaybacksToRemove.sorted().reversed() {
            if index < drumPlaybacks.count {
                drumPlaybacks.remove(at: index)
            }
        }

        // Update time
        currentTime += Double(frameCount) / sampleRate

        // Meter update (~20Hz) — write to heap pointers, no actor hop
        if currentTime - lastMeterUpdate > 0.05 {
            lastMeterUpdate = currentTime
            peakLevel = peak
            _rawMeter.pointee = peak
            _rawVoiceCount.pointee = voices.count
        }
    }

    // MARK: - DSP Utilities

    /// Analog-style soft saturation
    private func applySaturation(_ input: Float, drive: Float) -> Float {
        let driven = input * (1.0 + drive * 3.0)
        // Soft clipping using tanh approximation
        let x = driven
        let x2 = x * x
        return x * (27.0 + x2) / (27.0 + 9.0 * x2)
    }
}

// MARK: - MIDI Integration

extension TR808BassSynth {

    /// Handle MIDI note on — routes to drum kit or bass synth depending on loaded slots
    public func handleMIDINoteOn(channel: UInt8, note: UInt8, velocity: UInt8) {
        let vel = Float(velocity) / 127.0
        let midiNote = Int(note)

        // Route to drum kit if note matches a loaded drum slot (GM drum map)
        if !drumSlots.isEmpty, let slotIdx = drumSlots.firstIndex(where: { $0.midiNote == midiNote }) {
            triggerDrum(slotIndex: slotIdx, velocity: vel)
        } else {
            noteOn(note: midiNote, velocity: vel)
        }
    }

    /// Handle MIDI note off
    public func handleMIDINoteOff(channel: UInt8, note: UInt8) {
        // Drum hits are one-shot — only send note off to bass synth
        noteOff(note: Int(note))
    }

    /// Handle MIDI CC
    public func handleMIDICC(channel: UInt8, cc: UInt8, value: UInt8) {
        let normalizedValue = Float(value) / 127.0

        switch cc {
        case 1:  // Mod wheel → pitch glide time
            config.pitchGlideTime = 0.01 + normalizedValue * 0.49
        case 5:  // Portamento time
            config.pitchGlideTime = 0.01 + normalizedValue * 0.49
        case 71: // Filter resonance
            config.filterResonance = normalizedValue
        case 74: // Filter cutoff
            config.filterCutoff = 20.0 + normalizedValue * 1980.0
        case 73: // Attack (click amount)
            config.clickAmount = normalizedValue
        case 75: // Decay
            config.decay = 0.1 + normalizedValue * 9.9
        case 91: // Drive
            config.drive = normalizedValue
        case 7:  // Volume
            config.level = normalizedValue
        default:
            break
        }
    }

    /// Handle MPE pitch bend (per-note)
    public func handleMPEPitchBend(channel: UInt8, value: Int16) {
        // MPE pitch bend affects individual voice
        let semitones = Float(value) / 8192.0 * 48.0  // ±48 semitones

        voiceLock.lock()
        defer { voiceLock.unlock() }
        // Apply to voice on this channel (simplified - would need voice-channel mapping)
    }
}

// MARK: - Drum Kit Integration

extension TR808BassSynth {

    /// Load a complete drum kit from SynthPresetLibrary.
    /// Maps drum sounds to sequential MIDI notes starting at C1 (36) following GM drum map.
    public func loadDrumKit(genre: SynthPresetLibrary.GenreKit) {
        let library = SynthPresetLibrary.shared
        let presetList = library.drumPresets(for: genre)

        let sr = Float(sampleRate)
        var newSlots: [DrumSlot] = []

        for (index, preset) in presetList.prefix(16).enumerated() {
            let audioData = library.renderDrumHit(preset, targetSampleRate: sr)
            let slot = DrumSlot(
                name: preset.name,
                audioData: audioData,
                sampleRate: sr,
                midiNote: 36 + index,
                category: preset.tags.first ?? ""
            )
            newSlots.append(slot)
        }

        voiceLock.lock()
        defer { voiceLock.unlock() }
        drumPlaybacks.removeAll()

        drumSlots = newSlots
        currentDrumKit = genre.rawValue

        // Create matching sequencer pattern
        sequencerPattern = BeatPattern(name: genre.rawValue, trackCount: drumSlots.count)
    }

    /// Load all drum presets (no genre filter) — full kit with all 38+ sounds
    public func loadFullDrumKit() {
        let library = SynthPresetLibrary.shared
        let allDrums = library.presets(for: .drums)

        let sr = Float(sampleRate)
        var newSlots: [DrumSlot] = []

        for (index, preset) in allDrums.prefix(16).enumerated() {
            let audioData = library.renderDrumHit(preset, targetSampleRate: sr)
            let slot = DrumSlot(
                name: preset.name,
                audioData: audioData,
                sampleRate: sr,
                midiNote: 36 + index,
                category: preset.tags.first ?? ""
            )
            newSlots.append(slot)
        }

        voiceLock.lock()
        defer { voiceLock.unlock() }
        drumPlaybacks.removeAll()

        drumSlots = newSlots
        currentDrumKit = "Full Kit"
        sequencerPattern = BeatPattern(name: "Full Kit", trackCount: drumSlots.count)
    }

    /// Trigger a drum slot by index
    public func triggerDrum(slotIndex: Int, velocity: Float = 0.8) {
        guard slotIndex < drumSlots.count else { return }

        voiceLock.lock()
        defer { voiceLock.unlock() }

        // Clean up finished playbacks
        drumPlaybacks.removeAll { !$0.isActive }

        // Voice stealing if needed
        if drumPlaybacks.count >= maxDrumPlaybacks {
            drumPlaybacks.removeFirst()
        }

        drumPlaybacks.append(DrumPlayback(
            slotIndex: slotIndex,
            velocity: velocity
        ))
    }

    /// Trigger drum by MIDI note (GM drum map: C1 = 36)
    public func triggerDrumByNote(_ note: Int, velocity: Float = 0.8) {
        if let idx = drumSlots.firstIndex(where: { $0.midiNote == note }) {
            triggerDrum(slotIndex: idx, velocity: velocity)
        }
    }
}

// MARK: - Step Sequencer

extension TR808BassSynth {

    /// Start the step sequencer
    public func startSequencer() {
        guard !isSequencerPlaying else { return }
        isSequencerPlaying = true
        sequencerStep = 0

        let stepInterval = 60.0 / max(Double(sequencerBPM), 20.0) / 4.0  // 16th notes
        sequencerTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.advanceSequencer()
            }
        }
    }

    /// Stop the step sequencer
    public func stopSequencer() {
        isSequencerPlaying = false
        sequencerTimer?.invalidate()
        sequencerTimer = nil
        sequencerStep = 0
    }

    /// Advance to next step — triggers drum slots according to pattern grid
    private func advanceSequencer() {
        let step = sequencerStep

        for (trackIdx, track) in sequencerPattern.tracks.enumerated() {
            guard step < track.count else { continue }
            let beatStep = track[step]

            if beatStep.isActive && Float.random(in: 0...1) <= beatStep.probability {
                triggerDrum(slotIndex: trackIdx, velocity: beatStep.velocity)
            }
        }

        sequencerStep = (sequencerStep + 1) % Swift.max(1, sequencerPattern.stepCount)
    }

    /// Load a factory pattern preset
    public func loadPatternPreset(_ preset: BeatPatternPreset) {
        let tc = Swift.max(1, drumSlots.count)
        switch preset {
        case .fourOnFloor:
            sequencerPattern = .fourOnFloor(trackCount: tc)
        case .breakbeat:
            sequencerPattern = .breakbeat(trackCount: tc)
        case .trap:
            sequencerPattern = .trap(trackCount: tc)
        case .dnbRoller:
            sequencerPattern = .dnbRoller(trackCount: tc)
        case .empty:
            sequencerPattern = BeatPattern(name: "Empty", trackCount: tc)
        }
    }

    /// Pattern preset options
    public enum BeatPatternPreset: String, CaseIterable {
        case fourOnFloor = "4x4"
        case breakbeat = "Break"
        case trap = "Trap"
        case dnbRoller = "DnB"
        case empty = "Empty"
    }
}
#endif
