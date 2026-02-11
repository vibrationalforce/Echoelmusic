import Foundation
import Combine

// MARK: - Feature Interconnection Engine
// Bidirectional real-time connection between ALL Echoelmusic features.
// Every engine talks to every other engine through a unified event bus.
//
// Architecture:
// ┌─────────────────────────────────────────────────────────────────────┐
// │                    FeatureInterconnectionEngine                     │
// │                                                                     │
// │  ┌─────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐           │
// │  │  Audio   │  │  Video   │  │  Bio     │  │ Lighting │           │
// │  │  Engine  │◄─┼─►Engine  │◄─┼─►Engine  │◄─┼─►Engine  │           │
// │  └────┬────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘           │
// │       │            │              │              │                  │
// │       ▼            ▼              ▼              ▼                  │
// │  ┌──────────────────────────────────────────────────────┐          │
// │  │              Unified Event Bus                        │          │
// │  │  (Type-safe Combine publishers + priority routing)    │          │
// │  └──────────────────────────────────────────────────────┘          │
// │       ▲            ▲              ▲              ▲                  │
// │       │            │              │              │                  │
// │  ┌────┴────┐  ┌────┴─────┐  ┌────┴─────┐  ┌────┴─────┐           │
// │  │Creative │  │Wellness  │  │  Collab  │  │Quantum   │           │
// │  │ Studio  │  │  Engine  │  │   Hub    │  │  Engine  │           │
// │  └─────────┘  └──────────┘  └──────────┘  └──────────┘           │
// └─────────────────────────────────────────────────────────────────────┘

// MARK: - Feature Event Types

/// Every event that can flow between features
public enum FeatureEvent: Equatable {

    // Audio Events
    case bpmChanged(Double)
    case audioLevelChanged(Float)
    case beatDetected(beatPhase: Double)
    case frequencySpectrumUpdated
    case keyChanged(String)
    case audioEffectActivated(String)

    // Bio Events
    case heartRateUpdated(Double)
    case hrvUpdated(Double)
    case coherenceUpdated(Double)
    case breathingPhaseChanged(Double)
    case breathingRateChanged(Double)
    case bioStateChanged(BioState)

    // Video Events
    case videoFrameReady
    case videoEffectChanged(String)
    case videoTransitionTriggered
    case videoExportStarted

    // Creative Events
    case creativeStyleChanged(String)
    case aiGenerationCompleted(String)
    case presetLoaded(String)

    // Collaboration Events
    case participantJoined(String)
    case participantLeft(String)
    case sessionStateChanged(SessionState)
    case groupCoherenceUpdated(Double)

    // Lighting Events
    case dmxSceneChanged(String)
    case laserPatternChanged(String)
    case lightIntensityChanged(Double)

    // Quantum Events
    case quantumStateCollapsed
    case quantumCoherenceChanged(Double)
    case entanglementDetected

    // Navigation Events
    case workspaceChanged(String)
    case featureFocused(String)

    // Wellness Events
    case wellnessSessionStarted(String)
    case wellnessSessionEnded
    case meditationPhaseChanged(String)

    public enum BioState: String, Equatable {
        case resting, active, meditative, flow, stressed, recovering
    }

    public enum SessionState: String, Equatable {
        case idle, connecting, active, paused, ending
    }
}

// MARK: - Feature Connection

/// Defines how one feature connects to another
public struct FeatureConnection: Identifiable {
    public let id = UUID()
    public let source: FeatureDomain
    public let target: FeatureDomain
    public let mapping: ConnectionMapping
    public var isActive: Bool = true
    public var strength: Double = 1.0  // 0.0–1.0 modulation depth

    public enum ConnectionMapping: String {
        case direct         // 1:1 value transfer
        case scaled         // with range mapping
        case inverted       // inverse relationship
        case gated          // only when threshold met
        case smoothed       // with interpolation
        case quantized      // snapped to steps
    }
}

// MARK: - Feature Domains

/// All feature domains in Echoelmusic
public enum FeatureDomain: String, CaseIterable, Identifiable {
    case audio = "Audio"
    case video = "Video"
    case biofeedback = "Biofeedback"
    case lighting = "Lighting"
    case creative = "Creative"
    case wellness = "Wellness"
    case collaboration = "Collaboration"
    case quantum = "Quantum"
    case midi = "MIDI"
    case streaming = "Streaming"
    case spatial = "Spatial Audio"
    case visualization = "Visualization"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .audio: return "waveform"
        case .video: return "film"
        case .biofeedback: return "heart.fill"
        case .lighting: return "lightbulb.led.fill"
        case .creative: return "paintbrush.fill"
        case .wellness: return "leaf.fill"
        case .collaboration: return "person.3.fill"
        case .quantum: return "atom"
        case .midi: return "pianokeys"
        case .streaming: return "dot.radiowaves.left.and.right"
        case .spatial: return "speaker.wave.3.fill"
        case .visualization: return "eye.fill"
        }
    }

    /// Default connections this domain makes to others
    public var defaultTargets: [FeatureDomain] {
        switch self {
        case .biofeedback:
            return [.audio, .video, .lighting, .visualization, .quantum, .wellness]
        case .audio:
            return [.video, .lighting, .visualization, .midi, .streaming, .spatial]
        case .video:
            return [.lighting, .streaming, .visualization]
        case .collaboration:
            return [.audio, .video, .streaming, .wellness]
        case .quantum:
            return [.audio, .visualization, .lighting]
        case .wellness:
            return [.biofeedback, .audio, .visualization, .lighting]
        case .creative:
            return [.audio, .video, .visualization]
        case .midi:
            return [.audio, .lighting, .visualization]
        case .lighting:
            return [.visualization]
        case .streaming:
            return [.video, .audio]
        case .spatial:
            return [.audio, .visualization]
        case .visualization:
            return []
        }
    }
}

// MARK: - Interconnection Engine

/// Central engine that manages all feature-to-feature connections
@MainActor
public final class FeatureInterconnectionEngine: ObservableObject {

    // MARK: - Singleton

    static let shared = FeatureInterconnectionEngine()

    // MARK: - Published State

    @Published public var connections: [FeatureConnection] = []
    @Published public var activeDomains: Set<FeatureDomain> = Set(FeatureDomain.allCases)
    @Published public var eventLog: [EventLogEntry] = []
    @Published public var isInterconnected: Bool = true

    // MARK: - Event Bus

    /// Central event publisher — all features publish here
    public let eventBus = PassthroughSubject<FeatureEvent, Never>()

    /// Domain-specific event streams (filtered from main bus)
    public private(set) var domainStreams: [FeatureDomain: AnyPublisher<FeatureEvent, Never>] = [:]

    // MARK: - Current State Cache

    @Published public var currentBPM: Double = 120.0
    @Published public var currentHeartRate: Double = 72.0
    @Published public var currentCoherence: Double = 0.5
    @Published public var currentBeatPhase: Double = 0.0
    @Published public var currentBreathingPhase: Double = 0.0
    @Published public var currentAudioLevel: Float = 0.0
    @Published public var currentBioState: FeatureEvent.BioState = .resting
    @Published public var currentSessionState: FeatureEvent.SessionState = .idle

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupDefaultConnections()
        setupDomainStreams()
        setupEventProcessing()
    }

    // MARK: - Setup

    private func setupDefaultConnections() {
        // Create default connections between all domains
        for domain in FeatureDomain.allCases {
            for target in domain.defaultTargets {
                let connection = FeatureConnection(
                    source: domain,
                    target: target,
                    mapping: .smoothed
                )
                connections.append(connection)
            }
        }
    }

    private func setupDomainStreams() {
        // Create filtered streams for each domain
        for domain in FeatureDomain.allCases {
            let stream = eventBus
                .filter { [weak self] event in
                    guard let self = self else { return false }
                    return self.eventBelongsToDomain(event, domain: domain)
                }
                .eraseToAnyPublisher()
            domainStreams[domain] = stream
        }
    }

    private func setupEventProcessing() {
        // Process all events and update state cache
        eventBus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.processEvent(event)
            }
            .store(in: &cancellables)
    }

    // MARK: - Event Processing

    private func processEvent(_ event: FeatureEvent) {
        // Update state cache
        switch event {
        case .bpmChanged(let bpm):
            currentBPM = bpm
        case .heartRateUpdated(let hr):
            currentHeartRate = hr
        case .coherenceUpdated(let c):
            currentCoherence = c
        case .beatDetected(let phase):
            currentBeatPhase = phase
        case .breathingPhaseChanged(let phase):
            currentBreathingPhase = phase
        case .audioLevelChanged(let level):
            currentAudioLevel = level
        case .bioStateChanged(let state):
            currentBioState = state
        case .sessionStateChanged(let state):
            currentSessionState = state
        default:
            break
        }

        // Route to connected features
        routeEvent(event)

        // Log
        let entry = EventLogEntry(event: event, timestamp: Date())
        eventLog.append(entry)
        if eventLog.count > 200 {
            eventLog.removeFirst(50)
        }
    }

    private func routeEvent(_ event: FeatureEvent) {
        guard isInterconnected else { return }

        // Find source domain
        guard let sourceDomain = domainForEvent(event) else { return }

        // Find active connections from this domain
        let activeConnections = connections.filter {
            $0.source == sourceDomain && $0.isActive && activeDomains.contains($0.target)
        }

        // Route to each connected domain (actual routing would trigger domain-specific handlers)
        for connection in activeConnections {
            _ = connection.target
            _ = connection.strength
            // In a full implementation, this would call domain-specific handlers
        }
    }

    // MARK: - Domain Helpers

    private func domainForEvent(_ event: FeatureEvent) -> FeatureDomain? {
        switch event {
        case .bpmChanged, .audioLevelChanged, .beatDetected, .frequencySpectrumUpdated,
             .keyChanged, .audioEffectActivated:
            return .audio
        case .heartRateUpdated, .hrvUpdated, .coherenceUpdated,
             .breathingPhaseChanged, .breathingRateChanged, .bioStateChanged:
            return .biofeedback
        case .videoFrameReady, .videoEffectChanged, .videoTransitionTriggered, .videoExportStarted:
            return .video
        case .creativeStyleChanged, .aiGenerationCompleted, .presetLoaded:
            return .creative
        case .participantJoined, .participantLeft, .sessionStateChanged, .groupCoherenceUpdated:
            return .collaboration
        case .dmxSceneChanged, .laserPatternChanged, .lightIntensityChanged:
            return .lighting
        case .quantumStateCollapsed, .quantumCoherenceChanged, .entanglementDetected:
            return .quantum
        case .workspaceChanged, .featureFocused:
            return nil
        case .wellnessSessionStarted, .wellnessSessionEnded, .meditationPhaseChanged:
            return .wellness
        }
    }

    private func eventBelongsToDomain(_ event: FeatureEvent, domain: FeatureDomain) -> Bool {
        // Check if event originates from domain OR if domain is a target
        guard let source = domainForEvent(event) else { return false }
        if source == domain { return true }

        // Also include if this domain is a target of the source
        return connections.contains { $0.source == source && $0.target == domain && $0.isActive }
    }

    // MARK: - Public API

    /// Emit an event to the interconnection bus
    public func emit(_ event: FeatureEvent) {
        eventBus.send(event)
    }

    /// Subscribe to events for a specific domain
    public func subscribe(to domain: FeatureDomain) -> AnyPublisher<FeatureEvent, Never> {
        domainStreams[domain] ?? Empty().eraseToAnyPublisher()
    }

    /// Toggle a connection between two domains
    public func toggleConnection(source: FeatureDomain, target: FeatureDomain) {
        if let index = connections.firstIndex(where: { $0.source == source && $0.target == target }) {
            connections[index].isActive.toggle()
        }
    }

    /// Set connection strength
    public func setConnectionStrength(source: FeatureDomain, target: FeatureDomain, strength: Double) {
        if let index = connections.firstIndex(where: { $0.source == source && $0.target == target }) {
            connections[index].strength = max(0, min(1, strength))
        }
    }

    /// Enable/disable a feature domain
    public func setDomainActive(_ domain: FeatureDomain, active: Bool) {
        if active {
            activeDomains.insert(domain)
        } else {
            activeDomains.remove(domain)
        }
    }

    /// Get all connections for a specific domain
    public func connectionsFor(_ domain: FeatureDomain) -> [FeatureConnection] {
        connections.filter { $0.source == domain || $0.target == domain }
    }

    /// Get interconnection health score (how well connected the system is)
    public var interconnectionHealth: Double {
        let activeCount = Double(connections.filter(\.isActive).count)
        let totalCount = Double(connections.count)
        guard totalCount > 0 else { return 0 }
        return activeCount / totalCount
    }

    // MARK: - Presets

    /// Apply a connection preset
    public func applyPreset(_ preset: InterconnectionPreset) {
        switch preset {
        case .full:
            connections.indices.forEach { connections[$0].isActive = true }
            connections.indices.forEach { connections[$0].strength = 1.0 }

        case .minimal:
            connections.indices.forEach { connections[$0].isActive = false }
            // Only enable bio→audio and audio→visualization
            enableConnection(from: .biofeedback, to: .audio)
            enableConnection(from: .audio, to: .visualization)

        case .performance:
            connections.indices.forEach { connections[$0].isActive = true }
            // Boost audio and lighting connections
            connections.indices.forEach { i in
                if connections[i].target == .lighting || connections[i].target == .audio {
                    connections[i].strength = 1.0
                } else {
                    connections[i].strength = 0.5
                }
            }

        case .meditation:
            connections.indices.forEach { connections[$0].isActive = false }
            enableConnection(from: .biofeedback, to: .audio)
            enableConnection(from: .biofeedback, to: .visualization)
            enableConnection(from: .biofeedback, to: .lighting)
            enableConnection(from: .biofeedback, to: .wellness)
            // Gentle strengths
            connections.indices.forEach { i in
                if connections[i].isActive {
                    connections[i].strength = 0.6
                }
            }

        case .studio:
            connections.indices.forEach { connections[$0].isActive = true }
            // Focus on audio production chain
            connections.indices.forEach { i in
                if connections[i].source == .audio || connections[i].target == .audio {
                    connections[i].strength = 1.0
                } else {
                    connections[i].strength = 0.3
                }
            }

        case .collaboration:
            connections.indices.forEach { connections[$0].isActive = true }
            connections.indices.forEach { i in
                if connections[i].source == .collaboration || connections[i].target == .collaboration {
                    connections[i].strength = 1.0
                }
            }
        }
    }

    private func enableConnection(from source: FeatureDomain, to target: FeatureDomain) {
        if let index = connections.firstIndex(where: { $0.source == source && $0.target == target }) {
            connections[index].isActive = true
        }
    }

    public enum InterconnectionPreset: String, CaseIterable {
        case full = "Full Interconnection"
        case minimal = "Minimal"
        case performance = "Live Performance"
        case meditation = "Meditation"
        case studio = "Studio Production"
        case collaboration = "Collaboration"
    }
}

// MARK: - Event Log

public struct EventLogEntry: Identifiable {
    public let id = UUID()
    public let event: FeatureEvent
    public let timestamp: Date

    public var description: String {
        switch event {
        case .bpmChanged(let bpm): return "BPM: \(Int(bpm))"
        case .heartRateUpdated(let hr): return "HR: \(Int(hr)) bpm"
        case .coherenceUpdated(let c): return "Coherence: \(Int(c * 100))%"
        case .beatDetected(let phase): return "Beat @ \(String(format: "%.1f", phase))"
        case .bioStateChanged(let state): return "Bio: \(state.rawValue)"
        case .workspaceChanged(let ws): return "Workspace: \(ws)"
        case .presetLoaded(let name): return "Preset: \(name)"
        default: return "\(event)"
        }
    }
}
