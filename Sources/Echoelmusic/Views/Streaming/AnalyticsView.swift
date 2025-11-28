//
//  AnalyticsView.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//
//  ANALYTICS VIEW - Stream statistics and metrics
//

import SwiftUI
import Charts

struct AnalyticsView: View {
    @StateObject private var liveEngine = LiveStreamingEngine.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Analytics")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Key metrics
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        MetricCard(
                            title: "Total Viewers",
                            value: "\(liveEngine.analytics.totalViewers)",
                            icon: "person.2.fill",
                            color: .blue
                        )

                        MetricCard(
                            title: "Peak Viewers",
                            value: "\(liveEngine.analytics.peakViewers)",
                            icon: "arrow.up.circle.fill",
                            color: .green
                        )

                        MetricCard(
                            title: "Avg. Watch Time",
                            value: formatTime(liveEngine.analytics.averageViewTime),
                            icon: "clock.fill",
                            color: .orange
                        )

                        MetricCard(
                            title: "Chat Messages",
                            value: "\(liveEngine.analytics.chatMessagesCount)",
                            icon: "message.fill",
                            color: .purple
                        )
                    }

                    Divider()

                    // Stream health
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Stream Health")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        HStack {
                            VStack(alignment: .leading) {
                                Text("Bitrate")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(liveEngine.analytics.averageBitrate / 1_000_000) Mbps")
                                    .font(.headline)
                            }

                            Spacer()

                            VStack(alignment: .leading) {
                                Text("Dropped Frames")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f%%", liveEngine.analytics.droppedFramesPercent))
                                    .font(.headline)
                                    .foregroundColor(
                                        liveEngine.analytics.droppedFramesPercent > 5 ? .red : .green
                                    )
                            }
                        }

                        // Health bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.2))

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(healthColor)
                                    .frame(width: geometry.size.width * healthPercentage)
                            }
                        }
                        .frame(height: 8)
                    }

                    Divider()

                    // Viewer graph placeholder
                    VStack(alignment: .leading) {
                        Text("Viewer Count")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 150)
                            .overlay(
                                Text("Viewer graph")
                                    .foregroundColor(.secondary)
                            )
                    }
                }
                .padding()
            }
        }
        .background(Color.gray.opacity(0.05))
    }

    private var healthPercentage: CGFloat {
        switch liveEngine.streamHealth {
        case .excellent: return 1.0
        case .good: return 0.8
        case .fair: return 0.6
        case .poor: return 0.4
        case .critical: return 0.2
        }
    }

    private var healthColor: Color {
        switch liveEngine.streamHealth {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .yellow
        case .poor: return .orange
        case .critical: return .red
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct StreamSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Stream Settings")) {
                    TextField("Stream Title", text: .constant("My Stream"))
                    TextField("Stream Key", text: .constant("xxxx-xxxx-xxxx"))
                }

                Section(header: Text("Video")) {
                    Picker("Resolution", selection: .constant(0)) {
                        Text("1080p").tag(0)
                        Text("720p").tag(1)
                    }

                    Picker("Framerate", selection: .constant(0)) {
                        Text("60 fps").tag(0)
                        Text("30 fps").tag(1)
                    }

                    Picker("Bitrate", selection: .constant(0)) {
                        Text("6000 Kbps").tag(0)
                        Text("4500 Kbps").tag(1)
                    }
                }

                Section(header: Text("Audio")) {
                    Picker("Sample Rate", selection: .constant(0)) {
                        Text("48 kHz").tag(0)
                        Text("44.1 kHz").tag(1)
                    }

                    Picker("Bitrate", selection: .constant(0)) {
                        Text("128 Kbps").tag(0)
                        Text("96 Kbps").tag(1)
                    }
                }
            }
            .navigationTitle("Stream Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#if DEBUG
struct AnalyticsView_Previews: PreviewProvider {
    static var previews: some View {
        AnalyticsView()
            .frame(width: 350, height: 600)
    }
}
#endif
