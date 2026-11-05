import Foundation

/// The phase meter's two readings of a stereo block, as a studio's goniometer and correlation
/// meter show them. Pure and allocation-free; the Field's phase meter reads the master through it.
///
/// - Correlation: Σ L·R / √(Σ L² · Σ R²), from +1 (both sides the same: mono) through 0 (unrelated)
///   to −1 (one side the other inverted: it cancels when summed to mono).
/// - Goniometer: each pair drawn as mid against side, mid = (L + R)/√2 up, side = (L − R)/√2 across,
///   so mono is a vertical line, a hard-left or hard-right signal a diagonal, and an inverted pair
///   a horizontal line.
public enum StereoPhase {
    /// Below this energy per sample a block counts as silent and has no correlation.
    public static let silence: Float = 1e-10

    /// The block's correlation −1 … 1, or nil when either side is silent (a correlation of nothing
    /// is not a number). Non-finite samples count as 0.
    public static func correlation(left: UnsafePointer<Float>, right: UnsafePointer<Float>, count: Int) -> Float? {
        guard count > 0 else { return nil }
        var product: Double = 0, leftEnergy: Double = 0, rightEnergy: Double = 0
        for index in 0..<count {
            let l = Double(left[index].isFinite ? left[index] : 0)
            let r = Double(right[index].isFinite ? right[index] : 0)
            product += l * r
            leftEnergy += l * l
            rightEnergy += r * r
        }
        let floor = Double(silence) * Double(count)
        guard leftEnergy > floor, rightEnergy > floor else { return nil }
        let value = product / (leftEnergy * rightEnergy).squareRoot()
        guard value.isFinite else { return nil }
        return Float(Swift.min(1, Swift.max(-1, value)))
    }

    /// `pairs` points of the block, evenly spaced, into `points` as side, mid, side, mid … (2 × pairs
    /// values, each clamped to −1 … 1). A block shorter than `pairs` repeats its last sample;
    /// non-finite samples count as 0.
    public static func capture(left: UnsafePointer<Float>, right: UnsafePointer<Float>, count: Int,
                               into points: UnsafeMutablePointer<Float>, pairs: Int) {
        guard pairs > 0 else { return }
        let scale = Float(0.5).squareRoot()
        for pair in 0..<pairs {
            var side: Float = 0, mid: Float = 0
            if count > 0 {
                let index = Swift.min(count - 1, pair * count / pairs)
                let l = left[index].isFinite ? left[index] : 0
                let r = right[index].isFinite ? right[index] : 0
                side = (l - r) * scale
                mid = (l + r) * scale
            }
            points[2 * pair] = Swift.min(1, Swift.max(-1, side))
            points[2 * pair + 1] = Swift.min(1, Swift.max(-1, mid))
        }
    }
}
