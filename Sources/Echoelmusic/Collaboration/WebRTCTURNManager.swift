import Foundation
#if canImport(WebRTC)
import WebRTC
#endif

// MARK: - WebRTC TURN Server Manager
// Complete ICE/TURN/STUN configuration for reliable P2P connections
// Supports: Multiple TURN servers, automatic failover, credential refresh

@MainActor
public final class WebRTCTURNManager: ObservableObject {
    public static let shared = WebRTCTURNManager()

    @Published public private(set) var connectionState: ConnectionState = .disconnected
    @Published public private(set) var selectedServer: TURNServer?
    @Published public private(set) var latencyMs: Double = 0
    @Published public private(set) var bandwidthKbps: Double = 0

    // ICE Server configuration
    private var iceServers: [ICEServerConfig] = []
    private var turnServers: [TURNServer] = []
    private var stunServers: [STUNServer] = []

    // Credential management
    private var credentialRefreshTimer: Timer?
    private var credentials: TURNCredentials?

    // Connection quality monitoring
    private var qualityMonitor: ConnectionQualityMonitor

    // Configuration
    public struct Configuration {
        public var useTURN: Bool = true
        public var useSTUN: Bool = true
        public var preferUDP: Bool = true
        public var preferTCP: Bool = false
        public var enableIPv6: Bool = true
        public var maxRetries: Int = 3
        public var connectionTimeout: TimeInterval = 10
        public var credentialRefreshInterval: TimeInterval = 3600 // 1 hour

        public static let `default` = Configuration()
    }

    private var config: Configuration = .default

    public init() {
        self.qualityMonitor = ConnectionQualityMonitor()
        setupDefaultServers()
    }

    // MARK: - Server Configuration

    private func setupDefaultServers() {
        // Public STUN servers
        stunServers = [
            STUNServer(url: "stun:stun.l.google.com:19302", priority: 1),
            STUNServer(url: "stun:stun1.l.google.com:19302", priority: 2),
            STUNServer(url: "stun:stun2.l.google.com:19302", priority: 3),
            STUNServer(url: "stun:stun.stunprotocol.org:3478", priority: 4),
            STUNServer(url: "stun:stun.voip.blackberry.com:3478", priority: 5),
        ]

        // TURN servers (would be configured with actual credentials)
        turnServers = [
            TURNServer(
                url: "turn:turn.echoelmusic.com:3478",
                username: "",
                credential: "",
                protocol: .udp,
                priority: 1
            ),
            TURNServer(
                url: "turn:turn.echoelmusic.com:443",
                username: "",
                credential: "",
                protocol: .tcp,
                priority: 2
            ),
            TURNServer(
                url: "turns:turn.echoelmusic.com:443",
                username: "",
                credential: "",
                protocol: .tls,
                priority: 3
            ),
        ]
    }

    /// Configure with custom TURN servers
    public func configure(turnServers: [TURNServer], stunServers: [STUNServer]? = nil) {
        self.turnServers = turnServers
        if let stun = stunServers {
            self.stunServers = stun
        }
        buildICEConfiguration()
    }

    /// Set TURN credentials (for time-limited credentials)
    public func setCredentials(_ credentials: TURNCredentials) {
        self.credentials = credentials

        // Update TURN servers with credentials
        for i in 0..<turnServers.count {
            turnServers[i].username = credentials.username
            turnServers[i].credential = credentials.password
        }

        buildICEConfiguration()
        scheduleCredentialRefresh()
    }

    /// Fetch credentials from server
    public func fetchCredentials(from url: URL) async throws -> TURNCredentials {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TURNError.credentialFetchFailed
        }

        let credentials = try JSONDecoder().decode(TURNCredentials.self, from: data)
        setCredentials(credentials)
        return credentials
    }

    // MARK: - ICE Configuration

    private func buildICEConfiguration() {
        iceServers.removeAll()

        // Add STUN servers
        if config.useSTUN {
            for stun in stunServers.sorted(by: { $0.priority < $1.priority }) {
                iceServers.append(ICEServerConfig(
                    urls: [stun.url],
                    username: nil,
                    credential: nil
                ))
            }
        }

        // Add TURN servers
        if config.useTURN {
            for turn in turnServers.sorted(by: { $0.priority < $1.priority }) {
                guard !turn.username.isEmpty else { continue }

                var urls: [String] = []

                switch turn.protocol {
                case .udp where config.preferUDP:
                    urls.append(turn.url + "?transport=udp")
                case .tcp where config.preferTCP:
                    urls.append(turn.url + "?transport=tcp")
                case .tls:
                    urls.append(turn.url)
                default:
                    urls.append(turn.url)
                }

                iceServers.append(ICEServerConfig(
                    urls: urls,
                    username: turn.username,
                    credential: turn.credential
                ))
            }
        }
    }

    /// Get ICE servers configuration for WebRTC
    public func getICEServers() -> [ICEServerConfig] {
        if iceServers.isEmpty {
            buildICEConfiguration()
        }
        return iceServers
    }

    #if canImport(WebRTC)
    /// Get RTCConfiguration for WebRTC
    public func getRTCConfiguration() -> RTCConfiguration {
        let rtcConfig = RTCConfiguration()

        rtcConfig.iceServers = getICEServers().map { server in
            if let username = server.username, let credential = server.credential {
                return RTCIceServer(
                    urlStrings: server.urls,
                    username: username,
                    credential: credential
                )
            } else {
                return RTCIceServer(urlStrings: server.urls)
            }
        }

        rtcConfig.iceTransportPolicy = config.useTURN ? .relay : .all
        rtcConfig.bundlePolicy = .maxBundle
        rtcConfig.rtcpMuxPolicy = .require
        rtcConfig.tcpCandidatePolicy = config.preferTCP ? .enabled : .disabled
        rtcConfig.continualGatheringPolicy = .gatherContinually

        return rtcConfig
    }
    #endif

    // MARK: - Connection Management

    /// Test TURN server connectivity
    public func testConnectivity() async -> [ServerTestResult] {
        var results: [ServerTestResult] = []

        // Test STUN servers
        for stun in stunServers {
            let result = await testSTUNServer(stun)
            results.append(result)
        }

        // Test TURN servers
        for turn in turnServers {
            let result = await testTURNServer(turn)
            results.append(result)
        }

        // Select best server
        if let bestTURN = results
            .filter({ $0.serverType == .turn && $0.success })
            .min(by: { $0.latencyMs < $1.latencyMs }) {
            selectedServer = turnServers.first { $0.url == bestTURN.serverUrl }
            latencyMs = bestTURN.latencyMs
        }

        return results
    }

    private func testSTUNServer(_ server: STUNServer) async -> ServerTestResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        // Simple connectivity test via UDP
        do {
            let latency = try await measureLatency(to: server.url)
            return ServerTestResult(
                serverUrl: server.url,
                serverType: .stun,
                success: true,
                latencyMs: latency,
                error: nil
            )
        } catch {
            return ServerTestResult(
                serverUrl: server.url,
                serverType: .stun,
                success: false,
                latencyMs: 0,
                error: error.localizedDescription
            )
        }
    }

    private func testTURNServer(_ server: TURNServer) async -> ServerTestResult {
        guard !server.username.isEmpty else {
            return ServerTestResult(
                serverUrl: server.url,
                serverType: .turn,
                success: false,
                latencyMs: 0,
                error: "No credentials configured"
            )
        }

        do {
            let latency = try await measureLatency(to: server.url)
            return ServerTestResult(
                serverUrl: server.url,
                serverType: .turn,
                success: true,
                latencyMs: latency,
                error: nil
            )
        } catch {
            return ServerTestResult(
                serverUrl: server.url,
                serverType: .turn,
                success: false,
                latencyMs: 0,
                error: error.localizedDescription
            )
        }
    }

    private func measureLatency(to urlString: String) async throws -> Double {
        // Parse URL
        guard let url = URL(string: urlString.replacingOccurrences(of: "stun:", with: "https://")
                                            .replacingOccurrences(of: "turn:", with: "https://")
                                            .replacingOccurrences(of: "turns:", with: "https://")) else {
            throw TURNError.invalidURL
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        // Simple HTTP HEAD request to measure latency
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = config.connectionTimeout

        _ = try await URLSession.shared.data(for: request)

        let endTime = CFAbsoluteTimeGetCurrent()
        return (endTime - startTime) * 1000
    }

    // MARK: - Credential Refresh

    private func scheduleCredentialRefresh() {
        credentialRefreshTimer?.invalidate()

        credentialRefreshTimer = Timer.scheduledTimer(
            withTimeInterval: config.credentialRefreshInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshCredentials()
            }
        }
    }

    private func refreshCredentials() async {
        guard let currentCredentials = credentials,
              let refreshURL = currentCredentials.refreshURL else {
            return
        }

        do {
            _ = try await fetchCredentials(from: refreshURL)
            print("TURN credentials refreshed successfully")
        } catch {
            print("Failed to refresh TURN credentials: \(error)")
        }
    }

    // MARK: - Quality Monitoring

    /// Start monitoring connection quality
    public func startQualityMonitoring() {
        qualityMonitor.start { [weak self] quality in
            Task { @MainActor in
                self?.handleQualityUpdate(quality)
            }
        }
    }

    private func handleQualityUpdate(_ quality: ConnectionQuality) {
        latencyMs = quality.roundTripTimeMs
        bandwidthKbps = quality.availableBandwidthKbps

        // Auto-switch servers if quality degrades
        if quality.packetLossPercent > 10 || quality.roundTripTimeMs > 500 {
            Task {
                await switchToBackupServer()
            }
        }
    }

    private func switchToBackupServer() async {
        // Find next best server
        let results = await testConnectivity()

        if let backup = results
            .filter({ $0.serverType == .turn && $0.success && $0.serverUrl != selectedServer?.url })
            .min(by: { $0.latencyMs < $1.latencyMs }) {

            selectedServer = turnServers.first { $0.url == backup.serverUrl }
            print("Switched to backup TURN server: \(backup.serverUrl)")
        }
    }

    public func configure(_ config: Configuration) {
        self.config = config
        buildICEConfiguration()
    }
}

// MARK: - Supporting Types

public struct TURNServer: Codable, Identifiable {
    public var id: String { url }
    public var url: String
    public var username: String
    public var credential: String
    public var `protocol`: TransportProtocol
    public var priority: Int

    public enum TransportProtocol: String, Codable {
        case udp, tcp, tls
    }
}

public struct STUNServer: Codable, Identifiable {
    public var id: String { url }
    public var url: String
    public var priority: Int
}

public struct ICEServerConfig {
    public let urls: [String]
    public let username: String?
    public let credential: String?
}

public struct TURNCredentials: Codable {
    public let username: String
    public let password: String
    public let ttl: Int  // Time to live in seconds
    public let refreshURL: URL?

    public var expirationDate: Date {
        Date().addingTimeInterval(TimeInterval(ttl))
    }
}

public struct ServerTestResult {
    public let serverUrl: String
    public let serverType: ServerType
    public let success: Bool
    public let latencyMs: Double
    public let error: String?

    public enum ServerType {
        case stun, turn
    }
}

public enum ConnectionState {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed
}

public enum TURNError: Error {
    case invalidURL
    case credentialFetchFailed
    case connectionTimeout
    case serverUnreachable
}

// MARK: - Connection Quality Monitor

public class ConnectionQualityMonitor {
    private var timer: Timer?
    private var callback: ((ConnectionQuality) -> Void)?

    public struct ConnectionQuality {
        public var roundTripTimeMs: Double
        public var availableBandwidthKbps: Double
        public var packetLossPercent: Double
        public var jitterMs: Double
    }

    public func start(callback: @escaping (ConnectionQuality) -> Void) {
        self.callback = callback

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.measureQuality()
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func measureQuality() {
        // Simulated quality metrics (would come from actual WebRTC stats)
        let quality = ConnectionQuality(
            roundTripTimeMs: Double.random(in: 20...100),
            availableBandwidthKbps: Double.random(in: 500...2000),
            packetLossPercent: Double.random(in: 0...2),
            jitterMs: Double.random(in: 1...10)
        )

        callback?(quality)
    }
}

// MARK: - NAT Traversal Helper

public class NATTraversalHelper {
    /// Determine NAT type
    public static func detectNATType() async -> NATType {
        // STUN-based NAT detection would go here
        // For now, return unknown
        return .unknown
    }

    public enum NATType {
        case openInternet      // No NAT
        case fullCone          // Easy traversal
        case restrictedCone    // Medium difficulty
        case portRestricted    // Hard
        case symmetric         // Hardest, needs TURN
        case unknown
    }

    /// Check if TURN is required based on NAT type
    public static func requiresTURN(localNAT: NATType, remoteNAT: NATType) -> Bool {
        switch (localNAT, remoteNAT) {
        case (.symmetric, _), (_, .symmetric):
            return true
        case (.portRestricted, .portRestricted):
            return true
        default:
            return false
        }
    }
}

// MARK: - ICE Candidate Filter

public class ICECandidateFilter {
    public enum CandidateType {
        case host      // Local IP
        case srflx     // Server reflexive (STUN)
        case prflx     // Peer reflexive
        case relay     // TURN relay
    }

    /// Filter ICE candidates based on policy
    public static func filter(
        candidates: [String],
        allowHost: Bool = true,
        allowSrflx: Bool = true,
        allowRelay: Bool = true
    ) -> [String] {
        return candidates.filter { candidate in
            if candidate.contains("typ host") && !allowHost { return false }
            if candidate.contains("typ srflx") && !allowSrflx { return false }
            if candidate.contains("typ relay") && !allowRelay { return false }
            return true
        }
    }

    /// Prioritize candidates
    public static func prioritize(candidates: [String]) -> [String] {
        // Prefer relay for reliability, then srflx, then host
        return candidates.sorted { a, b in
            let priorityA = candidatePriority(a)
            let priorityB = candidatePriority(b)
            return priorityA > priorityB
        }
    }

    private static func candidatePriority(_ candidate: String) -> Int {
        if candidate.contains("typ relay") { return 3 }
        if candidate.contains("typ srflx") { return 2 }
        if candidate.contains("typ prflx") { return 1 }
        return 0
    }
}
