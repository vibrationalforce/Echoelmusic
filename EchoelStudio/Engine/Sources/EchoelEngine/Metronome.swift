import Foundation

/// The click: a short decaying sine burst, accented on the downbeat. A value type owned by
/// the render thread; nothing allocates.
public struct Metronome: Sendable {
    public var isEnabled = true
    public var level: Float = 0.3

    private var phase: Float = 0
    private var increment: Float = 0
    private var amplitude: Float = 0
    private var remaining = 0
    private let sampleRate: Float
    private let decay: Float

    public init(sampleRate: Float = 48_000) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        // About −60 dB over the 30 ms burst.
        decay = expf(logf(0.001) / (0.03 * self.sampleRate))
    }

    public mutating func trigger(accent: Bool) {
        guard isEnabled else { return }
        phase = 0
        increment = (accent ? 1_760 : 1_100) / sampleRate
        amplitude = accent ? 1 : 0.6
        remaining = Int(0.03 * sampleRate)
    }

    /// Adds the click into both channels.
    @inline(__always)
    public mutating func render(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, range: Range<Int>) {
        guard remaining > 0 else { return }
        for i in range {
            guard remaining > 0 else { return }
            let s = sinf(2 * Float.pi * phase) * amplitude * level
            left[i] += s
            right[i] += s
            phase += increment
            if phase >= 1 { phase -= 1 }
            amplitude *= decay
            remaining -= 1
        }
    }
}
