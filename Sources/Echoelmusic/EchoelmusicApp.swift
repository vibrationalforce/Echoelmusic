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
                    // PHASE 1: Attach ALL source nodes to the audio graph BEFORE starting.
                    // connectToMasterEngine now eagerly attaches source nodes.
                    // Attaching to a running engine can cause EXC_BREAKPOINT crashes.
                    EchoelSynth.shared.connectToMasterEngine(audioEngine)
                    EchoelBass.shared.connectToMasterEngine(audioEngine)
                    TR808BassSynth.shared.connectToMasterEngine(audioEngine)
                    _ = EchoelBeat.shared  // init singleton before connecting
                    EchoelBeat.shared.connectToMasterEngine(audioEngine)

                    // Now start engine with full graph wired
                    audioEngine.start()

                    // PHASE 2: Deferred heavy init — workspace, orchestrator, bio.
                    TuningBridge.shared.activate()
                    EchoelCreativeWorkspace.shared.deferredSetup()

                    _ = InstrumentOrchestrator.shared

                    recordingEngine.connectAudioEngine(audioEngine)
                    EchoelCreativeWorkspace.shared.connectAudioEngine(audioEngine)
                    InstrumentOrchestrator.shared.connectMainAudioEngine(audioEngine)

                    // PHASE 3: HealthKit (async — waits for user permission dialog)
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
