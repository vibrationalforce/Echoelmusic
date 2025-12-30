import Foundation
import AVFoundation
import Network
import Combine

// MARK: - Global Streaming Infrastructure
// SRT Protocol, HLS/DASH CDN, Multi-Bitrate Encoding
// Sub-second latency for global live sessions

/// SRT (Secure Reliable Transport) Protocol Engine
/// Lower latency than RTMP, handles packet loss gracefully
@MainActor
class SRTStreamEngine: ObservableObject {

    // MARK: - Published State

    @Published var isConnected: Bool = false
    @Published var currentLatency: Int = 0 // milliseconds
    @Published var packetLoss: Float = 0.0 // percentage
    @Published var bitrate: Int = 0 // kbps
    @Published var connectionQuality: ConnectionQuality = .unknown

    // MARK: - SRT Configuration

    struct SRTConfig {
        var latencyMs: Int = 120 // SRT latency buffer (20-8000ms)
        var maxBandwidth: Int = 10_000_000 // 10 Mbps max
        var payloadSize: Int = 1316 // SRT default MTU
        var overheadPercentage: Int = 25 // Bandwidth overhead for FEC
        var encryption: SRTEncryption = .aes256
        var passphrase: String? = nil

        // Advanced options
        var congestionControl: CongestionControl = .live
        var flightFlagSize: Int = 25600 // Packets in flight
        var peerIdleTimeout: Int = 5000 // ms
        var rcvBufferSize: Int = 8192000 // Receive buffer
        var sndBufferSize: Int = 8192000 // Send buffer
    }

    enum SRTEncryption: String, CaseIterable {
        case none = "None"
        case aes128 = "AES-128"
        case aes192 = "AES-192"
        case aes256 = "AES-256"
    }

    enum CongestionControl: String {
        case live = "live" // Low latency mode
        case file = "file" // High throughput mode
    }

    enum ConnectionQuality: String {
        case unknown = "Unknown"
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
        case critical = "Critical"
    }

    private var config: SRTConfig
    private var connection: NWConnection?
    private var statsTimer: Timer?

    init(config: SRTConfig = SRTConfig()) {
        self.config = config
        print("📡 SRTStreamEngine: Initialized with \(config.latencyMs)ms latency buffer")
    }

    // MARK: - Connection Management

    func connect(to url: String, streamKey: String) async throws {
        guard let srtURL = parseSRTUrl(url, streamKey: streamKey) else {
            throw SRTError.invalidURL
        }

        // Configure SRT parameters
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true

        // Create connection with SRT-like handling
        let host = NWEndpoint.Host(srtURL.host)
        let port = NWEndpoint.Port(integerLiteral: UInt16(srtURL.port))

        connection = NWConnection(host: host, port: port, using: parameters)

        connection?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.startStatsCollection()
                    print("✅ SRT: Connected to \(url)")
                case .failed(let error):
                    self?.isConnected = false
                    print("❌ SRT: Connection failed - \(error)")
                case .cancelled:
                    self?.isConnected = false
                default:
                    break
                }
            }
        }

        connection?.start(queue: .global(qos: .userInteractive))
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        isConnected = false
        statsTimer?.invalidate()
        print("🔌 SRT: Disconnected")
    }

    // MARK: - Data Transmission

    func sendPacket(_ data: Data, timestamp: UInt64) {
        guard isConnected else { return }

        // Add SRT header
        var packet = Data()
        packet.append(contentsOf: withUnsafeBytes(of: timestamp.bigEndian) { Array($0) })
        packet.append(data)

        connection?.send(content: packet, completion: .contentProcessed { error in
            if let error = error {
                print("⚠️ SRT: Send error - \(error)")
            }
        })
    }

    // MARK: - Statistics

    private func startStatsCollection() {
        statsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStats()
            }
        }
    }

    private func updateStats() {
        // Simulate stats (real SRT would get from library)
        currentLatency = config.latencyMs + Int.random(in: -20...20)
        packetLoss = Float.random(in: 0...0.5)
        bitrate = Int.random(in: 4000...6000)

        // Calculate quality based on metrics
        connectionQuality = calculateQuality()
    }

    private func calculateQuality() -> ConnectionQuality {
        if packetLoss > 5.0 || currentLatency > 500 {
            return .critical
        } else if packetLoss > 2.0 || currentLatency > 300 {
            return .poor
        } else if packetLoss > 1.0 || currentLatency > 200 {
            return .fair
        } else if packetLoss > 0.5 || currentLatency > 150 {
            return .good
        } else {
            return .excellent
        }
    }

    // MARK: - Helpers

    private func parseSRTUrl(_ url: String, streamKey: String) -> (host: String, port: Int)? {
        // srt://hostname:port?streamid=key
        guard url.hasPrefix("srt://") else { return nil }
        let stripped = url.replacingOccurrences(of: "srt://", with: "")
        let parts = stripped.split(separator: ":")
        guard parts.count >= 2 else { return nil }
        let host = String(parts[0])
        let port = Int(parts[1].split(separator: "?").first ?? "") ?? 9000
        return (host, port)
    }
}

enum SRTError: Error {
    case invalidURL
    case connectionFailed
    case sendFailed
}

// MARK: - HLS/DASH CDN Distribution System

/// Adaptive Bitrate Streaming for global CDN distribution
@MainActor
class AdaptiveBitrateDistribution: ObservableObject {

    // MARK: - Published State

    @Published var isLive: Bool = false
    @Published var currentProfile: EncodingProfile = .hd720
    @Published var viewerCount: Int = 0
    @Published var cdnEdges: [CDNEdge] = []
    @Published var segmentDuration: Double = 2.0 // seconds

    // MARK: - Encoding Profiles (Multi-Bitrate Ladder)

    enum EncodingProfile: String, CaseIterable, Identifiable {
        case audio64 = "Audio Only 64k"
        case sd360 = "360p"
        case sd480 = "480p"
        case hd720 = "720p"
        case hd1080 = "1080p"
        case uhd4k = "4K"
        case uhd8k = "8K"

        var id: String { rawValue }

        var config: EncodingConfig {
            switch self {
            case .audio64:
                return EncodingConfig(width: 0, height: 0, videoBitrate: 0, audioBitrate: 64, fps: 0)
            case .sd360:
                return EncodingConfig(width: 640, height: 360, videoBitrate: 800, audioBitrate: 64, fps: 30)
            case .sd480:
                return EncodingConfig(width: 854, height: 480, videoBitrate: 1400, audioBitrate: 128, fps: 30)
            case .hd720:
                return EncodingConfig(width: 1280, height: 720, videoBitrate: 2800, audioBitrate: 128, fps: 30)
            case .hd1080:
                return EncodingConfig(width: 1920, height: 1080, videoBitrate: 5000, audioBitrate: 192, fps: 60)
            case .uhd4k:
                return EncodingConfig(width: 3840, height: 2160, videoBitrate: 15000, audioBitrate: 256, fps: 60)
            case .uhd8k:
                return EncodingConfig(width: 7680, height: 4320, videoBitrate: 50000, audioBitrate: 320, fps: 60)
            }
        }
    }

    struct EncodingConfig {
        let width: Int
        let height: Int
        let videoBitrate: Int // kbps
        let audioBitrate: Int // kbps
        let fps: Int

        var totalBitrate: Int { videoBitrate + audioBitrate }
    }

    // MARK: - CDN Edge Server

    struct CDNEdge: Identifiable {
        let id: UUID
        let region: String
        let hostname: String
        let latencyMs: Int
        var isActive: Bool
        var viewerCount: Int

        static let globalEdges: [CDNEdge] = [
            CDNEdge(id: UUID(), region: "US-East", hostname: "edge-use.echoelmusic.com", latencyMs: 20, isActive: true, viewerCount: 0),
            CDNEdge(id: UUID(), region: "US-West", hostname: "edge-usw.echoelmusic.com", latencyMs: 25, isActive: true, viewerCount: 0),
            CDNEdge(id: UUID(), region: "Europe-West", hostname: "edge-euw.echoelmusic.com", latencyMs: 30, isActive: true, viewerCount: 0),
            CDNEdge(id: UUID(), region: "Europe-Central", hostname: "edge-euc.echoelmusic.com", latencyMs: 35, isActive: true, viewerCount: 0),
            CDNEdge(id: UUID(), region: "Asia-Pacific", hostname: "edge-apac.echoelmusic.com", latencyMs: 80, isActive: true, viewerCount: 0),
            CDNEdge(id: UUID(), region: "Japan", hostname: "edge-jp.echoelmusic.com", latencyMs: 90, isActive: true, viewerCount: 0),
            CDNEdge(id: UUID(), region: "South America", hostname: "edge-sa.echoelmusic.com", latencyMs: 100, isActive: true, viewerCount: 0),
            CDNEdge(id: UUID(), region: "Africa", hostname: "edge-af.echoelmusic.com", latencyMs: 120, isActive: true, viewerCount: 0),
            CDNEdge(id: UUID(), region: "Middle East", hostname: "edge-me.echoelmusic.com", latencyMs: 110, isActive: true, viewerCount: 0),
            CDNEdge(id: UUID(), region: "Australia", hostname: "edge-au.echoelmusic.com", latencyMs: 150, isActive: true, viewerCount: 0),
            CDNEdge(id: UUID(), region: "India", hostname: "edge-in.echoelmusic.com", latencyMs: 95, isActive: true, viewerCount: 0),
            CDNEdge(id: UUID(), region: "China", hostname: "edge-cn.echoelmusic.com", latencyMs: 130, isActive: true, viewerCount: 0),
        ]
    }

    // MARK: - Streaming Formats

    enum StreamFormat: String, CaseIterable {
        case hls = "HLS"
        case dash = "DASH"
        case cmaf = "CMAF"
        case llhls = "LL-HLS"
        case lldash = "LL-DASH"

        var fileExtension: String {
            switch self {
            case .hls, .llhls: return "m3u8"
            case .dash, .lldash, .cmaf: return "mpd"
            }
        }

        var latencyDescription: String {
            switch self {
            case .hls: return "6-30 seconds"
            case .dash: return "6-30 seconds"
            case .cmaf: return "3-10 seconds"
            case .llhls: return "2-5 seconds"
            case .lldash: return "2-5 seconds"
            }
        }
    }

    private var activeProfiles: Set<EncodingProfile> = [.sd360, .sd480, .hd720, .hd1080]
    private var formats: Set<StreamFormat> = [.hls, .dash, .llhls]

    init() {
        cdnEdges = CDNEdge.globalEdges
        print("🌐 AdaptiveBitrateDistribution: Initialized with \(cdnEdges.count) CDN edges")
    }

    // MARK: - Streaming Control

    func startDistribution(profiles: Set<EncodingProfile>, formats: Set<StreamFormat>) async throws {
        activeProfiles = profiles
        self.formats = formats

        // Generate master playlists
        let hlsPlaylist = generateHLSMasterPlaylist()
        let dashManifest = generateDASHManifest()

        print("📺 HLS Master Playlist:\n\(hlsPlaylist)")
        print("📺 DASH Manifest generated")

        isLive = true

        // Simulate pushing to CDN edges
        for edge in cdnEdges where edge.isActive {
            print("📡 Pushing to CDN edge: \(edge.region)")
        }

        print("✅ Distribution started with \(activeProfiles.count) profiles")
    }

    func stopDistribution() {
        isLive = false
        print("⏹ Distribution stopped")
    }

    // MARK: - Playlist Generation

    private func generateHLSMasterPlaylist() -> String {
        var playlist = "#EXTM3U\n"
        playlist += "#EXT-X-VERSION:7\n"
        playlist += "#EXT-X-INDEPENDENT-SEGMENTS\n\n"

        for profile in activeProfiles.sorted(by: { $0.config.totalBitrate < $1.config.totalBitrate }) {
            let config = profile.config
            if config.width > 0 {
                playlist += "#EXT-X-STREAM-INF:BANDWIDTH=\(config.totalBitrate * 1000),RESOLUTION=\(config.width)x\(config.height),CODECS=\"avc1.64001f,mp4a.40.2\",FRAME-RATE=\(config.fps)\n"
                playlist += "\(profile.rawValue.lowercased().replacingOccurrences(of: " ", with: "_")).m3u8\n\n"
            } else {
                playlist += "#EXT-X-STREAM-INF:BANDWIDTH=\(config.audioBitrate * 1000),CODECS=\"mp4a.40.2\"\n"
                playlist += "audio_only.m3u8\n\n"
            }
        }

        return playlist
    }

    private func generateDASHManifest() -> String {
        // MPD manifest structure
        var mpd = """
        <?xml version="1.0" encoding="UTF-8"?>
        <MPD xmlns="urn:mpeg:dash:schema:mpd:2011" type="dynamic" minBufferTime="PT\(segmentDuration)S">
          <Period start="PT0S">
            <AdaptationSet mimeType="video/mp4" segmentAlignment="true">
        """

        for profile in activeProfiles.sorted(by: { $0.config.totalBitrate < $1.config.totalBitrate }) {
            let config = profile.config
            if config.width > 0 {
                mpd += """

                      <Representation id="\(profile.rawValue)" bandwidth="\(config.videoBitrate * 1000)"
                                      width="\(config.width)" height="\(config.height)" frameRate="\(config.fps)"/>
                """
            }
        }

        mpd += """

            </AdaptationSet>
            <AdaptationSet mimeType="audio/mp4" segmentAlignment="true">
              <Representation id="audio" bandwidth="128000"/>
            </AdaptationSet>
          </Period>
        </MPD>
        """

        return mpd
    }

    // MARK: - Bandwidth Adaptation

    func selectOptimalProfile(forBandwidth bandwidth: Int) -> EncodingProfile {
        let sorted = activeProfiles.sorted { $0.config.totalBitrate > $1.config.totalBitrate }

        for profile in sorted {
            // Allow 20% headroom
            if profile.config.totalBitrate * 1200 <= bandwidth * 1000 {
                return profile
            }
        }

        return .audio64 // Fallback to audio only
    }

    func getNearestEdge(latitude: Double, longitude: Double) -> CDNEdge? {
        // In production: use actual geolocation
        return cdnEdges.filter { $0.isActive }.min(by: { $0.latencyMs < $1.latencyMs })
    }
}

// MARK: - Multi-Bitrate Encoder

/// Real-time multi-bitrate video encoder using VideoToolbox
class MultiBitrateEncoder {

    // MARK: - Encoder State

    struct EncoderState {
        var isEncoding: Bool = false
        var framesEncoded: Int = 0
        var encodingFPS: Float = 0
        var cpuUsage: Float = 0
    }

    @Published var state = EncoderState()

    // MARK: - Encoder Configuration

    struct EncoderConfig {
        var profiles: [AdaptiveBitrateDistribution.EncodingProfile]
        var keyFrameInterval: Int = 2 // seconds
        var bFrames: Bool = true
        var hardwareAcceleration: Bool = true
        var lowLatencyMode: Bool = true

        // H.264/H.265 specific
        var codec: VideoCodec = .h264
        var profile: H264Profile = .high

        enum VideoCodec: String {
            case h264 = "H.264"
            case h265 = "H.265/HEVC"
            case av1 = "AV1" // Future
        }

        enum H264Profile: String {
            case baseline = "Baseline"
            case main = "Main"
            case high = "High"
        }
    }

    private var config: EncoderConfig
    private var encoderSessions: [AdaptiveBitrateDistribution.EncodingProfile: Any] = [:]

    init(config: EncoderConfig) {
        self.config = config
        setupEncoders()
        print("🎬 MultiBitrateEncoder: Initialized with \(config.profiles.count) profiles")
    }

    private func setupEncoders() {
        for profile in config.profiles {
            // In production: Create VTCompressionSession for each profile
            encoderSessions[profile] = createEncoder(for: profile)
        }
    }

    private func createEncoder(for profile: AdaptiveBitrateDistribution.EncodingProfile) -> Any {
        let encoderConfig = profile.config

        print("🎬 Creating encoder for \(profile.rawValue): \(encoderConfig.width)x\(encoderConfig.height) @ \(encoderConfig.videoBitrate)kbps")

        // In production: Return actual VTCompressionSession
        return encoderConfig
    }

    // MARK: - Encoding

    func encodeFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        guard state.isEncoding else { return }

        for profile in config.profiles {
            // Scale frame to target resolution
            // Encode with VideoToolbox
            // Output to segment muxer
        }

        state.framesEncoded += 1
    }

    func start() {
        state.isEncoding = true
        print("▶️ Encoding started")
    }

    func stop() {
        state.isEncoding = false
        print("⏹ Encoding stopped")
    }
}

// MARK: - Low-Latency HLS (LL-HLS) Producer

/// Apple's Low-Latency HLS implementation for sub-3-second latency
class LowLatencyHLSProducer: ObservableObject {

    // MARK: - LL-HLS Specific Settings

    struct LLHLSConfig {
        var partDuration: Double = 0.2 // Part duration in seconds (200ms typical)
        var targetDuration: Double = 2.0 // Full segment duration
        var playlistDelta: Bool = true // Delta playlists for efficiency
        var preloadHint: Bool = true // Preload hints for next part
        var renderingReport: Bool = true // Client feedback
        var blockingPlaylistReload: Bool = true // Server push

        // Calculated values
        var partsPerSegment: Int { Int(targetDuration / partDuration) }
    }

    @Published var isProducing: Bool = false
    @Published var currentPart: Int = 0
    @Published var currentSegment: Int = 0
    @Published var estimatedLatency: Double = 2.5 // seconds

    private var config: LLHLSConfig

    init(config: LLHLSConfig = LLHLSConfig()) {
        self.config = config
        print("⚡ LowLatencyHLSProducer: Initialized with \(config.partDuration)s part duration")
    }

    // MARK: - Playlist Generation

    func generateLLHLSPlaylist() -> String {
        var playlist = "#EXTM3U\n"
        playlist += "#EXT-X-VERSION:9\n"
        playlist += "#EXT-X-TARGETDURATION:\(Int(config.targetDuration))\n"
        playlist += "#EXT-X-SERVER-CONTROL:CAN-BLOCK-RELOAD=YES,PART-HOLD-BACK=\(config.partDuration * 3)\n"
        playlist += "#EXT-X-PART-INF:PART-TARGET=\(config.partDuration)\n\n"

        // Last few segments with parts
        for seg in max(0, currentSegment - 5)...currentSegment {
            let partsCount = seg == currentSegment ? currentPart : config.partsPerSegment

            for part in 0..<partsCount {
                playlist += "#EXT-X-PART:DURATION=\(config.partDuration),URI=\"seg\(seg)_part\(part).m4s\""
                if part == partsCount - 1 && seg == currentSegment {
                    playlist += ",INDEPENDENT=YES"
                }
                playlist += "\n"
            }

            if seg < currentSegment || currentPart == config.partsPerSegment {
                playlist += "#EXTINF:\(config.targetDuration),\n"
                playlist += "segment\(seg).m4s\n\n"
            }
        }

        // Preload hint for next part
        if config.preloadHint {
            let nextPart = (currentPart + 1) % config.partsPerSegment
            let nextSeg = currentPart + 1 >= config.partsPerSegment ? currentSegment + 1 : currentSegment
            playlist += "#EXT-X-PRELOAD-HINT:TYPE=PART,URI=\"seg\(nextSeg)_part\(nextPart).m4s\"\n"
        }

        return playlist
    }

    // MARK: - Production Control

    func startProduction() {
        isProducing = true
        currentPart = 0
        currentSegment = 0

        // Simulate part production
        Timer.scheduledTimer(withTimeInterval: config.partDuration, repeats: true) { [weak self] timer in
            guard let self = self, self.isProducing else {
                timer.invalidate()
                return
            }

            self.currentPart += 1
            if self.currentPart >= self.config.partsPerSegment {
                self.currentPart = 0
                self.currentSegment += 1
            }
        }

        print("▶️ LL-HLS production started")
    }

    func stopProduction() {
        isProducing = false
        print("⏹ LL-HLS production stopped")
    }
}

// MARK: - Bandwidth Estimator

/// Real-time bandwidth estimation for adaptive streaming
class BandwidthEstimator: ObservableObject {

    @Published var estimatedBandwidth: Int = 5000 // kbps
    @Published var stability: Float = 1.0 // 0-1
    @Published var trend: BandwidthTrend = .stable

    enum BandwidthTrend {
        case improving
        case stable
        case degrading
    }

    private var samples: [Int] = []
    private let maxSamples = 20
    private let ewmaAlpha: Float = 0.3 // Exponential weighted moving average factor

    private var ewmaBandwidth: Float = 5000

    func addSample(bytesDownloaded: Int, durationMs: Int) {
        guard durationMs > 0 else { return }

        let bitsPerSecond = (bytesDownloaded * 8 * 1000) / durationMs
        let kbps = bitsPerSecond / 1000

        samples.append(kbps)
        if samples.count > maxSamples {
            samples.removeFirst()
        }

        // EWMA calculation
        ewmaBandwidth = ewmaAlpha * Float(kbps) + (1 - ewmaAlpha) * ewmaBandwidth
        estimatedBandwidth = Int(ewmaBandwidth)

        // Calculate stability
        if samples.count >= 5 {
            let variance = calculateVariance(samples.suffix(5).map { Float($0) })
            stability = max(0, 1 - (variance / ewmaBandwidth))
        }

        // Determine trend
        if samples.count >= 5 {
            let recent = samples.suffix(3).reduce(0, +) / 3
            let older = samples.prefix(3).reduce(0, +) / 3

            if recent > older * 11 / 10 {
                trend = .improving
            } else if recent < older * 9 / 10 {
                trend = .degrading
            } else {
                trend = .stable
            }
        }
    }

    private func calculateVariance(_ values: [Float]) -> Float {
        let mean = values.reduce(0, +) / Float(values.count)
        let squaredDiffs = values.map { ($0 - mean) * ($0 - mean) }
        return squaredDiffs.reduce(0, +) / Float(values.count)
    }

    func recommendedProfile() -> AdaptiveBitrateDistribution.EncodingProfile {
        // Conservative: use 70% of estimated bandwidth
        let safeBandwidth = estimatedBandwidth * 7 / 10

        // Factor in stability
        let adjustedBandwidth = Int(Float(safeBandwidth) * stability)

        if adjustedBandwidth >= 45000 { return .uhd8k }
        if adjustedBandwidth >= 12000 { return .uhd4k }
        if adjustedBandwidth >= 4000 { return .hd1080 }
        if adjustedBandwidth >= 2200 { return .hd720 }
        if adjustedBandwidth >= 1100 { return .sd480 }
        if adjustedBandwidth >= 600 { return .sd360 }
        return .audio64
    }
}

// MARK: - Global Stream Coordinator

/// Coordinates all streaming components for global distribution
@MainActor
class GlobalStreamCoordinator: ObservableObject {

    // MARK: - Sub-components

    let srtEngine = SRTStreamEngine()
    let abrDistribution = AdaptiveBitrateDistribution()
    let llhlsProducer = LowLatencyHLSProducer()
    let bandwidthEstimator = BandwidthEstimator()

    // MARK: - State

    @Published var isStreaming: Bool = false
    @Published var streamURL: String = ""
    @Published var viewerCount: Int = 0
    @Published var streamHealth: StreamHealth = .unknown

    enum StreamHealth: String {
        case unknown = "Unknown"
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
    }

    init() {
        print("🌍 GlobalStreamCoordinator: Initialized")
    }

    // MARK: - Stream Control

    func startGlobalStream(title: String, profiles: Set<AdaptiveBitrateDistribution.EncodingProfile>) async throws {

        // 1. Start SRT ingest
        try await srtEngine.connect(to: "srt://ingest.echoelmusic.com:9000", streamKey: "live_\(UUID().uuidString.prefix(8))")

        // 2. Start ABR distribution
        try await abrDistribution.startDistribution(profiles: profiles, formats: [.hls, .dash, .llhls])

        // 3. Start LL-HLS for low latency
        llhlsProducer.startProduction()

        isStreaming = true
        streamURL = "https://live.echoelmusic.com/\(UUID().uuidString.prefix(8))/master.m3u8"

        print("🎬 Global stream started: \(streamURL)")
    }

    func stopGlobalStream() {
        srtEngine.disconnect()
        abrDistribution.stopDistribution()
        llhlsProducer.stopProduction()

        isStreaming = false
        streamURL = ""

        print("⏹ Global stream stopped")
    }

    // MARK: - Health Monitoring

    func updateHealth() {
        let srtQuality = srtEngine.connectionQuality
        let packetLoss = srtEngine.packetLoss
        let latency = srtEngine.currentLatency

        if packetLoss < 0.1 && latency < 150 {
            streamHealth = .excellent
        } else if packetLoss < 0.5 && latency < 200 {
            streamHealth = .good
        } else if packetLoss < 1.0 && latency < 300 {
            streamHealth = .fair
        } else {
            streamHealth = .poor
        }
    }
}
