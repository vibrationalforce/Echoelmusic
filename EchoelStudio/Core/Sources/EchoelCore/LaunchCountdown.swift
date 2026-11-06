import Foundation

/// How long a queued session clip still waits: the launch boundary the engine waits for, seen
/// from where the song is heard, and the bars until it — for the clip's countdown in the session.
/// The same boundaries the render thread launches on (`EngineCore.boundary`): the next bar line of
/// the meter, the next multiple of a shorter quantum, or at once.
public enum LaunchCountdown {
    /// The tick a launch waiting now starts on, from a playhead at `playhead` (fractional ticks):
    /// with `quantum` nil the next bar line after it, with a positive quantum the next multiple of
    /// it after it, with 0 the playhead itself.
    public static func launchTick(after playhead: Double, quantum: Tick?, meter: MeterMap) -> Tick {
        let at = position(playhead)
        if let quantum {
            guard quantum > 0 else { return at }
            let next = (at / quantum + 1) * quantum
            return Swift.min(next, MusicalTime.maximumTick)
        }
        return Swift.min(meter.tick(ofBar: meter.bar(at: at) + 1), MusicalTime.maximumTick)
    }

    /// Whole bars until `launch`, rounded up, in the length of the bar playing at `playhead`: 1 for
    /// any wait inside the next bar, 0 once the launch is due.
    public static func barsUntil(_ launch: Tick, from playhead: Double, meter: MeterMap) -> Int {
        guard playhead.isFinite else { return 0 }
        let wait = Double(launch) - playhead
        guard wait > 0 else { return 0 }
        let bar = Double(Swift.max(meter.ticksPerBar(at: position(playhead)), 1))
        return Int(Swift.min((wait / bar).rounded(.up), Double(Int32.max)))
    }

    /// The bars a queued clip waits from `playhead`, for its label: "1 bar", "2 bars"; nil once due.
    public static func text(bars: Int) -> String? {
        guard bars > 0 else { return nil }
        return bars == 1 ? "1 bar" : "\(bars) bars"
    }

    /// A fractional playhead as a tick inside what a song holds; a non-finite one is bar 1.
    private static func position(_ playhead: Double) -> Tick {
        guard playhead.isFinite else { return 0 }
        return MusicalTime.integer(Swift.min(Swift.max(playhead, 0), Double(MusicalTime.maximumTick)).rounded(.down))
    }
}
