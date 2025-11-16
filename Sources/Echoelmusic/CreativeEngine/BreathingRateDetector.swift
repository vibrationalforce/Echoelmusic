import Foundation
import Combine

/// Detects breathing rate from HRV data using spectral analysis
/// Breathing causes rhythmic variations in heart rate (Respiratory Sinus Arrhythmia)
///
/// **Algorithm:**
/// - Analyzes HRV time series for periodic patterns
/// - Typical breathing rates: 4-20 breaths/minute
/// - Uses FFT to detect dominant frequency
///
/// **Usage:**
/// ```swift
/// let detector = BreathingRateDetector()
/// detector.startDetection(healthKitManager: healthKitManager)
/// print(detector.currentBreathingRate) // e.g., 12.5 BPM
/// ```
@MainActor
public class BreathingRateDetector: ObservableObject {

    // MARK: - Published State

    /// Current estimated breathing rate (breaths per minute)
    @Published public private(set) var currentBreathingRate: Double = 12.0

    /// Confidence in the breathing rate estimate (0.0 - 1.0)
    @Published public private(set) var confidence: Double = 0.0

    /// Whether detection is active
    @Published public private(set) var isDetecting: Bool = false

    // MARK: - Private State

    private var hrvHistory: [Double] = []
    private let maxHistorySize = 60 // 60 seconds at 1 Hz
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Breathing Rate Ranges

    private let minBreathingRate: Double = 4.0   // Very slow (meditation)
    private let maxBreathingRate: Double = 30.0  // Very fast (hyperventilation)
    private let normalBreathingRate: Double = 12.0 // Default/resting

    // MARK: - Public Methods

    /// Start breathing rate detection
    public func startDetection(healthKitManager: HealthKitManager?) {
        guard !isDetecting else { return }
        guard let healthKitManager = healthKitManager else {
            print("⚠️ BreathingRateDetector: No HealthKitManager provided")
            return
        }

        isDetecting = true
        hrvHistory.removeAll()

        // Observe HRV changes
        healthKitManager.$hrvRMSSD
            .sink { [weak self] hrvRMSSD in
                self?.addHRVSample(hrvRMSSD)
            }
            .store(in: &cancellables)

        // Update breathing rate estimate every 5 seconds
        updateTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateBreathingRate()
            }
        }

        print("🫁 BreathingRateDetector: Detection started")
    }

    /// Stop detection
    public func stopDetection() {
        isDetecting = false
        updateTimer?.invalidate()
        updateTimer = nil
        cancellables.removeAll()

        print("🫁 BreathingRateDetector: Detection stopped")
    }

    // MARK: - Private Methods

    private func addHRVSample(_ hrv: Double) {
        guard hrv > 0 else { return }

        hrvHistory.append(hrv)

        // Keep only recent history
        if hrvHistory.count > maxHistorySize {
            hrvHistory.removeFirst()
        }
    }

    private func updateBreathingRate() {
        guard hrvHistory.count >= 20 else {
            // Not enough data yet
            confidence = 0.0
            return
        }

        // Estimate breathing rate using simplified spectral analysis
        // In production, this would use FFT/Lomb-Scargle periodogram
        let estimatedRate = estimateBreathingRateFromVariability()

        // Clamp to valid range
        currentBreathingRate = min(max(estimatedRate, minBreathingRate), maxBreathingRate)

        // Update confidence based on data quality
        confidence = min(Double(hrvHistory.count) / Double(maxHistorySize), 1.0)
    }

    /// Simplified breathing rate estimation
    /// In production: Use FFT to find dominant frequency in 0.067-0.5 Hz range (4-30 BPM)
    private func estimateBreathingRateFromVariability() -> Double {
        // Calculate variance of HRV (proxy for breathing influence)
        let mean = hrvHistory.reduce(0, +) / Double(hrvHistory.count)
        let variance = hrvHistory.map { pow($0 - mean, 2) }.reduce(0, +) / Double(hrvHistory.count)
        let standardDeviation = sqrt(variance)

        // High HRV variability suggests slow, deep breathing
        // Low HRV variability suggests fast, shallow breathing
        // This is a simplified heuristic

        let normalizedVariability = min(standardDeviation / mean, 1.0)

        // Map variability to breathing rate
        // High variability (0.8-1.0) → Slow breathing (6-8 BPM)
        // Medium variability (0.4-0.8) → Normal breathing (10-14 BPM)
        // Low variability (0.0-0.4) → Fast breathing (14-20 BPM)

        if normalizedVariability > 0.6 {
            // Slow, deep breathing
            let t = (normalizedVariability - 0.6) / 0.4
            return 12.0 - (t * 4.0) // 12 → 8 BPM
        } else if normalizedVariability > 0.3 {
            // Normal breathing
            let t = (normalizedVariability - 0.3) / 0.3
            return 14.0 - (t * 2.0) // 14 → 12 BPM
        } else {
            // Fast breathing
            let t = normalizedVariability / 0.3
            return 18.0 - (t * 4.0) // 18 → 14 BPM
        }
    }
}

// MARK: - Advanced Breathing Detection (TODO: Implement with Accelerate framework)

extension BreathingRateDetector {

    /// Perform FFT-based breathing rate detection
    /// Requires: import Accelerate
    /// TODO: Implement full spectral analysis
    private func performFFTAnalysis() -> Double {
        // Placeholder for FFT implementation
        // 1. Apply Hanning window to HRV data
        // 2. Compute FFT
        // 3. Find peak in respiratory band (0.15-0.4 Hz for 9-24 BPM)
        // 4. Convert frequency to breaths/minute
        return normalBreathingRate
    }

    /// Detect breathing pattern (regular vs. irregular)
    public var breathingPattern: BreathingPattern {
        guard confidence > 0.5 else { return .unknown }

        // Analyze regularity of breathing
        // In production: Calculate coefficient of variation

        let isRegular = confidence > 0.7
        let isSlow = currentBreathingRate < 8
        let isFast = currentBreathingRate > 18

        if isRegular {
            if isSlow {
                return .deepMeditative
            } else if isFast {
                return .rapidEnergized
            } else {
                return .normalSteady
            }
        } else {
            return .irregular
        }
    }
}

// MARK: - Breathing Pattern

public enum BreathingPattern {
    case unknown
    case deepMeditative      // 4-8 BPM, regular
    case normalSteady        // 10-16 BPM, regular
    case rapidEnergized      // 18-25 BPM, regular
    case irregular           // Variable, erratic

    public var description: String {
        switch self {
        case .unknown: return "Unknown"
        case .deepMeditative: return "Deep & Meditative"
        case .normalSteady: return "Normal & Steady"
        case .rapidEnergized: return "Rapid & Energized"
        case .irregular: return "Irregular"
        }
    }

    public var color: Color {
        switch self {
        case .unknown: return .gray
        case .deepMeditative: return .purple
        case .normalSteady: return .green
        case .rapidEnergized: return .orange
        case .irregular: return .red
        }
    }
}
