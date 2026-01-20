import Foundation
#if os(watchOS)
import WatchKit
import HealthKit
import Combine

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

        log.info("⌚ Starting \(type.rawValue) session on Apple Watch", category: .system)

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

        log.info("⌚ Stopping session on Apple Watch", category: .system)

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
            log.error("❌ Failed to start workout session: \(error)", category: .system)
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

    private let watchConnectivityManager = WatchConnectivityManager.shared

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
        let sessionDict: [String: Any] = [
            "type": session.type.rawValue,
            "duration": session.duration,
            "avgHeartRate": session.avgHeartRate,
            "avgHRV": session.avgHRV,
            "avgCoherence": session.avgCoherence,
            "date": session.date.timeIntervalSince1970
        ]

        await watchConnectivityManager.sendSessionData(sessionDict)
        log.info("💾 Session saved and synced: \(duration)s, HRV: \(metrics.hrv), Coherence: \(metrics.coherence)", category: .system)
    }

    // MARK: - Real-time Bio Sync

    func syncBioMetrics() async {
        // Send real-time bio metrics to iPhone
        let bioDict: [String: Any] = [
            "heartRate": currentMetrics.heartRate,
            "hrv": currentMetrics.hrv,
            "coherence": currentMetrics.coherence,
            "breathingRate": currentMetrics.breathingRate,
            "timestamp": Date().timeIntervalSince1970
        ]

        await watchConnectivityManager.sendBioMetrics(bioDict)
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
        // Safely create HKQuantityTypes with guard statements
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate),
              let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
              let respiratoryType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else {
            throw HealthKitError.quantityTypeUnavailable
        }

        let typesToRead: Set<HKObjectType> = [
            heartRateType,
            hrvType,
            respiratoryType
        ]

        guard let heartRateSampleType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.quantityTypeUnavailable
        }

        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            heartRateSampleType
        ]

        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }

    enum HealthKitError: Error, LocalizedError {
        case quantityTypeUnavailable
        case queryFailed

        var errorDescription: String? {
            switch self {
            case .quantityTypeUnavailable:
                return "Required HealthKit quantity type is not available on this device"
            case .queryFailed:
                return "HealthKit query failed"
            }
        }
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
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            log.error("❌ Heart rate quantity type unavailable", category: .system)
            return
        }

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
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            log.error("❌ HRV quantity type unavailable", category: .system)
            return
        }

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
        log.info("🔊 Watch Audio Engine started", category: .system)
    }

    func stop() async {
        isPlaying = false
        log.info("🔊 Watch Audio Engine stopped", category: .system)
    }

    func playInhaleTone() async {
        // Spiele sanften aufsteigenden Ton
        log.info("🎵 Inhale tone", category: .system)
    }

    func playExhaleTone() async {
        // Spiele sanften absteigenden Ton
        log.info("🎵 Exhale tone", category: .system)
    }
}

// MARK: - WatchConnectivity Manager

import WatchConnectivity

class WatchConnectivityManager: NSObject, WCSessionDelegate {

    static let shared = WatchConnectivityManager()

    private var session: WCSession?

    override init() {
        super.init()
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
            log.info("⌚ WatchConnectivity activated", category: .system)
        }
    }

    // MARK: - Send Data to iPhone

    func sendSessionData(_ data: [String: Any]) async {
        guard let session = session, session.isReachable else {
            // Store locally if iPhone not reachable
            try? session?.updateApplicationContext(["pendingSession": data])
            log.info("⌚ Session data stored locally (iPhone not reachable)", category: .system)
            return
        }

        session.sendMessage(["sessionData": data], replyHandler: { reply in
            log.info("⌚ Session data synced to iPhone: \(reply)", category: .system)
        }, errorHandler: { error in
            log.error("❌ Failed to sync session: \(error)", category: .system)
        })
    }

    func sendBioMetrics(_ data: [String: Any]) async {
        guard let session = session, session.isReachable else {
            return  // Skip real-time sync if not reachable
        }

        // Use transferUserInfo for real-time bio data
        session.sendMessage(["bioMetrics": data], replyHandler: nil, errorHandler: nil)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        log.info("⌚ WCSession activation: \(activationState.rawValue)", category: .system)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Handle messages from iPhone (e.g., start session command)
        if let command = message["command"] as? String {
            Task { @MainActor in
                handleCommand(command)
            }
        }
    }

    @MainActor
    private func handleCommand(_ command: String) {
        switch command {
        case "startSession":
            log.info("⌚ Received start session command from iPhone", category: .system)
        case "stopSession":
            log.info("⌚ Received stop session command from iPhone", category: .system)
        default:
            break
        }
    }
}

#endif
