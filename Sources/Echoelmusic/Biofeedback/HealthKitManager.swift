import Foundation
import HealthKit
import Combine
import Accelerate
import os.log

/// Manages HealthKit integration for real-time HRV and heart rate monitoring
/// HeartMath-inspired coherence estimation for biofeedback
/// Based on published research from HeartMath Institute (McCraty et al. 2009)
///
/// ⚠️ DISCLAIMER: This is an open-source approximation inspired by HeartMath's research.
/// It is NOT the proprietary HeartMath coherence algorithm used in their commercial products.
/// For validated HeartMath measurements, use the official Inner Balance app.
@MainActor
class HealthKitManager: ObservableObject {

    // MARK: - Published Properties

    /// Current heart rate in beats per minute
    @Published var heartRate: Double = 60.0

    /// Heart Rate Variability RMSSD in milliseconds
    /// RMSSD = Root Mean Square of Successive Differences
    /// Normal range: 20-100 ms (higher = better autonomic function)
    @Published var hrvRMSSD: Double = 0.0

    /// Heart Rate Variability SDNN in milliseconds
    /// SDNN = Standard Deviation of NN intervals
    /// Normal range: 50-100 ms (higher = better overall HRV)
    /// Reference: Task Force ESC/NASPE (1996)
    @Published var hrvSDNN: Double = 0.0

    /// pNN50 - Percentage of successive intervals >50ms different
    /// Normal range: 5-20% (higher = better parasympathetic function)
    /// Reference: Task Force ESC/NASPE (1996)
    @Published var hrvPNN50: Double = 0.0

    /// Low Frequency power (0.04-0.15 Hz) in ms²
    /// Reflects sympathetic and parasympathetic activity
    /// Reference: Task Force ESC/NASPE (1996)
    @Published var hrvLF: Double = 0.0

    /// High Frequency power (0.15-0.4 Hz) in ms²
    /// Reflects parasympathetic (vagal) activity
    /// Reference: Task Force ESC/NASPE (1996)
    @Published var hrvHF: Double = 0.0

    /// LF/HF Ratio - Autonomic balance indicator
    /// Low ratio (<1): Parasympathetic dominance (relaxed)
    /// High ratio (>2): Sympathetic dominance (stressed/alert)
    /// Reference: Task Force ESC/NASPE (1996)
    @Published var hrvLFHFRatio: Double = 1.0

    /// Coherence score (0-100) - HeartMath-inspired estimation
    /// Approximate zones (not validated against official HeartMath thresholds):
    /// 0-40: Low coherence (may indicate stress/anxiety)
    /// 40-60: Medium coherence (transitional state)
    /// 60-100: High coherence (optimal/flow state potential)
    ///
    /// ⚠️ For research/educational use only. Not a medical device.
    @Published var hrvCoherence: Double = 0.0

    /// Calculated breathing rate in breaths per minute
    /// Derived from HRV spectral analysis (HF band: 0.15-0.4 Hz)
    /// Normal range: 12-20 breaths/min
    /// Coherent breathing: 6 breaths/min (0.1 Hz)
    @Published var breathingRate: Double = 12.0

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

    private static let logger = Logger(subsystem: "com.echoelmusic.biofeedback", category: "HealthKitManager")


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
                Self.logger.info("HealthKit authorized successfully")
                errorMessage = nil
            } else {
                Self.logger.warning("HealthKit access denied by user")
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

        Self.logger.info("HealthKit monitoring started - Heart Rate + HRV")
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

        Self.logger.info("HealthKit monitoring stopped")
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

                // Calculate all HRV metrics from buffered RR intervals
                if self.rrIntervalBuffer.count >= 30 { // Need minimum data
                    // HeartMath-inspired coherence
                    self.hrvCoherence = self.calculateCoherence(rrIntervals: self.rrIntervalBuffer)

                    // Respiratory rate extraction
                    self.breathingRate = self.calculateBreathingRate(rrIntervals: self.rrIntervalBuffer)

                    // Time-domain metrics (Task Force 1996)
                    self.hrvSDNN = self.calculateSDNN(rrIntervals: self.rrIntervalBuffer)
                    self.hrvPNN50 = self.calculatePNN50(rrIntervals: self.rrIntervalBuffer)

                    // Frequency-domain metrics (LF, HF, LF/HF ratio)
                    let (lf, hf, ratio) = self.calculateLFHF(rrIntervals: self.rrIntervalBuffer)
                    self.hrvLF = lf
                    self.hrvHF = hf
                    self.hrvLFHFRatio = ratio
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


    // MARK: - Coherence Estimation (HeartMath-Inspired)

    /// Estimate coherence score from RR intervals using spectral analysis
    /// Inspired by HeartMath Institute's research on heart-brain coherence
    ///
    /// **Method:**
    /// 1. Detrend RR intervals (remove linear trend)
    /// 2. Apply Hamming window
    /// 3. Perform FFT
    /// 4. Calculate power spectral density
    /// 5. Measure peak power in coherence band (0.04-0.26 Hz, centered at 0.1 Hz)
    /// 6. Normalize to 0-100 scale
    ///
    /// **Research Basis:**
    /// - McCraty et al. (2009). "The coherent heart" - HeartMath Institute
    /// - Lehrer & Gevirtz (2014). "Heart rate variability biofeedback" - Biofeedback 42(1):26-37
    /// - 0.1 Hz resonance maximizes baroreflex gain and vagal tone
    ///
    /// ⚠️ **Limitation:** This is an approximation. The exact HeartMath algorithm is proprietary.
    /// Coherence scores may not match official HeartMath devices (Inner Balance, emWave).
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

    /// Calculate breathing rate from RR intervals using spectral analysis
    ///
    /// Respiratory Sinus Arrhythmia (RSA) causes HRV oscillations at breathing frequency.
    /// The high-frequency (HF) component of HRV (0.15-0.4 Hz) corresponds to breathing.
    ///
    /// **Scientific References:**
    /// - Task Force ESC/NASPE (1996). "Heart rate variability: standards of measurement"
    ///   Circulation 93(5):1043-1065. DOI: 10.1161/01.CIR.93.5.1043
    /// - Hirsch & Bishop (1981). "Respiratory sinus arrhythmia in humans"
    ///   Am J Physiol 241(4):H620-H629
    /// - Berntson et al. (1997). "Heart rate variability: Origins, methods, and interpretive caveats"
    ///   Psychophysiology 34(6):623-648
    ///
    /// **Method:** FFT of windowed RR intervals, peak detection in respiratory band (0.15-0.4 Hz)
    ///
    /// - Parameter rrIntervals: Array of RR intervals in milliseconds
    /// - Returns: Estimated breathing rate in breaths per minute
    func calculateBreathingRate(rrIntervals: [Double]) -> Double {
        guard rrIntervals.count >= 30 else { return 12.0 } // Default to normal rate

        // Step 1: Detrend and window the data
        let detrended = detrend(rrIntervals)
        let windowed = applyHammingWindow(detrended)

        // Step 2: Perform FFT
        let fftSize = nextPowerOf2(windowed.count)
        let powerSpectrum = performFFTForCoherence(windowed, fftSize: fftSize)

        // Step 3: Find peak in respiratory frequency band (0.15-0.4 Hz)
        // This corresponds to 9-24 breaths/min
        let samplingRate = 1.0  // 1 RR interval per second
        let respiratoryBandLow = 0.15   // Hz (9 breaths/min)
        let respiratoryBandHigh = 0.4   // Hz (24 breaths/min)

        let binLow = Int(respiratoryBandLow * Double(fftSize) / samplingRate)
        let binHigh = Int(respiratoryBandHigh * Double(fftSize) / samplingRate)

        // Find frequency bin with maximum power in respiratory band
        var peakBin = binLow
        var peakPower = 0.0

        for bin in binLow...min(binHigh, powerSpectrum.count - 1) {
            if powerSpectrum[bin] > peakPower {
                peakPower = powerSpectrum[bin]
                peakBin = bin
            }
        }

        // Convert bin to frequency in Hz
        let peakFrequency = Double(peakBin) * samplingRate / Double(fftSize)

        // Convert Hz to breaths per minute
        let breathsPerMinute = peakFrequency * 60.0

        // Clamp to physiological range (4-30 breaths/min)
        return min(max(breathsPerMinute, 4.0), 30.0)
    }

    /// Calculate SDNN (Standard Deviation of NN intervals)
    ///
    /// SDNN is a fundamental HRV time-domain metric representing overall variability.
    /// It reflects all cyclic components of HRV (circadian rhythms, respiration, baroreflex).
    ///
    /// **Scientific Reference:**
    /// - Task Force ESC/NASPE (1996). "Heart rate variability: standards of measurement, physiological interpretation, and clinical use"
    ///   Circulation 93(5):1043-1065. DOI: 10.1161/01.CIR.93.5.1043
    ///
    /// **Normal Values:**
    /// - Healthy adults: 50-100 ms
    /// - Athletes: >100 ms
    /// - Stressed/fatigued: <50 ms
    ///
    /// **Calculation:** Standard deviation of all NN (normal-to-normal) intervals
    ///
    /// - Parameter rrIntervals: Array of RR intervals in milliseconds
    /// - Returns: SDNN in milliseconds
    func calculateSDNN(rrIntervals: [Double]) -> Double {
        guard rrIntervals.count >= 2 else { return 0.0 }

        // Calculate mean
        let mean = rrIntervals.reduce(0.0, +) / Double(rrIntervals.count)

        // Calculate variance
        let variance = rrIntervals.reduce(0.0) { $0 + pow($1 - mean, 2) } / Double(rrIntervals.count)

        // Return standard deviation
        return sqrt(variance)
    }

    /// Calculate pNN50 (Percentage of successive intervals >50ms different)
    ///
    /// pNN50 is a time-domain measure of parasympathetic (vagal) activity.
    /// Higher values indicate better vagal tone and stress resilience.
    ///
    /// **Scientific Reference:**
    /// - Task Force ESC/NASPE (1996). "Heart rate variability: standards of measurement"
    ///   Circulation 93(5):1043-1065. DOI: 10.1161/01.CIR.93.5.1043
    ///
    /// **Normal Values:**
    /// - Healthy adults: 5-20%
    /// - Athletes: >20%
    /// - Stressed/fatigued: <5%
    ///
    /// **Calculation:** (Number of successive interval differences >50ms) / (Total number of intervals - 1) * 100%
    ///
    /// - Parameter rrIntervals: Array of RR intervals in milliseconds
    /// - Returns: pNN50 as percentage (0-100)
    func calculatePNN50(rrIntervals: [Double]) -> Double {
        guard rrIntervals.count >= 2 else { return 0.0 }

        // Calculate successive differences
        var countOver50ms = 0
        for i in 0..<(rrIntervals.count - 1) {
            let difference = abs(rrIntervals[i + 1] - rrIntervals[i])
            if difference > 50.0 {
                countOver50ms += 1
            }
        }

        // Calculate percentage
        let percentage = Double(countOver50ms) / Double(rrIntervals.count - 1) * 100.0
        return percentage
    }

    /// Calculate LF and HF power, and LF/HF ratio
    ///
    /// Frequency-domain HRV analysis provides insight into autonomic nervous system balance:
    /// - LF (0.04-0.15 Hz): Sympathetic + Parasympathetic activity, baroreflex
    /// - HF (0.15-0.4 Hz): Parasympathetic (vagal) activity, respiratory sinus arrhythmia
    /// - LF/HF Ratio: Autonomic balance (sympatho-vagal balance)
    ///
    /// **Scientific References:**
    /// - Task Force ESC/NASPE (1996). "Heart rate variability: standards of measurement"
    ///   Circulation 93(5):1043-1065. DOI: 10.1161/01.CIR.93.5.1043
    /// - Akselrod et al. (1981). "Power spectrum analysis of heart rate fluctuation"
    ///   Science 213(4504):220-222. DOI: 10.1126/science.6166045
    ///
    /// **Interpretation:**
    /// - LF/HF < 1: Parasympathetic dominance (relaxed, recovery)
    /// - LF/HF 1-2: Balanced autonomic state
    /// - LF/HF > 2: Sympathetic dominance (stressed, alert, exercise)
    ///
    /// **Calculation:** FFT-based power spectral density in LF and HF bands
    ///
    /// - Parameter rrIntervals: Array of RR intervals in milliseconds
    /// - Returns: Tuple of (LF power in ms², HF power in ms², LF/HF ratio)
    func calculateLFHF(rrIntervals: [Double]) -> (lf: Double, hf: Double, ratio: Double) {
        guard rrIntervals.count >= 30 else { return (0.0, 0.0, 1.0) }

        // Step 1: Detrend and window the data
        let detrended = detrend(rrIntervals)
        let windowed = applyHammingWindow(detrended)

        // Step 2: Perform FFT
        let fftSize = nextPowerOf2(windowed.count)
        let powerSpectrum = performFFTForCoherence(windowed, fftSize: fftSize)

        // Step 3: Calculate power in frequency bands
        let samplingRate = 1.0  // 1 RR interval per second

        // LF band: 0.04-0.15 Hz
        let lfBandLow = 0.04
        let lfBandHigh = 0.15
        let lfBinLow = Int(lfBandLow * Double(fftSize) / samplingRate)
        let lfBinHigh = Int(lfBandHigh * Double(fftSize) / samplingRate)

        // HF band: 0.15-0.4 Hz
        let hfBandLow = 0.15
        let hfBandHigh = 0.4
        let hfBinLow = Int(hfBandLow * Double(fftSize) / samplingRate)
        let hfBinHigh = Int(hfBandHigh * Double(fftSize) / samplingRate)

        // Sum power in each band
        var lfPower = 0.0
        for bin in lfBinLow...min(lfBinHigh, powerSpectrum.count - 1) {
            lfPower += powerSpectrum[bin]
        }

        var hfPower = 0.0
        for bin in hfBinLow...min(hfBinHigh, powerSpectrum.count - 1) {
            hfPower += powerSpectrum[bin]
        }

        // Calculate LF/HF ratio (avoid division by zero)
        let ratio = hfPower > 0 ? lfPower / hfPower : 1.0

        return (lfPower, hfPower, ratio)
    }


    // MARK: - Cleanup

    deinit {
        stopMonitoring()
    }


    // MARK: - Test Mode Support (For Integration Tests)

    #if DEBUG
    /// Test mode flag - when true, uses injected test data instead of HealthKit
    var testMode: Bool = false

    /// Injected test data (used when testMode = true)
    private var testHeartRate: Double = 75.0
    private var testHRV: Double = 50.0
    private var testBreathingRateValue: Double = 12.0
    private var testCoherence: Double = 50.0
    private var testPermissionsGranted: Bool = true
    private var testError: HealthKitError?

    /// Current heart rate (supports test mode)
    var currentHeartRate: Double {
        return testMode ? testHeartRate : heartRate
    }

    /// Current HRV (supports test mode)
    var currentHRV: Double {
        return testMode ? testHRV : hrvRMSSD
    }

    /// Inject test heart rate data (for integration tests)
    func injectTestHRV(value: Double) {
        testHRV = value
        if testMode {
            Task { @MainActor in
                self.hrvRMSSD = value
            }
        }
    }

    /// Inject test breathing rate (for integration tests)
    func injectTestBreathingRate(rate: Double) {
        testBreathingRateValue = rate
        if testMode {
            Task { @MainActor in
                self.breathingRate = rate
            }
        }
    }

    /// Set test permissions (for integration tests)
    func setTestPermissions(granted: Bool) {
        testPermissionsGranted = granted
        if testMode {
            Task { @MainActor in
                self.isAuthorized = granted
            }
        }
    }

    /// Clear test cache (for integration tests)
    func clearTestCache() {
        if testMode {
            rrIntervalBuffer.removeAll()
        }
    }

    /// Simulate HealthKit error (for integration tests)
    func simulateError(_ error: HealthKitError) {
        testError = error
        if testMode {
            Task { @MainActor in
                self.errorMessage = error.description
            }
        }
    }

    /// Clear simulated error (for integration tests)
    func clearError() {
        testError = nil
        if testMode {
            Task { @MainActor in
                self.errorMessage = nil
            }
        }
    }

    /// Inject mock heart rate (for integration tests)
    func injectMockHeartRate(_ bpm: Double) {
        testHeartRate = bpm
        if testMode {
            Task { @MainActor in
                self.heartRate = bpm
            }
        }
    }
    #endif
}


// MARK: - HealthKit Test Error Types

#if DEBUG
enum HealthKitError: Error, CustomStringConvertible {
    case dataUnavailable
    case permissionDenied
    case queryFailed

    var description: String {
        switch self {
        case .dataUnavailable:
            return "HealthKit data unavailable"
        case .permissionDenied:
            return "HealthKit permission denied"
        case .queryFailed:
            return "HealthKit query failed"
        }
    }
}
#endif
