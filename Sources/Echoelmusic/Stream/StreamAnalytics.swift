import Foundation
import Combine
import os.log

/// Stream Analytics Dashboard
/// Tracks viewers, chat activity, bio-data correlation, engagement metrics
@MainActor
class StreamAnalytics: ObservableObject {

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.echoelmusic", category: "StreamAnalytics")

    // MARK: - Real-Time Metrics

    @Published var currentViewers: Int = 0
    @Published var peakViewers: Int = 0
    @Published var averageViewers: Double = 0.0
    @Published var chatMessagesPerMinute: Double = 0.0
    @Published var framesSent: Int = 0
    @Published var droppedFrames: Int = 0

    // MARK: - Bio-Data Correlation

    @Published var avgHRV: Float = 0.0
    @Published var avgCoherence: Float = 0.0
    @Published var avgHeartRate: Float = 0.0
    @Published var timeInFlowState: TimeInterval = 0.0

    // MARK: - Session Data

    private var sessionStartTime: Date?
    private var sessionDuration: TimeInterval = 0.0
    private var viewerSamples: [Int] = []
    private var bioSamples: [(hrv: Float, coherence: Float, heartRate: Float)] = []

    func startSession() {
        sessionStartTime = Date()
        resetMetrics()
        logger.info("Started session")
    }

    func endSession() {
        guard let startTime = sessionStartTime else { return }
        sessionDuration = Date().timeIntervalSince(startTime)

        // Calculate final averages
        if !viewerSamples.isEmpty {
            averageViewers = Double(viewerSamples.reduce(0, +)) / Double(viewerSamples.count)
        }

        if !bioSamples.isEmpty {
            let hrvSum = bioSamples.map { $0.hrv }.reduce(0, +)
            let coherenceSum = bioSamples.map { $0.coherence }.reduce(0, +)
            let hrSum = bioSamples.map { $0.heartRate }.reduce(0, +)

            avgHRV = hrvSum / Float(bioSamples.count)
            avgCoherence = coherenceSum / Float(bioSamples.count)
            avgHeartRate = hrSum / Float(bioSamples.count)
        }

        logger.info("Session ended - Duration: \(Int(sessionDuration), privacy: .public)s, Peak Viewers: \(peakViewers, privacy: .public), Avg HRV: \(avgHRV, privacy: .public)")
    }

    func recordFrame() {
        framesSent += 1
    }

    func recordViewers(_ count: Int) {
        currentViewers = count
        peakViewers = max(peakViewers, count)
        viewerSamples.append(count)
    }

    func recordBioData(hrv: Float, coherence: Float, heartRate: Float) {
        bioSamples.append((hrv, coherence, heartRate))

        // Track time in flow state (coherence > 0.6)
        if coherence > 0.6 {
            timeInFlowState += 1.0 // Assume 1 second per sample
        }
    }

    func recordSceneSwitch(to scene: Scene) {
        logger.debug("Scene switched to '\(scene.name, privacy: .public)'")
    }

    private func resetMetrics() {
        currentViewers = 0
        peakViewers = 0
        averageViewers = 0.0
        chatMessagesPerMinute = 0.0
        framesSent = 0
        droppedFrames = 0
        viewerSamples.removeAll()
        bioSamples.removeAll()
        timeInFlowState = 0.0
    }

    // MARK: - Bio-Data Correlation Analysis

    func calculateBioDataCorrelation() -> [CorrelationResult] {
        var results: [CorrelationResult] = []

        // Correlation: Viewer Count vs Coherence
        if viewerSamples.count == bioSamples.count && viewerSamples.count > 10 {
            let viewerCoherenceCorr = pearsonCorrelation(
                x: viewerSamples.map { Double($0) },
                y: bioSamples.map { Double($0.coherence) }
            )

            results.append(CorrelationResult(
                metric1: "Viewer Count",
                metric2: "Coherence",
                correlation: viewerCoherenceCorr,
                interpretation: interpretCorrelation(viewerCoherenceCorr, context: "viewers_coherence")
            ))
        }

        return results
    }

    private func pearsonCorrelation(x: [Double], y: [Double]) -> Double {
        guard x.count == y.count, x.count > 0 else { return 0.0 }

        let n = Double(x.count)
        let sumX = x.reduce(0, +)
        let sumY = y.reduce(0, +)
        let sumXY = zip(x, y).map(*).reduce(0, +)
        let sumX2 = x.map { $0 * $0 }.reduce(0, +)
        let sumY2 = y.map { $0 * $0 }.reduce(0, +)

        let numerator = n * sumXY - sumX * sumY
        let denominator = sqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY))

        return denominator == 0 ? 0 : numerator / denominator
    }

    private func interpretCorrelation(_ r: Double, context: String) -> String {
        if context == "viewers_coherence" {
            if r > 0.5 {
                return "High coherence (flow state) = more viewers! Keep maintaining flow."
            } else if r < -0.5 {
                return "Low coherence = fewer viewers. Try breathing exercises."
            } else {
                return "No clear correlation detected yet."
            }
        }
        return ""
    }
}

struct CorrelationResult {
    let metric1: String
    let metric2: String
    let correlation: Double
    let interpretation: String
}
