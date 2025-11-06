import SwiftUI

/// Real-time HRV monitoring view for Apple Watch
/// Displays current HRV (RMSSD), trend, and coherence score
struct HRVMonitorView: View {

    @EnvironmentObject var healthKitManager: WatchHealthKitManager

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Title
                Text("HRV Monitor")
                    .font(.headline)
                    .foregroundColor(.cyan)

                // Main HRV Value
                VStack(spacing: 4) {
                    Text("\(Int(healthKitManager.currentHRV))")
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundColor(.green)

                    Text("ms RMSSD")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Coherence Score
                CoherenceGaugeView(coherence: healthKitManager.hrvCoherence)

                // Trend Indicator
                HRVTrendView(trend: healthKitManager.hrvTrend)

                // Last Update
                Text("Updated: \(formatTime(healthKitManager.lastUpdateTime))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .containerBackground(.black.gradient, for: .navigation)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Coherence gauge showing 0-100 score
struct CoherenceGaugeView: View {
    let coherence: Double

    var coherenceColor: Color {
        if coherence >= 80 {
            return .green
        } else if coherence >= 50 {
            return .yellow
        } else {
            return .red
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Circular gauge
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: coherence / 100)
                    .stroke(
                        coherenceColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: coherence)

                VStack(spacing: 2) {
                    Text("\(Int(coherence))")
                        .font(.title2.bold())
                        .foregroundColor(coherenceColor)

                    Text("Coherence")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 100, height: 100)

            // Status text
            Text(coherenceStatus)
                .font(.caption)
                .foregroundColor(coherenceColor)
        }
    }

    var coherenceStatus: String {
        if coherence >= 80 {
            return "Excellent"
        } else if coherence >= 60 {
            return "Good"
        } else if coherence >= 40 {
            return "Fair"
        } else {
            return "Low"
        }
    }
}

/// HRV trend indicator (up/down/stable)
struct HRVTrendView: View {
    let trend: HRVTrend

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: trendIcon)
                .foregroundColor(trendColor)

            Text(trendText)
                .font(.caption)
                .foregroundColor(trendColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(trendColor.opacity(0.2))
        .cornerRadius(12)
    }

    var trendIcon: String {
        switch trend {
        case .increasing:
            return "arrow.up.right"
        case .decreasing:
            return "arrow.down.right"
        case .stable:
            return "arrow.right"
        }
    }

    var trendColor: Color {
        switch trend {
        case .increasing:
            return .green
        case .decreasing:
            return .red
        case .stable:
            return .yellow
        }
    }

    var trendText: String {
        switch trend {
        case .increasing:
            return "Improving"
        case .decreasing:
            return "Declining"
        case .stable:
            return "Stable"
        }
    }
}

enum HRVTrend {
    case increasing
    case decreasing
    case stable
}

#Preview {
    HRVMonitorView()
        .environmentObject(WatchHealthKitManager())
}
