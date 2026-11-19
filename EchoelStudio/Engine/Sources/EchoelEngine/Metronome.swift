import Foundation

/// How loud the click and the count-in click play, chosen in decibels on this device
/// (2026-11-19, founder: the click's level adjustable, off by default, a quiet start). Its
/// accented downbeat peaks at the chosen level; the other beats 4.4 dB under it.
public enum ClickLevel {
    /// The levels offered, quietest first.
    public static let choices: [Double] = [-36, -30, -24, -18, -12, -6]
    /// The level a new install starts at: quiet (before 2026-11-19 the click played at −10.5 dB).
    public static let standard: Double = -24

    /// The gain for `decibels`, held between −60 dB and 0 dB; not a number is the standard level.
    public static func gain(decibels: Double) -> Float {
        let db = decibels.isFinite ? Swift.min(Swift.max(decibels, -60), 0) : standard
        return Float(pow(10, db / 20))
    }

    /// "−24 dB", with a true minus sign.
    public static func title(_ decibels: Double) -> String {
        let whole = Int(decibels.rounded())
        return whole < 0 ? "\u{2212}\(-whole) dB" : "\(whole) dB"
    }
}

/// The click: a short decaying sine burst, accented on the downbeat. A value type owned by
/// the render thread; nothing allocates.
public struct Metronome: Sendable {
    public var isEnabled = true
    public var level: Float = ClickLevel.gain(decibels: ClickLevel.standard)

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
