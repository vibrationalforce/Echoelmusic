// =============================================================================
// ECHOELMUSIC - QUANTUM DATA STORE
// =============================================================================
// Shared data store for quantum state persistence across app extensions
// Used by: Main App, Widgets, App Clip
// =============================================================================

import Foundation

/// Shared data store for quantum coherence and bio-reactive state
/// Uses App Groups for cross-extension data sharing
@available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, visionOS 1.0, *)
public final class QuantumDataStore: @unchecked Sendable {

    // MARK: - Singleton

    public static let shared = QuantumDataStore()

    // MARK: - App Group

    private let appGroupIdentifier = "group.com.echoelmusic.shared"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    // MARK: - Keys

    private enum Keys {
        static let coherenceLevel = "quantum.coherence.level"
        static let lastSessionDate = "quantum.session.lastDate"
        static let totalSessionMinutes = "quantum.session.totalMinutes"
        static let peakCoherence = "quantum.coherence.peak"
        static let currentMode = "quantum.mode.current"
        static let heartRate = "bio.heartRate"
        static let hrvValue = "bio.hrvValue"
        static let breathingRate = "bio.breathingRate"
        static let entanglementCount = "quantum.entanglement.count"
        static let isQuantumActive = "quantum.session.active"
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Coherence Data

    /// Current coherence level (0.0 - 1.0)
    public var coherenceLevel: Double {
        get { sharedDefaults?.double(forKey: Keys.coherenceLevel) ?? 0.0 }
        set { sharedDefaults?.set(newValue, forKey: Keys.coherenceLevel) }
    }

    /// Peak coherence achieved in current session
    public var peakCoherence: Double {
        get { sharedDefaults?.double(forKey: Keys.peakCoherence) ?? 0.0 }
        set { sharedDefaults?.set(newValue, forKey: Keys.peakCoherence) }
    }

    /// Last session date
    public var lastSessionDate: Date? {
        get { sharedDefaults?.object(forKey: Keys.lastSessionDate) as? Date }
        set { sharedDefaults?.set(newValue, forKey: Keys.lastSessionDate) }
    }

    /// Total session minutes
    public var totalSessionMinutes: Int {
        get { sharedDefaults?.integer(forKey: Keys.totalSessionMinutes) ?? 0 }
        set { sharedDefaults?.set(newValue, forKey: Keys.totalSessionMinutes) }
    }

    /// Current quantum mode
    public var currentMode: String {
        get { sharedDefaults?.string(forKey: Keys.currentMode) ?? "bioCoherent" }
        set { sharedDefaults?.set(newValue, forKey: Keys.currentMode) }
    }

    // MARK: - Biometric Data

    /// Current heart rate (BPM)
    public var heartRate: Double {
        get { sharedDefaults?.double(forKey: Keys.heartRate) ?? 0.0 }
        set { sharedDefaults?.set(newValue, forKey: Keys.heartRate) }
    }

    /// Current HRV value (ms)
    public var hrvValue: Double {
        get { sharedDefaults?.double(forKey: Keys.hrvValue) ?? 0.0 }
        set { sharedDefaults?.set(newValue, forKey: Keys.hrvValue) }
    }

    /// Current breathing rate (breaths/min)
    public var breathingRate: Double {
        get { sharedDefaults?.double(forKey: Keys.breathingRate) ?? 0.0 }
        set { sharedDefaults?.set(newValue, forKey: Keys.breathingRate) }
    }

    // MARK: - Quantum State

    /// Alias for hrvValue for backward compatibility with widgets/live activity
    public var hrvCoherence: Double {
        get { hrvValue }
        set { hrvValue = newValue }
    }

    /// Number of entangled devices in current session
    public var entanglementCount: Int {
        get { sharedDefaults?.integer(forKey: Keys.entanglementCount) ?? 0 }
        set { sharedDefaults?.set(newValue, forKey: Keys.entanglementCount) }
    }

    /// Whether a quantum session is currently active
    public var isQuantumActive: Bool {
        get { sharedDefaults?.bool(forKey: Keys.isQuantumActive) ?? false }
        set { sharedDefaults?.set(newValue, forKey: Keys.isQuantumActive) }
    }

    // MARK: - Session Management

    /// Start a new quantum session
    public func startSession() {
        lastSessionDate = Date()
        peakCoherence = 0.0
        isQuantumActive = true
    }

    /// End current session and update totals
    public func endSession(durationMinutes: Int) {
        totalSessionMinutes += durationMinutes
        isQuantumActive = false
        entanglementCount = 0
    }

    /// Update coherence and track peak
    public func updateCoherence(_ value: Double) {
        coherenceLevel = value
        if value > peakCoherence {
            peakCoherence = value
        }
    }

    /// Update all biometric data at once
    public func updateBiometrics(heartRate: Double, hrv: Double, breathingRate: Double) {
        self.heartRate = heartRate
        self.hrvValue = hrv
        self.breathingRate = breathingRate
    }

    /// Reset all data
    public func reset() {
        coherenceLevel = 0.0
        peakCoherence = 0.0
        heartRate = 0.0
        hrvValue = 0.0
        breathingRate = 0.0
        entanglementCount = 0
        isQuantumActive = false
    }

    // MARK: - Widget Data

    /// Get formatted data for widget display
    public func getWidgetData() -> WidgetData {
        WidgetData(
            coherence: coherenceLevel,
            peakCoherence: peakCoherence,
            heartRate: heartRate,
            lastSession: lastSessionDate,
            totalMinutes: totalSessionMinutes,
            mode: currentMode
        )
    }

    /// Widget display data structure
    public struct WidgetData {
        public let coherence: Double
        public let peakCoherence: Double
        public let heartRate: Double
        public let lastSession: Date?
        public let totalMinutes: Int
        public let mode: String

        public var coherencePercentage: Int {
            Int(coherence * 100)
        }

        public var formattedHeartRate: String {
            heartRate > 0 ? "\(Int(heartRate)) BPM" : "--"
        }

        public var formattedTotalTime: String {
            let hours = totalMinutes / 60
            let mins = totalMinutes % 60
            if hours > 0 {
                return "\(hours)h \(mins)m"
            }
            return "\(mins)m"
        }
    }
}
