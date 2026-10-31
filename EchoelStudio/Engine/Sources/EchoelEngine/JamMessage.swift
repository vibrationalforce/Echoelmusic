import EchoelCore
import Foundation

/// Jam (wave W16, founder 2026-10-31: "Alle zusammen eine JamSession"): phones in one room play
/// to one bar. One phone hosts — it owns the tempo, the time signature, Play and Stop and where its
/// bars fall — and the others follow it the way they follow an external MIDI clock: the engine plays
/// the host's tempo and meter in place of the song's (`ClockFollower.played`), and the same
/// `PhaseLock` keeps the bar lines together. Only the small messages below travel: no audio, no
/// song and, in this version, no body value. Everything here is pure, so it is tested without a
/// network; the link itself is the app's `JamLink`.
public enum JamProtocol {
    /// The version this build writes and reads. A message from a newer build is refused whole,
    /// never half read: a field it adds could change what the others mean.
    public static let version = 1
    /// The Bonjour service a jam is found under (`_echoel-jam._tcp` and `_echoel-jam._udp` in the
    /// app's NSBonjourServices): at most 15 characters, lowercase letters, digits and hyphens.
    public static let serviceType = "echoel-jam"
}

/// What the host plays: sent when it changes, and at least once a second while anyone listens
/// (`JamBeacon`), so a guest always has a fresh anchor to carry on from.
public struct JamState: Codable, Equatable, Sendable {
    /// Beats per minute the host plays at `anchorTick`.
    public var tempo: Double
    public var signature: TimeSignature
    public var isPlaying: Bool
    /// The host's song position, in fractional ticks, as it is heard at `anchorTime`.
    public var anchorTick: Double
    /// When the host hears `anchorTick`, in seconds on the host's own clock.
    public var anchorTime: Double

    public init(tempo: Double, signature: TimeSignature, isPlaying: Bool, anchorTick: Double, anchorTime: Double) {
        self.tempo = tempo
        self.signature = signature
        self.isPlaying = isPlaying
        self.anchorTick = anchorTick
        self.anchorTime = anchorTime
    }

    /// Every number finite, the tempo inside `Tempo.range` and a time signature a song can have.
    /// A guest follows nothing else.
    public var isValid: Bool {
        tempo.isFinite && Tempo.range.contains(tempo) && signature.isValid && anchorTick.isFinite && anchorTime.isFinite
    }
}

/// A guest's question to the host's clock, stamped with when it left, on the guest's clock.
public struct JamPing: Codable, Equatable, Sendable {
    public var id: UInt32
    public var sentAt: Double

    public init(id: UInt32, sentAt: Double) {
        self.id = id
        self.sentAt = sentAt
    }
}

/// The host's answer: the ping's own stamp, and when it arrived and when the answer left, both on
/// the host's clock. With the moment the answer arrives this is NTP's arithmetic (`JamClockEstimate`).
public struct JamPong: Codable, Equatable, Sendable {
    public var id: UInt32
    public var guestSentAt: Double
    public var hostReceivedAt: Double
    public var hostSentAt: Double

    public init(id: UInt32, guestSentAt: Double, hostReceivedAt: Double, hostSentAt: Double) {
        self.id = id
        self.guestSentAt = guestSentAt
        self.hostReceivedAt = hostReceivedAt
        self.hostSentAt = hostSentAt
    }
}

/// One message on the jam's link, with the version it was written in. Flat on purpose: the kind
/// says which one field is set, and a message whose field is missing is not read at all.
public struct JamMessage: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case ping, pong, state, roster, leave
    }

    public let version: Int
    public let kind: Kind
    public let ping: JamPing?
    public let pong: JamPong?
    public let state: JamState?
    /// Everyone in the jam by name, the host first.
    public let roster: [String]?

    private init(kind: Kind, ping: JamPing? = nil, pong: JamPong? = nil, state: JamState? = nil,
                 roster: [String]? = nil) {
        self.version = JamProtocol.version
        self.kind = kind
        self.ping = ping
        self.pong = pong
        self.state = state
        self.roster = roster
    }

    public init(ping: JamPing) { self.init(kind: .ping, ping: ping) }
    public init(pong: JamPong) { self.init(kind: .pong, pong: pong) }
    public init(state: JamState) { self.init(kind: .state, state: state) }
    public init(roster: [String]) { self.init(kind: .roster, roster: roster) }

    /// The host ends the jam, or a guest leaves it.
    public static let leave = JamMessage(kind: .leave)

    /// What arrived, read.
    public enum Decoded: Equatable, Sendable {
        case message(JamMessage)
        /// Written by a newer Echoel: refused whole.
        case newerVersion(Int)
        /// Not a jam message, or one that breaks its own shape.
        case unreadable
    }

    /// The bytes for the link; nil when a number cannot be written (JSON has no NaN).
    public func encoded() -> Data? {
        try? JSONEncoder().encode(self)
    }

    public static func decode(_ data: Data) -> Decoded {
        struct Header: Decodable {
            let version: Int
        }
        guard let header = try? JSONDecoder().decode(Header.self, from: data), header.version >= 1 else {
            return .unreadable
        }
        guard header.version <= JamProtocol.version else { return .newerVersion(header.version) }
        guard let message = try? JSONDecoder().decode(JamMessage.self, from: data), message.isWhole else {
            return .unreadable
        }
        return .message(message)
    }

    /// The field its kind names is there.
    var isWhole: Bool {
        switch kind {
        case .ping: ping != nil
        case .pong: pong != nil
        case .state: state != nil
        case .roster: roster != nil
        case .leave: true
        }
    }
}

/// A phone in the jam: the name the others see, and the name it is found under on the link, which
/// carries a short token after the device name, so two phones both called "iPhone" — the name iOS
/// gives every app without a special entitlement — are still two (the earlier app's #1435).
public struct JamPeer: Hashable, Identifiable, Sendable {
    /// The name on the link: unique for one run of one phone's jam.
    public let id: String
    /// The device name, shown.
    public let name: String

    /// Shown for a phone whose name is empty.
    public static let fallbackName = "iPhone"
    static let separator: Character = "#"
    static let tokenLength = 6
    /// MultipeerConnectivity refuses a name longer than this many bytes of UTF-8 (and stops the app).
    static let maximumBytes = 63

    public init(linkName: String) {
        id = linkName
        if let mark = linkName.lastIndex(of: Self.separator),
           linkName.distance(from: mark, to: linkName.endIndex) == Self.tokenLength + 1 {
            let shown = String(linkName[..<mark])
            name = shown.isEmpty ? Self.fallbackName : shown
        } else {
            name = linkName.isEmpty ? Self.fallbackName : linkName
        }
    }

    /// `name` made safe for the link — never empty, never longer than the link takes — with
    /// `token` (letters and digits, padded to its length) after it.
    public static func linkName(name: String, token: String) -> String {
        let letters = String(token.filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.lowercased())
        let padded = String((letters + "000000").prefix(tokenLength))
        var shown = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if shown.isEmpty { shown = fallbackName }
        let budget = maximumBytes - tokenLength - 1
        while shown.utf8.count > budget { shown.removeLast() }
        return shown + String(separator) + padded
    }

    /// The names of a list as it reads, so two phones of one name are told apart: "iPhone",
    /// "iPhone 2".
    public static func labels(_ names: [String]) -> [String] {
        var seen: [String: Int] = [:]
        return names.map { (name: String) -> String in
            let count = (seen[name] ?? 0) + 1
            seen[name] = count
            return count == 1 ? name : "\(name) \(count)"
        }
    }
}
