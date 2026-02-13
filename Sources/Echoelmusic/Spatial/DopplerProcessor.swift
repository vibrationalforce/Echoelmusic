import Foundation
import Accelerate

/// Real-time Doppler effect processor for spatial audio sources.
///
/// Applies frequency shifting based on the relative velocity between
/// a sound source and the listener, simulating the Doppler effect.
///
/// Physics:
/// ```
/// f_observed = f_source * (v_sound + v_listener) / (v_sound + v_source)
/// ```
/// Where velocities are projected onto the source→listener vector.
class DopplerProcessor {

    // MARK: - Configuration

    struct Configuration {
        /// Speed of sound in m/s (343 at 20C sea level)
        var speedOfSound: Float = 343.0

        /// Maximum pitch shift ratio to prevent artifacts (e.g., 2.0 = 1 octave)
        var maxShiftRatio: Float = 2.0

        /// Smoothing factor to avoid sudden pitch jumps (0 = instant, 1 = frozen)
        var smoothing: Float = 0.95

        /// Enable supersonic clamping (prevents negative/infinite ratios)
        var clampSupersonic: Bool = true

        /// Interpolation quality for resampling
        var interpolationMode: InterpolationMode = .cubic

        static let `default` = Configuration()
        static let subtle = Configuration(maxShiftRatio: 1.2, smoothing: 0.98)
        static let dramatic = Configuration(maxShiftRatio: 3.0, smoothing: 0.85)
    }

    enum InterpolationMode {
        case linear
        case cubic
    }

    // MARK: - Properties

    var configuration: Configuration
    private let sampleRate: Double

    /// Current smoothed pitch shift ratio per source
    private var smoothedRatios: [UUID: Float] = [:]

    /// Resample buffer for pitch shifting
    private var resampleBuffer: [Float]
    private let maxBufferSize: Int

    // MARK: - Initialization

    init(sampleRate: Double = 48000, configuration: Configuration = .default) {
        self.sampleRate = sampleRate
        self.configuration = configuration
        self.maxBufferSize = Int(sampleRate) // 1 second max
        self.resampleBuffer = [Float](repeating: 0, count: maxBufferSize)
    }

    // MARK: - Doppler Calculation

    /// Compute the Doppler shift ratio for a source moving relative to the listener.
    ///
    /// - Parameters:
    ///   - sourcePosition: Source position in 3D space (meters)
    ///   - sourceVelocity: Source velocity vector (m/s)
    ///   - listenerPosition: Listener position in 3D space (meters)
    ///   - listenerVelocity: Listener velocity vector (m/s)
    /// - Returns: Frequency ratio (>1 = approaching/higher pitch, <1 = receding/lower pitch)
    func computeShiftRatio(
        sourcePosition: SIMD3<Float>,
        sourceVelocity: SIMD3<Float>,
        listenerPosition: SIMD3<Float>,
        listenerVelocity: SIMD3<Float>
    ) -> Float {
        let toListener = listenerPosition - sourcePosition
        let distance = simd_length(toListener)

        guard distance > 0.001 else {
            return 1.0 // Source at listener position, no Doppler
        }

        // Unit vector from source toward listener
        let direction = toListener / distance

        // Project velocities onto the source→listener axis
        // Positive = moving toward each other
        let vSource = simd_dot(sourceVelocity, direction)
        let vListener = simd_dot(listenerVelocity, direction)

        let c = configuration.speedOfSound

        // Clamp to prevent supersonic artifacts
        var effectiveVSource = vSource
        var effectiveVListener = vListener
        if configuration.clampSupersonic {
            effectiveVSource = min(effectiveVSource, c * 0.95)
            effectiveVListener = max(effectiveVListener, -c * 0.95)
        }

        // Doppler formula: f_obs = f_src * (c + v_listener) / (c + v_source)
        // Note: vSource positive = moving toward listener, so denominator uses (c - vSource)
        let numerator = c + effectiveVListener
        let denominator = c - effectiveVSource

        guard denominator > 0.001 else {
            return configuration.maxShiftRatio
        }

        var ratio = numerator / denominator

        // Clamp to configured range
        ratio = max(1.0 / configuration.maxShiftRatio, min(configuration.maxShiftRatio, ratio))

        return ratio
    }

    /// Compute smoothed Doppler shift for a tracked source.
    func computeSmoothedShiftRatio(
        sourceID: UUID,
        sourcePosition: SIMD3<Float>,
        sourceVelocity: SIMD3<Float>,
        listenerPosition: SIMD3<Float>,
        listenerVelocity: SIMD3<Float>
    ) -> Float {
        let instantRatio = computeShiftRatio(
            sourcePosition: sourcePosition,
            sourceVelocity: sourceVelocity,
            listenerPosition: listenerPosition,
            listenerVelocity: listenerVelocity
        )

        let previousRatio = smoothedRatios[sourceID] ?? 1.0
        let alpha = configuration.smoothing
        let smoothed = alpha * previousRatio + (1.0 - alpha) * instantRatio
        smoothedRatios[sourceID] = smoothed

        return smoothed
    }

    // MARK: - Audio Processing

    /// Apply Doppler pitch shift to an audio buffer via resampling.
    ///
    /// - Parameters:
    ///   - input: Input audio samples
    ///   - shiftRatio: Frequency ratio from `computeShiftRatio`
    /// - Returns: Pitch-shifted audio buffer (same length as input)
    func applyDopplerShift(_ input: [Float], shiftRatio: Float) -> [Float] {
        guard abs(shiftRatio - 1.0) > 0.001 else {
            return input // No shift needed
        }

        let count = input.count
        var output = [Float](repeating: 0, count: count)

        switch configuration.interpolationMode {
        case .linear:
            applyLinearInterpolation(input, output: &output, ratio: shiftRatio)
        case .cubic:
            applyCubicInterpolation(input, output: &output, ratio: shiftRatio)
        }

        return output
    }

    /// Apply Doppler to a buffer for a tracked source (with smoothing).
    func processSource(
        _ input: [Float],
        sourceID: UUID,
        sourcePosition: SIMD3<Float>,
        sourceVelocity: SIMD3<Float>,
        listenerPosition: SIMD3<Float>,
        listenerVelocity: SIMD3<Float> = .zero
    ) -> [Float] {
        let ratio = computeSmoothedShiftRatio(
            sourceID: sourceID,
            sourcePosition: sourcePosition,
            sourceVelocity: sourceVelocity,
            listenerPosition: listenerPosition,
            listenerVelocity: listenerVelocity
        )
        return applyDopplerShift(input, shiftRatio: ratio)
    }

    // MARK: - Interpolation

    private func applyLinearInterpolation(_ input: [Float], output: inout [Float], ratio: Float) {
        let count = input.count
        for i in 0..<count {
            let sourceIndex = Float(i) * ratio
            let intIndex = Int(sourceIndex)
            let frac = sourceIndex - Float(intIndex)

            if intIndex + 1 < count {
                output[i] = input[intIndex] * (1.0 - frac) + input[intIndex + 1] * frac
            } else if intIndex < count {
                output[i] = input[intIndex]
            }
        }
    }

    private func applyCubicInterpolation(_ input: [Float], output: inout [Float], ratio: Float) {
        let count = input.count
        for i in 0..<count {
            let sourceIndex = Float(i) * ratio
            let intIndex = Int(sourceIndex)
            let frac = sourceIndex - Float(intIndex)

            // Catmull-Rom cubic interpolation (4 points)
            let i0 = max(0, intIndex - 1)
            let i1 = intIndex
            let i2 = min(count - 1, intIndex + 1)
            let i3 = min(count - 1, intIndex + 2)

            guard i1 < count else { break }

            let p0 = input[i0]
            let p1 = input[i1]
            let p2 = input[i2]
            let p3 = input[i3]

            // Catmull-Rom coefficients
            let a = -0.5 * p0 + 1.5 * p1 - 1.5 * p2 + 0.5 * p3
            let b = p0 - 2.5 * p1 + 2.0 * p2 - 0.5 * p3
            let c = -0.5 * p0 + 0.5 * p2
            let d = p1

            output[i] = a * frac * frac * frac + b * frac * frac + c * frac + d
        }
    }

    // MARK: - Source Management

    /// Remove tracking state for a source that no longer exists.
    func removeSource(_ id: UUID) {
        smoothedRatios.removeValue(forKey: id)
    }

    /// Reset all tracking state.
    func reset() {
        smoothedRatios.removeAll()
    }
}
