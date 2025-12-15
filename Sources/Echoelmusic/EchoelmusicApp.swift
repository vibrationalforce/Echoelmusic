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

    /// Preset manager for saving/loading audio configurations
    @StateObject private var presetManager = PresetManager()

    init() {
        // Initialize AudioEngine with MicrophoneManager
        let micManager = MicrophoneManager()
        _microphoneManager = StateObject(wrappedValue: micManager)

        let audioEng = AudioEngine(microphoneManager: micManager)
        _audioEngine = StateObject(wrappedValue: audioEng)

        _unifiedControlHub = StateObject(wrappedValue: UnifiedControlHub(audioEngine: audioEng))

        // PERFORMANCE: Defer non-critical singleton initialization to background
        // This prevents 2-5 second startup blocking on main thread
        Task.detached(priority: .userInitiated) {
            // KRITISCH: Initialisiere alle Core-Systeme (Singletons)
            // Diese werden jetzt async geladen für schnelleren App-Start!
            _ = await MainActor.run { EchoelUniversalCore.shared }      // Master Integration Hub
            _ = await MainActor.run { SelfHealingEngine.shared }        // Auto-Recovery System
            _ = await MainActor.run { VideoAICreativeHub.shared }       // Video/AI Integration
            _ = await MainActor.run { MultiPlatformBridge.shared }      // MIDI/OSC/DMX/CV Bridge
            _ = await MainActor.run { EchoelTools.shared }              // Intelligent Creative Tools

            // INSTRUMENT PIPELINE
            _ = await MainActor.run { InstrumentOrchestrator.shared }   // UI→Synthesis→Audio Pipeline
            _ = await MainActor.run { WorldMusicBridge.shared }         // 42 Global Music Styles

            // STREAMING PIPELINE
            _ = await MainActor.run { SocialMediaManager.shared }       // One-Click Multi-Platform Publishing
            // Note: StreamEngine requires Metal device - initialized lazily in StreamingView

            await MainActor.run {
                print("⚛️ Echoelmusic Core Systems Initialized (async)")
                print("🎹 InstrumentOrchestrator: 54+ Instruments Ready")
                print("🌍 WorldMusicBridge: 42 Music Styles Loaded")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(microphoneManager)      // Makes mic manager available to all views
                .environmentObject(audioEngine)             // Makes audio engine available
                .environmentObject(healthKitManager)        // Makes health data available
                .environmentObject(recordingEngine)         // Makes recording engine available
                .environmentObject(unifiedControlHub)       // Makes unified control available
                .environmentObject(presetManager)           // Makes preset management available
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
