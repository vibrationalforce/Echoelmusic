import SwiftUI
import Combine
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

/// Reference-type holder for Combine subscriptions in value-type (struct) contexts
fileprivate final class CancellableHolder {
    var cancellables = Set<AnyCancellable>()
}

extension AnyCancellable {
    fileprivate func store(in holder: CancellableHolder) {
        self.store(in: &holder.cancellables)
    }
}

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

    @StateObject private var themeManager = ThemeManager()

    /// Holds Combine subscriptions for system-level bridges
    private let systemCancellables = CancellableHolder()

    @State private var coreSystemsReady = false
    @State private var initializationPhase: String = "Starting..."
    @State private var initializationProgress: Double = 0
    @State private var failedPhases: [String] = []
    @State private var showOnboarding = false

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
                LaunchScreen(
                    phase: initializationPhase,
                    progress: initializationProgress
                )
                    .preferredColorScheme(themeManager.resolvedColorScheme)
                    .task {
                        // Watchdog: unstructured Task fires after 10s to force-proceed.
                        // CRITICAL: Previous TaskGroup-based watchdog was broken because
                        // withTaskGroup MUST wait for ALL child tasks to complete, so if
                        // initializeCoreSystems() hung, the watchdog couldn't bypass it.
                        // Using an unstructured Task avoids this — it runs independently.
                        let watchdog = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 10_000_000_000) // 10s
                            if !coreSystemsReady {
                                log.warning("Core init watchdog: proceeding after 10s timeout", category: .system)
                                coreSystemsReady = true
                            }
                        }

                        await initializeCoreSystems()
                        watchdog.cancel()
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
            .environmentObject(themeManager)
            .preferredColorScheme(themeManager.resolvedColorScheme)
            .onAppear {
                connectSystems()
                // Show onboarding on first launch
                if !OnboardingManager.shared.hasCompletedOnboarding {
                    showOnboarding = true
                }
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView()
            }
    }

    // MARK: - Sequential Core System Initialization

    /// Total initialization phases for progress tracking
    private static let totalPhases: Double = 14

    /// Initializes all singletons in a controlled, sequential order.
    /// Each phase waits for the previous to complete, preventing circular deadlocks.
    /// Each phase is individually isolated so a single failure doesn't block the rest.
    /// Safely initialize a singleton on MainActor, catching any crash
    private func safeInit(_ label: String, phase: Int = 0, _ block: @MainActor () -> Void) async {
        await MainActor.run {
            initializationPhase = label
            initializationProgress = Double(phase) / Self.totalPhases
            block()
            log.debug("✓ [\(phase)/\(Int(Self.totalPhases))] \(label)", category: .system)
        }
    }

    private func initializeCoreSystems() async {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Phase 0: Detect hardware + permissions (all other systems query this)
        await safeInit("Detecting hardware...", phase: 0) { _ = AdaptiveCapabilityManager.shared }

        // Phase 1: Memory pressure monitoring (prevents OOM crashes)
        await safeInit("Memory monitor...", phase: 1) { _ = MemoryPressureHandler.shared }

        // Phase 2-4: Foundation singletons (no cross-references)
        await safeInit("Health & biometrics...", phase: 2) { _ = UnifiedHealthKitEngine.shared }
        await safeInit("Notifications...", phase: 3) { _ = PushNotificationManager.shared }
        await safeInit("Self-healing engine...", phase: 4) { _ = SelfHealingEngine.shared }
        await safeInit("Platform bridge...", phase: 5) { _ = MultiPlatformBridge.shared }

        // Phase 6: Core hub (references SelfHealingEngine, MultiPlatformBridge lazily)
        await safeInit("Universal core...", phase: 6) { _ = EchoelUniversalCore.shared }

        // Phase 7: Systems that reference EchoelUniversalCore
        await safeInit("Video & creative hub...", phase: 7) {
            _ = VideoAICreativeHub.shared
            _ = EchoelTools.shared
        }

        // Phase 8: EchoelToolkit (creates all 10 Echoel* tools — largest init chain)
        await safeInit("Echoel toolkit (10 engines)...", phase: 8) { _ = EchoelToolkit.shared }

        // Phase 9: Instrument pipeline
        await safeInit("Instruments & world music...", phase: 9) {
            _ = InstrumentOrchestrator.shared
            _ = WorldMusicBridge.shared
        }

        // Phase 10: Physical AI (JEPA world model + autonomous control)
        await safeInit("Physical AI engine...", phase: 10) {
            let physicalAI = PhysicalAIEngine.shared
            physicalAI.start()
            physicalAI.addObjective(.maintainCoherence())
        }

        // Phase 11: Script engine (community scripts + automation)
        await safeInit("Script engine...", phase: 11) {
            ScriptEngine.shared = ScriptEngine(
                audioAPI: AudioScriptAPI(),
                visualAPI: VisualScriptAPI(),
                bioAPI: BioScriptAPI(),
                streamAPI: StreamScriptAPI(),
                midiAPI: MIDIScriptAPI(),
                spatialAPI: SpatialScriptAPI()
            )
        }

        // Phase 12: Streaming & social
        await safeInit("Streaming pipeline...", phase: 12) { _ = SocialMediaManager.shared }

        // Phase 13: Creative Workspace (bridges all engines: BPM grid, video, pro engines)
        await safeInit("Creative workspace...", phase: 13) { _ = EchoelCreativeWorkspace.shared }

        // Phase 14: Crash-safe state persistence (auto-save every 10s, recover on next launch)
        await safeInit("State persistence...", phase: 14) { _ = CrashSafeStatePersistence.shared }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        await MainActor.run {
            initializationProgress = 1.0
            initializationPhase = "Ready"
            log.info("Echoelmusic initialized in \(String(format: "%.1f", elapsed))s (14 phases complete)", category: .system)
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

        // Wire EchoelCreativeWorkspace → AudioEngine BPM sync
        // This bridges the creative workspace BPM grid to the audio engine tempo
        let workspace = EchoelCreativeWorkspace.shared
        workspace.$globalBPM
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak audioEngine] bpm in
                audioEngine?.setTempo(Float(bpm))
            }
            .store(in: systemCancellables)

        // Wire EchoelCreativeWorkspace playback → AudioEngine start/stop
        workspace.$isPlaying
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak audioEngine] playing in
                if playing && !(audioEngine?.isRunning ?? false) {
                    audioEngine?.start()
                }
            }
            .store(in: systemCancellables)

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

        log.info("Bio-Reactive Audio-Visual Platform Ready — all systems connected end-to-end", category: .system)
    }
}

#endif // os(iOS) || os(macOS) || os(tvOS)
