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

    // MARK: - Timer

    private var monitoringTimer: Timer?

    // MARK: - HealthKit Integration

    private let healthStore = HKHealthStore()

    // MARK: - Initialization

    init() {
        log.science("✅ Evidence-Based HRV Training: Initialized")
        log.science("📚 Based on peer-reviewed research - Educational purposes only")
    }

    deinit {
        monitoringTimer?.invalidate()
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

        monitoringTimer?.invalidate()
        monitoringTimer = nil
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
        #if canImport(HealthKit)
        guard HKHealthStore.isHealthDataAvailable() else {
            log.science("⚠️ HealthKit not available — using simulation baseline")
            return await simulateBaselineHRV()
        }

        // Query the last 5 minutes of HRV samples (RMSSD/SDNN)
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        let predicate = HKQuery.predicateForSamples(
            withStart: fiveMinutesAgo,
            end: Date(),
            options: .strictEndDate
        )

        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            log.science("⚠️ HRV type not available — using simulation baseline")
            return await simulateBaselineHRV()
        }

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: hrvType,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, statistics, error in
                if let error = error {
                    log.science("⚠️ HRV query error: \(error.localizedDescription) — using simulation")
                    continuation.resume(returning: 50.0)
                    return
                }

                if let avg = statistics?.averageQuantity() {
                    let sdnn = Float(avg.doubleValue(for: HKUnit.secondUnit(with: .milli)))
                    log.science("📊 Baseline HRV from HealthKit: \(String(format: "%.1f", sdnn)) ms (SDNN)")
                    continuation.resume(returning: sdnn)
                } else {
                    log.science("⚠️ No recent HRV data — using simulation baseline")
                    continuation.resume(returning: 50.0)
                }
            }
            healthStore.execute(query)
        }
        #else
        return await simulateBaselineHRV()
        #endif
    }

    private func simulateBaselineHRV() async -> Float {
        // Fallback for simulator/platforms without HealthKit
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        // Typical resting HRV: 20-100 ms (age-dependent), use moderate default
        return 50.0
    }

    // MARK: - Start Monitoring

    private func startMonitoring() {
        // Invalidate any existing timer before creating a new one
        monitoringTimer?.invalidate()

        // Subscribe to real-time HealthKit updates from UnifiedHealthKitEngine
        let healthEngine = UnifiedHealthKitEngine.shared

        // Start streaming if not already
        if !healthEngine.isStreaming {
            healthEngine.startStreaming()
        }

        // Monitor at 1 Hz, pulling live data from UnifiedHealthKitEngine
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self, self.isTraining else {
                timer.invalidate()
                return
            }

            Task { @MainActor in
                let engine = UnifiedHealthKitEngine.shared

                // Pull real-time values from the unified HealthKit engine
                let liveHRV = Float(engine.hrvSDNN)
                let liveHR = Float(engine.heartRate)
                let liveCoherence = Float(engine.coherence) * 100.0 // Scale 0-1 → 0-100
                let liveBreathRate = Float(engine.breathingRate)

                // Update current metrics
                self.currentHRV = liveHRV > 0 ? liveHRV : self.currentHRV
                self.coherenceScore = liveCoherence
                self.respiratoryRate = liveBreathRate

                // Calculate LF/HF ratio from engine data
                let lfHf: Float
                if engine.heartData.hfPower > 0 {
                    lfHf = Float(engine.heartData.lfPower / engine.heartData.hfPower)
                } else {
                    lfHf = Float(engine.heartData.lfHfRatio)
                }

                let dataPoint = SessionDataPoint(
                    timestamp: Date(),
                    hrv: self.currentHRV,
                    heartRate: liveHR,
                    coherence: self.coherenceScore,
                    breathingRate: liveBreathRate,
                    lfHfRatio: lfHf
                )

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
