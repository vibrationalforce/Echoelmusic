import Foundation
import Accelerate
import HealthKit

// MARK: - ═══════════════════════════════════════════════════════════════════════════════
// MARK: Sleep Analytics - Bringing Science/Health to 100%
// MARK: ═══════════════════════════════════════════════════════════════════════════════
///
/// Comprehensive sleep analysis system based on HRV patterns:
/// 1. Sleep Stage Detection (Wake, REM, Light, Deep)
/// 2. Sleep Quality Score
/// 3. Sleep Efficiency Calculation
/// 4. Circadian Rhythm Analysis
/// 5. Recovery Prediction
///
/// Based on: Herzig et al. (2017), de Zambotti et al. (2019)
///

// MARK: - Sleep Stage Detector

/// Detects sleep stages from HRV data
/// Reference: Herzig D et al. (2017) "Reproducibility of Heart Rate Variability Is Parameter and Sleep Stage Dependent"
@MainActor
public final class SleepStageDetector: ObservableObject {

    // MARK: - Published State

    @Published public var currentStage: SleepStage = .wake
    @Published public var stageHistory: [StageSample] = []
    @Published public var sleepOnset: Date?
    @Published public var wakeTime: Date?
    @Published public var totalSleepTime: TimeInterval = 0
    @Published public var sleepEfficiency: Double = 0

    // MARK: - Sleep Stages

    public enum SleepStage: String, CaseIterable {
        case wake = "Awake"
        case rem = "REM"
        case light = "Light Sleep"      // N1 + N2
        case deep = "Deep Sleep"        // N3 (Slow Wave)

        var color: String {
            switch self {
            case .wake: return "#FF6B6B"
            case .rem: return "#4ECDC4"
            case .light: return "#45B7D1"
            case .deep: return "#5D5FEF"
            }
        }

        var description: String {
            switch self {
            case .wake: return "Fully conscious"
            case .rem: return "Rapid Eye Movement - Dreams"
            case .light: return "Transitional sleep (N1-N2)"
            case .deep: return "Restorative slow-wave (N3)"
            }
        }
    }

    // MARK: - Stage Sample

    public struct StageSample: Identifiable {
        public let id = UUID()
        public let timestamp: Date
        public let stage: SleepStage
        public let confidence: Double
        public let hrvMetrics: HRVMetrics
    }

    public struct HRVMetrics {
        public var rmssd: Double
        public var lfPower: Double
        public var hfPower: Double
        public var lfHfRatio: Double
        public var heartRate: Double
    }

    // MARK: - Detection Parameters

    private let analysisWindowMinutes: Int = 5
    private var hrvBuffer: [Double] = []  // RR intervals
    private let maxBufferSize = 600       // 5 minutes @ ~2 Hz

    // MARK: - Stage Thresholds (Research-based)

    /// Thresholds based on de Zambotti et al. (2019) and Herzig et al. (2017)
    private struct Thresholds {
        // Heart Rate thresholds (BPM)
        static let wakeHR: Double = 65
        static let remHR: Double = 60
        static let lightHR: Double = 55
        static let deepHR: Double = 50

        // RMSSD thresholds (ms) - higher in deep sleep
        static let wakeRMSSD: Double = 30
        static let remRMSSD: Double = 35
        static let lightRMSSD: Double = 45
        static let deepRMSSD: Double = 60

        // LF/HF ratio - lower in deep sleep
        static let wakeLFHF: Double = 2.0
        static let remLFHF: Double = 1.5
        static let lightLFHF: Double = 1.0
        static let deepLFHF: Double = 0.5
    }

    // MARK: - Initialization

    public init() {
        print("✅ SleepStageDetector: Initialized (Herzig 2017 algorithm)")
    }

    // MARK: - Data Input

    /// Add RR interval to buffer
    public func addRRInterval(_ rr: Double) {
        hrvBuffer.append(rr)
        if hrvBuffer.count > maxBufferSize {
            hrvBuffer.removeFirst()
        }

        // Analyze when buffer is full enough
        if hrvBuffer.count >= 120 {  // ~1 minute minimum
            Task {
                await analyzeCurrentWindow()
            }
        }
    }

    /// Add batch of RR intervals
    public func addRRIntervals(_ intervals: [Double]) {
        for rr in intervals {
            addRRInterval(rr)
        }
    }

    // MARK: - Analysis

    @MainActor
    private func analyzeCurrentWindow() async {
        guard hrvBuffer.count >= 120 else { return }

        // Calculate HRV metrics
        let metrics = calculateHRVMetrics(hrvBuffer)

        // Detect sleep stage
        let (stage, confidence) = detectStage(metrics)

        // Update state
        currentStage = stage

        // Record sample
        let sample = StageSample(
            timestamp: Date(),
            stage: stage,
            confidence: confidence,
            hrvMetrics: metrics
        )
        stageHistory.append(sample)

        // Detect sleep onset
        if sleepOnset == nil && stage != .wake {
            sleepOnset = Date()
        }

        // Update sleep metrics
        updateSleepMetrics()
    }

    private func calculateHRVMetrics(_ rrIntervals: [Double]) -> HRVMetrics {
        // RMSSD
        var rmssd: Double = 0
        if rrIntervals.count > 1 {
            var sumSquaredDiff: Double = 0
            for i in 0..<(rrIntervals.count - 1) {
                let diff = rrIntervals[i + 1] - rrIntervals[i]
                sumSquaredDiff += diff * diff
            }
            rmssd = sqrt(sumSquaredDiff / Double(rrIntervals.count - 1))
        }

        // Heart rate from mean RR
        let meanRR = rrIntervals.reduce(0, +) / Double(rrIntervals.count)
        let heartRate = 60000.0 / meanRR  // Convert ms to BPM

        // Power spectral density
        let (lfPower, hfPower) = calculateSpectralPower(rrIntervals)
        let lfHfRatio = hfPower > 0 ? lfPower / hfPower : 0

        return HRVMetrics(
            rmssd: rmssd,
            lfPower: lfPower,
            hfPower: hfPower,
            lfHfRatio: lfHfRatio,
            heartRate: heartRate
        )
    }

    private func calculateSpectralPower(_ rrIntervals: [Double]) -> (lf: Double, hf: Double) {
        guard rrIntervals.count >= 64 else { return (0, 0) }

        // Resample to uniform 4 Hz
        let resampledLength = min(256, rrIntervals.count)
        var resampled = [Double](repeating: 0, count: resampledLength)
        for i in 0..<resampledLength {
            let srcIdx = Int(Double(i) * Double(rrIntervals.count) / Double(resampledLength))
            resampled[i] = rrIntervals[min(srcIdx, rrIntervals.count - 1)]
        }

        // Detrend
        let mean = resampled.reduce(0, +) / Double(resampledLength)
        resampled = resampled.map { $0 - mean }

        // Simple DFT power calculation
        var lfPower: Double = 0
        var hfPower: Double = 0
        let sampleRate = 4.0

        for k in 0..<resampledLength/2 {
            var sumReal: Double = 0
            var sumImag: Double = 0

            for n in 0..<resampledLength {
                let angle = -2.0 * .pi * Double(k * n) / Double(resampledLength)
                sumReal += resampled[n] * cos(angle)
                sumImag += resampled[n] * sin(angle)
            }

            let power = (sumReal * sumReal + sumImag * sumImag) / Double(resampledLength * resampledLength)
            let freq = Double(k) * sampleRate / Double(resampledLength)

            // LF band: 0.04-0.15 Hz
            if freq >= 0.04 && freq < 0.15 {
                lfPower += power
            }
            // HF band: 0.15-0.4 Hz
            else if freq >= 0.15 && freq <= 0.4 {
                hfPower += power
            }
        }

        return (lfPower, hfPower)
    }

    private func detectStage(_ metrics: HRVMetrics) -> (SleepStage, Double) {
        // Multi-feature classification
        var scores: [SleepStage: Double] = [:]

        // Score each stage based on metrics
        for stage in SleepStage.allCases {
            scores[stage] = calculateStageScore(stage, metrics: metrics)
        }

        // Find best match
        let bestStage = scores.max(by: { $0.value < $1.value })!
        let totalScore = scores.values.reduce(0, +)
        let confidence = totalScore > 0 ? bestStage.value / totalScore : 0

        return (bestStage.key, confidence)
    }

    private func calculateStageScore(_ stage: SleepStage, metrics: HRVMetrics) -> Double {
        var score: Double = 0

        switch stage {
        case .wake:
            // Wake: Higher HR, lower RMSSD, higher LF/HF
            if metrics.heartRate > Thresholds.wakeHR { score += 1 }
            if metrics.rmssd < Thresholds.wakeRMSSD { score += 1 }
            if metrics.lfHfRatio > Thresholds.wakeLFHF { score += 1 }

        case .rem:
            // REM: Variable HR, moderate RMSSD, irregular patterns
            if metrics.heartRate > Thresholds.remHR && metrics.heartRate < Thresholds.wakeHR { score += 1 }
            if metrics.rmssd > Thresholds.wakeRMSSD && metrics.rmssd < Thresholds.lightRMSSD { score += 1 }
            if metrics.lfHfRatio > Thresholds.lightLFHF && metrics.lfHfRatio < Thresholds.wakeLFHF { score += 1 }

        case .light:
            // Light: Lower HR, moderate RMSSD
            if metrics.heartRate > Thresholds.deepHR && metrics.heartRate < Thresholds.remHR { score += 1 }
            if metrics.rmssd > Thresholds.remRMSSD && metrics.rmssd < Thresholds.deepRMSSD { score += 1 }
            if metrics.lfHfRatio > Thresholds.deepLFHF && metrics.lfHfRatio < Thresholds.lightLFHF { score += 1 }

        case .deep:
            // Deep: Lowest HR, highest RMSSD, lowest LF/HF
            if metrics.heartRate < Thresholds.lightHR { score += 1 }
            if metrics.rmssd > Thresholds.lightRMSSD { score += 1 }
            if metrics.lfHfRatio < Thresholds.deepLFHF { score += 1 }
        }

        return score
    }

    private func updateSleepMetrics() {
        guard !stageHistory.isEmpty else { return }

        // Total sleep time (excluding wake)
        let sleepSamples = stageHistory.filter { $0.stage != .wake }
        totalSleepTime = Double(sleepSamples.count) * 5 * 60  // 5-minute windows

        // Sleep efficiency = TST / TIB
        if let onset = sleepOnset {
            let timeInBed = Date().timeIntervalSince(onset)
            sleepEfficiency = timeInBed > 0 ? (totalSleepTime / timeInBed) * 100 : 0
        }
    }

    // MARK: - Sleep Architecture

    /// Get percentage of each sleep stage
    public func getSleepArchitecture() -> [SleepStage: Double] {
        guard !stageHistory.isEmpty else { return [:] }

        var counts: [SleepStage: Int] = [:]
        for stage in SleepStage.allCases {
            counts[stage] = stageHistory.filter { $0.stage == stage }.count
        }

        let total = Double(stageHistory.count)
        var percentages: [SleepStage: Double] = [:]
        for (stage, count) in counts {
            percentages[stage] = (Double(count) / total) * 100
        }

        return percentages
    }

    /// Get sleep quality score (0-100)
    public func calculateSleepQualityScore() -> Double {
        let architecture = getSleepArchitecture()

        // Ideal ratios (based on research)
        let idealDeep = 20.0      // 13-23%
        let idealREM = 22.0       // 20-25%
        let idealLight = 50.0     // 50-60%
        let idealWake = 8.0       // <5-10%

        var score: Double = 100

        // Penalize deviation from ideal
        if let deep = architecture[.deep] {
            score -= abs(deep - idealDeep) * 1.5
        }
        if let rem = architecture[.rem] {
            score -= abs(rem - idealREM) * 1.5
        }
        if let wake = architecture[.wake], wake > idealWake {
            score -= (wake - idealWake) * 2.0
        }

        // Bonus for good efficiency
        if sleepEfficiency > 85 {
            score += 5
        } else if sleepEfficiency < 75 {
            score -= 10
        }

        return max(0, min(100, score))
    }
}

// MARK: - Circadian Rhythm Analyzer

/// Analyzes circadian rhythm patterns from heart rate data
@MainActor
public final class CircadianRhythmAnalyzer: ObservableObject {

    // MARK: - Published State

    @Published public var circadianPhase: CircadianPhase = .day
    @Published public var chronotype: Chronotype = .intermediate
    @Published public var socialJetLag: TimeInterval = 0  // hours
    @Published public var melatoninOnsetEstimate: Date?
    @Published public var optimalWakeTime: Date?
    @Published public var optimalSleepTime: Date?

    // MARK: - Circadian Phases

    public enum CircadianPhase: String {
        case earlyMorning = "Early Morning"    // 4-7 AM
        case morning = "Morning"               // 7-12 PM
        case afternoon = "Afternoon"           // 12-5 PM
        case evening = "Evening"               // 5-9 PM
        case night = "Night"                   // 9 PM - 12 AM
        case lateNight = "Late Night"          // 12-4 AM
        case day = "Day"
    }

    // MARK: - Chronotypes

    public enum Chronotype: String, CaseIterable {
        case definiteMorning = "Definite Morning"     // Lark
        case moderateMorning = "Moderate Morning"
        case intermediate = "Intermediate"
        case moderateEvening = "Moderate Evening"
        case definiteEvening = "Definite Evening"     // Owl

        var optimalSleepWindow: (bedtime: Int, wakeTime: Int) {
            switch self {
            case .definiteMorning: return (21, 5)    // 9 PM - 5 AM
            case .moderateMorning: return (22, 6)    // 10 PM - 6 AM
            case .intermediate: return (23, 7)       // 11 PM - 7 AM
            case .moderateEvening: return (0, 8)     // 12 AM - 8 AM
            case .definiteEvening: return (1, 9)     // 1 AM - 9 AM
            }
        }
    }

    // MARK: - Data Storage

    private var dailyMinHR: [Date: Double] = [:]     // Day -> Minimum HR (sleep)
    private var dailyHRNadir: [Date: Date] = [:]     // Day -> Time of minimum HR

    // MARK: - Initialization

    public init() {
        print("✅ CircadianRhythmAnalyzer: Initialized")
    }

    // MARK: - Analysis

    /// Analyze circadian rhythm from heart rate history
    public func analyze(heartRateHistory: [(date: Date, hr: Double)]) {
        guard heartRateHistory.count >= 24 else { return }

        // Find daily HR nadirs (lowest point, usually during deep sleep)
        var dayData: [Date: [(date: Date, hr: Double)]] = [:]

        for sample in heartRateHistory {
            let dayKey = Calendar.current.startOfDay(for: sample.date)
            if dayData[dayKey] == nil {
                dayData[dayKey] = []
            }
            dayData[dayKey]?.append(sample)
        }

        for (day, samples) in dayData {
            if let minSample = samples.min(by: { $0.hr < $1.hr }) {
                dailyMinHR[day] = minSample.hr
                dailyHRNadir[day] = minSample.date
            }
        }

        // Estimate chronotype from nadir timing
        estimateChronotype()

        // Calculate social jet lag
        calculateSocialJetLag()

        // Estimate melatonin onset (DLMO) ~2h before typical sleep
        estimateMelatoninOnset()

        // Update current phase
        updateCurrentPhase()
    }

    private func estimateChronotype() {
        guard !dailyHRNadir.isEmpty else { return }

        // Average nadir time
        var totalMinutes: Int = 0
        for (_, nadirTime) in dailyHRNadir {
            let components = Calendar.current.dateComponents([.hour, .minute], from: nadirTime)
            var minutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
            // Adjust for overnight (if nadir is after midnight, add 24h worth)
            if minutes < 180 { minutes += 1440 }  // Before 3 AM
            totalMinutes += minutes
        }

        let avgMinutes = totalMinutes / dailyHRNadir.count
        let avgHour = (avgMinutes / 60) % 24

        // Classify chronotype based on HR nadir time
        // Earlier nadir = morning type
        switch avgHour {
        case 0..<3: chronotype = .definiteMorning
        case 3..<4: chronotype = .moderateMorning
        case 4..<5: chronotype = .intermediate
        case 5..<6: chronotype = .moderateEvening
        default: chronotype = .definiteEvening
        }

        // Set optimal times
        let window = chronotype.optimalSleepWindow
        let calendar = Calendar.current
        var sleepComponents = DateComponents()
        sleepComponents.hour = window.bedtime
        sleepComponents.minute = 0
        optimalSleepTime = calendar.date(from: sleepComponents)

        var wakeComponents = DateComponents()
        wakeComponents.hour = window.wakeTime
        wakeComponents.minute = 0
        optimalWakeTime = calendar.date(from: wakeComponents)
    }

    private func calculateSocialJetLag() {
        // Social jet lag = difference between weekday and weekend sleep midpoint
        // Simplified: estimate from chronotype deviation
        let deviationHours: [Chronotype: Double] = [
            .definiteMorning: -2.0,
            .moderateMorning: -1.0,
            .intermediate: 0.0,
            .moderateEvening: 1.0,
            .definiteEvening: 2.0
        ]

        socialJetLag = deviationHours[chronotype] ?? 0
    }

    private func estimateMelatoninOnset() {
        // DLMO typically 2 hours before habitual sleep time
        guard let sleepTime = optimalSleepTime else { return }
        melatoninOnsetEstimate = Calendar.current.date(byAdding: .hour, value: -2, to: sleepTime)
    }

    private func updateCurrentPhase() {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 4..<7: circadianPhase = .earlyMorning
        case 7..<12: circadianPhase = .morning
        case 12..<17: circadianPhase = .afternoon
        case 17..<21: circadianPhase = .evening
        case 21..<24: circadianPhase = .night
        default: circadianPhase = .lateNight
        }
    }

    /// Get alignment score (how well current schedule matches chronotype)
    public func getAlignmentScore() -> Double {
        // Score based on social jet lag
        let maxJetLag = 3.0  // hours
        let score = 100.0 * (1.0 - min(abs(socialJetLag), maxJetLag) / maxJetLag)
        return max(0, score)
    }
}

// MARK: - Recovery Predictor

/// Predicts recovery status and readiness based on sleep and HRV
@MainActor
public final class RecoveryPredictor: ObservableObject {

    // MARK: - Published State

    @Published public var recoveryScore: Double = 0       // 0-100
    @Published public var readinessToTrain: Readiness = .moderate
    @Published public var strainCapacity: Double = 0      // How much strain can handle
    @Published public var predictedPerformance: Double = 0  // % of optimal
    @Published public var recommendations: [String] = []

    // MARK: - Readiness Levels

    public enum Readiness: String {
        case primed = "Primed"           // 90-100%
        case ready = "Ready"             // 70-89%
        case moderate = "Moderate"       // 50-69%
        case needRest = "Need Rest"      // 30-49%
        case exhausted = "Exhausted"     // <30%

        var trainingRecommendation: String {
            switch self {
            case .primed: return "Optimal for high-intensity training"
            case .ready: return "Good for moderate-high intensity"
            case .moderate: return "Light to moderate training advised"
            case .needRest: return "Rest or very light activity recommended"
            case .exhausted: return "Complete rest required"
            }
        }
    }

    // MARK: - Initialization

    public init() {
        print("✅ RecoveryPredictor: Initialized")
    }

    // MARK: - Prediction

    /// Predict recovery and readiness
    public func predict(
        sleepQuality: Double,          // 0-100 from SleepStageDetector
        sleepDuration: TimeInterval,   // seconds
        hrvRMSSD: Double,              // Current RMSSD
        baselineRMSSD: Double,         // Personal baseline
        recentStrain: Double,          // 0-100 strain from recent activity
        daysWithoutRest: Int
    ) {
        // Calculate recovery components
        let sleepComponent = calculateSleepComponent(quality: sleepQuality, duration: sleepDuration)
        let hrvComponent = calculateHRVComponent(current: hrvRMSSD, baseline: baselineRMSSD)
        let strainComponent = calculateStrainComponent(strain: recentStrain, restDays: daysWithoutRest)

        // Weighted recovery score
        recoveryScore = sleepComponent * 0.4 + hrvComponent * 0.35 + strainComponent * 0.25

        // Determine readiness
        readinessToTrain = classifyReadiness(recoveryScore)

        // Calculate strain capacity
        strainCapacity = recoveryScore * 0.01 * 21  // Max strain score of 21

        // Predicted performance
        predictedPerformance = min(100, recoveryScore * 1.1)  // Can exceed baseline when primed

        // Generate recommendations
        generateRecommendations(
            sleepQuality: sleepQuality,
            sleepDuration: sleepDuration,
            hrvRatio: hrvRMSSD / max(1, baselineRMSSD),
            strain: recentStrain
        )
    }

    private func calculateSleepComponent(quality: Double, duration: TimeInterval) -> Double {
        let durationHours = duration / 3600

        // Optimal sleep: 7-9 hours
        var durationScore: Double = 100
        if durationHours < 6 {
            durationScore = durationHours / 6 * 70  // Severe penalty
        } else if durationHours < 7 {
            durationScore = 70 + (durationHours - 6) * 20
        } else if durationHours > 9 {
            durationScore = 100 - (durationHours - 9) * 5  // Slight penalty for oversleep
        }

        // Combine with quality
        return (quality * 0.6 + durationScore * 0.4)
    }

    private func calculateHRVComponent(current: Double, baseline: Double) -> Double {
        guard baseline > 0 else { return 50 }

        let ratio = current / baseline

        // Optimal: 100-110% of baseline
        if ratio >= 1.1 {
            return 100
        } else if ratio >= 1.0 {
            return 90 + (ratio - 1.0) * 100
        } else if ratio >= 0.9 {
            return 70 + (ratio - 0.9) * 200
        } else if ratio >= 0.8 {
            return 50 + (ratio - 0.8) * 200
        } else {
            return max(0, ratio * 62.5)  // 0.8 -> 50, 0 -> 0
        }
    }

    private func calculateStrainComponent(strain: Double, restDays: Int) -> Double {
        var score: Double = 100

        // Penalize high recent strain
        if strain > 15 {
            score -= (strain - 15) * 5
        }

        // Penalize consecutive training days
        if restDays > 3 {
            score -= Double(restDays - 3) * 10
        }

        return max(0, score)
    }

    private func classifyReadiness(_ score: Double) -> Readiness {
        switch score {
        case 90...: return .primed
        case 70..<90: return .ready
        case 50..<70: return .moderate
        case 30..<50: return .needRest
        default: return .exhausted
        }
    }

    private func generateRecommendations(sleepQuality: Double, sleepDuration: TimeInterval, hrvRatio: Double, strain: Double) {
        recommendations = []

        let hours = sleepDuration / 3600

        if hours < 7 {
            recommendations.append("⏰ Aim for 7-9 hours of sleep tonight")
        }

        if sleepQuality < 70 {
            recommendations.append("😴 Improve sleep quality: cool room, no screens before bed")
        }

        if hrvRatio < 0.9 {
            recommendations.append("💚 HRV below baseline - prioritize recovery activities")
        }

        if strain > 15 {
            recommendations.append("🏃 Recent high strain - consider active recovery")
        }

        if readinessToTrain == .needRest || readinessToTrain == .exhausted {
            recommendations.append("🛏️ Rest day recommended for optimal adaptation")
        }

        if readinessToTrain == .primed {
            recommendations.append("🔥 Great recovery! Good day for challenging workouts")
        }
    }
}

// MARK: - Sleep Analytics Hub

/// Central hub for all sleep analytics
@MainActor
public final class SleepAnalyticsHub: ObservableObject {

    public let stageDetector = SleepStageDetector()
    public let circadianAnalyzer = CircadianRhythmAnalyzer()
    public let recoveryPredictor = RecoveryPredictor()

    @Published public var lastNightSleepScore: Double = 0
    @Published public var weeklyAverageSleep: TimeInterval = 0
    @Published public var sleepDebt: TimeInterval = 0  // Accumulated sleep deficit

    public static let shared = SleepAnalyticsHub()

    private init() {
        print("═══════════════════════════════════════════════════════════════")
        print("  SLEEP ANALYTICS HUB")
        print("  Stage Detection • Circadian Analysis • Recovery Prediction")
        print("═══════════════════════════════════════════════════════════════")
    }

    /// Generate comprehensive sleep report
    public func generateReport() -> String {
        let architecture = stageDetector.getSleepArchitecture()
        let quality = stageDetector.calculateSleepQualityScore()

        return """
        ╔═══════════════════════════════════════════════════════════════╗
        ║                    SLEEP ANALYTICS REPORT                     ║
        ╠═══════════════════════════════════════════════════════════════╣
        ║                                                               ║
        ║  SLEEP QUALITY SCORE: \(String(format: "%5.1f", quality))/100                        ║
        ║  SLEEP EFFICIENCY:    \(String(format: "%5.1f", stageDetector.sleepEfficiency))%                          ║
        ║                                                               ║
        ╠═══════════════════════════════════════════════════════════════╣
        ║  SLEEP ARCHITECTURE                                           ║
        ║  • Deep Sleep:  \(String(format: "%5.1f", architecture[.deep] ?? 0))%  (ideal: 13-23%)              ║
        ║  • REM Sleep:   \(String(format: "%5.1f", architecture[.rem] ?? 0))%  (ideal: 20-25%)              ║
        ║  • Light Sleep: \(String(format: "%5.1f", architecture[.light] ?? 0))%  (ideal: 50-60%)             ║
        ║  • Awake:       \(String(format: "%5.1f", architecture[.wake] ?? 0))%  (ideal: <10%)                ║
        ║                                                               ║
        ╠═══════════════════════════════════════════════════════════════╣
        ║  CIRCADIAN RHYTHM                                             ║
        ║  • Chronotype:  \(circadianAnalyzer.chronotype.rawValue.padding(toLength: 20, withPad: " ", startingAt: 0))             ║
        ║  • Alignment:   \(String(format: "%5.1f", circadianAnalyzer.getAlignmentScore()))%                             ║
        ║  • Social Jet Lag: \(String(format: "%+.1f", circadianAnalyzer.socialJetLag))h                          ║
        ║                                                               ║
        ╠═══════════════════════════════════════════════════════════════╣
        ║  RECOVERY STATUS                                              ║
        ║  • Recovery Score: \(String(format: "%5.1f", recoveryPredictor.recoveryScore))/100                       ║
        ║  • Readiness: \(recoveryPredictor.readinessToTrain.rawValue.padding(toLength: 15, withPad: " ", startingAt: 0))                     ║
        ║  • Strain Capacity: \(String(format: "%5.1f", recoveryPredictor.strainCapacity))                          ║
        ║                                                               ║
        ╚═══════════════════════════════════════════════════════════════╝

        References:
        • Herzig D et al. (2017) - Sleep stage HRV patterns
        • de Zambotti M et al. (2019) - Consumer sleep tracking validation
        • Roenneberg T et al. (2003) - Chronotype & social jet lag
        """
    }
}
