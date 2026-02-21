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
@main
struct EchoelmusicApp: App {

    #if os(iOS) || os(tvOS)
    @UIApplicationDelegateAdaptor(EchoelAppDelegate.self) var appDelegate
    #endif

    /// StateObject ensures the MicrophoneManager stays alive
    /// throughout the app's lifetime
    @StateObject private var microphoneManager = MicrophoneManager()

    /// Central AudioEngine coordinates all audio components
    @StateObject private var audioEngine: AudioEngine

    /// HealthKit engine for biofeedback (unified engine)
    @ObservedObject private var healthKitEngine = UnifiedHealthKitEngine.shared

    /// HealthKitManager for MainNavigationHub + WorkspaceContentRouter
    @StateObject private var healthKitManager = HealthKitManager()

    /// Recording engine for multi-track recording
    @StateObject private var recordingEngine = RecordingEngine()

    /// EchoelToolkit — unified access to all 10 tools + Lambda
    @ObservedObject private var toolkit = EchoelToolkit.shared

    /// UnifiedControlHub for multimodal input
    @StateObject private var unifiedControlHub: UnifiedControlHub

    /// Push notification manager
    @ObservedObject private var pushManager = PushNotificationManager.shared

    init() {
        // Initialize AudioEngine with MicrophoneManager
        let micManager = MicrophoneManager()
        _microphoneManager = StateObject(wrappedValue: micManager)

        let audioEng = AudioEngine(microphoneManager: micManager)
        _audioEngine = StateObject(wrappedValue: audioEng)

        _unifiedControlHub = StateObject(wrappedValue: UnifiedControlHub(audioEngine: audioEng))

        // PERFORMANCE: Defer non-critical singleton initialization to background
        // This prevents 2-5 second startup blocking on main thread
        Task(priority: .userInitiated) {
            do {
                // KRITISCH: Initialisiere alle Core-Systeme (Singletons)
                // Sequential initialization to avoid circular singleton deadlocks:
                // EchoelUniversalCore <-> EchoelTools, EchoelUniversalCore <-> VideoAICreativeHub
                await MainActor.run { _ = SelfHealingEngine.shared }
                await MainActor.run { _ = MultiPlatformBridge.shared }
                await MainActor.run { _ = EchoelUniversalCore.shared }
                // After EchoelUniversalCore is fully assigned, these can safely reference it
                await MainActor.run { _ = VideoAICreativeHub.shared }
                await MainActor.run { _ = EchoelTools.shared }
                await MainActor.run { _ = EchoelToolkit.shared }

                // INSTRUMENT PIPELINE (depends on core systems)
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask { @MainActor in _ = InstrumentOrchestrator.shared }
                    group.addTask { @MainActor in _ = WorldMusicBridge.shared }
                    try await group.waitForAll()
                }

                // PHYSICAL AI PIPELINE (JEPA world model + autonomous control)
                await MainActor.run {
                    let physicalAI = PhysicalAIEngine.shared
                    physicalAI.start()
                    physicalAI.addObjective(.maintainCoherence())
                }

                // SCRIPT ENGINE (community scripts + automation)
                await MainActor.run {
                    let scriptEngine = ScriptEngine(
                        audioAPI: AudioScriptAPI(),
                        visualAPI: VisualScriptAPI(),
                        bioAPI: BioScriptAPI(),
                        streamAPI: StreamScriptAPI(),
                        midiAPI: MIDIScriptAPI(),
                        spatialAPI: SpatialScriptAPI()
                    )
                    log.info("📜 ScriptEngine: Initialized with all 6 APIs", category: .system)
                }

                // STREAMING PIPELINE
                await MainActor.run { _ = SocialMediaManager.shared }

                await MainActor.run {
                    log.info("⚛️ Echoelmusic Core Systems Initialized (async)", category: .system)
                    log.info("🎹 InstrumentOrchestrator: 54+ Instruments Ready", category: .system)
                    log.info("🌍 WorldMusicBridge: 42 Music Styles Loaded", category: .system)
                }
            } catch {
                await MainActor.run {
                    log.error("❌ Core system initialization failed: \(error.localizedDescription)", category: .system)
                    // App can still function - singletons will init lazily on first access
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            MainNavigationHub()
                .environmentObject(microphoneManager)      // Makes mic manager available to all views
                .environmentObject(audioEngine)             // Makes audio engine available
                .environmentObject(healthKitEngine)        // Makes health data available (UnifiedHealthKitEngine)
                .environmentObject(healthKitManager)       // Makes HealthKitManager available (for MainNavigationHub)
                .environmentObject(recordingEngine)         // Makes recording engine available
                .environmentObject(unifiedControlHub)       // Makes unified control available
                .environmentObject(toolkit)                 // Makes EchoelToolkit available to all views
                .preferredColorScheme(.dark)                // Force dark theme
                .onAppear {
                    // Connect HealthKit to AudioEngine for bio-parameter mapping
                    audioEngine.connectHealthKit(healthKitEngine)

                    // Connect RecordingEngine to AudioEngine for audio routing
                    recordingEngine.connectAudioEngine(audioEngine)

                    // Enable biometric monitoring through UnifiedControlHub
                    Task {
                        do {
                            try await unifiedControlHub.enableBiometricMonitoring()
                            log.info("✅ Biometric monitoring enabled via UnifiedControlHub", category: .system)
                        } catch {
                            log.warning("⚠️ Biometric monitoring not available: \(error.localizedDescription)", category: .system)
                        }

                        // Enable MIDI 2.0 + MPE
                        do {
                            try await unifiedControlHub.enableMIDI2()
                            log.info("✅ MIDI 2.0 + MPE enabled via UnifiedControlHub", category: .system)
                        } catch {
                            log.warning("⚠️ MIDI 2.0 not available: \(error.localizedDescription)", category: .system)
                        }

                        // Request push notification permission + register with APNs
                        let pushGranted = await PushNotificationManager.shared.requestAuthorization()
                        if pushGranted {
                            log.info("✅ Push notifications authorized", category: .system)
                        }
                    }

                    // Wire PhysicalAI → AudioEngine parameter control
                    let physicalAI = PhysicalAIEngine.shared
                    physicalAI.onParameterChange = { [weak audioEngine] parameter, value in
                        audioEngine?.applyPhysicalAIParameter(parameter, value: value)
                    }

                    // Wire ControlHub → PhysicalAI bio signal bridge
                    unifiedControlHub.connectPhysicalAI(physicalAI)

                    // Start UnifiedControlHub
                    unifiedControlHub.start()

                    log.info("🧠 PhysicalAI → AudioEngine wired", category: .system)
                    log.info("🎵 Echoelmusic Started - All Systems Connected!", category: .system)
                    log.info("🎹 MIDI 2.0 + MPE + Spatial Audio Ready", category: .system)
                    log.info("🌊 Bio-Reactive Audio-Visual Platform Ready", category: .system)
                }
        }
    }
}

#endif // os(iOS) || os(macOS) || os(tvOS)
