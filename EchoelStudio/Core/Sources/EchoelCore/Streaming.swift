import Foundation

/// Going live from the phone (wave W14): ONE outgoing stream — the Field as picture, the master
/// mix as sound — to one or more destinations, each in its own shape. This file is the pure half: the destinations, the
/// address each one is reached at, and how much upload a plan asks for. The protocol stack itself
/// is HaishinKit, in the app (`App/Streaming/`); nothing here opens a socket.
///
/// A stream key is a password to the musician's channel. It is never a field of a type here, so
/// no encoder can write it into a song, a preference or a log: the app keeps it in the keychain
/// and hands it in only to build the one address it is sent to (`StreamTarget.publishURL`).

/// How a stream travels. RTMP and RTMPS (RTMP over TLS) are what the platforms ingest; SRT is
/// the open low-latency transport (Haivision, MPL-2.0) relays and self-hosted servers take.
public enum StreamTransport: String, Codable, Sendable, CaseIterable {
    case rtmp
    case rtmps
    case srt

    /// RTMP and RTMPS share one stack and one address shape: `scheme://host/app/streamName`.
    public var isRTMP: Bool { self != .srt }
}

/// The picture's shape, chosen per destination: vertical for the short feeds (Reels, Shorts,
/// TikTok, a vertical Instagram live), landscape for YouTube, Twitch and the long players, and two
/// crops — square and 4:5 — for the feeds that show those. The Field is drawn at the chosen size,
/// aspect-correct, so a crop is the same picture framed tighter, never a stretched one.
/// Stored by name in the device's list of destinations; a new shape goes at the end.
public enum StreamFormat: String, Codable, Sendable, CaseIterable {
    case vertical
    case landscape
    case square
    case portrait

    public var title: String {
        switch self {
        case .vertical: "9:16"
        case .landscape: "16:9"
        case .square: "1:1"
        case .portrait: "4:5"
        }
    }

    /// The encoded size: 1080 pixels on the short side (1080p).
    public var pixelWidth: Int {
        switch self {
        case .landscape: 1920
        case .vertical, .square, .portrait: 1080
        }
    }

    public var pixelHeight: Int {
        switch self {
        case .vertical: 1920
        case .landscape, .square: 1080
        case .portrait: 1350
        }
    }

    /// Whether the shape is a crop of the vertical or landscape picture rather than one of the two.
    public var isCrop: Bool { self == .square || self == .portrait }
}

/// Where a stream can go. A platform here is a preset — a name, the transport it expects, its
/// ingest server where that server is the same for everyone, and where the musician finds the
/// rest. Instagram, TikTok, Kick, X and LinkedIn hand out a server per account or per live
/// session, so their preset has none: the musician pastes the one the platform shows.
/// Stored by name (the raw value) in the device's list of destinations, so a new one goes at the end.
public enum StreamPlatform: String, Codable, Sendable, CaseIterable {
    case youtube
    case youtubeShorts
    case twitch
    case facebook
    case instagram
    case tiktok
    case kick
    case x
    case linkedin
    case vimeo
    case restream
    case owncast
    case peertube
    case customRTMP
    case customSRT

    public var title: String {
        switch self {
        case .youtube: "YouTube"
        case .youtubeShorts: "YouTube Shorts"
        case .twitch: "Twitch"
        case .facebook: "Facebook"
        case .instagram: "Instagram"
        case .tiktok: "TikTok"
        case .kick: "Kick"
        case .x: "X"
        case .linkedin: "LinkedIn"
        case .vimeo: "Vimeo"
        case .restream: "Restream"
        case .owncast: "Owncast"
        case .peertube: "PeerTube"
        case .customRTMP: "Custom RTMP"
        case .customSRT: "Custom SRT"
        }
    }

    /// The transport the preset starts with. A destination may change RTMP to RTMPS and back by
    /// its server's scheme; SRT is only for `customSRT`.
    public var transport: StreamTransport {
        switch self {
        case .youtube, .youtubeShorts, .facebook, .instagram, .kick, .x, .linkedin, .vimeo: .rtmps
        case .twitch, .tiktok, .restream, .owncast, .peertube, .customRTMP: .rtmp
        case .customSRT: .srt
        }
    }

    /// The ingest server where it is the same for every account; nil where each account or each
    /// live session gets its own (and for the self-hosted and custom ones).
    public var defaultServer: String? {
        switch self {
        case .youtube, .youtubeShorts: "rtmps://a.rtmps.youtube.com/live2"
        case .twitch: "rtmp://live.twitch.tv/app"
        case .facebook: "rtmps://live-api-s.facebook.com:443/rtmp"
        case .vimeo: "rtmps://rtmp-global.cloud.vimeo.com:443/live"
        case .restream: "rtmp://live.restream.io/live"
        case .instagram, .tiktok, .kick, .x, .linkedin, .owncast, .peertube, .customRTMP, .customSRT: nil
        }
    }

    /// The shapes the platform's own player is built for, the recommended one first — the shape a
    /// new destination starts with. Instagram plays both (vertical lives and longform); a custom
    /// server takes whatever it is sent. Any destination may still choose any shape.
    public var recommendedFormats: [StreamFormat] {
        switch self {
        case .youtubeShorts, .tiktok: [.vertical]
        case .instagram: [.vertical, .landscape]
        case .facebook, .linkedin, .x: [.landscape, .vertical, .square]
        case .youtube, .twitch, .kick, .vimeo, .restream, .owncast, .peertube: [.landscape]
        case .customRTMP, .customSRT: [.landscape, .vertical, .square, .portrait]
        }
    }

    public var recommendedFormat: StreamFormat { recommendedFormats.first ?? .landscape }

    /// The video bit rate a new destination starts with, in kilobits a second, for 1080p at 30
    /// frames a second: within each platform's published range for that size, at the lower end
    /// where the platform caps or recommends less (Twitch 6000, Instagram and TikTok about 4000).
    public var recommendedVideoKbps: Int {
        switch self {
        case .youtube, .youtubeShorts, .twitch, .kick, .vimeo, .restream: 6_000
        case .facebook, .x, .customRTMP, .customSRT: 4_500
        case .instagram, .tiktok, .linkedin, .owncast, .peertube: 4_000
        }
    }

    /// Where the server and the key come from, in one line for the destination's page.
    public var whereToFind: String {
        switch self {
        case .youtube: "YouTube Studio → Go live → Stream: the stream key."
        case .youtubeShorts: "YouTube Studio → Go live → Stream, vertical: the stream key. A vertical live shows in Shorts."
        case .twitch: "Twitch dashboard → Settings → Stream: the primary stream key."
        case .facebook: "Facebook Live Producer → Streaming software: the stream key."
        case .instagram: "Instagram Live Producer (on the web): server URL and stream key, new for each live."
        case .tiktok: "TikTok LIVE Studio or LIVE Center: server URL and stream key."
        case .kick: "Kick dashboard → Settings → Stream: server URL and stream key."
        case .x: "X Media Studio → Producer: the RTMPS server and stream key."
        case .linkedin: "LinkedIn Live event → Streaming software: the stream URL and key."
        case .vimeo: "Vimeo event → Settings → Streaming software: the stream key."
        case .restream: "Restream → Stream settings: the stream key. Restream forwards to every channel you connect there."
        case .owncast: "Your Owncast server: rtmp://your-server/live and the stream key from its admin page."
        case .peertube: "PeerTube → Go live: the live RTMP URL and the live stream key."
        case .customRTMP: "Any RTMP server, for example your own MediaMTX relay (open source, MIT): rtmp://host/app."
        case .customSRT: "Any SRT listener, for example your own MediaMTX relay: srt://host:port; the key becomes the streamid."
        }
    }

    /// Whether the address needs a key on top of the server. The custom ones may carry the
    /// whole address in the server field (a relay path, an SRT streamid in the query).
    public var needsKey: Bool {
        switch self {
        case .customRTMP, .customSRT: false
        default: true
        }
    }
}

/// One destination: a name, its preset, the server it is sent to, its picture shape and bit
/// rates, and whether it is in the next stream. Everything here may be stored on the device; the key is NOT here — the keychain holds
/// it under `id` (`App/Streaming/StreamKeyStore.swift`).
public struct StreamTarget: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var platform: StreamPlatform
    public var server: String
    public var format: StreamFormat
    public var quality: StreamQuality
    public var isEnabled: Bool

    /// A destination from its preset: the platform's server, recommended shape and bit rate,
    /// unless given.
    public init(id: UUID = UUID(), name: String? = nil, platform: StreamPlatform, server: String? = nil,
                format: StreamFormat? = nil, quality: StreamQuality? = nil, isEnabled: Bool = false) {
        self.id = id
        self.name = name ?? platform.title
        self.platform = platform
        self.server = server ?? platform.defaultServer ?? ""
        self.format = format ?? platform.recommendedFormat
        self.quality = quality ?? StreamQuality(videoKbps: platform.recommendedVideoKbps)
        self.isEnabled = isEnabled
    }

    /// Why an address cannot be built. Each case says what to change.
    public enum AddressError: Error, Equatable, Sendable {
        case noServer
        case notAnAddress
        /// The scheme is not one this destination's transport speaks (http, or rtmp on an SRT target).
        case wrongScheme(String)
        case noHost
        case noKey
        /// A key carries a character its address cannot carry (a space, a line break, or a `#`
        /// in RTMP / an `&` in SRT, which the stack reads as the end of the key).
        case badKey
        /// An RTMP address needs an application and a stream name: rtmp://host/app/name.
        case noStreamName
        /// An SRT address asks for SRT's own encryption (`passphrase` or `pbkeylen` in its query).
        /// libsrt would encrypt with its own code, which this build does not ship to do: the app
        /// declares no non-exempt encryption (`ITSAppUsesNonExemptEncryption` is NO). An encrypted
        /// stream goes over RTMPS, which iOS encrypts.
        case srtEncryption

        public var explanation: String {
            switch self {
            case .noServer: "Add the server address."
            case .notAnAddress: "The server is not an address."
            case .wrongScheme(let scheme): "\(scheme.isEmpty ? "No" : "“\(scheme)”") is not a stream address — use rtmp://, rtmps:// or srt://."
            case .noHost: "The server address has no host."
            case .noKey: "Add the stream key."
            case .badKey: "The stream key has a space or a character it cannot carry."
            case .noStreamName: "An RTMP address needs an app and a stream name: rtmp://host/app/name."
            case .srtEncryption: "SRT encryption (a passphrase or pbkeylen in the address) is not offered. Remove it, or stream encrypted over RTMPS."
            }
        }
    }

    /// The transport the server's scheme asks for; nil when the scheme is not a stream scheme.
    public var transport: StreamTransport? {
        guard let scheme = URLComponents(string: Self.trimmed(server))?.scheme?.lowercased() else { return nil }
        return StreamTransport(rawValue: scheme)
    }

    /// The one address the stream is sent to: the server with the key appended — as the stream
    /// name (RTMP: `server/key`) or as the SRT `streamid`. Built only to connect, never stored or
    /// logged (`redactedServer` is what a log may say).
    public func publishURL(key: String) throws(AddressError) -> URL {
        let server = Self.trimmed(self.server)
        guard !server.isEmpty else { throw .noServer }
        guard let parts = URLComponents(string: server) else { throw .notAnAddress }
        let scheme = parts.scheme?.lowercased() ?? ""
        guard let transport = StreamTransport(rawValue: scheme),
              (platform == .customSRT) == (transport == .srt) else { throw .wrongScheme(scheme) }
        guard let host = parts.host, !host.isEmpty else { throw .noHost }
        if transport == .srt, Self.asksForEncryption(parts) { throw .srtEncryption }
        let key = Self.trimmed(key)
        if key.isEmpty, platform.needsKey { throw .noKey }
        let forbidden: Set<Character> = transport.isRTMP ? ["#"] : ["&"]
        let unsafe = key.contains { (character: Character) -> Bool in
            character.isWhitespace || character.isNewline || forbidden.contains(character)
                || character.unicodeScalars.contains { CharacterSet.controlCharacters.contains($0) }
        }
        guard !unsafe else { throw .badKey }

        let address: String
        if transport.isRTMP {
            var base = server
            while base.hasSuffix("/") { base.removeLast() }
            address = key.isEmpty ? base : base + "/" + key
        } else if key.isEmpty {
            address = server
        } else {
            address = server + (parts.query == nil ? "?" : "&") + "streamid=" + key
        }
        guard let url = URL(string: address) else { throw .notAnAddress }
        // The stack takes the first path component as the RTMP application and the rest as the
        // stream name; without both, the server refuses the publish after connecting.
        if transport.isRTMP, url.pathComponents.filter({ $0 != "/" }).count < 2 { throw .noStreamName }
        return url
    }

    /// The server's scheme and host only — what a log line or a status may show. Never the path
    /// (some servers carry the key there) and never the key.
    public var redactedServer: String {
        guard let parts = URLComponents(string: Self.trimmed(server)), let host = parts.host else { return "—" }
        return (parts.scheme.map { $0 + "://" } ?? "") + host
    }

    /// Whether an SRT address's query turns on SRT's own encryption: a `passphrase` (any value —
    /// libsrt refuses a short one rather than streaming in the clear) or a `pbkeylen`, by name in
    /// any case, also where the query is written percent-encoded.
    private static func asksForEncryption(_ parts: URLComponents) -> Bool {
        let names = (parts.queryItems ?? []).map { $0.name.lowercased() }
        let raw = (parts.percentEncodedQuery ?? "").lowercased()
        let decoded = raw.removingPercentEncoding ?? raw
        let pairs = decoded.split(separator: "&").map { $0.split(separator: "=", maxSplits: 1).first.map(String.init) ?? "" }
        return (names + pairs).contains { ["passphrase", "pbkeylen"].contains($0.trimmingCharacters(in: .whitespaces)) }
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// A destination's encoder settings: one video and one audio bit rate, at 30 frames a second.
public struct StreamQuality: Codable, Hashable, Sendable {
    public static let videoRange = 500...12_000
    public static let audioRange = 64...320
    public static let framesPerSecond = 30

    /// Kilobits a second; clamped to the ranges above on the way in.
    public var videoKbps: Int { didSet { videoKbps = Self.clamp(videoKbps, to: Self.videoRange) } }
    public var audioKbps: Int { didSet { audioKbps = Self.clamp(audioKbps, to: Self.audioRange) } }

    /// 4.5 Mbit/s for 1080p30 and 128 kbit/s AAC unless given; presets bring their own video rate.
    public init(videoKbps: Int = 4_500, audioKbps: Int = 128) {
        self.videoKbps = Self.clamp(videoKbps, to: Self.videoRange)
        self.audioKbps = Self.clamp(audioKbps, to: Self.audioRange)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(videoKbps: try container.decode(Int.self, forKey: .videoKbps),
                  audioKbps: try container.decode(Int.self, forKey: .audioKbps))
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        Swift.min(range.upperBound, Swift.max(range.lowerBound, value))
    }
}

/// What the next stream would be: its destinations and how many of them the phone may feed at
/// once. There is no length limit anywhere: a stream runs until it is stopped. Every destination is a full second upload from the phone, so the limit
/// starts at one; for more, the stream goes once to a relay (Restream, or a self-hosted MediaMTX)
/// that forwards it.
public struct StreamPlan: Equatable, Sendable {
    /// What a stream's container and transport add on top of its encoded bit rates.
    public static let overhead = 1.1
    public static let limitRange = 1...4

    public var targets: [StreamTarget]
    public var simultaneousLimit: Int { didSet { simultaneousLimit = Self.clamp(simultaneousLimit) } }

    public init(targets: [StreamTarget] = [], simultaneousLimit: Int = 1) {
        self.targets = targets
        self.simultaneousLimit = Self.clamp(simultaneousLimit)
    }

    /// The destinations the next stream goes to.
    public var enabledTargets: [StreamTarget] { targets.filter(\.isEnabled) }

    /// The upload the plan asks for, in kilobits a second: each destination is its own stream.
    public var uploadKbps: Int {
        let total = enabledTargets.reduce(0) { $0 + $1.quality.videoKbps + $1.quality.audioKbps }
        return Int((Double(total) * Self.overhead).rounded(.up))
    }

    /// The shapes the next stream draws: one picture per shape, shared by every destination in it.
    public var enabledFormats: [StreamFormat] {
        StreamFormat.allCases.filter { format in enabledTargets.contains { $0.format == format } }
    }

    public enum Refusal: Equatable, Sendable {
        case noTarget
        case tooManyTargets(enabled: Int, limit: Int)

        public var explanation: String {
            switch self {
            case .noTarget: "Turn on a destination first."
            case let .tooManyTargets(enabled, limit):
                "\(enabled) destinations are on, \(limit) at once is the limit. Stream once to a relay (Restream, or your own MediaMTX server) to reach more."
            }
        }
    }

    /// Why the plan cannot start; nil when it can.
    public var refusal: Refusal? {
        let count = enabledTargets.count
        if count == 0 { return .noTarget }
        if count > simultaneousLimit { return .tooManyTargets(enabled: count, limit: simultaneousLimit) }
        return nil
    }

    private static func clamp(_ value: Int) -> Int {
        Swift.min(limitRange.upperBound, Swift.max(limitRange.lowerBound, value))
    }
}
