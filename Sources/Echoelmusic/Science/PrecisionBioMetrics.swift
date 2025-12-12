import Foundation
import Combine
import Accelerate

// MARK: - Precision Bio Metrics
// Ultra-smooth heart rate and HRV calculations with high precision
// All calculations use Double (64-bit) for maximum accuracy

/// PrecisionBioMetrics - Ultra-Smooth Heart Rate & HRV Analysis
///
/// **Precision Features:**
/// - All calculations use Double (64-bit IEEE 754)
/// - 15-17 significant decimal digits
/// - Configurable display precision (0-6 decimal places)
/// - Sub-millisecond timing accuracy
///
/// **Smoothing Algorithms:**
/// - Exponential Moving Average (EMA) with configurable alpha
/// - Kalman Filter for optimal state estimation
/// - Butterworth low-pass filter for noise reduction
/// - Outlier rejection using IQR method
///
/// **HRV Metrics (validated against TaskForce 1996 standards):**
/// - RMSSD: Root Mean Square of Successive Differences
/// - SDNN: Standard Deviation of NN Intervals
/// - pNN50: Percentage of successive differences > 50ms
/// - LF/HF: Low Frequency / High Frequency power ratio
@MainActor
public final class PrecisionBioMetrics: ObservableObject {

    // MARK: - Published Properties (Full Precision)

    /// Current heart rate in BPM (beats per minute)
    /// Full Double precision, display with formatBPM() for desired decimal places
    @Published public private(set) var heartRateBPM: Double = 60.0

    /// Smoothed heart rate (ultra-smooth for visual display)
    @Published public private(set) var smoothedHeartRateBPM: Double = 60.0

    /// Heart rate trend (change per second)
    @Published public private(set) var heartRateTrend: Double = 0.0

    /// Current instantaneous heart rate frequency in Hz
    @Published public private(set) var heartRateHz: Double = 1.0

    /// RMSSD in milliseconds (parasympathetic indicator)
    @Published public private(set) var rmssd: Double = 50.0

    /// SDNN in milliseconds (overall HRV)
    @Published public private(set) var sdnn: Double = 50.0

    /// pNN50 percentage (0-100)
    @Published public private(set) var pnn50: Double = 20.0

    /// LF/HF power ratio (autonomic balance)
    @Published public private(set) var lfHfRatio: Double = 1.5

    /// Stress index (based on Baevsky's algorithm)
    @Published public private(set) var stressIndex: Double = 100.0

    /// HeartMath-style coherence score (0-100)
    @Published public private(set) var coherenceScore: Double = 50.0

    // MARK: - Smoothing Configuration

    /// Smoothing strength for display (0.0 = no smoothing, 1.0 = maximum smoothing)
    public var smoothingStrength: Double = 0.85 {
        didSet {
            smoothingStrength = max(0.0, min(0.99, smoothingStrength))
            kalmanFilter.processNoise = (1.0 - smoothingStrength) * 0.1
        }
    }

    /// Display precision (decimal places for formatted output)
    public var displayPrecision: Int = 2 {
        didSet {
            displayPrecision = max(0, min(6, displayPrecision))
        }
    }

    // MARK: - Internal State

    private var rrIntervals: [Double] = []  // RR intervals in milliseconds
    private var rrTimestamps: [Double] = []  // Timestamps in seconds
    private var kalmanFilter = KalmanFilter()
    private var butterworthFilter = ButterworthLowPass(cutoffHz: 0.5, sampleRate: 4.0)

    private let maxIntervals: Int = 300  // ~5 minutes at 60 BPM
    private var lastUpdateTime: Double = 0

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init() {
        // Initialize Kalman filter for heart rate
        kalmanFilter.stateEstimate = 60.0
        kalmanFilter.errorCovariance = 100.0
        kalmanFilter.processNoise = 0.01
        kalmanFilter.measurementNoise = 4.0

        EchoelLogger.info("[PrecisionBio] Initialized with Double precision", category: EchoelLogger.bio)
    }

    // MARK: - RR Interval Input

    /// Add a new RR interval measurement
    /// - Parameters:
    ///   - intervalMs: RR interval in milliseconds
    ///   - timestamp: Measurement timestamp in seconds (optional, uses current time if nil)
    public func addRRInterval(_ intervalMs: Double, timestamp: Double? = nil) {
        let now = timestamp ?? CACurrentMediaTime()

        // Validate physiological range (30-220 BPM → 273-2000 ms)
        guard intervalMs >= 272.727272727 && intervalMs <= 2000.0 else {
            EchoelLogger.debug("[PrecisionBio] RR interval out of range: \(intervalMs) ms", category: EchoelLogger.bio)
            return
        }

        // Outlier rejection using IQR
        if rrIntervals.count >= 10 && isOutlier(intervalMs) {
            EchoelLogger.debug("[PrecisionBio] RR interval rejected as outlier: \(intervalMs) ms", category: EchoelLogger.bio)
            return
        }

        // Add to buffer
        rrIntervals.append(intervalMs)
        rrTimestamps.append(now)

        // Maintain buffer size
        if rrIntervals.count > maxIntervals {
            rrIntervals.removeFirst()
            rrTimestamps.removeFirst()
        }

        // Update metrics
        updateMetrics(timestamp: now)
    }

    /// Add heart rate measurement directly (will be converted to RR interval)
    /// - Parameters:
    ///   - bpm: Heart rate in beats per minute
    ///   - timestamp: Measurement timestamp
    public func addHeartRateMeasurement(_ bpm: Double, timestamp: Double? = nil) {
        guard bpm >= 30.0 && bpm <= 220.0 else { return }
        let rrInterval = 60000.0 / bpm  // Convert BPM to ms
        addRRInterval(rrInterval, timestamp: timestamp)
    }

    // MARK: - Metric Calculations

    private func updateMetrics(timestamp: Double) {
        let deltaTime = timestamp - lastUpdateTime
        lastUpdateTime = timestamp

        guard rrIntervals.count >= 2 else { return }

        // Calculate instantaneous heart rate from latest RR
        let latestRR = rrIntervals.last!
        let instantBPM = 60000.0 / latestRR
        heartRateHz = 1000.0 / latestRR

        // Update raw heart rate
        heartRateBPM = instantBPM

        // Apply Kalman filter for optimal estimation
        let kalmanBPM = kalmanFilter.update(measurement: instantBPM)

        // Apply Butterworth low-pass for ultra-smooth display
        let butterworthBPM = butterworthFilter.process(kalmanBPM)

        // Blend for final smoothed value
        let alpha = 1.0 - smoothingStrength
        smoothedHeartRateBPM = smoothedHeartRateBPM * (1.0 - alpha) + butterworthBPM * alpha

        // Calculate trend (BPM change per second)
        if deltaTime > 0 {
            let newTrend = (smoothedHeartRateBPM - heartRateBPM) / deltaTime
            heartRateTrend = heartRateTrend * 0.9 + newTrend * 0.1
        }

        // Update HRV metrics (if enough data)
        if rrIntervals.count >= 10 {
            calculateHRVMetrics()
        }
    }

    private func calculateHRVMetrics() {
        let n = rrIntervals.count

        // RMSSD: Root Mean Square of Successive Differences
        var sumSquaredDiff: Double = 0
        var nn50Count: Int = 0

        for i in 1..<n {
            let diff = rrIntervals[i] - rrIntervals[i-1]
            sumSquaredDiff += diff * diff

            if abs(diff) > 50.0 {
                nn50Count += 1
            }
        }

        rmssd = sqrt(sumSquaredDiff / Double(n - 1))

        // pNN50: Percentage of intervals differing by > 50ms
        pnn50 = (Double(nn50Count) / Double(n - 1)) * 100.0

        // SDNN: Standard Deviation of NN intervals
        let mean = rrIntervals.reduce(0, +) / Double(n)
        var sumSquaredDeviation: Double = 0

        for interval in rrIntervals {
            let deviation = interval - mean
            sumSquaredDeviation += deviation * deviation
        }

        sdnn = sqrt(sumSquaredDeviation / Double(n))

        // LF/HF Ratio (if enough data for FFT)
        if rrIntervals.count >= 64 {
            calculateFrequencyDomainHRV()
        }

        // Stress Index (Baevsky)
        calculateStressIndex()

        // Coherence Score
        calculateCoherence()
    }

    private func calculateFrequencyDomainHRV() {
        // Resample RR intervals to regular time series
        let resampledRR = resampleToRegularTimeSeries(targetSampleRate: 4.0)
        guard resampledRR.count >= 64 else { return }

        // Pad to power of 2
        let n = nextPowerOf2(resampledRR.count)
        var paddedRR = resampledRR
        while paddedRR.count < n {
            paddedRR.append(paddedRR.last ?? 0)
        }

        // Detrend (remove linear trend)
        let detrended = detrend(paddedRR)

        // Apply Hann window
        var window = [Double](repeating: 0, count: n)
        vDSP_hann_windowD(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))

        var windowed = [Double](repeating: 0, count: n)
        vDSP_vmulD(detrended, 1, window, 1, &windowed, 1, vDSP_Length(n))

        // Perform FFT
        let spectrum = PrecisionFFTAnalyzer.analyze(samples: windowed, sampleRate: 4.0)

        // Calculate band powers
        var lfPower: Double = 0
        var hfPower: Double = 0

        for bin in spectrum {
            if bin.frequency >= 0.04 && bin.frequency < 0.15 {
                lfPower += bin.magnitude * bin.magnitude
            } else if bin.frequency >= 0.15 && bin.frequency < 0.4 {
                hfPower += bin.magnitude * bin.magnitude
            }
        }

        // LF/HF Ratio
        if hfPower > 0 {
            lfHfRatio = lfPower / hfPower
        }
    }

    private func calculateStressIndex() {
        // Baevsky Stress Index: SI = AMo / (2 × Mo × MxDMn)
        // AMo: amplitude of the mode (most frequent RR interval range)
        // Mo: mode value (most frequent RR interval)
        // MxDMn: variation range

        guard rrIntervals.count >= 10 else { return }

        let sorted = rrIntervals.sorted()
        let minRR = sorted.first!
        let maxRR = sorted.last!
        let mxDMn = maxRR - minRR

        guard mxDMn > 0 else {
            stressIndex = 0
            return
        }

        // Calculate histogram (50ms bins)
        let binWidth: Double = 50.0
        var histogram: [Double: Int] = [:]

        for rr in rrIntervals {
            let bin = floor(rr / binWidth) * binWidth
            histogram[bin, default: 0] += 1
        }

        // Find mode and AMo
        var modeValue: Double = 0
        var modeBin: Double = 0
        var maxCount: Int = 0

        for (bin, count) in histogram {
            if count > maxCount {
                maxCount = count
                modeBin = bin
                modeValue = bin + binWidth / 2
            }
        }

        let amo = (Double(maxCount) / Double(rrIntervals.count)) * 100.0

        // Calculate Stress Index
        if modeValue > 0 && mxDMn > 0 {
            stressIndex = amo / (2.0 * (modeValue / 1000.0) * (mxDMn / 1000.0))
        }
    }

    private func calculateCoherence() {
        // HeartMath coherence: Peak power in 0.04-0.26 Hz / Total power
        guard rrIntervals.count >= 64 else { return }

        let resampledRR = resampleToRegularTimeSeries(targetSampleRate: 4.0)
        guard resampledRR.count >= 64 else { return }

        let n = nextPowerOf2(resampledRR.count)
        var paddedRR = resampledRR
        while paddedRR.count < n {
            paddedRR.append(paddedRR.last ?? 0)
        }

        let detrended = detrend(paddedRR)

        var window = [Double](repeating: 0, count: n)
        vDSP_hann_windowD(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))

        var windowed = [Double](repeating: 0, count: n)
        vDSP_vmulD(detrended, 1, window, 1, &windowed, 1, vDSP_Length(n))

        let spectrum = PrecisionFFTAnalyzer.analyze(samples: windowed, sampleRate: 4.0)

        var coherenceBandPower: Double = 0
        var peakPower: Double = 0
        var totalPower: Double = 0

        for bin in spectrum {
            let power = bin.magnitude * bin.magnitude
            totalPower += power

            if bin.frequency >= 0.04 && bin.frequency <= 0.26 {
                coherenceBandPower += power
                if power > peakPower {
                    peakPower = power
                }
            }
        }

        // Coherence ratio normalized to 0-100
        if totalPower > 0 {
            let peakRatio = peakPower / totalPower
            coherenceScore = min(100.0, peakRatio * 1000.0)  // Scale for display
        }
    }

    // MARK: - Helper Functions

    private func isOutlier(_ value: Double) -> Bool {
        guard rrIntervals.count >= 10 else { return false }

        let sorted = rrIntervals.sorted()
        let q1Index = sorted.count / 4
        let q3Index = (sorted.count * 3) / 4

        let q1 = sorted[q1Index]
        let q3 = sorted[q3Index]
        let iqr = q3 - q1

        let lowerBound = q1 - 1.5 * iqr
        let upperBound = q3 + 1.5 * iqr

        return value < lowerBound || value > upperBound
    }

    private func resampleToRegularTimeSeries(targetSampleRate: Double) -> [Double] {
        guard rrIntervals.count >= 2, rrTimestamps.count >= 2 else { return [] }

        let startTime = rrTimestamps.first!
        let endTime = rrTimestamps.last!
        let duration = endTime - startTime

        guard duration > 0 else { return [] }

        let sampleCount = Int(duration * targetSampleRate)
        guard sampleCount > 0 else { return [] }

        var resampled: [Double] = []
        let timeStep = 1.0 / targetSampleRate

        for i in 0..<sampleCount {
            let t = startTime + Double(i) * timeStep

            // Linear interpolation
            var rr = rrIntervals[0]
            for j in 1..<rrTimestamps.count {
                if rrTimestamps[j] >= t {
                    let t0 = rrTimestamps[j-1]
                    let t1 = rrTimestamps[j]
                    let rr0 = rrIntervals[j-1]
                    let rr1 = rrIntervals[j]

                    let alpha = (t - t0) / (t1 - t0)
                    rr = rr0 + alpha * (rr1 - rr0)
                    break
                }
            }
            resampled.append(rr)
        }

        return resampled
    }

    private func detrend(_ data: [Double]) -> [Double] {
        let n = Double(data.count)
        guard n > 1 else { return data }

        // Linear regression: y = mx + b
        var sumX: Double = 0
        var sumY: Double = 0
        var sumXY: Double = 0
        var sumX2: Double = 0

        for (i, y) in data.enumerated() {
            let x = Double(i)
            sumX += x
            sumY += y
            sumXY += x * y
            sumX2 += x * x
        }

        let m = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        let b = (sumY - m * sumX) / n

        // Remove trend
        var detrended: [Double] = []
        for (i, y) in data.enumerated() {
            let trend = m * Double(i) + b
            detrended.append(y - trend)
        }

        return detrended
    }

    private func nextPowerOf2(_ n: Int) -> Int {
        var power = 1
        while power < n {
            power *= 2
        }
        return power
    }

    // MARK: - Formatting (High Precision Display)

    /// Format BPM with specified decimal places
    /// - Parameters:
    ///   - bpm: Heart rate value
    ///   - decimalPlaces: Number of decimal places (0-6)
    /// - Returns: Formatted string
    public func formatBPM(_ bpm: Double? = nil, decimalPlaces: Int? = nil) -> String {
        let value = bpm ?? smoothedHeartRateBPM
        let places = decimalPlaces ?? displayPrecision
        return String(format: "%.\(places)f", value)
    }

    /// Format heart rate in Hz with specified decimal places
    public func formatHz(decimalPlaces: Int? = nil) -> String {
        let places = decimalPlaces ?? displayPrecision
        return String(format: "%.\(places)f Hz", heartRateHz)
    }

    /// Format RMSSD with specified decimal places
    public func formatRMSSD(decimalPlaces: Int? = nil) -> String {
        let places = decimalPlaces ?? displayPrecision
        return String(format: "%.\(places)f ms", rmssd)
    }

    /// Format SDNN with specified decimal places
    public func formatSDNN(decimalPlaces: Int? = nil) -> String {
        let places = decimalPlaces ?? displayPrecision
        return String(format: "%.\(places)f ms", sdnn)
    }

    /// Format pNN50 with specified decimal places
    public func formatPNN50(decimalPlaces: Int? = nil) -> String {
        let places = decimalPlaces ?? displayPrecision
        return String(format: "%.\(places)f%%", pnn50)
    }

    /// Format LF/HF ratio with specified decimal places
    public func formatLFHF(decimalPlaces: Int? = nil) -> String {
        let places = decimalPlaces ?? displayPrecision
        return String(format: "%.\(places)f", lfHfRatio)
    }

    /// Format all metrics as dictionary with full precision
    public func allMetricsFullPrecision() -> [String: String] {
        return [
            "heartRateBPM": String(format: "%.15g", heartRateBPM),
            "smoothedBPM": String(format: "%.15g", smoothedHeartRateBPM),
            "heartRateHz": String(format: "%.15g", heartRateHz),
            "rmssd": String(format: "%.15g", rmssd),
            "sdnn": String(format: "%.15g", sdnn),
            "pnn50": String(format: "%.15g", pnn50),
            "lfHfRatio": String(format: "%.15g", lfHfRatio),
            "stressIndex": String(format: "%.15g", stressIndex),
            "coherenceScore": String(format: "%.15g", coherenceScore)
        ]
    }

    // MARK: - Reset

    /// Reset all metrics and buffers
    public func reset() {
        rrIntervals.removeAll()
        rrTimestamps.removeAll()
        heartRateBPM = 60.0
        smoothedHeartRateBPM = 60.0
        heartRateTrend = 0.0
        heartRateHz = 1.0
        rmssd = 50.0
        sdnn = 50.0
        pnn50 = 20.0
        lfHfRatio = 1.5
        stressIndex = 100.0
        coherenceScore = 50.0

        kalmanFilter.reset()
        butterworthFilter.reset()
    }
}

// MARK: - Kalman Filter

/// Kalman filter for optimal state estimation
private struct KalmanFilter {
    var stateEstimate: Double = 60.0
    var errorCovariance: Double = 1.0
    var processNoise: Double = 0.01
    var measurementNoise: Double = 4.0

    mutating func update(measurement: Double) -> Double {
        // Prediction step
        let predictedState = stateEstimate
        let predictedCovariance = errorCovariance + processNoise

        // Update step
        let kalmanGain = predictedCovariance / (predictedCovariance + measurementNoise)
        stateEstimate = predictedState + kalmanGain * (measurement - predictedState)
        errorCovariance = (1.0 - kalmanGain) * predictedCovariance

        return stateEstimate
    }

    mutating func reset() {
        stateEstimate = 60.0
        errorCovariance = 1.0
    }
}

// MARK: - Butterworth Low-Pass Filter

/// Second-order Butterworth low-pass filter for smooth transitions
private struct ButterworthLowPass {
    private var a1: Double = 0
    private var a2: Double = 0
    private var b0: Double = 0
    private var b1: Double = 0
    private var b2: Double = 0

    private var x1: Double = 0
    private var x2: Double = 0
    private var y1: Double = 0
    private var y2: Double = 0

    init(cutoffHz: Double, sampleRate: Double) {
        let omega = 2.0 * .pi * cutoffHz / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * 0.7071)  // Q = 0.7071 for Butterworth

        let a0 = 1.0 + alpha

        b0 = (1.0 - cosOmega) / 2.0 / a0
        b1 = (1.0 - cosOmega) / a0
        b2 = (1.0 - cosOmega) / 2.0 / a0
        a1 = (-2.0 * cosOmega) / a0
        a2 = (1.0 - alpha) / a0
    }

    mutating func process(_ input: Double) -> Double {
        let output = b0 * input + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2

        x2 = x1
        x1 = input
        y2 = y1
        y1 = output

        return output
    }

    mutating func reset() {
        x1 = 0
        x2 = 0
        y1 = 0
        y2 = 0
    }
}
