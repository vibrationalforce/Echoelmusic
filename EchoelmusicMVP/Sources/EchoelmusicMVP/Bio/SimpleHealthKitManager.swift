// SimpleHealthKitManager - Minimal HealthKit Integration
// Works with real HealthKit on device, simulated on simulator

import Foundation
import Combine

#if canImport(HealthKit)
import HealthKit
#endif

// MARK: - Bio Data Model

public struct SimpleBioData: Sendable {
    public var heartRate: Double
    public var hrv: Double
    public var coherence: Double
    public var breathingRate: Double
    public var timestamp: Date

    public init(
        heartRate: Double = 72.0,
        hrv: Double = 50.0,
        coherence: Double = 0.5,
        breathingRate: Double = 12.0,
        timestamp: Date = Date()
    ) {
        self.heartRate = heartRate
        self.hrv = hrv
        self.coherence = coherence
        self.breathingRate = breathingRate
        self.timestamp = timestamp
    }

    /// Calculate coherence from HRV (simplified algorithm)
    public static func calculateCoherence(hrv: Double) -> Double {
        // Coherence increases with higher HRV (typically 20-100ms range)
        // Optimal HRV for coherence: 60-80ms
        let normalized = min(max((hrv - 20) / 80, 0), 1)

        // Apply smoothing curve
        let coherence = sin(normalized * .pi / 2)
        return min(max(coherence, 0), 1)
    }
}

// MARK: - Simple HealthKit Manager

@MainActor
public final class SimpleHealthKitManager: ObservableObject {
    // MARK: - Published Properties

    @Published public var isAuthorized: Bool = false
    @Published public var isMonitoring: Bool = false
    @Published public var currentBioData: SimpleBioData = SimpleBioData()
    @Published public var errorMessage: String?

    // MARK: - Callbacks

    public var onBioDataUpdate: ((SimpleBioData) -> Void)?

    // MARK: - Private Properties

    #if canImport(HealthKit)
    private var healthStore: HKHealthStore?
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var hrvQuery: HKAnchoredObjectQuery?
    #endif

    private var simulationTimer: Timer?
    private var useSimulation: Bool = false

    // Simulation state
    private var simulatedHR: Double = 72.0
    private var simulatedHRV: Double = 50.0
    private var breathPhase: Double = 0.0

    // MARK: - Initialization

    public init() {
        #if canImport(HealthKit)
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
            useSimulation = false
        } else {
            useSimulation = true
        }
        #else
        useSimulation = true
        #endif

        print("❤️ HealthKit Manager initialized (simulation: \(useSimulation))")
    }

    // MARK: - Authorization

    public func requestAuthorization() async -> Bool {
        #if canImport(HealthKit)
        guard let healthStore = healthStore else {
            useSimulation = true
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
            print("✅ HealthKit authorized")
            return true
        } catch {
            errorMessage = "HealthKit authorization failed: \(error.localizedDescription)"
            useSimulation = true
            isAuthorized = true // Allow app to run with simulation
            print("⚠️ HealthKit auth failed, using simulation")
            return true
        }
        #else
        useSimulation = true
        isAuthorized = true
        return true
        #endif
    }

    // MARK: - Monitoring

    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        if useSimulation {
            startSimulation()
        } else {
            #if canImport(HealthKit)
            startHealthKitQueries()
            #endif
        }

        print("📊 Bio monitoring started")
    }

    public func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false

        if useSimulation {
            stopSimulation()
        } else {
            #if canImport(HealthKit)
            stopHealthKitQueries()
            #endif
        }

        print("📊 Bio monitoring stopped")
    }

    // MARK: - Simulation

    private func startSimulation() {
        // Reset simulation state
        simulatedHR = 72.0
        simulatedHRV = 50.0
        breathPhase = 0.0

        // Update at 1 Hz (realistic for bio data)
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
        // Simulate breathing cycle (4 seconds in, 4 seconds out)
        breathPhase += 0.125 // 1/8 of cycle per second
        if breathPhase > 1.0 { breathPhase -= 1.0 }

        let breathSine = sin(breathPhase * 2 * .pi)

        // Heart rate varies with breathing (respiratory sinus arrhythmia)
        let baseHR = 72.0
        let hrVariation = breathSine * 5.0 // ±5 BPM variation
        simulatedHR = baseHR + hrVariation + Double.random(in: -1...1)

        // HRV increases during calm states
        let baseHRV = 50.0
        let hrvVariation = abs(breathSine) * 15.0 // Higher during deep breathing
        simulatedHRV = baseHRV + hrvVariation + Double.random(in: -2...2)

        // Calculate coherence
        let coherence = SimpleBioData.calculateCoherence(hrv: simulatedHRV)

        // Breathing rate (breaths per minute)
        let breathingRate = 12.0 + breathSine * 2.0

        // Create bio data
        let bioData = SimpleBioData(
            heartRate: simulatedHR,
            hrv: simulatedHRV,
            coherence: coherence,
            breathingRate: breathingRate,
            timestamp: Date()
        )

        currentBioData = bioData
        onBioDataUpdate?(bioData)
    }

    // MARK: - Real HealthKit Queries

    #if canImport(HealthKit)
    private func startHealthKitQueries() {
        guard let healthStore = healthStore else { return }

        // Heart Rate Query
        if let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            let query = HKAnchoredObjectQuery(
                type: heartRateType,
                predicate: nil,
                anchor: nil,
                limit: HKObjectQueryNoLimit
            ) { [weak self] _, samples, _, _, error in
                if let error = error {
                    print("❌ Heart rate query error: \(error)")
                    return
                }
                self?.processHeartRateSamples(samples)
            }

            query.updateHandler = { [weak self] _, samples, _, _, error in
                if let error = error {
                    print("❌ Heart rate update error: \(error)")
                    return
                }
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
            ) { [weak self] _, samples, _, _, error in
                if let error = error {
                    print("❌ HRV query error: \(error)")
                    return
                }
                self?.processHRVSamples(samples)
            }

            query.updateHandler = { [weak self] _, samples, _, _, error in
                if let error = error {
                    print("❌ HRV update error: \(error)")
                    return
                }
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

        let heartRate = latest.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

        Task { @MainActor in
            var bioData = self.currentBioData
            bioData.heartRate = heartRate
            bioData.timestamp = Date()
            self.currentBioData = bioData
            self.onBioDataUpdate?(bioData)
        }
    }

    private func processHRVSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample],
              let latest = samples.last else { return }

        let hrv = latest.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))

        Task { @MainActor in
            var bioData = self.currentBioData
            bioData.hrv = hrv
            bioData.coherence = SimpleBioData.calculateCoherence(hrv: hrv)
            bioData.timestamp = Date()
            self.currentBioData = bioData
            self.onBioDataUpdate?(bioData)
        }
    }
    #endif
}

// MARK: - Health Disclaimer

public struct HealthDisclaimer {
    public static let shortText = """
    This app is for relaxation and creative purposes only. \
    It is NOT a medical device and should not be used for \
    diagnosis or treatment of any health condition.
    """

    public static let fullText = """
    IMPORTANT HEALTH DISCLAIMER

    Echoelmusic is designed for relaxation, creativity, and general wellness purposes only.

    This application:
    • Is NOT a medical device
    • Does NOT provide medical advice
    • Should NOT be used to diagnose, treat, cure, or prevent any disease
    • Is NOT a substitute for professional medical care

    The biometric readings (heart rate, HRV, coherence) are for informational
    and entertainment purposes only. Always consult a qualified healthcare
    provider for any health concerns.

    If you experience any discomfort during use, stop immediately and
    consult a medical professional.

    © 2026 Echoelmusic - For relaxation and creativity only.
    """
}
