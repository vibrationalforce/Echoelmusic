import Foundation

/// The harmonic-plus-noise model behind `SynthEngine.ddsp` — the core of the earlier app's
/// `EchoelDDSP` (after Engel et al. 2020, "DDSP", without the network: the parameters come from
/// the player), ported as a value type one voice owns (W5, docs/dev/PLAN_ENGINE_RECOVERY).
///
/// Sixty-four sines at integer multiples of the note, each with its own amplitude from one
/// spectral exponent, plus white noise through a bank of eight one-pole filters summed with pink
/// weights. `character` is the one control and travels the axis the earlier engine's coherence
/// travelled (its three live mappings, brightness · harmonicity · noise level, moved together):
/// 0 is dark and breathy — partials fall as 1/n^2.5, six parts tone to four parts noise — 1 is
/// bright and pure — 1/n^0.5, no noise; 0.5 is the earlier engine's natural shape with a
/// little air. Each partial's amplitude glides to its target (~4 ms) and the blend glides too
/// (~2 ms), so a turned Character never steps. Partials from 85 % of Nyquist fade out over a
/// smoothstep and are silent above it, instead of folding back.
///
/// Render thread: nothing here allocates. The state is SIMD vectors inline in the struct; the
/// sine is a quarter-wave polynomial (largest error 3.6e-6, measured against `sin`) instead of
/// `sinf` per partial or a table; the amplitude table is rebuilt only when `character` has
/// moved, at most once per `controlInterval` samples; the constants below are read once in
/// `init`, off the render thread, so their first use never runs a lazy initializer there.
///
/// Two things are deliberately not the earlier engine's. Its "golden-ratio stagger" of the
/// starting phases was linear in the partial number, which for harmonics is one time shift —
/// every partial kept the same phase and the bright end peaked at 5.8 times the level of a
/// sine; a quadratic spread (n² times the golden ratio) brings that to 1.8 (measured over the
/// three characters: zero phases 3.9, linear 5.8, quadratic 1.8). And the amplitudes are
/// normalised to equal power rather than to the fundamental, so Character travels at about one
/// loudness (root mean square 0.48 … 0.69 at a full-level voice) instead of growing with the
/// partial count.
struct DDSPSource: Sendable {
    typealias Bank = SIMD64<Float>
    typealias Bands = SIMD8<Float>

    static let partialCount = 64
    static let bandCount = 8
    /// Samples between taper and table updates: 0.67 ms at 48 kHz.
    static let controlInterval = 32
    /// Per-sample glide of each partial's amplitude toward its target: 0.995 per sample in the
    /// earlier engine, about 4 ms at 48 kHz.
    static let amplitudeGlide: Float = 0.005
    /// Per-sample glide of the harmonic/noise blend: the earlier engine's 0.01, about 2 ms.
    static let blendGlide: Float = 0.01
    /// A blend this close to its target takes the target, so a noise level turned to zero
    /// reaches exactly zero instead of decaying through denormals.
    static let blendSnap: Float = 1e-6
    /// Character has to move this far before the amplitude table is rebuilt.
    static let characterStep: Float = 1e-4

    /// The spectral exponent at Character 0 and how far it falls by Character 1: 1/n^2.5 (the
    /// earlier engine's dark shape at brightness 0) to 1/n^0.5 (its natural shape at brightness 1).
    static let exponentAtZero: Float = 2.5
    static let exponentSpan: Float = 2
    /// Harmonicity — the tone's share of the blend — at Character 0 and its rise by 1.
    static let harmonicityAtZero: Float = 0.6
    static let harmonicitySpan: Float = 0.38
    /// The noise level at Character 0; it falls to nothing at 1.
    static let noiseAtZero: Float = 0.8

    /// The anti-alias band in cycles per sample: a partial fades from 85 % of Nyquist and is
    /// silent at Nyquist (the earlier engine's band).
    static let taperStart: Float = 0.425
    static let taperScale: Float = 1 / 0.075

    /// The partial numbers 1 … 64, their base-2 logarithms (so an amplitude is one `exp2f`), and
    /// the starting phase of each in cycles: the fraction of n² times the golden ratio.
    static let ratios: Bank = {
        var v = Bank()
        for i in 0..<partialCount { v[i] = Float(i + 1) }
        return v
    }()
    static let log2Ratios: Bank = {
        var v = Bank()
        for i in 0..<partialCount { v[i] = log2f(Float(i + 1)) }
        return v
    }()
    static let startPhases: Bank = {
        let golden: Double = 0.618_033_988_75
        var v = Bank()
        for i in 0..<partialCount {
            let n = Double(i + 1)
            let turns = n * n * golden
            v[i] = Float(turns - turns.rounded(.down))
        }
        return v
    }()

    /// The noise bank: eight one-pole lowpasses with cutoffs an octave apart, from 1/128 of
    /// Nyquist up to Nyquist (187 Hz … 24 kHz at 48 kHz), each summed with a weight proportional
    /// to 1/√cutoff — equal power per octave, pink — and scaled so the bank's output has the root
    /// mean square of a full-level sine (1/√2) for white noise uniform in −1 … 1. The pole of a
    /// one-pole at a fraction f of Nyquist is e^(−πf), whatever the sample rate, so the bank needs
    /// none (as the earlier engine's bank did not). The scale is exact: two one-poles fed the
    /// same white noise of variance σ² have the cross-power σ²(1−a)(1−b)/(1−ab).
    static let bandPoles: Bands = {
        var v = Bands()
        for k in 0..<bandCount { v[k] = expf(-Float.pi * exp2f(Float(k - (bandCount - 1)))) }
        return v
    }()
    static let bandGains: Bands = 1 - bandPoles
    static let bandWeights: Bands = {
        var raw = Bands()
        for k in 0..<bandCount { raw[k] = 1 / exp2f(Float(k - (bandCount - 1))).squareRoot() }
        var power: Double = 0
        for j in 0..<bandCount {
            for k in 0..<bandCount {
                let a = Double(bandPoles[j]), b = Double(bandPoles[k])
                power += Double(raw[j] * raw[k]) * (1 - a) * (1 - b) / (1 - a * b)
            }
        }
        power /= 3  // the variance of white noise uniform in −1 … 1
        let scale = power > 0 ? Float((0.5 / power).squareRoot()) : 1
        return raw * scale
    }()

    // The sine polynomial: the Taylor series of sin(πu/2) to the ninth order, on 0 … 1.
    static let c1: Float = 1.570_796_3
    static let c3: Float = -0.645_964_09
    static let c5: Float = 0.079_692_626
    static let c7: Float = -0.004_681_754_1
    static let c9: Float = 0.000_160_441_18

    /// Each partial's position in its cycle, 0 ..< 1.
    private var phases: Bank
    /// Each partial's amplitude now, gliding toward `target`.
    private var amplitudes: Bank
    /// The amplitude table for `tableCharacter`, normalised to unit power.
    private var target: Bank
    /// 1 below the anti-alias band, 0 from Nyquist up, for the increment of the last update.
    private var taper: Bank
    /// The one-pole states of the noise bank.
    private var bands: Bands
    /// The harmonic/noise blend now, gliding; −1 until the first sample seeds it.
    private var harmonicity: Float = -1
    private var noiseLevel: Float = -1
    /// The character `target` was built for; −1 until the first sample builds one.
    private var tableCharacter: Float = -1
    private var controlCountdown = 0
    /// xorshift32 state for the white noise; never zero.
    private var prng: UInt32 = 0x1234_5678

    init() {
        phases = Self.startPhases
        amplitudes = Bank(repeating: 0)
        target = Bank(repeating: 0)
        taper = Bank(repeating: 1)
        bands = Bands(repeating: 0)
        // The remaining constants are read here, off the render thread, so the first `next`
        // finds them initialised (see the type's note).
        _ = Self.ratios
        _ = Self.log2Ratios
        _ = Self.bandPoles
        _ = Self.bandGains
        _ = Self.bandWeights
    }

    /// A fresh note on a silent voice: partials back at their starting phases and at nothing,
    /// so they glide in; the blend and the table are built again from the first sample.
    mutating func reset() {
        phases = Self.startPhases
        amplitudes = Bank(repeating: 0)
        bands = Bands(repeating: 0)
        harmonicity = -1
        noiseLevel = -1
        tableCharacter = -1
        controlCountdown = 0
    }

    /// Every note gets its own noise: the synth's note counter, spread over the 32 bits by a
    /// Fibonacci hash so two voices never share a sequence (shared noise adds coherently across
    /// a chord). xorshift32 needs a non-zero state.
    mutating func reseed(_ order: UInt64) {
        let mixed = UInt32(truncatingIfNeeded: (order &* 0x9E37_79B9_7F4A_7C15) >> 32)
        prng = mixed == 0 ? 0x1234_5678 : mixed
    }

    /// One sample. `dt` is the note's increment in cycles per sample (finite, 0 < dt < 0.5, as
    /// `EngineSource` guarantees); `character` is 0 … 1.
    @inline(__always)
    mutating func next(character: Float, dt: Float) -> Float {
        if controlCountdown <= 0 {
            controlCountdown = Self.controlInterval
            updateTaper(dt: dt)
            if Swift.abs(character - tableCharacter) > Self.characterStep {
                rebuildTable(character: character)
            }
        }
        controlCountdown -= 1

        let harmonicityTarget = Self.harmonicityAtZero + Self.harmonicitySpan * character
        let noiseTarget = Self.noiseAtZero * (1 - character)
        if harmonicity < 0 {
            harmonicity = harmonicityTarget
            noiseLevel = noiseTarget
        } else {
            harmonicity += (harmonicityTarget - harmonicity) * Self.blendGlide
            noiseLevel += (noiseTarget - noiseLevel) * Self.blendGlide
            if Swift.abs(harmonicity - harmonicityTarget) < Self.blendSnap { harmonicity = harmonicityTarget }
            if Swift.abs(noiseLevel - noiseTarget) < Self.blendSnap { noiseLevel = noiseTarget }
        }

        phases = phases + Self.ratios * dt
        phases = phases - phases.rounded(.down)
        amplitudes = amplitudes + (target - amplitudes) * Self.amplitudeGlide
        let harmonic = (Self.sine(phases) * (amplitudes * taper)).sum()

        let white = nextWhite()
        bands = bands * Self.bandPoles + Self.bandGains * white
        let noise = (bands * Self.bandWeights).sum()

        return harmonic * harmonicity + noise * noiseLevel * (1 - harmonicity)
    }

    /// The anti-alias weights for this increment: 1 − smoothstep across the band.
    @inline(__always)
    private mutating func updateTaper(dt: Float) {
        let position = (Self.ratios * dt - Self.taperStart) * Self.taperScale
        let t = pointwiseMin(pointwiseMax(position, Bank(repeating: 0)), Bank(repeating: 1))
        taper = 1 - t * t * (3 - t * 2)
    }

    /// The amplitude of partial n is n^−p for the exponent `character` chooses, the set
    /// normalised to unit power. Sixty-four `exp2f` — only when Character has moved.
    private mutating func rebuildTable(character: Float) {
        tableCharacter = character
        let exponent = Self.exponentAtZero - Self.exponentSpan * character
        var table = Bank()
        var power: Float = 0
        for i in 0..<Self.partialCount {
            let a = exp2f(-exponent * Self.log2Ratios[i])
            table[i] = a
            power += a * a
        }
        target = power > 0 ? table / power.squareRoot() : table
    }

    /// sin(2πt) for each lane of `t`, t in 0 ..< 1: the cycle folded onto a quarter wave and the
    /// polynomial applied there, with the sign from the half.
    @inline(__always)
    static func sine(_ t: Bank) -> Bank {
        let x = t - 0.5                         // sin(2πt) = −sin(2πx)
        let z = pointwiseMax(x, -x)             // sin(2πx) = sign(x) · sin(2πz)
        let d = z - 0.25
        let w = 0.25 - pointwiseMax(d, -d)      // sin(2πz) = sin(2πw), w in 0 … 0.25
        let u = w * 4                           // sin(2πw) = sin(πu/2), u in 0 … 1
        let u2 = u * u
        var q = u2 * c9 + c7
        q = q * u2 + c5
        q = q * u2 + c3
        q = q * u2 + c1
        q = q * u
        return q.replacing(with: -q, where: x .>= 0)
    }

    /// White noise in −1 … 1: xorshift32 (Marsaglia 2003), no locks, no calls.
    @inline(__always)
    private mutating func nextWhite() -> Float {
        prng ^= prng << 13
        prng ^= prng >> 17
        prng ^= prng << 5
        return Float(Int32(bitPattern: prng)) / Float(Int32.max)
    }
}
