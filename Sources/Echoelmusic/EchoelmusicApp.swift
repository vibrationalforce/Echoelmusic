#if canImport(SwiftUI)
import SwiftUI

/// Echoelmusic — Bio-Reactive Soundscape Generator
/// Your body, weather, and time of day create evolving ambient soundscapes.
@main
struct EchoelmusicApp: App {

    @State private var audioEngine: AudioEngine
    @State private var microphoneManager: MicrophoneManager
    @State private var soundscapeEngine: SoundscapeEngine
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let mic = MicrophoneManager()
        let audio = AudioEngine(microphoneManager: mic)
        let soundscape = SoundscapeEngine()

        _microphoneManager = State(wrappedValue: mic)
        _audioEngine = State(wrappedValue: audio)
        _soundscapeEngine = State(wrappedValue: soundscape)

        _ = MemoryPressureHandler.shared
    }

    var body: some Scene {
        WindowGroup {
            SoundscapeView()
                .environment(audioEngine)
                .environment(EchoelBioEngine.shared)
                .environment(soundscapeEngine)
                .task {
                    log.log(.info, category: .system, "STARTUP [1/3] Starting audio engine...")
                    audioEngine.start()

                    log.log(.info, category: .system, "STARTUP [2/3] Starting bio streaming...")
                    soundscapeEngine.bioSourceManager.startStreaming()

                    log.log(.info, category: .system, "STARTUP [3/3] Connecting soundscape engine...")
                    soundscapeEngine.connect(audio: audioEngine, bio: EchoelBioEngine.shared)

                    log.log(.info, category: .system, "STARTUP COMPLETE — Soundscape ready")
                }
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    switch newPhase {
                    case .active:
                        if oldPhase == .background {
                            audioEngine.start()
                            soundscapeEngine.bioSourceManager.startStreaming()
                            log.log(.info, category: .system, "App active — audio + bio resumed")
                        }
                    case .background:
                        log.log(.info, category: .system, "App backgrounded — audio continues")
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
