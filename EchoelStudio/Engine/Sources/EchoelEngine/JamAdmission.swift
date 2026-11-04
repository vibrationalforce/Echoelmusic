import Foundation

/// Who is waiting to be let into a jam (W16, team SAFE 2026-11-04): a phone that asks to join is
/// not taken in by itself — the host sees its name and lets it in or turns it away. This is the pure
/// half: the requests, in the order they came, each until the host answers or it runs out. The link
/// (`App/Jam/JamLink.swift`) holds the answers MultipeerConnectivity waits for, keyed by `id`.
///
/// Rules: one request per phone (asking again replaces the earlier one, which is answered no); never
/// more waiting than the jam has room for; a request older than `timeout` is answered no, because the
/// asking phone has given up by then (`JamLink.joinTimeout`).
public struct JamAdmission: Equatable, Sendable {
    public struct Request: Equatable, Identifiable, Sendable {
        /// The asking phone's name on the link (`JamPeer.id`).
        public let id: String
        /// What the host sees.
        public let name: String
        /// When it asked, on the host's clock (`JamTime`), in seconds.
        public let askedAt: Double
    }

    /// What became of an `ask`. Either way, `replaced` is an earlier request of the same phone,
    /// taken out and to be answered no.
    public enum Outcome: Equatable, Sendable {
        /// Waits for the host.
        case waiting(replaced: Request?)
        /// Answered no at once: no room, or not a request that can be read.
        case declined(replaced: Request?)
    }

    public let timeout: Double
    public let room: Int
    public private(set) var pending: [Request] = []

    /// `room`: how many may wait at once — at most the jam's free places. `timeout`: seconds.
    public init(timeout: Double, room: Int) {
        self.timeout = timeout.isFinite && timeout > 0 ? timeout : 0
        self.room = Swift.max(0, room)
    }

    /// A phone asks to join. `free`: places left in the jam now (guests not yet counted here).
    public mutating func ask(id: String, name: String, at time: Double, free: Int) -> Outcome {
        let replaced = pending.first { $0.id == id }
        pending.removeAll { $0.id == id }
        guard !id.isEmpty, time.isFinite, timeout > 0,
              pending.count < Swift.min(room, Swift.max(0, free)) else { return .declined(replaced: replaced) }
        pending.append(Request(id: id, name: name, askedAt: time))
        return .waiting(replaced: replaced)
    }

    /// The host's answer to `id`: the request it answers, removed; nil when nothing waits under it
    /// (answered already, or run out).
    public mutating func answer(_ id: String) -> Request? {
        guard let index = pending.firstIndex(where: { $0.id == id }) else { return nil }
        return pending.remove(at: index)
    }

    /// Removes and returns every request older than `timeout` at `now`; each is to be answered no.
    public mutating func expire(at now: Double) -> [Request] {
        guard now.isFinite else { return [] }
        let gone = pending.filter { now - $0.askedAt >= timeout }
        pending.removeAll { now - $0.askedAt >= timeout }
        return gone
    }

    /// Everything still waiting, removed — the jam ends; each is to be answered no.
    public mutating func clear() -> [Request] {
        let gone = pending
        pending = []
        return gone
    }
}
