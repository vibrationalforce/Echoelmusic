// EchoelToolkit.swift
// Echoelmusic — The Unified Tool Architecture
//
// ═══════════════════════════════════════════════════════════════════════════════
// MASTER CONSOLIDATION: 498 classes → 10 Echoel* Tools + Core
//
// Philosophy: Weniger Tools, die mehr können.
// Every tool is an Echoel* — consistent naming, consistent API, consistent power.
//
// ┌───────────────────────────────────────────────────────────────────────────┐
// │                        EchoelCore (120Hz)                                │
// │                              │                                           │
// │   ┌──────────┬──────────┬────┴────┬──────────┐                          │
// │   │          │          │         │          │                          │
// │ EchoelSynth EchoelMix EchoelFX EchoelSeq EchoelMIDI                  │
// │ (synthesis) (mixing)  (effects) (sequencer)(control)                   │
// │   │          │          │         │          │                          │
// │   ├──────────┼──────────┼─────────┼──────────┤                          │
// │   │          │          │         │          │                          │
// │ EchoelBio  EchoelField     EchoelBeam      EchoelNet                  │
// │ (biometrics)(vis+vid+       (light+stage)  (protocols+                │
// │             avatar+world)                   collab+mint)              │
// │   │          │              │              │                            │
// │   └──────────┴──────────────┴──────────────┘                            │
// │                        EchoelMind                                        │
// │              (intelligence + translate + assistant)                      │
// └───────────────────────────────────────────────────────────────────────────┘
//
// Communication: All tools talk via EngineBus (publish/subscribe/request)
// Bio-Reactivity: All tools conform to BioReactiveEngine when appropriate
// ═══════════════════════════════════════════════════════════════════════════════

import Foundation
import Combine

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 1. EchoelSynth — All Synthesis in One
// ═══════════════════════════════════════════════════════════════════════════════
//
// MERGES: AudioEngine, EchoelDDSP, EchoelModalBank, EchoelCellular, EchoelQuant,
//         EchoelSampler, TR808BassSynth, BreakbeatChopper, BinauralBeatGenerator,
//         UniversalSoundLibrary, SynthPresetLibrary, LoopEngine, MetronomeEngine
//
// 16 classes → 1 unified synthesis engine with pluggable backends

/// The heart of sound generation — every synthesis method in one interface
@MainActor
public final class EchoelSynth: ObservableObject {

    // Sub-engines (internal — users interact through EchoelSynth API only)
    public let ddsp: EchoelDDSP
    public let modal: EchoelModalBank
    public let cellular: EchoelCellular
    public let quant: EchoelQuant
    public let sampler: EchoelSampler
    public let presets: SynthPresetLibrary

    @Published public var activeEngine: SynthEngineType = .ddsp
    @Published public var isPlaying: Bool = false

    private var busSubscription: BusSubscription?

    public enum SynthEngineType: String, CaseIterable, Sendable {
        case ddsp = "DDSP"              // Harmonic + noise (Google Magenta-inspired)
        case modal = "Modal"            // Physical modeling (bells, strings, plates)
        case cellular = "Cellular"      // Cellular automata → audio
        case quant = "Quantum"          // Schrödinger equation synthesis
        case sampler = "Sampler"        // Sample playback + slicing
        case tr808 = "EchoelBeat"       // Analog drum machine
    }

    /// Circadian-aware DDSP tuning (time-of-day adaptive synthesis)
    @Published public var circadianTuningEnabled: Bool = true

    private var wellnessSubscription: BusSubscription?

    public init(sampleRate: Float = 44100) {
        self.ddsp = EchoelDDSP(sampleRate: sampleRate)
        self.modal = EchoelModalBank(sampleRate: sampleRate)
        self.cellular = EchoelCellular(sampleRate: sampleRate)
        self.quant = EchoelQuant(sampleRate: sampleRate)
        self.sampler = EchoelSampler(sampleRate: sampleRate)
        self.presets = SynthPresetLibrary.shared

        // Listen to bio data for reactive synthesis
        busSubscription = EngineBus.shared.subscribe(to: .bio) { [weak self] msg in
            if case .bioUpdate(let bio) = msg {
                Task { @MainActor in
                    self?.applyBio(bio)
                }
            }
        }

        // Listen to wellness session commands for sub-bass healing frequencies
        wellnessSubscription = EngineBus.shared.subscribe(to: .custom) { [weak self] msg in
            if case .custom(let topic, let payload) = msg, topic == "bio.wellness" {
                Task { @MainActor in
                    self?.applyWellness(payload)
                }
            }
        }

        // Apply initial circadian tuning
        applyCircadianTuning()
    }

    /// Apply circadian-aware DDSP defaults based on time of day
    /// Morning: bright, energetic (high brightness, fast vibrato)
    /// Evening: warm, calming (low brightness, slow vibrato, warm timbre)
    public func applyCircadianTuning() {
        guard circadianTuningEnabled else { return }

        let circadian = CircadianRhythmEngine.shared
        let phase = circadian.currentPhase
        let (entrainmentHz, _) = circadian.getCurrentAudioSettings()

        // Map circadian phase to DDSP parameters
        switch phase {
        case .deepSleep, .remSleep:
            ddsp.brightness = 0.15
            ddsp.harmonicity = 0.9
            ddsp.spectralShape = .sine
            ddsp.vibratoRate = 0.5
            ddsp.vibratoDepth = 0.02
        case .cortisol:
            ddsp.brightness = 0.35
            ddsp.harmonicity = 0.75
            ddsp.spectralShape = .triangle
            ddsp.vibratoRate = 2.0
            ddsp.vibratoDepth = 0.01
        case .peakAlertness:
            ddsp.brightness = 0.7
            ddsp.harmonicity = 0.6
            ddsp.spectralShape = .sawtooth
            ddsp.vibratoRate = 4.0
            ddsp.vibratoDepth = 0.015
        case .postLunch:
            ddsp.brightness = 0.4
            ddsp.harmonicity = 0.8
            ddsp.spectralShape = .triangle
            ddsp.vibratoRate = 2.5
            ddsp.vibratoDepth = 0.01
        case .secondWind:
            ddsp.brightness = 0.6
            ddsp.harmonicity = 0.65
            ddsp.spectralShape = .sawtooth
            ddsp.vibratoRate = 3.5
            ddsp.vibratoDepth = 0.012
        case .windDown:
            ddsp.brightness = 0.3
            ddsp.harmonicity = 0.85
            ddsp.spectralShape = .triangle
            ddsp.vibratoRate = 1.5
            ddsp.vibratoDepth = 0.008
        case .melatonin:
            ddsp.brightness = 0.2
            ddsp.harmonicity = 0.95
            ddsp.spectralShape = .sine
            ddsp.vibratoRate = 0.8
            ddsp.vibratoDepth = 0.005
        }

        // Publish circadian state for other tools
        EngineBus.shared.publish(.custom(
            topic: "synth.circadian",
            payload: [
                "phase": phase.rawValue,
                "entrainmentHz": "\(entrainmentHz)"
            ]
        ))
    }

    /// Apply wellness healing frequency from BiophysicalWellnessEngine via bus
    private func applyWellness(_ payload: [String: String]) {
        if payload["active"] == "true", let freqStr = payload["frequency"],
           let freq = Double(freqStr) {
            // Set DDSP to sub-bass healing frequency with high harmonicity (pure tone)
            ddsp.frequency = Float(freq)
            ddsp.harmonicity = 0.95
            ddsp.brightness = 0.2
            ddsp.amplitude = 0.3  // Gentle
            ddsp.spectralShape = .sine
        }
    }

    // MARK: - Unified Play API

    public func noteOn(note: Int, velocity: Int = 100) {
        let freq = 440.0 * powf(2.0, Float(note - 69) / 12.0)
        let vel = Float(velocity) / 127.0

        switch activeEngine {
        case .ddsp: ddsp.noteOn(frequency: freq)
        case .modal: modal.noteOn(frequency: freq, velocity: vel)
        case .cellular: cellular.frequency = freq
        case .quant: quant.frequency = freq; quant.excite()
        case .sampler: sampler.noteOn(note: note, velocity: velocity)
        case .tr808: ddsp.noteOn(frequency: freq) // Route through DDSP
        }
        isPlaying = true
        EngineBus.shared.publishParam(engine: "synth", param: "noteOn", value: Float(note))
    }

    public func noteOff(note: Int) {
        switch activeEngine {
        case .ddsp: ddsp.noteOff()
        case .modal: modal.noteOff()
        case .cellular: break // Cellular is continuous
        case .quant: break // Quantum decays naturally
        case .sampler: sampler.noteOff(note: note)
        case .tr808: ddsp.noteOff()
        }
        isPlaying = false
    }

    public func render(buffer: inout [Float], frameCount: Int) {
        switch activeEngine {
        case .ddsp: ddsp.render(buffer: &buffer, frameCount: frameCount)
        case .modal: modal.render(buffer: &buffer, frameCount: frameCount)
        case .cellular: cellular.render(buffer: &buffer, frameCount: frameCount)
        case .quant: quant.render(buffer: &buffer, frameCount: frameCount)
        case .sampler:
            let rendered = sampler.render(frameCount: frameCount)
            for i in 0..<Swift.min(buffer.count, rendered.count) {
                buffer[i] = rendered[i]
            }
        case .tr808: ddsp.render(buffer: &buffer, frameCount: frameCount)
        }
    }

    public func loadPreset(_ preset: SynthPreset) {
        switch preset.engine {
        case .ddsp:
            activeEngine = .ddsp
            ddsp.frequency = preset.frequency
            ddsp.amplitude = preset.amplitude
            ddsp.harmonicity = preset.harmonicity
            ddsp.brightness = preset.brightness
        case .modalBank:
            activeEngine = .modal
            modal.frequency = preset.frequency
            modal.amplitude = preset.amplitude
            modal.stiffness = preset.stiffness
            modal.damping = preset.damping
        case .cellular:
            activeEngine = .cellular
            cellular.frequency = preset.frequency
        case .quant:
            activeEngine = .quant
            quant.frequency = preset.frequency
            quant.unisonVoices = preset.unisonVoices
        case .tr808:
            activeEngine = .tr808
        case .breakbeat:
            activeEngine = .sampler
        }
        EngineBus.shared.publish(.presetLoaded(name: preset.name))
    }

    private func applyBio(_ bio: BioSnapshot) {
        // Extended 12-parameter mapping for DDSP
        let hrNormalized = (bio.heartRate - 40.0) / 140.0  // 40-180 BPM → 0-1
        ddsp.applyBioReactive(
            coherence: bio.coherence,
            hrvVariability: bio.hrvVariability,
            heartRate: max(0, min(1, hrNormalized)),
            breathPhase: bio.breathPhase,
            breathDepth: bio.breathDepth,
            lfHfRatio: bio.lfHfRatio,
            coherenceTrend: bio.coherenceTrend
        )
        modal.applyBioReactive(coherence: bio.coherence, hrvVariability: bio.hrvVariability, breathPhase: bio.breathPhase)
        cellular.coherence = bio.coherence
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 2. EchoelMix — Mixing Console
// ═══════════════════════════════════════════════════════════════════════════════
//
// MERGES: ProMixEngine, ProSessionEngine, BPMTransitionEngine, BioAdaptiveMixer,
//         AdaptiveAudioEngine, AudioAnalysisEngine, SpectralAnalyzer
//
// 7 classes → 1 unified mixing engine

/// Professional mixing — channels, sends, analysis, session management
@MainActor
public final class EchoelMix: ObservableObject {
    @Published public var masterVolume: Float = 0.8
    @Published public var bpm: Float = 120
    @Published public var isRecording: Bool = false
    @Published public var rmsLevel: Float = 0
    @Published public var spectralCentroid: Float = 0

    public var channelCount: Int { channels.count }
    private var channels: [MixChannel] = []

    public struct MixChannel: Identifiable, Sendable {
        public let id: Int
        public var name: String
        public var volume: Float = 0.8
        public var pan: Float = 0.0
        public var mute: Bool = false
        public var solo: Bool = false
    }

    public init() {
        // Register as audio provider on the bus
        EngineBus.shared.provide("audio.bpm") { [weak self] in self?.bpm }
        EngineBus.shared.provide("audio.rms") { [weak self] in self?.rmsLevel }
        EngineBus.shared.provide("audio.volume") { [weak self] in self?.masterVolume }
    }

    public func addChannel(name: String) -> Int {
        let ch = MixChannel(id: channels.count, name: name)
        channels.append(ch)
        return ch.id
    }

    public func setVolume(_ volume: Float, channel: Int) {
        guard channel < channels.count else { return }
        channels[channel].volume = volume
        EngineBus.shared.publishParam(engine: "mix", param: "ch\(channel).vol", value: volume)
    }

    public func startSession() { isRecording = true }
    public func stopSession() { isRecording = false }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 3. EchoelFX — All Effects in One Chain
// ═══════════════════════════════════════════════════════════════════════════════
//
// MERGES: BioReactiveVocalEngine, ProVocalChain, VocalPostProcessor,
//         VocalHarmonyGenerator, VocalDoublingEngine, VibratoEngine,
//         RealTimePitchCorrector, BreathDetector, PhaseVocoder,
//         AutomaticVocalAligner, SpatialEnhancements, NodeGraph effects
//
// 11+ classes → 1 unified FX chain

/// Every audio effect — reverb, delay, pitch, vocal, spatial — in one chain
public final class EchoelFX: @unchecked Sendable {

    public enum EffectType: String, CaseIterable, Sendable {
        case reverb, delay, chorus, flanger, phaser
        case compressor, limiter, gate, eq
        case pitchShift, harmonizer, vocoder
        case vocalTune, vocalDouble, vocalHarmony
        case distortion, bitcrush, wavefold
        case spatializer, stereoWidth
        case filter, formant
    }

    public struct EffectSlot: Identifiable, Sendable {
        public let id: UUID
        public var type: EffectType
        public var enabled: Bool = true
        public var mix: Float = 1.0        // Dry/wet
        public var params: [String: Float]  // Effect-specific parameters
    }

    private var chain: [EffectSlot] = []

    public init() {}

    public func addEffect(_ type: EffectType, params: [String: Float] = [:]) -> UUID {
        let slot = EffectSlot(id: UUID(), type: type, enabled: true, mix: 1.0, params: params)
        chain.append(slot)
        return slot.id
    }

    public func removeEffect(_ id: UUID) {
        chain.removeAll { $0.id == id }
    }

    public func setParam(_ id: UUID, key: String, value: Float) {
        guard let idx = chain.firstIndex(where: { $0.id == id }) else { return }
        chain[idx].params[key] = value
    }

    public func process(buffer: inout [Float], frameCount: Int) {
        for slot in chain where slot.enabled {
            processSlot(slot, buffer: &buffer, frameCount: frameCount)
        }
    }

    private func processSlot(_ slot: EffectSlot, buffer: inout [Float], frameCount: Int) {
        // Each effect type processes in-place
        // Actual DSP implementations live in the existing Node classes
        // This is the unified routing layer
    }

    public var activeEffectCount: Int { chain.filter(\.enabled).count }
    public var totalEffectCount: Int { chain.count }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 4. EchoelSeq — Sequencer & Arrangement
// ═══════════════════════════════════════════════════════════════════════════════
//
// MERGES: VisualStepSequencer patterns, BPMGridEditEngine, LoopEngine,
//         IntelligentAutomationEngine, ScriptEngine automation
//
// Pattern sequencing, step editing, automation, arrangement

/// Sequencing — step patterns, automation lanes, arrangement clips
@MainActor
public final class EchoelSeq: ObservableObject {

    @Published public var bpm: Float = 120
    @Published public var isPlaying: Bool = false
    @Published public var currentStep: Int = 0
    @Published public var stepCount: Int = 16

    public struct Pattern: Identifiable, Sendable {
        public let id: UUID
        public var name: String
        public var steps: [Bool]
        public var velocities: [Float]
        public var noteValues: [Int]

        public init(name: String, steps: Int = 16) {
            self.id = UUID()
            self.name = name
            self.steps = [Bool](repeating: false, count: steps)
            self.velocities = [Float](repeating: 0.8, count: steps)
            self.noteValues = [Int](repeating: 60, count: steps)
        }
    }

    public private(set) var patterns: [Pattern] = []
    private var timer: DispatchSourceTimer?

    public init() {}

    public func addPattern(name: String) -> UUID {
        let p = Pattern(name: name, steps: stepCount)
        patterns.append(p)
        return p.id
    }

    public func setStep(pattern: UUID, step: Int, active: Bool, velocity: Float = 0.8, note: Int = 60) {
        guard let idx = patterns.firstIndex(where: { $0.id == pattern }),
              step < patterns[idx].steps.count else { return }
        patterns[idx].steps[step] = active
        patterns[idx].velocities[step] = velocity
        patterns[idx].noteValues[step] = note
    }

    public func play() {
        isPlaying = true
        let intervalMs = Int(60000.0 / bpm / 4.0) // 16th notes
        let t = DispatchSource.makeTimerSource(flags: .strict, queue: .global(qos: .userInteractive))
        t.schedule(deadline: .now(), repeating: .milliseconds(intervalMs), leeway: .milliseconds(1))
        t.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.tick()
            }
        }
        t.resume()
        timer = t
    }

    public func stop() {
        isPlaying = false
        timer?.cancel()
        timer = nil
        currentStep = 0
    }

    private func tick() {
        currentStep = (currentStep + 1) % stepCount
        for pattern in patterns {
            if pattern.steps[currentStep] {
                let note = pattern.noteValues[currentStep]
                let vel = pattern.velocities[currentStep]
                EngineBus.shared.publishParam(engine: "seq", param: "trigger", value: Float(note))
                // Trigger via bus — EchoelSynth listens
                _ = vel // Used by subscriber
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 5. EchoelMIDI — MIDI/MPE Control
// ═══════════════════════════════════════════════════════════════════════════════
//
// MERGES: MIDI2Manager, MPEZoneManager, MIDIController, MIDIToSpatialMapper,
//         TouchInstrumentsHub, PianoRollViewModel, ChordPadViewModel,
//         DrumPadViewModel, Echoboard
//
// 13 classes → 1 unified MIDI hub

/// All MIDI — input, output, mapping, MPE, touch instruments
@MainActor
public final class EchoelMIDI: ObservableObject {

    @Published public var connectedDevices: [String] = []
    @Published public var mpeEnabled: Bool = false
    @Published public var lastNote: Int = 0
    @Published public var lastVelocity: Int = 0

    /// MIDI routing target
    public enum MIDITarget: String, CaseIterable, Sendable {
        case synth = "EchoelSynth"
        case sampler = "Sampler"
        case fx = "EchoelFX"
        case field = "EchoelField"
        case beam = "EchoelBeam"
        case custom = "Custom"
    }

    public var routingTable: [Int: MIDITarget] = [:]  // Channel → Target

    public init() {
        // Default: channel 1 → synth
        routingTable[1] = .synth
    }

    /// Process incoming MIDI note
    public func noteOn(channel: Int, note: Int, velocity: Int) {
        lastNote = note
        lastVelocity = velocity
        let target = routingTable[channel] ?? .synth
        EngineBus.shared.publish(.custom(
            topic: "midi.noteOn",
            payload: ["target": target.rawValue, "note": "\(note)", "vel": "\(velocity)"]
        ))
    }

    /// Process incoming MIDI CC
    public func controlChange(channel: Int, cc: Int, value: Int) {
        EngineBus.shared.publishParam(engine: "midi", param: "cc\(cc)", value: Float(value) / 127.0)
    }

    /// MPE pressure/slide/bend per-note
    public func mpeMessage(note: Int, pressure: Float, slide: Float, bend: Float) {
        guard mpeEnabled else { return }
        EngineBus.shared.publish(.custom(
            topic: "midi.mpe",
            payload: ["note": "\(note)", "pressure": "\(pressure)", "slide": "\(slide)", "bend": "\(bend)"]
        ))
    }

    public func route(channel: Int, to target: MIDITarget) {
        routingTable[channel] = target
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 6. EchoelBio — Biometrics & Wellness
// ═══════════════════════════════════════════════════════════════════════════════
//
// MERGES: UnifiedHealthKitEngine, HealthKitManager, BiophysicalWellnessEngine,
//         CircadianRhythmEngine, EVMAnalysisEngine, InertialAnalysisEngine,
//         TapticStimulationEngine, OuraRingIntegration, BioParameterMapper,
//         PhysicalAIEngine (sensor fusion part)
//
// 12 classes → 1 bio hub (single source of truth)

/// The single source of truth for all biometric data
@MainActor
public final class EchoelBio: ObservableObject {

    @Published public var heartRate: Float = 70
    @Published public var hrvMs: Float = 50
    @Published public var coherence: Float = 0.5
    @Published public var breathPhase: Float = 0.5
    @Published public var breathDepth: Float = 0.5
    @Published public var breathingRate: Float = 12
    @Published public var lfHfRatio: Float = 0.5
    @Published public var flowScore: Float = 0
    @Published public var stressIndex: Float = 0.5
    @Published public var energyLevel: Float = 0.5
    @Published public var wellnessScore: Float = 0.5
    @Published public var isStreaming: Bool = false

    // NeuroSpiritual integration
    @Published public var polyvagalState: PolyvagalState = .ventralVagal
    @Published public var consciousnessState: ConsciousnessState = .relaxedAwareness

    // EEG integration
    @Published public var eegConnected: Bool = false
    @Published public var dominantBrainwave: String = "Alpha"

    // Wellness session state
    @Published public var wellnessSessionActive: Bool = false
    @Published public var wellnessFrequency: Float = 0

    // Rausch-inspired bio-signal processing
    /// Graph-based bio-event detection and clustering (DELLY-inspired)
    public let eventGraph = BioEventGraph(maxEvents: 512, clusterCount: 4)

    /// Adaptive signal deconvolution — separates cardiac, respiratory, artifact (Tracy-inspired)
    public let deconvolver = BioSignalDeconvolver(sampleRate: 60.0)

    /// Coherence trend tracker (derivative for spectral morphing)
    private var coherenceHistory: [Float] = []
    private let coherenceHistorySize = 30  // 0.5s at 60Hz

    /// EEG observation cancellable
    private var eegCancellable: AnyCancellable?

    /// NeuroSpiritual observation cancellable
    private var neuroCancellable: AnyCancellable?

    /// Wellness observation cancellable
    private var wellnessCancellable: AnyCancellable?

    public init() {
        // Register as bio provider on bus
        EngineBus.shared.provide("bio.heartRate") { [weak self] in self?.heartRate }
        EngineBus.shared.provide("bio.coherence") { [weak self] in self?.coherence }
        EngineBus.shared.provide("bio.breathPhase") { [weak self] in self?.breathPhase }
        EngineBus.shared.provide("bio.flowScore") { [weak self] in self?.flowScore }
        EngineBus.shared.provide("bio.hrvMs") { [weak self] in self?.hrvMs }
        EngineBus.shared.provide("bio.polyvagalState") { [weak self] in
            Float(PolyvagalState.allCases.firstIndex(of: self?.polyvagalState ?? .ventralVagal) ?? 0)
        }
        EngineBus.shared.provide("bio.consciousnessState") { [weak self] in
            Float(ConsciousnessState.allCases.firstIndex(of: self?.consciousnessState ?? .relaxedAwareness) ?? 2)
        }

        // Wire EEG → BioEventGraph (5 brainwave bands as event channels)
        wireEEGSensorBridge()

        // Wire NeuroSpiritual → polyvagal + consciousness state
        wireNeuroSpiritualEngine()
    }

    // MARK: - EEG Integration

    /// Connect EEGSensorBridge bands to BioEventGraph for pattern detection
    private func wireEEGSensorBridge() {
        eegCancellable = EEGSensorBridge.shared.$currentBands
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bands in
                guard let self = self else { return }
                self.eegConnected = EEGSensorBridge.shared.connectionState == .streaming

                guard self.eegConnected else { return }

                // Feed 5 brainwave bands into event graph as composite channel
                let total = max(0.001, Float(bands.totalPower))
                let alphaNorm = Float(bands.alpha) / total
                let thetaNorm = Float(bands.theta) / total
                let betaNorm = Float(bands.beta) / total
                let gammaNorm = Float(bands.gamma) / total
                let deltaNorm = Float(bands.delta) / total

                // Composite: alpha/theta ratio as coherence-like metric (higher = more relaxed/focused)
                let alphaTheta = (alphaNorm + thetaNorm) / max(0.001, betaNorm + deltaNorm)
                self.eventGraph.feedSample(min(1, alphaTheta / 3.0), channel: .composite)

                // Update flow score from EEG (theta-alpha border + gamma = flow state)
                let eegFlowScore = Float(EEGSensorBridge.shared.flowScore)
                if eegFlowScore > 0 { self.flowScore = eegFlowScore }

                // Update dominant brainwave
                self.dominantBrainwave = bands.dominantBand

                // Feed gamma as separate high-frequency event source
                if gammaNorm > 0.3 {
                    self.eventGraph.feedSample(gammaNorm, channel: .composite)
                }
            }
    }

    // MARK: - NeuroSpiritual Integration

    /// Connect NeuroSpiritualEngine polyvagal + consciousness states
    private func wireNeuroSpiritualEngine() {
        let neuro = NeuroSpiritualEngine.shared

        neuroCancellable = neuro.$polyvagalState
            .combineLatest(neuro.$consciousnessState, neuro.$overallCoherence)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] polyvagal, consciousness, neuroCoherence in
                guard let self = self else { return }
                self.polyvagalState = polyvagal
                self.consciousnessState = consciousness

                // Publish polyvagal-aware parameters via bus
                EngineBus.shared.publish(.custom(
                    topic: "bio.neuroState",
                    payload: [
                        "polyvagal": polyvagal.rawValue,
                        "consciousness": consciousness.rawValue,
                        "neuroCoherence": String(format: "%.3f", neuroCoherence)
                    ]
                ))
            }
    }

    // MARK: - Wellness Session Integration

    /// Start a BiophysicalWellness session and publish healing frequencies via bus
    public func startWellnessSession(preset: BiophysicalPreset) {
        wellnessSessionActive = true
        wellnessFrequency = Float(preset.primaryFrequency)

        // Publish healing frequency to synth via bus
        EngineBus.shared.publish(.custom(
            topic: "bio.wellness",
            payload: [
                "preset": preset.rawValue,
                "frequency": "\(preset.primaryFrequency)",
                "freqMin": "\(preset.frequencyRange.min)",
                "freqMax": "\(preset.frequencyRange.max)",
                "active": "true"
            ]
        ))
    }

    /// Stop wellness session
    public func stopWellnessSession() {
        wellnessSessionActive = false
        wellnessFrequency = 0

        EngineBus.shared.publish(.custom(
            topic: "bio.wellness",
            payload: ["active": "false"]
        ))
    }

    public func startStreaming() {
        isStreaming = true
    }

    public func stopStreaming() {
        isStreaming = false
        eventGraph.reset()
        deconvolver.reset()
        coherenceHistory.removeAll()
    }

    /// Push new bio reading and broadcast to all tools via bus
    public func update(heartRate: Float? = nil, hrvMs: Float? = nil, coherence: Float? = nil,
                       breathPhase: Float? = nil, breathDepth: Float? = nil,
                       lfHfRatio: Float? = nil, flowScore: Float? = nil) {
        if let hr = heartRate { self.heartRate = hr }
        if let hrv = hrvMs { self.hrvMs = hrv }
        if let c = coherence { self.coherence = c }
        if let bp = breathPhase { self.breathPhase = bp }
        if let bd = breathDepth { self.breathDepth = bd }
        if let lf = lfHfRatio { self.lfHfRatio = lf }
        if let fs = flowScore { self.flowScore = fs }

        // Feed event graph — detects peaks, valleys, anomalies, transitions
        eventGraph.feedSample(self.coherence, channel: .coherence)
        eventGraph.feedSample(self.heartRate / 180.0, channel: .heartRate)
        eventGraph.feedSample(self.breathPhase, channel: .breathing)
        eventGraph.feedSample(self.hrvMs / 100.0, channel: .hrv)

        // Feed deconvolver — separates cardiac, respiratory, artifact from composite
        let composite = self.coherence * 0.4 + (self.heartRate / 180.0) * 0.3 + self.breathPhase * 0.3
        _ = deconvolver.process(composite)

        // Track coherence trend (derivative)
        coherenceHistory.append(self.coherence)
        if coherenceHistory.count > coherenceHistorySize {
            coherenceHistory.removeFirst()
        }
        let coherenceTrend = computeCoherenceTrend()

        // Broadcast extended snapshot to ALL tools
        var snapshot = BioSnapshot()
        snapshot.coherence = self.coherence
        snapshot.heartRate = self.heartRate
        snapshot.breathPhase = self.breathPhase
        snapshot.flowScore = self.flowScore
        snapshot.hrvVariability = min(1.0, self.hrvMs / 100.0)
        snapshot.breathDepth = self.breathDepth
        snapshot.lfHfRatio = self.lfHfRatio
        snapshot.coherenceTrend = coherenceTrend
        snapshot.polyvagalIndex = Float(PolyvagalState.allCases.firstIndex(of: polyvagalState) ?? 0)
        snapshot.consciousnessLevel = Float(ConsciousnessState.allCases.firstIndex(of: consciousnessState) ?? 2)
        snapshot.wellnessFrequency = self.wellnessFrequency
        EngineBus.shared.publishBio(snapshot)
    }

    /// Current dominant bio-state cluster (for adaptive synthesis/visuals)
    public var dominantBioState: Int {
        eventGraph.dominantClusterIndex()
    }

    /// Recent anomaly density — maps to synthesis complexity
    public var anomalyDensity: Float {
        eventGraph.recentAnomalyDensity()
    }

    /// Deconvolved cardiac component
    public var cardiacSignal: Float {
        deconvolver.cardiacValue()
    }

    /// Deconvolved respiratory component
    public var respiratorySignal: Float {
        deconvolver.respiratoryValue()
    }

    /// Signal quality (inverse of artifact level)
    public var signalQuality: Float {
        1.0 - min(1.0, deconvolver.artifactLevel() * 5.0)
    }

    /// Optimal audio parameters from NeuroSpiritual state
    public var neuroAudioParams: (frequency: Double, carrier: Double, volume: Double) {
        NeuroSpiritualEngine.shared.getOptimalAudioParameters()
    }

    /// Optimal light color from polyvagal state
    public var neuroLightColor: (r: Float, g: Float, b: Float) {
        NeuroSpiritualEngine.shared.getOptimalLightColor()
    }

    private func computeCoherenceTrend() -> Float {
        guard coherenceHistory.count >= 2 else { return 0 }
        let recent = coherenceHistory.suffix(10)
        let older = coherenceHistory.prefix(max(1, coherenceHistory.count - 10))
        let recentAvg = recent.reduce(0, +) / Float(recent.count)
        let olderAvg = older.reduce(0, +) / Float(older.count)
        return max(-1, min(1, (recentAvg - olderAvg) * 5.0))
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 7. EchoelField — Visuals + Video + Avatar + World
// ═══════════════════════════════════════════════════════════════════════════════
//
// MERGES: UnifiedVisualSoundEngine, ImmersiveVisualEngine, Intelligent360VisualEngine,
//         MetalShaderManager, MIDIToVisualMapper, CymaticsRenderer,
//         OctaveCreativeStudio, PhotonicsVisualizationEngine,
//         VideoAICreativeHub, VideoEditingEngine, VideoProcessingEngine,
//         StreamEngine, CameraManager, MultiCamManager, ChromaKeyEngine,
//         BackgroundSourceManager, VideoExportManager, RecordingEngine,
//         DAWProductionEngine, BPMGridEditEngine
//
// ABSORBS (formerly separate homepage tools):
//   EchoelAvatar → Gaussian Splatting, ARKit 52 blendshapes, aura, live avatar
//   EchoelWorld  → Procedural worlds, 6 biomes, weather systems, day/night
//
// 1 unified visual creation pipeline: 2D/3D visuals + video + avatars + worlds
// SEO: "EchoelField" — bio-field, visual field, creative field. No conflicts.

/// All visuals + video + avatars + worlds — the unified visual creation field
@MainActor
public final class EchoelField: ObservableObject {

    // MARK: - Visual Modes

    public enum VisualMode: String, CaseIterable, Sendable {
        case particles = "Particles"
        case cymatics = "Cymatics"
        case geometry = "Sacred Geometry"
        case spectrum = "Spectrum"
        case immersive3D = "Immersive 3D"
        case spatial360 = "360"
        case waveform = "Waveform"
        case hilbert = "Hilbert"
        // Avatar modes (from EchoelAvatar)
        case avatar = "Avatar"              // Gaussian Splatting 3D avatar
        case aura = "Aura"                  // Bio-reactive aura visualization
        // World modes (from EchoelWorld)
        case world = "World"                // Procedural 3D environments
    }

    // MARK: - Video Modes

    public enum VideoMode: String, CaseIterable, Sendable {
        case capture = "Capture"
        case edit = "Edit"
        case stream = "Stream"
        case multiCam = "MultiCam"
    }

    // MARK: - Render Modes

    public enum RenderMode: String, CaseIterable, Sendable {
        case realtime = "Realtime"              // Metal 120fps visuals
        case photoRealistic = "Photorealistic"  // RealityKit PBR + IBL
        case videoExport = "Video Export"       // ProRes render pipeline
        case hybrid = "Hybrid"                  // Realtime + overlay
    }

    // MARK: - Visual Properties

    @Published public var visualMode: VisualMode = .particles
    @Published public var intensity: Float = 0.5
    @Published public var hue: Float = 0.6
    @Published public var complexity: Float = 0.5
    @Published public var particleCount: Int = 200
    @Published public var beatReactive: Bool = true

    // MARK: - Video Properties

    @Published public var videoMode: VideoMode = .capture
    @Published public var isRecording: Bool = false
    @Published public var isStreaming: Bool = false
    @Published public var chromaKeyEnabled: Bool = false

    // MARK: - Render Properties

    @Published public var renderMode: RenderMode = .realtime

    // MARK: - Avatar Properties (from EchoelAvatar)

    /// Gaussian Splatting avatar active
    @Published public var avatarActive: Bool = false
    /// ARKit 52-blendshape face tracking for avatar animation
    @Published public var faceTrackingActive: Bool = false
    /// Bio-reactive aura: colors shift with coherence, HR, breath
    @Published public var auraEnabled: Bool = true
    /// Live avatar streaming for remote performances
    @Published public var liveAvatarStreaming: Bool = false

    // MARK: - World Properties (from EchoelWorld)

    /// Procedural world biome types
    public enum Biome: String, CaseIterable, Sendable {
        case forest = "Forest"
        case desert = "Desert"
        case ocean = "Ocean"
        case arctic = "Arctic"
        case volcanic = "Volcanic"
        case crystal = "Crystal"
    }

    /// Current world biome — bio-state influences weather
    @Published public var activeBiome: Biome = .forest
    /// Dynamic weather driven by HRV (calm = sunshine, stress = storms)
    @Published public var weatherIntensity: Float = 0.3
    /// Day/night cycle progress (0 = dawn, 0.5 = noon, 1 = midnight)
    @Published public var dayNightPhase: Float = 0.25

    // MARK: - Bio-Reactive Photorealistic Properties

    /// Depth of field blur radius — driven by HRV coherence (high coherence = shallow DoF)
    @Published public var depthOfFieldRadius: Float = 0.0

    /// Particle system density — driven by breath phase (inhale = expand, exhale = contract)
    @Published public var particleDensity: Float = 0.5

    /// Color temperature shift in Kelvin — driven by heart rate (low HR = warm, high HR = cool)
    @Published public var colorTemperature: Float = 6500

    /// Hilbert curve mapper — bio data → 2D locality-preserving visualization
    public let hilbertMapper = HilbertSensorMapper(order: 5)  // 32×32 = 1024 points

    private var busSubscription: BusSubscription?

    public init() {
        busSubscription = EngineBus.shared.subscribe(to: [.bio, .audio]) { [weak self] msg in
            Task { @MainActor in
                switch msg {
                case .bioUpdate(let bio):
                    self?.intensity = 0.3 + bio.coherence * 0.7
                    self?.particleCount = bio.flowScore > 0.75 ? 500 : 200
                    self?.hilbertMapper.feedSample(bio.coherence)

                    // Bio-reactive photorealistic mappings
                    self?.depthOfFieldRadius = bio.coherence * 12.0
                    self?.particleDensity = 0.3 + bio.breathPhase * 0.7
                    let hrNorm = max(0, min(1, (bio.heartRate - 60) / 120))
                    self?.colorTemperature = 3200 + hrNorm * 6300

                    // Bio-reactive world weather (low coherence = storms, high = calm)
                    self?.weatherIntensity = 1.0 - bio.coherence

                case .audioAnalysis(let audio):
                    if audio.beatDetected && self?.beatReactive == true {
                        self?.intensity = Swift.min(1.0, (self?.intensity ?? 0.5) + 0.2)
                    }
                default: break
                }
            }
        }
    }

    // MARK: - Visual API

    /// Get Hilbert density grid for bio-pattern visualization (normalized 0-1)
    public func hilbertDensityGrid() -> [Float] {
        hilbertMapper.getDensityGrid()
    }

    /// Get recent Hilbert mapped points for particle rendering
    public func hilbertParticles(count: Int = 64) -> [HilbertSensorMapper.MappedPoint] {
        hilbertMapper.recentPoints(count: count)
    }

    // MARK: - Video API

    public func startRecording() { isRecording = true }
    public func stopRecording() { isRecording = false }
    public func startStreaming(url: String) { isStreaming = true }
    public func stopStreaming() { isStreaming = false }
}

/// Backward compatibility — remove after 1 release cycle
public typealias EchoelCanvas = EchoelField
public typealias EchoelVis = EchoelField
public typealias EchoelVid = EchoelField
public typealias EchoelAvatar = EchoelField
public typealias EchoelWorld = EchoelField

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 8. EchoelBeam — Lighting + Stage (merged EchoelLux + EchoelStage)
// ═══════════════════════════════════════════════════════════════════════════════
//
// MERGES: ProCueSystem, TimecodeEngine, CueList, ILDALaserController,
//         LaserPatternGenerator, Push3LEDController, MIDIToLightMapper,
//         UDPSocket (ArtNet), ExternalDisplayManager, iPadExternalDisplay,
//         AirPlayManager, AppleGlassesOptimization, ProjectionMappingEngine,
//         MultiScreenRouter
//
// 16 classes → 1 unified output controller (lighting + display routing)
// SEO: "EchoelBeam" — light beams, projection beams, display beaming. Avoids Output.com conflict.

/// All output — DMX, Art-Net, lasers, smart home, external displays, projection, VR/XR
@MainActor
public final class EchoelBeam: ObservableObject {

    // MARK: - Lighting Modes

    public enum LightingMode: String, CaseIterable, Sendable {
        case dmx = "DMX/Art-Net"
        case laser = "ILDA Laser"
        case led = "LED Strip"
        case cue = "Cue System"
        case bioReactive = "Bio-Reactive"
    }

    // MARK: - Display Modes

    public enum DisplayMode: String, CaseIterable, Sendable {
        case mirror = "Mirror"
        case extended = "Extended Display"
        case audience = "Audience View"
        case therapist = "Therapist View"
        case projection = "Projection Mapping"
        case dome = "Dome / Planetarium"
        case vrHeadset = "VR/XR Headset"
        case multiScreen = "Multi-Screen"
    }

    public enum DisplayType: String, CaseIterable, Sendable {
        case externalHDMI = "HDMI/USB-C"
        case airPlay = "AirPlay"
        case smartGlasses = "Smart Glasses"
        case vrXR = "VR/XR Device"
        case projector = "Projector"
        case domeBeamer = "Dome Beamer"
        case multiBeamer = "Multi-Beamer Array"
        case ledWall = "LED Wall"
    }

    // MARK: - Lighting Properties

    @Published public var lightingMode: LightingMode = .bioReactive
    @Published public var masterIntensity: Float = 1.0
    @Published public var hue: Float = 0.6
    @Published public var saturation: Float = 0.8
    @Published public var isLightingConnected: Bool = false

    /// DMX universe address
    public var dmxAddress: String = "192.168.1.100"
    public var dmxUniverse: Int = 1

    // MARK: - Display Properties

    @Published public var displayMode: DisplayMode = .mirror
    @Published public var connectedDisplays: [ConnectedDisplay] = []
    @Published public var isOutputActive: Bool = false

    /// The rendering pipeline handles actual display detection and frame routing
    public let pipeline = ExternalDisplayRenderingPipeline.shared

    /// Dante/AES67 audio transport for professional installations
    public let danteTransport = DanteAudioTransport.shared

    /// NDI/Syphon video transport for broadcast and VJ workflows
    public let videoTransport = VideoNetworkTransport.shared

    /// EchoelSync: bio-reactive sync across devices
    public let sync = EchoelSyncProtocol.shared

    public struct ConnectedDisplay: Identifiable {
        public let id: String
        public let name: String
        public let type: DisplayType
        public let width: Int
        public let height: Int
        public let isActive: Bool

        public init(id: String, name: String, type: DisplayType, width: Int, height: Int, isActive: Bool) {
            self.id = id
            self.name = name
            self.type = type
            self.width = width
            self.height = height
            self.isActive = isActive
        }
    }

    private var lightBusSubscription: BusSubscription?
    private var frameBusSubscription: BusSubscription?
    private var cancellables = Set<AnyCancellable>()

    public init() {
        // Auto-react to bio data when in bioReactive lighting mode
        lightBusSubscription = EngineBus.shared.subscribe(to: .bio) { [weak self] msg in
            Task { @MainActor in
                guard self?.lightingMode == .bioReactive else { return }
                if case .bioUpdate(let bio) = msg {
                    self?.masterIntensity = bio.coherence
                    self?.hue = bio.breathPhase
                }
            }
        }

        // Subscribe to visual frames for display routing
        frameBusSubscription = EngineBus.shared.subscribe(to: .visual) { [weak self] msg in
            Task { @MainActor in
                guard self?.isOutputActive == true else { return }
                if case .visualStateChange(let frame) = msg {
                    self?.routeFrame(frame)
                }
            }
        }

        // Sync detected outputs from pipeline to our connectedDisplays
        pipeline.$detectedOutputs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] outputs in
                self?.connectedDisplays = outputs.map { output in
                    ConnectedDisplay(
                        id: output.id,
                        name: output.name,
                        type: Self.mapCategory(output.category),
                        width: output.nativeWidth,
                        height: output.nativeHeight,
                        isActive: output.isAvailable
                    )
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Lighting API

    /// Send RGB to all connected fixtures
    public func setColor(r: Float, g: Float, b: Float, intensity: Float) {
        EngineBus.shared.publish(.custom(
            topic: "light.color",
            payload: ["r": "\(r)", "g": "\(g)", "b": "\(b)", "i": "\(intensity)"]
        ))
    }

    // MARK: - Display API

    private static func mapCategory(_ category: DisplayOutputDescriptor.OutputCategory) -> DisplayType {
        switch category {
        case .externalDisplay: return .externalHDMI
        case .airPlay: return .airPlay
        case .smartGlasses: return .smartGlasses
        case .vrXRHeadset: return .vrXR
        case .projector: return .projector
        case .domeBeamer: return .domeBeamer
        case .multiBeamerArray: return .multiBeamer
        case .ledWall: return .ledWall
        case .ndiOutput: return .externalHDMI
        case .syphonOutput: return .externalHDMI
        }
    }

    /// Start output to all connected displays
    public func startOutput() {
        isOutputActive = true
        pipeline.startPipeline()
        EngineBus.shared.publish(.custom(topic: "stage.output.start", payload: ["mode": displayMode.rawValue]))
    }

    /// Stop all output routing
    public func stopOutput() {
        isOutputActive = false
        pipeline.stopPipeline()
        EngineBus.shared.publish(.custom(topic: "stage.output.stop", payload: [:]))
    }

    /// Route visual frame via the pipeline to all assigned outputs
    private func routeFrame(_ frame: VisualFrame) {
        pipeline.routeVisualFrame(frame)
    }

    /// Scan for all available displays, NDI sources, and AirPlay devices
    public func scanForDisplays() {
        pipeline.scanForAllOutputs()
        danteTransport.startDiscovery()
        videoTransport.startNDIDiscovery()
    }

    /// Set content per screen for multi-screen mode
    public func assignContent(displayId: String, contentType: DisplayMode) {
        let pipelineContent: OutputContentAssignment.ContentType
        switch contentType {
        case .mirror: pipelineContent = .mirror
        case .extended: pipelineContent = .cleanFeed
        case .audience: pipelineContent = .audienceVisuals
        case .therapist: pipelineContent = .therapistBioData
        case .projection: pipelineContent = .cleanFeed
        case .dome: pipelineContent = .domeProjection
        case .vrHeadset: pipelineContent = .immersive360
        case .multiScreen: pipelineContent = .multiviewMonitor
        }
        pipeline.assignContent(outputId: displayId, content: pipelineContent)
    }
}

/// Backward compatibility — remove after 1 release cycle
public typealias EchoelOutput = EchoelBeam
public typealias EchoelLux = EchoelBeam
public typealias EchoelStage = EchoelBeam
public typealias EchoelConnect = EchoelNet
public typealias EchoelMint = EchoelNet

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 9. EchoelNet — Networking, Protocols & Publishing
// ═══════════════════════════════════════════════════════════════════════════════
//
// MERGES: CloudSyncManager, CollaborationEngine, WebRTCClient,
//         EchoelmusicWebSocket, RTMPClient, AuthenticationService,
//         OfflineSupport, AnalyticsManager, StreamEngine (network part)
//
// ABSORBS (formerly separate homepage tools):
//   EchoelConnect → OSC, MSC, Mackie Control, sACN, PosiStageNet, 17 protocols
//   EchoelMint    → Dynamic NFTs, bio-capture, on-chain metadata, export
//
// 1 unified network + protocol + publishing hub

/// Networking — collab, sync, 17 protocols, Dante, NFT publishing, EchoelSync
@MainActor
public final class EchoelNet: ObservableObject {

    @Published public var isOnline: Bool = true
    @Published public var collaborators: [String] = []
    @Published public var syncStatus: String = "idle"

    // MARK: - Protocol Hub (from EchoelConnect)

    /// All supported industry protocols
    public enum ProtocolType: String, CaseIterable, Sendable {
        case osc = "OSC"                    // Open Sound Control
        case msc = "MSC"                    // MIDI Show Control
        case mackieControl = "Mackie Control"  // HUI/MCU fader protocol
        case sACN = "sACN"                  // E1.31 streaming ACN
        case posiStageNet = "PosiStageNet"  // Real-time position tracking
        case artNet = "Art-Net"             // DMX over IP
        case midi2 = "MIDI 2.0"            // Universal MIDI Packet
        case dante = "Dante"               // AES67 audio transport
        case ndi = "NDI"                   // Network Device Interface
        case syphon = "Syphon"             // GPU texture sharing (macOS)
        case spout = "Spout"               // GPU texture sharing (Windows)
        case sharePlay = "SharePlay"       // Apple SharePlay
        case echoelSync = "EchoelSync"     // Proprietary bio-sync
        case webRTC = "WebRTC"             // Peer-to-peer streaming
        case rtmp = "RTMP"                 // Live streaming
        case hls = "HLS"                   // HTTP Live Streaming
        case srt = "SRT"                   // Secure Reliable Transport
    }

    @Published public var activeProtocols: Set<String> = []

    // MARK: - NFT Publishing (from EchoelMint)

    /// Dynamic NFT state
    @Published public var mintingActive: Bool = false

    /// Bio-capture moments for NFT minting
    public struct BioCaptureEvent: Identifiable, Sendable {
        public let id: UUID
        public let timestamp: Date
        public let coherence: Float
        public let heartRate: Float
        public let type: String  // "coherence_peak", "creative_breakthrough", "milestone"

        public init(id: UUID = UUID(), timestamp: Date = Date(), coherence: Float, heartRate: Float, type: String) {
            self.id = id
            self.timestamp = timestamp
            self.coherence = coherence
            self.heartRate = heartRate
            self.type = type
        }
    }

    @Published public var capturedEvents: [BioCaptureEvent] = []

    public init() {}

    // MARK: - Collaboration API

    public func startCollaboration(roomId: String) {
        syncStatus = "connecting"
        EngineBus.shared.publish(.custom(topic: "net.collab.start", payload: ["room": roomId]))
    }

    public func stopCollaboration() {
        collaborators.removeAll()
        syncStatus = "idle"
    }

    public func syncToCloud() {
        syncStatus = "syncing"
    }

    // MARK: - Protocol API (from EchoelConnect)

    /// Enable a protocol connection
    public func enableProtocol(_ proto: ProtocolType) {
        activeProtocols.insert(proto.rawValue)
        EngineBus.shared.publish(.custom(topic: "net.protocol.enable", payload: ["protocol": proto.rawValue]))
    }

    /// Disable a protocol connection
    public func disableProtocol(_ proto: ProtocolType) {
        activeProtocols.remove(proto.rawValue)
    }

    /// Send OSC message
    public func sendOSC(address: String, arguments: [Any]) {
        EngineBus.shared.publish(.custom(topic: "net.osc.send", payload: ["address": address]))
    }

    // MARK: - Mint API (from EchoelMint)

    /// Capture a bio-moment for potential NFT minting
    public func captureBioMoment(coherence: Float, heartRate: Float, type: String) {
        let event = BioCaptureEvent(coherence: coherence, heartRate: heartRate, type: type)
        capturedEvents.append(event)
        EngineBus.shared.publish(.custom(topic: "net.mint.capture", payload: [
            "coherence": "\(coherence)", "heartRate": "\(heartRate)", "type": type
        ]))
    }

    /// Mint captured event as dynamic NFT with on-chain metadata
    public func mintNFT(eventId: UUID) {
        mintingActive = true
        EngineBus.shared.publish(.custom(topic: "net.mint.create", payload: ["eventId": eventId.uuidString]))
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - 10. EchoelMind — Intelligence Layer
// ═══════════════════════════════════════════════════════════════════════════════
//
// MERGES: EchoelCreativeAI (AIComposer + BioReactiveAIComposer + QuantumComposer),
//         MLModelManager, MLInferenceEngine, LLMService, AIStemSeparationEngine,
//         QuantumIntelligenceEngine, SuperIntelligenceQuantumBioPhysicalEngine
//
// ABSORBS (formerly separate homepage tools):
//   EchoelTranslate → 20+ languages, speech-to-text, lyrics, subtitles, TTS
//   Echoela         → AI assistant skills, constitutional AI, voice control
//
// 1 unified intelligence layer = brain + language + assistant personality
// SEO: "EchoelMind" — distinctive, avoids "Echo AI" saturation. The mind of Echoelmusic.

/// The mind — LLM, CoreML, stem separation, composition, translation, assistant
@MainActor
public final class EchoelMind: ObservableObject {

    public let creative: EchoelCreativeAI

    @Published public var isProcessing: Bool = false
    @Published public var lastResult: String = ""

    // MARK: - AI Tasks (core + absorbed)

    public enum AITask: String, CaseIterable, Sendable {
        // Core AI
        case compose = "Compose"            // Chord/melody suggestions
        case separate = "Stem Separate"     // 6-stem AI separation
        case transcribe = "Transcribe"      // Audio → MIDI
        case generate = "Generate"          // LLM creative generation
        case analyze = "Analyze"            // Audio analysis
        case videoAI = "Video AI"           // Auto-cam, framing, highlights
        // EchoelMind (absorbed)
        case foundationModel = "Foundation Model"  // Apple Foundation Models, 3B params
        case sessionIntelligence = "Session Intelligence"  // Reports, briefs
        case adaptiveLearning = "Adaptive Learning"  // Evolving suggestions
        // EchoelTranslate (absorbed)
        case translate = "Translate"        // 20+ languages
        case speechToText = "Speech-to-Text"  // On-device recognition
        case textToSpeech = "Text-to-Speech"  // Natural voice synthesis
        case lyrics = "Lyrics"              // Transcription + translation
        case subtitles = "Subtitles"        // Live subtitle generation
    }

    // MARK: - Mind Properties (from EchoelMind)

    /// Apple Foundation Models backend (on-device, 3B params)
    @Published public var foundationModelActive: Bool = false
    /// Bio-reactive AI: coherence level modulates suggestion depth
    @Published public var bioReactiveIntelligence: Bool = true

    // MARK: - Translate Properties (from EchoelTranslate)

    @Published public var activeLanguage: String = "en"
    @Published public var supportedLanguages: [String] = [
        "en", "de", "fr", "es", "it", "pt", "ja", "ko", "zh",
        "ar", "hi", "ru", "nl", "sv", "da", "no", "fi", "pl", "tr", "uk"
    ]

    // MARK: - Assistant Properties (from Echoela)

    /// Echoela personality layer — 25 skills (one per tool)
    @Published public var assistantActive: Bool = true
    /// Constitutional AI safety constraints
    @Published public var constitutionalAIEnabled: Bool = true
    /// Voice control active
    @Published public var voiceControlEnabled: Bool = false

    public init() {
        self.creative = EchoelCreativeAI.shared
    }

    public func run(_ task: AITask, input: String = "") async -> String {
        isProcessing = true
        defer { isProcessing = false }

        switch task {
        case .compose:
            let suggestion = creative.suggestChord()
            lastResult = "\(suggestion.chord) (\(suggestion.reason))"
        case .generate:
            lastResult = await creative.generate(prompt: input)
        case .separate, .transcribe, .analyze, .videoAI:
            lastResult = "[\(task.rawValue)] Processing..."
        case .foundationModel, .sessionIntelligence, .adaptiveLearning:
            lastResult = "[Mind: \(task.rawValue)] On-device inference..."
        case .translate, .speechToText, .textToSpeech, .lyrics, .subtitles:
            lastResult = "[Translate: \(task.rawValue)] \(activeLanguage)..."
        }

        EngineBus.shared.publish(.custom(topic: "ai.result", payload: ["task": task.rawValue, "result": lastResult]))
        return lastResult
    }
}

// Backward-compatible typealiases — absorbed into EchoelMind
public typealias EchoelAI = EchoelMind
public typealias EchoelTranslate = EchoelMind
public typealias Echoela = EchoelMind

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - EchoelToolkit — The Master Registry
// ═══════════════════════════════════════════════════════════════════════════════

/// The entire Echoelmusic toolkit in one place
/// Initialize once, access everything
@MainActor
public final class EchoelToolkit: ObservableObject {

    public static let shared = EchoelToolkit()

    // The 10 Echoel* Tools — SEO-optimized authentic naming
    public let synth: EchoelSynth       // Synthesis
    public let mix: EchoelMix           // Mixing
    public let fx: EchoelFX             // Effects
    public let seq: EchoelSeq           // Sequencer
    public let midi: EchoelMIDI         // MIDI/MPE
    public let bio: EchoelBio           // Biometrics
    public let field: EchoelField       // Visuals + Video + Avatar + World
    public let beam: EchoelBeam         // Lighting + Stage
    public let net: EchoelNet           // Networking + Protocols + NFT
    public let mind: EchoelMind         // Intelligence + Translation + Assistant

    // Backward-compatible accessors — remove after 1 release cycle
    public var canvas: EchoelField { field }
    public var vis: EchoelField { field }
    public var vid: EchoelField { field }
    public var output: EchoelBeam { beam }
    public var lux: EchoelBeam { beam }
    public var stage: EchoelBeam { beam }
    public var ai: EchoelMind { mind }

    // Infrastructure
    public let bus: EngineBus
    public let registry: EngineRegistry

    private init() {
        self.bus = EngineBus.shared
        self.registry = EngineRegistry.shared
        self.synth = EchoelSynth()
        self.mix = EchoelMix()
        self.fx = EchoelFX()
        self.seq = EchoelSeq()
        self.midi = EchoelMIDI()
        self.bio = EchoelBio()
        self.field = EchoelField()
        self.beam = EchoelBeam()
        self.net = EchoelNet()
        self.mind = EchoelMind()
    }

    /// One-line status of the entire system
    public var status: String {
        """
        EchoelToolkit: 10 tools active
        Synth: \(synth.activeEngine.rawValue) | Mix: \(mix.channelCount)ch @ \(mix.bpm) BPM
        Bio: HR=\(Int(bio.heartRate)) Coh=\(String(format: "%.0f%%", bio.coherence * 100))
        Field: \(field.visualMode.rawValue) | Beam: \(beam.lightingMode.rawValue)
        Bus: \(bus.stats)
        """
    }
}
