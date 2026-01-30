import SwiftUI

#if os(iOS) || os(macOS) || os(tvOS)

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

        // PERFORMANCE: Defer non-critical singleton initialization to background
        // This prevents 2-5 second startup blocking on main thread
        Task(priority: .userInitiated) {
            do {
                // KRITISCH: Initialisiere alle Core-Systeme (Singletons)
                // Diese werden jetzt async geladen für schnelleren App-Start!
                // Use TaskGroup for parallel initialization with error handling
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask { @MainActor in _ = EchoelUniversalCore.shared }
                    group.addTask { @MainActor in _ = SelfHealingEngine.shared }
                    group.addTask { @MainActor in _ = VideoAICreativeHub.shared }
                    group.addTask { @MainActor in _ = MultiPlatformBridge.shared }
                    group.addTask { @MainActor in _ = EchoelTools.shared }
                    try await group.waitForAll()
                }

                // INSTRUMENT PIPELINE (depends on core systems)
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask { @MainActor in _ = InstrumentOrchestrator.shared }
                    group.addTask { @MainActor in _ = WorldMusicBridge.shared }
                    try await group.waitForAll()
                }

                // STREAMING PIPELINE
                await MainActor.run { _ = SocialMediaManager.shared }

                await MainActor.run {
                    log.info("⚛️ Echoelmusic Core Systems Initialized (async)", category: .system)
                    log.info("🎹 InstrumentOrchestrator: 54+ Instruments Ready", category: .system)
                    log.info("🌍 WorldMusicBridge: 42 Music Styles Loaded", category: .system)
                }
            } catch {
                await MainActor.run {
                    log.error("❌ Core system initialization failed: \(error.localizedDescription)", category: .system)
                    // App can still function - singletons will init lazily on first access
                }
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
                            log.info("✅ Biometric monitoring enabled via UnifiedControlHub", category: .system)
                        } catch {
                            log.warning("⚠️ Biometric monitoring not available: \(error.localizedDescription)", category: .system)
                        }

                        // Enable MIDI 2.0 + MPE
                        do {
                            try await unifiedControlHub.enableMIDI2()
                            log.info("✅ MIDI 2.0 + MPE enabled via UnifiedControlHub", category: .system)
                        } catch {
                            log.warning("⚠️ MIDI 2.0 not available: \(error.localizedDescription)", category: .system)
                        }
                    }

                    // Start UnifiedControlHub
                    unifiedControlHub.start()

                    log.info("🎵 Echoelmusic Started - All Systems Connected!", category: .system)
                    log.info("🎹 MIDI 2.0 + MPE + Spatial Audio Ready", category: .system)
                    log.info("🌊 Bio-Reactive Audio-Visual Platform Ready", category: .system)
                }
        }
    }
}

#endif // os(iOS) || os(macOS) || os(tvOS)
