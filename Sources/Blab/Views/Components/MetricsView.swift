import SwiftUI

/// Real-time performance metrics display
struct MetricsView: View {
    @ObservedObject private var monitor = PerformanceMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Performance Metrics")
                    .font(.headline)
                Spacer()
                if monitor.isPerformanceWarning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            Divider()

            // Metrics Grid
            VStack(spacing: 8) {
                MetricRow(
                    icon: "cpu",
                    label: "CPU",
                    value: String(format: "%.1f%%", monitor.cpuUsage),
                    threshold: PerformanceMonitor.Thresholds.maxCPU,
                    currentValue: monitor.cpuUsage,
                    isInverted: false
                )

                MetricRow(
                    icon: "memorychip",
                    label: "Memory",
                    value: String(format: "%.1f MB", monitor.memoryUsage),
                    threshold: PerformanceMonitor.Thresholds.maxMemory,
                    currentValue: monitor.memoryUsage,
                    isInverted: false
                )

                MetricRow(
                    icon: "gauge.high",
                    label: "FPS",
                    value: String(format: "%.0f", monitor.fps),
                    threshold: PerformanceMonitor.Thresholds.minFPS,
                    currentValue: monitor.fps,
                    isInverted: true
                )

                MetricRow(
                    icon: "waveform.path.ecg",
                    label: "Control Loop",
                    value: String(format: "%.0f Hz", monitor.controlLoopHz),
                    threshold: PerformanceMonitor.Thresholds.targetControlLoopHz,
                    currentValue: monitor.controlLoopHz,
                    isInverted: true
                )
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(12)
        .shadow(radius: 5)
    }
}

// MARK: - Metric Row

struct MetricRow: View {
    let icon: String
    let label: String
    let value: String
    let threshold: Double
    let currentValue: Double
    let isInverted: Bool // If true, lower values are bad (e.g., FPS)

    private var isWarning: Bool {
        if isInverted {
            return currentValue > 0 && currentValue < threshold
        } else {
            return currentValue > threshold
        }
    }

    private var progressColor: Color {
        if isWarning {
            return .red
        } else if isInverted {
            return currentValue >= threshold ? .green : .yellow
        } else {
            return currentValue <= threshold * 0.8 ? .green : .yellow
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(progressColor)

            // Label
            Text(label)
                .font(.subheadline)
                .frame(width: 80, alignment: .leading)

            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)

                    // Progress
                    Rectangle()
                        .fill(progressColor)
                        .frame(
                            width: progressWidth(for: geometry.size.width),
                            height: 8
                        )
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)

            // Value
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .frame(width: 60, alignment: .trailing)
                .foregroundColor(isWarning ? .red : .primary)
        }
    }

    private func progressWidth(for totalWidth: CGFloat) -> CGFloat {
        let ratio: CGFloat
        if isInverted {
            // For FPS/Hz, show progress relative to target
            ratio = min(currentValue / threshold, 1.5) / 1.5
        } else {
            // For CPU/Memory, show progress relative to threshold
            ratio = min(currentValue / threshold, 1.5) / 1.5
        }
        return totalWidth * ratio
    }
}

// MARK: - Compact Metrics Badge

/// Compact metrics badge for inline display
struct MetricsBadge: View {
    @ObservedObject private var monitor = PerformanceMonitor.shared

    var body: some View {
        HStack(spacing: 8) {
            // Warning indicator
            if monitor.isPerformanceWarning {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
            }

            // CPU
            Label(
                String(format: "%.0f%%", monitor.cpuUsage),
                systemImage: "cpu"
            )
            .font(.caption2)

            // Memory
            Label(
                String(format: "%.0f", monitor.memoryUsage),
                systemImage: "memorychip"
            )
            .font(.caption2)

            // FPS
            Label(
                String(format: "%.0f", monitor.fps),
                systemImage: "gauge.high"
            )
            .font(.caption2)

            // Control Loop
            Label(
                String(format: "%.0f", monitor.controlLoopHz),
                systemImage: "waveform.path.ecg"
            )
            .font(.caption2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            monitor.isPerformanceWarning
                ? Color.yellow.opacity(0.2)
                : Color.green.opacity(0.2)
        )
        .cornerRadius(8)
    }
}

// MARK: - Performance Report View

struct PerformanceReportView: View {
    let report: PerformanceReport

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text("Performance Report")
                        .font(.title2)
                        .bold()
                    Spacer()
                    if report.meetsThresholds {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                            .font(.title2)
                    }
                }

                Text(report.timestamp.formatted())
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                // Metrics
                VStack(alignment: .leading, spacing: 12) {
                    MetricDetail(
                        label: "CPU Usage",
                        value: String(format: "%.1f%%", report.cpuUsage),
                        threshold: "\(PerformanceMonitor.Thresholds.maxCPU)%",
                        isGood: report.cpuUsage <= PerformanceMonitor.Thresholds.maxCPU
                    )

                    MetricDetail(
                        label: "Memory Usage",
                        value: String(format: "%.1f MB", report.memoryUsage),
                        threshold: "\(PerformanceMonitor.Thresholds.maxMemory) MB",
                        isGood: report.memoryUsage <= PerformanceMonitor.Thresholds.maxMemory
                    )

                    MetricDetail(
                        label: "Frame Rate",
                        value: String(format: "%.1f FPS", report.fps),
                        threshold: "\(PerformanceMonitor.Thresholds.minFPS) FPS",
                        isGood: report.fps >= PerformanceMonitor.Thresholds.minFPS || report.fps == 0
                    )

                    MetricDetail(
                        label: "Control Loop",
                        value: String(format: "%.1f Hz", report.controlLoopHz),
                        threshold: "\(PerformanceMonitor.Thresholds.targetControlLoopHz) Hz",
                        isGood: report.controlLoopHz >= PerformanceMonitor.Thresholds.minControlLoopHz || report.controlLoopHz == 0
                    )
                }

                // Warnings
                if !report.warnings.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Warnings")
                            .font(.headline)
                            .foregroundColor(.yellow)

                        ForEach(Array(report.warnings.enumerated()), id: \.offset) { index, warning in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.yellow)
                                Text(warning)
                                    .font(.caption)
                            }
                        }
                    }
                }

                // Status
                Divider()

                HStack {
                    Text("Overall Status:")
                        .font(.headline)
                    Spacer()
                    Text(report.meetsThresholds ? "All Thresholds Met" : "Performance Issues Detected")
                        .font(.subheadline)
                        .foregroundColor(report.meetsThresholds ? .green : .yellow)
                }
            }
            .padding()
        }
    }
}

// MARK: - Metric Detail

struct MetricDetail: View {
    let label: String
    let value: String
    let threshold: String
    let isGood: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title3)
                    .bold()
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Threshold")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(threshold)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Image(systemName: isGood ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isGood ? .green : .red)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Previews

struct MetricsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MetricsView()
                .padding()
                .previewDisplayName("Metrics View")

            MetricsBadge()
                .padding()
                .previewDisplayName("Metrics Badge")

            PerformanceReportView(
                report: PerformanceReport(
                    timestamp: Date(),
                    cpuUsage: 25.0,
                    memoryUsage: 150.0,
                    fps: 60.0,
                    controlLoopHz: 59.5,
                    meetsThresholds: true,
                    warnings: []
                )
            )
            .previewDisplayName("Performance Report - Good")

            PerformanceReportView(
                report: PerformanceReport(
                    timestamp: Date(),
                    cpuUsage: 45.0,
                    memoryUsage: 250.0,
                    fps: 45.0,
                    controlLoopHz: 48.0,
                    meetsThresholds: false,
                    warnings: [
                        "CPU usage (45.0%) exceeds threshold (30.0%)",
                        "Memory usage (250.0 MB) exceeds threshold (200.0 MB)",
                        "FPS (45.0) below minimum (50.0)",
                        "Control loop frequency (48.0 Hz) below minimum (50.0 Hz)"
                    ]
                )
            )
            .previewDisplayName("Performance Report - Warning")
        }
    }
}
