// OSCBiofeedbackBridge.swift
// Bridges HealthKit and Microphone data to OSC
//
// Usage: Initialize in EchoelApp.swift and it will automatically
// send biofeedback data to Desktop Engine via OSC

import Foundation
import Combine

/// Bridges biofeedback data (HealthKit, Microphone) to OSC
@MainActor
class OSCBiofeedbackBridge: ObservableObject {

    // MARK: - Dependencies

    private let oscManager: OSCManager
    private let healthKitManager: HealthKitManager?
    private let microphoneManager: MicrophoneManager?

    // MARK: - State

    @Published var isEnabled: Bool = true
    @Published var messagesSent: Int = 0

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Throttling

    private var lastHeartRateSent: Date?
    private var lastHRVSent: Date?
    private var lastPitchSent: Date?

    private let heartRateThrottle: TimeInterval = 1.0  // 1 Hz
    private let hrvThrottle: TimeInterval = 1.0        // 1 Hz
    private let pitchThrottle: TimeInterval = 0.016    // ~60 Hz

    // MARK: - Initialization

    init(oscManager: OSCManager,
         healthKitManager: HealthKitManager? = nil,
         microphoneManager: MicrophoneManager? = nil) {

        self.oscManager = oscManager
        self.healthKitManager = healthKitManager
        self.microphoneManager = microphoneManager

        setupObservers()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Observe HealthKit heart rate
        healthKitManager?.$heartRate
            .sink { [weak self] heartRate in
                self?.sendHeartRate(heartRate)
            }
            .store(in: &cancellables)

        // Observe HealthKit HRV
        healthKitManager?.$hrvRMSSD
            .sink { [weak self] hrv in
                self?.sendHRV(hrv)
            }
            .store(in: &cancellables)

        // Observe HealthKit HRV Coherence
        healthKitManager?.$hrvCoherence
            .sink { [weak self] coherence in
                self?.sendCoherence(coherence)
            }
            .store(in: &cancellables)

        // TODO: Observe Microphone pitch when available
        // For now, we'll add a method to manually send pitch
    }

    // MARK: - Send Methods

    /// Send heart rate to Desktop (throttled to 1 Hz)
    private func sendHeartRate(_ bpm: Double) {
        guard isEnabled,
              oscManager.isConnected,
              shouldSend(lastSent: lastHeartRateSent, throttle: heartRateThrottle) else {
            return
        }

        oscManager.sendHeartRate(Float(bpm))
        lastHeartRateSent = Date()
        messagesSent += 1

        print("📡 OSC → HR: \(String(format: "%.1f", bpm)) bpm")
    }

    /// Send HRV to Desktop (throttled to 1 Hz)
    private func sendHRV(_ hrv: Double) {
        guard isEnabled,
              oscManager.isConnected,
              shouldSend(lastSent: lastHRVSent, throttle: hrvThrottle) else {
            return
        }

        oscManager.sendHRV(Float(hrv))
        lastHRVSent = Date()
        messagesSent += 1

        print("📡 OSC → HRV: \(String(format: "%.1f", hrv)) ms")
    }

    /// Send HRV Coherence to Desktop (uses HRV throttle)
    private func sendCoherence(_ coherence: Double) {
        guard isEnabled,
              oscManager.isConnected,
              shouldSend(lastSent: lastHRVSent, throttle: hrvThrottle) else {
            return
        }

        // Send as a parameter (normalized 0-1)
        let normalized = Float(coherence / 100.0)  // Coherence is 0-100, normalize to 0-1
        oscManager.sendParameter(name: "hrv_coherence", value: normalized)

        print("📡 OSC → Coherence: \(String(format: "%.1f", coherence))%")
    }

    /// Send pitch from microphone (throttled to ~60 Hz)
    func sendPitch(frequency: Float, confidence: Float) {
        guard isEnabled,
              oscManager.isConnected,
              shouldSend(lastSent: lastPitchSent, throttle: pitchThrottle),
              confidence > 0.5 else {  // Only send high-confidence pitches
            return
        }

        oscManager.sendPitch(frequency: frequency, confidence: confidence)
        lastPitchSent = Date()
        messagesSent += 1

        // Only log occasionally to avoid spam
        if messagesSent % 60 == 0 {
            print("📡 OSC → Pitch: \(String(format: "%.1f", frequency)) Hz (conf: \(String(format: "%.2f", confidence)))")
        }
    }

    /// Send amplitude from microphone
    func sendAmplitude(_ db: Float) {
        guard isEnabled, oscManager.isConnected else { return }

        oscManager.sendAmplitude(db)
    }

    // MARK: - Control Methods

    /// Enable or disable OSC sending
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        print("📡 OSC Biofeedback Bridge: \(enabled ? "Enabled" : "Disabled")")
    }

    // MARK: - Helpers

    /// Check if enough time has passed since last send (throttling)
    private func shouldSend(lastSent: Date?, throttle: TimeInterval) -> Bool {
        guard let lastSent = lastSent else { return true }
        return Date().timeIntervalSince(lastSent) >= throttle
    }

    // MARK: - Statistics

    func resetStatistics() {
        messagesSent = 0
    }
}
