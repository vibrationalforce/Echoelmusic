import Foundation

/// Live-jam J0/J1 (founder 2026-10-07, "LIVE ZUSAMMEN MUSIZIEREN"): the first MEASURED number
/// between two phones. A probe goes out to every connected peer, the peer echoes it back at
/// once, and the sender times the round trip on its OWN clock.
///
/// ⭐ WHAT THIS MEASURES, said exactly, because the founder's targets are about something
/// else: the **NETWORK ROUND TRIP** of a tiny frame over MultipeerConnectivity's `.unreliable`
/// channel, including both phones' delivery to the app — on the echoing side the echo leaves
/// from the transport callback, before any main-actor hop. It is **NOT the heard latency**
/// (no audio buffer, no codec, no output path is in it), and half of it is **NOT the one-way
/// time** (the two directions need not be symmetric; nothing here claims they are). The
/// founder's targets (own monitoring ≤ 10 ms, remote signal ≤ 20 ms one-way p95) are measured
/// at the ear; this is one honest LEG of that budget, not the budget.
///
/// ⭐ WHY THE TWO CLOCKS NEVER MEET: the probe carries only an id. The sender keeps its own
/// send time per id and subtracts on the echo, so two phones' clocks are never compared, and
/// a peer cannot forge a time — an echo for an id this side never sent, or sent and already
/// written off, is ignored.
///
/// ⭐ WHY THE FRAME IS NOT JSON: a `ColabPayload` with a new `kind` would reach an OLDER
/// build's receiver as an unknown payload — it treats anything that is not "bio" as a shared
/// piece and would announce "Piece received" twice a second. These ten bytes fail
/// `ColabPayload.decode` on every build, so an older peer drops them silently (and never
/// echoes: that peer simply shows as all-lost, which is true).
///
/// Built: yes. Wired: `MultipeerSession` probes while a peer is connected and writes a summary
/// line to the diag log. Device: no — needs two phones (NEEDS-FOUNDER-VERIFY, J1).
enum LinkProbeFrame {

    enum Kind: UInt8, Sendable { case ping = 0, echo = 1 }

    /// "EPRB" — JSON never starts with "E", so a frame can never be mistaken for a payload.
    static let magic: [UInt8] = [0x45, 0x50, 0x52, 0x42]
    static let version: UInt8 = 1
    static let length = 10

    static func encode(_ kind: Kind, id: UInt32) -> Data {
        var bytes = magic
        bytes.append(version)
        bytes.append(kind.rawValue)
        bytes.append(contentsOf: [UInt8(id & 0xFF), UInt8((id >> 8) & 0xFF),
                                  UInt8((id >> 16) & 0xFF), UInt8((id >> 24) & 0xFF)])
        return Data(bytes)
    }

    /// The frame's kind and id, or nil for anything that is not exactly one probe frame.
    static func decode(_ data: Data) -> (kind: Kind, id: UInt32)? {
        let bytes = [UInt8](data)
        guard bytes.count == length, Array(bytes[0..<4]) == magic, bytes[4] == version,
              let kind = Kind(rawValue: bytes[5]) else { return nil }
        let id = UInt32(bytes[6]) | UInt32(bytes[7]) << 8 | UInt32(bytes[8]) << 16 | UInt32(bytes[9]) << 24
        return (kind, id)
    }

    /// The echo of a ping: the same bytes with the kind flipped. Nil for anything else — an
    /// echo is never echoed, so two peers cannot bounce one frame between them forever.
    static func echo(of data: Data) -> Data? {
        guard let frame = decode(data), frame.kind == .ping else { return nil }
        return encode(.echo, id: frame.id)
    }
}

/// What the meter can honestly say about one peer's link so far.
struct LinkLatencySummary: Equatable, Sendable {
    let sent: Int
    let received: Int
    let lost: Int
    /// Round trips currently in the window the percentiles are taken over.
    let samples: Int
    /// Milliseconds. Nil until the window holds enough round trips for that percentile to
    /// name a real sample (see `LinkLatencyMeter.percentile`), never an extrapolation.
    let p50: Double?
    let p95: Double?
    let p99: Double?
    let max: Double?

    /// One diag-log line. It names what the number IS, so an exported log cannot be read as
    /// the heard latency.
    func logLine(peer: String) -> String {
        func ms(_ value: Double?) -> String { value.map { String(format: "%.1f", $0) } ?? "-" }
        return "link: peer=\(peer) rtt p50=\(ms(p50)) p95=\(ms(p95)) p99=\(ms(p99)) max=\(ms(max)) ms"
            + " n=\(samples) lost=\(lost)/\(sent) (network round trip, not heard latency)"
    }
}

/// Round-trip bookkeeping for ONE peer. A value type with no clock of its own: every call
/// takes the time, so the tests drive it exactly and the session decides which clock (a
/// monotonic one — `ProcessInfo.systemUptime` — never wall time, which can jump).
struct LinkLatencyMeter: Sendable {

    /// The percentiles are taken over the most recent round trips only — a link changes when
    /// someone walks into the next room, and an all-time p95 would hide it.
    static let window = 256
    /// An echo later than this is a loss. Generous on purpose: for a JAM, a 2 s frame is as
    /// lost as one that never came, and counting it late would flatter the percentiles.
    static let lostAfter: TimeInterval = 2.0
    /// Unanswered probes kept at most; beyond it the oldest is written off as lost. Bounds the
    /// memory a silent peer can cost.
    static let maxOutstanding = 64

    private(set) var sent = 0
    private(set) var received = 0
    private(set) var lost = 0
    private var outstanding: [UInt32: TimeInterval] = [:]
    private var order: [UInt32] = []
    private var ring: [Double] = []
    private var next = 0

    /// A probe left at `time`. A non-finite time is not recorded at all.
    mutating func didSend(id: UInt32, at time: TimeInterval) {
        guard time.isFinite, outstanding[id] == nil else { return }
        sent += 1
        outstanding[id] = time
        order.append(id)
        while order.count > Self.maxOutstanding {
            let oldest = order.removeFirst()
            if outstanding.removeValue(forKey: oldest) != nil { lost += 1 }
        }
    }

    /// The echo of `id` arrived at `time`. True when it became a round trip. An id this side
    /// did not send, an echo already counted, one already written off as lost, and a
    /// non-finite or negative interval are all ignored.
    @discardableResult
    mutating func didEcho(id: UInt32, at time: TimeInterval) -> Bool {
        guard let sentAt = outstanding[id] else { return false }
        let seconds = time - sentAt
        guard seconds.isFinite, seconds >= 0 else { return false }
        outstanding[id] = nil
        order.removeAll { $0 == id }
        guard seconds <= Self.lostAfter else { lost += 1; return false }
        received += 1
        let milliseconds = seconds * 1000
        if ring.count < Self.window {
            ring.append(milliseconds)
        } else {
            ring[next] = milliseconds
        }
        next = (next + 1) % Self.window
        return true
    }

    /// Writes off every probe older than `lostAfter` at `now`.
    mutating func expire(now: TimeInterval) {
        guard now.isFinite else { return }
        let overdue = order.filter { id in outstanding[id].map { now - $0 > Self.lostAfter } ?? false }
        for id in overdue {
            outstanding[id] = nil
            lost += 1
        }
        order.removeAll { outstanding[$0] == nil }
    }

    func summary() -> LinkLatencySummary {
        let sorted = ring.sorted()
        return LinkLatencySummary(sent: sent, received: received, lost: lost, samples: sorted.count,
                                  p50: Self.percentile(sorted, 0.50),
                                  p95: Self.percentile(sorted, 0.95),
                                  p99: Self.percentile(sorted, 0.99),
                                  max: sorted.last)
    }

    /// Nearest-rank percentile of an ascending array — always a sample that was measured.
    /// Nil until the window holds at least `1 / (1 − q)` samples, so the tail it names has at
    /// least one round trip IN it: p95 needs 20, p99 needs 100. Below that, the "p99" of
    /// thirty samples would just be the maximum wearing a better name.
    static func percentile(_ sorted: [Double], _ q: Double) -> Double? {
        guard q > 0, q < 1 else { return nil }
        let needed = Int((1 / (1 - q)).rounded(.up))
        guard sorted.count >= Swift.max(needed, 1) else { return nil }
        let rank = Int((q * Double(sorted.count)).rounded(.up))
        return sorted[Swift.min(Swift.max(rank, 1), sorted.count) - 1]
    }
}
