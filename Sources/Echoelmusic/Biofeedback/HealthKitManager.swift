import Foundation
import HealthKit
import Accelerate

/// Manages HealthKit integration for real-time HRV and heart rate monitoring
/// Implements HeartMath Institute's coherence algorithm for biofeedback
/// Migrated to @Observable for better performance (Swift 5.9+)
@MainActor
@Observable
final class HealthKitManager {

    // MARK: - Observable Properties

    /// Current heart rate in beats per minute
    var heartRate: Double = 60.0

    /// Heart Rate Variability RMSSD in milliseconds
    /// RMSSD = Root Mean Square of Successive Differences
    /// Normal range: 20-100 ms (higher = better autonomic function)
    var hrvRMSSD: Double = 0.0

    /// HeartMath coherence score (0-100)
    /// 0-40: Low coherence (stress/anxiety)
    /// 40-60: Medium coherence (transitional)
    /// 60-100: High coherence (optimal/flow state)
    var hrvCoherence: Double = 0.0

    /// Whether HealthKit authorization has been granted
    var isAuthorized: Bool = false

    /// Error message if authorization or monitoring fails
    var errorMessage: String?

    /// Demo mode - simulates biofeedback when HealthKit unavailable
    var isDemoMode: Bool = false


    // MARK: - Private Properties

    /// The HealthKit store for querying health data
    private let healthStore = HKHealthStore()

    /// Active query for heart rate monitoring
    private var heartRateQuery: HKQuery?

    /// Active query for HRV monitoring
    private var hrvQuery: HKQuery?

    /// Buffer for RR intervals (for coherence calculation)
    /// Stores last 60 seconds of RR intervals
    private var rrIntervalBuffer: [Double] = []
    private let maxBufferSize = 120 // 120 RR intervals ≈ 60 seconds at 60 BPM

    /// Timer for demo mode simulation
    private var demoTimer: Timer?

    /// Types we need to read from HealthKit
    private let typesToRead: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    ]


    // MARK: - Initialization

    init() {
        checkAvailability()
    }


    // MARK: - HealthKit Availability

    /// Check if HealthKit is available on this device
    private func checkAvailability() {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit is not available on this device"
            return
        }

        // Check authorization status
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        let status = healthStore.authorizationStatus(for: heartRateType)

        isAuthorized = (status == .sharingAuthorized)
    }


    // MARK: - Authorization

    /// Request authorization to access HealthKit data
    /// - Throws: HealthKit authorization errors
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            let error = NSError(
                domain: "com.echoelmusic.healthkit",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "HealthKit not available"]
            )
            throw error
        }

        do {
            // Request read access for heart rate and HRV
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)

            // Check if actually authorized
            let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
            let status = healthStore.authorizationStatus(for: heartRateType)

            isAuthorized = (status == .sharingAuthorized)

            if isAuthorized {
                #if DEBUG
                debugLog("✅", "HealthKit authorized")
                #endif
                errorMessage = nil
            } else {
                errorMessage = "HealthKit access denied. Enable in Settings."
            }

        } catch {
            errorMessage = "HealthKit authorization failed: \(error.localizedDescription)"
            throw error
        }
    }


    // MARK: - Monitoring Control

    /// Start real-time monitoring of heart rate and HRV
    func startMonitoring() {
        guard isAuthorized else {
            errorMessage = "HealthKit not authorized. Please grant access."
            return
        }

        startHeartRateMonitoring()
        startHRVMonitoring()

        #if DEBUG
        debugLog("🫀", "HealthKit monitoring started")
        #endif
    }

    /// Stop all HealthKit monitoring
    func stopMonitoring() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }

        if let query = hrvQuery {
            healthStore.stop(query)
            hrvQuery = nil
        }

        rrIntervalBuffer.removeAll()

        // Stop demo mode if active
        demoTimer?.invalidate()
        demoTimer = nil

        #if DEBUG
        debugLog("⏹️", "HealthKit monitoring stopped")
        #endif
    }


    // MARK: - Heart Rate Monitoring

    /// Start continuous heart rate monitoring
    private func startHeartRateMonitoring() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return
        }

        // Create a query that updates in real-time
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in

            guard let self = self else { return }

            if let error = error {
                Task { @MainActor in
                    self.errorMessage = "Heart rate query error: \(error.localizedDescription)"
                }
                return
            }

            self.processHeartRateSamples(samples)
        }

        // Set update handler for continuous monitoring
        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            guard let self = self else { return }

            if let error = error {
                Task { @MainActor in
                    self.errorMessage = "Heart rate update error: \(error.localizedDescription)"
                }
                return
            }

            self.processHeartRateSamples(samples)
        }

        heartRateQuery = query
        healthStore.execute(query)
    }

    /// Process heart rate samples and update published property
    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample] else { return }

        // Get most recent heart rate
        if let latest = samples.last {
            let bpm = latest.quantity.doubleValue(for: HKUnit(from: "count/min"))

            Task { @MainActor in
                self.heartRate = bpm
            }
        }
    }


    // MARK: - HRV Monitoring

    /// Start continuous HRV monitoring
    private func startHRVMonitoring() {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return
        }

        let query = HKAnchoredObjectQuery(
            type: hrvType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in

            guard let self = self else { return }

            if let error = error {
                Task { @MainActor in
                    self.errorMessage = "HRV query error: \(error.localizedDescription)"
                }
                return
            }

            self.processHRVSamples(samples)
        }

        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            guard let self = self else { return }

            if let error = error {
                Task { @MainActor in
                    self.errorMessage = "HRV update error: \(error.localizedDescription)"
                }
                return
            }

            self.processHRVSamples(samples)
        }

        hrvQuery = query
        healthStore.execute(query)
    }

    /// Process HRV samples and calculate coherence
    private func processHRVSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample] else { return }

        // Get RR intervals from HRV samples
        for sample in samples {
            let rmssd = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))

            // Add to buffer (simulating RR intervals from RMSSD)
            // In production, you'd want actual RR intervals via HKHeartbeatSeriesSample
            addRRInterval(rmssd)

            Task { @MainActor in
                self.hrvRMSSD = rmssd

                // Calculate coherence from buffered RR intervals
                if self.rrIntervalBuffer.count >= 30 { // Need minimum data
                    self.hrvCoherence = self.calculateCoherence(rrIntervals: self.rrIntervalBuffer)
                }
            }
        }
    }

    /// Add RR interval to circular buffer
    private func addRRInterval(_ interval: Double) {
        rrIntervalBuffer.append(interval)

        // Keep buffer size limited (circular buffer behavior)
        if rrIntervalBuffer.count > maxBufferSize {
            rrIntervalBuffer.removeFirst()
        }
    }


    // MARK: - HeartMath Coherence Algorithm

    /// Calculate HeartMath coherence score from RR intervals
    /// Based on HeartMath Institute's research on heart-brain coherence
    ///
    /// Algorithm steps:
    /// 1. Detrend RR intervals (remove linear trend)
    /// 2. Apply Hamming window
    /// 3. Perform FFT
    /// 4. Calculate power spectral density
    /// 5. Measure peak power in coherence band (0.04-0.26 Hz, centered at 0.1 Hz)
    /// 6. Normalize to 0-100 scale
    ///
    /// - Parameter rrIntervals: Array of RR intervals in milliseconds
    /// - Returns: Coherence score from 0 (low) to 100 (high)
    func calculateCoherence(rrIntervals: [Double]) -> Double {
        guard rrIntervals.count >= 30 else { return 0.0 }

        // Step 1: Detrend the data (remove linear trend)
        let detrended = detrend(rrIntervals)

        // Step 2: Apply Hamming window to reduce spectral leakage
        let windowed = applyHammingWindow(detrended)

        // Step 3: Perform FFT
        let fftSize = nextPowerOf2(windowed.count)
        let powerSpectrum = performFFTForCoherence(windowed, fftSize: fftSize)

        // Step 4: Calculate coherence score
        // HeartMath coherence band: 0.04-0.26 Hz, with peak typically at 0.1 Hz
        // Assuming 1 Hz sampling rate (1 RR interval per second)
        let samplingRate = 1.0
        let coherenceBandLow = 0.04  // Hz
        let coherenceBandHigh = 0.26 // Hz

        let binLow = Int(coherenceBandLow * Double(fftSize) / samplingRate)
        let binHigh = Int(coherenceBandHigh * Double(fftSize) / samplingRate)

        // Find peak power in coherence band
        let coherenceBandPower = powerSpectrum[binLow...binHigh]
        let peakPower = coherenceBandPower.max() ?? 0.0

        // Calculate total power across all frequencies
        let totalPower = powerSpectrum.reduce(0.0, +)

        // Coherence ratio: peak power / total power
        let coherenceRatio = totalPower > 0 ? peakPower / totalPower : 0.0

        // Normalize to 0-100 scale (empirically calibrated)
        let coherenceScore = min(coherenceRatio * 500.0, 100.0)

        return coherenceScore
    }

    /// Remove linear trend from signal
    private func detrend(_ data: [Double]) -> [Double] {
        let n = Double(data.count)
        let xSum = (0..<data.count).reduce(0.0) { $0 + Double($1) }
        let ySum = data.reduce(0.0, +)
        let xySum = data.enumerated().reduce(0.0) { $0 + Double($1.offset) * $1.element }
        let xxSum = (0..<data.count).reduce(0.0) { $0 + Double($1 * $1) }

        // Linear regression: y = slope * x + intercept
        let slope = (n * xySum - xSum * ySum) / (n * xxSum - xSum * xSum)
        let intercept = (ySum - slope * xSum) / n

        // Subtract trend line from data
        return data.enumerated().map { index, value in
            value - (slope * Double(index) + intercept)
        }
    }

    /// Apply Hamming window to reduce spectral leakage
    private func applyHammingWindow(_ data: [Double]) -> [Double] {
        let n = data.count
        var windowed = [Double](repeating: 0, count: n)

        for i in 0..<n {
            let window = 0.54 - 0.46 * cos(2.0 * .pi * Double(i) / Double(n - 1))
            windowed[i] = data[i] * window
        }

        return windowed
    }

    /// Perform FFT and return power spectrum
    private func performFFTForCoherence(_ data: [Double], fftSize: Int) -> [Double] {
        // Prepare input (pad to fftSize)
        var realParts = [Float](repeating: 0, count: fftSize)
        for i in 0..<min(data.count, fftSize) {
            realParts[i] = Float(data[i])
        }
        var imagParts = [Float](repeating: 0, count: fftSize)

        // Setup FFT
        guard let fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            vDSP_DFT_Direction.FORWARD
        ) else {
            return []
        }

        defer {
            vDSP_DFT_DestroySetup(fftSetup)
        }

        // Perform FFT
        vDSP_DFT_Execute(fftSetup, &realParts, &imagParts, &realParts, &imagParts)

        // Calculate power spectrum (magnitude squared)
        var powerSpectrum = [Double](repeating: 0, count: fftSize / 2)
        for i in 0..<(fftSize / 2) {
            let magnitude = sqrt(realParts[i] * realParts[i] + imagParts[i] * imagParts[i])
            powerSpectrum[i] = Double(magnitude * magnitude)
        }

        return powerSpectrum
    }

    /// Find next power of 2 for FFT efficiency
    private func nextPowerOf2(_ n: Int) -> Int {
        var power = 1
        while power < n {
            power *= 2
        }
        return power
    }


    // MARK: - Demo Mode

    /// Enable demo mode with simulated biofeedback data
    /// Use when HealthKit is unavailable or for testing
    func enableDemoMode() {
        isDemoMode = true
        isAuthorized = true // Pretend we're authorized

        // Stop real monitoring if active
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
        if let query = hrvQuery {
            healthStore.stop(query)
            hrvQuery = nil
        }

        // Start demo simulation
        demoTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateDemoValues()
            }
        }

        #if DEBUG
        debugLog("🎭", "HealthKit demo mode enabled")
        #endif
    }

    /// Disable demo mode
    func disableDemoMode() {
        isDemoMode = false
        demoTimer?.invalidate()
        demoTimer = nil

        // Reset values
        heartRate = 60.0
        hrvRMSSD = 0.0
        hrvCoherence = 0.0

        #if DEBUG
        debugLog("🎭", "HealthKit demo mode disabled")
        #endif
    }

    /// Update demo values with realistic simulation
    private func updateDemoValues() {
        guard isDemoMode else { return }

        // Simulate heart rate with natural variation (55-95 BPM)
        let hrVariation = Double.random(in: -3...3)
        heartRate = max(55, min(95, heartRate + hrVariation))

        // Simulate HRV RMSSD (20-80 ms range)
        let hrvVariation = Double.random(in: -5...5)
        hrvRMSSD = max(20, min(80, hrvRMSSD + hrvVariation))
        if hrvRMSSD == 0 { hrvRMSSD = 45 } // Initialize if zero

        // Coherence follows HRV pattern with some randomness
        // Higher HRV generally correlates with higher coherence
        let baseCoherence = 30 + (hrvRMSSD / 80.0) * 50
        let coherenceVariation = Double.random(in: -5...5)
        hrvCoherence = max(0, min(100, baseCoherence + coherenceVariation))

        // Add simulated RR intervals to buffer for coherence algorithm
        let simulatedRR = 60000 / heartRate + Double.random(in: -50...50)
        addRRInterval(simulatedRR)
    }


    // MARK: - Cleanup

    deinit {
        stopMonitoring()
    }
}

// MARK: - ObservableObject Compatibility (for gradual migration)

extension HealthKitManager: ObservableObject {
    // This extension allows HealthKitManager to work with both
    // @EnvironmentObject (legacy) and @Environment (new)
    // Remove after full migration to @Observable
}
