import Foundation
import HealthKit
import Combine

/// HealthKit manager specifically for Apple Watch
/// Leverages built-in HRV and heart rate sensors
@MainActor
class WatchHealthKitManager: ObservableObject {

    // MARK: - Published Properties

    /// Current HRV (RMSSD) in milliseconds
    @Published var currentHRV: Double = 0.0

    /// Current heart rate in BPM
    @Published var heartRate: Double = 70.0

    /// HRV coherence score (0-100)
    @Published var hrvCoherence: Double = 50.0

    /// Whether HealthKit is authorized
    @Published var isAuthorized: Bool = false

    /// Current HRV trend
    @Published var hrvTrend: HRVTrend = .stable

    /// Last update time
    @Published var lastUpdateTime: Date = Date()

    // MARK: - Private Properties

    private let healthStore = HKHealthStore()
    private var hrvQuery: HKAnchoredObjectQuery?
    private var heartRateQuery: HKAnchoredObjectQuery?

    // HRV history for trend calculation
    private var hrvHistory: [Double] = []
    private let historySize = 10

    // MARK: - Initialization

    init() {
        checkAuthorization()
    }

    // MARK: - Authorization

    private func checkAuthorization() {
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        let status = healthStore.authorizationStatus(for: hrvType)
        isAuthorized = status == .sharingAuthorized
    }

    func requestAuthorization() async throws {
        let typesToRead: Set = [
            HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKQuantityType.quantityType(forIdentifier: .heartRate)!,
        ]

        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)

        isAuthorized = true
        print("[WatchHealthKit] ✅ Authorization granted")
    }

    // MARK: - Monitoring

    func startMonitoring() {
        guard isAuthorized else {
            print("[WatchHealthKit] ⚠️  Not authorized")
            return
        }

        startHRVQuery()
        startHeartRateQuery()

        print("[WatchHealthKit] ▶️  Monitoring started")
    }

    func stopMonitoring() {
        if let query = hrvQuery {
            healthStore.stop(query)
        }

        if let query = heartRateQuery {
            healthStore.stop(query)
        }

        print("[WatchHealthKit] ⏹️  Monitoring stopped")
    }

    // MARK: - HRV Query

    private func startHRVQuery() {
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!

        let query = HKAnchoredObjectQuery(
            type: hrvType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHRVSamples(samples)
        }

        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHRVSamples(samples)
        }

        healthStore.execute(query)
        self.hrvQuery = query
    }

    private func processHRVSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else { return }

        // Get most recent sample
        let sortedSamples = samples.sorted { $0.startDate > $1.startDate }
        guard let latest = sortedSamples.first else { return }

        let hrvValue = latest.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))

        Task { @MainActor in
            self.currentHRV = hrvValue
            self.lastUpdateTime = latest.endDate

            // Add to history
            self.hrvHistory.append(hrvValue)
            if self.hrvHistory.count > self.historySize {
                self.hrvHistory.removeFirst()
            }

            // Update trend
            self.updateTrend()

            // Calculate coherence (simplified)
            self.updateCoherence()

            print("[WatchHealthKit] HRV Updated: \(String(format: "%.1f", hrvValue)) ms")
        }
    }

    // MARK: - Heart Rate Query

    private func startHeartRateQuery() {
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        let query = HKAnchoredObjectQuery(
            type: hrType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }

        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }

        healthStore.execute(query)
        self.heartRateQuery = query
    }

    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else { return }

        // Get most recent sample
        let sortedSamples = samples.sorted { $0.startDate > $1.startDate }
        guard let latest = sortedSamples.first else { return }

        let hrValue = latest.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

        Task { @MainActor in
            self.heartRate = hrValue
            print("[WatchHealthKit] HR Updated: \(Int(hrValue)) BPM")
        }
    }

    // MARK: - Trend Calculation

    private func updateTrend() {
        guard hrvHistory.count >= 3 else {
            hrvTrend = .stable
            return
        }

        // Compare recent values to older values
        let recentAvg = hrvHistory.suffix(3).reduce(0.0, +) / 3.0
        let olderAvg = hrvHistory.prefix(hrvHistory.count - 3).reduce(0.0, +) / Double(hrvHistory.count - 3)

        let change = (recentAvg - olderAvg) / olderAvg * 100.0

        if change > 5.0 {
            hrvTrend = .increasing
        } else if change < -5.0 {
            hrvTrend = .decreasing
        } else {
            hrvTrend = .stable
        }
    }

    // MARK: - Coherence Calculation

    private func updateCoherence() {
        guard !hrvHistory.isEmpty else {
            hrvCoherence = 50.0
            return
        }

        // Simplified coherence calculation
        // Higher HRV = better coherence
        // Typical HRV range: 20-100 ms

        let avgHRV = hrvHistory.reduce(0.0, +) / Double(hrvHistory.count)

        // Map HRV to coherence score (0-100)
        // 20ms = 0%, 100ms = 100%
        let coherence = ((avgHRV - 20.0) / 80.0) * 100.0
        hrvCoherence = max(0, min(100, coherence))
    }

    // MARK: - Cleanup

    deinit {
        stopMonitoring()
    }
}

enum HRVTrend {
    case increasing
    case decreasing
    case stable
}
