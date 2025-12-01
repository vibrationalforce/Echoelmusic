import SwiftUI

/// Main entry point for the Echoelmusic app
/// Bio-reactive audio-visual experiences platform
@main
struct EchoelmusicApp: App {

    /// StateObject ensures the MicrophoneManager stays alive
    /// throughout the app's lifetime
    @StateObject private var microphoneManager = MicrophoneManager()

    /// Central AudioEngine coordinates all audio components
    @StateObject private var audioEngine: AudioEngine

    /// HealthKit manager for biofeedback
    @StateObject private var healthKitManager = HealthKitManager()

    /// Recording engine for multi-track recording
    @StateObject private var recordingEngine = RecordingEngine()

    /// UnifiedControlHub for multimodal input
    @StateObject private var unifiedControlHub: UnifiedControlHub

    init() {
        // Initialize AudioEngine with MicrophoneManager
        let micManager = MicrophoneManager()
        _microphoneManager = StateObject(wrappedValue: micManager)

        let audioEng = AudioEngine(microphoneManager: micManager)
        _audioEngine = StateObject(wrappedValue: audioEng)

        _unifiedControlHub = StateObject(wrappedValue: UnifiedControlHub(audioEngine: audioEng))

        // KRITISCH: Initialisiere alle Core-Systeme (Singletons)
        // Diese müssen beim App-Start aktiviert werden!
        _ = EchoelUniversalCore.shared      // Master Integration Hub
        _ = SelfHealingEngine.shared        // Auto-Recovery System
        _ = VideoAICreativeHub.shared       // Video/AI Integration
        _ = MultiPlatformBridge.shared      // MIDI/OSC/DMX/CV Bridge
        _ = EchoelTools.shared              // Intelligent Creative Tools

        print("⚛️ Echoelmusic Core Systems Initialized")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(microphoneManager)      // Makes mic manager available to all views
                .environmentObject(audioEngine)             // Makes audio engine available
                .environmentObject(healthKitManager)        // Makes health data available
                .environmentObject(recordingEngine)         // Makes recording engine available
                .environmentObject(unifiedControlHub)       // Makes unified control available
                .preferredColorScheme(.dark)                // Force dark theme
                .onAppear {
                    // Connect HealthKit to AudioEngine for bio-parameter mapping
                    audioEngine.connectHealthKit(healthKitManager)

                    // Connect RecordingEngine to AudioEngine for audio routing
                    recordingEngine.connectAudioEngine(audioEngine)

                    // Enable biometric monitoring through UnifiedControlHub
                    Task {
                        do {
                            try await unifiedControlHub.enableBiometricMonitoring()
                            print("✅ Biometric monitoring enabled via UnifiedControlHub")
                        } catch {
                            print("⚠️ Biometric monitoring not available: \(error.localizedDescription)")
                        }

                        // Enable MIDI 2.0 + MPE
                        do {
                            try await unifiedControlHub.enableMIDI2()
                            print("✅ MIDI 2.0 + MPE enabled via UnifiedControlHub")
                        } catch {
                            print("⚠️ MIDI 2.0 not available: \(error.localizedDescription)")
                        }
                    }

                    // Start UnifiedControlHub
                    unifiedControlHub.start()

                    print("🎵 Echoelmusic Started - All Systems Connected!")
                    print("🎹 MIDI 2.0 + MPE + Spatial Audio Ready")
                    print("🌊 Bio-Reactive Audio-Visual Platform Ready")
                }
        }
    }
}
