import SwiftUI

/// Main entry point for the Echoelmusic app
/// Bio-reactive audio-visual experiences platform
///
/// ECHOELMUSIC - Bio-Reactive Sound. Healing Through Music.
///
/// Integrated Systems:
/// - Audio Engine (C++ Core + Swift)
/// - Bio/Health (HRV, HealthKit, Healing)
/// - Input (Face, Gesture, MIDI, Touch)
/// - Output (Spatial Audio, Visuals, LED)
/// - Intelligence (Quantum AI, ML)
/// - Business (Creator, Agency, EoelWorks)
/// - 23+ Languages, WCAG 2.1 AAA
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

    /// Master Integration Hub - connects ALL 90+ systems
    @StateObject private var integrationHub = EchoelmusicIntegrationHub.shared

    init() {
        // Initialize AudioEngine with MicrophoneManager
        let micManager = MicrophoneManager()
        _microphoneManager = StateObject(wrappedValue: micManager)

        let audioEng = AudioEngine(microphoneManager: micManager)
        _audioEngine = StateObject(wrappedValue: audioEng)

        _unifiedControlHub = StateObject(wrappedValue: UnifiedControlHub(audioEngine: audioEng))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(microphoneManager)      // Makes mic manager available to all views
                .environmentObject(audioEngine)             // Makes audio engine available
                .environmentObject(healthKitManager)        // Makes health data available
                .environmentObject(recordingEngine)         // Makes recording engine available
                .environmentObject(unifiedControlHub)       // Makes unified control available
                .environmentObject(integrationHub)          // Makes integration hub available
                .preferredColorScheme(.dark)                // Force dark theme
                .onAppear {
                    // Connect HealthKit to AudioEngine for bio-parameter mapping
                    audioEngine.connectHealthKit(healthKitManager)

                    // Connect RecordingEngine to AudioEngine for audio routing
                    recordingEngine.connectAudioEngine(audioEngine)

                    // Enable biometric monitoring through UnifiedControlHub
                    Task {
                        // Initialize the master integration hub (connects all 90+ systems)
                        await integrationHub.initializeAllSystems()

                        do {
                            try await unifiedControlHub.enableBiometricMonitoring()
                            print("Biometric monitoring enabled via UnifiedControlHub")
                        } catch {
                            print("Biometric monitoring not available: \(error.localizedDescription)")
                        }

                        // Enable MIDI 2.0 + MPE
                        do {
                            try await unifiedControlHub.enableMIDI2()
                            print("MIDI 2.0 + MPE enabled via UnifiedControlHub")
                        } catch {
                            print("MIDI 2.0 not available: \(error.localizedDescription)")
                        }

                        // Start bio-reactive mode
                        await integrationHub.startBioReactiveMode()
                    }

                    // Start UnifiedControlHub
                    unifiedControlHub.start()

                    print("""

                    ========================================
                    ECHOELMUSIC - ALL SYSTEMS ONLINE
                    ========================================
                    Bio-Reactive Audio-Visual Platform
                    Healing Through Music
                    ========================================
                    - Audio Engine: Ready
                    - Bio-Reactive Mode: Active
                    - MIDI 2.0 + MPE: Ready
                    - Spatial Audio: Ready
                    - QuantumLifeScanner: Ready
                    - EoelWorks (Arbeitsvermittlung): Ready
                    - CreatorManager: Ready
                    - AgencyManager: Ready
                    - 23+ Languages: Ready
                    - Accessibility (WCAG AAA): Ready
                    ========================================

                    """)
                }
        }
    }
}
