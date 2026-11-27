import Foundation

/// A pitch shift that keeps a voice's formants where they are, with a formant shift of its own.
/// Grains are cut at the input's own periods and laid down again at the new period: pitch-
/// synchronous overlap-add (Moulines & Charpentier, *Speech Communication* 9, 1990). A grain is
/// about two periods of the input under a raised-cosine window, centred on a pitch mark, and holds
/// one ring of the vocal tract; laying the grains closer together (higher) or further apart
/// (lower) changes the pitch and leaves the resonances alone. `SpliceHead`, which the harmonizer
/// and the pitch correction play through, reads the input faster or slower instead, and that moves
/// the formants with the pitch; it stays as it is.
///
/// **Marks.** The `PitchTracker` hears whether a note sounds and about how long its period is. The
/// period a note's marks start on is settled from that: of the tracker's period, its third, half,
/// double and triple, the shortest that repeats nearly as well as the best of them (`preference`),
/// all weighed over the same stretch, because the shortest lag that repeats is the period (YIN's
/// rule). That corrects the tracker where it hears a note above its 1 kHz (up to 2 kHz) as two
/// periods, or a vowel whose first formant sits on its second or third harmonic an octave or more
/// too high. The
/// loudest point of the newest period becomes a mark if the period before it matches; from there
/// each next mark is where the next period best matches the last one — the normalised correlation
/// of the two, within `reach` of the last period, refined between samples by a parabola — or a
/// half or a third of that period if the sound repeats there nearly as well, since a note that
/// leaps an octave up still repeats at its old one. Where the tracker hears two or three of the
/// marks' periods in one of its own, the marks check once whether the note repeats clearly better
/// at that longer period: a note that leaps an octave down can go on nearly repeating at its old
/// one when its odd harmonics are weak. So the marks follow the waveform itself through a glide, a
/// vibrato or a leap, and a note ends where its periods stop resembling each other (`resemblance`),
/// not a tracker window later: the tracker's analyses go on hearing a tone for about 4 to 21 ms
/// after it stops (at 110 to 440 Hz; longer the higher the note, and depending on where the stop
/// falls between two analyses). Where the tracker keeps hearing a period unrelated to the marks',
/// the note starts again on the tracker's. A note just heard is marked backwards, period by period,
/// to where it began, as far back as the output has not played yet.
///
/// **Grains.** A grain's window rises from the mark before its own and falls to the mark after.
/// Grains are laid one input period over the pitch ratio apart, each taking the mark nearest its
/// place in time, so a shift up repeats grains and a shift down skips some. For a formant shift
/// each grain is read the formant ratio times as fast: upward its halves shrink by that ratio;
/// downward it keeps its length and is cut narrower, so a grain never outgrows the two periods
/// around its mark. Each grain is weighted by √(f / r), r the pitch ratio and f the formant ratio:
/// laid r times as densely and f times as short, a voice's grains — most of whose energy sits at
/// the pulse on the mark — would carry r / f times the power. So a voiced sound keeps about its
/// power (within 2 dB on the tests' vowel), and two octaves down, its grains no longer touching,
/// its peaks are about twice as high.
///
/// **Without a note** — noise, a consonant, silence — the input passes untouched, exactly as late
/// as the grains. Grains and input cross-fade over a note's first and last period with the windows
/// the grains themselves use, so at no shift the output is the input `latencySamples` later,
/// voiced or not.
///
/// **Latency** (`latencySamples`): a grain starts up to one period before its centre, and placing
/// the centre needs the mark after it, so two of the longest periods the tracker hears (70 Hz) plus
/// the reach of one search: 1411 samples at 48 kHz, 1298 at 44.1 kHz, 2817 at 96 kHz — 29.3 to
/// 29.4 ms — the same for every setting and every sound.
///
/// **Limits**, measured on synthetic tones and vowels. The tracker first hears a note about 19 to
/// 32 ms after it starts — later after a consonant than after silence, and depending on where the
/// start falls between two analyses — and the output is 29.4 ms late; where the tracker hears a
/// note later than that, the difference passes unshifted before the grains fade in: up to about
/// 3 ms, at the latest starts of a low note (82 Hz) or of a vowel after a consonant. It shifts one
/// voice at a time: what the tracker hears no single pitch in, and anything below 70 Hz, passes
/// unshifted. A note above 2 kHz, which the tracker hears as three or more periods, and a voice
/// whose odd harmonics lie about 16 dB or more below its even ones (14 dB just after a leap an
/// octave down), which the tracker and the marks alike hear an octave too high, are shifted from
/// the wrong period and land at the wrong pitch. The formant shift reads between samples on
/// straight lines.
///
/// **Cost** (derived from the code, not measured on a device). Per sample: the tracker's YIN, about
/// 460 multiply-adds at 48 kHz; the mark search with its half and third, about 50 multiply-adds at
/// 220 Hz and 135 at 70 Hz; about 15 operations for each grain sounding, of which about twice the
/// pitch ratio sound at once (3 to 4 a fifth up). Once per note: settling its period, about 40,000
/// multiply-adds at 220 Hz.
///
/// Owned by the render thread: set `settings` and call `process` from that thread. Everything is
/// allocated in `init`; nothing allocates, locks or waits after that. A sample that is not a number
/// empties the shifter, and that frame is silence; a run of them empties it once. A finite sample
/// near the largest float leaves the voice unshifted for under a second, until the DC blocker on
/// the analysed mean has let it go.
public final class GrainShifter: @unchecked Sendable {
    public struct Settings: Equatable, Sendable {
        /// The pitch shift in semitones, −24 … 24.
        public var pitch: Double
        /// The formant shift in semitones, −12 … 12. 0 keeps the formants where the input has
        /// them, at any pitch; the same value as `pitch` moves them with it, as `SpliceHead` does.
        public var formant: Double

        public init(pitch: Double = 0, formant: Double = 0) {
            self.pitch = pitch
            self.formant = formant
        }

        /// Every value inside its range; a value that is not a number is 0.
        public var clamped: Settings {
            func clamp(_ value: Double, _ limit: Double) -> Double {
                value.isFinite ? Swift.min(Swift.max(value, -limit), limit) : 0
            }
            return Settings(pitch: clamp(pitch, 24), formant: clamp(formant, 12))
        }
    }

    /// How much a period must resemble the one before it to belong to the same note: their
    /// normalised correlation. A held vowel sits near 1 and noise matches itself only by chance;
    /// the tracker's own gate (YIN's 0.15) is about 0.85 in these terms. At 0.5 a vowel's grains
    /// reached up to 4.3 ms back into a soft consonant before it (a hiss 18.5 dB below the vowel, at
    /// 220 and 330 Hz), where at 0.7 the consonant passes untouched to its end (measured; the
    /// consonant test checks the second).
    static let resemblance = 0.7
    /// How much less a shorter period may match than a longer one and still be taken, and how much
    /// better a longer one must match to replace a shorter: the shortest lag that repeats is the
    /// note's period (YIN's rule). A note leaping an octave up still repeats at its old period, now
    /// two of its own.
    static let preference = 0.05
    /// How far the tracker may hear another period than the marks follow, as a share, and for how
    /// many analyses in a row (about 16 ms at 48 kHz), before the note ends and starts again on
    /// the tracker's period. The tracker lags a glide by about half its window; 15 % in that time
    /// is a glide of about 2.4 semitones in 15 ms.
    static let disagreement = 0.15
    static let patience = 3
    /// How far a period may differ from the one before, as a share of it: a vibrato or a glide moves
    /// far less from one period to the next, a leap to another note more.
    static let reach = 0.05
    /// Steps in the raised-cosine table the windows read.
    static let tableSize = 1_024
    /// Grains sounding at once, at most: each spans two periods, and two octaves up they are laid a
    /// quarter period apart, so eight overlap.
    static let grainCapacity = 16
    /// A mark's flags: it opens a note, it closes one.
    private static let opens: UInt8 = 1
    private static let closes: UInt8 = 2

    /// How far the output sits behind the input, in samples, at `sampleRate` (see the type).
    public static func latencySamples(sampleRate: Double) -> Int {
        let longest = longestPeriod(sampleRate: sanitized(sampleRate))
        return 2 * longest + searchRadius(Double(longest)) + 4
    }

    private static func sanitized(_ sampleRate: Double) -> Double {
        sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
    }

    /// The longest and the shortest period the tracker hears, in samples. The longest is also the
    /// longest the marks follow.
    private static func longestPeriod(sampleRate: Double) -> Int {
        Int(sampleRate / PitchTracker.minimumHertz) + 1
    }

    private static func shortestPeriod(sampleRate: Double) -> Int {
        Swift.max(4, Int(sampleRate / PitchTracker.maximumHertz))
    }

    /// The shortest period the marks follow, half the tracker's shortest: the tracker hears a note
    /// above its 1 kHz as two of its periods, and the marks halve that, so a note up to 2 kHz keeps
    /// its octave.
    private static func briefestPeriod(sampleRate: Double) -> Int {
        Swift.max(2, shortestPeriod(sampleRate: sampleRate) / 2)
    }

    /// How many samples either side of the expected period a search looks.
    private static func searchRadius(_ period: Double) -> Int {
        Swift.max(2, Int((period * reach).rounded(.up)))
    }

    public var settings: Settings {
        didSet {
            settings = settings.clamped
            derive()
        }
    }

    public let sampleRate: Double
    public let latencySamples: Int
    /// How long the output goes on after the input stops, in samples: the latency, plus the last
    /// note's grains, laid down up to half a period past its last mark and a period long.
    public let tailSamples: Int

    private let tracker: PitchTracker
    private let shortest: Int
    private let briefest: Int
    private let longest: Int
    /// The input, both sides and their mean (the sound the marks are found in, without its DC, so
    /// that an offset cannot make any stretch resemble any other), `capacity` samples each, every
    /// sample written twice so that any stretch of them reads straight through.
    private let capacity: Int
    private let leftHistory: UnsafeMutablePointer<Float>
    private let rightHistory: UnsafeMutablePointer<Float>
    private let midHistory: UnsafeMutablePointer<Float>
    /// Where the newest input sample sits, counted from the start or the last `reset`.
    private var newest = -1
    /// Something other than silence has come in since the start or the last `reset`. Only then has
    /// a bad sample anything to empty, so a run of them costs one reset, not one per sample.
    private var holding = false
    /// The DC blocker on the mean, a one-pole high-pass at 20 Hz: its last input and output.
    private let blockerPole: Float
    private var blockerInput: Float = 0
    private var blockerOutput: Float = 0

    /// The pitch marks, the last `markCapacity` of `markCount`: each one's place in input samples,
    /// the length of its window's left half (back to the mark before; for a note's first mark one
    /// period, or less where the output has already played part of it), and whether it opens or
    /// closes a note.
    private let markCapacity: Int
    private let markPositions: UnsafeMutablePointer<Double>
    private let markLefts: UnsafeMutablePointer<Double>
    private let markFlags: UnsafeMutablePointer<UInt8>
    private var markCount = 0
    /// A note is open: its marks are still being found.
    private var open = false
    /// The period the next mark is looked for at, in samples.
    private var expected = 0.0
    /// Analyses in a row in which the tracker heard a period far from `expected`.
    private var disagreements = 0
    /// 2 or 3 when the last analysis heard that many of the marks' periods in one of its own, else 0:
    /// the marks then check once whether the note repeats clearly better at that longer period.
    private var multiple = 0
    /// Where the last closed note's fade ends; the next note's fade starts after it.
    private var previousEnd = -Double.infinity
    /// A new note's marks, found backwards, before they are kept.
    private let scratchCapacity: Int
    private let scratchPositions: UnsafeMutablePointer<Double>
    private let scratchLefts: UnsafeMutablePointer<Double>
    /// The correlations of one search.
    private let scoreCapacity: Int
    private let scores: UnsafeMutablePointer<Double>
    /// The periods a settling weighs, shortest first, and how well each repeats.
    private static let candidateCapacity = 5
    private let candidateLags: UnsafeMutablePointer<Double>
    private let candidateScores: UnsafeMutablePointer<Double>

    /// Laying grains: the synthesis phase counted in marks (k + f stands a share f of the way from
    /// mark k to the next), the furthest mark of the note it has walked to, the first mark of the
    /// next note, and the next grain's centre and mark once they are known (mark −1: not yet).
    private var laying = false
    private var phase = 0.0
    private var reached = 0
    private var nextNote = 0
    private var pendingCentre = 0.0
    private var pendingMark = -1

    private struct Grain {
        /// Where it is centred in the output and where it was cut in the input, in samples.
        var centre = 0.0
        var source = 0.0
        var mark = 0
        /// Its window's halves in output samples; `fall` is 0 until the mark after is known.
        var rise = 1.0
        var fall = 0.0
        /// Input samples read per output sample: the formant ratio.
        var speed = 1.0
        /// What the halves were divided by: the formant ratio, or 1 when that is below 1.
        var shrink = 1.0
        var gain: Float = 1
    }

    private let grains: UnsafeMutablePointer<Grain>
    private var grainCount = 0
    /// The first mark after the output's place, for the fade between the grains and the input.
    private var coverNext = 0
    /// 0.5 + 0.5·cos(π·i / tableSize) for i in 0 … tableSize.
    private let table: UnsafeMutablePointer<Float>

    private var ratio = 1.0
    private var formantRatio = 1.0
    private var grainGain: Float = 1

    public init(sampleRate: Double, settings: Settings = Settings()) {
        let rate = Self.sanitized(sampleRate)
        self.sampleRate = rate
        tracker = PitchTracker(sampleRate: rate)
        longest = Self.longestPeriod(sampleRate: rate)
        shortest = Self.shortestPeriod(sampleRate: rate)
        briefest = Self.briefestPeriod(sampleRate: rate)
        let latency = Self.latencySamples(sampleRate: rate)
        latencySamples = latency
        tailSamples = latency + (3 * longest) / 2 + 2
        capacity = latency + 3 * longest + 64
        leftHistory = .allocate(capacity: 2 * capacity)
        leftHistory.initialize(repeating: 0, count: 2 * capacity)
        rightHistory = .allocate(capacity: 2 * capacity)
        rightHistory.initialize(repeating: 0, count: 2 * capacity)
        midHistory = .allocate(capacity: 2 * capacity)
        midHistory.initialize(repeating: 0, count: 2 * capacity)
        blockerPole = Float(Foundation.exp(-2 * Double.pi * 20 / rate))
        let closest = Swift.max(1, briefest - Self.searchRadius(Double(briefest)))
        markCapacity = capacity / closest + 16
        markPositions = .allocate(capacity: markCapacity)
        markPositions.initialize(repeating: 0, count: markCapacity)
        markLefts = .allocate(capacity: markCapacity)
        markLefts.initialize(repeating: 1, count: markCapacity)
        markFlags = .allocate(capacity: markCapacity)
        markFlags.initialize(repeating: 0, count: markCapacity)
        scratchCapacity = (latency + 2 * longest) / closest + 4
        scratchPositions = .allocate(capacity: scratchCapacity)
        scratchPositions.initialize(repeating: 0, count: scratchCapacity)
        scratchLefts = .allocate(capacity: scratchCapacity)
        scratchLefts.initialize(repeating: 1, count: scratchCapacity)
        scoreCapacity = 2 * Self.searchRadius(Double(longest)) + 3
        scores = .allocate(capacity: scoreCapacity)
        scores.initialize(repeating: 0, count: scoreCapacity)
        candidateLags = .allocate(capacity: Self.candidateCapacity)
        candidateLags.initialize(repeating: 0, count: Self.candidateCapacity)
        candidateScores = .allocate(capacity: Self.candidateCapacity)
        candidateScores.initialize(repeating: 0, count: Self.candidateCapacity)
        grains = .allocate(capacity: Self.grainCapacity)
        grains.initialize(repeating: Grain(), count: Self.grainCapacity)
        table = .allocate(capacity: Self.tableSize + 1)
        for index in 0...Self.tableSize {
            table[index] = Float(0.5 + 0.5 * Foundation.cos(Double.pi * Double(index) / Double(Self.tableSize)))
        }
        self.settings = settings.clamped
        derive()
    }

    deinit {
        leftHistory.deallocate()
        rightHistory.deallocate()
        midHistory.deallocate()
        markPositions.deallocate()
        markLefts.deallocate()
        markFlags.deallocate()
        scratchPositions.deallocate()
        scratchLefts.deallocate()
        scores.deallocate()
        candidateLags.deallocate()
        candidateScores.deallocate()
        grains.deinitialize(count: Self.grainCapacity)
        grains.deallocate()
        table.deallocate()
    }

    private func derive() {
        ratio = Foundation.pow(2, settings.pitch / 12)
        formantRatio = Foundation.pow(2, settings.formant / 12)
        grainGain = Float((formantRatio / ratio).squareRoot())
    }

    /// Forgets everything it heard: the input, the pitch, the marks and the grains.
    public func reset() {
        tracker.reset()
        leftHistory.update(repeating: 0, count: 2 * capacity)
        rightHistory.update(repeating: 0, count: 2 * capacity)
        midHistory.update(repeating: 0, count: 2 * capacity)
        newest = -1
        holding = false
        blockerInput = 0
        blockerOutput = 0
        markCount = 0
        open = false
        expected = 0
        disagreements = 0
        multiple = 0
        previousEnd = -.infinity
        laying = false
        phase = 0
        reached = 0
        nextNote = 0
        pendingCentre = 0
        pendingMark = -1
        grainCount = 0
        coverNext = 0
    }

    /// Processes `frames` samples in place.
    public func process(left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, frames: Int) {
        for i in 0..<frames {
            var inLeft = left[i]
            var inRight = right[i]
            if !inLeft.isFinite || !inRight.isFinite {
                // The first of a run empties the shifter; the rest are silence for an empty one.
                if holding { reset() }
                inLeft = 0
                inRight = 0
            }
            let (outLeft, outRight) = step(inLeft, inRight)
            guard outLeft.isFinite, outRight.isFinite else {
                reset()
                left[i] = 0
                right[i] = 0
                continue
            }
            left[i] = outLeft
            right[i] = outRight
        }
    }

    /// One input pair in, one output pair out, `latencySamples` behind it.
    @inline(__always)
    private func step(_ inLeft: Float, _ inRight: Float) -> (Float, Float) {
        newest += 1
        if inLeft != 0 || inRight != 0 { holding = true }
        let place = slot(newest)
        // Halved before they are added, so that two of the largest floats cannot sum to infinity;
        // and a blocker that overflows starts again from silence — its state would otherwise stay
        // NaN, and no note would be found again.
        let both = 0.5 * inLeft + 0.5 * inRight
        var mean = both - blockerInput + blockerPole * blockerOutput
        if mean.isFinite {
            if Swift.abs(mean) < 1e-20 { mean = 0 }
            blockerInput = both
        } else {
            mean = 0
            blockerInput = 0
        }
        blockerOutput = mean
        leftHistory[place] = inLeft
        leftHistory[place + capacity] = inLeft
        rightHistory[place] = inRight
        rightHistory[place + capacity] = inRight
        midHistory[place] = mean
        midHistory[place + capacity] = mean
        if tracker.push(mean) {
            if open { compare() } else { listen() }
        }
        if open { follow() }
        let now = newest - latencySamples
        lay(until: now)
        let (grainLeft, grainRight) = grainSum(at: now)
        let dry = 1 - coverage(at: now)
        let input = slot(now)
        return (grainLeft + dry * leftHistory[input], grainRight + dry * rightHistory[input])
    }

    @inline(__always)
    private func slot(_ position: Int) -> Int {
        let remainder = position % capacity
        return remainder < 0 ? remainder + capacity : remainder
    }

    @inline(__always)
    private func markPosition(_ mark: Int) -> Double { markPositions[mark % markCapacity] }

    @inline(__always)
    private func markLeft(_ mark: Int) -> Double { markLefts[mark % markCapacity] }

    @inline(__always)
    private func markFlag(_ mark: Int) -> UInt8 { markFlags[mark % markCapacity] }

    private func append(_ position: Double, left: Double, flags: UInt8) {
        let index = markCount % markCapacity
        markPositions[index] = position
        markLefts[index] = left
        markFlags[index] = flags
        markCount += 1
    }

    /// After an analysis that heard a pitch, while no note is open: the period is settled from what
    /// the tracker heard (`settle`), the loudest point of the newest whole period becomes a mark if
    /// the period before it matches, and the note is marked back to where it began — as far as the
    /// output has not played yet, and never into the last note's fade.
    private func listen() {
        let heard = tracker.period
        guard heard > 0, heard.isFinite else { return }
        let guess = Swift.min(Swift.max(heard, Double(shortest)), Double(longest))
        guard let period = settle(guess, endingAt: newest) else { return }
        let span = Int(period.rounded())
        let radius = Self.searchRadius(period)
        let end = newest - radius - 2
        var peak = end
        var loudest: Float = 0
        for spot in (end - span + 1)...end {
            let value = Swift.abs(midHistory[slot(spot)])
            if value > loudest {
                loudest = value
                peak = spot
            }
        }
        guard loudest > 0, let back = match(endingAt: peak, lag: -span, radius: radius) else { return }
        let limit = Swift.max(Double(newest - latencySamples), previousEnd)
        var position = Double(peak)
        var left = -back.lag
        guard position - left >= limit else { return }
        scratchPositions[0] = position
        scratchLefts[0] = left
        var count = 1
        while count < scratchCapacity {
            let candidate = position - left
            let found = match(endingAt: Int(candidate.rounded()), lag: -Int(left.rounded()),
                              radius: Self.searchRadius(left))
            var candidateLeft = left
            if let found { candidateLeft = -found.lag }
            if candidate - candidateLeft < limit {
                // Its fade would begin where the output has already played: it may still open the
                // note on a shorter fade from there, if that is a quarter of a period or more.
                let room = candidate - limit
                if room >= 0.25 * candidateLeft {
                    scratchPositions[count] = candidate
                    scratchLefts[count] = room
                    count += 1
                }
                break
            }
            scratchPositions[count] = candidate
            scratchLefts[count] = candidateLeft
            count += 1
            position = candidate
            left = candidateLeft
            if found == nil { break }
        }
        open = true
        expected = -back.lag
        disagreements = 0
        multiple = 0
        for index in stride(from: count - 1, through: 0, by: -1) {
            append(scratchPositions[index], left: scratchLefts[index], flags: index == count - 1 ? Self.opens : 0)
        }
    }

    /// While a note is open: the next mark, about a period after the last, where the next period
    /// best matches it — or a half or a third of that period, if the sound repeats there nearly as
    /// well; where nothing matches, the note closes on the last mark. When the tracker has just
    /// heard two or three of the marks' periods in one of its own, the period is weighed against
    /// that longer one first (`reconsider`).
    private func follow() {
        while open {
            let last = markCount - 1
            let position = markPosition(last)
            let anchor = Int(position.rounded())
            if multiple > 1 {
                reconsider(at: anchor)
                multiple = 0
            }
            let span = Int(expected.rounded())
            let radius = Self.searchRadius(expected)
            guard newest >= anchor + span + radius else { return }
            guard let whole = match(endingAt: anchor, lag: span, radius: radius) else {
                closeNote()
                return
            }
            var chosen = whole
            let third = whole.lag / 3, half = whole.lag / 2
            if third >= Double(briefest),
               let shorter = match(endingAt: anchor, lag: Int(third.rounded()), radius: Self.searchRadius(third), window: span),
               shorter.score >= whole.score - Self.preference {
                chosen = shorter
            } else if half >= Double(briefest),
                      let shorter = match(endingAt: anchor, lag: Int(half.rounded()), radius: Self.searchRadius(half), window: span),
                      shorter.score >= whole.score - Self.preference {
                chosen = shorter
            }
            append(position + chosen.lag, left: chosen.lag, flags: 0)
            expected = chosen.lag
        }
    }

    /// After an analysis while a note is open: if the tracker keeps hearing a period that is
    /// neither the one the marks follow nor twice or three times it — the marks kept a lag a new
    /// note also happens to match — the note ends, and the next analysis starts it again on the
    /// tracker's period. Twice or three times is the tracker still hearing the note before a leap
    /// up that the marks have already taken — or a note that leapt down while the marks kept a part
    /// of its period, which `multiple` lets `follow` check.
    private func compare() {
        let heard = tracker.period
        guard heard > 0, heard.isFinite, expected > 0 else {
            disagreements = 0
            multiple = 0
            return
        }
        let ratio = Swift.max(heard / expected, expected / heard)
        let nearest = Swift.max(1, ratio.rounded())
        let apart = nearest > 3 || Swift.abs(ratio / nearest - 1) > Self.disagreement
        disagreements = apart ? disagreements + 1 : 0
        multiple = !apart && nearest > 1 && heard > expected ? Int(nearest) : 0
        if disagreements >= Self.patience { closeNote() }
    }

    /// Ends the open note on its newest mark; its fade lasts that mark's left half.
    private func closeNote() {
        let last = markCount - 1
        markFlags[last % markCapacity] |= Self.closes
        open = false
        disagreements = 0
        multiple = 0
        previousEnd = markPosition(last) + markLeft(last)
    }

    /// The period the marks follow, from the tracker's `guess`: of the guess, its third, half,
    /// double and triple — each a period the marks may follow — the shortest whose stretch ending at
    /// `end` matches the one before it nearly as well (within `preference`) as the best of them,
    /// because the shortest lag that repeats is the period. The tracker hears a note above its 1 kHz
    /// as two periods, and a vowel whose first formant sits on its second or third harmonic — half
    /// or a third of the period repeating nearly as well as the whole — an octave or more too high.
    /// Nil where none matches. Reads only the past.
    private func settle(_ guess: Double, endingAt end: Int) -> Double? {
        // Every candidate is weighed over the stretch of the longest one that fits (see `match`).
        let longestTimes = 3 * guess <= Double(longest) ? 3.0 : 2 * guess <= Double(longest) ? 2.0 : 1.0
        let window = Int((longestTimes * guess).rounded())
        let whole = match(endingAt: end, lag: -Int(guess.rounded()), radius: Self.searchRadius(guess), window: window)
        var base = guess
        if let whole { base = -whole.lag }
        var count = 0
        var best = -Double.infinity
        for share in 0..<Self.candidateCapacity {
            var found: (lag: Double, score: Double)?
            if share == 2 {
                found = whole
            } else if share < 2 {
                let lag = base / Double(3 - share)
                if lag >= Double(briefest) {
                    found = match(endingAt: end, lag: -Int(lag.rounded()), radius: Self.searchRadius(lag), window: window)
                }
            } else {
                let times = share - 1
                let lag = base * Double(times)
                if lag <= Double(longest) {
                    // A multiple of a period already refined between samples needs only a narrow search.
                    let radius = whole == nil ? Self.searchRadius(lag) : times + 1
                    found = match(endingAt: end, lag: -Int(lag.rounded()), radius: radius, window: window)
                }
            }
            guard let found else { continue }
            candidateLags[count] = -found.lag
            candidateScores[count] = found.score
            best = Swift.max(best, found.score)
            count += 1
        }
        for index in 0..<count where candidateScores[index] >= best - Self.preference {
            return candidateLags[index]
        }
        return nil
    }

    /// The tracker heard `multiple` of the marks' periods in one of its own. If the stretch before
    /// the last mark repeats clearly better (by more than `preference`) at that longer period than at
    /// one, the marks have been following a part of the period — a note that leapt an octave down
    /// and still nearly repeats at its old period, because its odd harmonics are weak — and they
    /// follow the longer one from here. Reads only the past.
    private func reconsider(at anchor: Int) {
        let longer = Double(multiple) * expected
        guard longer <= Double(longest) else { return }
        let window = Int(longer.rounded())
        guard let many = match(endingAt: anchor, lag: -window, radius: multiple + 1) else { return }
        let one = match(endingAt: anchor, lag: -Int(expected.rounded()), radius: 2, window: window)?.score ?? 0
        if many.score > one + Self.preference { expected = -many.lag }
    }

    /// The `window` samples of the mean ending at `end` (`|lag|` of them unless given) against as
    /// many ending at `end + l`, for every l within `radius` of `lag`: the l whose normalised
    /// correlation is highest, refined by a parabola through the correlations around it, and that
    /// correlation — if the two stretches resemble each other enough and |l| is a period the marks
    /// may follow; nil otherwise. Two lags are weighed against each other over the same window: over a
    /// stretch as short as itself, half the period of a vowel whose first formant sits on its second
    /// harmonic can match nearly as well as the whole period, and the octave above would win. Reads
    /// only the past.
    private func match(endingAt end: Int, lag: Int, radius: Int, window: Int? = nil) -> (lag: Double, score: Double)? {
        let length = window ?? Swift.abs(lag)
        let count = 2 * radius + 1
        guard length >= briefest / 2, count <= scoreCapacity else { return nil }
        let lowest = lag - radius
        let reference = midHistory + slot(end - length + 1)
        var referenceEnergy = 0.0
        for k in 0..<length {
            let value = Double(reference[k])
            referenceEnergy += value * value
        }
        guard referenceEnergy > 1e-12 else { return nil }
        var candidate = midHistory + slot(end + lowest - length + 1)
        var candidateEnergy = 0.0
        for k in 0..<length {
            let value = Double(candidate[k])
            candidateEnergy += value * value
        }
        var best = 0
        for index in 0..<count {
            if index > 0 {
                let leaving = Double(candidate[0]), entering = Double(candidate[length])
                candidateEnergy += entering * entering - leaving * leaving
                candidate += 1
            }
            var cross = 0.0
            for k in 0..<length { cross += Double(reference[k]) * Double(candidate[k]) }
            let energy = referenceEnergy * candidateEnergy
            scores[index] = energy > 1e-24 ? cross / energy.squareRoot() : 0
            if scores[index] > scores[best] { best = index }
        }
        guard scores[best] >= Self.resemblance else { return nil }
        var refined = Double(lowest + best)
        if best > 0, best < count - 1 {
            let before = scores[best - 1], at = scores[best], after = scores[best + 1]
            let curve = before - 2 * at + after
            if curve < 0 { refined += Swift.min(Swift.max(0.5 * (before - after) / curve, -0.5), 0.5) }
        }
        let size = Swift.abs(refined)
        guard refined.isFinite, size >= Double(briefest), size <= Double(longest) else { return nil }
        return (lag: refined, score: scores[best])
    }

    /// Lays down every grain whose window has begun by `now`, moving the synthesis phase on by one
    /// period over the pitch ratio after each.
    private func lay(until now: Int) {
        let time = Double(now)
        while true {
            if pendingMark < 0 {
                guard let next = nextGrain() else { return }
                pendingCentre = next.centre
                pendingMark = next.mark
            }
            let shrink = Swift.max(formantRatio, 1)
            guard pendingCentre - markLeft(pendingMark) / shrink <= time else { return }
            let right = rightHalf(of: pendingMark)
            if grainCount < Self.grainCapacity {
                grains[grainCount] = Grain(centre: pendingCentre, source: markPosition(pendingMark), mark: pendingMark,
                                           rise: markLeft(pendingMark) / shrink, fall: right > 0 ? right / shrink : 0,
                                           speed: formantRatio, shrink: shrink, gain: grainGain)
                grainCount += 1
            }
            pendingMark = -1
            phase += 1 / ratio
        }
    }

    /// Where the next grain is centred and the mark it is cut at: where the synthesis phase stands
    /// between two marks of the note, cut at the nearer one. A note's grains begin on its first
    /// mark and end half a period past its last; nil while the marks it needs are still to come.
    private func nextGrain() -> (centre: Double, mark: Int)? {
        while true {
            if !laying {
                guard nextNote < markCount else { return nil }
                laying = true
                phase = Double(nextNote)
                reached = nextNote
            }
            let index = Int(phase.rounded(.down))
            while reached < index, markFlag(reached) & Self.closes == 0 {
                guard reached + 1 < markCount else { return nil }
                reached += 1
            }
            let fraction = phase - Double(index)
            let closing = markFlag(reached) & Self.closes != 0
            if reached < index || (closing && fraction >= 0.5) {
                laying = false
                nextNote = reached + 1
                continue
            }
            let position = markPosition(index)
            if fraction == 0 { return (position, index) }
            if closing { return (position + fraction * markLeft(index), index) }
            guard index + 1 < markCount else { return nil }
            let following = markPosition(index + 1)
            return (position + fraction * (following - position), fraction < 0.5 ? index : index + 1)
        }
    }

    /// The right half of a mark's window, in input samples: up to the next mark, or for a note's
    /// last mark as long as its left half; 0 while the next mark is still to come.
    @inline(__always)
    private func rightHalf(of mark: Int) -> Double {
        if markFlag(mark) & Self.closes != 0 { return markLeft(mark) }
        guard mark + 1 < markCount else { return 0 }
        return markPosition(mark + 1) - markPosition(mark)
    }

    /// The grains sounding at output place `now`, summed; a grain that has ended is let go.
    @inline(__always)
    private func grainSum(at now: Int) -> (Float, Float) {
        let time = Double(now)
        var sumLeft: Float = 0
        var sumRight: Float = 0
        var index = 0
        while index < grainCount {
            let grain = grains[index]
            let offset = time - grain.centre
            let weight: Float
            if offset <= 0 {
                weight = shape(-offset / grain.rise)
            } else {
                var fall = grain.fall
                if fall == 0 {
                    let right = rightHalf(of: grain.mark)
                    fall = (right > 0 ? right : markLeft(grain.mark)) / grain.shrink
                    grains[index].fall = fall
                }
                guard offset < fall else {
                    grainCount -= 1
                    grains[index] = grains[grainCount]
                    continue
                }
                weight = shape(offset / fall)
            }
            let (x, y) = read(grain.source + grain.speed * offset)
            let scale = grain.gain * weight
            sumLeft += scale * x
            sumRight += scale * y
            index += 1
        }
        return (sumLeft, sumRight)
    }

    /// How much of the output the grains carry at output place `now`, 0 … 1: 1 inside a note,
    /// rising over a note's first period and falling over its last, with the grains' own windows.
    @inline(__always)
    private func coverage(at now: Int) -> Float {
        let time = Double(now)
        while coverNext < markCount, markPosition(coverNext) <= time { coverNext += 1 }
        if coverNext > 0 {
            let before = coverNext - 1
            if markFlag(before) & Self.closes == 0 { return 1 }
            let since = time - markPosition(before)
            let edge = markLeft(before)
            if since < edge { return shape(since / edge) }
        }
        if coverNext < markCount, markFlag(coverNext) & Self.opens != 0 {
            let until = markPosition(coverNext) - time
            let edge = markLeft(coverNext)
            if until < edge { return shape(until / edge) }
        }
        return 0
    }

    /// Both sides of the input at a place between samples, on a straight line; never ahead of the
    /// newest sample nor further back than the history holds.
    @inline(__always)
    private func read(_ position: Double) -> (Float, Float) {
        guard position.isFinite else { return (0, 0) }
        let bounded = Swift.min(Swift.max(position, Double(newest - capacity + 2)), Double(newest))
        let base = bounded.rounded(.down)
        let place = slot(Int(base))
        let fraction = Float(bounded - base)
        let left = leftHistory[place] + (leftHistory[place + 1] - leftHistory[place]) * fraction
        let right = rightHistory[place] + (rightHistory[place + 1] - rightHistory[place]) * fraction
        return (left, right)
    }

    /// The raised cosine 0.5 + 0.5·cos(π·x) for x in 0 … 1 — 1 at 0, 0 at 1 — from the table.
    @inline(__always)
    private func shape(_ x: Double) -> Float {
        let unit = Swift.min(1.0, Swift.max(0.0, x))
        let place = unit * Double(Self.tableSize)
        let index = Swift.min(Int(place), Self.tableSize - 1)
        let fraction = Float(place - Double(index))
        return table[index] + (table[index + 1] - table[index]) * fraction
    }
}
