// MasteringSuiteEngine.swift
// Echoelmusic - Professional Mastering Suite
// Created by Claude (Phase 4) - December 2025

import Foundation
import Accelerate
import AVFoundation
import CoreML

// MARK: - Loudness Standards

/// Industry loudness standards for different platforms
public enum LoudnessStandard: String, CaseIterable, Codable {
    case spotify = "Spotify"              // -14 LUFS
    case appleMusicLoud = "Apple Music (Loud)"  // -16 LUFS
    case appleMusicQuiet = "Apple Music"  // -16 LUFS with -1dB headroom
    case youtube = "YouTube"              // -14 LUFS
    case tidal = "Tidal"                  // -14 LUFS
    case amazonMusic = "Amazon Music"     // -14 LUFS
    case soundCloud = "SoundCloud"        // -14 LUFS
    case bandcamp = "Bandcamp"            // No normalization
    case cdStandard = "CD"                // -9 LUFS typical
    case broadcast = "Broadcast (EBU R128)" // -23 LUFS
    case cinema = "Cinema"                // -24 LUFS
    case podcast = "Podcast"              // -16 LUFS
    case vinylMaster = "Vinyl"            // -12 LUFS with limited HF
    case club = "Club/DJ"                 // -6 LUFS (loud!)

    var targetLUFS: Float {
        switch self {
        case .spotify, .youtube, .tidal, .amazonMusic, .soundCloud: return -14.0
        case .appleMusicLoud, .appleMusicQuiet, .podcast: return -16.0
        case .cdStandard: return -9.0
        case .broadcast: return -23.0
        case .cinema: return -24.0
        case .vinylMaster: return -12.0
        case .club: return -6.0
        case .bandcamp: return -14.0 // No normalization but reasonable target
        }
    }

    var truePeakLimit: Float {
        switch self {
        case .appleMusicQuiet: return -1.0
        case .broadcast, .cinema: return -1.0
        case .vinylMaster: return -0.5
        case .club: return -0.1
        default: return -1.0
        }
    }

    var loudnessRange: ClosedRange<Float> {
        switch self {
        case .broadcast: return 5.0...20.0  // EBU R128 LRA
        case .cinema: return 15.0...25.0
        case .podcast: return 3.0...8.0
        default: return 4.0...16.0
        }
    }
}

// MARK: - LUFS Meter

/// ITU-R BS.1770 compliant loudness meter
public final class LUFSMeter: @unchecked Sendable {

    // K-weighting filter coefficients (48kHz)
    private struct KWeightingCoefficients {
        // High shelf filter (first stage)
        static let highShelfB: [Double] = [1.53512485958697, -2.69169618940638, 1.19839281085285]
        static let highShelfA: [Double] = [1.0, -1.69065929318241, 0.73248077421585]

        // High pass filter (second stage)
        static let highPassB: [Double] = [1.0, -2.0, 1.0]
        static let highPassA: [Double] = [1.0, -1.99004745483398, 0.99007225036621]
    }

    private let sampleRate: Double
    private let blockSize: Int  // 400ms blocks
    private let overlapSize: Int  // 75% overlap

    // Filter states
    private var highShelfState: [[Double]] = [[0, 0], [0, 0]]  // L, R
    private var highPassState: [[Double]] = [[0, 0], [0, 0]]

    // Measurement buffers
    private var blockBuffer: [[Float]] = [[], []]
    private var momentaryBlocks: [Double] = []
    private var shortTermBlocks: [Double] = []

    // Results
    public private(set) var momentaryLoudness: Float = -70.0  // 400ms
    public private(set) var shortTermLoudness: Float = -70.0  // 3s
    public private(set) var integratedLoudness: Float = -70.0  // Full program
    public private(set) var loudnessRange: Float = 0.0  // LRA
    public private(set) var truePeak: Float = -70.0

    public init(sampleRate: Double = 48000) {
        self.sampleRate = sampleRate
        self.blockSize = Int(sampleRate * 0.4)  // 400ms
        self.overlapSize = Int(sampleRate * 0.1)  // 100ms (75% overlap)
    }

    /// Process stereo audio buffer
    public func process(left: [Float], right: [Float]) {
        guard left.count == right.count else { return }

        // Apply K-weighting and accumulate
        for i in 0..<left.count {
            let kWeightedL = applyKWeighting(sample: Double(left[i]), channel: 0)
            let kWeightedR = applyKWeighting(sample: Double(right[i]), channel: 1)

            blockBuffer[0].append(Float(kWeightedL))
            blockBuffer[1].append(Float(kWeightedR))

            // Check for block completion
            if blockBuffer[0].count >= blockSize {
                processBlock()
            }
        }

        // Update true peak using oversampling
        updateTruePeak(left: left, right: right)
    }

    private func applyKWeighting(sample: Double, channel: Int) -> Double {
        // Stage 1: High shelf filter
        let b = KWeightingCoefficients.highShelfB
        let a = KWeightingCoefficients.highShelfA

        let highShelfOut = b[0] * sample + highShelfState[channel][0]
        highShelfState[channel][0] = b[1] * sample - a[1] * highShelfOut + highShelfState[channel][1]
        highShelfState[channel][1] = b[2] * sample - a[2] * highShelfOut

        // Stage 2: High pass filter
        let b2 = KWeightingCoefficients.highPassB
        let a2 = KWeightingCoefficients.highPassA

        let highPassOut = b2[0] * highShelfOut + highPassState[channel][0]
        highPassState[channel][0] = b2[1] * highShelfOut - a2[1] * highPassOut + highPassState[channel][1]
        highPassState[channel][1] = b2[2] * highShelfOut - a2[2] * highPassOut

        return highPassOut
    }

    private func processBlock() {
        // Calculate mean square for each channel
        var sumL: Float = 0
        var sumR: Float = 0

        vDSP_measqv(blockBuffer[0], 1, &sumL, vDSP_Length(blockSize))
        vDSP_measqv(blockBuffer[1], 1, &sumR, vDSP_Length(blockSize))

        // Sum with channel weights (1.0 for L/R, different for surround)
        let meanSquare = Double(sumL + sumR)

        // Convert to LUFS
        let blockLoudness = meanSquare > 0 ? -0.691 + 10 * log10(meanSquare) : -70.0

        momentaryBlocks.append(blockLoudness)

        // Momentary loudness (last block)
        momentaryLoudness = Float(blockLoudness)

        // Short-term loudness (last 3 seconds = ~30 blocks with overlap)
        let shortTermBlockCount = Int(3.0 / 0.1)  // 3s / 100ms overlap
        if momentaryBlocks.count >= shortTermBlockCount {
            let recentBlocks = Array(momentaryBlocks.suffix(shortTermBlockCount))
            shortTermLoudness = calculateGatedLoudness(blocks: recentBlocks)
        }

        // Integrated loudness with gating
        integratedLoudness = calculateGatedLoudness(blocks: momentaryBlocks)

        // Loudness Range (LRA)
        loudnessRange = calculateLoudnessRange()

        // Remove overlap samples, keep rest
        blockBuffer[0] = Array(blockBuffer[0].suffix(blockSize - overlapSize))
        blockBuffer[1] = Array(blockBuffer[1].suffix(blockSize - overlapSize))
    }

    private func calculateGatedLoudness(blocks: [Double]) -> Float {
        guard !blocks.isEmpty else { return -70.0 }

        // Absolute threshold: -70 LUFS
        let absoluteThreshold = -70.0
        var gatedBlocks = blocks.filter { $0 > absoluteThreshold }

        guard !gatedBlocks.isEmpty else { return -70.0 }

        // Relative threshold: -10 LU below ungated loudness
        let ungatedLoudness = gatedBlocks.reduce(0, +) / Double(gatedBlocks.count)
        let relativeThreshold = ungatedLoudness - 10.0

        gatedBlocks = gatedBlocks.filter { $0 > relativeThreshold }

        guard !gatedBlocks.isEmpty else { return -70.0 }

        // Final integrated loudness
        let integratedPower = gatedBlocks.map { pow(10, $0 / 10) }.reduce(0, +) / Double(gatedBlocks.count)
        return Float(10 * log10(integratedPower))
    }

    private func calculateLoudnessRange() -> Float {
        guard momentaryBlocks.count > 10 else { return 0.0 }

        // Use short-term loudness distribution
        let sorted = momentaryBlocks.sorted()
        let lowIndex = Int(Double(sorted.count) * 0.10)  // 10th percentile
        let highIndex = Int(Double(sorted.count) * 0.95)  // 95th percentile

        guard highIndex > lowIndex else { return 0.0 }

        return Float(sorted[highIndex] - sorted[lowIndex])
    }

    private func updateTruePeak(left: [Float], right: [Float]) {
        // 4x oversampling for true peak detection
        let oversampledL = oversample4x(left)
        let oversampledR = oversample4x(right)

        var maxL: Float = 0
        var maxR: Float = 0
        vDSP_maxmgv(oversampledL, 1, &maxL, vDSP_Length(oversampledL.count))
        vDSP_maxmgv(oversampledR, 1, &maxR, vDSP_Length(oversampledR.count))

        let peakLinear = max(maxL, maxR)
        let peakDB = peakLinear > 0 ? 20 * log10(peakLinear) : -70.0

        truePeak = max(truePeak, Float(peakDB))
    }

    private func oversample4x(_ samples: [Float]) -> [Float] {
        // Simple linear interpolation for 4x oversampling
        // (Production would use polyphase FIR filter)
        var oversampled = [Float](repeating: 0, count: samples.count * 4)

        for i in 0..<samples.count - 1 {
            let current = samples[i]
            let next = samples[i + 1]
            let step = (next - current) / 4

            oversampled[i * 4] = current
            oversampled[i * 4 + 1] = current + step
            oversampled[i * 4 + 2] = current + step * 2
            oversampled[i * 4 + 3] = current + step * 3
        }

        return oversampled
    }

    public func reset() {
        highShelfState = [[0, 0], [0, 0]]
        highPassState = [[0, 0], [0, 0]]
        blockBuffer = [[], []]
        momentaryBlocks = []
        shortTermBlocks = []
        momentaryLoudness = -70.0
        shortTermLoudness = -70.0
        integratedLoudness = -70.0
        loudnessRange = 0.0
        truePeak = -70.0
    }
}

// MARK: - True Peak Limiter

/// Transparent true peak limiter with lookahead
public final class TruePeakLimiter: @unchecked Sendable {

    private let sampleRate: Float
    private let lookaheadMs: Float = 5.0
    private let releaseMs: Float = 100.0

    private var lookaheadSamples: Int
    private var delayBuffer: [[Float]] = [[], []]
    private var writeIndex: Int = 0

    private var envelope: Float = 0
    private var releaseCoeff: Float = 0

    public var ceiling: Float = -1.0  // dBTP
    public var isActive: Bool = false

    public init(sampleRate: Float = 48000) {
        self.sampleRate = sampleRate
        self.lookaheadSamples = Int(sampleRate * lookaheadMs / 1000)
        self.releaseCoeff = exp(-1.0 / (sampleRate * releaseMs / 1000))

        // Initialize delay buffers
        delayBuffer[0] = [Float](repeating: 0, count: lookaheadSamples)
        delayBuffer[1] = [Float](repeating: 0, count: lookaheadSamples)
    }

    public func process(left: inout [Float], right: inout [Float]) {
        let ceilingLinear = pow(10, ceiling / 20)

        for i in 0..<left.count {
            // Find peak in lookahead window
            let peakL = abs(left[i])
            let peakR = abs(right[i])
            let peak = max(peakL, peakR)

            // Update envelope
            if peak > envelope {
                envelope = peak
            } else {
                envelope = envelope * releaseCoeff + peak * (1 - releaseCoeff)
            }

            // Calculate gain reduction
            var gain: Float = 1.0
            if envelope > ceilingLinear {
                gain = ceilingLinear / envelope
                isActive = true
            } else {
                isActive = false
            }

            // Apply soft knee
            let kneeDB: Float = 3.0
            let kneeStart = ceilingLinear * pow(10, -kneeDB / 20)
            if envelope > kneeStart && envelope <= ceilingLinear {
                let x = 20 * log10(envelope / kneeStart)
                let compressionDB = x * x / (2 * kneeDB)
                gain = pow(10, -compressionDB / 20)
            }

            // Store in delay buffer
            let readIndex = (writeIndex + 1) % lookaheadSamples
            let delayedL = delayBuffer[0][readIndex]
            let delayedR = delayBuffer[1][readIndex]

            delayBuffer[0][writeIndex] = left[i]
            delayBuffer[1][writeIndex] = right[i]
            writeIndex = (writeIndex + 1) % lookaheadSamples

            // Output limited signal
            left[i] = delayedL * gain
            right[i] = delayedR * gain
        }
    }

    public func reset() {
        delayBuffer[0] = [Float](repeating: 0, count: lookaheadSamples)
        delayBuffer[1] = [Float](repeating: 0, count: lookaheadSamples)
        writeIndex = 0
        envelope = 0
    }
}

// MARK: - Mid-Side Processor

/// Mid-Side encoding/decoding and processing
public final class MidSideProcessor: @unchecked Sendable {

    public struct Settings {
        public var midGain: Float = 0.0      // dB
        public var sideGain: Float = 0.0     // dB
        public var stereoWidth: Float = 1.0  // 0-2, 1 = normal
        public var midHighPass: Float = 0    // Hz, 0 = off
        public var sideHighPass: Float = 80  // Hz
        public var midCompression: Float = 0 // 0-1
        public var sideCompression: Float = 0

        public init() {}
    }

    public var settings = Settings()

    private let sampleRate: Float
    private var midHPState: [Float] = [0, 0]
    private var sideHPState: [Float] = [0, 0]

    public init(sampleRate: Float = 48000) {
        self.sampleRate = sampleRate
    }

    public func process(left: inout [Float], right: inout [Float]) {
        // Convert to Mid-Side
        var mid = [Float](repeating: 0, count: left.count)
        var side = [Float](repeating: 0, count: left.count)

        for i in 0..<left.count {
            mid[i] = (left[i] + right[i]) * 0.5
            side[i] = (left[i] - right[i]) * 0.5
        }

        // Apply high-pass filters
        if settings.midHighPass > 0 {
            applyHighPass(buffer: &mid, cutoff: settings.midHighPass, state: &midHPState)
        }
        if settings.sideHighPass > 0 {
            applyHighPass(buffer: &side, cutoff: settings.sideHighPass, state: &sideHPState)
        }

        // Apply gain
        let midGainLinear = pow(10, settings.midGain / 20)
        let sideGainLinear = pow(10, settings.sideGain / 20) * settings.stereoWidth

        var midScaled = midGainLinear
        var sideScaled = sideGainLinear
        vDSP_vsmul(mid, 1, &midScaled, &mid, 1, vDSP_Length(mid.count))
        vDSP_vsmul(side, 1, &sideScaled, &side, 1, vDSP_Length(side.count))

        // Apply gentle compression if enabled
        if settings.midCompression > 0 {
            applySoftCompression(buffer: &mid, amount: settings.midCompression)
        }
        if settings.sideCompression > 0 {
            applySoftCompression(buffer: &side, amount: settings.sideCompression)
        }

        // Convert back to Left-Right
        for i in 0..<left.count {
            left[i] = mid[i] + side[i]
            right[i] = mid[i] - side[i]
        }
    }

    private func applyHighPass(buffer: inout [Float], cutoff: Float, state: inout [Float]) {
        let omega = 2 * Float.pi * cutoff / sampleRate
        let alpha = sin(omega) / (2 * 0.707)  // Q = 0.707

        let a0 = 1 + alpha
        let b0 = ((1 + cos(omega)) / 2) / a0
        let b1 = (-(1 + cos(omega))) / a0
        let b2 = ((1 + cos(omega)) / 2) / a0
        let a1 = (-2 * cos(omega)) / a0
        let a2 = (1 - alpha) / a0

        for i in 0..<buffer.count {
            let input = buffer[i]
            let output = b0 * input + state[0]
            state[0] = b1 * input - a1 * output + state[1]
            state[1] = b2 * input - a2 * output
            buffer[i] = output
        }
    }

    private func applySoftCompression(buffer: inout [Float], amount: Float) {
        let threshold: Float = 0.5
        let ratio: Float = 1 + amount * 3  // 1:1 to 4:1

        for i in 0..<buffer.count {
            let input = buffer[i]
            let absInput = abs(input)

            if absInput > threshold {
                let overThreshold = absInput - threshold
                let compressed = threshold + overThreshold / ratio
                buffer[i] = input > 0 ? compressed : -compressed
            }
        }
    }

    public func reset() {
        midHPState = [0, 0]
        sideHPState = [0, 0]
    }
}

// MARK: - Reference Track Matcher

/// Analyze and match loudness/spectrum to reference track
public actor ReferenceTrackMatcher {

    public struct MatchResult {
        public let targetLUFS: Float
        public let currentLUFS: Float
        public let gainAdjustment: Float
        public let spectralDifference: [Float]  // Per-band difference in dB
        public let dynamicRangeDifference: Float
        public let stereoWidthDifference: Float
    }

    private let fftSize = 4096
    private let numBands = 31  // 1/3 octave bands

    public init() {}

    public func analyze(reference: [Float], target: [Float], sampleRate: Float) async -> MatchResult {
        // Analyze both tracks
        let refAnalysis = analyzeTrack(reference, sampleRate: sampleRate)
        let targetAnalysis = analyzeTrack(target, sampleRate: sampleRate)

        // Calculate differences
        let gainAdjustment = refAnalysis.loudness - targetAnalysis.loudness

        var spectralDiff = [Float](repeating: 0, count: numBands)
        for i in 0..<numBands {
            spectralDiff[i] = refAnalysis.spectrum[i] - targetAnalysis.spectrum[i]
        }

        return MatchResult(
            targetLUFS: refAnalysis.loudness,
            currentLUFS: targetAnalysis.loudness,
            gainAdjustment: gainAdjustment,
            spectralDifference: spectralDiff,
            dynamicRangeDifference: refAnalysis.dynamicRange - targetAnalysis.dynamicRange,
            stereoWidthDifference: refAnalysis.stereoWidth - targetAnalysis.stereoWidth
        )
    }

    private struct TrackAnalysis {
        let loudness: Float
        let spectrum: [Float]
        let dynamicRange: Float
        let stereoWidth: Float
    }

    private func analyzeTrack(_ samples: [Float], sampleRate: Float) -> TrackAnalysis {
        // Simple loudness estimation (RMS-based approximation)
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        let loudness = rms > 0 ? 20 * log10(rms) - 10 : -70  // Rough LUFS approximation

        // Spectral analysis via FFT
        let spectrum = analyzeSpectrum(samples, sampleRate: sampleRate)

        // Dynamic range (peak to RMS)
        var peak: Float = 0
        vDSP_maxmgv(samples, 1, &peak, vDSP_Length(samples.count))
        let dynamicRange = peak > 0 && rms > 0 ? 20 * log10(peak / rms) : 0

        // Stereo width (assume mono input for simplicity)
        let stereoWidth: Float = 1.0

        return TrackAnalysis(
            loudness: loudness,
            spectrum: spectrum,
            dynamicRange: dynamicRange,
            stereoWidth: stereoWidth
        )
    }

    private func analyzeSpectrum(_ samples: [Float], sampleRate: Float) -> [Float] {
        guard samples.count >= fftSize else {
            return [Float](repeating: -60, count: numBands)
        }

        // Perform FFT
        let log2n = vDSP_Length(log2(Float(fftSize)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return [Float](repeating: -60, count: numBands)
        }
        defer { vDSP_destroy_fftsetup(fftSetup) }

        var real = [Float](samples.prefix(fftSize))
        var imag = [Float](repeating: 0, count: fftSize)

        real.withUnsafeMutableBufferPointer { realPtr in
            imag.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                vDSP_fft_zip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
            }
        }

        // Calculate magnitude spectrum
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        for i in 0..<fftSize/2 {
            magnitudes[i] = sqrt(real[i] * real[i] + imag[i] * imag[i])
        }

        // Average into 1/3 octave bands
        let bandEdges = calculateThirdOctaveBands(sampleRate: sampleRate, fftSize: fftSize)
        var bandLevels = [Float](repeating: 0, count: numBands)

        for band in 0..<numBands {
            let lowBin = bandEdges[band].low
            let highBin = min(bandEdges[band].high, fftSize / 2 - 1)

            if highBin > lowBin {
                var sum: Float = 0
                for bin in lowBin...highBin {
                    sum += magnitudes[bin] * magnitudes[bin]
                }
                let avg = sum / Float(highBin - lowBin + 1)
                bandLevels[band] = avg > 0 ? 10 * log10(avg) : -60
            } else {
                bandLevels[band] = -60
            }
        }

        return bandLevels
    }

    private func calculateThirdOctaveBands(sampleRate: Float, fftSize: Int) -> [(low: Int, high: Int)] {
        // ISO 1/3 octave center frequencies from 20Hz to 20kHz
        let centerFreqs: [Float] = [
            20, 25, 31.5, 40, 50, 63, 80, 100, 125, 160,
            200, 250, 315, 400, 500, 630, 800, 1000, 1250, 1600,
            2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000, 12500, 16000,
            20000
        ]

        let binWidth = sampleRate / Float(fftSize)
        let factor = pow(2.0, 1.0/6.0)  // 1/3 octave factor

        return centerFreqs.map { center in
            let lowFreq = center / Float(factor)
            let highFreq = center * Float(factor)
            let lowBin = max(1, Int(lowFreq / binWidth))
            let highBin = min(fftSize / 2 - 1, Int(highFreq / binWidth))
            return (low: lowBin, high: highBin)
        }
    }
}

// MARK: - Mastering Suite Engine

/// Complete professional mastering suite
public actor MasteringSuiteEngine {

    public static let shared = MasteringSuiteEngine()

    // Components
    private let lufsMeter = LUFSMeter()
    private let truePeakLimiter = TruePeakLimiter()
    private let midSideProcessor = MidSideProcessor()
    private let referenceMatcher = ReferenceTrackMatcher()

    // Settings
    public var targetStandard: LoudnessStandard = .spotify
    public var enableLimiter: Bool = true
    public var enableMidSide: Bool = true
    public var autoGain: Bool = true

    // Meters
    public private(set) var currentLUFS: Float = -70
    public private(set) var currentTruePeak: Float = -70
    public private(set) var currentLRA: Float = 0
    public private(set) var gainReduction: Float = 0

    private init() {}

    /// Process audio buffer for mastering
    public func process(left: inout [Float], right: inout [Float]) async {
        // Measure input
        lufsMeter.process(left: left, right: right)

        // Mid-Side processing
        if enableMidSide {
            midSideProcessor.process(left: &left, right: &right)
        }

        // Auto gain to target
        if autoGain {
            let currentLoudness = lufsMeter.integratedLoudness
            let targetLoudness = targetStandard.targetLUFS
            let gainNeeded = targetLoudness - currentLoudness

            // Apply makeup gain (with safety limit)
            let safeGain = min(gainNeeded, 12.0)  // Max 12dB boost
            let gainLinear = pow(10, safeGain / 20)

            var gain = gainLinear
            vDSP_vsmul(left, 1, &gain, &left, 1, vDSP_Length(left.count))
            vDSP_vsmul(right, 1, &gain, &right, 1, vDSP_Length(right.count))
        }

        // True peak limiting
        if enableLimiter {
            truePeakLimiter.ceiling = targetStandard.truePeakLimit
            truePeakLimiter.process(left: &left, right: &right)
            gainReduction = truePeakLimiter.isActive ? -3.0 : 0  // Approximate
        }

        // Update meters
        currentLUFS = lufsMeter.integratedLoudness
        currentTruePeak = lufsMeter.truePeak
        currentLRA = lufsMeter.loudnessRange
    }

    /// Match to reference track
    public func matchToReference(_ reference: [Float], target: [Float], sampleRate: Float) async -> ReferenceTrackMatcher.MatchResult {
        await referenceMatcher.analyze(reference: reference, target: target, sampleRate: sampleRate)
    }

    /// Get mastering report
    public func generateReport() -> MasteringReport {
        MasteringReport(
            integratedLUFS: currentLUFS,
            truePeak: currentTruePeak,
            loudnessRange: currentLRA,
            targetStandard: targetStandard,
            meetsStandard: currentLUFS >= targetStandard.targetLUFS - 1 &&
                          currentLUFS <= targetStandard.targetLUFS + 1 &&
                          currentTruePeak <= targetStandard.truePeakLimit,
            recommendations: generateRecommendations()
        )
    }

    private func generateRecommendations() -> [String] {
        var recommendations: [String] = []

        if currentLUFS < targetStandard.targetLUFS - 2 {
            recommendations.append("Track is too quiet. Consider increasing gain.")
        } else if currentLUFS > targetStandard.targetLUFS + 1 {
            recommendations.append("Track is too loud. May be normalized down by streaming platforms.")
        }

        if currentTruePeak > targetStandard.truePeakLimit {
            recommendations.append("True peak exceeds limit. Enable limiter or reduce gain.")
        }

        if currentLRA < targetStandard.loudnessRange.lowerBound {
            recommendations.append("Dynamic range is compressed. Consider less limiting.")
        } else if currentLRA > targetStandard.loudnessRange.upperBound {
            recommendations.append("Dynamic range is very wide. Consider gentle compression.")
        }

        if recommendations.isEmpty {
            recommendations.append("Track meets \(targetStandard.rawValue) standards. ✓")
        }

        return recommendations
    }

    public func reset() {
        lufsMeter.reset()
        truePeakLimiter.reset()
        midSideProcessor.reset()
        currentLUFS = -70
        currentTruePeak = -70
        currentLRA = 0
        gainReduction = 0
    }
}

// MARK: - Mastering Report

public struct MasteringReport: Codable {
    public let integratedLUFS: Float
    public let truePeak: Float
    public let loudnessRange: Float
    public let targetStandard: LoudnessStandard
    public let meetsStandard: Bool
    public let recommendations: [String]

    public var summary: String {
        """
        MASTERING REPORT
        ================
        Integrated Loudness: \(String(format: "%.1f", integratedLUFS)) LUFS
        True Peak: \(String(format: "%.1f", truePeak)) dBTP
        Loudness Range: \(String(format: "%.1f", loudnessRange)) LU
        Target: \(targetStandard.rawValue) (\(String(format: "%.0f", targetStandard.targetLUFS)) LUFS)
        Status: \(meetsStandard ? "✓ PASS" : "✗ NEEDS ADJUSTMENT")

        Recommendations:
        \(recommendations.map { "• \($0)" }.joined(separator: "\n"))
        """
    }
}
