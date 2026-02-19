// UnifiedHealthKitEngine.swift
// Echoelmusic - Consolidated HealthKit Integration
//
// Unified engine combining features from:
// - HealthKitManager (HeartMath coherence, FFT, breathing rate)
// - ProductionHealthKitManager (multi-source, privacy, workout, export/import)
// - RealTimeHealthKitEngine (high-precision streaming, delegates, SwiftUI views)
//
// Created 2026-02-04
// Copyright (c) 2026 Echoelmusic. All rights reserved.
//
// ============================================================================
// DISCLAIMER: NOT A MEDICAL DEVICE
// This biometric integration is for CREATIVE and INFORMATIONAL purposes only.
// NOT intended for health monitoring or medical decisions.
// Consult healthcare providers for all health concerns.
// ============================================================================

import Foundation
import SwiftUI
import Combine
import Accelerate

#if canImport(HealthKit)
import HealthKit
#endif

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Data Structures

/// Data source for HealthKit biometric data
public enum HealthDataSource: String, Codable, Sendable {
    case realDevice        // Actual HealthKit data from iPhone/Apple Watch
    case appleWatch        // Watch-specific queries with higher priority
    case simulation        // Fallback for simulator/testing
    case replay            // Recorded session playback
}

/// HealthKit data privacy configuration
public struct HealthPrivacyConfig: Sendable {
    public let anonymizeData: Bool
    public let localOnlyProcessing: Bool
    public let encryptAtRest: Bool
    public let hipaaCompliant: Bool
    public let dataRetentionDays: Int

    public static let `default` = HealthPrivacyConfig(
        anonymizeData: true,
        localOnlyProcessing: true,
        encryptAtRest: true,
        hipaaCompliant: true,
        dataRetentionDays: 30
    )

    public static let maxPrivacy = HealthPrivacyConfig(
        anonymizeData: true,
        localOnlyProcessing: true,
        encryptAtRest: true,
        hipaaCompliant: true,
        dataRetentionDays: 7
    )

    public init(
        anonymizeData: Bool,
        localOnlyProcessing: Bool,
        encryptAtRest: Bool,
        hipaaCompliant: Bool,
        dataRetentionDays: Int
    ) {
        self.anonymizeData = anonymizeData
        self.localOnlyProcessing = localOnlyProcessing
        self.encryptAtRest = encryptAtRest
        self.hipaaCompliant = hipaaCompliant
        self.dataRetentionDays = dataRetentionDays
    }
}

/// Real-time heart data
public struct UnifiedHeartData: Codable, Sendable, Equatable {
    public var timestamp: Date
    public var heartRate: Double              // BPM
    public var heartRateVariability: Double   // SDNN in ms
    public var rrIntervals: [Double]          // Recent RR intervals in ms
    public var rmssd: Double                  // Root mean square of successive differences
    public var pnn50: Double                  // Percentage of intervals > 50ms difference
    public var coherenceScore: Double         // HeartMath coherence (0-1)
    public var lfPower: Double                // Low frequency power (0.04-0.15 Hz)
    public var hfPower: Double                // High frequency power (0.15-0.4 Hz)
    public var lfHfRatio: Double              // LF/HF ratio
    public var source: HealthDataSource

    public init(
        timestamp: Date = Date(),
        heartRate: Double = 70,
        heartRateVariability: Double = 50,
        rrIntervals: [Double] = [],
        rmssd: Double = 0,
        pnn50: Double = 0,
        coherenceScore: Double = 0.5,
        lfPower: Double = 0,
        hfPower: Double = 0,
        lfHfRatio: Double = 1.0,
        source: HealthDataSource = .realDevice
    ) {
        self.timestamp = timestamp
        self.heartRate = heartRate
        self.heartRateVariability = heartRateVariability
        self.rrIntervals = rrIntervals
        self.rmssd = rmssd
        self.pnn50 = pnn50
        self.coherenceScore = coherenceScore
        self.lfPower = lfPower
        self.hfPower = hfPower
        self.lfHfRatio = lfHfRatio
        self.source = source
    }
}

/// Real-time respiratory data
public struct UnifiedRespiratoryData: Codable, Sendable, Equatable {
    public var breathingRate: Double          // Breaths per minute
    public var breathPhase: Double            // 0-1 (0=inhale start, 0.5=exhale start)
    public var breathDepth: Double            // Relative depth 0-1
    public var respiratorySinusArrhythmia: Double
    public var timestamp: Date

    public init(
        breathingRate: Double = 12,
        breathPhase: Double = 0.5,
        breathDepth: Double = 0.5,
        respiratorySinusArrhythmia: Double = 0,
        timestamp: Date = Date()
    ) {
        self.breathingRate = breathingRate
        self.breathPhase = breathPhase
        self.breathDepth = breathDepth
        self.respiratorySinusArrhythmia = respiratorySinusArrhythmia
        self.timestamp = timestamp
    }
}

/// Coherence trend direction
public enum CoherenceTrend: String, Sendable {
    case increasing
    case decreasing
    case stable
}

/// Coherence level classification
public enum CoherenceLevel: String, Sendable {
    case low      // 0-40
    case medium   // 40-60
    case high     // 60-100
}

/// Authorization state
public enum HealthKitAuthState: Sendable {
    case unknown
    case notDetermined
    case authorized
    case denied
    case unavailable

    public var canRetry: Bool {
        switch self {
        case .notDetermined, .unknown: return true
        case .denied, .authorized, .unavailable: return false
        }
    }
}

// MARK: - Optimized Circular Buffer

/// High-performance O(1) circular buffer for real-time biometric data
struct HealthCircularBuffer<T> {
    private var buffer: [T?]
    private var writeIndex: Int = 0
    private(set) var count: Int = 0
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }

    /// O(1) append with automatic oldest-value overwrite
    mutating func append(_ value: T) {
        buffer[writeIndex] = value
        writeIndex = (writeIndex + 1) % capacity
        count = min(count + 1, capacity)
    }

    /// Get all values in chronological order (oldest to newest)
    func toArray() -> [T] {
        guard count > 0 else { return [] }

        var result: [T] = []
        result.reserveCapacity(count)

        if count < capacity {
            for i in 0..<count {
                if let value = buffer[i] {
                    result.append(value)
                }
            }
        } else {
            for i in 0..<capacity {
                let index = (writeIndex + i) % capacity
                if let value = buffer[index] {
                    result.append(value)
                }
            }
        }
        return result
    }

    func hasMinimumSamples(_ minimum: Int) -> Bool {
        count >= minimum
    }

    var isEmpty: Bool { count == 0 }
    var isFull: Bool { count == capacity }

    mutating func clear() {
        buffer = Array(repeating: nil, count: capacity)
        writeIndex = 0
        count = 0
    }
}

// MARK: - Delegate Protocol

/// Protocol for receiving real-time health updates
public protocol UnifiedHealthKitDelegate: AnyObject {
    func healthKit(_ engine: UnifiedHealthKitEngine, didUpdateHeart data: UnifiedHeartData)
    func healthKit(_ engine: UnifiedHealthKitEngine, didUpdateRespiratory data: UnifiedRespiratoryData)
    func healthKit(_ engine: UnifiedHealthKitEngine, didChangeCoherence coherence: Double, trend: CoherenceTrend)
    func healthKitDidLoseConnection(_ engine: UnifiedHealthKitEngine)
}

// Default implementations
public extension UnifiedHealthKitDelegate {
    func healthKit(_ engine: UnifiedHealthKitEngine, didUpdateHeart data: UnifiedHeartData) {}
    func healthKit(_ engine: UnifiedHealthKitEngine, didUpdateRespiratory data: UnifiedRespiratoryData) {}
    func healthKit(_ engine: UnifiedHealthKitEngine, didChangeCoherence coherence: Double, trend: CoherenceTrend) {}
    func healthKitDidLoseConnection(_ engine: UnifiedHealthKitEngine) {}
}

// MARK: - Unified HealthKit Engine

/// Unified HealthKit integration engine combining all biometric features
/// NOT A MEDICAL DEVICE - For creative/informational purposes only
@MainActor
public final class UnifiedHealthKitEngine: ObservableObject {

    // MARK: - Singleton

    public static let shared = UnifiedHealthKitEngine()

    // MARK: - Published State

    @Published public private(set) var isStreaming: Bool = false
    @Published public private(set) var isAuthorized: Bool = false
    @Published public private(set) var authState: HealthKitAuthState = .unknown
    @Published public private(set) var dataSource: HealthDataSource = .realDevice

    // Heart data
    @Published public private(set) var heartData: UnifiedHeartData = UnifiedHeartData()
    @Published public private(set) var heartRate: Double = 70.0
    @Published public private(set) var hrvSDNN: Double = 50.0
    @Published public private(set) var coherence: Double = 0.5
    @Published public private(set) var coherenceLevel: CoherenceLevel = .medium
    @Published public private(set) var coherenceTrend: CoherenceTrend = .stable
    @Published public private(set) var coherenceHistory: [Double] = []

    // Respiratory data
    @Published public private(set) var respiratoryData: UnifiedRespiratoryData = UnifiedRespiratoryData()
    @Published public private(set) var breathingRate: Double = 12.0

    // Stream statistics
    @Published public private(set) var sampleRate: Double = 0
    @Published public private(set) var lastUpdateTime: Date = Date()
    @Published public private(set) var errorMessage: String?

    // MARK: - Configuration

    public var privacyConfig: HealthPrivacyConfig
    public weak var delegate: UnifiedHealthKitDelegate?

    /// Callbacks for non-delegate usage
    public var onHeartUpdate: ((UnifiedHeartData) -> Void)?
    public var onRespiratoryUpdate: ((UnifiedRespiratoryData) -> Void)?
    public var onCoherenceChange: ((Double, CoherenceTrend) -> Void)?

    // MARK: - Private Properties

    #if canImport(HealthKit)
    private var healthStore: HKHealthStore?
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var hrvQuery: HKAnchoredObjectQuery?
    private var lastAnchor: HKQueryAnchor?

    private let typesToRead: Set<HKObjectType> = {
        var types: Set<HKObjectType> = []
        if let hr = HKObjectType.quantityType(forIdentifier: .heartRate) { types.insert(hr) }
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) { types.insert(hrv) }
        if let rhr = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { types.insert(rhr) }
        if let resp = HKObjectType.quantityType(forIdentifier: .respiratoryRate) { types.insert(resp) }
        if let spo2 = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) { types.insert(spo2) }
        return types
    }()
    #endif

    // Buffers
    private var rrIntervalBuffer: HealthCircularBuffer<Double>
    private var coherenceBuffer: HealthCircularBuffer<Double>
    private let maxRRIntervals = 120  // ~60 seconds at 60 BPM
    private let coherenceWindowSize = 60

    // FFT caching for coherence calculation
    private var cachedFFTSetup: OpaquePointer?
    private var cachedFFTSize: Int = 0

    // High-precision timer for streaming
    private var updateTimer: DispatchSourceTimer?
    private let updateQueue = DispatchQueue(label: "com.echoelmusic.healthkit.unified", qos: .userInteractive)

    // Replay
    private var replayTimer: Timer?
    private var replayIndex: Int = 0
    private var replayData: [Double] = []

    // MARK: - Health Disclaimer

    public static let healthDisclaimer = """
    ============================================================================
    IMPORTANT: NOT A MEDICAL DEVICE
    ============================================================================

    This biometric integration is for CREATIVE and INFORMATIONAL purposes only.

    - Heart rate, HRV, and coherence readings may NOT be accurate
    - "Coherence" scores are creative interpretations, not clinical measurements
    - NOT intended for health monitoring or medical decisions
    - NOT a substitute for professional medical devices or care

    If you have health concerns, consult a qualified healthcare provider.

    ============================================================================
    """

    // MARK: - Initialization

    public init(
        dataSource: HealthDataSource = .realDevice,
        privacy: HealthPrivacyConfig = .default
    ) {
        self.dataSource = dataSource
        self.privacyConfig = privacy
        self.rrIntervalBuffer = HealthCircularBuffer(capacity: maxRRIntervals)
        self.coherenceBuffer = HealthCircularBuffer(capacity: coherenceWindowSize)

        #if canImport(HealthKit)
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
        }
        #endif

        #if targetEnvironment(simulator)
        self.dataSource = .simulation
        log.biofeedback("Running in simulator, using simulated HealthKit data")
        #endif

        checkAvailability()
        log.biofeedback("UnifiedHealthKitEngine initialized (source: \(dataSource.rawValue))")
    }

    deinit {
        if let setup = cachedFFTSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    // MARK: - Availability Check

    private func checkAvailability() {
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            authState = .unavailable
            errorMessage = "HealthKit is not available on this device"
            dataSource = .simulation
            return
        }

        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
              let store = healthStore else {
            errorMessage = "Heart rate type not available"
            return
        }

        let status = store.authorizationStatus(for: heartRateType)
        switch status {
        case .sharingAuthorized:
            isAuthorized = true
            authState = .authorized
        case .sharingDenied:
            authState = .denied
        case .notDetermined:
            authState = .notDetermined
        @unknown default:
            authState = .unknown
        }
        #else
        authState = .unavailable
        dataSource = .simulation
        errorMessage = "HealthKit not available on this platform"
        #endif
    }

    // MARK: - Authorization

    /// Request HealthKit authorization
    public func requestAuthorization() async throws {
        #if canImport(HealthKit)
        guard let store = healthStore else {
            authState = .unavailable
            dataSource = .simulation
            isAuthorized = true  // Allow simulation
            return
        }

        guard HKHealthStore.isHealthDataAvailable() else {
            authState = .unavailable
            dataSource = .simulation
            isAuthorized = true
            return
        }

        do {
            try await store.requestAuthorization(toShare: [], read: typesToRead)

            guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
                authState = .unavailable
                return
            }

            let status = store.authorizationStatus(for: heartRateType)
            isAuthorized = (status == .sharingAuthorized)

            if isAuthorized {
                authState = .authorized
                errorMessage = nil
                log.biofeedback("HealthKit authorized")
            } else {
                authState = .denied
                dataSource = .simulation
                isAuthorized = true  // Allow simulation fallback
                errorMessage = "HealthKit access denied. Using simulation mode."
            }
        } catch {
            authState = .denied
            dataSource = .simulation
            isAuthorized = true  // Allow simulation fallback
            errorMessage = "Authorization failed: \(error.localizedDescription)"
            log.biofeedback("HealthKit authorization failed: \(error)", level: .warning)
        }
        #else
        authState = .unavailable
        dataSource = .simulation
        isAuthorized = true
        #endif
    }

    /// Open Health settings
    public func openHealthSettings() {
        #if os(iOS)
        if let url = URL(string: "x-apple-health://") {
            Task { @MainActor in
                await UIApplication.shared.open(url)
            }
        }
        #endif
    }

    // MARK: - Streaming Control

    /// Start real-time health data streaming
    public func startStreaming() {
        guard !isStreaming else { return }
        isStreaming = true

        log.biofeedback("Starting health streaming (source: \(dataSource.rawValue))")
        log.biofeedback(Self.healthDisclaimer)

        switch dataSource {
        case .realDevice, .appleWatch:
            #if canImport(HealthKit)
            startHealthKitQueries()
            enableBackgroundDelivery()
            #else
            startSimulationStreaming()
            #endif
        case .simulation:
            startSimulationStreaming()
        case .replay:
            log.biofeedback("Replay mode - use loadRecordedSession()")
        }
    }

    /// Stop streaming
    public func stopStreaming() {
        guard isStreaming else { return }
        isStreaming = false

        updateTimer?.cancel()
        updateTimer = nil

        #if canImport(HealthKit)
        stopHealthKitQueries()
        #endif

        stopReplayPlayback()
        log.biofeedback("Health streaming stopped")
    }

    // MARK: - HealthKit Queries

    #if canImport(HealthKit)
    private func startHealthKitQueries() {
        guard let store = healthStore else { return }

        // Heart rate query
        if let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            let predicate: NSPredicate? = dataSource == .appleWatch
                ? HKQuery.predicateForObjects(from: [HKDevice.local()])
                : nil

            let query = HKAnchoredObjectQuery(
                type: heartRateType,
                predicate: predicate,
                anchor: lastAnchor,
                limit: HKObjectQueryNoLimit
            ) { [weak self] _, samples, _, anchor, error in
                DispatchQueue.main.async {
                    self?.handleHeartRateSamples(samples: samples, anchor: anchor, error: error)
                }
            }

            query.updateHandler = { [weak self] _, samples, _, anchor, error in
                DispatchQueue.main.async {
                    self?.handleHeartRateSamples(samples: samples, anchor: anchor, error: error)
                }
            }

            store.execute(query)
            heartRateQuery = query
        }

        // HRV query
        if let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            let query = HKAnchoredObjectQuery(
                type: hrvType,
                predicate: nil,
                anchor: nil,
                limit: HKObjectQueryNoLimit
            ) { [weak self] _, samples, _, _, error in
                DispatchQueue.main.async {
                    self?.handleHRVSamples(samples: samples, error: error)
                }
            }

            query.updateHandler = { [weak self] _, samples, _, _, error in
                DispatchQueue.main.async {
                    self?.handleHRVSamples(samples: samples, error: error)
                }
            }

            store.execute(query)
            hrvQuery = query
        }

        log.biofeedback("HealthKit queries started")
    }

    private func stopHealthKitQueries() {
        if let query = heartRateQuery {
            healthStore?.stop(query)
        }
        if let query = hrvQuery {
            healthStore?.stop(query)
        }
        heartRateQuery = nil
        hrvQuery = nil
    }

    private func handleHeartRateSamples(samples: [HKSample]?, anchor: HKQueryAnchor?, error: Error?) {
        if let error = error {
            self.errorMessage = "Heart rate query error: \(error.localizedDescription)"
            return
        }

        guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else { return }
        lastAnchor = anchor

        if let latest = samples.last {
            let bpm = latest.quantity.doubleValue(for: HKUnit(from: "count/min"))
            self.heartRate = bpm
            self.heartData.heartRate = bpm
            self.heartData.timestamp = latest.endDate
            self.heartData.source = self.dataSource

            // Calculate RR interval and add to buffer
            let rrInterval = 60000.0 / bpm
            self.rrIntervalBuffer.append(rrInterval)
            self.heartData.rrIntervals = self.rrIntervalBuffer.toArray()

            // Calculate HRV metrics
            self.calculateHRVMetrics()

            // Calculate coherence
            self.calculateCoherence()

            // Notify
            self.notifyHeartUpdate()
            self.lastUpdateTime = Date()
        }
    }

    private func handleHRVSamples(samples: [HKSample]?, error: Error?) {
        if let error = error {
            self.errorMessage = "HRV query error: \(error.localizedDescription)"
            return
        }

        guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else { return }

        if let latest = samples.last {
            let sdnn = latest.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
            self.hrvSDNN = sdnn
            self.heartData.heartRateVariability = sdnn
        }
    }

    private func enableBackgroundDelivery() {
        guard let store = healthStore,
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else { return }

        store.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { success, error in
            if let error = error {
                log.biofeedback("Background delivery error: \(error.localizedDescription)", level: .warning)
            } else if success {
                log.biofeedback("Background delivery enabled")
            }
        }
    }
    #endif

    // MARK: - Simulation Streaming

    private func startSimulationStreaming() {
        updateTimer?.cancel()

        let timer = DispatchSource.makeTimerSource(flags: [], queue: updateQueue)
        timer.schedule(deadline: .now(), repeating: .seconds(1), leeway: .milliseconds(10))
        timer.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.simulateHealthUpdate()
            }
        }
        timer.resume()
        updateTimer = timer
    }

    private func simulateHealthUpdate() {
        let time = CFAbsoluteTimeGetCurrent()

        // Simulate heart rate with natural variation
        let baseHR = 70.0
        let variation = sin(time * 0.1) * 5.0 + sin(time * 0.3) * 3.0
        let noise = Double.random(in: -2...2)
        heartRate = baseHR + variation + noise
        heartData.heartRate = heartRate
        heartData.timestamp = Date()
        heartData.source = .simulation

        // Simulate RR intervals
        let rrInterval = 60000.0 / heartRate + Double.random(in: -20...20)
        rrIntervalBuffer.append(rrInterval)
        heartData.rrIntervals = rrIntervalBuffer.toArray()

        // Calculate HRV metrics
        calculateHRVMetrics()

        // Simulate respiratory data
        let breathCycle = sin(time * 0.5) * 0.5 + 0.5
        respiratoryData.breathPhase = breathCycle
        respiratoryData.breathingRate = 12.0 + sin(time * 0.02) * 2.0
        respiratoryData.breathDepth = 0.5 + sin(time * 0.5) * 0.3
        respiratoryData.timestamp = Date()
        breathingRate = respiratoryData.breathingRate

        // Calculate coherence
        calculateCoherence()

        // Notify
        notifyHeartUpdate()
        notifyRespiratoryUpdate()

        lastUpdateTime = Date()
        sampleRate = 1.0
    }

    // MARK: - HRV Calculations

    private func calculateHRVMetrics() {
        guard rrIntervalBuffer.hasMinimumSamples(10) else { return }

        let intervals = rrIntervalBuffer.toArray()
        let n = intervals.count

        // Mean RR
        let meanRR = intervals.reduce(0, +) / Double(n)

        // SDNN — direct loop avoids intermediate array allocation
        var varianceSum = 0.0
        for interval in intervals {
            let diff = interval - meanRR
            varianceSum += diff * diff
        }
        let variance = varianceSum / Double(n)
        hrvSDNN = sqrt(variance)
        heartData.heartRateVariability = hrvSDNN

        // RMSSD
        var sumSquaredDiffs = 0.0
        for i in 1..<n {
            let diff = intervals[i] - intervals[i-1]
            sumSquaredDiffs += diff * diff
        }
        heartData.rmssd = sqrt(sumSquaredDiffs / Double(n - 1))

        // pNN50
        var count50 = 0
        for i in 1..<n {
            if abs(intervals[i] - intervals[i-1]) > 50 {
                count50 += 1
            }
        }
        heartData.pnn50 = Double(count50) / Double(n - 1) * 100
    }

    // MARK: - HeartMath Coherence Algorithm

    private func calculateCoherence() {
        guard rrIntervalBuffer.hasMinimumSamples(30) else { return }

        let intervals = rrIntervalBuffer.toArray()

        // Detrend
        let detrended = detrend(intervals)

        // Apply Hamming window
        let windowed = applyHammingWindow(detrended)

        // FFT
        let fftSize = nextPowerOf2(windowed.count)
        let powerSpectrum = performFFT(windowed, fftSize: fftSize)

        // HeartMath coherence band: 0.04-0.26 Hz
        let samplingRate = 1.0
        let coherenceBandLow = 0.04
        let coherenceBandHigh = 0.26

        let binLow = Int(coherenceBandLow * Double(fftSize) / samplingRate)
        let binHigh = min(powerSpectrum.count - 1, Int(coherenceBandHigh * Double(fftSize) / samplingRate))

        guard binLow < binHigh, binHigh < powerSpectrum.count else { return }

        // Peak power in coherence band
        let coherenceBandPower = Array(powerSpectrum[binLow...binHigh])
        let peakPower = coherenceBandPower.max() ?? 0.0
        let totalPower = powerSpectrum.reduce(0.0, +)

        // Coherence ratio normalized to 0-1
        let coherenceRatio = totalPower > 0 ? peakPower / totalPower : 0.0
        let newCoherence = min(coherenceRatio * 5.0, 1.0)  // Scale to 0-1

        // Smooth
        coherence = coherence * 0.8 + newCoherence * 0.2
        heartData.coherenceScore = coherence

        // Update level
        let coherencePercent = coherence * 100
        if coherencePercent >= 60 {
            coherenceLevel = .high
        } else if coherencePercent >= 40 {
            coherenceLevel = .medium
        } else {
            coherenceLevel = .low
        }

        // Update history and trend
        coherenceBuffer.append(coherence)
        coherenceHistory = coherenceBuffer.toArray()
        updateCoherenceTrend()

        // Calculate breathing rate from RSA
        calculateBreathingRate()

        // Notify
        delegate?.healthKit(self, didChangeCoherence: coherence, trend: coherenceTrend)
        onCoherenceChange?(coherence, coherenceTrend)
    }

    private func detrend(_ data: [Double]) -> [Double] {
        let n = Double(data.count)
        let xSum = (0..<data.count).reduce(0.0) { $0 + Double($1) }
        let ySum = data.reduce(0.0, +)
        let xySum = data.enumerated().reduce(0.0) { $0 + Double($1.offset) * $1.element }
        let xxSum = (0..<data.count).reduce(0.0) { $0 + Double($1 * $1) }

        let slope = (n * xySum - xSum * ySum) / (n * xxSum - xSum * xSum)
        let intercept = (ySum - slope * xSum) / n

        return data.enumerated().map { index, value in
            value - (slope * Double(index) + intercept)
        }
    }

    private func applyHammingWindow(_ data: [Double]) -> [Double] {
        let n = data.count
        var windowed = [Double](repeating: 0, count: n)

        for i in 0..<n {
            let window = 0.54 - 0.46 * cos(2.0 * .pi * Double(i) / Double(n - 1))
            windowed[i] = data[i] * window
        }

        return windowed
    }

    private func performFFT(_ data: [Double], fftSize: Int) -> [Double] {
        var realParts = [Float](repeating: 0, count: fftSize)
        for i in 0..<min(data.count, fftSize) {
            realParts[i] = Float(data[i])
        }
        var imagParts = [Float](repeating: 0, count: fftSize)

        // Cache FFT setup
        if cachedFFTSize != fftSize {
            if let oldSetup = cachedFFTSetup {
                vDSP_DFT_DestroySetup(oldSetup)
            }
            cachedFFTSetup = vDSP_DFT_zop_CreateSetup(
                nil,
                vDSP_Length(fftSize),
                vDSP_DFT_Direction.FORWARD
            )
            cachedFFTSize = fftSize
        }

        guard let fftSetup = cachedFFTSetup else { return [] }

        var realIn = realParts
        var imagIn = imagParts
        vDSP_DFT_Execute(fftSetup, &realIn, &imagIn, &realParts, &imagParts)

        var powerSpectrum = [Float](repeating: 0, count: fftSize / 2)
        var splitComplex = DSPSplitComplex(realp: &realParts, imagp: &imagParts)
        vDSP_zvmags(&splitComplex, 1, &powerSpectrum, 1, vDSP_Length(fftSize / 2))

        return powerSpectrum.map { Double($0) }
    }

    private func nextPowerOf2(_ n: Int) -> Int {
        var power = 1
        while power < n {
            power *= 2
        }
        return power
    }

    private func updateCoherenceTrend() {
        guard coherenceBuffer.count >= 10 else {
            coherenceTrend = .stable
            return
        }

        let allValues = coherenceBuffer.toArray()
        let recent = Array(allValues.suffix(10))
        let older = Array(allValues.prefix(10))

        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let olderAvg = older.reduce(0, +) / Double(older.count)
        let diff = recentAvg - olderAvg

        if diff > 0.05 {
            coherenceTrend = .increasing
        } else if diff < -0.05 {
            coherenceTrend = .decreasing
        } else {
            coherenceTrend = .stable
        }
    }

    // MARK: - Breathing Rate Estimation

    private func calculateBreathingRate() {
        guard rrIntervalBuffer.hasMinimumSamples(30) else {
            breathingRate = 12.0
            return
        }

        let intervals = rrIntervalBuffer.toArray()
        let detrended = detrend(intervals)
        let windowed = applyHammingWindow(detrended)
        let fftSize = nextPowerOf2(windowed.count)
        let powerSpectrum = performFFT(windowed, fftSize: fftSize)

        guard !powerSpectrum.isEmpty else {
            breathingRate = 12.0
            return
        }

        // Respiratory frequency band: 0.15-0.4 Hz (9-24 breaths/min)
        let samplingRate = 1.0
        let respiratoryBandLow = 0.15
        let respiratoryBandHigh = 0.4

        let binLow = max(1, Int(respiratoryBandLow * Double(fftSize) / samplingRate))
        let binHigh = min(powerSpectrum.count - 1, Int(respiratoryBandHigh * Double(fftSize) / samplingRate))

        guard binLow < binHigh else {
            breathingRate = 12.0
            return
        }

        var maxPower: Double = 0.0
        var peakBin = binLow

        for i in binLow...binHigh {
            if powerSpectrum[i] > maxPower {
                maxPower = powerSpectrum[i]
                peakBin = i
            }
        }

        let peakFrequency = Double(peakBin) * samplingRate / Double(fftSize)
        breathingRate = max(6.0, min(30.0, peakFrequency * 60.0))
        respiratoryData.breathingRate = breathingRate
    }

    // MARK: - Export/Import

    /// Export RR intervals to file
    public func exportRRIntervals(to url: URL) throws {
        let data = try JSONEncoder().encode(rrIntervalBuffer.toArray())
        try data.write(to: url)
        log.biofeedback("Exported \(rrIntervalBuffer.count) RR intervals")
    }

    /// Import RR intervals from file
    public func importRRIntervals(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let intervals = try JSONDecoder().decode([Double].self, from: data)
        rrIntervalBuffer.clear()
        for interval in intervals {
            rrIntervalBuffer.append(interval)
        }
        log.biofeedback("Imported \(intervals.count) RR intervals")
    }

    /// Load recorded session for replay
    public func loadRecordedSession(from url: URL, playbackSpeed: Double = 1.0) {
        do {
            let data = try Data(contentsOf: url)
            replayData = try JSONDecoder().decode([Double].self, from: data)
            dataSource = .replay
            startReplayPlayback(speed: playbackSpeed)
            log.biofeedback("Loaded session for replay at \(playbackSpeed)x")
        } catch {
            errorMessage = "Failed to load session: \(error.localizedDescription)"
            log.biofeedback("Replay load error: \(error)", level: .error)
        }
    }

    private func startReplayPlayback(speed: Double) {
        stopReplayPlayback()
        replayIndex = 0
        isStreaming = true

        let interval = 1.0 / speed
        replayTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.playNextReplayFrame()
            }
        }
    }

    private func stopReplayPlayback() {
        replayTimer?.invalidate()
        replayTimer = nil
    }

    private func playNextReplayFrame() {
        guard replayIndex < replayData.count else {
            stopReplayPlayback()
            isStreaming = false
            log.biofeedback("Replay complete")
            return
        }

        let rrInterval = replayData[replayIndex]
        rrIntervalBuffer.append(rrInterval)

        heartRate = 60000.0 / rrInterval
        heartData.heartRate = heartRate
        heartData.rrIntervals = rrIntervalBuffer.toArray()
        heartData.timestamp = Date()
        heartData.source = .replay

        calculateHRVMetrics()
        calculateCoherence()
        notifyHeartUpdate()

        replayIndex += 1
    }

    // MARK: - Historical Queries

    #if canImport(HealthKit)
    /// Query historical heart rate data
    public func queryHeartRateHistory(
        startDate: Date,
        endDate: Date
    ) async throws -> [HKQuantitySample] {
        guard let store = healthStore,
              let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw NSError(domain: "UnifiedHealthKitEngine", code: -1, userInfo: [NSLocalizedDescriptionKey: "HealthKit not available"])
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
                }
            }
            store.execute(query)
        }
    }
    #endif

    // MARK: - Cleanup

    /// Clear local data buffer
    public func clearLocalData() {
        rrIntervalBuffer.clear()
        coherenceBuffer.clear()
        coherenceHistory.removeAll()
        log.biofeedback("Local data cleared")
    }

    // MARK: - Notifications

    private func notifyHeartUpdate() {
        delegate?.healthKit(self, didUpdateHeart: heartData)
        onHeartUpdate?(heartData)
    }

    private func notifyRespiratoryUpdate() {
        delegate?.healthKit(self, didUpdateRespiratory: respiratoryData)
        onRespiratoryUpdate?(respiratoryData)
    }
}

// MARK: - Convenience Extensions

extension UnifiedHealthKitEngine {

    /// Quick start with authorization and streaming
    public func quickStart() async -> Bool {
        do {
            try await requestAuthorization()
            startStreaming()
            return true
        } catch {
            log.biofeedback("Quick start failed: \(error)", level: .warning)
            // Fall back to simulation
            dataSource = .simulation
            startStreaming()
            return true
        }
    }

    /// Get coherence as percentage (0-100)
    public var coherencePercent: Int {
        Int(coherence * 100)
    }

    /// Check if currently using real device data
    public var isUsingRealData: Bool {
        dataSource == .realDevice || dataSource == .appleWatch
    }
}

// MARK: - SwiftUI Views

/// Unified HealthKit streaming view
public struct UnifiedHealthKitView: View {
    @ObservedObject var engine: UnifiedHealthKitEngine
    @State private var showDisclaimer = true

    public init(engine: UnifiedHealthKitEngine = .shared) {
        _engine = ObservedObject(wrappedValue: engine)
    }

    public var body: some View {
        ZStack {
            mainContent

            if showDisclaimer {
                HealthDisclaimerView(showDisclaimer: $showDisclaimer)
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 16) {
            // Status header
            HStack {
                Circle()
                    .fill(engine.isStreaming ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(engine.isStreaming ? "Streaming" : "Stopped")
                    .font(.caption)
                Text("(\(engine.dataSource.rawValue))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if engine.isStreaming {
                    Text("\(engine.sampleRate, specifier: "%.1f") Hz")
                        .font(.caption.monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }

            // Heart metrics
            VStack(spacing: 10) {
                HealthMetricRow(label: "Heart Rate", value: "\(Int(engine.heartRate))", unit: "BPM", color: .red)
                HealthMetricRow(label: "HRV (SDNN)", value: "\(Int(engine.hrvSDNN))", unit: "ms", color: .orange)
                HealthMetricRow(label: "Coherence", value: "\(engine.coherencePercent)", unit: "%", color: coherenceColor)

                // Coherence trend
                HStack {
                    Text("Trend:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Image(systemName: trendIcon)
                        .foregroundColor(trendColor)
                    Text(engine.coherenceTrend.rawValue.capitalized)
                        .font(.caption)
                }
            }

            // Coherence graph
            CoherenceHistoryGraph(history: engine.coherenceHistory)
                .frame(height: 80)

            // Breathing
            VStack(spacing: 6) {
                Text("Breathing")
                    .font(.caption)
                    .foregroundColor(.secondary)
                BreathPhaseIndicator(phase: engine.respiratoryData.breathPhase)
                    .frame(height: 30)
                Text("\(Int(engine.breathingRate)) breaths/min")
                    .font(.caption.monospacedDigit())
            }

            // Controls
            Button {
                if engine.isStreaming {
                    engine.stopStreaming()
                } else {
                    engine.startStreaming()
                }
            } label: {
                Label(engine.isStreaming ? "Stop" : "Start",
                      systemImage: engine.isStreaming ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(engine.isStreaming ? .red : .green)

            // Disclaimer
            Text("For creative/informational purposes only. Not a medical device.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var coherenceColor: Color {
        switch engine.coherenceLevel {
        case .high: return .green
        case .medium: return .yellow
        case .low: return .orange
        }
    }

    private var trendIcon: String {
        switch engine.coherenceTrend {
        case .increasing: return "arrow.up.right"
        case .decreasing: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    private var trendColor: Color {
        switch engine.coherenceTrend {
        case .increasing: return .green
        case .decreasing: return .orange
        case .stable: return .gray
        }
    }
}

struct HealthMetricRow: View {
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
            Spacer()
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(unit)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct CoherenceHistoryGraph: View {
    let history: [Double]

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard history.count > 1 else { return }

                let stepX = geometry.size.width / CGFloat(history.count - 1)

                for (index, value) in history.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = geometry.size.height * (1 - CGFloat(value))

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.cyan, lineWidth: 2)
        }
        .background(Color.cyan.opacity(0.1))
        .cornerRadius(8)
    }
}

struct BreathPhaseIndicator: View {
    let phase: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.green.opacity(0.2))

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.green.opacity(0.5))
                    .frame(width: geometry.size.width * phase)
                    .animation(.easeInOut(duration: 0.5), value: phase)
            }
        }
    }
}

struct HealthDisclaimerView: View {
    @Binding var showDisclaimer: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.red)

                Text("Health Data Disclaimer")
                    .font(.title2.bold())

                Text("This biometric feature is for CREATIVE and INFORMATIONAL purposes only.\n\nNOT a medical device. NOT for health monitoring or medical decisions.\n\nReadings may not be accurate. Consult healthcare providers for health concerns.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()

                Button("I Understand") {
                    showDisclaimer = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(30)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    UnifiedHealthKitView()
}
#endif
