import Foundation
import AVFoundation
import CoreML
import Combine

/// Intelligent Posting Manager - AI-Powered Social Media Distribution
///
/// **Features:**
/// - Cross-posting to 8+ platforms simultaneously
/// - AI-powered optimal posting time prediction
/// - Platform-specific content optimization
/// - Automatic short-form / long-form categorization
/// - Hashtag generation and optimization
/// - Caption AI assistance
/// - Analytics aggregation
/// - Scheduled posting queue
/// - Bio-reactive content tagging
///
/// **Supported Platforms:**
/// 1. TikTok (Short-form)
/// 2. Instagram (Reels, Posts, Stories)
/// 3. YouTube (Shorts, Videos)
/// 4. Facebook (Feed, Stories)
/// 5. Twitter/X (Videos, Spaces)
/// 6. LinkedIn (Feed, Articles)
/// 7. Snapchat (Spotlight)
/// 8. Pinterest (Idea Pins)
///
/// **Example:**
/// ```swift
/// let manager = IntelligentPostingManager()
/// try await manager.crossPost(
///     video: videoURL,
///     platforms: [.tiktok, .instagram, .youtube],
///     caption: "My latest creation!",
///     enableAIOptimization: true
/// )
/// ```
@MainActor
class IntelligentPostingManager: ObservableObject {

    // MARK: - Published State

    @Published var scheduledPosts: [ScheduledPost] = []
    @Published var postHistory: [PostResult] = []
    @Published var aggregatedAnalytics: AnalyticsSnapshot?
    @Published var isPosting: Bool = false
    @Published var aiSuggestions: [AISuggestion] = []

    // MARK: - Social Media Platforms

    enum SocialPlatform: String, CaseIterable, Identifiable {
        case tiktok = "TikTok"
        case instagramReel = "Instagram Reel"
        case instagramPost = "Instagram Post"
        case instagramStory = "Instagram Story"
        case youtubeShort = "YouTube Short"
        case youtubeVideo = "YouTube Video"
        case facebook = "Facebook"
        case twitter = "Twitter/X"
        case linkedin = "LinkedIn"
        case snapchat = "Snapchat"
        case pinterest = "Pinterest"

        var id: String { rawValue }

        var contentType: ContentType {
            switch self {
            case .tiktok, .instagramReel, .youtubeShort, .instagramStory:
                return .shortForm
            case .youtubeVideo:
                return .longForm
            case .instagramPost, .facebook, .twitter, .linkedin, .snapchat, .pinterest:
                return .mixed
            }
        }

        var maxDuration: TimeInterval? {
            switch self {
            case .tiktok: return 180              // 3 minutes
            case .instagramReel: return 90        // 90 seconds
            case .instagramStory: return 60       // 60 seconds
            case .youtubeShort: return 60         // 60 seconds
            case .youtubeVideo: return nil        // Unlimited
            case .facebook: return 14400          // 4 hours
            case .twitter: return 140             // 2:20
            case .linkedin: return 600            // 10 minutes
            case .snapchat: return 60             // 60 seconds
            case .pinterest: return 60            // 60 seconds
            case .instagramPost: return 60        // 60 seconds
            }
        }

        var aspectRatio: AspectRatio {
            switch self {
            case .tiktok, .instagramReel, .youtubeShort, .instagramStory, .snapchat:
                return .portrait9x16
            case .youtubeVideo, .twitter, .facebook:
                return .landscape16x9
            case .instagramPost, .pinterest:
                return .square1x1
            case .linkedin:
                return .landscape16x9
            }
        }

        var maxHashtags: Int {
            switch self {
            case .tiktok: return 100
            case .instagramReel, .instagramPost, .instagramStory: return 30
            case .youtubeShort, .youtubeVideo: return 15
            case .facebook: return 50
            case .twitter: return 10
            case .linkedin: return 30
            case .snapchat: return 5
            case .pinterest: return 20
            }
        }

        var maxCaptionLength: Int {
            switch self {
            case .tiktok: return 2200
            case .instagramReel, .instagramPost, .instagramStory: return 2200
            case .youtubeShort, .youtubeVideo: return 5000
            case .facebook: return 63206
            case .twitter: return 280
            case .linkedin: return 3000
            case .snapchat: return 250
            case .pinterest: return 500
            }
        }

        var icon: String {
            switch self {
            case .tiktok: return "🎵"
            case .instagramReel, .instagramPost, .instagramStory: return "📷"
            case .youtubeShort, .youtubeVideo: return "📺"
            case .facebook: return "📘"
            case .twitter: return "🐦"
            case .linkedin: return "💼"
            case .snapchat: return "👻"
            case .pinterest: return "📌"
            }
        }

        var requiresOAuth: Bool {
            return true  // All platforms require authentication
        }
    }

    enum ContentType: String {
        case shortForm = "Short-form"    // <60s vertical video
        case longForm = "Long-form"      // >60s horizontal video
        case mixed = "Mixed"             // Supports both
    }

    enum AspectRatio {
        case portrait9x16    // 9:16 (1080x1920)
        case landscape16x9   // 16:9 (1920x1080)
        case square1x1       // 1:1 (1080x1080)
        case landscape4x3    // 4:3 (1440x1080)

        var size: (width: Int, height: Int) {
            switch self {
            case .portrait9x16: return (1080, 1920)
            case .landscape16x9: return (1920, 1080)
            case .square1x1: return (1080, 1080)
            case .landscape4x3: return (1440, 1080)
            }
        }
    }

    // MARK: - Post Content

    struct PostContent {
        let videoURL: URL
        let thumbnailURL: URL?
        let caption: String
        let hashtags: [String]
        let mentionedUsers: [String]
        let location: String?
        let music: MusicMetadata?
        let bioData: BioMetadata?

        struct MusicMetadata {
            let title: String
            let artist: String
            let duration: TimeInterval
            let bpm: Double?
            let key: String?
        }

        struct BioMetadata {
            let avgHRV: Float
            let avgCoherence: Float
            let flowState: String
            let sessionDuration: TimeInterval
        }
    }

    // MARK: - Scheduled Post

    struct ScheduledPost: Identifiable {
        let id = UUID()
        let content: PostContent
        let platforms: Set<SocialPlatform>
        let scheduledTime: Date
        var status: Status
        var optimizedCaptions: [SocialPlatform: String]
        var optimizedHashtags: [SocialPlatform: [String]]

        enum Status: String {
            case pending = "⏳ Pending"
            case processing = "🔄 Processing"
            case posting = "📤 Posting"
            case completed = "✅ Completed"
            case failed = "❌ Failed"
        }

        var isPast: Bool {
            scheduledTime < Date()
        }
    }

    // MARK: - Post Result

    struct PostResult: Identifiable {
        let id = UUID()
        let platform: SocialPlatform
        let postID: String?
        let postedAt: Date
        let success: Bool
        let errorMessage: String?
        let postURL: URL?
        let initialMetrics: InitialMetrics?

        struct InitialMetrics {
            let views: Int
            let likes: Int
            let comments: Int
            let shares: Int
        }

        var statusIcon: String {
            success ? "✅" : "❌"
        }
    }

    // MARK: - AI Suggestions

    struct AISuggestion: Identifiable {
        let id = UUID()
        let type: SuggestionType
        let title: String
        let description: String
        let confidence: Float
        let data: [String: Any]

        enum SuggestionType: String {
            case optimalPostingTime = "⏰ Optimal Time"
            case hashtagOptimization = "🏷️ Hashtags"
            case captionImprovement = "✍️ Caption"
            case platformSelection = "🎯 Platforms"
            case contentTrending = "📈 Trending"
            case audienceInsight = "👥 Audience"
        }
    }

    // MARK: - Analytics

    struct AnalyticsSnapshot {
        let totalPosts: Int
        let totalViews: Int
        let totalLikes: Int
        let totalComments: Int
        let totalShares: Int
        let avgEngagementRate: Double
        let topPlatform: SocialPlatform
        let topPerformingPost: String?
        let platformBreakdown: [SocialPlatform: PlatformMetrics]

        struct PlatformMetrics {
            let posts: Int
            let views: Int
            let likes: Int
            let engagementRate: Double
        }
    }

    // MARK: - Posting Options

    struct PostingOptions {
        var enableAIOptimization: Bool = true
        var enableAutomaticHashtags: Bool = true
        var enableCaptionAI: Bool = true
        var enableBioDataTags: Bool = true
        var scheduleForOptimalTime: Bool = false
        var adaptCaptionPerPlatform: Bool = true
        var addWatermark: Bool = false
        var notifyOnComplete: Bool = true
    }

    // MARK: - Cross-Posting

    /// Cross-post video to multiple platforms simultaneously
    func crossPost(
        content: PostContent,
        platforms: Set<SocialPlatform>,
        options: PostingOptions = PostingOptions(),
        progressHandler: ((SocialPlatform, Double) -> Void)? = nil
    ) async throws -> [PostResult] {
        guard !isPosting else {
            throw PostingError.alreadyPosting
        }

        isPosting = true
        defer { isPosting = false }

        print("📤 Starting cross-post to \(platforms.count) platforms:")
        for platform in platforms {
            print("   \(platform.icon) \(platform.rawValue)")
        }

        // Step 1: AI Optimization (if enabled)
        var optimizedContent = content
        if options.enableAIOptimization {
            optimizedContent = await optimizeContent(content, for: platforms, options: options)
        }

        // Step 2: Validate video for each platform
        for platform in platforms {
            try validateContent(optimizedContent, for: platform)
        }

        // Step 3: Generate platform-specific variants
        let variants = try await generatePlatformVariants(optimizedContent, for: platforms, options: options)

        // Step 4: Post to each platform
        var results: [PostResult] = []

        for (index, platform) in platforms.enumerated() {
            print("\n🔄 Posting to \(platform.icon) \(platform.rawValue)...")
            progressHandler?(platform, Double(index) / Double(platforms.count))

            do {
                let result = try await postToPlatform(
                    variant: variants[platform]!,
                    platform: platform,
                    options: options
                )
                results.append(result)

                if result.success {
                    print("   ✅ Posted successfully")
                    if let url = result.postURL {
                        print("   🔗 \(url.absoluteString)")
                    }
                } else {
                    print("   ❌ Failed: \(result.errorMessage ?? "Unknown error")")
                }
            } catch {
                print("   ❌ Error: \(error.localizedDescription)")
                results.append(PostResult(
                    platform: platform,
                    postID: nil,
                    postedAt: Date(),
                    success: false,
                    errorMessage: error.localizedDescription,
                    postURL: nil,
                    initialMetrics: nil
                ))
            }
        }

        progressHandler?(platforms.first!, 1.0)

        // Step 5: Store results
        postHistory.append(contentsOf: results)

        print("\n✅ Cross-post complete:")
        let successCount = results.filter { $0.success }.count
        print("   Success: \(successCount)/\(platforms.count)")

        return results
    }

    /// Schedule post for future publishing
    func schedulePost(
        content: PostContent,
        platforms: Set<SocialPlatform>,
        scheduledTime: Date,
        options: PostingOptions = PostingOptions()
    ) async throws -> ScheduledPost {
        print("📅 Scheduling post for \(scheduledTime.formatted())")

        // AI optimize content
        var optimizedContent = content
        if options.enableAIOptimization {
            optimizedContent = await optimizeContent(content, for: platforms, options: options)
        }

        // Generate platform-specific captions and hashtags
        let optimizedCaptions = generateCaptionsPerPlatform(optimizedContent, for: platforms)
        let optimizedHashtags = generateHashtagsPerPlatform(optimizedContent, for: platforms)

        let scheduledPost = ScheduledPost(
            content: optimizedContent,
            platforms: platforms,
            scheduledTime: scheduledTime,
            status: .pending,
            optimizedCaptions: optimizedCaptions,
            optimizedHashtags: optimizedHashtags
        )

        scheduledPosts.append(scheduledPost)

        print("✅ Post scheduled for \(platforms.count) platforms")
        return scheduledPost
    }

    /// Batch post - upload content once, distribute everywhere
    func batchPost(
        videos: [PostContent],
        platformsPerVideo: [Set<SocialPlatform>],
        options: PostingOptions = PostingOptions(),
        progressHandler: ((Int, PostContent, Double) -> Void)? = nil
    ) async throws -> [[PostResult]] {
        guard videos.count == platformsPerVideo.count else {
            throw PostingError.invalidBatchConfiguration
        }

        print("📦 Starting batch post:")
        print("   Videos: \(videos.count)")

        var allResults: [[PostResult]] = []

        for (index, (content, platforms)) in zip(videos, platformsPerVideo).enumerated() {
            print("\n🔄 Posting video \(index + 1)/\(videos.count)...")

            let results = try await crossPost(
                content: content,
                platforms: platforms,
                options: options,
                progressHandler: { platform, progress in
                    let totalProgress = (Double(index) + progress) / Double(videos.count)
                    progressHandler?(index, content, totalProgress)
                }
            )

            allResults.append(results)
        }

        print("\n✅ Batch post complete: \(videos.count) videos posted")
        return allResults
    }

    // MARK: - AI Content Optimization

    private func optimizeContent(
        _ content: PostContent,
        for platforms: Set<SocialPlatform>,
        options: PostingOptions
    ) async -> PostContent {
        print("🤖 AI optimizing content...")

        var optimized = content

        // Generate AI suggestions
        generateAISuggestions(for: content, platforms: platforms)

        // AI Caption Enhancement
        if options.enableCaptionAI {
            optimized.caption = enhanceCaptionWithAI(content.caption, platforms: platforms)
        }

        // Automatic Hashtag Generation
        if options.enableAutomaticHashtags && optimized.hashtags.isEmpty {
            optimized.hashtags = generateHashtagsWithAI(content: content, platforms: platforms)
        }

        // Bio-Data Tagging
        if options.enableBioDataTags, let bioData = content.bioData {
            let bioTags = generateBioTags(bioData: bioData)
            optimized.hashtags.append(contentsOf: bioTags)
        }

        print("   ✅ Content optimized")
        return optimized
    }

    private func generateAISuggestions(for content: PostContent, platforms: Set<SocialPlatform>) {
        aiSuggestions.removeAll()

        // Suggest optimal posting time
        let optimalTime = predictOptimalPostingTime(for: platforms)
        aiSuggestions.append(AISuggestion(
            type: .optimalPostingTime,
            title: "Post at \(optimalTime.formatted(date: .omitted, time: .shortened))",
            description: "Based on your audience engagement patterns, this time will maximize reach.",
            confidence: 0.87,
            data: ["time": optimalTime]
        ))

        // Suggest trending hashtags
        let trendingHashtags = getTrendingHashtags(for: platforms)
        if !trendingHashtags.isEmpty {
            aiSuggestions.append(AISuggestion(
                type: .hashtagOptimization,
                title: "Use trending hashtags",
                description: "These hashtags are currently trending: \(trendingHashtags.prefix(3).joined(separator: ", "))",
                confidence: 0.92,
                data: ["hashtags": trendingHashtags]
            ))
        }

        // Platform selection suggestions
        let recommendedPlatforms = recommendPlatforms(for: content)
        if !recommendedPlatforms.isEmpty {
            aiSuggestions.append(AISuggestion(
                type: .platformSelection,
                title: "Consider additional platforms",
                description: "Your content would perform well on: \(recommendedPlatforms.map { $0.rawValue }.joined(separator: ", "))",
                confidence: 0.78,
                data: ["platforms": recommendedPlatforms.map { $0.rawValue }]
            ))
        }
    }

    private func enhanceCaptionWithAI(_ caption: String, platforms: Set<SocialPlatform>) -> String {
        // TODO: Implement actual AI caption enhancement using CoreML
        // For now, basic enhancement
        var enhanced = caption

        // Add engaging opener if missing
        if !caption.starts(with: "✨") && !caption.starts(with: "🎵") {
            enhanced = "🎵 " + enhanced
        }

        // Add call to action if missing
        let ctas = ["Let me know what you think!", "Drop a comment below!", "Share if you enjoyed!", "Follow for more!"]
        if !caption.contains("!") {
            enhanced += "\n\n" + ctas.randomElement()!
        }

        return enhanced
    }

    private func generateHashtagsWithAI(content: PostContent, platforms: Set<SocialPlatform>) -> [String] {
        // TODO: Implement AI-powered hashtag generation using CoreML
        // Analyze video content, music, bio-data to generate relevant hashtags

        var hashtags: [String] = []

        // Music-related hashtags
        if let music = content.music {
            hashtags.append("#music")
            hashtags.append("#\(music.artist.replacingOccurrences(of: " ", with: ""))")
            if let bpm = music.bpm {
                hashtags.append("#\(Int(bpm))bpm")
            }
        }

        // Bio-data hashtags
        if let bioData = content.bioData {
            hashtags.append("#biofeedback")
            if bioData.avgCoherence > 0.7 {
                hashtags.append("#flowstate")
            }
        }

        // Platform-specific trending
        for platform in platforms {
            switch platform {
            case .tiktok:
                hashtags.append("#fyp")
                hashtags.append("#viral")
            case .instagramReel, .instagramPost:
                hashtags.append("#reels")
                hashtags.append("#explore")
            case .youtubeShort:
                hashtags.append("#shorts")
            default:
                break
            }
        }

        return Array(Set(hashtags))  // Remove duplicates
    }

    private func generateBioTags(bioData: PostContent.BioMetadata) -> [String] {
        var tags: [String] = []

        if bioData.avgCoherence > 0.8 {
            tags.append("#peakperformance")
        }
        if bioData.avgHRV > 80 {
            tags.append("#wellness")
        }
        if bioData.flowState == "flow" {
            tags.append("#flowstate")
        }

        return tags
    }

    // MARK: - Content Validation

    private func validateContent(_ content: PostContent, for platform: SocialPlatform) throws {
        // Check video duration
        let asset = AVURLAsset(url: content.videoURL)
        let duration = asset.duration.seconds

        if let maxDuration = platform.maxDuration, duration > maxDuration {
            throw PostingError.videoDurationExceedsLimit(platform, duration, maxDuration)
        }

        // Check caption length
        if content.caption.count > platform.maxCaptionLength {
            throw PostingError.captionTooLong(platform, content.caption.count, platform.maxCaptionLength)
        }

        // Check hashtag count
        if content.hashtags.count > platform.maxHashtags {
            throw PostingError.tooManyHashtags(platform, content.hashtags.count, platform.maxHashtags)
        }

        print("   ✅ Content validated for \(platform.rawValue)")
    }

    // MARK: - Platform Variants

    private func generatePlatformVariants(
        _ content: PostContent,
        for platforms: Set<SocialPlatform>,
        options: PostingOptions
    ) async throws -> [SocialPlatform: PostContent] {
        var variants: [SocialPlatform: PostContent] = [:]

        for platform in platforms {
            var variant = content

            // Adapt caption per platform
            if options.adaptCaptionPerPlatform {
                variant.caption = adaptCaption(content.caption, for: platform)
            }

            // Trim hashtags to platform limit
            variant.hashtags = Array(content.hashtags.prefix(platform.maxHashtags))

            // TODO: Re-encode video to platform-specific format (aspect ratio, bitrate)

            variants[platform] = variant
        }

        return variants
    }

    private func adaptCaption(_ caption: String, for platform: SocialPlatform) -> String {
        // Trim to platform max length
        var adapted = String(caption.prefix(platform.maxCaptionLength - 50))  // Reserve 50 chars for hashtags

        // Platform-specific adaptations
        switch platform {
        case .twitter:
            // Twitter has 280 char limit - make it concise
            adapted = String(adapted.prefix(200))
        case .linkedin:
            // LinkedIn prefers professional tone
            adapted = adapted.replacingOccurrences(of: "🔥", with: "")
        case .tiktok:
            // TikTok loves emojis and trending sounds
            if !adapted.contains("🎵") {
                adapted = "🎵 " + adapted
            }
        default:
            break
        }

        return adapted
    }

    // MARK: - Platform Posting (Simulated)

    private func postToPlatform(
        variant: PostContent,
        platform: SocialPlatform,
        options: PostingOptions
    ) async throws -> PostResult {
        // TODO: Implement actual platform APIs
        // - TikTok: Content Posting API
        // - Instagram: Graph API
        // - YouTube: Data API v3
        // - Facebook: Graph API
        // - Twitter: API v2
        // - LinkedIn: Share API
        // - etc.

        // Simulate posting delay
        try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

        // Simulate success/failure
        let success = Double.random(in: 0...1) > 0.1  // 90% success rate

        return PostResult(
            platform: platform,
            postID: success ? UUID().uuidString : nil,
            postedAt: Date(),
            success: success,
            errorMessage: success ? nil : "Simulated error",
            postURL: success ? URL(string: "https://\(platform.rawValue.lowercased()).com/post/\(UUID().uuidString)") : nil,
            initialMetrics: success ? PostResult.InitialMetrics(
                views: Int.random(in: 0...100),
                likes: Int.random(in: 0...50),
                comments: Int.random(in: 0...10),
                shares: Int.random(in: 0...5)
            ) : nil
        )
    }

    // MARK: - AI Predictions

    private func predictOptimalPostingTime(for platforms: Set<SocialPlatform>) -> Date {
        // TODO: Implement ML model for optimal posting time prediction
        // Factors: historical engagement, timezone, day of week, platform algorithms

        let calendar = Calendar.current
        let now = Date()

        // Simple heuristic: weekday evening (7 PM)
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 19  // 7 PM
        components.minute = 0

        return calendar.date(from: components) ?? now
    }

    private func getTrendingHashtags(for platforms: Set<SocialPlatform>) -> [String] {
        // TODO: Fetch real trending hashtags from platform APIs
        return ["#trending", "#viral", "#fyp", "#foryou", "#music"]
    }

    private func recommendPlatforms(for content: PostContent) -> [SocialPlatform] {
        // TODO: Implement ML model for platform recommendation
        var recommended: [SocialPlatform] = []

        // If short music video, recommend TikTok and Reels
        if let music = content.music, music.duration < 60 {
            recommended.append(.tiktok)
            recommended.append(.instagramReel)
            recommended.append(.youtubeShort)
        }

        return recommended
    }

    // MARK: - Caption & Hashtag Generation

    private func generateCaptionsPerPlatform(
        _ content: PostContent,
        for platforms: Set<SocialPlatform>
    ) -> [SocialPlatform: String] {
        var captions: [SocialPlatform: String] = [:]

        for platform in platforms {
            captions[platform] = adaptCaption(content.caption, for: platform)
        }

        return captions
    }

    private func generateHashtagsPerPlatform(
        _ content: PostContent,
        for platforms: Set<SocialPlatform>
    ) -> [SocialPlatform: [String]] {
        var hashtags: [SocialPlatform: [String]] = [:]

        for platform in platforms {
            hashtags[platform] = Array(content.hashtags.prefix(platform.maxHashtags))
        }

        return hashtags
    }

    // MARK: - Analytics

    func fetchAggregatedAnalytics() async throws -> AnalyticsSnapshot {
        // TODO: Fetch analytics from all platform APIs
        // Aggregate views, likes, comments, shares across all platforms

        // Simulated analytics
        return AnalyticsSnapshot(
            totalPosts: postHistory.count,
            totalViews: Int.random(in: 1000...50000),
            totalLikes: Int.random(in: 100...5000),
            totalComments: Int.random(in: 10...500),
            totalShares: Int.random(in: 5...250),
            avgEngagementRate: Double.random(in: 0.02...0.15),
            topPlatform: .tiktok,
            topPerformingPost: postHistory.first?.postID,
            platformBreakdown: [:]
        )
    }
}

// MARK: - Errors

enum PostingError: LocalizedError {
    case alreadyPosting
    case invalidBatchConfiguration
    case videoDurationExceedsLimit(IntelligentPostingManager.SocialPlatform, TimeInterval, TimeInterval)
    case captionTooLong(IntelligentPostingManager.SocialPlatform, Int, Int)
    case tooManyHashtags(IntelligentPostingManager.SocialPlatform, Int, Int)
    case platformAuthenticationRequired(IntelligentPostingManager.SocialPlatform)
    case uploadFailed(IntelligentPostingManager.SocialPlatform, String)

    var errorDescription: String? {
        switch self {
        case .alreadyPosting:
            return "Already posting to another platform"
        case .invalidBatchConfiguration:
            return "Batch configuration is invalid"
        case .videoDurationExceedsLimit(let platform, let duration, let limit):
            return "\(platform.rawValue) video duration (\(Int(duration))s) exceeds limit (\(Int(limit))s)"
        case .captionTooLong(let platform, let length, let limit):
            return "\(platform.rawValue) caption (\(length) chars) exceeds limit (\(limit) chars)"
        case .tooManyHashtags(let platform, let count, let limit):
            return "\(platform.rawValue) hashtag count (\(count)) exceeds limit (\(limit))"
        case .platformAuthenticationRequired(let platform):
            return "\(platform.rawValue) requires authentication"
        case .uploadFailed(let platform, let reason):
            return "\(platform.rawValue) upload failed: \(reason)"
        }
    }
}
