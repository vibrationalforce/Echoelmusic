// MARK: - EchoelaWatchApp.swift
// Echoelmusic Suite - watchOS Biometric Hub
// Bundle ID: com.echoelmusic.app.watchkitapp
// Copyright 2026 Echoelmusic. All rights reserved.

import SwiftUI
#if canImport(HealthKit)
import HealthKit
#endif
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif
import Combine

// MARK: - Watch Manager

/// watchOS manager for biometric sensing and remote control
/// Primary source of heart rate, HRV, and coherence data for NFT creation
@MainActor
public final class EchoelaWatchManager: NSObject, ObservableObject {

    // MARK: - Singleton

    public static let shared = EchoelaWatchManager()

    // MARK: - Published State

    @Published public private(set) var isSessionActive: Bool = false
    @Published public private(set) var currentHeartRate: Double = 0
    @Published public private(set) var currentHRV: Double = 0
    @Published public private(set) var currentCoherence: Double = 0
    @Published public private(set) var breathingRate: Double = 0
    @Published public private(set) var isPhoneConnected: Bool = false
    @Published public private(set) var sessionDuration: TimeInterval = 0
    @Published public private(set) var coherenceHistory: [Double] = []

    // MARK: - Types

    /// Biometric sample
    public struct BiometricSample: Codable {
        public let timestamp: Date
        public let heartRate: Double
        public let hrv: Double
        public let coherence: Double
        public let breathingRate: Double
    }

    /// Session summary
    public struct SessionSummary: Codable {
        public let id: UUID
        public let startTime: Date
        public let endTime: Date
        public let duration: TimeInterval
        public let samples: [BiometricSample]
        public let averageHeartRate: Double
        public let averageHRV: Double
        public let peakCoherence: Double
        public let averageCoherence: Double
    }

    // MARK: - HealthKit

    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var hrvQuery: HKAnchoredObjectQuery?
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    // MARK: - Watch Connectivity

    private var wcSession: WCSession?

    // MARK: - Session State

    private var sessionStartTime: Date?
    private var samples: [BiometricSample] = []
    private var timer: Timer?
    private var rrIntervals: [Double] = []  // For coherence calculation

    // MARK: - Configuration

    /// Sample rate for biometric data (Hz) - High frequency for Physical AI
    public static let sampleRateHz: Double = 50.0  // 50Hz for < 20ms latency

    /// Coherence calculation window (seconds)
    public static let coherenceWindow: TimeInterval = 60

    /// High-frequency mode for Physical AI integration
    public var highFrequencyMode: Bool = true

    /// Target latency for Physical AI (ms)
    public static let targetLatencyMs: Double = 20.0

    /// HRV types to query
    private let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)
    private let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)
    private let respirationRateType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate)

    // MARK: - Initialization

    private override init() {
        super.init()
        setupWatchConnectivity()
        setupEchoelaContext()
    }

    private func setupWatchConnectivity() {
        if WCSession.isSupported() {
            wcSession = WCSession.default
            wcSession?.delegate = self
            wcSession?.activate()
        }
    }

    private func setupEchoelaContext() {
        Task { @MainActor in
            EchoelaManager.shared.setContext(.watchSensing)
        }

        // Listen for Echoela actions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleEchoelaAction(_:)),
            name: .echoelaAction,
            object: nil
        )
    }

    // MARK: - Public API

    /// Request HealthKit authorization
    public func requestAuthorization() async throws {
        let typesToRead: Set<HKSampleType> = Set(
            [heartRateType, hrvType, respirationRateType].compactMap { $0 }
        )

        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
    }

    /// Start biometric sensing session
    public func startSession() async throws {
        guard !isSessionActive else { return }

        // Request authorization if needed
        try await requestAuthorization()

        // Configure workout session for continuous heart rate
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .mindAndBody
        configuration.locationType = .indoor

        workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        workoutBuilder = workoutSession?.associatedWorkoutBuilder()
        workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )

        workoutSession?.delegate = self
        workoutBuilder?.delegate = self

        // Start session
        let startDate = Date()
        workoutSession?.startActivity(with: startDate)
        try await workoutBuilder?.beginCollection(at: startDate)

        // Start queries
        startHeartRateQuery()
        startHRVQuery()

        // Start high-frequency timer for Physical AI integration
        let interval = highFrequencyMode ? (1.0 / Self.sampleRateHz) : 1.0
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSession()
                if self?.highFrequencyMode == true {
                    self?.streamHighFrequencyData()
                }
            }
        }

        sessionStartTime = startDate
        isSessionActive = true
        samples.removeAll()
        coherenceHistory.removeAll()

        // Notify phone
        sendMessageToPhone(["action": "sessionStarted", "timestamp": startDate.timeIntervalSince1970])
    }

    /// Stop biometric sensing session
    public func stopSession() async throws -> SessionSummary {
        guard isSessionActive else {
            throw WatchError.noActiveSession
        }

        // Stop workout
        let endDate = Date()
        workoutSession?.end()
        try await workoutBuilder?.endCollection(at: endDate)

        // Stop queries
        if let query = heartRateQuery {
            healthStore.stop(query)
        }
        if let query = hrvQuery {
            healthStore.stop(query)
        }

        // Stop timer
        timer?.invalidate()
        timer = nil

        // Calculate summary
        let summary = calculateSessionSummary(endTime: endDate)

        isSessionActive = false
        sessionDuration = 0

        // Send summary to phone
        if let data = try? JSONEncoder().encode(summary) {
            sendDataToPhone(data, description: "sessionSummary")
        }

        return summary
    }

    /// Get current biometric snapshot
    public func getCurrentSnapshot() -> BiometricSample {
        return BiometricSample(
            timestamp: Date(),
            heartRate: currentHeartRate,
            hrv: currentHRV,
            coherence: currentCoherence,
            breathingRate: breathingRate
        )
    }

    // MARK: - Private Methods

    private func startHeartRateQuery() {
        let predicate = HKQuery.predicateForSamples(
            withStart: Date(),
            end: nil,
            options: .strictStartDate
        )

        guard let hrType = heartRateType else { return }
        heartRateQuery = HKAnchoredObjectQuery(
            type: hrType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            Task { @MainActor in
                self?.processHeartRateSamples(samples)
            }
        }

        heartRateQuery?.updateHandler = { [weak self] _, samples, _, _, _ in
            Task { @MainActor in
                self?.processHeartRateSamples(samples)
            }
        }

        if let query = heartRateQuery {
            healthStore.execute(query)
        }
    }

    private func startHRVQuery() {
        let predicate = HKQuery.predicateForSamples(
            withStart: Date(),
            end: nil,
            options: .strictStartDate
        )

        guard let hrvTypeUnwrapped = hrvType else { return }
        hrvQuery = HKAnchoredObjectQuery(
            type: hrvTypeUnwrapped,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            Task { @MainActor in
                self?.processHRVSamples(samples)
            }
        }

        hrvQuery?.updateHandler = { [weak self] _, samples, _, _, _ in
            Task { @MainActor in
                self?.processHRVSamples(samples)
            }
        }

        if let query = hrvQuery {
            healthStore.execute(query)
        }
    }

    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let latest = samples.last else { return }

        let heartRate = latest.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

        Task { @MainActor in
            self.currentHeartRate = heartRate

            // Extract RR interval for coherence (60000 / HR = RR in ms)
            let rrInterval = 60000.0 / heartRate
            self.rrIntervals.append(rrInterval)

            // Keep only last 60 seconds of RR intervals
            let maxSamples = Int(Self.coherenceWindow * Self.sampleRateHz)
            if self.rrIntervals.count > maxSamples {
                self.rrIntervals.removeFirst(self.rrIntervals.count - maxSamples)
            }

            // Send to phone
            self.sendMessageToPhone([
                "heartRate": heartRate,
                "timestamp": Date().timeIntervalSince1970
            ])
        }
    }

    private func processHRVSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let latest = samples.last else { return }

        let hrv = latest.quantity.doubleValue(for: .secondUnit(with: .milli))

        Task { @MainActor in
            self.currentHRV = hrv

            // Send to phone
            self.sendMessageToPhone([
                "hrv": hrv,
                "timestamp": Date().timeIntervalSince1970
            ])
        }
    }

    private func updateSession() {
        guard isSessionActive, let startTime = sessionStartTime else { return }

        // Update duration
        sessionDuration = Date().timeIntervalSince(startTime)

        // Calculate coherence from RR intervals
        currentCoherence = calculateCoherence()
        coherenceHistory.append(currentCoherence)

        // Estimate breathing rate from HRV pattern
        breathingRate = estimateBreathingRate()

        // Create sample
        let sample = BiometricSample(
            timestamp: Date(),
            heartRate: currentHeartRate,
            hrv: currentHRV,
            coherence: currentCoherence,
            breathingRate: breathingRate
        )
        samples.append(sample)

        // Send coherence update to phone
        sendMessageToPhone([
            "coherence": currentCoherence,
            "breathingRate": breathingRate,
            "timestamp": Date().timeIntervalSince1970
        ])
    }

    private func calculateCoherence() -> Double {
        guard rrIntervals.count >= 10 else { return 0 }

        // HeartMath-inspired coherence calculation
        // Uses ratio of power in resonant frequency band (0.04-0.26 Hz)
        // to total power

        // Simplified: Use coefficient of variation of RR intervals
        let mean = rrIntervals.reduce(0, +) / Double(rrIntervals.count)
        let variance = rrIntervals.reduce(0) { $0 + pow($1 - mean, 2) } / Double(rrIntervals.count)
        let stdDev = sqrt(variance)
        let cv = stdDev / mean

        // Convert to 0-1 coherence score (lower CV = higher coherence)
        // Typical CV range: 0.02 (high coherence) to 0.15 (low coherence)
        let normalizedCV = min(max(cv, 0.02), 0.15)
        let coherence = 1.0 - ((normalizedCV - 0.02) / 0.13)

        return max(0, min(1, coherence))
    }

    private func estimateBreathingRate() -> Double {
        // Estimate breathing from RR interval oscillations
        // RSA (Respiratory Sinus Arrhythmia) causes HR to increase on inhale
        // and decrease on exhale

        guard rrIntervals.count >= 20 else { return 12 }  // Default 12 breaths/min

        // Simple zero-crossing detection
        let mean = rrIntervals.reduce(0, +) / Double(rrIntervals.count)
        let centered = rrIntervals.map { $0 - mean }

        var crossings = 0
        for i in 1..<centered.count {
            if (centered[i-1] < 0 && centered[i] >= 0) ||
               (centered[i-1] >= 0 && centered[i] < 0) {
                crossings += 1
            }
        }

        // Each full cycle = 2 crossings, duration = samples / sample rate
        let duration = Double(rrIntervals.count) / Self.sampleRateHz
        let cycles = Double(crossings) / 2.0
        let breathsPerSecond = cycles / duration
        let breathsPerMinute = breathsPerSecond * 60

        return max(4, min(30, breathsPerMinute))
    }

    private func calculateSessionSummary(endTime: Date) -> SessionSummary {
        let startTime = sessionStartTime ?? Date()
        let duration = endTime.timeIntervalSince(startTime)

        let avgHR = samples.isEmpty ? 0 : samples.map(\.heartRate).reduce(0, +) / Double(samples.count)
        let avgHRV = samples.isEmpty ? 0 : samples.map(\.hrv).reduce(0, +) / Double(samples.count)
        let avgCoherence = coherenceHistory.isEmpty ? 0 : coherenceHistory.reduce(0, +) / Double(coherenceHistory.count)
        let peakCoherence = coherenceHistory.max() ?? 0

        return SessionSummary(
            id: UUID(),
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            samples: samples,
            averageHeartRate: avgHR,
            averageHRV: avgHRV,
            peakCoherence: peakCoherence,
            averageCoherence: avgCoherence
        )
    }

    private func sendMessageToPhone(_ message: [String: Any]) {
        guard let session = wcSession, session.isReachable else { return }
        session.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }

    /// Stream high-frequency sensor data for Physical AI Engine
    /// Target: < 20ms latency for real-time aura response
    private func streamHighFrequencyData() {
        guard let session = wcSession, session.isReachable else { return }

        // Package RR intervals for RMSSD calculation on phone
        let recentRR = Array(rrIntervals.suffix(5)).map { Float($0) }

        let sensorData: [String: Any] = [
            "type": "highFrequencySensor",
            "timestamp": Date().timeIntervalSince1970,
            "heartRate": currentHeartRate,
            "rrIntervals": recentRR,
            "coherence": currentCoherence,
            "hrv": currentHRV,
            "breathingRate": breathingRate,
            "source": "appleWatch"
        ]

        // Use sendMessage for lowest latency (vs transferUserInfo)
        session.sendMessage(sensorData, replyHandler: nil) { error in
            // Silently handle - high frequency means some drops are OK
        }
    }

    /// Enable/disable high-frequency mode
    public func setHighFrequencyMode(_ enabled: Bool) {
        highFrequencyMode = enabled

        // Restart timer with new interval if session is active
        if isSessionActive {
            timer?.invalidate()
            let interval = enabled ? (1.0 / Self.sampleRateHz) : 1.0
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    self?.updateSession()
                    if self?.highFrequencyMode == true {
                        self?.streamHighFrequencyData()
                    }
                }
            }
        }
    }

    private func sendDataToPhone(_ data: Data, description: String) {
        guard let session = wcSession, session.activationState == .activated else { return }

        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(description).json")
        try? data.write(to: fileURL)

        session.transferFile(fileURL, metadata: ["type": description])
    }

    @objc private func handleEchoelaAction(_ notification: Notification) {
        guard let info = notification.userInfo as? [String: Any],
              (info["category"] as? String) == "watch" else { return }

        let action = info["action"] as? String

        Task { @MainActor in
            switch action {
            case "sense":
                try? await startSession()
            case "stop":
                _ = try? await stopSession()
            default:
                break
            }
        }
    }
}

// MARK: - Watch Connectivity Delegate

extension EchoelaWatchManager: WCSessionDelegate {
    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            isPhoneConnected = (activationState == .activated)
        }
    }

    public func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isPhoneConnected = session.isReachable
        }
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // Handle commands from phone
        if let action = message["action"] as? String {
            Task { @MainActor in
                switch action {
                case "startSession":
                    try? await startSession()
                case "stopSession":
                    _ = try? await stopSession()
                default:
                    break
                }
            }
        }
    }
}

// MARK: - Workout Session Delegate

extension EchoelaWatchManager: HKWorkoutSessionDelegate {
    public func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        // Handle state changes
    }

    public func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            isSessionActive = false
        }
    }
}

// MARK: - Live Workout Builder Delegate

extension EchoelaWatchManager: HKLiveWorkoutBuilderDelegate {
    public func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // Handle collected events
    }

    public func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // Data collected
    }
}

// MARK: - Errors

public enum WatchError: LocalizedError {
    case noActiveSession
    case healthKitNotAvailable
    case authorizationDenied

    public var errorDescription: String? {
        switch self {
        case .noActiveSession:
            return "No active biometric session"
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device"
        case .authorizationDenied:
            return "HealthKit authorization was denied"
        }
    }
}

// MARK: - Watch UI

/// Main watchOS app view
public struct EchoelaWatchView: View {
    @ObservedObject private var watchManager = EchoelaWatchManager.shared

    public init() {}

    public var body: some View {
        TabView {
            // Main metrics view
            EchoelaMetricsView()

            // Session control
            SessionControlView()

            // Phone connection status
            ConnectionView()
        }
        .tabViewStyle(.carousel)
    }
}

struct EchoelaMetricsView: View {
    @ObservedObject private var watchManager = EchoelaWatchManager.shared

    var body: some View {
        VStack(spacing: 8) {
            // Coherence gauge
            Gauge(value: watchManager.currentCoherence) {
                Image(systemName: "heart.circle.fill")
            }
            .gaugeStyle(.accessoryCircular)
            .tint(coherenceColor)

            Text("\(Int(watchManager.currentCoherence * 100))%")
                .font(.title2)
                .fontWeight(.bold)

            HStack(spacing: 16) {
                VStack {
                    Text("\(Int(watchManager.currentHeartRate))")
                        .font(.headline)
                    Text("BPM")
                        .font(.caption2)
                }

                VStack {
                    Text("\(Int(watchManager.currentHRV))")
                        .font(.headline)
                    Text("HRV")
                        .font(.caption2)
                }
            }
            .foregroundStyle(.secondary)
        }
    }

    var coherenceColor: Color {
        if watchManager.currentCoherence > 0.7 {
            return .green
        } else if watchManager.currentCoherence > 0.4 {
            return .yellow
        } else {
            return .red
        }
    }
}

struct SessionControlView: View {
    @ObservedObject private var watchManager = EchoelaWatchManager.shared

    var body: some View {
        VStack(spacing: 12) {
            if watchManager.isSessionActive {
                Text(formatDuration(watchManager.sessionDuration))
                    .font(.title3)
                    .monospacedDigit()

                Button {
                    Task {
                        _ = try? await watchManager.stopSession()
                    }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .tint(.red)
            } else {
                Button {
                    Task {
                        try? await watchManager.startSession()
                    }
                } label: {
                    Label("Start Sensing", systemImage: "waveform")
                }
                .tint(.purple)
            }
        }
    }

    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct ConnectionView: View {
    @ObservedObject private var watchManager = EchoelaWatchManager.shared

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: watchManager.isPhoneConnected ? "iphone.radiowaves.left.and.right" : "iphone.slash")
                .font(.largeTitle)
                .foregroundStyle(watchManager.isPhoneConnected ? .green : .secondary)

            Text(watchManager.isPhoneConnected ? "Connected" : "Disconnected")
                .font(.caption)
        }
    }
}
