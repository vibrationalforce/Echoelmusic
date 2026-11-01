import Foundation

/// A sung vowel as the vocal tract shapes it: five formants, each a centre frequency and a
/// bandwidth in hertz (lanes 0 … 4; the rest unused).
struct Vowel: Sendable, Equatable {
    var frequencies: SIMD8<Float>
    var bandwidths: SIMD8<Float>

    init(_ frequencies: (Float, Float, Float, Float, Float), _ bandwidths: (Float, Float, Float, Float, Float)) {
        self.frequencies = SIMD8(frequencies.0, frequencies.1, frequencies.2, frequencies.3, frequencies.4, 0, 0, 0)
        self.bandwidths = SIMD8(bandwidths.0, bandwidths.1, bandwidths.2, bandwidths.3, bandwidths.4, 0, 0, 0)
    }

    init(frequencies: SIMD8<Float>, bandwidths: SIMD8<Float>) {
        self.frequencies = frequencies
        self.bandwidths = bandwidths
    }

    /// The vowels in the order `character` walks them, from dark to bright — oo, oh, ah, eh, ee —
    /// the order in which the second formant rises (from the back of the mouth to the front). The
    /// values are the widely used formant tables of sung vowels, a bass's and a soprano's (as in the
    /// Csound manual's formant table).
    static let bass: (Vowel, Vowel, Vowel, Vowel, Vowel) = (
        Vowel((350, 600, 2_400, 2_675, 2_950), (40, 80, 100, 120, 120)),       // oo
        Vowel((400, 750, 2_400, 2_600, 2_900), (40, 80, 100, 120, 120)),       // oh
        Vowel((600, 1_040, 2_250, 2_450, 2_750), (60, 70, 110, 120, 130)),     // ah
        Vowel((400, 1_620, 2_400, 2_800, 3_100), (40, 80, 100, 120, 120)),     // eh
        Vowel((250, 1_750, 2_600, 3_050, 3_340), (60, 90, 100, 120, 120))      // ee
    )
    static let soprano: (Vowel, Vowel, Vowel, Vowel, Vowel) = (
        Vowel((325, 700, 2_700, 3_800, 4_950), (50, 60, 170, 180, 200)),       // oo
        Vowel((450, 800, 2_830, 3_800, 4_950), (70, 80, 100, 130, 135)),       // oh
        Vowel((800, 1_150, 2_900, 3_900, 4_950), (80, 90, 120, 130, 140)),     // ah
        Vowel((350, 2_000, 2_800, 3_600, 4_950), (60, 100, 120, 150, 200)),    // eh
        Vowel((270, 2_140, 2_950, 3_900, 4_950), (60, 90, 100, 120, 120))      // ee
    )

    /// The vowel at `character` (0 oo … 0.25 oh … 0.5 ah … 0.75 eh … 1 ee) for a voice at
    /// `register` (0 a bass's, 1 a soprano's): straight lines between the table's vowels, so the
    /// formants glide as character moves. Arithmetic only.
    static func at(character: Float, register: Float) -> Vowel {
        let c = character.isFinite ? Swift.min(Swift.max(character, 0), 1) : 0.5
        let r = register.isFinite ? Swift.min(Swift.max(register, 0), 1) : 0.5
        let low = interpolate(bass, c), high = interpolate(soprano, c)
        return Vowel(frequencies: low.frequencies + (high.frequencies - low.frequencies) * r,
                     bandwidths: low.bandwidths + (high.bandwidths - low.bandwidths) * r)
    }

    private static func interpolate(_ table: (Vowel, Vowel, Vowel, Vowel, Vowel), _ character: Float) -> Vowel {
        let position = character * 4
        let (a, b, t): (Vowel, Vowel, Float) = switch position {
        case ..<1: (table.0, table.1, position)
        case ..<2: (table.1, table.2, position - 1)
        case ..<3: (table.2, table.3, position - 2)
        default: (table.3, table.4, Swift.min(position - 3, 1))
        }
        return Vowel(frequencies: a.frequencies + (b.frequencies - a.frequencies) * t,
                     bandwidths: a.bandwidths + (b.bandwidths - a.bandwidths) * t)
    }
}

/// The vocal tract: five formant resonators in series — the cascade of Klatt's formant synthesizer
/// (1980) — so a vowel's spectrum, its peaks and the valleys between them, comes out of the formant
/// frequencies alone. Each resonator has unity gain at 0 Hz. Arithmetic only, nothing allocates.
struct VocalTract: Sendable {
    /// Per resonator: y = input · x + first · y₋₁ + second · y₋₂.
    private var input = SIMD8<Float>(repeating: 1)
    private var first = SIMD8<Float>.zero
    private var second = SIMD8<Float>.zero
    private var y1 = SIMD8<Float>.zero
    private var y2 = SIMD8<Float>.zero

    mutating func reset() {
        y1 = .zero
        y2 = .zero
    }

    /// Tunes the five resonators to `vowel` at `sampleRate`. A formant at or above 45 % of the rate
    /// passes nothing of its own: it would fold back. An `expf` and a `cosf` per formant.
    mutating func tune(to vowel: Vowel, sampleRate: Float) {
        guard sampleRate.isFinite, sampleRate > 0 else { return }
        let period = 1 / sampleRate
        for k in 0..<5 {
            let frequency = vowel.frequencies[k], bandwidth = vowel.bandwidths[k]
            guard frequency.isFinite, bandwidth.isFinite, frequency > 0, bandwidth > 0,
                  frequency < 0.45 * sampleRate else {
                input[k] = 1
                first[k] = 0
                second[k] = 0
                continue
            }
            let radius = expf(-Float.pi * bandwidth * period)
            second[k] = -radius * radius
            first[k] = 2 * radius * cosf(2 * Float.pi * frequency * period)
            input[k] = 1 - first[k] - second[k]
        }
    }

    /// One sample through the five resonators in turn.
    @inline(__always)
    mutating func process(_ x: Float) -> Float {
        var signal = x
        for k in 0..<5 {
            let y = input[k] * signal + first[k] * y1[k] + second[k] * y2[k]
            y2[k] = y1[k]
            y1[k] = y
            signal = y
        }
        return signal
    }

    /// The mean power a full-scale sawtooth at `hertz` keeps through the tract: each harmonic's
    /// power, 2 / (π² n²), times the tract's gain there, up to 48 harmonics below 6 kHz. Without the
    /// tract it is the sawtooth's own 1/3. Two trigonometric calls; the harmonics turn by rotation.
    func sawPower(at hertz: Float, sampleRate: Float) -> Float {
        guard hertz.isFinite, hertz > 0, sampleRate.isFinite, sampleRate > 0 else { return 0 }
        let step = 2 * Float.pi * hertz / sampleRate
        let turnCos = cosf(step), turnSin = sinf(step)
        var cosine = turnCos, sine = turnSin
        let limit = Swift.min(0.45 * sampleRate, 6_000)
        var total: Float = 0
        var n: Float = 1
        while n <= 48, n * hertz < limit {
            let cosine2 = 2 * cosine * cosine - 1, sine2 = 2 * sine * cosine
            var gain: Float = 1
            for k in 0..<5 {
                let re = 1 - first[k] * cosine - second[k] * cosine2
                let im = first[k] * sine + second[k] * sine2
                gain *= input[k] * input[k] / Swift.max(re * re + im * im, 1e-12)
            }
            total += gain / (n * n)
            (cosine, sine) = (cosine * turnCos - sine * turnSin, sine * turnCos + cosine * turnSin)
            n += 1
        }
        return total * 2 / (Float.pi * Float.pi)
    }
}

/// The choir engine's voice (VOX, founder 2026-11-01): a small ensemble on one note — three singers,
/// each a band-limited sawtooth a few cents from the others with a slow vibrato of its own, and a
/// breath of noise — through one vocal tract (`VocalTract`). `character` walks the vowels from dark
/// to bright, oo · oh · ah · eh · ee; the note's register moves the formants from a bass's to a
/// soprano's as it rises (A2 to C5). A synthesized vowel, not a recording and not anyone's voice.
///
/// A value type a synth voice owns; nothing allocates. The noise takes its sequence from the note
/// counter, so an export renders the same breath every time.
struct ChoirSource: Sendable {
    /// The singers' offsets from the note, in cents, their vibrato rates in hertz, and the vibrato's
    /// depth in cents: a choir's spread, not a chorus effect.
    static let detunes = SIMD4<Float>(-8, 0, 7, 0)
    static let vibratoRates = SIMD4<Float>(5.1, 5.6, 4.7, 0)
    static let vibratoCents: Float = 9
    /// The breath: noise at this level against the singers' sum.
    static let breath: Float = 0.04
    /// The register's ends: a bass's formants at A2, a soprano's at C5.
    static let lowestNote: Float = 45
    static let highestNote: Float = 72
    /// Samples between two control updates: the singers' pitches and, when character or the pitch
    /// moved, the tract.
    static let controlInterval = 32
    /// Character has to move this far before the tract is tuned again.
    static let characterStep: Float = 1e-4
    /// The level the choir sings at before the voice's envelope, as a root mean square: a vowel, a
    /// register and a note all come out alike, as loud as the other engines (`SynthEngineTests`).
    /// A note whose harmonic falls on a narrow formant would otherwise ring twenty times louder
    /// than one whose harmonics fall between them.
    static let level: Float = 0.35
    /// How far character or the pitch move before the level is worked out again, and how fast it
    /// glides there.
    static let levelCharacterStep: Float = 0.02
    static let levelPitchStep: Float = 0.03
    static let levelGlideSeconds: Float = 0.01

    private var s0 = Oscillator(waveform: .saw, phase: 0)
    private var s1 = Oscillator(waveform: .saw, phase: 0.37)
    private var s2 = Oscillator(waveform: .saw, phase: 0.71)
    private var vibratoPhases = SIMD4<Float>(0, 0.33, 0.66, 0)
    private var ratios = SIMD4<Float>(repeating: 1)
    private var tract = VocalTract()
    private var tunedCharacter: Float = .nan
    private var tunedHertz: Float = .nan
    /// The character and pitch the level was worked out for, the gain now and where it goes.
    private var levelCharacter: Float = .nan
    private var levelHertz: Float = .nan
    private var gain: Float = 0
    private var gainTarget: Float = 0
    private var gainPole: Float = 0
    private var register: Float = 0.5
    private var sampleRate: Float = 48_000
    private var countdown = 0
    private var noise: UInt32 = 0x1234_5678

    mutating func reset() {
        s0.reset(phase: 0)
        s1.reset(phase: 0.37)
        s2.reset(phase: 0.71)
        vibratoPhases = SIMD4<Float>(0, 0.33, 0.66, 0)
        ratios = SIMD4<Float>(repeating: 1)
        tract.reset()
        tunedCharacter = .nan
        tunedHertz = .nan
        levelCharacter = .nan
        levelHertz = .nan
        gain = 0
        gainTarget = 0
        countdown = 0
    }

    /// A key struck this voice: the register of its note, the rate the voice plays at, and a noise
    /// sequence of its own (`order` is the synth's note counter).
    mutating func strike(pitch: UInt8, sampleRate rate: Float, order: UInt64) {
        let note = Float(Swift.min(pitch, 127))
        register = Swift.min(Swift.max((note - Self.lowestNote) / (Self.highestNote - Self.lowestNote), 0), 1)
        if rate.isFinite, rate > 0 { sampleRate = rate }
        gainPole = expf(-1 / (Self.levelGlideSeconds * sampleRate))
        noise = UInt32(truncatingIfNeeded: order &* 2_654_435_761) | 1
        tunedCharacter = .nan
        countdown = 0
    }

    /// One sample; `dt` is the note's frequency over the sample rate, bend and vibrato included.
    @inline(__always)
    mutating func next(character: Float, dt: Float) -> Float {
        guard dt.isFinite, dt > 0, dt < 0.5 else { return 0 }
        if countdown <= 0 {
            control(character: character, dt: dt)
            countdown = Self.controlInterval
        }
        countdown -= 1
        var singers = s0.next(increment: dt * ratios[0])
        singers += s1.next(increment: dt * ratios[1])
        singers += s2.next(increment: dt * ratios[2])
        noise = noise &* 1_664_525 &+ 1_013_904_223
        let breath = Float(Int32(bitPattern: noise)) / Float(Int32.max)
        gain = gainTarget + (gain - gainTarget) * gainPole
        let out = tract.process(singers * (1 / 3) + breath * Self.breath) * gain
        return out.isFinite ? out : 0
    }

    /// The singers' pitch ratios for the next stretch, and the tract when the vowel or the pitch moved.
    private mutating func control(character: Float, dt: Float) {
        let step = Float(Self.controlInterval) / sampleRate
        vibratoPhases += Self.vibratoRates * step
        vibratoPhases -= vibratoPhases.rounded(.down)
        for k in 0..<3 {
            let cents = Self.detunes[k] + Self.vibratoCents * sinf(2 * Float.pi * vibratoPhases[k])
            ratios[k] = exp2f(cents / 1_200)
        }
        let c = character.isFinite ? Swift.min(Swift.max(character, 0), 1) : 0.5
        let hertz = dt * sampleRate
        let moved = !(Swift.abs(c - tunedCharacter) < Self.characterStep)
            || !(Swift.abs(hertz - tunedHertz) < tunedHertz * 0.03)
        guard moved else { return }
        var vowel = Vowel.at(character: c, register: register)
        // A high note above the first formant has nothing there to ring: singers raise the formant
        // to the note, and so does the tract.
        vowel.frequencies[0] = Swift.max(vowel.frequencies[0], hertz * 1.05)
        tract.tune(to: vowel, sampleRate: sampleRate)
        tunedCharacter = c
        tunedHertz = hertz
        let isFirst = levelCharacter.isNaN
        guard isFirst || !(Swift.abs(c - levelCharacter) < Self.levelCharacterStep)
            || !(Swift.abs(hertz - levelHertz) < levelHertz * Self.levelPitchStep) else { return }
        // Three singers out of step add their power: the sum over three keeps a third of one saw's.
        let power = tract.sawPower(at: hertz, sampleRate: sampleRate) / 3
        gainTarget = Swift.min(Swift.max(Self.level / Swift.max(power, 1e-9).squareRoot(), 0.01), 100)
        if isFirst { gain = gainTarget }
        levelCharacter = c
        levelHertz = hertz
    }
}
