import SwiftUI
import WidgetKit

/// Widget entry view - Adapts to different widget sizes
struct HRVWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: HRVWidgetEntry

    var body: some View {
        switch widgetFamily {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        @unknown default:
            SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Small Widget (68x68 pt)

struct SmallWidgetView: View {
    let entry: HRVWidgetEntry

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    entry.coherenceColor.opacity(0.3),
                    entry.coherenceColor.opacity(0.1)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 8) {
                // Icon
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundColor(entry.coherenceColor)

                // HRV value
                Text(entry.hrvFormatted)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                // Label
                Text("HRV")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .widgetURL(URL(string: "echoelmusic://hrv"))
    }
}

// MARK: - Medium Widget (157x68 pt)

struct MediumWidgetView: View {
    let entry: HRVWidgetEntry

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    entry.coherenceColor.opacity(0.2),
                    entry.coherenceColor.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            HStack(spacing: 16) {
                // Left: HRV
                VStack(spacing: 4) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.title3)
                        .foregroundColor(entry.coherenceColor)

                    Text(entry.hrvFormatted)
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)

                    Text("HRV")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 50)

                // Right: Coherence
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
                            .frame(width: 40, height: 40)

                        Circle()
                            .trim(from: 0, to: entry.coherence / 100)
                            .stroke(entry.coherenceColor, lineWidth: 6)
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(-90))
                    }

                    Text(entry.coherenceFormatted)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)

                    Text("Coherence")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .widgetURL(URL(string: "echoelmusic://hrv"))
    }
}

// MARK: - Large Widget (157x157 pt)

struct LargeWidgetView: View {
    let entry: HRVWidgetEntry

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    entry.coherenceColor.opacity(0.2),
                    entry.coherenceColor.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 12) {
                // Header
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(entry.coherenceColor)

                    Text("Echoelmusic")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    // Status indicator
                    Circle()
                        .fill(entry.coherenceColor)
                        .frame(width: 8, height: 8)
                }
                .padding(.horizontal)
                .padding(.top)

                Divider()

                // Stats grid
                VStack(spacing: 16) {
                    // HRV
                    StatRow(
                        icon: "waveform.path.ecg",
                        label: "HRV",
                        value: entry.hrvFormatted,
                        color: entry.coherenceColor
                    )

                    // Coherence
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .frame(width: 24)
                            .foregroundColor(entry.coherenceColor)

                        Text("Coherence")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        // Coherence gauge
                        ZStack {
                            Circle()
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 4)
                                .frame(width: 32, height: 32)

                            Circle()
                                .trim(from: 0, to: entry.coherence / 100)
                                .stroke(entry.coherenceColor, lineWidth: 4)
                                .frame(width: 32, height: 32)
                                .rotationEffect(.degrees(-90))
                        }

                        Text(entry.coherenceFormatted)
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal)

                    // Heart Rate
                    StatRow(
                        icon: "heart.fill",
                        label: "Heart Rate",
                        value: entry.heartRateFormatted,
                        color: .red
                    )

                    // Breathing Phase
                    StatRow(
                        icon: "wind",
                        label: "Breathing",
                        value: entry.breathingPhase,
                        color: .blue
                    )
                }

                Spacer()

                // Last updated
                Text("Updated \(entry.date, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
            }
        }
        .widgetURL(URL(string: "echoelmusic://hrv"))
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(color)

            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.system(.body, design: .rounded))
                .fontWeight(.semibold)
        }
        .padding(.horizontal)
    }
}
