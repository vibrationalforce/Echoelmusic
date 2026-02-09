// OuraRingIntegration.swift
// Echoelmusic
//
// Oura Ring integration for offline analytics
// Reads Oura data via HealthKit sync for session recommendations
//
// NOTE: Oura Ring does NOT provide real-time streaming.
// Use Apple Watch or Polar H10 for live bio-reactive audio.
// Oura data is used for: preset suggestions, session planning, recovery tracking.

import Foundation
import HealthKit

// MARK: - Oura Ring Data Types

/// Oura Ring metrics synced to HealthKit
public struct OuraMetrics {
    /// Sleep score (0-100) - Overall sleep quality
    public var sleepScore: Int?

    /// Readiness score (0-100) - How ready you are for the day
    public var readinessScore: Int?

    /// HRV average (ms) - Last night's average
    public var hrvAverage: Double?

    /// Resting heart rate (bpm)
    public var restingHeartRate: Double?

    /// Total sleep duration (hours)
    public var sleepDuration: Double?

    /// Deep sleep percentage
    public var deepSleepPercent: Double?

    /// REM sleep percentage
    public var remSleepPercent: Double?

    /// Body temperature deviation (°C)
    public var temperatureDeviation: Double?

    /// Activity score (0-100)
    public var activityScore: Int?

    /// Steps today
    public var steps: Int?

    /// Last sync timestamp
    public var lastSync: Date?

    public init() {}
}

// MARK: - Session Recommendations

/// Recommended session based on Oura data
public struct OuraSessionRecommendation {
    public let presetName: String
    public let presetNameDE: String
    public let intensity: SessionIntensity
    public let duration: TimeInterval
    public let reason: String
    public let reasonDE: String

    public enum SessionIntensity: String {
        case recovery = "Recovery"
        case gentle = "Gentle"
        case moderate = "Moderate"
        case energetic = "Energetic"
        case intense = "Intense"
    }
}

// MARK: - Oura Ring Integration Manager

/// Manages Oura Ring data integration via HealthKit
///
/// Usage:
/// ```swift
/// let oura = OuraRingIntegration()
/// await oura.fetchLatestMetrics()
/// let recommendation = oura.getSessionRecommendation()
/// ```
@MainActor
public class OuraRingIntegration: ObservableObject {

    // MARK: - Published Properties

    @Published public var metrics = OuraMetrics()
    @Published public var isOuraConnected = false
    @Published public var lastError: String?

    // MARK: - Private Properties

    private let healthStore = HKHealthStore()

    // MARK: - HealthKit Types (Oura syncs these)

    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()

        // Sleep
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }

        // Heart
        if let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrvType)
        }
        if let hrType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(hrType)
        }

        // Activity
        if let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) {
            types.insert(stepsType)
        }

        // Temperature (if available)
        if #available(iOS 16.0, *) {
            if let tempType = HKObjectType.quantityType(forIdentifier: .appleSleepingWristTemperature) {
                types.insert(tempType)
            }
        }

        return types
    }()

    // MARK: - Initialization

    public init() {
        checkOuraConnection()
    }

    // MARK: - Authorization

    /// Request HealthKit authorization for Oura data types
    public func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw OuraError.healthKitNotAvailable
        }

        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    // MARK: - Check Oura Connection

    /// Check if Oura Ring data exists in HealthKit
    private func checkOuraConnection() {
        // Oura data has specific source bundle identifier
        // We check for recent HRV data as indicator
        Task {
            let hasRecentData = await hasRecentOuraData()
            await MainActor.run {
                self.isOuraConnected = hasRecentData
            }
        }
    }

    private func hasRecentOuraData() async -> Bool {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return false
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-24 * 60 * 60),
            end: Date(),
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: (samples?.count ?? 0) > 0)
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Fetch Metrics

    /// Fetch latest Oura metrics from HealthKit
    public func fetchLatestMetrics() async {
        do {
            try await requestAuthorization()

            async let hrv = fetchHRVAverage()
            async let hr = fetchRestingHeartRate()
            async let sleep = fetchSleepData()
            async let steps = fetchSteps()

            let (hrvValue, hrValue, sleepData, stepsValue) = await (hrv, hr, sleep, steps)

            await MainActor.run {
                self.metrics.hrvAverage = hrvValue
                self.metrics.restingHeartRate = hrValue
                self.metrics.sleepDuration = sleepData.duration
                self.metrics.steps = stepsValue
                self.metrics.lastSync = Date()

                // Calculate scores based on data
                self.calculateScores()
            }

        } catch {
            await MainActor.run {
                self.lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Individual Fetchers

    private func fetchHRVAverage() async -> Double? {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: Date().addingTimeInterval(-24 * 60 * 60)),
            end: Date(),
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: hrvType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, _ in
                let value = statistics?.averageQuantity()?.doubleValue(for: HKUnit.secondUnit(with: .milli))
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func fetchRestingHeartRate() async -> Double? {
        guard let hrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-24 * 60 * 60),
            end: Date(),
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: hrType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, _ in
                let value = statistics?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }

    private func fetchSleepData() async -> (duration: Double?, deepPercent: Double?, remPercent: Double?) {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return (nil, nil, nil)
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-24 * 60 * 60),
            end: Date(),
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
            ) { _, samples, _ in
                guard let sleepSamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: (nil, nil, nil))
                    return
                }

                var totalSleep: TimeInterval = 0
                var deepSleep: TimeInterval = 0
                var remSleep: TimeInterval = 0

                for sample in sleepSamples {
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)
                    totalSleep += duration

                    if #available(iOS 16.0, *) {
                        switch sample.value {
                        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                            deepSleep += duration
                        case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                            remSleep += duration
                        default:
                            break
                        }
                    }
                }

                let totalHours = totalSleep / 3600
                let deepPercent = totalSleep > 0 ? (deepSleep / totalSleep) * 100 : nil
                let remPercent = totalSleep > 0 ? (remSleep / totalSleep) * 100 : nil

                continuation.resume(returning: (totalHours, deepPercent, remPercent))
            }
            healthStore.execute(query)
        }
    }

    private func fetchSteps() async -> Int? {
        guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: Calendar.current.startOfDay(for: Date()),
            end: Date(),
            options: .strictStartDate
        )

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepsType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: HKUnit.count())
                continuation.resume(returning: value.map { Int($0) })
            }
            healthStore.execute(query)
        }
    }

    // MARK: - Calculate Scores

    private func calculateScores() {
        // Sleep Score (simplified calculation)
        if let duration = metrics.sleepDuration {
            let durationScore = min(100, Int((duration / 8.0) * 100))
            metrics.sleepScore = durationScore
        }

        // Readiness Score (based on HRV and sleep)
        if let hrv = metrics.hrvAverage, let sleepScore = metrics.sleepScore {
            // Higher HRV = better recovery
            let hrvScore = min(100, Int((hrv / 60.0) * 100))
            metrics.readinessScore = (hrvScore + sleepScore) / 2
        }

        // Activity Score
        if let steps = metrics.steps {
            metrics.activityScore = min(100, Int((Double(steps) / 10000.0) * 100))
        }
    }

    // MARK: - Session Recommendations

    /// Get session recommendation based on Oura metrics
    public func getSessionRecommendation() -> OuraSessionRecommendation {
        let readiness = metrics.readinessScore ?? 50
        let sleepScore = metrics.sleepScore ?? 50
        let hrv = metrics.hrvAverage ?? 40

        // Low readiness / poor sleep → Recovery session
        if readiness < 40 || sleepScore < 40 {
            return OuraSessionRecommendation(
                presetName: "Deep Recovery",
                presetNameDE: "Tiefe Erholung",
                intensity: .recovery,
                duration: 20 * 60,
                reason: "Your readiness is low. A gentle recovery session is recommended.",
                reasonDE: "Deine Bereitschaft ist niedrig. Eine sanfte Erholungssession wird empfohlen."
            )
        }

        // Medium readiness → Gentle session
        if readiness < 60 {
            return OuraSessionRecommendation(
                presetName: "Gentle Flow",
                presetNameDE: "Sanfter Flow",
                intensity: .gentle,
                duration: 15 * 60,
                reason: "Moderate readiness detected. A gentle session will support recovery.",
                reasonDE: "Moderate Bereitschaft erkannt. Eine sanfte Session unterstützt die Erholung."
            )
        }

        // Good readiness + good HRV → Moderate to Energetic
        if readiness >= 70 && hrv >= 50 {
            return OuraSessionRecommendation(
                presetName: "Creative Energy",
                presetNameDE: "Kreative Energie",
                intensity: .energetic,
                duration: 30 * 60,
                reason: "Excellent readiness! Your body is ready for an energetic creative session.",
                reasonDE: "Ausgezeichnete Bereitschaft! Dein Körper ist bereit für eine energetische kreative Session."
            )
        }

        // Default: Moderate
        return OuraSessionRecommendation(
            presetName: "Balanced Focus",
            presetNameDE: "Ausgewogener Fokus",
            intensity: .moderate,
            duration: 20 * 60,
            reason: "Good overall state. A balanced session is recommended.",
            reasonDE: "Guter Gesamtzustand. Eine ausgewogene Session wird empfohlen."
        )
    }

    // MARK: - Preset Mapping

    /// Map Oura recommendation to Echoelmusic preset
    public func getRecommendedPreset() -> String {
        let recommendation = getSessionRecommendation()

        switch recommendation.intensity {
        case .recovery:
            return "DeepMeditation"
        case .gentle:
            return "ZenMaster"
        case .moderate:
            return "AmbientDrone"
        case .energetic:
            return "ActiveFlow"
        case .intense:
            return "TechnoMinimal"
        }
    }

    // MARK: - Morning Insight

    /// Get morning insight message based on last night's data
    public func getMorningInsight() -> (message: String, messageDE: String) {
        let recommendation = getSessionRecommendation()
        let sleepHours = metrics.sleepDuration ?? 0
        let hrv = metrics.hrvAverage ?? 0

        let message = """
        Good morning! Last night: \(String(format: "%.1f", sleepHours))h sleep, \(Int(hrv))ms HRV.
        Recommended: \(recommendation.presetName) (\(Int(recommendation.duration / 60)) min)
        """

        let messageDE = """
        Guten Morgen! Letzte Nacht: \(String(format: "%.1f", sleepHours))h Schlaf, \(Int(hrv))ms HRV.
        Empfohlen: \(recommendation.presetNameDE) (\(Int(recommendation.duration / 60)) min)
        """

        return (message, messageDE)
    }
}

// MARK: - Errors

public enum OuraError: Error, LocalizedError {
    case healthKitNotAvailable
    case authorizationDenied
    case noDataAvailable

    public var errorDescription: String? {
        switch self {
        case .healthKitNotAvailable:
            return "HealthKit is not available on this device"
        case .authorizationDenied:
            return "HealthKit authorization was denied"
        case .noDataAvailable:
            return "No Oura Ring data found in HealthKit"
        }
    }
}

// MARK: - SwiftUI View

import SwiftUI

/// Oura Ring status view for settings
public struct OuraStatusView: View {
    @StateObject private var oura = OuraRingIntegration()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "circle.hexagongrid.fill")
                    .foregroundColor(oura.isOuraConnected ? EchoelBrand.primary : EchoelBrand.textTertiary)
                Text("Oura Ring")
                    .font(EchoelBrandFont.cardTitle())
                Spacer()
                Text(oura.isOuraConnected ? "Connected" : "Not found")
                    .font(EchoelBrandFont.caption())
                    .foregroundColor(oura.isOuraConnected ? EchoelBrand.primary : EchoelBrand.textTertiary)
            }

            if oura.isOuraConnected, let lastSync = oura.metrics.lastSync {
                HStack {
                    if let sleep = oura.metrics.sleepScore {
                        MetricBadge(label: "Sleep", value: "\(sleep)%")
                    }
                    if let readiness = oura.metrics.readinessScore {
                        MetricBadge(label: "Ready", value: "\(readiness)%")
                    }
                    if let hrv = oura.metrics.hrvAverage {
                        MetricBadge(label: "HRV", value: "\(Int(hrv))ms")
                    }
                }

                Text("Last sync: \(lastSync.formatted())")
                    .font(EchoelBrandFont.caption())
                    .foregroundColor(EchoelBrand.textTertiary)
            }

            Text("Oura data is used for session recommendations, not real-time audio.")
                .font(EchoelBrandFont.caption())
                .foregroundColor(EchoelBrand.textTertiary)
        }
        .padding()
        .echoelCard()
        .onAppear {
            Task {
                await oura.fetchLatestMetrics()
            }
        }
    }
}

private struct MetricBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(EchoelBrandFont.dataSmall())
                .foregroundColor(EchoelBrand.primary)
            Text(label)
                .font(EchoelBrandFont.label())
                .foregroundColor(EchoelBrand.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(EchoelBrand.bgGlass)
        .cornerRadius(EchoelRadius.sm)
    }
}
