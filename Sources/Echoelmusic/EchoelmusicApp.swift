#if canImport(SwiftUI)
import SwiftUI

/// Echoelmusic — Bio-Reactive Synthesizer
/// Clean, minimal entry point. No intro animation — straight to the app.
@main
struct EchoelmusicApp: App {

    @State private var audioEngine: AudioEngine
    @State private var microphoneManager: MicrophoneManager
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
                .environment(themeManager)
                .preferredColorScheme(themeManager.resolvedColorScheme)
                .task {
                    // PHASE 1: Wire core synth BEFORE engine.start().
                    // Graph mutation on a running engine causes EXC_BREAKPOINT crashes.
                    log.log(.info, category: .system, "STARTUP [1/4] Connecting EchoelSynth...")
                    EchoelSynth.shared.connectToMasterEngine(audioEngine)
                    log.log(.info, category: .system, "STARTUP [2/4] Connecting EchoelBass...")
                    EchoelBass.shared.connectToMasterEngine(audioEngine)
                    log.log(.info, category: .system, "STARTUP [3/4] Starting audio engine...")
                    audioEngine.start()

                    // PHASE 2: Workspace wiring
                    log.log(.info, category: .system, "STARTUP [4/4] Wiring workspace...")
                    TuningBridge.shared.activate()
                    EchoelCreativeWorkspace.shared.deferredSetup()
                    EchoelCreativeWorkspace.shared.connectAudioEngine(audioEngine)

                    log.log(.info, category: .system, "STARTUP COMPLETE — Synth ready")
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
