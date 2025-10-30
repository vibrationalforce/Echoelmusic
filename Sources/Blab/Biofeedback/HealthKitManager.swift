import Foundation
import HealthKit
import Combine
import Accelerate

/// Manages HealthKit integration for real-time HRV and heart rate monitoring
/// Implements HeartMath Institute's coherence algorithm for biofeedback
@MainActor
class HealthKitManager: ObservableObject {

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

    /// Low Frequency HRV power (0.04-0.15 Hz) - Sympathetic activity
    /// Reflects baroreflex activity and sympathetic modulation
    @Published var hrvLF: Double = 0.0

    /// High Frequency HRV power (0.15-0.4 Hz) - Parasympathetic activity
    /// Reflects respiratory sinus arrhythmia (RSA) and vagal tone
    @Published var hrvHF: Double = 0.0

    /// LF/HF Ratio - Sympathovagal balance
    /// < 1.0: Parasympathetic dominance (relaxation)
    /// 1.0-2.5: Balanced autonomic state
    /// > 2.5: Sympathetic dominance (stress/activation)
    @Published var hrvLFHFRatio: Double = 0.0

    /// Total HRV power (0.003-0.4 Hz)
    @Published var hrvTotalPower: Double = 0.0

    /// Whether HealthKit authorization has been granted
    @Published var isAuthorized: Bool = false

    /// Error message if authorization or monitoring fails
    @Published var errorMessage: String?


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
                domain: "com.blab.healthkit",
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
                print("✅ HealthKit authorized")
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

        rrIntervalBuffer.removeAll()

        print("⏹️ HealthKit monitoring stopped")
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

                // Calculate coherence and frequency domain metrics from buffered RR intervals
                if self.rrIntervalBuffer.count >= 30 { // Need minimum data
                    self.hrvCoherence = self.calculateCoherence(rrIntervals: self.rrIntervalBuffer)
                    self.updateFrequencyDomainMetrics()
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

    /// Calculate HRV frequency domain analysis (LF, HF, LF/HF ratio)
    ///
    /// **Scientific Basis:**
    /// - LF (0.04-0.15 Hz): Baroreflex activity, sympathetic + parasympathetic modulation
    /// - HF (0.15-0.4 Hz): Respiratory sinus arrhythmia (RSA), pure parasympathetic
    /// - LF/HF Ratio: Sympathovagal balance indicator
    ///
    /// **References:**
    /// - Task Force (1996). Heart rate variability: Standards of measurement
    /// - Malik, M. (1996). Heart rate variability. Annals of Noninvasive Electrocardiology
    /// - McCraty, R. & Shaffer, F. (2015). Heart rate variability: New perspectives
    ///
    /// - Parameter rrIntervals: Array of RR intervals in milliseconds
    /// - Returns: Tuple with (LF power, HF power, LF/HF ratio, total power)
    func calculateLFHF(rrIntervals: [Double]) -> (lf: Double, hf: Double, lfhfRatio: Double, totalPower: Double) {
        guard rrIntervals.count >= 30 else {
            return (0.0, 0.0, 0.0, 0.0)
        }

        // Step 1: Detrend and window the data
        let detrended = detrend(rrIntervals)
        let windowed = applyHammingWindow(detrended)

        // Step 2: Perform FFT
        let fftSize = nextPowerOf2(windowed.count)
        let powerSpectrum = performFFTForCoherence(windowed, fftSize: fftSize)

        // Step 3: Define frequency bands (Task Force, 1996)
        let samplingRate = 1.0  // 1 Hz (1 RR interval per second)
        let vlfLow = 0.003   // Hz
        let vlfHigh = 0.04   // Hz
        let lfLow = 0.04     // Hz
        let lfHigh = 0.15    // Hz
        let hfLow = 0.15     // Hz
        let hfHigh = 0.4     // Hz

        // Convert frequencies to FFT bins
        let vlfBinLow = Int(vlfLow * Double(fftSize) / samplingRate)
        let vlfBinHigh = Int(vlfHigh * Double(fftSize) / samplingRate)
        let lfBinLow = Int(lfLow * Double(fftSize) / samplingRate)
        let lfBinHigh = Int(lfHigh * Double(fftSize) / samplingRate)
        let hfBinLow = Int(hfLow * Double(fftSize) / samplingRate)
        let hfBinHigh = Int(hfHigh * Double(fftSize) / samplingRate)

        // Step 4: Calculate power in each band
        let vlfPower = powerSpectrum[vlfBinLow...min(vlfBinHigh, powerSpectrum.count - 1)].reduce(0.0, +)
        let lfPower = powerSpectrum[lfBinLow...min(lfBinHigh, powerSpectrum.count - 1)].reduce(0.0, +)
        let hfPower = powerSpectrum[hfBinLow...min(hfBinHigh, powerSpectrum.count - 1)].reduce(0.0, +)

        // Total power (VLF + LF + HF)
        let totalPower = vlfPower + lfPower + hfPower

        // LF/HF Ratio (guard against division by zero)
        let lfhfRatio = hfPower > 0.001 ? lfPower / hfPower : 0.0

        return (lf: lfPower, hf: hfPower, lfhfRatio: lfhfRatio, totalPower: totalPower)
    }

    /// Update HRV frequency domain metrics
    private func updateFrequencyDomainMetrics() {
        guard rrIntervalBuffer.count >= 30 else { return }

        let result = calculateLFHF(rrIntervals: rrIntervalBuffer)

        Task { @MainActor in
            self.hrvLF = result.lf
            self.hrvHF = result.hf
            self.hrvLFHFRatio = result.lfhfRatio
            self.hrvTotalPower = result.totalPower
        }
    }

    /// Get autonomic balance interpretation
    var autonomicBalanceDescription: String {
        if hrvLFHFRatio < 1.0 {
            return "Parasympathetic Dominance (Relaxed)"
        } else if hrvLFHFRatio < 2.5 {
            return "Balanced Autonomic State"
        } else {
            return "Sympathetic Dominance (Stressed/Active)"
        }
    }

    /// Get detailed HRV frequency analysis summary
    var frequencyAnalysisSummary: String {
        """
        HRV Frequency Domain Analysis:
          LF Power: \(String(format: "%.2f", hrvLF)) ms²
          HF Power: \(String(format: "%.2f", hrvHF)) ms²
          LF/HF Ratio: \(String(format: "%.2f", hrvLFHFRatio))
          Total Power: \(String(format: "%.2f", hrvTotalPower)) ms²
          Balance: \(autonomicBalanceDescription)
        """
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
