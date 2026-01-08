// EchoelmusicApp.swift
// Main app entry point and state management

import SwiftUI

// MARK: - App Entry Point

@main
public struct EchoelmusicApp: App {
    @StateObject private var appState = AppState()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - App State

@MainActor
public final class AppState: ObservableObject {
    // MARK: - Published Properties

    @Published public var isSessionActive: Bool = false
    @Published public var bioData: BiometricData = BiometricData()
    @Published public var visualizationType: VisualizationType = .coherence
    @Published public var audioMode: AudioMode = .ambient
    @Published public var binauralState: BinauralState = .alpha

    // MARK: - Session

    @Published public var sessionDuration: TimeInterval = 0
    private var sessionTimer: Timer?
    private var sessionStartTime: Date?

    public var formattedDuration: String {
        let minutes = Int(sessionDuration) / 60
        let seconds = Int(sessionDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Managers

    public let biofeedbackManager: BiofeedbackManager
    public let audioEngine: AudioEngine
    public let presetManager: PresetManager

    // MARK: - Initialization

    public init() {
        self.biofeedbackManager = BiofeedbackManager()
        self.audioEngine = AudioEngine()
        self.presetManager = PresetManager()

        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        // Bio data updates
        biofeedbackManager.onDataUpdate = { [weak self] data in
            Task { @MainActor in
                self?.bioData = data
                self?.audioEngine.updateFromBioData(data)
            }
        }
    }

    // MARK: - Session Control

    public func startSession() {
        guard !isSessionActive else { return }

        isSessionActive = true
        sessionStartTime = Date()
        sessionDuration = 0

        // Start biofeedback
        biofeedbackManager.startMonitoring()

        // Start audio
        audioEngine.setMode(audioMode)
        audioEngine.start()

        // Start timer
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSessionDuration()
            }
        }

        print("Session started")
    }

    public func stopSession() {
        guard isSessionActive else { return }

        isSessionActive = false

        // Stop timer
        sessionTimer?.invalidate()
        sessionTimer = nil

        // Stop biofeedback
        biofeedbackManager.stopMonitoring()

        // Stop audio
        audioEngine.stop()

        print("Session stopped - Duration: \(formattedDuration)")
    }

    private func updateSessionDuration() {
        guard let startTime = sessionStartTime else { return }
        sessionDuration = Date().timeIntervalSince(startTime)
    }

    // MARK: - Audio Mode

    public func setAudioMode(_ mode: AudioMode) {
        audioMode = mode
        if isSessionActive {
            audioEngine.setMode(mode)
        }
    }

    // MARK: - Presets

    public func applyPreset(_ preset: Preset) {
        visualizationType = preset.visualization
        audioMode = preset.audioMode
        binauralState = preset.binauralState
        audioEngine.baseFrequency = preset.baseFrequency
        audioEngine.setVolume(preset.volume)

        presetManager.applyPreset(preset)

        if isSessionActive {
            audioEngine.setMode(audioMode)
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct EchoelmusicApp_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environmentObject(AppState())
            .preferredColorScheme(.dark)
    }
}
#endif
