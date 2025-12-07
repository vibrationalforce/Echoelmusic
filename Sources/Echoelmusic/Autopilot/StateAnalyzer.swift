import Foundation
import Combine

// MARK: - State Analyzer
/// Analysiert biometrische Daten zur Erkennung des physiologischen Zustands
///
/// **Wissenschaftliche Grundlage:**
/// - ✅ HRV-Analyse (RMSSD, SDNN) - Standard in Stressforschung
/// - ✅ Herzfrequenz-Variabilität als Stressindikator (Thayer 2012)
/// - ✅ Respiratorische Sinusarrhythmie (RSA) - Vagustonus-Marker
/// - ⚠️ Kohärenz-Metrik (HeartMath) - proprietär, nicht universell akzeptiert

@MainActor
public class StateAnalyzer: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var currentState: UserPhysiologicalState = .neutral

    @Published public private(set) var stateConfidence: Double = 0.0

    @Published public private(set) var hrvTrend: Trend = .stable

    @Published public private(set) var arousalLevel: Double = 0.5

    @Published public private(set) var coherenceLevel: Double = 0.5

    // MARK: - Configuration

    public var sensitivity: Double = 0.5 {
        didSet {
            updateThresholds()
        }
    }

    // MARK: - Internal State

    /// Gleitender Durchschnitt der Herzfrequenz
    private var hrBuffer: RingBuffer<Double>

    /// Gleitender Durchschnitt der HRV
    private var hrvBuffer: RingBuffer<Double>

    /// Kohärenz-Historie
    private var coherenceBuffer: RingBuffer<Double>

    /// Respirationsrate-Buffer
    private var respirationBuffer: RingBuffer<Double>

    /// Baseline-Werte (individuell kalibriert)
    private var baseline: BiometricBaseline?

    /// Zustandsübergangs-Matrix
    private var stateHistory: [UserPhysiologicalState] = []
    private let stateHistoryMaxLength = 30

    // MARK: - Thresholds (anpassbar via sensitivity)

    private var stressHRVThreshold: Double = 30.0      // ms - unter diesem Wert = Stress
    private var relaxedHRVThreshold: Double = 60.0     // ms - über diesem Wert = entspannt
    private var highHRThreshold: Double = 100.0        // BPM
    private var lowHRThreshold: Double = 55.0          // BPM

    // MARK: - Initialization

    public init(bufferSize: Int = 60) {
        // 60 Samples bei 1Hz = 1 Minute gleitender Durchschnitt
        self.hrBuffer = RingBuffer(capacity: bufferSize)
        self.hrvBuffer = RingBuffer(capacity: bufferSize)
        self.coherenceBuffer = RingBuffer(capacity: bufferSize)
        self.respirationBuffer = RingBuffer(capacity: bufferSize)
    }

    // MARK: - Data Input

    /// Verarbeite neue biometrische Daten
    public func process(_ data: BiometricDataPoint) {
        // Daten in Buffer einfügen
        if let hr = data.heartRate {
            hrBuffer.append(hr)
        }

        if let hrv = data.hrv {
            hrvBuffer.append(hrv)
        }

        if let coherence = data.coherence {
            coherenceBuffer.append(coherence)
        }

        if let respiration = data.respirationRate {
            respirationBuffer.append(respiration)
        }

        // Zustand neu berechnen
        analyzeState()
    }

    /// Verarbeite Frequenzmessung
    public func processFrequency(_ measurement: MeasuredFrequency, organ: Organ) {
        // Frequenzmessungen können zusätzliche Einsichten liefern
        // z.B. Herzfrequenz-Variabilität auf Sub-Beat-Ebene

        if organ == .heart {
            // Berechne instantane HR aus Frequenz
            let instantHR = measurement.value * 60.0  // Hz → BPM
            hrBuffer.append(instantHR)
        }
    }

    // MARK: - Baseline Calibration

    /// Kalibriere individuelle Baseline
    public func calibrateBaseline(duration: TimeInterval = 60) async -> BiometricBaseline? {
        print("[StateAnalyzer] Starting baseline calibration for \(duration)s...")

        let startTime = Date()
        var hrSamples: [Double] = []
        var hrvSamples: [Double] = []

        while Date().timeIntervalSince(startTime) < duration {
            if let hr = hrBuffer.last {
                hrSamples.append(hr)
            }
            if let hrv = hrvBuffer.last {
                hrvSamples.append(hrv)
            }

            try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
        }

        guard hrSamples.count >= 10, hrvSamples.count >= 10 else {
            print("[StateAnalyzer] ❌ Insufficient data for calibration")
            return nil
        }

        let newBaseline = BiometricBaseline(
            meanHR: hrSamples.mean,
            sdHR: hrSamples.standardDeviation,
            meanHRV: hrvSamples.mean,
            sdHRV: hrvSamples.standardDeviation,
            timestamp: Date()
        )

        self.baseline = newBaseline

        print("[StateAnalyzer] ✅ Baseline calibrated:")
        print("  HR: \(String(format: "%.1f", newBaseline.meanHR)) ± \(String(format: "%.1f", newBaseline.sdHR)) BPM")
        print("  HRV: \(String(format: "%.1f", newBaseline.meanHRV)) ± \(String(format: "%.1f", newBaseline.sdHRV)) ms")

        return newBaseline
    }

    // MARK: - State Analysis

    private func analyzeState() {
        // Berechne aktuelle Metriken
        let currentHR = hrBuffer.average ?? 70.0
        let currentHRV = hrvBuffer.average ?? 50.0
        let currentCoherence = coherenceBuffer.average ?? 0.5

        // Berechne Arousal (basierend auf HR und HRV)
        arousalLevel = calculateArousal(hr: currentHR, hrv: currentHRV)

        // Berechne Kohärenz-Level
        coherenceLevel = currentCoherence

        // Bestimme HRV-Trend
        hrvTrend = calculateHRVTrend()

        // Bestimme Zustand basierend auf multiplen Faktoren
        let newState = determineState(
            hr: currentHR,
            hrv: currentHRV,
            coherence: currentCoherence,
            arousal: arousalLevel
        )

        // Konfidenz basierend auf Datenmenge und -qualität
        stateConfidence = calculateConfidence()

        // Zustandsübergang mit Hysterese
        if shouldTransitionTo(newState) {
            currentState = newState
            recordStateTransition(newState)
        }
    }

    private func calculateArousal(hr: Double, hrv: Double) -> Double {
        // Arousal-Formel:
        // - Höhere HR → höheres Arousal
        // - Niedrigeres HRV → höheres Arousal (Stress)

        let hrNormalized: Double
        if let base = baseline {
            // Normalisiert auf individuelle Baseline
            hrNormalized = (hr - base.meanHR) / (base.sdHR * 3) + 0.5
        } else {
            // Standardnormalisierung (60-100 BPM → 0-1)
            hrNormalized = (hr - 60) / 40.0
        }

        let hrvNormalized: Double
        if let base = baseline {
            hrvNormalized = (hrv - base.meanHRV) / (base.sdHRV * 3) + 0.5
        } else {
            // Standard: 20-80ms → 0-1 (invertiert)
            hrvNormalized = 1.0 - (hrv - 20) / 60.0
        }

        // Gewichtete Kombination
        let arousal = (hrNormalized * 0.4 + hrvNormalized * 0.6)

        return max(0, min(1, arousal))
    }

    private func calculateHRVTrend() -> Trend {
        guard hrvBuffer.count >= 10 else { return .stable }

        let recentHRV = hrvBuffer.lastN(5).mean
        let olderHRV = hrvBuffer.firstN(5).mean

        let change = recentHRV - olderHRV
        let threshold = 5.0  // 5ms Änderung ist signifikant

        if change > threshold {
            return .increasing
        } else if change < -threshold {
            return .decreasing
        } else {
            return .stable
        }
    }

    private func determineState(
        hr: Double,
        hrv: Double,
        coherence: Double,
        arousal: Double
    ) -> UserPhysiologicalState {

        // Entscheidungsbaum basierend auf wissenschaftlichen Schwellenwerten

        // Hoher Stress: Niedriges HRV + hohe HR
        if hrv < stressHRVThreshold && hr > highHRThreshold {
            return .stressed
        }

        // Ängstlich: Hohe HR ohne extrem niedriges HRV
        if hr > highHRThreshold && hrv >= stressHRVThreshold {
            return .anxious
        }

        // Tiefe Entspannung: Hohes HRV + hohe Kohärenz + niedrige HR
        if hrv > relaxedHRVThreshold && coherence > 0.7 && hr < 65 {
            return .deepRelaxation
        }

        // Entspannt: Hohes HRV
        if hrv > relaxedHRVThreshold {
            return .relaxed
        }

        // Fokussiert: Mittleres Arousal + stabile HRV
        if arousal > 0.5 && arousal < 0.7 && hrvTrend == .stable {
            return .focused
        }

        // Müde: Niedriges Arousal + niedrige HR
        if arousal < 0.3 && hr < lowHRThreshold {
            return .drowsy
        }

        // Energetisiert: Hohes Arousal + hohe HR + akzeptables HRV
        if arousal > 0.7 && hr > 80 && hrv > stressHRVThreshold {
            return .energized
        }

        // Kreativ: Mittleres Arousal mit leicht erhöhtem HRV (Flow-Zustand)
        if arousal > 0.4 && arousal < 0.6 && hrv > 50 && coherence > 0.5 {
            return .creative
        }

        return .neutral
    }

    private func shouldTransitionTo(_ newState: UserPhysiologicalState) -> Bool {
        // Hysterese: Zustand muss mehrmals hintereinander erkannt werden

        // Füge temporär hinzu für Prüfung
        var tempHistory = stateHistory
        tempHistory.append(newState)
        if tempHistory.count > 5 {
            tempHistory.removeFirst()
        }

        // Mindestens 3 von 5 müssen übereinstimmen
        let matchCount = tempHistory.filter { $0 == newState }.count
        return matchCount >= 3
    }

    private func recordStateTransition(_ state: UserPhysiologicalState) {
        stateHistory.append(state)
        if stateHistory.count > stateHistoryMaxLength {
            stateHistory.removeFirst()
        }
    }

    private func calculateConfidence() -> Double {
        // Konfidenz basierend auf:
        // 1. Datenmenge
        // 2. Datenkonsistenz
        // 3. Baseline vorhanden

        var confidence = 0.0

        // Datenmenge (mehr = besser, bis zu 60 Samples)
        let dataFactor = min(1.0, Double(hrBuffer.count) / 30.0)
        confidence += dataFactor * 0.3

        // Datenkonsistenz (niedrige Varianz = mehr Vertrauen)
        if let hrvSD = hrvBuffer.standardDeviation, hrvSD < 20 {
            confidence += 0.3
        } else if let hrvSD = hrvBuffer.standardDeviation, hrvSD < 40 {
            confidence += 0.15
        }

        // Baseline vorhanden
        if baseline != nil {
            confidence += 0.4
        } else {
            confidence += 0.2  // Standardwerte
        }

        return min(1.0, confidence)
    }

    private func updateThresholds() {
        // Passe Schwellenwerte basierend auf Sensitivity an
        // Höhere Sensitivity = empfindlichere Erkennung

        let factor = sensitivity  // 0.0 - 1.0

        // Bei höherer Sensitivity: Niedrigere Schwelle für Stress
        stressHRVThreshold = 40.0 - (factor * 15.0)  // 25-40ms

        // Bei höherer Sensitivity: Niedrigere Schwelle für Entspannung
        relaxedHRVThreshold = 50.0 + (factor * 20.0)  // 50-70ms

        // HR-Schwellen bleiben physiologisch basiert
        highHRThreshold = 100.0 - (factor * 10.0)  // 90-100 BPM
        lowHRThreshold = 55.0 + (factor * 5.0)     // 55-60 BPM
    }
}

// MARK: - Supporting Types

public enum Trend: String, Codable {
    case increasing
    case stable
    case decreasing

    public var symbol: String {
        switch self {
        case .increasing: return "↑"
        case .stable: return "→"
        case .decreasing: return "↓"
        }
    }
}

public struct BiometricBaseline: Codable {
    public let meanHR: Double
    public let sdHR: Double
    public let meanHRV: Double
    public let sdHRV: Double
    public let timestamp: Date

    /// Alter der Baseline in Stunden
    public var ageInHours: Double {
        Date().timeIntervalSince(timestamp) / 3600.0
    }

    /// Ist die Baseline noch aktuell? (< 24 Stunden)
    public var isRecent: Bool {
        ageInHours < 24.0
    }
}

// MARK: - Ring Buffer

/// Effizienter Ringbuffer für gleitende Durchschnitte
public class RingBuffer<T: Numeric> {
    private var buffer: [T]
    private var writeIndex: Int = 0
    private let capacity: Int
    public private(set) var count: Int = 0

    public init(capacity: Int) {
        self.capacity = capacity
        self.buffer = []
        self.buffer.reserveCapacity(capacity)
    }

    public func append(_ value: T) {
        if buffer.count < capacity {
            buffer.append(value)
        } else {
            buffer[writeIndex] = value
        }
        writeIndex = (writeIndex + 1) % capacity
        count = min(count + 1, capacity)
    }

    public var last: T? {
        guard count > 0 else { return nil }
        let index = (writeIndex - 1 + capacity) % capacity
        return buffer[index]
    }

    public func lastN(_ n: Int) -> [T] {
        guard count > 0 else { return [] }
        let actualN = min(n, count)
        var result: [T] = []

        for i in 0..<actualN {
            let index = (writeIndex - 1 - i + capacity) % capacity
            if index < buffer.count {
                result.append(buffer[index])
            }
        }

        return result.reversed()
    }

    public func firstN(_ n: Int) -> [T] {
        guard count > 0 else { return [] }
        let actualN = min(n, count)

        if buffer.count < capacity {
            return Array(buffer.prefix(actualN))
        } else {
            var result: [T] = []
            for i in 0..<actualN {
                let index = (writeIndex + i) % capacity
                result.append(buffer[index])
            }
            return result
        }
    }

    public var all: [T] {
        return buffer
    }
}

// MARK: - Array Extensions for Statistics

extension RingBuffer where T == Double {
    public var average: Double? {
        guard count > 0 else { return nil }
        return buffer.reduce(0, +) / Double(buffer.count)
    }

    public var standardDeviation: Double? {
        guard count > 1 else { return nil }
        guard let avg = average else { return nil }

        let variance = buffer.map { ($0 - avg) * ($0 - avg) }.reduce(0, +) / Double(buffer.count - 1)
        return sqrt(variance)
    }
}

extension Array where Element == Double {
    var mean: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }

    var standardDeviation: Double {
        guard count > 1 else { return 0 }
        let avg = mean
        let variance = map { ($0 - avg) * ($0 - avg) }.reduce(0, +) / Double(count - 1)
        return sqrt(variance)
    }
}
