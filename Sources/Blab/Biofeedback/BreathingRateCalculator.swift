import Foundation
import Accelerate

/// Breathing Rate Calculator from HRV data
/// Uses Heart Rate Variability patterns to estimate respiratory rate
///
/// Techniques:
/// - Time-domain: RMSSD, SDNN analysis
/// - Frequency-domain: High-Frequency (HF) band power (0.15-0.4 Hz)
/// - Peak detection in HRV waveform
/// - Respiratory Sinus Arrhythmia (RSA) analysis
///
/// Typical breathing rates:
/// - Rest: 6-12 breaths/min
/// - Meditation: 4-6 breaths/min
/// - Exercise: 15-25 breaths/min
/// - Stress: 12-20 breaths/min

public final class BreathingRateCalculator {

    // MARK: - Properties

    private var rrIntervals: [Double] = [] // R-R intervals in milliseconds
    private var timestamps: [Date] = []

    private let windowSize: Int = 60 // seconds
    private let minSampleCount: Int = 20 // Minimum R-R intervals needed

    // Breathing rate frequency bands (Hz)
    private let breathingFrequencyRange = (min: 0.12, max: 0.4) // 7-24 breaths/min

    // MARK: - Public Methods

    /// Add a new R-R interval measurement
    public func addRRInterval(_ interval: Double, timestamp: Date = Date()) {
        rrIntervals.append(interval)
        timestamps.append(timestamp)

        // Keep only recent data (within window)
        cleanOldData()
    }

    /// Calculate current breathing rate (breaths per minute)
    public func calculateBreathingRate() -> Double? {
        guard rrIntervals.count >= minSampleCount else {
            return nil // Not enough data
        }

        // Try multiple methods and average results
        var estimates: [Double] = []

        // Method 1: Frequency domain (HF power)
        if let freqEstimate = estimateFromFrequencyDomain() {
            estimates.append(freqEstimate)
        }

        // Method 2: Peak detection in HRV
        if let peakEstimate = estimateFromPeakDetection() {
            estimates.append(peakEstimate)
        }

        // Method 3: RSA analysis
        if let rsaEstimate = estimateFromRSA() {
            estimates.append(rsaEstimate)
        }

        guard !estimates.isEmpty else {
            return nil
        }

        // Return median estimate (robust to outliers)
        let sorted = estimates.sorted()
        let median = sorted[sorted.count / 2]

        return clampBreathingRate(median)
    }

    /// Calculate instantaneous breathing rate from recent data
    public func instantaneousRate() -> Double? {
        guard rrIntervals.count >= 10 else { return nil }

        // Use last 10 intervals
        let recentIntervals = Array(rrIntervals.suffix(10))
        let rate = estimateFromPeakDetection(intervals: recentIntervals)

        return rate.map(clampBreathingRate)
    }

    // MARK: - Frequency Domain Analysis

    /// Estimate breathing rate from HF power spectrum
    private func estimateFromFrequencyDomain() -> Double? {
        guard rrIntervals.count >= 30 else { return nil }

        // Resample to even intervals (required for FFT)
        let resampledData = resampleToEvenIntervals(rrIntervals, targetRate: 4.0) // 4 Hz

        guard resampledData.count >= 64 else { return nil }

        // Perform FFT
        let fftSize = min(256, resampledData.count.nextPowerOfTwo())
        let spectrum = performFFT(resampledData, size: fftSize)

        // Find peak in HF band (0.15-0.4 Hz)
        let sampleRate = 4.0
        let peakFrequency = findPeakFrequency(
            spectrum: spectrum,
            sampleRate: sampleRate,
            minFreq: breathingFrequencyRange.min,
            maxFreq: breathingFrequencyRange.max
        )

        guard let freq = peakFrequency else { return nil }

        // Convert Hz to breaths/min
        return freq * 60.0
    }

    private func performFFT(_ data: [Double], size: Int) -> [Double] {
        var paddedData = data
        while paddedData.count < size {
            paddedData.append(0)
        }
        paddedData = Array(paddedData.prefix(size))

        // Remove DC component
        let mean = paddedData.reduce(0, +) / Double(paddedData.count)
        let centered = paddedData.map { $0 - mean }

        // Apply Hanning window
        let windowed = applyHanningWindow(centered)

        // Perform FFT using Accelerate
        var real = [Double](repeating: 0, count: size)
        var imag = [Double](repeating: 0, count: size)

        for i in 0..<size {
            real[i] = windowed[i]
        }

        var splitComplex = DSPDoubleSplitComplex(realp: &real, imagp: &imag)

        let log2n = vDSP_Length(log2(Double(size)))
        guard let fftSetup = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2)) else {
            return []
        }

        vDSP_fft_zripD(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

        // Calculate magnitude spectrum
        var magnitudes = [Double](repeating: 0, count: size / 2)
        vDSP_zvmagsD(&splitComplex, 1, &magnitudes, 1, vDSP_Length(size / 2))

        vDSP_destroy_fftsetupD(fftSetup)

        return magnitudes
    }

    private func findPeakFrequency(
        spectrum: [Double],
        sampleRate: Double,
        minFreq: Double,
        maxFreq: Double
    ) -> Double? {
        let binWidth = sampleRate / Double(spectrum.count * 2)

        let minBin = Int(minFreq / binWidth)
        let maxBin = min(Int(maxFreq / binWidth), spectrum.count - 1)

        guard minBin < maxBin else { return nil }

        let relevantSpectrum = Array(spectrum[minBin...maxBin])
        guard let maxIndex = relevantSpectrum.indices.max(by: { relevantSpectrum[$0] < relevantSpectrum[$1] }) else {
            return nil
        }

        let peakBin = minBin + maxIndex
        return Double(peakBin) * binWidth
    }

    // MARK: - Peak Detection

    /// Estimate breathing rate from peaks in HRV waveform
    private func estimateFromPeakDetection(intervals: [Double]? = nil) -> Double? {
        let data = intervals ?? rrIntervals
        guard data.count >= 10 else { return nil }

        // Smooth the data
        let smoothed = smoothData(data, windowSize: 3)

        // Find peaks
        let peaks = findPeaks(smoothed, minDistance: 3)

        guard peaks.count >= 2 else { return nil }

        // Calculate average time between peaks
        var peakIntervals: [Double] = []
        for i in 1..<peaks.count {
            let interval = Double(peaks[i] - peaks[i-1])
            peakIntervals.append(interval)
        }

        let avgPeakInterval = peakIntervals.reduce(0, +) / Double(peakIntervals.count)

        // Convert to breaths per minute
        // Assuming each R-R interval is ~1 second (approximate)
        let breathsPerMinute = 60.0 / avgPeakInterval

        return breathsPerMinute
    }

    private func findPeaks(_ data: [Double], minDistance: Int) -> [Int] {
        var peaks: [Int] = []

        for i in minDistance..<(data.count - minDistance) {
            var isPeak = true

            // Check if this point is higher than neighbors
            for j in (i - minDistance)...(i + minDistance) where j != i {
                if data[i] <= data[j] {
                    isPeak = false
                    break
                }
            }

            if isPeak {
                peaks.append(i)
            }
        }

        return peaks
    }

    // MARK: - RSA Analysis

    /// Estimate breathing rate from Respiratory Sinus Arrhythmia pattern
    private func estimateFromRSA() -> Double? {
        guard rrIntervals.count >= 20 else { return nil }

        // Calculate successive differences
        var differences: [Double] = []
        for i in 1..<rrIntervals.count {
            differences.append(rrIntervals[i] - rrIntervals[i-1])
        }

        // Find zero crossings (sign changes)
        var crossings: [Int] = []
        for i in 1..<differences.count {
            if (differences[i] >= 0 && differences[i-1] < 0) ||
               (differences[i] < 0 && differences[i-1] >= 0) {
                crossings.append(i)
            }
        }

        guard crossings.count >= 3 else { return nil }

        // Average interval between crossings
        var intervals: [Double] = []
        for i in 1..<crossings.count {
            intervals.append(Double(crossings[i] - crossings[i-1]))
        }

        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)

        // One breath cycle = 2 crossings (inhale + exhale)
        let breathsPerMinute = 60.0 / (avgInterval * 2.0)

        return breathsPerMinute
    }

    // MARK: - Helper Methods

    private func cleanOldData() {
        let cutoffTime = Date().addingTimeInterval(-Double(windowSize))

        while !timestamps.isEmpty && timestamps.first! < cutoffTime {
            timestamps.removeFirst()
            rrIntervals.removeFirst()
        }
    }

    private func resampleToEvenIntervals(_ data: [Double], targetRate: Double) -> [Double] {
        guard !data.isEmpty else { return [] }

        // Create evenly spaced time series
        let totalDuration = Double(data.count) * (data.reduce(0, +) / Double(data.count)) / 1000.0
        let sampleCount = Int(totalDuration * targetRate)

        var resampled: [Double] = []
        for i in 0..<sampleCount {
            let time = Double(i) / targetRate
            let index = min(Int(time * Double(data.count) / totalDuration), data.count - 1)
            resampled.append(data[index])
        }

        return resampled
    }

    private func smoothData(_ data: [Double], windowSize: Int) -> [Double] {
        var smoothed: [Double] = []

        for i in 0..<data.count {
            let start = max(0, i - windowSize / 2)
            let end = min(data.count, i + windowSize / 2 + 1)

            let window = Array(data[start..<end])
            let avg = window.reduce(0, +) / Double(window.count)
            smoothed.append(avg)
        }

        return smoothed
    }

    private func applyHanningWindow(_ data: [Double]) -> [Double] {
        let n = data.count
        return data.enumerated().map { i, value in
            let window = 0.5 - 0.5 * cos(2.0 * .pi * Double(i) / Double(n - 1))
            return value * window
        }
    }

    private func clampBreathingRate(_ rate: Double) -> Double {
        return max(4.0, min(30.0, rate)) // Clamp to realistic range
    }
}

// MARK: - Extensions

extension Int {
    func nextPowerOfTwo() -> Int {
        var n = self - 1
        n |= n >> 1
        n |= n >> 2
        n |= n >> 4
        n |= n >> 8
        n |= n >> 16
        return n + 1
    }
}

// MARK: - Convenience Integration

extension BreathingRateCalculator {

    /// Create from HealthKit HRV samples
    public static func fromHealthKitSamples(_ samples: [(rrInterval: Double, date: Date)]) -> BreathingRateCalculator {
        let calculator = BreathingRateCalculator()

        for sample in samples {
            calculator.addRRInterval(sample.rrInterval, timestamp: sample.date)
        }

        return calculator
    }

    /// Estimate from simple heart rate (less accurate fallback)
    public static func estimateFromHeartRate(_ bpm: Double) -> Double {
        // Rough approximation: breathing rate ≈ HR / 4
        // This is a very crude estimate and should only be used as last resort
        let estimated = bpm / 4.0
        return max(4.0, min(20.0, estimated))
    }
}
