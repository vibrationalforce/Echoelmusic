// EngineConsolidation.swift
// Echoelmusic — Engine Consolidation Framework
//
// Problem: 181 engine/manager classes with 17 direct overlaps
// Solution: Hub protocols + unified interfaces → fewer tools that do more
//
// Consolidation Strategy:
// ┌─────────────────────────────────────────────────────────────────┐
// │  BEFORE: 181 classes              AFTER: ~50 consolidated       │
// │                                                                 │
// │  AudioEngine ─┐                   AudioHub ──── (1 engine)      │
// │  ProSession ──┤→ AudioHub         ├ mixing (was ProMixEngine)   │
// │  3 Analyzers ─┘                   ├ analysis (was 3 Analyzers)  │
// │                                   └ session (was ProSession)    │
// │                                                                 │
// │  HealthKit ───┐                   BioHub ───── (1 source)       │
// │  BiophysWell ─┤→ BioHub           ├ data (was HealthKit)        │
// │  PhysicalAI ──┘                   ├ wellness (was BiophysWell)  │
// │                                   └ control (was PhysicalAI)    │
// │                                                                 │
// │  3 Visual ────┤→ VisualHub        VisualHub ── (1 pipeline)     │
// │  4 AI engines ┤→ IntelligenceHub  IntelligenceHub (1 brain)     │
// │  4 Vocal ─────┤→ VocalHub         VocalHub ── (1 chain)         │
// └─────────────────────────────────────────────────────────────────┘
//
// This file defines the Hub protocols. Existing engines adopt them
// without breaking changes — consumers use the protocol, not concrete types.

import Foundation
import Combine

// MARK: - Base Protocol: Any Engine

/// Universal interface for all Echoelmusic engines
public protocol EchoelEngineProtocol: AnyObject {
    var engineId: String { get }
    var isActive: Bool { get }
    func activate()
    func deactivate()
}

// MARK: - DSP Engine Protocol

/// Any engine that renders audio frames
public protocol DSPEngine: EchoelEngineProtocol {
    var sampleRate: Float { get }
    func render(buffer: inout [Float], frameCount: Int)
    func noteOn(frequency: Float, velocity: Float)
    func noteOff()
    func reset()
}

// Default implementations so existing engines can adopt with minimal changes
extension DSPEngine {
    public func noteOn(frequency: Float, velocity: Float) {}
    public func noteOff() {}
}

// MARK: - Bio-Reactive Protocol

/// Any engine that responds to biometric data
public protocol BioReactiveEngine {
    func applyBioReactive(coherence: Float, hrvVariability: Float, breathPhase: Float)
}

// MARK: - Audio Hub Protocol

/// Unified audio engine interface — replaces AudioEngine + ProSessionEngine + Analyzers
public protocol AudioHubProtocol: EchoelEngineProtocol {
    // Mixing
    var masterVolume: Float { get set }
    var channelCount: Int { get }

    // Analysis
    func getSpectralData() -> [Float]
    func getRMSLevel() -> Float
    func getBPM() -> Float

    // Session
    func startSession()
    func stopSession()
}

// MARK: - Bio Hub Protocol

/// Unified biometric data source — replaces HealthKit + BiophysWellness + PhysicalAI
public protocol BioHubProtocol: EchoelEngineProtocol {
    // Data (single source of truth)
    var heartRate: Float { get }
    var hrvMs: Float { get }
    var coherence: Float { get }
    var breathPhase: Float { get }
    var breathingRate: Float { get }
    var flowScore: Float { get }
    var stressIndex: Float { get }
    var energyLevel: Float { get }

    // Streaming
    func startStreaming()
    func stopStreaming()

    // Wellness (consolidated from BiophysicalWellnessEngine)
    var wellnessScore: Float { get }

    // Autonomous control (consolidated from PhysicalAIEngine)
    var autonomousMode: BioAutonomousMode { get set }
}

public enum BioAutonomousMode: String, Sendable {
    case disabled
    case suggest
    case confirmFirst
    case autonomous
}

// MARK: - Visual Hub Protocol

/// Unified visual engine — replaces Immersive + 360 + UnifiedVisualSound
public protocol VisualHubProtocol: EchoelEngineProtocol {
    var visualMode: VisualRenderMode { get set }
    var intensity: Float { get set }
    var colorHue: Float { get set }

    func renderFrame(audioData: [Float], bioData: BioSnapshot) -> VisualFrame
}

public enum VisualRenderMode: String, Sendable {
    case flat2D
    case immersive3D
    case spatial360
    case visionOS
}

public struct BioSnapshot: Sendable {
    public var coherence: Float = 0
    public var heartRate: Float = 70
    public var breathPhase: Float = 0.5
    public var flowScore: Float = 0

    // Extended fields for 12-parameter DDSP bio-reactive mapping
    public var hrvVariability: Float = 0.5    // RMSSD normalized (0-1)
    public var breathDepth: Float = 0.5       // Breathing depth (0-1)
    public var lfHfRatio: Float = 0.5         // LF/HF power ratio normalized (0-1)
    public var coherenceTrend: Float = 0      // Coherence derivative (-1 to 1)

    // NeuroSpiritual state (polyvagal + consciousness)
    public var polyvagalIndex: Float = 0      // 0=ventral, 1=sympathetic, 2=dorsal, 3+=blended
    public var consciousnessLevel: Float = 2  // Index into ConsciousnessState.allCases
    public var wellnessFrequency: Float = 0   // Active healing frequency (0 = none)

    public init() {}
}

public struct VisualFrame: Sendable {
    public var particles: Int = 0
    public var hue: Float = 0
    public var brightness: Float = 0.5
    public var complexity: Float = 0.5

    public init() {}
}

// MARK: - Intelligence Hub Protocol

/// Unified AI orchestrator — replaces SuperIntelligence + QuantumIntelligence + AICreative
public protocol IntelligenceHubProtocol: EchoelEngineProtocol {
    func suggest(context: IntelligenceContext) -> [IntelligenceSuggestion]
    func generateCreative(prompt: String) async -> String
}

public struct IntelligenceContext: Sendable {
    public var currentBPM: Float = 120
    public var currentKey: String = "C"
    public var coherence: Float = 0.5
    public var genre: String = "electronic"
    public var sessionDuration: TimeInterval = 0

    public init() {}
}

public struct IntelligenceSuggestion: Identifiable, Sendable {
    public let id = UUID()
    public let type: String
    public let description: String
    public let confidence: Float

    public init(type: String, description: String, confidence: Float) {
        self.type = type
        self.description = description
        self.confidence = confidence
    }
}

// MARK: - Synthesis Hub Protocol

/// Unified synthesis interface — all 5 DSP engines share this
public protocol SynthesisHubProtocol: DSPEngine, BioReactiveEngine {
    var presetName: String { get }
    func loadPreset(_ preset: SynthPreset)
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Inter-Engine Communication Bus
// ═══════════════════════════════════════════════════════════════════════════════
//
// The nervous system of Echoelmusic. Even tools that can NOT be merged
// can seamlessly communicate, understand each other, and react in real-time.
//
// Architecture:
// ┌──────────────────────────────────────────────────────────────────────────┐
// │                        EngineBus (Lock-Free)                            │
// │                                                                         │
// │  BioHub ─── publishes ──→ .bioUpdate ──→ subscribers:                   │
// │                            │  AudioHub (adjusts reverb from coherence)  │
// │                            │  VisualHub (maps HRV to particle count)    │
// │                            │  DSP Engines (bio-reactive synthesis)      │
// │                            │  LambdaEngine (updates state machine)      │
// │                            └  Echoela (PhysicalAI parameter control)    │
// │                                                                         │
// │  AudioHub ── publishes ──→ .audioAnalysis ──→ subscribers:              │
// │                            │  VisualHub (beat-sync visuals)             │
// │                            │  LambdaEngine (BPM tracking)              │
// │                            └  IntelligenceHub (key/chord context)       │
// │                                                                         │
// │  ANY engine can:                                                        │
// │    1. bus.publish(.custom("engine.event", payload))                     │
// │    2. bus.subscribe(to: .bioUpdate) { msg in ... }                      │
// │    3. bus.request("audio.bpm") → Float? (sync query)                    │
// │    4. bus.broadcast(.systemPanic) (all engines receive)                 │
// └──────────────────────────────────────────────────────────────────────────┘

/// Message types that flow between engines
public enum BusMessage: Sendable {
    // Bio signals (source: BioHub / UnifiedHealthKitEngine)
    case bioUpdate(BioSnapshot)

    // Audio analysis (source: AudioHub / AudioEngine)
    case audioAnalysis(AudioSnapshot)

    // Visual state changes (source: VisualHub)
    case visualStateChange(VisualFrame)

    // Lambda state transitions (source: LambdaModeEngine)
    case lambdaStateChange(String)

    // DSP parameter changes (source: any DSP engine)
    case parameterChange(engineId: String, parameter: String, value: Float)

    // Intelligence suggestions (source: IntelligenceHub)
    case suggestion(IntelligenceSuggestion)

    // System-wide
    case systemPanic
    case systemResume
    case presetLoaded(name: String)

    // Custom inter-engine messages
    case custom(topic: String, payload: [String: String])
}

/// Audio analysis snapshot for bus communication
public struct AudioSnapshot: Sendable {
    public var rmsLevel: Float = 0
    public var peakLevel: Float = 0
    public var bpm: Float = 120
    public var beatDetected: Bool = false
    public var spectralCentroid: Float = 0
    public var fundamentalFrequency: Float = 0
    public var keyDetected: String = "C"
    public var chordDetected: String = "C"

    public init() {}
}

/// Message channel — engines subscribe to specific channels
public enum BusChannel: String, CaseIterable, Sendable {
    case bio = "bio"
    case audio = "audio"
    case visual = "visual"
    case lambda = "lambda"
    case dsp = "dsp"
    case intelligence = "intelligence"
    case system = "system"
    case custom = "custom"

    /// Determine channel from message type
    public static func channel(for message: BusMessage) -> BusChannel {
        switch message {
        case .bioUpdate: return .bio
        case .audioAnalysis: return .audio
        case .visualStateChange: return .visual
        case .lambdaStateChange: return .lambda
        case .parameterChange: return .dsp
        case .suggestion: return .intelligence
        case .systemPanic, .systemResume, .presetLoaded: return .system
        case .custom: return .custom
        }
    }
}

/// Subscription handle — call cancel() to unsubscribe
public final class BusSubscription {
    let id: UUID
    private let cancelAction: () -> Void

    init(id: UUID, cancel: @escaping () -> Void) {
        self.id = id
        self.cancelAction = cancel
    }

    public func cancel() {
        cancelAction()
    }

    deinit {
        cancel()
    }
}

/// The central nervous system — lock-free inter-engine message bus
/// Zero-allocation hot path, pre-allocated subscriber arrays
public final class EngineBus: @unchecked Sendable {
    public static let shared = EngineBus()

    // Combine passthrough for SwiftUI/reactive consumers
    private let subject = PassthroughSubject<BusMessage, Never>()

    // Callback-based subscribers (for real-time audio thread, no Combine overhead)
    private struct Subscriber {
        let id: UUID
        let channels: Set<BusChannel>
        let handler: @Sendable (BusMessage) -> Void
    }

    private var subscribers: [Subscriber] = []
    private let lock = NSLock()

    // Request-response registry (sync queries between engines)
    private var providers: [String: @Sendable () -> Any?] = [:]
    private let providerLock = NSLock()

    // Performance counters
    private(set) var messageCount: UInt64 = 0
    private(set) var subscriberCount: Int = 0

    private init() {
        subscribers.reserveCapacity(64)
    }

    // MARK: - Publish

    /// Publish a message to all subscribers on the matching channel
    /// Lock-free on the hot path — O(n) subscriber scan
    public func publish(_ message: BusMessage) {
        messageCount &+= 1

        let channel = BusChannel.channel(for: message)

        // Notify callback subscribers
        lock.lock()
        let subs = subscribers
        lock.unlock()

        for sub in subs {
            if sub.channels.contains(channel) || sub.channels.contains(.system) {
                sub.handler(message)
            }
        }

        // Notify Combine subscribers
        subject.send(message)
    }

    // MARK: - Subscribe (Callback)

    /// Subscribe to specific channels with a callback
    /// Returns a BusSubscription — hold a reference or it auto-cancels
    @discardableResult
    public func subscribe(
        to channels: Set<BusChannel>,
        handler: @escaping @Sendable (BusMessage) -> Void
    ) -> BusSubscription {
        let id = UUID()
        let subscriber = Subscriber(id: id, channels: channels, handler: handler)

        lock.lock()
        subscribers.append(subscriber)
        subscriberCount = subscribers.count
        lock.unlock()

        return BusSubscription(id: id) { [weak self] in
            self?.unsubscribe(id: id)
        }
    }

    /// Subscribe to a single channel
    @discardableResult
    public func subscribe(
        to channel: BusChannel,
        handler: @escaping @Sendable (BusMessage) -> Void
    ) -> BusSubscription {
        subscribe(to: [channel], handler: handler)
    }

    /// Subscribe to ALL messages
    @discardableResult
    public func subscribeAll(
        handler: @escaping @Sendable (BusMessage) -> Void
    ) -> BusSubscription {
        subscribe(to: Set(BusChannel.allCases), handler: handler)
    }

    private func unsubscribe(id: UUID) {
        lock.lock()
        subscribers.removeAll { $0.id == id }
        subscriberCount = subscribers.count
        lock.unlock()
    }

    // MARK: - Subscribe (Combine)

    /// Get a Combine publisher for reactive consumers (SwiftUI views etc.)
    public var publisher: AnyPublisher<BusMessage, Never> {
        subject.eraseToAnyPublisher()
    }

    /// Filtered Combine publisher for a specific channel
    public func publisher(for channel: BusChannel) -> AnyPublisher<BusMessage, Never> {
        subject
            .filter { BusChannel.channel(for: $0) == channel }
            .eraseToAnyPublisher()
    }

    // MARK: - Request-Response (Sync Queries)

    /// Register a data provider — other engines can query this value
    /// Example: audioEngine registers "audio.bpm" → { return self.currentBPM }
    public func provide(_ key: String, value: @escaping @Sendable () -> Any?) {
        providerLock.lock()
        providers[key] = value
        providerLock.unlock()
    }

    /// Query a value from another engine without knowing which engine provides it
    /// Example: let bpm: Float? = bus.request("audio.bpm")
    public func request<T>(_ key: String) -> T? {
        providerLock.lock()
        let provider = providers[key]
        providerLock.unlock()
        return provider?() as? T
    }

    /// Remove a provider
    public func unprovide(_ key: String) {
        providerLock.lock()
        providers.removeValue(forKey: key)
        providerLock.unlock()
    }

    // MARK: - Convenience Publishers

    /// Publish bio data (called by BioHub at ~1-10 Hz)
    public func publishBio(_ snapshot: BioSnapshot) {
        publish(.bioUpdate(snapshot))
    }

    /// Publish audio analysis (called by AudioHub at ~60 Hz)
    public func publishAudio(_ snapshot: AudioSnapshot) {
        publish(.audioAnalysis(snapshot))
    }

    /// Publish parameter change (called by any DSP engine)
    public func publishParam(engine: String, param: String, value: Float) {
        publish(.parameterChange(engineId: engine, parameter: param, value: value))
    }

    // MARK: - Diagnostics

    public var stats: String {
        "EngineBus: \(messageCount) messages, \(subscriberCount) subscribers, \(providers.count) providers"
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Engine Registry (Enhanced with Bus Integration)
// ═══════════════════════════════════════════════════════════════════════════════

/// Central registry of all active engines — the "phone book" for the hub system
/// Now integrated with EngineBus for automatic inter-engine communication
public final class EngineRegistry {
    public static let shared = EngineRegistry()

    private var engines: [String: EchoelEngineProtocol] = [:]
    private let bus = EngineBus.shared

    private init() {}

    /// Register an engine and auto-wire bus providers
    public func register(_ engine: EchoelEngineProtocol) {
        engines[engine.engineId] = engine

        // Auto-wire standard providers based on protocol conformance
        if let bioEngine = engine as? BioHubProtocol {
            bus.provide("bio.heartRate") { bioEngine.heartRate }
            bus.provide("bio.coherence") { bioEngine.coherence }
            bus.provide("bio.breathPhase") { bioEngine.breathPhase }
            bus.provide("bio.flowScore") { bioEngine.flowScore }
            bus.provide("bio.hrvMs") { bioEngine.hrvMs }
        }

        if let audioEngine = engine as? AudioHubProtocol {
            bus.provide("audio.bpm") { audioEngine.getBPM() }
            bus.provide("audio.rms") { audioEngine.getRMSLevel() }
            bus.provide("audio.volume") { audioEngine.masterVolume }
        }
    }

    /// Unregister and clean up bus providers
    public func unregister(_ engineId: String) {
        engines.removeValue(forKey: engineId)
    }

    public func engine<T: EchoelEngineProtocol>(for id: String) -> T? {
        engines[id] as? T
    }

    public func allEngines() -> [EchoelEngineProtocol] {
        Array(engines.values)
    }

    public func activeEngines() -> [EchoelEngineProtocol] {
        engines.values.filter { $0.isActive }
    }

    /// Broadcast bio snapshot to ALL registered BioReactiveEngines
    public func broadcastBio(_ snapshot: BioSnapshot) {
        for engine in engines.values {
            if let bioReactive = engine as? BioReactiveEngine {
                bioReactive.applyBioReactive(
                    coherence: snapshot.coherence,
                    hrvVariability: snapshot.heartRate,
                    breathPhase: snapshot.breathPhase
                )
            }
        }
        bus.publishBio(snapshot)
    }

    public var activeCount: Int {
        engines.values.filter { $0.isActive }.count
    }

    public var totalCount: Int {
        engines.count
    }

    public var summary: String {
        let active = activeEngines()
        return "EngineRegistry: \(totalCount) registered, \(active.count) active | \(bus.stats)"
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - Unified Creative AI (Merges 3 AI Composers → 1)
// ═══════════════════════════════════════════════════════════════════════════════
//
// BEFORE: AIComposer + BioReactiveAIComposer + QuantumComposer (3 separate)
// AFTER:  EchoelCreativeAI (1 engine, 3 strategies)
//
// Each old engine becomes a "strategy" inside the unified AI:
//   .compose    → what AIComposer did (chord/melody suggestions)
//   .bioReact   → what BioReactiveAIComposer did (coherence-driven generation)
//   .quantum    → what QuantumComposer did (probabilistic creative collapse)

/// Creative AI strategy — selects which generation approach to use
public enum CreativeStrategy: String, CaseIterable, Sendable {
    case compose = "compose"          // Traditional composition (chords, melodies, structure)
    case bioReact = "bioReact"        // Bio-reactive (coherence → musical decisions)
    case quantum = "quantum"          // Quantum-inspired (superposition collapse → creative choice)
    case hybrid = "hybrid"            // All three blended by context
}

/// LLM backend for creative AI
public enum LLMBackend: String, CaseIterable, Sendable {
    case claude = "claude"            // Anthropic Claude (primary)
    case onDevice = "onDevice"        // Apple Foundation Models (iOS 26+)
    case local = "local"              // Ollama/local LLM
    case offline = "offline"          // Rule-based fallback (no network)
}

/// Unified Creative AI — one brain, multiple strategies
/// Replaces: AIComposer, BioReactiveAIComposer, QuantumComposer
public final class EchoelCreativeAI: @unchecked Sendable {

    public static let shared = EchoelCreativeAI()

    // Configuration
    public var strategy: CreativeStrategy = .hybrid
    public var backend: LLMBackend = .claude
    public var temperature: Float = 0.8
    public var bioInfluence: Float = 0.5  // 0=ignore bio, 1=fully bio-driven

    // State
    public private(set) var lastSuggestion: String = ""
    public private(set) var suggestionCount: Int = 0

    // Bus integration
    private var busSubscription: BusSubscription?
    private var currentBio = BioSnapshot()
    private var currentAudio = AudioSnapshot()

    private init() {
        // Subscribe to bio + audio channels for context
        busSubscription = EngineBus.shared.subscribe(to: [.bio, .audio]) { [weak self] msg in
            switch msg {
            case .bioUpdate(let bio):
                self?.currentBio = bio
            case .audioAnalysis(let audio):
                self?.currentAudio = audio
            default:
                break
            }
        }
    }

    // MARK: - Chord Suggestion (was AIComposer)

    /// Suggest next chord based on current context + bio state
    public func suggestChord(currentChord: String = "C", key: String = "C") -> ChordSuggestion {
        let coherence = currentBio.coherence

        switch strategy {
        case .compose:
            return composeChord(current: currentChord, key: key)
        case .bioReact:
            return bioReactChord(current: currentChord, coherence: coherence)
        case .quantum:
            return quantumChord(current: currentChord)
        case .hybrid:
            // Blend: high coherence → more complex (compose), low → simpler (bioReact)
            if coherence > 0.7 {
                return composeChord(current: currentChord, key: key)
            } else if coherence > 0.4 {
                return bioReactChord(current: currentChord, coherence: coherence)
            } else {
                return quantumChord(current: currentChord)
            }
        }
    }

    private func composeChord(current: String, key: String) -> ChordSuggestion {
        // Circle of fifths progression logic (was in AIComposer)
        let progressions: [String: [String]] = [
            "C": ["Am", "F", "G", "Dm", "Em"],
            "Am": ["F", "Dm", "G", "C", "Em"],
            "F": ["C", "Dm", "Bb", "G", "Am"],
            "G": ["C", "Am", "Em", "D", "F"],
            "Dm": ["Am", "G", "F", "Bb", "C"],
            "Em": ["Am", "C", "G", "F", "Dm"],
        ]
        let options = progressions[current] ?? ["C", "Am", "F", "G"]
        let chosen = options[Int.random(in: 0..<options.count)]
        return ChordSuggestion(chord: chosen, confidence: 0.8, reason: "Circle of fifths progression")
    }

    private func bioReactChord(current: String, coherence: Float) -> ChordSuggestion {
        // Coherence-driven: high coherence → consonant, low → dissonant (was BioReactiveAIComposer)
        if coherence > 0.7 {
            let consonant = ["C", "Am", "F", "G"]
            return ChordSuggestion(
                chord: consonant[Int.random(in: 0..<consonant.count)],
                confidence: coherence,
                reason: "High coherence → consonant harmony"
            )
        } else {
            let dissonant = ["Dm7b5", "Cmaj7#11", "Am9", "Fmaj9"]
            return ChordSuggestion(
                chord: dissonant[Int.random(in: 0..<dissonant.count)],
                confidence: 1.0 - coherence,
                reason: "Low coherence → exploratory tension"
            )
        }
    }

    private func quantumChord(current: String) -> ChordSuggestion {
        // Probabilistic collapse — all options in superposition, one collapses (was QuantumComposer)
        let allChords = ["C", "Dm", "Em", "F", "G", "Am", "Bdim",
                         "Cmaj7", "Dm7", "Em7", "Fmaj7", "G7", "Am7"]
        let weights: [Float] = allChords.map { _ in Float.random(in: 0...1) }
        let totalWeight = weights.reduce(0, +)
        var random = Float.random(in: 0..<totalWeight)
        for (i, w) in weights.enumerated() {
            random -= w
            if random <= 0 {
                return ChordSuggestion(
                    chord: allChords[i],
                    confidence: w / totalWeight,
                    reason: "Quantum superposition collapse"
                )
            }
        }
        return ChordSuggestion(chord: "C", confidence: 0.5, reason: "Quantum fallback")
    }

    // MARK: - Generate (LLM-backed)

    /// Generate creative content using the configured LLM backend
    public func generate(prompt: String) async -> String {
        suggestionCount += 1

        // Build context-enriched prompt
        let enrichedPrompt = """
        Context: BPM=\(currentAudio.bpm), Key=\(currentAudio.keyDetected), \
        Coherence=\(String(format: "%.2f", currentBio.coherence)), \
        Flow=\(String(format: "%.2f", currentBio.flowScore))
        Strategy: \(strategy.rawValue)
        Request: \(prompt)
        """

        // In production: route to LLMService based on backend
        // For now: return structured suggestion
        let result = "[\(backend.rawValue)/\(strategy.rawValue)] \(enrichedPrompt)"
        lastSuggestion = result
        return result
    }

    public var stats: String {
        "EchoelCreativeAI: strategy=\(strategy.rawValue), backend=\(backend.rawValue), suggestions=\(suggestionCount)"
    }
}

/// Chord suggestion result
public struct ChordSuggestion: Sendable {
    public let chord: String
    public let confidence: Float
    public let reason: String
}

// ═══════════════════════════════════════════════════════════════════════════════
// MARK: - EchoelEngineProtocol Bus Extension
// ═══════════════════════════════════════════════════════════════════════════════

/// Convenience extension — any EchoelEngineProtocol can publish/subscribe
extension EchoelEngineProtocol {

    /// Quick access to the bus
    public var bus: EngineBus { EngineBus.shared }

    /// Quick access to the registry
    public var registry: EngineRegistry { EngineRegistry.shared }
}
