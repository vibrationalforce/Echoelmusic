import SwiftUI
import Charts

// MARK: - Science Visualization Dashboard
/// Research-grade biometric visualization with clinical accuracy
/// Pure scientific data presentation - evidence-based only

struct ScienceDashboardView: View {

    @ObservedObject var scienceHub: ScienceModeHub
    @State private var selectedMetric: MetricType = .hrv
    @State private var timeWindow: TimeWindow = .minutes5

    enum MetricType: String, CaseIterable {
        case hrv = "HRV"
        case heartRate = "Heart Rate"
        case coherence = "Coherence"
        case frequency = "Frequency"
        case poincare = "Poincaré"
    }

    enum TimeWindow: String, CaseIterable {
        case minutes1 = "1 min"
        case minutes5 = "5 min"
        case minutes10 = "10 min"
        case session = "Session"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with session status
                SessionStatusHeader(scienceHub: scienceHub)

                // Real-time metrics
                RealTimeMetricsGrid(metrics: scienceHub.bioMetrics, hrvAnalysis: scienceHub.hrvAnalysis)

                // Metric selector
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(MetricType.allCases, id: \.self) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Time window selector
                Picker("Time", selection: $timeWindow) {
                    ForEach(TimeWindow.allCases, id: \.self) { window in
                        Text(window.rawValue).tag(window)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Main visualization
                Group {
                    switch selectedMetric {
                    case .hrv:
                        HRVTimeSeriesChart(data: scienceHub.sessionData, window: timeWindow)
                    case .heartRate:
                        HeartRateChart(data: scienceHub.sessionData, window: timeWindow)
                    case .coherence:
                        CoherenceChart(data: scienceHub.sessionData, window: timeWindow)
                    case .frequency:
                        FrequencySpectrumChart(spectrum: scienceHub.hrvAnalysis.frequencySpectrum)
                    case .poincare:
                        PoincareScatterPlot(points: scienceHub.hrvAnalysis.poincarePoints, sd1: scienceHub.hrvAnalysis.sd1, sd2: scienceHub.hrvAnalysis.sd2)
                    }
                }
                .frame(height: 300)
                .padding()

                // HRV Analysis Summary
                HRVAnalysisSummary(analysis: scienceHub.hrvAnalysis)

                // Statistical Summary
                if !scienceHub.sessionData.isEmpty {
                    StatisticalSummaryView(data: scienceHub.sessionData)
                }

                // Export buttons
                ExportControlsView(scienceHub: scienceHub)
            }
            .padding()
        }
        .navigationTitle("Science Dashboard")
    }
}

// MARK: - Session Status Header

struct SessionStatusHeader: View {
    @ObservedObject var scienceHub: ScienceModeHub

    var body: some View {
        HStack {
            Circle()
                .fill(scienceHub.isActive ? Color.green : Color.gray)
                .frame(width: 12, height: 12)

            Text(scienceHub.isActive ? "Recording" : "Idle")
                .font(.headline)

            Spacer()

            if scienceHub.isActive {
                Text("\(scienceHub.sessionData.count) samples")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button(scienceHub.isActive ? "Stop" : "Start") {
                if scienceHub.isActive {
                    _ = scienceHub.endSession()
                } else {
                    scienceHub.startSession()
                }
            }
            .buttonStyle(.bordered)
            .tint(scienceHub.isActive ? .red : .green)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Real-Time Metrics Grid

struct RealTimeMetricsGrid: View {
    let metrics: RealTimeBioMetrics
    let hrvAnalysis: AdvancedHRVAnalysis

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            MetricCard(
                title: "Heart Rate",
                value: String(format: "%.0f", metrics.heartRate),
                unit: "BPM",
                color: .red,
                range: "Normal: 60-100"
            )

            MetricCard(
                title: "HRV (RMSSD)",
                value: String(format: "%.1f", metrics.hrv),
                unit: "ms",
                color: .green,
                range: "Normal: 20-100"
            )

            MetricCard(
                title: "Coherence",
                value: String(format: "%.0f", metrics.coherence),
                unit: "%",
                color: .blue,
                range: "Target: >60"
            )

            MetricCard(
                title: "SDNN",
                value: String(format: "%.1f", hrvAnalysis.sdnn),
                unit: "ms",
                color: .purple,
                range: "Normal: 50-100"
            )

            MetricCard(
                title: "pNN50",
                value: String(format: "%.1f", hrvAnalysis.pnn50),
                unit: "%",
                color: .orange,
                range: "Normal: 3-30"
            )

            MetricCard(
                title: "Stress Index",
                value: String(format: "%.0f", hrvAnalysis.stressIndex),
                unit: "",
                color: stressColor(hrvAnalysis.stressIndex),
                range: "Low: <40"
            )
        }
        .padding(.horizontal)
    }

    private func stressColor(_ value: Double) -> Color {
        if value < 40 { return .green }
        if value < 60 { return .yellow }
        if value < 80 { return .orange }
        return .red
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    let range: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)

                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(range)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - HRV Time Series Chart

struct HRVTimeSeriesChart: View {
    let data: [SessionDataPoint]
    let window: ScienceDashboardView.TimeWindow

    private var filteredData: [SessionDataPoint] {
        let cutoff: TimeInterval
        switch window {
        case .minutes1: cutoff = 60
        case .minutes5: cutoff = 300
        case .minutes10: cutoff = 600
        case .session: return data
        }

        let now = Date()
        return data.filter { now.timeIntervalSince($0.timestamp) <= cutoff }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("HRV (RMSSD) Over Time")
                .font(.headline)

            if #available(iOS 16.0, *) {
                Chart(filteredData) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("HRV", point.hrv)
                    )
                    .foregroundStyle(.green)
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartYAxisLabel("RMSSD (ms)")
            } else {
                // Fallback for older iOS
                CanvasLineChart(data: filteredData.map { ($0.timestamp, $0.hrv) }, color: .green)
            }
        }
    }
}

// MARK: - Heart Rate Chart

struct HeartRateChart: View {
    let data: [SessionDataPoint]
    let window: ScienceDashboardView.TimeWindow

    private var filteredData: [SessionDataPoint] {
        let cutoff: TimeInterval
        switch window {
        case .minutes1: cutoff = 60
        case .minutes5: cutoff = 300
        case .minutes10: cutoff = 600
        case .session: return data
        }

        let now = Date()
        return data.filter { now.timeIntervalSince($0.timestamp) <= cutoff }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Heart Rate Over Time")
                .font(.headline)

            if #available(iOS 16.0, *) {
                Chart(filteredData) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("HR", point.heartRate)
                    )
                    .foregroundStyle(.red)
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartYAxisLabel("BPM")
            } else {
                CanvasLineChart(data: filteredData.map { ($0.timestamp, $0.heartRate) }, color: .red)
            }
        }
    }
}

// MARK: - Coherence Chart

struct CoherenceChart: View {
    let data: [SessionDataPoint]
    let window: ScienceDashboardView.TimeWindow

    private var filteredData: [SessionDataPoint] {
        let cutoff: TimeInterval
        switch window {
        case .minutes1: cutoff = 60
        case .minutes5: cutoff = 300
        case .minutes10: cutoff = 600
        case .session: return data
        }

        let now = Date()
        return data.filter { now.timeIntervalSince($0.timestamp) <= cutoff }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Coherence Score Over Time")
                .font(.headline)

            if #available(iOS 16.0, *) {
                Chart(filteredData) { point in
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Coherence", point.coherence)
                    )
                    .foregroundStyle(.blue.opacity(0.3))

                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Coherence", point.coherence)
                    )
                    .foregroundStyle(.blue)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartYAxisLabel("Score")
            } else {
                CanvasLineChart(data: filteredData.map { ($0.timestamp, $0.coherence) }, color: .blue)
            }
        }
    }
}

// MARK: - Frequency Spectrum Chart

struct FrequencySpectrumChart: View {
    let spectrum: [FrequencyPoint]

    var body: some View {
        VStack(alignment: .leading) {
            Text("HRV Power Spectrum")
                .font(.headline)

            HStack {
                Text("VLF").font(.caption2).foregroundColor(.gray)
                Text("LF").font(.caption2).foregroundColor(.orange)
                Text("HF").font(.caption2).foregroundColor(.green)
            }

            Canvas { context, size in
                guard !spectrum.isEmpty else { return }

                let maxPower = spectrum.map { $0.power }.max() ?? 1
                let maxFreq = 0.5 // Hz

                // Draw frequency bands
                let vlfEnd = 0.04 / maxFreq * size.width
                let lfEnd = 0.15 / maxFreq * size.width
                let hfEnd = 0.4 / maxFreq * size.width

                // VLF band (gray)
                context.fill(
                    Path(CGRect(x: 0, y: 0, width: vlfEnd, height: size.height)),
                    with: .color(.gray.opacity(0.1))
                )

                // LF band (orange)
                context.fill(
                    Path(CGRect(x: vlfEnd, y: 0, width: lfEnd - vlfEnd, height: size.height)),
                    with: .color(.orange.opacity(0.1))
                )

                // HF band (green)
                context.fill(
                    Path(CGRect(x: lfEnd, y: 0, width: hfEnd - lfEnd, height: size.height)),
                    with: .color(.green.opacity(0.1))
                )

                // Draw spectrum line
                var path = Path()
                for (index, point) in spectrum.enumerated() {
                    let x = point.frequency / maxFreq * size.width
                    let y = size.height - (point.power / maxPower * size.height * 0.9)

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }

                context.stroke(path, with: .color(.blue), lineWidth: 2)

                // Axis labels
                let xAxisLabels = ["0", "0.1", "0.2", "0.3", "0.4", "0.5"]
                for (i, label) in xAxisLabels.enumerated() {
                    let x = CGFloat(i) / CGFloat(xAxisLabels.count - 1) * size.width
                    context.draw(
                        Text(label).font(.caption2),
                        at: CGPoint(x: x, y: size.height + 10)
                    )
                }
            }

            Text("Frequency (Hz)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

// MARK: - Poincaré Scatter Plot

struct PoincareScatterPlot: View {
    let points: [PoincarePoint]
    let sd1: Double
    let sd2: Double

    var body: some View {
        VStack(alignment: .leading) {
            Text("Poincaré Plot (RRn vs RRn+1)")
                .font(.headline)

            HStack {
                Text("SD1: \(String(format: "%.1f", sd1)) ms")
                    .font(.caption)
                Text("SD2: \(String(format: "%.1f", sd2)) ms")
                    .font(.caption)
                Text("Ratio: \(String(format: "%.2f", sd1 / max(sd2, 1)))")
                    .font(.caption)
            }
            .foregroundColor(.secondary)

            Canvas { context, size in
                guard !points.isEmpty else { return }

                let allValues = points.flatMap { [$0.x, $0.y] }
                let minVal = allValues.min() ?? 600
                let maxVal = allValues.max() ?? 1000
                let range = maxVal - minVal

                func scale(_ value: Double, in dimension: CGFloat) -> CGFloat {
                    CGFloat((value - minVal) / range) * dimension * 0.9 + dimension * 0.05
                }

                // Draw identity line
                let identityPath = Path { path in
                    path.move(to: CGPoint(x: 0, y: size.height))
                    path.addLine(to: CGPoint(x: size.width, y: 0))
                }
                context.stroke(identityPath, with: .color(.gray.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [5]))

                // Draw points
                for point in points {
                    let x = scale(point.x, in: size.width)
                    let y = size.height - scale(point.y, in: size.height)

                    let circle = Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6))
                    context.fill(circle, with: .color(.blue.opacity(0.5)))
                }

                // Draw SD1/SD2 ellipse (simplified)
                let centerX = size.width / 2
                let centerY = size.height / 2
                let ellipseWidth = CGFloat(sd2 / range) * size.width * 2
                let ellipseHeight = CGFloat(sd1 / range) * size.height * 2

                let ellipse = Path(ellipseIn: CGRect(
                    x: centerX - ellipseWidth/2,
                    y: centerY - ellipseHeight/2,
                    width: ellipseWidth,
                    height: ellipseHeight
                ))
                context.stroke(ellipse, with: .color(.red), lineWidth: 2)
            }

            HStack {
                Text("RRn (ms)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
    }
}

// MARK: - HRV Analysis Summary

struct HRVAnalysisSummary: View {
    let analysis: AdvancedHRVAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("HRV Analysis Summary")
                .font(.headline)

            GroupBox("Time Domain") {
                HStack {
                    VStack(alignment: .leading) {
                        AnalysisRow(label: "Mean RR", value: String(format: "%.0f ms", analysis.meanRR))
                        AnalysisRow(label: "SDNN", value: String(format: "%.1f ms", analysis.sdnn))
                        AnalysisRow(label: "RMSSD", value: String(format: "%.1f ms", analysis.rmssd))
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        AnalysisRow(label: "Heart Rate", value: String(format: "%.0f BPM", analysis.heartRate))
                        AnalysisRow(label: "pNN50", value: String(format: "%.1f%%", analysis.pnn50))
                        AnalysisRow(label: "Stress Index", value: String(format: "%.0f", analysis.stressIndex))
                    }
                }
            }

            GroupBox("Frequency Domain") {
                HStack {
                    VStack(alignment: .leading) {
                        AnalysisRow(label: "VLF Power", value: String(format: "%.0f ms²", analysis.vlfPower))
                        AnalysisRow(label: "LF Power", value: String(format: "%.0f ms²", analysis.lfPower))
                        AnalysisRow(label: "HF Power", value: String(format: "%.0f ms²", analysis.hfPower))
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        AnalysisRow(label: "LF/HF Ratio", value: String(format: "%.2f", analysis.lfHfRatio))
                        AnalysisRow(label: "LF (n.u.)", value: String(format: "%.1f%%", analysis.lfNormalized))
                        AnalysisRow(label: "HF (n.u.)", value: String(format: "%.1f%%", analysis.hfNormalized))
                    }
                }
            }

            GroupBox("Poincaré Analysis") {
                HStack {
                    AnalysisRow(label: "SD1", value: String(format: "%.1f ms", analysis.sd1))
                    Spacer()
                    AnalysisRow(label: "SD2", value: String(format: "%.1f ms", analysis.sd2))
                    Spacer()
                    AnalysisRow(label: "SD1/SD2", value: String(format: "%.2f", analysis.sd1sd2Ratio))
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AnalysisRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Statistical Summary View

struct StatisticalSummaryView: View {
    let data: [SessionDataPoint]

    private var summary: (hrvMean: Double, hrvSD: Double, hrMean: Double, hrSD: Double, coherenceMean: Double, n: Int) {
        let hrvValues = data.map { $0.hrv }
        let hrValues = data.map { $0.heartRate }
        let coherenceValues = data.map { $0.coherence }

        return (
            hrvMean: hrvValues.average(),
            hrvSD: hrvValues.standardDeviation(),
            hrMean: hrValues.average(),
            hrSD: hrValues.standardDeviation(),
            coherenceMean: coherenceValues.average(),
            n: data.count
        )
    }

    var body: some View {
        GroupBox("Statistical Summary (n=\(summary.n))") {
            VStack(alignment: .leading, spacing: 8) {
                Text("HRV: \(String(format: "%.1f ± %.1f", summary.hrvMean, summary.hrvSD)) ms")
                    .font(.subheadline)
                Text("Heart Rate: \(String(format: "%.1f ± %.1f", summary.hrMean, summary.hrSD)) BPM")
                    .font(.subheadline)
                Text("Coherence: \(String(format: "%.1f", summary.coherenceMean))%")
                    .font(.subheadline)
            }
        }
    }
}

// MARK: - Export Controls

struct ExportControlsView: View {
    @ObservedObject var scienceHub: ScienceModeHub
    @State private var showingExportSheet = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Data Export")
                .font(.headline)

            HStack(spacing: 16) {
                Button(action: {
                    let csv = scienceHub.exportToCSV()
                    UIPasteboard.general.string = csv
                }) {
                    Label("Copy CSV", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)

                Button(action: {
                    showingExportSheet = true
                }) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(isPresented: $showingExportSheet) {
            ExportSheet(scienceHub: scienceHub)
        }
    }
}

struct ExportSheet: View {
    @ObservedObject var scienceHub: ScienceModeHub
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Format") {
                    Button("Export as CSV") {
                        // Export logic
                        dismiss()
                    }

                    Button("Export as JSON") {
                        // Export logic
                        dismiss()
                    }
                }

                Section("Data Included") {
                    Text("• \(scienceHub.sessionData.count) data points")
                    Text("• Time-domain HRV metrics")
                    Text("• Frequency-domain analysis")
                    Text("• Poincaré parameters")
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Canvas Line Chart (Fallback)

struct CanvasLineChart: View {
    let data: [(Date, Double)]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard data.count >= 2 else { return }

            let minY = data.map { $0.1 }.min() ?? 0
            let maxY = data.map { $0.1 }.max() ?? 100
            let rangeY = maxY - minY

            let minX = data.first?.0.timeIntervalSince1970 ?? 0
            let maxX = data.last?.0.timeIntervalSince1970 ?? 1
            let rangeX = maxX - minX

            var path = Path()

            for (index, point) in data.enumerated() {
                let x = (point.0.timeIntervalSince1970 - minX) / rangeX * Double(size.width)
                let y = size.height - (point.1 - minY) / rangeY * Double(size.height) * 0.9 - Double(size.height) * 0.05

                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            context.stroke(path, with: .color(color), lineWidth: 2)
        }
    }
}

// MARK: - Extension

extension Array where Element == Double {
    func average() -> Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }

    func standardDeviation() -> Double {
        guard count >= 2 else { return 0 }
        let mean = average()
        let sumSquaredDev = reduce(0) { $0 + pow($1 - mean, 2) }
        return sqrt(sumSquaredDev / Double(count - 1))
    }
}
