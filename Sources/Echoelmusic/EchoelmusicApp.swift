#if canImport(SwiftUI)
import SwiftUI

/// Echoelmusic — DAW + Video Production
/// Clean, minimal entry point. No intro animation — straight to the app.
@main
struct EchoelmusicApp: App {

    @State private var audioEngine: AudioEngine
    @State private var microphoneManager: MicrophoneManager
    @State private var recordingEngine = RecordingEngine()
    @State private var themeManager = ThemeManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let mic = MicrophoneManager()
        _microphoneManager = State(wrappedValue: mic)
        _audioEngine = State(wrappedValue: AudioEngine(microphoneManager: mic))

        // Eager init of critical singletons — memory handler first for pressure monitoring
        _ = MemoryPressureHandler.shared
        _ = CrashSafeStatePersistence.shared
    }

    var body: some Scene {
        WindowGroup {
            MainNavigationHub()
                .environment(audioEngine)
                .environment(microphoneManager)
                .environment(recordingEngine)
                .environment(themeManager)
                .preferredColorScheme(themeManager.resolvedColorScheme)
                .task {
                    // Deferred singleton init — runs after first frame renders.
                    // Using .task instead of .onAppear to avoid blocking the main thread
                    // with heavy DSP/Metal initialization during app launch.
                    TuningBridge.shared.activate()

                    // Complete heavy workspace init (StageEngine, VisEngine, default session)
                    EchoelCreativeWorkspace.shared.deferredSetup()

                    _ = InstrumentOrchestrator.shared
                    _ = EchoelBeat.shared

                    recordingEngine.connectAudioEngine(audioEngine)
                    EchoelCreativeWorkspace.shared.connectAudioEngine(audioEngine)
                    InstrumentOrchestrator.shared.connectMainAudioEngine(audioEngine)
                    audioEngine.start()

                    // Request HealthKit authorization, then start bio streaming.
                    // Must happen AFTER workspace.deferredSetup() so engines are ready,
                    // but auth must complete BEFORE startStreaming() so HealthKit data
                    // is used instead of mic fallback.
                    _ = await EchoelBioEngine.shared.requestAuthorization()
                    EchoelBioEngine.shared.startStreaming()
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    switch newPhase {
                    case .active:
                        // Resuming from background — re-activate audio session
                        // to recover from potential interruption
                        if oldPhase == .background {
                            audioEngine.start()
                            log.log(.info, category: .system, "App active — audio engine resumed")
                        }
                    case .background:
                        // Audio continues in background (UIBackgroundModes=audio).
                        // Auto-save timer handles state persistence.
                        log.log(.info, category: .system, "App backgrounded")
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
        }
    }
}
#endif
