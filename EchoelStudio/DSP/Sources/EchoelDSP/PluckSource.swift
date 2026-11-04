import Foundation

/// The delay line a plucked string rings in, allocated once per voice where the voice is made —
/// never on the render thread — and released with it.
final class PluckLine: @unchecked Sendable {
    let capacity: Int
    let samples: UnsafeMutablePointer<Float>

    init(capacity: Int) {
        self.capacity = Swift.max(8, capacity)
        samples = .allocate(capacity: self.capacity)
        samples.initialize(repeating: 0, count: self.capacity)
    }

    deinit {
        samples.deallocate()
    }
}

/// A plucked string (EchoelTools A6): the Karplus-Strong loop. A burst of filtered noise one
/// period long is fed into a delay line one period long; the line feeds itself back through a
/// gentle lowpass, so the high harmonics fall first and the tone settles into the note, as a
/// string does. `character` is the pluck's brightness — how much of the noise's top the pick
/// lets through and how little the loop damps (dark and soft at 0, bright and wiry at 1); the
/// patch's Decay and Sustain are how long the string rings (`ringSeconds`). The noise is seeded with the
/// synth's note counter, so the same song plucks the same strings live and in an export.
/// Nothing here allocates; the line comes from the voice's `init`.
struct PluckSource: Sendable {
    /// The lowest string the line holds — the piano's A0 — so sixteen voices of 32 synths hold
    /// about 3.6 MB at 48 kHz; a lower note sounds an octave (or more) up.
    static let lowestHertz: Float = 27.5
    /// The string's ring time to −60 dB: the patch's Decay and Sustain both lengthen it — a
    /// string has no sustain stage, so the held level the other engines keep becomes ring here.
    static func ringSeconds(decay: Float, sustain: Float) -> Float {
        let d = decay.isFinite ? Swift.min(Swift.max(decay, 0), 10) : 0.2
        let s = sustain.isFinite ? Swift.min(Swift.max(sustain, 0), 1) : 0.7
        return 0.05 + 5 * d + 3 * s
    }
    /// The pick's rise, in samples: a burst that starts at full level is a click on a held note.
    static let pickRise = 24

    private let line: PluckLine
    private var write = 0
    private var previous: Float = 0
    private var exciting = 0
    private var excited = 0
    private var noise: UInt32 = 1
    private var pick: Float = 0
    private var blockIn: Float = 0
    private var blockOut: Float = 0
    /// −60 dB in samples of the output rate, set from the patch before each render.
    var ringSamples: Float = 48_000

    init(sampleRate: Float) {
        let rate = sampleRate.isFinite && sampleRate > 0 ? sampleRate : 48_000
        line = PluckLine(capacity: Int(rate / Self.lowestHertz) + 4)
    }

    /// Silent and empty: a fresh note starts on a still string.
    mutating func reset() {
        line.samples.update(repeating: 0, count: line.capacity)
        write = 0
        previous = 0
        exciting = 0
        excited = 0
        pick = 0
        blockIn = 0
        blockOut = 0
    }

    /// The string is plucked: a period of noise goes in from the next sample, on top of what
    /// still rings. `dt` is the note's increment, `order` the synth's note counter.
    mutating func strike(order: UInt64, dt: Float) {
        guard dt.isFinite, dt > 0 else { return }
        exciting = Int(Self.period(dt, capacity: line.capacity).rounded(.up))
        excited = 0
        // A sequence of its own per note, never zero (xorshift stays at zero).
        noise = UInt32(truncatingIfNeeded: order &* 2_654_435_761 &+ 0x9E37_79B9) | 1
    }

    /// Samples one period lasts at `dt`, an octave up for each octave below the line's lowest.
    @inline(__always)
    static func period(_ dt: Float, capacity: Int) -> Float {
        var period = 1 / dt
        let longest = Float(capacity - 3)
        while period > longest { period *= 0.5 }
        return period
    }

    @inline(__always)
    mutating func next(character c: Float, dt: Float) -> Float {
        let period = Self.period(dt, capacity: line.capacity)
        // The loop's lowpass, (1 − s) + s·z⁻¹: s = ½ is the classic average, dark; near 0 bright.
        let s = 0.5 - 0.45 * c
        // The lowpass delays the loop by s samples; the line makes up the rest of the period.
        let delay = Swift.max(1, period - s)
        let whole = Int(delay)
        let fraction = delay - Float(whole)
        let capacity = line.capacity
        var a = write - whole
        if a < 0 { a += capacity }
        var b = a - 1
        if b < 0 { b += capacity }
        let delayed = line.samples[a] + (line.samples[b] - line.samples[a]) * fraction
        let filtered = (1 - s) * delayed + s * previous
        previous = delayed
        let ring = Swift.min(Swift.max(ringSamples, 1), 1e9)
        let feedback = expf(-6.907_755 * period / ring)
        var input: Float = 0
        if exciting > 0 {
            noise ^= noise << 13
            noise ^= noise >> 17
            noise ^= noise << 5
            let white = Float(Int32(bitPattern: noise)) / 2_147_483_648
            // The pick: how much of the noise's top it lets through.
            let opening = 0.03 + 0.97 * c * c
            pick += opening * (white - pick)
            let rise = Swift.min(Float(excited + 1) / Float(Self.pickRise), 1)
            // A darker pick lets less of the noise through; its level is made up (the one-pole's
            // power gain is a / (2 − a)), so a soft pluck is as loud as a bright one.
            input = pick * rise * (((2 - opening) / opening).squareRoot() * 0.6)
            exciting -= 1
            excited += 1
        }
        var y = input + feedback * filtered
        if !y.isFinite { y = 0 }
        line.samples[write] = y
        write += 1
        if write >= capacity { write = 0 }
        // The noise's own offset would ring as DC: a gentle blocker (≈ 7 Hz at 48 kHz).
        let out = y - blockIn + 0.999 * blockOut
        blockIn = y
        blockOut = out.isFinite ? out : 0
        return blockOut
    }
}
