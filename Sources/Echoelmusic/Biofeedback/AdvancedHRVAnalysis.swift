//
//  AdvancedHRVAnalysis.swift
//  Echoelmusic
//
//  Advanced HRV Analysis including Poincaré plots, DFA, entropy measures
//  Based on scientific HRV research (PMC7527628, HeartMath Institute)
//
//  Created by Echoelmusic Team
//  Copyright © 2026 Echoelmusic. All rights reserved.
//

import Foundation
import Accelerate

// MARK: - Poincaré Plot Analysis

/// Poincaré plot analysis for HRV assessment
/// Plots RR(n) vs RR(n+1) to visualize heart rate variability patterns
public final class PoincarePlotAnalyzer {

    // MARK: - Poincaré Result

    public struct PoincarePlotResult {
        /// SD1: Short-term HRV (perpendicular to line of identity)
        /// Reflects parasympathetic activity
        public let sd1: Double

        /// SD2: Long-term HRV (along line of identity)
        /// Reflects overall HRV including sympathetic activity
        public let sd2: Double

        /// SD1/SD2 ratio - balance indicator
        /// Lower values suggest sympathetic dominance
        public let sd1SD2Ratio: Double

        /// Centroid of the plot (mean RR)
        public let centroidX: Double
        public let centroidY: Double

        /// Area of the fitted ellipse (π × SD1 × SD2)
        public let ellipseArea: Double

        /// Cardiac Sympathetic Index (CSI) = SD2/SD1
        public let csi: Double

        /// Cardiac Vagal Index (CVI) = log10(SD1 × SD2)
        public let cvi: Double

        /// Health interpretation
        public let interpretation: HealthInterpretation

        public enum HealthInterpretation: String {
            case excellent = "Excellent HRV - High adaptability"
            case good = "Good HRV - Healthy variability"
            case moderate = "Moderate HRV - Normal range"
            case reduced = "Reduced HRV - Consider stress management"
            case low = "Low HRV - May indicate chronic stress"
        }

        /// Points for visualization (RRn, RRn+1)
        public let plotPoints: [(x: Double, y: Double)]
    }

    // MARK: - Analysis

    /// Analyze RR intervals using Poincaré plot method
    /// - Parameter rrIntervals: R-R intervals in milliseconds
    /// - Returns: Poincaré analysis results
    public func analyze(rrIntervals: [Double]) -> PoincarePlotResult? {
        guard rrIntervals.count >= 10 else { return nil }

        // Create Poincaré plot points (RRn vs RRn+1)
        var plotPoints: [(x: Double, y: Double)] = []
        for i in 0..<(rrIntervals.count - 1) {
            plotPoints.append((x: rrIntervals[i], y: rrIntervals[i + 1]))
        }

        // Calculate centroid
        let centroidX = plotPoints.reduce(0.0) { $0 + $1.x } / Double(plotPoints.count)
        let centroidY = plotPoints.reduce(0.0) { $0 + $1.y } / Double(plotPoints.count)

        // Calculate SD1 and SD2 using standard deviation method
        // SD1 = SDSD / sqrt(2) where SDSD is successive difference SD
        // SD2 = sqrt(2 * SDNN^2 - 0.5 * SDSD^2)

        // Calculate successive differences
        var successiveDiffs: [Double] = []
        for i in 0..<(rrIntervals.count - 1) {
            successiveDiffs.append(rrIntervals[i + 1] - rrIntervals[i])
        }

        // SDSD (standard deviation of successive differences)
        let sdsd = standardDeviation(successiveDiffs)

        // SDNN (standard deviation of all RR intervals)
        let sdnn = standardDeviation(rrIntervals)

        // SD1 - short-term variability (parasympathetic)
        let sd1 = sdsd / sqrt(2.0)

        // SD2 - long-term variability
        let sd2Squared = 2.0 * sdnn * sdnn - 0.5 * sdsd * sdsd
        let sd2 = sd2Squared > 0 ? sqrt(sd2Squared) : 0

        // Derived metrics
        let sd1SD2Ratio = sd2 > 0 ? sd1 / sd2 : 0
        let ellipseArea = Double.pi * sd1 * sd2
        let csi = sd1 > 0 ? sd2 / sd1 : 0  // Cardiac Sympathetic Index
        let cvi = (sd1 > 0 && sd2 > 0) ? log10(sd1 * sd2) : 0  // Cardiac Vagal Index

        // Health interpretation based on SD1 values
        // Normal SD1 ranges: 20-50ms indicates good parasympathetic function
        let interpretation: PoincarePlotResult.HealthInterpretation
        switch sd1 {
        case 50...:
            interpretation = .excellent
        case 35..<50:
            interpretation = .good
        case 20..<35:
            interpretation = .moderate
        case 10..<20:
            interpretation = .reduced
        default:
            interpretation = .low
        }

        return PoincarePlotResult(
            sd1: sd1,
            sd2: sd2,
            sd1SD2Ratio: sd1SD2Ratio,
            centroidX: centroidX,
            centroidY: centroidY,
            ellipseArea: ellipseArea,
            csi: csi,
            cvi: cvi,
            interpretation: interpretation,
            plotPoints: plotPoints
        )
    }

    // MARK: - Helper Functions

    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }

        let mean = values.reduce(0, +) / Double(values.count)
        let squaredDiffs = values.map { ($0 - mean) * ($0 - mean) }
        let variance = squaredDiffs.reduce(0, +) / Double(values.count - 1)

        return sqrt(variance)
    }
}

// MARK: - Detrended Fluctuation Analysis (DFA)

/// DFA for assessing fractal-like properties of HRV
/// α1 (short-term) correlates with parasympathetic activity
/// α2 (long-term) reflects overall complexity
public final class DFAAnalyzer {

    // MARK: - DFA Result

    public struct DFAResult {
        /// Short-term scaling exponent (4-16 beats)
        /// Healthy range: 0.85-1.15
        public let alpha1: Double

        /// Long-term scaling exponent (16-64 beats)
        /// Healthy range: 0.85-1.15
        public let alpha2: Double

        /// Overall scaling exponent
        public let alphaOverall: Double

        /// Interpretation
        public let interpretation: DFAInterpretation

        public enum DFAInterpretation: String {
            case healthy = "Healthy fractal dynamics"
            case decreased = "Decreased complexity - possible stress"
            case increased = "Increased randomness"
            case abnormal = "Abnormal HRV dynamics"
        }

        /// Fluctuation function values for plotting
        public let fluctuationData: [(scale: Int, fluctuation: Double)]
    }

    // MARK: - Analysis

    /// Perform Detrended Fluctuation Analysis
    /// - Parameter rrIntervals: R-R intervals in milliseconds
    /// - Returns: DFA scaling exponents
    public func analyze(rrIntervals: [Double]) -> DFAResult? {
        guard rrIntervals.count >= 64 else { return nil }

        // Step 1: Integrate the signal (cumulative sum of deviations from mean)
        let mean = rrIntervals.reduce(0, +) / Double(rrIntervals.count)
        var integratedSignal: [Double] = []
        var cumSum = 0.0
        for rr in rrIntervals {
            cumSum += rr - mean
            integratedSignal.append(cumSum)
        }

        // Step 2: Divide into boxes and compute fluctuations
        let scales = [4, 6, 8, 12, 16, 24, 32, 48, 64]
        var fluctuationData: [(scale: Int, fluctuation: Double)] = []

        for scale in scales where scale <= rrIntervals.count / 4 {
            let fluctuation = computeFluctuation(signal: integratedSignal, scale: scale)
            fluctuationData.append((scale, fluctuation))
        }

        guard fluctuationData.count >= 4 else { return nil }

        // Step 3: Linear regression to find scaling exponents
        // Alpha1: short-term (scales 4-16)
        let shortTermData = fluctuationData.filter { $0.scale <= 16 }
        let alpha1 = computeScalingExponent(data: shortTermData)

        // Alpha2: long-term (scales 16-64)
        let longTermData = fluctuationData.filter { $0.scale >= 16 }
        let alpha2 = computeScalingExponent(data: longTermData)

        // Overall
        let alphaOverall = computeScalingExponent(data: fluctuationData)

        // Interpretation
        let interpretation: DFAResult.DFAInterpretation
        if alpha1 >= 0.75 && alpha1 <= 1.25 && alpha2 >= 0.75 && alpha2 <= 1.25 {
            interpretation = .healthy
        } else if alpha1 < 0.75 || alpha2 < 0.75 {
            interpretation = .decreased
        } else if alpha1 > 1.5 || alpha2 > 1.5 {
            interpretation = .increased
        } else {
            interpretation = .abnormal
        }

        return DFAResult(
            alpha1: alpha1,
            alpha2: alpha2,
            alphaOverall: alphaOverall,
            interpretation: interpretation,
            fluctuationData: fluctuationData
        )
    }

    // MARK: - Helper Functions

    private func computeFluctuation(signal: [Double], scale: Int) -> Double {
        let n = signal.count
        let numBoxes = n / scale
        guard numBoxes > 0 else { return 0 }

        var totalFluctuation = 0.0

        for box in 0..<numBoxes {
            let start = box * scale
            let end = start + scale

            // Extract segment
            let segment = Array(signal[start..<end])

            // Fit linear trend
            let (slope, intercept) = linearFit(segment)

            // Compute RMS of residuals
            var squaredResiduals = 0.0
            for (i, value) in segment.enumerated() {
                let trend = slope * Double(i) + intercept
                let residual = value - trend
                squaredResiduals += residual * residual
            }

            totalFluctuation += squaredResiduals
        }

        return sqrt(totalFluctuation / Double(numBoxes * scale))
    }

    private func linearFit(_ values: [Double]) -> (slope: Double, intercept: Double) {
        let n = Double(values.count)
        guard n > 1 else { return (0, values.first ?? 0) }

        var sumX = 0.0
        var sumY = 0.0
        var sumXY = 0.0
        var sumX2 = 0.0

        for (i, y) in values.enumerated() {
            let x = Double(i)
            sumX += x
            sumY += y
            sumXY += x * y
            sumX2 += x * x
        }

        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return (0, sumY / n) }

        let slope = (n * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / n

        return (slope, intercept)
    }

    private func computeScalingExponent(data: [(scale: Int, fluctuation: Double)]) -> Double {
        guard data.count >= 2 else { return 1.0 }

        // Log-log linear regression
        let logData = data.map { (log(Double($0.scale)), log($0.fluctuation)) }

        var sumX = 0.0
        var sumY = 0.0
        var sumXY = 0.0
        var sumX2 = 0.0
        let n = Double(logData.count)

        for (x, y) in logData {
            sumX += x
            sumY += y
            sumXY += x * y
            sumX2 += x * x
        }

        let denominator = n * sumX2 - sumX * sumX
        guard denominator != 0 else { return 1.0 }

        return (n * sumXY - sumX * sumY) / denominator
    }
}

// MARK: - Sample Entropy

/// Sample Entropy analysis for HRV complexity
/// Lower values indicate more regular (less complex) patterns
public final class SampleEntropyAnalyzer {

    // MARK: - Result

    public struct SampleEntropyResult {
        /// Sample entropy value
        /// Healthy range: 1.0-2.0
        public let entropy: Double

        /// Interpretation
        public let interpretation: EntropyInterpretation

        public enum EntropyInterpretation: String {
            case highComplexity = "High complexity - excellent adaptability"
            case normalComplexity = "Normal complexity - healthy HRV"
            case reducedComplexity = "Reduced complexity - may indicate stress"
            case lowComplexity = "Low complexity - possible health concern"
        }
    }

    // MARK: - Analysis

    /// Calculate Sample Entropy
    /// - Parameters:
    ///   - data: Time series data (RR intervals)
    ///   - m: Embedding dimension (typically 2)
    ///   - r: Tolerance (typically 0.2 * SD)
    /// - Returns: Sample entropy result
    public func analyze(data: [Double], m: Int = 2, r: Double? = nil) -> SampleEntropyResult? {
        guard data.count >= 10 + m else { return nil }

        // Calculate tolerance if not provided (0.2 * SD)
        let tolerance: Double
        if let r = r {
            tolerance = r
        } else {
            let mean = data.reduce(0, +) / Double(data.count)
            let variance = data.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(data.count - 1)
            tolerance = 0.2 * sqrt(variance)
        }

        // Count template matches for m and m+1
        let countM = countTemplateMatches(data: data, templateLength: m, tolerance: tolerance)
        let countM1 = countTemplateMatches(data: data, templateLength: m + 1, tolerance: tolerance)

        // Sample entropy = -ln(B/A) where A = count(m), B = count(m+1)
        guard countM > 0 && countM1 > 0 else { return nil }

        let entropy = -log(Double(countM1) / Double(countM))

        // Interpretation
        let interpretation: SampleEntropyResult.EntropyInterpretation
        switch entropy {
        case 1.5...:
            interpretation = .highComplexity
        case 1.0..<1.5:
            interpretation = .normalComplexity
        case 0.5..<1.0:
            interpretation = .reducedComplexity
        default:
            interpretation = .lowComplexity
        }

        return SampleEntropyResult(
            entropy: entropy,
            interpretation: interpretation
        )
    }

    private func countTemplateMatches(data: [Double], templateLength: Int, tolerance: Double) -> Int {
        let n = data.count
        var count = 0

        for i in 0..<(n - templateLength) {
            for j in (i + 1)..<(n - templateLength) {
                // Check if templates match (all elements within tolerance)
                var matches = true
                for k in 0..<templateLength {
                    if abs(data[i + k] - data[j + k]) > tolerance {
                        matches = false
                        break
                    }
                }
                if matches {
                    count += 1
                }
            }
        }

        return count
    }
}

// MARK: - Comprehensive HRV Analyzer

/// Comprehensive HRV analysis combining all advanced metrics
public final class AdvancedHRVAnalyzer {

    private let poincareAnalyzer = PoincarePlotAnalyzer()
    private let dfaAnalyzer = DFAAnalyzer()
    private let entropyAnalyzer = SampleEntropyAnalyzer()

    // MARK: - Complete Result

    public struct ComprehensiveHRVResult {
        // Time domain
        public let meanRR: Double
        public let sdnn: Double
        public let rmssd: Double
        public let pnn50: Double

        // Poincaré
        public let poincare: PoincarePlotAnalyzer.PoincarePlotResult?

        // DFA
        public let dfa: DFAAnalyzer.DFAResult?

        // Entropy
        public let sampleEntropy: SampleEntropyAnalyzer.SampleEntropyResult?

        // Overall health score (0-100)
        public let healthScore: Int

        // Interpretation
        public let overallInterpretation: String

        // Recommendations
        public let recommendations: [String]
    }

    // MARK: - Analysis

    /// Perform comprehensive HRV analysis
    /// - Parameter rrIntervals: R-R intervals in milliseconds
    /// - Returns: Complete HRV analysis results
    public func analyze(rrIntervals: [Double]) -> ComprehensiveHRVResult? {
        guard rrIntervals.count >= 30 else { return nil }

        // Time domain metrics
        let meanRR = rrIntervals.reduce(0, +) / Double(rrIntervals.count)

        let sdnn = standardDeviation(rrIntervals)

        // RMSSD
        var squaredDiffs: [Double] = []
        for i in 0..<(rrIntervals.count - 1) {
            let diff = rrIntervals[i + 1] - rrIntervals[i]
            squaredDiffs.append(diff * diff)
        }
        let rmssd = sqrt(squaredDiffs.reduce(0, +) / Double(squaredDiffs.count))

        // pNN50
        var nn50Count = 0
        for i in 0..<(rrIntervals.count - 1) {
            if abs(rrIntervals[i + 1] - rrIntervals[i]) > 50 {
                nn50Count += 1
            }
        }
        let pnn50 = Double(nn50Count) / Double(rrIntervals.count - 1) * 100

        // Advanced analyses
        let poincare = poincareAnalyzer.analyze(rrIntervals: rrIntervals)
        let dfa = dfaAnalyzer.analyze(rrIntervals: rrIntervals)
        let entropy = entropyAnalyzer.analyze(data: rrIntervals)

        // Calculate health score (0-100)
        var score = 50.0

        // SDNN contribution (ideal: 50-100ms)
        if sdnn >= 50 && sdnn <= 100 {
            score += 15
        } else if sdnn >= 30 && sdnn < 50 {
            score += 10
        } else if sdnn > 100 {
            score += 12
        }

        // RMSSD contribution (ideal: 20-50ms)
        if rmssd >= 20 && rmssd <= 50 {
            score += 15
        } else if rmssd > 50 {
            score += 12
        } else if rmssd >= 10 {
            score += 5
        }

        // Poincaré SD1 contribution
        if let p = poincare {
            if p.sd1 >= 35 { score += 10 }
            else if p.sd1 >= 20 { score += 5 }
        }

        // DFA contribution
        if let d = dfa {
            if d.alpha1 >= 0.85 && d.alpha1 <= 1.15 { score += 10 }
        }

        // Entropy contribution
        if let e = entropy {
            if e.entropy >= 1.0 { score += 10 }
        }

        let healthScore = min(100, max(0, Int(score)))

        // Interpretation
        let interpretation: String
        switch healthScore {
        case 80...:
            interpretation = "Excellent HRV - Your autonomic nervous system shows high adaptability and resilience."
        case 60..<80:
            interpretation = "Good HRV - Healthy variability patterns with room for improvement."
        case 40..<60:
            interpretation = "Moderate HRV - Consider stress management and lifestyle optimization."
        case 20..<40:
            interpretation = "Reduced HRV - May indicate chronic stress or fatigue. Consider consulting a healthcare provider."
        default:
            interpretation = "Low HRV - Significant reduction in heart rate variability. Please consult a healthcare provider."
        }

        // Recommendations
        var recommendations: [String] = []

        if sdnn < 50 {
            recommendations.append("Practice deep breathing exercises (4-7-8 pattern) for 5-10 minutes daily")
        }
        if rmssd < 20 {
            recommendations.append("Increase parasympathetic activity through meditation or yoga")
        }
        if poincare?.sd1SD2Ratio ?? 0 < 0.5 {
            recommendations.append("Your sympathetic nervous system may be overactive - prioritize rest and recovery")
        }
        if dfa?.alpha1 ?? 0 < 0.85 {
            recommendations.append("Consider improving sleep quality and duration")
        }
        if entropy?.entropy ?? 0 < 1.0 {
            recommendations.append("Engage in varied physical activities to increase HRV complexity")
        }

        if recommendations.isEmpty {
            recommendations.append("Maintain your current healthy lifestyle practices")
            recommendations.append("Continue regular coherence training sessions")
        }

        return ComprehensiveHRVResult(
            meanRR: meanRR,
            sdnn: sdnn,
            rmssd: rmssd,
            pnn50: pnn50,
            poincare: poincare,
            dfa: dfa,
            sampleEntropy: entropy,
            healthScore: healthScore,
            overallInterpretation: interpretation,
            recommendations: recommendations
        )
    }

    // MARK: - Helper

    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count - 1)
        return sqrt(variance)
    }
}

// MARK: - Health Disclaimer

/// IMPORTANT: Advanced HRV metrics are for educational and wellness purposes only.
/// They are NOT intended to diagnose, treat, cure, or prevent any disease.
/// Always consult a qualified healthcare provider for medical advice.
/// See LambdaHealthDisclaimer for complete disclaimers.
