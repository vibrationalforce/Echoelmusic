import Foundation
import ActivityKit

/// Live Activity attributes for biofeedback sessions
///
/// **Purpose:** Real-time session updates in Dynamic Island and Lock Screen
///
/// **Features:**
/// - Dynamic Island: iPhone 14 Pro+ compact/minimal/expanded views
/// - Lock Screen: Rich notifications with live updates
/// - Always-On Display: Persistent session state on iPhone 14 Pro+
///
/// **Use Cases:**
/// - HRV monitoring session in progress
/// - Breathing exercise with live phase updates
/// - Coherence training with real-time feedback
/// - Group session participation status
///
/// **Platform:** iOS 16.1+ (Live Activities)
///
@available(iOS 16.1, *)
struct BiofeedbackActivityAttributes: ActivityAttributes {

    // MARK: - Static Content (Set Once)

    /// Static data that doesn't change during the activity
    public struct ContentState: Codable, Hashable {
        /// Current HRV value (ms)
        var currentHRV: Double

        /// Current coherence score (0-100)
        var currentCoherence: Double

        /// Current heart rate (BPM)
        var currentHeartRate: Double

        /// Current breathing phase
        var breathingPhase: BreathingPhase

        /// Session elapsed time (seconds)
        var elapsedTime: TimeInterval

        /// Target session duration (seconds)
        var targetDuration: TimeInterval?

        /// Coherence level (for color coding)
        var coherenceLevel: CoherenceLevel {
            switch currentCoherence {
            case 0..<30:
                return .low
            case 30..<60:
                return .medium
            default:
                return .high
            }
        }

        /// Progress percentage (0-1)
        var progress: Double {
            guard let target = targetDuration, target > 0 else { return 0 }
            return min(elapsedTime / target, 1.0)
        }

        /// Formatted HRV string
        var hrvFormatted: String {
            String(format: "%.1f ms", currentHRV)
        }

        /// Formatted coherence string
        var coherenceFormatted: String {
            String(format: "%.0f%%", currentCoherence)
        }

        /// Formatted heart rate string
        var heartRateFormatted: String {
            String(format: "%.0f BPM", currentHeartRate)
        }

        /// Formatted elapsed time
        var elapsedTimeFormatted: String {
            let minutes = Int(elapsedTime) / 60
            let seconds = Int(elapsedTime) % 60
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    // MARK: - Static Attributes

    /// Session ID
    var sessionID: String

    /// Session type
    var sessionType: SessionType

    /// Session start time
    var startTime: Date

    /// User name (optional, for group sessions)
    var userName: String?
}

// MARK: - Supporting Types

@available(iOS 16.1, *)
public enum SessionType: String, Codable, Hashable {
    case hrvMonitoring = "HRV Monitoring"
    case breathing = "Breathing Exercise"
    case coherenceTraining = "Coherence Training"
    case groupSession = "Group Session"

    var icon: String {
        switch self {
        case .hrvMonitoring:
            return "waveform.path.ecg"
        case .breathing:
            return "wind"
        case .coherenceTraining:
            return "chart.line.uptrend.xyaxis"
        case .groupSession:
            return "person.3.fill"
        }
    }

    var displayName: String {
        return self.rawValue
    }
}

public enum BreathingPhase: String, Codable, Hashable {
    case inhale = "Inhale"
    case hold = "Hold"
    case exhale = "Exhale"
    case rest = "Rest"

    var icon: String {
        switch self {
        case .inhale:
            return "arrow.up.circle.fill"
        case .hold:
            return "pause.circle.fill"
        case .exhale:
            return "arrow.down.circle.fill"
        case .rest:
            return "circle"
        }
    }

    var color: String {
        switch self {
        case .inhale:
            return "blue"
        case .hold:
            return "purple"
        case .exhale:
            return "green"
        case .rest:
            return "gray"
        }
    }
}

public enum CoherenceLevel: String, Codable, Hashable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var color: String {
        switch self {
        case .low:
            return "red"
        case .medium:
            return "yellow"
        case .high:
            return "green"
        }
    }
}
