// HRVSoundscapeEngine.swift
// Echoelmusic - Pleasant, Customizable Bio-Reactive Audio for HRV Training
//
// Generates a layered soundscape that responds to real-time HRV/coherence:
// - Layer 1: Warm pad/drone (foundation) — always playing
// - Layer 2: Binaural/isochronic beats (entrainment) — optional
// - Layer 3: Breathing guide tones (chime on inhale/exhale) — optional
// - Layer 4: Harmonic overtones (respond to coherence) — optional
//
// Sound design philosophy:
// - Warmth over precision (432 Hz base, rich harmonics, soft attacks)
// - Individual customization (carrier freq, timbre, layer volumes, spatial width)
// - Bio-reactive but subtle (no jarring changes, always smooth transitions)
//
// ============================================================================
// NOT A MEDICAL DEVICE — Audio is for wellness/creative purposes only.
// ============================================================================

import Foundation
import AVFoundation
import Accelerate
import Combine
import SwiftUI

// MARK: - Sound Timbre

/// Available sound timbres for the pad/drone layer
public enum SoundTimbre: String, CaseIterable, Codable, Sendable {
    case warmPad       // Soft, warm analog pad (few harmonics, slow attack)
    case crystalBowl   // Singing bowl / crystal resonance (prominent harmonics)
    case deepDrone      // Low, grounding drone (sub-bass + harmonics)
    case etherealChoir  // Soft choir-like tones (vowel formants)
    case oceanWave      // Filtered noise resembling ocean waves
    case tibetanBowl    // Tibetan singing bowl with beating harmonics

    public var displayName: String {
        switch self {
        case .warmPad: return "Warm Pad"
        case .crystalBowl: return "Crystal Bowl"
        case .deepDrone: return "Deep Drone"
        case .etherealChoir: return "Ethereal Choir"
        case .oceanWave: return "Ocean Waves"
        case .tibetanBowl: return "Tibetan Bowl"
        }
    }

    /// Harmonic structure (partial frequencies relative to fundamental)
    var harmonics: [(partial: Float, amplitude: Float)] {
        switch self {
        case .warmPad:
            return [(1.0, 1.0), (2.0, 0.5), (3.0, 0.2), (4.0, 0.08)]
        case .crystalBowl:
            return [(1.0, 1.0), (2.0, 0.7), (3.0, 0.5), (4.0, 0.3), (5.0, 0.15), (6.0, 0.08)]
        case .deepDrone:
            return [(0.5, 0.6), (1.0, 1.0), (1.5, 0.3), (2.0, 0.4), (3.0, 0.15)]
        case .etherealChoir:
            // Vowel formant approximation (Ah sound)
            return [(1.0, 1.0), (2.0, 0.8), (3.0, 0.3), (4.0, 0.5), (5.0, 0.2)]
        case .oceanWave:
            return [(1.0, 0.3)]  // Mostly filtered noise, minimal tone
        case .tibetanBowl:
            // Inharmonic partials characteristic of metal bowls
            return [(1.0, 1.0), (2.76, 0.7), (4.72, 0.4), (7.0, 0.2)]
        }
    }
}

// MARK: - Breathing Guide Style

/// Style of the breathing guide audio cue
public enum BreathingGuideStyle: String, CaseIterable, Codable, Sendable {
    case none          // No breathing cues
    case softChime     // Gentle chime on inhale/exhale transitions
    case toneRise      // Rising tone for inhale, falling for exhale
    case volumeSwell   // Pad volume follows breath (louder=inhale, softer=exhale)

    public var displayName: String {
        switch self {
        case .none: return "No Guide"
        case .softChime: return "Soft Chime"
        case .toneRise: return "Rising/Falling Tone"
        case .volumeSwell: return "Volume Breathing"
        }
    }
}

// MARK: - Sound Preferences

/// User's personal sound preferences for HRV training sessions
public struct HRVSoundPreferences: Codable, Sendable {
    /// Base frequency in Hz (default 432, range 396-528)
    public var carrierFrequency: Float

    /// Selected timbre for the pad/drone layer
    public var timbre: SoundTimbre

    /// Brainwave entrainment beat frequency (Hz)
    public var beatFrequency: Float

    /// Whether binaural/isochronic beats are enabled
    public var beatsEnabled: Bool

    /// Breathing guide style
    public var breathingGuide: BreathingGuideStyle

    /// Target breathing rate (breaths per minute)
    public var targetBreathingRate: Float

    /// Individual layer volumes (0-1)
    public var padVolume: Float
    public var beatsVolume: Float
    public var breathingVolume: Float
    public var harmonicsVolume: Float

    /// Master volume (0-1)
    public var masterVolume: Float

    /// Spatial width (0=mono, 1=wide stereo)
    public var spatialWidth: Float

    /// How strongly coherence affects the sound (0=static, 1=maximum reactivity)
    public var bioReactivity: Float

    /// Reverb amount (0-1)
    public var reverbAmount: Float

    public static let `default` = HRVSoundPreferences(
        carrierFrequency: 432.0,
        timbre: .warmPad,
        beatFrequency: 10.0,  // Alpha
        beatsEnabled: true,
        breathingGuide: .softChime,
        targetBreathingRate: 6.0,  // Resonance frequency
        padVolume: 0.6,
        beatsVolume: 0.25,
        breathingVolume: 0.3,
        harmonicsVolume: 0.2,
        masterVolume: 0.7,
        spatialWidth: 0.5,
        bioReactivity: 0.5,
        reverbAmount: 0.4
    )

    /// Preset: Deep calm (slower, warmer, more reverb)
    public static let deepCalm = HRVSoundPreferences(
        carrierFrequency: 396.0,
        timbre: .deepDrone,
        beatFrequency: 6.0,  // Theta
        beatsEnabled: true,
        breathingGuide: .volumeSwell,
        targetBreathingRate: 5.5,
        padVolume: 0.7,
        beatsVolume: 0.2,
        breathingVolume: 0.4,
        harmonicsVolume: 0.15,
        masterVolume: 0.6,
        spatialWidth: 0.7,
        bioReactivity: 0.3,
        reverbAmount: 0.6
    )

    /// Preset: Crystal focus (brighter, more beats, less reverb)
    public static let crystalFocus = HRVSoundPreferences(
        carrierFrequency: 440.0,
        timbre: .crystalBowl,
        beatFrequency: 10.0,  // Alpha
        beatsEnabled: true,
        breathingGuide: .softChime,
        targetBreathingRate: 6.0,
        padVolume: 0.5,
        beatsVolume: 0.35,
        breathingVolume: 0.25,
        harmonicsVolume: 0.3,
        masterVolume: 0.7,
        spatialWidth: 0.4,
        bioReactivity: 0.6,
        reverbAmount: 0.3
    )

    /// Preset: Tibetan meditation
    public static let tibetanMeditation = HRVSoundPreferences(
        carrierFrequency: 432.0,
        timbre: .tibetanBowl,
        beatFrequency: 6.0,  // Theta
        beatsEnabled: false,
        breathingGuide: .toneRise,
        targetBreathingRate: 5.5,
        padVolume: 0.65,
        beatsVolume: 0.0,
        breathingVolume: 0.35,
        harmonicsVolume: 0.25,
        masterVolume: 0.65,
        spatialWidth: 0.6,
        bioReactivity: 0.4,
        reverbAmount: 0.55
    )
}

// MARK: - HRV Soundscape Engine

/// Generates a layered, bio-reactive soundscape for HRV training
@MainActor
public final class HRVSoundscapeEngine: ObservableObject {

    // MARK: - Published State

    @Published public var preferences: HRVSoundPreferences {
        didSet { applyPreferences() }
    }
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var isHeadphonesConnected: Bool = false
    @Published public private(set) var currentCoherence: Double = 0.5

    // MARK: - Audio Engine

    private let audioEngine = AVAudioEngine()
    private let padNode = AVAudioPlayerNode()
    private let beatsNode = AVAudioPlayerNode()
    private let breathNode = AVAudioPlayerNode()
    private let harmonicsNode = AVAudioPlayerNode()

    /// Reverb effect
    private let reverb = AVAudioUnitReverb()

    /// Audio format
    private var format: AVAudioFormat?

    /// Buffer size for audio generation
    private let bufferFrameCount: AVAudioFrameCount = 2048

    /// Phase accumulators for continuous waveform generation
    private var padPhases: [Float] = []
    private var beatsPhaseL: Float = 0
    private var beatsPhaseR: Float = 0
    private var breathPhase: Float = 0
    private var harmonicsPhases: [Float] = []

    /// Current breath cycle position (0-1)
    private var breathCyclePosition: Float = 0

    /// Buffer scheduling timer
    private var bufferTimer: Timer?

    /// Smoothed coherence for audio parameter modulation
    private var smoothedCoherence: Float = 0.5

    /// Cancellable for preference persistence
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init(preferences: HRVSoundPreferences = .default) {
        self.preferences = preferences
        setupAudioGraph()
        loadSavedPreferences()
    }

    deinit {
        bufferTimer?.invalidate()
        audioEngine.stop()
    }

    // MARK: - Audio Graph Setup

    private func setupAudioGraph() {
        // Attach nodes
        audioEngine.attach(padNode)
        audioEngine.attach(beatsNode)
        audioEngine.attach(breathNode)
        audioEngine.attach(harmonicsNode)
        audioEngine.attach(reverb)

        let mixer = audioEngine.mainMixerNode
        let sampleRate = mixer.outputFormat(forBus: 0).sampleRate
        let outputFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)
            ?? mixer.outputFormat(forBus: 0)

        self.format = outputFormat

        // Initialize phase arrays based on timbre
        let harmonicCount = preferences.timbre.harmonics.count
        padPhases = [Float](repeating: 0, count: harmonicCount)
        harmonicsPhases = [Float](repeating: 0, count: 8)

        // Connect: nodes → reverb → mixer → output
        audioEngine.connect(padNode, to: reverb, format: outputFormat)
        audioEngine.connect(beatsNode, to: reverb, format: outputFormat)
        audioEngine.connect(breathNode, to: reverb, format: outputFormat)
        audioEngine.connect(harmonicsNode, to: mixer, format: outputFormat)  // Harmonics bypass reverb
        audioEngine.connect(reverb, to: mixer, format: outputFormat)

        // Configure reverb
        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = preferences.reverbAmount * 100

        // Set initial volumes
        applyVolumes()

        audioEngine.prepare()
    }

    // MARK: - Public API

    /// Start the soundscape
    public func start() {
        guard !isPlaying else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredIOBufferDuration(0.01)  // 10ms buffer
            try session.setActive(true)

            detectHeadphones()

            if !audioEngine.isRunning {
                try audioEngine.start()
            }

            padNode.play()
            beatsNode.play()
            breathNode.play()
            harmonicsNode.play()

            // Schedule continuous buffers
            scheduleAllBuffers()
            bufferTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
                self?.scheduleAllBuffers()
            }

            isPlaying = true
            log.audio("HRV Soundscape started (\(preferences.timbre.displayName), \(Int(preferences.carrierFrequency)) Hz)")

        } catch {
            log.audio("HRV Soundscape failed to start: \(error.localizedDescription)", level: .error)
        }
    }

    /// Stop the soundscape
    public func stop() {
        guard isPlaying else { return }

        bufferTimer?.invalidate()
        bufferTimer = nil

        padNode.stop()
        beatsNode.stop()
        breathNode.stop()
        harmonicsNode.stop()
        audioEngine.stop()

        try? AVAudioSession.sharedInstance().setActive(false)

        isPlaying = false
        log.audio("HRV Soundscape stopped")
    }

    /// Update from biometric data (called by training view)
    public func updateBiometrics(coherence: Double, heartRate: Double, breathingRate: Double) {
        // Smooth coherence to prevent jarring audio changes
        let alpha: Float = 0.1  // Very smooth (10% new, 90% old)
        smoothedCoherence = smoothedCoherence * (1 - alpha) + Float(coherence) * alpha
        currentCoherence = Double(smoothedCoherence)
    }

    // MARK: - Buffer Generation

    private func scheduleAllBuffers() {
        guard let format = self.format else { return }

        // Pad layer
        if let padBuffer = generatePadBuffer(format: format) {
            padNode.scheduleBuffer(padBuffer, completionHandler: nil)
        }

        // Beats layer (if enabled)
        if preferences.beatsEnabled, let beatsBuffer = generateBeatsBuffer(format: format) {
            beatsNode.scheduleBuffer(beatsBuffer, completionHandler: nil)
        }

        // Breathing guide layer
        if preferences.breathingGuide != .none, let breathBuffer = generateBreathBuffer(format: format) {
            breathNode.scheduleBuffer(breathBuffer, completionHandler: nil)
        }

        // Harmonics layer (coherence-reactive)
        if let harmonicsBuffer = generateHarmonicsBuffer(format: format) {
            harmonicsNode.scheduleBuffer(harmonicsBuffer, completionHandler: nil)
        }
    }

    /// Generate warm pad/drone buffer
    private func generatePadBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferFrameCount) else { return nil }
        buffer.frameLength = bufferFrameCount

        guard let leftData = buffer.floatChannelData?[0],
              let rightData = buffer.floatChannelData?[1] else { return nil }

        let sampleRate = Float(format.sampleRate)
        let harmonics = preferences.timbre.harmonics
        let baseFreq = preferences.carrierFrequency
        let volume = preferences.padVolume * preferences.masterVolume

        // Coherence modulation: higher coherence → slightly brighter (more harmonics)
        let brightnessModulation = 0.7 + smoothedCoherence * 0.3 * preferences.bioReactivity

        // Ensure we have enough phase accumulators
        while padPhases.count < harmonics.count {
            padPhases.append(0)
        }

        for i in 0..<Int(bufferFrameCount) {
            var sampleL: Float = 0
            var sampleR: Float = 0

            for (h, harmonic) in harmonics.enumerated() {
                let freq = baseFreq * harmonic.partial
                let phaseInc = 2.0 * Float.pi * freq / sampleRate

                // Higher harmonics modulated by coherence
                let harmonicAmp: Float
                if h == 0 {
                    harmonicAmp = harmonic.amplitude
                } else {
                    harmonicAmp = harmonic.amplitude * brightnessModulation
                }

                let sample = harmonicAmp * sin(padPhases[h])

                // Stereo spread based on spatial width
                let pan = preferences.spatialWidth * (Float(h % 2 == 0 ? 1 : -1)) * 0.3
                sampleL += sample * (1.0 - pan) * 0.5
                sampleR += sample * (1.0 + pan) * 0.5

                padPhases[h] += phaseInc
                if padPhases[h] > 2.0 * Float.pi {
                    padPhases[h] -= 2.0 * Float.pi
                }
            }

            // Soft clipping for warmth
            sampleL = tanh(sampleL * 1.2) * volume
            sampleR = tanh(sampleR * 1.2) * volume

            leftData[i] = sampleL
            rightData[i] = sampleR
        }

        return buffer
    }

    /// Generate binaural/isochronic beats buffer
    private func generateBeatsBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferFrameCount) else { return nil }
        buffer.frameLength = bufferFrameCount

        guard let leftData = buffer.floatChannelData?[0],
              let rightData = buffer.floatChannelData?[1] else { return nil }

        let sampleRate = Float(format.sampleRate)
        let carrier = preferences.carrierFrequency
        let beat = preferences.beatFrequency
        let volume = preferences.beatsVolume * preferences.masterVolume * 0.5  // Beats are quieter

        // Coherence modulation: shift beat frequency toward alpha when coherent
        let coherenceShift = (smoothedCoherence - 0.5) * 4.0 * preferences.bioReactivity
        let modulatedBeat = Swift.max(1.0, beat + coherenceShift)

        if isHeadphonesConnected {
            // Binaural mode: different frequency per ear
            let leftFreq = carrier - modulatedBeat / 2.0
            let rightFreq = carrier + modulatedBeat / 2.0
            let leftInc = 2.0 * Float.pi * leftFreq / sampleRate
            let rightInc = 2.0 * Float.pi * rightFreq / sampleRate

            for i in 0..<Int(bufferFrameCount) {
                leftData[i] = volume * sin(beatsPhaseL)
                rightData[i] = volume * sin(beatsPhaseR)

                beatsPhaseL += leftInc
                beatsPhaseR += rightInc

                if beatsPhaseL > 2.0 * Float.pi { beatsPhaseL -= 2.0 * Float.pi }
                if beatsPhaseR > 2.0 * Float.pi { beatsPhaseR -= 2.0 * Float.pi }
            }
        } else {
            // Isochronic mode: amplitude-modulated carrier (works on speakers)
            let carrierInc = 2.0 * Float.pi * carrier / sampleRate
            let pulseInc = 2.0 * Float.pi * modulatedBeat / sampleRate

            for i in 0..<Int(bufferFrameCount) {
                let carrierSample = sin(beatsPhaseL)
                let pulse = (sin(beatsPhaseR) + 1.0) / 2.0  // 0-1 envelope

                let sample = volume * carrierSample * pulse
                leftData[i] = sample
                rightData[i] = sample

                beatsPhaseL += carrierInc
                beatsPhaseR += pulseInc

                if beatsPhaseL > 2.0 * Float.pi { beatsPhaseL -= 2.0 * Float.pi }
                if beatsPhaseR > 2.0 * Float.pi { beatsPhaseR -= 2.0 * Float.pi }
            }
        }

        return buffer
    }

    /// Generate breathing guide audio buffer
    private func generateBreathBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferFrameCount) else { return nil }
        buffer.frameLength = bufferFrameCount

        guard let leftData = buffer.floatChannelData?[0],
              let rightData = buffer.floatChannelData?[1] else { return nil }

        let sampleRate = Float(format.sampleRate)
        let breathCycleHz = preferences.targetBreathingRate / 60.0  // Convert BPM to Hz
        let volume = preferences.breathingVolume * preferences.masterVolume

        switch preferences.breathingGuide {
        case .none:
            // Silence
            memset(leftData, 0, Int(bufferFrameCount) * MemoryLayout<Float>.size)
            memset(rightData, 0, Int(bufferFrameCount) * MemoryLayout<Float>.size)

        case .softChime:
            // Generate a soft bell/chime at breath transitions
            let breathInc = breathCycleHz / sampleRate
            let chimeFreq: Float = preferences.carrierFrequency * 2.0  // One octave up
            let chimeInc = 2.0 * Float.pi * chimeFreq / sampleRate

            for i in 0..<Int(bufferFrameCount) {
                let prevPosition = breathCyclePosition
                breathCyclePosition += breathInc
                if breathCyclePosition > 1.0 { breathCyclePosition -= 1.0 }

                // Detect transitions (inhale at 0, exhale at 0.5)
                let isTransition = (prevPosition < 0.5 && breathCyclePosition >= 0.5)
                    || (prevPosition > breathCyclePosition)  // Wrap-around

                if isTransition {
                    breathPhase = 0  // Reset chime
                }

                // Exponential decay envelope for chime
                let chimeT = breathPhase / sampleRate
                let envelope = exp(-chimeT * 4.0) * volume  // ~250ms decay

                let sample = envelope * sin(breathPhase * chimeInc / sampleRate * sampleRate)
                leftData[i] = sample
                rightData[i] = sample

                breathPhase += 1.0
            }

        case .toneRise:
            // Pitch rises during inhale (0-0.5), falls during exhale (0.5-1.0)
            let breathInc = breathCycleHz / sampleRate
            let baseFreq = preferences.carrierFrequency * 1.5

            for i in 0..<Int(bufferFrameCount) {
                breathCyclePosition += breathInc
                if breathCyclePosition > 1.0 { breathCyclePosition -= 1.0 }

                // Pitch modulation: +/- 10% of base frequency
                let pitchMod: Float
                if breathCyclePosition < 0.5 {
                    // Inhale: rising pitch
                    pitchMod = 1.0 + 0.1 * (breathCyclePosition * 2.0)
                } else {
                    // Exhale: falling pitch
                    pitchMod = 1.1 - 0.1 * ((breathCyclePosition - 0.5) * 2.0)
                }

                let freq = baseFreq * pitchMod
                let phaseInc = 2.0 * Float.pi * freq / sampleRate
                breathPhase += phaseInc
                if breathPhase > 2.0 * Float.pi { breathPhase -= 2.0 * Float.pi }

                // Smooth sine with low volume
                let sample = volume * 0.5 * sin(breathPhase)
                leftData[i] = sample
                rightData[i] = sample
            }

        case .volumeSwell:
            // Pad volume modulated by breath cycle (handled in pad generation)
            // This layer generates a subtle breath-sync noise wash
            let breathInc = breathCycleHz / sampleRate

            for i in 0..<Int(bufferFrameCount) {
                breathCyclePosition += breathInc
                if breathCyclePosition > 1.0 { breathCyclePosition -= 1.0 }

                // Sine envelope following breath
                let breathEnvelope = (sin(breathCyclePosition * 2.0 * Float.pi - Float.pi / 2.0) + 1.0) / 2.0

                // Gentle filtered noise
                let noise = Float.random(in: -1...1) * 0.1
                let sample = noise * breathEnvelope * volume
                leftData[i] = sample
                rightData[i] = sample
            }
        }

        return buffer
    }

    /// Generate coherence-reactive harmonic overtones
    private func generateHarmonicsBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferFrameCount) else { return nil }
        buffer.frameLength = bufferFrameCount

        guard let leftData = buffer.floatChannelData?[0],
              let rightData = buffer.floatChannelData?[1] else { return nil }

        let sampleRate = Float(format.sampleRate)
        let baseFreq = preferences.carrierFrequency
        let volume = preferences.harmonicsVolume * preferences.masterVolume

        // Number of harmonics scales with coherence (more coherence = richer sound)
        let maxHarmonics = 8
        let activeHarmonics = Swift.max(2, Int(Float(maxHarmonics) * smoothedCoherence))

        while harmonicsPhases.count < maxHarmonics {
            harmonicsPhases.append(0)
        }

        for i in 0..<Int(bufferFrameCount) {
            var sampleL: Float = 0
            var sampleR: Float = 0

            for h in 0..<activeHarmonics {
                // Perfect fifth intervals (musical consonance)
                let interval: Float
                switch h {
                case 0: interval = 1.0      // Unison
                case 1: interval = 1.5      // Perfect fifth
                case 2: interval = 2.0      // Octave
                case 3: interval = 2.5      // Octave + major third
                case 4: interval = 3.0      // Octave + fifth
                case 5: interval = 4.0      // Two octaves
                case 6: interval = 5.0      // Two octaves + major third
                default: interval = 6.0     // Two octaves + fifth
                }

                let freq = baseFreq * interval
                let phaseInc = 2.0 * Float.pi * freq / sampleRate

                // Amplitude falls off with harmonic number, boosted by coherence
                let harmonicAmp = volume / Float(h + 2) * smoothedCoherence

                let sample = harmonicAmp * sin(harmonicsPhases[h])

                // Alternate stereo placement
                let pan = preferences.spatialWidth * (Float(h % 2 == 0 ? 1 : -1)) * 0.4
                sampleL += sample * (1.0 - pan) * 0.5
                sampleR += sample * (1.0 + pan) * 0.5

                harmonicsPhases[h] += phaseInc
                if harmonicsPhases[h] > 2.0 * Float.pi {
                    harmonicsPhases[h] -= 2.0 * Float.pi
                }
            }

            leftData[i] = sampleL
            rightData[i] = sampleR
        }

        return buffer
    }

    // MARK: - Preferences

    private func applyPreferences() {
        applyVolumes()
        reverb.wetDryMix = preferences.reverbAmount * 100

        // Reset phase arrays for new timbre
        let harmonicCount = preferences.timbre.harmonics.count
        if padPhases.count != harmonicCount {
            padPhases = [Float](repeating: 0, count: harmonicCount)
        }

        savePreferences()
    }

    private func applyVolumes() {
        padNode.volume = preferences.padVolume
        beatsNode.volume = preferences.beatsVolume
        breathNode.volume = preferences.breathingVolume
        harmonicsNode.volume = preferences.harmonicsVolume
    }

    private func detectHeadphones() {
        let route = AVAudioSession.sharedInstance().currentRoute
        isHeadphonesConnected = route.outputs.contains { output in
            output.portType == .headphones ||
            output.portType == .bluetoothHFP ||
            output.portType == .bluetoothLE ||
            output.portType == .bluetoothA2DP
        }
    }

    // MARK: - Persistence

    private static let preferencesKey = "com.echoelmusic.hrv.soundPreferences"

    private func savePreferences() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: Self.preferencesKey)
        }
    }

    private func loadSavedPreferences() {
        if let data = UserDefaults.standard.data(forKey: Self.preferencesKey),
           let saved = try? JSONDecoder().decode(HRVSoundPreferences.self, from: data) {
            self.preferences = saved
        }
    }
}
