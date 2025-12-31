import Foundation
import Combine
import Network

// MARK: - Global Collaboration Network
// Worldwide TURN servers, Audio Stem Sharing, Jam Session Matchmaking
// Target: <50ms latency for real-time musical collaboration

/// Global TURN Server Infrastructure
/// Ensures NAT traversal for 99%+ of network configurations
/// Migrated to @Observable for better performance (Swift 5.9+)
@MainActor
@Observable
final class GlobalTURNInfrastructure {

    // MARK: - Observable State

    var connectedServer: TURNServer?
    var connectionLatency: Int = 0 // ms
    var relayedData: Int = 0 // bytes
    var natType: NATType = .unknown

    // MARK: - TURN Server Configuration

    struct TURNServer: Identifiable, Hashable {
        let id: UUID
        let region: String
        let hostname: String
        let port: Int
        let protocol_: TURNProtocol
        let latencyMs: Int
        var isActive: Bool
        var load: Float // 0-1

        static func == (lhs: TURNServer, rhs: TURNServer) -> Bool {
            lhs.id == rhs.id
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }

    enum TURNProtocol: String {
        case udp = "UDP"
        case tcp = "TCP"
        case tls = "TLS"
    }

    enum NATType: String {
        case unknown = "Unknown"
        case openInternet = "Open Internet"
        case fullCone = "Full Cone NAT"
        case restrictedCone = "Restricted Cone NAT"
        case portRestricted = "Port Restricted NAT"
        case symmetric = "Symmetric NAT"

        var description: String {
            switch self {
            case .unknown: return "NAT type not yet detected"
            case .openInternet: return "Direct connection possible"
            case .fullCone: return "Good - STUN should work"
            case .restrictedCone: return "Good - STUN should work"
            case .portRestricted: return "Fair - May need TURN"
            case .symmetric: return "Challenging - TURN required"
            }
        }

        var requiresTURN: Bool {
            switch self {
            case .symmetric: return true
            default: return false
            }
        }
    }

    // MARK: - Global TURN Server Network

    static let globalServers: [TURNServer] = [
        // North America
        TURNServer(id: UUID(), region: "US-East (Virginia)", hostname: "turn-use1.echoelmusic.com", port: 3478, protocol_: .udp, latencyMs: 20, isActive: true, load: 0.3),
        TURNServer(id: UUID(), region: "US-West (Oregon)", hostname: "turn-usw2.echoelmusic.com", port: 3478, protocol_: .udp, latencyMs: 25, isActive: true, load: 0.4),
        TURNServer(id: UUID(), region: "US-Central (Texas)", hostname: "turn-usc1.echoelmusic.com", port: 3478, protocol_: .udp, latencyMs: 35, isActive: true, load: 0.2),
        TURNServer(id: UUID(), region: "Canada (Montreal)", hostname: "turn-ca1.echoelmusic.com", port: 3478, protocol_: .udp, latencyMs: 40, isActive: true, load: 0.2),

        // Europe
        TURNServer(id: UUID(), region: "Europe-West (Frankfurt)", hostname: "turn-euw1.echoelmusic.com", port: 3478, protocol_: .udp, latencyMs: 25, isActive: true, load: 0.5),
        TURNServer(id: UUID(), region: "Europe-North (Stockholm)", hostname: "turn-eun1.echoelmusic.com", port: 3478, protocol_: .udp, latencyMs: 35, isActive: true, load: 0.3),
        TURNServer(id: UUID(), region: "Europe-South (Milan)", hostname: "turn-eus1.echoelmusic.com", port: 3478, protocol_: .udp, latencyMs: 30, isActive: true, load: 0.3),
        TURNServer(id: UUID(), region: "UK (London)", hostname: "turn-uk1.echoelmusic.com", port: 3478, protocol_: .udp, latencyMs: 28, isActive: true, load: 0.4),

        // Asia Pacific
        TURNServer(id: UUID(), region: "Asia-East (Tokyo)", hostname: "turn-ape1.echoelmusic.com", port: 3478, protocol_: .udp, latencyMs: 80, isActive: true, load: 0.4),
        TURNServer(id: UUID(), region: "Asia-Southeast (Singapore)", hostname: "turn-apse1.echoelmusic.com", port: 3478, protocol_: .udp, latencyMs: 90, isActive: true, load: 0.5),
        TURNServer(id: UUID(), region: "Asia-South (Mumbai)", hostname: "turn-aps1.echoelmusic.com", port: 3478, protocol_: .udp, latencyMs: 95, isActive: true, load: 0.3),
        TURNServer(id: UUID(), region: "Korea (Seoul)", hostname: "turn-apn1.echoelmusic.com", port: 3478, protocol_: .udp, latencyMs: 85, isActive: true, load: 0.4),

        // Oceania
        TURNServer(id: UUID(), region: "Australia (Sydney)", hostname: "turn-au1.echoelmusic.com", port: 3478, protocol_: .udp, latencyMs: 150, isActive: true, load: 0.2),
        TURNServer(id: UUID(), region: "New Zealand (Auckland)", hostname: "turn-nz1.echoelmusic.com", port: 3478, protocol_: .udp, latencyMs: 160, isActive: true, load: 0.1),

        // South America
        TURNServer(id: UUID(), region: "South America (Sao Paulo)", hostname: "turn-sa1.echoelmusic.com", port: 3478, protocol_: .udp, latencyMs: 100, isActive: true, load: 0.3),
        TURNServer(id: UUID(), region: "South America (Santiago)", hostname: "turn-sa2.echoelmusic.com", port: 3478, protocol_: .udp, latencyMs: 110, isActive: true, load: 0.2),

        // Africa
        TURNServer(id: UUID(), region: "Africa-North (Cairo)", hostname: "turn-afn1.echoelmusic.com", port: 3478, protocol_: .udp, latencyMs: 80, isActive: true, load: 0.2),
        TURNServer(id: UUID(), region: "Africa-South (Johannesburg)", hostname: "turn-afs1.echoelmusic.com", port: 3478, protocol_: .udp, latencyMs: 140, isActive: true, load: 0.2),
        TURNServer(id: UUID(), region: "Africa-West (Lagos)", hostname: "turn-afw1.echoelmusic.com", port: 3478, protocol_: .udp, latencyMs: 120, isActive: true, load: 0.3),
        TURNServer(id: UUID(), region: "Africa-East (Nairobi)", hostname: "turn-afe1.echoelmusic.com", port: 3478, protocol_: .udp, latencyMs: 130, isActive: true, load: 0.2),

        // Middle East
        TURNServer(id: UUID(), region: "Middle East (Dubai)", hostname: "turn-me1.echoelmusic.com", port: 3478, protocol_: .udp, latencyMs: 70, isActive: true, load: 0.3),
        TURNServer(id: UUID(), region: "Middle East (Tel Aviv)", hostname: "turn-me2.echoelmusic.com", port: 3478, protocol_: .udp, latencyMs: 65, isActive: true, load: 0.2),

        // China (Special Region)
        TURNServer(id: UUID(), region: "China-East (Shanghai)", hostname: "turn-cn1.echoelmusic.cn", port: 3478, protocol_: .tls, latencyMs: 120, isActive: true, load: 0.6),
        TURNServer(id: UUID(), region: "China-North (Beijing)", hostname: "turn-cn2.echoelmusic.cn", port: 3478, protocol_: .tls, latencyMs: 130, isActive: true, load: 0.5),
    ]

    private var availableServers: [TURNServer] = []

    init() {
        availableServers = Self.globalServers
        #if DEBUG
        debugLog("🌐", "GlobalTURNInfrastructure: Initialized with \(availableServers.count) servers worldwide")
        #endif
    }

    // MARK: - Server Selection

    func selectOptimalServer(forLatitude lat: Double, forLongitude lon: Double) async -> TURNServer? {
        // Filter active servers with low load
        let candidates = availableServers.filter { $0.isActive && $0.load < 0.8 }

        // Sort by latency (in production: actually measure RTT)
        let sorted = candidates.sorted { $0.latencyMs < $1.latencyMs }

        // Return best server
        guard let best = sorted.first else { return nil }

        connectedServer = best
        connectionLatency = best.latencyMs

        #if DEBUG
        debugLog("✅", "Selected TURN server: \(best.region) (\(best.hostname)) - \(best.latencyMs)ms")
        #endif
        return best
    }

    // MARK: - NAT Detection

    func detectNATType() async -> NATType {
        // STUN binding request to detect NAT type
        // In production: Send multiple STUN requests from different ports

        // Simulate detection
        try? await Task.sleep(nanoseconds: 500_000_000)

        let types: [NATType] = [.fullCone, .restrictedCone, .portRestricted, .symmetric]
        natType = types.randomElement() ?? .unknown

        #if DEBUG
        debugLog("🔍", "Detected NAT type: \(natType.rawValue) - \(natType.description)")
        #endif
        return natType
    }

    // MARK: - ICE Configuration

    func generateICEServers() -> [ICEServerConfig] {
        var servers: [ICEServerConfig] = []

        // Add STUN servers (free, no auth)
        servers.append(ICEServerConfig(urls: ["stun:stun.l.google.com:19302"]))
        servers.append(ICEServerConfig(urls: ["stun:stun1.l.google.com:19302"]))
        servers.append(ICEServerConfig(urls: ["stun:stun2.l.google.com:19302"]))
        servers.append(ICEServerConfig(urls: ["stun:stun.echoelmusic.com:3478"]))

        // Add TURN servers (authenticated, relayed)
        if let server = connectedServer {
            let turnURL = "turn:\(server.hostname):\(server.port)"
            servers.append(ICEServerConfig(
                urls: [turnURL],
                username: "echoelmusic",
                credential: generateTURNCredential()
            ))

            // Add TCP fallback for restrictive firewalls
            let turnTCPURL = "turn:\(server.hostname):\(server.port)?transport=tcp"
            servers.append(ICEServerConfig(
                urls: [turnTCPURL],
                username: "echoelmusic",
                credential: generateTURNCredential()
            ))
        }

        return servers
    }

    private func generateTURNCredential() -> String {
        // In production: Generate time-limited HMAC credential
        let timestamp = Int(Date().timeIntervalSince1970) + 86400 // 24 hour validity
        return "\(timestamp):temp_credential"
    }
}

struct ICEServerConfig {
    let urls: [String]
    var username: String? = nil
    var credential: String? = nil
}

// MARK: - Audio Stem Sharing System

/// Real-time stem sharing for collaborative music production
/// Migrated to @Observable for better performance (Swift 5.9+)
@MainActor
@Observable
final class AudioStemSharing {

    // MARK: - Observable State

    var availableStems: [AudioStem] = []
    var activeDownloads: [UUID: Float] = [:] // stemID: progress
    var sharedStems: [AudioStem] = []
    var networkUsage: NetworkUsage = NetworkUsage()

    // MARK: - Stem Definition

    struct AudioStem: Identifiable, Codable {
        let id: UUID
        var name: String
        var type: StemType
        var format: AudioFormat
        var sampleRate: Int
        var bitDepth: Int
        var channels: Int
        var durationSeconds: Double
        var fileSizeBytes: Int
        var bpm: Double?
        var key: String?
        var creatorID: UUID
        var creatorName: String
        var isLossless: Bool
        var timestamp: Date

        enum StemType: String, Codable, CaseIterable {
            case drums = "Drums"
            case bass = "Bass"
            case guitar = "Guitar"
            case keys = "Keys/Synth"
            case vocals = "Vocals"
            case strings = "Strings"
            case brass = "Brass"
            case percussion = "Percussion"
            case fx = "FX/Ambience"
            case full = "Full Mix"
            case other = "Other"
        }

        enum AudioFormat: String, Codable {
            case wav = "WAV"
            case aiff = "AIFF"
            case flac = "FLAC"
            case alac = "ALAC"
            case mp3 = "MP3"
            case aac = "AAC"
            case opus = "Opus"

            var isLossless: Bool {
                switch self {
                case .wav, .aiff, .flac, .alac: return true
                default: return false
                }
            }
        }
    }

    struct NetworkUsage {
        var uploadedBytes: Int = 0
        var downloadedBytes: Int = 0
        var uploadSpeed: Int = 0 // bytes/sec
        var downloadSpeed: Int = 0 // bytes/sec
    }

    // MARK: - Stem Sharing Protocol

    enum StemMessage: Codable {
        case announce(stem: AudioStem)
        case request(stemID: UUID)
        case chunk(stemID: UUID, chunkIndex: Int, totalChunks: Int, data: Data)
        case complete(stemID: UUID)
        case cancel(stemID: UUID)
    }

    private let chunkSize = 64 * 1024 // 64KB chunks for smooth streaming

    init() {
        #if DEBUG
        debugLog("🎼", "AudioStemSharing: Initialized")
        #endif
    }

    // MARK: - Sharing Operations

    func shareStem(from url: URL, metadata: AudioStem) async throws {
        var stem = metadata

        // Read file data
        let data = try Data(contentsOf: url)
        stem = AudioStem(
            id: stem.id,
            name: stem.name,
            type: stem.type,
            format: stem.format,
            sampleRate: stem.sampleRate,
            bitDepth: stem.bitDepth,
            channels: stem.channels,
            durationSeconds: stem.durationSeconds,
            fileSizeBytes: data.count,
            bpm: stem.bpm,
            key: stem.key,
            creatorID: stem.creatorID,
            creatorName: stem.creatorName,
            isLossless: stem.format.isLossless,
            timestamp: Date()
        )

        // Announce stem to network
        sharedStems.append(stem)

        #if DEBUG
        debugLog("📤", "Sharing stem: \(stem.name) (\(formatBytes(stem.fileSizeBytes)))")
        #endif
    }

    func requestStem(_ stemID: UUID) async throws -> URL {
        guard let stem = availableStems.first(where: { $0.id == stemID }) else {
            throw StemError.stemNotFound
        }

        activeDownloads[stemID] = 0.0

        // Simulate download with progress
        let totalChunks = (stem.fileSizeBytes + chunkSize - 1) / chunkSize
        var receivedData = Data()

        for chunk in 0..<totalChunks {
            // In production: Receive actual chunk from peer
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms per chunk

            let progress = Float(chunk + 1) / Float(totalChunks)
            activeDownloads[stemID] = progress

            // Simulate chunk data
            let chunkData = Data(repeating: 0, count: min(chunkSize, stem.fileSizeBytes - chunk * chunkSize))
            receivedData.append(chunkData)
        }

        activeDownloads.removeValue(forKey: stemID)

        // Save to temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(stemID).\(stem.format.rawValue.lowercased())")
        try receivedData.write(to: tempURL)

        #if DEBUG
        debugLog("📥", "Downloaded stem: \(stem.name)")
        #endif
        return tempURL
    }

    func cancelDownload(_ stemID: UUID) {
        activeDownloads.removeValue(forKey: stemID)
        #if DEBUG
        debugLog("❌", "Cancelled download: \(stemID)")
        #endif
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

enum StemError: Error {
    case stemNotFound
    case downloadFailed
    case invalidFormat
}

// MARK: - Jam Session Matchmaking

/// Global matchmaking for collaborative jam sessions
/// Migrated to @Observable for better performance (Swift 5.9+)
@MainActor
@Observable
final class JamSessionMatchmaking {

    // MARK: - Observable State

    var isSearching: Bool = false
    var searchProgress: Float = 0.0
    var foundSessions: [JamSession] = []
    var currentSession: JamSession?
    var matchedMusicians: [Musician] = []

    // MARK: - Session Definition

    struct JamSession: Identifiable, Codable {
        let id: UUID
        var name: String
        var genre: Genre
        var bpm: Int
        var key: MusicalKey
        var skill: SkillLevel
        var maxParticipants: Int
        var currentParticipants: Int
        var hostID: UUID
        var hostName: String
        var region: String
        var languages: [String]
        var instruments: [Instrument]
        var isOpen: Bool
        var createdAt: Date

        var isFull: Bool { currentParticipants >= maxParticipants }
    }

    struct Musician: Identifiable, Codable {
        let id: UUID
        var name: String
        var instrument: Instrument
        var skill: SkillLevel
        var genres: [Genre]
        var languages: [String]
        var region: String
        var latencyMs: Int
        var rating: Float // 0-5 stars
        var sessionsPlayed: Int
        var isOnline: Bool
    }

    enum Genre: String, Codable, CaseIterable, Identifiable {
        case rock = "Rock"
        case jazz = "Jazz"
        case blues = "Blues"
        case electronic = "Electronic"
        case hiphop = "Hip-Hop"
        case classical = "Classical"
        case folk = "Folk"
        case world = "World"
        case metal = "Metal"
        case pop = "Pop"
        case rnb = "R&B"
        case country = "Country"
        case reggae = "Reggae"
        case latin = "Latin"
        case afrobeat = "Afrobeat"
        case indian = "Indian Classical"
        case ambient = "Ambient"
        case experimental = "Experimental"
        case any = "Any Genre"

        var id: String { rawValue }
    }

    enum SkillLevel: String, Codable, CaseIterable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
        case professional = "Professional"
        case any = "Any Level"

        var matchRange: ClosedRange<Int> {
            switch self {
            case .beginner: return 0...1
            case .intermediate: return 1...2
            case .advanced: return 2...3
            case .professional: return 3...4
            case .any: return 0...4
            }
        }

        var numericValue: Int {
            switch self {
            case .beginner: return 0
            case .intermediate: return 1
            case .advanced: return 2
            case .professional: return 3
            case .any: return 2
            }
        }
    }

    enum Instrument: String, Codable, CaseIterable, Identifiable {
        case guitar = "Guitar"
        case bass = "Bass"
        case drums = "Drums"
        case piano = "Piano"
        case keyboard = "Keyboard/Synth"
        case vocals = "Vocals"
        case violin = "Violin"
        case cello = "Cello"
        case saxophone = "Saxophone"
        case trumpet = "Trumpet"
        case flute = "Flute"
        case dj = "DJ/Turntables"
        case producer = "Producer"
        case percussion = "Percussion"
        case harmonica = "Harmonica"
        case ukulele = "Ukulele"
        case banjo = "Banjo"
        case sitar = "Sitar"
        case tabla = "Tabla"
        case kora = "Kora"
        case mbira = "Mbira"
        case other = "Other"

        var id: String { rawValue }
    }

    struct MusicalKey: Codable, Hashable {
        let root: String
        let mode: Mode

        enum Mode: String, Codable {
            case major = "Major"
            case minor = "Minor"
            case dorian = "Dorian"
            case mixolydian = "Mixolydian"
            case any = "Any"
        }

        var description: String { "\(root) \(mode.rawValue)" }

        static let common: [MusicalKey] = [
            MusicalKey(root: "C", mode: .major),
            MusicalKey(root: "G", mode: .major),
            MusicalKey(root: "D", mode: .major),
            MusicalKey(root: "A", mode: .minor),
            MusicalKey(root: "E", mode: .minor),
            MusicalKey(root: "Any", mode: .any),
        ]
    }

    // MARK: - Search Preferences

    struct MatchPreferences {
        var genres: [Genre] = [.any]
        var instruments: [Instrument] = []
        var skill: SkillLevel = .any
        var bpmRange: ClosedRange<Int> = 60...180
        var maxLatency: Int = 100 // ms
        var languages: [String] = []
        var preferSameRegion: Bool = true
    }

    private var preferences = MatchPreferences()

    init() {
        #if DEBUG
        debugLog("🎭", "JamSessionMatchmaking: Initialized")
        #endif
    }

    // MARK: - Session Discovery

    func searchSessions(preferences: MatchPreferences) async throws -> [JamSession] {
        self.preferences = preferences
        isSearching = true
        searchProgress = 0.0

        // Simulate search with progress
        for i in 1...10 {
            try await Task.sleep(nanoseconds: 200_000_000)
            searchProgress = Float(i) / 10.0
        }

        // Generate sample sessions matching preferences
        foundSessions = generateMatchingSessions(count: 8)

        isSearching = false
        #if DEBUG
        debugLog("🔍", "Found \(foundSessions.count) matching sessions")
        #endif
        return foundSessions
    }

    private func generateMatchingSessions(count: Int) -> [JamSession] {
        var sessions: [JamSession] = []

        let regions = ["US-East", "Europe-West", "Asia-Pacific", "South America", "Africa"]
        let hosts = ["JazzCat42", "RockNRoller", "BeatMaster", "MelodyMaker", "GrooveLord", "SynthWizard", "DrumKing", "BassQueen"]

        for i in 0..<count {
            let genre = preferences.genres.contains(.any) ? Genre.allCases.randomElement()! : preferences.genres.randomElement()!
            let skill = preferences.skill == .any ? SkillLevel.allCases.filter { $0 != .any }.randomElement()! : preferences.skill

            sessions.append(JamSession(
                id: UUID(),
                name: "\(hosts[i % hosts.count])'s \(genre.rawValue) Jam",
                genre: genre,
                bpm: Int.random(in: preferences.bpmRange),
                key: MusicalKey.common.randomElement()!,
                skill: skill,
                maxParticipants: Int.random(in: 2...8),
                currentParticipants: Int.random(in: 1...4),
                hostID: UUID(),
                hostName: hosts[i % hosts.count],
                region: regions.randomElement()!,
                languages: ["en"],
                instruments: [.guitar, .bass, .drums, .keyboard].shuffled().prefix(3).map { $0 },
                isOpen: true,
                createdAt: Date().addingTimeInterval(-Double.random(in: 0...3600))
            ))
        }

        return sessions.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Quick Match

    func quickMatch(instrument: Instrument, genre: Genre, skill: SkillLevel) async throws -> JamSession? {
        let prefs = MatchPreferences(
            genres: [genre],
            instruments: [instrument],
            skill: skill
        )

        let sessions = try await searchSessions(preferences: prefs)

        // Find best match (not full, lowest latency region)
        return sessions.first { !$0.isFull }
    }

    // MARK: - Session Creation

    func createSession(name: String, genre: Genre, bpm: Int, key: MusicalKey, skill: SkillLevel, maxParticipants: Int) async throws -> JamSession {
        let session = JamSession(
            id: UUID(),
            name: name,
            genre: genre,
            bpm: bpm,
            key: key,
            skill: skill,
            maxParticipants: maxParticipants,
            currentParticipants: 1,
            hostID: UUID(),
            hostName: "You",
            region: "Auto-detected",
            languages: [],
            instruments: [],
            isOpen: true,
            createdAt: Date()
        )

        currentSession = session
        #if DEBUG
        debugLog("🎵", "Created session: \(session.name)")
        #endif
        return session
    }

    // MARK: - Session Joining

    func joinSession(_ sessionID: UUID) async throws {
        guard let session = foundSessions.first(where: { $0.id == sessionID }) else {
            throw MatchmakingError.sessionNotFound
        }

        guard !session.isFull else {
            throw MatchmakingError.sessionFull
        }

        currentSession = session
        #if DEBUG
        debugLog("🤝", "Joined session: \(session.name)")
        #endif
    }

    func leaveSession() {
        currentSession = nil
        #if DEBUG
        debugLog("👋", "Left session")
        #endif
    }
}

enum MatchmakingError: Error {
    case sessionNotFound
    case sessionFull
    case connectionFailed
}

// MARK: - Collaborative Session Coordinator

/// Coordinates all collaboration components for global jam sessions
/// Migrated to @Observable for better performance (Swift 5.9+)
@MainActor
@Observable
final class GlobalCollaborationCoordinator {

    // MARK: - Sub-components

    let turnInfrastructure = GlobalTURNInfrastructure()
    let stemSharing = AudioStemSharing()
    let matchmaking = JamSessionMatchmaking()

    // MARK: - Observable State

    var isConnected: Bool = false
    var sessionState: SessionState = .idle
    var participants: [JamSessionMatchmaking.Musician] = []
    var networkQuality: NetworkQuality = .unknown

    enum SessionState: String {
        case idle = "Idle"
        case searching = "Searching"
        case connecting = "Connecting"
        case inSession = "In Session"
        case disconnecting = "Disconnecting"
    }

    enum NetworkQuality: String {
        case unknown = "Unknown"
        case excellent = "Excellent (<30ms)"
        case good = "Good (30-60ms)"
        case fair = "Fair (60-100ms)"
        case poor = "Poor (>100ms)"
    }

    init() {
        #if DEBUG
        debugLog("🌍", "GlobalCollaborationCoordinator: Initialized")
        #endif
    }

    // MARK: - Quick Start Flow

    func quickJam(instrument: JamSessionMatchmaking.Instrument, genre: JamSessionMatchmaking.Genre) async throws {
        sessionState = .searching

        // 1. Detect NAT type
        let natType = await turnInfrastructure.detectNATType()
        #if DEBUG
        debugLog("📡", "NAT Type: \(natType.rawValue)")
        #endif

        // 2. Select optimal TURN server
        guard let server = await turnInfrastructure.selectOptimalServer(forLatitude: 0, forLongitude: 0) else {
            throw CollaborationError.noServersAvailable
        }
        #if DEBUG
        debugLog("🌐", "Selected server: \(server.region)")
        #endif

        // 3. Quick match to session
        sessionState = .connecting
        guard let session = try await matchmaking.quickMatch(
            instrument: instrument,
            genre: genre,
            skill: .any
        ) else {
            // No session found, create one
            _ = try await matchmaking.createSession(
                name: "\(genre.rawValue) Jam",
                genre: genre,
                bpm: 120,
                key: JamSessionMatchmaking.MusicalKey(root: "C", mode: .major),
                skill: .intermediate,
                maxParticipants: 4
            )
            sessionState = .inSession
            isConnected = true
            return
        }

        // 4. Join session
        try await matchmaking.joinSession(session.id)
        sessionState = .inSession
        isConnected = true

        #if DEBUG
        debugLog("🎵", "Quick jam started in: \(session.name)")
        #endif
    }

    // MARK: - Session Control

    func disconnect() {
        sessionState = .disconnecting
        matchmaking.leaveSession()
        participants.removeAll()
        sessionState = .idle
        isConnected = false
        #if DEBUG
        debugLog("👋", "Disconnected from session")
        #endif
    }

    // MARK: - Stem Operations

    func shareStemToSession(url: URL, type: AudioStemSharing.AudioStem.StemType) async throws {
        let metadata = AudioStemSharing.AudioStem(
            id: UUID(),
            name: url.lastPathComponent,
            type: type,
            format: .wav,
            sampleRate: 48000,
            bitDepth: 24,
            channels: 2,
            durationSeconds: 0,
            fileSizeBytes: 0,
            bpm: nil,
            key: nil,
            creatorID: UUID(),
            creatorName: "You",
            isLossless: true,
            timestamp: Date()
        )

        try await stemSharing.shareStem(from: url, metadata: metadata)
    }

    // MARK: - Network Quality

    func updateNetworkQuality() {
        let latency = turnInfrastructure.connectionLatency

        if latency < 30 {
            networkQuality = .excellent
        } else if latency < 60 {
            networkQuality = .good
        } else if latency < 100 {
            networkQuality = .fair
        } else {
            networkQuality = .poor
        }
    }
}

enum CollaborationError: Error {
    case noServersAvailable
    case connectionFailed
    case sessionFull
}

// MARK: - Regional Latency Optimizer

/// Optimizes connections between musicians in different regions
class RegionalLatencyOptimizer {

    struct RegionPair: Hashable {
        let regionA: String
        let regionB: String
    }

    // Expected latencies between major regions (one-way, ms)
    static let regionLatencies: [RegionPair: Int] = [
        RegionPair(regionA: "US-East", regionB: "US-West"): 35,
        RegionPair(regionA: "US-East", regionB: "Europe-West"): 40,
        RegionPair(regionA: "US-West", regionB: "Asia-Pacific"): 70,
        RegionPair(regionA: "Europe-West", regionB: "Asia-Pacific"): 100,
        RegionPair(regionA: "US-East", regionB: "South America"): 60,
        RegionPair(regionA: "Europe-West", regionB: "Africa"): 50,
        RegionPair(regionA: "Asia-Pacific", regionB: "Australia"): 80,
    ]

    /// Check if two regions can have a reasonable jam session (<100ms RTT)
    static func canJamTogether(regionA: String, regionB: String) -> Bool {
        if regionA == regionB { return true }

        let pair = RegionPair(regionA: regionA, regionB: regionB)
        let reversePair = RegionPair(regionA: regionB, regionB: regionA)

        if let latency = regionLatencies[pair] ?? regionLatencies[reversePair] {
            return latency * 2 < 100 // RTT < 100ms
        }

        return false // Unknown region pair, be conservative
    }

    /// Suggest optimal relay server for cross-region session
    static func suggestRelayServer(forParticipants regions: [String]) -> String {
        // Find most central location
        let regionCounts = Dictionary(grouping: regions, by: { $0 }).mapValues { $0.count }
        if let dominant = regionCounts.max(by: { $0.value < $1.value }) {
            return dominant.key
        }
        return "US-East" // Default
    }
}

// MARK: - Backward Compatibility

extension GlobalTURNInfrastructure: ObservableObject { }
extension AudioStemSharing: ObservableObject { }
extension JamSessionMatchmaking: ObservableObject { }
extension GlobalCollaborationCoordinator: ObservableObject { }
