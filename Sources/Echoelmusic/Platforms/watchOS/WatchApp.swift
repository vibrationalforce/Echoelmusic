import Foundation
import WatchKit
import HealthKit
import Combine
import WatchConnectivity
import os.log

#if os(watchOS)

/// Echoelmusic für Apple Watch
///
/// Die Apple Watch ist die IDEALE Plattform für Echoelmusic:
/// - Direkte Bio-Daten: Herzfrequenz, HRV, Coherence am Handgelenk
/// - Kontinuierliche Messung: 24/7 Zugriff auf Gesundheitsdaten
/// - Komplikationen: Live HRV/Coherence auf dem Watch Face
/// - Haptic Feedback: Taktiles Biofeedback für Atemübungen
/// - Standalone: Funktioniert unabhängig vom iPhone
///
/// Features:
/// - Real-time HRV & Coherence Monitoring
/// - Guided Breathing Sessions mit Haptic Feedback
/// - Audio Biofeedback über Watch Speaker/AirPods
/// - Workout Integration (Meditation, Breathing, etc.)
/// - Complications für Watch Faces
/// - Background Heart Rate Monitoring
///
@MainActor
@Observable
class WatchApp {

    // MARK: - Published Properties

    /// Aktuelle Bio-Metriken
    var currentMetrics: BioMetrics = BioMetrics()

    /// Ist eine Session aktiv?
    var isSessionActive: Bool = false

    /// Aktuelle Breathing-Rate
    var breathingRate: Double = 6.0 // Atemzüge pro Minute

    /// Session-Status
    var sessionDuration: TimeInterval = 0

    // MARK: - Private Properties

    private let healthKitManager: WatchHealthKitManager
    private let hapticEngine: HapticEngine
    private let audioEngine: WatchAudioEngine
    private let connectivityManager: WatchConnectivityManager
    private var workoutSession: HKWorkoutSession?
    private var sessionStartTime: Date?

    private var cancellables = Set<AnyCancellable>()
    private static let logger = Logger(subsystem: "com.echoelmusic.watch", category: "WatchApp")

    // MARK: - Bio Metrics

    struct BioMetrics {
        var heartRate: Double = 0
        var hrv: Double = 0
        var coherence: Double = 0
        var breathingRate: Double = 6.0
        var stressLevel: Double = 0.5
        var lastUpdate: Date = Date()

        var coherenceLevel: CoherenceLevel {
            switch coherence {
            case 0.8...1.0: return .high
            case 0.5..<0.8: return .medium
            case 0..<0.5: return .low
            default: return .low
            }
        }

        enum CoherenceLevel: String {
            case low = "Niedrig"
            case medium = "Mittel"
            case high = "Hoch"

            var color: (r: Double, g: Double, b: Double) {
                switch self {
                case .low: return (1.0, 0.3, 0.3)
                case .medium: return (1.0, 0.8, 0.2)
                case .high: return (0.3, 1.0, 0.3)
                }
            }
        }
    }

    // MARK: - Initialization

    init() {
        self.healthKitManager = WatchHealthKitManager()
        self.hapticEngine = HapticEngine()
        self.audioEngine = WatchAudioEngine()
        self.connectivityManager = WatchConnectivityManager()

        setupObservers()
        connectivityManager.activate()
    }

    private func setupObservers() {
        // Beobachte HealthKit-Updates
        healthKitManager.metricsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] metrics in
                self?.currentMetrics = metrics
            }
            .store(in: &cancellables)
    }

    // MARK: - Session Management

    func startSession(type: SessionType) async throws {
        guard !isSessionActive else { return }

        Self.logger.info("Starting \(type.rawValue) session on Apple Watch")

        // Starte HealthKit Workout
        try await startWorkoutSession(type: type)

        // Starte kontinuierliche Messung
        try await healthKitManager.startContinuousMonitoring()

        // Starte Audio-Engine
        await audioEngine.start(breathingRate: breathingRate)

        isSessionActive = true
        sessionStartTime = Date()

        // Starte Haptic-Feedback für Atemführung
        startBreathingGuidance()
    }

    func stopSession() async {
        guard isSessionActive else { return }

        Self.logger.info("Stopping session on Apple Watch")

        // Stoppe Workout
        workoutSession?.end()
        workoutSession = nil

        // Stoppe Monitoring
        healthKitManager.stopContinuousMonitoring()

        // Stoppe Audio
        await audioEngine.stop()

        // Stoppe Haptics
        stopBreathingGuidance()

        isSessionActive = false

        // Speichere Session-Daten
        if let startTime = sessionStartTime {
            let duration = Date().timeIntervalSince(startTime)
            await saveSession(duration: duration, metrics: currentMetrics)
        }
    }

    // MARK: - Workout Integration

    private func startWorkoutSession(type: SessionType) async throws {
        let configuration = HKWorkoutConfiguration()

        switch type {
        case .meditation:
            configuration.activityType = .mindAndBody
        case .breathing:
            configuration.activityType = .mindAndBody
        case .hrvTraining:
            configuration.activityType = .functionalStrengthTraining
        case .coherenceBuilding:
            configuration.activityType = .yoga
        }

        configuration.locationType = .indoor

        do {
            workoutSession = try HKWorkoutSession(healthStore: healthKitManager.healthStore,
                                                   configuration: configuration)
            workoutSession?.startActivity(with: Date())
        } catch {
            Self.logger.error("Failed to start workout session: \(error.localizedDescription)")
            throw error
        }
    }

    enum SessionType: String {
        case meditation = "Meditation"
        case breathing = "Atemübung"
        case hrvTraining = "HRV-Training"
        case coherenceBuilding = "Kohärenz-Aufbau"
    }

    // MARK: - Breathing Guidance

    private var breathingTimer: Timer?

    private func startBreathingGuidance() {
        let cycleInterval = 60.0 / breathingRate // Sekunden pro Atemzyklus
        let inhaleTime = cycleInterval * 0.4
        let exhaleTime = cycleInterval * 0.6

        var isInhale = true

        breathingTimer = Timer.scheduledTimer(withTimeInterval: inhaleTime, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            if isInhale {
                // Einatmen - sanftes Tap-Pattern
                self.hapticEngine.playInhalePattern()
                Task {
                    await self.audioEngine.playInhaleTone()
                }
            } else {
                // Ausatmen - längeres Tap-Pattern
                self.hapticEngine.playExhalePattern()
                Task {
                    await self.audioEngine.playExhaleTone()
                }
            }

            isInhale.toggle()

            // Passe Timer für nächsten Zyklus an
            self.breathingTimer?.invalidate()
            let nextInterval = isInhale ? inhaleTime : exhaleTime
            self.breathingTimer = Timer.scheduledTimer(withTimeInterval: nextInterval, repeats: false) { _ in
                self.startBreathingGuidance()
            }
        }
    }

    private func stopBreathingGuidance() {
        breathingTimer?.invalidate()
        breathingTimer = nil
    }

    // MARK: - Data Management

    private func saveSession(duration: TimeInterval, metrics: BioMetrics) async {
        // Speichere Session-Daten für Sync mit iPhone
        let session = SessionData(
            type: .hrvTraining,
            duration: duration,
            avgHeartRate: metrics.heartRate,
            avgHRV: metrics.hrv,
            avgCoherence: metrics.coherence,
            date: Date()
        )

        // Sync with iPhone via WatchConnectivity
        do {
            try connectivityManager.sendSessionData(session)
            Self.logger.info("Session saved and synced: \(duration)s, HRV: \(metrics.hrv), Coherence: \(metrics.coherence)")
        } catch {
            Self.logger.error("Failed to sync session with iPhone: \(error.localizedDescription)")
            // Save locally for later sync
            connectivityManager.queueForLaterSync(session)
        }
    }

    struct SessionData: Codable {
        let type: SessionType
        let duration: TimeInterval
        let avgHeartRate: Double
        let avgHRV: Double
        let avgCoherence: Double
        let date: Date
    }

    // MARK: - Complication Data

    func getComplicationData() -> ComplicationData {
        return ComplicationData(
            hrv: currentMetrics.hrv,
            coherence: currentMetrics.coherence,
            coherenceLevel: currentMetrics.coherenceLevel,
            timestamp: currentMetrics.lastUpdate
        )
    }

    struct ComplicationData {
        let hrv: Double
        let coherence: Double
        let coherenceLevel: BioMetrics.CoherenceLevel
        let timestamp: Date

        var displayText: String {
            String(format: "HRV: %.2f", hrv)
        }

        var shortText: String {
            String(format: "%.2f", hrv)
        }
    }
}

// MARK: - HealthKit Manager

@MainActor
class WatchHealthKitManager {

    let healthStore = HKHealthStore()
    let metricsPublisher = PassthroughSubject<WatchApp.BioMetrics, Never>()

    private var heartRateQuery: HKAnchoredObjectQuery?
    private var hrvQuery: HKAnchoredObjectQuery?

    func requestAuthorization() async throws {
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!
        ]

        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]

        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }

    func startContinuousMonitoring() async throws {
        // Start continuous heart rate monitoring
        startHeartRateQuery()
        startHRVQuery()
    }

    func stopContinuousMonitoring() {
        if let query = heartRateQuery {
            healthStore.stop(query)
        }
        if let query = hrvQuery {
            healthStore.stop(query)
        }
    }

    private func startHeartRateQuery() {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            guard let samples = samples as? [HKQuantitySample] else { return }

            Task { @MainActor in
                if let latestSample = samples.last {
                    let hr = latestSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    var metrics = self?.metricsPublisher.value ?? WatchApp.BioMetrics()
                    metrics.heartRate = hr
                    metrics.lastUpdate = Date()
                    self?.metricsPublisher.send(metrics)
                }
            }
        }

        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            guard let samples = samples as? [HKQuantitySample] else { return }

            Task { @MainActor in
                if let latestSample = samples.last {
                    let hr = latestSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    var metrics = self?.metricsPublisher.value ?? WatchApp.BioMetrics()
                    metrics.heartRate = hr
                    metrics.lastUpdate = Date()
                    self?.metricsPublisher.send(metrics)
                }
            }
        }

        heartRateQuery = query
        healthStore.execute(query)
    }

    private func startHRVQuery() {
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!

        let query = HKAnchoredObjectQuery(
            type: hrvType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            guard let samples = samples as? [HKQuantitySample] else { return }

            Task { @MainActor in
                if let latestSample = samples.last {
                    let hrv = latestSample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                    var metrics = self?.metricsPublisher.value ?? WatchApp.BioMetrics()
                    metrics.hrv = hrv / 100.0 // Normalisiere zu 0-1
                    metrics.coherence = self?.calculateCoherence(hrv: hrv) ?? 0
                    metrics.lastUpdate = Date()
                    self?.metricsPublisher.send(metrics)
                }
            }
        }

        hrvQuery = query
        healthStore.execute(query)
    }

    private func calculateCoherence(hrv: Double) -> Double {
        // Vereinfachte Kohärenzberechnung
        // In Produktion: Vollständige Spektralanalyse
        return min(hrv / 100.0, 1.0)
    }
}

// MARK: - Haptic Engine

class HapticEngine {

    func playInhalePattern() {
        WKInterfaceDevice.current().play(.start)
    }

    func playExhalePattern() {
        WKInterfaceDevice.current().play(.stop)
    }

    func playSuccessPattern() {
        WKInterfaceDevice.current().play(.success)
    }

    func playFailurePattern() {
        WKInterfaceDevice.current().play(.failure)
    }
}

// MARK: - Audio Engine

@MainActor
class WatchAudioEngine {

    private var isPlaying: Bool = false
    private static let logger = Logger(subsystem: "com.echoelmusic.watch", category: "AudioEngine")

    func start(breathingRate: Double) async {
        isPlaying = true
        Self.logger.info("Watch Audio Engine started with breathing rate: \(breathingRate)")
    }

    func stop() async {
        isPlaying = false
        Self.logger.info("Watch Audio Engine stopped")
    }

    func playInhaleTone() async {
        // Spiele sanften aufsteigenden Ton
        Self.logger.debug("Playing inhale tone")
    }

    func playExhaleTone() async {
        // Spiele sanften absteigenden Ton
        Self.logger.debug("Playing exhale tone")
    }
}

// MARK: - WatchConnectivity Manager

/// Manages WatchConnectivity session for syncing data with iPhone
class WatchConnectivityManager: NSObject, WCSessionDelegate {

    private var session: WCSession?
    private var pendingSessionData: [WatchApp.SessionData] = []
    private static let logger = Logger(subsystem: "com.echoelmusic.watch", category: "WatchConnectivity")

    func activate() {
        guard WCSession.isSupported() else {
            Self.logger.warning("WatchConnectivity not supported on this device")
            return
        }

        session = WCSession.default
        session?.delegate = self
        session?.activate()
        Self.logger.info("WatchConnectivity session activated")
    }

    // MARK: - Send Session Data

    func sendSessionData(_ sessionData: WatchApp.SessionData) throws {
        guard let session = session, session.isReachable else {
            throw WatchConnectivityError.notReachable
        }

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(sessionData)

            let message: [String: Any] = [
                "type": "sessionData",
                "data": data,
                "timestamp": Date().timeIntervalSince1970
            ]

            session.sendMessage(message, replyHandler: { reply in
                Self.logger.info("Session data sent successfully to iPhone")
            }, errorHandler: { error in
                Self.logger.error("Failed to send session data: \(error.localizedDescription)")
            })
        } catch {
            Self.logger.error("Failed to encode session data: \(error.localizedDescription)")
            throw error
        }
    }

    func queueForLaterSync(_ sessionData: WatchApp.SessionData) {
        pendingSessionData.append(sessionData)
        Self.logger.info("Session data queued for later sync (queue size: \(self.pendingSessionData.count))")

        // Try to transfer as user info for background transfer
        transferPendingData()
    }

    private func transferPendingData() {
        guard !pendingSessionData.isEmpty else { return }

        do {
            let encoder = JSONEncoder()
            let dataArray = try encoder.encode(pendingSessionData)

            let userInfo: [String: Any] = [
                "type": "batchSessionData",
                "sessions": dataArray,
                "count": pendingSessionData.count
            ]

            session?.transferUserInfo(userInfo)
            Self.logger.info("Transferred \(self.pendingSessionData.count) pending sessions via background transfer")

            // Clear pending data after successful transfer
            pendingSessionData.removeAll()
        } catch {
            Self.logger.error("Failed to transfer pending data: \(error.localizedDescription)")
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            Self.logger.error("WCSession activation failed: \(error.localizedDescription)")
        } else {
            Self.logger.info("WCSession activated with state: \(String(describing: activationState))")

            // Try to send any pending data
            if activationState == .activated && !pendingSessionData.isEmpty {
                transferPendingData()
            }
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Self.logger.info("Received message from iPhone: \(message.keys.joined(separator: ", "))")
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Self.logger.info("Received message with reply handler from iPhone")
        replyHandler(["status": "received"])
    }

    enum WatchConnectivityError: Error {
        case notReachable
        case sessionNotActivated
        case encodingFailed
    }
}

#endif
