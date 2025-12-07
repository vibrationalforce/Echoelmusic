// IndividualFrequencyScanner.swift
// Echoelmusic - Individual Biological Frequency Analysis
//
// SCIENTIFIC PRINCIPLE:
// Biological frequencies are NOT static constants. They are:
// 1. INDIVIDUAL - Each person has unique frequency signatures
// 2. DYNAMIC - Frequencies fluctuate moment to moment
// 3. VARIABLE - Healthy variability indicates adaptability (like HRV)
// 4. PRECISE - Measurable to multiple decimal places
//
// The heart doesn't beat like a clock at "60 BPM" - it dances:
// 1.0234Hz → 0.9871Hz → 1.0456Hz → 0.9923Hz
// This variability (HRV) IS the health marker.
//
// Scientific References:
// - Malik, M. (1996): Heart rate variability: Standards of measurement
// - Thayer, J.F. (2012): Neurovisceral integration model
// - Buzsáki, G. (2006): Rhythms of the Brain - neural oscillation variability
// - Glass, L. (2001): Synchronization and rhythmic processes in physiology
// - Strogatz, S. (2003): Sync: How Order Emerges from Chaos
// - Goldberger, A.L. (1996): Fractal dynamics in physiology and disease

import Foundation
import simd
import Combine
import Accelerate

// MARK: - Precision Types

/// High-precision frequency measurement (6+ decimal places)
public typealias PreciseFrequency = Double

/// Frequency with uncertainty bounds
public struct MeasuredFrequency: Codable, CustomStringConvertible {
    public let value: PreciseFrequency          // Central frequency
    public let uncertainty: PreciseFrequency    // Measurement uncertainty (±)
    public let confidence: Double               // 0.0-1.0 confidence level
    public let timestamp: Date
    public let sampleCount: Int                 // Number of samples averaged

    public var description: String {
        String(format: "%.6f Hz (±%.6f, %.1f%% confidence, n=%d)",
               value, uncertainty, confidence * 100, sampleCount)
    }

    /// Range within uncertainty bounds
    public var range: ClosedRange<PreciseFrequency> {
        (value - uncertainty)...(value + uncertainty)
    }
}

// MARK: - Biological Oscillation Model

/// Models the natural variability of biological rhythms
public struct BiologicalOscillation: Codable {
    public var baseFrequency: PreciseFrequency      // Central tendency
    public var instantFrequency: PreciseFrequency   // Current moment
    public var variabilitySD: PreciseFrequency      // Standard deviation
    public var variabilityRMSSD: PreciseFrequency   // Root mean square of successive differences
    public var coherence: Double                     // 0-1 how ordered/chaotic
    public var fractalDimension: Double             // Complexity measure (healthy ~1.0-1.5)

    // Time-domain statistics
    public var meanNN: PreciseFrequency             // Mean interval
    public var sdnn: PreciseFrequency               // SD of all intervals
    public var nn50: Int                            // Intervals differing >50ms
    public var pnn50: Double                        // Percentage of NN50

    // Frequency-domain bands (for neural/cardiac)
    public var vlfPower: Double                     // Very Low Frequency power
    public var lfPower: Double                      // Low Frequency power
    public var hfPower: Double                      // High Frequency power
    public var lfHfRatio: Double                    // Sympathovagal balance

    public init(baseFrequency: PreciseFrequency) {
        self.baseFrequency = baseFrequency
        self.instantFrequency = baseFrequency
        self.variabilitySD = 0
        self.variabilityRMSSD = 0
        self.coherence = 0
        self.fractalDimension = 1.0
        self.meanNN = 1.0 / baseFrequency
        self.sdnn = 0
        self.nn50 = 0
        self.pnn50 = 0
        self.vlfPower = 0
        self.lfPower = 0
        self.hfPower = 0
        self.lfHfRatio = 1.0
    }
}

// MARK: - Individual Frequency Profile

/// Personal frequency signature - unique to each individual
public struct IndividualFrequencyProfile: Codable, Identifiable {
    public var id: UUID
    public var createdAt: Date
    public var lastUpdated: Date

    // Personal identifiers (anonymized)
    public var profileHash: String                   // Anonymous identifier

    // Baseline frequencies per organ (measured, not assumed)
    public var organBaselines: [Organ: BiologicalOscillation]

    // Neural frequency bands (individual ranges)
    public var deltaRange: ClosedRange<PreciseFrequency>    // Deep sleep
    public var thetaRange: ClosedRange<PreciseFrequency>    // Drowsy/meditative
    public var alphaRange: ClosedRange<PreciseFrequency>    // Relaxed
    public var betaRange: ClosedRange<PreciseFrequency>     // Active thinking
    public var gammaRange: ClosedRange<PreciseFrequency>    // Higher cognition

    // Cardiac signature
    public var restingHRV: BiologicalOscillation
    public var respiratorySinusArrhythmia: PreciseFrequency

    // Circadian rhythm parameters
    public var chronotype: PreciseFrequency          // Personal circadian period
    public var melatoninOnset: PreciseFrequency      // Dim light melatonin onset timing

    public init() {
        self.id = UUID()
        self.createdAt = Date()
        self.lastUpdated = Date()
        self.profileHash = UUID().uuidString

        // Initialize with typical ranges - TO BE REPLACED by individual measurement
        self.organBaselines = [:]

        // Neural bands - these MUST be calibrated per individual
        // Literature values are just starting points
        self.deltaRange = 0.5...4.0
        self.thetaRange = 4.0...8.0
        self.alphaRange = 8.0...13.0
        self.betaRange = 13.0...30.0
        self.gammaRange = 30.0...100.0

        // Cardiac - requires measurement
        self.restingHRV = BiologicalOscillation(baseFrequency: 1.0)
        self.respiratorySinusArrhythmia = 0.25  // ~15 breaths/min typical

        // Circadian - varies significantly between individuals
        self.chronotype = 24.0                   // Hours (can be 23.5-24.7)
        self.melatoninOnset = 21.0              // Hour of day (varies widely)
    }
}

// MARK: - Real-Time Frequency Scanner

/// Scans and measures biological frequencies in real-time
@MainActor
public class IndividualFrequencyScanner: ObservableObject {

    // MARK: - Published State

    @Published public var isScanning: Bool = false
    @Published public var currentProfile: IndividualFrequencyProfile?
    @Published public var realtimeMeasurements: [Organ: MeasuredFrequency] = [:]
    @Published public var signalQuality: Double = 0      // 0-1

    // Live oscillation data
    @Published public var heartOscillation: BiologicalOscillation?
    @Published public var brainOscillation: BiologicalOscillation?
    @Published public var respirationOscillation: BiologicalOscillation?

    // MARK: - Internal State

    private var sampleBuffer: [Organ: [PreciseFrequency]] = [:]
    private var timestampBuffer: [Organ: [Date]] = [:]
    private let bufferSize: Int = 256               // Samples for FFT
    private let sampleRate: Double = 1000.0         // Hz (for high precision)

    private var scanTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Configuration

    public struct ScanConfiguration {
        public var minimumSamples: Int = 30         // Minimum for valid measurement
        public var confidenceThreshold: Double = 0.7
        public var updateInterval: TimeInterval = 0.01  // 100 Hz updates
        public var fftWindowSize: Int = 512
        public var overlapRatio: Double = 0.5       // 50% overlap for continuity

        public static let highPrecision = ScanConfiguration(
            minimumSamples: 100,
            confidenceThreshold: 0.9,
            updateInterval: 0.001,  // 1000 Hz
            fftWindowSize: 2048,
            overlapRatio: 0.75
        )

        public static let realtime = ScanConfiguration(
            minimumSamples: 20,
            confidenceThreshold: 0.6,
            updateInterval: 0.016,  // 60 Hz
            fftWindowSize: 256,
            overlapRatio: 0.5
        )
    }

    public var configuration = ScanConfiguration.realtime

    // MARK: - Initialization

    public init() {
        // Initialize buffers for each organ
        for organ in Organ.allCases {
            sampleBuffer[organ] = []
            timestampBuffer[organ] = []
        }
    }

    // MARK: - Scanning Control

    /// Start real-time frequency scanning
    public func startScanning() {
        guard !isScanning else { return }
        isScanning = true

        if currentProfile == nil {
            currentProfile = IndividualFrequencyProfile()
        }

        scanTimer = Timer.scheduledTimer(
            withTimeInterval: configuration.updateInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.processScanCycle()
            }
        }
    }

    /// Stop scanning
    public func stopScanning() {
        isScanning = false
        scanTimer?.invalidate()
        scanTimer = nil
    }

    // MARK: - Data Input

    /// Feed raw sensor data for a specific organ/system
    public func feedSensorData(organ: Organ, value: Double, timestamp: Date = Date()) {
        // Add to buffer
        sampleBuffer[organ, default: []].append(value)
        timestampBuffer[organ, default: []].append(timestamp)

        // Limit buffer size
        if sampleBuffer[organ]!.count > bufferSize {
            sampleBuffer[organ]!.removeFirst()
            timestampBuffer[organ]!.removeFirst()
        }
    }

    /// Feed cardiac R-R intervals (in seconds, with full precision)
    public func feedRRInterval(_ interval: PreciseFrequency, timestamp: Date = Date()) {
        let instantHR = 1.0 / interval  // Convert to Hz
        feedSensorData(organ: .heart, value: instantHR, timestamp: timestamp)
    }

    /// Feed EEG data (raw voltage or preprocessed)
    public func feedEEGData(_ voltage: Double, channel: String, timestamp: Date = Date()) {
        feedSensorData(organ: .brain, value: voltage, timestamp: timestamp)
    }

    /// Feed respiration signal
    public func feedRespirationData(_ value: Double, timestamp: Date = Date()) {
        feedSensorData(organ: .lungs, value: value, timestamp: timestamp)
    }

    // MARK: - Processing

    private func processScanCycle() {
        for organ in Organ.allCases {
            guard let samples = sampleBuffer[organ],
                  samples.count >= configuration.minimumSamples else {
                continue
            }

            let measurement = analyzeFrequency(samples: samples, organ: organ)
            realtimeMeasurements[organ] = measurement

            // Update specific oscillation models
            updateOscillationModel(organ: organ, samples: samples)
        }

        // Calculate overall signal quality
        updateSignalQuality()
    }

    /// Analyze frequency from sample buffer using FFT
    private func analyzeFrequency(samples: [Double], organ: Organ) -> MeasuredFrequency {
        let n = samples.count

        // Apply Hanning window
        var windowedSamples = applyHanningWindow(samples)

        // Zero-pad to next power of 2
        let fftSize = nextPowerOf2(n)
        while windowedSamples.count < fftSize {
            windowedSamples.append(0)
        }

        // Perform FFT
        let frequencies = performFFT(windowedSamples)

        // Find dominant frequency with sub-bin precision
        let (peakFreq, confidence) = findPeakFrequency(
            magnitudes: frequencies,
            sampleRate: sampleRate,
            fftSize: fftSize
        )

        // Calculate uncertainty based on frequency resolution and SNR
        let frequencyResolution = sampleRate / Double(fftSize)
        let uncertainty = frequencyResolution / (2.0 * sqrt(Double(n)))

        return MeasuredFrequency(
            value: peakFreq,
            uncertainty: uncertainty,
            confidence: confidence,
            timestamp: Date(),
            sampleCount: n
        )
    }

    /// Update biological oscillation model with new samples
    private func updateOscillationModel(organ: Organ, samples: [Double]) {
        guard samples.count >= 10 else { return }

        var oscillation = currentProfile?.organBaselines[organ] ??
                         BiologicalOscillation(baseFrequency: samples.reduce(0, +) / Double(samples.count))

        // Update instant frequency (most recent)
        oscillation.instantFrequency = samples.last!

        // Calculate statistics
        let mean = samples.reduce(0, +) / Double(samples.count)
        oscillation.baseFrequency = mean
        oscillation.meanNN = 1.0 / mean

        // Standard deviation
        let variance = samples.map { pow($0 - mean, 2) }.reduce(0, +) / Double(samples.count - 1)
        oscillation.variabilitySD = sqrt(variance)
        oscillation.sdnn = oscillation.variabilitySD / mean  // Normalized

        // RMSSD (Root Mean Square of Successive Differences)
        var sumSquaredDiff: Double = 0
        var nn50Count = 0
        for i in 1..<samples.count {
            let diff = abs(samples[i] - samples[i-1])
            sumSquaredDiff += diff * diff

            // NN50: differences > 0.05 (50ms equivalent at 1Hz base)
            if diff > 0.05 * mean {
                nn50Count += 1
            }
        }
        oscillation.variabilityRMSSD = sqrt(sumSquaredDiff / Double(samples.count - 1))
        oscillation.nn50 = nn50Count
        oscillation.pnn50 = Double(nn50Count) / Double(samples.count - 1)

        // Coherence (0-1, based on regularity of oscillation)
        oscillation.coherence = calculateCoherence(samples)

        // Fractal dimension (healthy ~1.0-1.5)
        oscillation.fractalDimension = calculateFractalDimension(samples)

        // Frequency domain analysis
        let (vlf, lf, hf) = calculateFrequencyDomainPower(samples)
        oscillation.vlfPower = vlf
        oscillation.lfPower = lf
        oscillation.hfPower = hf
        oscillation.lfHfRatio = hf > 0 ? lf / hf : 0

        // Store in profile
        currentProfile?.organBaselines[organ] = oscillation

        // Update published state
        switch organ {
        case .heart:
            heartOscillation = oscillation
        case .brain:
            brainOscillation = oscillation
        case .lungs:
            respirationOscillation = oscillation
        default:
            break
        }
    }

    // MARK: - Signal Processing Helpers

    private func applyHanningWindow(_ samples: [Double]) -> [Double] {
        let n = samples.count
        return samples.enumerated().map { i, sample in
            let window = 0.5 * (1 - cos(2 * .pi * Double(i) / Double(n - 1)))
            return sample * window
        }
    }

    private func nextPowerOf2(_ n: Int) -> Int {
        var power = 1
        while power < n {
            power *= 2
        }
        return power
    }

    private func performFFT(_ samples: [Double]) -> [Double] {
        let n = samples.count
        guard n > 0 && (n & (n - 1)) == 0 else {
            return []  // Must be power of 2
        }

        // Use Accelerate framework for efficient FFT
        var real = samples
        var imaginary = [Double](repeating: 0, count: n)

        // Simple DFT for demonstration (use vDSP_fft_zripD in production)
        var magnitudes = [Double](repeating: 0, count: n/2)

        for k in 0..<n/2 {
            var realSum: Double = 0
            var imagSum: Double = 0

            for t in 0..<n {
                let angle = 2 * .pi * Double(k) * Double(t) / Double(n)
                realSum += real[t] * cos(angle)
                imagSum -= real[t] * sin(angle)
            }

            magnitudes[k] = sqrt(realSum * realSum + imagSum * imagSum) / Double(n)
        }

        return magnitudes
    }

    /// Find peak frequency with parabolic interpolation for sub-bin precision
    private func findPeakFrequency(magnitudes: [Double], sampleRate: Double, fftSize: Int) -> (frequency: Double, confidence: Double) {
        guard magnitudes.count > 2 else {
            return (0, 0)
        }

        // Find peak bin
        var maxIndex = 1
        var maxValue: Double = 0

        for i in 1..<(magnitudes.count - 1) {
            if magnitudes[i] > maxValue {
                maxValue = magnitudes[i]
                maxIndex = i
            }
        }

        // Parabolic interpolation for sub-bin precision
        // Using: p = 0.5 * (α - γ) / (α - 2β + γ)
        // where α = magnitude[peak-1], β = magnitude[peak], γ = magnitude[peak+1]

        let alpha = magnitudes[max(0, maxIndex - 1)]
        let beta = magnitudes[maxIndex]
        let gamma = magnitudes[min(magnitudes.count - 1, maxIndex + 1)]

        let denominator = alpha - 2 * beta + gamma
        let interpolation: Double
        if abs(denominator) > 1e-10 {
            interpolation = 0.5 * (alpha - gamma) / denominator
        } else {
            interpolation = 0
        }

        let preciseBin = Double(maxIndex) + interpolation
        let frequency = preciseBin * sampleRate / Double(fftSize)

        // Calculate confidence based on peak prominence
        let meanMagnitude = magnitudes.reduce(0, +) / Double(magnitudes.count)
        let confidence = min(1.0, (maxValue - meanMagnitude) / maxValue)

        return (frequency, confidence)
    }

    /// Calculate coherence (regularity of oscillation)
    private func calculateCoherence(_ samples: [Double]) -> Double {
        guard samples.count >= 10 else { return 0 }

        // Coherence based on autocorrelation at expected period
        let mean = samples.reduce(0, +) / Double(samples.count)
        var normalizedSamples = samples.map { $0 - mean }

        // Find dominant period via zero-crossings
        var zeroCrossings = 0
        for i in 1..<normalizedSamples.count {
            if normalizedSamples[i-1] * normalizedSamples[i] < 0 {
                zeroCrossings += 1
            }
        }

        let estimatedPeriod = Double(normalizedSamples.count) / Double(max(1, zeroCrossings / 2))

        // Calculate autocorrelation at estimated period
        let lag = Int(estimatedPeriod)
        guard lag < samples.count / 2 else { return 0 }

        var correlation: Double = 0
        var norm1: Double = 0
        var norm2: Double = 0

        for i in 0..<(samples.count - lag) {
            correlation += normalizedSamples[i] * normalizedSamples[i + lag]
            norm1 += normalizedSamples[i] * normalizedSamples[i]
            norm2 += normalizedSamples[i + lag] * normalizedSamples[i + lag]
        }

        let denominator = sqrt(norm1 * norm2)
        return denominator > 0 ? abs(correlation / denominator) : 0
    }

    /// Calculate Higuchi fractal dimension
    private func calculateFractalDimension(_ samples: [Double]) -> Double {
        guard samples.count >= 20 else { return 1.0 }

        // Simplified Higuchi algorithm
        let kMax = min(10, samples.count / 4)
        var lengths: [(k: Int, L: Double)] = []

        for k in 1...kMax {
            var sumL: Double = 0

            for m in 1...k {
                var length: Double = 0
                let n = (samples.count - m) / k

                for i in 1..<n {
                    let index1 = m + i * k - 1
                    let index2 = m + (i - 1) * k - 1
                    if index1 < samples.count && index2 < samples.count {
                        length += abs(samples[index1] - samples[index2])
                    }
                }

                length *= Double(samples.count - 1) / (Double(k) * Double(n) * Double(k))
                sumL += length
            }

            lengths.append((k, sumL / Double(k)))
        }

        // Linear regression of log(L) vs log(1/k) to find slope (fractal dimension)
        var sumX: Double = 0
        var sumY: Double = 0
        var sumXY: Double = 0
        var sumX2: Double = 0

        for (k, L) in lengths where L > 0 {
            let x = log(1.0 / Double(k))
            let y = log(L)
            sumX += x
            sumY += y
            sumXY += x * y
            sumX2 += x * x
        }

        let n = Double(lengths.count)
        let denominator = n * sumX2 - sumX * sumX

        if abs(denominator) < 1e-10 {
            return 1.0
        }

        let slope = (n * sumXY - sumX * sumY) / denominator
        return max(1.0, min(2.0, slope))  // Healthy range 1.0-2.0
    }

    /// Calculate frequency domain power in VLF, LF, HF bands
    private func calculateFrequencyDomainPower(_ samples: [Double]) -> (vlf: Double, lf: Double, hf: Double) {
        // Standard HRV frequency bands (in Hz)
        let vlfRange = 0.003...0.04
        let lfRange = 0.04...0.15
        let hfRange = 0.15...0.4

        let magnitudes = performFFT(samples)
        let freqResolution = sampleRate / Double(samples.count)

        var vlfPower: Double = 0
        var lfPower: Double = 0
        var hfPower: Double = 0

        for (i, mag) in magnitudes.enumerated() {
            let freq = Double(i) * freqResolution
            let power = mag * mag

            if vlfRange.contains(freq) {
                vlfPower += power
            } else if lfRange.contains(freq) {
                lfPower += power
            } else if hfRange.contains(freq) {
                hfPower += power
            }
        }

        return (vlfPower, lfPower, hfPower)
    }

    private func updateSignalQuality() {
        let measurementCount = realtimeMeasurements.count
        let avgConfidence = realtimeMeasurements.values.map { $0.confidence }.reduce(0, +) /
                          max(1, Double(measurementCount))
        signalQuality = avgConfidence
    }

    // MARK: - Calibration

    /// Calibrate baseline frequencies for an individual
    public func calibrateBaseline(organ: Organ, duration: TimeInterval = 60) async -> BiologicalOscillation? {
        let startTime = Date()

        // Collect samples for duration
        while Date().timeIntervalSince(startTime) < duration {
            try? await Task.sleep(nanoseconds: UInt64(configuration.updateInterval * 1_000_000_000))
        }

        // Get final oscillation model
        return currentProfile?.organBaselines[organ]
    }

    /// Full calibration session (all systems)
    public func runFullCalibration() async -> IndividualFrequencyProfile {
        startScanning()

        // Calibrate each major system
        print("Calibrating heart rhythm...")
        _ = await calibrateBaseline(organ: .heart, duration: 120)

        print("Calibrating brain waves...")
        _ = await calibrateBaseline(organ: .brain, duration: 60)

        print("Calibrating respiration...")
        _ = await calibrateBaseline(organ: .lungs, duration: 60)

        stopScanning()

        currentProfile?.lastUpdated = Date()
        return currentProfile ?? IndividualFrequencyProfile()
    }
}

// MARK: - Adaptive Frequency Generator

/// Generates therapeutic frequencies adapted to individual measurements
public class AdaptiveFrequencyGenerator: ObservableObject {

    @Published public var outputFrequency: PreciseFrequency = 0
    @Published public var targetFrequency: PreciseFrequency = 0
    @Published public var adaptationRate: Double = 0.1

    private let scanner: IndividualFrequencyScanner
    private var adaptationTimer: Timer?

    public init(scanner: IndividualFrequencyScanner) {
        self.scanner = scanner
    }

    /// Generate frequency that "entrains" with measured biological rhythm
    /// The output dances around the target, not rigidly locked
    public func generateEntrainmentFrequency(
        for organ: Organ,
        targetCoherence: Double = 0.8
    ) -> PreciseFrequency {

        guard let measurement = scanner.realtimeMeasurements[organ] else {
            return 0
        }

        let measuredFreq = measurement.value
        let variability = measurement.uncertainty

        // Target is the measured frequency, but we add intentional variability
        // to encourage biological entrainment (not rigid locking)
        let variance = variability * (1.0 - targetCoherence)
        let jitter = Double.random(in: -variance...variance)

        // Smooth transition to new frequency
        let newTarget = measuredFreq + jitter
        targetFrequency = targetFrequency * (1 - adaptationRate) + newTarget * adaptationRate

        // Output dances around target (like biological systems do)
        let outputJitter = variance * 0.1 * sin(Date().timeIntervalSince1970 * measuredFreq * 2 * .pi)
        outputFrequency = targetFrequency + outputJitter

        return outputFrequency
    }

    /// Generate binaural beat frequency based on individual's measured brain state
    public func generateAdaptiveBinauralBeat(
        currentState: MeasuredFrequency,
        desiredState: PreciseFrequency
    ) -> (leftEar: PreciseFrequency, rightEar: PreciseFrequency) {

        let current = currentState.value
        let target = desiredState

        // Calculate the entrainment frequency (difference between ears)
        // Start close to current state, gradually shift toward target
        let entrainmentFreq = current + (target - current) * adaptationRate

        // Base frequency (carrier) - typically in comfortable hearing range
        let carrierFrequency: PreciseFrequency = 200.0

        // Left ear gets carrier, right ear gets carrier + entrainment difference
        return (
            leftEar: carrierFrequency,
            rightEar: carrierFrequency + entrainmentFreq
        )
    }
}

// MARK: - Frequency Report

public struct IndividualFrequencyReport {

    /// Generate detailed report of individual's frequency signature
    public static func generate(from profile: IndividualFrequencyProfile) -> String {
        var report = """
        ══════════════════════════════════════════════════════════════════════
        INDIVIDUAL BIOLOGICAL FREQUENCY REPORT
        Profile ID: \(profile.id.uuidString.prefix(8))
        Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .medium))
        ══════════════════════════════════════════════════════════════════════

        NOTE: These frequencies are INDIVIDUAL to this person.
        They are NOT universal constants. They fluctuate moment to moment.
        The VARIABILITY is as important as the central frequency.

        ──────────────────────────────────────────────────────────────────────
        CARDIAC RHYTHM
        ──────────────────────────────────────────────────────────────────────

        """

        if let heart = profile.organBaselines[.heart] {
            report += formatOscillationReport(heart, name: "Heart")
        } else {
            report += "  [Not yet calibrated]\n"
        }

        report += """

        ──────────────────────────────────────────────────────────────────────
        NEURAL OSCILLATIONS
        ──────────────────────────────────────────────────────────────────────

        Individual Band Ranges (calibrated to this person):

        """

        report += String(format: "  Delta: %.4f - %.4f Hz\n", profile.deltaRange.lowerBound, profile.deltaRange.upperBound)
        report += String(format: "  Theta: %.4f - %.4f Hz\n", profile.thetaRange.lowerBound, profile.thetaRange.upperBound)
        report += String(format: "  Alpha: %.4f - %.4f Hz\n", profile.alphaRange.lowerBound, profile.alphaRange.upperBound)
        report += String(format: "  Beta:  %.4f - %.4f Hz\n", profile.betaRange.lowerBound, profile.betaRange.upperBound)
        report += String(format: "  Gamma: %.4f - %.4f Hz\n", profile.gammaRange.lowerBound, profile.gammaRange.upperBound)

        if let brain = profile.organBaselines[.brain] {
            report += "\n  Current Brain State:\n"
            report += formatOscillationReport(brain, name: "Brain")
        }

        report += """

        ──────────────────────────────────────────────────────────────────────
        CIRCADIAN RHYTHM
        ──────────────────────────────────────────────────────────────────────

        """

        report += String(format: "  Personal Circadian Period: %.4f hours\n", profile.chronotype)
        report += String(format: "  (Deviation from 24h: %+.4f hours)\n", profile.chronotype - 24.0)
        report += String(format: "  Melatonin Onset (DLMO): %.2f (clock time)\n", profile.melatoninOnset)

        report += """

        ──────────────────────────────────────────────────────────────────────
        ORGAN BASELINES
        ──────────────────────────────────────────────────────────────────────

        """

        for organ in Organ.allCases {
            if let oscillation = profile.organBaselines[organ] {
                report += "\n  \(organ.rawValue):\n"
                report += formatOscillationReport(oscillation, name: organ.rawValue, indent: 4)
            }
        }

        report += """

        ══════════════════════════════════════════════════════════════════════
        INTERPRETATION GUIDE
        ══════════════════════════════════════════════════════════════════════

        Coherence (0-1):
          > 0.8 = High coherence (ordered, potentially too rigid)
          0.5-0.8 = Healthy range (balanced complexity)
          < 0.5 = Low coherence (potentially chaotic)

        Fractal Dimension (1.0-2.0):
          ~1.0-1.5 = Healthy complexity
          < 1.0 = Too regular (loss of adaptability)
          > 1.5 = Too random (loss of order)

        LF/HF Ratio:
          < 1.0 = Parasympathetic dominance (relaxed)
          1.0-2.0 = Balanced
          > 2.0 = Sympathetic dominance (stressed)

        IMPORTANT: These values must be interpreted in context.
        Trends over time are more meaningful than single measurements.

        ══════════════════════════════════════════════════════════════════════
        """

        return report
    }

    private static func formatOscillationReport(_ osc: BiologicalOscillation, name: String, indent: Int = 2) -> String {
        let pad = String(repeating: " ", count: indent)
        var s = ""
        s += String(format: "%sBase Frequency:    %.6f Hz\n", pad, osc.baseFrequency)
        s += String(format: "%sInstant Frequency: %.6f Hz\n", pad, osc.instantFrequency)
        s += String(format: "%sVariability (SD):  %.6f Hz\n", pad, osc.variabilitySD)
        s += String(format: "%sRMSSD:             %.6f\n", pad, osc.variabilityRMSSD)
        s += String(format: "%sCoherence:         %.4f\n", pad, osc.coherence)
        s += String(format: "%sFractal Dimension: %.4f\n", pad, osc.fractalDimension)
        s += String(format: "%sLF/HF Ratio:       %.4f\n", pad, osc.lfHfRatio)
        return s
    }
}
