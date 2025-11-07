import WidgetKit
import SwiftUI

/// Echoelmusic Widget - Real-time HRV and coherence on home screen
///
/// **Purpose:** Extend the seamless "Erlebnisbad" to home screens
///
/// **Platforms:**
/// - iOS 14.0+: Home screen widgets
/// - iPadOS 14.0+: Home screen and Today view
/// - macOS 11.0+: Notification Center widgets
///
/// **Widget Sizes:**
/// - **Small:** Current HRV value with coherence color
/// - **Medium:** HRV + Coherence gauge + Last updated
/// - **Large:** HRV history chart + Current stats
///
/// **Features:**
/// - Real-time HRV display
/// - Coherence color coding (red/yellow/green)
/// - Automatic updates every 15 minutes
/// - Deep link to app
/// - Shared data via App Groups
///
/// **Data Source:**
/// - App Groups container: group.com.echoelmusic.shared
/// - UserDefaults for latest HRV/coherence
/// - Timeline updates every 15 minutes
///
@main
struct EchoelmusicWidget: Widget {
    let kind: String = "EchoelmusicWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HRVTimelineProvider()) { entry in
            HRVWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Echoelmusic")
        .description("Track your HRV and coherence in real-time")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        #if os(macOS)
        .supportedFamilies([.systemSmall, .systemMedium])
        #endif
    }
}

// MARK: - Preview

struct EchoelmusicWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Small widget
            HRVWidgetEntryView(entry: HRVWidgetEntry(
                date: Date(),
                hrv: 67.5,
                coherence: 75.0,
                heartRate: 68,
                breathingPhase: "Inhale"
            ))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small")

            // Medium widget
            HRVWidgetEntryView(entry: HRVWidgetEntry(
                date: Date(),
                hrv: 67.5,
                coherence: 75.0,
                heartRate: 68,
                breathingPhase: "Inhale"
            ))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Medium")

            // Large widget
            HRVWidgetEntryView(entry: HRVWidgetEntry(
                date: Date(),
                hrv: 67.5,
                coherence: 75.0,
                heartRate: 68,
                breathingPhase: "Inhale"
            ))
            .previewContext(WidgetPreviewContext(family: .systemLarge))
            .previewDisplayName("Large")
        }
    }
}
