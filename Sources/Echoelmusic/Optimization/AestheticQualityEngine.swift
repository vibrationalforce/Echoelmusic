import Foundation
import Accelerate
import simd
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// ═══════════════════════════════════════════════════════════════════════════════
// AESTHETIC QUALITY ENGINE - VISUAL EXCELLENCE
// ═══════════════════════════════════════════════════════════════════════════════
//
// Visual quality enhancements:
// • Advanced beat detection with onset analysis
// • Perceptual-weighted frequency response
// • HDR color pipeline support
// • Advanced dithering for gradient quality
// • Motion smoothing algorithms
// • Bio-reactive visual transitions
//
// Audio-Visual Sync:
// • Sub-frame latency compensation
// • Predictive visual positioning
// • Beat-synced animation timing
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Advanced Beat Detector

/// High-accuracy beat detection with onset analysis
public final class AdvancedBeatDetector {

    // Configuration
    public struct Config {
        public var sampleRate: Float = 44100
        public var hopSize: Int = 512
        public var sensitivity: Float = 0.5
        public var minBPM: Float = 60
        public var maxBPM: Float = 200

        public init() {}
    }

    private var config: Config

    // Detection state
    private var energyHistory: [Float]
    private var onsetHistory: [Float]
    private var beatHistory: [UInt64]
    private var historySize: Int = 43  // ~1 second at 512 hop

    // Spectral flux for onset detection
    private var previousSpectrum: [Float]
    private let fftSize: Int = 2048
    private var fftSetup: vDSP_DFT_Setup?

    // BPM estimation
    private var currentBPM: Float = 120
    private var confidence: Float = 0

    // Pre-allocated buffers
    private var realBuffer: [Float]
    private var imagBuffer: [Float]
    private var magnitudeBuffer: [Float]
    private var windowBuffer: [Float]

    public init(config: Config = Config()) {
        self.config = config

        energyHistory = [Float](repeating: 0, count: historySize)
        onsetHistory = [Float](repeating: 0, count: historySize)
        beatHistory = []
        previousSpectrum = [Float](repeating: 0, count: fftSize / 2)

        realBuffer = [Float](repeating: 0, count: fftSize)
        imagBuffer = [Float](repeating: 0, count: fftSize)
        magnitudeBuffer = [Float](repeating: 0, count: fftSize / 2)
        windowBuffer = [Float](repeating: 0, count: fftSize)

        vDSP_hann_window(&windowBuffer, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    /// Process audio frame and detect beats
    public func process(
        _ samples: UnsafePointer<Float>,
        frameCount: Int
    ) -> BeatResult {
        // Compute energy
        var energy: Float = 0
        vDSP_measqv(samples, 1, &energy, vDSP_Length(frameCount))
        energy = sqrt(energy / Float(frameCount))

        // Compute spectral flux (onset detection)
        let spectralFlux = computeSpectralFlux(samples, frameCount: frameCount)

        // Update history
        energyHistory.removeFirst()
        energyHistory.append(energy)

        onsetHistory.removeFirst()
        onsetHistory.append(spectralFlux)

        // Adaptive threshold
        let energyMean = energyHistory.reduce(0, +) / Float(historySize)
        let energyStd = sqrt(energyHistory.map { ($0 - energyMean) * ($0 - energyMean) }
            .reduce(0, +) / Float(historySize))

        let onsetMean = onsetHistory.reduce(0, +) / Float(historySize)
        let onsetStd = sqrt(onsetHistory.map { ($0 - onsetMean) * ($0 - onsetMean) }
            .reduce(0, +) / Float(historySize))

        // Beat detection thresholds
        let energyThreshold = energyMean + config.sensitivity * energyStd
        let onsetThreshold = onsetMean + config.sensitivity * onsetStd * 1.5

        // Detect beat
        let isBeat = energy > energyThreshold && spectralFlux > onsetThreshold

        if isBeat {
            let timestamp = mach_absolute_time()
            beatHistory.append(timestamp)

            // Keep only recent beats (last 5 seconds)
            let cutoff = timestamp - UInt64(5_000_000_000)  // 5 seconds in ns
            beatHistory = beatHistory.filter { $0 > cutoff }

            // Estimate BPM
            if beatHistory.count >= 4 {
                estimateBPM()
            }
        }

        // Compute beat phase (0-1, where beat occurs at 1)
        let beatPhase = computeBeatPhase()

        return BeatResult(
            isBeat: isBeat,
            energy: energy,
            spectralFlux: spectralFlux,
            bpm: currentBPM,
            confidence: confidence,
            phase: beatPhase,
            onsetStrength: spectralFlux / max(onsetMean, 0.001)
        )
    }

    private func computeSpectralFlux(
        _ samples: UnsafePointer<Float>,
        frameCount: Int
    ) -> Float {
        guard let setup = fftSetup else { return 0 }

        // Window and FFT
        let count = min(frameCount, fftSize)
        vDSP_vmul(samples, 1, windowBuffer, 1, &realBuffer, 1, vDSP_Length(count))

        if count < fftSize {
            for i in count..<fftSize {
                realBuffer[i] = 0
            }
        }

        memset(&imagBuffer, 0, fftSize * MemoryLayout<Float>.size)
        vDSP_DFT_Execute(setup, realBuffer, imagBuffer, &realBuffer, &imagBuffer)

        // Compute magnitudes
        var splitComplex = DSPSplitComplex(realp: &realBuffer, imagp: &imagBuffer)
        vDSP_zvmags(&splitComplex, 1, &magnitudeBuffer, 1, vDSP_Length(fftSize / 2))

        // Spectral flux (half-wave rectified difference)
        var flux: Float = 0
        for i in 0..<(fftSize / 2) {
            let diff = magnitudeBuffer[i] - previousSpectrum[i]
            if diff > 0 {
                flux += diff
            }
        }

        // Update previous spectrum
        memcpy(&previousSpectrum, &magnitudeBuffer, (fftSize / 2) * MemoryLayout<Float>.size)

        return flux
    }

    private func estimateBPM() {
        guard beatHistory.count >= 4 else { return }

        // Calculate inter-beat intervals
        var intervals: [Float] = []
        for i in 1..<beatHistory.count {
            let intervalNs = Float(beatHistory[i] - beatHistory[i - 1])
            let intervalSec = intervalNs / 1_000_000_000.0
            let bpm = 60.0 / intervalSec

            if bpm >= config.minBPM && bpm <= config.maxBPM {
                intervals.append(bpm)
            }
        }

        guard !intervals.isEmpty else { return }

        // Median BPM
        let sorted = intervals.sorted()
        let median = sorted[sorted.count / 2]

        // Filter outliers and average
        let filtered = intervals.filter { abs($0 - median) < 20 }
        guard !filtered.isEmpty else { return }

        let newBPM = filtered.reduce(0, +) / Float(filtered.count)

        // Smooth update
        currentBPM = currentBPM * 0.7 + newBPM * 0.3

        // Confidence based on consistency
        let variance = filtered.map { ($0 - newBPM) * ($0 - newBPM) }
            .reduce(0, +) / Float(filtered.count)
        confidence = 1.0 / (1.0 + sqrt(variance) / 10.0)
    }

    private func computeBeatPhase() -> Float {
        guard !beatHistory.isEmpty else { return 0 }

        let now = mach_absolute_time()
        let lastBeat = beatHistory.last!
        let beatIntervalNs = UInt64(60_000_000_000 / currentBPM)

        let elapsed = now - lastBeat
        let phase = Float(elapsed % beatIntervalNs) / Float(beatIntervalNs)

        return phase
    }

    /// Beat detection result
    public struct BeatResult {
        public let isBeat: Bool
        public let energy: Float
        public let spectralFlux: Float
        public let bpm: Float
        public let confidence: Float
        public let phase: Float         // 0-1 phase within beat
        public let onsetStrength: Float // Relative onset intensity
    }
}

// MARK: - Perceptual Audio Processor

/// Perceptually-weighted frequency analysis
public final class PerceptualAudioProcessor {

    // A-weighting coefficients (simplified)
    private let aWeighting: [Float]

    // Frequency band boundaries (Hz)
    private let bandEdges: [Float] = [20, 60, 250, 500, 2000, 4000, 6000, 20000]

    // Pre-computed band indices for FFT
    private var bandIndices: [(start: Int, end: Int)] = []

    private let fftSize: Int
    private let sampleRate: Float

    public init(fftSize: Int = 4096, sampleRate: Float = 44100) {
        self.fftSize = fftSize
        self.sampleRate = sampleRate

        // Generate A-weighting curve
        let binCount = fftSize / 2
        var weights = [Float](repeating: 0, count: binCount)

        for i in 0..<binCount {
            let freq = Float(i) * sampleRate / Float(fftSize)
            weights[i] = Self.aWeightingDB(freq)
        }

        // Normalize
        var maxWeight: Float = 0
        vDSP_maxv(weights, 1, &maxWeight, vDSP_Length(binCount))
        var normFactor = 1.0 / max(maxWeight, 0.001)
        vDSP_vsmul(weights, 1, &normFactor, &weights, 1, vDSP_Length(binCount))

        self.aWeighting = weights

        // Pre-compute band indices
        for i in 0..<(bandEdges.count - 1) {
            let startFreq = bandEdges[i]
            let endFreq = bandEdges[i + 1]

            let startBin = Int(startFreq * Float(fftSize) / sampleRate)
            let endBin = Int(endFreq * Float(fftSize) / sampleRate)

            bandIndices.append((start: max(0, startBin), end: min(binCount - 1, endBin)))
        }
    }

    /// A-weighting in dB at given frequency
    private static func aWeightingDB(_ freq: Float) -> Float {
        guard freq > 0 else { return -100 }

        let f2 = freq * freq
        let f4 = f2 * f2

        // A-weighting formula
        let numerator = 12194.0 * 12194.0 * f4
        let denominator = (f2 + 20.6 * 20.6) *
            sqrt((f2 + 107.7 * 107.7) * (f2 + 737.9 * 737.9)) *
            (f2 + 12194.0 * 12194.0)

        let ra = numerator / max(Float(denominator), 0.00001)
        return 20.0 * log10(max(ra, 0.00001)) + 2.0
    }

    /// Apply A-weighting to magnitude spectrum
    public func applyAWeighting(
        _ magnitudes: UnsafeMutablePointer<Float>,
        count: Int
    ) {
        let processCount = min(count, aWeighting.count)
        aWeighting.withUnsafeBufferPointer { weights in
            vDSP_vmul(magnitudes, 1, weights.baseAddress!, 1, magnitudes, 1, vDSP_Length(processCount))
        }
    }

    /// Extract frequency bands from spectrum
    public func extractBands(
        _ magnitudes: UnsafePointer<Float>,
        count: Int
    ) -> FrequencyBands {
        var bands = FrequencyBands()

        for (index, range) in bandIndices.enumerated() {
            guard range.start < count && range.end < count else { continue }

            var bandEnergy: Float = 0
            let bandCount = range.end - range.start + 1

            vDSP_meanv(magnitudes.advanced(by: range.start), 1, &bandEnergy, vDSP_Length(bandCount))

            bands[index] = bandEnergy
        }

        return bands
    }

    /// Compute perceptual loudness (approximation of LUFS)
    public func computeLoudness(
        _ magnitudes: UnsafePointer<Float>,
        count: Int
    ) -> Float {
        // Apply K-weighting (simplified as A-weighting here)
        var weighted = [Float](repeating: 0, count: count)
        memcpy(&weighted, magnitudes, count * MemoryLayout<Float>.size)

        applyAWeighting(&weighted, count: count)

        // Mean square
        var meanSquare: Float = 0
        vDSP_measqv(weighted, 1, &meanSquare, vDSP_Length(count))

        // Convert to LUFS-like scale
        let loudness = -0.691 + 10.0 * log10(max(meanSquare, 0.00001))

        return loudness
    }
}

// MARK: - HDR Color Pipeline

/// HDR color processing support
@frozen
public struct HDRColorPipeline {

    /// HDR color space identifiers
    public enum ColorSpace {
        case sRGB           // Standard, gamma 2.2
        case linearSRGB     // Linear, for processing
        case displayP3      // Wide gamut
        case bt2020         // HDR wide gamut
        case scRGB          // Extended range linear

        var transferFunction: TransferFunction {
            switch self {
            case .sRGB, .displayP3: return .sRGB
            case .linearSRGB, .scRGB: return .linear
            case .bt2020: return .pq
            }
        }
    }

    public enum TransferFunction {
        case linear
        case sRGB
        case pq  // Perceptual Quantizer (HDR)
    }

    // MARK: - Transfer Functions

    /// sRGB OETF (Opto-Electronic Transfer Function)
    @inlinable
    public static func sRGBToLinear(_ c: Float) -> Float {
        if c <= 0.04045 {
            return c / 12.92
        } else {
            return pow((c + 0.055) / 1.055, 2.4)
        }
    }

    /// sRGB EOTF (Electro-Optical Transfer Function)
    @inlinable
    public static func linearToSRGB(_ c: Float) -> Float {
        if c <= 0.0031308 {
            return c * 12.92
        } else {
            return 1.055 * pow(c, 1.0 / 2.4) - 0.055
        }
    }

    /// PQ (Perceptual Quantizer) OETF for HDR
    @inlinable
    public static func pqToLinear(_ e: Float) -> Float {
        let m1: Float = 0.1593017578125
        let m2: Float = 78.84375
        let c1: Float = 0.8359375
        let c2: Float = 18.8515625
        let c3: Float = 18.6875

        let ep = pow(max(e, 0), 1.0 / m2)
        let numerator = max(ep - c1, 0)
        let denominator = c2 - c3 * ep

        return pow(numerator / max(denominator, 0.00001), 1.0 / m1)
    }

    /// PQ EOTF for HDR
    @inlinable
    public static func linearToPQ(_ y: Float) -> Float {
        let m1: Float = 0.1593017578125
        let m2: Float = 78.84375
        let c1: Float = 0.8359375
        let c2: Float = 18.8515625
        let c3: Float = 18.6875

        let yp = pow(max(y, 0), m1)
        let numerator = c1 + c2 * yp
        let denominator = 1 + c3 * yp

        return pow(numerator / denominator, m2)
    }

    // MARK: - Batch Processing

    /// Convert batch sRGB to linear (SIMD)
    public static func batchSRGBToLinear(
        _ input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        count: Int
    ) {
        for i in 0..<count {
            output[i] = sRGBToLinear(input[i])
        }
    }

    /// Convert batch linear to sRGB (SIMD)
    public static func batchLinearToSRGB(
        _ input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        count: Int
    ) {
        for i in 0..<count {
            output[i] = linearToSRGB(input[i])
        }
    }

    // MARK: - Tone Mapping

    /// ACES filmic tone mapping (HDR to SDR)
    @inlinable
    public static func acesToneMap(_ x: Float) -> Float {
        let a: Float = 2.51
        let b: Float = 0.03
        let c: Float = 2.43
        let d: Float = 0.59
        let e: Float = 0.14

        return clamp((x * (a * x + b)) / (x * (c * x + d) + e), min: 0, max: 1)
    }

    /// Reinhard tone mapping
    @inlinable
    public static func reinhardToneMap(_ x: Float, whitePoint: Float = 4.0) -> Float {
        let wp2 = whitePoint * whitePoint
        return x * (1 + x / wp2) / (1 + x)
    }

    /// Apply tone mapping to RGB
    @inlinable
    public static func toneMapRGB(
        _ rgb: SIMD3<Float>,
        method: ToneMappingMethod = .aces
    ) -> SIMD3<Float> {
        switch method {
        case .aces:
            return SIMD3(
                acesToneMap(rgb.x),
                acesToneMap(rgb.y),
                acesToneMap(rgb.z)
            )
        case .reinhard:
            return SIMD3(
                reinhardToneMap(rgb.x),
                reinhardToneMap(rgb.y),
                reinhardToneMap(rgb.z)
            )
        case .none:
            return rgb
        }
    }

    public enum ToneMappingMethod {
        case none
        case reinhard
        case aces
    }

    // MARK: - Helpers

    @inlinable
    static func clamp(_ value: Float, min: Float, max: Float) -> Float {
        return Swift.min(Swift.max(value, min), max)
    }
}

// MARK: - Dithering Engine

/// High-quality dithering for gradient banding prevention
@frozen
public struct DitheringEngine {

    /// Bayer 4x4 dithering matrix (normalized to 0-1)
    private static let bayer4x4: [Float] = [
        0/16, 8/16, 2/16, 10/16,
        12/16, 4/16, 14/16, 6/16,
        3/16, 11/16, 1/16, 9/16,
        15/16, 7/16, 13/16, 5/16
    ]

    /// Bayer 8x8 dithering matrix (normalized to 0-1)
    private static let bayer8x8: [Float] = [
        0/64, 32/64, 8/64, 40/64, 2/64, 34/64, 10/64, 42/64,
        48/64, 16/64, 56/64, 24/64, 50/64, 18/64, 58/64, 26/64,
        12/64, 44/64, 4/64, 36/64, 14/64, 46/64, 6/64, 38/64,
        60/64, 28/64, 52/64, 20/64, 62/64, 30/64, 54/64, 22/64,
        3/64, 35/64, 11/64, 43/64, 1/64, 33/64, 9/64, 41/64,
        51/64, 19/64, 59/64, 27/64, 49/64, 17/64, 57/64, 25/64,
        15/64, 47/64, 7/64, 39/64, 13/64, 45/64, 5/64, 37/64,
        63/64, 31/64, 55/64, 23/64, 61/64, 29/64, 53/64, 21/64
    ]

    /// Get Bayer dither value for pixel position
    @inlinable
    public static func bayer4x4Value(x: Int, y: Int) -> Float {
        let index = (y & 3) * 4 + (x & 3)
        return bayer4x4[index]
    }

    /// Get Bayer 8x8 dither value for pixel position
    @inlinable
    public static func bayer8x8Value(x: Int, y: Int) -> Float {
        let index = (y & 7) * 8 + (x & 7)
        return bayer8x8[index]
    }

    /// Apply ordered dithering to value (for 8-bit output)
    @inlinable
    public static func ditherTo8Bit(
        value: Float,
        x: Int,
        y: Int,
        spread: Float = 1.0
    ) -> UInt8 {
        let threshold = bayer8x8Value(x: x, y: y) - 0.5
        let dithered = value + threshold * spread / 255.0
        return UInt8(clamping: Int(dithered * 255))
    }

    /// Temporal dithering (frame-based noise)
    @inlinable
    public static func temporalDither(
        value: Float,
        x: Int,
        y: Int,
        frame: Int
    ) -> Float {
        // Rotate Bayer pattern each frame
        let offsetX = (frame * 3) & 7
        let offsetY = (frame * 5) & 7
        let threshold = bayer8x8Value(x: x + offsetX, y: y + offsetY) - 0.5
        return value + threshold / 255.0
    }

    /// Blue noise dithering (precomputed LUT would be better)
    @inlinable
    public static func blueNoise(x: Int, y: Int, seed: UInt32) -> Float {
        // Simple spatial hash for blue-noise-like pattern
        var h = seed
        h ^= UInt32(x) * 0x85ebca6b
        h ^= UInt32(y) * 0xc2b2ae35
        h = h ^ (h >> 16)
        h = h &* 0x85ebca6b
        h = h ^ (h >> 13)
        h = h &* 0xc2b2ae35
        h = h ^ (h >> 16)

        return Float(h) / Float(UInt32.max)
    }
}

// MARK: - Motion Smoothing

/// Advanced motion smoothing for visual elements
public final class MotionSmoother {

    /// Exponential smoothing state
    public struct SmoothingState {
        public var current: Float = 0
        public var velocity: Float = 0

        public init(initial: Float = 0) {
            self.current = initial
            self.velocity = 0
        }
    }

    /// Simple exponential smoothing
    @inlinable
    public static func exponential(
        target: Float,
        state: inout SmoothingState,
        smoothing: Float  // 0-1, higher = smoother
    ) -> Float {
        let alpha = 1.0 - smoothing
        state.current = state.current + alpha * (target - state.current)
        return state.current
    }

    /// Double exponential smoothing (includes velocity)
    @inlinable
    public static func doubleExponential(
        target: Float,
        state: inout SmoothingState,
        dataSmoothingAlpha: Float = 0.3,
        trendSmoothingBeta: Float = 0.1
    ) -> Float {
        let newVelocity = trendSmoothingBeta * (state.current - target) +
            (1 - trendSmoothingBeta) * state.velocity
        let newCurrent = dataSmoothingAlpha * target +
            (1 - dataSmoothingAlpha) * (state.current + state.velocity)

        state.current = newCurrent
        state.velocity = newVelocity

        return newCurrent
    }

    /// Spring physics smoothing
    @inlinable
    public static func spring(
        target: Float,
        state: inout SmoothingState,
        stiffness: Float = 100,  // Spring constant
        damping: Float = 10,      // Damping ratio
        dt: Float = 1.0 / 60.0   // Time step
    ) -> Float {
        // F = -kx - cv (Hooke's law with damping)
        let displacement = state.current - target
        let springForce = -stiffness * displacement
        let dampingForce = -damping * state.velocity
        let acceleration = springForce + dampingForce

        state.velocity += acceleration * dt
        state.current += state.velocity * dt

        return state.current
    }

    /// Critical damped spring (no oscillation)
    @inlinable
    public static func criticalDampedSpring(
        target: Float,
        state: inout SmoothingState,
        omega: Float = 10.0,  // Natural frequency
        dt: Float = 1.0 / 60.0
    ) -> Float {
        // Critical damping: damping ratio = 1
        let x = state.current - target
        let v = state.velocity

        // Analytical solution for critically damped spring
        let exp = Foundation.exp(-omega * dt)
        state.current = target + (x + (v + omega * x) * dt) * exp
        state.velocity = (v - omega * (v + omega * x) * dt) * exp

        return state.current
    }

    /// Hysteresis smoothing (prevents jitter near threshold)
    @inlinable
    public static func hysteresis(
        value: Float,
        state: inout Float,
        threshold: Float = 0.1
    ) -> Float {
        if abs(value - state) > threshold {
            state = value
        }
        return state
    }
}

// MARK: - Bio-Reactive Visual Transition

/// Smooth bio-reactive visual transitions
public final class BioReactiveTransition {

    /// Transition configuration
    public struct Config {
        public var coherenceInfluence: Float = 0.5
        public var heartRateInfluence: Float = 0.3
        public var breathingInfluence: Float = 0.2
        public var transitionSpeed: Float = 0.1

        public init() {}
    }

    private var config: Config

    // State for each parameter
    private var colorState = MotionSmoother.SmoothingState()
    private var intensityState = MotionSmoother.SmoothingState()
    private var scaleState = MotionSmoother.SmoothingState()

    public init(config: Config = Config()) {
        self.config = config
    }

    /// Compute transition parameters from bio data
    public func update(
        coherence: Float,
        heartRate: Float,
        breathingRate: Float,
        dt: Float = 1.0 / 60.0
    ) -> TransitionState {
        // Normalize inputs
        let normCoherence = coherence  // Already 0-1
        let normHR = (heartRate - 40) / 160  // 40-200 BPM → 0-1
        let normBR = (breathingRate - 4) / 26  // 4-30 BPM → 0-1

        // Compute target values
        let targetWarmth = normCoherence * 0.6 + (1 - normHR) * 0.4
        let targetIntensity = 0.5 + normHR * 0.3 + normCoherence * 0.2
        let targetScale = 0.8 + normBR * 0.2 + normCoherence * 0.1

        // Smooth transitions using spring physics
        let warmth = MotionSmoother.criticalDampedSpring(
            target: targetWarmth,
            state: &colorState,
            omega: 5.0 * (1 + normCoherence),  // Faster transitions at high coherence
            dt: dt
        )

        let intensity = MotionSmoother.criticalDampedSpring(
            target: targetIntensity,
            state: &intensityState,
            omega: 3.0,
            dt: dt
        )

        let scale = MotionSmoother.criticalDampedSpring(
            target: targetScale,
            state: &scaleState,
            omega: 2.0,
            dt: dt
        )

        return TransitionState(
            colorWarmth: warmth,
            intensity: intensity,
            scale: scale,
            coherenceLevel: normCoherence
        )
    }

    /// Apply easing based on coherence state
    @inlinable
    public func easedTransition(_ t: Float, coherence: Float) -> Float {
        return Easing.bioSmooth(t, coherence: coherence)
    }

    /// Transition state output
    public struct TransitionState {
        public let colorWarmth: Float    // 0 = cool, 1 = warm
        public let intensity: Float      // 0-1 visual intensity
        public let scale: Float          // Scale multiplier
        public let coherenceLevel: Float // Current coherence

        /// Color temperature in Kelvin (2700K-6500K)
        public var colorTemperature: Float {
            return 6500 - colorWarmth * 3800
        }

        /// RGB color tint based on warmth
        public var colorTint: SIMD3<Float> {
            // Warm to cool gradient
            let warm = SIMD3<Float>(1.0, 0.85, 0.7)
            let cool = SIMD3<Float>(0.7, 0.85, 1.0)
            return warm * colorWarmth + cool * (1 - colorWarmth)
        }
    }
}

// MARK: - Visual Quality Presets

/// Quality presets for visual rendering
public enum VisualQualityPreset {
    case performance  // Low latency, reduced quality
    case balanced     // Default
    case quality      // Maximum visual quality
    case cinematic    // Film-like aesthetics

    public var settings: VisualQualitySettings {
        switch self {
        case .performance:
            return VisualQualitySettings(
                ditherEnabled: false,
                motionSmoothing: .none,
                colorSpace: .sRGB,
                toneMapping: .none,
                bloomQuality: 0,
                msaaSamples: 1
            )
        case .balanced:
            return VisualQualitySettings(
                ditherEnabled: true,
                motionSmoothing: .exponential,
                colorSpace: .sRGB,
                toneMapping: .reinhard,
                bloomQuality: 1,
                msaaSamples: 2
            )
        case .quality:
            return VisualQualitySettings(
                ditherEnabled: true,
                motionSmoothing: .spring,
                colorSpace: .displayP3,
                toneMapping: .aces,
                bloomQuality: 2,
                msaaSamples: 4
            )
        case .cinematic:
            return VisualQualitySettings(
                ditherEnabled: true,
                motionSmoothing: .criticalDamped,
                colorSpace: .bt2020,
                toneMapping: .aces,
                bloomQuality: 3,
                msaaSamples: 8,
                filmGrain: 0.02,
                chromaticAberration: 0.001
            )
        }
    }
}

/// Visual quality settings
public struct VisualQualitySettings {
    public var ditherEnabled: Bool
    public var motionSmoothing: MotionSmoothingType
    public var colorSpace: HDRColorPipeline.ColorSpace
    public var toneMapping: HDRColorPipeline.ToneMappingMethod
    public var bloomQuality: Int  // 0 = off, 1-3 = quality levels
    public var msaaSamples: Int
    public var filmGrain: Float = 0
    public var chromaticAberration: Float = 0

    public enum MotionSmoothingType {
        case none
        case exponential
        case spring
        case criticalDamped
    }
}
