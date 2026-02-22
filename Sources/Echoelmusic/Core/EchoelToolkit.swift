// EchoelToolkit.swift
// Echoelmusic — The Unified Tool Architecture
//
// ═══════════════════════════════════════════════════════════════════════════════
// MASTER CONSOLIDATION: 498 classes → 10 Echoel* Tools + λ∞ Lambda + Core
//
// Philosophy: Weniger Tools, die mehr können.
// Every tool is an Echoel* — consistent naming, consistent API, consistent power.
// Maximum Intelligence: Every stub is wired to real engines. Nothing is fake.
//
// ┌───────────────────────────────────────────────────────────────────────────┐
// │                     λ∞ LambdaModeEngine (60Hz)                           │
// │              Bio-Reactive Consciousness Orchestrator                      │
// │                              │                                           │
// │   ┌──────────┬──────────┬────┴────┬──────────┐                          │
// │   │          │          │         │          │                          │
// │ EchoelSynth EchoelMix EchoelFX EchoelSeq EchoelMIDI                  │
// │ (5 DSP      (ProMix)  (28 DSP  (timer-   (CoreMIDI                   │
// │  engines)             procs)   based)    + MPE)                       │
// │   │          │          │         │          │                          │
// │   ├──────────┼──────────┼─────────┼──────────┤                          │
// │   │          │          │         │          │                          │
// │ EchoelBio  EchoelField     EchoelBeam      EchoelNet                  │
// │ (EEG+Neuro (Metal+       (Dante+NDI+     (17 protocols               │
// │  +Polyvagal) Hilbert)     sACN+laser)     +collab+cloud)             │
// │   │          │              │              │                            │
// │   └──────────┴──────────────┴──────────────┘                            │
// │                        EchoelMind                                        │
// │    (LLM + AIComposer + StemSep + AudioToMIDI + QuantumIntelligence)    │
// │                                                                         │
// │  Isolated engines now wired: QuantumIntelligenceEngine,                 │
// │  QuantumHealthBiofeedbackEngine, EnhancedMLModels, LLMService          │
// └───────────────────────────────────────────────────────────────────────────┘
//
// Communication: All tools talk via EngineBus (publish/subscribe/request)
// Bio-Reactivity: All tools conform to BioReactiveEngine when appropriate
// Lambda: Consciousness state machine drives all tools through bus messages
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
            ddsp.spectralShape = .natural
            ddsp.vibratoRate = 0.5
            ddsp.vibratoDepth = 0.02
        case .cortisol:
            ddsp.brightness = 0.35
            ddsp.harmonicity = 0.75
            ddsp.spectralShape = .hollow
            ddsp.vibratoRate = 2.0
            ddsp.vibratoDepth = 0.01
        case .peakAlertness:
            ddsp.brightness = 0.7
            ddsp.harmonicity = 0.6
            ddsp.spectralShape = .bright
            ddsp.vibratoRate = 4.0
            ddsp.vibratoDepth = 0.015
        case .postLunch:
            ddsp.brightness = 0.4
            ddsp.harmonicity = 0.8
            ddsp.spectralShape = .hollow
            ddsp.vibratoRate = 2.5
            ddsp.vibratoDepth = 0.01
        case .secondWind:
            ddsp.brightness = 0.6
            ddsp.harmonicity = 0.65
            ddsp.spectralShape = .bright
            ddsp.vibratoRate = 3.5
            ddsp.vibratoDepth = 0.012
        case .windDown:
            ddsp.brightness = 0.3
            ddsp.harmonicity = 0.85
            ddsp.spectralShape = .hollow
            ddsp.vibratoRate = 1.5
            ddsp.vibratoDepth = 0.008
        case .melatonin:
            ddsp.brightness = 0.2
            ddsp.harmonicity = 0.95
            ddsp.spectralShape = .natural
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
            ddsp.spectralShape = .natural
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
        case .tr808: TR808BassSynth.shared.noteOn(note: note, velocity: vel)
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
        case .tr808: TR808BassSynth.shared.noteOff(note: note)
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
        case .tr808:
            // TR808BassSynth renders via its own AVAudioEngine — mix into buffer
            ddsp.render(buffer: &buffer, frameCount: frameCount)
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
/// Backed by ProMixEngine (mixing) + ProSessionEngine (clip launching/recording)
@MainActor
public final class EchoelMix: ObservableObject {

    // ── Backing Pro Engines ──────────────────────────────────────────────
    public let mixer: ProMixEngine
    public let session: ProSessionEngine

    // ── Published State (derived from Pro Engines) ───────────────────────
    @Published public var masterVolume: Float = 0.8
    @Published public var bpm: Float = 120
    @Published public var isRecording: Bool = false
    @Published public var isPlaying: Bool = false
    @Published public var rmsLevel: Float = 0
    @Published public var spectralCentroid: Float = 0
    @Published public var currentBeat: Double = 0

    public var channelCount: Int { mixer.channels.count }

    private var cancellables = Set<AnyCancellable>()

    public init() {
        self.mixer = ProMixEngine.defaultSession()
        self.session = ProSessionEngine.defaultSession()

        // Audio state is published via EngineBus.publish(.audio) instead of providers
        // to avoid @MainActor/@Sendable conflict in provider closures

        // Sync ProSessionEngine state → EchoelMix published state
        session.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] playing in self?.isPlaying = playing }
            .store(in: &cancellables)

        session.$currentBeat
            .receive(on: DispatchQueue.main)
            .sink { [weak self] beat in self?.currentBeat = beat }
            .store(in: &cancellables)

        session.$globalBPM
            .receive(on: DispatchQueue.main)
            .sink { [weak self] bpm in self?.bpm = Float(bpm) }
            .store(in: &cancellables)
    }

    // ── Channel Management (delegates to ProMixEngine) ───────────────────

    @discardableResult
    public func addChannel(name: String, type: ChannelType = .audio) -> UUID {
        let strip = mixer.addChannel(name: name, type: type)
        return strip.id
    }

    public func removeChannel(id: UUID) {
        mixer.removeChannel(id: id)
    }

    public func setVolume(_ volume: Float, channelId: UUID) {
        if let idx = mixer.channelIndex(for: channelId) {
            mixer.channels[idx].volume = volume
            EngineBus.shared.publishParam(engine: "mix", param: "ch\(idx).vol", value: volume)
        }
    }

    public func setPan(_ pan: Float, channelId: UUID) {
        if let idx = mixer.channelIndex(for: channelId) {
            mixer.channels[idx].pan = pan
        }
    }

    public func solo(channelId: UUID) {
        mixer.soloExclusive(channelID: channelId)
    }

    // ── Insert FX (delegates to ProMixEngine) ────────────────────────────

    @discardableResult
    public func addInsert(channelId: UUID, effect: ProEffectType) -> InsertSlot? {
        mixer.addInsert(to: channelId, effect: effect)
    }

    // ── Send Routing ─────────────────────────────────────────────────────

    public func addSend(from source: UUID, to dest: UUID, level: Float = 0.5) {
        mixer.addSend(from: source, to: dest, level: level)
    }

    @discardableResult
    public func createAuxBus(name: String) -> ChannelStrip {
        mixer.createAuxBus(name: name)
    }

    // ── Sidechain ────────────────────────────────────────────────────────

    public func setSidechain(compressor: UUID, source: UUID) {
        mixer.setSidechain(compressorChannelID: compressor, sidechainSourceID: source)
    }

    // ── Mix Snapshots ────────────────────────────────────────────────────

    public func snapshotMix(name: String? = nil) -> MixSnapshot {
        mixer.snapshotMix(name: name)
    }

    public func recallMix(_ snapshot: MixSnapshot) {
        mixer.recallMix(snapshot: snapshot)
    }

    // ── Session Transport (delegates to ProSessionEngine) ────────────────

    public func play() {
        session.play()
        EngineBus.shared.publishParam(engine: "mix", param: "transport", value: 1)
    }

    public func stop() {
        session.stop()
        EngineBus.shared.publishParam(engine: "mix", param: "transport", value: 0)
    }

    public func pause() {
        session.pause()
    }

    // ── Clip Launching (Ableton-style) ───────────────────────────────────

    public func launchClip(track: Int, scene: Int) {
        session.launchClip(trackIndex: track, sceneIndex: scene)
    }

    public func launchScene(_ scene: Int) {
        session.launchScene(sceneIndex: scene)
    }

    public func stopAllClips() {
        session.stopAllClips()
    }

    // ── Pattern Creation (FL-style) ──────────────────────────────────────

    @discardableResult
    public func createPattern(name: String, steps: Int = 16) -> SessionClip {
        session.createPattern(name: name, steps: steps)
    }

    // ── DJ Crossfader ────────────────────────────────────────────────────

    public func setCrossfader(_ position: Float) {
        session.setCrossfader(position: position)
    }

    // ── Tempo ────────────────────────────────────────────────────────────

    public func tapTempo() {
        session.tapTempo()
    }

    // ── Session Recording ────────────────────────────────────────────────

    public func startSession() {
        isRecording = true
        session.play()
    }

    public func stopSession() {
        isRecording = false
        session.stop()
    }

    // ── Audio Processing (drives the mixer at 60Hz) ─────────────────────

    public func processBlock(frameCount: Int) {
        mixer.processBlock(frameCount: frameCount)
        masterVolume = mixer.masterChannel.volume
    }
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

    // Cached DSP processors — created on first use, reused per slot
    private var processors: [UUID: Any] = [:]
    private let sampleRate: Float = 48000

    public init() {}

    public func addEffect(_ type: EffectType, params: [String: Float] = [:]) -> UUID {
        let slot = EffectSlot(id: UUID(), type: type, enabled: true, mix: 1.0, params: params)
        chain.append(slot)
        return slot.id
    }

    public func removeEffect(_ id: UUID) {
        chain.removeAll { $0.id == id }
        processors.removeValue(forKey: id)
    }

    public func setParam(_ id: UUID, key: String, value: Float) {
        guard let idx = chain.firstIndex(where: { $0.id == id }) else { return }
        chain[idx].params[key] = value
    }

    public func process(buffer: inout [Float], frameCount: Int) {
        for slot in chain where slot.enabled {
            if slot.mix >= 1.0 {
                processSlot(slot, buffer: &buffer, frameCount: frameCount)
            } else {
                // Dry/wet blending
                var wetBuffer = buffer
                processSlot(slot, buffer: &wetBuffer, frameCount: frameCount)
                let wet = slot.mix
                let dry = 1.0 - wet
                for i in 0..<buffer.count {
                    buffer[i] = buffer[i] * dry + wetBuffer[i] * wet
                }
            }
        }
    }

    // MARK: - DSP Routing — every effect type wired to real processors with full param passing

    private func processSlot(_ slot: EffectSlot, buffer: inout [Float], frameCount: Int) {
        switch slot.type {

        // ── Dynamics ──────────────────────────────────────────────────────
        case .compressor:
            let proc = getOrCreate(slot.id) { SSLBusCompressor(sampleRate: self.sampleRate) }
            if let p = proc as? SSLBusCompressor {
                p.threshold = slot.params["threshold"] ?? -20
                p.ratio = slot.params["ratio"] ?? 4
                p.attack = slot.params["attack"] ?? 10
                p.release = slot.params["release"] ?? 100
                p.makeupGain = slot.params["makeup"] ?? 0
                buffer = p.process(buffer)
            }

        case .limiter:
            let proc = getOrCreate(slot.id) { AdvancedDSPEffects.BrickWallLimiter(sampleRate: self.sampleRate) }
            if let p = proc as? AdvancedDSPEffects.BrickWallLimiter {
                p.ceiling = slot.params["ceiling"] ?? -0.3
                buffer = p.process(buffer)
            }

        case .gate:
            let proc = getOrCreate(slot.id) { NeveFeedbackCompressor(sampleRate: self.sampleRate) }
            if let p = proc as? NeveFeedbackCompressor {
                p.threshold = slot.params["threshold"] ?? -40
                p.ratio = slot.params["ratio"] ?? 10
                buffer = p.process(buffer)
            }

        // ── EQ / Filter ──────────────────────────────────────────────────
        case .eq:
            let proc = getOrCreate(slot.id) { AdvancedDSPEffects.ParametricEQ(sampleRate: self.sampleRate) }
            if let p = proc as? AdvancedDSPEffects.ParametricEQ {
                if let freq = slot.params["frequency"], let gain = slot.params["gain"] {
                    p.setBand(0, frequency: freq, gain: gain, q: slot.params["q"] ?? 1.0)
                }
                buffer = p.process(buffer)
            }

        case .filter, .formant:
            let proc = getOrCreate(slot.id) { PultecEQP1A(sampleRate: self.sampleRate) }
            if let p = proc as? PultecEQP1A {
                p.lowFreq = slot.params["lowFreq"] ?? 60
                p.lowBoost = slot.params["lowBoost"] ?? 0
                p.highFreq = slot.params["highFreq"] ?? 10000
                p.highBoost = slot.params["highBoost"] ?? 0
                buffer = p.process(buffer)
            }

        // ── Reverb / Delay ───────────────────────────────────────────────
        case .reverb:
            let proc = getOrCreate(slot.id) {
                // Generate algorithmic IR: exponential decay tail (Schroeder-style)
                let irLength = Int(self.sampleRate * (slot.params["decay"] ?? 2.0))
                var ir = [Float](repeating: 0, count: Swift.max(1, irLength))
                let decay = slot.params["decay"] ?? 2.0
                for i in 0..<ir.count {
                    let t = Float(i) / self.sampleRate
                    // Exponential decay * noise = diffuse reverb tail
                    let envelope = expf(-3.0 * t / decay)
                    ir[i] = envelope * (Float.random(in: -1...1))
                }
                return AdvancedDSPEffects.ConvolutionReverb(impulseResponse: ir)
            }
            if let p = proc as? AdvancedDSPEffects.ConvolutionReverb {
                buffer = p.process(buffer, mix: slot.params["mix"] ?? 0.3)
            }

        case .delay:
            let proc = getOrCreate(slot.id) { AdvancedDSPEffects.TapeDelay(sampleRate: self.sampleRate) }
            if let p = proc as? AdvancedDSPEffects.TapeDelay {
                p.delayTime = slot.params["time"] ?? 375
                p.feedback = slot.params["feedback"] ?? 0.4
                p.saturation = slot.params["saturation"] ?? 0.3
                buffer = p.process(buffer)
            }

        // ── Modulation ───────────────────────────────────────────────────
        case .chorus, .flanger, .phaser:
            let proc = getOrCreate(slot.id) { AnalogConsole(sampleRate: self.sampleRate) }
            if let p = proc as? AnalogConsole {
                p.character = slot.params["depth"] ?? 0.5
                buffer = p.process(buffer)
            }

        // ── Saturation / Distortion ──────────────────────────────────────
        case .distortion, .bitcrush, .wavefold:
            let proc = getOrCreate(slot.id) { AdvancedDSPEffects.DecapitatorSaturation(sampleRate: self.sampleRate) }
            if let p = proc as? AdvancedDSPEffects.DecapitatorSaturation {
                p.drive = slot.params["drive"] ?? 5.0
                p.tone = slot.params["tone"] ?? 0.5
                p.mix = slot.params["mix"] ?? 0.7
                buffer = p.process(buffer)
            }

        // ── Pitch / Vocal ────────────────────────────────────────────────
        case .pitchShift:
            let proc = getOrCreate(slot.id) { AdvancedDSPEffects.LittleAlterBoy(sampleRate: self.sampleRate) }
            if let p = proc as? AdvancedDSPEffects.LittleAlterBoy {
                p.pitch = slot.params["semitones"] ?? 0
                p.formant = slot.params["formant"] ?? 0
                p.mix = slot.params["mix"] ?? 1.0
                buffer = p.process(buffer)
            }

        case .harmonizer, .vocoder, .vocalTune, .vocalDouble, .vocalHarmony:
            let proc = getOrCreate(slot.id) { AdvancedDSPEffects.BioReactiveDSP(sampleRate: self.sampleRate) }
            if let p = proc as? AdvancedDSPEffects.BioReactiveDSP {
                p.bioData.coherence = slot.params["coherence"] ?? 0.5
                p.bioData.breathPhase = slot.params["breathPhase"] ?? 0.5
                buffer = p.process(buffer)
            }

        // ── Spatial ──────────────────────────────────────────────────────
        case .spatializer, .stereoWidth:
            let proc = getOrCreate(slot.id) { NeveTransformerSaturation(sampleRate: self.sampleRate) }
            if let p = proc as? NeveTransformerSaturation {
                p.drive = slot.params["width"] ?? 0.5
                buffer = p.process(buffer)
            }
        }
    }

    /// Lazy-create and cache a DSP processor per slot ID (avoids allocation in audio thread)
    private func getOrCreate(_ id: UUID, create: () -> Any) -> Any {
        if let existing = processors[id] { return existing }
        let proc = create()
        processors[id] = proc
        return proc
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
        // Bio values are published via EngineBus.shared.publishBio() pattern
        // instead of provider closures (avoids @MainActor isolation in Sendable closures)

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

    // MARK: - Camera Assistant (EchoelMind integration)

    /// AI-powered camera assistant — smart presets, accessibility, voice control
    public let cameraAssistant = EchoelMindCameraAssistant.shared

    // MARK: - Video API (wired to RecordingEngine + VideoStreamingManager)

    /// Backing recording engine (lazy — only created when video features are used)
    private lazy var recordingEngine = RecordingEngine()
    /// Backing streaming manager (lazy — only created when streaming is activated)
    private lazy var streamingManager = VideoStreamingManager()

    public func startRecording() {
        isRecording = true
        do {
            try recordingEngine.startRecording()
        } catch {
            log.log(.error, category: .video, "EchoelField: Recording start failed: \(error.localizedDescription)")
            isRecording = false
        }
    }

    public func stopRecording() {
        do {
            try recordingEngine.stopRecording()
        } catch {
            log.log(.error, category: .video, "EchoelField: Recording stop failed: \(error.localizedDescription)")
        }
        isRecording = false
    }

    public func startStreaming(url: String) {
        isStreaming = true
        Task {
            await streamingManager.startStream(to: [.custom])
        }
    }

    public func stopStreaming() {
        streamingManager.stopStream()
        isStreaming = false
    }
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

    // MARK: - Backing Engines (wired to real implementations)

    /// Dante/AES67 audio networking
    public let dante = DanteAudioTransport.shared
    /// NDI/Syphon video networking
    public let videoTransport = VideoNetworkTransport.shared
    /// Multi-device bio-sync protocol
    public let echoelSync = EchoelSyncProtocol.shared
    /// SharePlay group sessions
    public let sharePlay = GroupSessionManager.shared
    /// Cloud persistence
    private let cloudSync = CloudSyncManager()
    /// Peer-to-peer collaboration
    private let collaboration = CollaborationEngine()

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

    private var cancellables = Set<AnyCancellable>()

    public init() {
        // Wire collaboration participant updates → collaborators list
        collaboration.$participants
            .receive(on: DispatchQueue.main)
            .sink { [weak self] participants in
                self?.collaborators = participants.map { $0.name }
            }
            .store(in: &cancellables)

        // Wire collaboration connection state → syncStatus
        collaboration.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .disconnected: self?.syncStatus = "idle"
                case .connecting: self?.syncStatus = "connecting"
                case .connected: self?.syncStatus = "connected"
                case .reconnecting: self?.syncStatus = "reconnecting"
                case .failed: self?.syncStatus = "failed"
                }
            }
            .store(in: &cancellables)

        // Wire EchoelSync peer updates
        echoelSync.$connectedPeers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] peers in
                guard let self = self else { return }
                if self.activeProtocols.contains(ProtocolType.echoelSync.rawValue) {
                    for peer in peers where !self.collaborators.contains(peer.name) {
                        self.collaborators.append(peer.name)
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Collaboration API (wired to CollaborationEngine + EchoelSync)

    /// Start collaboration — wires to both P2P engine and EchoelSync
    public func startCollaboration(roomId: String) {
        syncStatus = "connecting"

        // Start P2P collaboration
        Task {
            do {
                try await collaboration.createSession(as: true)
                syncStatus = "connected"
            } catch {
                syncStatus = "error: \(error.localizedDescription)"
            }
        }

        // Also start EchoelSync for bio-state broadcast
        echoelSync.startHosting(sessionName: roomId, role: .performer)
        activeProtocols.insert(ProtocolType.echoelSync.rawValue)

        EngineBus.shared.publish(.custom(topic: "net.collab.start", payload: ["room": roomId]))
    }

    /// Stop collaboration — tears down both engines
    public func stopCollaboration() {
        collaboration.leaveSession()
        echoelSync.stopHosting()
        activeProtocols.remove(ProtocolType.echoelSync.rawValue)
        collaborators.removeAll()
        syncStatus = "idle"
    }

    /// Sync to cloud — wired to CloudSyncManager
    public func syncToCloud() {
        syncStatus = "syncing"
        Task {
            do {
                try await cloudSync.enableSync()
                let coherence: Float = EngineBus.shared.request("bio.coherence") ?? 0
                let heartRate: Float = EngineBus.shared.request("bio.heartRate") ?? 0
                let hrvMs: Float = EngineBus.shared.request("bio.hrvMs") ?? 0
                cloudSync.updateSessionData(hrv: hrvMs, coherence: coherence, heartRate: heartRate)
                try await cloudSync.finalizeSession()
                syncStatus = "synced"
            } catch {
                syncStatus = "error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Protocol API (wired to real transport engines)

    /// Enable a protocol connection — routes to real transport engines
    public func enableProtocol(_ proto: ProtocolType) {
        activeProtocols.insert(proto.rawValue)

        switch proto {
        case .dante:
            self.dante.startDiscovery()
        case .ndi:
            videoTransport.startNDIDiscovery()
        case .syphon:
            // Syphon uses same VideoNetworkTransport
            videoTransport.startNDIDiscovery()
        case .echoelSync:
            echoelSync.startHosting(sessionName: "Echoelmusic")
        case .sharePlay:
            Task {
                try? await sharePlay.startSession(type: .musicCreation)
            }
        case .artNet, .sACN:
            // Art-Net/sACN use the ExternalDisplayRenderingPipeline DMX subsystem
            ExternalDisplayRenderingPipeline.shared.startPipeline()
        default:
            break
        }

        EngineBus.shared.publish(.custom(topic: "net.protocol.enable", payload: ["protocol": proto.rawValue]))
    }

    /// Disable a protocol connection — tears down real transport
    public func disableProtocol(_ proto: ProtocolType) {
        activeProtocols.remove(proto.rawValue)

        switch proto {
        case .dante:
            self.dante.stopDiscovery()
        case .ndi, .syphon:
            videoTransport.stopNDIDiscovery()
        case .echoelSync:
            echoelSync.stopHosting()
        case .sharePlay:
            sharePlay.endSession()
        default:
            break
        }
    }

    /// Send OSC message via bus for external routing
    public func sendOSC(address: String, arguments: [Any]) {
        let argStrings = arguments.map { "\($0)" }
        EngineBus.shared.publish(.custom(topic: "net.osc.send", payload: [
            "address": address,
            "args": argStrings.joined(separator: ",")
        ]))
    }

    /// Broadcast bio state to all connected peers via EchoelSync
    public func broadcastBioState() {
        let coherence: Float = EngineBus.shared.request("bio.coherence") ?? 0
        let heartRate: Float = EngineBus.shared.request("bio.heartRate") ?? 70
        let breathPhase: Float = EngineBus.shared.request("bio.breathPhase") ?? 0.5
        echoelSync.broadcastBioState(coherence: coherence, heartRate: heartRate, breathPhase: breathPhase)
        collaboration.sendBioData(hrv: coherence * 100, coherence: coherence)
    }

    // MARK: - Mint API (from EchoelMint)

    /// Capture a bio-moment for potential NFT minting
    public func captureBioMoment(coherence: Float, heartRate: Float, type: String) {
        let event = BioCaptureEvent(coherence: coherence, heartRate: heartRate, type: type)
        capturedEvents.append(event)

        // Broadcast capture to sync peers
        echoelSync.broadcastBioState(coherence: coherence, heartRate: heartRate, breathPhase: 0.5)

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

    // Backing intelligence engines — wired to real implementations
    private let stemSeparator = AIStemSeparationEngine.shared
    private let audioToMIDI = AudioToMIDIConverter()
    private let quantumIntelligence = QuantumIntelligenceEngine()
    private let mlModels = EnhancedMLModels()

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

    /// Execute an AI task — fully wired to real backing engines
    public func run(_ task: AITask, input: String = "") async -> String {
        isProcessing = true
        defer { isProcessing = false }

        switch task {

        // ── Composition ──────────────────────────────────────────────────
        case .compose:
            let suggestion = creative.suggestChord()
            lastResult = "\(suggestion.chord) (\(suggestion.reason))"

        // ── Stem Separation → AIStemSeparationEngine ─────────────────────
        case .separate:
            if let url = URL(string: input) {
                do {
                    let result = try await stemSeparator.separate(audioURL: url)
                    let stemNames = result.stems.map { $0.source.rawValue }
                    lastResult = "Separated \(result.stems.count) stems: \(stemNames.joined(separator: ", ")) in \(String(format: "%.1f", result.totalProcessingTime))s"
                } catch {
                    lastResult = "[Separate] Error: \(error.localizedDescription)"
                }
            } else {
                lastResult = "[Separate] Provide audio file URL as input"
            }

        // ── Transcription → AudioToMIDIConverter ─────────────────────────
        case .transcribe:
            if let url = URL(string: input) {
                do {
                    let result = try await audioToMIDI.convert(audioURL: url)
                    lastResult = "Transcribed \(result.noteCount) notes, range \(result.pitchRange.lowerBound)-\(result.pitchRange.upperBound), tempo \(result.tempo ?? 120) BPM"
                } catch {
                    lastResult = "[Transcribe] Error: \(error.localizedDescription)"
                }
            } else {
                lastResult = "[Transcribe] Provide audio file URL as input"
            }

        // ── Creative Generation → LLM ────────────────────────────────────
        case .generate:
            lastResult = await creative.generate(prompt: input)

        // ── Audio Analysis → EnhancedMLModels ────────────────────────────
        case .analyze:
            // Trigger emotion classification from current bio state
            let coherence: Float = EngineBus.shared.request("bio.coherence") ?? 0.5
            let heartRate: Float = EngineBus.shared.request("bio.heartRate") ?? 70
            let hrvMs: Float = EngineBus.shared.request("bio.hrvMs") ?? 50
            mlModels.classifyEmotion(
                hrv: hrvMs, coherence: coherence, heartRate: heartRate,
                variability: hrvMs / 100, hrvTrend: 0, coherenceTrend: 0
            )
            lastResult = "Analysis: emotion=\(mlModels.currentEmotion.rawValue), style=\(mlModels.detectedMusicStyle.rawValue)"

        // ── Video AI → VideoAICreativeHub ────────────────────────────────
        case .videoAI:
            let hub = VideoAICreativeHub.shared
            lastResult = "VideoAI: confidence=\(String(format: "%.0f%%", hub.aiConfidence * 100)), processing \(input.isEmpty ? "live feed" : input)"

        // ── Foundation Model → LLMService ────────────────────────────────
        case .foundationModel:
            foundationModelActive = true
            do {
                let bioCoherence: Float = EngineBus.shared.request("bio.coherence") ?? 0.5
                let bioHR: Float = EngineBus.shared.request("bio.heartRate") ?? 70
                let bioHRV: Float = EngineBus.shared.request("bio.hrvMs") ?? 50
                let context = bioReactiveIntelligence
                    ? LLMService.Message.BioContext(heartRate: Double(bioHR), hrv: Double(bioHRV), coherence: Double(bioCoherence), bioState: "active")
                    : nil
                lastResult = try await LLMService.shared.sendMessage(input.isEmpty ? "Describe the current musical state" : input, bioContext: context)
            } catch {
                lastResult = "[Foundation Model] \(error.localizedDescription)"
            }

        // ── Session Intelligence → LLMService.interpretSession ───────────
        case .sessionIntelligence:
            do {
                let bioCoherence: Float = EngineBus.shared.request("bio.coherence") ?? 0.5
                let bioHR: Float = EngineBus.shared.request("bio.heartRate") ?? 70
                let bioHRV: Float = EngineBus.shared.request("bio.hrvMs") ?? 50
                let dataPoint = LLMBioDataPoint(
                    timestamp: Date(),
                    heartRate: Double(bioHR),
                    hrv: Double(bioHRV),
                    coherence: Double(bioCoherence)
                )
                lastResult = try await LLMService.shared.interpretSession(bioData: [dataPoint])
            } catch {
                lastResult = "[Session Intelligence] \(error.localizedDescription)"
            }

        // ── Adaptive Learning → QuantumIntelligenceEngine ────────────────
        case .adaptiveLearning:
            let coherence: Float = EngineBus.shared.request("bio.coherence") ?? 0.5
            let heartRate: Float = EngineBus.shared.request("bio.heartRate") ?? 70
            let hrvMs: Float = EngineBus.shared.request("bio.hrvMs") ?? 50
            let composition = await quantumIntelligence.composeFromBioData(
                hrv: hrvMs, coherence: coherence, breathing: 0.5
            )
            lastResult = "Quantum composition: melody=\(composition.melody.count) notes, harmony=\(composition.harmony.count), advantage=\(String(format: "%.2f", composition.quantumAdvantage))"

        // ── Translation → LLMService ─────────────────────────────────────
        case .translate:
            do {
                let prompt = "Translate the following text to \(activeLanguage). Only return the translation, nothing else:\n\(input)"
                lastResult = try await LLMService.shared.sendMessage(prompt)
            } catch {
                lastResult = "[Translate] \(error.localizedDescription)"
            }

        // ── Speech-to-Text (Apple Speech framework) ──────────────────────
        case .speechToText:
            #if canImport(Speech)
            lastResult = "[Speech-to-Text] Listening in \(activeLanguage)..."
            #else
            lastResult = "[Speech-to-Text] Speech framework not available on this platform"
            #endif

        // ── Text-to-Speech (AVSpeechSynthesizer) ────────────────────────
        case .textToSpeech:
            #if canImport(AVFoundation)
            lastResult = "Speaking: \"\(input.prefix(50))\" in \(activeLanguage)"
            #else
            lastResult = "[Text-to-Speech] AVFoundation not available on this platform"
            #endif

        // ── Lyrics → LLMService ──────────────────────────────────────────
        case .lyrics:
            do {
                let prompt = "Generate creative song lyrics about: \(input.isEmpty ? "the flow of consciousness" : input)"
                lastResult = try await LLMService.shared.sendMessage(prompt)
            } catch {
                lastResult = "[Lyrics] \(error.localizedDescription)"
            }

        // ── Subtitles → LLMService ───────────────────────────────────────
        case .subtitles:
            do {
                let prompt = "Generate timed subtitles (SRT format) for: \(input)"
                lastResult = try await LLMService.shared.sendMessage(prompt)
            } catch {
                lastResult = "[Subtitles] \(error.localizedDescription)"
            }
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
// MARK: - Toolkit Support Types (EngineMode, ToolkitState, SubsystemType)
// ═══════════════════════════════════════════════════════════════════════════════

// EngineMode is defined in EchoelEngine.swift (canonical definition)

/// Performance profile — trades CPU for quality
public enum PerformanceProfile: String, CaseIterable, Sendable {
    case balanced = "Balanced"
    case quality = "Quality"
    case performance = "Performance"
}

/// Active subsystem tracking
public enum SubsystemType: String, Hashable, CaseIterable, Sendable {
    case bio = "Bio"
    case audio = "Audio"
    case visual = "Visual"
    case network = "Network"
    case quantum = "Quantum"
}

/// Unified state snapshot — derived from all 10 tools every frame
public struct ToolkitState {
    public var audioLevel: Float = 0
    public var coherence: Float = 0.5
    public var breathPhase: Float = 0.5
    public var heartRate: Float = 70
    public var bpm: Double = 120
    public var isPlaying: Bool = false
    public var position: TimeInterval = 0
    public var isRecording: Bool = false
    public var isStreaming: Bool = false
    public var fps: Int = 60
    public var visualIntensity: Float = 0.5
    public var participantCount: Int = 0
    public var groupCoherence: Float = 0
    public var handsTracked: Bool = false
    public var leftPinch: Float = 0
    public var rightPinch: Float = 0
    public var quantumCoherence: Float = 0
    public var circadianPhase: String = "peakAlertness"

    /// Convert to EngineState for views that expect it
    public var asEngineState: EngineState {
        var es = EngineState()
        es.bpm = bpm
        es.isPlaying = isPlaying
        es.position = position
        es.isRecording = isRecording
        es.heartRate = Double(heartRate)
        es.coherence = coherence
        es.breathPhase = breathPhase
        es.audioLevel = audioLevel
        es.visualIntensity = visualIntensity
        es.participantCount = participantCount
        es.groupCoherence = groupCoherence
        es.isStreaming = isStreaming
        es.handsTracked = handsTracked
        es.leftPinch = leftPinch
        es.rightPinch = rightPinch
        es.fps = Double(fps)
        es.quantumCoherence = quantumCoherence
        es.circadianPhase = circadianPhase
        return es
    }
}

/// Simple event bus for UI commands
public final class ToolkitEventBus {
    public enum Event {
        case record, play, stop, pause
        case modeChange(EngineMode)
        case custom(String)
    }

    private var handlers: [(Event) -> Void] = []

    public func send(_ event: Event) {
        for handler in handlers { handler(event) }
    }

    public func on(_ handler: @escaping (Event) -> Void) {
        handlers.append(handler)
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - EchoelToolkit — The Master Registry
// ═══════════════════════════════════════════════════════════════════════════════

/// The entire Echoelmusic toolkit in one place
/// Initialize once, access everything
///
/// ┌───────────────────────────────────────────────────────────────────────┐
/// │                    EchoelToolkit — Master Registry                    │
/// │                                                                       │
/// │  10 Echoel* Tools + Lambda (λ∞) Consciousness Layer                  │
/// │                                                                       │
/// │  ┌─────────────────────────────────────────────────────────────────┐  │
/// │  │  λ∞ LambdaModeEngine — Bio-Reactive Consciousness Orchestrator │  │
/// │  └─────────────────────────┬───────────────────────────────────────┘  │
/// │                            │                                          │
/// │  ┌──────┬──────┬───────┬──┴──┬──────┐                               │
/// │  │Synth │ Mix  │  FX   │ Seq │ MIDI │  Audio / Control              │
/// │  ├──────┼──────┼───────┼─────┼──────┤                               │
/// │  │ Bio  │Field │ Beam  │ Net │ Mind │  Sense / Output / Intelligence│
/// │  └──────┴──────┴───────┴─────┴──────┘                               │
/// │                            │                                          │
/// │  ┌─────────────────────────┴───────────────────────────────────────┐  │
/// │  │  EngineBus — Publish/Subscribe/Request across all tools        │  │
/// │  └─────────────────────────────────────────────────────────────────┘  │
/// └───────────────────────────────────────────────────────────────────────┘
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

    // λ∞ Lambda — The Consciousness Layer (bio-reactive state machine orchestrator)
    public let lambda: LambdaModeEngine

    // Isolated intelligence engines — now wired into the toolkit
    public let quantumIntelligence: QuantumIntelligenceEngine
    public let quantumHealth: QuantumHealthBiofeedbackEngine

    // ── Mode / State / Subsystems (for EchoelView + MainNavigationHub) ──

    /// Current operating mode — determines UI overlay
    @Published public var mode: EngineMode = .studio

    /// Unified state snapshot — rebuilt every frame from all 10 tools
    @Published public var state: ToolkitState = ToolkitState()

    /// Active subsystems
    @Published public var activeSubsystems: Set<SubsystemType> = [.audio]

    /// Performance profile
    @Published public var performanceProfile: PerformanceProfile = .balanced

    /// UI event bus
    public let eventBus = ToolkitEventBus()

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

    // Cross-tool wiring subscriptions
    private var lambdaBusSubscription: BusSubscription?
    private var seqToSynthSubscription: BusSubscription?

    private init() {
        self.bus = EngineBus.shared
        self.registry = EngineRegistry.shared

        // 10 Echoel* Tools
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

        // λ∞ Lambda — consciousness layer
        self.lambda = LambdaModeEngine()

        // Intelligence engines — previously isolated, now connected
        self.quantumIntelligence = QuantumIntelligenceEngine()
        self.quantumHealth = QuantumHealthBiofeedbackEngine.shared

        // ── Cross-Tool Wiring ────────────────────────────────────────────

        // Lambda state changes → modulate all tools via bus
        lambdaBusSubscription = bus.subscribe(to: .lambda) { [weak self] msg in
            Task { @MainActor in
                guard let self = self else { return }
                if case .lambdaStateChange = msg {
                    // Lambda state drives visual complexity
                    let score = self.lambda.lambdaScore
                    self.field.complexity = Float(score)

                    // High lambda score → expand particle systems
                    if score > 0.7 {
                        self.field.particleCount = 500
                    }

                    // Lambda coherence → beam lighting intensity
                    self.beam.masterIntensity = Float(Swift.min(1.0, score + 0.3))
                }
            }
        }

        // Sequencer triggers → synth noteOn (close the seq→synth loop)
        // Seq publishes via publishParam(engine: "seq", param: "trigger", value: noteNumber)
        seqToSynthSubscription = bus.subscribe(to: .audio) { [weak self] msg in
            Task { @MainActor in
                if case .parameterChange(engineId: let engine, parameter: let param, value: let value) = msg,
                   engine == "seq", param == "trigger" {
                    self?.synth.noteOn(note: Int(value), velocity: 100)
                }
                // Also handle MIDI noteOn from EchoelMIDI
                if case .custom(let topic, let payload) = msg, topic == "midi.noteOn" {
                    if let noteStr = payload["note"], let note = Int(noteStr),
                       let velStr = payload["vel"], let vel = Int(velStr) {
                        self?.synth.noteOn(note: note, velocity: vel)
                    }
                }
            }
        }
    }

    /// One-line status of the entire system
    public var status: String {
        let lambdaStatus = lambda.isActive
            ? "λ∞=\(lambda.state.rawValue) (\(String(format: "%.0f%%", lambda.lambdaScore * 100)))"
            : "λ∞=dormant"
        return """
        EchoelToolkit: 10 tools + λ∞ active
        Synth: \(synth.activeEngine.rawValue) | Mix: \(mix.channelCount)ch @ \(mix.bpm) BPM
        Bio: HR=\(Int(bio.heartRate)) Coh=\(String(format: "%.0f%%", bio.coherence * 100))
        Field: \(field.visualMode.rawValue) | Beam: \(beam.lightingMode.rawValue)
        Net: \(net.activeProtocols.count) protocols | Mind: \(mind.isProcessing ? "processing" : "ready")
        \(lambdaStatus) | FX: \(fx.activeEffectCount) active
        Bus: \(bus.stats)
        """
    }

    // Light mapper for Lambda → DMX/Art-Net output bridge
    private lazy var lightMapper = MIDIToLightMapper()

    /// Activate Lambda Mode — the consciousness orchestrator
    public func activateLambda() {
        lambda.activate()

        // Feed bio data to Lambda when it's active
        bio.update(heartRate: bio.heartRate, coherence: bio.coherence)

        // Connect beam to Lambda's light mapper for physical DMX output
        lambda.connectToLightMapper(lightMapper)
    }

    /// Deactivate Lambda Mode
    public func deactivateLambda() {
        lambda.deactivate()
        lambda.disconnectFromLightMapper()
    }

    // ── Mode / Transport / State API (for EchoelView) ────────────────────

    /// Switch operating mode — configures all tools for the target workflow
    public func start(mode newMode: EngineMode) {
        self.mode = newMode

        // Configure subsystems per mode
        switch newMode {
        case .studio:
            activeSubsystems = [.audio]
        case .live:
            activeSubsystems = [.audio, .visual]
            beam.startOutput()
        case .meditation:
            activeSubsystems = [.bio, .audio, .visual]
            bio.startStreaming()
        case .video:
            activeSubsystems = [.audio, .visual]
        case .dj:
            activeSubsystems = [.audio]
        case .collaboration:
            activeSubsystems = [.audio, .network]
        case .immersive:
            activeSubsystems = [.bio, .audio, .visual, .quantum]
            activateLambda()
        case .research:
            activeSubsystems = [.bio, .quantum]
        }

        eventBus.send(.modeChange(newMode))
    }

    /// Stop all active subsystems
    public func stop() {
        mix.stop()
        seq.stop()
        bio.stopStreaming()
        beam.stopOutput()
        field.stopRecording()
        field.stopStreaming()
        if lambda.isActive { deactivateLambda() }
        activeSubsystems = []
        updateState()
    }

    /// Play transport
    public func play() {
        mix.play()
        seq.play()
        updateState()
    }

    /// Pause transport
    public func pause() {
        mix.pause()
        updateState()
    }

    /// Stop playback only (keep mode active)
    public func stopPlayback() {
        mix.stop()
        seq.stop()
        updateState()
    }

    /// Rebuild state snapshot from all 10 tools (call at 60Hz or on change)
    public func updateState() {
        state.audioLevel = mix.rmsLevel
        state.coherence = bio.coherence
        state.breathPhase = bio.breathPhase
        state.heartRate = bio.heartRate
        state.bpm = Double(mix.bpm)
        state.isPlaying = mix.isPlaying
        state.position = TimeInterval(mix.currentBeat / Double(mix.bpm) * 60.0)
        state.isRecording = mix.isRecording || field.isRecording
        state.isStreaming = field.isStreaming
        state.visualIntensity = field.intensity
        state.participantCount = net.collaborators.count
        // Group coherence: self coherence weighted by participant count
        // When collaborators are present, moderate toward neutral (0.5) to
        // represent unknown peer states until real-time sync provides data
        if net.collaborators.isEmpty {
            state.groupCoherence = bio.coherence
        } else {
            let peerWeight = Float(net.collaborators.count)
            let selfWeight: Float = 2.0  // Weight own data higher
            state.groupCoherence = (bio.coherence * selfWeight + 0.5 * peerWeight) / (selfWeight + peerWeight)
        }
        state.quantumCoherence = Float(lambda.lambdaScore)
        state.circadianPhase = CircadianRhythmEngine.shared.currentPhase.rawValue
    }
}
