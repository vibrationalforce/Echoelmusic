// BiometricIntegrationExample.swift
// Complete integration example for EchoelBiometrics™
// Shows how to use all systems together
//
// SPDX-License-Identifier: MIT
// Copyright © 2025 Echoel Development Team

import Foundation
import Combine

#if os(iOS)
import UIKit

/**
 * COMPLETE BIOMETRIC INTEGRATION EXAMPLE
 *
 * This example demonstrates how to:
 * 1. Initialize all Echoel biometric systems
 * 2. Start data collection from multiple sensors
 * 3. Combine data in EchoelFlow™
 * 4. Map to audio parameters
 * 5. Use with ULTRATHINK features
 *
 * SYSTEMS DEMONSTRATED:
 * - EchoelVision™ (Eye tracking via ARKit)
 * - EchoelMind™ (EEG via Muse)
 * - EchoelRing™ (Oura Ring sleep/recovery)
 * - EchoelFlow™ (Master coordinator)
 * - EchoelSync™ (Biometric synchronization)
 */

@available(iOS 14.0, *)
class BiometricMusicController {

    // MARK: - Properties

    private var cancellables = Set<AnyCancellable>()

    // Current audio parameters
    private var audioParams: [String: Float] = [:]

    // Wellness insights
    private var currentInsights: [String] = []

    // MARK: - Initialization

    init() {
        print("🎵 EchoelBiometrics™ Music Controller Initialized")
    }

    // MARK: - Setup

    /// Complete setup of all biometric systems
    func setup() {
        print("\n=== SETTING UP ECHOEL BIOMETRICS ===\n")

        // 1. Configure EchoelRing with Oura API token
        setupOuraRing()

        // 2. Start EchoelVision eye tracking
        setupEyeTracking()

        // 3. Connect EchoelMind EEG device
        setupEEGMonitoring()

        // 4. Start EchoelFlow master coordinator
        setupMasterCoordinator()

        // 5. Subscribe to data updates
        subscribeToUpdates()

        print("\n✅ All biometric systems initialized!\n")
    }

    private func setupOuraRing() {
        print("💍 Setting up EchoelRing™ (Oura)...")

        // In production, get token from secure storage
        let ouraToken = "YOUR_OURA_ACCESS_TOKEN"

        EchoelRingManager.shared.configure(accessToken: ouraToken)
        EchoelRingManager.shared.fetchTodaysData()

        print("   ✓ Connected to Oura Cloud API")
    }

    private func setupEyeTracking() {
        print("👁️ Setting up EchoelVision™ (Eye Tracking)...")

        EchoelVisionManager.shared.startTracking()

        print("   ✓ ARKit eye tracking started")
    }

    private func setupEEGMonitoring() {
        print("🧠 Setting up EchoelMind™ (EEG)...")

        EchoelMindManager.shared.connectMuse()

        // Wait for connection (simplified - production would use callbacks)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            EchoelMindManager.shared.startMonitoring()
            print("   ✓ Muse EEG monitoring started")
        }
    }

    private func setupMasterCoordinator() {
        print("🌊 Starting EchoelFlow™ (Master Coordinator)...")

        EchoelFlowManager.shared.start()

        print("   ✓ Unified biometric flow active")
    }

    // MARK: - Data Subscriptions

    private func subscribeToUpdates() {
        print("\n=== SUBSCRIBING TO BIOMETRIC DATA ===\n")

        // Subscribe to unified biometric stream
        EchoelFlowManager.shared.subscribeToBioData()
            .sink { [weak self] bioData in
                self?.handleBioDataUpdate(bioData)
            }
            .store(in: &cancellables)

        // Subscribe to physiological state changes
        EchoelFlowManager.shared.subscribeToState()
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)

        // Subscribe to Oura sleep data
        EchoelRingManager.shared.subscribeToSleepData()
            .sink { [weak self] sleepData in
                self?.handleSleepData(sleepData)
            }
            .store(in: &cancellables)

        // Subscribe to Oura readiness data
        EchoelRingManager.shared.subscribeToReadinessData()
            .sink { [weak self] readinessData in
                self?.handleReadinessData(readinessData)
            }
            .store(in: &cancellables)

        print("✅ Subscribed to all biometric streams\n")
    }

    // MARK: - Data Handlers

    private func handleBioDataUpdate(_ bioData: EchoelBioData) {
        // Map biometric data to audio parameters
        audioParams = EchoelFlowManager.shared.mapToAudioParameters()

        // Example: Print current eye gaze position
        if Int(bioData.timestamp) % 1000000 == 0 { // Every second
            print("👁️ Gaze: (\(String(format: "%.2f", bioData.gazePosition.x)), \(String(format: "%.2f", bioData.gazePosition.y)))")
            print("❤️ HR: \(Int(bioData.heartRate)) BPM, HRV: \(Int(bioData.hrvRMSSD)) ms")
            print("🧠 Alpha: \(Int(bioData.alpha))%, Beta: \(Int(bioData.beta))%")
            print("💪 Readiness: \(Int(bioData.readinessScore))/100")
            print("")
        }

        // Apply audio parameters to your audio engine
        applyAudioParameters(audioParams)
    }

    private func handleStateChange(_ state: PhysiologicalState) {
        print("🎯 State changed: \(state.rawValue)")

        // Get state-specific audio profile
        let profile = state.audioProfile

        print("   Energy: \(String(format: "%.1f", profile["energy"] ?? 0))")
        print("   Clarity: \(String(format: "%.1f", profile["clarity"] ?? 0))")
        print("   Complexity: \(String(format: "%.1f", profile["complexity"] ?? 0))")
        print("")

        // Trigger UI update, lighting change, etc.
        updateVisualsForState(state)
    }

    private func handleSleepData(_ sleepData: OuraSleepData) {
        print("💤 Sleep Score: \(Int(sleepData.sleepScore))/100")
        print("   Deep: \(sleepData.deepSleepMinutes) min")
        print("   REM: \(sleepData.remSleepMinutes) min")
        print("   Light: \(sleepData.lightSleepMinutes) min")
        print("")
    }

    private func handleReadinessData(_ readinessData: OuraReadinessData) {
        print("⚡ Readiness Score: \(Int(readinessData.readinessScore))/100")
        print("   Resting HR: \(Int(readinessData.restingHeartRate)) BPM")
        print("   HRV Balance: \(Int(readinessData.hrvBalance))")
        print("")

        // Get wellness insights
        currentInsights = EchoelFlowManager.shared.getWellnessInsights()

        print("💡 Insights:")
        for insight in currentInsights {
            print("   \(insight)")
        }
        print("")
    }

    // MARK: - Audio Integration

    private func applyAudioParameters(_ params: [String: Float]) {
        // Example: Apply to your audio engine
        // In production, this would control actual DSP parameters

        if let pan = params["stereo_pan"] {
            // Control stereo position based on eye gaze
            setStereoPan(pan)
        }

        if let cutoff = params["filter_cutoff"] {
            // Control filter brightness based on gaze Y position
            setFilterCutoff(cutoff)
        }

        if let reverb = params["reverb_size"] {
            // Control reverb size based on pupil dilation
            setReverbSize(reverb)
        }

        if let coherence = params["coherence_harmony"] {
            // Control harmonic richness based on HRV coherence
            setHarmonicContent(coherence)
        }

        if let tempo = params["heart_rate_tempo"] {
            // Sync tempo to heart rate
            setTempo(tempo)
        }
    }

    // MARK: - Audio Engine Stubs (Production would use real DSP)

    private func setStereoPan(_ pan: Float) {
        // -1 (left) to +1 (right)
        // In production: audioEngine.stereoPan = pan
    }

    private func setFilterCutoff(_ cutoff: Float) {
        // 200-18200 Hz
        // In production: audioEngine.filter.cutoff = cutoff
    }

    private func setReverbSize(_ size: Float) {
        // 0-1
        // In production: audioEngine.reverb.size = size
    }

    private func setHarmonicContent(_ content: Float) {
        // 0-1
        // In production: audioEngine.synthesizer.harmonicContent = content
    }

    private func setTempo(_ bpm: Float) {
        // In production: audioEngine.transport.tempo = bpm
    }

    // MARK: - Visual Integration

    private func updateVisualsForState(_ state: PhysiologicalState) {
        // Example: Update UI colors, lighting, etc.

        let color: UIColor

        switch state {
        case .peak:
            color = .systemYellow
        case .focused:
            color = .systemBlue
        case .creative:
            color = .systemPurple
        case .relaxed:
            color = .systemGreen
        case .stressed:
            color = .systemRed
        case .fatigued:
            color = .systemGray
        case .recovering:
            color = .systemOrange
        case .meditative:
            color = .systemTeal
        }

        // In production: Update UI background, send to Hue lights, etc.
        print("🎨 Visual update: \(color)")
    }

    // MARK: - Neurofeedback Training

    func startNeurofeedbackTraining(target: NeuralState, durationMinutes: Int) {
        print("\n=== STARTING NEUROFEEDBACK TRAINING ===")
        print("Target: \(target.rawValue)")
        print("Duration: \(durationMinutes) minutes\n")

        EchoelMindManager.shared.startNeurofeedbackTraining(
            target: target,
            duration: TimeInterval(durationMinutes * 60)
        )

        // Poll for neurofeedback audio parameters
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let neurofeedbackParams = EchoelMindManager.shared.getNeurofeedbackAudioParams()

            // Apply neurofeedback-specific audio (reward desired brain states)
            self.applyAudioParameters(neurofeedbackParams)
        }
    }

    // MARK: - Group Coherence

    func enableGroupCoherence(participants: [String]) {
        print("\n=== ENABLING GROUP COHERENCE ===")
        print("Participants: \(participants.joined(separator: ", "))\n")

        // In production, this would sync biometric data across network
        // using EchoelSync biometric protocol

        print("🌐 Group coherence sync enabled")
        print("💓 Audio will adapt to collective heart coherence")
    }

    // MARK: - Circadian Optimization

    func optimizeForCircadianPhase() {
        let phase = EchoelRingManager.shared.getCurrentCircadianPhase()
        let params = EchoelRingManager.shared.getCircadianAudioParameters()

        print("\n=== CIRCADIAN OPTIMIZATION ===")
        print("Current phase: \(phase.description)")
        print("Audio adjustments:")
        print("   Brightness: \(String(format: "%.1f", params["filter_brightness"] ?? 0))")
        print("   Tempo: \(String(format: "%.1f%%", (params["tempo_multiplier"] ?? 1.0) * 100))")
        print("   Reverb: \(String(format: "%.1f", params["reverb_size"] ?? 0))")
        print("")

        applyAudioParameters(params)
    }

    // MARK: - Export & Analytics

    func exportBiometricSession() -> String {
        print("\n=== EXPORTING SESSION DATA ===\n")

        guard let json = EchoelFlowManager.shared.exportAsJSON() else {
            return "{}"
        }

        print("✅ Session data exported as JSON")
        print("   Length: \(json.count) bytes")

        return json
    }

    func printCurrentStatus() {
        let bioData = EchoelFlowManager.shared.getCurrentBioData()
        let state = EchoelFlowManager.shared.getCurrentState()

        print("\n=== CURRENT BIOMETRIC STATUS ===")
        print("State: \(state.rawValue)")
        print("")
        print("Vision:")
        print("  Gaze: (\(String(format: "%.2f", bioData.gazePosition.x)), \(String(format: "%.2f", bioData.gazePosition.y)))")
        print("  Pupil: \(String(format: "%.1f", bioData.pupilDiameter)) mm")
        print("  Blink rate: \(Int(bioData.blinkRate))/min")
        print("")
        print("Neural:")
        print("  Alpha: \(Int(bioData.alpha))%")
        print("  Beta: \(Int(bioData.beta))%")
        print("  Theta: \(Int(bioData.theta))%")
        print("  Meditation: \(Int(bioData.meditation))/100")
        print("  Attention: \(Int(bioData.attention))/100")
        print("")
        print("Cardiac:")
        print("  HR: \(Int(bioData.heartRate)) BPM")
        print("  HRV: \(Int(bioData.hrvRMSSD)) ms")
        print("  Coherence: \(Int(bioData.coherence))/100")
        print("")
        print("Wellness:")
        print("  Sleep Score: \(Int(bioData.sleepScore))/100")
        print("  Readiness: \(Int(bioData.readinessScore))/100")
        print("  Stress: \(Int(bioData.stressIndex))/100")
        print("")
    }

    // MARK: - Cleanup

    func shutdown() {
        print("\n=== SHUTTING DOWN BIOMETRIC SYSTEMS ===\n")

        EchoelFlowManager.shared.stop()
        EchoelVisionManager.shared.stopTracking()
        EchoelMindManager.shared.stopMonitoring()
        EchoelMindManager.shared.disconnect()

        cancellables.removeAll()

        print("✅ All systems stopped\n")
    }
}

// MARK: - Example Usage

/**
 * EXAMPLE 1: Basic Setup
 */
func exampleBasicSetup() {
    print("📱 EXAMPLE 1: Basic Biometric Music Setup\n")

    let controller = BiometricMusicController()
    controller.setup()

    // Run for 60 seconds, then print status
    DispatchQueue.main.asyncAfter(deadline: .now() + 60.0) {
        controller.printCurrentStatus()
    }
}

/**
 * EXAMPLE 2: Neurofeedback Training
 */
func exampleNeurofeedbackTraining() {
    print("📱 EXAMPLE 2: Neurofeedback Training Session\n")

    let controller = BiometricMusicController()
    controller.setup()

    // Train meditation (alpha waves) for 10 minutes
    controller.startNeurofeedbackTraining(
        target: .meditation,
        durationMinutes: 10
    )
}

/**
 * EXAMPLE 3: Group Meditation Session
 */
func exampleGroupMeditation() {
    print("📱 EXAMPLE 3: Group Meditation with Coherence Sync\n")

    let controller = BiometricMusicController()
    controller.setup()

    // Enable group coherence with 3 participants
    controller.enableGroupCoherence(participants: [
        "Alice",
        "Bob",
        "Charlie"
    ])

    print("🧘 Music will now sync to group heart coherence")
    print("💓 When hearts sync, music becomes more harmonious")
}

/**
 * EXAMPLE 4: Circadian-Optimized Creative Session
 */
func exampleCircadianOptimized() {
    print("📱 EXAMPLE 4: Circadian-Optimized Creative Session\n")

    let controller = BiometricMusicController()
    controller.setup()

    // Optimize audio for current circadian phase
    controller.optimizeForCircadianPhase()

    print("🌅 Audio optimized for your body's natural rhythm")
}

/**
 * EXAMPLE 5: Export Session Data
 */
func exampleExportSession() {
    print("📱 EXAMPLE 5: Export Biometric Session Data\n")

    let controller = BiometricMusicController()
    controller.setup()

    // Run session for 5 minutes
    DispatchQueue.main.asyncAfter(deadline: .now() + 300.0) {
        let jsonData = controller.exportBiometricSession()

        // Save to file or send to research database
        print("💾 Session data ready for analysis")
        print(jsonData)

        controller.shutdown()
    }
}

#endif // os(iOS)
