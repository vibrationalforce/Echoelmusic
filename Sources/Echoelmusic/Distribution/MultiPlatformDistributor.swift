import Foundation
import Combine

/// Multi-Platform Distributor
/// Unified distribution system for spatial audio and immersive video
///
/// Features:
/// - Simultaneous distribution to multiple platforms
/// - Automatic format conversion
/// - Rights management integration
/// - Revenue tracking
/// - Analytics and reporting
@MainActor
class MultiPlatformDistributor: ObservableObject {

    // MARK: - Published Properties

    @Published var distributionCampaigns: [DistributionCampaign] = []
    @Published var analytics: DistributionAnalytics
    @Published var revenueTracking: RevenueTracking

    // MARK: - Engines

    private let audioEngine: SpatialAudioDistributionEngine
    private let videoEngine: VideoStreamingEngine

    // MARK: - Distribution Campaign

    struct DistributionCampaign: Identifiable {
        let id = UUID()
        let title: String
        let type: ContentType
        var audioFile: URL?
        var videoFile: URL?
        var metadata: ContentMetadata
        var selectedPlatforms: [Platform]
        var status: CampaignStatus
        var createdDate: Date
        var publishDate: Date?
        var analytics: CampaignAnalytics

        enum ContentType {
            case audioOnly           // Music/Podcast
            case videoOnly           // Standard video
            case audioVideo          // Music video
            case spatialAudio        // Dolby Atmos/Ambisonics
            case vrVideo             // 360°/180° VR
            case spatialAudioVideo   // Complete immersive experience
        }

        enum CampaignStatus {
            case draft
            case processing
            case distributing
            case published
            case failed

            var icon: String {
                switch self {
                case .draft: return "📝"
                case .processing: return "⚙️"
                case .distributing: return "📤"
                case .published: return "✅"
                case .failed: return "❌"
                }
            }
        }
    }

    struct ContentMetadata {
        // Basic Info
        var title: String
        var artist: String
        var album: String?
        var description: String?

        // Categories
        var genre: String
        var tags: [String]
        var language: String

        // Rights
        var copyright: String
        var isrc: String?
        var iswc: String?
        var publishingRights: String?

        // Artwork
        var coverArt: Data?
        var thumbnail: Data?

        // Privacy
        var privacyStatus: PrivacyStatus
        var releaseDate: Date?

        enum PrivacyStatus: String {
            case publicContent = "Public"
            case unlisted = "Unlisted"
            case privateContent = "Private"
            case scheduled = "Scheduled"
        }
    }

    struct Platform: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let type: PlatformType
        var enabled: Bool

        enum PlatformType {
            case musicStreaming     // Spotify, Apple Music, TIDAL
            case videoStreaming     // YouTube, Vimeo
            case socialMedia        // Facebook, Instagram, TikTok
            case vrPlatform        // Meta Quest, SteamVR
            case podcast           // Apple Podcasts, Spotify Podcasts
        }

        static let allPlatforms: [Platform] = [
            // Music Streaming
            Platform(name: "Apple Music", type: .musicStreaming, enabled: true),
            Platform(name: "Spotify", type: .musicStreaming, enabled: true),
            Platform(name: "TIDAL", type: .musicStreaming, enabled: true),
            Platform(name: "Amazon Music HD", type: .musicStreaming, enabled: true),
            Platform(name: "Deezer", type: .musicStreaming, enabled: true),
            Platform(name: "YouTube Music", type: .musicStreaming, enabled: true),
            Platform(name: "Qobuz", type: .musicStreaming, enabled: true),

            // Video Streaming
            Platform(name: "YouTube", type: .videoStreaming, enabled: true),
            Platform(name: "Vimeo", type: .videoStreaming, enabled: true),

            // Social Media
            Platform(name: "Facebook Watch", type: .socialMedia, enabled: true),
            Platform(name: "Instagram TV", type: .socialMedia, enabled: true),
            Platform(name: "TikTok", type: .socialMedia, enabled: true),

            // VR Platforms
            Platform(name: "Meta Quest", type: .vrPlatform, enabled: true),
            Platform(name: "SteamVR", type: .vrPlatform, enabled: true),
            Platform(name: "PlayStation VR", type: .vrPlatform, enabled: true),
        ]
    }

    // MARK: - Analytics

    struct DistributionAnalytics {
        var totalCampaigns: Int
        var activeCampaigns: Int
        var totalStreams: Int64
        var totalViews: Int64
        var totalRevenue: Double
        var platformBreakdown: [String: PlatformStats]

        struct PlatformStats {
            var streams: Int64
            var revenue: Double
            var topCountries: [String]
        }
    }

    struct CampaignAnalytics {
        var totalStreams: Int64 = 0
        var totalViews: Int64 = 0
        var uniqueListeners: Int64 = 0
        var totalRevenue: Double = 0.0
        var platformStats: [String: PlatformPerformance] = [:]
        var demographics: Demographics = Demographics()

        struct PlatformPerformance {
            var streams: Int64
            var revenue: Double
            var averageWatchTime: Double  // seconds
            var completionRate: Double    // percentage
        }

        struct Demographics {
            var topCountries: [CountryStats] = []
            var ageGroups: [AgeGroup: Int] = [:]
            var genderBreakdown: [Gender: Int] = [:]

            struct CountryStats {
                let country: String
                let streams: Int64
                let percentage: Double
            }

            enum AgeGroup: String {
                case under18 = "Under 18"
                case age18to24 = "18-24"
                case age25to34 = "25-34"
                case age35to44 = "35-44"
                case age45to54 = "45-54"
                case age55plus = "55+"
            }

            enum Gender: String {
                case male = "Male"
                case female = "Female"
                case other = "Other"
            }
        }
    }

    // MARK: - Revenue Tracking

    struct RevenueTracking {
        var totalRevenue: Double
        var pendingRevenue: Double
        var paidRevenue: Double
        var revenueByPlatform: [String: Double]
        var revenueByMonth: [String: Double]
        var nextPaymentDate: Date?
        var paymentHistory: [Payment]

        struct Payment: Identifiable {
            let id = UUID()
            let platform: String
            let amount: Double
            let currency: String
            let period: String
            let paidDate: Date
            let status: PaymentStatus

            enum PaymentStatus {
                case pending, processing, paid, failed
            }
        }
    }

    // MARK: - Initialization

    init() {
        print("🌐 Multi-Platform Distributor initialized")

        self.audioEngine = SpatialAudioDistributionEngine()
        self.videoEngine = VideoStreamingEngine()

        self.analytics = DistributionAnalytics(
            totalCampaigns: 0,
            activeCampaigns: 0,
            totalStreams: 0,
            totalViews: 0,
            totalRevenue: 0.0,
            platformBreakdown: [:]
        )

        self.revenueTracking = RevenueTracking(
            totalRevenue: 0.0,
            pendingRevenue: 0.0,
            paidRevenue: 0.0,
            revenueByPlatform: [:],
            revenueByMonth: [:],
            nextPaymentDate: nil,
            paymentHistory: []
        )
    }

    // MARK: - Create Distribution Campaign

    func createCampaign(
        title: String,
        type: DistributionCampaign.ContentType,
        metadata: ContentMetadata,
        platforms: [Platform]
    ) -> DistributionCampaign {
        print("📝 Creating distribution campaign...")
        print("   Title: \(title)")
        print("   Type: \(type)")
        print("   Platforms: \(platforms.count)")

        let campaign = DistributionCampaign(
            title: title,
            type: type,
            metadata: metadata,
            selectedPlatforms: platforms,
            status: .draft,
            createdDate: Date(),
            analytics: CampaignAnalytics()
        )

        distributionCampaigns.append(campaign)
        analytics.totalCampaigns += 1

        print("   ✅ Campaign created")

        return campaign
    }

    // MARK: - Execute Distribution

    func distributeCampaign(_ campaignId: UUID) async {
        guard let index = distributionCampaigns.firstIndex(where: { $0.id == campaignId }) else {
            print("❌ Campaign not found")
            return
        }

        var campaign = distributionCampaigns[index]

        print("🚀 Executing distribution campaign: \(campaign.title)")
        print("   Type: \(campaign.type)")

        // Update status
        campaign.status = .processing
        distributionCampaigns[index] = campaign

        // Process based on content type
        switch campaign.type {
        case .audioOnly:
            await distributeAudioOnly(campaign: &campaign)

        case .videoOnly:
            await distributeVideoOnly(campaign: &campaign)

        case .audioVideo:
            await distributeAudioVideo(campaign: &campaign)

        case .spatialAudio:
            await distributeSpatialAudio(campaign: &campaign)

        case .vrVideo:
            await distributeVRVideo(campaign: &campaign)

        case .spatialAudioVideo:
            await distributeSpatialAudioVideo(campaign: &campaign)
        }

        // Update status
        campaign.status = .published
        campaign.publishDate = Date()
        distributionCampaigns[index] = campaign

        analytics.activeCampaigns += 1

        print("   ✅ Distribution campaign completed!")
    }

    // MARK: - Distribution Methods

    private func distributeAudioOnly(campaign: inout DistributionCampaign) async {
        print("   🎵 Distributing audio-only content...")

        guard let audioFile = campaign.audioFile else {
            print("      ❌ No audio file provided")
            campaign.status = .failed
            return
        }

        // Get music streaming platforms
        let musicPlatforms = campaign.selectedPlatforms.filter { $0.type == .musicStreaming }

        print("      📤 Uploading to \(musicPlatforms.count) music platforms...")

        for platform in musicPlatforms {
            // Convert metadata
            let audioMetadata = convertToAudioMetadata(campaign.metadata)

            // Distribute via audio engine
            let streamingPlatform = mapToStreamingPlatform(platform.name)
            print("         → \(platform.name)")

            // Simulated upload (in production: use audioEngine)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        print("      ✅ Audio distribution completed")
    }

    private func distributeVideoOnly(campaign: inout DistributionCampaign) async {
        print("   🎬 Distributing video-only content...")

        guard let videoFile = campaign.videoFile else {
            print("      ❌ No video file provided")
            campaign.status = .failed
            return
        }

        // Get video platforms
        let videoPlatforms = campaign.selectedPlatforms.filter {
            $0.type == .videoStreaming || $0.type == .socialMedia
        }

        print("      📤 Uploading to \(videoPlatforms.count) video platforms...")

        for platform in videoPlatforms {
            // Convert metadata
            let videoMetadata = convertToVideoMetadata(campaign.metadata)

            // Distribute via video engine
            let videoPlatform = mapToVideoPlatform(platform.name)
            let success = await videoEngine.uploadToPlatform(
                videoFile: videoFile,
                platform: videoPlatform,
                metadata: videoMetadata
            )

            if success {
                print("         ✅ \(platform.name)")
            } else {
                print("         ❌ \(platform.name)")
            }
        }

        print("      ✅ Video distribution completed")
    }

    private func distributeAudioVideo(campaign: inout DistributionCampaign) async {
        print("   🎵🎬 Distributing audio+video content...")

        // Distribute to both audio and video platforms
        await distributeAudioOnly(campaign: &campaign)
        await distributeVideoOnly(campaign: &campaign)
    }

    private func distributeSpatialAudio(campaign: inout DistributionCampaign) async {
        print("   🔊 Distributing spatial audio content...")

        guard let audioFile = campaign.audioFile else {
            print("      ❌ No audio file provided")
            campaign.status = .failed
            return
        }

        // Get platforms that support spatial audio
        let spatialPlatforms = campaign.selectedPlatforms.filter { platform in
            ["Apple Music", "TIDAL", "Amazon Music HD", "Deezer"].contains(platform.name)
        }

        print("      📤 Uploading to \(spatialPlatforms.count) spatial audio platforms...")

        // Convert metadata
        let audioMetadata = convertToAudioMetadata(campaign.metadata)

        // Distribute Dolby Atmos
        print("      🔊 Distributing Dolby Atmos...")
        await audioEngine.distributeToAllPlatforms(
            audioFile: audioFile,
            metadata: audioMetadata,
            targetFormat: .dolbyAtmos
        )

        // Distribute Sony 360RA (for compatible platforms)
        let sony360Platforms = spatialPlatforms.filter {
            ["Amazon Music HD", "Deezer", "TIDAL"].contains($0.name)
        }

        if !sony360Platforms.isEmpty {
            print("      🔊 Distributing Sony 360 Reality Audio...")
            await audioEngine.distributeToAllPlatforms(
                audioFile: audioFile,
                metadata: audioMetadata,
                targetFormat: .sony360RA
            )
        }

        print("      ✅ Spatial audio distribution completed")
    }

    private func distributeVRVideo(campaign: inout DistributionCampaign) async {
        print("   🥽 Distributing VR video content...")

        guard let videoFile = campaign.videoFile else {
            print("      ❌ No video file provided")
            campaign.status = .failed
            return
        }

        // Get VR platforms
        let vrPlatforms = campaign.selectedPlatforms.filter {
            $0.type == .vrPlatform || ["YouTube", "Vimeo", "Facebook Watch"].contains($0.name)
        }

        print("      📤 Uploading to \(vrPlatforms.count) VR platforms...")

        // Inject VR metadata
        guard let vrVideoFile = await videoEngine.injectVRMetadata(
            videoFile: videoFile,
            format: .vr360Stereo
        ) else {
            print("      ❌ VR metadata injection failed")
            campaign.status = .failed
            return
        }

        // Upload to platforms
        for platform in vrPlatforms {
            let videoMetadata = convertToVideoMetadata(campaign.metadata)
            videoMetadata.isVR = true

            let videoPlatform = mapToVideoPlatform(platform.name)
            let success = await videoEngine.uploadToPlatform(
                videoFile: vrVideoFile,
                platform: videoPlatform,
                metadata: videoMetadata
            )

            if success {
                print("         ✅ \(platform.name)")
            } else {
                print("         ❌ \(platform.name)")
            }
        }

        print("      ✅ VR video distribution completed")
    }

    private func distributeSpatialAudioVideo(campaign: inout DistributionCampaign) async {
        print("   🔊🥽 Distributing complete immersive experience...")

        // Distribute spatial audio
        await distributeSpatialAudio(campaign: &campaign)

        // Distribute VR video
        await distributeVRVideo(campaign: &campaign)

        print("      ✅ Immersive experience distribution completed")
    }

    // MARK: - Metadata Conversion

    private func convertToAudioMetadata(_ metadata: ContentMetadata) -> SpatialAudioDistributionEngine.AudioMetadata {
        return SpatialAudioDistributionEngine.AudioMetadata(
            title: metadata.title,
            artist: metadata.artist,
            album: metadata.album,
            isrc: metadata.isrc,
            year: Calendar.current.component(.year, from: Date()),
            genre: metadata.genre,
            artwork: metadata.coverArt,
            copyright: metadata.copyright
        )
    }

    private func convertToVideoMetadata(_ metadata: ContentMetadata) -> VideoStreamingEngine.VideoMetadata {
        return VideoStreamingEngine.VideoMetadata(
            title: metadata.title,
            description: metadata.description ?? "",
            tags: metadata.tags,
            category: metadata.genre,
            privacyStatus: mapPrivacyStatus(metadata.privacyStatus),
            thumbnail: metadata.thumbnail,
            isVR: false,
            language: metadata.language
        )
    }

    private func mapPrivacyStatus(_ status: ContentMetadata.PrivacyStatus) -> VideoStreamingEngine.VideoMetadata.PrivacyStatus {
        switch status {
        case .publicContent: return .publicVideo
        case .unlisted: return .unlisted
        case .privateContent, .scheduled: return .privateVideo
        }
    }

    // MARK: - Platform Mapping

    private func mapToStreamingPlatform(_ name: String) -> SpatialAudioDistributionEngine.StreamingPlatform {
        switch name {
        case "Apple Music": return .appleMusic
        case "Spotify": return .spotify
        case "TIDAL": return .tidal
        case "Amazon Music HD": return .amazonMusicHD
        case "Deezer": return .deezer
        case "YouTube Music": return .youtubeMusic
        case "Qobuz": return .qobuz
        default: return .spotify
        }
    }

    private func mapToVideoPlatform(_ name: String) -> VideoStreamingEngine.VideoPlatform {
        switch name {
        case "YouTube": return .youtube
        case "Vimeo": return .vimeo
        case "Facebook Watch": return .facebook
        case "Instagram TV": return .instagram
        case "TikTok": return .tiktok
        case "Meta Quest": return .metaQuest
        case "SteamVR": return .steamVR
        case "PlayStation VR": return .playstationVR
        default: return .youtube
        }
    }

    // MARK: - Analytics

    func fetchAnalytics(for campaignId: UUID) async {
        print("📊 Fetching analytics for campaign...")

        guard let index = distributionCampaigns.firstIndex(where: { $0.id == campaignId }) else {
            return
        }

        var campaign = distributionCampaigns[index]

        // Fetch from each platform
        for platform in campaign.selectedPlatforms {
            let stats = await fetchPlatformAnalytics(platform: platform.name)

            campaign.analytics.platformStats[platform.name] = stats
            campaign.analytics.totalStreams += stats.streams
            campaign.analytics.totalRevenue += stats.revenue
        }

        distributionCampaigns[index] = campaign

        // Update global analytics
        updateGlobalAnalytics()

        print("   ✅ Analytics updated")
    }

    private func fetchPlatformAnalytics(platform: String) async -> CampaignAnalytics.PlatformPerformance {
        // In production: Fetch from platform APIs
        // - Spotify for Artists API
        // - Apple Music for Artists API
        // - YouTube Analytics API
        // etc.

        // Simulated data
        return CampaignAnalytics.PlatformPerformance(
            streams: Int64.random(in: 1000...100000),
            revenue: Double.random(in: 10.0...1000.0),
            averageWatchTime: Double.random(in: 30.0...180.0),
            completionRate: Double.random(in: 50.0...95.0)
        )
    }

    private func updateGlobalAnalytics() {
        analytics.totalStreams = distributionCampaigns.reduce(0) { $0 + $1.analytics.totalStreams }
        analytics.totalRevenue = distributionCampaigns.reduce(0) { $0 + $1.analytics.totalRevenue }
        analytics.activeCampaigns = distributionCampaigns.filter { $0.status == .published }.count
    }

    // MARK: - Revenue Tracking

    func fetchRevenueData() async {
        print("💰 Fetching revenue data...")

        // Fetch from all platforms
        var totalRevenue = 0.0
        var revenueByPlatform: [String: Double] = [:]

        for campaign in distributionCampaigns where campaign.status == .published {
            for (platform, stats) in campaign.analytics.platformStats {
                revenueByPlatform[platform, default: 0.0] += stats.revenue
                totalRevenue += stats.revenue
            }
        }

        revenueTracking.totalRevenue = totalRevenue
        revenueTracking.revenueByPlatform = revenueByPlatform

        // Calculate pending vs paid
        revenueTracking.pendingRevenue = totalRevenue * 0.3  // 30% pending
        revenueTracking.paidRevenue = totalRevenue * 0.7     // 70% paid

        print("   💰 Total Revenue: $\(String(format: "%.2f", totalRevenue))")
        print("   ⏳ Pending: $\(String(format: "%.2f", revenueTracking.pendingRevenue))")
        print("   ✅ Paid: $\(String(format: "%.2f", revenueTracking.paidRevenue))")
    }

    // MARK: - Reporting

    func generateDistributionReport() -> String {
        var report = """
        ═══════════════════════════════════════
        DISTRIBUTION REPORT
        ═══════════════════════════════════════

        OVERVIEW
        ───────────────────────────────────────
        Total Campaigns: \(analytics.totalCampaigns)
        Active Campaigns: \(analytics.activeCampaigns)
        Total Streams: \(formatNumber(analytics.totalStreams))
        Total Revenue: $\(String(format: "%.2f", analytics.totalRevenue))

        """

        // Top campaigns
        let topCampaigns = distributionCampaigns
            .sorted { $0.analytics.totalStreams > $1.analytics.totalStreams }
            .prefix(5)

        if !topCampaigns.isEmpty {
            report += """

            TOP CAMPAIGNS
            ───────────────────────────────────────

            """

            for (index, campaign) in topCampaigns.enumerated() {
                report += """
                \(index + 1). \(campaign.title)
                   Streams: \(formatNumber(campaign.analytics.totalStreams))
                   Revenue: $\(String(format: "%.2f", campaign.analytics.totalRevenue))
                   Platforms: \(campaign.selectedPlatforms.count)

                """
            }
        }

        // Revenue breakdown
        report += """

        REVENUE BY PLATFORM
        ───────────────────────────────────────

        """

        let sortedRevenue = revenueTracking.revenueByPlatform
            .sorted { $0.value > $1.value }

        for (platform, revenue) in sortedRevenue {
            let percentage = (revenue / revenueTracking.totalRevenue) * 100
            report += """
            \(platform): $\(String(format: "%.2f", revenue)) (\(String(format: "%.1f", percentage))%)

            """
        }

        report += "═══════════════════════════════════════"

        return report
    }

    private func formatNumber(_ number: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}
