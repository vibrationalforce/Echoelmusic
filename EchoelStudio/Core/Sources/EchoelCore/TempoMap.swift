import Foundation

/// A tempo change that takes effect at `tick` and holds until the next one.
public struct TempoChange: Codable, Equatable, Hashable, Sendable {
    public let tick: Tick
    public let bpm: Double

    public init(tick: Tick, bpm: Double) {
        self.tick = tick
        self.bpm = bpm
    }
}

/// The song's tempo over time: the project tempo from tick 0, then each change in order.
/// Every conversion between musical time (ticks) and clock time (seconds, samples) goes
/// through this, so audio, MIDI clock and — later — light and video agree on one timeline.
///
/// Built on the main thread; every lookup is a binary search over arrays it already holds,
/// so the render thread may call it without allocating.
public struct TempoMap: Equatable, Sendable {
    public struct Segment: Equatable, Sendable {
        public let startTick: Tick
        public let bpm: Double
        public let startSeconds: Double

        var secondsPerTick: Double { 60 / (bpm * Double(MusicalTime.ticksPerQuarter)) }
    }

    public let segments: [Segment]

    public init(bpm: Double, changes: [TempoChange] = []) {
        var segments = [Segment(startTick: 0, bpm: bpm, startSeconds: 0)]
        for change in changes.sorted(by: { $0.tick < $1.tick }) where change.tick > 0 {
            guard let last = segments.last else { break }
            if change.tick == last.startTick {
                segments[segments.count - 1] = Segment(startTick: last.startTick, bpm: change.bpm,
                                                       startSeconds: last.startSeconds)
                continue
            }
            let seconds = last.startSeconds + Double(change.tick - last.startTick) * last.secondsPerTick
            segments.append(Segment(startTick: change.tick, bpm: change.bpm, startSeconds: seconds))
        }
        self.segments = segments
    }

    public func bpm(at tick: Tick) -> Double {
        segments[segmentIndex(atTick: tick)].bpm
    }

    /// Clock time of `tick`, counted from tick 0. Negative ticks extrapolate the first tempo.
    public func seconds(at tick: Tick) -> Double {
        let s = segments[segmentIndex(atTick: tick)]
        return s.startSeconds + Double(tick - s.startTick) * s.secondsPerTick
    }

    /// The tick sounding at `seconds`, rounded down. Non-finite input reads as tick 0.
    public func tick(atSeconds seconds: Double) -> Tick {
        guard seconds.isFinite else { return 0 }
        let s = segments[segmentIndex(atSeconds: seconds)]
        let ticks = (seconds - s.startSeconds) / s.secondsPerTick
        return s.startTick + Tick(ticks.rounded(.down))
    }

    /// Where in musical time `seconds` falls, in fractional ticks — for what moves continuously
    /// (automation), where a whole tick would be a step. Non-finite input reads as 0.
    public func position(atSeconds seconds: Double) -> Double {
        guard seconds.isFinite else { return 0 }
        let s = segments[segmentIndex(atSeconds: seconds)]
        return Double(s.startTick) + (seconds - s.startSeconds) / s.secondsPerTick
    }

    /// Clock time of a fractional tick — the inverse of `position(atSeconds:)`. Non-finite input
    /// reads as 0.
    public func seconds(atPosition position: Double) -> Double {
        guard position.isFinite else { return 0 }
        let whole = Tick(Swift.min(Swift.max(position, -Double(MusicalTime.maximumTick)), Double(MusicalTime.maximumTick)).rounded(.down))
        let s = segments[segmentIndex(atTick: whole)]
        return s.startSeconds + (position - Double(s.startTick)) * s.secondsPerTick
    }

    private func segmentIndex(atTick tick: Tick) -> Int {
        var low = 0, high = segments.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if segments[mid].startTick <= tick { low = mid } else { high = mid - 1 }
        }
        return low
    }

    private func segmentIndex(atSeconds seconds: Double) -> Int {
        var low = 0, high = segments.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if segments[mid].startSeconds <= seconds { low = mid } else { high = mid - 1 }
        }
        return low
    }
}

extension Project {
    /// The tempo map this project plays at.
    public var tempoMap: TempoMap { TempoMap(bpm: tempo, changes: tempoChanges) }
}
