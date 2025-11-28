import Foundation
import HealthKit
import Combine
import Accelerate

/// Manages HealthKit integration for real-time HRV and heart rate monitoring
/// Implements HeartMath Institute's coherence algorithm for biofeedback
///
/// **SAFETY NOTICE:**
/// This is a wellness app, NOT a medical device. HRV data is for informational
/// purposes only and should not be used to make medical decisions.
@MainActor
class HealthKitManager: ObservableObject {

    // MARK: - Singleton

    /// Shared instance for app-wide access
    static let shared = HealthKitManager()

    // MARK: - Published Properties

    /// Current heart rate in beats per minute
    @Published var heartRate: Double = 60.0

    /// Heart Rate Variability RMSSD in milliseconds
    /// RMSSD = Root Mean Square of Successive Differences
    /// Normal range: 20-100 ms (higher = better autonomic function)
    @Published var hrvRMSSD: Double = 0.0

    /// HeartMath coherence score (0-100)
    /// 0-40: Low coherence (stress/anxiety)
    /// 40-60: Medium coherence (transitional)
    /// 60-100: High coherence (optimal/flow state)
    @Published var hrvCoherence: Double = 0.0

    /// Whether HealthKit authorization has been granted
    @Published var isAuthorized: Bool = false

    /// Error message if authorization or monitoring fails
    @Published var errorMessage: String?

    /// Whether monitoring is currently active
    @Published var isMonitoring: Bool = false

    /// Whether medical disclaimer has been acknowledged
    @Published var hasAcknowledgedDisclaimer: Bool = false


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

    /// Valid HRV range for validation (in milliseconds)
    private let validHRVRange: ClosedRange<Double> = 5.0...300.0

    /// Valid heart rate range (BPM)
    private let validHeartRateRange: ClosedRange<Double> = 30.0...220.0

    /// UserDefaults key for disclaimer acknowledgment
    private let disclaimerKey = "healthkit_disclaimer_acknowledged"

    /// Types we need to read from HealthKit (SAFE: no force unwrap)
    private var typesToRead: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        if let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) {
            types.insert(heartRateType)
        }
        if let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrvType)
        }
        return types
    }


    // MARK: - Initialization

    init() {
        loadDisclaimerStatus()
        checkAvailability()
    }

    /// Load disclaimer acknowledgment status from UserDefaults
    private func loadDisclaimerStatus() {
        hasAcknowledgedDisclaimer = UserDefaults.standard.bool(forKey: disclaimerKey)
    }

    /// Acknowledge the medical disclaimer
    func acknowledgeDisclaimer() {
        hasAcknowledgedDisclaimer = true
        UserDefaults.standard.set(true, forKey: disclaimerKey)
    }


    // MARK: - HealthKit Availability

    /// Check if HealthKit is available on this device
    private func checkAvailability() {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit is not available on this device"
            return
        }

        // Check authorization status (SAFE: no force unwrap)
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            errorMessage = "Heart rate type not available on this device"
            return
        }

        let status = healthStore.authorizationStatus(for: heartRateType)
        isAuthorized = (status == .sharingAuthorized)
    }


    // MARK: - Authorization

    /// Request authorization to access HealthKit data
    /// - Throws: HealthKit authorization errors
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            let error = NSError(
                domain: "com.eoel.healthkit",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "HealthKit not available on this device"]
            )
            errorMessage = "HealthKit is not available on this device"
            throw error
        }

        guard !typesToRead.isEmpty else {
            let error = NSError(
                domain: "com.eoel.healthkit",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Required HealthKit types not available"]
            )
            errorMessage = "Heart rate monitoring not supported on this device"
            throw error
        }

        do {
            // Request read access for heart rate and HRV
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)

            // Check if actually authorized (SAFE: no force unwrap)
            guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
                errorMessage = "Heart rate type not available"
                return
            }

            let status = healthStore.authorizationStatus(for: heartRateType)

            switch status {
            case .sharingAuthorized:
                isAuthorized = true
                errorMessage = nil
                print("✅ HealthKit authorized")

            case .notDetermined:
                isAuthorized = false
                errorMessage = "HealthKit authorization pending. Please grant access."

            case .sharingDenied:
                isAuthorized = false
                errorMessage = "HealthKit access denied. Enable in Settings > Privacy > Health."

            @unknown default:
                isAuthorized = false
                errorMessage = "Unknown HealthKit authorization status."
            }

        } catch {
            isAuthorized = false
            errorMessage = "HealthKit authorization failed: \(error.localizedDescription)"
            throw error
        }
    }


    // MARK: - Monitoring Control

    /// Start real-time monitoring of heart rate and HRV
    /// - Note: Requires disclaimer acknowledgment and authorization
    func startMonitoring() {
        guard hasAcknowledgedDisclaimer else {
            errorMessage = "Please acknowledge the medical disclaimer before using biofeedback features."
            return
        }

        guard isAuthorized else {
            errorMessage = "HealthKit not authorized. Please grant access in Settings > Privacy > Health."
            return
        }

        guard !isMonitoring else { return }

        startHeartRateMonitoring()
        startHRVMonitoring()

        isMonitoring = true
        print("🫀 HealthKit monitoring started")
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

        // Secure memory clearing: zero out buffer before removing
        securelyCleanBuffer()

        isMonitoring = false
        print("⏹️ HealthKit monitoring stopped")
    }

    /// Securely clear the RR interval buffer (privacy/security)
    private func securelyCleanBuffer() {
        // Overwrite with zeros before clearing
        for i in 0..<rrIntervalBuffer.count {
            rrIntervalBuffer[i] = 0.0
        }
        rrIntervalBuffer.removeAll()
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

            // VALIDATE HRV data before processing
            guard validateHRVValue(rmssd) else {
                print("⚠️ Invalid HRV value rejected: \(rmssd) ms")
                continue
            }

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

    /// Validate HRV value is within physiologically possible range
    /// - Parameter hrv: HRV value in milliseconds
    /// - Returns: true if valid, false if outlier
    private func validateHRVValue(_ hrv: Double) -> Bool {
        // Check for NaN or infinity
        guard hrv.isFinite else { return false }

        // Check physiological range (RMSSD typically 5-300ms)
        guard validHRVRange.contains(hrv) else { return false }

        // Outlier detection: if we have history, check for sudden spikes
        if rrIntervalBuffer.count >= 5 {
            let recentMean = rrIntervalBuffer.suffix(5).reduce(0, +) / 5.0
            let deviation = abs(hrv - recentMean)
            let maxAllowedDeviation = recentMean * 1.5 // 150% deviation threshold

            if deviation > maxAllowedDeviation && deviation > 50 {
                print("⚠️ HRV outlier detected: \(hrv) ms (mean: \(recentMean) ms)")
                return false
            }
        }

        return true
    }

    /// Validate heart rate value is within physiologically possible range
    /// - Parameter bpm: Heart rate in beats per minute
    /// - Returns: true if valid, false if outlier
    private func validateHeartRate(_ bpm: Double) -> Bool {
        guard bpm.isFinite else { return false }
        return validHeartRateRange.contains(bpm)
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


    // MARK: - Cleanup

    deinit {
        stopMonitoring()
    }
}
