import EchoelCore

/// Where Play starts and where Stop goes back to — the ruler's cue. A tap on the ruler while the
/// song is stopped sets it; a Stop while playing returns to it, and a second Stop (one while
/// already stopped) returns to bar 1 and forgets it, as a pro DAW's Stop does.
///
/// Transport state of this session, never the song's: it is no `Command` (Law 1), so it is not an
/// undo step, and nothing writes it to a song file (Law 3). Main thread only; the render thread
/// only ever sees the seek it leads to.
public struct PlayStartCue: Equatable, Sendable {
    /// The cue, or nil when Play starts and Stop returns at bar 1.
    public private(set) var tick: Tick?

    public init() {}

    /// Puts the cue at `tick`, inside what a song holds.
    public mutating func set(_ tick: Tick) {
        self.tick = Swift.min(Swift.max(0, tick), MusicalTime.maximumTick)
    }

    public mutating func clear() { tick = nil }

    /// Where a stop the engine makes itself (the input opening or closing, a take's end) sends the
    /// playhead: the cue, or bar 1 without one. It keeps the cue, because it is no Stop of the
    /// musician's: arming a track after a locate still records from the cue.
    public var returnTick: Tick { tick ?? 0 }

    /// Where a Stop sends the playhead. While playing: the cue, or bar 1 without one. While
    /// already stopped (the second Stop): bar 1, and the cue is forgotten, so the next Play starts
    /// there too.
    public mutating func stop(whilePlaying playing: Bool) -> Tick {
        guard playing else {
            tick = nil
            return 0
        }
        return tick ?? 0
    }
}
