import Foundation
import Accelerate

/// Breathing Phase Detector using Respiratory Sinus Arrhythmia (RSA) analysis
///
/// **Scientific Basis:**
/// - RSA: Heart rate increases during inhalation, decreases during exhalation
/// - HF HRV band (0.15-0.4 Hz) reflects breathing at 9-24 breaths/min
/// - Peak detection in filtered HRV signal reveals breath cycle phase
/// - Phase normalization: 0.0 = start inhale, 0.5 = start exhale, 1.0 = end cycle
///
/// **References:**
/// - Grossman, P. & Taylor, E.W. (2007). Toward understanding respiratory sinus arrhythmia
/// - Yasuma, F. & Hayano, J. (2004). Respiratory sinus arrhythmia
/// - Hirsch, J.A. & Bishop, B. (1981). Respiratory sinus arrhythmia in humans
/// - Lehrer, P.M. (2013). How does heart rate variability biofeedback work?
final class BreathingPhaseDetector: @unchecked Sendable {

    // MARK: - Breathing Metrics

    /// Current breathing phase (0.0-1.0)
    /// 0.0-0.45: Inhalation
    /// 0.45-0.55: Transition
    /// 0.55-1.0: Exhalation
    private(set) var currentPhase: Double = 0.0

    /// Detected breathing rate (breaths per minute)
    private(set) var breathingRate: Double = 15.0

    /// RSA amplitude (peak-to-trough RR interval difference in ms)
    private(set) var rsaAmplitude: Double = 0.0

    /// Confidence in current breathing detection (0.0-1.0)
    private(set) var confidence: Double = 0.0

    /// Whether currently inhaling
    var isInhaling: Bool {
        currentPhase < 0.5
    }

    /// Whether currently exhaling
    var isExhaling: Bool {
        currentPhase >= 0.5
    }

    // MARK: - Internal State

    /// RR interval buffer for RSA analysis
    private var rrIntervalBuffer: [Double] = []
    private let maxBufferSize = 200 // ~120 seconds at 60 BPM

    /// Filtered RSA signal (HF band extracted)
    private var rsaSignal: [Double] = []

    /// Peak/trough timestamps for phase calculation
    private struct BreathCycle {
        let peakTime: Double      // Time of RR interval peak (inhalation peak)
        let troughTime: Double    // Time of RR interval trough (exhalation trough)
        let peakValue: Double     // Peak RR interval
        let troughValue: Double   // Trough RR interval
    }

    private var recentCycles: [BreathCycle] = []
    private let maxCycles = 10

    /// Timestamp buffer (seconds since start)
    private var timestamps: [Double] = []
    private var startTime: Double?

    /// Current time tracker
    private var currentTime: Double {
        if let start = startTime {
            return Date().timeIntervalSince1970 - start
        } else {
            startTime = Date().timeIntervalSince1970
            return 0.0
        }
    }

    // MARK: - Configuration

    /// Minimum breathing rate (breaths/min) for detection
    private let minBreathingRate: Double = 4.0  // Very slow breathing

    /// Maximum breathing rate (breaths/min) for detection
    private let maxBreathingRate: Double = 30.0 // Very fast breathing

    /// Minimum RSA amplitude (ms) for confident detection
    private let minRSAAmplitude: Double = 20.0

    /// Peak detection threshold (relative to signal std dev)
    private let peakThreshold: Double = 0.5

    // MARK: - Public Methods

    /// Add new RR interval measurement
    /// - Parameter rrInterval: RR interval in milliseconds
    func addRRInterval(_ rrInterval: Double) {
        guard rrInterval > 300 && rrInterval < 2000 else { return } // Physiologically plausible range

        let time = currentTime

        // Add to buffers
        rrIntervalBuffer.append(rrInterval)
        timestamps.append(time)

        // Maintain buffer size
        if rrIntervalBuffer.count > maxBufferSize {
            rrIntervalBuffer.removeFirst()
            timestamps.removeFirst()
        }

        // Process RSA signal if we have enough data
        if rrIntervalBuffer.count >= 30 {
            updateRSASignal()
            detectBreathingCycles()
            updateCurrentPhase()
        }
    }

    /// Reset detector state
    func reset() {
        rrIntervalBuffer.removeAll()
        timestamps.removeAll()
        rsaSignal.removeAll()
        recentCycles.removeAll()
        currentPhase = 0.0
        breathingRate = 15.0
        rsaAmplitude = 0.0
        confidence = 0.0
        startTime = nil
    }

    // MARK: - RSA Signal Processing

    /// Extract RSA signal using band-pass filtering (0.15-0.4 Hz)
    private func updateRSASignal() {
        // Detrend RR intervals
        let detrended = detrend(rrIntervalBuffer)

        // Apply Hamming window
        let windowed = applyHammingWindow(detrended)

        // Perform FFT
        let fftSize = nextPowerOf2(windowed.count)
        let spectrum = performFFT(windowed, fftSize: fftSize)

        // Extract HF band (0.15-0.4 Hz) - respiratory frequency range
        let samplingRate = 1.0 // ~1 Hz (1 RR interval per second)
        let hfLow = 0.15  // 9 breaths/min
        let hfHigh = 0.4  // 24 breaths/min

        let binLow = Int(hfLow * Double(fftSize) / samplingRate)
        let binHigh = Int(hfHigh * Double(fftSize) / samplingRate)

        // Apply band-pass filter (zero out frequencies outside HF band)
        var filteredSpectrum = spectrum
        for i in 0..<filteredSpectrum.count {
            if i < binLow || i > binHigh {
                filteredSpectrum[i] = (real: 0.0, imag: 0.0)
            }
        }

        // Inverse FFT to get filtered time-domain signal
        rsaSignal = performIFFT(filteredSpectrum, fftSize: fftSize)

        // Truncate to original length
        if rsaSignal.count > rrIntervalBuffer.count {
            rsaSignal = Array(rsaSignal.prefix(rrIntervalBuffer.count))
        }
    }

    /// Detect breathing cycles from RSA signal peaks/troughs
    private func detectBreathingCycles() {
        guard rsaSignal.count >= 20 else { return }

        // Calculate signal statistics for peak detection
        let mean = rsaSignal.reduce(0.0, +) / Double(rsaSignal.count)
        let variance = rsaSignal.map { pow($0 - mean, 2) }.reduce(0.0, +) / Double(rsaSignal.count)
        let stdDev = sqrt(variance)

        guard stdDev > 0.0 else { return }

        // Detect peaks (inhalation) and troughs (exhalation)
        var peaks: [(index: Int, value: Double, time: Double)] = []
        var troughs: [(index: Int, value: Double, time: Double)] = []

        for i in 2..<(rsaSignal.count - 2) {
            let value = rsaSignal[i]

            // Peak detection (local maximum above threshold)
            if value > rsaSignal[i-1] && value > rsaSignal[i+1] &&
               value > mean + peakThreshold * stdDev {
                peaks.append((i, value, timestamps[i]))
            }

            // Trough detection (local minimum below threshold)
            if value < rsaSignal[i-1] && value < rsaSignal[i+1] &&
               value < mean - peakThreshold * stdDev {
                troughs.append((i, value, timestamps[i]))
            }
        }

        // Match peaks with troughs to form breath cycles
        var newCycles: [BreathCycle] = []

        for peak in peaks {
            // Find closest following trough
            if let trough = troughs.first(where: { $0.time > peak.time }) {
                let amplitude = abs(peak.value - trough.value)

                // Validate cycle duration (corresponds to reasonable breathing rate)
                let cycleDuration = trough.time - peak.time
                let estimatedRate = 30.0 / cycleDuration // Half-cycle to full-cycle BPM

                if estimatedRate >= minBreathingRate && estimatedRate <= maxBreathingRate {
                    let cycle = BreathCycle(
                        peakTime: peak.time,
                        troughTime: trough.time,
                        peakValue: peak.value,
                        troughValue: trough.value
                    )
                    newCycles.append(cycle)
                }
            }
        }

        // Update recent cycles
        recentCycles.append(contentsOf: newCycles)
        if recentCycles.count > maxCycles {
            recentCycles = Array(recentCycles.suffix(maxCycles))
        }

        // Update metrics
        if let lastCycle = recentCycles.last {
            rsaAmplitude = abs(lastCycle.peakValue - lastCycle.troughValue)

            // Calculate breathing rate from recent cycles
            if recentCycles.count >= 3 {
                let cycleDurations = zip(recentCycles.dropLast(), recentCycles.dropFirst()).map {
                    $1.peakTime - $0.peakTime
                }
                let avgDuration = cycleDurations.reduce(0.0, +) / Double(cycleDurations.count)
                breathingRate = 60.0 / avgDuration // Convert to breaths/min
                breathingRate = max(minBreathingRate, min(maxBreathingRate, breathingRate))
            }

            // Update confidence based on RSA amplitude and cycle consistency
            let amplitudeConfidence = min(1.0, rsaAmplitude / 100.0) // 100ms = max confidence
            let cycleConsistency = recentCycles.count >= 3 ? 1.0 : Double(recentCycles.count) / 3.0
            confidence = amplitudeConfidence * cycleConsistency
        }
    }

    /// Update current breathing phase based on most recent cycle
    private func updateCurrentPhase() {
        guard let lastCycle = recentCycles.last else {
            currentPhase = 0.0
            return
        }

        let time = currentTime

        // Calculate phase based on position within current breath cycle
        let cycleDuration = (lastCycle.troughTime - lastCycle.peakTime) * 2.0 // Full cycle

        if time >= lastCycle.peakTime && time <= lastCycle.troughTime {
            // Within inhalation to exhalation transition (0.0 - 0.5)
            let elapsed = time - lastCycle.peakTime
            let halfCycle = lastCycle.troughTime - lastCycle.peakTime
            currentPhase = 0.5 * (elapsed / halfCycle)
        } else if time > lastCycle.troughTime {
            // Within exhalation to next inhalation (0.5 - 1.0)
            let elapsed = time - lastCycle.troughTime
            let halfCycle = lastCycle.troughTime - lastCycle.peakTime
            currentPhase = 0.5 + 0.5 * (elapsed / halfCycle)

            // Wrap around if beyond full cycle
            if currentPhase >= 1.0 {
                currentPhase = 0.0
            }
        } else {
            // Before current cycle peak (use previous cycle if available)
            if recentCycles.count >= 2 {
                let prevCycle = recentCycles[recentCycles.count - 2]
                let elapsed = time - prevCycle.troughTime
                let halfCycle = prevCycle.troughTime - prevCycle.peakTime
                currentPhase = 0.5 + 0.5 * (elapsed / halfCycle)

                if currentPhase >= 1.0 {
                    currentPhase = 0.0
                }
            }
        }
    }

    // MARK: - Signal Processing Utilities

    /// Detrend signal (remove linear trend)
    private func detrend(_ data: [Double]) -> [Double] {
        let n = Double(data.count)
        guard n > 1 else { return data }

        let xSum = (0..<data.count).reduce(0.0) { $0 + Double($1) }
        let ySum = data.reduce(0.0, +)
        let xySum = data.enumerated().reduce(0.0) { $0 + Double($1.offset) * $1.element }
        let xxSum = (0..<data.count).reduce(0.0) { $0 + Double($1 * $1) }

        let slope = (n * xySum - xSum * ySum) / (n * xxSum - xSum * xSum)
        let intercept = (ySum - slope * xSum) / n

        return data.enumerated().map { index, value in
            value - (slope * Double(index) + intercept)
        }
    }

    /// Apply Hamming window
    private func applyHammingWindow(_ data: [Double]) -> [Double] {
        let n = data.count
        var windowed = [Double](repeating: 0, count: n)

        for i in 0..<n {
            let window = 0.54 - 0.46 * cos(2.0 * .pi * Double(i) / Double(n - 1))
            windowed[i] = data[i] * window
        }

        return windowed
    }

    /// Perform FFT and return complex spectrum
    private func performFFT(_ data: [Double], fftSize: Int) -> [(real: Double, imag: Double)] {
        var realParts = [Float](repeating: 0, count: fftSize)
        for i in 0..<min(data.count, fftSize) {
            realParts[i] = Float(data[i])
        }
        var imagParts = [Float](repeating: 0, count: fftSize)

        guard let fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            vDSP_DFT_Direction.FORWARD
        ) else {
            return []
        }

        defer { vDSP_DFT_DestroySetup(fftSetup) }

        vDSP_DFT_Execute(fftSetup, &realParts, &imagParts, &realParts, &imagParts)

        return (0..<fftSize).map { (real: Double(realParts[$0]), imag: Double(imagParts[$0])) }
    }

    /// Perform inverse FFT
    private func performIFFT(_ spectrum: [(real: Double, imag: Double)], fftSize: Int) -> [Double] {
        var realParts = spectrum.map { Float($0.real) }
        var imagParts = spectrum.map { Float($0.imag) }

        guard let fftSetup = vDSP_DFT_zop_CreateSetup(
            nil,
            vDSP_Length(fftSize),
            vDSP_DFT_Direction.INVERSE
        ) else {
            return []
        }

        defer { vDSP_DFT_DestroySetup(fftSetup) }

        vDSP_DFT_Execute(fftSetup, &realParts, &imagParts, &realParts, &imagParts)

        // Normalize by FFT size
        let scale = 1.0 / Float(fftSize)
        return realParts.map { Double($0 * scale) }
    }

    /// Next power of 2
    private func nextPowerOf2(_ n: Int) -> Int {
        var power = 1
        while power < n {
            power *= 2
        }
        return power
    }

    // MARK: - Descriptive Properties

    /// Get breathing state description
    var breathingStateDescription: String {
        if isInhaling {
            return "Inhaling"
        } else if isExhaling {
            return "Exhaling"
        } else {
            return "Transition"
        }
    }

    /// Get comprehensive breathing analysis
    var breathingAnalysisSummary: String {
        """
        Breathing Phase Analysis:
          Phase: \(String(format: "%.2f", currentPhase)) (\(breathingStateDescription))
          Rate: \(String(format: "%.1f", breathingRate)) breaths/min
          RSA Amplitude: \(String(format: "%.1f", rsaAmplitude)) ms
          Confidence: \(String(format: "%.0f", confidence * 100))%
          Detected Cycles: \(recentCycles.count)
        """
    }
}
