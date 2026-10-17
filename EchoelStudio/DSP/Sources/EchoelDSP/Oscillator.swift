import Foundation

/// A band-limited oscillator: sine, and saw, square and triangle with PolyBLEP correction
/// at the discontinuities, so high notes do not fold back as inharmonic aliasing.
/// A value type owned by one voice; nothing here allocates.
public struct Oscillator: Sendable {
    public enum Waveform: String, CaseIterable, Codable, Sendable {
        case sine, saw, square, triangle
    }

    public var waveform: Waveform
    /// 0…1, the position in the current cycle.
    public private(set) var phase: Float
    private var triangleState: Float = 0

    public init(waveform: Waveform = .saw, phase: Float = 0) {
        self.waveform = waveform
        self.phase = phase.isFinite ? phase - phase.rounded(.down) : 0
        triangleState = Self.naiveTriangle(self.phase)
    }

    public mutating func reset(phase: Float = 0) {
        self.phase = phase.isFinite ? phase - phase.rounded(.down) : 0
        triangleState = Self.naiveTriangle(self.phase)
    }

    /// The integrator starts where the triangle already is, so there is no DC transient
    /// (starting it at 0 overshot to ~1.6 on high notes).
    static func naiveTriangle(_ t: Float) -> Float {
        t < 0.5 ? 4 * t - 1 : 3 - 4 * t
    }

    /// One sample at `increment` = frequency / sample rate. Non-finite or out-of-range
    /// increments (at or above Nyquist) produce silence rather than garbage.
    @inline(__always)
    public mutating func next(increment dt: Float) -> Float {
        guard dt.isFinite, dt > 0, dt < 0.5 else { return 0 }
        let t = phase
        var out: Float
        switch waveform {
        case .sine:
            out = sinf(2 * Float.pi * t)
        case .saw:
            out = 2 * t - 1 - Self.polyBLEP(t, dt)
        case .square, .triangle:
            out = t < 0.5 ? 1 : -1
            out += Self.polyBLEP(t, dt)
            var shifted = t + 0.5
            if shifted >= 1 { shifted -= 1 }
            out -= Self.polyBLEP(shifted, dt)
            if waveform == .triangle {
                // Leaky integration of the band-limited square gives a band-limited triangle.
                triangleState = dt * 4 * out + (1 - dt) * triangleState
                if !triangleState.isFinite { triangleState = 0 }
                out = triangleState
            }
        }
        phase += dt
        if phase >= 1 { phase -= 1 }
        return out
    }

    /// The two-sample polynomial residual that smooths a unit step at phase 0.
    @inline(__always)
    static func polyBLEP(_ t: Float, _ dt: Float) -> Float {
        if t < dt {
            let x = t / dt
            return x + x - x * x - 1
        } else if t > 1 - dt {
            let x = (t - 1) / dt
            return x * x + x + x + 1
        }
        return 0
    }
}
