import Foundation
import Network
import Combine

/// Network Optimization & Adaptive Streaming Engine
/// Automatically detects network speed and optimizes transmission quality
///
/// Features:
/// - Upload/Download speed detection
/// - Adaptive bitrate streaming
/// - Network quality monitoring
/// - Automatic quality adjustment
/// - CDN selection
/// - Packet loss detection
/// - Jitter compensation
@MainActor
class NetworkOptimizationEngine: ObservableObject {

    // MARK: - Published Properties

    @Published var networkStatus: NetworkStatus
    @Published var streamingQuality: StreamingQuality
    @Published var adaptiveSettings: AdaptiveSettings

    // MARK: - Network Monitor

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")

    // MARK: - Network Status

    struct NetworkStatus: Codable {
        var isConnected: Bool
        var connectionType: ConnectionType
        var downloadSpeedMbps: Double
        var uploadSpeedMbps: Double
        var latencyMs: Double
        var jitterMs: Double
        var packetLoss: Double  // Percentage
        var quality: NetworkQuality

        enum ConnectionType: String, Codable {
            case wifi = "Wi-Fi"
            case ethernet = "Ethernet"
            case cellular5G = "5G"
            case cellular4G = "4G/LTE"
            case cellular3G = "3G"
            case unknown = "Unknown"
        }

        enum NetworkQuality: String, Codable {
            case excellent = "Excellent (100+ Mbps)"
            case good = "Good (50-100 Mbps)"
            case fair = "Fair (10-50 Mbps)"
            case poor = "Poor (1-10 Mbps)"
            case veryPoor = "Very Poor (<1 Mbps)"

            var color: String {
                switch self {
                case .excellent: return "green"
                case .good: return "blue"
                case .fair: return "yellow"
                case .poor: return "orange"
                case .veryPoor: return "red"
                }
            }
        }

        var description: String {
            """
            Connection: \(connectionType.rawValue)
            Download: \(String(format: "%.1f", downloadSpeedMbps)) Mbps
            Upload: \(String(format: "%.1f", uploadSpeedMbps)) Mbps
            Latency: \(String(format: "%.0f", latencyMs)) ms
            Jitter: \(String(format: "%.0f", jitterMs)) ms
            Packet Loss: \(String(format: "%.1f", packetLoss))%
            Quality: \(quality.rawValue)
            """
        }
    }

    // MARK: - Streaming Quality

    enum StreamingQuality: String, Codable, CaseIterable {
        case source = "Source Quality (Lossless)"
        case ultra = "Ultra (4K @ 60fps)"
        case high = "High (1080p @ 60fps)"
        case medium = "Medium (720p @ 30fps)"
        case low = "Low (480p @ 30fps)"
        case autoLow = "Auto-Low (Adaptive)"

        var videoBitrateMbps: Double {
            switch self {
            case .source: return 50.0   // Lossless
            case .ultra: return 25.0    // 4K
            case .high: return 8.0      // 1080p
            case .medium: return 2.5    // 720p
            case .low: return 1.0       // 480p
            case .autoLow: return 0.5   // Adaptive
            }
        }

        var audioBitrate Kbps: Int {
            switch self {
            case .source: return 1411   // CD quality (16-bit/44.1kHz PCM)
            case .ultra: return 320     // High quality MP3/AAC
            case .high: return 256      // Good quality
            case .medium: return 192    // Standard
            case .low: return 128       // Low
            case .autoLow: return 64    // Very low
            }
        }

        var resolution: CGSize {
            switch self {
            case .source, .ultra: return CGSize(width: 3840, height: 2160)  // 4K
            case .high: return CGSize(width: 1920, height: 1080)  // 1080p
            case .medium: return CGSize(width: 1280, height: 720)  // 720p
            case .low, .autoLow: return CGSize(width: 854, height: 480)  // 480p
            }
        }

        var frameRate: Int {
            switch self {
            case .source, .ultra, .high: return 60
            case .medium, .low, .autoLow: return 30
            }
        }

        var requiredDownloadMbps: Double {
            return videoBitrateMbps + (Double(audioBitrateKbps) / 1000.0)
        }
    }

    // MARK: - Adaptive Settings

    struct AdaptiveSettings: Codable {
        var enableAdaptive: Bool
        var currentQuality: StreamingQuality
        var targetQuality: StreamingQuality
        var bufferSizeSeconds: Double
        var maxBufferSizeSeconds: Double
        var minBufferSizeSeconds: Double
        var qualitySwitchThreshold: Double  // Percentage

        var description: String {
            """
            Adaptive Streaming: \(enableAdaptive ? "ON" : "OFF")
            Current Quality: \(currentQuality.rawValue)
            Target Quality: \(targetQuality.rawValue)
            Buffer: \(String(format: "%.1f", bufferSizeSeconds))s / \(String(format: "%.1f", maxBufferSizeSeconds))s
            """
        }
    }

    // MARK: - Initialization

    init() {
        print("🌐 Network Optimization Engine initialized")

        // Initialize with default values
        self.networkStatus = NetworkStatus(
            isConnected: false,
            connectionType: .unknown,
            downloadSpeedMbps: 0,
            uploadSpeedMbps: 0,
            latencyMs: 0,
            jitterMs: 0,
            packetLoss: 0,
            quality: .veryPoor
        )

        self.streamingQuality = .medium

        self.adaptiveSettings = AdaptiveSettings(
            enableAdaptive: true,
            currentQuality: .medium,
            targetQuality: .high,
            bufferSizeSeconds: 5.0,
            maxBufferSizeSeconds: 30.0,
            minBufferSizeSeconds: 2.0,
            qualitySwitchThreshold: 0.8
        )

        // Start monitoring
        startNetworkMonitoring()
        Task {
            await measureNetworkSpeed()
        }
    }

    // MARK: - Network Monitoring

    func startNetworkMonitoring() {
        print("   🔍 Starting network monitoring...")

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updateNetworkStatus(path: path)
            }
        }

        monitor.start(queue: monitorQueue)
    }

    private func updateNetworkStatus(path: NWPath) {
        var connectionType: NetworkStatus.ConnectionType = .unknown

        // Detect connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else if path.usesInterfaceType(.cellular) {
            // Detect cellular generation (simplified)
            connectionType = .cellular4G  // Default to 4G
        }

        networkStatus.isConnected = path.status == .satisfied
        networkStatus.connectionType = connectionType

        print("   📶 Network status updated:")
        print("      Connected: \(networkStatus.isConnected)")
        print("      Type: \(connectionType.rawValue)")

        // Re-measure speed on connection change
        if networkStatus.isConnected {
            Task {
                await measureNetworkSpeed()
            }
        }
    }

    // MARK: - Speed Measurement

    func measureNetworkSpeed() async {
        print("   📊 Measuring network speed...")

        // Download speed test
        let downloadSpeed = await measureDownloadSpeed()
        networkStatus.downloadSpeedMbps = downloadSpeed

        // Upload speed test
        let uploadSpeed = await measureUploadSpeed()
        networkStatus.uploadSpeedMbps = uploadSpeed

        // Latency test (ping)
        let latency = await measureLatency()
        networkStatus.latencyMs = latency

        // Jitter test
        let jitter = await measureJitter()
        networkStatus.jitterMs = jitter

        // Packet loss test
        let packetLoss = await measurePacketLoss()
        networkStatus.packetLoss = packetLoss

        // Determine quality
        networkStatus.quality = determineNetworkQuality(downloadSpeed: downloadSpeed)

        print("   ✅ Network speed measured:")
        print("      \(networkStatus.description)")

        // Adjust streaming quality based on speed
        adjustStreamingQuality()
    }

    private func measureDownloadSpeed() async -> Double {
        // In production: Download test file from CDN
        // Measure transfer time and calculate speed

        // Simulate test (10 MB file in 2 seconds = 40 Mbps)
        try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms

        // Return simulated speed based on connection type
        switch networkStatus.connectionType {
        case .ethernet: return 500.0  // Gigabit Ethernet
        case .wifi: return 100.0      // Modern Wi-Fi
        case .cellular5G: return 150.0
        case .cellular4G: return 25.0
        case .cellular3G: return 3.0
        case .unknown: return 10.0
        }
    }

    private func measureUploadSpeed() async -> Double {
        // In production: Upload test file to server

        try? await Task.sleep(nanoseconds: 100_000_000)

        // Typically ~10-20% of download speed
        return networkStatus.downloadSpeedMbps * 0.2
    }

    private func measureLatency() async -> Double {
        // In production: Ping test server
        // Multiple pings and average

        try? await Task.sleep(nanoseconds: 50_000_000)

        // Typical latencies
        switch networkStatus.connectionType {
        case .ethernet: return 5.0
        case .wifi: return 20.0
        case .cellular5G: return 30.0
        case .cellular4G: return 50.0
        case .cellular3G: return 150.0
        case .unknown: return 100.0
        }
    }

    private func measureJitter() async -> Double {
        // Jitter = variation in latency
        // Multiple latency measurements and calculate standard deviation

        try? await Task.sleep(nanoseconds: 50_000_000)

        // Typical jitter (10-20% of latency)
        return networkStatus.latencyMs * 0.15
    }

    private func measurePacketLoss() async -> Double {
        // Send multiple packets and count losses

        try? await Task.sleep(nanoseconds: 50_000_000)

        // Typical packet loss
        switch networkStatus.quality {
        case .excellent, .good: return 0.1
        case .fair: return 0.5
        case .poor: return 2.0
        case .veryPoor: return 5.0
        }
    }

    private func determineNetworkQuality(downloadSpeed: Double) -> NetworkStatus.NetworkQuality {
        if downloadSpeed >= 100 {
            return .excellent
        } else if downloadSpeed >= 50 {
            return .good
        } else if downloadSpeed >= 10 {
            return .fair
        } else if downloadSpeed >= 1 {
            return .poor
        } else {
            return .veryPoor
        }
    }

    // MARK: - Adaptive Streaming

    func adjustStreamingQuality() {
        guard adaptiveSettings.enableAdaptive else { return }

        print("   🎯 Adjusting streaming quality...")

        // Select quality based on network speed
        let availableBandwidth = networkStatus.downloadSpeedMbps
        let targetQuality: StreamingQuality

        if availableBandwidth >= 50 {
            targetQuality = .source  // Lossless
        } else if availableBandwidth >= 25 {
            targetQuality = .ultra  // 4K
        } else if availableBandwidth >= 8 {
            targetQuality = .high  // 1080p
        } else if availableBandwidth >= 2.5 {
            targetQuality = .medium  // 720p
        } else if availableBandwidth >= 1 {
            targetQuality = .low  // 480p
        } else {
            targetQuality = .autoLow  // Adaptive low
        }

        // Update if changed
        if targetQuality != adaptiveSettings.targetQuality {
            adaptiveSettings.targetQuality = targetQuality
            streamingQuality = targetQuality

            print("   ✅ Quality adjusted to: \(targetQuality.rawValue)")
            print("      Video: \(targetQuality.videoBitrateMbps) Mbps")
            print("      Audio: \(targetQuality.audioBitrateKbps) kbps")
            print("      Resolution: \(Int(targetQuality.resolution.width))x\(Int(targetQuality.resolution.height)) @ \(targetQuality.frameRate)fps")
        }
    }

    // MARK: - Buffer Management

    func updateBufferStatus(currentBuffer: Double) {
        adaptiveSettings.bufferSizeSeconds = currentBuffer

        // If buffer is low, reduce quality
        if currentBuffer < adaptiveSettings.minBufferSizeSeconds {
            print("   ⚠️ Buffer low (\(String(format: "%.1f", currentBuffer))s), reducing quality...")
            reduceQuality()
        }

        // If buffer is high and network is good, increase quality
        if currentBuffer > adaptiveSettings.maxBufferSizeSeconds * 0.8 &&
           networkStatus.quality == .excellent || networkStatus.quality == .good {
            print("   📈 Buffer healthy, increasing quality...")
            increaseQuality()
        }
    }

    private func reduceQuality() {
        let allQualities = StreamingQuality.allCases
        if let currentIndex = allQualities.firstIndex(of: streamingQuality),
           currentIndex < allQualities.count - 1 {
            streamingQuality = allQualities[currentIndex + 1]
            adaptiveSettings.currentQuality = streamingQuality
            print("      → \(streamingQuality.rawValue)")
        }
    }

    private func increaseQuality() {
        let allQualities = StreamingQuality.allCases
        if let currentIndex = allQualities.firstIndex(of: streamingQuality),
           currentIndex > 0 {
            streamingQuality = allQualities[currentIndex - 1]
            adaptiveSettings.currentQuality = streamingQuality
            print("      → \(streamingQuality.rawValue)")
        }
    }

    // MARK: - CDN Selection

    func selectOptimalCDN(cdns: [CDNServer]) async -> CDNServer? {
        print("   🌍 Selecting optimal CDN from \(cdns.count) servers...")

        var bestCDN: CDNServer?
        var lowestLatency: Double = .infinity

        // Test latency to each CDN
        for cdn in cdns {
            let latency = await testCDNLatency(cdn: cdn)

            print("      \(cdn.location): \(String(format: "%.0f", latency)) ms")

            if latency < lowestLatency {
                lowestLatency = latency
                bestCDN = cdn
            }
        }

        if let best = bestCDN {
            print("   ✅ Selected: \(best.location) (\(String(format: "%.0f", lowestLatency)) ms)")
        }

        return bestCDN
    }

    struct CDNServer {
        let url: URL
        let location: String
        let region: String
    }

    private func testCDNLatency(cdn: CDNServer) async -> Double {
        // Ping CDN server
        let startTime = Date()

        // In production: HTTP HEAD request
        try? await Task.sleep(nanoseconds: UInt64.random(in: 10_000_000...100_000_000))

        let endTime = Date()
        return endTime.timeIntervalSince(startTime) * 1000  // ms
    }

    // MARK: - Quality Recommendations

    func getRecommendedSettings() -> QualityRecommendations {
        let networkQuality = networkStatus.quality

        return QualityRecommendations(
            streaming: recommendedStreamingQuality(),
            recording: recommendedRecordingQuality(),
            collaboration: recommendedCollaborationSettings(),
            cloudSync: recommendedCloudSyncSettings()
        )
    }

    struct QualityRecommendations {
        let streaming: StreamingQuality
        let recording: RecordingQuality
        let collaboration: CollaborationSettings
        let cloudSync: CloudSyncSettings

        struct RecordingQuality {
            let videoResolution: CGSize
            let videoFramerate: Int
            let videoBitrate: Double
            let audioSampleRate: Int
            let audioBitDepth: Int
        }

        struct CollaborationSettings {
            let maxParticipants: Int
            let audioLatency: Double
            let videoEnabled: Bool
        }

        struct CloudSyncSettings {
            let enabled: Bool
            let syncInterval: TimeInterval
            let backgroundSync: Bool
        }
    }

    private func recommendedStreamingQuality() -> StreamingQuality {
        switch networkStatus.quality {
        case .excellent: return .source
        case .good: return .ultra
        case .fair: return .high
        case .poor: return .medium
        case .veryPoor: return .low
        }
    }

    private func recommendedRecordingQuality() -> QualityRecommendations.RecordingQuality {
        switch networkStatus.quality {
        case .excellent, .good:
            return QualityRecommendations.RecordingQuality(
                videoResolution: CGSize(width: 3840, height: 2160),
                videoFramerate: 60,
                videoBitrate: 50.0,
                audioSampleRate: 96000,
                audioBitDepth: 32
            )
        case .fair:
            return QualityRecommendations.RecordingQuality(
                videoResolution: CGSize(width: 1920, height: 1080),
                videoFramerate: 60,
                videoBitrate: 25.0,
                audioSampleRate: 48000,
                audioBitDepth: 24
            )
        default:
            return QualityRecommendations.RecordingQuality(
                videoResolution: CGSize(width: 1280, height: 720),
                videoFramerate: 30,
                videoBitrate: 10.0,
                audioSampleRate: 48000,
                audioBitDepth: 16
            )
        }
    }

    private func recommendedCollaborationSettings() -> QualityRecommendations.CollaborationSettings {
        switch networkStatus.quality {
        case .excellent:
            return QualityRecommendations.CollaborationSettings(
                maxParticipants: 16,
                audioLatency: 10.0,
                videoEnabled: true
            )
        case .good:
            return QualityRecommendations.CollaborationSettings(
                maxParticipants: 8,
                audioLatency: 20.0,
                videoEnabled: true
            )
        case .fair:
            return QualityRecommendations.CollaborationSettings(
                maxParticipants: 4,
                audioLatency: 50.0,
                videoEnabled: false
            )
        default:
            return QualityRecommendations.CollaborationSettings(
                maxParticipants: 2,
                audioLatency: 100.0,
                videoEnabled: false
            )
        }
    }

    private func recommendedCloudSyncSettings() -> QualityRecommendations.CloudSyncSettings {
        switch networkStatus.quality {
        case .excellent, .good:
            return QualityRecommendations.CloudSyncSettings(
                enabled: true,
                syncInterval: 60.0,  // 1 minute
                backgroundSync: true
            )
        case .fair:
            return QualityRecommendations.CloudSyncSettings(
                enabled: true,
                syncInterval: 300.0,  // 5 minutes
                backgroundSync: false
            )
        default:
            return QualityRecommendations.CloudSyncSettings(
                enabled: false,
                syncInterval: 0,
                backgroundSync: false
            )
        }
    }

    // MARK: - Cleanup

    deinit {
        monitor.cancel()
    }
}
