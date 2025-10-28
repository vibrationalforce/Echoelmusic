import Foundation
import UIKit

/// Protocol for social media platform adapters
/// Each platform implements this protocol to provide consistent interface
@MainActor
protocol PlatformAdapter {

    /// Check if platform SDK is configured
    var isConfigured: Bool { get }

    /// Platform-specific requirements
    var requirements: PlatformRequirements { get}

    /// Check authentication status
    func isAuthenticated() async -> Bool

    /// Authenticate user with platform
    /// - Parameter viewController: Presenting view controller for OAuth flow
    func authenticate(from viewController: UIViewController) async throws

    /// Sign out from platform
    func signOut() async

    /// Upload video to platform
    /// - Parameters:
    ///   - videoURL: Local URL of video file
    ///   - metadata: Video metadata (title, description, hashtags)
    ///   - progressCallback: Progress callback (0.0 - 1.0)
    /// - Returns: Upload result with post ID and URL
    func uploadVideo(
        videoURL: URL,
        metadata: VideoMetadata,
        progressCallback: @escaping (Double) -> Void
    ) async throws -> UploadResult

    /// Get user profile info (if authenticated)
    func getUserProfile() async throws -> UserProfile?
}


/// User profile information
struct UserProfile {
    let userID: String
    let username: String
    let displayName: String
    let profileImageURL: URL?
    let followerCount: Int?
    let isVerified: Bool
}
