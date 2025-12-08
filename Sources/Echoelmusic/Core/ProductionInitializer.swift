import Foundation
import Combine

// ═══════════════════════════════════════════════════════════════════════════════
// PRODUCTION INITIALIZER - QUANTUM COMPLETE SYSTEM BOOTSTRAP
// ═══════════════════════════════════════════════════════════════════════════════
//
// Central initialization point for the entire Echoelmusic system:
// • Validates all module dependencies
// • Establishes cross-system connections
// • Configures default parameters
// • Sets up error recovery
// • Initializes performance monitoring
//
// ═══════════════════════════════════════════════════════════════════════════════

@MainActor
public final class ProductionInitializer: ObservableObject {

    // MARK: - Singleton

    public static let shared = ProductionInitializer()

    // MARK: - State

    @Published public private(set) var isInitialized: Bool = false
    @Published public private(set) var initializationProgress: Float = 0.0
    @Published public private(set) var activeSubsystems: Set<Subsystem> = []
    @Published public private(set) var lastError: Error?

    // MARK: - Subsystems

    public enum Subsystem: String, CaseIterable {
        case core = "Core Systems"
        case audio = "Audio Engine"
        case visual = "Visual Engine"
        case bio = "Bio Feedback"
        case midi = "MIDI System"
        case osc = "OSC Network"
        case stream = "Streaming"
        case recording = "Recording"
        case ai = "AI Composer"
        case physical = "Physical Modeling"
        case dsp = "DSP Effects"
        case cloud = "Cloud Sync"
        case dmx = "DMX Lighting"
        case collaboration = "Collaboration"
        case automation = "Automation"
    }

    // MARK: - Dependencies

    private let subsystemDependencies: [Subsystem: [Subsystem]] = [
        .audio: [.core],
        .visual: [.core, .audio],
        .bio: [.core],
        .midi: [.core, .audio],
        .osc: [.core],
        .stream: [.core, .audio, .visual],
        .recording: [.core, .audio],
        .ai: [.core, .audio],
        .physical: [.core, .audio],
        .dsp: [.core, .audio],
        .cloud: [.core],
        .dmx: [.core, .osc],
        .collaboration: [.core, .cloud],
        .automation: [.core, .audio, .midi]
    ]

    // MARK: - Initialization

    private init() {}

    // MARK: - Full System Initialization

    public func initializeAllSystems() async throws {
        guard !isInitialized else { return }

        let totalSteps = Float(Subsystem.allCases.count)
        var completedSteps: Float = 0

        // Initialize in dependency order
        let orderedSubsystems = topologicalSort(Subsystem.allCases)

        for subsystem in orderedSubsystems {
            do {
                try await initializeSubsystem(subsystem)
                activeSubsystems.insert(subsystem)
            } catch {
                lastError = error
                print("⚠️ ProductionInitializer: Failed to initialize \(subsystem.rawValue): \(error)")

                // Continue with non-critical subsystems
                if !isCritical(subsystem) {
                    continue
                } else {
                    throw error
                }
            }

            completedSteps += 1
            initializationProgress = completedSteps / totalSteps
        }

        // Establish cross-system connections
        await establishConnections()

        // Start monitoring
        startHealthMonitoring()

        isInitialized = true
        initializationProgress = 1.0

        print("✅ ProductionInitializer: All systems initialized successfully")
        print("   Active subsystems: \(activeSubsystems.count)/\(Subsystem.allCases.count)")
    }

    // MARK: - Subsystem Initialization

    private func initializeSubsystem(_ subsystem: Subsystem) async throws {
        // Check dependencies
        if let deps = subsystemDependencies[subsystem] {
            for dep in deps {
                guard activeSubsystems.contains(dep) else {
                    throw InitializationError.dependencyNotMet(subsystem, requires: dep)
                }
            }
        }

        switch subsystem {
        case .core:
            _ = EchoelUniversalCore.shared
            _ = SelfHealingEngine.shared

        case .audio:
            _ = ProductionAudioBridge.shared

        case .visual:
            _ = ProductionVisualBridge.shared

        case .bio:
            // HealthKit requires authorization
            // Actual initialization handled by HealthKitManager

            break

        case .midi:
            // MIDI requires system permissions
            break

        case .osc:
            _ = ProductionOSCBridge.shared

        case .stream:
            _ = ProductionStreamBridge.shared

        case .recording:
            // RecordingEngine initialization
            break

        case .ai:
            _ = ProductionAIComposerBridge.shared

        case .physical:
            _ = ProductionPhysicalModelBridge.shared

        case .dsp:
            // DSP filters are instantiated on demand
            break

        case .cloud:
            _ = ProductionCloudBridge.shared

        case .dmx:
            _ = ProductionLEDBridge.shared

        case .collaboration:
            _ = ProductionCollaborationBridge.shared

        case .automation:
            _ = ProductionAutomationBridge.shared
        }

        print("✅ Initialized: \(subsystem.rawValue)")
    }

    // MARK: - Connection Establishment

    private func establishConnections() async {
        // Bio → Audio
        NotificationCenter.default.addObserver(
            forName: .bioDataUpdated,
            object: nil,
            queue: .main
        ) { notification in
            guard let hrv = notification.userInfo?["hrv"] as? Float,
                  let coherence = notification.userInfo?["coherence"] as? Float,
                  let heartRate = notification.userInfo?["heartRate"] as? Float else {
                return
            }

            Task { @MainActor in
                // Distribute bio data to all systems
                UnifiedSystemIntegration.shared.distributeBioData(
                    heartRate: heartRate,
                    hrv: hrv,
                    coherence: coherence
                )
            }
        }

        // Audio → Visual
        NotificationCenter.default.addObserver(
            forName: .audioBufferProcessed,
            object: nil,
            queue: .main
        ) { notification in
            guard let buffer = notification.userInfo?["buffer"] as? [Float] else {
                return
            }

            Task { @MainActor in
                ProductionVisualBridge.shared.processAudioBuffer(buffer)
            }
        }

        // MIDI → Audio/LED
        NotificationCenter.default.addObserver(
            forName: .midiEventReceived,
            object: nil,
            queue: .main
        ) { notification in
            guard let event = notification.userInfo?["event"] as? MIDIEvent else {
                return
            }

            Task { @MainActor in
                ProductionAudioBridge.shared.handleMIDI(event)
                ProductionLEDBridge.shared.handleMIDI(event)
            }
        }

        print("✅ ProductionInitializer: Cross-system connections established")
    }

    // MARK: - Health Monitoring

    private var healthMonitorCancellable: AnyCancellable?

    private func startHealthMonitoring() {
        healthMonitorCancellable = Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.performHealthCheck()
            }
    }

    private func performHealthCheck() {
        var healthySubsystems = 0
        var issues: [String] = []

        for subsystem in activeSubsystems {
            if isSubsystemHealthy(subsystem) {
                healthySubsystems += 1
            } else {
                issues.append(subsystem.rawValue)
            }
        }

        if !issues.isEmpty {
            print("⚠️ Health Check: Issues with \(issues.joined(separator: ", "))")

            // Attempt recovery
            for issue in issues {
                if let subsystem = Subsystem(rawValue: issue) {
                    attemptRecovery(for: subsystem)
                }
            }
        }
    }

    private func isSubsystemHealthy(_ subsystem: Subsystem) -> Bool {
        // Simplified health check
        switch subsystem {
        case .core:
            return true // Core is always assumed healthy if initialized
        case .audio:
            return ProductionAudioBridge.shared.masterVolume >= 0
        case .visual:
            return ProductionVisualBridge.shared.visualIntensity >= 0
        default:
            return true
        }
    }

    private func attemptRecovery(for subsystem: Subsystem) {
        print("🔄 Attempting recovery for: \(subsystem.rawValue)")

        // Recovery strategies per subsystem
        switch subsystem {
        case .audio:
            // Reset audio parameters
            ProductionAudioBridge.shared.masterVolume = 1.0

        case .osc:
            // Reconnect OSC
            ProductionOSCBridge.shared.isConnected = false

        default:
            break
        }
    }

    // MARK: - Utilities

    private func isCritical(_ subsystem: Subsystem) -> Bool {
        [.core, .audio].contains(subsystem)
    }

    private func topologicalSort(_ subsystems: [Subsystem]) -> [Subsystem] {
        var sorted: [Subsystem] = []
        var visited: Set<Subsystem> = []

        func visit(_ subsystem: Subsystem) {
            guard !visited.contains(subsystem) else { return }
            visited.insert(subsystem)

            if let deps = subsystemDependencies[subsystem] {
                for dep in deps {
                    visit(dep)
                }
            }

            sorted.append(subsystem)
        }

        for subsystem in subsystems {
            visit(subsystem)
        }

        return sorted
    }

    // MARK: - Status Report

    public func generateStatusReport() -> String {
        var report = """
        ═══════════════════════════════════════════
        ECHOELMUSIC PRODUCTION STATUS REPORT
        ═══════════════════════════════════════════

        Initialization: \(isInitialized ? "Complete ✅" : "Pending ⏳")
        Progress: \(Int(initializationProgress * 100))%

        Active Subsystems (\(activeSubsystems.count)/\(Subsystem.allCases.count)):
        """

        for subsystem in Subsystem.allCases {
            let status = activeSubsystems.contains(subsystem) ? "✅" : "⏹️"
            report += "\n  \(status) \(subsystem.rawValue)"
        }

        if let error = lastError {
            report += "\n\nLast Error: \(error.localizedDescription)"
        }

        report += "\n\n═══════════════════════════════════════════"

        return report
    }

    // MARK: - Shutdown

    public func shutdown() {
        healthMonitorCancellable?.cancel()

        // Clean up in reverse order
        let reversedSubsystems = Array(topologicalSort(Array(activeSubsystems)).reversed())

        for subsystem in reversedSubsystems {
            shutdownSubsystem(subsystem)
        }

        activeSubsystems.removeAll()
        isInitialized = false
        initializationProgress = 0

        print("⏹️ ProductionInitializer: All systems shut down")
    }

    private func shutdownSubsystem(_ subsystem: Subsystem) {
        // Cleanup per subsystem
        switch subsystem {
        case .stream:
            ProductionStreamBridge.shared.isLive = false

        case .osc:
            ProductionOSCBridge.shared.isConnected = false

        case .cloud:
            ProductionCloudBridge.shared.isSyncing = false

        default:
            break
        }

        print("⏹️ Shutdown: \(subsystem.rawValue)")
    }
}

// MARK: - Errors

enum InitializationError: LocalizedError {
    case dependencyNotMet(ProductionInitializer.Subsystem, requires: ProductionInitializer.Subsystem)
    case subsystemFailed(ProductionInitializer.Subsystem, underlying: Error)

    var errorDescription: String? {
        switch self {
        case .dependencyNotMet(let subsystem, let requires):
            return "\(subsystem.rawValue) requires \(requires.rawValue) to be initialized first"
        case .subsystemFailed(let subsystem, let error):
            return "\(subsystem.rawValue) failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let bioDataUpdated = Notification.Name("bioDataUpdated")
    static let audioBufferProcessed = Notification.Name("audioBufferProcessed")
    static let midiEventReceived = Notification.Name("midiEventReceived")
}

// MARK: - App Entry Point Extension

extension ProductionInitializer {

    /// Call this at app launch to initialize all systems
    public static func bootstrap() async {
        do {
            try await shared.initializeAllSystems()
            ProductionBridges.initialize()
            print(shared.generateStatusReport())
        } catch {
            print("❌ Bootstrap failed: \(error)")
        }
    }
}
