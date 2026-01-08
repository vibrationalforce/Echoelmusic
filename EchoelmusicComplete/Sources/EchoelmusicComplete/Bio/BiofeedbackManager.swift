// BiofeedbackManager.swift
// Complete HealthKit integration with simulation fallback

import Foundation
import Combine

#if canImport(HealthKit)
import HealthKit
#endif

// MARK: - Biofeedback Manager

@MainActor
public final class BiofeedbackManager: ObservableObject {
    // MARK: - Published Properties

    @Published public var currentData: BiometricData = BiometricData()
    @Published public var isMonitoring: Bool = false
    @Published public var isAuthorized: Bool = false
    @Published public var isSimulating: Bool = false
    @Published public var errorMessage: String?

    // MARK: - Callbacks

    public var onDataUpdate: ((BiometricData) -> Void)?

    // MARK: - Private Properties

    #if canImport(HealthKit)
    private var healthStore: HKHealthStore?
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var hrvQuery: HKAnchoredObjectQuery?
    #endif

    private var simulationTimer: Timer?
    private var rrIntervalBuffer: [Double] = []
    private let coherenceCalculator = CoherenceCalculator()

    // Simulation state
    private var simPhase: Double = 0
    private var simBreathPhase: Double = 0

    // MARK: - Initialization

    public init() {
        setupHealthKit()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - HealthKit Setup

    private func setupHealthKit() {
        #if canImport(HealthKit)
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
            isSimulating = false
        } else {
            isSimulating = true
        }
        #else
        isSimulating = true
        #endif
    }

    // MARK: - Authorization

    public func requestAuthorization() async -> Bool {
        #if canImport(HealthKit)
        guard let healthStore = healthStore else {
            isSimulating = true
            isAuthorized = true
            return true
        }

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!
        ]

        do {
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
            isAuthorized = true
            return true
        } catch {
            errorMessage = "HealthKit authorization failed: \(error.localizedDescription)"
            isSimulating = true
            isAuthorized = true
            return true
        }
        #else
        isSimulating = true
        isAuthorized = true
        return true
        #endif
    }

    // MARK: - Monitoring Control

    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        if isSimulating {
            startSimulation()
        } else {
            #if canImport(HealthKit)
            startHealthKitQueries()
            #else
            startSimulation()
            #endif
        }
    }

    public func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        stopSimulation()
        #if canImport(HealthKit)
        stopHealthKitQueries()
        #endif
    }

    // MARK: - Simulation

    private func startSimulation() {
        simPhase = 0
        simBreathPhase = 0

        simulationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSimulatedData()
            }
        }
    }

    private func stopSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
    }

    private func updateSimulatedData() {
        // Breathing cycle: 4 seconds in, 6 seconds out = 6 breaths/min
        simBreathPhase += 0.1
        if simBreathPhase > 1.0 { simBreathPhase = 0 }

        let breathSine = sin(simBreathPhase * 2 * .pi)

        // Heart rate varies with breathing (RSA)
        let baseHR = 68.0
        let hrVariation = breathSine * 8.0  // ±8 BPM with breath
        let heartRate = baseHR + hrVariation + Double.random(in: -2...2)

        // HRV increases with relaxation
        let baseHRV = 55.0
        let hrvVariation = abs(breathSine) * 20.0
        let hrvMs = baseHRV + hrvVariation + Double.random(in: -3...3)

        // Add to RR interval buffer
        let rrInterval = 60000.0 / heartRate  // ms
        rrIntervalBuffer.append(rrInterval)
        if rrIntervalBuffer.count > AppConstants.hrvBufferSize {
            rrIntervalBuffer.removeFirst()
        }

        // Calculate coherence
        let coherence = coherenceCalculator.calculate(hrvMs: hrvMs, rrIntervals: rrIntervalBuffer)

        // Breathing rate
        let breathingRate = 12.0 + breathSine * 2.0

        // Create data
        let data = BiometricData(
            heartRate: heartRate,
            hrvMs: hrvMs,
            coherence: coherence,
            breathingRate: breathingRate,
            breathPhase: simBreathPhase,
            timestamp: Date()
        )

        currentData = data
        onDataUpdate?(data)
    }

    // MARK: - HealthKit Queries

    #if canImport(HealthKit)
    private func startHealthKitQueries() {
        guard let healthStore = healthStore else { return }

        // Heart Rate Query
        if let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            let query = HKAnchoredObjectQuery(
                type: hrType,
                predicate: nil,
                anchor: nil,
                limit: HKObjectQueryNoLimit
            ) { [weak self] _, samples, _, _, _ in
                self?.processHeartRateSamples(samples)
            }

            query.updateHandler = { [weak self] _, samples, _, _, _ in
                self?.processHeartRateSamples(samples)
            }

            healthStore.execute(query)
            heartRateQuery = query
        }

        // HRV Query
        if let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            let query = HKAnchoredObjectQuery(
                type: hrvType,
                predicate: nil,
                anchor: nil,
                limit: HKObjectQueryNoLimit
            ) { [weak self] _, samples, _, _, _ in
                self?.processHRVSamples(samples)
            }

            query.updateHandler = { [weak self] _, samples, _, _, _ in
                self?.processHRVSamples(samples)
            }

            healthStore.execute(query)
            hrvQuery = query
        }
    }

    private func stopHealthKitQueries() {
        if let query = heartRateQuery {
            healthStore?.stop(query)
            heartRateQuery = nil
        }
        if let query = hrvQuery {
            healthStore?.stop(query)
            hrvQuery = nil
        }
    }

    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample],
              let latest = samples.last else { return }

        let hr = latest.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

        Task { @MainActor in
            self.currentData.heartRate = hr
            self.currentData.timestamp = Date()

            // Update RR buffer
            let rrInterval = 60000.0 / hr
            self.rrIntervalBuffer.append(rrInterval)
            if self.rrIntervalBuffer.count > AppConstants.hrvBufferSize {
                self.rrIntervalBuffer.removeFirst()
            }

            self.onDataUpdate?(self.currentData)
        }
    }

    private func processHRVSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample],
              let latest = samples.last else { return }

        let hrv = latest.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))

        Task { @MainActor in
            self.currentData.hrvMs = hrv
            self.currentData.coherence = self.coherenceCalculator.calculate(
                hrvMs: hrv,
                rrIntervals: self.rrIntervalBuffer
            )
            self.currentData.timestamp = Date()
            self.onDataUpdate?(self.currentData)
        }
    }
    #endif
}

// MARK: - Coherence Calculator

public final class CoherenceCalculator {
    private var smoothedCoherence: Double = 50.0

    /// Calculate coherence using HeartMath-inspired algorithm
    public func calculate(hrvMs: Double, rrIntervals: [Double]) -> Double {
        // RMSSD-based coherence (simplified HeartMath)
        let rmssd = calculateRMSSD(rrIntervals)

        // Normalize HRV to coherence (20-100ms range → 0-100 score)
        let hrvNormalized = (hrvMs - 20) / 80.0
        let hrvCoherence = max(0, min(1, hrvNormalized)) * 100

        // RMSSD contribution
        let rmssdNormalized = (rmssd - 20) / 80.0
        let rmssdCoherence = max(0, min(1, rmssdNormalized)) * 100

        // Combine (weighted average)
        let rawCoherence = hrvCoherence * 0.6 + rmssdCoherence * 0.4

        // Smooth the value
        smoothedCoherence = smoothedCoherence * (1 - AppConstants.coherenceSmoothing) +
                           rawCoherence * AppConstants.coherenceSmoothing

        return max(0, min(100, smoothedCoherence))
    }

    /// Calculate RMSSD from RR intervals
    private func calculateRMSSD(_ intervals: [Double]) -> Double {
        guard intervals.count > 1 else { return 50.0 }

        var sumSquaredDiffs: Double = 0
        for i in 1..<intervals.count {
            let diff = intervals[i] - intervals[i-1]
            sumSquaredDiffs += diff * diff
        }

        return sqrt(sumSquaredDiffs / Double(intervals.count - 1))
    }
}
