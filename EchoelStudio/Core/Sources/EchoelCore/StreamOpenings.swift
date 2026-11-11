import Foundation

/// The destinations of an outgoing stream that are being opened right now (wave W14): made, set
/// up, connecting — the time between Go Live and a server's answer, which a slow network
/// stretches to seconds. Pure, so every order of open, close and a second open is tested here,
/// where no server can be made slow on purpose.
///
/// The publisher kept a destination only once its session was set up. A Stop before that found
/// nothing to close, and the session connected afterwards with nobody holding it; a Stop while it
/// connected was shown as a connection that failed; and a server that answered after the Stop
/// was called live. Every open is an attempt with its own number: a close ends the attempt under
/// way, and the open asks at each step whether it is still the one.
public struct StreamOpenings: Equatable, Sendable {
    /// The attempt under way for each destination.
    private var underWay: [UUID: UInt64] = [:]
    /// The number of the last attempt begun. Numbers are never used twice.
    private var last: UInt64 = 0

    public init() {}

    /// An open of `destination` begins. Answers its number; an older attempt for the same
    /// destination is over.
    public mutating func begin(_ destination: UUID) -> UInt64 {
        last &+= 1
        underWay[destination] = last
        return last
    }

    /// Whether `attempt` is still the open under way for `destination` — false once a close came
    /// in, even when a newer attempt for it is under way now.
    public func isUnderWay(_ attempt: UInt64, for destination: UUID) -> Bool {
        underWay[destination] == attempt
    }

    /// The attempt came to its end by itself, live or failed. A newer attempt for the same
    /// destination stays under way.
    public mutating func finish(_ attempt: UInt64, for destination: UUID) {
        guard underWay[destination] == attempt else { return }
        underWay[destination] = nil
    }

    /// `destination` is closed: an open under way for it is over.
    public mutating func close(_ destination: UUID) {
        underWay[destination] = nil
    }

    /// Stop: every open under way is over.
    public mutating func closeAll() {
        underWay.removeAll()
    }
}
