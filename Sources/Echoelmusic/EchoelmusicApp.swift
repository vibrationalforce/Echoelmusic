import SwiftUI
import UserNotifications

#if os(iOS) || os(tvOS)
/// AppDelegate adaptor for APNs device token callbacks
class EchoelAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in
            PushNotificationManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
        }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in
            PushNotificationManager.shared.didFailToRegisterForRemoteNotifications(error: error)
        }
    }
}
#endif

#if os(iOS) || os(macOS) || os(tvOS)

/// Main entry point for the Echoelmusic app
/// Bio-reactive audio-visual experiences platform
///
/// ARCHITECTURE: Splash-screen-gated startup
/// All singletons are initialized SEQUENTIALLY in `initializeCoreSystems()`,
/// which runs asynchronously while the LaunchScreen is displayed.
/// MainNavigationHub is ONLY rendered after all systems are ready.
/// This prevents:
/// 1. Circular singleton deadlocks (sequential init order)
/// 2. Race conditions (no eager @ObservedObject singleton access)
/// 3. UI rendering before systems are initialized
@main
struct EchoelmusicApp: App {

    #if os(iOS) || os(tvOS)
    @UIApplicationDelegateAdaptor(EchoelAppDelegate.self) var appDelegate
    #endif

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Owned State Objects (lightweight, no singleton dependencies)

    /// StateObject ensures the MicrophoneManager stays alive
    /// throughout the app's lifetime
    @StateObject private var microphoneManager = MicrophoneManager()

    /// Central AudioEngine coordinates all audio components
    @StateObject private var audioEngine: AudioEngine

    /// HealthKitManager for MainNavigationHub + WorkspaceContentRouter
    @StateObject private var healthKitManager = HealthKitManager()

    /// Recording engine for multi-track recording
    @StateObject private var recordingEngine = RecordingEngine()

    /// UnifiedControlHub for multimodal input
    @StateObject private var unifiedControlHub: UnifiedControlHub

    // MARK: - Initialization Gate
    // NOTE: Singletons (UnifiedHealthKitEngine, EchoelToolkit, PushNotificationManager,
    // EchoelUniversalCore, etc.) are NO LONGER accessed eagerly via @ObservedObject.
    // They were causing a massive synchronous init cascade of 30+ objects BEFORE
    // the init() body even ran, bypassing the sequential initialization entirely.
    // Now they are initialized in initializeCoreSystems() and accessed via .shared
    // only after coreSystemsReady == true.

    @State private var coreSystemsReady = false

    init() {
        // Initialize AudioEngine with MicrophoneManager
        let micManager = MicrophoneManager()
        _microphoneManager = StateObject(wrappedValue: micManager)

        let audioEng = AudioEngine(microphoneManager: micManager)
        _audioEngine = StateObject(wrappedValue: audioEng)

        _unifiedControlHub = StateObject(wrappedValue: UnifiedControlHub(audioEngine: audioEng))
    }

    var body: some Scene {
        WindowGroup {
            if coreSystemsReady {
                mainContent
            } else {
                LaunchScreen()
                    .preferredColorScheme(.dark)
                    .task {
                        await initializeCoreSystems()
                        coreSystemsReady = true
                    }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            switch newPhase {
            case .background:
                // Save state before app gets suspended/terminated
                if let state = buildCurrentSessionState() {
                    CrashSafeStatePersistence.shared.saveState(state)
                }
            case .active:
                // Re-probe capabilities (user may have changed permissions in Settings)
                AdaptiveCapabilityManager.shared.refreshAll()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }

    /// Build a minimal session state snapshot for crash recovery
    private func buildCurrentSessionState() -> SessionState? {
        guard coreSystemsReady else { return nil }
        return SessionState()
    }

    // MARK: - Main Content (only rendered after core systems are ready)

    @ViewBuilder
    private var mainContent: some View {
        MainNavigationHub()
            .environmentObject(microphoneManager)
            .environmentObject(audioEngine)
            .environmentObject(UnifiedHealthKitEngine.shared)
            .environmentObject(healthKitManager)
            .environmentObject(recordingEngine)
            .environmentObject(unifiedControlHub)
            .environmentObject(EchoelToolkit.shared)
            .preferredColorScheme(.dark)
            .onAppear {
                connectSystems()
            }
    }

    // MARK: - Sequential Core System Initialization

    /// Initializes all singletons in a controlled, sequential order.
    /// Each phase waits for the previous to complete, preventing circular deadlocks.
    /// Each phase is individually isolated so a single failure doesn't block the rest.
    private func initializeCoreSystems() async {
        // Phase 0: Detect hardware + permissions (all other systems query this)
        await MainActor.run { _ = AdaptiveCapabilityManager.shared }

        // Phase 0.5: Memory pressure monitoring (prevents OOM crashes)
        await MainActor.run { _ = MemoryPressureHandler.shared }

        // Phase 1: Foundation singletons (no cross-references)
        await MainActor.run { _ = UnifiedHealthKitEngine.shared }
        await MainActor.run { _ = PushNotificationManager.shared }
        await MainActor.run { _ = SelfHealingEngine.shared }
        await MainActor.run { _ = MultiPlatformBridge.shared }

        // Phase 2: Core hub (references SelfHealingEngine, MultiPlatformBridge lazily)
        await MainActor.run { _ = EchoelUniversalCore.shared }

        // Phase 3: Systems that reference EchoelUniversalCore
        await MainActor.run { _ = VideoAICreativeHub.shared }
        await MainActor.run { _ = EchoelTools.shared }

        // Phase 4: EchoelToolkit (creates all 10 Echoel* tools — largest init chain)
        await MainActor.run { _ = EchoelToolkit.shared }

        // Phase 5: Instrument pipeline (can run in parallel)
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { @MainActor in _ = InstrumentOrchestrator.shared }
                group.addTask { @MainActor in _ = WorldMusicBridge.shared }
                try await group.waitForAll()
            }
        } catch {
            await MainActor.run {
                log.warning("Phase 5 (Instruments) failed: \(error.localizedDescription)", category: .system)
            }
        }

        // Phase 6: Physical AI (JEPA world model + autonomous control)
        await MainActor.run {
            let physicalAI = PhysicalAIEngine.shared
            physicalAI.start()
            physicalAI.addObjective(.maintainCoherence())
        }

        // Phase 7: Script engine (community scripts + automation)
        await MainActor.run {
            ScriptEngine.shared = ScriptEngine(
                audioAPI: AudioScriptAPI(),
                visualAPI: VisualScriptAPI(),
                bioAPI: BioScriptAPI(),
                streamAPI: StreamScriptAPI(),
                midiAPI: MIDIScriptAPI(),
                spatialAPI: SpatialScriptAPI()
            )
            log.info("ScriptEngine: Initialized with all 6 APIs", category: .system)
        }

        // Phase 8: Streaming pipeline
        await MainActor.run { _ = SocialMediaManager.shared }

        // Phase 9: Crash-safe state persistence (auto-save every 10s, recover on next launch)
        await MainActor.run { _ = CrashSafeStatePersistence.shared }

        await MainActor.run {
            log.info("Echoelmusic Core Systems Initialized", category: .system)
        }
    }

    // MARK: - System Connections (runs after MainNavigationHub appears)

    /// Wires all systems together after UI is ready and all singletons are initialized.
    private func connectSystems() {
        let healthKitEngine = UnifiedHealthKitEngine.shared

        // Connect HealthKit to AudioEngine for bio-parameter mapping
        audioEngine.connectHealthKit(healthKitEngine)

        // Connect RecordingEngine to AudioEngine for audio routing
        recordingEngine.connectAudioEngine(audioEngine)

        // Wire PhysicalAI → AudioEngine parameter control
        let physicalAI = PhysicalAIEngine.shared
        physicalAI.onParameterChange = { [weak audioEngine] parameter, value in
            audioEngine?.applyPhysicalAIParameter(parameter, value: value)
        }

        // Wire ControlHub → PhysicalAI bio signal bridge
        unifiedControlHub.connectPhysicalAI(physicalAI)

        // Start UnifiedControlHub
        unifiedControlHub.start()

        // Async tasks: biometric monitoring, MIDI, push notifications
        Task {
            do {
                try await unifiedControlHub.enableBiometricMonitoring()
                log.info("Biometric monitoring enabled via UnifiedControlHub", category: .system)
            } catch {
                log.warning("Biometric monitoring not available: \(error.localizedDescription)", category: .system)
            }

            do {
                try await unifiedControlHub.enableMIDI2()
                log.info("MIDI 2.0 + MPE enabled via UnifiedControlHub", category: .system)
            } catch {
                log.warning("MIDI 2.0 not available: \(error.localizedDescription)", category: .system)
            }

            let pushGranted = await PushNotificationManager.shared.requestAuthorization()
            if pushGranted {
                log.info("Push notifications authorized", category: .system)
            }
        }

        log.info("Bio-Reactive Audio-Visual Platform Ready", category: .system)
    }
}

#endif // os(iOS) || os(macOS) || os(tvOS)
