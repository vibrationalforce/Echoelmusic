import Foundation

/// The sound of one hit of noise as numbers, not as a recording: how many bursts strike and how
/// far apart, how fast the strike falls, the quiet ring under it and how much darker that is, the
/// band, and the air over it. A clap, a snare's wires, a shaker and a hat are settings of these.
///
/// Nothing stores a `HitSound` yet: the fields can still change until a song keeps them.
public struct HitSound: Equatable, Sendable {
    /// How many bursts strike, 1 … 4: one is a single smack, more are hands that do not land together.
    public var bursts: Int
    /// Seconds from one burst to the next, 0.004 … 0.04.
    public var gap: Float
    /// Seconds a burst takes to rise, 0.0002 … 0.05.
    public var attack: Float
    /// The strike: seconds the last burst takes to fall to 1/e, 0.002 … 0.5.
    public var snap: Float
    /// The ring under the strike: seconds it takes to fall to 1/e, 0.005 … 3.
    public var tail: Float
    /// The ring's share of the hit, 0 … 1; the strike has the rest.
    public var tailLevel: Float
    /// How far the ring moves from the band toward the filter's low-pass side, 0 … 1: at 0 the
    /// same band, at 1 the band and what lies under it. A narrow band keeps its peak on that side
    /// too, so there the ring darkens less. The two sides are mixed in a straight line, so a ring
    /// halfway between them is a little quieter.
    public var dark: Float
    /// The band's centre in Hz, 100 … 12 000.
    public var band: Float
    /// How narrow the band is, 0 … 0.95.
    public var focus: Float
    /// The air over the band — noise above `HitVoice.airCorner` — 0 … 1.
    public var air: Float
    /// Seconds the air takes to fall to 1/e after the last burst, 0.001 … 0.2.
    public var airTime: Float
    /// Level as a factor, 0 … 1.
    public var level: Float

    public init(bursts: Int, gap: Float, attack: Float, snap: Float, tail: Float, tailLevel: Float, dark: Float,
                band: Float, focus: Float, air: Float, airTime: Float, level: Float = 1) {
        self.bursts = bursts
        self.gap = gap
        self.attack = attack
        self.snap = snap
        self.tail = tail
        self.tailLevel = tailLevel
        self.dark = dark
        self.band = band
        self.focus = focus
        self.air = air
        self.airTime = airTime
        self.level = level
    }

    /// A hand clap: two bursts 11 ms apart, a strike of 22 ms, a short dark ring. Computed, so the
    /// render thread never waits on a stored value's first use.
    public static var clap: HitSound {
        HitSound(bursts: 2, gap: 0.011, attack: 0.001, snap: 0.022, tail: 0.06, tailLevel: 0.12, dark: 0.9,
                 band: 1_500, focus: 0.45, air: 0.12, airTime: 0.006)
    }

    /// The sound a voice can play: every number finite and inside its range. A number that is
    /// none plays the clap's.
    var playable: HitSound {
        let fallback = HitSound.clap
        return HitSound(bursts: Swift.min(Swift.max(bursts, 1), 4),
                        gap: Self.held(gap, 0.004, 0.04, fallback.gap),
                        attack: Self.held(attack, 0.0002, 0.05, fallback.attack),
                        snap: Self.held(snap, 0.002, 0.5, fallback.snap),
                        tail: Self.held(tail, 0.005, 3, fallback.tail),
                        tailLevel: Self.held(tailLevel, 0, 1, fallback.tailLevel),
                        dark: Self.held(dark, 0, 1, fallback.dark),
                        band: Self.held(band, 100, 12_000, fallback.band),
                        focus: Self.held(focus, 0, 0.95, fallback.focus),
                        air: Self.held(air, 0, 1, fallback.air),
                        airTime: Self.held(airTime, 0.001, 0.2, fallback.airTime),
                        level: Self.held(level, 0, 1, fallback.level))
    }

    private static func held(_ value: Float, _ low: Float, _ high: Float, _ fallback: Float) -> Float {
        value.isFinite ? Swift.min(Swift.max(value, low), high) : fallback
    }
}

/// One voice that plays a `HitSound`: white noise through one band, shaped by a train of bursts.
///
/// Three levels run side by side. The strike rises with every burst; inside the train it falls
/// fast enough to be heard as separate bursts, and after the last one with `snap`. The ring rises
/// with the first burst only and then falls with `tail`; it moves toward the same filter's
/// low-pass side by `dark`, so a hit gets darker as it rings out. The air is the noise above the
/// corner, recharged by every burst and gone soon after with `airTime`. The voice stops once all
/// three are inaudible.
///
/// Band and focus move the colour, not the loudness: the band is levelled to the filter's real
/// noise power, and the noise keeps one density per hertz at every sample rate, so a sound plays
/// alike at 44.1 kHz and at 192 kHz. The velocity sets the loudness and nothing else here. A hit on
/// a voice that still sounds starts it over, as a drum of the kit does: what it played last fades
/// out in `DrumVoice.carrySeconds`. A value of scalars for the render thread: it allocates nothing
/// and takes no lock; its noise runs on from hit to hit, so no two hits draw the same samples.
public struct HitVoice: Sendable {
    /// The air is the noise above this corner, in Hz.
    public static let airCorner: Float = 4_000
    /// The air's share at full `air`: beside a band it is loud for its level. Computed, like the
    /// other constants here, so the render thread never waits on a stored value's first use.
    private static var airShare: Float { 0.5 }
    /// The band, focus and sample rate at which the band plays at its own level — the clap's.
    private static var levelBand: Float { 1_500 }
    private static var levelFocus: Float { 0.45 }
    private static var levelRate: Float { 48_000 }
    /// Under this a part of the hit — strike, ring, air, the carried last sample — is inaudible;
    /// when all are, the voice stops.
    private static var floor: Float { 1e-4 }
    /// Levels this small are rounded to zero, so a long ring never runs on subnormal numbers.
    private static var tiny: Float { 1e-30 }

    public private(set) var isActive = false

    private let sampleRate: Float
    private var filter: SVFilter
    private let airCoefficient: Float
    /// Scales the air's noise so its density per hertz is the same at every sample rate.
    private let airScale: Float
    /// The band's noise power at `levelBand`, `levelFocus` and `levelRate`.
    private let referencePower: Float
    private let carryDecay: Float
    private var airState: Float = 0
    private var noise: UInt32 = 0x9E37_79B9

    private var gain: Float = 0
    /// Levels the band to `referencePower`, whatever its band, focus and sample rate.
    private var bandGain: Float = 1
    private var tailLevel: Float = 0
    private var dark: Float = 0
    private var air: Float = 0
    private var gapFrames = 1
    private var attackFrames = 1
    private var burstFall: Float = 0
    private var snapFall: Float = 0
    private var tailFall: Float = 0
    private var airFall: Float = 0

    private var strike: Float = 0
    private var ring: Float = 0
    private var airLevel: Float = 0
    private var burstsLeft = 0
    private var untilBurst = 0
    private var rise = 0
    /// Frames the ring still rises with the first burst; then it only falls.
    private var ringRiseLeft = 0
    /// What the voice played last, and what of it still fades out after a hit started it over.
    private var lastOutput: Float = 0
    private var carry: Float = 0

    /// The sample rates a voice plays at; any other, and one that is no number, plays at 48 kHz.
    /// The bounds also keep a gap or an attack a countable number of frames.
    public static let sampleRates: ClosedRange<Float> = 8_000...768_000

    public init(sampleRate: Float) {
        let rate: Float = sampleRate.isFinite && Self.sampleRates.contains(sampleRate) ? sampleRate : 48_000
        self.sampleRate = rate
        filter = SVFilter(mode: .bandpass, cutoff: Self.levelBand, resonance: Self.levelFocus, sampleRate: rate)
        airCoefficient = expf(-2 * Float.pi * Self.airCorner / rate)
        airScale = sqrtf(rate / Self.levelRate)
        referencePower = Self.bandPower(band: Self.levelBand, focus: Self.levelFocus, sampleRate: Self.levelRate)
        carryDecay = DrumVoice.coefficient(seconds: DrumVoice.carrySeconds, sampleRate: rate)
    }

    /// The power the filter's band-pass passes of white noise of unit power, at `band` and `focus`
    /// as `SVFilter` holds them (cutoff below Nyquist, resonance 0.01 … 0.95).
    static func bandPower(band: Float, focus: Float, sampleRate: Float) -> Float {
        let normalized = Swift.min(Swift.max(band / sampleRate, 1e-5), 0.49)
        let g = tanf(Float.pi * normalized)
        let k = 1 - Swift.min(Swift.max(focus, 0.01), 0.95)
        return g / (k * (1 + g * k + g * g))
    }

    /// Strikes `sound`. Velocity 0 is no hit. A voice that still sounds starts over.
    public mutating func trigger(_ sound: HitSound, velocity: UInt8) {
        guard velocity > 0 else { return }
        let played = sound.playable
        carry = isActive ? lastOutput : 0
        filter.reset()
        strike = 0
        ring = 0
        airLevel = 0
        let loudness = Float(Swift.min(velocity, 127)) / 127
        gain = loudness * loudness * played.level
        filter.setCutoff(played.band)
        filter.setResonance(played.focus)
        let power = Self.bandPower(band: played.band, focus: played.focus, sampleRate: sampleRate)
        bandGain = sqrtf(referencePower / Swift.max(power, 1e-12))
        gapFrames = Swift.max(1, Int(played.gap * sampleRate))
        attackFrames = Swift.max(1, Int(played.attack * sampleRate))
        // A burst rises over at most half the gap, so bursts that follow stay apart.
        if played.bursts > 1 { attackFrames = Swift.min(attackFrames, Swift.max(1, gapFrames / 2)) }
        // Over the frames between its rise and the next burst, a burst falls to under 1 %.
        burstFall = expf(-5 / Float(Swift.max(1, gapFrames - attackFrames)))
        snapFall = DrumVoice.coefficient(seconds: played.snap, sampleRate: sampleRate)
        tailFall = DrumVoice.coefficient(seconds: played.tail, sampleRate: sampleRate)
        airFall = DrumVoice.coefficient(seconds: played.airTime, sampleRate: sampleRate)
        tailLevel = played.tailLevel
        dark = played.dark
        air = played.air
        burstsLeft = played.bursts
        untilBurst = 0
        rise = 0
        ringRiseLeft = attackFrames
        isActive = true
    }

    public mutating func silence() {
        isActive = false
        strike = 0
        ring = 0
        airLevel = 0
        airState = 0
        burstsLeft = 0
        untilBurst = 0
        rise = 0
        ringRiseLeft = 0
        lastOutput = 0
        carry = 0
        filter.reset()
    }

    /// Adds the sounding hit into `buffer`; the caller clears it first.
    public mutating func render(into buffer: UnsafeMutableBufferPointer<Float>) {
        guard isActive else { return }
        for index in buffer.indices {
            if burstsLeft > 0, untilBurst == 0 {
                burstsLeft -= 1
                untilBurst = gapFrames
                rise = attackFrames
            }
            if untilBurst > 0 { untilBurst -= 1 }
            if rise > 0 {
                strike += (1 - strike) / Float(rise)
                rise -= 1
                airLevel = Swift.max(airLevel, strike)
            } else {
                let inTrain = burstsLeft > 0
                strike *= inTrain ? burstFall : snapFall
                airLevel *= inTrain ? burstFall : airFall
            }
            if ringRiseLeft > 0 {
                ring = Swift.max(ring, strike)
                ringRiseLeft -= 1
            } else {
                ring *= tailFall
            }
            if strike < Self.tiny { strike = 0 }
            if ring < Self.tiny { ring = 0 }
            if airLevel < Self.tiny { airLevel = 0 }
            let white = nextNoise()
            let filtered = filter.processBandAndLow(white)
            let airy = white * airScale
            airState = airCoefficient * airState + (1 - airCoefficient) * airy
            let high = airy - airState
            let struck = filtered.band * (1 - tailLevel) * strike
            let rung = (filtered.band + dark * (filtered.low - filtered.band)) * tailLevel * ring
            let output = ((struck + rung) * bandGain + air * high * airLevel * Self.airShare) * gain + carry
            buffer[index] += output
            lastOutput = output
            carry *= carryDecay
            if burstsLeft == 0, rise == 0,
               strike * (1 - tailLevel) * bandGain < Self.floor,
               ring * tailLevel * bandGain < Self.floor,
               air * Self.airShare * airLevel * airScale < Self.floor,
               Swift.abs(carry) < Self.floor {
                silence()
                return
            }
        }
    }

    private mutating func nextNoise() -> Float {
        noise ^= noise << 13
        noise ^= noise >> 17
        noise ^= noise << 5
        return Float(noise) / Float(UInt32.max) * 2 - 1
    }
}
