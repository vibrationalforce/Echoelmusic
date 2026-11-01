// Ported from the earlier app (Sources/Echoelmusic/Bio/RespirationEstimator.swift) for Echoel
// Studio, wave W12b "breath from the heartbeat". Kept from it, because each was paid for: the three
// filter time constants, the swing scale, the band accepted wider than the band targeted and never
// clamped back (#424), the swing divided by its own envelope (it is a normalized sine, not an
// envelope), and a staleness anchored on the last ACCEPTED crossing with the pipeline's delay
// subtracted rather than added (#452). What is new here says so where it stands. Pure, Foundation
// only.

import Foundation

/// The breath, read from the timing of the heartbeat (wave W12b). Breathing moves the pulse:
/// breathing in speeds it up, breathing out slows it down (respiratory sinus arrhythmia). The
/// beat-to-beat rate therefore swings with the breath, and this follows that swing.
///
/// Feed it each beat — the interval it closes and when it closed, in seconds on the caller's own
/// monotonic clock — and age it to "now" between beats. It answers:
/// - `amplitude` 0 … 1: 1 at the top of a breath in, 0 at the bottom of a breath out, 0.5 with no
///   swing. It is the swing as it stands NOW, not as it stood at the last beat (see below).
/// - `ratePerMinute`: breaths a minute; nil until one whole breath has been measured.
/// - `confidence` 0 … 1, the product of four parts, each of which alone can veto: the swing is big
///   enough, it repeats from one breath to the next, a breath was measured recently, and beats
///   still arrive.
/// - `breath`: the amplitude while the confidence holds, else nil. It turns on at
///   `publishConfidence` and off below `releaseConfidence`. Nil is the answer whenever the swing
///   is not clearly a breath — never a stand-in.
///
/// **How.** Each beat's rate (60 000 / interval) is stamped at the MIDDLE of its interval, because
/// an interval is the mean rate across it. A high-pass takes the slow baseline away, a low-pass
/// keeps the breath and drops beat-to-beat jitter, an envelope sizes the swing. Upward zero
/// crossings, placed between samples, give the breath's period. Every beat is an outlier check
/// first: a rate further than `outlierShare` from the baseline is a missed or an extra beat and is
/// left out; four in a row are a new rate, and a new run begins. A pause longer than `gapSeconds`
/// begins a new run too: nothing measured before a gap vouches for what follows it.
///
/// **Phase (new here).** A beat-to-beat series knows the swing only at its beats, late by half an
/// interval, and its filters add their own delay; at 15 breaths a minute that put the earlier
/// app's swing about a quarter of a breath behind the breath. So the newest sample is turned
/// FORWARD to now through the measured period: the sample a quarter period earlier is its
/// quadrature, and the angle is the time since the sample plus the filters' own delay at that
/// period. A breath in is then at the top while it is a breath in, however late the beats arrive.
///
/// **Repeats (new here).** A swing counts as a breath only while it looks like itself one breath
/// earlier: Pearson's correlation of the last one and a half periods with the same stretch one
/// period before, and of two breaths in a row the smaller counts — one stretch of random beats
/// that happens to look like the one before is not enough. Random beats cross zero as often as a
/// breath does, and their crossings are spaced almost as evenly; they do not repeat.
///
/// **A sensor's grid (new here).** A camera times beats to its frames, and a pulse that is steady
/// against the frame rate makes a pattern of long and short intervals that repeats as evenly as
/// any breath. Its swing is a fraction of one frame step, so the swing a breath needs is at least
/// `resolutionShare` of the rate step one `resolutionMilliseconds` makes.
///
/// **What it cannot tell apart.** Any other slow, even swing of the pulse reads the same — the
/// blood-pressure rhythm near six a minute is the known one. It reads best when the breath is slow
/// and even, where the breath's swing is large; a fast, shallow breath mixed with other swings
/// stays unmeasured. It is for self-observation and music, not a respiration monitor.
///
/// No allocation after `init`: the samples live in two preallocated rings.
public struct BreathEstimator: Sendable {
    // MARK: Constants kept from the earlier app

    /// High-pass: the pulse's slow baseline, removed so only the breath's swing remains (s).
    static let trendSeconds = 8.0
    /// Low-pass: keeps the breath, drops beat-to-beat jitter (s).
    static let smoothSeconds = 0.8
    /// How fast the swing's size follows it, for the 0 … 1 scale (s).
    static let envelopeSeconds = 6.0
    /// A mean swing this large, in beats a minute, is big enough to count fully.
    static let fullSwingBeatsPerMinute = 1.5
    /// About the peak of a sine over its mean absolute value: a clean breath spans 0 … 1.
    static let peakOverMeanSwing = 1.4
    /// The breaths a minute this estimator targets. A breath is ACCEPTED on a band wider by
    /// `acceptTolerance` at both ends, and the rate is never clamped back into this one: a clamp
    /// would put a made-up reading on the edge (#424).
    public static let slowestPerMinute = 4.0
    public static let fastestPerMinute = 30.0
    static let acceptTolerance = 1.06
    /// The delay between a breath's crossing and the beat that shows it reaching here, not charged
    /// as staleness (the earlier app's camera budget; a strap's delay is shorter).
    static let lagAllowanceSeconds = 1.8

    // MARK: Constants new here

    /// A breath shorter than this many beats cannot be read from beats: the pattern of long and
    /// short intervals a sensor's grid makes repeats every two or three beats.
    static let minimumBeatsPerBreath = 3.0
    /// Longer than this without a beat, and a new run begins.
    static let gapSeconds = 5.0
    /// A beat whose rate lies further than this share from the baseline is an outlier.
    static let outlierShare = 0.3
    /// This many outliers in a row are a new rate, not outliers: a new run begins.
    static let outliersForNewRate = 4
    /// How much of the swing is compared with itself one period earlier, in periods.
    static let comparedPeriods = 1.5
    /// The correlation at which the repeat counts nothing, and at which it counts fully.
    static let unrelatedCorrelation = 0.5
    static let repeatingCorrelation = 0.85
    /// How far each new correlation moves the remembered one.
    static let correlationSmoothing = 0.34
    /// Beats are fresh this long after the last one; the confidence is gone at `beatsGoneSeconds`.
    static let beatsFreshSeconds = 3.5
    static let beatsGoneSeconds = 6.0
    /// The smallest swing a breath needs, as a share of one timing step of the sensor.
    static let resolutionShare = 0.75
    /// Samples kept for the repeat and the quarter-period look back: 2.5 of the slowest periods
    /// at a fast pulse.
    static let capacity = 128

    /// The confidence at which `breath` begins, and below which it ends.
    public static let publishConfidence = 0.4
    public static let releaseConfidence = 0.3

    // MARK: Outputs

    /// 1 at the top of a breath in, 0 at the bottom of a breath out; 0.5 with no swing.
    public private(set) var amplitude = 0.5
    /// Breaths a minute, from the smoothed period; nil until one breath has been measured.
    public private(set) var ratePerMinute: Double?
    /// 0 … 1, see the type's documentation.
    public private(set) var confidence = 0.0
    /// The amplitude while the breath is clearly measured, else nil.
    public var breath: Double? { publishing ? amplitude : nil }

    // MARK: State

    private var publishing = false
    /// When the newest beat taken ended, on the caller's clock.
    private var lastEnd: Double?
    /// The middle of the newest beat in the filters: the time of the newest sample.
    private var lastStamp: Double?
    private var trend = 0.0
    private var smooth = 0.0
    private var envelope = 0.0
    private var lastCrossing: Double?
    private var lastAccepted: Double?
    /// The smoothed breath period in seconds; 0 until one is accepted.
    private var period = 0.0
    /// The smoothed correlation, from the second one measured in this run on; nil before.
    private var regularity: Double?
    /// The newest correlation, which the next one is paired with.
    private var lastCorrelation: Double?
    /// The latest time this was told about, by a beat or by `age(to:)`; it never runs back.
    private var clock: Double?
    private var outliersInARow = 0
    /// One timing step of the beats' source, in milliseconds.
    private var resolution = 1.0
    /// The samples, a ring: `stamps[i]`, `swings[i]`; `head` is the next write, `count` how many.
    private var stamps: [Double]
    private var swings: [Double]
    private var head = 0
    private var count = 0

    public init() {
        stamps = [Double](repeating: 0, count: Self.capacity)
        swings = [Double](repeating: 0, count: Self.capacity)
    }

    /// Everything forgotten: a stopped source, a new take.
    public mutating func reset() {
        amplitude = 0.5
        ratePerMinute = nil
        confidence = 0
        publishing = false
        lastEnd = nil
        lastStamp = nil
        trend = 0
        smooth = 0
        envelope = 0
        lastCrossing = nil
        lastAccepted = nil
        period = 0
        regularity = nil
        lastCorrelation = nil
        clock = nil
        outliersInARow = 0
        resolution = 1
        head = 0
        count = 0
    }

    // MARK: Input

    /// One beat: the interval it closes, in milliseconds, and when it closed, in seconds on the
    /// caller's monotonic clock. `resolutionMilliseconds` is the source's timing step — a camera's
    /// frame period; a strap times to about a millisecond. A non-finite or implausible interval
    /// (outside 300 … 2 000 ms, the band `RRIntervalHygiene` holds) and a beat that does not come
    /// after the last one are ignored.
    public mutating func add(intervalMilliseconds interval: Double, endingAt end: Double,
                             resolutionMilliseconds: Double = 1) {
        guard interval.isFinite, end.isFinite,
              interval >= RRIntervalHygiene.minPlausibleMs, interval <= RRIntervalHygiene.maxPlausibleMs else { return }
        let stamp = end - interval / 2_000
        if let lastEnd, end <= lastEnd { return }
        if let lastStamp, stamp <= lastStamp { return }
        let beatsPerMinute = 60_000 / interval
        let gap = lastEnd.map { end - $0 > Self.gapSeconds } ?? true
        if gap {
            restart()
        }
        lastEnd = end
        if resolutionMilliseconds.isFinite, resolutionMilliseconds > 0 { resolution = resolutionMilliseconds }
        // Beats arrive late, so the state stays at the latest time it was told about.
        let now = Swift.max(end, clock ?? end)
        guard let previousStamp = lastStamp else {
            begin(at: beatsPerMinute, stamp: stamp)
            refresh(at: now)
            return
        }
        guard Swift.abs(beatsPerMinute - trend) <= Self.outlierShare * trend else {
            outliersInARow += 1
            if outliersInARow >= Self.outliersForNewRate {
                restart()
                lastEnd = end
                begin(at: beatsPerMinute, stamp: stamp)
            }
            refresh(at: now)
            return
        }
        outliersInARow = 0
        let step = stamp - previousStamp
        trend += (1 - Foundation.exp(-step / Self.trendSeconds)) * (beatsPerMinute - trend)
        let deviation = beatsPerMinute - trend
        let before = smooth
        smooth += (1 - Foundation.exp(-step / Self.smoothSeconds)) * (deviation - smooth)
        envelope += (1 - Foundation.exp(-step / Self.envelopeSeconds)) * (Swift.abs(smooth) - envelope)
        lastStamp = stamp
        remember(smooth, at: stamp)
        // An upward zero crossing, placed between the two samples rather than on a beat.
        if before < 0, smooth >= 0 {
            crossed(at: previousStamp + step * (-before) / (smooth - before), newest: stamp)
        }
        refresh(at: now)
    }

    /// A strap's packet: its intervals in the order they happened, the last one ending about when
    /// the packet arrived. They are placed back from the arrival, so a packet the strap lost
    /// leaves a pause in time, as it should, and a beat that would land on one already taken is
    /// dropped.
    public mutating func add(packet intervals: [Double], arrivedAt arrival: Double) {
        guard arrival.isFinite else { return }
        var total = 0.0
        for interval in intervals where interval.isFinite && interval > 0 { total += interval }
        var end = arrival - total / 1_000
        for interval in intervals where interval.isFinite && interval > 0 {
            end += interval / 1_000
            add(intervalMilliseconds: interval, endingAt: end)
        }
    }

    /// Time passed without a beat: the amplitude turns on with the breath and the confidence ages,
    /// so a breath measured a while ago does not stay certified (the earlier app's latch). `now`
    /// is on the clock the beats use. A time before the last beat, or before a time already asked
    /// about, is refused: it means two clocks were mixed, and ageing back would raise the
    /// confidence again.
    public mutating func age(to now: Double) {
        guard now.isFinite, let lastEnd, now >= lastEnd, now >= (clock ?? now) else { return }
        refresh(at: now)
    }

    // MARK: Steps

    /// A new run on the same source: everything measured goes; the source's timing step and the
    /// clock stay.
    private mutating func restart() {
        let step = resolution
        let told = clock
        reset()
        resolution = step
        clock = told
    }

    private mutating func begin(at beatsPerMinute: Double, stamp: Double) {
        trend = beatsPerMinute
        smooth = 0
        lastStamp = stamp
        remember(0, at: stamp)
    }

    /// A crossing: the period from the one before, if it is a breath, and how much the swing
    /// repeats over it. The crossing anchors the next period either way.
    private mutating func crossed(at time: Double, newest: Double) {
        defer { lastCrossing = time }
        guard let earlier = lastCrossing, trend > 0 else { return }
        let length = time - earlier
        guard length > 0 else { return }
        let perMinute = 60 / length
        guard perMinute >= Self.slowestPerMinute / Self.acceptTolerance,
              perMinute <= Self.fastestPerMinute * Self.acceptTolerance,
              length >= Self.minimumBeatsPerBreath * 60 / trend else { return }
        period = period == 0 ? length : period + 0.3 * (length - period)
        ratePerMinute = 60 / period
        lastAccepted = time
        guard let repeats = correlation(over: period, until: newest) else { return }
        if let previous = lastCorrelation {
            let both = Swift.min(previous, repeats)
            regularity = regularity.map { $0 + Self.correlationSmoothing * (both - $0) } ?? both
        }
        lastCorrelation = repeats
    }

    /// Amplitude, confidence and whether the breath is published, at `now`, which the callers keep
    /// from running back.
    private mutating func refresh(at now: Double) {
        clock = now
        let reach = Swift.max(envelope, 1e-6) * Self.peakOverMeanSwing
        let unit = Swift.min(1, Swift.max(-1, swing(at: now) / reach))
        amplitude = unit.isFinite ? 0.5 + 0.5 * unit : 0.5
        confidence = currentConfidence(at: now)
        let bar = publishing ? Self.releaseConfidence : Self.publishConfidence
        publishing = ratePerMinute != nil && confidence >= bar
    }

    private func currentConfidence(at now: Double) -> Double {
        guard let regularity, let accepted = lastAccepted, let lastEnd, period > 0, trend > 0 else { return 0 }
        let gridStep = trend * trend * resolution / 60_000
        let size = Swift.min(1, envelope / Swift.max(Self.fullSwingBeatsPerMinute, Self.resolutionShare * gridStep))
        let repeats = Swift.min(1, Swift.max(0, (regularity - Self.unrelatedCorrelation)
            / (Self.repeatingCorrelation - Self.unrelatedCorrelation)))
        // A period and a half of grace after the last breath measured, then the same span to fade.
        let grace = 1.5 * period
        let charged = Swift.max(0, now - accepted - Self.lagAllowanceSeconds)
        let recent = charged <= grace ? 1 : Swift.max(0, 1 - (charged - grace) / grace)
        let silence = now - lastEnd
        let beating = silence <= Self.beatsFreshSeconds
            ? 1
            : Swift.max(0, 1 - (silence - Self.beatsFreshSeconds) / (Self.beatsGoneSeconds - Self.beatsFreshSeconds))
        let product = size * repeats * recent * beating
        return product.isFinite ? Swift.min(1, Swift.max(0, product)) : 0
    }

    /// The swing as it stands at `now`: the newest sample turned forward by the time since it and
    /// the filters' own delay, at the measured period. Without a period, or before the samples
    /// reach a quarter period back, the newest sample as it is.
    private func swing(at now: Double) -> Double {
        guard period > 0, let stamp = lastStamp, let back = swing(atStamp: stamp - period / 4) else { return smooth }
        let ahead = Swift.max(0, now - stamp) + filterDelay(period: period)
        let turn = 2 * Double.pi * ahead / period
        return smooth * Foundation.cos(turn) - back * Foundation.sin(turn)
    }

    /// The seconds the high-pass and the low-pass put between the swing and `smooth` at a breath of
    /// `period`, for samples one beat apart: their discrete phase at that frequency.
    private func filterDelay(period: Double) -> Double {
        guard trend > 0, period > 0 else { return 0 }
        let beat = 60 / trend
        let frequency = 2 * Double.pi / period
        let angle = frequency * beat
        let keepTrend = Foundation.exp(-beat / Self.trendSeconds)
        let keepSmooth = Foundation.exp(-beat / Self.smoothSeconds)
        let sine = Foundation.sin(angle)
        let cosine = Foundation.cos(angle)
        let highPass = Foundation.atan2(sine, 1 - cosine) - Foundation.atan2(keepTrend * sine, 1 - keepTrend * cosine)
        let lowPass = -Foundation.atan2(keepSmooth * sine, 1 - keepSmooth * cosine)
        let delay = -(highPass + lowPass) / frequency
        return delay.isFinite ? delay : 0
    }

    // MARK: The samples

    private mutating func remember(_ value: Double, at stamp: Double) {
        stamps[head] = stamp
        swings[head] = value
        head = (head + 1) % Self.capacity
        count = Swift.min(count + 1, Self.capacity)
    }

    /// The ring position of the `index`-th sample, oldest first.
    private func slot(_ index: Int) -> Int {
        (head - count + index + Self.capacity) % Self.capacity
    }

    /// The swing at `time`, read between the two samples around it; nil outside the samples.
    private func swing(atStamp time: Double) -> Double? {
        guard count > 0 else { return nil }
        let first = stamps[slot(0)]
        let last = stamps[slot(count - 1)]
        guard time >= first, time <= last else { return nil }
        if count == 1 { return swings[slot(0)] }
        var low = 0
        var high = count - 1
        while high - low > 1 {
            let middle = (low + high) / 2
            if stamps[slot(middle)] <= time { low = middle } else { high = middle }
        }
        let start = stamps[slot(low)]
        let stop = stamps[slot(high)]
        guard stop > start else { return swings[slot(low)] }
        let share = (time - start) / (stop - start)
        return swings[slot(low)] + share * (swings[slot(high)] - swings[slot(low)])
    }

    /// Pearson's correlation of the last `comparedPeriods` of the swing with the same stretch one
    /// `period` earlier; nil while the samples do not reach back that far.
    private func correlation(over period: Double, until now: Double) -> Double? {
        guard count > 0, period > 0 else { return nil }
        let window = Self.comparedPeriods * period
        guard stamps[slot(0)] <= now - window - period else { return nil }
        var n = 0.0, sumX = 0.0, sumY = 0.0, sumXX = 0.0, sumYY = 0.0, sumXY = 0.0
        for index in 0..<count {
            let position = slot(index)
            let time = stamps[position]
            guard time >= now - window else { continue }
            guard let earlier = swing(atStamp: time - period) else { return nil }
            let x = swings[position]
            n += 1
            sumX += x
            sumY += earlier
            sumXX += x * x
            sumYY += earlier * earlier
            sumXY += x * earlier
        }
        guard n >= 4 else { return nil }
        let covariance = sumXY - sumX * sumY / n
        let spreadX = sumXX - sumX * sumX / n
        let spreadY = sumYY - sumY * sumY / n
        guard spreadX > 0, spreadY > 0 else { return nil }
        let r = covariance / (spreadX * spreadY).squareRoot()
        return r.isFinite ? r : nil
    }
}
