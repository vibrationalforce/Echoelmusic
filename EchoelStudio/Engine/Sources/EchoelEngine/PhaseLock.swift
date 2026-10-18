import Foundation

/// Keeps a followed song in phase with its clock, gently: each measurement of how far ahead
/// (positive) or behind the song plays is smoothed, a small error is taken out a little at a time
/// by nudging the playhead a few samples — inaudible, no note is cut — and only an error too large
/// to nudge relocks with a jump. A tiny error is left alone, so jitter is never chased.
/// Pure: hand it errors, it answers corrections.
public struct PhaseLock: Sendable {
    public enum Correction: Equatable, Sendable {
        case none
        /// Move the playhead by this many seconds (negative: back).
        case nudge(seconds: Double)
        /// Too far off to nudge: jump to the clock's position.
        case relock
    }

    /// Errors smaller than this are jitter: the playhead is only known per rendered block.
    public static let deadband = 0.002
    /// Errors larger than this are a jump, not a drift.
    public static let relockThreshold = 0.08
    /// Most one correction moves. An audio region is read at the playhead, so every nudge is a
    /// skip of this size in it; half a millisecond is the most that stays unnoticed.
    public static let maximumNudge = 0.0005
    /// Share of the smoothed error each correction takes out.
    static let gain = 0.3
    /// Weight of a new measurement in the smoothed error.
    static let smoothing = 0.25

    private var smoothed: Double?

    public init() {}

    /// Forgets the history: after a seek, a start or a relock the old errors mean nothing.
    public mutating func reset() {
        smoothed = nil
    }

    /// One measurement: the song is `error` seconds ahead of the clock (negative: behind).
    public mutating func correct(error: Double) -> Correction {
        guard error.isFinite else { return .none }
        if Swift.abs(error) > Self.relockThreshold {
            smoothed = nil
            return .relock
        }
        let current = smoothed.map { $0 + (error - $0) * Self.smoothing } ?? error
        guard Swift.abs(current) > Self.deadband else {
            smoothed = current
            return .none
        }
        let step = Swift.min(Swift.max(current * Self.gain, -Self.maximumNudge), Self.maximumNudge)
        // What this correction takes out is no longer error.
        smoothed = current - step
        return .nudge(seconds: -step)
    }
}
