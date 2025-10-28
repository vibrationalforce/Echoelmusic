import Foundation
import UIKit

/// Central manager for social media platform integrations
/// Handles authentication, upload, and platform-specific operations
@MainActor
class SocialMediaManager: ObservableObject {

    // MARK: - Published State

    @Published var isAuthenticated: [PlatformType: Bool] = [:]
    @Published var isUploading: Bool = false
    @Published var uploadProgress: Double = 0.0
    @Published var lastError: Error?

    // MARK: - Platform Adapters

    private var instagram: InstagramAdapter?
    private var tiktok: TikTokAdapter?
    private var youtube: YouTubeAdapter?
    private var snapchat: SnapchatAdapter?
    private var twitter: TwitterAdapter?

    // MARK: - Initialization

    init() {
        // Initialize platform adapters
        self.instagram = InstagramAdapter()
        self.tiktok = TikTokAdapter()
        self.youtube = YouTubeAdapter()
        self.snapchat = SnapchatAdapter()
        self.twitter = TwitterAdapter()

        // Check authentication status
        Task {
            await refreshAuthStatus()
        }
    }

    // MARK: - Authentication

    /// Check authentication status for all platforms
    func refreshAuthStatus() async {
        isAuthenticated[.instagram] = await instagram?.isAuthenticated() ?? false
        isAuthenticated[.tiktok] = await tiktok?.isAuthenticated() ?? false
        isAuthenticated[.youtube] = await youtube?.isAuthenticated() ?? false
        isAuthenticated[.snapchat] = await snapchat?.isAuthenticated() ?? false
        isAuthenticated[.twitter] = await twitter?.isAuthenticated() ?? false
    }

    /// Authenticate with platform
    func authenticate(platform: PlatformType, from viewController: UIViewController) async throws {
        switch platform {
        case .instagram:
            try await instagram?.authenticate(from: viewController)
        case .tiktok:
            try await tiktok?.authenticate(from: viewController)
        case .youtube:
            try await youtube?.authenticate(from: viewController)
        case .snapchat:
            try await snapchat?.authenticate(from: viewController)
        case .twitter:
            try await twitter?.authenticate(from: viewController)
        }

        await refreshAuthStatus()
    }

    /// Sign out from platform
    func signOut(from platform: PlatformType) async {
        switch platform {
        case .instagram:
            await instagram?.signOut()
        case .tiktok:
            await tiktok?.signOut()
        case .youtube:
            await youtube?.signOut()
        case .snapchat:
            await snapchat?.signOut()
        case .twitter:
            await twitter?.signOut()
        }

        await refreshAuthStatus()
    }

    // MARK: - Upload

    /// Upload video to platform
    func uploadVideo(
        videoURL: URL,
        platform: PlatformType,
        metadata: VideoMetadata,
        progressCallback: @escaping (Double) -> Void
    ) async throws -> UploadResult {

        isUploading = true
        defer { isUploading = false }

        do {
            let result: UploadResult

            switch platform {
            case .instagram:
                result = try await instagram!.uploadVideo(
                    videoURL: videoURL,
                    metadata: metadata,
                    progressCallback: progressCallback
                )
            case .tiktok:
                result = try await tiktok!.uploadVideo(
                    videoURL: videoURL,
                    metadata: metadata,
                    progressCallback: progressCallback
                )
            case .youtube:
                result = try await youtube!.uploadVideo(
                    videoURL: videoURL,
                    metadata: metadata,
                    progressCallback: progressCallback
                )
            case .snapchat:
                result = try await snapchat!.uploadVideo(
                    videoURL: videoURL,
                    metadata: metadata,
                    progressCallback: progressCallback
                )
            case .twitter:
                result = try await twitter!.uploadVideo(
                    videoURL: videoURL,
                    metadata: metadata,
                    progressCallback: progressCallback
                )
            }

            print("✅ Uploaded to \(platform.rawValue): \(result.postURL ?? "No URL")")
            return result

        } catch {
            lastError = error
            print("❌ Upload failed to \(platform.rawValue): \(error)")
            throw error
        }
    }

    /// Upload video to multiple platforms simultaneously
    func uploadToMultiplePlatforms(
        videoURL: URL,
        platforms: [PlatformType],
        metadata: VideoMetadata
    ) async throws -> [PlatformType: UploadResult] {

        var results: [PlatformType: UploadResult] = [:]

        // Upload to each platform concurrently
        try await withThrowingTaskGroup(of: (PlatformType, UploadResult).self) { group in
            for platform in platforms {
                group.addTask {
                    let result = try await self.uploadVideo(
                        videoURL: videoURL,
                        platform: platform,
                        metadata: metadata,
                        progressCallback: { _ in }
                    )
                    return (platform, result)
                }
            }

            for try await (platform, result) in group {
                results[platform] = result
            }
        }

        return results
    }

    // MARK: - Platform Capabilities

    /// Check if platform is available and configured
    func isPlatformAvailable(_ platform: PlatformType) -> Bool {
        switch platform {
        case .instagram:
            return instagram?.isConfigured ?? false
        case .tiktok:
            return tiktok?.isConfigured ?? false
        case .youtube:
            return youtube?.isConfigured ?? false
        case .snapchat:
            return snapchat?.isConfigured ?? false
        case .twitter:
            return twitter?.isConfigured ?? false
        }
    }

    /// Get platform-specific requirements
    func getPlatformRequirements(_ platform: PlatformType) -> PlatformRequirements {
        switch platform {
        case .instagram:
            return instagram?.requirements ?? PlatformRequirements.instagram
        case .tiktok:
            return tiktok?.requirements ?? PlatformRequirements.tiktok
        case .youtube:
            return youtube?.requirements ?? PlatformRequirements.youtube
        case .snapchat:
            return snapchat?.requirements ?? PlatformRequirements.snapchat
        case .twitter:
            return twitter?.requirements ?? PlatformRequirements.twitter
        }
    }
}


// MARK: - Platform Type

enum PlatformType: String, CaseIterable {
    case instagram = "Instagram"
    case tiktok = "TikTok"
    case youtube = "YouTube"
    case snapchat = "Snapchat"
    case twitter = "Twitter/X"

    var icon: String {
        switch self {
        case .instagram: return "camera.fill"
        case .tiktok: return "music.note"
        case .youtube: return "play.rectangle.fill"
        case .snapchat: return "face.smiling"
        case .twitter: return "text.bubble"
        }
    }

    var color: UIColor {
        switch self {
        case .instagram: return UIColor(red: 0.9, green: 0.3, blue: 0.5, alpha: 1.0)
        case .tiktok: return UIColor.black
        case .youtube: return UIColor.red
        case .snapchat: return UIColor.yellow
        case .twitter: return UIColor(red: 0.1, green: 0.6, blue: 1.0, alpha: 1.0)
        }
    }
}


// MARK: - Video Metadata

struct VideoMetadata {
    let title: String
    let description: String
    let hashtags: [String]
    let location: String?
    let privacy: PrivacyLevel

    enum PrivacyLevel: String {
        case publicVideo = "public"
        case private_ = "private"
        case friendsOnly = "friends"
        case unlisted = "unlisted"
    }

    /// Create from session
    static func from(session: Session, customTitle: String? = nil) -> VideoMetadata {
        let hashtags = generateHashtags(from: session)

        return VideoMetadata(
            title: customTitle ?? session.name,
            description: generateDescription(from: session),
            hashtags: hashtags,
            location: nil,
            privacy: .publicVideo
        )
    }

    private static func generateHashtags(from session: Session) -> [String] {
        var tags = ["#blab", "#biomusic", "#hrv", "#breathwork"]

        // Add based on session characteristics
        if session.averageCoherence > 70 {
            tags.append("#meditation")
            tags.append("#mindfulness")
        }

        if session.averageHeartRate > 100 {
            tags.append("#energetic")
            tags.append("#active")
        }

        return tags
    }

    private static func generateDescription(from session: Session) -> String {
        let duration = Int(session.duration)
        let avgHRV = Int(session.averageHRV)
        let coherence = Int(session.averageCoherence)

        return """
        Bio-reactive music session 🎵

        Duration: \(duration)s
        HRV: \(avgHRV)ms
        Coherence: \(coherence)/100

        Created with BLAB - transforming breath and biometrics into sound
        """
    }
}


// MARK: - Upload Result

struct UploadResult {
    let success: Bool
    let postID: String?
    let postURL: String?
    let thumbnail: URL?
    let uploadedAt: Date

    static func success(postID: String, postURL: String?) -> UploadResult {
        return UploadResult(
            success: true,
            postID: postID,
            postURL: postURL,
            thumbnail: nil,
            uploadedAt: Date()
        )
    }

    static func failure() -> UploadResult {
        return UploadResult(
            success: false,
            postID: nil,
            postURL: nil,
            thumbnail: nil,
            uploadedAt: Date()
        )
    }
}


// MARK: - Platform Requirements

struct PlatformRequirements {
    let minDuration: TimeInterval
    let maxDuration: TimeInterval
    let maxFileSize: Int64  // bytes
    let supportedFormats: [String]
    let requiresApproval: Bool
    let supportsScheduling: Bool

    static let instagram = PlatformRequirements(
        minDuration: 3.0,
        maxDuration: 90.0,
        maxFileSize: 100_000_000,  // 100 MB
        supportedFormats: ["mp4", "mov"],
        requiresApproval: false,
        supportsScheduling: true
    )

    static let tiktok = PlatformRequirements(
        minDuration: 3.0,
        maxDuration: 180.0,
        maxFileSize: 287_000_000,  // 287 MB
        supportedFormats: ["mp4", "mov"],
        requiresApproval: false,
        supportsScheduling: true
    )

    static let youtube = PlatformRequirements(
        minDuration: 1.0,
        maxDuration: 3600.0,
        maxFileSize: 2_000_000_000,  // 2 GB
        supportedFormats: ["mp4", "mov", "avi"],
        requiresApproval: false,
        supportsScheduling: true
    )

    static let snapchat = PlatformRequirements(
        minDuration: 1.0,
        maxDuration: 60.0,
        maxFileSize: 32_000_000,  // 32 MB
        supportedFormats: ["mp4", "mov"],
        requiresApproval: false,
        supportsScheduling: false
    )

    static let twitter = PlatformRequirements(
        minDuration: 0.5,
        maxDuration: 140.0,
        maxFileSize: 512_000_000,  // 512 MB
        supportedFormats: ["mp4", "mov"],
        requiresApproval: false,
        supportsScheduling: true
    )
}


// MARK: - Social Media Error

enum SocialMediaError: LocalizedError {
    case notAuthenticated
    case notConfigured
    case uploadFailed(String)
    case invalidVideo
    case durationExceeded
    case fileSizeTooLarge
    case unsupportedFormat
    case networkError
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not signed in to platform"
        case .notConfigured:
            return "Platform SDK not configured"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .invalidVideo:
            return "Invalid video file"
        case .durationExceeded:
            return "Video duration exceeds platform limit"
        case .fileSizeTooLarge:
            return "File size too large"
        case .unsupportedFormat:
            return "Video format not supported"
        case .networkError:
            return "Network connection error"
        case .rateLimited:
            return "Rate limit exceeded, try again later"
        }
    }
}
