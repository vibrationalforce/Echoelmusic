/// A locked plugin's demo: two seconds of silence in every thirty, counted from the frame its
/// render resources were allocated. The silence fades in and out over 10 ms, so the gate never
/// clicks — it used to switch between full level and nothing at once (ultra-audit A9).
///
/// Pure and allocation-free: a render block calls it.
public enum DemoGate {
    // Computed, not stored: the render thread reads them, and a stored static is initialised
    // lazily on its first read.
    static var period: Double { 30 }
    static var silenceStart: Double { 28 }
    static var ramp: Double { 0.01 }

    /// The gain `frame` frames in: 1, ramping to 0 over the 10 ms before second 28, 0, and
    /// ramping back to 1 over the 10 ms before second 30.
    public static func gain(atFrame frame: Int64, sampleRate: Double) -> Float {
        let rate = usable(sampleRate)
        let seconds = Double(position(of: frame, rate: rate)) / rate
        let fadeOut = silenceStart - ramp, fadeIn = period - ramp
        if seconds < fadeOut { return 1 }
        if seconds < silenceStart { return Float((silenceStart - seconds) / ramp) }
        if seconds < fadeIn { return 0 }
        return Float(Swift.min((seconds - fadeIn) / ramp, 1))
    }

    /// Whether the demo is silent `frame` frames in.
    public static func isSilent(atFrame frame: Int64, sampleRate: Double) -> Bool {
        gain(atFrame: frame, sampleRate: sampleRate) == 0
    }

    /// Multiplies `frames` of both channels by the gate, from `frame` on. A block that ends before
    /// the fade-out begins is left as it is.
    public static func apply(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int,
                             fromFrame frame: Int64, sampleRate: Double) {
        guard frames > 0 else { return }
        let rate = usable(sampleRate)
        let fadeBegins = Int64(((silenceStart - ramp) * rate).rounded(.down))
        if position(of: frame, rate: rate) + Int64(frames) <= fadeBegins { return }
        for i in 0..<frames {
            let g = gain(atFrame: frame + Int64(i), sampleRate: rate)
            left[i] *= g
            right[i] *= g
        }
    }

    private static func usable(_ sampleRate: Double) -> Double {
        sampleRate.isFinite && sampleRate >= 1 ? sampleRate : 48_000
    }

    /// Frames into the current thirty-second cycle.
    private static func position(of frame: Int64, rate: Double) -> Int64 {
        let cycle = Swift.max(Int64(period * rate), 1)
        return ((frame % cycle) + cycle) % cycle
    }
}
