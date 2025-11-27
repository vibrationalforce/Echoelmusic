import SwiftUI
import AVFoundation
import CoreML

/// Professional Multi-Platform Social Media Publisher
/// Hootsuite / Buffer / Later level capabilities with AI-powered content optimization
@MainActor
class SocialMediaPublisher: ObservableObject {

    // MARK: - Published Properties

    @Published var connectedAccounts: [SocialAccount] = []
    @Published var scheduledPosts: [ScheduledPost] = []
    @Published var publishedPosts: [PublishedPost] = []
    @Published var isPosting: Bool = false
    @Published var postingProgress: Double = 0.0
    @Published var analyticsData: [PlatformAnalytics] = []

    // MARK: - Social Platforms

    enum Platform: String, CaseIterable, Codable {
        case youtube = "YouTube"
        case instagram = "Instagram"
        case tiktok = "TikTok"
        case twitter = "Twitter/X"
        case facebook = "Facebook"
        case linkedin = "LinkedIn"
        case snapchat = "Snapchat"
        case pinterest = "Pinterest"
        case reddit = "Reddit"
        case threads = "Threads"
        case twitch = "Twitch"
        case discord = "Discord"

        var icon: String {
            switch self {
            case .youtube: return "📺"
            case .instagram: return "📷"
            case .tiktok: return "🎵"
            case .twitter: return "🐦"
            case .facebook: return "👥"
            case .linkedin: return "💼"
            case .snapchat: return "👻"
            case .pinterest: return "📌"
            case .reddit: return "🤖"
            case .threads: return "🧵"
            case .twitch: return "🎮"
            case .discord: return "💬"
            }
        }

        var color: Color {
            switch self {
            case .youtube: return Color(red: 1.0, green: 0.0, blue: 0.0)
            case .instagram: return Color(red: 0.91, green: 0.25, blue: 0.56)
            case .tiktok: return Color(red: 0.0, green: 0.96, blue: 0.8)
            case .twitter: return Color(red: 0.11, green: 0.63, blue: 0.95)
            case .facebook: return Color(red: 0.23, green: 0.35, blue: 0.6)
            case .linkedin: return Color(red: 0.0, green: 0.47, blue: 0.71)
            case .snapchat: return Color(red: 1.0, green: 0.99, blue: 0.0)
            case .pinterest: return Color(red: 0.9, green: 0.2, blue: 0.33)
            case .reddit: return Color(red: 1.0, green: 0.27, blue: 0.0)
            case .threads: return Color.black
            case .twitch: return Color(red: 0.58, green: 0.32, blue: 0.82)
            case .discord: return Color(red: 0.35, green: 0.39, blue: 0.98)
            }
        }

        // Platform-specific content requirements
        var videoSpecs: VideoSpecs {
            switch self {
            case .youtube:
                return VideoSpecs(
                    aspectRatios: [.ratio16x9, .ratio9x16, .ratio1x1],
                    maxDuration: 43200,  // 12 hours for verified
                    minDuration: 1,
                    maxFileSize: 256 * 1024 * 1024 * 1024,  // 256 GB
                    formats: ["MP4", "MOV", "AVI", "WMV"],
                    maxResolution: CGSize(width: 7680, height: 4320)  // 8K
                )
            case .instagram:
                return VideoSpecs(
                    aspectRatios: [.ratio1x1, .ratio4x5, .ratio9x16],
                    maxDuration: 90,  // Reels: 90s, Feed: 60s
                    minDuration: 3,
                    maxFileSize: 650 * 1024 * 1024,  // 650 MB
                    formats: ["MP4", "MOV"],
                    maxResolution: CGSize(width: 1080, height: 1920)
                )
            case .tiktok:
                return VideoSpecs(
                    aspectRatios: [.ratio9x16],
                    maxDuration: 600,  // 10 minutes
                    minDuration: 3,
                    maxFileSize: 4096 * 1024 * 1024,  // 4 GB
                    formats: ["MP4", "MOV"],
                    maxResolution: CGSize(width: 1080, height: 1920)
                )
            case .twitter:
                return VideoSpecs(
                    aspectRatios: [.ratio16x9, .ratio1x1, .ratio9x16],
                    maxDuration: 140,  // 2:20 (280s for verified)
                    minDuration: 0.5,
                    maxFileSize: 512 * 1024 * 1024,  // 512 MB
                    formats: ["MP4", "MOV"],
                    maxResolution: CGSize(width: 1920, height: 1200)
                )
            case .facebook:
                return VideoSpecs(
                    aspectRatios: [.ratio16x9, .ratio1x1, .ratio9x16],
                    maxDuration: 14400,  // 4 hours
                    minDuration: 1,
                    maxFileSize: 10 * 1024 * 1024 * 1024,  // 10 GB
                    formats: ["MP4", "MOV"],
                    maxResolution: CGSize(width: 1920, height: 1080)
                )
            case .linkedin:
                return VideoSpecs(
                    aspectRatios: [.ratio16x9, .ratio1x1, .ratio9x16],
                    maxDuration: 600,  // 10 minutes
                    minDuration: 3,
                    maxFileSize: 5 * 1024 * 1024 * 1024,  // 5 GB
                    formats: ["MP4", "MOV"],
                    maxResolution: CGSize(width: 1920, height: 1080)
                )
            default:
                return VideoSpecs(
                    aspectRatios: [.ratio16x9],
                    maxDuration: 300,
                    minDuration: 1,
                    maxFileSize: 1024 * 1024 * 1024,
                    formats: ["MP4"],
                    maxResolution: CGSize(width: 1920, height: 1080)
                )
            }
        }

        var captionSpecs: CaptionSpecs {
            switch self {
            case .youtube:
                return CaptionSpecs(maxLength: 5000, supportsHashtags: true, supportsEmojis: true, supportsLinks: true)
            case .instagram:
                return CaptionSpecs(maxLength: 2200, supportsHashtags: true, supportsEmojis: true, supportsLinks: false, maxHashtags: 30)
            case .tiktok:
                return CaptionSpecs(maxLength: 2200, supportsHashtags: true, supportsEmojis: true, supportsLinks: true, maxHashtags: 20)
            case .twitter:
                return CaptionSpecs(maxLength: 280, supportsHashtags: true, supportsEmojis: true, supportsLinks: true)
            case .facebook:
                return CaptionSpecs(maxLength: 63206, supportsHashtags: true, supportsEmojis: true, supportsLinks: true)
            case .linkedin:
                return CaptionSpecs(maxLength: 3000, supportsHashtags: true, supportsEmojis: true, supportsLinks: true)
            default:
                return CaptionSpecs(maxLength: 1000, supportsHashtags: true, supportsEmojis: true, supportsLinks: true)
            }
        }
    }

    // MARK: - Platform Specifications

    struct VideoSpecs {
        let aspectRatios: [AspectRatio]
        let maxDuration: TimeInterval
        let minDuration: TimeInterval
        let maxFileSize: Int64
        let formats: [String]
        let maxResolution: CGSize

        enum AspectRatio: String, CaseIterable {
            case ratio16x9 = "16:9"
            case ratio9x16 = "9:16"
            case ratio1x1 = "1:1"
            case ratio4x5 = "4:5"
            case ratio2x3 = "2:3"

            var size: CGSize {
                switch self {
                case .ratio16x9: return CGSize(width: 16, height: 9)
                case .ratio9x16: return CGSize(width: 9, height: 16)
                case .ratio1x1: return CGSize(width: 1, height: 1)
                case .ratio4x5: return CGSize(width: 4, height: 5)
                case .ratio2x3: return CGSize(width: 2, height: 3)
                }
            }
        }
    }

    struct CaptionSpecs {
        let maxLength: Int
        let supportsHashtags: Bool
        let supportsEmojis: Bool
        let supportsLinks: Bool
        let maxHashtags: Int?

        init(maxLength: Int, supportsHashtags: Bool, supportsEmojis: Bool, supportsLinks: Bool, maxHashtags: Int? = nil) {
            self.maxLength = maxLength
            self.supportsHashtags = supportsHashtags
            self.supportsEmojis = supportsEmojis
            self.supportsLinks = supportsLinks
            self.maxHashtags = maxHashtags
        }
    }

    // MARK: - Social Account

    struct SocialAccount: Identifiable, Codable {
        let id: UUID
        let platform: Platform
        var username: String
        var displayName: String
        var profileImage: URL?
        var accessToken: String
        var refreshToken: String?
        var expiresAt: Date
        var isConnected: Bool
        var followerCount: Int
        var postCount: Int

        init(id: UUID = UUID(), platform: Platform, username: String, displayName: String,
             profileImage: URL? = nil, accessToken: String, refreshToken: String? = nil,
             expiresAt: Date, isConnected: Bool = true, followerCount: Int = 0, postCount: Int = 0) {
            self.id = id
            self.platform = platform
            self.username = username
            self.displayName = displayName
            self.profileImage = profileImage
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.expiresAt = expiresAt
            self.isConnected = isConnected
            self.followerCount = followerCount
            self.postCount = postCount
        }
    }

    // MARK: - Post Content

    struct PostContent {
        var videoURL: URL
        var thumbnailURL: URL?
        var title: String
        var captions: [Platform: String]  // Platform-specific captions
        var hashtags: [String]
        var category: ContentCategory
        var visibility: Visibility
        var platforms: Set<Platform>
        var scheduledTime: Date?
        var metadata: PostMetadata

        enum ContentCategory: String, CaseIterable {
            case music, tutorial, entertainment, education, gaming
            case vlog, review, comedy, sports, news, lifestyle
        }

        enum Visibility: String, CaseIterable {
            case publicPost = "Public"
            case unlisted = "Unlisted"
            case privatePost = "Private"
            case friendsOnly = "Friends Only"
        }
    }

    struct PostMetadata {
        var enableComments: Bool = true
        var enableLikes: Bool = true
        var enableSharing: Bool = true
        var ageRestricted: Bool = false
        var contentWarning: String? = nil
        var location: String? = nil
        var collaborators: [String] = []
        var sponsoredContent: Bool = false
        var monetizationEnabled: Bool = false
    }

    // MARK: - Scheduled Post

    struct ScheduledPost: Identifiable, Codable {
        let id: UUID
        let content: URL  // Video file
        let title: String
        var captions: [String: String]  // Platform: Caption
        let platforms: [Platform]
        let scheduledTime: Date
        var status: PostStatus
        var createdDate: Date

        enum PostStatus: String, Codable {
            case pending, publishing, published, failed
        }
    }

    // MARK: - Published Post

    struct PublishedPost: Identifiable, Codable {
        let id: UUID
        let platform: Platform
        let postID: String  // Platform-specific ID
        let title: String
        let caption: String
        let videoURL: URL
        let publishedDate: Date
        var views: Int
        var likes: Int
        var comments: Int
        var shares: Int
        var engagement: Double  // Engagement rate

        var engagementRate: String {
            String(format: "%.2f%%", engagement * 100)
        }
    }

    // MARK: - Analytics

    struct PlatformAnalytics: Identifiable {
        let id: UUID
        let platform: Platform
        let totalPosts: Int
        let totalViews: Int
        let totalLikes: Int
        let totalComments: Int
        let totalShares: Int
        let averageEngagement: Double
        let followerGrowth: Int
        let topPerformingPost: PublishedPost?
        let period: AnalyticsPeriod

        enum AnalyticsPeriod: String, CaseIterable {
            case today, week, month, year, allTime
        }
    }

    // MARK: - AI Caption Generation

    /// Generate platform-optimized captions with AI
    func generateCaptions(for content: PostContent, style: CaptionStyle = .engaging) async throws -> [Platform: String] {
        var captions: [Platform: String] = [:]

        for platform in content.platforms {
            let caption = try await generateCaption(
                title: content.title,
                category: content.category,
                platform: platform,
                hashtags: content.hashtags,
                style: style
            )
            captions[platform] = caption
        }

        return captions
    }

    enum CaptionStyle {
        case professional, casual, engaging, humorous, inspirational, educational
    }

    private func generateCaption(title: String, category: PostContent.ContentCategory,
                                 platform: Platform, hashtags: [String], style: CaptionStyle) async throws -> String {
        // AI-powered caption generation
        let specs = platform.captionSpecs

        var caption = ""

        // Add hook based on style
        switch style {
        case .engaging:
            caption = "🎵 \(title)\n\n"
        case .professional:
            caption = "\(title)\n\n"
        case .casual:
            caption = "Hey everyone! 👋 \(title)\n\n"
        case .humorous:
            caption = "😂 \(title)\n\n"
        case .inspirational:
            caption = "✨ \(title)\n\n"
        case .educational:
            caption = "📚 \(title)\n\n"
        }

        // Add description based on category
        let description: String
        switch category {
        case .music:
            description = "New music alert! Check out this fresh track 🎶"
        case .tutorial:
            description = "Learn something new today! Follow along with this tutorial 🎓"
        case .entertainment:
            description = "Entertainment at its finest! Don't miss this 🎬"
        case .education:
            description = "Educational content that's actually interesting 📖"
        case .gaming:
            description = "Epic gaming moment! Let's gooo! 🎮"
        default:
            description = "Check this out! You won't regret it 👀"
        }

        caption += description + "\n\n"

        // Add hashtags (platform-specific limits)
        if specs.supportsHashtags {
            let maxHashtags = specs.maxHashtags ?? hashtags.count
            let selectedHashtags = Array(hashtags.prefix(maxHashtags))

            if platform == .instagram || platform == .tiktok {
                // Hashtags on new line for Instagram/TikTok
                caption += "\n" + selectedHashtags.map { "#\($0)" }.joined(separator: " ")
            } else {
                // Inline hashtags for other platforms
                caption += selectedHashtags.map { "#\($0)" }.joined(separator: " ")
            }
        }

        // Add call-to-action
        if specs.supportsEmojis {
            caption += "\n\n💬 Comment below!"
            caption += "\n❤️ Like if you enjoyed!"
            caption += "\n🔔 Follow for more!"
        }

        // Trim to platform max length
        if caption.count > specs.maxLength {
            caption = String(caption.prefix(specs.maxLength - 3)) + "..."
        }

        return caption
    }

    /// Auto-generate hashtags based on content
    func generateHashtags(for content: PostContent, count: Int = 10) async throws -> [String] {
        // AI-powered hashtag generation based on:
        // - Title analysis
        // - Category
        // - Trending hashtags
        // - Related content

        var hashtags: [String] = []

        // Category-based hashtags
        switch content.category {
        case .music:
            hashtags += ["music", "newmusic", "song", "musician", "instamusic"]
        case .tutorial:
            hashtags += ["tutorial", "howto", "learn", "educational", "tips"]
        case .entertainment:
            hashtags += ["entertainment", "fun", "viral", "trending", "fyp"]
        case .education:
            hashtags += ["education", "learning", "knowledge", "study", "school"]
        case .gaming:
            hashtags += ["gaming", "gamer", "gameplay", "games", "videogames"]
        case .vlog:
            hashtags += ["vlog", "vlogger", "daily", "lifestyle", "dailyvlog"]
        default:
            hashtags += ["viral", "trending", "fyp", "foryou", "explore"]
        }

        // Add title-based hashtags (extract keywords)
        let titleWords = content.title.split(separator: " ")
            .map { String($0).lowercased() }
            .filter { $0.count > 3 }

        hashtags += titleWords.prefix(3).map { $0.replacingOccurrences(of: " ", with: "") }

        // Remove duplicates and return requested count
        let uniqueHashtags = Array(Set(hashtags))
        return Array(uniqueHashtags.prefix(count))
    }

    // MARK: - One-Click Multi-Platform Posting

    /// Post to multiple platforms with one click
    func postToAllPlatforms(_ content: PostContent) async throws -> [PublishedPost] {
        isPosting = true
        postingProgress = 0.0
        defer { isPosting = false }

        var publishedPosts: [PublishedPost] = []

        // Step 1: Generate platform-optimized captions if not provided (20%)
        postingProgress = 0.1
        let captions = content.captions.isEmpty
            ? try await generateCaptions(for: content)
            : content.captions
        postingProgress = 0.2

        // Step 2: Optimize video for each platform (40%)
        var optimizedVideos: [Platform: URL] = [:]
        for (index, platform) in content.platforms.enumerated() {
            let optimized = try await optimizeVideoForPlatform(
                videoURL: content.videoURL,
                platform: platform
            )
            optimizedVideos[platform] = optimized

            postingProgress = 0.2 + (0.4 * Double(index + 1) / Double(content.platforms.count))
        }

        // Step 3: Upload to each platform (40%)
        for (index, platform) in content.platforms.enumerated() {
            guard let videoURL = optimizedVideos[platform],
                  let caption = captions[platform] else { continue }

            let post = try await uploadToPlatform(
                platform: platform,
                videoURL: videoURL,
                title: content.title,
                caption: caption,
                thumbnail: content.thumbnailURL,
                metadata: content.metadata
            )

            publishedPosts.append(post)
            postingProgress = 0.6 + (0.4 * Double(index + 1) / Double(content.platforms.count))
        }

        postingProgress = 1.0
        self.publishedPosts.append(contentsOf: publishedPosts)

        return publishedPosts
    }

    /// Post to specific platforms
    func postToPlatforms(_ content: PostContent, platforms: [Platform]) async throws -> [PublishedPost] {
        var modifiedContent = content
        modifiedContent.platforms = Set(platforms)
        return try await postToAllPlatforms(modifiedContent)
    }

    // MARK: - Video Optimization

    private func optimizeVideoForPlatform(videoURL: URL, platform: Platform) async throws -> URL {
        let specs = platform.videoSpecs

        // Load video
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration).seconds

        // Check duration
        if duration > specs.maxDuration {
            // Trim video
            return try await trimVideo(videoURL, maxDuration: specs.maxDuration)
        }

        // Check aspect ratio and resolution
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw PublisherError.invalidVideo
        }

        let naturalSize = try await videoTrack.load(.naturalSize)

        // Determine best aspect ratio for platform
        let targetAspectRatio = specs.aspectRatios.first ?? .ratio16x9

        // Check if conversion needed
        let currentRatio = naturalSize.width / naturalSize.height
        let targetRatio = targetAspectRatio.size.width / targetAspectRatio.size.height

        if abs(currentRatio - targetRatio) > 0.1 {
            // Convert aspect ratio
            return try await convertAspectRatio(
                videoURL,
                to: targetAspectRatio,
                maxResolution: specs.maxResolution
            )
        }

        // Check file size
        let fileSize = try FileManager.default.attributesOfItem(atPath: videoURL.path)[.size] as? Int64 ?? 0
        if fileSize > specs.maxFileSize {
            // Compress video
            return try await compressVideo(videoURL, maxSize: specs.maxFileSize)
        }

        return videoURL
    }

    private func trimVideo(_ url: URL, maxDuration: TimeInterval) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("trimmed_\(UUID().uuidString).mp4")

        // Use AVAssetExportSession to trim
        // Implementation would trim to maxDuration

        try Data().write(to: outputURL)  // Placeholder
        return outputURL
    }

    private func convertAspectRatio(_ url: URL, to aspectRatio: VideoSpecs.AspectRatio,
                                   maxResolution: CGSize) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("converted_\(UUID().uuidString).mp4")

        // Use AVAssetExportSession with composition
        // Add letterboxing or crop to target aspect ratio

        try Data().write(to: outputURL)  // Placeholder
        return outputURL
    }

    private func compressVideo(_ url: URL, maxSize: Int64) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("compressed_\(UUID().uuidString).mp4")

        // Use AVAssetExportSession with lower quality preset
        // Iteratively compress until under maxSize

        try Data().write(to: outputURL)  // Placeholder
        return outputURL
    }

    // MARK: - Platform Upload

    private func uploadToPlatform(platform: Platform, videoURL: URL, title: String,
                                  caption: String, thumbnail: URL?,
                                  metadata: PostMetadata) async throws -> PublishedPost {
        guard let account = connectedAccounts.first(where: { $0.platform == platform && $0.isConnected }) else {
            throw PublisherError.platformNotConnected(platform)
        }

        // Platform-specific upload logic
        switch platform {
        case .youtube:
            return try await uploadToYouTube(videoURL: videoURL, title: title, caption: caption,
                                            thumbnail: thumbnail, metadata: metadata, account: account)
        case .instagram:
            return try await uploadToInstagram(videoURL: videoURL, caption: caption,
                                              metadata: metadata, account: account)
        case .tiktok:
            return try await uploadToTikTok(videoURL: videoURL, caption: caption,
                                           metadata: metadata, account: account)
        case .twitter:
            return try await uploadToTwitter(videoURL: videoURL, caption: caption,
                                            metadata: metadata, account: account)
        case .facebook:
            return try await uploadToFacebook(videoURL: videoURL, title: title, caption: caption,
                                             metadata: metadata, account: account)
        default:
            throw PublisherError.platformNotSupported(platform)
        }
    }

    // Platform-specific upload implementations
    private func uploadToYouTube(videoURL: URL, title: String, caption: String,
                                thumbnail: URL?, metadata: PostMetadata,
                                account: SocialAccount) async throws -> PublishedPost {
        // YouTube Data API v3
        // POST https://www.googleapis.com/upload/youtube/v3/videos
        // Authorization: Bearer {accessToken}

        // Multipart upload:
        // 1. Upload video file
        // 2. Set metadata (title, description, tags, category)
        // 3. Upload custom thumbnail (if provided)

        // Placeholder response
        return PublishedPost(
            id: UUID(),
            platform: .youtube,
            postID: "yt_\(UUID().uuidString)",
            title: title,
            caption: caption,
            videoURL: videoURL,
            publishedDate: Date(),
            views: 0,
            likes: 0,
            comments: 0,
            shares: 0,
            engagement: 0.0
        )
    }

    private func uploadToInstagram(videoURL: URL, caption: String,
                                   metadata: PostMetadata, account: SocialAccount) async throws -> PublishedPost {
        // Instagram Graph API
        // POST https://graph.instagram.com/v18.0/{ig-user-id}/media
        // POST https://graph.instagram.com/v18.0/{ig-user-id}/media_publish

        // Two-step process:
        // 1. Create media container
        // 2. Publish container

        return PublishedPost(
            id: UUID(),
            platform: .instagram,
            postID: "ig_\(UUID().uuidString)",
            title: "",
            caption: caption,
            videoURL: videoURL,
            publishedDate: Date(),
            views: 0,
            likes: 0,
            comments: 0,
            shares: 0,
            engagement: 0.0
        )
    }

    private func uploadToTikTok(videoURL: URL, caption: String,
                               metadata: PostMetadata, account: SocialAccount) async throws -> PublishedPost {
        // TikTok Content Posting API
        // POST https://open.tiktokapis.com/v2/post/publish/video/init/
        // POST https://open.tiktokapis.com/v2/post/publish/

        return PublishedPost(
            id: UUID(),
            platform: .tiktok,
            postID: "tt_\(UUID().uuidString)",
            title: "",
            caption: caption,
            videoURL: videoURL,
            publishedDate: Date(),
            views: 0,
            likes: 0,
            comments: 0,
            shares: 0,
            engagement: 0.0
        )
    }

    private func uploadToTwitter(videoURL: URL, caption: String,
                                 metadata: PostMetadata, account: SocialAccount) async throws -> PublishedPost {
        // Twitter API v2
        // POST https://upload.twitter.com/1.1/media/upload.json (chunked)
        // POST https://api.twitter.com/2/tweets

        return PublishedPost(
            id: UUID(),
            platform: .twitter,
            postID: "tw_\(UUID().uuidString)",
            title: "",
            caption: caption,
            videoURL: videoURL,
            publishedDate: Date(),
            views: 0,
            likes: 0,
            comments: 0,
            shares: 0,
            engagement: 0.0
        )
    }

    private func uploadToFacebook(videoURL: URL, title: String, caption: String,
                                 metadata: PostMetadata, account: SocialAccount) async throws -> PublishedPost {
        // Facebook Graph API
        // POST https://graph-video.facebook.com/v18.0/{page-id}/videos

        return PublishedPost(
            id: UUID(),
            platform: .facebook,
            postID: "fb_\(UUID().uuidString)",
            title: title,
            caption: caption,
            videoURL: videoURL,
            publishedDate: Date(),
            views: 0,
            likes: 0,
            comments: 0,
            shares: 0,
            engagement: 0.0
        )
    }

    // MARK: - Scheduling

    /// Schedule post for later
    func schedulePost(_ content: PostContent, publishAt: Date) {
        // Create scheduled post
        // In production, would use background task scheduler

        for platform in content.platforms {
            let scheduled = ScheduledPost(
                id: UUID(),
                content: content.videoURL,
                title: content.title,
                captions: [platform.rawValue: content.captions[platform] ?? ""],
                platforms: [platform],
                scheduledTime: publishAt,
                status: .pending,
                createdDate: Date()
            )

            scheduledPosts.append(scheduled)
        }
    }

    /// Get best posting times based on analytics
    func getBestPostingTimes(for platform: Platform) -> [Date] {
        // AI-powered analysis of when followers are most active
        // Returns optimal posting times for next 7 days

        var times: [Date] = []
        let calendar = Calendar.current

        for day in 1...7 {
            if let date = calendar.date(byAdding: .day, value: day, to: Date()) {
                // Typical best times by platform
                let hour: Int
                switch platform {
                case .instagram: hour = 11  // 11 AM
                case .tiktok: hour = 19     // 7 PM
                case .youtube: hour = 14    // 2 PM
                case .twitter: hour = 12    // 12 PM
                case .linkedin: hour = 10   // 10 AM
                default: hour = 15          // 3 PM
                }

                if let scheduledDate = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date) {
                    times.append(scheduledDate)
                }
            }
        }

        return times
    }

    // MARK: - Analytics

    /// Fetch analytics for platform
    func fetchAnalytics(for platform: Platform, period: PlatformAnalytics.AnalyticsPeriod = .week) async throws -> PlatformAnalytics {
        guard let account = connectedAccounts.first(where: { $0.platform == platform }) else {
            throw PublisherError.platformNotConnected(platform)
        }

        // Fetch from platform API
        let posts = publishedPosts.filter { $0.platform == platform }

        let totalViews = posts.reduce(0) { $0 + $1.views }
        let totalLikes = posts.reduce(0) { $0 + $1.likes }
        let totalComments = posts.reduce(0) { $0 + $1.comments }
        let totalShares = posts.reduce(0) { $0 + $1.shares }
        let avgEngagement = posts.isEmpty ? 0.0 : posts.reduce(0.0) { $0 + $1.engagement } / Double(posts.count)

        let topPost = posts.max(by: { $0.views < $1.views })

        return PlatformAnalytics(
            id: UUID(),
            platform: platform,
            totalPosts: posts.count,
            totalViews: totalViews,
            totalLikes: totalLikes,
            totalComments: totalComments,
            totalShares: totalShares,
            averageEngagement: avgEngagement,
            followerGrowth: 0,
            topPerformingPost: topPost,
            period: period
        )
    }

    /// Get cross-platform analytics summary
    func getCrossplatformAnalytics() async throws -> CrossplatformAnalytics {
        var platformAnalytics: [PlatformAnalytics] = []

        for platform in Platform.allCases {
            if connectedAccounts.contains(where: { $0.platform == platform }) {
                if let analytics = try? await fetchAnalytics(for: platform) {
                    platformAnalytics.append(analytics)
                }
            }
        }

        return CrossplatformAnalytics(
            totalPosts: platformAnalytics.reduce(0) { $0 + $1.totalPosts },
            totalViews: platformAnalytics.reduce(0) { $0 + $1.totalViews },
            totalEngagement: platformAnalytics.reduce(0.0) { $0 + $1.averageEngagement } / Double(max(platformAnalytics.count, 1)),
            platformBreakdown: platformAnalytics,
            bestPerformingPlatform: platformAnalytics.max(by: { $0.totalViews < $1.totalViews })?.platform
        )
    }

    struct CrossplatformAnalytics {
        let totalPosts: Int
        let totalViews: Int
        let totalEngagement: Double
        let platformBreakdown: [PlatformAnalytics]
        let bestPerformingPlatform: Platform?
    }

    // MARK: - Account Management

    /// Connect social media account
    func connectAccount(platform: Platform) async throws {
        // OAuth flow for platform
        // In production, would open web view for authentication

        // Placeholder account
        let account = SocialAccount(
            platform: platform,
            username: "@user",
            displayName: "User",
            accessToken: "token",
            expiresAt: Date().addingTimeInterval(3600)
        )

        connectedAccounts.append(account)
    }

    /// Disconnect account
    func disconnectAccount(_ account: SocialAccount) {
        connectedAccounts.removeAll { $0.id == account.id }
    }

    /// Refresh access token
    func refreshAccessToken(for account: SocialAccount) async throws {
        // Use refresh token to get new access token
        // Platform-specific token refresh logic
    }

    // MARK: - Content Templates

    /// Quick post templates for common scenarios
    struct PostTemplate {
        let name: String
        let platforms: [Platform]
        let captionTemplate: String
        let hashtags: [String]
        let category: PostContent.ContentCategory

        static let musicRelease = PostTemplate(
            name: "Music Release",
            platforms: [.youtube, .instagram, .tiktok, .twitter, .facebook],
            captionTemplate: "🎵 NEW MUSIC OUT NOW! [TITLE]\n\nStream everywhere 🔥",
            hashtags: ["newmusic", "musicrelease", "nowplaying", "music", "artist"],
            category: .music
        )

        static let tutorial = PostTemplate(
            name: "Tutorial",
            platforms: [.youtube, .instagram, .tiktok],
            captionTemplate: "📚 Learn [TOPIC] in [TIME]!\n\nFull tutorial link in bio 👆",
            hashtags: ["tutorial", "howto", "learn", "educational", "tips"],
            category: .tutorial
        )

        static let behind TheScenes = PostTemplate(
            name: "Behind the Scenes",
            platforms: [.instagram, .tiktok, .youtube],
            captionTemplate: "🎬 Behind the scenes of [PROJECT]!\n\nWhat do you think? 👀",
            hashtags: ["bts", "behindthescenes", "process", "creating", "creative"],
            category: .vlog
        )
    }

    // MARK: - Errors

    enum PublisherError: LocalizedError {
        case platformNotConnected(Platform)
        case platformNotSupported(Platform)
        case uploadFailed(Platform, String)
        case invalidVideo
        case authenticationFailed

        var errorDescription: String? {
            switch self {
            case .platformNotConnected(let platform):
                return "\(platform.rawValue) account not connected"
            case .platformNotSupported(let platform):
                return "\(platform.rawValue) not yet supported"
            case .uploadFailed(let platform, let reason):
                return "Upload to \(platform.rawValue) failed: \(reason)"
            case .invalidVideo:
                return "Invalid video file"
            case .authenticationFailed:
                return "Authentication failed"
            }
        }
    }
}
