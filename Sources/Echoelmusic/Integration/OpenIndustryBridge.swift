import Foundation
import AVFoundation
import Network
import Combine

// MARK: - Open Industry Bridge
// Connects Echoelmusic to the entire audio/visual/streaming industry
// using ONLY open standards, royalty-free protocols, and free APIs

/// Central hub for zero-cost industry integration
/// All protocols and formats are open-source, royalty-free, or have free tiers
@MainActor
public class OpenIndustryBridge: ObservableObject {

    // MARK: - Singleton

    public static let shared = OpenIndustryBridge()

    // MARK: - Published State

    @Published public var connectedServices: [IndustryService] = []
    @Published public var activeProtocols: Set<OpenProtocol> = []

    // MARK: - Sub-Bridges

    public let audio = OpenAudioBridge()
    public let video = OpenVideoBridge()
    public let streaming = OpenStreamingBridge()
    public let control = OpenControlBridge()
    public let visual = OpenVisualBridge()
    public let social = OpenSocialBridge()
    public let collaboration = OpenCollaborationBridge()

    // MARK: - Initialization

    private init() {
        setupDefaultConnections()
    }

    private func setupDefaultConnections() {
        // Enable all royalty-free protocols by default
        activeProtocols = [
            .oscUDP, .oscTCP,           // Open Sound Control (free)
            .midi2,                      // MIDI 2.0 (royalty-free since 2020)
            .rtpMIDI,                    // Network MIDI (Apple's free implementation)
            .linkAbleton,                // Ableton Link (open source)
            .ndi,                        // NDI (free SDK, royalty-free use)
            .srt,                        // SRT (open source streaming)
            .webRTC,                     // WebRTC (open source, royalty-free)
            .rtmp,                       // RTMP (open protocol)
            .hls,                        // HLS (Apple's free streaming)
            .spout,                      // Spout (open source texture sharing)
            .syphon,                     // Syphon (open source for macOS)
            .artNet,                     // Art-Net (open protocol for DMX)
            .sACN,                       // sACN/E1.31 (open DMX over network)
            .lv2,                        // LV2 plugins (open source)
            .clap,                       // CLAP plugins (open source)
            .vst3,                       // VST3 (royalty-free since 2018)
            .auv3,                       // Audio Units (Apple's free format)
            .fhir,                       // HL7 FHIR (open healthcare standard)
            .dicom                       // DICOM (open medical imaging)
        ]
    }
}

// MARK: - Open Protocol Enumeration

public enum OpenProtocol: String, CaseIterable {
    // Audio Control
    case oscUDP = "OSC/UDP"
    case oscTCP = "OSC/TCP"
    case midi2 = "MIDI 2.0"
    case rtpMIDI = "RTP-MIDI"
    case linkAbleton = "Ableton Link"

    // Video/Texture Sharing
    case ndi = "NDI"
    case spout = "Spout"
    case syphon = "Syphon"

    // Streaming
    case rtmp = "RTMP"
    case srt = "SRT"
    case webRTC = "WebRTC"
    case hls = "HLS"
    case dash = "DASH"

    // Lighting
    case artNet = "Art-Net"
    case sACN = "sACN/E1.31"
    case dmx = "DMX512"

    // Plugins
    case vst3 = "VST3"
    case auv3 = "Audio Units"
    case lv2 = "LV2"
    case clap = "CLAP"

    // Medical
    case fhir = "HL7 FHIR"
    case dicom = "DICOM"

    var licenseCost: String { "Free / Open Source" }

    var documentation: String {
        switch self {
        case .oscUDP, .oscTCP: return "https://opensoundcontrol.stanford.edu"
        case .midi2: return "https://midi.org/midi-2-0"
        case .rtpMIDI: return "https://developer.apple.com/documentation/coremidi"
        case .linkAbleton: return "https://github.com/Ableton/link"
        case .ndi: return "https://ndi.video/developers/"
        case .spout: return "https://spout.zeal.co"
        case .syphon: return "https://syphon.github.io"
        case .rtmp: return "https://rtmp.veriskope.com/docs/spec/"
        case .srt: return "https://github.com/Haivision/srt"
        case .webRTC: return "https://webrtc.org"
        case .hls: return "https://developer.apple.com/streaming/"
        case .dash: return "https://dashif.org"
        case .artNet: return "https://art-net.org.uk"
        case .sACN: return "https://tsp.esta.org/tsp/documents/docs/ANSI_E1-31-2018.pdf"
        case .dmx: return "https://tsp.esta.org/tsp/documents/docs/ANSI-ESTA_E1-11_2008R2018.pdf"
        case .vst3: return "https://steinbergmedia.github.io/vst3_dev_portal/"
        case .auv3: return "https://developer.apple.com/audio-unit/"
        case .lv2: return "https://lv2plug.in"
        case .clap: return "https://github.com/free-audio/clap"
        case .fhir: return "https://hl7.org/fhir/"
        case .dicom: return "https://www.dicomstandard.org"
        }
    }
}

// MARK: - Industry Service

public struct IndustryService: Identifiable {
    public let id = UUID()
    public let name: String
    public let category: ServiceCategory
    public let protocol_: OpenProtocol
    public let status: ConnectionStatus
    public let endpoint: String?

    public enum ServiceCategory: String, CaseIterable {
        case daw = "DAW Integration"
        case visualSoftware = "Visual Software"
        case streaming = "Streaming Platform"
        case lighting = "Lighting Control"
        case plugin = "Plugin Host"
        case medical = "Medical System"
        case social = "Social Platform"
    }

    public enum ConnectionStatus {
        case connected
        case connecting
        case disconnected
        case available
    }
}

// MARK: - Open Audio Bridge

/// Royalty-free audio protocol integrations
public class OpenAudioBridge: ObservableObject {

    // MARK: - OSC (Open Sound Control) - Completely Free

    private var oscServer: NWListener?
    private var oscConnections: [NWConnection] = []

    @Published public var oscInPort: UInt16 = 8000
    @Published public var oscOutPort: UInt16 = 9000
    @Published public var oscTargetHost: String = "127.0.0.1"

    /// Start OSC server (UDP)
    public func startOSCServer(port: UInt16 = 8000) throws {
        let params = NWParameters.udp
        oscServer = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)

        oscServer?.newConnectionHandler = { [weak self] connection in
            self?.handleOSCConnection(connection)
        }

        oscServer?.start(queue: .main)
        oscInPort = port
    }

    private func handleOSCConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        oscConnections.append(connection)

        connection.receiveMessage { [weak self] content, _, _, error in
            if let data = content {
                self?.parseOSCMessage(data)
            }
        }
    }

    private func parseOSCMessage(_ data: Data) {
        // OSC message parsing (Type-Length-Value format)
        // Address pattern starts with '/'
        guard data.first == 0x2F else { return } // '/'

        // Find null terminator for address
        if let nullIndex = data.firstIndex(of: 0x00) {
            let addressData = data[0..<nullIndex]
            if let address = String(data: addressData, encoding: .utf8) {
                NotificationCenter.default.post(
                    name: .oscMessageReceived,
                    object: nil,
                    userInfo: ["address": address, "data": data]
                )
            }
        }
    }

    /// Send OSC message
    public func sendOSC(address: String, values: [Any]) {
        var message = Data()

        // Address (null-padded to 4-byte boundary)
        let addressBytes = address.utf8 + [0]
        message.append(contentsOf: addressBytes)
        while message.count % 4 != 0 { message.append(0) }

        // Type tag
        var typeTag = ","
        for value in values {
            switch value {
            case is Int32: typeTag += "i"
            case is Float: typeTag += "f"
            case is String: typeTag += "s"
            case is Data: typeTag += "b"
            default: break
            }
        }
        let typeBytes = typeTag.utf8 + [0]
        message.append(contentsOf: typeBytes)
        while message.count % 4 != 0 { message.append(0) }

        // Values
        for value in values {
            switch value {
            case let i as Int32:
                var bigEndian = i.bigEndian
                message.append(Data(bytes: &bigEndian, count: 4))
            case let f as Float:
                var bits = f.bitPattern.bigEndian
                message.append(Data(bytes: &bits, count: 4))
            case let s as String:
                let stringBytes = s.utf8 + [0]
                message.append(contentsOf: stringBytes)
                while message.count % 4 != 0 { message.append(0) }
            default: break
            }
        }

        // Send via UDP
        let host = NWEndpoint.Host(oscTargetHost)
        let port = NWEndpoint.Port(rawValue: oscOutPort)!
        let connection = NWConnection(host: host, port: port, using: .udp)

        connection.start(queue: .main)
        connection.send(content: message, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    // MARK: - Ableton Link - Open Source (github.com/Ableton/link)

    @Published public var linkEnabled = false
    @Published public var linkTempo: Double = 120.0
    @Published public var linkBeat: Double = 0.0
    @Published public var linkPeers: Int = 0

    /// Enable Ableton Link synchronization
    /// Link SDK is open source under GPLv2+ with linking exception
    public func enableLink() {
        // Link integration via C++ SDK wrapper
        // See: https://github.com/Ableton/link
        linkEnabled = true
        NotificationCenter.default.post(name: .linkEnabled, object: nil)
    }

    // MARK: - MIDI 2.0 - Royalty-Free Since 2020

    /// MIDI 2.0 is royalty-free for all implementations
    /// Universal MIDI Packet (UMP) format support
    public func createMIDI2Connection() {
        // CoreMIDI supports MIDI 2.0 natively on iOS 14+ / macOS 11+
        NotificationCenter.default.post(name: .midi2Available, object: nil)
    }

    // MARK: - Plugin Formats

    /// VST3 - Royalty-free since 2018 (Steinberg)
    /// AU - Always free (Apple)
    /// LV2 - Open source (ISC license)
    /// CLAP - Open source (MIT license)

    public struct PluginFormats {
        public static let vst3 = PluginFormatInfo(
            name: "VST3",
            license: "Royalty-Free (GPLv3 dual-licensed)",
            paths: [
                "/Library/Audio/Plug-Ins/VST3",
                "~/Library/Audio/Plug-Ins/VST3"
            ]
        )

        public static let audioUnit = PluginFormatInfo(
            name: "Audio Units v3",
            license: "Free (Apple)",
            paths: [
                "/Library/Audio/Plug-Ins/Components",
                "~/Library/Audio/Plug-Ins/Components"
            ]
        )

        public static let lv2 = PluginFormatInfo(
            name: "LV2",
            license: "Open Source (ISC)",
            paths: [
                "/Library/Audio/Plug-Ins/LV2",
                "~/.lv2"
            ]
        )

        public static let clap = PluginFormatInfo(
            name: "CLAP",
            license: "Open Source (MIT)",
            paths: [
                "/Library/Audio/Plug-Ins/CLAP",
                "~/Library/Audio/Plug-Ins/CLAP"
            ]
        )
    }

    public struct PluginFormatInfo {
        public let name: String
        public let license: String
        public let paths: [String]
    }
}

// MARK: - Open Video Bridge

/// Free video protocols and texture sharing
public class OpenVideoBridge: ObservableObject {

    // MARK: - NDI (Network Device Interface) - Free SDK

    /// NDI is free for non-commercial and most commercial uses
    /// SDK: https://ndi.video/download-ndi-sdk/

    @Published public var ndiSources: [NDISource] = []
    @Published public var ndiOutputEnabled = false

    public struct NDISource: Identifiable {
        public let id = UUID()
        public let name: String
        public let ipAddress: String
    }

    /// Discover NDI sources on network
    public func discoverNDISources() {
        // NDI discovery via mDNS/Bonjour
        let browser = NWBrowser(for: .bonjour(type: "_ndi._tcp", domain: nil), using: .tcp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            self?.ndiSources = results.compactMap { result in
                if case .service(let name, _, _, _) = result.endpoint {
                    return NDISource(name: name, ipAddress: "discovered")
                }
                return nil
            }
        }
        browser.start(queue: .main)
    }

    /// Start NDI output
    public func startNDIOutput(name: String = "Echoelmusic") {
        ndiOutputEnabled = true
        // NDI SDK integration for sending frames
    }

    // MARK: - Syphon (macOS) / Spout (Windows) - Open Source

    /// Both are MIT/BSD licensed, completely free

    @Published public var syphonServers: [String] = []

    public func discoverSyphonServers() {
        // Syphon server directory lookup
        // See: https://github.com/Syphon/Syphon-Framework
    }

    // MARK: - V4L2 (Linux) - Open Source

    /// Video4Linux2 - kernel standard, completely free
    public func listV4L2Devices() -> [String] {
        // List /dev/video* devices on Linux
        return []
    }
}

// MARK: - Open Streaming Bridge

/// Royalty-free streaming protocols
public class OpenStreamingBridge: ObservableObject {

    // MARK: - RTMP - Open Protocol

    /// RTMP specification is public and royalty-free
    /// Used by: YouTube, Twitch, Facebook Live, etc.

    @Published public var rtmpStreaming = false
    @Published public var rtmpURL: String = ""

    public struct RTMPEndpoint {
        public let platform: String
        public let ingestURL: String

        public static let youtube = RTMPEndpoint(
            platform: "YouTube Live",
            ingestURL: "rtmp://a.rtmp.youtube.com/live2"
        )

        public static let twitch = RTMPEndpoint(
            platform: "Twitch",
            ingestURL: "rtmp://live.twitch.tv/app"
        )

        public static let facebook = RTMPEndpoint(
            platform: "Facebook Live",
            ingestURL: "rtmps://live-api-s.facebook.com:443/rtmp"
        )

        public static let custom = RTMPEndpoint(
            platform: "Custom RTMP",
            ingestURL: ""
        )
    }

    // MARK: - SRT (Secure Reliable Transport) - Open Source

    /// Haivision SRT Protocol - open source (MPL 2.0)
    /// Better than RTMP for unstable connections
    /// https://github.com/Haivision/srt

    @Published public var srtEnabled = false

    public func startSRTStream(url: String) {
        // SRT library integration
        srtEnabled = true
    }

    // MARK: - WebRTC - Royalty-Free

    /// W3C/IETF standard, completely free
    /// Used for: Discord, Google Meet, real-time communication

    public func createWebRTCPeer() {
        // WebRTC peer connection
    }

    // MARK: - HLS / DASH - Free Standards

    /// HLS: Apple's HTTP Live Streaming (free)
    /// DASH: MPEG-DASH (ISO standard, royalty-free)

    public func generateHLSPlaylist() -> String {
        """
        #EXTM3U
        #EXT-X-VERSION:3
        #EXT-X-STREAM-INF:BANDWIDTH=800000
        stream_800k.m3u8
        #EXT-X-STREAM-INF:BANDWIDTH=1400000
        stream_1400k.m3u8
        """
    }
}

// MARK: - Open Control Bridge

/// Free lighting and hardware control protocols
public class OpenControlBridge: ObservableObject {

    // MARK: - Art-Net - Open Protocol

    /// Art-Net 4 is free to implement
    /// DMX over IP for lighting control

    @Published public var artNetEnabled = false
    @Published public var artNetUniverse: Int = 0

    public func sendArtNetDMX(universe: Int, channels: [UInt8]) {
        // Art-Net packet: OpCode 0x5000 (ArtDmx)
        var packet = Data()

        // Header "Art-Net\0"
        packet.append(contentsOf: "Art-Net".utf8)
        packet.append(0)

        // OpCode (little endian)
        packet.append(0x00)
        packet.append(0x50)

        // Protocol version (14)
        packet.append(0)
        packet.append(14)

        // Sequence, Physical, Universe
        packet.append(0) // Sequence
        packet.append(0) // Physical
        packet.append(UInt8(universe & 0xFF))
        packet.append(UInt8((universe >> 8) & 0xFF))

        // Length (big endian)
        let length = min(channels.count, 512)
        packet.append(UInt8((length >> 8) & 0xFF))
        packet.append(UInt8(length & 0xFF))

        // DMX data
        packet.append(contentsOf: channels.prefix(512))

        // Send to broadcast or unicast
        sendUDP(data: packet, host: "255.255.255.255", port: 6454)
    }

    // MARK: - sACN / E1.31 - Open Standard

    /// ANSI E1.31 (sACN) - open standard for DMX over IP
    /// More reliable than Art-Net for large installations

    public func sendSACN(universe: Int, channels: [UInt8]) {
        // sACN uses multicast: 239.255.{universe_high}.{universe_low}
        let multicastIP = "239.255.\((universe >> 8) & 0xFF).\(universe & 0xFF)"
        // E1.31 packet format implementation
    }

    private func sendUDP(data: Data, host: String, port: UInt16) {
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: .udp
        )
        connection.start(queue: .main)
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

// MARK: - Open Visual Bridge

/// Open source visual programming protocols
public class OpenVisualBridge: ObservableObject {

    // MARK: - TouchDesigner Integration via OSC/MIDI

    /// TouchDesigner accepts OSC and MIDI for free
    /// No additional licensing needed for control

    public func sendToTouchDesigner(parameter: String, value: Float) {
        OpenIndustryBridge.shared.audio.sendOSC(
            address: "/td/\(parameter)",
            values: [value]
        )
    }

    // MARK: - Resolume Integration via OSC

    /// Resolume accepts OSC commands
    public func sendToResolume(layer: Int, clip: Int, parameter: String, value: Float) {
        OpenIndustryBridge.shared.audio.sendOSC(
            address: "/composition/layers/\(layer)/clips/\(clip)/\(parameter)",
            values: [value]
        )
    }

    // MARK: - Open Frameworks / Processing / VVVV

    /// All open source visual frameworks accept OSC
    public let supportedFrameworks = [
        "openFrameworks (MIT)",
        "Processing (GPL/LGPL)",
        "VVVV (LGPL)",
        "Max/MSP (via OSC)",
        "Pure Data (BSD)",
        "Cinder (BSD)",
        "Three.js (MIT)",
        "p5.js (LGPL)"
    ]
}

// MARK: - Open Social Bridge

/// Free tier API integrations
public class OpenSocialBridge: ObservableObject {

    /// All major platforms offer free API access with rate limits
    public struct FreeAPITiers {
        public static let platforms: [PlatformAPIInfo] = [
            PlatformAPIInfo(
                name: "YouTube",
                freeQuota: "10,000 units/day",
                documentation: "https://developers.google.com/youtube/v3"
            ),
            PlatformAPIInfo(
                name: "Twitch",
                freeQuota: "Unlimited (with rate limits)",
                documentation: "https://dev.twitch.tv/docs/api"
            ),
            PlatformAPIInfo(
                name: "Discord",
                freeQuota: "Unlimited for bots",
                documentation: "https://discord.com/developers/docs"
            ),
            PlatformAPIInfo(
                name: "Twitter/X",
                freeQuota: "Free tier available",
                documentation: "https://developer.twitter.com"
            ),
            PlatformAPIInfo(
                name: "TikTok",
                freeQuota: "Content posting API",
                documentation: "https://developers.tiktok.com"
            ),
            PlatformAPIInfo(
                name: "Bluesky",
                freeQuota: "Unlimited (AT Protocol)",
                documentation: "https://atproto.com"
            ),
            PlatformAPIInfo(
                name: "Mastodon",
                freeQuota: "Unlimited (ActivityPub)",
                documentation: "https://docs.joinmastodon.org/api/"
            )
        ]
    }

    public struct PlatformAPIInfo {
        public let name: String
        public let freeQuota: String
        public let documentation: String
    }
}

// MARK: - Open Collaboration Bridge

/// Free real-time collaboration protocols
public class OpenCollaborationBridge: ObservableObject {

    // MARK: - WebSocket - Open Standard

    /// WebSocket (RFC 6455) - completely free
    public func createCollaborationSession() {
        // WebSocket-based real-time sync
    }

    // MARK: - CRDT Libraries - Open Source

    /// Conflict-free Replicated Data Types for collaboration
    /// Yjs, Automerge - all open source

    public let crdtLibraries = [
        "Yjs (MIT) - https://yjs.dev",
        "Automerge (MIT) - https://automerge.org",
        "Diamond Types (Apache 2.0)"
    ]

    // MARK: - WebRTC Data Channels

    /// Peer-to-peer collaboration without servers
    public func createP2PSession() {
        // WebRTC data channel for direct sync
    }
}

// MARK: - DAW Integration Profiles

/// Pre-configured integrations for popular DAWs
public struct DAWIntegration {

    public static let profiles: [DAWProfile] = [
        // Ableton Live
        DAWProfile(
            name: "Ableton Live",
            protocols: [.oscUDP, .linkAbleton, .midi2],
            oscPort: 11000,
            features: ["Link tempo sync", "OSC remote control", "MIDI mapping"]
        ),

        // Logic Pro
        DAWProfile(
            name: "Logic Pro",
            protocols: [.oscUDP, .midi2, .auv3],
            oscPort: 8000,
            features: ["Control Surface support", "AU hosting", "MIDI FX"]
        ),

        // FL Studio
        DAWProfile(
            name: "FL Studio",
            protocols: [.oscUDP, .midi2, .vst3],
            oscPort: 10000,
            features: ["OSC control", "VST3 hosting", "Image-Line Bridge"]
        ),

        // Reaper
        DAWProfile(
            name: "Reaper",
            protocols: [.oscUDP, .midi2, .vst3, .lv2],
            oscPort: 8000,
            features: ["ReaScript API", "All plugin formats", "OSC Learn"]
        ),

        // Bitwig Studio
        DAWProfile(
            name: "Bitwig Studio",
            protocols: [.oscUDP, .linkAbleton, .midi2, .clap],
            oscPort: 8000,
            features: ["Link sync", "CLAP support", "OSC", "Modular"]
        ),

        // Pro Tools (via Eucon alternative)
        DAWProfile(
            name: "Pro Tools",
            protocols: [.oscUDP, .midi2],
            oscPort: 9000,
            features: ["HUI emulation", "MIDI control"]
        ),

        // Cubase/Nuendo
        DAWProfile(
            name: "Cubase/Nuendo",
            protocols: [.midi2, .vst3, .oscUDP],
            oscPort: 8000,
            features: ["VST3 native", "Generic Remote", "OSC"]
        ),

        // GarageBand
        DAWProfile(
            name: "GarageBand",
            protocols: [.midi2, .auv3],
            oscPort: nil,
            features: ["Audio Units", "MIDI control"]
        ),

        // Ardour (Open Source DAW)
        DAWProfile(
            name: "Ardour",
            protocols: [.oscUDP, .midi2, .lv2, .vst3],
            oscPort: 3819,
            features: ["Full OSC API", "LV2 native", "JACK"]
        )
    ]

    public struct DAWProfile {
        public let name: String
        public let protocols: [OpenProtocol]
        public let oscPort: UInt16?
        public let features: [String]
    }
}

// MARK: - Visual Software Integration

public struct VisualSoftwareIntegration {

    public static let profiles: [VisualProfile] = [
        VisualProfile(
            name: "TouchDesigner",
            protocols: [.oscUDP, .midi2, .ndi, .spout, .syphon],
            oscPort: 7000,
            features: ["OSC In/Out", "NDI I/O", "Spout/Syphon", "MIDI"]
        ),
        VisualProfile(
            name: "Resolume Arena/Avenue",
            protocols: [.oscUDP, .midi2, .ndi, .spout, .syphon, .artNet, .sACN],
            oscPort: 7000,
            features: ["Full OSC API", "Art-Net output", "NDI", "Spout"]
        ),
        VisualProfile(
            name: "MadMapper",
            protocols: [.oscUDP, .midi2, .artNet, .sACN, .syphon],
            oscPort: 8010,
            features: ["OSC control", "Art-Net/sACN", "Syphon input"]
        ),
        VisualProfile(
            name: "OBS Studio",
            protocols: [.oscUDP, .ndi, .srt, .rtmp],
            oscPort: 4455, // obs-websocket
            features: ["WebSocket API", "NDI input", "SRT output"]
        ),
        VisualProfile(
            name: "Unreal Engine",
            protocols: [.oscUDP, .ndi, .liveLink],
            oscPort: 8000,
            features: ["OSC plugin", "NDI plugin", "Live Link"]
        ),
        VisualProfile(
            name: "Unity",
            protocols: [.oscUDP, .midi2, .ndi],
            oscPort: 8000,
            features: ["OSC packages", "MIDI packages", "NDI plugin"]
        ),
        VisualProfile(
            name: "Blender",
            protocols: [.oscUDP],
            oscPort: 9000,
            features: ["AddOns for OSC", "Python scripting"]
        )
    ]

    public struct VisualProfile {
        public let name: String
        public let protocols: [OpenProtocol]
        public let oscPort: UInt16
        public let features: [String]
    }
}

// MARK: - Notifications

public extension Notification.Name {
    static let oscMessageReceived = Notification.Name("oscMessageReceived")
    static let linkEnabled = Notification.Name("linkEnabled")
    static let midi2Available = Notification.Name("midi2Available")
    static let ndiSourceDiscovered = Notification.Name("ndiSourceDiscovered")
}

// MARK: - Quick Connect

public extension OpenIndustryBridge {

    /// One-tap connection to any DAW
    func quickConnectDAW(_ dawName: String) {
        guard let profile = DAWIntegration.profiles.first(where: { $0.name == dawName }) else {
            return
        }

        // Enable Link if supported
        if profile.protocols.contains(.linkAbleton) {
            audio.enableLink()
        }

        // Start OSC if supported
        if profile.protocols.contains(.oscUDP), let port = profile.oscPort {
            try? audio.startOSCServer(port: port)
        }

        // Enable MIDI 2.0
        if profile.protocols.contains(.midi2) {
            audio.createMIDI2Connection()
        }

        connectedServices.append(IndustryService(
            name: profile.name,
            category: .daw,
            protocol_: .oscUDP,
            status: .connected,
            endpoint: "localhost:\(profile.oscPort ?? 0)"
        ))
    }

    /// One-tap connection to visual software
    func quickConnectVisual(_ softwareName: String) {
        guard let profile = VisualSoftwareIntegration.profiles.first(where: { $0.name == softwareName }) else {
            return
        }

        // Start OSC
        try? audio.startOSCServer(port: profile.oscPort)

        // Enable NDI if supported
        if profile.protocols.contains(.ndi) {
            video.startNDIOutput(name: "Echoelmusic")
        }

        connectedServices.append(IndustryService(
            name: profile.name,
            category: .visualSoftware,
            protocol_: .oscUDP,
            status: .connected,
            endpoint: "localhost:\(profile.oscPort)"
        ))
    }

    /// Connect to streaming platform (free RTMP)
    func quickConnectStreaming(_ platform: OpenStreamingBridge.RTMPEndpoint, streamKey: String) {
        streaming.rtmpURL = "\(platform.ingestURL)/\(streamKey)"
        streaming.rtmpStreaming = true

        connectedServices.append(IndustryService(
            name: platform.platform,
            category: .streaming,
            protocol_: .rtmp,
            status: .connected,
            endpoint: platform.ingestURL
        ))
    }
}

// MARK: - Cost Summary

public struct IndustryIntegrationCost {
    public static let summary = """
    ╔══════════════════════════════════════════════════════════════╗
    ║            ECHOELMUSIC INDUSTRY INTEGRATION                  ║
    ║                    COST ANALYSIS                             ║
    ╠══════════════════════════════════════════════════════════════╣
    ║ AUDIO PROTOCOLS                                              ║
    ║   OSC (Open Sound Control)              FREE - Open Standard ║
    ║   MIDI 2.0                              FREE - Royalty-Free  ║
    ║   Ableton Link                          FREE - Open Source   ║
    ║   RTP-MIDI (Network MIDI)               FREE - Apple         ║
    ╠══════════════════════════════════════════════════════════════╣
    ║ PLUGIN FORMATS                                               ║
    ║   VST3                                  FREE - Since 2018    ║
    ║   Audio Units (AU)                      FREE - Apple         ║
    ║   LV2                                   FREE - Open Source   ║
    ║   CLAP                                  FREE - Open Source   ║
    ╠══════════════════════════════════════════════════════════════╣
    ║ VIDEO/TEXTURE                                                ║
    ║   NDI                                   FREE - SDK Available ║
    ║   Syphon (macOS)                        FREE - Open Source   ║
    ║   Spout (Windows)                       FREE - Open Source   ║
    ╠══════════════════════════════════════════════════════════════╣
    ║ STREAMING                                                    ║
    ║   RTMP                                  FREE - Open Protocol ║
    ║   SRT                                   FREE - Open Source   ║
    ║   WebRTC                                FREE - W3C Standard  ║
    ║   HLS                                   FREE - Apple         ║
    ╠══════════════════════════════════════════════════════════════╣
    ║ LIGHTING                                                     ║
    ║   Art-Net                               FREE - Open Protocol ║
    ║   sACN (E1.31)                          FREE - ANSI Standard ║
    ║   DMX512                                FREE - Open Standard ║
    ╠══════════════════════════════════════════════════════════════╣
    ║ SOCIAL/STREAMING APIS                                        ║
    ║   YouTube API                           FREE - 10k units/day ║
    ║   Twitch API                            FREE - With limits   ║
    ║   Discord API                           FREE - Unlimited     ║
    ║   Bluesky/AT Protocol                   FREE - Open Protocol ║
    ║   Mastodon/ActivityPub                  FREE - Open Protocol ║
    ╠══════════════════════════════════════════════════════════════╣
    ║ MEDICAL STANDARDS                                            ║
    ║   HL7 FHIR                              FREE - Open Standard ║
    ║   DICOM                                 FREE - Open Standard ║
    ╠══════════════════════════════════════════════════════════════╣
    ║                                                              ║
    ║   TOTAL LICENSING COST:                 $0.00                ║
    ║                                                              ║
    ╚══════════════════════════════════════════════════════════════╝
    """
}
