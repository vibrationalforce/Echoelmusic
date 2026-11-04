import Foundation

/// The last stage of an Echoel unit in another app's host: a soft clip that leaves everything up
/// to −3 dBFS untouched and bends what lies above it onto a curve that never reaches full scale.
/// A host may sum our output into a fixed-point bus or a converter that cuts flat; a flanger at
/// feedback −0.95 peaked at 4.0 from a 0.5 sine (audit 2026-11-04). Above the knee the curve is
/// `knee + (1 − knee)·tanh((|x| − knee)/(1 − knee))`: it leaves the knee at the slope of the
/// line it continues, so the bend has no corner. A sample that is not finite becomes silence.
///
/// Pure and allocation-free: a render block calls it.
public enum OutputSafety {
    /// −3 dBFS. Computed, not stored: the render thread reads it (see `DemoGate`).
    public static var knee: Float { 0.707_945_8 }

    /// One sample through the curve.
    @inline(__always)
    public static func shape(_ x: Float) -> Float {
        guard x.isFinite else { return 0 }
        let magnitude = Swift.abs(x)
        let k = knee
        guard magnitude > k else { return x }
        let bent = k + (1 - k) * tanhf((magnitude - k) / (1 - k))
        return x < 0 ? -bent : bent
    }

    /// `frames` of both channels through the curve, in place.
    public static func apply(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        for i in 0..<Swift.max(frames, 0) {
            left[i] = shape(left[i])
            right[i] = shape(right[i])
        }
    }
}
