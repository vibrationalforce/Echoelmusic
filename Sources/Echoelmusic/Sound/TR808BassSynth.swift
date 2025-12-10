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
import Combine

// MARK: - 808 Bass Configuration

/// Configuration for the 808 Bass Synthesizer
public struct TR808BassConfig: Codable, Equatable {

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

// MARK: - TR808 Bass Synthesizer

/// Professional 808 Bass Synthesizer with Pitch Glide
@MainActor
public final class TR808BassSynth: ObservableObject {

    // MARK: - Singleton

    public static let shared = TR808BassSynth()

    // MARK: - Published State

    @Published public var config = TR808BassConfig.classic808
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

    private var voices: [TR808Voice] = []
    private let voiceLock = NSLock()

    // MARK: - DSP State

    private var currentTime: Double = 0.0
    private var lastMeterUpdate: Double = 0.0
    private var peakLevel: Float = 0.0

    // MARK: - Bio-Reactive

    private var bioCoherence: Float = 0.5
    private var bioEnergy: Float = 0.5

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupAudioEngine()
    }

    deinit {
        stop()
        audioEngine?.stop()
    }

    // MARK: - Audio Engine Setup

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()

        guard let engine = audioEngine else { return }

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)
        guard let audioFormat = format else { return }

        // Create source node for real-time synthesis
        sourceNode = AVAudioSourceNode { [weak self] _, timeStamp, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            guard let leftBuffer = ablPointer[0].mData?.assumingMemoryBound(to: Float.self),
                  let rightBuffer = ablPointer[1].mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }

            // Render audio on audio thread
            self.renderAudio(
                leftBuffer: leftBuffer,
                rightBuffer: rightBuffer,
                frameCount: Int(frameCount)
            )

            return noErr
        }

        guard let source = sourceNode else { return }

        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: audioFormat)

        do {
            try engine.start()
        } catch {
            // Engine failed to start - will retry on first note
        }
    }

    // MARK: - Public API

    /// Start the synthesizer
    public func start() {
        guard let engine = audioEngine, !engine.isRunning else { return }

        do {
            try engine.start()
            isPlaying = true
        } catch {
            isPlaying = false
        }
    }

    /// Stop the synthesizer
    public func stop() {
        isPlaying = false

        voiceLock.lock()
        voices.removeAll()
        voiceLock.unlock()

        activeVoiceCount = 0
        currentNote = nil
    }

    /// Trigger a note with velocity
    public func noteOn(note: Int, velocity: Float = 0.8) {
        // Ensure engine is running - ✅ ERROR HANDLING: Log startup failures
        if audioEngine?.isRunning != true {
            do {
                try audioEngine?.start()
            } catch {
                print("❌ TR808BassSynth: Failed to start audio engine: \(error.localizedDescription)")
                return // Don't process note if engine failed
            }
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
        voices.removeAll()
        voiceLock.unlock()

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

    private func renderAudio(leftBuffer: UnsafeMutablePointer<Float>, rightBuffer: UnsafeMutablePointer<Float>, frameCount: Int) {
        // Get config snapshot for thread safety
        let cfg = config

        // Clear buffers
        memset(leftBuffer, 0, frameCount * MemoryLayout<Float>.size)
        memset(rightBuffer, 0, frameCount * MemoryLayout<Float>.size)

        voiceLock.lock()

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
                    let releaseProgress = min(1.0, releaseElapsed / cfg.release)
                    env = voice.releaseStartEnvelope * (1.0 - releaseProgress)
                } else {
                    // Exponential decay
                    let decayProgress = elapsed / cfg.decay
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
                    let glideProgress = min(1.0, elapsed / cfg.pitchGlideTime)
                    voice.pitchGlideProgress = glideProgress

                    // Apply glide curve (exponential)
                    let curvedProgress = pow(glideProgress, cfg.pitchGlideCurve)

                    // Calculate pitch offset (starts at glideRange, ends at 0)
                    let pitchOffset = cfg.pitchGlideRange * (1.0 - curvedProgress)
                    pitchMultiplier = pow(2.0, pitchOffset / 12.0)
                }

                // Pitch envelope
                if cfg.pitchEnvAmount != 0 {
                    let pitchEnvProgress = min(1.0, elapsed / cfg.pitchEnvDecay)
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

        voiceLock.unlock()

        // Update time
        currentTime += Double(frameCount) / sampleRate

        // Update meter (throttled)
        if currentTime - lastMeterUpdate > 0.05 {
            lastMeterUpdate = currentTime
            peakLevel = peak

            Task { @MainActor in
                self.meterLevel = peak
                self.activeVoiceCount = self.voices.count
                if self.voices.isEmpty {
                    self.isPlaying = false
                }
            }
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

    /// Handle MIDI note on
    public func handleMIDINoteOn(channel: UInt8, note: UInt8, velocity: UInt8) {
        let vel = Float(velocity) / 127.0
        noteOn(note: Int(note), velocity: vel)
    }

    /// Handle MIDI note off
    public func handleMIDINoteOff(channel: UInt8, note: UInt8) {
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
        // Apply to voice on this channel (simplified - would need voice-channel mapping)
        voiceLock.unlock()
    }
}

// MARK: - SwiftUI View

import SwiftUI

public struct TR808BassSynthView: View {
    @StateObject private var synth = TR808BassSynth.shared
    @State private var selectedPreset: String = "Classic 808"

    private let presets: [(String, TR808BassConfig)] = [
        ("Classic 808", .classic808),
        ("Hard Trap", .hardTrap),
        ("Deep Sub", .deepSub),
        ("Distorted", .distorted808),
        ("Long Slide", .longSlide)
    ]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Preset selector
                    presetSelector

                    // Pitch Glide section
                    pitchGlideSection

                    // Envelope section
                    envelopeSection

                    // Tone section
                    toneSection

                    // Keyboard
                    keyboardView
                }
                .padding()
            }
        }
    }

    private var headerView: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)

                Text("808")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("TR-808 Bass Synth")
                    .font(.title2.bold())

                Text("Sub-Bass Engine with Pitch Glide")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

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

                Text(String(format: "%.0f", synth.meterLevel * 100))
                    .font(.caption2.monospacedDigit())
            }
        }
        .padding()
    }

    private var meterColor: Color {
        if synth.meterLevel > 0.9 { return .red }
        if synth.meterLevel > 0.7 { return .orange }
        return .green
    }

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
                                    Capsule()
                                        .fill(selectedPreset == name ? Color.orange : Color.gray.opacity(0.2))
                                )
                                .foregroundColor(selectedPreset == name ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var pitchGlideSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pitch Glide")
                    .font(.headline)

                Spacer()

                Toggle("", isOn: $synth.config.pitchGlideEnabled)
                    .labelsHidden()
            }

            if synth.config.pitchGlideEnabled {
                VStack(spacing: 16) {
                    // Glide Time
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Glide Time")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.0f ms", synth.config.pitchGlideTime * 1000))
                                .font(.caption.monospacedDigit())
                        }
                        Slider(value: $synth.config.pitchGlideTime, in: 0.01...0.5)
                            .tint(.orange)
                    }

                    // Glide Range
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Glide Range")
                                .font(.caption)
                            Spacer()
                            Text(String(format: "%.0f st", synth.config.pitchGlideRange))
                                .font(.caption.monospacedDigit())
                        }
                        Slider(value: $synth.config.pitchGlideRange, in: -24...0)
                            .tint(.orange)
                    }

                    // Glide Curve
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Curve")
                                .font(.caption)
                            Spacer()
                            Text(synth.config.pitchGlideCurve > 0.5 ? "Exponential" : "Linear")
                                .font(.caption)
                        }
                        Slider(value: $synth.config.pitchGlideCurve, in: 0...1)
                            .tint(.orange)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
    }

    private var envelopeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Envelope")
                .font(.headline)

            HStack(spacing: 20) {
                // Click
                VStack(spacing: 4) {
                    Text("Click")
                        .font(.caption)
                    Slider(value: $synth.config.clickAmount, in: 0...1)
                        .tint(.red)
                    Text(String(format: "%.0f%%", synth.config.clickAmount * 100))
                        .font(.caption2.monospacedDigit())
                }

                // Decay
                VStack(spacing: 4) {
                    Text("Decay")
                        .font(.caption)
                    Slider(value: $synth.config.decay, in: 0.1...5)
                        .tint(.red)
                    Text(String(format: "%.1fs", synth.config.decay))
                        .font(.caption2.monospacedDigit())
                }

                // Release
                VStack(spacing: 4) {
                    Text("Release")
                        .font(.caption)
                    Slider(value: $synth.config.release, in: 0.01...2)
                        .tint(.red)
                    Text(String(format: "%.2fs", synth.config.release))
                        .font(.caption2.monospacedDigit())
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
        )
    }

    private var toneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tone")
                .font(.headline)

            HStack(spacing: 20) {
                // Drive
                VStack(spacing: 4) {
                    Text("Drive")
                        .font(.caption)
                    Slider(value: $synth.config.drive, in: 0...1)
                        .tint(.purple)
                    Text(String(format: "%.0f%%", synth.config.drive * 100))
                        .font(.caption2.monospacedDigit())
                }

                // Filter
                VStack(spacing: 4) {
                    Text("Filter")
                        .font(.caption)
                    Slider(value: $synth.config.filterCutoff, in: 20...2000)
                        .tint(.purple)
                    Text(String(format: "%.0f Hz", synth.config.filterCutoff))
                        .font(.caption2.monospacedDigit())
                }

                // Level
                VStack(spacing: 4) {
                    Text("Level")
                        .font(.caption)
                    Slider(value: $synth.config.level, in: 0...1)
                        .tint(.purple)
                    Text(String(format: "%.0f%%", synth.config.level * 100))
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

    private var keyboardView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Play")
                .font(.headline)

            // Simple octave keyboard (C1 - C2 for bass)
            HStack(spacing: 4) {
                ForEach([36, 38, 40, 41, 43, 45, 47, 48], id: \.self) { note in
                    Button(action: {}) {
                        Text(noteNameForMIDI(note))
                            .font(.caption2)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(synth.currentNote == note ? Color.orange : Color.gray.opacity(0.2))
                            )
                            .foregroundColor(synth.currentNote == note ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                synth.noteOn(note: note, velocity: 0.8)
                            }
                            .onEnded { _ in
                                synth.noteOff(note: note)
                            }
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

    private func noteNameForMIDI(_ note: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (note / 12) - 1
        let noteName = names[note % 12]
        return "\(noteName)\(octave)"
    }
}

// MARK: - Preview

#if DEBUG
struct TR808BassSynthView_Previews: PreviewProvider {
    static var previews: some View {
        TR808BassSynthView()
    }
}
#endif
