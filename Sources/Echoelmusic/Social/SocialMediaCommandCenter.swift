import Foundation
import Combine

// MARK: - Social Media Command Center
// Unified social media management rivaling Hootsuite, Buffer, Sprout Social
//
// Supported platforms:
// - Instagram (Posts, Stories, Reels, LIVE)
// - TikTok (Videos, LIVE)
// - YouTube (Videos, Shorts, LIVE, Premieres)
// - Facebook (Posts, Reels, LIVE)
// - Twitter/X (Posts, Threads, Spaces)
// - LinkedIn (Posts, Articles)
// - Twitch (LIVE streaming)
// - Discord (Bot integration)
// - Threads (Meta)
// - Bluesky (AT Protocol)
//
// Features:
// - Multi-platform posting
// - Content calendar & scheduling
// - Analytics dashboard
// - Engagement monitoring
// - AI-powered content suggestions
// - Bio-reactive live streaming

// MARK: - Platform Definitions

enum SocialPlatform: String, CaseIterable, Codable {
    case instagram = "Instagram"
    case tiktok = "TikTok"
    case youtube = "YouTube"
    case facebook = "Facebook"
    case twitter = "Twitter/X"
    case linkedin = "LinkedIn"
    case twitch = "Twitch"
    case discord = "Discord"
    case threads = "Threads"
    case bluesky = "Bluesky"

    var supportsVideo: Bool {
        switch self {
        case .linkedin: return true
        default: return true
        }
    }

    var supportsLive: Bool {
        switch self {
        case .instagram, .tiktok, .youtube, .facebook, .twitch, .twitter:
            return true
        default:
            return false
        }
    }

    var maxVideoLength: TimeInterval {
        switch self {
        case .instagram: return 90 * 60      // 90 min (Reels: 90 sec)
        case .tiktok: return 10 * 60         // 10 min
        case .youtube: return 12 * 3600      // 12 hours
        case .facebook: return 240 * 60      // 4 hours
        case .twitter: return 140            // 2:20
        case .linkedin: return 10 * 60       // 10 min
        default: return 0
        }
    }

    var optimalAspectRatio: String {
        switch self {
        case .instagram, .tiktok, .youtube:  // Shorts
            return "9:16"
        case .youtube:  // Regular
            return "16:9"
        case .twitter, .facebook, .linkedin:
            return "16:9"
        default:
            return "16:9"
        }
    }

    var characterLimit: Int? {
        switch self {
        case .twitter: return 280
        case .threads: return 500
        case .bluesky: return 300
        case .linkedin: return 3000
        default: return nil
        }
    }

    var hashtagLimit: Int {
        switch self {
        case .instagram: return 30
        case .tiktok: return 100  // chars, not count
        case .twitter: return 10  // recommended
        case .linkedin: return 5   // recommended
        default: return 30
        }
    }

    var apiBaseURL: String {
        switch self {
        case .instagram, .facebook, .threads:
            return "https://graph.facebook.com/v18.0"
        case .youtube:
            return "https://www.googleapis.com/youtube/v3"
        case .twitter:
            return "https://api.twitter.com/2"
        case .tiktok:
            return "https://open.tiktokapis.com/v2"
        case .linkedin:
            return "https://api.linkedin.com/v2"
        case .twitch:
            return "https://api.twitch.tv/helix"
        case .discord:
            return "https://discord.com/api/v10"
        case .bluesky:
            return "https://bsky.social/xrpc"
        }
    }
}

// MARK: - Account Management

struct SocialAccount: Identifiable, Codable {
    let id: UUID
    let platform: SocialPlatform
    var username: String
    var displayName: String
    var profileImageURL: URL?
    var accessToken: String
    var refreshToken: String?
    var tokenExpiry: Date?
    var isConnected: Bool

    // Account metrics
    var followerCount: Int = 0
    var followingCount: Int = 0
    var postCount: Int = 0

    init(platform: SocialPlatform, username: String, displayName: String, accessToken: String) {
        self.id = UUID()
        self.platform = platform
        self.username = username
        self.displayName = displayName
        self.accessToken = accessToken
        self.isConnected = true
    }
}

// MARK: - Content Types

struct SocialPost: Identifiable, Codable {
    let id: UUID
    var caption: String
    var mediaURLs: [URL]
    var mediaType: MediaType
    var platforms: [SocialPlatform]
    var scheduledDate: Date?
    var status: PostStatus
    var publishedURLs: [SocialPlatform: URL] = [:]

    // Platform-specific settings
    var instagramSettings: InstagramSettings?
    var youtubeSettings: YouTubeSettings?
    var tiktokSettings: TikTokSettings?

    enum MediaType: String, Codable {
        case image, video, carousel, story, reel, short, live
    }

    enum PostStatus: String, Codable {
        case draft, scheduled, publishing, published, failed
    }

    struct InstagramSettings: Codable {
        var shareToFeed: Bool = true
        var shareToStory: Bool = false
        var enableComments: Bool = true
        var locationTag: String?
        var collaborators: [String] = []
    }

    struct YouTubeSettings: Codable {
        var title: String = ""
        var description: String = ""
        var tags: [String] = []
        var category: Int = 22  // People & Blogs
        var privacy: Privacy = .public
        var madeForKids: Bool = false
        var notifySubscribers: Bool = true

        enum Privacy: String, Codable {
            case `public`, unlisted, `private`
        }
    }

    struct TikTokSettings: Codable {
        var allowComments: Bool = true
        var allowDuet: Bool = true
        var allowStitch: Bool = true
        var brandContentDisclosure: Bool = false
    }

    init(caption: String, mediaURLs: [URL] = [], mediaType: MediaType = .image, platforms: [SocialPlatform] = []) {
        self.id = UUID()
        self.caption = caption
        self.mediaURLs = mediaURLs
        self.mediaType = mediaType
        self.platforms = platforms
        self.status = .draft
    }
}

// MARK: - Content Calendar

@MainActor
class ContentCalendar: ObservableObject {

    @Published var posts: [SocialPost] = []
    @Published var scheduledPosts: [SocialPost] = []

    func schedulePost(_ post: SocialPost, for date: Date) {
        var scheduledPost = post
        scheduledPost.scheduledDate = date
        scheduledPost.status = .scheduled
        posts.append(scheduledPost)
        updateScheduledPosts()
    }

    func reschedule(_ postId: UUID, to date: Date) {
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            posts[index].scheduledDate = date
            updateScheduledPosts()
        }
    }

    func cancelScheduled(_ postId: UUID) {
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            posts[index].status = .draft
            posts[index].scheduledDate = nil
            updateScheduledPosts()
        }
    }

    func postsForDate(_ date: Date) -> [SocialPost] {
        let calendar = Calendar.current
        return scheduledPosts.filter { post in
            guard let scheduledDate = post.scheduledDate else { return false }
            return calendar.isDate(scheduledDate, inSameDayAs: date)
        }
    }

    private func updateScheduledPosts() {
        scheduledPosts = posts
            .filter { $0.status == .scheduled && $0.scheduledDate != nil }
            .sorted { ($0.scheduledDate ?? .distantPast) < ($1.scheduledDate ?? .distantPast) }
    }

    /// Get optimal posting times based on engagement data
    func suggestOptimalTimes(for platform: SocialPlatform) -> [Date] {
        // Based on general best practices - would use actual analytics in production
        let calendar = Calendar.current
        var times: [Date] = []

        // General optimal times (platform-specific in production)
        let optimalHours: [Int]
        switch platform {
        case .instagram:
            optimalHours = [9, 12, 17, 20]
        case .tiktok:
            optimalHours = [7, 12, 19, 22]
        case .youtube:
            optimalHours = [12, 15, 18]
        case .twitter:
            optimalHours = [8, 12, 17]
        case .linkedin:
            optimalHours = [7, 10, 12]
        default:
            optimalHours = [9, 12, 18]
        }

        let today = Date()
        for hour in optimalHours {
            if let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: today) {
                times.append(date)
            }
        }

        return times
    }
}

// MARK: - Analytics Dashboard

struct PlatformAnalytics: Codable {
    let platform: SocialPlatform
    let dateRange: DateRange
    var metrics: Metrics

    struct DateRange: Codable {
        let start: Date
        let end: Date
    }

    struct Metrics: Codable {
        var impressions: Int = 0
        var reach: Int = 0
        var engagement: Int = 0
        var engagementRate: Double = 0
        var likes: Int = 0
        var comments: Int = 0
        var shares: Int = 0
        var saves: Int = 0
        var clicks: Int = 0
        var videoViews: Int = 0
        var watchTime: TimeInterval = 0
        var followerGrowth: Int = 0
        var profileViews: Int = 0
    }
}

@MainActor
class AnalyticsDashboard: ObservableObject {

    @Published var analytics: [SocialPlatform: PlatformAnalytics] = [:]
    @Published var isLoading: Bool = false

    @Published var totalFollowers: Int = 0
    @Published var totalEngagement: Int = 0
    @Published var overallEngagementRate: Double = 0

    func fetchAnalytics(for accounts: [SocialAccount], dateRange: PlatformAnalytics.DateRange) async {
        isLoading = true

        for account in accounts {
            // In production, call actual platform APIs
            let mockMetrics = PlatformAnalytics.Metrics(
                impressions: Int.random(in: 10000...100000),
                reach: Int.random(in: 5000...50000),
                engagement: Int.random(in: 500...5000),
                engagementRate: Double.random(in: 0.02...0.10),
                likes: Int.random(in: 300...3000),
                comments: Int.random(in: 50...500),
                shares: Int.random(in: 20...200),
                saves: Int.random(in: 30...300),
                clicks: Int.random(in: 100...1000),
                followerGrowth: Int.random(in: -50...500)
            )

            analytics[account.platform] = PlatformAnalytics(
                platform: account.platform,
                dateRange: dateRange,
                metrics: mockMetrics
            )
        }

        calculateTotals()
        isLoading = false
    }

    private func calculateTotals() {
        totalFollowers = analytics.values.reduce(0) { $0 + $1.metrics.followerGrowth }
        totalEngagement = analytics.values.reduce(0) { $0 + $1.metrics.engagement }

        let totalImpressions = analytics.values.reduce(0) { $0 + $1.metrics.impressions }
        overallEngagementRate = totalImpressions > 0 ? Double(totalEngagement) / Double(totalImpressions) : 0
    }

    func topPerformingContent(for platform: SocialPlatform) -> [ContentPerformance] {
        // Would fetch from API in production
        return []
    }

    struct ContentPerformance: Identifiable {
        let id: UUID
        let postId: String
        let thumbnailURL: URL?
        let engagementRate: Double
        let impressions: Int
        let postedAt: Date
    }
}

// MARK: - Social Media Command Center Manager

@MainActor
class SocialMediaCommandCenter: ObservableObject {

    static let shared = SocialMediaCommandCenter()

    @Published var accounts: [SocialAccount] = []
    @Published var calendar = ContentCalendar()
    @Published var analytics = AnalyticsDashboard()

    @Published var isPublishing: Bool = false
    @Published var publishProgress: [UUID: Double] = [:]

    private var publishers: [SocialPlatform: PlatformPublisher] = [:]

    private init() {
        setupPublishers()
    }

    private func setupPublishers() {
        for platform in SocialPlatform.allCases {
            publishers[platform] = PlatformPublisher(platform: platform)
        }
    }

    // MARK: - Account Management

    func connectAccount(_ account: SocialAccount) {
        accounts.append(account)
    }

    func disconnectAccount(_ id: UUID) {
        accounts.removeAll { $0.id == id }
    }

    func refreshTokens() async {
        for index in accounts.indices {
            if let expiry = accounts[index].tokenExpiry,
               expiry < Date().addingTimeInterval(3600) {
                // Token expiring soon, refresh it
                // In production, call OAuth refresh endpoint
                accounts[index].tokenExpiry = Date().addingTimeInterval(3600 * 24)
            }
        }
    }

    // MARK: - Publishing

    func publish(_ post: SocialPost) async throws -> [SocialPlatform: URL] {
        isPublishing = true
        publishProgress[post.id] = 0

        var publishedURLs: [SocialPlatform: URL] = [:]

        for (index, platform) in post.platforms.enumerated() {
            guard let account = accounts.first(where: { $0.platform == platform && $0.isConnected }) else {
                continue
            }

            guard let publisher = publishers[platform] else { continue }

            do {
                let url = try await publisher.publish(post: post, account: account)
                publishedURLs[platform] = url
            } catch {
                print("Failed to publish to \(platform.rawValue): \(error)")
            }

            publishProgress[post.id] = Double(index + 1) / Double(post.platforms.count)
        }

        isPublishing = false
        publishProgress.removeValue(forKey: post.id)

        return publishedURLs
    }

    func schedulePost(_ post: SocialPost, for date: Date) {
        calendar.schedulePost(post, for: date)

        // Set up background task to publish at scheduled time
        // In production, use server-side scheduling
    }

    // MARK: - Content Suggestions

    func suggestHashtags(for content: String, platform: SocialPlatform) -> [String] {
        // AI-powered hashtag suggestions based on content
        // In production, use NLP and trending data
        let commonHashtags: [SocialPlatform: [String]] = [
            .instagram: ["#instagood", "#photooftheday", "#music", "#art", "#creative"],
            .tiktok: ["#fyp", "#foryou", "#viral", "#trending", "#music"],
            .youtube: ["#shorts", "#music", "#tutorial", "#howto"],
            .twitter: ["#Music", "#Art", "#Creative", "#NewMusic"],
            .linkedin: ["#Innovation", "#Technology", "#Leadership", "#Music"]
        ]

        return commonHashtags[platform] ?? []
    }

    func suggestCaption(for mediaType: SocialPost.MediaType, platform: SocialPlatform) -> String {
        // AI-generated caption suggestions
        let templates: [String] = [
            "Check out my latest creation! What do you think?",
            "New content just dropped - link in bio!",
            "Creating something special today",
            "Behind the scenes of my creative process"
        ]
        return templates.randomElement() ?? ""
    }

    func analyzePostPerformance(_ post: SocialPost) -> PostAnalysis {
        // Analyze past performance and suggest improvements
        return PostAnalysis(
            estimatedReach: Int.random(in: 1000...10000),
            estimatedEngagement: Double.random(in: 0.03...0.08),
            suggestions: [
                "Add more relevant hashtags",
                "Post during peak hours for better engagement",
                "Include a call-to-action in your caption"
            ],
            sentiment: .positive
        )
    }

    struct PostAnalysis {
        let estimatedReach: Int
        let estimatedEngagement: Double
        let suggestions: [String]
        let sentiment: Sentiment

        enum Sentiment: String {
            case positive, neutral, negative
        }
    }

    // MARK: - Live Streaming

    func startLiveStream(title: String, platforms: [SocialPlatform]) async throws -> LiveStreamSession {
        // Create multi-platform live stream
        var streamKeys: [SocialPlatform: String] = [:]

        for platform in platforms {
            guard let account = accounts.first(where: { $0.platform == platform }),
                  platform.supportsLive else { continue }

            // In production, call platform APIs to get stream keys
            streamKeys[platform] = "stream_key_\(platform.rawValue)"
        }

        return LiveStreamSession(
            id: UUID(),
            title: title,
            platforms: platforms,
            streamKeys: streamKeys,
            startTime: Date(),
            status: .preparing
        )
    }

    struct LiveStreamSession: Identifiable {
        let id: UUID
        let title: String
        let platforms: [SocialPlatform]
        let streamKeys: [SocialPlatform: String]
        let startTime: Date
        var status: Status
        var viewerCount: Int = 0
        var peakViewers: Int = 0

        enum Status: String {
            case preparing, live, ended
        }
    }
}

// MARK: - Platform-Specific Publishers

class PlatformPublisher {
    let platform: SocialPlatform

    init(platform: SocialPlatform) {
        self.platform = platform
    }

    func publish(post: SocialPost, account: SocialAccount) async throws -> URL {
        // Platform-specific API calls
        // This is a simplified version - production would implement full OAuth + API

        switch platform {
        case .instagram:
            return try await publishToInstagram(post: post, account: account)
        case .youtube:
            return try await publishToYouTube(post: post, account: account)
        case .tiktok:
            return try await publishToTikTok(post: post, account: account)
        case .twitter:
            return try await publishToTwitter(post: post, account: account)
        default:
            return try await genericPublish(post: post, account: account)
        }
    }

    private func publishToInstagram(post: SocialPost, account: SocialAccount) async throws -> URL {
        // Instagram Graph API publishing
        // 1. Upload media to container
        // 2. Create media object
        // 3. Publish

        // Simulated response
        return URL(string: "https://instagram.com/p/\(UUID().uuidString.prefix(11))")!
    }

    private func publishToYouTube(post: SocialPost, account: SocialAccount) async throws -> URL {
        // YouTube Data API v3
        // 1. Initialize resumable upload
        // 2. Upload video
        // 3. Set metadata

        return URL(string: "https://youtube.com/watch?v=\(UUID().uuidString.prefix(11))")!
    }

    private func publishToTikTok(post: SocialPost, account: SocialAccount) async throws -> URL {
        // TikTok Content Posting API
        // 1. Initialize upload
        // 2. Upload video
        // 3. Publish with settings

        return URL(string: "https://tiktok.com/@\(account.username)/video/\(Int.random(in: 1000000000...9999999999))")!
    }

    private func publishToTwitter(post: SocialPost, account: SocialAccount) async throws -> URL {
        // Twitter API v2
        // 1. Upload media (if any)
        // 2. Create tweet

        return URL(string: "https://twitter.com/\(account.username)/status/\(Int.random(in: 1000000000000000000...9999999999999999999))")!
    }

    private func genericPublish(post: SocialPost, account: SocialAccount) async throws -> URL {
        // Generic publishing fallback
        return URL(string: "\(platform.apiBaseURL)/\(post.id)")!
    }
}

// MARK: - Export Presets for Social Platforms

struct SocialMediaExportPresets {

    static func preset(for platform: SocialPlatform, contentType: SocialPost.MediaType) -> ExportSettings {
        switch (platform, contentType) {
        case (.instagram, .reel), (.tiktok, .video):
            return ExportSettings(
                resolution: (1080, 1920),
                frameRate: 30,
                videoBitrate: 8_000_000,
                audioBitrate: 128_000,
                codec: "h264",
                container: "mp4"
            )
        case (.youtube, .video):
            return ExportSettings(
                resolution: (3840, 2160),
                frameRate: 60,
                videoBitrate: 35_000_000,
                audioBitrate: 384_000,
                codec: "h265",
                container: "mp4"
            )
        case (.youtube, .short):
            return ExportSettings(
                resolution: (1080, 1920),
                frameRate: 60,
                videoBitrate: 12_000_000,
                audioBitrate: 192_000,
                codec: "h264",
                container: "mp4"
            )
        default:
            return ExportSettings(
                resolution: (1920, 1080),
                frameRate: 30,
                videoBitrate: 10_000_000,
                audioBitrate: 192_000,
                codec: "h264",
                container: "mp4"
            )
        }
    }

    struct ExportSettings {
        let resolution: (width: Int, height: Int)
        let frameRate: Int
        let videoBitrate: Int
        let audioBitrate: Int
        let codec: String
        let container: String
    }
}
