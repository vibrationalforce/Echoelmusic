import Foundation

/// A three-band clipper: the sound split into low, mid and high at two crossovers, each band
/// driven into a clipper at the ceiling on its own, the bands summed and clipped once more at the
/// same ceiling — so a kick can be squared off without the vocal above it breaking up, and the
/// master gets louder with less pumping than a full-band limiter. Written new for Echoel Studio, as a value of
/// settings and a render-thread processor like `MultibandCompressor`.
///
/// **Crossovers.** Linkwitz-Riley of the fourth order, two Butterworth `ZDFStage`s in a row per
/// side of a split: low = LP(f1), rest = HP(f1), mid = LP(f2)(rest), high = HP(f2)(rest), and the
/// low band runs through the second split's allpass, so low + mid + high is the allpass
/// AP(f1)·AP(f2) — magnitude-flat. The frequencies glide in steps of `step` samples.
///
/// **Clipping.** Per band: the drive, then the clip curve at the ceiling with the shared
/// softness `k`: with `u = x / ceiling`, `|u| ≤ 1 − k` passes unchanged, above it
/// `sign·((1 − k) + k·tanh((|u| − (1 − k)) / k))` (k = 0 is a hard clip) — continuous, slope 1 at
/// the knee, never above the ceiling. No gain compensation: the loudness is the point.
///
/// **Oversampling.** Every clip runs at four times the rate: each band is raised ×4 by two
/// halfband stages (linear phase, polyphase: the even outputs are the side taps, the odd ones the
/// centre tap's delay), clipped there, summed there, the sum clipped there, and brought down ×4 by
/// the same two stages. Stage 1 (base ↔ 2×) has `firstTaps` = 99 taps, Kaiser β 7.6: at least
/// 76 dB of stopband from 0.55·fs, passband ripple ±0.0012 dB up to 0.45·fs. Stage 2 (2× ↔ 4×)
/// has `secondTaps` = 23 taps, Kaiser β 7.4: 75 dB from 1.45·fs, where stage 2's images start.
///
/// **Ceiling guard.** A band-limited signal that was clipped flat at 4× overshoots between the
/// clipped samples once it is brought down — the base-rate samples sat up to 2.6 dB over the
/// ceiling for a 15 kHz sine driven 18 dB (a float simulation of this design, 2026-11-06). A hard
/// clip at the base rate would fold all the harmonics the oversampling kept away straight back in (the
/// 7 kHz test's fold-back went from −59 to −26 dB). So the wet sum passes a look-ahead gain of
/// `guardWindow` samples: the lowest gain any sample of the window needs, held over the window and
/// averaged over it again, which is never above what the delayed sample needs, and returns over
/// 10 ms. Under the ceiling it is exactly 1. A clamp at the ceiling after it catches rounding.
/// It IS a full-band look-ahead limiter on what the clipping leaves over the ceiling: measured in
/// the review simulation, up to about 3.8 dB at 44.1/48 kHz (4.5 dB at 96 kHz) on bright, hard-
/// driven material, heard as about 1 dB of pumping on high transients — the price of a hard
/// true-sample ceiling without folding the harmonics back. The fold-back is measured at two bins
/// at +12 dB (−58 dB); the broadband alias floor rises with drive (−22 … −45 dB in the review).
///
/// **Mix** blends the wet sound with the input as it came in, before Input — aligned, never
/// clipped: at Mix < 1 the dry part adds to the ceiling unclipped.
///
/// **Latency** `latencySamples` = 85 at every rate: 2·24 + 5 + 1 = 54 for the halfband chain
/// (one 4× sample of padding makes it whole) and 31 for the guard. The dry sound runs through the
/// same two crossover allpasses and a delay of exactly that, so dry and wet are in phase at every
/// frequency and every Mix; a plain delay would cancel at the crossovers (−180° there).
///
/// A sample that is not a number comes in as silence; a result that is not one empties the
/// processor and comes out as silence. Owned by the render thread:
/// set `settings` and call `process` from that thread. Everything is allocated in `init`; any
/// block length is processed sample by sample, nothing allocates, locks or waits after that.
public final class MultibandClipper: @unchecked Sendable {
    public struct Settings: Equatable, Codable, Sendable {
        /// dB before the split, −12 … +24.
        public var inputGain: Double
        /// Hz between low and mid, 40 … 800.
        public var lowCrossover: Double
        /// Hz between mid and high, 1000 … 10000 — the ranges never meet, so it is always above the low one.
        public var highCrossover: Double
        /// Per band, low first: dB into its clipper, 0 … 18.
        public var lowDrive: Double
        public var midDrive: Double
        public var highDrive: Double
        /// 0 (hard clip) … 1 (the whole range soft), shared by the bands and the sum.
        public var softness: Double
        /// dBFS the output never passes, −12 … 0.
        public var ceiling: Double
        /// 0 (dry) … 1 (clipped).
        public var mix: Double

        public init(inputGain: Double = 0, lowCrossover: Double = 150, highCrossover: Double = 3_000,
                    lowDrive: Double = 0, midDrive: Double = 0, highDrive: Double = 0,
                    softness: Double = 0.3, ceiling: Double = -0.3, mix: Double = 1) {
            self.inputGain = inputGain
            self.lowCrossover = lowCrossover
            self.highCrossover = highCrossover
            self.lowDrive = lowDrive
            self.midDrive = midDrive
            self.highDrive = highDrive
            self.softness = softness
            self.ceiling = ceiling
            self.mix = mix
        }

        /// Every value inside its range; non-finite values take the default.
        public var clamped: Settings {
            let base = Settings()
            func clamp(_ value: Double, _ range: ClosedRange<Double>, _ fallback: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, range.lowerBound), range.upperBound) : fallback
            }
            let low = clamp(lowCrossover, 40...800, base.lowCrossover)
            return Settings(inputGain: clamp(inputGain, -12...24, base.inputGain),
                            lowCrossover: low,
                            highCrossover: Swift.max(clamp(highCrossover, 1_000...10_000, base.highCrossover), low),
                            lowDrive: clamp(lowDrive, 0...18, base.lowDrive),
                            midDrive: clamp(midDrive, 0...18, base.midDrive),
                            highDrive: clamp(highDrive, 0...18, base.highDrive),
                            softness: clamp(softness, 0...1, base.softness),
                            ceiling: clamp(ceiling, -12...0, base.ceiling),
                            mix: clamp(mix, 0...1, base.mix))
        }
    }

    public var settings: Settings {
        didSet {
            settings = settings.clamped
            update()
            // Set before the first block, a value takes effect at once: the effect loads as stored.
            if !hasRun {
                now = targets
                increments = Values()
            }
        }
    }

    public let sampleRate: Double

    /// Taps of the first halfband stage (base rate ↔ 2×), `4·m + 3` so its end taps are not zero.
    public static let firstTaps = 99
    /// Taps of the second halfband stage (2× ↔ 4×).
    public static let secondTaps = 23
    /// Samples the ceiling guard looks ahead (and averages over).
    static let guardWindow = 32
    /// Samples between two steps of the gliding values.
    static let step = 32
    private static let firstHalf = (firstTaps - 3) / 4
    private static let secondHalf = (secondTaps - 3) / 4
    /// Side taps (the even ones) per stage: `2·m + 2`.
    private static let firstSides = 2 * firstHalf + 2
    private static let secondSides = 2 * secondHalf + 2
    /// How far the output sits behind the input, in samples at the base rate, at every rate.
    public static let latencySamples = 2 * firstHalf + secondHalf + 1 + guardWindow - 1
    public var latencySamples: Int { Self.latencySamples }

    // Histories: the upsamplers per band and side (stage 1: 0 …< 6, stage 2: 6 …< 12, index
    // band · 2 + side), then per side the downsamplers' odd and even halves.
    private static let upFirst = 0, upSecond = 6, downSecondOdd = 12, downSecondEven = 14
    private static let downFirstOdd = 16, downFirstEven = 18, historyCount = 20

    private let firstSide: UnsafeMutablePointer<Float>
    private let secondSide: UnsafeMutablePointer<Float>
    private let historyStorage: UnsafeMutablePointer<Float>
    private let historyStorageCount: Int
    private let histories: UnsafeMutablePointer<HalfbandHistory>
    /// Per side (left 0 …< 9, right 9 …< 18): the seven crossover stages as `MultibandCompressor`
    /// uses them, then the dry sound's allpass at each crossover.
    private let stages: UnsafeMutablePointer<ZDFStage>
    /// The dry sound, both sides, `latencySamples + 1` long each.
    private let dryLine: UnsafeMutablePointer<Float>
    private let dryLength: Int
    private var dryPosition = 0
    /// The guard: the gains needed, their running minimum, and the wet sound (both sides) waiting.
    private let needed: UnsafeMutablePointer<Float>
    private let held: UnsafeMutablePointer<Float>
    private let waiting: UnsafeMutablePointer<Float>
    private var heldSum: Double
    private var guardPosition = 0
    private var guardGain: Float = 1
    private let guardRelease: Float
    /// The last 4× sample of the clipped sum per side, the padding that makes the latency whole.
    private var carryLeft: Float = 0, carryRight: Float = 0

    // Values as the sound plays them: targets, and where the glide has got to.
    private var targets = Values()
    private var now = Values()
    /// Whether a block has run since the start or the last `reset`.
    private var hasRun = false
    private var increments = Values()
    private var stepPhase = 0
    private let stepPole: Float

    /// The gliding values: the linear gains move every sample, the rest every `step`.
    private struct Values {
        var input: Float = 1, low: Float = 1, mid: Float = 1, high: Float = 1, mix: Float = 1
        var g1: Float = 0, g2: Float = 0, softness: Float = 0.3, ceiling: Float = 1
    }

    public init(sampleRate: Double, settings: Settings = Settings()) {
        let rate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        self.sampleRate = rate
        let one = UnsafeMutablePointer<Float>.allocate(capacity: Self.firstSides)
        let two = UnsafeMutablePointer<Float>.allocate(capacity: Self.secondSides)
        Self.design(one, taps: Self.firstTaps, beta: 7.6)
        Self.design(two, taps: Self.secondTaps, beta: 7.4)
        firstSide = one
        secondSide = two
        var lengths: [Int] = []
        for index in 0..<Self.historyCount {
            let first = index < Self.upSecond || index >= Self.downFirstOdd
            lengths.append(first ? Self.firstSides : Self.secondSides)
        }
        let storageCount = 2 * lengths.reduce(0, +)
        let storage = UnsafeMutablePointer<Float>.allocate(capacity: storageCount)
        storage.initialize(repeating: 0, count: storageCount)
        let table = UnsafeMutablePointer<HalfbandHistory>.allocate(capacity: Self.historyCount)
        var offset = 0
        for (index, length) in lengths.enumerated() {
            (table + index).initialize(to: HalfbandHistory(storage: storage + offset, length: length))
            offset += 2 * length
        }
        historyStorageCount = storageCount
        historyStorage = storage
        histories = table
        stages = .allocate(capacity: 18)
        stages.initialize(repeating: ZDFStage(), count: 18)
        let delayLength = Self.latencySamples + 1
        dryLength = delayLength
        dryLine = .allocate(capacity: 2 * delayLength)
        dryLine.initialize(repeating: 0, count: 2 * delayLength)
        needed = .allocate(capacity: Self.guardWindow)
        needed.initialize(repeating: 1, count: Self.guardWindow)
        held = .allocate(capacity: Self.guardWindow)
        held.initialize(repeating: 1, count: Self.guardWindow)
        waiting = .allocate(capacity: 2 * Self.guardWindow)
        waiting.initialize(repeating: 0, count: 2 * Self.guardWindow)
        heldSum = Double(Self.guardWindow)
        guardRelease = Float(1 - Foundation.exp(-1 / (0.01 * rate)))
        stepPole = Float(Foundation.exp(-Double(Self.step) / (Compressor.gainGlideSeconds * rate)))
        self.settings = settings.clamped
        update()
        now = targets
    }

    deinit {
        firstSide.deallocate()
        secondSide.deallocate()
        histories.deinitialize(count: Self.historyCount)
        histories.deallocate()
        historyStorage.deallocate()
        stages.deinitialize(count: 18)
        stages.deallocate()
        dryLine.deallocate()
        needed.deallocate()
        held.deallocate()
        waiting.deallocate()
    }

    /// The side taps (every second one, starting at the first) of a Kaiser-windowed halfband
    /// lowpass of `taps = 4·m + 3` taps, cut at a quarter of its rate; its centre tap is ½ and the
    /// other odd ones are zero, which is why the polyphase forms below need only these.
    static func design(_ output: UnsafeMutablePointer<Float>, taps: Int, beta: Double) {
        func bessel(_ x: Double) -> Double {
            var sum = 1.0, term = 1.0, k = 1.0
            while term > 1e-12 * sum {
                let half = x / (2 * k)
                term *= half * half
                sum += term
                k += 1
            }
            return sum
        }
        let centre = (taps - 1) / 2
        let norm = bessel(beta)
        for j in 0..<((taps - 3) / 2 + 2) {
            let index = 2 * j
            let offset = Double(index - centre)
            let sinc = Foundation.sin(Double.pi * offset / 2) / (Double.pi * offset)
            let r = 2 * Double(index) / Double(taps - 1) - 1
            let window = bessel(beta * Swift.max(0, 1 - r * r).squareRoot()) / norm
            output[j] = Float(sinc * window)
        }
    }

    /// The full impulse response of a stage, for the tests: the side taps on the even indices,
    /// ½ in the centre.
    static func impulseResponse(taps: Int, beta: Double) -> [Float] {
        let count = (taps - 3) / 2 + 2
        let taps2 = UnsafeMutablePointer<Float>.allocate(capacity: count)
        defer { taps2.deallocate() }
        design(taps2, taps: taps, beta: beta)
        var response = [Float](repeating: 0, count: taps)
        for j in 0..<count { response[2 * j] = taps2[j] }
        response[(taps - 1) / 2] = 0.5
        return response
    }

    private func update() {
        let s = settings
        func gain(_ decibels: Double) -> Float { Float(Foundation.pow(10, decibels / 20)) }
        targets.input = gain(s.inputGain)
        targets.low = gain(s.lowDrive)
        targets.mid = gain(s.midDrive)
        targets.high = gain(s.highDrive)
        targets.mix = Float(s.mix)
        targets.g1 = ZDFStage.g(s.lowCrossover, sampleRate: sampleRate)
        targets.g2 = ZDFStage.g(s.highCrossover, sampleRate: sampleRate)
        targets.softness = Float(s.softness)
        targets.ceiling = gain(s.ceiling)
    }

    /// Empties the filters, the oversampling, the delays and the guard.
    public func reset() {
        historyStorage.update(repeating: 0, count: historyStorageCount)
        for index in 0..<18 { stages[index].reset() }
        dryLine.update(repeating: 0, count: 2 * dryLength)
        needed.update(repeating: 1, count: Self.guardWindow)
        held.update(repeating: 1, count: Self.guardWindow)
        waiting.update(repeating: 0, count: 2 * Self.guardWindow)
        heldSum = Double(Self.guardWindow)
        guardGain = 1
        carryLeft = 0
        carryRight = 0
        now = targets
        increments = Values()
        stepPhase = 0
        hasRun = false
    }

    /// One glide step: the values the next `step` samples move to.
    private func advance() {
        let pole = stepPole
        func glided(_ value: Float, _ target: Float) -> Float {
            let next = target + (value - target) * pole
            return Swift.abs(next - target) <= 1e-6 * Swift.max(1, Swift.abs(target)) ? target : next
        }
        // A ramp that has arrived holds its value exactly, so a steady setting is bit-steady.
        func ramp(_ value: inout Float, _ target: Float) -> Float {
            guard Swift.abs(value - target) > 1e-6 * Swift.max(1, Swift.abs(target)) else {
                value = target
                return 0
            }
            return (glided(value, target) - value) / Float(MultibandClipper.step)
        }
        increments.input = ramp(&now.input, targets.input)
        increments.low = ramp(&now.low, targets.low)
        increments.mid = ramp(&now.mid, targets.mid)
        increments.high = ramp(&now.high, targets.high)
        increments.mix = ramp(&now.mix, targets.mix)
        now.g1 = glided(now.g1, targets.g1)
        now.g2 = glided(now.g2, targets.g2)
        now.softness = glided(now.softness, targets.softness)
        now.ceiling = glided(now.ceiling, targets.ceiling)
    }

    /// The clip curve at the ceiling: linear to `1 − k`, then the tanh knee, never above `ceiling`.
    @inline(__always)
    static func clip(_ x: Float, ceiling: Float, inverseCeiling: Float, softness: Float) -> Float {
        let knee = 1 - softness
        let level = Swift.abs(x) * inverseCeiling
        guard level > knee else { return x }
        let shaped: Float = softness < 1e-4 ? 1 : Swift.min(knee + softness * tanh((level - knee) / softness), 1)
        return x < 0 ? -shaped * ceiling : shaped * ceiling
    }

    /// One side of one sample: the wet sound before the guard, and the dry sound through the same
    /// allpasses. `base` is the side's first stage, `channel` 0 (left) or 1.
    @inline(__always)
    private func channelSample(_ input: Float, dryInput: Float, base: Int, channel: Int) -> (wet: Float, dry: Float) {
        let k = ZDFStage.butterworth
        let g1 = now.g1, g2 = now.g2
        let first = stages[base].process(input, g: g1, k: k)
        let lowBand = stages[base + 1].process(first.low, g: g1, k: k).low
        let rest = stages[base + 2].process(first.high, g: g1, k: k).high
        let second = stages[base + 3].process(rest, g: g2, k: k)
        let midBand = stages[base + 4].process(second.low, g: g2, k: k).low
        let highBand = stages[base + 5].process(second.high, g: g2, k: k).high
        let lowAligned = lowBand - 2 * k * stages[base + 6].process(lowBand, g: g2, k: k).band
        let dryFirst = dryInput - 2 * k * stages[base + 7].process(dryInput, g: g1, k: k).band
        let dry = dryFirst - 2 * k * stages[base + 8].process(dryFirst, g: g2, k: k).band

        let ceiling = now.ceiling, inverse = 1 / now.ceiling, softness = now.softness
        let one = firstSide, two = secondSide
        let m1 = Self.firstHalf, m2 = Self.secondHalf
        var z0: Float = 0, z1: Float = 0, z2: Float = 0, z3: Float = 0
        let bands: (Float, Float, Float) = (lowAligned * now.low, midBand * now.mid, highBand * now.high)
        for band in 0..<3 {
            let value = band == 0 ? bands.0 : (band == 1 ? bands.1 : bands.2)
            let up1 = histories + (Self.upFirst + band * 2 + channel)
            let up2 = histories + (Self.upSecond + band * 2 + channel)
            up1.pointee.push(value)
            let even = 2 * up1.pointee.dot(one)
            let odd = up1.pointee.at(m1)
            up2.pointee.push(even)
            let a0 = 2 * up2.pointee.dot(two), a1 = up2.pointee.at(m2)
            up2.pointee.push(odd)
            let a2 = 2 * up2.pointee.dot(two), a3 = up2.pointee.at(m2)
            z0 += Self.clip(a0, ceiling: ceiling, inverseCeiling: inverse, softness: softness)
            z1 += Self.clip(a1, ceiling: ceiling, inverseCeiling: inverse, softness: softness)
            z2 += Self.clip(a2, ceiling: ceiling, inverseCeiling: inverse, softness: softness)
            z3 += Self.clip(a3, ceiling: ceiling, inverseCeiling: inverse, softness: softness)
        }
        z0 = Self.clip(z0, ceiling: ceiling, inverseCeiling: inverse, softness: softness)
        z1 = Self.clip(z1, ceiling: ceiling, inverseCeiling: inverse, softness: softness)
        z2 = Self.clip(z2, ceiling: ceiling, inverseCeiling: inverse, softness: softness)
        z3 = Self.clip(z3, ceiling: ceiling, inverseCeiling: inverse, softness: softness)
        // Down: one 4× sample of padding (the last one of the previous sample), then pairs.
        let carried = channel == 0 ? carryLeft : carryRight
        if channel == 0 { carryLeft = z3 } else { carryRight = z3 }
        let odd2 = histories + (Self.downSecondOdd + channel), even2 = histories + (Self.downSecondEven + channel)
        even2.pointee.push(carried)
        odd2.pointee.push(z0)
        let w0 = odd2.pointee.dot(two) + 0.5 * even2.pointee.at(m2)
        even2.pointee.push(z1)
        odd2.pointee.push(z2)
        let w1 = odd2.pointee.dot(two) + 0.5 * even2.pointee.at(m2)
        let odd1 = histories + (Self.downFirstOdd + channel), even1 = histories + (Self.downFirstEven + channel)
        even1.pointee.push(w0)
        odd1.pointee.push(w1)
        let wet = odd1.pointee.dot(one) + 0.5 * even1.pointee.at(m1)
        return (wet, dry)
    }

    /// Processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        guard frames > 0 else { return }
        hasRun = true
        let window = Self.guardWindow, mask = Self.guardWindow - 1
        var bad = false
        for i in 0..<frames {
            if stepPhase == 0 { advance() }
            stepPhase = (stepPhase + 1) % Self.step
            now.input += increments.input
            now.low += increments.low
            now.mid += increments.mid
            now.high += increments.high
            now.mix += increments.mix

            // The boundary: a sample that is not a number is silence.
            // The dry sound is the input as it came in, before Input: Mix never adds gain unclipped.
            var rawLeft = left[i], rawRight = right[i]
            if !rawLeft.isFinite { rawLeft = 0 }
            if !rawRight.isFinite { rawRight = 0 }
            var inLeft = rawLeft * now.input, inRight = rawRight * now.input
            if !inLeft.isFinite { inLeft = 0 }
            if !inRight.isFinite { inRight = 0 }
            let l = channelSample(inLeft, dryInput: rawLeft, base: 0, channel: 0)
            let r = channelSample(inRight, dryInput: rawRight, base: 9, channel: 1)

            // The guard: linked, so a side that needs less never shifts the image.
            let ceiling = now.ceiling
            let peak = Swift.max(Swift.abs(l.wet), Swift.abs(r.wet))
            let need: Float = peak > ceiling ? ceiling / peak : 1
            guardPosition = (guardPosition + 1) & mask
            needed[guardPosition] = need
            var lowest = needed[0]
            for j in 1..<window { lowest = Swift.min(lowest, needed[j]) }
            heldSum += Double(lowest) - Double(held[guardPosition])
            held[guardPosition] = lowest
            let average = Float(heldSum / Double(window))
            // Snaps home once the glide stops moving, so the gain returns to exactly 1.
            let glided = guardGain + guardRelease * (average - guardGain)
            guardGain = average - guardGain < 1e-6 ? average : Swift.min(average, glided)
            let late = (guardPosition + 1) & mask
            let wetLeft = waiting[late] * guardGain, wetRight = waiting[window + late] * guardGain
            waiting[guardPosition] = l.wet
            waiting[window + guardPosition] = r.wet
            let outWet = (Swift.min(Swift.max(wetLeft, -ceiling), ceiling), Swift.min(Swift.max(wetRight, -ceiling), ceiling))

            // The dry sound, as far behind as the wet one.
            dryPosition = dryPosition + 1 == dryLength ? 0 : dryPosition + 1
            let read = dryPosition + 1 == dryLength ? 0 : dryPosition + 1
            let dryLeft = dryLine[read], dryRight = dryLine[dryLength + read]
            dryLine[dryPosition] = l.dry
            dryLine[dryLength + dryPosition] = r.dry

            let mix = now.mix
            let outLeft = dryLeft + mix * (outWet.0 - dryLeft)
            let outRight = dryRight + mix * (outWet.1 - dryRight)
            if outLeft.isFinite, outRight.isFinite {
                left[i] = outLeft
                right[i] = outRight
            } else {
                bad = true
                left[i] = 0
                right[i] = 0
            }
        }
        if bad {
            let keep = (now, increments, stepPhase)
            reset()
            (now, increments, stepPhase) = keep
        }
    }
}

/// The last `length` samples of one signal, newest first, in a ring written twice over so the
/// window is always one contiguous run: a halfband stage's FIR reads it without wrapping.
struct HalfbandHistory {
    let storage: UnsafeMutablePointer<Float>
    let length: Int
    private(set) var position = 0

    init(storage: UnsafeMutablePointer<Float>, length: Int) {
        self.storage = storage
        self.length = length
    }

    @inline(__always)
    mutating func push(_ value: Float) {
        position = position == 0 ? length - 1 : position - 1
        storage[position] = value
        storage[position + length] = value
    }

    /// The sample `age` pushes ago (0 is the newest).
    @inline(__always)
    func at(_ age: Int) -> Float { storage[position + age] }

    /// Σ taps[j]·x[n − j] over the whole history, the taps symmetric (`taps[j] == taps[length − 1 − j]`).
    @inline(__always)
    func dot(_ taps: UnsafeMutablePointer<Float>) -> Float {
        let window = storage + position
        var sum: Float = 0
        let last = length - 1
        for j in 0..<(length / 2) { sum += taps[j] * (window[j] + window[last - j]) }
        return sum
    }
}
