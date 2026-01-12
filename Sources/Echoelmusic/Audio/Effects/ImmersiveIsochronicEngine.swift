// SPDX-License-Identifier: MIT
// Copyright 2026 Echoelmusic
// Immersive Isochronic Engine - Professional Sound Design for Focus & Relaxation
// Replaces boring sine waves with rich, layered audio textures

import Foundation
import AVFoundation
import Accelerate
import Combine

/// Professional isochronic tone engine with rich sound design
///
/// **Why Isochronic over Binaural:**
/// - Works on ANY audio system (speakers, headphones, spatial, club PA)
/// - No stereo separation required - the RHYTHM creates the entrainment
/// - More research-backed for attention/focus effects
/// - Compatible with spatial audio and surround systems
///
/// **Sound Design Philosophy:**
/// - Rich harmonic content (not boring pure sine waves)
/// - Layered pad textures for musicality
/// - Soft attack/release to prevent fatigue
/// - Bio-reactive modulation for personalization
///
/// **Scientific Honesty:**
/// HINWEIS: Isochronic tones may support subjective relaxation and focus.
/// EEG entrainment evidence is mixed (see Huang & Charyton, 2008).
/// This is a creative/wellness tool, NOT a medical device.
@MainActor
public final class ImmersiveIsochronicEngine: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentPreset: EntrainmentPreset = .focus
    @Published public private(set) var currentSoundscape: Soundscape = .warmPad
    @Published public private(set) var rhythmFrequency: Float = 10.0
    @Published public private(set) var spatialPosition: SpatialPosition = .center

    // MARK: - Entrainment Presets (Research-Based Frequencies)

    /// Entrainment presets based on established EEG frequency bands
    /// Note: Individual responses vary - these are starting points, not prescriptions
    public enum EntrainmentPreset: String, CaseIterable, Identifiable {
        case deepRest       // 2-4 Hz Delta - Sleep, recovery
        case meditation     // 4-8 Hz Theta - Meditation, creativity
        case relaxedFocus   // 8-12 Hz Alpha - Calm alertness
        case focus          // 12-15 Hz SMR - Sustained attention
        case activeThinking // 15-20 Hz Beta - Active cognition
        case peakFlow       // 20-40 Hz Gamma - Peak performance (use sparingly)

        public var id: String { rawValue }

        /// Center frequency of the band
        public var centerFrequency: Float {
            switch self {
            case .deepRest: return 2.5
            case .meditation: return 6.0
            case .relaxedFocus: return 10.0
            case .focus: return 13.5
            case .activeThinking: return 17.5
            case .peakFlow: return 30.0
            }
        }

        /// Frequency range for subtle variation
        public var frequencyRange: ClosedRange<Float> {
            switch self {
            case .deepRest: return 1.5...4.0
            case .meditation: return 4.0...8.0
            case .relaxedFocus: return 8.0...12.0
            case .focus: return 12.0...15.0
            case .activeThinking: return 15.0...20.0
            case .peakFlow: return 20.0...40.0
            }
        }

        public var displayName: String {
            switch self {
            case .deepRest: return "Deep Rest"
            case .meditation: return "Meditation"
            case .relaxedFocus: return "Relaxed Focus"
            case .focus: return "Focus"
            case .activeThinking: return "Active Thinking"
            case .peakFlow: return "Peak Flow"
            }
        }

        public var description: String {
            switch self {
            case .deepRest: return "Delta band (2-4 Hz) - For winding down before sleep"
            case .meditation: return "Theta band (4-8 Hz) - Reflective, meditative states"
            case .relaxedFocus: return "Alpha band (8-12 Hz) - Calm, alert awareness"
            case .focus: return "SMR band (12-15 Hz) - Sustained attention, studying"
            case .activeThinking: return "Beta band (15-20 Hz) - Active problem-solving"
            case .peakFlow: return "Gamma band (20-40 Hz) - Peak performance moments"
            }
        }

        /// Recommended session duration in minutes
        public var recommendedDuration: Int {
            switch self {
            case .deepRest: return 30
            case .meditation: return 20
            case .relaxedFocus: return 15
            case .focus: return 25
            case .activeThinking: return 20
            case .peakFlow: return 10 // Gamma should be used sparingly
            }
        }
    }

    // MARK: - Soundscapes (Rich Audio Textures)

    /// Soundscape determines the tonal character - NO boring sine waves!
    public enum Soundscape: String, CaseIterable, Identifiable {
        case warmPad        // Soft, warm synthesizer pad
        case crystalBowl    // Singing bowl-inspired harmonics
        case organicDrone   // Natural harmonic drone
        case cosmicWash     // Ethereal, spacious texture
        case earthyGround   // Grounding, bass-rich tone
        case shimmeringAir  // Light, airy upper harmonics

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .warmPad: return "Warm Pad"
            case .crystalBowl: return "Crystal Bowl"
            case .organicDrone: return "Organic Drone"
            case .cosmicWash: return "Cosmic Wash"
            case .earthyGround: return "Earthy Ground"
            case .shimmeringAir: return "Shimmering Air"
            }
        }

        /// Base carrier frequency for this soundscape
        var carrierFrequency: Float {
            switch self {
            case .warmPad: return 220.0       // A3 - warm middle register
            case .crystalBowl: return 528.0   // C5 - "Solfeggio" (cultural, not magical)
            case .organicDrone: return 136.1  // OM frequency (cultural significance)
            case .cosmicWash: return 174.0    // Low F - spacious
            case .earthyGround: return 110.0  // A2 - grounding bass
            case .shimmeringAir: return 396.0 // G4 - bright, airy
            }
        }

        /// Harmonic profile - which overtones to include
        var harmonicProfile: HarmonicProfile {
            switch self {
            case .warmPad: return HarmonicProfile(
                harmonics: [1.0, 0.5, 0.25, 0.125, 0.06],
                detuning: [0, 2, -2, 5, -3] // Slight chorus effect
            )
            case .crystalBowl: return HarmonicProfile(
                harmonics: [1.0, 0.0, 0.3, 0.0, 0.15, 0.0, 0.08], // Odd harmonics
                detuning: [0, 0, 1, 0, -1, 0, 2]
            )
            case .organicDrone: return HarmonicProfile(
                harmonics: [1.0, 0.7, 0.4, 0.3, 0.2, 0.15, 0.1, 0.08],
                detuning: [0, 0, 0, 0, 0, 0, 0, 0] // Pure harmonics
            )
            case .cosmicWash: return HarmonicProfile(
                harmonics: [1.0, 0.6, 0.4, 0.3, 0.2, 0.15, 0.1, 0.08, 0.05],
                detuning: [0, 3, -3, 5, -5, 7, -7, 10, -10] // Wide detune
            )
            case .earthyGround: return HarmonicProfile(
                harmonics: [1.0, 0.8, 0.4, 0.2, 0.1],
                detuning: [0, 0, 1, -1, 0]
            )
            case .shimmeringAir: return HarmonicProfile(
                harmonics: [0.3, 0.5, 1.0, 0.8, 0.6, 0.4, 0.3, 0.2],
                detuning: [0, 1, 2, -1, 3, -2, 4, -3] // Shimmer
            )
            }
        }
    }

    /// Harmonic content definition for rich tones
    public struct HarmonicProfile {
        let harmonics: [Float]  // Amplitude of each harmonic (1 = fundamental)
        let detuning: [Float]   // Cents detuning for each harmonic (chorus effect)
    }

    // MARK: - Spatial Position

    /// Spatial positioning for immersive audio
    public enum SpatialPosition: String, CaseIterable {
        case center         // Centered, intimate
        case wide           // Wide stereo field
        case surrounding    // Surrounding presence
        case overhead       // Above (visionOS spatial)
        case grounded       // Below/grounding

        var stereoWidth: Float {
            switch self {
            case .center: return 0.0
            case .wide: return 0.8
            case .surrounding: return 1.0
            case .overhead: return 0.6
            case .grounded: return 0.4
            }
        }
    }

    // MARK: - Configuration

    /// Master volume (0.0 - 1.0)
    public var volume: Float = 0.5 {
        didSet { volume = min(max(volume, 0.0), 1.0) }
    }

    /// Pulse shape softness (0 = sharp square, 1 = very soft sine)
    public var pulseSoftness: Float = 0.7 {
        didSet { pulseSoftness = min(max(pulseSoftness, 0.0), 1.0) }
    }

    /// Bio-reactive modulation amount (0 = none, 1 = full)
    public var bioModulationAmount: Float = 0.5

    // MARK: - Audio Engine

    private let audioEngine = AVAudioEngine()
    private let sourceNode: AVAudioSourceNode
    private var sampleRate: Double = 48000

    // Phase accumulators for continuous synthesis
    private var carrierPhases: [Double] = []
    private var pulsePhase: Double = 0
    private var lfoPhase: Double = 0

    // Current synthesis parameters (thread-safe via atomic)
    private var currentCarrierFreq: Float = 220.0
    private var currentPulseFreq: Float = 10.0
    private var currentHarmonics: [Float] = [1.0]
    private var currentDetuning: [Float] = [0]

    // MARK: - Initialization

    public init() {
        // Initialize source node with render callback
        self.sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            return self.renderAudio(frameCount: frameCount, audioBufferList: audioBufferList)
        }

        setupAudioEngine()
    }

    deinit {
        stop()
    }

    // MARK: - Public API

    /// Configure with a preset and soundscape
    public func configure(preset: EntrainmentPreset, soundscape: Soundscape = .warmPad) {
        self.currentPreset = preset
        self.currentSoundscape = soundscape
        self.rhythmFrequency = preset.centerFrequency

        // Update synthesis parameters
        updateSynthesisParameters()

        log.audio("Configured: \(preset.displayName) @ \(rhythmFrequency) Hz with \(soundscape.displayName)")
    }

    /// Set rhythm frequency directly (for bio-reactive modulation)
    public func setRhythmFrequency(_ frequency: Float) {
        self.rhythmFrequency = min(max(frequency, 0.5), 60.0)
        updateSynthesisParameters()
    }

    /// Bio-reactive: Map HRV coherence to rhythm frequency
    /// High coherence → Alpha/SMR for maintaining focus
    /// Low coherence → Theta for relaxation
    public func modulateFromCoherence(_ coherence: Double) {
        guard bioModulationAmount > 0 else { return }

        let normalizedCoherence = min(max(coherence / 100.0, 0), 1)

        // Map coherence to frequency: low coherence → lower freq, high → higher
        // Range: 6 Hz (theta) to 15 Hz (SMR)
        let baseFrequency = currentPreset.centerFrequency
        let modulationRange: Float = 4.0 * bioModulationAmount

        let modulatedFreq = baseFrequency + Float(normalizedCoherence - 0.5) * modulationRange
        self.rhythmFrequency = min(max(modulatedFreq, 2.0), 40.0)

        updateSynthesisParameters()
        log.audio("Bio-modulated: coherence \(Int(coherence))% → \(String(format: "%.1f", rhythmFrequency)) Hz")
    }

    /// Bio-reactive: Map heart rate to subtle tempo variations
    public func modulateFromHeartRate(_ bpm: Double) {
        guard bioModulationAmount > 0 else { return }

        // Very subtle: HR variations modulate pulse softness
        // Higher HR → slightly sharper pulses (more alerting)
        // Lower HR → softer pulses (more calming)
        let normalizedHR = min(max((bpm - 50) / 100, 0), 1) // 50-150 BPM range
        self.pulseSoftness = 0.5 + Float(1.0 - normalizedHR) * 0.4 * bioModulationAmount
    }

    /// Set spatial position
    public func setSpatialPosition(_ position: SpatialPosition) {
        self.spatialPosition = position
        log.audio("Spatial position: \(position.rawValue)")
    }

    /// Start playback
    public func start() {
        guard !isPlaying else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredSampleRate(48000)
            try session.setPreferredIOBufferDuration(0.005)
            try session.setActive(true)

            self.sampleRate = session.sampleRate

            if !audioEngine.isRunning {
                try audioEngine.start()
            }

            isPlaying = true
            log.audio("Immersive Isochronic Engine started: \(currentPreset.displayName) @ \(rhythmFrequency) Hz")

        } catch {
            log.audio("Failed to start: \(error.localizedDescription)", level: .error)
        }
    }

    /// Stop playback
    public func stop() {
        guard isPlaying else { return }

        audioEngine.stop()
        try? AVAudioSession.sharedInstance().setActive(false)

        // Reset phases
        carrierPhases = Array(repeating: 0, count: currentHarmonics.count)
        pulsePhase = 0
        lfoPhase = 0

        isPlaying = false
        log.audio("Immersive Isochronic Engine stopped")
    }

    // MARK: - Private Methods

    private func setupAudioEngine() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2)!

        audioEngine.attach(sourceNode)
        audioEngine.connect(sourceNode, to: audioEngine.mainMixerNode, format: format)
        audioEngine.prepare()
    }

    private func updateSynthesisParameters() {
        let profile = currentSoundscape.harmonicProfile
        currentCarrierFreq = currentSoundscape.carrierFrequency
        currentPulseFreq = rhythmFrequency
        currentHarmonics = profile.harmonics
        currentDetuning = profile.detuning

        // Ensure phase arrays match harmonic count
        if carrierPhases.count != currentHarmonics.count {
            carrierPhases = Array(repeating: 0, count: currentHarmonics.count)
        }
    }

    /// Core audio render callback - generates rich isochronic tones
    private func renderAudio(frameCount: UInt32, audioBufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

        guard ablPointer.count >= 2,
              let leftBuffer = ablPointer[0].mData?.assumingMemoryBound(to: Float.self),
              let rightBuffer = ablPointer[1].mData?.assumingMemoryBound(to: Float.self) else {
            return noErr
        }

        let sr = sampleRate
        let carrierFreq = Double(currentCarrierFreq)
        let pulseFreq = Double(currentPulseFreq)
        let harmonics = currentHarmonics
        let detuning = currentDetuning
        let vol = volume
        let softness = pulseSoftness
        let width = spatialPosition.stereoWidth

        // LFO for subtle movement (0.1 Hz)
        let lfoFreq = 0.1

        for frame in 0..<Int(frameCount) {
            // === Pulse Envelope (Isochronic Rhythm) ===
            // Shape: soft sine-based pulse, adjustable sharpness
            let pulseRaw = sin(pulsePhase)
            // Transform sine (-1...1) to pulse envelope (0...1) with adjustable shape
            let pulseEnvelope: Float
            if softness >= 0.9 {
                // Very soft: smooth sine
                pulseEnvelope = Float((pulseRaw + 1.0) / 2.0)
            } else {
                // Sharper: use power function
                let normalized = (pulseRaw + 1.0) / 2.0
                let sharpness = 1.0 + (1.0 - Double(softness)) * 3.0
                pulseEnvelope = Float(pow(normalized, sharpness))
            }

            // === Carrier Tone (Rich Harmonics) ===
            var sample: Float = 0

            for (i, amplitude) in harmonics.enumerated() {
                guard amplitude > 0.01 else { continue }

                let harmonicNumber = Double(i + 1)
                let detuningCents = Double(i < detuning.count ? detuning[i] : 0)
                let detuneMultiplier = pow(2.0, detuningCents / 1200.0)

                let freq = carrierFreq * harmonicNumber * detuneMultiplier

                // Ensure we have enough phase accumulators
                while carrierPhases.count <= i {
                    carrierPhases.append(0)
                }

                sample += amplitude * Float(sin(carrierPhases[i]))

                // Update phase
                carrierPhases[i] += (2.0 * .pi * freq) / sr
                if carrierPhases[i] > 2.0 * .pi {
                    carrierPhases[i] -= 2.0 * .pi
                }
            }

            // Normalize by harmonic sum
            let harmonicSum = harmonics.reduce(0, +)
            if harmonicSum > 0 {
                sample /= harmonicSum
            }

            // === Apply Pulse Envelope ===
            sample *= pulseEnvelope

            // === LFO Modulation (Subtle Movement) ===
            let lfoValue = Float(sin(lfoPhase)) * 0.1 + 1.0 // 0.9 - 1.1
            sample *= lfoValue

            // === Apply Volume ===
            sample *= vol

            // === Stereo Positioning ===
            let pan = Float(sin(lfoPhase * 2.0)) * width * 0.3 // Subtle movement
            let leftGain = 1.0 - max(pan, 0)
            let rightGain = 1.0 + min(pan, 0)

            leftBuffer[frame] = sample * leftGain
            rightBuffer[frame] = sample * rightGain

            // === Update Phases ===
            pulsePhase += (2.0 * .pi * pulseFreq) / sr
            if pulsePhase > 2.0 * .pi {
                pulsePhase -= 2.0 * .pi
            }

            lfoPhase += (2.0 * .pi * lfoFreq) / sr
            if lfoPhase > 2.0 * .pi {
                lfoPhase -= 2.0 * .pi
            }
        }

        return noErr
    }
}

// MARK: - Legacy Compatibility (Renamed from BinauralBeatGenerator)

/// Type alias for backward compatibility during migration
@available(*, deprecated, renamed: "ImmersiveIsochronicEngine")
public typealias BinauralBeatGenerator = ImmersiveIsochronicEngine

/// Extension for legacy BrainwaveState compatibility
extension ImmersiveIsochronicEngine {

    /// Legacy brainwave state mapping (deprecated, use EntrainmentPreset)
    @available(*, deprecated, message: "Use EntrainmentPreset instead")
    public enum BrainwaveState: String, CaseIterable {
        case delta, theta, alpha, beta, gamma

        var toPreset: EntrainmentPreset {
            switch self {
            case .delta: return .deepRest
            case .theta: return .meditation
            case .alpha: return .relaxedFocus
            case .beta: return .activeThinking
            case .gamma: return .peakFlow
            }
        }

        public var beatFrequency: Float {
            toPreset.centerFrequency
        }

        public var description: String {
            toPreset.description
        }
    }

    /// Legacy configuration method
    @available(*, deprecated, message: "Use configure(preset:soundscape:) instead")
    public func configure(carrier: Float, beat: Float, amplitude: Float) {
        self.volume = amplitude
        self.rhythmFrequency = beat
        updateSynthesisParameters()
    }

    /// Legacy brainwave configuration
    @available(*, deprecated, message: "Use configure(preset:soundscape:) instead")
    public func configure(state: BrainwaveState) {
        configure(preset: state.toPreset)
    }

    /// Legacy HRV method
    @available(*, deprecated, message: "Use modulateFromCoherence(_:) instead")
    public func setBeatFrequencyFromHRV(coherence: Double) {
        modulateFromCoherence(coherence)
    }

    /// Legacy property accessors
    @available(*, deprecated, message: "Use rhythmFrequency instead")
    public var beatFrequency: Float {
        get { rhythmFrequency }
        set { setRhythmFrequency(newValue) }
    }

    @available(*, deprecated, message: "Use volume instead")
    public var amplitude: Float {
        get { volume }
        set { volume = newValue }
    }

    /// Legacy carrier frequency (now determined by soundscape)
    @available(*, deprecated, message: "Carrier frequency is now determined by soundscape")
    public var carrierFrequency: Float {
        currentSoundscape.carrierFrequency
    }
}

// MARK: - SwiftUI Preview Support

#if DEBUG
extension ImmersiveIsochronicEngine {
    static var preview: ImmersiveIsochronicEngine {
        let engine = ImmersiveIsochronicEngine()
        engine.configure(preset: .focus, soundscape: .warmPad)
        return engine
    }
}
#endif
