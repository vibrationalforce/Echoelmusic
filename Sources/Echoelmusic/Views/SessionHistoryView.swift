#if canImport(SwiftUI) && canImport(SwiftData)
import SwiftUI
import SwiftData

/// Shows past soundscape sessions with bio metrics.
struct SessionHistoryView: View {

    @Query(sort: \SoundscapeSession.startDate, order: .reverse)
    private var sessions: [SoundscapeSession]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 32))
                .foregroundStyle(.white.opacity(0.15))
            Text("No sessions yet")
                .foregroundStyle(.white.opacity(0.3))
            Text("Play a soundscape for at least 10 seconds to record a session.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.2))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var sessionList: some View {
        List(sessions) { session in
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(session.startDate, style: .date)
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text(formatDuration(session.durationSeconds))
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 16) {
                    metricPill("HR", String(format: "%.0f", session.avgHeartRate))
                    metricPill("HRV", String(format: "%.0f%%", session.avgHRV * 100))
                    metricPill("Coh", String(format: "%.0f%%", session.avgCoherence * 100))
                    metricPill("Peak", String(format: "%.0f%%", session.peakCoherence * 100))
                }

                HStack(spacing: 8) {
                    Text(session.primarySource)
                    Text("·")
                    Text(session.circadianPhase.capitalized)
                    Text("·")
                    Text(session.weatherCondition.capitalized)
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private func metricPill(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return m > 0 ? "\(m)m \(s)s" : "\(s)s"
    }
}
#endif
