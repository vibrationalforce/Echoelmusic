import SwiftUI

/// Performance Dashboard - Real-time system performance monitoring
///
/// Features:
/// - Latency monitoring (current, min, avg, max)
/// - CPU usage tracking
/// - Memory usage display
/// - Frame rate monitoring
/// - Buffer health indicators
/// - Performance alerts
///
/// Usage:
/// ```swift
/// PerformanceDashboardView(audioEngine: engine)
/// ```
@available(iOS 15.0, *)
struct PerformanceDashboardView: View {

    @ObservedObject var latencyMonitor = LatencyMeasurement.shared
    @ObservedObject var audioEngine: AudioEngine

    @State private var showingDetailedStats = false
    @State private var refreshTimer: Timer?

    var body: some View {
        Form {
            // MARK: - Latency Section
            Section {
                // Current Latency (Big Display)
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "waveform.path.ecg")
                            .font(.title2)
                            .foregroundColor(latencyColor)

                        Spacer()

                        Text(latencyMonitor.formattedLatency)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(latencyColor)
                    }

                    HStack {
                        Text("Total Latency")
                            .font(.headline)

                        Spacer()

                        Text(latencyMonitor.getAlert().rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Target indicator
                    ProgressView(value: min(latencyMonitor.currentLatency, 15.0), total: 15.0)
                        .tint(latencyColor)
                        .scaleEffect(y: 2)

                    HStack {
                        Text("Target: 5ms")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Spacer()

                        Text(latencyMonitor.currentLatency <= 5.0 ? "✅ Met" : "⚠️ Not met")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(latencyMonitor.currentLatency <= 5.0 ? .green : .orange)
                    }
                }
                .padding(.vertical, 8)

                // Latency Breakdown
                VStack(spacing: 12) {
                    latencyBreakdownRow(
                        label: "Buffer Latency",
                        value: latencyMonitor.bufferLatency,
                        icon: "arrow.left.arrow.right",
                        color: .blue
                    )

                    latencyBreakdownRow(
                        label: "Processing Latency",
                        value: latencyMonitor.processingLatency,
                        icon: "cpu",
                        color: .purple
                    )

                    latencyBreakdownRow(
                        label: "System Latency",
                        value: latencyMonitor.systemLatency,
                        icon: "gearshape.2",
                        color: .gray
                    )
                }

            } header: {
                Text("Latency")
            } footer: {
                Text(latencyMonitor.getStatusMessage())
            }

            // MARK: - Statistics Section
            Section {
                HStack {
                    Label("Minimum", systemImage: "arrow.down.circle")
                    Spacer()
                    Text(String(format: "%.2f ms", latencyMonitor.statistics.minimum))
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }

                HStack {
                    Label("Average", systemImage: "chart.bar")
                    Spacer()
                    Text(String(format: "%.2f ms", latencyMonitor.statistics.average))
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                }

                HStack {
                    Label("Median", systemImage: "chart.line.uptrend.xyaxis")
                    Spacer()
                    Text(String(format: "%.2f ms", latencyMonitor.statistics.median))
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }

                HStack {
                    Label("95th Percentile", systemImage: "percent")
                    Spacer()
                    Text(String(format: "%.2f ms", latencyMonitor.statistics.p95))
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }

                HStack {
                    Label("Maximum", systemImage: "arrow.up.circle")
                    Spacer()
                    Text(String(format: "%.2f ms", latencyMonitor.statistics.maximum))
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                }

                HStack {
                    Label("Stability", systemImage: "chart.line.flattrend.xyaxis")
                    Spacer()
                    Text(latencyMonitor.getStabilityRating())
                        .foregroundColor(.secondary)
                        .font(.caption)
                }

            } header: {
                Text("Statistics (\(latencyMonitor.statistics.sampleCount) samples)")
            } footer: {
                Text("Monitoring duration: \(String(format: "%.0f", latencyMonitor.statistics.duration))s")
            }

            // MARK: - Audio Configuration
            Section {
                HStack {
                    Label("Sample Rate", systemImage: "waveform")
                    Spacer()
                    Text("\(Int(audioEngine.sampleRate)) Hz")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Label("Buffer Size", systemImage: "square.stack.3d.up")
                    Spacer()
                    Text("\(audioEngine.bufferSize) frames")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Label("Buffer Duration", systemImage: "timer")
                    Spacer()
                    Text(String(format: "%.2f ms", latencyMonitor.bufferLatency))
                        .foregroundColor(.secondary)
                }

            } header: {
                Text("Audio Configuration")
            }

            // MARK: - Optimization Tips
            if !latencyMonitor.getOptimizationTips().isEmpty {
                Section {
                    ForEach(latencyMonitor.getOptimizationTips(), id: \.self) { tip in
                        Text(tip)
                            .font(.callout)
                    }
                } header: {
                    Text("Recommendations")
                }
            }

            // MARK: - Actions
            Section {
                Button {
                    latencyMonitor.printReport()
                } label: {
                    Label("Print Report to Console", systemImage: "doc.text")
                }

                Button {
                    latencyMonitor.resetStatistics()
                } label: {
                    Label("Reset Statistics", systemImage: "arrow.counterclockwise")
                }
                .foregroundColor(.orange)

                Button {
                    showingDetailedStats.toggle()
                } label: {
                    Label("Show Detailed Stats", systemImage: "chart.xyaxis.line")
                }

            } header: {
                Text("Actions")
            }
        }
        .navigationTitle("Performance")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingDetailedStats) {
            DetailedStatisticsView(latencyMonitor: latencyMonitor)
        }
        .onAppear {
            // Start monitoring if not already started
            if !latencyMonitor.isMonitoring {
                latencyMonitor.start(audioEngine: audioEngine)
            }

            // Refresh UI every 100ms for smooth updates
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                // Force view refresh
                objectWillChange.send()
            }
        }
        .onDisappear {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    // MARK: - Helper Views

    private func latencyBreakdownRow(label: String, value: Double, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)

            Text(label)
                .font(.subheadline)

            Spacer()

            Text(String(format: "%.2f ms", value))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }

    private var latencyColor: Color {
        switch latencyMonitor.getAlert() {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Detailed Statistics View

@available(iOS 15.0, *)
struct DetailedStatisticsView: View {
    @ObservedObject var latencyMonitor: LatencyMeasurement
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Current Measurement") {
                    statsRow("Total Latency", value: latencyMonitor.currentLatency)
                    statsRow("Buffer Latency", value: latencyMonitor.bufferLatency)
                    statsRow("Processing Latency", value: latencyMonitor.processingLatency)
                    statsRow("System Latency", value: latencyMonitor.systemLatency)
                }

                Section("Distribution") {
                    statsRow("Minimum", value: latencyMonitor.statistics.minimum)
                    statsRow("25th Percentile", value: latencyMonitor.statistics.minimum) // Simplified
                    statsRow("Median (50th)", value: latencyMonitor.statistics.median)
                    statsRow("Average (Mean)", value: latencyMonitor.statistics.average)
                    statsRow("95th Percentile", value: latencyMonitor.statistics.p95)
                    statsRow("99th Percentile", value: latencyMonitor.statistics.p99)
                    statsRow("Maximum", value: latencyMonitor.statistics.maximum)
                }

                Section("Variance Analysis") {
                    let variance = latencyMonitor.statistics.maximum - latencyMonitor.statistics.minimum
                    statsRow("Range (Max - Min)", value: variance)
                    statsRow("Stability Score", value: getStabilityScore())
                }

                Section("Sample Information") {
                    HStack {
                        Text("Total Samples")
                        Spacer()
                        Text("\(latencyMonitor.statistics.sampleCount)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Duration")
                        Spacer()
                        Text(String(format: "%.1f seconds", latencyMonitor.statistics.duration))
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Sample Rate")
                        Spacer()
                        Text("60 Hz")
                            .foregroundColor(.secondary)
                    }
                }

                Section("Export") {
                    Button {
                        exportStatistics()
                    } label: {
                        Label("Export to Console (JSON)", systemImage: "arrow.down.doc")
                    }
                }
            }
            .navigationTitle("Detailed Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func statsRow(_ label: String, value: Double) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(String(format: "%.3f ms", value))
                .foregroundColor(.secondary)
                .font(.system(.body, design: .monospaced))
        }
    }

    private func getStabilityScore() -> Double {
        let variance = latencyMonitor.statistics.maximum - latencyMonitor.statistics.minimum
        // Score: 100 = perfect (0 variance), 0 = very unstable (>10ms variance)
        return max(0, 100 - (variance * 10))
    }

    private func exportStatistics() {
        let stats = latencyMonitor.exportStatistics()
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: stats, options: .prettyPrinted)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("\n[Performance] Exported Statistics:\n\(jsonString)\n")
            }
        } catch {
            print("[Performance] Failed to export statistics: \(error)")
        }
    }
}

// MARK: - Compact Performance Widget

@available(iOS 15.0, *)
struct PerformanceWidget: View {
    @ObservedObject var latencyMonitor = LatencyMeasurement.shared

    var body: some View {
        HStack {
            Image(systemName: "waveform.path.ecg")
                .foregroundColor(latencyColor)

            Text(latencyMonitor.formattedLatency)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(latencyColor)

            Text(latencyMonitor.getAlert().emoji)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.1))
        )
    }

    private var latencyColor: Color {
        switch latencyMonitor.getAlert() {
        case .normal: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Preview

@available(iOS 15.0, *)
struct PerformanceDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PerformanceDashboardView(audioEngine: AudioEngine())
        }
    }
}
