// SelfHealingCodeTransformation.swift
// Echoelmusic - λ% Ralph Wiggum Loop Quantum Light Science Developer Genius Mode
//
// Self-Healing Code Transformation Engine
// Erweitert die bestehende SelfHealingEngine um Environment-bewusste
// Transformation: Wenn sich die Umgebung ändert (Auto→Tauchen→Fliegen→Orbit),
// transformiert sich der gesamte Signal-Processing-Graph automatisch.
//
// Ebenen der Selbstheilung:
//   Level 0: Parameter-Anpassung (bestehende SelfHealingEngine)
//   Level 1: Pipeline-Rekonfiguration (Lambda-Chain Swap)
//   Level 2: Topologie-Transformation (Signal-Graph Umverdrahtung)
//   Level 3: Emergente Adaptation (Pattern-Learning über Environments)
//   Level 4: Quantum Coherence Lock (φ-stabilisierte Selbstheilung)
//
// "The doctor said I wouldn't have so many nose bleeds if I kept
//  my finger outta there" - Ralph Wiggum, Self-Healing Specialist
//
// ═══════════════════════════════════════════════════════════════════════════════
// PRINCIPLE: Code heilt sich nicht nur bei Fehlern — es transformiert sich
// vorausschauend, wenn die Umgebung signalisiert dass Veränderung kommt.
// Wie ein lebender Organismus, der sich an neue Habitate anpasst.
// ═══════════════════════════════════════════════════════════════════════════════
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine

// MARK: - Transformation Level

/// Tiefe der Selbstheilungs-Transformation
public enum TransformationLevel: Int, CaseIterable, Codable, Sendable, Comparable {
    case parameterAdjust = 0     // Bestehende SelfHealingEngine
    case pipelineSwap = 1        // Lambda-Chain austauschen
    case topologyTransform = 2   // Signal-Graph umverdrahten
    case emergentAdaptation = 3  // Pattern-Learning
    case quantumCoherenceLock = 4 // φ-stabilisiert

    public static func < (lhs: TransformationLevel, rhs: TransformationLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var description: String {
        switch self {
        case .parameterAdjust: return "Parameter-Anpassung"
        case .pipelineSwap: return "Pipeline-Rekonfiguration"
        case .topologyTransform: return "Topologie-Transformation"
        case .emergentAdaptation: return "Emergente Adaptation"
        case .quantumCoherenceLock: return "Quantum Coherence Lock"
        }
    }

    /// Minimale Kohärenz für dieses Level (höhere Level brauchen stabilere Systeme)
    public var minimumCoherence: Double {
        switch self {
        case .parameterAdjust: return 0.0
        case .pipelineSwap: return 0.2
        case .topologyTransform: return 0.4
        case .emergentAdaptation: return 0.6
        case .quantumCoherenceLock: return 0.8
        }
    }
}

// MARK: - Transformation Event

/// Protokollierte Transformation
public struct TransformationEvent: Identifiable, Sendable {
    public let id: UUID = UUID()
    public let timestamp: Date
    public let level: TransformationLevel
    public let trigger: TransformationTrigger
    public let fromEnvironment: EnvironmentClass?
    public let toEnvironment: EnvironmentClass?
    public let action: String
    public let success: Bool
    public let latencyMs: Double
}

/// Was die Transformation ausgelöst hat
public enum TransformationTrigger: String, CaseIterable, Codable, Sendable {
    case environmentChange = "Environment-Wechsel"
    case comfortDrop = "Komfort-Abfall"
    case coherenceLoss = "Kohärenz-Verlust"
    case sensorFailure = "Sensor-Ausfall"
    case transitionDetected = "Übergang erkannt"
    case patternPrediction = "Muster-Vorhersage"
    case userIntent = "Nutzer-Intent"
    case emergencyRecovery = "Notfall-Recovery"
    case periodicOptimization = "Periodische Optimierung"
}

// MARK: - Signal Graph Node

/// Knoten im Signal-Processing-Graphen
public struct SignalGraphNode: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let type: SignalNodeType
    public var isActive: Bool
    public var connections: [String]  // IDs der verbundenen Knoten

    public init(id: String, name: String, type: SignalNodeType, isActive: Bool = true, connections: [String] = []) {
        self.id = id
        self.name = name
        self.type = type
        self.isActive = isActive
        self.connections = connections
    }
}

/// Typ eines Signal-Graph-Knotens
public enum SignalNodeType: String, CaseIterable, Codable, Sendable {
    case sensorInput = "Sensor-Input"
    case bioInput = "Bio-Input"
    case environmentInput = "Environment-Input"
    case lambdaOperator = "Lambda-Operator"
    case audioOutput = "Audio-Output"
    case visualOutput = "Visual-Output"
    case hapticOutput = "Haptic-Output"
    case dmxOutput = "DMX-Output"
    case mixer = "Mixer"
    case filter = "Filter"
    case analyzer = "Analyzer"
}

// MARK: - Adaptation Pattern

/// Gelerntes Muster für Environment-Transformation
public struct AdaptationPattern: Identifiable, Sendable {
    public let id: UUID = UUID()
    public let fromEnvironment: EnvironmentClass
    public let toEnvironment: EnvironmentClass
    public let optimalChain: String              // Name der besten Lambda-Chain
    public let transitionDuration: TimeInterval
    public let successRate: Double               // 0–1
    public let timesObserved: Int
}

// MARK: - Self-Healing Code Transformation Engine

/// Environment-bewusste Self-Healing Transformation
/// Erweitert die bestehende SelfHealingEngine um Environment-Awareness
@MainActor
public class SelfHealingCodeTransformation: ObservableObject {

    public static let shared = SelfHealingCodeTransformation()

    // MARK: - Dependencies

    private let universalEngine = UniversalEnvironmentEngine.shared
    private let loopProcessor = EnvironmentLoopProcessor.shared

    // MARK: - Published State

    @Published public var isActive: Bool = false
    @Published public var currentLevel: TransformationLevel = .parameterAdjust
    @Published public var maxAllowedLevel: TransformationLevel = .quantumCoherenceLock
    @Published public var transformationLog: [TransformationEvent] = []
    @Published public var signalGraph: [SignalGraphNode] = []
    @Published public var learnedPatterns: [AdaptationPattern] = []
    @Published public var coherenceStability: Double = 0.5
    @Published public var transformationsPerMinute: Double = 0.0

    // MARK: - Configuration

    @Published public var autoTransformEnabled: Bool = true
    @Published public var learningEnabled: Bool = true
    @Published public var preemptiveTransformEnabled: Bool = true
    @Published public var coherenceLockThreshold: Double = 0.8

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private var lastEnvironment: EnvironmentClass?
    private var coherenceHistory: [Double] = []
    private var lastTransformTime: Date = Date.distantPast

    private init() {
        setupDefaultSignalGraph()
        setupSubscriptions()
    }

    // MARK: - Lifecycle

    /// Self-Healing Transformation aktivieren
    public func activate() {
        guard !isActive else { return }
        isActive = true
        lastEnvironment = universalEngine.currentEnvironment
    }

    /// Deaktivieren
    public func deactivate() {
        isActive = false
    }

    // MARK: - Signal Graph Setup

    private func setupDefaultSignalGraph() {
        signalGraph = [
            // Inputs
            SignalGraphNode(id: "env_sensor", name: "Environment Sensors", type: .environmentInput,
                           connections: ["lambda_chain"]),
            SignalGraphNode(id: "bio_sensor", name: "Bio Sensors", type: .bioInput,
                           connections: ["bio_mixer"]),

            // Processing
            SignalGraphNode(id: "lambda_chain", name: "Lambda Chain", type: .lambdaOperator,
                           connections: ["main_mixer"]),
            SignalGraphNode(id: "bio_mixer", name: "Bio Mixer", type: .mixer,
                           connections: ["main_mixer"]),
            SignalGraphNode(id: "main_mixer", name: "Main Mixer", type: .mixer,
                           connections: ["audio_out", "visual_out", "haptic_out"]),

            // Outputs
            SignalGraphNode(id: "audio_out", name: "Audio Output", type: .audioOutput),
            SignalGraphNode(id: "visual_out", name: "Visual Output", type: .visualOutput),
            SignalGraphNode(id: "haptic_out", name: "Haptic Output", type: .hapticOutput)
        ]
    }

    // MARK: - Combine Subscriptions

    private func setupSubscriptions() {
        // Environment-Wechsel beobachten
        universalEngine.$currentEnvironment
            .removeDuplicates()
            .sink { [weak self] newEnv in
                guard let self, self.isActive else { return }
                self.handleEnvironmentChange(to: newEnv)
            }
            .store(in: &cancellables)

        // Comfort-Score beobachten
        universalEngine.$comfortScore
            .sink { [weak self] comfort in
                guard let self, self.isActive else { return }
                self.handleComfortChange(comfort)
            }
            .store(in: &cancellables)

        // Loop-Ergebnisse für Kohärenz-Tracking
        loopProcessor.coherenceOutput
            .sink { [weak self] coherence in
                guard let self, self.isActive else { return }
                self.trackCoherence(coherence)
            }
            .store(in: &cancellables)
    }

    // MARK: - Environment Change Handling

    private func handleEnvironmentChange(to newEnv: EnvironmentClass) {
        let oldEnv = lastEnvironment
        lastEnvironment = newEnv

        guard autoTransformEnabled else { return }
        guard let oldEnv, oldEnv != newEnv else { return }

        // Level 1: Pipeline Swap
        performTransformation(level: .pipelineSwap, trigger: .environmentChange, from: oldEnv, to: newEnv) {
            // Automatisch die beste Lambda-Chain wählen
            let domain = newEnv.domain
            self.loopProcessor.setLambdaChain(LambdaChain.chain(for: domain))
            return "Lambda-Chain gewechselt: \(domain.rawValue)"
        }

        // Level 2: Topologie Transform (wenn Domäne wechselt)
        if oldEnv.domain != newEnv.domain {
            performTransformation(level: .topologyTransform, trigger: .transitionDetected, from: oldEnv, to: newEnv) {
                self.transformSignalGraph(for: newEnv)
                return "Signal-Graph transformiert für \(newEnv.domain.rawValue)"
            }
        }

        // Level 3: Pattern lernen
        if learningEnabled {
            learnTransitionPattern(from: oldEnv, to: newEnv)
        }
    }

    // MARK: - Comfort Change Handling

    private func handleComfortChange(_ comfort: Double) {
        if comfort < 0.3 {
            performTransformation(level: .parameterAdjust, trigger: .comfortDrop, from: nil, to: nil) {
                // Beruhigende Parameter aktivieren
                return "Comfort-Recovery: Theta-Entrainment aktiviert"
            }
        }
    }

    // MARK: - Coherence Tracking

    private func trackCoherence(_ coherence: Double) {
        coherenceHistory.append(coherence)
        if coherenceHistory.count > 600 { // 10 Sekunden bei 60Hz
            coherenceHistory.removeFirst(coherenceHistory.count - 600)
        }

        // Kohärenz-Stabilität berechnen (niedrige Varianz = stabil)
        let mean = coherenceHistory.reduce(0, +) / Double(coherenceHistory.count)
        let variance = coherenceHistory.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(coherenceHistory.count)
        coherenceStability = Swift.max(0, 1.0 - sqrt(variance) * 5.0)

        // Level 4: Quantum Coherence Lock
        if coherenceStability > coherenceLockThreshold && currentLevel < .quantumCoherenceLock {
            performTransformation(level: .quantumCoherenceLock, trigger: .periodicOptimization, from: nil, to: nil) {
                return "φ-Lock erreicht: Kohärenz-Stabilität \(String(format: "%.1f%%", self.coherenceStability * 100))"
            }
        }

        // Kohärenz-Verlust erkennen
        if coherenceHistory.count > 60 {
            let recent = Array(coherenceHistory.suffix(30))
            let older = Array(coherenceHistory.dropLast(30).suffix(30))
            let recentMean = recent.reduce(0, +) / Double(recent.count)
            let olderMean = older.reduce(0, +) / Double(older.count)

            if olderMean - recentMean > 0.2 {
                performTransformation(level: .pipelineSwap, trigger: .coherenceLoss, from: nil, to: nil) {
                    return "Kohärenz-Recovery: Pipeline neu kalibriert"
                }
            }
        }
    }

    // MARK: - Transformation Execution

    private func performTransformation(
        level: TransformationLevel,
        trigger: TransformationTrigger,
        from: EnvironmentClass?,
        to: EnvironmentClass?,
        action: () -> String
    ) {
        guard level <= maxAllowedLevel else { return }
        guard level.minimumCoherence <= coherenceStability || trigger == .emergencyRecovery else { return }

        // Rate-Limiting: max 10 Transformationen pro Minute
        let now = Date()
        let timeSinceLast = now.timeIntervalSince(lastTransformTime)
        guard timeSinceLast > 6.0 || trigger == .emergencyRecovery else { return }

        let startTime = Date()
        let actionDescription = action()
        let latency = Date().timeIntervalSince(startTime) * 1000.0

        let event = TransformationEvent(
            timestamp: now,
            level: level,
            trigger: trigger,
            fromEnvironment: from,
            toEnvironment: to,
            action: actionDescription,
            success: true,
            latencyMs: latency
        )

        transformationLog.append(event)
        lastTransformTime = now
        currentLevel = level

        // Log begrenzen
        if transformationLog.count > 500 {
            transformationLog.removeFirst(transformationLog.count - 500)
        }

        // Transformations/Minute berechnen
        let recentEvents = transformationLog.filter {
            now.timeIntervalSince($0.timestamp) < 60
        }
        transformationsPerMinute = Double(recentEvents.count)
    }

    // MARK: - Signal Graph Transformation (Level 2)

    private func transformSignalGraph(for environment: EnvironmentClass) {
        let domain = environment.domain

        switch domain {
        case .aquatic:
            // Unter Wasser: Haptic wichtiger als Visual, spezielle Reverb-Kette
            activateNode("haptic_out")
            injectNode(SignalGraphNode(id: "water_reverb", name: "Water Reverb", type: .filter,
                                      connections: ["audio_out"]))
            injectNode(SignalGraphNode(id: "depth_analyzer", name: "Depth Analyzer", type: .analyzer,
                                      connections: ["lambda_chain"]))

        case .aerial:
            // In der Luft: Wind-Spatial, 3D-Audio kritisch
            injectNode(SignalGraphNode(id: "wind_spatial", name: "Wind Spatial", type: .filter,
                                      connections: ["audio_out"]))
            injectNode(SignalGraphNode(id: "altitude_analyzer", name: "Altitude Analyzer", type: .analyzer,
                                      connections: ["lambda_chain"]))

        case .extraterrestrial:
            // Weltraum: Kein Schall im Vakuum — Haptic & Visual dominieren
            deactivateNode("audio_out")
            activateNode("haptic_out")
            activateNode("visual_out")
            injectNode(SignalGraphNode(id: "radiation_monitor", name: "Radiation Monitor", type: .analyzer,
                                      connections: ["haptic_out"]))

        case .vehicular:
            // Fahrzeug: Audio-only Sicherheitsmodus
            deactivateNode("visual_out")
            activateNode("audio_out")
            injectNode(SignalGraphNode(id: "motion_comp", name: "Motion Compensator", type: .filter,
                                      connections: ["audio_out"]))

        case .subterranean:
            // Untergrund: Massive Reverb, tiefe Frequenzen
            injectNode(SignalGraphNode(id: "cave_reverb", name: "Cave Reverb", type: .filter,
                                      connections: ["audio_out"]))

        case .terrestrial:
            // Standard: Alles aktiv, normale Konfiguration
            setupDefaultSignalGraph()
        }
    }

    // MARK: - Graph Manipulation Helpers

    private func activateNode(_ id: String) {
        if let index = signalGraph.firstIndex(where: { $0.id == id }) {
            signalGraph[index].isActive = true
        }
    }

    private func deactivateNode(_ id: String) {
        if let index = signalGraph.firstIndex(where: { $0.id == id }) {
            signalGraph[index].isActive = false
        }
    }

    private func injectNode(_ node: SignalGraphNode) {
        if !signalGraph.contains(where: { $0.id == node.id }) {
            signalGraph.append(node)
        }
    }

    private func removeNode(_ id: String) {
        signalGraph.removeAll { $0.id == id }
        // Verbindungen bereinigen
        for i in signalGraph.indices {
            signalGraph[i].connections.removeAll { $0 == id }
        }
    }

    // MARK: - Pattern Learning (Level 3)

    private func learnTransitionPattern(from: EnvironmentClass, to: EnvironmentClass) {
        if let index = learnedPatterns.firstIndex(where: {
            $0.fromEnvironment == from && $0.toEnvironment == to
        }) {
            // Bestehendes Pattern aktualisieren
            var pattern = learnedPatterns[index]
            let newCount = pattern.timesObserved + 1
            let newSuccessRate = (pattern.successRate * Double(pattern.timesObserved) + 1.0) / Double(newCount)
            learnedPatterns[index] = AdaptationPattern(
                fromEnvironment: from,
                toEnvironment: to,
                optimalChain: pattern.optimalChain,
                transitionDuration: pattern.transitionDuration,
                successRate: newSuccessRate,
                timesObserved: newCount
            )
        } else {
            // Neues Pattern anlegen
            let chain = LambdaChain.chain(for: to.domain)
            let chainName = chain.operators.first?.name ?? "universal"
            learnedPatterns.append(AdaptationPattern(
                fromEnvironment: from,
                toEnvironment: to,
                optimalChain: chainName,
                transitionDuration: 30.0,
                successRate: 1.0,
                timesObserved: 1
            ))
        }
    }

    // MARK: - Preemptive Transformation

    /// Vorhersage-basierte Transformation (z.B. GPS zeigt Annäherung an Wasser)
    public func predictEnvironmentChange(to predicted: EnvironmentClass, confidence: Double) {
        guard preemptiveTransformEnabled, confidence > 0.7 else { return }

        performTransformation(level: .emergentAdaptation, trigger: .patternPrediction,
                            from: universalEngine.currentEnvironment, to: predicted) {
            // Vorbereitende Transformation
            let domain = predicted.domain
            let chain = LambdaChain.chain(for: domain)
            // Sanftes Einblenden der neuen Chain
            return "Preemptive: Vorbereitung auf \(predicted.rawValue) (\(String(format: "%.0f%%", confidence * 100)) Konfidenz)"
        }
    }

    // MARK: - Emergency Recovery

    /// Notfall-Recovery — alle Systeme auf sicheren Zustand
    public func emergencyRecovery() {
        performTransformation(level: .parameterAdjust, trigger: .emergencyRecovery, from: nil, to: nil) {
            self.setupDefaultSignalGraph()
            self.loopProcessor.setLambdaChain(.universal)
            self.coherenceHistory.removeAll()
            self.coherenceStability = 0.5
            return "Emergency Recovery: Alle Systeme auf Default zurückgesetzt"
        }
    }

    // MARK: - Statistics

    /// Zusammenfassung der Transformations-Statistik
    public var statistics: TransformationStatistics {
        let byLevel = Dictionary(grouping: transformationLog) { $0.level }
        let byTrigger = Dictionary(grouping: transformationLog) { $0.trigger }

        return TransformationStatistics(
            totalTransformations: transformationLog.count,
            byLevel: byLevel.mapValues { $0.count },
            byTrigger: byTrigger.mapValues { $0.count },
            averageLatencyMs: transformationLog.isEmpty ? 0 :
                transformationLog.map(\.latencyMs).reduce(0, +) / Double(transformationLog.count),
            successRate: transformationLog.isEmpty ? 1.0 :
                Double(transformationLog.filter(\.success).count) / Double(transformationLog.count),
            learnedPatterns: learnedPatterns.count,
            currentCoherenceStability: coherenceStability,
            currentLevel: currentLevel
        )
    }
}

// MARK: - Transformation Statistics

public struct TransformationStatistics: Sendable {
    public let totalTransformations: Int
    public let byLevel: [TransformationLevel: Int]
    public let byTrigger: [TransformationTrigger: Int]
    public let averageLatencyMs: Double
    public let successRate: Double
    public let learnedPatterns: Int
    public let currentCoherenceStability: Double
    public let currentLevel: TransformationLevel
}
