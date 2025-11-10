import SwiftUI

#if os(iOS) || os(macOS)
// Main app entry point for iOS/iPadOS/macOS
// Other platforms (watchOS, tvOS, visionOS) have their own entry points

/// Main entry point for the Echoelmusic app
/// Cross-platform: iOS, iPadOS, macOS, Mac Catalyst
@main
struct EchoelmusicApp: App {

    /// StateObject ensures the MicrophoneManager stays alive
    /// throughout the app's lifetime
    @StateObject private var microphoneManager = MicrophoneManager()

    /// Central AudioEngine coordinates all audio components
    @StateObject private var audioEngine: AudioEngine

    /// HealthKit manager for biofeedback (iOS only)
    #if os(iOS)
    @StateObject private var healthKitManager = HealthKitManager()
    #endif

    /// Recording engine for multi-track recording
    @StateObject private var recordingEngine = RecordingEngine()

    /// UnifiedControlHub for multimodal input
    @StateObject private var unifiedControlHub: UnifiedControlHub

    init() {
        print("🚀 Initializing Echoelmusic for \(PlatformCapabilities.platformName)")

        // Initialize AudioEngine with MicrophoneManager
        let micManager = MicrophoneManager()
        _microphoneManager = StateObject(wrappedValue: micManager)

        let audioEng = AudioEngine(microphoneManager: micManager)
        _audioEngine = StateObject(wrappedValue: audioEng)

        _unifiedControlHub = StateObject(wrappedValue: UnifiedControlHub(audioEngine: audioEng))

        print("✅ Platform: \(PlatformCapabilities.platformName)")
        print("✅ Device: \(PlatformCapabilities.deviceType)")
        print("✅ HealthKit Available: \(PlatformCapabilities.hasHealthKit)")
        print("✅ Camera Available: \(PlatformCapabilities.hasCamera)")
        print("✅ Spatial Audio: \(PlatformCapabilities.hasSpatialAudio)")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(microphoneManager)      // Makes mic manager available to all views
                .environmentObject(audioEngine)             // Makes audio engine available
                #if os(iOS)
                .environmentObject(healthKitManager)        // Makes health data available (iOS only)
                #endif
                .environmentObject(recordingEngine)         // Makes recording engine available
                .environmentObject(unifiedControlHub)       // Makes unified control available
                .preferredColorScheme(.dark)                // Force dark theme
                .onAppear {
                    #if os(iOS)
                    // Connect HealthKit to AudioEngine for bio-parameter mapping (iOS only)
                    audioEngine.connectHealthKit(healthKitManager)
                    #endif

                    // Connect RecordingEngine to AudioEngine for audio routing
                    recordingEngine.connectAudioEngine(audioEngine)

                    // Enable biometric monitoring through UnifiedControlHub
                    Task {
                        #if os(iOS)
                        do {
                            try await unifiedControlHub.enableBiometricMonitoring()
                            print("✅ Biometric monitoring enabled via UnifiedControlHub")
                        } catch {
                            print("⚠️ Biometric monitoring not available: \(error.localizedDescription)")
                        }
                        #endif

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

                    print("🎵 Echoelmusic App Started - All Systems Connected!")
                    print("🎹 MIDI 2.0 + MPE + Spatial Audio Ready")
                    print("🌊 Stereo → 3D → 4D → AFA Sound")
                    print("📱 Platform: \(PlatformCapabilities.platformName)")
                }
        }
        #if os(macOS)
        .windowStyle(.automatic)
        .defaultSize(width: 1280, height: 800)
        #endif
    }
}

#endif

