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

    /// Integration Hub - Central coordinator for all platform systems
    /// Using @State since IntegrationHub uses @Observable
    @State private var integrationHub = IntegrationHub.shared

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

            // NEW: Initialize IntegrationHub (Accessibility, Localization, Streaming, Collaboration)
            await IntegrationHub.shared.initializeAll()

            #if DEBUG
            debugLog("⚛️", "Echoelmusic Core Systems Initialized (async)")
            debugLog("🎹", "InstrumentOrchestrator: 54+ Instruments Ready")
            debugLog("🌍", "WorldMusicBridge: 42 Music Styles Loaded")
            debugLog("🔌", "IntegrationHub: All systems connected")
            #endif
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
                .environment(integrationHub)                // NEW: IntegrationHub (@Observable)
                .preferredColorScheme(.dark)                // Force dark theme
                .onAppear {
                    // Connect HealthKit to AudioEngine for bio-parameter mapping
                    audioEngine.connectHealthKit(healthKitManager)

                    // Connect RecordingEngine to AudioEngine for audio routing
                    recordingEngine.connectAudioEngine(audioEngine)

                    // NEW: Connect IntegrationHub to Audio & HealthKit
                    integrationHub.connectToAudioEngine(audioEngine)
                    integrationHub.connectToHealthKit(healthKitManager)

                    // Enable biometric monitoring through UnifiedControlHub
                    Task {
                        do {
                            try await unifiedControlHub.enableBiometricMonitoring()
                            #if DEBUG
                            debugLog("✅", "Biometric monitoring enabled via UnifiedControlHub")
                            #endif
                        } catch {
                            #if DEBUG
                            debugLog("⚠️", "Biometric monitoring not available: \(error.localizedDescription)")
                            #endif
                        }

                        // Enable MIDI 2.0 + MPE
                        do {
                            try await unifiedControlHub.enableMIDI2()
                            #if DEBUG
                            debugLog("✅", "MIDI 2.0 + MPE enabled via UnifiedControlHub")
                            #endif
                        } catch {
                            #if DEBUG
                            debugLog("⚠️", "MIDI 2.0 not available: \(error.localizedDescription)")
                            #endif
                        }

                        // Load saved health sessions
                        try? await LocalHealthStorage.shared.loadSessions()
                    }

                    // Start UnifiedControlHub
                    unifiedControlHub.start()

                    #if DEBUG
                    debugLog("🎵", "Echoelmusic Started - All Systems Connected!")
                    debugLog("🎹", "MIDI 2.0 + MPE + Spatial Audio Ready")
                    debugLog("🌊", "Bio-Reactive Audio-Visual Platform Ready")
                    debugLog("🔌", "IntegrationHub: Accessibility + Localization + Streaming + Collaboration")
                    #endif
                }
        }
    }
}
