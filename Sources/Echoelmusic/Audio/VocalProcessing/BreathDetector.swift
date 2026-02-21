import Foundation
import Accelerate

/// Real-time breath detection and removal engine for vocal processing.
///
/// Detects breath sounds in vocal recordings using spectral analysis and energy
/// envelope tracking. Supports automatic removal, gain reduction, or marking.
///
/// Detection Algorithm:
/// 1. STFT analysis of input signal
/// 2. Spectral centroid & flatness measurement (breath = noise-like, high centroid)
/// 3. Energy envelope tracking (breath = low energy relative to singing)
/// 4. Zero-crossing rate (breath = high ZCR)
/// 5. Temporal smoothing to avoid false positives
public class BreathDetector {

    // MARK: - Configuration

    struct Configuration: Codable, Sendable {
        /// Detection sensitivity (0 = least sensitive, 1 = most sensitive)
        var sensitivity: Float = 0.5

        /// Minimum breath duration in seconds to detect
        var minimumDuration: Float = 0.1

        /// Maximum breath duration in seconds
        var maximumDuration: Float = 2.0

        /// Gain reduction applied to detected breaths (0 = silent, 1 = no change)
        var reductionGain: Float = 0.0

        /// Crossfade duration at breath boundaries in seconds
        var crossfadeDuration: Float = 0.01

        /// Processing mode
        var mode: DetectionMode = .remove

        static let `default` = Configuration()
        static let gentle = Configuration(sensitivity: 0.3, reductionGain: 0.3, crossfadeDuration: 0.02)
        static let aggressive = Configuration(sensitivity: 0.8, reductionGain: 0.0, crossfadeDuration: 0.005)
    }

    public enum DetectionMode: String, CaseIterable, Codable, Sendable {
        case detect      // Only detect and mark, no processing
        case reduce      // Reduce breath volume by reductionGain
        case remove      // Remove breaths entirely (reductionGain = 0)
        case replace     // Replace breaths with room tone
    }

    // MARK: - Detected Breath Region

    struct BreathRegion {
        let startSample: Int
        let endSample: Int
        let confidence: Float     // 0-1 how certain this is a breath
        let peakEnergy: Float

        var durationSamples: Int { endSample - startSample }

        func duration(atSampleRate sampleRate: Double) -> Double {
            Double(durationSamples) / sampleRate
        }
    }

    // MARK: - Properties

    var configuration: Configuration
    private let sampleRate: Double
    private let fftSize: Int
    private let hopSize: Int

    // Analysis buffers (pre-allocated)
    private var windowBuffer: [Float]
    private var fftRealBuffer: [Float]
    private var fftImagBuffer: [Float]
    private var magnitudeBuffer: [Float]

    // State tracking
    private var isInBreath: Bool = false
    private var breathStartSample: Int = 0
    private var consecutiveBreathFrames: Int = 0
    private var consecutiveNonBreathFrames: Int = 0
    private var detectedRegions: [BreathRegion] = []

    // Spectral analysis thresholds (adaptive)
    private var runningEnergyMean: Float = 0
    private var runningEnergyVariance: Float = 0
    private var frameCount: Int = 0

    // Room tone estimation for replace mode
    private var roomToneBuffer: [Float] = []
    private let maxRoomToneSamples = 48000  // 1 second at 48kHz

    // MARK: - Initialization

    init(sampleRate: Double = 48000, fftSize: Int = 2048, configuration: Configuration = .default) {
        self.sampleRate = sampleRate
        self.fftSize = fftSize
        self.hopSize = fftSize / 4
        self.configuration = configuration

        // Pre-allocate buffers
        self.windowBuffer = [Float](repeating: 0, count: fftSize)
        self.fftRealBuffer = [Float](repeating: 0, count: fftSize)
        self.fftImagBuffer = [Float](repeating: 0, count: fftSize)
        self.magnitudeBuffer = [Float](repeating: 0, count: fftSize / 2)

        // Create Hann window
        vDSP_hann_window(&windowBuffer, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
    }

    // MARK: - Offline Analysis

    /// Analyze an entire audio buffer and return detected breath regions.
    func analyzeBuffer(_ buffer: [Float]) -> [BreathRegion] {
        reset()
        detectedRegions = []

        let totalFrames = (buffer.count - fftSize) / hopSize
        guard totalFrames > 0 else { return [] }

        // First pass: compute features for all frames
        var frameFeatures: [(energy: Float, spectralCentroid: Float, spectralFlatness: Float, zcr: Float)] = []
        frameFeatures.reserveCapacity(totalFrames)

        for frameIndex in 0..<totalFrames {
            let offset = frameIndex * hopSize
            let frame = Array(buffer[offset..<offset + fftSize])
            let features = computeFrameFeatures(frame)
            frameFeatures.append(features)
        }

        // Compute adaptive thresholds from statistics
        let energies = frameFeatures.map { $0.energy }
        let sortedEnergies = energies.sorted()
        let medianEnergy = sortedEnergies[sortedEnergies.count / 2]

        // Sensitivity-adjusted threshold
        let sensitivityFactor = 1.0 - configuration.sensitivity * 0.7
        let energyThreshold = medianEnergy * sensitivityFactor

        let minBreathFrames = Int(configuration.minimumDuration * Float(sampleRate) / Float(hopSize))
        let maxBreathFrames = Int(configuration.maximumDuration * Float(sampleRate) / Float(hopSize))

        // Second pass: classify frames
        var breathFrameCount = 0
        var breathStart = 0

        for (frameIndex, features) in frameFeatures.enumerated() {
            let isBreathFrame = classifyFrame(
                features: features,
                energyThreshold: energyThreshold
            )

            if isBreathFrame {
                if breathFrameCount == 0 {
                    breathStart = frameIndex
                }
                breathFrameCount += 1
            } else {
                if breathFrameCount >= minBreathFrames && breathFrameCount <= maxBreathFrames {
                    let startSample = breathStart * hopSize
                    let endSample = min(frameIndex * hopSize, buffer.count)
                    let peakE = frameFeatures[breathStart..<breathStart + breathFrameCount]
                        .map { $0.energy }
                        .max() ?? 0

                    let confidence = computeBreathConfidence(
                        frameFeatures: Array(frameFeatures[breathStart..<breathStart + breathFrameCount]),
                        energyThreshold: energyThreshold
                    )

                    if confidence > 0.4 {
                        detectedRegions.append(BreathRegion(
                            startSample: startSample,
                            endSample: endSample,
                            confidence: confidence,
                            peakEnergy: peakE
                        ))
                    }
                }
                breathFrameCount = 0
            }
        }

        // Handle breath at end of buffer
        if breathFrameCount >= minBreathFrames && breathFrameCount <= maxBreathFrames {
            let startSample = breathStart * hopSize
            let endSample = buffer.count
            let confidence: Float = 0.6
            detectedRegions.append(BreathRegion(
                startSample: startSample,
                endSample: endSample,
                confidence: confidence,
                peakEnergy: 0
            ))
        }

        return detectedRegions
    }

    // MARK: - Processing

    /// Process an audio buffer: detect and apply breath removal/reduction.
    /// Returns the processed buffer.
    func processBuffer(_ buffer: [Float]) -> [Float] {
        let regions = analyzeBuffer(buffer)

        guard !regions.isEmpty, configuration.mode != .detect else {
            return buffer
        }

        var output = buffer
        let crossfadeSamples = Int(configuration.crossfadeDuration * Float(sampleRate))

        for region in regions {
            let start = max(0, region.startSample - crossfadeSamples)
            let end = min(buffer.count, region.endSample + crossfadeSamples)

            for i in start..<end {
                var gain: Float = 1.0

                if i < region.startSample {
                    // Fade out before breath
                    let fadeProgress = Float(i - start) / Float(crossfadeSamples)
                    gain = 1.0 - fadeProgress * (1.0 - configuration.reductionGain)
                } else if i >= region.endSample {
                    // Fade in after breath
                    let fadeProgress = Float(i - region.endSample) / Float(crossfadeSamples)
                    gain = configuration.reductionGain + fadeProgress * (1.0 - configuration.reductionGain)
                } else {
                    // Inside breath region
                    gain = configuration.reductionGain
                }

                if configuration.mode == .replace && i >= region.startSample && i < region.endSample {
                    // Replace with room tone
                    if !roomToneBuffer.isEmpty {
                        let rtIndex = (i - region.startSample) % roomToneBuffer.count
                        output[i] = roomToneBuffer[rtIndex] * 0.5
                    } else {
                        output[i] = buffer[i] * gain
                    }
                } else {
                    output[i] = buffer[i] * gain
                }
            }
        }

        return output
    }

    /// Capture room tone from a quiet segment for replace mode.
    func captureRoomTone(from buffer: [Float], startSample: Int, durationSamples: Int) {
        let end = min(startSample + durationSamples, buffer.count)
        guard startSample < end else { return }
        roomToneBuffer = Array(buffer[startSample..<end])
    }

    // MARK: - Frame Analysis

    private func computeFrameFeatures(_ frame: [Float]) -> (energy: Float, spectralCentroid: Float, spectralFlatness: Float, zcr: Float) {
        // Apply window
        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(frame, 1, windowBuffer, 1, &windowed, 1, vDSP_Length(fftSize))

        // Compute energy (RMS)
        var energy: Float = 0
        vDSP_rmsqv(windowed, 1, &energy, vDSP_Length(fftSize))

        // Compute magnitude spectrum via FFT
        var realParts = windowed
        var imagParts = [Float](repeating: 0, count: fftSize)

        if let setup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD) {
            var realOut = [Float](repeating: 0, count: fftSize)
            var imagOut = [Float](repeating: 0, count: fftSize)
            vDSP_DFT_Execute(setup, &realParts, &imagParts, &realOut, &imagOut)
            vDSP_DFT_DestroySetup(setup)

            // Magnitude spectrum
            let halfSize = fftSize / 2
            var splitComplex = DSPSplitComplex(realp: &realOut, imagp: &imagOut)
            var mags = [Float](repeating: 0, count: halfSize)
            vDSP_zvmags(&splitComplex, 1, &mags, 1, vDSP_Length(halfSize))

            // Spectral centroid
            var weightedSum: Float = 0
            var magSum: Float = 0
            for i in 0..<halfSize {
                weightedSum += Float(i) * mags[i]
                magSum += mags[i]
            }
            let spectralCentroid = magSum > 0 ? weightedSum / magSum : 0

            // Spectral flatness (geometric mean / arithmetic mean)
            let arithmeticMean = magSum / Float(halfSize)
            var logSum: Float = 0
            var nonZeroCount = 0
            for i in 0..<halfSize {
                if mags[i] > 1e-10 {
                    logSum += Foundation.log(mags[i])
                    nonZeroCount += 1
                }
            }
            let geometricMean = nonZeroCount > 0 ? exp(logSum / Float(nonZeroCount)) : 0
            let spectralFlatness = arithmeticMean > 0 ? geometricMean / arithmeticMean : 0

            // Zero-crossing rate
            let zcr = computeZCR(frame)

            return (energy, spectralCentroid, spectralFlatness, zcr)
        }

        return (energy, 0, 0, 0)
    }

    private func computeZCR(_ frame: [Float]) -> Float {
        var crossings = 0
        for i in 1..<frame.count {
            if (frame[i] >= 0 && frame[i - 1] < 0) || (frame[i] < 0 && frame[i - 1] >= 0) {
                crossings += 1
            }
        }
        return Float(crossings) / Float(frame.count)
    }

    private func classifyFrame(
        features: (energy: Float, spectralCentroid: Float, spectralFlatness: Float, zcr: Float),
        energyThreshold: Float
    ) -> Bool {
        // Breath characteristics:
        // - Lower energy than singing (but not silence)
        // - High spectral flatness (noise-like)
        // - High zero-crossing rate
        // - Moderate spectral centroid (higher than voiced, lower than sibilants)

        let isLowEnergy = features.energy < energyThreshold && features.energy > energyThreshold * 0.01
        let isNoisy = features.spectralFlatness > 0.3 * (1.0 - configuration.sensitivity * 0.5)
        let hasHighZCR = features.zcr > 0.05

        // Weighted classification
        var score: Float = 0
        if isLowEnergy { score += 0.4 }
        if isNoisy { score += 0.35 }
        if hasHighZCR { score += 0.25 }

        return score >= 0.6
    }

    private func computeBreathConfidence(
        frameFeatures: [(energy: Float, spectralCentroid: Float, spectralFlatness: Float, zcr: Float)],
        energyThreshold: Float
    ) -> Float {
        guard !frameFeatures.isEmpty else { return 0 }

        let avgFlatness = frameFeatures.map { $0.spectralFlatness }.reduce(0, +) / Float(frameFeatures.count)
        let avgZCR = frameFeatures.map { $0.zcr }.reduce(0, +) / Float(frameFeatures.count)
        let avgEnergy = frameFeatures.map { $0.energy }.reduce(0, +) / Float(frameFeatures.count)

        var confidence: Float = 0

        // High flatness = more noise-like = more likely breath
        confidence += min(avgFlatness * 1.5, 0.4)

        // Moderate ZCR
        if avgZCR > 0.05 && avgZCR < 0.4 { confidence += 0.3 }

        // Energy below threshold but not silence
        if avgEnergy < energyThreshold && avgEnergy > energyThreshold * 0.01 {
            confidence += 0.3
        }

        return min(confidence, 1.0)
    }

    // MARK: - Reset

    func reset() {
        isInBreath = false
        breathStartSample = 0
        consecutiveBreathFrames = 0
        consecutiveNonBreathFrames = 0
        frameCount = 0
        runningEnergyMean = 0
        runningEnergyVariance = 0
    }
}
