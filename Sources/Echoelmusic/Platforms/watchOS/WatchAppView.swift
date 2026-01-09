import SwiftUI

#if os(watchOS)
import WatchKit

/// Main SwiftUI App entry point for watchOS
@main
struct EchoelmusicWatchApp: App {

    @State private var watchApp = WatchApp()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environment(watchApp)
        }
    }
}

/// Main content view for watchOS
struct WatchContentView: View {

    @Environment(WatchApp.self) private var watchApp
    @State private var selectedTab: WatchTab = .metrics

    var body: some View {
        TabView(selection: $selectedTab) {
            // Bio Metrics Tab
            WatchMetricsView()
                .tag(WatchTab.metrics)

            // Session Tab
            WatchSessionView()
                .tag(WatchTab.session)

            // Settings Tab
            WatchSettingsView()
                .tag(WatchTab.settings)
        }
        .tabViewStyle(.verticalPage)
    }

    enum WatchTab {
        case metrics
        case session
        case settings
    }
}

/// Bio metrics display for watchOS
struct WatchMetricsView: View {

    @Environment(WatchApp.self) private var watchApp

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Heart Rate
                MetricCard(
                    icon: "heart.fill",
                    value: "\(Int(watchApp.currentMetrics.heartRate))",
                    unit: "BPM",
                    color: .red
                )

                // HRV
                MetricCard(
                    icon: "waveform.path.ecg",
                    value: String(format: "%.0f", watchApp.currentMetrics.hrv * 100),
                    unit: "HRV",
                    color: .purple
                )

                // Coherence
                CoherenceRing(coherence: watchApp.currentMetrics.coherence)
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("Metrics")
    }
}

/// Session control view for watchOS
struct WatchSessionView: View {

    @Environment(WatchApp.self) private var watchApp
    @State private var selectedSessionType: WatchApp.SessionType = .breathing

    var body: some View {
        VStack(spacing: 16) {
            if watchApp.isSessionActive {
                // Active session view
                VStack(spacing: 8) {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)

                    Text("Session Active")
                        .font(.headline)

                    Text(formatDuration(watchApp.sessionDuration))
                        .font(.system(.title2, design: .monospaced))
                        .foregroundColor(.green)

                    Button(action: {
                        Task {
                            await watchApp.stopSession()
                        }
                    }) {
                        Label("Stop", systemImage: "stop.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            } else {
                // Session picker
                VStack(spacing: 12) {
                    Text("Start Session")
                        .font(.headline)

                    ForEach([WatchApp.SessionType.breathing, .meditation, .hrvTraining], id: \.self) { type in
                        Button(action: {
                            Task {
                                try? await watchApp.startSession(type: type)
                            }
                        }) {
                            HStack {
                                Image(systemName: iconFor(type))
                                Text(type.rawValue)
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .navigationTitle("Session")
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func iconFor(_ type: WatchApp.SessionType) -> String {
        switch type {
        case .breathing: return "wind"
        case .meditation: return "brain.head.profile"
        case .hrvTraining: return "heart.text.square"
        case .coherenceBuilding: return "waveform.path"
        }
    }
}

/// Settings view for watchOS
struct WatchSettingsView: View {

    @Environment(WatchApp.self) private var watchApp
    @AppStorage("breathingRate") private var breathingRate: Double = 6.0
    @AppStorage("hapticFeedback") private var hapticFeedback: Bool = true
    @AppStorage("audioFeedback") private var audioFeedback: Bool = true

    var body: some View {
        List {
            Section("Breathing") {
                Stepper(value: $breathingRate, in: 4...12, step: 0.5) {
                    VStack(alignment: .leading) {
                        Text("Rate")
                        Text("\(breathingRate, specifier: "%.1f") /min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Feedback") {
                Toggle("Haptic", isOn: $hapticFeedback)
                Toggle("Audio", isOn: $audioFeedback)
            }

            Section("Info") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Components

struct MetricCard: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)

            Spacer()

            VStack(alignment: .trailing) {
                Text(value)
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
    }
}

struct CoherenceRing: View {
    let coherence: Double

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: CGFloat(coherence))
                    .stroke(coherenceColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack {
                    Text("\(Int(coherence * 100))")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                    Text("%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 80, height: 80)

            Text("Coherence")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var coherenceColor: Color {
        switch coherence {
        case 0.8...1.0: return .green
        case 0.5..<0.8: return .yellow
        default: return .red
        }
    }
}

#endif
