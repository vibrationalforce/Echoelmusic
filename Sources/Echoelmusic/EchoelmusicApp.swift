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
                    // PHASE 1: Wire ALL sound generators BEFORE engine.start().
                    // connectToMasterEngine eagerly attaches source nodes to the graph.
                    // Graph mutation on a running engine causes EXC_BREAKPOINT crashes.
                    log.log(.info, category: .system, "STARTUP [1/10] Connecting EchoelSynth...")
                    EchoelSynth.shared.connectToMasterEngine(audioEngine)
                    log.log(.info, category: .system, "STARTUP [2/10] Connecting EchoelBass...")
                    EchoelBass.shared.connectToMasterEngine(audioEngine)
                    log.log(.info, category: .system, "STARTUP [3/10] Connecting TR808BassSynth...")
                    TR808BassSynth.shared.connectToMasterEngine(audioEngine)
                    log.log(.info, category: .system, "STARTUP [4/10] Connecting EchoelBeat...")
                    EchoelBeat.shared.connectToMasterEngine(audioEngine)
                    log.log(.info, category: .system, "STARTUP [5/10] Starting audio engine...")
                    audioEngine.start()

                    // PHASE 2: Deferred heavy init — workspace, orchestrator, bio.
                    log.log(.info, category: .system, "STARTUP [6/10] Activating TuningBridge...")
                    TuningBridge.shared.activate()
                    log.log(.info, category: .system, "STARTUP [7/10] Running deferredSetup...")
                    EchoelCreativeWorkspace.shared.deferredSetup()
                    log.log(.info, category: .system, "STARTUP [8/10] Initializing InstrumentOrchestrator...")

                    _ = InstrumentOrchestrator.shared

                    log.log(.info, category: .system, "STARTUP [9/10] Wiring engines...")
                    recordingEngine.connectAudioEngine(audioEngine)
                    EchoelCreativeWorkspace.shared.connectAudioEngine(audioEngine)
                    InstrumentOrchestrator.shared.connectMainAudioEngine(audioEngine)

                    // PHASE 3: HealthKit (async — waits for user permission dialog)
                    log.log(.info, category: .system, "STARTUP [10/10] Requesting HealthKit authorization...")
                    _ = await EchoelBioEngine.shared.requestAuthorization()
                    log.log(.info, category: .system, "STARTUP COMPLETE — all systems initialized")
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
