import Foundation
import WatchKit
import HealthKit
import Combine
import WatchConnectivity

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

        setupObservers()
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

        print("⌚ Starting \(type.rawValue) session on Apple Watch")

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

        print("⌚ Stopping session on Apple Watch")

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
            print("❌ Failed to start workout session: \(error)")
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
            try await connectivityManager.sendSessionToPhone(session)
            print("📲 Session synced to iPhone: \(duration)s, HRV: \(metrics.hrv), Coherence: \(metrics.coherence)")
        } catch {
            // Store locally for later sync if phone is not reachable
            connectivityManager.queueSessionForLaterSync(session)
            print("💾 Session queued for later sync: \(error.localizedDescription)")
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

    func start(breathingRate: Double) async {
        isPlaying = true
        print("🔊 Watch Audio Engine started")
    }

    func stop() async {
        isPlaying = false
        print("🔊 Watch Audio Engine stopped")
    }

    func playInhaleTone() async {
        // Spiele sanften aufsteigenden Ton
        print("🎵 Inhale tone")
    }

    func playExhaleTone() async {
        // Spiele sanften absteigenden Ton
        print("🎵 Exhale tone")
    }
}

// MARK: - WatchConnectivity Manager

/// Manages bidirectional communication between Watch and iPhone
class WatchConnectivityManager: NSObject, WCSessionDelegate {

    private var session: WCSession?
    private var pendingSessions: [WatchApp.SessionData] = []
    private let pendingSessionsKey = "PendingSessions"

    override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }

        // Load any pending sessions from storage
        loadPendingSessions()
    }

    // MARK: - Send Session to iPhone

    func sendSessionToPhone(_ sessionData: WatchApp.SessionData) async throws {
        guard let session = session, session.isReachable else {
            throw WatchConnectivityError.phoneNotReachable
        }

        let encoder = JSONEncoder()
        let data = try encoder.encode(sessionData)

        let message: [String: Any] = [
            "type": "session_sync",
            "data": data,
            "timestamp": Date().timeIntervalSince1970
        ]

        return try await withCheckedThrowingContinuation { continuation in
            session.sendMessage(message, replyHandler: { reply in
                if let success = reply["success"] as? Bool, success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: WatchConnectivityError.syncFailed)
                }
            }, errorHandler: { error in
                continuation.resume(throwing: error)
            })
        }
    }

    // MARK: - Queue for Later Sync

    func queueSessionForLaterSync(_ sessionData: WatchApp.SessionData) {
        pendingSessions.append(sessionData)
        savePendingSessions()
        print("📦 Queued session for later sync. Total pending: \(pendingSessions.count)")
    }

    /// Attempt to sync all pending sessions
    func syncPendingSessions() async {
        guard !pendingSessions.isEmpty else { return }

        var successfullySync: [WatchApp.SessionData] = []

        for session in pendingSessions {
            do {
                try await sendSessionToPhone(session)
                successfullySync.append(session)
            } catch {
                // Stop trying if phone is not reachable
                break
            }
        }

        // Remove successfully synced sessions
        pendingSessions.removeAll { session in
            successfullySync.contains { $0.date == session.date }
        }
        savePendingSessions()

        if !successfullySync.isEmpty {
            print("📲 Synced \(successfullySync.count) pending sessions")
        }
    }

    // MARK: - Real-time Metrics Streaming

    func sendLiveMetrics(_ metrics: WatchApp.BioMetrics) {
        guard let session = session, session.isReachable else { return }

        let message: [String: Any] = [
            "type": "live_metrics",
            "heartRate": metrics.heartRate,
            "hrv": metrics.hrv,
            "coherence": metrics.coherence,
            "breathingRate": metrics.breathingRate,
            "stressLevel": metrics.stressLevel,
            "timestamp": Date().timeIntervalSince1970
        ]

        // Use transferUserInfo for background transfer
        session.transferUserInfo(message)
    }

    // MARK: - Persistence

    private func savePendingSessions() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(pendingSessions) {
            UserDefaults.standard.set(data, forKey: pendingSessionsKey)
        }
    }

    private func loadPendingSessions() {
        if let data = UserDefaults.standard.data(forKey: pendingSessionsKey),
           let sessions = try? JSONDecoder().decode([WatchApp.SessionData].self, from: data) {
            pendingSessions = sessions
        }
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated {
            print("⌚ WatchConnectivity: Session activated")

            // Try to sync pending sessions when connected
            Task {
                await syncPendingSessions()
            }
        } else if let error = error {
            print("⌚ WatchConnectivity: Activation failed - \(error.localizedDescription)")
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Handle messages from iPhone (e.g., start/stop commands)
        if let command = message["command"] as? String {
            switch command {
            case "start_session":
                NotificationCenter.default.post(name: .startSessionFromPhone, object: nil)
            case "stop_session":
                NotificationCenter.default.post(name: .stopSessionFromPhone, object: nil)
            case "update_breathing_rate":
                if let rate = message["rate"] as? Double {
                    NotificationCenter.default.post(name: .updateBreathingRate, object: nil, userInfo: ["rate": rate])
                }
            default:
                break
            }
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable {
            print("⌚ WatchConnectivity: iPhone is now reachable")
            Task {
                await syncPendingSessions()
            }
        } else {
            print("⌚ WatchConnectivity: iPhone is not reachable")
        }
    }
}

// MARK: - WatchConnectivity Errors

enum WatchConnectivityError: LocalizedError {
    case phoneNotReachable
    case syncFailed

    var errorDescription: String? {
        switch self {
        case .phoneNotReachable:
            return "iPhone is not reachable. Session will sync when connection is restored."
        case .syncFailed:
            return "Failed to sync session with iPhone."
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let startSessionFromPhone = Notification.Name("startSessionFromPhone")
    static let stopSessionFromPhone = Notification.Name("stopSessionFromPhone")
    static let updateBreathingRate = Notification.Name("updateBreathingRate")
}

#endif
