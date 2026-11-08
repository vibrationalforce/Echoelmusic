import Foundation

/// The life of one outgoing stream (wave W14), from Go Live to the moment everything is closed
/// again. Pure, so the order of Go Live, Stop and a second Go Live is tested here, where no
/// destination can be made slow on purpose.
///
/// It replaces two flags and an optional (`isLive`, `isStarting`, `startedAt`) that could say
/// "live and starting at once" or "on air since a time while off". And it closes two races the
/// flags allowed: an attempt that was stopped while a destination connected and then found a NEW
/// attempt's "starting" flag set, so it kept opening and declared itself live; and a Go Live
/// pressed while the last stream still closed, whose update handler the old Stop then removed.
/// Every Go Live is an attempt with its own number, and Go Live waits until Stop has finished.
public struct StreamLifecycle: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        /// Nothing is sent; Go Live may begin.
        case off
        /// The destinations are being opened.
        case starting
        /// At least one destination accepted the stream at `since`.
        case live(since: Date)
        /// The stream is being closed; Go Live waits until it is off.
        case stopping
    }

    public private(set) var phase: Phase = .off
    /// The number of the attempt running or last run. A new Go Live raises it.
    public private(set) var attempt: UInt64 = 0

    public init() {}

    /// A stream is starting, live or closing: the destinations' list stays as it is.
    public var isOn: Bool { phase != .off }
    /// Stop means something now.
    public var canStop: Bool {
        switch phase {
        case .starting, .live: true
        case .off, .stopping: false
        }
    }
    public var isLive: Bool { startedAt != nil }
    /// When the current stream went live; nil unless it is live.
    public var startedAt: Date? {
        if case .live(let since) = phase { return since }
        return nil
    }

    /// Go Live: a new attempt. Answers its number; nil while a stream is on (or still closing).
    @discardableResult
    public mutating func begin() -> UInt64? {
        guard phase == .off else { return nil }
        attempt &+= 1
        phase = .starting
        return attempt
    }

    /// Whether `attempt` is the one still starting — false once it was stopped, even when a newer
    /// attempt is starting now.
    public func isStarting(_ attempt: UInt64) -> Bool {
        phase == .starting && attempt == self.attempt
    }

    /// The attempt's destinations are open and at least one accepted it. False (nothing changed)
    /// when the attempt is not the one starting.
    @discardableResult
    public mutating func wentLive(_ attempt: UInt64, at date: Date) -> Bool {
        guard isStarting(attempt) else { return false }
        phase = .live(since: date)
        return true
    }

    /// Stop, a forced end or a start nobody accepted: the stream begins to close. False (nothing
    /// changed) when there is nothing to stop or it is already closing.
    @discardableResult
    public mutating func beginStopping() -> Bool {
        guard canStop else { return false }
        phase = .stopping
        return true
    }

    /// Everything is closed; the next Go Live may begin.
    public mutating func stopped() {
        guard phase == .stopping else { return }
        phase = .off
    }
}
