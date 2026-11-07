import Foundation

/// How long a queued session clip still waits, for its countdown in the session: from where the
/// song is heard to the tick the render thread fixed for its launch when it was queued
/// (`LaunchReport.tick`). More than a bar away it counts whole bars, inside the last bar beats, so
/// the number goes down as the clip waits — with the one-bar quantum from "4 beats" to "1 beat".
public enum LaunchCountdown {
    public enum Remaining: Equatable, Sendable {
        case bars(Int)
        case beats(Int)
    }

    /// What is left until `launch` from a playhead at `playhead` (fractional ticks), each count
    /// rounded up, in the bar and beat playing at the playhead; nil once the launch is due or the
    /// playhead is no number.
    public static func remaining(until launch: Tick, from playhead: Double, meter: MeterMap) -> Remaining? {
        guard playhead.isFinite else { return nil }
        let wait = Double(launch) - playhead
        guard wait > 0 else { return nil }
        let at = position(playhead)
        let bar = Double(Swift.max(meter.ticksPerBar(at: at), 1))
        if wait > bar { return .bars(count(wait / bar)) }
        let beat = Double(Swift.max(meter.ticksPerBeat(at: at), 1))
        return .beats(count(wait / beat))
    }

    /// The label: "2 bars", "1 beat"; nil once due.
    public static func text(_ remaining: Remaining?) -> String? {
        switch remaining {
        case .bars(let n): return n == 1 ? "1 bar" : "\(n) bars"
        case .beats(let n): return n == 1 ? "1 beat" : "\(n) beats"
        case nil: return nil
        }
    }

    private static func count(_ ratio: Double) -> Int {
        Int(Swift.min(Swift.max(ratio.rounded(.up), 1), Double(Int32.max)))
    }

    /// A fractional playhead as a tick inside what a song holds.
    private static func position(_ playhead: Double) -> Tick {
        MusicalTime.integer(Swift.min(Swift.max(playhead, 0), Double(MusicalTime.maximumTick)).rounded(.down))
    }
}
