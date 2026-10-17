import Foundation

/// Topology-preserving-transform state-variable filter (zero-delay feedback): lowpass,
/// highpass, bandpass and notch from the same two trapezoidal integrators.
///
/// Ported from the legacy `EchoelSVFilter`, keeping what that file learned:
/// - TPT, not Chamberlin — unconditionally stable for any cutoff below Nyquist, so the
///   cutoff needs no musical clamp (the Chamberlin form had to lid it at SR/6).
/// - The cutoff has a floor (~0.5 Hz at 48 kHz): at `g = 0` the state would freeze and
///   lowpass would emit stuck DC forever.
/// - Non-finite state is reset, so one bad sample cannot silence the voice for good.
///
/// A value type owned by one voice on the render thread: set parameters and process from
/// that same thread, so no torn coefficient set can exist. Nothing here allocates.
public struct SVFilter: Sendable {
    public enum Mode: String, CaseIterable, Codable, Sendable {
        case lowpass, highpass, bandpass, notch
    }

    public var mode: Mode
    public private(set) var cutoff: Float
    public private(set) var resonance: Float

    private var sampleRate: Float
    private var g: Float = 0
    private var k: Float = 1
    private var ic1eq: Float = 0
    private var ic2eq: Float = 0

    public init(mode: Mode = .lowpass, cutoff: Float = 2_000, resonance: Float = 0.3, sampleRate: Float = 48_000) {
        self.mode = mode
        self.cutoff = cutoff
        self.resonance = resonance
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        update()
    }

    /// Cutoff in Hz. Non-finite reads as 1 kHz; the value is held just below Nyquist.
    public mutating func setCutoff(_ hz: Float) {
        guard hz != cutoff else { return }
        cutoff = hz
        update()
    }

    /// Resonance 0…1; 0.95 is the ceiling, short of a screaming self-oscillation.
    public mutating func setResonance(_ value: Float) {
        guard value != resonance else { return }
        resonance = value
        update()
    }

    public mutating func setSampleRate(_ rate: Float) {
        let resolved = rate > 0 && rate.isFinite ? rate : 48_000
        guard resolved != sampleRate else { return }
        sampleRate = resolved
        update()
    }

    public mutating func reset() {
        ic1eq = 0
        ic2eq = 0
    }

    @inline(__always)
    public mutating func process(_ input: Float) -> Float {
        let a1 = 1 / (1 + g * (g + k))
        let a2 = g * a1
        let a3 = g * a2
        let v3 = input - ic2eq
        let v1 = a1 * ic1eq + a2 * v3
        let v2 = ic2eq + a2 * ic1eq + a3 * v3
        ic1eq = Self.flush(2 * v1 - ic1eq)
        ic2eq = Self.flush(2 * v2 - ic2eq)
        switch mode {
        case .lowpass: return v2
        case .bandpass: return v1
        case .highpass: return input - k * v1 - v2
        case .notch: return input - k * v1
        }
    }

    private mutating func update() {
        let requested = cutoff.isFinite ? Swift.max(0, cutoff) : 1_000
        let normalized = Swift.min(Swift.max(requested / sampleRate, 1e-5), 0.49)
        g = tanf(Float.pi * normalized)
        let r = resonance.isFinite ? Swift.min(Swift.max(resonance, 0.01), 0.95) : 0.3
        k = 1 - r
    }

    /// Non-finite or denormal state reads as zero; `abs(x) > 1e-25` is already false for NaN,
    /// so `isFinite` is there for ±∞.
    @inline(__always)
    private static func flush(_ x: Float) -> Float {
        (x.isFinite && Swift.abs(x) > 1e-25) ? x : 0
    }
}
