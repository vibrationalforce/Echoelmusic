import SwiftUI
import ActivityKit
import WidgetKit

/// Live Activity views for Dynamic Island and Lock Screen
///
/// **Dynamic Island Modes:**
/// - **Compact:** Small pill showing HRV + coherence color
/// - **Minimal:** Leading (HRV) + Trailing (coherence %)
/// - **Expanded:** Full session stats with breathing animation
///
/// **Lock Screen:**
/// - Rich notification with current stats
/// - Real-time updates every 1-5 seconds
/// - Progress bar for timed sessions
///
@available(iOS 16.1, *)
struct BiofeedbackLiveActivityView: View {
    let context: ActivityViewContext<BiofeedbackActivityAttributes>

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: context.attributes.sessionType.icon)
                    .foregroundColor(coherenceColor)

                Text(context.attributes.sessionType.displayName)
                    .font(.headline)

                Spacer()

                Text(context.state.elapsedTimeFormatted)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Main stats
            HStack(spacing: 20) {
                // HRV
                VStack(spacing: 4) {
                    Text(context.state.hrvFormatted)
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)

                    Text("HRV")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Divider()
                    .frame(height: 40)

                // Coherence
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                            .frame(width: 40, height: 40)

                        Circle()
                            .trim(from: 0, to: context.state.currentCoherence / 100)
                            .stroke(coherenceColor, lineWidth: 4)
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(-90))
                    }

                    Text(context.state.coherenceFormatted)
                        .font(.caption)
                        .fontWeight(.semibold)

                    Text("Coherence")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Divider()
                    .frame(height: 40)

                // Heart Rate
                VStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.title3)

                    Text(context.state.heartRateFormatted)
                        .font(.caption)
                        .fontWeight(.semibold)
                }

                Divider()
                    .frame(height: 40)

                // Breathing
                VStack(spacing: 4) {
                    Image(systemName: context.state.breathingPhase.icon)
                        .foregroundColor(breathingColor)
                        .font(.title3)

                    Text(context.state.breathingPhase.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Progress bar (if timed session)
            if let targetDuration = context.state.targetDuration, targetDuration > 0 {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 4)

                        Rectangle()
                            .fill(coherenceColor)
                            .frame(width: geometry.size.width * context.state.progress, height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding()
        .activityBackgroundTint(Color.black.opacity(0.1))
        .activitySystemActionForegroundColor(coherenceColor)
    }

    // MARK: - Computed Properties

    private var coherenceColor: Color {
        switch context.state.coherenceLevel {
        case .low:
            return .red
        case .medium:
            return .yellow
        case .high:
            return .green
        }
    }

    private var breathingColor: Color {
        switch context.state.breathingPhase {
        case .inhale:
            return .blue
        case .hold:
            return .purple
        case .exhale:
            return .green
        case .rest:
            return .gray
        }
    }
}

// MARK: - Dynamic Island Views

@available(iOS 16.1, *)
extension BiofeedbackLiveActivityView {

    /// Compact view - Small pill in Dynamic Island
    struct CompactView: View {
        let context: ActivityViewContext<BiofeedbackActivityAttributes>

        var body: some View {
            HStack(spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundColor(coherenceColor)

                Text(context.state.hrvFormatted)
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
        }

        private var coherenceColor: Color {
            switch context.state.coherenceLevel {
            case .low:
                return .red
            case .medium:
                return .yellow
            case .high:
                return .green
            }
        }
    }

    /// Minimal view - Leading + Trailing in Dynamic Island
    struct MinimalView: View {
        let context: ActivityViewContext<BiofeedbackActivityAttributes>

        var leading: some View {
            Text(context.state.hrvFormatted)
                .font(.caption2)
                .fontWeight(.semibold)
        }

        var trailing: some View {
            Text(context.state.coherenceFormatted)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(coherenceColor)
        }

        private var coherenceColor: Color {
            switch context.state.coherenceLevel {
            case .low:
                return .red
            case .medium:
                return .yellow
            case .high:
                return .green
            }
        }
    }

    /// Expanded view - Full Dynamic Island takeover
    struct ExpandedView: View {
        let context: ActivityViewContext<BiofeedbackActivityAttributes>

        var body: some View {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Image(systemName: context.attributes.sessionType.icon)
                        .foregroundColor(coherenceColor)

                    Text(context.attributes.sessionType.displayName)
                        .font(.headline)

                    Spacer()

                    Text(context.state.elapsedTimeFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Stats grid
                HStack(spacing: 16) {
                    // HRV
                    VStack(spacing: 4) {
                        Text(context.state.hrvFormatted)
                            .font(.title3)
                            .fontWeight(.bold)

                        Text("HRV")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    // Coherence gauge
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                            .frame(width: 60, height: 60)

                        Circle()
                            .trim(from: 0, to: context.state.currentCoherence / 100)
                            .stroke(coherenceColor, lineWidth: 6)
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 0) {
                            Text(context.state.coherenceFormatted)
                                .font(.caption)
                                .fontWeight(.bold)

                            Text("Coherence")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Heart Rate
                    VStack(spacing: 4) {
                        Text(context.state.heartRateFormatted)
                            .font(.title3)
                            .fontWeight(.bold)

                        Text("BPM")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }

                // Breathing animation
                HStack {
                    Image(systemName: context.state.breathingPhase.icon)
                        .foregroundColor(breathingColor)

                    Text(context.state.breathingPhase.rawValue)
                        .font(.subheadline)
                        .foregroundColor(breathingColor)

                    Spacer()
                }
            }
            .padding()
        }

        private var coherenceColor: Color {
            switch context.state.coherenceLevel {
            case .low:
                return .red
            case .medium:
                return .yellow
            case .high:
                return .green
            }
        }

        private var breathingColor: Color {
            switch context.state.breathingPhase {
            case .inhale:
                return .blue
            case .hold:
                return .purple
            case .exhale:
                return .green
            case .rest:
                return .gray
            }
        }
    }
}

// MARK: - Widget Configuration

@available(iOS 16.1, *)
struct BiofeedbackLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BiofeedbackActivityAttributes.self) { context in
            // Lock Screen view
            BiofeedbackLiveActivityView(context: context)

        } dynamicIsland: { context in
            // Dynamic Island views
            DynamicIsland {
                // Expanded view
                DynamicIslandExpandedRegion(.center) {
                    BiofeedbackLiveActivityView.ExpandedView(context: context)
                }
            } compactLeading: {
                // Compact leading
                Image(systemName: "heart.fill")
                    .foregroundColor(coherenceColor(for: context.state.coherenceLevel))
            } compactTrailing: {
                // Compact trailing
                Text(context.state.hrvFormatted)
                    .font(.caption2)
                    .fontWeight(.semibold)
            } minimal: {
                // Minimal view
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(coherenceColor(for: context.state.coherenceLevel))
            }
        }
    }

    private func coherenceColor(for level: CoherenceLevel) -> Color {
        switch level {
        case .low:
            return .red
        case .medium:
            return .yellow
        case .high:
            return .green
        }
    }
}

// MARK: - Preview

@available(iOS 16.1, *)
struct BiofeedbackLiveActivity_Previews: PreviewProvider {
    static let attributes = BiofeedbackActivityAttributes(
        sessionID: "preview-session",
        sessionType: .hrvMonitoring,
        startTime: Date(),
        userName: nil
    )

    static let contentState = BiofeedbackActivityAttributes.ContentState(
        currentHRV: 67.5,
        currentCoherence: 75.0,
        currentHeartRate: 68.0,
        breathingPhase: .inhale,
        elapsedTime: 120,
        targetDuration: 600
    )

    static var previews: some View {
        attributes
            .previewContext(contentState, viewKind: .content)
            .previewDisplayName("Lock Screen")

        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.compact))
            .previewDisplayName("Dynamic Island - Compact")

        attributes
            .previewContext(contentState, viewKind: .dynamicIsland(.expanded))
            .previewDisplayName("Dynamic Island - Expanded")
    }
}
