import SwiftUI
import Combine

/// Echoelmusic — DAW + Video Production
/// Clean, minimal entry point
@main
struct EchoelmusicApp: App {

    @StateObject private var audioEngine: AudioEngine
    @StateObject private var microphoneManager: MicrophoneManager
    @StateObject private var recordingEngine = RecordingEngine()
    @StateObject private var themeManager = ThemeManager()

    @State private var isReady = false

    init() {
        let mic = MicrophoneManager()
        _microphoneManager = StateObject(wrappedValue: mic)
        _audioEngine = StateObject(wrappedValue: AudioEngine(microphoneManager: mic))
    }

    var body: some Scene {
        WindowGroup {
            if isReady {
                MainNavigationHub()
                    .environmentObject(audioEngine)
                    .environmentObject(microphoneManager)
                    .environmentObject(recordingEngine)
                    .environmentObject(themeManager)
                    .preferredColorScheme(themeManager.resolvedColorScheme)
                    .onAppear {
                        recordingEngine.connectAudioEngine(audioEngine)
                    }
            } else {
                LaunchScreen(phase: "Loading...", progress: 0.5)
                    .task {
                        await MainActor.run {
                            _ = MemoryPressureHandler.shared
                            _ = EchoelCreativeWorkspace.shared
                            _ = CrashSafeStatePersistence.shared
                        }
                        isReady = true
                    }
            }
        }
    }
}
