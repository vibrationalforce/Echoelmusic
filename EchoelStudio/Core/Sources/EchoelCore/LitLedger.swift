import Foundation

/// The universes a light output has lit and not yet said dark, kept across launches (SAF-1). The
/// app darkens its rig whenever it leaves it — switched off, a new receiver, the background, a
/// quit — but an app that crashes, hangs or is ended by the system while suspended says nothing,
/// and a node holds the last frame it heard: the lamps stay on. This ledger is written when an
/// output first lights a universe and cleared when that universe is said dark, so whatever it
/// still holds at the next launch was left lit.
///
/// It never opens a connection (Law 10): the next launch says those universes dark only when the
/// musician switches that same output on to that same receiver again, through the socket they
/// asked for. The app keeps the bytes in its defaults; this type only decides.
public struct LitLedger: Equatable, Sendable {
    /// The light protocol of an entry, by its stored name.
    public enum Output: String, Codable, Sendable, CaseIterable {
        case artNet
        case sacn

        /// The universes on the wire the protocol can address.
        public var universeRange: ClosedRange<Int> {
            switch self {
            case .artNet: ArtDMXPacket.universeRange
            case .sacn: E131Packet.universeRange
            }
        }
    }

    /// One universe on the wire of one receiver that was lit, with the longest frame sent there.
    public struct Entry: Equatable, Hashable, Codable, Sendable {
        public var output: Output
        public var host: String
        public var port: UInt16
        public var universe: Int
        public var frameLength: Int

        public init(output: Output, host: String, port: UInt16, universe: Int, frameLength: Int) {
            self.output = output
            self.host = host
            self.port = port
            self.universe = universe
            self.frameLength = frameLength
        }

        /// Whether the entry names something a dark frame can go to: a host, a port, a universe
        /// the protocol has and a DMX frame of 1 … 512 slots.
        var isUsable: Bool {
            !host.isEmpty && port > 0 && output.universeRange.contains(universe)
                && LitLedger.frameLengths.contains(frameLength)
        }

        func isSame(_ output: Output, host: String, port: UInt16, universe: Int) -> Bool {
            self.output == output && self.host == host && self.port == port && self.universe == universe
        }
    }

    /// A DMX frame carries 1 … 512 slots.
    public static let frameLengths: ClosedRange<Int> = 1...512
    /// At most this many entries are kept; past it the oldest go first (a rig spans a few
    /// universes, not hundreds, so this bound is never reached in use — it bounds a damaged file).
    public static var capacity: Int { 64 }

    /// The entries, the first lit first, each universe of each receiver once.
    public private(set) var entries: [Entry]

    public init(entries: [Entry] = []) {
        var kept: [Entry] = []
        for entry in entries where entry.isUsable {
            if let index = kept.firstIndex(where: { $0.isSame(entry.output, host: entry.host, port: entry.port,
                                                               universe: entry.universe) }) {
                kept[index].frameLength = Swift.max(kept[index].frameLength, entry.frameLength)
            } else {
                kept.append(entry)
            }
        }
        self.entries = Array(kept.suffix(Self.capacity))
    }

    public var isEmpty: Bool { entries.isEmpty }

    /// A frame of `channels` was sent to `universe` of `host`:`port`, padded on the wire to
    /// `frameLength` slots when that is longer. A frame with any slot above zero lights it; an
    /// all-dark frame changes nothing (saying a universe dark is `forget`). Returns whether the
    /// ledger changed — a new universe or a longer frame — so the app writes its defaults only
    /// then, never on every frame.
    @discardableResult
    public mutating func lit(_ output: Output, host: String, port: UInt16, universe: Int, channels: [UInt8],
                             frameLength: Int = 0) -> Bool {
        guard channels.contains(where: { $0 != 0 }) else { return false }
        let length = Swift.min(Swift.max(channels.count, frameLength), Self.frameLengths.upperBound)
        let entry = Entry(output: output, host: host, port: port, universe: universe, frameLength: length)
        guard entry.isUsable else { return false }
        if let index = entries.firstIndex(where: { $0.isSame(output, host: host, port: port, universe: universe) }) {
            guard length > entries[index].frameLength else { return false }
            entries[index].frameLength = length
            return true
        }
        entries.append(entry)
        if entries.count > Self.capacity { entries.removeFirst(entries.count - Self.capacity) }
        return true
    }

    /// `universe` of `host`:`port` was said dark. Returns whether the ledger changed.
    @discardableResult
    public mutating func forget(_ output: Output, host: String, port: UInt16, universe: Int) -> Bool {
        let before = entries.count
        entries.removeAll { $0.isSame(output, host: host, port: port, universe: universe) }
        return entries.count != before
    }

    /// Every universe of `host`:`port` was said dark. Returns whether the ledger changed.
    @discardableResult
    public mutating func forget(_ output: Output, host: String, port: UInt16) -> Bool {
        let before = entries.count
        entries.removeAll { $0.output == output && $0.host == host && $0.port == port }
        return entries.count != before
    }

    /// What to darken when `output` is switched on to `host`:`port`: each universe the ledger holds
    /// for exactly that receiver, with the frame length to send. A ledger entry for another
    /// receiver is not darkened — that would be a connection the musician did not switch on — and
    /// stays until its own receiver is switched on again.
    public func leftLit(_ output: Output, host: String, port: UInt16) -> [Int: Int] {
        var universes: [Int: Int] = [:]
        for entry in entries where entry.output == output && entry.host == host && entry.port == port {
            universes[entry.universe] = Swift.max(universes[entry.universe] ?? 0, entry.frameLength)
        }
        return universes
    }

    /// The bytes the app keeps in its defaults.
    public func encoded() -> Data {
        (try? JSONEncoder().encode(entries)) ?? Data()
    }

    /// The ledger from kept bytes; nothing, damaged or foreign bytes are an empty ledger, and an
    /// entry that names no usable universe is dropped.
    public static func decoded(_ data: Data?) -> LitLedger {
        guard let data, !data.isEmpty, let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            return LitLedger()
        }
        return LitLedger(entries: entries)
    }
}
