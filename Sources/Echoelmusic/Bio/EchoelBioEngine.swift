#if canImport(HealthKit)
//
//  EchoelBioEngine.swift
//  Echoelmusic — Real Biofeedback Engine
//
//  HealthKit integration for real physiological data:
//  - Heart Rate (HR) from Apple Watch / chest strap
//  - Heart Rate Variability (HRV) — self-calculated RMSSD
//  - Breathing Rate (iOS 17+)
//  - Coherence score (derived from HRV spectral analysis)
//
//  Replaces the mic-audio-level proxy in EchoelCreativeWorkspace.
//
//  IMPORTANT: Not a medical device. Data for self-observation only.
//

import Foundation
import HealthKit
#if canImport(Observation)
import Observation
#endif
#if canImport(Combine)
import Combine
#endif

// MARK: - Bio Data Snapshot

/// Current physiological state — updated from HealthKit or fallback
public struct BioSnapshot: Sendable {
    /// Heart rate in BPM [40-200]
    public var heartRate: Double = 72.0

    /// HRV as RMSSD in ms, normalized to [0-1]
    public var hrvNormalized: Double = 0.5

    /// Raw RMSSD in milliseconds
    public var hrvRMSSD: Double = 50.0

    /// Breathing rate in breaths/min [4-30]
    public var breathRate: Double = 12.0

    /// Breath phase [0-1] (0=exhale start, 0.5=inhale start, 1=exhale start)
    public var breathPhase: Double = 0.5

    /// Coherence score [0-1] (derived from LF/HF ratio of HRV)
    public var coherence: Double = 0.5

    /// LF/HF ratio of HRV spectrum
    public var lfHfRatio: Double = 1.0

    /// Data source description
    public var source: BioDataSource = .fallback

    /// Timestamp
    public var timestamp: Date = Date()
}

/// Where bio data is coming from
public enum BioDataSource: String, Sendable {
    case healthKit = "HealthKit"
    case appleWatch = "Apple Watch"
    case chestStrap = "Chest Strap"
    case arkit = "ARKit Face"
    case microphone = "Microphone"
    case fallback = "Simulated"
}

// MARK: - EchoelBioEngine

/// Real biofeedback engine with HealthKit integration
@preconcurrency @MainActor
@Observable
public final class EchoelBioEngine {

    // MARK: - Singleton

    @MainActor public static let shared = EchoelBioEngine()

    // MARK: - Published State

    public var snapshot: BioSnapshot = BioSnapshot()
    public var isAuthorized: Bool = false
    public var isStreaming: Bool = false
    public var dataSource: BioDataSource = .fallback

    /// Smoothed values for audio thread (EMA with ~100ms window)
    public var smoothHeartRate: Double = 72.0
    public var smoothHRV: Double = 0.5
    public var smoothCoherence: Double = 0.5
    public var smoothBreathPhase: Double = 0.5
    public var smoothBreathDepth: Double = 0.5

    // MARK: - HealthKit

    private var healthStore: HKHealthStore?
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var hrvQuery: HKAnchoredObjectQuery?
    private var breathRateQuery: HKAnchoredObjectQuery?
    private var cancellables = Set<AnyCancellable>()
    private var breathTimerCancellable: AnyCancellable?

    // MARK: - HRV Calculation

    /// Recent RR intervals for RMSSD calculation
    private var rrIntervals: [Double] = []
    private let maxRRIntervals = 60 // ~1 minute of data

    /// Smoothing factor (higher = smoother, more latency)
    private let smoothingAlpha: Double = 0.15

    // MARK: - Constants

    /// Apple Watch HR latency is ~4-5 seconds — don't use for beat-sync
    private let appleWatchHRLatency: TimeInterval = 4.5

    /// RMSSD normalization: 100ms is "excellent", 20ms is "low"
    private let rmssdNormalizationMax: Double = 100.0

    // MARK: - Init

    private init() {
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
        }
    }

    // MARK: - Authorization

    /// Request HealthKit permissions
    public func requestAuthorization() async -> Bool {
        guard let healthStore = healthStore else {
            log.log(.warning, category: .audio, "HealthKit not available on this device")
            return false
        }

        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate),
              let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
              let brType = HKObjectType.quantityType(forIdentifier: .respiratoryRate) else {
            log.log(.warning, category: .audio, "HealthKit quantity types unavailable")
            isAuthorized = false
            return false
        }
        let readTypes: Set<HKObjectType> = [hrType, hrvType, brType]

        do {
            try await healthStore.requestAuthorization(toShare: Set(), read: readTypes)
            // requestAuthorization does NOT throw when user denies — check actual status
            let hrStatus = healthStore.authorizationStatus(for: hrType)
            let authorized = hrStatus == .sharingAuthorized || hrStatus == .notDetermined
            // Note: .notDetermined means user hasn't been asked yet for this specific type,
            // but after requestAuthorization it means sharing wasn't requested (read-only).
            // For read types, Apple hides denial — we detect via query returning no data.
            // Best-effort: check if at least heart rate is readable.
            isAuthorized = authorized
            if authorized {
                log.log(.info, category: .audio, "HealthKit authorization granted")
            } else {
                log.log(.warning, category: .audio, "HealthKit authorization denied by user")
            }
            return authorized
        } catch {
            log.log(.error, category: .audio, "HealthKit authorization failed: \(error.localizedDescription)")
            isAuthorized = false
            return false
        }
    }

    // MARK: - Streaming

    /// Start real-time bio data streaming
    public func startStreaming() {
        guard !isStreaming else { return }

        if let healthStore = healthStore, isAuthorized {
            startHeartRateQuery(healthStore: healthStore)
            startHRVQuery(healthStore: healthStore)
            startBreathRateQuery(healthStore: healthStore)
            dataSource = .healthKit
        } else {
            dataSource = .fallback
            startFallbackMode()
        }

        isStreaming = true
        log.log(.info, category: .audio, "Bio streaming started — source: \(dataSource.rawValue)")
    }

    /// Stop streaming
    public func stopStreaming() {
        guard isStreaming else { return }

        if let healthStore = healthStore {
            if let query = heartRateQuery { healthStore.stop(query) }
            if let query = hrvQuery { healthStore.stop(query) }
            if let query = breathRateQuery { healthStore.stop(query) }
        }
        heartRateQuery = nil
        hrvQuery = nil
        breathRateQuery = nil
        cancellables.removeAll()
        breathTimerCancellable?.cancel()
        breathTimerCancellable = nil

        isStreaming = false
        log.log(.info, category: .audio, "Bio streaming stopped")
    }

    // MARK: - HealthKit Queries

    private func startHeartRateQuery(healthStore: HKHealthStore) {
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-60),
            end: nil,
            options: .strictStartDate
        )

        heartRateQuery = HKAnchoredObjectQuery(
            type: hrType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.processHeartRateSamples(samples)
        }

        heartRateQuery?.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.processHeartRateSamples(samples)
        }

        if let query = heartRateQuery {
            healthStore.execute(query)
        }
    }

    private func startHRVQuery(healthStore: HKHealthStore) {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }

        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-300),
            end: nil,
            options: .strictStartDate
        )

        hrvQuery = HKAnchoredObjectQuery(
            type: hrvType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.processHRVSamples(samples)
        }

        hrvQuery?.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.processHRVSamples(samples)
        }

        if let query = hrvQuery {
            healthStore.execute(query)
        }
    }

    private func startBreathRateQuery(healthStore: HKHealthStore) {
        guard let breathType = HKObjectType.quantityType(forIdentifier: .respiratoryRate) else { return }

        let predicate = HKQuery.predicateForSamples(
            withStart: Date().addingTimeInterval(-300),
            end: nil,
            options: .strictStartDate
        )

        breathRateQuery = HKAnchoredObjectQuery(
            type: breathType,
            predicate: predicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, _ in
            self?.processBreathRateSamples(samples)
        }

        breathRateQuery?.updateHandler = { [weak self] _, samples, _, _, _ in
            self?.processBreathRateSamples(samples)
        }

        if let query = breathRateQuery {
            healthStore.execute(query)
        }
    }

    // MARK: - Sample Processing

    private nonisolated func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else { return }

        guard let latestSample = quantitySamples.last else { return }
        let bpm = latestSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

        // Calculate RR interval from HR: RR = 60000 / HR (in ms)
        let rrInterval = 60000.0 / max(bpm, 40.0)

        // HealthKit callbacks run on system query thread — DispatchQueue.main.async
        // avoids Swift 6 dispatch_assert_queue_fail
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.snapshot.heartRate = bpm
            self.snapshot.timestamp = latestSample.startDate
            self.smoothHeartRate = self.smoothHeartRate * (1.0 - self.smoothingAlpha) + bpm * self.smoothingAlpha

            // Accumulate RR intervals for RMSSD calculation
            self.rrIntervals.append(rrInterval)
            if self.rrIntervals.count > self.maxRRIntervals {
                self.rrIntervals.removeFirst()
            }

            // Calculate RMSSD from RR intervals
            if self.rrIntervals.count >= 5 {
                self.calculateRMSSD()
            }
        }
    }

    private nonisolated func processHRVSamples(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else { return }

        // Apple provides SDNN, not RMSSD — we use our own RMSSD calculation
        // But SDNN can serve as a fallback
        guard let latestSample = quantitySamples.last else { return }
        let sdnn = latestSample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Use SDNN as approximate coherence indicator if we don't have enough RR intervals
            if self.rrIntervals.count < 5 {
                let normalized = min(sdnn / self.rmssdNormalizationMax, 1.0)
                self.snapshot.hrvNormalized = normalized
                self.smoothHRV = self.smoothHRV * (1.0 - self.smoothingAlpha) + normalized * self.smoothingAlpha
            }
        }
    }

    private nonisolated func processBreathRateSamples(_ samples: [HKSample]?) {
        guard let quantitySamples = samples as? [HKQuantitySample], !quantitySamples.isEmpty else { return }

        guard let latestSample = quantitySamples.last else { return }
        let rate = latestSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.snapshot.breathRate = rate
        }
    }

    // MARK: - RMSSD Calculation (Rausch 2017)

    /// Calculate RMSSD from successive RR interval differences
    /// Apple only provides SDNN — we need RMSSD for coherence assessment
    private func calculateRMSSD() {
        guard rrIntervals.count >= 2 else { return }

        var sumSquaredDiffs: Double = 0.0
        var count = 0

        for i in 1..<rrIntervals.count {
            let diff = rrIntervals[i] - rrIntervals[i - 1]
            sumSquaredDiffs += diff * diff
            count += 1
        }

        guard count > 0 else { return }
        let rmssd = (sumSquaredDiffs / Double(count)).squareRoot()

        snapshot.hrvRMSSD = rmssd
        let normalized = min(rmssd / rmssdNormalizationMax, 1.0)
        snapshot.hrvNormalized = normalized
        smoothHRV = smoothHRV * (1.0 - smoothingAlpha) + normalized * smoothingAlpha

        // Calculate coherence from HRV regularity
        // High coherence = regular, sinusoidal HRV pattern
        // Low coherence = erratic HRV
        calculateCoherence()
    }

    /// Coherence based on HRV regularity (simplified spectral analysis)
    /// Full implementation would use BioSignalDeconvolver (Rausch 2017)
    private func calculateCoherence() {
        guard rrIntervals.count >= 10 else { return }

        // Calculate variance of successive differences
        let diffs = zip(rrIntervals.dropFirst(), rrIntervals).map { $0 - $1 }
        guard !diffs.isEmpty else { return }
        let mean = diffs.reduce(0, +) / Double(diffs.count)
        let variance = diffs.reduce(0.0) { $0 + ($1 - mean) * ($1 - mean) } / Double(diffs.count)

        // Low variance in diffs = high coherence (regular pattern)
        // Normalize: variance < 100 = high coherence, > 2000 = low
        let coherence = max(0.0, min(1.0, 1.0 - (variance / 2000.0)))

        snapshot.coherence = coherence
        smoothCoherence = smoothCoherence * (1.0 - smoothingAlpha) + coherence * smoothingAlpha
    }

    // MARK: - Fallback Mode (Mic Level Proxy)

    /// When HealthKit unavailable, use microphone RMS as coherence proxy
    private func startFallbackMode() {
        // Cancel any existing breath timer to prevent accumulation
        breathTimerCancellable?.cancel()
        // Simulate slow breath oscillation for demo purposes
        let breathTimer = Timer.publish(every: 1.0 / 20.0, on: .main, in: .common).autoconnect()
        breathTimerCancellable = breathTimer.sink { [weak self] _ in
            guard let self = self else { return }
            // Sinusoidal breath simulation at ~12 breaths/min
            let phase = Date().timeIntervalSinceReferenceDate * (12.0 / 60.0) * 2.0 * Double.pi
            self.snapshot.breathPhase = (sin(phase) + 1.0) / 2.0
            self.smoothBreathPhase = self.snapshot.breathPhase
        }
    }

    // MARK: - Bio → Audio Parameter Bridge

    /// Get current bio parameters for audio engine consumption
    public func audioParameters() -> (coherence: Float, hrv: Float, heartRate: Float, breathPhase: Float, breathDepth: Float) {
        return (
            coherence: Float(smoothCoherence),
            hrv: Float(smoothHRV),
            heartRate: Float(smoothHeartRate),
            breathPhase: Float(smoothBreathPhase),
            breathDepth: Float(smoothBreathDepth)
        )
    }
}

// MARK: - Bio Status View

#if canImport(SwiftUI)
import SwiftUI

/// Compact bio status indicator for transport bar
public struct BioStatusView: View {
    @Bindable private var bio = EchoelBioEngine.shared

    public init() {}

    public var body: some View {
        HStack(spacing: EchoelSpacing.sm) {
            // Coherence ring — grayed out when using fallback data
            ZStack {
                Circle()
                    .stroke(EchoelBrand.border, lineWidth: 3)
                Circle()
                    .trim(from: 0, to: isRealData ? bio.smoothCoherence : 0)
                    .stroke(isRealData ? coherenceColor : EchoelBrand.textSecondary.opacity(0.3), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if isRealData {
                    Text(String(format: "%.0f", bio.smoothCoherence * 100))
                        .font(EchoelBrandFont.dataSmall())
                } else {
                    Text("—")
                        .font(EchoelBrandFont.dataSmall())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(isRealData ? .red : .gray)
                        .font(.system(size: 10))
                    Text(isRealData ? "\(Int(bio.smoothHeartRate))" : "—")
                        .font(EchoelBrandFont.data())
                        .foregroundStyle(isRealData ? EchoelBrand.textPrimary : .secondary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundStyle(isRealData ? EchoelBrand.accent : .gray)
                        .font(.system(size: 10))
                    Text(isRealData ? String(format: "%.0f", bio.snapshot.hrvRMSSD) : "—")
                        .font(EchoelBrandFont.dataSmall())
                        .foregroundStyle(.secondary)
                }
            }

            // Source badge
            VStack(spacing: 1) {
                Circle()
                    .fill(sourceColor)
                    .frame(width: 6, height: 6)
                Text(sourceLabel)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Whether we have real physiological data (not simulated fallback)
    private var isRealData: Bool {
        bio.isStreaming && bio.dataSource != .fallback
    }

    private var sourceLabel: String {
        switch bio.dataSource {
        case .healthKit, .appleWatch, .chestStrap: return "HK"
        case .arkit: return "AR"
        case .microphone: return "MIC"
        case .fallback: return "OFF"
        }
    }

    private var sourceColor: Color {
        switch bio.dataSource {
        case .healthKit, .appleWatch, .chestStrap: return .green
        case .arkit: return .blue
        case .microphone: return .orange
        case .fallback: return .gray
        }
    }

    private var coherenceColor: Color {
        if bio.smoothCoherence > 0.7 { return .green }
        if bio.smoothCoherence > 0.4 { return .yellow }
        return .red
    }
}
#endif

#else
// Non-HealthKit platforms (macOS, Linux)
import Foundation
#if canImport(Observation)
import Observation
#endif

public struct BioSnapshot: Sendable {
    public var heartRate: Double = 72.0
    public var hrvNormalized: Double = 0.5
    public var hrvRMSSD: Double = 50.0
    public var breathRate: Double = 12.0
    public var breathPhase: Double = 0.5
    public var coherence: Double = 0.5
    public var lfHfRatio: Double = 1.0
    public var source: BioDataSource = .fallback
    public var timestamp: Date = Date()
}

public enum BioDataSource: String, Sendable {
    case healthKit = "HealthKit"
    case appleWatch = "Apple Watch"
    case chestStrap = "Chest Strap"
    case arkit = "ARKit Face"
    case microphone = "Microphone"
    case fallback = "Simulated"
}

@preconcurrency @MainActor
@Observable
public final class EchoelBioEngine {
    @MainActor public static let shared = EchoelBioEngine()
    public var snapshot: BioSnapshot = BioSnapshot()
    public var isAuthorized: Bool = false
    public var isStreaming: Bool = false
    public var smoothCoherence: Double = 0.5
    public var smoothHRV: Double = 0.5
    public var smoothHeartRate: Double = 72.0
    public var smoothBreathPhase: Double = 0.5
    public var smoothBreathDepth: Double = 0.5
    private init() {}

    public func requestAuthorization() async -> Bool { false }
    public func startStreaming() { isStreaming = true }
    public func stopStreaming() { isStreaming = false }

    public func audioParameters() -> (coherence: Float, hrv: Float, heartRate: Float, breathPhase: Float, breathDepth: Float) {
        (Float(smoothCoherence), Float(smoothHRV), Float(smoothHeartRate), Float(smoothBreathPhase), Float(smoothBreathDepth))
    }
}
#endif
