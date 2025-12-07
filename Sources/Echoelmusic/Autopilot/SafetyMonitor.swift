import Foundation
import Combine

// MARK: - Safety Monitor
/// Überwacht Sicherheitsaspekte und verhindert gefährliche Zustände
///
/// **Sicherheitsebenen:**
/// 1. Physiologische Grenzen (HR, HRV extreme Werte)
/// 2. Frequenz-Sicherheit (keine gefährlichen Frequenzen)
/// 3. Sitzungsdauer (Übermüdung verhindern)
/// 4. Raten-Limits (zu schnelle Änderungen verhindern)
///
/// **WICHTIG:**
/// - Diese Software ersetzt KEINE medizinische Beratung
/// - Bei ungewöhnlichen Symptomen sofort stoppen
/// - Nicht bei Epilepsie oder Herzerkrankungen ohne ärztliche Freigabe

@MainActor
public class SafetyMonitor: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var currentStatus: SafetyStatus = .nominal

    @Published public private(set) var activeWarnings: [SafetyWarning] = []

    @Published public private(set) var sessionDuration: TimeInterval = 0

    // MARK: - Configuration

    public var thresholds: SafetyThresholds = SafetyThresholds()

    // MARK: - Internal State

    private var sessionStartTime: Date?
    private var lastBiometricData: BiometricDataPoint?
    private var biometricHistory: [BiometricDataPoint] = []
    private let historyMaxSize = 300  // 5 Minuten bei 1Hz

    private var warningHistory: [SafetyWarning] = []

    // MARK: - Rate Tracking

    private var hrChangeRate: Double = 0       // BPM pro Minute
    private var hrvChangeRate: Double = 0      // ms pro Minute
    private var frequencyChangeRate: Double = 0

    // MARK: - Initialization

    public init() {}

    // MARK: - Session Management

    public func startSession() {
        sessionStartTime = Date()
        biometricHistory.removeAll()
        activeWarnings.removeAll()
        currentStatus = .nominal
        print("[SafetyMonitor] Session started")
    }

    public func endSession() {
        sessionStartTime = nil
        print("[SafetyMonitor] Session ended. Duration: \(Int(sessionDuration))s")
    }

    // MARK: - Validation

    /// Validiere biometrische Daten
    public func validate(_ data: BiometricDataPoint) -> SafetyStatus {
        // Update session duration
        if let start = sessionStartTime {
            sessionDuration = Date().timeIntervalSince(start)
        }

        // Speichere für Trend-Analyse
        biometricHistory.append(data)
        if biometricHistory.count > historyMaxSize {
            biometricHistory.removeFirst()
        }

        // Berechne Änderungsraten
        updateChangeRates(data)

        var warnings: [SafetyWarning] = []

        // 1. Herzfrequenz-Grenzen
        if let hr = data.heartRate {
            if hr > thresholds.maxHeartRate {
                warnings.append(SafetyWarning(
                    type: .heartRateHigh,
                    severity: .critical,
                    message: "Herzfrequenz zu hoch: \(Int(hr)) BPM (Max: \(Int(thresholds.maxHeartRate)))",
                    value: hr
                ))
            } else if hr > thresholds.maxHeartRate * 0.9 {
                warnings.append(SafetyWarning(
                    type: .heartRateHigh,
                    severity: .warning,
                    message: "Herzfrequenz erhöht: \(Int(hr)) BPM",
                    value: hr
                ))
            }

            if hr < thresholds.minHeartRate {
                warnings.append(SafetyWarning(
                    type: .heartRateLow,
                    severity: .critical,
                    message: "Herzfrequenz zu niedrig: \(Int(hr)) BPM (Min: \(Int(thresholds.minHeartRate)))",
                    value: hr
                ))
            }
        }

        // 2. HRV-Änderungsrate
        if abs(hrvChangeRate) > thresholds.maxHRVChangeRate {
            warnings.append(SafetyWarning(
                type: .hrvRapidChange,
                severity: .warning,
                message: "HRV ändert sich schnell: \(String(format: "%.1f", hrvChangeRate)) ms/min",
                value: hrvChangeRate
            ))
        }

        // 3. Sitzungsdauer
        if sessionDuration > thresholds.maxSessionDuration {
            warnings.append(SafetyWarning(
                type: .sessionTooLong,
                severity: .warning,
                message: "Sitzung läuft seit \(Int(sessionDuration/60)) Minuten. Pause empfohlen.",
                value: sessionDuration
            ))
        } else if sessionDuration > thresholds.maxSessionDuration * 0.8 {
            warnings.append(SafetyWarning(
                type: .sessionTooLong,
                severity: .info,
                message: "Sitzung läuft seit \(Int(sessionDuration/60)) Minuten.",
                value: sessionDuration
            ))
        }

        // Update warnings
        activeWarnings = warnings

        // Speichere Daten
        lastBiometricData = data

        // Bestimme Status
        currentStatus = determineStatus(from: warnings)

        return currentStatus
    }

    /// Validiere Frequenzparameter
    public func validateFrequency(_ frequency: Double) -> SafetyStatus {
        var warnings: [SafetyWarning] = []

        // Frequenzgrenzen prüfen
        if frequency < thresholds.minFrequency {
            warnings.append(SafetyWarning(
                type: .frequencyTooLow,
                severity: .warning,
                message: "Frequenz unter Minimum: \(String(format: "%.2f", frequency)) Hz",
                value: frequency
            ))
        }

        if frequency > thresholds.maxFrequency {
            warnings.append(SafetyWarning(
                type: .frequencyTooHigh,
                severity: .critical,
                message: "Frequenz über Maximum: \(String(format: "%.0f", frequency)) Hz",
                value: frequency
            ))
        }

        // Photosensitive Epilepsie-Warnung (3-30 Hz visuelle Flicker)
        if frequency >= 3 && frequency <= 30 {
            warnings.append(SafetyWarning(
                type: .photosensitiveRange,
                severity: .info,
                message: "Frequenz im photosensitiven Bereich (3-30 Hz). Vorsicht bei Epilepsie.",
                value: frequency
            ))
        }

        activeWarnings.append(contentsOf: warnings)
        return determineStatus(from: warnings)
    }

    // MARK: - Change Rate Calculation

    private func updateChangeRates(_ data: BiometricDataPoint) {
        guard biometricHistory.count >= 60 else { return }

        // Berechne Änderung über letzte Minute
        let oneMinuteAgo = biometricHistory[biometricHistory.count - 60]

        if let currentHR = data.heartRate, let oldHR = oneMinuteAgo.heartRate {
            hrChangeRate = currentHR - oldHR  // BPM/min
        }

        if let currentHRV = data.hrv, let oldHRV = oneMinuteAgo.hrv {
            hrvChangeRate = currentHRV - oldHRV  // ms/min
        }
    }

    // MARK: - Status Determination

    private func determineStatus(from warnings: [SafetyWarning]) -> SafetyStatus {
        // Prüfe auf kritische Warnungen
        if let critical = warnings.first(where: { $0.severity == .critical }) {
            return .critical(critical.message)
        }

        // Prüfe auf normale Warnungen
        if let warning = warnings.first(where: { $0.severity == .warning }) {
            return .warning(warning.message)
        }

        // Prüfe auf Limits
        if warnings.contains(where: { $0.type == .sessionTooLong }) {
            return .limitReached("Maximale Sitzungsdauer")
        }

        return .nominal
    }

    // MARK: - Emergency Stop

    /// Notfall-Stopp auslösen
    public func emergencyStop(reason: String) {
        currentStatus = .critical("EMERGENCY STOP: \(reason)")

        let warning = SafetyWarning(
            type: .emergencyStop,
            severity: .critical,
            message: reason,
            value: nil
        )

        activeWarnings.append(warning)
        warningHistory.append(warning)

        print("[SafetyMonitor] 🛑 EMERGENCY STOP: \(reason)")

        // Notification senden
        NotificationCenter.default.post(
            name: .autopilotEmergencyStop,
            object: nil,
            userInfo: ["reason": reason]
        )
    }

    // MARK: - Statistics

    public func getSessionStatistics() -> SessionStatistics {
        guard !biometricHistory.isEmpty else {
            return SessionStatistics()
        }

        let hrs = biometricHistory.compactMap { $0.heartRate }
        let hrvs = biometricHistory.compactMap { $0.hrv }

        return SessionStatistics(
            duration: sessionDuration,
            avgHeartRate: hrs.isEmpty ? nil : hrs.reduce(0, +) / Double(hrs.count),
            minHeartRate: hrs.min(),
            maxHeartRate: hrs.max(),
            avgHRV: hrvs.isEmpty ? nil : hrvs.reduce(0, +) / Double(hrvs.count),
            warningCount: warningHistory.count,
            criticalEventCount: warningHistory.filter { $0.severity == .critical }.count
        )
    }
}

// MARK: - Safety Warning

public struct SafetyWarning: Identifiable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let type: WarningType
    public let severity: Severity
    public let message: String
    public let value: Double?

    public init(
        type: WarningType,
        severity: Severity,
        message: String,
        value: Double?
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = type
        self.severity = severity
        self.message = message
        self.value = value
    }

    public enum WarningType: String, Codable {
        case heartRateHigh
        case heartRateLow
        case hrvRapidChange
        case sessionTooLong
        case frequencyTooLow
        case frequencyTooHigh
        case photosensitiveRange
        case emergencyStop
        case systemError
    }

    public enum Severity: String, Codable, Comparable {
        case info
        case warning
        case critical

        public static func < (lhs: Severity, rhs: Severity) -> Bool {
            let order: [Severity] = [.info, .warning, .critical]
            return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
        }
    }
}

// MARK: - Session Statistics

public struct SessionStatistics: Codable {
    public var duration: TimeInterval = 0
    public var avgHeartRate: Double?
    public var minHeartRate: Double?
    public var maxHeartRate: Double?
    public var avgHRV: Double?
    public var warningCount: Int = 0
    public var criticalEventCount: Int = 0
}

// MARK: - Notification Names

public extension Notification.Name {
    static let autopilotEmergencyStop = Notification.Name("autopilotEmergencyStop")
    static let autopilotSafetyWarning = Notification.Name("autopilotSafetyWarning")
}
