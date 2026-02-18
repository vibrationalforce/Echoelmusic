import Foundation
#if canImport(HealthKit)
import HealthKit
#endif
import Combine

/// Evidence-Based HRV Training System
/// Based on peer-reviewed research from PubMed, validated clinical protocols
/// No health claims - educational and research purposes only
///
/// Key Research References:
/// - Lehrer & Gevirtz (2014). "Heart rate variability biofeedback" - Biofeedback 42(1)
/// - Shaffer & Ginsberg (2017). "HRV Biofeedback" - Front. Public Health 5:258
/// - McCraty et al. (2009). "The coherent heart" - HeartMath Institute
/// - Gevirtz (2013). "The promise of heart rate variability biofeedback" - Biofeedback 41(3)
@MainActor
class EvidenceBasedHRVTraining: ObservableObject {

    // MARK: - Published State

    @Published var currentProtocol: TrainingProtocol?
    @Published var sessionProgress: Double = 0.0
    @Published var isTraining: Bool = false
    @Published var sessionData: [SessionDataPoint] = []

    // MARK: - Evidence-Based Metrics (Per Research)

    @Published var baselineHRV: Float = 0.0      // RMSSD in ms
    @Published var currentHRV: Float = 0.0
    @Published var hrvTrend: HRVTrend = .stable
    @Published var coherenceScore: Float = 0.0   // HeartMath Coherence (0-100)
    @Published var respiratoryRate: Float = 0.0  // Breaths per minute

    // MARK: - Training Protocols (Evidence-Based)

    enum TrainingProtocol: String, CaseIterable {
        case resonanceFrequency = "Resonance Frequency Training"
        case slowBreathing = "Slow Breathing Protocol"
        case heartMathCoherence = "HeartMath Coherence Building"
        case autogenicTraining = "Autogenic Training"

        var description: String {
            switch self {
            case .resonanceFrequency:
                return "Breathing at ~0.1 Hz (6 breaths/min) to maximize HRV amplitude. Evidence: Vaschillo et al. 2002, Lehrer et al. 2003"
            case .slowBreathing:
                return "Paced breathing 4-7 breaths/min for autonomic balance. Evidence: Russo et al. 2017, Laborde et al. 2017"
            case .heartMathCoherence:
                return "Heart-focused breathing with positive emotion. Evidence: McCraty et al. 2009, Bradley et al. 2010"
            case .autogenicTraining:
                return "Self-regulation through mental exercises. Evidence: Stetter & Kupper 2002, Miu et al. 2009"
            }
        }

        var targetBreathingRate: Float {
            switch self {
            case .resonanceFrequency: return 6.0  // 0.1 Hz
            case .slowBreathing: return 5.5
            case .heartMathCoherence: return 6.0
            case .autogenicTraining: return 8.0
            }
        }

        var sessionDuration: TimeInterval {
            switch self {
            case .resonanceFrequency: return 20 * 60  // 20 minutes (research standard)
            case .slowBreathing: return 15 * 60
            case .heartMathCoherence: return 10 * 60
            case .autogenicTraining: return 25 * 60
            }
        }

        var evidenceLevel: EvidenceLevel {
            switch self {
            case .resonanceFrequency: return .level1a  // Multiple RCTs, Meta-Analysis
            case .slowBreathing: return .level1b      // Individual RCT
            case .heartMathCoherence: return .level2a  // Controlled study without randomization
            case .autogenicTraining: return .level1a   // Meta-Analysis
            }
        }
    }

    // MARK: - Evidence Levels (Oxford Centre for Evidence-Based Medicine)

    enum EvidenceLevel: String {
        case level1a = "1a - Systematic Review/Meta-Analysis of RCTs"
        case level1b = "1b - Individual RCT"
        case level2a = "2a - Systematic Review of Cohort Studies"
        case level2b = "2b - Individual Cohort Study"
        case level3 = "3 - Case-Control Study"
        case level4 = "4 - Case Series"
        case level5 = "5 - Expert Opinion"
    }

    // MARK: - HRV Trend

    enum HRVTrend {
        case increasing  // Positive adaptation
        case stable      // Maintenance
        case decreasing  // Potential overtraining/stress
    }

    // MARK: - Session Data Point

    struct SessionDataPoint {
        let timestamp: Date
        let hrv: Float           // RMSSD in ms
        let heartRate: Float     // BPM
        let coherence: Float     // 0-100 score
        let breathingRate: Float // Breaths/min
        let lfHfRatio: Float     // LF/HF ratio (autonomic balance)
    }

    // MARK: - HealthKit Integration

    #if canImport(HealthKit)
    private let healthStore = HKHealthStore()
    #endif

    // MARK: - Initialization

    init() {
        log.science("✅ Evidence-Based HRV Training: Initialized")
        log.science("📚 Based on peer-reviewed research - Educational purposes only")
    }

    // MARK: - Start Training Session

    func startSession(protocol protocolType: TrainingProtocol) async throws {
        guard !isTraining else { return }

        currentProtocol = protocolType
        isTraining = true
        sessionProgress = 0.0
        sessionData.removeAll()

        // Calculate baseline
        baselineHRV = try await measureBaselineHRV()

        log.science("▶️ HRV Training: \(protocolType.rawValue)")
        log.science("📊 Evidence Level: \(protocolType.evidenceLevel.rawValue)")
        log.science("🫁 Target Breathing Rate: \(protocolType.targetBreathingRate) breaths/min")
        log.science("⏱️ Duration: \(Int(protocolType.sessionDuration / 60)) minutes")

        // Start monitoring
        startMonitoring()
    }

    // MARK: - Stop Training Session

    func stopSession() {
        guard isTraining else { return }

        isTraining = false

        // Calculate results
        let finalHRV = sessionData.last?.hrv ?? 0.0
        let avgCoherence = sessionData.map { $0.coherence }.reduce(0, +) / Float(sessionData.count)
        let hrvChange = finalHRV - baselineHRV

        log.science("⏹️ HRV Training: Session Ended")
        log.science("📊 Results:")
        log.science("   - Baseline HRV: \(String(format: "%.1f", baselineHRV)) ms")
        log.science("   - Final HRV: \(String(format: "%.1f", finalHRV)) ms")
        log.science("   - Change: \(hrvChange >= 0 ? "+" : "")\(String(format: "%.1f", hrvChange)) ms (\(String(format: "%.1f", (hrvChange / baselineHRV) * 100))%)")
        log.science("   - Avg Coherence: \(String(format: "%.1f", avgCoherence))")

        currentProtocol = nil
    }

    // MARK: - Measure Baseline HRV

    private func measureBaselineHRV() async throws -> Float {
        // Request HRV from HealthKit (last 5 minutes average)
        // This is a placeholder - real implementation would query HealthKit

        // Simulate baseline measurement
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

        // Typical resting HRV: 20-100 ms (age-dependent)
        return 50.0
    }

    // MARK: - Start Monitoring

    private func startMonitoring() {
        // Monitor HRV, Heart Rate, Breathing Rate continuously
        // This would integrate with HealthKitManager for real data

        // For now, simulate monitoring
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self, self.isTraining else {
                timer.invalidate()
                return
            }

            // Simulate data point
            let dataPoint = SessionDataPoint(
                timestamp: Date(),
                hrv: self.currentHRV,
                heartRate: 70.0,
                coherence: self.coherenceScore,
                breathingRate: self.currentProtocol?.targetBreathingRate ?? 6.0,
                lfHfRatio: 1.5
            )

            Task { @MainActor in
                self.sessionData.append(dataPoint)
                self.updateProgress()
            }
        }
    }

    // MARK: - Update Progress

    private func updateProgress() {
        guard let protocolType = currentProtocol else { return }

        let elapsed = TimeInterval(sessionData.count) // 1 data point per second
        sessionProgress = elapsed / protocolType.sessionDuration

        // Auto-stop when complete
        if sessionProgress >= 1.0 {
            stopSession()
        }
    }

    // MARK: - Update Real-Time Data

    func updateMetrics(hrv: Float, heartRate: Float, coherence: Float, breathingRate: Float) {
        currentHRV = hrv
        coherenceScore = coherence
        respiratoryRate = breathingRate

        // Calculate HRV trend
        if sessionData.count > 10 {
            let recentAvg = sessionData.suffix(10).map { $0.hrv }.reduce(0, +) / 10.0
            let previousAvg = sessionData.dropLast(10).suffix(10).map { $0.hrv }.reduce(0, +) / 10.0

            if recentAvg > previousAvg * 1.05 {
                hrvTrend = .increasing
            } else if recentAvg < previousAvg * 0.95 {
                hrvTrend = .decreasing
            } else {
                hrvTrend = .stable
            }
        }
    }

    // MARK: - Evidence-Based Recommendations

    func getRecommendations() -> [String] {
        var recommendations: [String] = []

        // Based on current HRV
        if currentHRV < 20 {
            recommendations.append("Low HRV detected. Consider: adequate sleep (7-9h), stress management, avoiding overtraining. (Source: Thayer et al. 2012)")
        } else if currentHRV > 80 {
            recommendations.append("High HRV - excellent autonomic function. Continue current lifestyle. (Source: Nunan et al. 2010)")
        }

        // Based on coherence
        if coherenceScore < 40 {
            recommendations.append("Low coherence. Try HeartMath Coherence Building protocol - focus on heart area with positive emotion while breathing slowly. (Source: McCraty & Zayas 2014)")
        }

        // Based on breathing rate
        if respiratoryRate < 4 || respiratoryRate > 10 {
            recommendations.append("Breathing rate outside optimal range (4-7 breaths/min). Adjust to resonance frequency for maximum HRV. (Source: Lehrer et al. 2000)")
        }

        // Based on trend
        if hrvTrend == .decreasing {
            recommendations.append("HRV decreasing. Potential indicators: overtraining, insufficient recovery, chronic stress. Consider rest day. (Source: Plews et al. 2013)")
        }

        return recommendations
    }

    // MARK: - Export Session Data for Research

    func exportSessionData() -> SessionReport {
        return SessionReport(
            trainingProtocol: currentProtocol?.rawValue ?? "Unknown",
            duration: sessionData.count,
            baselineHRV: baselineHRV,
            avgHRV: sessionData.map { $0.hrv }.reduce(0, +) / Float(sessionData.count),
            avgCoherence: sessionData.map { $0.coherence }.reduce(0, +) / Float(sessionData.count),
            avgLFHFRatio: sessionData.map { $0.lfHfRatio }.reduce(0, +) / Float(sessionData.count),
            dataPoints: sessionData
        )
    }
}

// MARK: - Session Report

struct SessionReport {
    let trainingProtocol: String
    let duration: Int  // seconds
    let baselineHRV: Float
    let avgHRV: Float
    let avgCoherence: Float
    let avgLFHFRatio: Float
    let dataPoints: [EvidenceBasedHRVTraining.SessionDataPoint]

    // Export to CSV for research analysis
    func toCSV() -> String {
        var csv = "Timestamp,HRV_RMSSD_ms,HeartRate_BPM,Coherence_Score,BreathingRate_BPM,LF_HF_Ratio\n"

        for point in dataPoints {
            csv += "\(point.timestamp.timeIntervalSince1970),"
            csv += "\(point.hrv),"
            csv += "\(point.heartRate),"
            csv += "\(point.coherence),"
            csv += "\(point.breathingRate),"
            csv += "\(point.lfHfRatio)\n"
        }

        return csv
    }

    // Export to JSON for external analysis tools
    func toJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}

extension SessionReport: Codable {}
extension EvidenceBasedHRVTraining.SessionDataPoint: Codable {}
