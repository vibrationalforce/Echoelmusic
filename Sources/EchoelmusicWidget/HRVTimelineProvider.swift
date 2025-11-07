import WidgetKit
import Foundation

/// Timeline provider for HRV widgets
///
/// **Update Strategy:**
/// - Refresh every 15 minutes (Widget best practice)
/// - Fetch latest data from shared UserDefaults
/// - Provide placeholder and snapshot for previews
///
struct HRVTimelineProvider: TimelineProvider {

    // MARK: - Shared Data

    private let sharedDefaults = UserDefaults(suiteName: "group.com.echoelmusic.shared")

    // MARK: - Timeline Provider Methods

    func placeholder(in context: Context) -> HRVWidgetEntry {
        HRVWidgetEntry(
            date: Date(),
            hrv: 65.0,
            coherence: 70.0,
            heartRate: 68,
            breathingPhase: "Inhale"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (HRVWidgetEntry) -> Void) {
        let entry: HRVWidgetEntry

        if context.isPreview {
            // Preview data
            entry = HRVWidgetEntry(
                date: Date(),
                hrv: 67.5,
                coherence: 75.0,
                heartRate: 68,
                breathingPhase: "Inhale"
            )
        } else {
            // Real data
            entry = fetchCurrentEntry()
        }

        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HRVWidgetEntry>) -> Void) {
        // Fetch current data
        let currentEntry = fetchCurrentEntry()

        // Schedule next update in 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!

        let timeline = Timeline(entries: [currentEntry], policy: .after(nextUpdate))

        completion(timeline)
    }

    // MARK: - Data Fetching

    private func fetchCurrentEntry() -> HRVWidgetEntry {
        // Read from shared UserDefaults
        let hrv = sharedDefaults?.double(forKey: "currentHRV") ?? 0.0
        let coherence = sharedDefaults?.double(forKey: "currentCoherence") ?? 0.0
        let heartRate = sharedDefaults?.double(forKey: "currentHeartRate") ?? 0.0
        let breathingPhase = sharedDefaults?.string(forKey: "breathingPhase") ?? "Rest"

        return HRVWidgetEntry(
            date: Date(),
            hrv: hrv,
            coherence: coherence,
            heartRate: heartRate,
            breathingPhase: breathingPhase
        )
    }
}

// MARK: - Widget Entry

struct HRVWidgetEntry: TimelineEntry {
    let date: Date
    let hrv: Double
    let coherence: Double
    let heartRate: Double
    let breathingPhase: String

    /// Coherence level based on score
    var coherenceLevel: CoherenceLevel {
        switch coherence {
        case 0..<30:
            return .low
        case 30..<60:
            return .medium
        default:
            return .high
        }
    }

    /// Color for coherence level
    var coherenceColor: Color {
        switch coherenceLevel {
        case .low:
            return .red
        case .medium:
            return .yellow
        case .high:
            return .green
        }
    }

    /// Formatted HRV string
    var hrvFormatted: String {
        String(format: "%.1f ms", hrv)
    }

    /// Formatted coherence string
    var coherenceFormatted: String {
        String(format: "%.0f%%", coherence)
    }

    /// Formatted heart rate string
    var heartRateFormatted: String {
        String(format: "%.0f BPM", heartRate)
    }
}

enum CoherenceLevel {
    case low
    case medium
    case high

    var description: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }
}
