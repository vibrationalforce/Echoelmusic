import Foundation
import SwiftUI
import Combine
import Accelerate

// MARK: - Science Mode
/// Research-grade biometric analysis with peer-reviewed protocols
/// Evidence-based music therapy with clinical study framework

// MARK: - Science Mode Hub

@MainActor
public final class ScienceModeHub: ObservableObject {

    // MARK: - Singleton
    public static let shared = ScienceModeHub()

    // MARK: - Published State
    @Published public var isActive: Bool = false
    @Published public var currentStudy: ResearchStudy?
    @Published public var analysisResults: [AnalysisResult] = []
    @Published public var bioMetrics: RealTimeBioMetrics = RealTimeBioMetrics()
    @Published public var hrvAnalysis: AdvancedHRVAnalysis = AdvancedHRVAnalysis()
    @Published public var sessionData: [SessionDataPoint] = []

    // MARK: - Research Configuration
    @Published public var researchMode: ResearchMode = .standard
    @Published public var dataCollectionRate: DataCollectionRate = .high
    @Published public var exportFormat: ExportFormat = .csv
    @Published public var blindingEnabled: Bool = false

    // MARK: - Statistical Engine
    private let statisticsEngine = StatisticalAnalysisEngine()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Data Buffers
    private var rrIntervalBuffer: [Double] = []
    private let maxBufferSize = 600 // 10 minutes at 1Hz
    private var sessionStartTime: Date?

    init() {
        EchoelLogger.success("ScienceModeHub initialized", category: EchoelLogger.bio)
    }

    // MARK: - Session Management

    public func startSession(study: ResearchStudy? = nil) {
        isActive = true
        currentStudy = study
        sessionStartTime = Date()
        sessionData.removeAll()
        rrIntervalBuffer.removeAll()
        EchoelLogger.log("🔬", "Science session started: \(study?.name ?? "Open Session")", category: EchoelLogger.bio)
    }

    public func endSession() -> SessionReport {
        isActive = false
        let report = generateSessionReport()
        EchoelLogger.log("🔬", "Science session ended. Duration: \(report.durationMinutes) min", category: EchoelLogger.bio)
        return report
    }

    // MARK: - Data Input

    public func addRRInterval(_ interval: Double) {
        guard isActive else { return }

        // Validate interval (300-2000ms = 30-200 BPM)
        guard interval >= 300 && interval <= 2000 else { return }

        rrIntervalBuffer.append(interval)
        if rrIntervalBuffer.count > maxBufferSize {
            rrIntervalBuffer.removeFirst()
        }

        // Update metrics
        updateRealTimeMetrics()

        // Store data point
        let dataPoint = SessionDataPoint(
            timestamp: Date(),
            rrInterval: interval,
            heartRate: 60000.0 / interval,
            hrv: hrvAnalysis.rmssd,
            coherence: bioMetrics.coherence
        )
        sessionData.append(dataPoint)
    }

    public func addHeartRate(_ bpm: Double) {
        guard bpm >= 30 && bpm <= 220 else { return }
        bioMetrics.heartRate = bpm
    }

    public func addHRV(_ rmssd: Double) {
        bioMetrics.hrv = rmssd
    }

    public func addCoherence(_ score: Double) {
        bioMetrics.coherence = score.clamped(0, 100)
    }

    // MARK: - Real-Time Analysis

    private func updateRealTimeMetrics() {
        guard rrIntervalBuffer.count >= 10 else { return }

        // Time-domain HRV
        hrvAnalysis.rmssd = calculateRMSSD()
        hrvAnalysis.sdnn = calculateSDNN()
        hrvAnalysis.pnn50 = calculatePNN50()
        hrvAnalysis.meanRR = calculateMeanRR()
        hrvAnalysis.heartRate = 60000.0 / hrvAnalysis.meanRR

        // Frequency-domain analysis
        if rrIntervalBuffer.count >= 128 {
            performFrequencyDomainAnalysis()
        }

        // Poincaré analysis
        if rrIntervalBuffer.count >= 20 {
            performPoincareAnalysis()
        }

        // Coherence calculation
        bioMetrics.coherence = calculateCoherence()

        // Stress index (Baevsky)
        hrvAnalysis.stressIndex = calculateStressIndex()

        // Update bio metrics
        bioMetrics.hrv = hrvAnalysis.rmssd
        bioMetrics.heartRate = hrvAnalysis.heartRate
    }

    // MARK: - Time-Domain HRV Calculations

    private func calculateRMSSD() -> Double {
        guard rrIntervalBuffer.count >= 2 else { return 0 }

        var sumSquaredDiff: Double = 0
        for i in 1..<rrIntervalBuffer.count {
            let diff = rrIntervalBuffer[i] - rrIntervalBuffer[i-1]
            sumSquaredDiff += diff * diff
        }

        return sqrt(sumSquaredDiff / Double(rrIntervalBuffer.count - 1))
    }

    private func calculateSDNN() -> Double {
        guard rrIntervalBuffer.count >= 2 else { return 0 }

        let mean = rrIntervalBuffer.reduce(0, +) / Double(rrIntervalBuffer.count)
        var sumSquaredDev: Double = 0

        for interval in rrIntervalBuffer {
            let dev = interval - mean
            sumSquaredDev += dev * dev
        }

        return sqrt(sumSquaredDev / Double(rrIntervalBuffer.count - 1))
    }

    private func calculatePNN50() -> Double {
        guard rrIntervalBuffer.count >= 2 else { return 0 }

        var count50: Int = 0
        for i in 1..<rrIntervalBuffer.count {
            let diff = abs(rrIntervalBuffer[i] - rrIntervalBuffer[i-1])
            if diff > 50 {
                count50 += 1
            }
        }

        return Double(count50) / Double(rrIntervalBuffer.count - 1) * 100
    }

    private func calculateMeanRR() -> Double {
        guard !rrIntervalBuffer.isEmpty else { return 800 }
        return rrIntervalBuffer.reduce(0, +) / Double(rrIntervalBuffer.count)
    }

    // MARK: - Frequency-Domain Analysis

    private func performFrequencyDomainAnalysis() {
        let n = min(rrIntervalBuffer.count, 256)
        guard n >= 128 else { return }

        // Prepare data for FFT
        var data = Array(rrIntervalBuffer.suffix(n))

        // Detrend (remove linear trend)
        data = detrend(data)

        // Apply Hamming window
        data = applyHammingWindow(data)

        // Zero-pad to power of 2
        let fftSize = 256
        while data.count < fftSize {
            data.append(0)
        }

        // Perform FFT using Accelerate
        let (frequencies, powers) = performFFT(data, sampleRate: 1.0) // 1Hz for RR intervals

        // Calculate band powers
        hrvAnalysis.vlfPower = calculateBandPower(frequencies: frequencies, powers: powers, lowFreq: 0.003, highFreq: 0.04)
        hrvAnalysis.lfPower = calculateBandPower(frequencies: frequencies, powers: powers, lowFreq: 0.04, highFreq: 0.15)
        hrvAnalysis.hfPower = calculateBandPower(frequencies: frequencies, powers: powers, lowFreq: 0.15, highFreq: 0.4)

        // LF/HF ratio
        hrvAnalysis.lfHfRatio = hrvAnalysis.hfPower > 0 ? hrvAnalysis.lfPower / hrvAnalysis.hfPower : 0

        // Total power
        hrvAnalysis.totalPower = hrvAnalysis.vlfPower + hrvAnalysis.lfPower + hrvAnalysis.hfPower

        // Normalized units
        let lfhfTotal = hrvAnalysis.lfPower + hrvAnalysis.hfPower
        hrvAnalysis.lfNormalized = lfhfTotal > 0 ? hrvAnalysis.lfPower / lfhfTotal * 100 : 50
        hrvAnalysis.hfNormalized = lfhfTotal > 0 ? hrvAnalysis.hfPower / lfhfTotal * 100 : 50

        // Store spectrum for visualization
        hrvAnalysis.frequencySpectrum = Array(zip(frequencies, powers).prefix(64).map { FrequencyPoint(frequency: $0, power: $1) })
    }

    private func detrend(_ data: [Double]) -> [Double] {
        guard data.count >= 2 else { return data }

        let n = Double(data.count)
        let xMean = (n - 1) / 2
        var yMean = data.reduce(0, +) / n

        var sumXY: Double = 0
        var sumXX: Double = 0

        for (i, y) in data.enumerated() {
            let x = Double(i) - xMean
            sumXY += x * (y - yMean)
            sumXX += x * x
        }

        let slope = sumXX > 0 ? sumXY / sumXX : 0
        let intercept = yMean - slope * xMean

        return data.enumerated().map { Double($0.offset) * slope + intercept - $0.element + yMean }
    }

    private func applyHammingWindow(_ data: [Double]) -> [Double] {
        let n = data.count
        return data.enumerated().map { i, value in
            let window = 0.54 - 0.46 * cos(2 * .pi * Double(i) / Double(n - 1))
            return value * window
        }
    }

    private func performFFT(_ data: [Double], sampleRate: Double) -> ([Double], [Double]) {
        let n = data.count
        let log2n = vDSP_Length(log2(Double(n)))

        guard let fftSetup = vDSP_create_fftsetupD(log2n, FFTRadix(kFFTRadix2)) else {
            return ([], [])
        }
        defer { vDSP_destroy_fftsetupD(fftSetup) }

        var real = data
        var imag = [Double](repeating: 0, count: n)

        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPDoubleSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_fft_zipD(fftSetup, &splitComplex, 1, log2n, FFTDirection(kFFTDirection_Forward))
            }
        }

        // Calculate magnitudes
        var magnitudes = [Double](repeating: 0, count: n/2)
        for i in 0..<n/2 {
            magnitudes[i] = sqrt(real[i] * real[i] + imag[i] * imag[i]) / Double(n)
        }

        // Frequency bins
        let frequencies = (0..<n/2).map { Double($0) * sampleRate / Double(n) }

        return (frequencies, magnitudes)
    }

    private func calculateBandPower(frequencies: [Double], powers: [Double], lowFreq: Double, highFreq: Double) -> Double {
        var power: Double = 0
        for (freq, pwr) in zip(frequencies, powers) {
            if freq >= lowFreq && freq < highFreq {
                power += pwr * pwr
            }
        }
        return power
    }

    // MARK: - Poincaré Analysis

    private func performPoincareAnalysis() {
        guard rrIntervalBuffer.count >= 20 else { return }

        var sd1Squared: Double = 0
        var sd2Squared: Double = 0

        let n = rrIntervalBuffer.count - 1

        for i in 0..<n {
            let x = rrIntervalBuffer[i]
            let y = rrIntervalBuffer[i + 1]

            // SD1: perpendicular to line of identity
            let sd1Point = (y - x) / sqrt(2)
            sd1Squared += sd1Point * sd1Point

            // SD2: along line of identity
            let sd2Point = (x + y) / sqrt(2)
            sd2Squared += sd2Point * sd2Point
        }

        hrvAnalysis.sd1 = sqrt(sd1Squared / Double(n))
        hrvAnalysis.sd2 = sqrt(sd2Squared / Double(n) - pow(rrIntervalBuffer.reduce(0, +) / Double(rrIntervalBuffer.count), 2))
        hrvAnalysis.sd1sd2Ratio = hrvAnalysis.sd2 > 0 ? hrvAnalysis.sd1 / hrvAnalysis.sd2 : 0

        // Store Poincaré points for visualization
        hrvAnalysis.poincarePoints = (0..<n).map { i in
            PoincarePoint(x: rrIntervalBuffer[i], y: rrIntervalBuffer[i + 1])
        }
    }

    // MARK: - Coherence Calculation (HeartMath Algorithm)

    private func calculateCoherence() -> Double {
        guard rrIntervalBuffer.count >= 64 else { return 0 }

        // Use last 64 intervals (~1 minute)
        let recentIntervals = Array(rrIntervalBuffer.suffix(64))

        // Detrend and window
        var data = detrend(recentIntervals)
        data = applyHammingWindow(data)

        // FFT
        let (frequencies, powers) = performFFT(data, sampleRate: 1.0)

        // Find peak in coherence band (0.04-0.26 Hz)
        var maxPower: Double = 0
        var totalPower: Double = 0

        for (freq, power) in zip(frequencies, powers) {
            if freq >= 0.04 && freq <= 0.26 {
                maxPower = max(maxPower, power)
                totalPower += power
            }
        }

        // Coherence ratio (peak power / total power in band)
        let coherenceRatio = totalPower > 0 ? maxPower / totalPower : 0

        // Scale to 0-100
        return min(coherenceRatio * 200, 100)
    }

    // MARK: - Stress Index (Baevsky)

    private func calculateStressIndex() -> Double {
        guard !rrIntervalBuffer.isEmpty else { return 50 }

        let meanRR = calculateMeanRR()
        let sdnn = calculateSDNN()

        // Simplified Baevsky stress index
        // SI = AMo / (2 * Mo * MxDMn)
        // Approximation using available metrics

        let normalizedHRV = sdnn / 100 // Normalize SDNN (typical range 20-100ms)
        let normalizedHR = (hrvAnalysis.heartRate - 60) / 40 // Normalize HR (60-100 BPM typical)

        let stressIndex = 50 * (1 - normalizedHRV.clamped(0, 1)) + 50 * normalizedHR.clamped(0, 1)
        return stressIndex.clamped(0, 100)
    }

    // MARK: - Session Report

    private func generateSessionReport() -> SessionReport {
        let duration = sessionStartTime.map { Date().timeIntervalSince($0) } ?? 0

        return SessionReport(
            id: UUID(),
            studyId: currentStudy?.id,
            startTime: sessionStartTime ?? Date(),
            endTime: Date(),
            durationMinutes: duration / 60,
            dataPoints: sessionData.count,
            averageHRV: sessionData.map { $0.hrv }.average(),
            averageHeartRate: sessionData.map { $0.heartRate }.average(),
            averageCoherence: sessionData.map { $0.coherence }.average(),
            hrvAnalysis: hrvAnalysis,
            statisticalSummary: statisticsEngine.generateSummary(from: sessionData)
        )
    }

    // MARK: - Export

    public func exportToCSV() -> String {
        var csv = "Timestamp,RR_Interval_ms,Heart_Rate_BPM,HRV_RMSSD_ms,Coherence_Score\n"

        let formatter = ISO8601DateFormatter()

        for point in sessionData {
            csv += "\(formatter.string(from: point.timestamp)),"
            csv += "\(point.rrInterval),"
            csv += String(format: "%.1f,", point.heartRate)
            csv += String(format: "%.2f,", point.hrv)
            csv += String(format: "%.1f\n", point.coherence)
        }

        return csv
    }

    public func exportToJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        let export = SessionExport(
            metadata: SessionMetadata(
                version: "1.0",
                exportDate: Date(),
                studyName: currentStudy?.name,
                protocolType: currentStudy?.protocol.rawValue
            ),
            hrvAnalysis: hrvAnalysis,
            dataPoints: sessionData
        )

        return try? encoder.encode(export)
    }
}

// MARK: - Supporting Types

public struct RealTimeBioMetrics {
    public var heartRate: Double = 72
    public var hrv: Double = 50
    public var coherence: Double = 50
    public var breathingRate: Double = 12
    public var stressLevel: Double = 50
}

public struct AdvancedHRVAnalysis: Codable {
    // Time-domain
    public var meanRR: Double = 800
    public var heartRate: Double = 75
    public var sdnn: Double = 50
    public var rmssd: Double = 40
    public var pnn50: Double = 15

    // Frequency-domain
    public var vlfPower: Double = 0
    public var lfPower: Double = 0
    public var hfPower: Double = 0
    public var lfHfRatio: Double = 1.0
    public var totalPower: Double = 0
    public var lfNormalized: Double = 50
    public var hfNormalized: Double = 50

    // Poincaré
    public var sd1: Double = 20
    public var sd2: Double = 50
    public var sd1sd2Ratio: Double = 0.4

    // Stress
    public var stressIndex: Double = 50

    // Visualization data
    public var frequencySpectrum: [FrequencyPoint] = []
    public var poincarePoints: [PoincarePoint] = []
}

public struct FrequencyPoint: Codable, Identifiable {
    public var id: Double { frequency }
    public var frequency: Double
    public var power: Double
}

public struct PoincarePoint: Codable, Identifiable {
    public var id: String { "\(x)-\(y)" }
    public var x: Double
    public var y: Double
}

public struct SessionDataPoint: Codable, Identifiable {
    public var id: Date { timestamp }
    public var timestamp: Date
    public var rrInterval: Double
    public var heartRate: Double
    public var hrv: Double
    public var coherence: Double
}

public struct SessionReport: Codable, Identifiable {
    public var id: UUID
    public var studyId: UUID?
    public var startTime: Date
    public var endTime: Date
    public var durationMinutes: Double
    public var dataPoints: Int
    public var averageHRV: Double
    public var averageHeartRate: Double
    public var averageCoherence: Double
    public var hrvAnalysis: AdvancedHRVAnalysis
    public var statisticalSummary: StatisticalSummary
}

public struct SessionExport: Codable {
    public var metadata: SessionMetadata
    public var hrvAnalysis: AdvancedHRVAnalysis
    public var dataPoints: [SessionDataPoint]
}

public struct SessionMetadata: Codable {
    public var version: String
    public var exportDate: Date
    public var studyName: String?
    public var protocolType: String?
}

// MARK: - Research Study

public struct ResearchStudy: Identifiable, Codable {
    public var id: UUID
    public var name: String
    public var description: String
    public var `protocol`: StudyProtocol
    public var duration: TimeInterval
    public var sessions: Int
    public var evidenceLevel: EvidenceLevel
    public var references: [String]

    public enum StudyProtocol: String, Codable, CaseIterable {
        case hrvBiofeedback = "HRV Biofeedback"
        case resonanceFrequency = "Resonance Frequency Training"
        case slowBreathing = "Slow Breathing Protocol"
        case coherenceBuilding = "HeartMath Coherence"
        case musicTherapy = "Music Therapy"
        case binauralBeats = "Binaural Beat Entrainment"
        case custom = "Custom Protocol"
    }
}

public enum EvidenceLevel: String, Codable, CaseIterable {
    case level1a = "1a - Meta-Analysis of RCTs"
    case level1b = "1b - Individual RCT"
    case level2a = "2a - Systematic Review"
    case level2b = "2b - Individual Cohort Study"
    case level3 = "3 - Case-Control Study"
    case level4 = "4 - Case Series"
    case level5 = "5 - Expert Opinion"
}

public enum ResearchMode: String, CaseIterable {
    case standard = "Standard"
    case clinical = "Clinical Trial"
    case research = "Research Study"
    case pilot = "Pilot Study"
}

public enum DataCollectionRate: String, CaseIterable {
    case low = "Low (1Hz)"
    case medium = "Medium (4Hz)"
    case high = "High (10Hz)"
}

public enum ExportFormat: String, CaseIterable {
    case csv = "CSV"
    case json = "JSON"
    case fhir = "FHIR R4"
}

// MARK: - Statistical Analysis Engine

public class StatisticalAnalysisEngine {

    public func generateSummary(from data: [SessionDataPoint]) -> StatisticalSummary {
        let hrvValues = data.map { $0.hrv }
        let hrValues = data.map { $0.heartRate }
        let coherenceValues = data.map { $0.coherence }

        return StatisticalSummary(
            hrvMean: hrvValues.average(),
            hrvSD: hrvValues.standardDeviation(),
            hrvMin: hrvValues.min() ?? 0,
            hrvMax: hrvValues.max() ?? 0,
            hrMean: hrValues.average(),
            hrSD: hrValues.standardDeviation(),
            coherenceMean: coherenceValues.average(),
            coherenceSD: coherenceValues.standardDeviation(),
            sampleSize: data.count,
            trendDirection: calculateTrend(hrvValues)
        )
    }

    private func calculateTrend(_ values: [Double]) -> TrendDirection {
        guard values.count >= 10 else { return .stable }

        let firstHalf = Array(values.prefix(values.count / 2)).average()
        let secondHalf = Array(values.suffix(values.count / 2)).average()

        let change = (secondHalf - firstHalf) / firstHalf * 100

        if change > 5 { return .increasing }
        if change < -5 { return .decreasing }
        return .stable
    }
}

public struct StatisticalSummary: Codable {
    public var hrvMean: Double
    public var hrvSD: Double
    public var hrvMin: Double
    public var hrvMax: Double
    public var hrMean: Double
    public var hrSD: Double
    public var coherenceMean: Double
    public var coherenceSD: Double
    public var sampleSize: Int
    public var trendDirection: TrendDirection
}

public enum TrendDirection: String, Codable {
    case increasing = "Increasing"
    case decreasing = "Decreasing"
    case stable = "Stable"
}

// MARK: - Array Extensions

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

extension Double {
    func clamped(_ min: Double, _ max: Double) -> Double {
        Swift.min(Swift.max(self, min), max)
    }
}
