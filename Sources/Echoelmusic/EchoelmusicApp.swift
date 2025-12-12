import SwiftUI

/// Main entry point for the Echoelmusic app
/// Bio-reactive audio-visual experiences platform
///
/// Architecture:
/// - Single MicrophoneManager instance shared across app
/// - AudioEngine coordinates all audio components
/// - UnifiedControlHub orchestrates multimodal input at 60Hz
/// - Background initialization of singletons for fast startup
@main
struct EchoelmusicApp: App {

    // MARK: - Core State Objects

    /// Microphone manager for voice/breath input (single instance)
    @StateObject private var microphoneManager: MicrophoneManager

    /// Central AudioEngine coordinates all audio components
    @StateObject private var audioEngine: AudioEngine

    /// HealthKit manager for biofeedback
    @StateObject private var healthKitManager: HealthKitManager

    /// Recording engine for multi-track recording
    @StateObject private var recordingEngine: RecordingEngine

    /// UnifiedControlHub for multimodal input
    @StateObject private var unifiedControlHub: UnifiedControlHub

    // MARK: - Initialization

    init() {
        // FIXED: Create single MicrophoneManager instance (was creating duplicate)
        let micManager = MicrophoneManager()
        _microphoneManager = StateObject(wrappedValue: micManager)

        // Initialize AudioEngine with the single MicrophoneManager instance
        let audioEng = AudioEngine(microphoneManager: micManager)
        _audioEngine = StateObject(wrappedValue: audioEng)

        // Initialize HealthKit manager
        let healthKit = HealthKitManager()
        _healthKitManager = StateObject(wrappedValue: healthKit)

        // Initialize Recording engine
        let recording = RecordingEngine()
        _recordingEngine = StateObject(wrappedValue: recording)

        // Initialize UnifiedControlHub with AudioEngine reference
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
                EchoelLogger.log("⚛️", "Echoelmusic Core Systems Initialized (async)", category: EchoelLogger.system)
                EchoelLogger.log("🎹", "InstrumentOrchestrator: 54+ Instruments Ready", category: EchoelLogger.audio)
                EchoelLogger.log("🌍", "WorldMusicBridge: 42 Music Styles Loaded", category: EchoelLogger.audio)
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
                            EchoelLogger.success("Biometric monitoring enabled via UnifiedControlHub", category: EchoelLogger.bio)
                        } catch {
                            EchoelLogger.warning("Biometric monitoring not available: \(error.localizedDescription)", category: EchoelLogger.bio)
                        }

                        // Enable MIDI 2.0 + MPE
                        do {
                            try await unifiedControlHub.enableMIDI2()
                            EchoelLogger.success("MIDI 2.0 + MPE enabled via UnifiedControlHub", category: EchoelLogger.midi)
                        } catch {
                            EchoelLogger.warning("MIDI 2.0 not available: \(error.localizedDescription)", category: EchoelLogger.midi)
                        }
                    }

                    // Start UnifiedControlHub
                    unifiedControlHub.start()

                    EchoelLogger.log("🎵", "Echoelmusic Started - All Systems Connected!", category: EchoelLogger.system)
                    EchoelLogger.log("🎹", "MIDI 2.0 + MPE + Spatial Audio Ready", category: EchoelLogger.midi)
                    EchoelLogger.log("🌊", "Bio-Reactive Audio-Visual Platform Ready", category: EchoelLogger.system)
                }
        }
    }
}
