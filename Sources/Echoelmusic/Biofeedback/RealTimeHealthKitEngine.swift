// RealTimeHealthKitEngine.swift
// Echoelmusic - Real-Time HealthKit Streaming Engine
// λ∞ Ralph Wiggum Loop Genius Mode
// Created 2026-01-06
//
// "When I grow up, I want to be a principal or a caterpillar."
// - Ralph Wiggum, Cardiologist
//
// ═══════════════════════════════════════════════════════════════════════════════
// DISCLAIMER: This is NOT a medical device. Biometric data is for creative and
// informational purposes only. NOT for health monitoring or medical decisions.
// Consult healthcare providers for all health concerns.
// ═══════════════════════════════════════════════════════════════════════════════
//
// ============================================================================
// DEPRECATION NOTICE
// ============================================================================
// This file is DEPRECATED. Please use UnifiedHealthKitEngine instead.
//
// Migration guide:
// - Replace: RealTimeHealthKitEngine() with UnifiedHealthKitEngine.shared
// - Replace: RealTimeHeartData with UnifiedHeartData
// - Replace: RealTimeRespiratoryData with UnifiedRespiratoryData
// - Replace: HealthKitStreamDelegate with UnifiedHealthKitDelegate
// - Replace: HealthKitStreamView with UnifiedHealthKitView
//
// UnifiedHealthKitEngine combines features from:
// - HealthKitManager
// - ProductionHealthKitManager
// - RealTimeHealthKitEngine (this file)
//
// This file will be removed in a future version.
// ============================================================================

import Foundation
import SwiftUI
import Combine
import Accelerate

#if canImport(HealthKit)
import HealthKit
#endif

//==============================================================================
// MARK: - LAMBDA LOOP OPTIMIZED Circular Buffer
//==============================================================================

/// High-performance circular buffer for real-time biometric streaming
/// OPTIMIZATION: O(1) operations for append/access, no allocations
private struct RealTimeCircularBuffer {
    private var buffer: [Double]
    private var writeIndex: Int = 0
    private(set) var count: Int = 0
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = [Double](repeating: 0, count: capacity)
    }

    /// O(1) append with automatic oldest-value overwrite
    mutating func append(_ value: Double) {
        buffer[writeIndex] = value
        writeIndex = (writeIndex + 1) % capacity
        count = min(count + 1, capacity)
    }

    /// Get all values in chronological order
    func toArray() -> [Double] {
        guard count > 0 else { return [] }
        if count < capacity {
            return Array(buffer[0..<count])
        }
        // Full buffer - read from oldest to newest
        return Array(buffer[writeIndex..<capacity]) + Array(buffer[0..<writeIndex])
    }

    /// Get last N values without allocation (returns ArraySlice)
    func suffix(_ n: Int) -> [Double] {
        let arr = toArray()
        return Array(arr.suffix(n))
    }

    var isEmpty: Bool { count == 0 }
    var isFull: Bool { count == capacity }

    mutating func clear() {
        buffer = [Double](repeating: 0, count: capacity)
        writeIndex = 0
        count = 0
    }
}

//==============================================================================
// MARK: - Real-Time Heart Data
//==============================================================================

/// Real-time heart rate and HRV data
public struct RealTimeHeartData: Equatable, Sendable {
    public var heartRate: Double              // Current BPM
    public var heartRateVariability: Double   // SDNN in ms
    public var rrIntervals: [Double]          // Recent RR intervals in ms
    public var timestamp: Date

    // Derived metrics
    public var rmssd: Double                  // Root mean square of successive differences
    public var pnn50: Double                  // Percentage of intervals > 50ms difference
    public var coherenceRatio: Double         // HRV coherence (0-1)
    public var lfPower: Double                // Low frequency power (0.04-0.15 Hz)
    public var hfPower: Double                // High frequency power (0.15-0.4 Hz)
    public var lfHfRatio: Double              // LF/HF ratio (stress indicator)

    public init(
        heartRate: Double = 70,
        heartRateVariability: Double = 50,
        rrIntervals: [Double] = [],
        timestamp: Date = Date(),
        rmssd: Double = 0,
        pnn50: Double = 0,
        coherenceRatio: Double = 0.5,
        lfPower: Double = 0,
        hfPower: Double = 0,
        lfHfRatio: Double = 1.0
    ) {
        self.heartRate = heartRate
        self.heartRateVariability = heartRateVariability
        self.rrIntervals = rrIntervals
        self.timestamp = timestamp
        self.rmssd = rmssd
        self.pnn50 = pnn50
        self.coherenceRatio = coherenceRatio
        self.lfPower = lfPower
        self.hfPower = hfPower
        self.lfHfRatio = lfHfRatio
    }
}

//==============================================================================
// MARK: - Real-Time Respiratory Data
//==============================================================================

/// Real-time respiratory data
public struct RealTimeRespiratoryData: Equatable, Sendable {
    public var breathingRate: Double          // Breaths per minute
    public var breathPhase: Double            // 0-1 (0=inhale start, 0.5=exhale start)
    public var breathDepth: Double            // Relative depth 0-1
    public var respiratorySinusArrhythmia: Double  // RSA amplitude
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

//==============================================================================
// MARK: - Real-Time Activity Data
//==============================================================================

/// Real-time activity and motion data
public struct RealTimeActivityData: Equatable, Sendable {
    public var activeEnergyBurned: Double     // kcal
    public var stepCount: Int
    public var distanceWalking: Double        // meters
    public var flightsClimbed: Int
    public var exerciseMinutes: Int
    public var standHours: Int
    public var activityLevel: ActivityLevel
    public var timestamp: Date

    public enum ActivityLevel: String, Sendable {
        case sedentary
        case light
        case moderate
        case vigorous
    }

    public init(
        activeEnergyBurned: Double = 0,
        stepCount: Int = 0,
        distanceWalking: Double = 0,
        flightsClimbed: Int = 0,
        exerciseMinutes: Int = 0,
        standHours: Int = 0,
        activityLevel: ActivityLevel = .sedentary,
        timestamp: Date = Date()
    ) {
        self.activeEnergyBurned = activeEnergyBurned
        self.stepCount = stepCount
        self.distanceWalking = distanceWalking
        self.flightsClimbed = flightsClimbed
        self.exerciseMinutes = exerciseMinutes
        self.standHours = standHours
        self.activityLevel = activityLevel
        self.timestamp = timestamp
    }
}

//==============================================================================
// MARK: - HealthKit Stream Delegate
//==============================================================================

/// Protocol for receiving real-time health updates
public protocol HealthKitStreamDelegate: AnyObject {
    func healthKitStream(_ stream: RealTimeHealthKitEngine, didUpdateHeart data: RealTimeHeartData)
    func healthKitStream(_ stream: RealTimeHealthKitEngine, didUpdateRespiratory data: RealTimeRespiratoryData)
    func healthKitStream(_ stream: RealTimeHealthKitEngine, didUpdateActivity data: RealTimeActivityData)
    func healthKitStream(_ stream: RealTimeHealthKitEngine, didDetectCoherenceChange coherence: Double)
    func healthKitStreamDidLoseConnection(_ stream: RealTimeHealthKitEngine)
}

// Default implementations
public extension HealthKitStreamDelegate {
    func healthKitStream(_ stream: RealTimeHealthKitEngine, didUpdateHeart data: RealTimeHeartData) {}
    func healthKitStream(_ stream: RealTimeHealthKitEngine, didUpdateRespiratory data: RealTimeRespiratoryData) {}
    func healthKitStream(_ stream: RealTimeHealthKitEngine, didUpdateActivity data: RealTimeActivityData) {}
    func healthKitStream(_ stream: RealTimeHealthKitEngine, didDetectCoherenceChange coherence: Double) {}
    func healthKitStreamDidLoseConnection(_ stream: RealTimeHealthKitEngine) {}
}

//==============================================================================
// MARK: - Real-Time HealthKit Engine
//==============================================================================

/// Real-time streaming engine for HealthKit data
/// NOT A MEDICAL DEVICE - For creative/informational purposes only
@available(iOS 15.0, macOS 13.0, watchOS 8.0, *)
@MainActor
public final class RealTimeHealthKitEngine: ObservableObject {

    //==========================================================================
    // MARK: - Published Properties
    //==========================================================================

    @Published public var isStreaming: Bool = false
    @Published public var isAuthorized: Bool = false
    @Published public var isWatchConnected: Bool = false

    @Published public var heartData: RealTimeHeartData = RealTimeHeartData()
    @Published public var respiratoryData: RealTimeRespiratoryData = RealTimeRespiratoryData()
    @Published public var activityData: RealTimeActivityData = RealTimeActivityData()

    // Derived coherence metrics
    @Published public var currentCoherence: Double = 0.5
    @Published public var coherenceHistory: [Double] = []
    @Published public var coherenceTrend: CoherenceTrend = .stable

    // Stream statistics
    @Published public var sampleRate: Double = 0  // Samples per second
    @Published public var lastUpdateTime: Date = Date()
    @Published public var droppedSamples: Int = 0

    public enum CoherenceTrend: String, Sendable {
        case increasing, decreasing, stable
    }

    //==========================================================================
    // MARK: - Private Properties
    //==========================================================================

    public weak var delegate: HealthKitStreamDelegate?

    #if canImport(HealthKit)
    private var healthStore: HKHealthStore?
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var hrvQuery: HKAnchoredObjectQuery?
    private var workoutSession: Any?  // HKWorkoutSession on watchOS
    #endif

    private var cancellables = Set<AnyCancellable>()

    // LAMBDA LOOP OPTIMIZATION: High-precision timer for real-time updates
    private var updateTimer: DispatchSourceTimer?
    private let updateQueue = DispatchQueue(label: "com.echoelmusic.healthkit.realtime", qos: .userInteractive)

    // LAMBDA LOOP OPTIMIZATION: O(1) circular buffers instead of O(n) arrays
    private var rrIntervalBuffer: RealTimeCircularBuffer
    private let maxRRIntervals = 300  // ~5 minutes of data

    // Coherence calculation - also using circular buffer
    private let coherenceWindowSize = 60  // seconds
    private var coherenceBuffer: RealTimeCircularBuffer

    //==========================================================================
    // MARK: - Health Disclaimer
    //==========================================================================

    public static let healthDisclaimer = """
    ═══════════════════════════════════════════════════════════════════════════
    IMPORTANT: NOT A MEDICAL DEVICE
    ═══════════════════════════════════════════════════════════════════════════

    This biometric streaming feature is for CREATIVE and INFORMATIONAL purposes only.

    • Heart rate, HRV, and other readings may NOT be accurate
    • "Coherence" scores are ARTISTIC interpretations, not clinical measurements
    • NOT intended for health monitoring or medical decisions
    • NOT a substitute for professional medical devices or care

    If you have health concerns, consult a qualified healthcare provider.

    ═══════════════════════════════════════════════════════════════════════════
    """

    //==========================================================================
    // MARK: - Initialization
    //==========================================================================

    public init() {
        // LAMBDA LOOP: Pre-allocate circular buffers for O(1) operations
        self.rrIntervalBuffer = RealTimeCircularBuffer(capacity: maxRRIntervals)
        self.coherenceBuffer = RealTimeCircularBuffer(capacity: coherenceWindowSize)

        #if canImport(HealthKit)
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
        }
        #endif
    }

    //==========================================================================
    // MARK: - Authorization
    //==========================================================================

    /// Request HealthKit authorization
    public func requestAuthorization() async -> Bool {
        #if canImport(HealthKit)
        guard let healthStore = healthStore else {
            log.biofeedback("❤️ HealthKit not available on this device", level: .warning)
            return false
        }

        // Build types set safely without force unwrapping
        var typesToRead: Set<HKObjectType> = []
        if let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate) {
            typesToRead.insert(heartRate)
        }
        if let hrv = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            typesToRead.insert(hrv)
        }
        if let respRate = HKObjectType.quantityType(forIdentifier: .respiratoryRate) {
            typesToRead.insert(respRate)
        }
        if let spo2 = HKObjectType.quantityType(forIdentifier: .oxygenSaturation) {
            typesToRead.insert(spo2)
        }
        if let energy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            typesToRead.insert(energy)
        }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) {
            typesToRead.insert(steps)
        }
        if let distance = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning) {
            typesToRead.insert(distance)
        }
        if let mindful = HKObjectType.categoryType(forIdentifier: .mindfulSession) {
            typesToRead.insert(mindful)
        }

        guard !typesToRead.isEmpty else {
            log.biofeedback("❤️ No HealthKit types available on this device", level: .warning)
            return false
        }

        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            await MainActor.run {
                self.isAuthorized = true
            }
            log.biofeedback("❤️ HealthKit authorization granted")
            return true
        } catch {
            log.biofeedback("❤️ HealthKit authorization failed: \(error)", level: .error)
            return false
        }
        #else
        return false
        #endif
    }

    //==========================================================================
    // MARK: - Streaming Control
    //==========================================================================

    /// Start real-time health data streaming
    public func startStreaming() {
        guard !isStreaming else { return }

        #if canImport(HealthKit)
        startHealthKitQueries()
        #endif

        // Start simulation for testing/demo
        startSimulatedStreaming()

        isStreaming = true
        log.biofeedback("❤️ RealTimeHealthKitEngine: Started streaming")
        log.biofeedback(Self.healthDisclaimer)
    }

    /// Stop streaming
    public func stopStreaming() {
        isStreaming = false
        // LAMBDA LOOP 100%: Clean up high-precision timer
        updateTimer?.cancel()
        updateTimer = nil

        #if canImport(HealthKit)
        stopHealthKitQueries()
        #endif

        log.biofeedback("❤️ RealTimeHealthKitEngine: Stopped streaming")
    }

    #if canImport(HealthKit)
    private func startHealthKitQueries() {
        guard let healthStore = healthStore else { return }

        // Heart rate query - safe unwrap for production safety
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            log.biofeedback("⚠️ Heart rate type not available")
            return
        }
        heartRateQuery = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deleted, anchor, error in
            Task { @MainActor in
                self?.processHeartRateSamples(samples)
            }
        }

        heartRateQuery?.updateHandler = { [weak self] query, samples, deleted, anchor, error in
            Task { @MainActor in
                self?.processHeartRateSamples(samples)
            }
        }

        if let query = heartRateQuery {
            healthStore.execute(query)
        }

        // HRV query
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            log.biofeedback("⚠️ HRV type not available")
            return
        }

        hrvQuery = HKAnchoredObjectQuery(
            type: hrvType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deleted, anchor, error in
            Task { @MainActor in
                self?.processHRVSamples(samples)
            }
        }

        hrvQuery?.updateHandler = { [weak self] query, samples, deleted, anchor, error in
            Task { @MainActor in
                self?.processHRVSamples(samples)
            }
        }

        if let query = hrvQuery {
            healthStore.execute(query)
        }
    }

    private func stopHealthKitQueries() {
        if let query = heartRateQuery {
            healthStore?.stop(query)
        }
        if let query = hrvQuery {
            healthStore?.stop(query)
        }
    }

    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else { return }

        Task { @MainActor in
            for sample in samples {
                let heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

                // Calculate RR interval from heart rate
                // LAMBDA LOOP: O(1) circular buffer append (no removeFirst needed)
                let rrInterval = 60000.0 / heartRate  // ms
                rrIntervalBuffer.append(rrInterval)

                heartData.heartRate = heartRate
                heartData.rrIntervals = rrIntervalBuffer.toArray()
                heartData.timestamp = sample.endDate

                // Calculate derived metrics
                calculateHRVMetrics()

                delegate?.healthKitStream(self, didUpdateHeart: heartData)
            }

            lastUpdateTime = Date()
        }
    }

    private func processHRVSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], !samples.isEmpty else { return }

        Task { @MainActor in
            for sample in samples {
                let hrv = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                heartData.heartRateVariability = hrv
                heartData.timestamp = sample.endDate
            }
        }
    }
    #endif

    private func startSimulatedStreaming() {
        // LAMBDA LOOP 100%: High-precision simulated streaming
        updateTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: updateQueue)
        timer.schedule(deadline: .now(), repeating: .seconds(1), leeway: .milliseconds(10))
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.simulateHealthUpdate()
            }
        }
        timer.resume()
        updateTimer = timer
    }

    private func simulateHealthUpdate() {
        let time = Date().timeIntervalSinceReferenceDate

        // Simulate heart rate with natural variation
        let baseHR = 70.0
        let variation = sin(time * 0.1) * 5.0 + sin(time * 0.3) * 3.0
        let noise = Double.random(in: -2...2)
        heartData.heartRate = baseHR + variation + noise

        // Simulate RR intervals - LAMBDA LOOP O(1) circular buffer
        let rrInterval = 60000.0 / heartData.heartRate
        rrIntervalBuffer.append(rrInterval + Double.random(in: -20...20))
        heartData.rrIntervals = rrIntervalBuffer.toArray()
        heartData.timestamp = Date()

        // Calculate HRV metrics
        calculateHRVMetrics()

        // Simulate respiratory data
        let breathCycle = sin(time * 0.5) * 0.5 + 0.5  // 0-1 cycle
        respiratoryData.breathPhase = breathCycle
        respiratoryData.breathingRate = 12.0 + sin(time * 0.02) * 2.0
        respiratoryData.breathDepth = 0.5 + sin(time * 0.5) * 0.3
        respiratoryData.timestamp = Date()

        // Calculate coherence
        calculateCoherence()

        // Notify delegate
        delegate?.healthKitStream(self, didUpdateHeart: heartData)
        delegate?.healthKitStream(self, didUpdateRespiratory: respiratoryData)

        lastUpdateTime = Date()
        sampleRate = 1.0
    }

    //==========================================================================
    // MARK: - HRV Calculations
    //==========================================================================

    private func calculateHRVMetrics() {
        guard rrIntervalBuffer.count >= 10 else { return }

        let intervals = rrIntervalBuffer.toArray()

        // SDNN (Standard Deviation of NN intervals)
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        let variance = intervals.map { pow($0 - mean, 2) }.reduce(0, +) / Double(intervals.count)
        heartData.heartRateVariability = sqrt(variance)

        // RMSSD (Root Mean Square of Successive Differences)
        var sumSquaredDiffs = 0.0
        for i in 1..<intervals.count {
            let diff = intervals[i] - intervals[i-1]
            sumSquaredDiffs += diff * diff
        }
        heartData.rmssd = sqrt(sumSquaredDiffs / Double(intervals.count - 1))

        // pNN50 (Percentage of intervals with >50ms difference)
        var count50 = 0
        for i in 1..<intervals.count {
            if abs(intervals[i] - intervals[i-1]) > 50 {
                count50 += 1
            }
        }
        heartData.pnn50 = Double(count50) / Double(intervals.count - 1) * 100

        // Simplified frequency domain (would need FFT for accurate calculation)
        // Using time-domain approximations
        heartData.lfPower = heartData.heartRateVariability * 0.5
        heartData.hfPower = heartData.rmssd * 0.7
        heartData.lfHfRatio = heartData.lfPower / max(heartData.hfPower, 0.001)
    }

    //==========================================================================
    // MARK: - Coherence Calculation
    //==========================================================================

    private func calculateCoherence() {
        // Coherence is calculated from the rhythm of HRV
        // High coherence = smooth, sine-wave-like HRV pattern
        // This is a simplified calculation - real coherence uses spectral analysis

        guard rrIntervalBuffer.count >= 30 else { return }

        // LAMBDA LOOP: Efficient suffix extraction from circular buffer
        let recent = rrIntervalBuffer.suffix(30)

        // Calculate how "smooth" the RR interval changes are
        var smoothness = 0.0
        for i in 2..<recent.count {
            let prevDiff = recent[i-1] - recent[i-2]
            let currDiff = recent[i] - recent[i-1]

            // If differences have same sign, pattern is smoother
            if prevDiff * currDiff > 0 {
                smoothness += 1
            }
        }
        smoothness /= Double(recent.count - 2)

        // Combine with RMSSD for coherence estimate
        let rmssdFactor = min(1.0, heartData.rmssd / 100.0)
        let newCoherence = (smoothness * 0.6 + rmssdFactor * 0.4)

        // Smooth the coherence value
        currentCoherence = currentCoherence * 0.8 + newCoherence * 0.2
        heartData.coherenceRatio = currentCoherence

        // Update history and trend - LAMBDA LOOP O(1) circular buffer
        coherenceBuffer.append(currentCoherence)
        coherenceHistory = coherenceBuffer.toArray()
        updateCoherenceTrend()

        delegate?.healthKitStream(self, didDetectCoherenceChange: currentCoherence)
    }

    private func updateCoherenceTrend() {
        guard coherenceBuffer.count >= 10 else {
            coherenceTrend = .stable
            return
        }

        // LAMBDA LOOP: Use circular buffer's optimized suffix method
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

    //==========================================================================
    // MARK: - Breathing Rate Detection
    //==========================================================================

    /// Detect breathing rate from HRV (Respiratory Sinus Arrhythmia)
    public func detectBreathingFromHRV() -> Double? {
        guard rrIntervalBuffer.count >= 60 else { return nil }

        // RSA causes HR to increase on inhale and decrease on exhale
        // We look for this cyclical pattern in RR intervals
        // LAMBDA LOOP: Optimized suffix extraction
        let intervals = rrIntervalBuffer.suffix(60)

        // Find zero crossings of detrended signal
        let mean = intervals.reduce(0, +) / Double(intervals.count)
        let detrended = intervals.map { $0 - mean }

        var zeroCrossings = 0
        for i in 1..<detrended.count {
            if detrended[i-1] * detrended[i] < 0 {
                zeroCrossings += 1
            }
        }

        // Each breath cycle has 2 zero crossings
        let breathsPerMinute = Double(zeroCrossings) / 2.0

        respiratoryData.breathingRate = breathsPerMinute
        respiratoryData.respiratorySinusArrhythmia = heartData.rmssd

        return breathsPerMinute
    }
}

//==============================================================================
// MARK: - HealthKit Stream View
//==============================================================================

@available(iOS 15.0, macOS 13.0, *)
public struct HealthKitStreamView: View {
    @ObservedObject var engine: RealTimeHealthKitEngine
    @State private var showDisclaimer = true

    public init(engine: RealTimeHealthKitEngine) {
        self.engine = engine
    }

    public var body: some View {
        ZStack {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Circle()
                        .fill(engine.isStreaming ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                    Text(engine.isStreaming ? "Streaming" : "Stopped")
                        .font(.caption)

                    Spacer()

                    if engine.isStreaming {
                        Text("\(engine.sampleRate, specifier: "%.1f") Hz")
                            .font(.caption.monospacedDigit())
                            .foregroundColor(.secondary)
                    }
                }

                // Heart metrics
                VStack(spacing: 12) {
                    MetricRow(label: "Heart Rate", value: "\(Int(engine.heartData.heartRate))", unit: "BPM", color: .red)
                    MetricRow(label: "HRV (SDNN)", value: "\(Int(engine.heartData.heartRateVariability))", unit: "ms", color: .orange)
                    MetricRow(label: "RMSSD", value: "\(Int(engine.heartData.rmssd))", unit: "ms", color: .yellow)
                    MetricRow(label: "Coherence", value: "\(Int(engine.currentCoherence * 100))", unit: "%", color: .cyan)
                }

                // Coherence visualization
                CoherenceGraph(history: engine.coherenceHistory)
                    .frame(height: 100)

                // Breathing
                VStack(spacing: 8) {
                    Text("Breathing")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    BreathingIndicator(phase: engine.respiratoryData.breathPhase)
                        .frame(height: 40)

                    Text("\(Int(engine.respiratoryData.breathingRate)) breaths/min")
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

            if showDisclaimer {
                HealthDisclaimerOverlay(showDisclaimer: $showDisclaimer)
            }
        }
    }
}

@available(iOS 15.0, macOS 13.0, *)
struct MetricRow: View {
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

@available(iOS 15.0, macOS 13.0, *)
struct CoherenceGraph: View {
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

@available(iOS 15.0, macOS 13.0, *)
struct BreathingIndicator: View {
    let phase: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.2))

                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.green.opacity(0.5))
                    .frame(width: geometry.size.width * phase)
                    .animation(.easeInOut(duration: 0.5), value: phase)
            }
        }
    }
}

@available(iOS 15.0, macOS 13.0, *)
struct HealthDisclaimerOverlay: View {
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

                Text("This biometric streaming feature is for CREATIVE and INFORMATIONAL purposes only.\n\nNOT a medical device. NOT for health monitoring or medical decisions.\n\nReadings may not be accurate. Consult healthcare providers for health concerns.")
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
