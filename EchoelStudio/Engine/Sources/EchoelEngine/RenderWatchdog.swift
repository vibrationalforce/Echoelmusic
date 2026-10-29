/// Notices a graph that stopped rendering while the song plays. `AVAudioEngine` can report
/// itself running while the source node is no longer called — the session lost the hardware
/// without a notification, a route change half finished — and then the transport runs over
/// silence and nothing says so. The app looks at the render count about once a second while it
/// plays; a count that has not moved for `stallLimit` is a stall, and the app rebuilds the graph.
/// A rebuild that brings nothing back is tried `healLimit` times, then the watchdog stays quiet
/// until the count moves or playing stops, so a dead device is not rebuilt for ever.
///
/// Pure arithmetic on the count and the time the app passes in: it runs on the main actor in the
/// app and offline in a test, never on the render thread.
public struct RenderWatchdog: Equatable, Sendable {
    /// How long the count may stand still while playing before it is a stall.
    public static var stallLimit: Duration { .seconds(2) }
    /// Rebuilds in a row that may find the count still standing, before the watchdog gives up.
    public static var healLimit: Int { 3 }

    public enum Verdict: Equatable, Sendable {
        /// Rendering, or not watched.
        case fine
        /// The count stood still for `stalled`; rebuild the graph.
        case heal(stalled: Duration)
        /// The last allowed rebuild did not bring it back either; said once, then `fine`.
        case gaveUp
    }

    /// The count at the last look; nil while not watching.
    public private(set) var lastCount: UInt64?
    /// When the count last moved (or the wait last started again).
    public private(set) var since: Duration = .zero
    /// Rebuilds since the count last moved.
    public private(set) var heals = 0

    public init() {}

    /// One look: the render count now, at `now` on any steady clock, and whether the song plays.
    /// Not playing forgets everything, so a pause is never a stall and a new Play starts fresh.
    /// A count that changes in either direction moved: a rebuilt graph starts its own from zero.
    public mutating func look(count: UInt64, at now: Duration, playing: Bool) -> Verdict {
        guard playing else {
            self = RenderWatchdog()
            return .fine
        }
        guard lastCount == count else {
            lastCount = count
            since = now
            heals = 0
            return .fine
        }
        let stalled = now - since
        // A clock that went back (a test, a reset origin) is not a stall: it starts the wait again.
        guard stalled >= Self.stallLimit else {
            if stalled < .zero { since = now }
            return .fine
        }
        // One past the limit is the stall after the last rebuild: said once, then quiet.
        guard heals <= Self.healLimit else { return .fine }
        heals += 1
        // The next rebuild waits a whole limit again, so the graph has time to come back.
        since = now
        return heals > Self.healLimit ? .gaveUp : .heal(stalled: stalled)
    }
}
