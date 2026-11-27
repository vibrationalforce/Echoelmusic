import Foundation

/// How one body source moved while Record ran: body recording BR-1, the G-A contract's "Recorded"
/// path (`.claude/skills/g-a-body-modulation/references/CONTRACT.md`). A take is a list of runs,
/// each a stretch in which the source was measured without a break, with a gap wherever it was
/// not. Outside every run the source is absent, so a route on it adds exactly nothing there, as it
/// does live while a sensor is lost: a gap is never filled with a stand-in.
///
/// A point is a song position on the tick grid and the source's value there, 0 … 1: a value that
/// was read or, where a run ends or was cut, one held from a reading or taken from the line between
/// two; never rounded, never clamped. Between two points of a run the take moves in a straight
/// line. Thinning keeps some of the points, and `tolerance` states how far the take may then be
/// from the readings it was made from: every one lies within it, measured at the reading's tick.
///
/// One take per source, for the whole song: every route on the source follows it, a route made
/// after the recording too, and depth, curve and polarity stay free to change, because what is
/// kept is the source, not what it moved. Codable in the shape a song stores it in
/// (`Project.bodyTakes`, format 5; BR-2).
public struct BodyTake: Codable, Equatable, Sendable {
    /// One kept point: where in the song, as a tick, and the source's value there. A song stores
    /// points only as the two lists of their run (`Run`), never one by one.
    public struct Point: Equatable, Sendable {
        public var tick: Tick
        public var value: Double

        public init(tick: Tick, value: Double) {
            self.tick = tick
            self.value = value
        }
    }

    /// A stretch measured without a break: two points at least, ticks rising.
    ///
    /// A song stores a run as two lists of one length, `ticks` and `values`, the n-th value at the
    /// n-th tick. A take is the longest list a song holds, up to `maximumPoints`, and an object per
    /// point, `{tick, value}` as automation stores it, would about double its bytes and make it
    /// slower to write and to read. Two lists of different lengths are damage: the song is refused.
    public struct Run: Codable, Equatable, Sendable {
        public var points: [Point]

        public init(points: [Point]) {
            self.points = points
        }

        private enum CodingKeys: String, CodingKey {
            case ticks, values
        }

        public init(from decoder: any Decoder) throws {
            let stored = try decoder.container(keyedBy: CodingKeys.self)
            let ticks = try stored.decode([Tick].self, forKey: .ticks)
            let values = try stored.decode([Double].self, forKey: .values)
            guard ticks.count == values.count else {
                throw DecodingError.dataCorruptedError(forKey: .values, in: stored,
                                                       debugDescription: "a run holds one value for each tick")
            }
            points = zip(ticks, values).map { (pair: (Tick, Double)) -> Point in Point(tick: pair.0, value: pair.1) }
        }

        public func encode(to encoder: any Encoder) throws {
            var stored = encoder.container(keyedBy: CodingKeys.self)
            try stored.encode(points.map { (point: Point) -> Tick in point.tick }, forKey: .ticks)
            try stored.encode(points.map { (point: Point) -> Double in point.value }, forKey: .values)
        }
    }

    /// A source that measures the body (`BioEgressPolicy.measuresBody`).
    public var source: ModulationSource
    /// On, playback and export follow the take; off, it is kept and nothing plays it.
    public var enabled: Bool
    /// The stated largest distance, as a share of the source's travel, between the take and any
    /// reading it was made from.
    public var tolerance: Double
    /// In song order, each starting after the one before it has ended.
    public var runs: [Run]

    /// What a recording is thinned to first: 0.1 % of the source's travel. For the pulse, read over
    /// 40 … 200 bpm (`HealthPulse.plausibleBeats`), that is 0.16 bpm, finer than a chest strap's
    /// whole-bpm packet (0.625 %).
    public static let defaultTolerance = 0.001
    /// The tolerances a recording tries in turn while its take would hold more than
    /// `maximumPoints`: each doubles the one before, up to 1 %.
    public static let tolerances: [Double] = [0.001, 0.002, 0.004, 0.008, 0.01]
    /// The most points one take holds: enough that an hour of breath fits at the default tolerance
    /// with one reading per update of the source (a calculation on synthetic readings, not a
    /// measurement). A capture that reads every update twice, 60 readings a second of a source that
    /// changes 30 times, turns each change into a step the thinning has to trace, and the same hour
    /// then needs a larger tolerance. How readings reach the recorder is BR-5's decision.
    public static let maximumPoints = 50_000

    public init(source: ModulationSource, enabled: Bool = true, tolerance: Double = BodyTake.defaultTolerance,
                runs: [Run]) {
        self.source = source
        self.enabled = enabled
        self.tolerance = tolerance
        self.runs = runs
    }

    /// The points of every run together.
    public var pointCount: Int {
        runs.reduce(0) { (count: Int, run: Run) -> Int in count + run.points.count }
    }

    /// The source's value at a fractional tick, the position the engine plays: a point's own value
    /// on its tick, a straight line between two points of a run, nil outside every run and for a
    /// position that is not finite. Arithmetic and binary search only.
    public func value(atPosition position: Double) -> Double? {
        guard position.isFinite else { return nil }
        // How many runs start at or before the position; the last of them is the one it can be in.
        var low = 0, high = runs.count
        while low < high {
            let middle = (low + high) / 2
            if let first = runs[middle].points.first, Double(first.tick) <= position {
                low = middle + 1
            } else {
                high = middle
            }
        }
        guard low > 0 else { return nil }
        return Self.value(in: runs[low - 1].points, atPosition: position)
    }

    /// The take with a gap from `span.lowerBound` through `span.upperBound`. The curve outside is
    /// kept: a run the span cuts ends, or begins, with a point on its own line at the tick next to
    /// the span (the line up to it moves by no more than the rounding of one division), and every
    /// other point stays as it was. A piece left with one point covers no time and goes.
    public func removing(span: ClosedRange<Tick>) -> BodyTake {
        var take = self
        take.runs = Self.joined(before(span), after(span))
        return take
    }

    /// Punch-in: `take` inside `span`, its gaps included, and this take outside it, kept as
    /// `removing(span:)` keeps it. Where the two meet on neighbouring ticks they become one run, so
    /// a route never drops to nothing for the tick between. The stated tolerance is the larger of
    /// the two parts that are left; on or off stays as this take was.
    public func replacing(span: ClosedRange<Tick>, with take: BodyTake) -> BodyTake {
        let outside = (before(span), after(span))
        let inside = Self.restricted(take.runs, to: span)
        var result = self
        result.runs = Self.joined(Self.joined(outside.0, inside), outside.1)
        let keepsOutside = !outside.0.isEmpty || !outside.1.isEmpty
        if !inside.isEmpty {
            result.tolerance = keepsOutside ? Swift.max(tolerance, take.tolerance) : take.tolerance
        }
        return result
    }

    /// The runs before `span`, cut at the tick before it.
    private func before(_ span: ClosedRange<Tick>) -> [Run] {
        span.lowerBound > Tick.min ? Self.restricted(runs, to: Tick.min...(span.lowerBound - 1)) : []
    }

    /// The runs after `span`, cut at the tick after it.
    private func after(_ span: ClosedRange<Tick>) -> [Run] {
        span.upperBound < Tick.max ? Self.restricted(runs, to: (span.upperBound + 1)...Tick.max) : []
    }

    // MARK: - The arithmetic, shared by playback, cutting and thinning

    /// The line from `a` to `b` at `position`, in the arithmetic `AutomationLane` reads with.
    /// Thinning checks its lines with this, and playback reads the take with this, so a stated
    /// tolerance holds to the last bit. From `a`'s tick to just before `b`'s the line stays between
    /// the two values, rounding included: the share of the way is then below 1 by at least 2⁻⁵³,
    /// so the step it adds rounds short of the whole step, and a flat stretch adds nothing.
    @inline(__always)
    static func interpolate(_ a: Point, _ b: Point, at position: Double) -> Double {
        let length = Double(b.tick) - Double(a.tick)
        guard length > 0 else { return a.value }
        return a.value + (b.value - a.value) * ((position - Double(a.tick)) / length)
    }

    /// The value of one run at `position`, nil outside it.
    static func value(in points: [Point], atPosition position: Double) -> Double? {
        guard let first = points.first, let last = points.last,
              position >= Double(first.tick), position <= Double(last.tick) else { return nil }
        if position == Double(last.tick) { return last.value }
        // points[low].tick <= position < points[high].tick
        var low = 0, high = points.count - 1
        while low + 1 < high {
            let middle = (low + high) / 2
            if Double(points[middle].tick) <= position { low = middle } else { high = middle }
        }
        return interpolate(points[low], points[high], at: position)
    }

    /// Each run's part inside `range`, with a point on the run's line at each edge the range cuts
    /// through; a part with fewer than two points is dropped.
    static func restricted(_ runs: [Run], to range: ClosedRange<Tick>) -> [Run] {
        runs.compactMap { (run: Run) -> Run? in
            guard let first = run.points.first, let last = run.points.last,
                  first.tick <= range.upperBound, last.tick >= range.lowerBound else { return nil }
            var points = run.points.filter { (point: Point) -> Bool in range.contains(point.tick) }
            if first.tick < range.lowerBound, points.first?.tick != range.lowerBound,
               let cut = value(in: run.points, atPosition: Double(range.lowerBound)) {
                points.insert(Point(tick: range.lowerBound, value: cut), at: 0)
            }
            if last.tick > range.upperBound, points.last?.tick != range.upperBound,
               let cut = value(in: run.points, atPosition: Double(range.upperBound)) {
                points.append(Point(tick: range.upperBound, value: cut))
            }
            return points.count >= 2 ? Run(points: points) : nil
        }
    }

    /// `later` after `earlier`; a run ending one tick before the next begins is joined to it.
    static func joined(_ earlier: [Run], _ later: [Run]) -> [Run] {
        guard let next = later.first, let end = earlier.last?.points.last?.tick,
              let start = next.points.first?.tick, end < Tick.max, end + 1 == start else {
            return earlier + later
        }
        var runs = earlier
        runs[runs.count - 1].points += next.points
        return runs + later.dropFirst()
    }

    /// The points of one run thinned so that every one of them lies within `tolerance` of the kept
    /// line, measured vertically at its tick: the guarantee Ramer–Douglas–Peucker gives, found
    /// greedily. From the first point on, each kept point is followed by the farthest point the
    /// straight line to which passes every point between them; the last point is always kept. The
    /// search narrows the range of slopes from the kept point that still pass every point so far,
    /// and stops once none is left, so its work grows with the points, where RDP's splits crowd the
    /// end of a noisy stretch and read it again and again. (A line that keeps passing while no
    /// point can end it, an exact zigzag of ± `tolerance` around it, costs more.) Each line chosen
    /// is checked with the arithmetic playback reads the take with, so the tolerance holds to the
    /// last bit. Kept points are the run's own, untouched, and the same points always thin the
    /// same way.
    static func thinned(_ points: [Point], tolerance: Double) -> [Point] {
        guard points.count > 2, tolerance.isFinite, tolerance >= 0 else { return points }
        var kept = [points[0]]
        var reachable: [Int] = []
        var anchor = 0
        while anchor < points.count - 1 {
            let a = points[anchor]
            var low = -Double.infinity, high = Double.infinity
            reachable.removeAll(keepingCapacity: true)
            var index = anchor + 1
            while index < points.count {
                let length = Double(points[index].tick) - Double(a.tick)
                guard length > 0 else { break }
                let slope = (points[index].value - a.value) / length
                if slope >= low, slope <= high { reachable.append(index) }
                low = Swift.max(low, (points[index].value - tolerance - a.value) / length)
                high = Swift.min(high, (points[index].value + tolerance - a.value) / length)
                guard low <= high else { break }
                index += 1
            }
            // The farthest point the check confirms; the next one always passes, nothing lies between.
            var next = anchor + 1
            while let candidate = reachable.popLast() {
                if passes(points, from: anchor, to: candidate, within: tolerance) {
                    next = candidate
                    break
                }
            }
            kept.append(points[next])
            anchor = next
        }
        return kept
    }

    /// Whether every point between `first` and `last` lies within `tolerance` of the line from
    /// one to the other, as playback reads it.
    static func passes(_ points: [Point], from first: Int, to last: Int, within tolerance: Double) -> Bool {
        var index = first + 1
        while index < last {
            let error = Swift.abs(interpolate(points[first], points[last], at: Double(points[index].tick)) - points[index].value)
            guard error <= tolerance else { return false }
            index += 1
        }
        return true
    }
}

/// Collects one body source's readings while Record runs, and lands them as a `BodyTake` at Stop
/// (BR-1; the capture that feeds it comes with BR-5). The capture hands it what the source reads,
/// a value or nothing while it is not measured, with the song position the engine plays. Pure: no
/// clock, no sensor, no actor, so `landing(over:)` can run off the main actor.
///
/// - A reading that is nil, not finite or outside 0 … 1 is the source absent: a gap, never a 0,
///   never clamped.
/// - A position goes on the nearest tick of the grid every note and automation point is stored on
///   (those take the tick that is sounding, rounded down): at most half a tick from where it was
///   read. A position that is not finite, lies outside the song, or does not rise above the one
///   before it in the same pass is ignored, whatever was read there.
/// - A run ends at the first reading that found the source absent, holding its last value up to
///   there, as the engine held it until the value was cleared. The run the recording ends in stops
///   at its last reading.
/// - Every jump of the song position while Record runs, a loop's wrap or any other, is reported
///   with `wrap(from:to:)` and starts a new pass. Unreported, a jump forward joins the run before
///   it with a straight line over song time that never played.
/// - A recording replaces an earlier take only where it ran: from its first reading to its last,
///   less any song time a jump skipped. Each pass replaces the passes before it where it ran, its
///   gaps included; a pass that never measured the source replaces nothing, as a MIDI pass without
///   a note is no take.
public struct BodyTakeRecorder: Sendable {
    /// What became of a recording.
    public enum Outcome: Equatable, Sendable {
        /// The whole recording is in the take, each reading within the tolerance it states; where
        /// passes overlap, the newest pass's.
        case landed
        /// No stretch of the recording measured the source: an earlier take stays as it was.
        case nothingMeasured
        /// Even at the largest tolerance the take would hold more points than it may: the recording
        /// stopped at the reading at this tick, and what came before it is in the take.
        case stopped(at: Tick)
    }

    /// The take after a recording, and what became of the recording.
    public struct Landing: Equatable, Sendable {
        /// What the song holds for the source afterwards; nil when there is no take at all.
        public let take: BodyTake?
        public let outcome: Outcome
    }

    /// Where the song position jumped: before which reading, the tick it left off at, and the tick
    /// it went on from.
    private struct Wrap: Sendable {
        let index: Int
        let end: Tick?
        let start: Tick?
    }

    public let source: ModulationSource
    let maximumPoints: Int
    /// Every reading kept, in the order it came: its tick, and its value, NaN while the source was absent.
    private var ticks: [Tick] = []
    private var values: [Double] = []
    private var wraps: [Wrap] = []
    /// A reading in the current pass must lie after this tick.
    private var previous: Tick?

    /// A recorder for `source`; nil for a source that does not measure the body.
    public init?(source: ModulationSource) {
        self.init(source: source, maximumPoints: BodyTake.maximumPoints)
    }

    /// The same with a smaller limit, for a test; never more than a take may hold.
    init?(source: ModulationSource, maximumPoints: Int) {
        guard BioEgressPolicy.measuresBody(source) else { return nil }
        self.source = source
        self.maximumPoints = Swift.min(Swift.max(maximumPoints, 2), BodyTake.maximumPoints)
    }

    /// One reading: the source's value, or nil when it is not measured, at the song position the
    /// engine plays (a fractional tick under the tempo it plays). The recorder has no clock and no
    /// tempo, so it cannot tell a jump of the position from readings far apart: after a jump that
    /// was not reported with `wrap(from:to:)`, a reading continues the pass.
    public mutating func record(_ reading: Double?, atPosition position: Double) {
        guard let tick = Self.nearestTick(to: position) else { return }
        if let previous, tick <= previous { return }
        previous = tick
        ticks.append(tick)
        if let reading, reading.isFinite, reading >= 0, reading <= 1 {
            values.append(reading)
        } else {
            values.append(.nan)
        }
    }

    /// The song position jumped: it reached `end` and went on from `start`. A loop's wrap is one
    /// such jump; a locate, a chase or a re-sync while Record runs is another, and each is reported
    /// here, between the last reading before it and the first after it. The pass that ends holds
    /// its last value up to `end`; the readings that follow are a new pass, from `start` on, and its
    /// first reading holds back to `start`. Song time a jump forward skipped was not recorded: the
    /// take has a gap there, or keeps what an earlier take held.
    public mutating func wrap(from end: Double, to start: Double) {
        let first = Self.nearestTick(to: start)
        wraps.append(Wrap(index: ticks.count, end: Self.nearestTick(to: end), start: first))
        previous = first.map { (tick: Tick) -> Tick in tick - 1 }
    }

    /// What the song holds for the source once the recording lands over `earlier`, the take the
    /// song held before (a take of another source is not this one's). Thinned at the default
    /// tolerance, or at the first larger one at which the whole take fits `BodyTake.maximumPoints`;
    /// if none does, the recording stops at a reading where it still fits. A recording plays: the
    /// take it lands in is switched on.
    public func landing(over earlier: BodyTake?) -> Landing {
        let base = earlier?.source == source ? earlier : nil
        guard let recorded = fold(readings: ticks.count) else {
            return Landing(take: base, outcome: .nothingMeasured)
        }
        for tolerance in BodyTake.tolerances {
            let take = land(recorded, over: base, tolerance: tolerance)
            if take.pointCount <= maximumPoints { return Landing(take: take, outcome: .landed) }
        }
        // Even the largest tolerance holds too many points: keep the recording up to a reading at
        // which one more would not fit, found by halving. Not always the longest start that fits:
        // the points need not grow with each reading, since a later reading can let a line reach
        // farther, and a longer start can replace more of an earlier take or an earlier pass.
        let tolerance = BodyTake.tolerances.last ?? BodyTake.defaultTolerance
        var fitting = 0, failing = ticks.count
        while fitting + 1 < failing {
            let middle = fitting + (failing - fitting) / 2
            if let part = fold(readings: middle), land(part, over: base, tolerance: tolerance).pointCount > maximumPoints {
                failing = middle
            } else {
                fitting = middle
            }
        }
        let stop = fitting < ticks.count ? ticks[fitting] : ticks.last ?? 0
        let take = fold(readings: fitting).map { (part: Fold) -> BodyTake in land(part, over: base, tolerance: tolerance) }
        return Landing(take: take ?? base, outcome: .stopped(at: stop))
    }

    /// The song position on the nearest tick; nil for one that is not finite or lies outside the song.
    static func nearestTick(to position: Double) -> Tick? {
        guard position.isFinite else { return nil }
        let tick = MusicalTime.integer(position.rounded())
        guard tick >= 0, tick <= MusicalTime.maximumTick else { return nil }
        return tick
    }

    // MARK: - Landing

    /// The first readings as one unthinned take, each pass written over the ones before it, and
    /// the spans the passes that measured something covered, merged.
    private struct Fold {
        let take: BodyTake
        let covered: [ClosedRange<Tick>]
    }

    /// One pass while it is put together.
    private struct Pass {
        var first: Tick?
        var last: Tick?
        let start: Tick?
        var runs: [BodyTake.Run] = []
        var open: [BodyTake.Point] = []
        var read = false

        init(start: Tick?) {
            self.start = start
            first = start
            last = start
        }

        var span: ClosedRange<Tick>? {
            guard let first, let last, first <= last else { return nil }
            return first...last
        }

        mutating func add(tick: Tick, value: Double) {
            if value.isNaN {
                if let held = open.last {
                    open.append(BodyTake.Point(tick: tick, value: held.value))
                    closeRun()
                }
            } else {
                if open.isEmpty, !read, let start, start < tick {
                    open.append(BodyTake.Point(tick: start, value: value))
                }
                open.append(BodyTake.Point(tick: tick, value: value))
            }
            read = true
            if first == nil { first = tick }
            last = tick
        }

        /// The pass ends; at a jump's `end` the last value holds up to there.
        mutating func close(holdingTo end: Tick?) {
            if let end, let held = open.last, end > held.tick {
                open.append(BodyTake.Point(tick: end, value: held.value))
            }
            closeRun()
            if let end, end > (last ?? Tick.min) { last = end }
        }

        mutating func closeRun() {
            if open.count >= 2 { runs.append(BodyTake.Run(points: open)) }
            open = []
        }
    }

    /// The first `count` readings folded; nil when no pass among them measured the source.
    private func fold(readings count: Int) -> Fold? {
        var passes: [Pass] = []
        var pass = Pass(start: nil)
        var next = 0
        // Index `count` takes no reading: it ends the passes whose jump came after the last one.
        for index in 0...Swift.max(count, 0) {
            while next < wraps.count, wraps[next].index <= index {
                pass.close(holdingTo: wraps[next].end)
                passes.append(pass)
                pass = Pass(start: wraps[next].start)
                next += 1
            }
            if index < count { pass.add(tick: ticks[index], value: values[index]) }
        }
        pass.close(holdingTo: nil)
        passes.append(pass)

        var take = BodyTake(source: source, tolerance: 0, runs: [])
        var covered: [ClosedRange<Tick>] = []
        for pass in passes where !pass.runs.isEmpty {
            guard let span = pass.span else { continue }
            take = take.replacing(span: span, with: BodyTake(source: source, tolerance: 0, runs: pass.runs))
            covered = Self.merged(covered, span)
        }
        return covered.isEmpty ? nil : Fold(take: take, covered: covered)
    }

    /// `recorded` thinned at `tolerance` and written over `earlier` where it was recorded.
    private func land(_ recorded: Fold, over earlier: BodyTake?, tolerance: Double) -> BodyTake {
        let runs = recorded.take.runs.map { (run: BodyTake.Run) -> BodyTake.Run in
            BodyTake.Run(points: BodyTake.thinned(run.points, tolerance: tolerance))
        }
        let recording = BodyTake(source: source, tolerance: tolerance, runs: runs)
        var take = earlier ?? BodyTake(source: source, tolerance: tolerance, runs: [])
        var remainder = take
        for span in recorded.covered {
            take = take.replacing(span: span, with: recording)
            remainder = remainder.removing(span: span)
        }
        let keepsEarlier = earlier != nil && !remainder.runs.isEmpty
        take.tolerance = keepsEarlier ? Swift.max(earlier?.tolerance ?? tolerance, tolerance) : tolerance
        take.enabled = true
        return take
    }

    /// `spans` with `span` added, spans that overlap or meet on neighbouring ticks merged.
    private static func merged(_ spans: [ClosedRange<Tick>], _ span: ClosedRange<Tick>) -> [ClosedRange<Tick>] {
        var joined = span
        var apart: [ClosedRange<Tick>] = []
        for other in spans {
            if other.upperBound + 1 < joined.lowerBound || other.lowerBound > joined.upperBound + 1 {
                apart.append(other)
            } else {
                joined = Swift.min(other.lowerBound, joined.lowerBound)...Swift.max(other.upperBound, joined.upperBound)
            }
        }
        return (apart + [joined]).sorted { (a: ClosedRange<Tick>, b: ClosedRange<Tick>) -> Bool in a.lowerBound < b.lowerBound }
    }
}

// MARK: - In the song (BR-2)

extension BodyTake {
    /// The most takes one song holds, those kept from a newer build included: one per body source,
    /// with room to spare. The bound keeps a damaged file from carrying thousands of them.
    public static let maximumPerSong = 64

    /// The errors a take may state: from 0, every point a reading as it was read, to the largest a
    /// recording falls back to (`tolerances`). Beyond it a take would no longer say how the body
    /// moved, only roughly where it went.
    public static let toleranceRange: ClosedRange<Double> = 0...0.01

    /// Why a song cannot hold this take, as a clause the musician can read; nil when it can. Only a
    /// source that measures the body has a take; the rest is what every stored take obeys
    /// (`problem(runs:tolerance:)`).
    public var problem: String? {
        guard BioEgressPolicy.measuresBody(source) else { return "only a source that measures the body has a take" }
        return Self.problem(runs: runs, tolerance: tolerance)
    }

    /// The rules of a stored take whatever its source, so a take kept from a newer build obeys them
    /// too: a stated error within `toleranceRange`; one run at least, each of two points or more; at
    /// most `maximumPoints` points; every tick on the song's timeline and after the tick before it,
    /// so the ticks rise within a run and each run starts after the one before it ended; every value
    /// finite and within 0 … 1, as it was read.
    static func problem(runs: [Run], tolerance: Double) -> String? {
        guard tolerance.isFinite, toleranceRange.contains(tolerance) else {
            return "a take states an error of 0 to 1 % of its source's travel"
        }
        guard !runs.isEmpty else { return "a take holds at least one stretch of readings" }
        var count = 0
        var previous: Tick = -1
        for run in runs {
            guard run.points.count >= 2 else { return "every stretch of a take holds two points or more" }
            count += run.points.count
            guard count <= maximumPoints else { return "a take holds at most \(maximumPoints) points" }
            for point in run.points {
                guard point.tick > previous, point.tick <= MusicalTime.maximumTick else {
                    return "a take's ticks rise along the song, each stretch after the one before it ends"
                }
                guard point.value.isFinite, point.value >= 0, point.value <= 1 else {
                    return "a take's values lie within 0…1 of its source's travel"
                }
                previous = point.tick
            }
        }
        return nil
    }
}

extension Project {
    /// The take of `source`, if the song holds one.
    public func bodyTake(of source: ModulationSource) -> BodyTake? {
        bodyTakes.first { (take: BodyTake) -> Bool in take.source == source }
    }
}
