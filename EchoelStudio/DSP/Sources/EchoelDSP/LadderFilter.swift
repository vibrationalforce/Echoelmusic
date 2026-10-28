import Foundation

/// A four-pole lowpass in the shape of the Moog ladder (EchoelTools A2): four one-pole stages
/// in series with the last fed back through a soft clip, so resonance rings and drives warmly
/// instead of the state-variable filter's clean peak. The passband loses level as resonance
/// rises, as the analogue one does; a gentle make-up keeps it near unity. Value type owned by
/// one voice; nothing here allocates. Same calls as `SVFilter`, so a voice swaps one for the other.
public struct LadderFilter: Sendable {
    public private(set) var cutoff: Float
    public private(set) var resonance: Float
    private var sampleRate: Float
    private var g: Float = 0
    private var k: Float = 0
    private var s1: Float = 0, s2: Float = 0, s3: Float = 0, s4: Float = 0

    public init(cutoff: Float = 2_000, resonance: Float = 0.3, sampleRate: Float = 48_000) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        self.cutoff = 2_000
        self.resonance = 0.3
        setCutoff(cutoff)
        setResonance(resonance)
    }

    public mutating func setCutoff(_ hz: Float) {
        let top = sampleRate * 0.45
        cutoff = hz.isFinite ? Swift.min(Swift.max(hz, 10), top) : 2_000
        g = 1 - expf(-2 * Float.pi * cutoff / sampleRate)
    }

    /// 0 … 0.95 of the way to self-oscillation.
    public mutating func setResonance(_ value: Float) {
        resonance = value.isFinite ? Swift.min(Swift.max(value, 0), 0.95) : 0.3
        k = 4 * resonance
    }

    public mutating func reset() {
        s1 = 0; s2 = 0; s3 = 0; s4 = 0
    }

    @inline(__always)
    public mutating func process(_ input: Float) -> Float {
        let x = Self.softClip(input - k * s4)
        s1 += g * (x - s1)
        s2 += g * (s1 - s2)
        s3 += g * (s2 - s3)
        s4 += g * (s3 - s4)
        guard s4.isFinite else {
            reset()
            return 0
        }
        return s4 * (1 + k * 0.5)
    }

    /// A rational tanh: smooth, bounded to ±1, cheap.
    @inline(__always)
    static func softClip(_ x: Float) -> Float {
        let c = Swift.min(Swift.max(x, -3), 3)
        return c * (27 + c * c) / (27 + 9 * c * c)
    }
}
