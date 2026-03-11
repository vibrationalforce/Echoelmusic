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
                    _ = EchoelCreativeWorkspace.shared
                    _ = InstrumentOrchestrator.shared
                    _ = EchoelBeat.shared

                    recordingEngine.connectAudioEngine(audioEngine)
                    EchoelCreativeWorkspace.shared.connectAudioEngine(audioEngine)
                    InstrumentOrchestrator.shared.connectMainAudioEngine(audioEngine)
                    audioEngine.start()
                }
        }
    }
}
#endif
