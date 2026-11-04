import Foundation

/// A change of time signature on a bar line: from `tick` the song counts bars of `numerator`
/// beats of `1/denominator`, until the next change. The song's own `timeSignature` is the first
/// bar's, as it always was.
public struct TimeSignatureChange: Codable, Equatable, Hashable, Sendable {
    public let tick: Tick
    public let numerator: Int
    public let denominator: Int

    public init(tick: Tick, signature: TimeSignature) {
        self.tick = tick
        self.numerator = signature.numerator
        self.denominator = signature.denominator
    }

    public var signature: TimeSignature { TimeSignature(numerator, denominator) }
}

/// The song's bars over time: the project's time signature from tick 0, then each change — the
/// one answer to "where is the bar line, where is the beat" for the click, the launch quantum,
/// the host's downbeat, snapping and export. A song without changes answers exactly as the
/// constant `MusicalTime.ticksPerBar` did.
///
/// Built on the main thread; every lookup is a binary search over an array it already holds plus
/// integer arithmetic, so the render thread may call it without allocating.
public struct MeterMap: Equatable, Sendable {
    public struct Segment: Equatable, Sendable {
        public let startTick: Tick
        /// The bar this segment starts with, counted from 0 (bar 1 is 0).
        public let startBar: Int64
        public let signature: TimeSignature
        public let barTicks: Tick
        public let beatTicks: Tick
    }

    public let segments: [Segment]

    /// `changes` in any order; one at or before tick 0, or at the tick of the one before it,
    /// replaces it. A change off a bar line — which no command writes and no song file opens
    /// with (`Project.validate`) — counts from the next bar line, so a lookup never fails.
    public init(signature: TimeSignature, changes: [TimeSignatureChange] = []) {
        var segments = [Self.segment(at: 0, bar: 0, signature)]
        for change in changes.sorted(by: { $0.tick < $1.tick }) {
            guard let last = segments.last else { break }
            let signature = change.signature.isValid ? change.signature : last.signature
            if change.tick <= last.startTick {
                segments[segments.count - 1] = Self.segment(at: last.startTick, bar: last.startBar, signature)
                continue
            }
            let bars = (change.tick - last.startTick + last.barTicks - 1) / last.barTicks
            let start = last.startTick + bars * last.barTicks
            if start == last.startTick { continue }
            segments.append(Self.segment(at: start, bar: last.startBar + bars, signature))
        }
        self.segments = segments
    }

    private static func segment(at tick: Tick, bar: Int64, _ signature: TimeSignature) -> Segment {
        let valid = signature.isValid ? signature : .common
        return Segment(startTick: tick, startBar: bar, signature: valid,
                       barTicks: Swift.max(MusicalTime.ticksPerBar(valid), 1),
                       beatTicks: Swift.max(MusicalTime.ticksPerBeat(valid), 1))
    }

    /// The meter as heard from `tick` on, with `tick` as 0: the signature playing there, then each
    /// later change, shifted. What a clip placed at `tick` counts in its own time.
    public func starting(at tick: Tick) -> MeterMap {
        let first = segments[index(atTick: tick)]
        let later = segments.filter { $0.startTick > tick }
            .map { TimeSignatureChange(tick: $0.startTick - tick, signature: $0.signature) }
        return MeterMap(signature: first.signature, changes: later)
    }

    /// Whether the song keeps one time signature throughout.
    public var isConstant: Bool { segments.count == 1 }

    public func signature(at tick: Tick) -> TimeSignature { segments[index(atTick: tick)].signature }
    public func ticksPerBar(at tick: Tick) -> Tick { segments[index(atTick: tick)].barTicks }
    public func ticksPerBeat(at tick: Tick) -> Tick { segments[index(atTick: tick)].beatTicks }

    /// The bar holding `tick`, counted from 0. Before tick 0 the first signature extrapolates.
    public func bar(at tick: Tick) -> Int64 {
        let s = segments[index(atTick: tick)]
        return s.startBar + Self.floorDivide(tick - s.startTick, s.barTicks)
    }

    /// The bar line at or before `tick`.
    public func barStart(at tick: Tick) -> Tick {
        let s = segments[index(atTick: tick)]
        return s.startTick + Self.floorDivide(tick - s.startTick, s.barTicks) * s.barTicks
    }

    /// Where bar `index` (counted from 0) starts. Saturates past any tick a song holds.
    public func tick(ofBar index: Int64) -> Tick {
        var low = 0, high = segments.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if segments[mid].startBar <= index { low = mid } else { high = mid - 1 }
        }
        let s = segments[low]
        let (product, overflow) = (index - s.startBar).multipliedReportingOverflow(by: s.barTicks)
        guard !overflow else { return index < s.startBar ? .min : .max }
        let (sum, overflowed) = s.startTick.addingReportingOverflow(product)
        return overflowed ? (product < 0 ? .min : .max) : sum
    }

    public func isBarLine(_ tick: Tick) -> Bool { barStart(at: tick) == tick }

    /// The first bar line at or after `tick`.
    public func nextBarLine(atOrAfter tick: Tick) -> Tick {
        let start = barStart(at: tick)
        return start == tick ? tick : start + ticksPerBar(at: tick)
    }

    /// The bar line nearest `tick` (half way rounds up), never before bar 1.
    public func nearestBarLine(_ tick: Tick) -> Tick {
        let clamped = Swift.max(0, tick)
        let start = barStart(at: clamped)
        let length = ticksPerBar(at: clamped)
        return clamped - start >= (length + 1) / 2 ? start + length : start
    }

    /// The beat at or before `tick`, in the signature playing there. A change falls on a bar
    /// line, which is a beat of both signatures, so beats count on across it.
    public func beatStart(at tick: Tick) -> Tick {
        let s = segments[index(atTick: tick)]
        return s.startTick + Self.floorDivide(tick - s.startTick, s.beatTicks) * s.beatTicks
    }

    private func index(atTick tick: Tick) -> Int {
        var low = 0, high = segments.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if segments[mid].startTick <= tick { low = mid } else { high = mid - 1 }
        }
        return low
    }

    private static func floorDivide(_ a: Tick, _ b: Tick) -> Tick {
        let q = a / b
        return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q
    }
}

extension Project {
    /// The bars this project counts.
    public var meterMap: MeterMap { MeterMap(signature: timeSignature, changes: timeSignatureChanges) }

    /// The bars a clip counts in its own time: the song's meter from the clip's earliest
    /// placement in the arrangement. A clip that only plays in the session has no place in the
    /// song, so it counts the first bar's signature, as every launch quantum of one bar did
    /// before a song could change its meter.
    public func clipMeter(_ clip: ClipID) -> MeterMap {
        let starts = tracks.flatMap { $0.placements.filter { $0.clip == clip }.map(\.start) }
        guard let first = starts.min() else { return MeterMap(signature: timeSignature) }
        return meterMap.starting(at: first)
    }
}
