// EchoelmusicMVP - App Entry Point
// Bio-reactive audio-visual experience

import SwiftUI

// MARK: - App Entry Point

@main
struct EchoelmusicMVPApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

// MARK: - App State

@MainActor
final class AppState: ObservableObject {
    // MARK: - Published Properties

    @Published var isSessionActive: Bool = false
    @Published var currentCoherence: Double = 0.5
    @Published var heartRate: Double = 72.0
    @Published var hrvValue: Double = 50.0
    @Published var breathingRate: Double = 12.0

    // MARK: - Managers

    let healthKitManager: SimpleHealthKitManager
    let audioEngine: BasicAudioEngine

    // MARK: - Session Timer

    private var sessionTimer: Timer?
    private var sessionStartTime: Date?

    @Published var sessionDuration: TimeInterval = 0

    // MARK: - Initialization

    init() {
        self.healthKitManager = SimpleHealthKitManager()
        self.audioEngine = BasicAudioEngine()

        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Observe HealthKit updates
        healthKitManager.onBioDataUpdate = { [weak self] bioData in
            Task { @MainActor in
                self?.updateFromBioData(bioData)
            }
        }
    }

    private func updateFromBioData(_ bioData: SimpleBioData) {
        self.heartRate = bioData.heartRate
        self.hrvValue = bioData.hrv
        self.currentCoherence = bioData.coherence
        self.breathingRate = bioData.breathingRate

        // Update audio engine with bio data
        audioEngine.updateFromBioData(bioData)
    }

    // MARK: - Session Control

    func startSession() {
        guard !isSessionActive else { return }

        isSessionActive = true
        sessionStartTime = Date()
        sessionDuration = 0

        // Start HealthKit monitoring
        healthKitManager.startMonitoring()

        // Start audio engine
        audioEngine.start()

        // Start session timer
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSessionDuration()
            }
        }

        print("🎵 Session started")
    }

    func stopSession() {
        guard isSessionActive else { return }

        isSessionActive = false

        // Stop timer
        sessionTimer?.invalidate()
        sessionTimer = nil

        // Stop HealthKit
        healthKitManager.stopMonitoring()

        // Stop audio
        audioEngine.stop()

        print("🎵 Session stopped - Duration: \(formatDuration(sessionDuration))")
    }

    private func updateSessionDuration() {
        guard let startTime = sessionStartTime else { return }
        sessionDuration = Date().timeIntervalSince(startTime)
    }

    // MARK: - Formatting

    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Preview Provider

#if DEBUG
struct EchoelmusicMVPApp_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
    }
}
#endif
