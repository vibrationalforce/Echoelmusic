#if canImport(SwiftUI)
import SwiftUI

/// Echoelmusic — DAW + Video Production
/// Clean, minimal entry point
@main
struct EchoelmusicApp: App {

    @State private var audioEngine: AudioEngine
    @State private var microphoneManager: MicrophoneManager
    @State private var recordingEngine = RecordingEngine()
    @State private var themeManager = ThemeManager()

    @State private var isReady = false
    @State private var launchPhase = "Initializing..."
    @State private var launchProgress = 0.0

    init() {
        let mic = MicrophoneManager()
        _microphoneManager = State(wrappedValue: mic)
        _audioEngine = State(wrappedValue: AudioEngine(microphoneManager: mic))
    }

    var body: some Scene {
        WindowGroup {
            if isReady {
                MainNavigationHub()
                    .environment(audioEngine)
                    .environment(microphoneManager)
                    .environment(recordingEngine)
                    .environment(themeManager)
                    .preferredColorScheme(themeManager.resolvedColorScheme)
                    .onAppear {
                        recordingEngine.connectAudioEngine(audioEngine)
                        EchoelCreativeWorkspace.shared.connectAudioEngine(audioEngine)
                        // Route instrument audio through main engine (unified pipeline)
                        InstrumentOrchestrator.shared.connectMainAudioEngine(audioEngine)
                        // Start audio engine immediately so synths, presets, and meters work
                        audioEngine.start()
                    }
            } else {
                LaunchScreen(phase: launchPhase, progress: launchProgress)
                    .task {
                        await initializeSystems()
                    }
            }
        }
    }

    /// Sequential initialization with progress feedback
    @MainActor
    private func initializeSystems() async {
        launchPhase = "Audio Engine"
        launchProgress = 0.2
        // AudioEngine already initialized in init() — just let UI update
        try? await Task.sleep(nanoseconds: 100_000_000)

        launchPhase = "Memory Manager"
        launchProgress = 0.4
        _ = MemoryPressureHandler.shared
        try? await Task.sleep(nanoseconds: 50_000_000)

        launchPhase = "Tuning System"
        launchProgress = 0.5
        TuningBridge.shared.activate()
        try? await Task.sleep(nanoseconds: 50_000_000)

        launchPhase = "Creative Workspace"
        launchProgress = 0.6
        _ = EchoelCreativeWorkspace.shared
        // Pre-warm audio singletons so first key/drum tap has zero latency
        _ = InstrumentOrchestrator.shared
        _ = EchoelBeat.shared
        try? await Task.sleep(nanoseconds: 50_000_000)

        launchPhase = "State Persistence"
        launchProgress = 0.8
        _ = CrashSafeStatePersistence.shared
        try? await Task.sleep(nanoseconds: 50_000_000)

        launchPhase = "Ready"
        launchProgress = 1.0
        try? await Task.sleep(nanoseconds: 200_000_000)

        isReady = true
    }
}
#endif
