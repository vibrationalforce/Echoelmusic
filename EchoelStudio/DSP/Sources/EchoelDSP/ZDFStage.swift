import Foundation

/// One zero-delay-feedback state-variable stage (the TPT form `SVFilter` uses) with its
/// coefficients passed in on every sample, so the effects that glide a frequency per sample —
/// the formant filter, the multiband's crossovers, the mid/side tilt — share one tested
/// integrator pair instead of each writing its own. `g = tan(π·f/sr)`, `k = 1/Q`.
///
/// A value type of two floats: no allocation, render-thread safe. A non-finite state is emptied,
/// so one bad sample cannot ring forever.
struct ZDFStage: Sendable {
    private var ic1: Float = 0
    private var ic2: Float = 0

    /// Lowpass, bandpass (unnormalised: its peak is `1/k`) and highpass of one sample.
    @inline(__always)
    mutating func process(_ input: Float, g: Float, k: Float) -> (low: Float, band: Float, high: Float) {
        let a1 = 1 / (1 + g * (g + k))
        let a2 = g * a1
        let a3 = g * a2
        let v3 = input - ic2
        let v1 = a1 * ic1 + a2 * v3
        let v2 = ic2 + a2 * ic1 + a3 * v3
        ic1 = 2 * v1 - ic1
        ic2 = 2 * v2 - ic2
        if !ic1.isFinite || !ic2.isFinite {
            ic1 = 0
            ic2 = 0
        }
        // Flush what has decayed below hearing, so a silent tail never runs on denormals.
        if Swift.abs(ic1) < 1e-20 { ic1 = 0 }
        if Swift.abs(ic2) < 1e-20 { ic2 = 0 }
        return (v2, v1, input - k * v1 - v2)
    }

    mutating func reset() {
        ic1 = 0
        ic2 = 0
    }

    /// The prewarped integrator gain for `hertz`, held below Nyquist.
    static func g(_ hertz: Double, sampleRate: Double) -> Float {
        let limited = Swift.min(Swift.max(hertz.isFinite ? hertz : 1_000, 1), sampleRate * 0.49)
        return Float(Foundation.tan(Double.pi * limited / sampleRate))
    }

    /// The Butterworth damping, `√2`: two Butterworth stages in a row are a Linkwitz-Riley
    /// crossover of the fourth order.
    static let butterworth: Float = Float(2).squareRoot()
}
