import Foundation

/// A frequency shifter: every frequency in the sound moves by the same number of Hz (not by the
/// same ratio, as a pitch shifter would), so harmonic sounds turn inharmonic — small shifts give
/// a slow beating sway, large ones a metallic, detuned colour. Written new for Echoel Studio 1.0
/// (the earlier app named it and never rendered it, ECHOELTOOLS catalog B9), as a value of
/// settings and a render-thread processor like `Chorus`.
///
/// The method is single-sideband modulation: two chains of four second-order allpasses (the
/// coefficients Olli Niemitalo published for a 90° pair across the audible band) turn each side
/// into an analytic pair, which a quadrature oscillator turns by `shift` Hz. The pair holds 90°
/// within about a degree from ~20 Hz to ~20 kHz at 44.1–48 kHz; the unwanted sideband stays
/// about 45 dB down there. Negative shifts move down. The mix glides in ~10 ms. One bad sample
/// empties the allpasses rather than ringing in them. Owned by the render thread: set `settings`
/// and call `process` from that thread. The state is allocated in `init`; nothing allocates after
/// that.
public final class FrequencyShifter: @unchecked Sendable {
    public struct Settings: Equatable, Codable, Sendable {
        /// The shift in Hz, −1000 … 1000.
        public var shift: Double
        /// Dry 0 … shifted 1.
        public var mix: Double

        public init(shift: Double = 100, mix: Double = 0.5) {
            self.shift = shift
            self.mix = mix
        }

        /// Every value inside its range; non-finite values take the default.
        public var clamped: Settings {
            let base = Settings()
            func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            return Settings(shift: clamp(shift, -1_000...1_000, base.shift), mix: clamp(mix, 0...1, base.mix))
        }
    }

    /// The allpass coefficients of the two chains (each stage uses its square): the in-phase
    /// chain, read one sample late, and the quadrature chain.
    static let inPhase: [Float] = [0.6923878, 0.9360654322959, 0.9882295226860, 0.9987488452737]
    static let quadrature: [Float] = [0.4021921162426, 0.8561710882420, 0.9722909545651, 0.9952884791278]
    static let stages = 4
    /// Per stage: input one and two samples back, output one and two samples back.
    private static let stateSize = 4

    public var settings: Settings {
        didSet { settings = settings.clamped }
    }

    public let sampleRate: Double
    /// Four chains (left in-phase, left quadrature, right in-phase, right quadrature), each with
    /// `stages × stateSize` values.
    private let state: UnsafeMutablePointer<Float>
    private let coefficients: UnsafeMutablePointer<Float>
    private var delayedLeft: Float = 0
    private var delayedRight: Float = 0
    /// The oscillator's phase, 0 ..< 1.
    private var phase: Double = 0
    private var wetNow: Float
    private let glide: Float

    private static var chainLength: Int { stages * stateSize }
    private static var stateCount: Int { 4 * chainLength }

    public init(sampleRate: Double, settings: Settings = Settings()) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        glide = Float(1 - Foundation.exp(-1 / (Compressor.gainGlideSeconds * self.sampleRate)))
        state = .allocate(capacity: FrequencyShifter.stateCount)
        state.initialize(repeating: 0, count: FrequencyShifter.stateCount)
        coefficients = .allocate(capacity: 2 * FrequencyShifter.stages)
        for index in 0..<FrequencyShifter.stages {
            let a = FrequencyShifter.inPhase[index], b = FrequencyShifter.quadrature[index]
            (coefficients + index).initialize(to: a * a)
            (coefficients + FrequencyShifter.stages + index).initialize(to: b * b)
        }
        let start = settings.clamped
        self.settings = start
        wetNow = Float(start.mix)
    }

    deinit {
        state.deallocate()
        coefficients.deallocate()
    }

    /// Empties the allpasses and starts the oscillator over.
    public func reset() {
        state.update(repeating: 0, count: Self.stateCount)
        delayedLeft = 0
        delayedRight = 0
        phase = 0
        wetNow = Float(settings.mix)
    }

    /// One chain of second-order allpasses `y = a²·(x + y₂) − x₂`, run on one sample.
    @inline(__always)
    private func allpasses(_ input: Float, chain index: Int, coefficients offset: Int) -> Float {
        var value = input
        let base = state + index * Self.chainLength
        for stage in 0..<Self.stages {
            let s = base + stage * Self.stateSize
            let output = coefficients[offset + stage] * (value + s[3]) - s[1]
            s[1] = s[0]
            s[0] = value
            s[3] = s[2]
            s[2] = output
            value = output
        }
        return value
    }

    /// Processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        let step = settings.shift / sampleRate
        let wetTarget = Float(settings.mix)
        let quadratureOffset = Self.stages
        var wet = wetNow
        for i in 0..<frames {
            wet = Compressor.glided(wet, toward: wetTarget, by: glide)
            let angle = 2 * Double.pi * phase
            let cosine = Float(Foundation.cos(angle)), sine = Float(Foundation.sin(angle))
            phase += step
            if phase >= 1 { phase -= 1 }
            if phase < 0 { phase += 1 }
            let inLeft = left[i], inRight = right[i]
            guard inLeft.isFinite, inRight.isFinite else {
                reset()
                left[i] = 0
                right[i] = 0
                wet = wetNow
                continue
            }
            let realLeft = delayedLeft
            delayedLeft = allpasses(inLeft, chain: 0, coefficients: 0)
            let imaginaryLeft = allpasses(inLeft, chain: 1, coefficients: quadratureOffset)
            let realRight = delayedRight
            delayedRight = allpasses(inRight, chain: 2, coefficients: 0)
            let imaginaryRight = allpasses(inRight, chain: 3, coefficients: quadratureOffset)
            let shiftedLeft = realLeft * cosine + imaginaryLeft * sine
            let shiftedRight = realRight * cosine + imaginaryRight * sine
            let outLeft = inLeft * (1 - wet) + shiftedLeft * wet
            let outRight = inRight * (1 - wet) + shiftedRight * wet
            guard outLeft.isFinite, outRight.isFinite else {
                reset()
                left[i] = 0
                right[i] = 0
                wet = wetNow
                continue
            }
            left[i] = outLeft
            right[i] = outRight
        }
        wetNow = wet
    }
}
