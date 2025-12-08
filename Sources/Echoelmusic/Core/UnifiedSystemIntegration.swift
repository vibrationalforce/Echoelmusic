import Foundation
import Combine
import Metal

// ═══════════════════════════════════════════════════════════════════════════════
// UNIFIED SYSTEM INTEGRATION - QUANTUM COHERENT ARCHITECTURE
// ═══════════════════════════════════════════════════════════════════════════════
//
// This module provides seamless integration between all Echoelmusic systems:
// • Bio-feedback → Audio → Visual → Stream pipeline
// • AI Composer ↔ Physical Modeling ↔ OSC communication
// • Recording ↔ Cloud ↔ Collaboration synchronization
// • Automation ↔ MIDI ↔ LED controller mapping
// • Privacy-aware data flow management
//
// ═══════════════════════════════════════════════════════════════════════════════

@MainActor
final class UnifiedSystemIntegration: ObservableObject {

    // MARK: - Singleton

    static let shared = UnifiedSystemIntegration()

    // MARK: - Published State

    @Published var isFullyInitialized: Bool = false
    @Published var activeModules: Set<ModuleType> = []
    @Published var systemHealth: SystemHealth = .optimal
    @Published var dataFlowRate: DataFlowMetrics = DataFlowMetrics()

    // MARK: - Module Types

    enum ModuleType: String, CaseIterable {
        case audio = "Audio Engine"
        case visual = "Visual Engine"
        case bio = "Bio Feedback"
        case streaming = "Streaming"
        case recording = "Recording"
        case midi = "MIDI"
        case osc = "OSC"
        case ai = "AI Composer"
        case physical = "Physical Modeling"
        case cloud = "Cloud Sync"
        case collaboration = "Collaboration"
        case automation = "Automation"
        case led = "LED Control"
        case video = "Video Processing"
    }

    enum SystemHealth: String {
        case optimal = "Optimal"
        case good = "Good"
        case degraded = "Degraded"
        case critical = "Critical"
    }

    struct DataFlowMetrics {
        var bioToAudioLatency: TimeInterval = 0
        var audioToVisualLatency: TimeInterval = 0
        var totalPipelineLatency: TimeInterval = 0
        var messagesPerSecond: Int = 0
        var droppedMessages: Int = 0
    }

    // MARK: - Internal State

    private var cancellables = Set<AnyCancellable>()
    private var moduleConnections: [ModuleConnection] = []
    private var dataRoutes: [DataRoute] = []

    // Bio state cache
    private var currentBioState = BioState()

    // Performance monitoring
    private var lastUpdateTime = Date()
    private var messageCount = 0

    // MARK: - Initialization

    private init() {
        setupDefaultConnections()
        setupDataRoutes()
        startMonitoring()
        print("✅ UnifiedSystemIntegration: Initialized")
    }

    // MARK: - Connection Setup

    private func setupDefaultConnections() {
        // Bio → Audio → Visual pipeline
        moduleConnections.append(ModuleConnection(
            source: .bio,
            destination: .audio,
            transform: .bioToAudioParameters
        ))

        moduleConnections.append(ModuleConnection(
            source: .audio,
            destination: .visual,
            transform: .audioToVisualParameters
        ))

        // Bio → AI Composer
        moduleConnections.append(ModuleConnection(
            source: .bio,
            destination: .ai,
            transform: .bioToMusicStyle
        ))

        // AI Composer → Physical Modeling
        moduleConnections.append(ModuleConnection(
            source: .ai,
            destination: .physical,
            transform: .composerToSynthParameters
        ))

        // MIDI → LED
        moduleConnections.append(ModuleConnection(
            source: .midi,
            destination: .led,
            transform: .midiToLightColors
        ))

        // Audio → OSC broadcast
        moduleConnections.append(ModuleConnection(
            source: .audio,
            destination: .osc,
            transform: .audioToOSCMessages
        ))

        // Bio → OSC broadcast
        moduleConnections.append(ModuleConnection(
            source: .bio,
            destination: .osc,
            transform: .bioToOSCMessages
        ))

        // Recording → Cloud
        moduleConnections.append(ModuleConnection(
            source: .recording,
            destination: .cloud,
            transform: .sessionToCloudSync
        ))

        // Automation → All audio parameters
        moduleConnections.append(ModuleConnection(
            source: .automation,
            destination: .audio,
            transform: .automationToParameters
        ))

        // Visual → Streaming
        moduleConnections.append(ModuleConnection(
            source: .visual,
            destination: .streaming,
            transform: .visualToStreamScene
        ))

        // Bio → Streaming (scene switching)
        moduleConnections.append(ModuleConnection(
            source: .bio,
            destination: .streaming,
            transform: .bioToSceneTriggers
        ))
    }

    private func setupDataRoutes() {
        // Primary data routes for real-time processing
        dataRoutes = [
            DataRoute(
                name: "Bio-Audio-Visual Pipeline",
                modules: [.bio, .audio, .visual],
                priority: .realtime,
                maxLatency: 0.016 // 60fps
            ),
            DataRoute(
                name: "MIDI Processing",
                modules: [.midi, .audio, .led],
                priority: .realtime,
                maxLatency: 0.005 // <5ms for MIDI
            ),
            DataRoute(
                name: "AI Generation",
                modules: [.bio, .ai, .physical, .audio],
                priority: .high,
                maxLatency: 0.1
            ),
            DataRoute(
                name: "Streaming Pipeline",
                modules: [.audio, .visual, .video, .streaming],
                priority: .realtime,
                maxLatency: 0.033 // 30fps minimum
            ),
            DataRoute(
                name: "Cloud Sync",
                modules: [.recording, .cloud, .collaboration],
                priority: .background,
                maxLatency: 5.0
            )
        ]
    }

    // MARK: - Bio Data Distribution

    func distributeBioData(heartRate: Float, hrv: Float, coherence: Float, respirationRate: Float? = nil) {
        let startTime = Date()

        // Update cached state
        currentBioState = BioState(
            heartRate: heartRate,
            hrv: hrv,
            coherence: coherence,
            respirationRate: respirationRate ?? estimateRespirationRate(from: hrv),
            timestamp: Date()
        )

        // Distribute to all connected bio consumers
        for connection in moduleConnections where connection.source == .bio {
            routeBioData(to: connection.destination, using: connection.transform)
        }

        // Update latency metrics
        dataFlowRate.bioToAudioLatency = Date().timeIntervalSince(startTime)
        messageCount += 1
    }

    private func routeBioData(to destination: ModuleType, using transform: DataTransform) {
        switch destination {
        case .audio:
            // Route to audio engine for parameter modulation
            let audioParams = transform.transformBioToAudio(currentBioState)
            AudioParameterBridge.shared?.applyBioParameters(audioParams)

        case .visual:
            // Route to visual engine
            VisualParameterBridge.shared?.updateBioData(
                hrv: currentBioState.hrv,
                coherence: currentBioState.coherence,
                heartRate: currentBioState.heartRate
            )

        case .ai:
            // Route to AI composer for style adaptation
            AIComposerBridge.shared?.updateBioState(currentBioState)

        case .osc:
            // Broadcast via OSC
            OSCBridge.shared?.streamBioData(
                heartRate: currentBioState.heartRate,
                hrv: currentBioState.hrv,
                coherence: currentBioState.coherence
            )

        case .streaming:
            // Update stream engine for bio-reactive scenes
            StreamBridge.shared?.updateBioParameters(
                coherence: currentBioState.coherence,
                heartRate: currentBioState.heartRate,
                hrv: currentBioState.hrv
            )

        case .automation:
            // Update automation engine
            AutomationBridge.shared?.updateBioData(
                heartRate: currentBioState.heartRate,
                hrv: currentBioState.hrv,
                coherence: currentBioState.coherence
            )

        default:
            break
        }
    }

    // MARK: - Audio Data Distribution

    func distributeAudioData(buffer: [Float], spectrum: [Float]? = nil, pitch: Float? = nil) {
        let startTime = Date()

        for connection in moduleConnections where connection.source == .audio {
            routeAudioData(
                to: connection.destination,
                buffer: buffer,
                spectrum: spectrum,
                pitch: pitch
            )
        }

        // Update latency metrics
        dataFlowRate.audioToVisualLatency = Date().timeIntervalSince(startTime)
    }

    private func routeAudioData(to destination: ModuleType, buffer: [Float], spectrum: [Float]?, pitch: Float?) {
        switch destination {
        case .visual:
            VisualParameterBridge.shared?.processAudioBuffer(buffer)
            if let spectrum = spectrum {
                VisualParameterBridge.shared?.updateSpectrum(spectrum)
            }

        case .osc:
            if let pitch = pitch {
                OSCBridge.shared?.sendAudioData(level: buffer.map { abs($0) }.max() ?? 0, pitch: pitch)
            }

        case .streaming:
            // Audio is mixed into stream
            break

        case .led:
            // Audio-reactive LED control
            LEDBridge.shared?.updateFromAudio(buffer: buffer, spectrum: spectrum)

        default:
            break
        }
    }

    // MARK: - MIDI Distribution

    func distributeMIDIEvent(_ event: MIDIEvent) {
        for connection in moduleConnections where connection.source == .midi {
            routeMIDIEvent(to: connection.destination, event: event)
        }
    }

    private func routeMIDIEvent(to destination: ModuleType, event: MIDIEvent) {
        switch destination {
        case .audio:
            AudioParameterBridge.shared?.handleMIDI(event)

        case .led:
            LEDBridge.shared?.handleMIDI(event)

        case .visual:
            VisualParameterBridge.shared?.handleMIDI(event)

        case .automation:
            AutomationBridge.shared?.handleMIDI(event)

        case .osc:
            OSCBridge.shared?.forwardMIDI(event)

        default:
            break
        }
    }

    // MARK: - OSC Message Distribution

    func distributeOSCMessage(_ message: OSCMessageData) {
        // Route incoming OSC to appropriate modules
        let address = message.address

        if address.hasPrefix("/audio") {
            AudioParameterBridge.shared?.handleOSC(message)
        } else if address.hasPrefix("/visual") {
            VisualParameterBridge.shared?.handleOSC(message)
        } else if address.hasPrefix("/bio") {
            // External bio data source
            if let heartRate = message.floatValue(at: "/bio/heartRate"),
               let hrv = message.floatValue(at: "/bio/hrv"),
               let coherence = message.floatValue(at: "/bio/coherence") {
                distributeBioData(heartRate: heartRate, hrv: hrv, coherence: coherence)
            }
        } else if address.hasPrefix("/midi") {
            // MIDI over OSC
            if let event = message.toMIDIEvent() {
                distributeMIDIEvent(event)
            }
        } else if address.hasPrefix("/scene") {
            StreamBridge.shared?.handleOSC(message)
        }
    }

    // MARK: - Automation Distribution

    func distributeAutomationValue(parameter: String, value: Float, target: String) {
        // Route automation to appropriate module
        let components = target.split(separator: "/")
        guard let moduleStr = components.first else { return }

        switch String(moduleStr) {
        case "audio":
            AudioParameterBridge.shared?.setParameter(parameter, value: value)

        case "visual":
            VisualParameterBridge.shared?.setParameter(parameter, value: value)

        case "synth", "physical":
            PhysicalModelBridge.shared?.setParameter(parameter, value: value)

        case "stream":
            StreamBridge.shared?.setParameter(parameter, value: value)

        default:
            break
        }
    }

    // MARK: - Recording/Cloud Integration

    func syncRecordingToCloud(_ session: RecordingSessionData) {
        guard activeModules.contains(.cloud) else { return }

        Task {
            await CloudBridge.shared?.syncSession(session)
        }
    }

    func syncCollaborationState(_ state: CollaborationState) {
        guard activeModules.contains(.collaboration) else { return }

        Task {
            await CollaborationBridge.shared?.syncState(state)
        }
    }

    // MARK: - Module Management

    func activateModule(_ module: ModuleType) {
        activeModules.insert(module)
        updateSystemHealth()
        print("✅ UnifiedSystemIntegration: Activated \(module.rawValue)")
    }

    func deactivateModule(_ module: ModuleType) {
        activeModules.remove(module)
        updateSystemHealth()
        print("⏹️ UnifiedSystemIntegration: Deactivated \(module.rawValue)")
    }

    func isModuleActive(_ module: ModuleType) -> Bool {
        activeModules.contains(module)
    }

    // MARK: - Health Monitoring

    private func startMonitoring() {
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateMetrics()
            }
            .store(in: &cancellables)
    }

    private func updateMetrics() {
        // Calculate messages per second
        let elapsed = Date().timeIntervalSince(lastUpdateTime)
        if elapsed > 0 {
            dataFlowRate.messagesPerSecond = Int(Double(messageCount) / elapsed)
        }

        messageCount = 0
        lastUpdateTime = Date()

        // Calculate total pipeline latency
        dataFlowRate.totalPipelineLatency = dataFlowRate.bioToAudioLatency + dataFlowRate.audioToVisualLatency

        updateSystemHealth()
    }

    private func updateSystemHealth() {
        let latency = dataFlowRate.totalPipelineLatency

        if latency < 0.010 && dataFlowRate.droppedMessages == 0 {
            systemHealth = .optimal
        } else if latency < 0.033 && dataFlowRate.droppedMessages < 10 {
            systemHealth = .good
        } else if latency < 0.100 {
            systemHealth = .degraded
        } else {
            systemHealth = .critical
        }
    }

    // MARK: - Utilities

    private func estimateRespirationRate(from hrv: Float) -> Float {
        // RSA (Respiratory Sinus Arrhythmia) estimation
        // Higher HRV often correlates with slower, deeper breathing
        return 6.0 + (100.0 - hrv) / 100.0 * 12.0 // 6-18 breaths/min
    }

    // MARK: - Configuration

    func configureConnection(from source: ModuleType, to destination: ModuleType, enabled: Bool) {
        if enabled {
            if !moduleConnections.contains(where: { $0.source == source && $0.destination == destination }) {
                moduleConnections.append(ModuleConnection(
                    source: source,
                    destination: destination,
                    transform: .identity
                ))
            }
        } else {
            moduleConnections.removeAll { $0.source == source && $0.destination == destination }
        }
    }

    func getActiveConnections() -> [ModuleConnection] {
        moduleConnections.filter { activeModules.contains($0.source) && activeModules.contains($0.destination) }
    }

    // MARK: - Diagnostics

    func generateDiagnosticReport() -> String {
        var report = """
        ═══════════════════════════════════════════
        ECHOELMUSIC SYSTEM DIAGNOSTIC REPORT
        ═══════════════════════════════════════════

        System Health: \(systemHealth.rawValue)

        Active Modules (\(activeModules.count)/\(ModuleType.allCases.count)):
        """

        for module in ModuleType.allCases {
            let status = activeModules.contains(module) ? "✅" : "⏹️"
            report += "\n  \(status) \(module.rawValue)"
        }

        report += """


        Data Flow Metrics:
          Bio → Audio Latency: \(String(format: "%.3f", dataFlowRate.bioToAudioLatency * 1000))ms
          Audio → Visual Latency: \(String(format: "%.3f", dataFlowRate.audioToVisualLatency * 1000))ms
          Total Pipeline Latency: \(String(format: "%.3f", dataFlowRate.totalPipelineLatency * 1000))ms
          Messages/Second: \(dataFlowRate.messagesPerSecond)
          Dropped Messages: \(dataFlowRate.droppedMessages)

        Active Connections: \(getActiveConnections().count)

        """

        return report
    }
}

// MARK: - Supporting Types

struct ModuleConnection: Identifiable {
    let id = UUID()
    let source: UnifiedSystemIntegration.ModuleType
    let destination: UnifiedSystemIntegration.ModuleType
    let transform: DataTransform
}

struct DataRoute {
    let name: String
    let modules: [UnifiedSystemIntegration.ModuleType]
    let priority: Priority
    let maxLatency: TimeInterval

    enum Priority {
        case realtime
        case high
        case normal
        case background
    }
}

struct BioState {
    var heartRate: Float = 70.0
    var hrv: Float = 50.0
    var coherence: Float = 0.5
    var respirationRate: Float = 12.0
    var timestamp: Date = Date()
}

struct MIDIEvent {
    let status: UInt8
    let channel: UInt8
    let data1: UInt8
    let data2: UInt8
    let timestamp: UInt64

    var isNoteOn: Bool { (status & 0xF0) == 0x90 && data2 > 0 }
    var isNoteOff: Bool { (status & 0xF0) == 0x80 || (isNoteOn && data2 == 0) }
    var isCC: Bool { (status & 0xF0) == 0xB0 }
}

struct OSCMessageData {
    let address: String
    let arguments: [Any]

    func floatValue(at path: String) -> Float? {
        guard address == path, let value = arguments.first as? Float else { return nil }
        return value
    }

    func toMIDIEvent() -> MIDIEvent? {
        guard address.hasPrefix("/midi"),
              arguments.count >= 3,
              let status = arguments[0] as? UInt8,
              let data1 = arguments[1] as? UInt8,
              let data2 = arguments[2] as? UInt8 else {
            return nil
        }
        return MIDIEvent(status: status, channel: status & 0x0F, data1: data1, data2: data2, timestamp: 0)
    }
}

struct RecordingSessionData {
    let id: UUID
    let name: String
    let duration: TimeInterval
    let tracks: Int
    let fileSize: Int64
}

struct CollaborationState {
    let sessionId: UUID
    let participants: Int
    let lastUpdate: Date
}

// MARK: - Data Transforms

enum DataTransform {
    case identity
    case bioToAudioParameters
    case bioToVisualParameters
    case bioToMusicStyle
    case audioToVisualParameters
    case audioToOSCMessages
    case bioToOSCMessages
    case composerToSynthParameters
    case midiToLightColors
    case sessionToCloudSync
    case automationToParameters
    case visualToStreamScene
    case bioToSceneTriggers

    func transformBioToAudio(_ bio: BioState) -> AudioParameters {
        AudioParameters(
            filterCutoff: 200 + bio.coherence * 2000,
            filterResonance: 0.3 + bio.hrv / 200.0,
            reverbMix: 0.2 + bio.coherence * 0.4,
            tempo: 60 + bio.heartRate
        )
    }
}

struct AudioParameters {
    var filterCutoff: Float = 1000
    var filterResonance: Float = 0.5
    var reverbMix: Float = 0.3
    var tempo: Float = 120
}

// MARK: - Bridge Protocols (Placeholders)

class AudioParameterBridge {
    static var shared: AudioParameterBridge?
    func applyBioParameters(_ params: AudioParameters) {}
    func handleMIDI(_ event: MIDIEvent) {}
    func handleOSC(_ message: OSCMessageData) {}
    func setParameter(_ name: String, value: Float) {}
}

class VisualParameterBridge {
    static var shared: VisualParameterBridge?
    func updateBioData(hrv: Float, coherence: Float, heartRate: Float) {}
    func processAudioBuffer(_ buffer: [Float]) {}
    func updateSpectrum(_ spectrum: [Float]) {}
    func handleMIDI(_ event: MIDIEvent) {}
    func handleOSC(_ message: OSCMessageData) {}
    func setParameter(_ name: String, value: Float) {}
}

class AIComposerBridge {
    static var shared: AIComposerBridge?
    func updateBioState(_ state: BioState) {}
}

class OSCBridge {
    static var shared: OSCBridge?
    func streamBioData(heartRate: Float, hrv: Float, coherence: Float) {}
    func sendAudioData(level: Float, pitch: Float) {}
    func forwardMIDI(_ event: MIDIEvent) {}
}

class StreamBridge {
    static var shared: StreamBridge?
    func updateBioParameters(coherence: Float, heartRate: Float, hrv: Float) {}
    func handleOSC(_ message: OSCMessageData) {}
    func setParameter(_ name: String, value: Float) {}
}

class AutomationBridge {
    static var shared: AutomationBridge?
    func updateBioData(heartRate: Float, hrv: Float, coherence: Float) {}
    func handleMIDI(_ event: MIDIEvent) {}
}

class LEDBridge {
    static var shared: LEDBridge?
    func handleMIDI(_ event: MIDIEvent) {}
    func updateFromAudio(buffer: [Float], spectrum: [Float]?) {}
}

class PhysicalModelBridge {
    static var shared: PhysicalModelBridge?
    func setParameter(_ name: String, value: Float) {}
}

class CloudBridge {
    static var shared: CloudBridge?
    func syncSession(_ session: RecordingSessionData) async {}
}

class CollaborationBridge {
    static var shared: CollaborationBridge?
    func syncState(_ state: CollaborationState) async {}
}
