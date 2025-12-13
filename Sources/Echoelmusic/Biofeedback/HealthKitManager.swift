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

    /// Estimated breathing rate in breaths per minute
    /// Calculated from respiratory sinus arrhythmia (RSA) component of HRV
    /// Normal range: 12-20 breaths/min (lower during relaxation)
    @Published var breathingRate: Double = 15.0

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

                // Calculate coherence and breathing rate from buffered RR intervals
                if self.rrIntervalBuffer.count >= 30 { // Need minimum data
                    self.hrvCoherence = self.calculateCoherence(rrIntervals: self.rrIntervalBuffer)
                    self.breathingRate = self.calculateBreathingRate(rrIntervals: self.rrIntervalBuffer)
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

    /// Calculate breathing rate from respiratory sinus arrhythmia (RSA)
    /// RSA is the natural variation in heart rate during breathing
    /// Peak frequency in the HF band (0.15-0.4 Hz) corresponds to breathing rate
    ///
    /// - Parameter rrIntervals: Array of RR intervals in milliseconds
    /// - Returns: Estimated breathing rate in breaths per minute
    func calculateBreathingRate(rrIntervals: [Double]) -> Double {
        guard rrIntervals.count >= 30 else { return 15.0 } // Default if insufficient data

        // Detrend and window the data
        let detrended = detrend(rrIntervals)
        let windowed = applyHammingWindow(detrended)

        // Perform FFT
        let fftSize = nextPowerOf2(windowed.count)
        let powerSpectrum = performFFTForCoherence(windowed, fftSize: fftSize)

        // Respiratory band: 0.15-0.4 Hz (9-24 breaths/min)
        // HF band in HRV analysis corresponds to respiratory modulation
        let samplingRate = 1.0 // 1 RR interval per second approximation
        let respiratoryBandLow = 0.15  // Hz (~9 breaths/min)
        let respiratoryBandHigh = 0.4   // Hz (~24 breaths/min)

        let binLow = max(1, Int(respiratoryBandLow * Double(fftSize) / samplingRate))
        let binHigh = min(fftSize / 2 - 1, Int(respiratoryBandHigh * Double(fftSize) / samplingRate))

        guard binLow < binHigh && binHigh < powerSpectrum.count else { return 15.0 }

        // Find peak frequency in respiratory band
        var peakBin = binLow
        var peakPower: Double = 0.0

        for bin in binLow...binHigh {
            if powerSpectrum[bin] > peakPower {
                peakPower = powerSpectrum[bin]
                peakBin = bin
            }
        }

        // Convert bin to frequency, then to breaths per minute
        let peakFrequency = Double(peakBin) * samplingRate / Double(fftSize)
        let breathsPerMinute = peakFrequency * 60.0

        // Clamp to physiological range (6-30 breaths/min)
        return min(max(breathsPerMinute, 6.0), 30.0)
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


    // MARK: - HKHeartbeatSeriesSample Support (Actual RR Intervals)

    /// Start monitoring actual RR intervals using HKHeartbeatSeriesSample
    /// Available on watchOS and iOS with Apple Watch
    @available(iOS 13.0, watchOS 6.0, *)
    func startHeartbeatSeriesMonitoring() {
        guard isAuthorized else { return }

        guard let heartbeatType = HKObjectType.seriesType(forIdentifier: HKDataTypeIdentifierHeartbeatSeries.self) else {
            print("⚠️ Heartbeat series not available")
            return
        }

        let query = HKAnchoredObjectQuery(
            type: heartbeatType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] _, samples, _, _, error in
            guard let self = self, error == nil else { return }
            self.processHeartbeatSeries(samples)
        }

        query.updateHandler = { [weak self] _, samples, _, _, error in
            guard let self = self, error == nil else { return }
            self.processHeartbeatSeries(samples)
        }

        healthStore.execute(query)
    }

    /// Process heartbeat series to extract actual RR intervals
    private func processHeartbeatSeries(_ samples: [HKSample]?) {
        guard let series = samples as? [HKHeartbeatSeriesSample] else { return }

        for sample in series {
            let query = HKHeartbeatSeriesQuery(heartbeatSeries: sample) { [weak self] _, time, precedes, done, error in
                guard let self = self, error == nil else { return }

                if !precedes {
                    // This is an actual heartbeat with time since last beat
                    let rrInterval = time * 1000  // Convert to milliseconds
                    self.addRRInterval(rrInterval)

                    Task { @MainActor in
                        if self.rrIntervalBuffer.count >= 30 {
                            self.hrvCoherence = self.calculateCoherence(rrIntervals: self.rrIntervalBuffer)
                            self.breathingRate = self.calculateBreathingRate(rrIntervals: self.rrIntervalBuffer)
                            self.hrvRMSSD = self.calculateRMSSD(rrIntervals: self.rrIntervalBuffer)
                        }
                    }
                }
            }
            healthStore.execute(query)
        }
    }

    /// Calculate RMSSD from actual RR intervals
    /// RMSSD = Root Mean Square of Successive Differences
    /// Formula: sqrt(mean((RR[i+1] - RR[i])²))
    func calculateRMSSD(rrIntervals: [Double]) -> Double {
        guard rrIntervals.count > 1 else { return 0.0 }

        var sumSquaredDiff: Double = 0.0
        for i in 0..<(rrIntervals.count - 1) {
            let diff = rrIntervals[i + 1] - rrIntervals[i]
            sumSquaredDiff += diff * diff
        }

        let meanSquaredDiff = sumSquaredDiff / Double(rrIntervals.count - 1)
        return sqrt(meanSquaredDiff)
    }

    // MARK: - Background Delivery

    /// Enable background delivery for heart rate updates
    func enableBackgroundDelivery() async throws {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return
        }

        try await healthStore.enableBackgroundDelivery(
            for: heartRateType,
            frequency: .immediate
        )

        print("✅ Background delivery enabled for heart rate")
    }

    /// Disable background delivery
    func disableBackgroundDelivery() async throws {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return
        }

        try await healthStore.disableBackgroundDelivery(for: heartRateType)
        print("⏹️ Background delivery disabled")
    }

    // MARK: - Fetch Historical Data

    /// Fetch heart rate samples from a specific time range
    /// - Parameters:
    ///   - startDate: Start of the time range
    ///   - endDate: End of the time range
    /// - Returns: Array of heart rate samples with timestamps
    func fetchHeartRateSamples(from startDate: Date, to endDate: Date) async throws -> [(date: Date, bpm: Double)] {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let results = quantitySamples.map { sample -> (date: Date, bpm: Double) in
                    let bpm = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    return (date: sample.startDate, bpm: bpm)
                }

                continuation.resume(returning: results)
            }

            healthStore.execute(query)
        }
    }

    /// Fetch HRV samples from a specific time range
    /// - Parameters:
    ///   - startDate: Start of the time range
    ///   - endDate: End of the time range
    /// - Returns: Array of HRV samples (SDNN in ms) with timestamps
    func fetchHRVSamples(from startDate: Date, to endDate: Date) async throws -> [(date: Date, sdnn: Double)] {
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let results = quantitySamples.map { sample -> (date: Date, sdnn: Double) in
                    let sdnn = sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                    return (date: sample.startDate, sdnn: sdnn)
                }

                continuation.resume(returning: results)
            }

            healthStore.execute(query)
        }
    }

    // MARK: - Statistics

    /// Get average heart rate for today
    func getTodayAverageHeartRate() async throws -> Double? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let samples = try await fetchHeartRateSamples(from: startOfDay, to: Date())

        guard !samples.isEmpty else { return nil }

        let sum = samples.reduce(0.0) { $0 + $1.bpm }
        return sum / Double(samples.count)
    }

    /// Get average HRV for today
    func getTodayAverageHRV() async throws -> Double? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let samples = try await fetchHRVSamples(from: startOfDay, to: Date())

        guard !samples.isEmpty else { return nil }

        let sum = samples.reduce(0.0) { $0 + $1.sdnn }
        return sum / Double(samples.count)
    }

    // MARK: - Integration with EchoelLife

    /// Sync current bio state to EchoelLife
    func syncToEchoelLife() {
        Task { @MainActor in
            EchoelLife.shared.updateBioData(
                heartRate: Float(heartRate),
                hrv: Float(hrvRMSSD),
                coherence: Float(hrvCoherence / 100.0),  // Normalize to 0-1
                breathingRate: Float(breathingRate)
            )
        }
    }

    // MARK: - Cleanup

    deinit {
        stopMonitoring()
    }
}
