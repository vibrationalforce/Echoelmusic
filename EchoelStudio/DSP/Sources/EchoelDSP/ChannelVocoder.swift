import Foundation

/// A channel vocoder (VA-5): the modulator — a voice — is split into bands, each band's level is
/// followed, and the same bands of the carrier are played at those levels, so the carrier speaks
/// or sings with the modulator's articulation and keeps its own pitch and colour. The carrier is
/// a buffer the caller passes: the avatar's voice (`AvatarSource`), a noise, a synth, any signal.
/// Written new for Echoel Studio; no audio vocoder existed in the earlier app.
///
/// **Bands.** 8 to 32, log-spaced from `lowestHertz` (100 Hz) to `highestHertz` (8 kHz):
/// band n of N sits at 100 · 80^(n / (N − 1)) Hz exactly (`centre(ofBand:bandCount:)`). Each band is
/// two zero-delay-feedback band-passes in a row (`ZDFStage`, unity peak), on the modulator and on
/// the carrier alike, with one Q for all bands of a count, chosen so that two neighbours meet 3 dB
/// down (`quality(bandCount:)`: Q 1.01 at 8 bands, 2.19 at 16, 4.55 at 32).
///
/// **Followers.** A band's level is read from its second band-pass's three outputs: the band output
/// squared, less the low-pass output times the high-pass output. For any one tone that product is
/// minus the square of the band output's quarter-cycle partner — the high-pass is then the
/// low-pass turned over and (f/f₀)² as large, on the filter's warped axis — so a steady tone reads
/// a steady level at any frequency, with no ripple to smooth away and nothing extra from the skirts,
/// and any sound reads its band's power on average. The level rises with `attack` and falls with
/// `release`, both one-pole time constants in seconds: a tone reaches 1 − 1/e of its level in
/// `attack`, and falls to 1/e of it in `release` once it stops.
///
/// **Output.** Each carrier band is played at its modulator band's level, scaled by the share of
/// white noise the band passes, so that a white carrier as loud as a full-scale sine
/// (`carrierReference`) gives back the modulator's band levels at any band count, and about its
/// level: on the tests' whispered vowel 0.5 to 0.7 dB under it with the attack as long as the
/// release, and 2 to 3 dB over it with the default fast attack, which rides a noisy band's peaks.
/// A quieter carrier gives a quieter vocoder, in proportion, and a carrier whose power lies where
/// the voice's does gives a louder one (a full-scale sawtooth at 110 Hz, 11 dB over on that
/// whisper): the carrier's colour stays in the sound, as in any channel vocoder.
///
/// Two pitched signals follow each other less closely in narrow bands: a band that holds no
/// harmonic of the voice or of the carrier hears only its neighbours' skirts. A voiced "ah" at
/// 150 Hz on a sawtooth at 110 Hz, read through the bands themselves, follows with r = 0.99 at
/// 8 bands, 0.93 at 16 and 0.87 at 32 (measured on the tests' signals), so fewer bands suit a
/// pitched voice on a pitched carrier.
///
/// Every other band is turned over: two neighbours meet 131° apart in phase, so they nearly cancel
/// where they meet, and the bank would sum 7 to 13 dB below flat over a band; turned over, they meet
/// 49° apart and it sums within about 1.5 dB of flat, 0.4 to 0.8 dB above it (both worked out from
/// the bands' responses at 48 kHz). `shift` moves the carrier's bands by semitones against the
/// modulator's — the output's formants up or down — gliding there. A carrier alone never sounds; a
/// band the carrier leaves empty stays empty. A band whose centre lies above 45 % of the sample rate
/// (only at rates under 17.8 kHz) stays silent rather than crowd the others under Nyquist.
///
/// **Sibilance.** The modulator's own sound above `crossover` (two Butterworth `ZDFStage` high-passes
/// in a row, 24 dB per octave) is added at the `sibilance` level, so an "s" or a "t" stays one
/// whatever the carrier holds.
///
/// **A new band count** crosses over: the new bands run unheard for `warmSeconds` while their
/// filters and followers settle on the modulator, then take over over `fadeSeconds`, at equal power
/// (cosine and sine): two layouts of bands meet each other at every phase across the spectrum, and a
/// straight-line crossing would lose 3 dB halfway. A count asked for meanwhile follows once the
/// crossing is done. `bandCount` is the count heard now.
///
/// Silence in is silence out, sample for sample, and the output reaches exact silence once the
/// bands have rung out after the modulator stops. No look-ahead: the latency is 0 — a band delays
/// what it passes by its own group delay, as any band-pass does: 2Q / (πf) at its centre, 14 ms at
/// 100 Hz and 1.4 ms at 1 kHz with 16 bands. A sample that is not a number, in either input,
/// empties the vocoder and comes out as silence. One channel: a stereo voice is summed by the
/// caller, or each side has its own vocoder. Owned by the render thread: set `settings` and call
/// `process` from that thread. Everything is allocated in `init`.
///
/// **Cost**, derived from the code, not measured on a device: per sample and band, four `ZDFStage`
/// steps, a square root and about twenty operations more, about 120 in all — about 3 900 a sample at
/// 32 bands, twice that while a band count crosses over.
public final class ChannelVocoder: @unchecked Sendable {
    public struct Settings: Equatable, Sendable {
        /// Bands, within `ChannelVocoder.bandCounts`.
        public var bandCount: Int
        /// Seconds a band's level takes to rise, as a time constant, within `attacks`.
        public var attack: Double
        /// Seconds a band's level takes to fall, as a time constant, within `releases`.
        public var release: Double
        /// Semitones the carrier's bands sit above (or below) the modulator's, within `shifts`.
        public var shift: Double
        /// The level of the modulator's own highs above `crossover`, 0 … 1.
        public var sibilance: Double
        /// Hertz above which the modulator's own sound passes, within `crossovers`.
        public var crossover: Double

        public static let attacks: ClosedRange<Double> = 0.000_5 ... 0.5
        public static let releases: ClosedRange<Double> = 0.002 ... 2
        public static let shifts: ClosedRange<Double> = -12 ... 12
        public static let crossovers: ClosedRange<Double> = 2_000 ... 12_000

        public init(bandCount: Int = 16, attack: Double = 0.002, release: Double = 0.015, shift: Double = 0,
                    sibilance: Double = 0.5, crossover: Double = 6_000) {
            self.bandCount = bandCount
            self.attack = attack
            self.release = release
            self.shift = shift
            self.sibilance = sibilance
            self.crossover = crossover
        }

        /// Every value inside its range; one that is not a number takes its default.
        public var clamped: Settings {
            let base = Settings()
            func held(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            return Settings(bandCount: ChannelVocoder.heldCount(bandCount), attack: held(attack, Self.attacks, base.attack),
                            release: held(release, Self.releases, base.release), shift: held(shift, Self.shifts, base.shift),
                            sibilance: held(sibilance, 0 ... 1, base.sibilance),
                            crossover: held(crossover, Self.crossovers, base.crossover))
        }
    }

    // MARK: The bands

    /// How many bands a vocoder may have.
    public static let bandCounts: ClosedRange<Int> = 8 ... 32
    /// The centre of the lowest band and of the highest, in hertz, at every band count.
    public static let lowestHertz = 100.0
    public static let highestHertz = 8_000.0
    /// The level of the carrier, as a root mean square, at which the output takes the modulator's
    /// band levels: a full-scale sine's, 1/√2.
    public static let carrierReference = 1 / 2.0.squareRoot()
    /// Seconds new bands run unheard after a change of the band count, and seconds they then take to
    /// take over.
    public static let warmSeconds = 0.03
    public static let fadeSeconds = 0.03

    /// The centre of band `band` of `bandCount`, in hertz: 100 · 80^(band / (bandCount − 1)), so the
    /// first is 100 Hz and the last 8 kHz exactly. A band outside the count reads its nearest end;
    /// a count outside `bandCounts` is held to it. Arithmetic only.
    public static func centre(ofBand band: Int, bandCount: Int) -> Double {
        let count = heldCount(bandCount)
        guard band > 0 else { return lowestHertz }
        guard band < count - 1 else { return highestHertz }
        return lowestHertz * Foundation.pow(highestHertz / lowestHertz, Double(band) / Double(count - 1))
    }

    /// Every centre of `bandCount` bands, the lowest first. Allocates.
    public static func bandCentres(bandCount: Int) -> [Double] {
        let count = heldCount(bandCount)
        return (0..<count).map { (band: Int) -> Double in centre(ofBand: band, bandCount: count) }
    }

    /// The Q every band of `bandCount` has: two neighbours a ratio r apart meet 3 dB down, which for
    /// two band-passes in a row is Q = √(√2 − 1) / (√r − 1/√r).
    static func quality(bandCount: Int) -> Double {
        let count = heldCount(bandCount)
        let ratio = Foundation.pow(highestHertz / lowestHertz, 1 / Double(count - 1))
        return (2.0.squareRoot() - 1).squareRoot() / (ratio.squareRoot() - 1 / ratio.squareRoot())
    }

    static func heldCount(_ count: Int) -> Int {
        Swift.min(Swift.max(count, bandCounts.lowerBound), bandCounts.upperBound)
    }

    /// Bands per bank, the most a count can ask for.
    private static let capacity = 32
    /// A band level below this is silence, so a band that has rung out reaches exactly nothing.
    private static let levelFloor: Float = 1e-9

    // MARK: State

    public var settings: Settings {
        didSet {
            settings = settings.clamped
            update()
        }
    }

    public let sampleRate: Double
    /// The band count heard now: the old one until a change has crossed over.
    public private(set) var bandCount: Int

    /// Two banks of `capacity` bands, the one heard and the one a change brings in: per band two
    /// stages on the modulator and two on the carrier, its followed level, its modulator and
    /// carrier coefficients (the carrier's gliding to `carrierTarget`) and its gain.
    private let modulatorStages: UnsafeMutablePointer<ZDFStage>
    private let carrierStages: UnsafeMutablePointer<ZDFStage>
    private let levels: UnsafeMutablePointer<Float>
    private let modulatorG: UnsafeMutablePointer<Float>
    private let carrierG: UnsafeMutablePointer<Float>
    private let carrierTarget: UnsafeMutablePointer<Float>
    private let gains: UnsafeMutablePointer<Float>
    /// Per bank: its band count and its damping 1/Q.
    private let counts: UnsafeMutablePointer<Int>
    private let dampings: UnsafeMutablePointer<Float>
    /// The bank heard; while a change runs, how many samples it has run (−1 while none does).
    private var live = 0
    private var changeAt = -1
    private let warmSamples: Int
    private let fadeSamples: Int
    /// The sibilance: its two high-passes, their coefficient and its level, now and where they go.
    private var highFirst = ZDFStage()
    private var highSecond = ZDFStage()
    private var highG: Float = 0
    private var highTarget: Float = 0
    private var sibilanceNow: Float = 0
    private var sibilanceTarget: Float = 0
    private var attackCoefficient: Float = 1
    private var releaseCoefficient: Float = 1
    private let glide: Float

    public init(sampleRate: Double, settings: Settings = Settings()) {
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        let stages = 2 * Self.capacity * 2, bands = 2 * Self.capacity
        modulatorStages = .allocate(capacity: stages)
        modulatorStages.initialize(repeating: ZDFStage(), count: stages)
        carrierStages = .allocate(capacity: stages)
        carrierStages.initialize(repeating: ZDFStage(), count: stages)
        levels = .allocate(capacity: bands)
        levels.initialize(repeating: 0, count: bands)
        modulatorG = .allocate(capacity: bands)
        modulatorG.initialize(repeating: 0, count: bands)
        carrierG = .allocate(capacity: bands)
        carrierG.initialize(repeating: 0, count: bands)
        carrierTarget = .allocate(capacity: bands)
        carrierTarget.initialize(repeating: 0, count: bands)
        gains = .allocate(capacity: bands)
        gains.initialize(repeating: 0, count: bands)
        counts = .allocate(capacity: 2)
        counts.initialize(repeating: 0, count: 2)
        dampings = .allocate(capacity: 2)
        dampings.initialize(repeating: 1, count: 2)
        warmSamples = Swift.max(1, Int((Self.warmSeconds * self.sampleRate).rounded()))
        fadeSamples = Swift.max(1, Int((Self.fadeSeconds * self.sampleRate).rounded()))
        glide = Float(1 - Foundation.exp(-1 / (Compressor.gainGlideSeconds * self.sampleRate)))
        let start = settings.clamped
        self.settings = start
        bandCount = start.bandCount
        configure(bank: 0, count: start.bandCount)
        update()
        highG = highTarget
        sibilanceNow = sibilanceTarget
    }

    deinit {
        modulatorStages.deinitialize(count: 2 * Self.capacity * 2)
        modulatorStages.deallocate()
        carrierStages.deinitialize(count: 2 * Self.capacity * 2)
        carrierStages.deallocate()
        levels.deallocate()
        modulatorG.deallocate()
        carrierG.deallocate()
        carrierTarget.deallocate()
        gains.deallocate()
        counts.deallocate()
        dampings.deallocate()
    }

    /// The followers' coefficients, the carrier's bands at the shift, the sibilance's corner and
    /// level, from the settings. Arithmetic only.
    private func update() {
        let s = settings
        attackCoefficient = Float(1 - Foundation.exp(-1 / (s.attack * sampleRate)))
        releaseCoefficient = Float(1 - Foundation.exp(-1 / (s.release * sampleRate)))
        let ratio = Foundation.pow(2, s.shift / 12)
        for which in 0..<2 {
            let count = counts[which]
            for band in 0..<count {
                let hertz = Self.centre(ofBand: band, bandCount: count) * ratio
                carrierTarget[which * Self.capacity + band] = ZDFStage.g(hertz, sampleRate: sampleRate)
            }
        }
        highTarget = ZDFStage.g(s.crossover, sampleRate: sampleRate)
        sibilanceTarget = Float(s.sibilance)
    }

    /// Sets bank `bank` up for `count` bands, empty: the centres, the Q, the carrier at the shift,
    /// and each band's gain — 1 / (√share · `carrierReference`), the share being the white noise a
    /// band passes, sin(2πf / fs) / (4Q), which is π·f / (4Q) of the analog pair over the bilinear
    /// map. Arithmetic only.
    private func configure(bank which: Int, count: Int) {
        let held = Self.heldCount(count)
        let sharpness = Self.quality(bandCount: held)
        counts[which] = held
        dampings[which] = Float(1 / sharpness)
        let ratio = Foundation.pow(2, settings.shift / 12)
        for band in 0..<Self.capacity {
            let index = which * Self.capacity + band
            modulatorStages[2 * index].reset()
            modulatorStages[2 * index + 1].reset()
            carrierStages[2 * index].reset()
            carrierStages[2 * index + 1].reset()
            levels[index] = 0
            guard band < held else { continue }
            let hertz = Self.centre(ofBand: band, bandCount: held)
            modulatorG[index] = ZDFStage.g(hertz, sampleRate: sampleRate)
            carrierTarget[index] = ZDFStage.g(hertz * ratio, sampleRate: sampleRate)
            carrierG[index] = carrierTarget[index]
            // Too close to Nyquist to be a band of its own: silent (see the type).
            guard hertz < 0.45 * sampleRate else {
                gains[index] = 0
                continue
            }
            let share = Foundation.sin(2 * Double.pi * hertz / sampleRate) / (4 * sharpness)
            // Every other band turned over (see the type).
            let sign: Double = band % 2 == 0 ? 1 : -1
            gains[index] = Float(sign / (share.squareRoot() * Self.carrierReference))
        }
    }

    /// Empties the bands, the followers and the sibilance; the band count asked for is heard at once.
    public func reset() {
        if changeAt >= 0 { finishChange(beginNext: false) }
        if counts[live] != settings.bandCount { configure(bank: live, count: settings.bandCount) }
        bandCount = counts[live]
        empty()
        highFirst.reset()
        highSecond.reset()
        for band in 0..<Self.capacity {
            let index = live * Self.capacity + band
            carrierG[index] = carrierTarget[index]
        }
        highG = highTarget
        sibilanceNow = sibilanceTarget
    }

    /// The bands' filters and followers, both banks, emptied.
    private func empty() {
        for index in 0..<(2 * Self.capacity) {
            modulatorStages[2 * index].reset()
            modulatorStages[2 * index + 1].reset()
            carrierStages[2 * index].reset()
            carrierStages[2 * index + 1].reset()
            levels[index] = 0
        }
    }

    private func beginChange() {
        configure(bank: 1 - live, count: settings.bandCount)
        changeAt = 0
    }

    private func finishChange(beginNext: Bool = true) {
        live = 1 - live
        bandCount = counts[live]
        changeAt = -1
        if beginNext, settings.bandCount != bandCount { beginChange() }
    }

    /// Writes the modulator's level in each band heard now, as a root mean square, the lowest band
    /// first, into `buffer`: for a meter. Returns how many it wrote — `bandCount`, or fewer if the
    /// buffer is shorter. Allocates nothing.
    public func readBandLevels(into buffer: UnsafeMutableBufferPointer<Float>) -> Int {
        let count = Swift.min(buffer.count, counts[live])
        for band in 0..<count { buffer[band] = levels[live * Self.capacity + band] }
        return count
    }

    // MARK: Processing

    /// Vocodes `frames` samples: `modulator` shapes `carrier`, the result goes to `output`, which may
    /// be either input's buffer (each sample is read before it is written).
    public func process(modulator: UnsafePointer<Float>, carrier: UnsafePointer<Float>,
                        output: UnsafeMutablePointer<Float>, frames: Int) {
        guard frames > 0 else { return }
        if changeAt < 0, settings.bandCount != bandCount { beginChange() }
        let k = ZDFStage.butterworth
        var first = highFirst, second = highSecond
        var gHigh = highG, sibilance = sibilanceNow
        for i in 0..<frames {
            let m = modulator[i], c = carrier[i]
            guard m.isFinite, c.isFinite else {
                silence(&first, &second)
                output[i] = 0
                continue
            }
            gHigh = Compressor.glided(gHigh, toward: highTarget, by: glide)
            sibilance = Compressor.glided(sibilance, toward: sibilanceTarget, by: glide)
            var out = bank(live, modulator: m, carrier: c)
            if changeAt >= 0 {
                let incoming = bank(1 - live, modulator: m, carrier: c)
                let share = Float(Swift.min(Swift.max(changeAt - warmSamples, 0), fadeSamples)) / Float(fadeSamples)
                let angle = 0.5 * Float.pi * share
                out = out * cosf(angle) + incoming * sinf(angle)
                changeAt += 1
                if changeAt >= warmSamples + fadeSamples { finishChange() }
            }
            let high = second.process(first.process(m, g: gHigh, k: k).high, g: gHigh, k: k).high
            out += high * sibilance
            guard out.isFinite else {
                silence(&first, &second)
                output[i] = 0
                continue
            }
            output[i] = out
        }
        highFirst = first
        highSecond = second
        highG = gHigh
        sibilanceNow = sibilance
    }

    /// A sample that is not a number, in or out: everything emptied, a change finished at once.
    private func silence(_ first: inout ZDFStage, _ second: inout ZDFStage) {
        if changeAt >= 0 { finishChange(beginNext: false) }
        empty()
        first.reset()
        second.reset()
    }

    /// One sample of bank `index`: every band's modulator level followed, its carrier band played at
    /// that level and gain, the bands summed.
    @inline(__always)
    private func bank(_ index: Int, modulator m: Float, carrier c: Float) -> Float {
        let count = counts[index]
        let k = dampings[index]
        let squared = k * k
        let base = index * Self.capacity
        let attack = attackCoefficient, release = releaseCoefficient, step = glide
        let silent = Self.levelFloor
        var sum: Float = 0
        for band in 0..<count {
            let i = base + band
            let s = 2 * i
            let gm = modulatorG[i]
            let heard = modulatorStages[s + 1].process(modulatorStages[s].process(m, g: gm, k: k).band * k, g: gm, k: k)
            let inPhase = heard.band * k
            let power = 0.5 * (inPhase * inPhase - squared * heard.low * heard.high)
            let envelope = power > 0 ? power.squareRoot() : 0
            var level = levels[i]
            level += (envelope - level) * (envelope > level ? attack : release)
            if level < silent { level = 0 }
            levels[i] = level
            var gc = carrierG[i]
            let target = carrierTarget[i]
            if gc != target {
                gc = Compressor.glided(gc, toward: target, by: step)
                carrierG[i] = gc
            }
            let tone = carrierStages[s + 1].process(carrierStages[s].process(c, g: gc, k: k).band * k, g: gc, k: k).band * k
            sum += tone * level * gains[i]
        }
        return sum
    }
}
