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

// MARK: - Consolidation Registry

/// Central registry of all active engines — the "phone book" for the hub system
/// Replaces scattered singletons with a single lookup point
public final class EngineRegistry {
    public static let shared = EngineRegistry()

    private var engines: [String: EchoelEngineProtocol] = [:]

    private init() {}

    public func register(_ engine: EchoelEngineProtocol) {
        engines[engine.engineId] = engine
    }

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

    public var activeCount: Int {
        engines.values.filter { $0.isActive }.count
    }

    public var totalCount: Int {
        engines.count
    }

    /// Summary for diagnostics
    public var summary: String {
        let active = activeEngines()
        return "EngineRegistry: \(totalCount) registered, \(active.count) active"
    }
}
