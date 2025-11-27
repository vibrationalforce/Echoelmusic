// ContentManagementAPI.swift
// Echoelmusic - Complete Content Management System & REST API
// Handles Projects, Assets, Templates, Marketplace, and Social Features

import Foundation
import Combine

// MARK: - API Configuration

public struct APIConfiguration {
    public let baseURL: URL
    public let apiKey: String?
    public let timeout: TimeInterval
    public let maxRetries: Int

    public static let production = APIConfiguration(
        baseURL: URL(string: "https://api.echoelmusic.com/v1")!,
        apiKey: nil,
        timeout: 30,
        maxRetries: 3
    )

    public static let staging = APIConfiguration(
        baseURL: URL(string: "https://staging-api.echoelmusic.com/v1")!,
        apiKey: nil,
        timeout: 30,
        maxRetries: 3
    )
}

// MARK: - Content Models

/// Project/Session stored in cloud
public struct CloudProject: Identifiable, Codable {
    public let id: String
    public var name: String
    public var description: String?
    public var ownerId: String
    public var collaboratorIds: [String]
    public var visibility: Visibility
    public var tags: [String]
    public var genre: String?
    public var tempo: Double?
    public var key: String?
    public var duration: TimeInterval?
    public var thumbnailURL: URL?
    public var previewAudioURL: URL?
    public var projectFileURL: URL?
    public var version: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var publishedAt: Date?
    public var stats: ProjectStats

    public enum Visibility: String, Codable {
        case `private`
        case unlisted
        case `public`
        case collaborative
    }

    public struct ProjectStats: Codable {
        public var plays: Int
        public var likes: Int
        public var comments: Int
        public var shares: Int
        public var downloads: Int
        public var remixes: Int
    }
}

/// Media asset (audio, video, image)
public struct MediaAsset: Identifiable, Codable {
    public let id: String
    public var name: String
    public var type: AssetType
    public var mimeType: String
    public var fileSize: Int64
    public var duration: TimeInterval?
    public var sampleRate: Int?
    public var channels: Int?
    public var bitDepth: Int?
    public var width: Int?
    public var height: Int?
    public var frameRate: Double?
    public var url: URL
    public var thumbnailURL: URL?
    public var waveformURL: URL?
    public var tags: [String]
    public var category: String?
    public var license: License
    public var ownerId: String
    public var createdAt: Date

    public enum AssetType: String, Codable {
        case audio
        case video
        case image
        case midi
        case preset
        case plugin
        case template
    }

    public enum License: String, Codable {
        case free
        case creativeCommons
        case royaltyFree
        case exclusive
        case custom
    }
}

/// Template for projects
public struct ProjectTemplate: Identifiable, Codable {
    public let id: String
    public var name: String
    public var description: String
    public var category: Category
    public var thumbnailURL: URL?
    public var previewURL: URL?
    public var templateFileURL: URL
    public var authorId: String
    public var authorName: String
    public var tags: [String]
    public var genre: String?
    public var difficulty: Difficulty
    public var isPremium: Bool
    public var price: Decimal?
    public var downloadCount: Int
    public var rating: Float
    public var createdAt: Date

    public enum Category: String, Codable, CaseIterable {
        case daw = "DAW"
        case videoEdit = "Video Edit"
        case vjPerformance = "VJ Performance"
        case liveStream = "Live Stream"
        case collaboration = "Collaboration"
        case meditation = "Meditation"
        case podcast = "Podcast"
        case music = "Music Production"
    }

    public enum Difficulty: String, Codable {
        case beginner
        case intermediate
        case advanced
        case expert
    }
}

/// Marketplace item
public struct MarketplaceItem: Identifiable, Codable {
    public let id: String
    public var name: String
    public var description: String
    public var type: ItemType
    public var category: String
    public var thumbnailURL: URL?
    public var previewURLs: [URL]
    public var downloadURL: URL?
    public var authorId: String
    public var authorName: String
    public var price: Decimal
    public var currency: String
    public var isFree: Bool
    public var tags: [String]
    public var rating: Float
    public var reviewCount: Int
    public var downloadCount: Int
    public var version: String
    public var compatibility: [String]
    public var fileSize: Int64
    public var createdAt: Date
    public var updatedAt: Date

    public enum ItemType: String, Codable, CaseIterable {
        case samplePack = "Sample Pack"
        case preset = "Preset"
        case plugin = "Plugin"
        case template = "Template"
        case visualPack = "Visual Pack"
        case lut = "LUT"
        case midi = "MIDI Pack"
        case course = "Course"
    }
}

/// User profile (social)
public struct UserProfile: Identifiable, Codable {
    public let id: String
    public var username: String
    public var displayName: String
    public var bio: String?
    public var avatarURL: URL?
    public var coverImageURL: URL?
    public var location: String?
    public var website: String?
    public var socialLinks: [String: String]
    public var genres: [String]
    public var skills: [String]
    public var isVerified: Bool
    public var isPremium: Bool
    public var followerCount: Int
    public var followingCount: Int
    public var projectCount: Int
    public var joinedAt: Date
}

/// Social post/activity
public struct SocialPost: Identifiable, Codable {
    public let id: String
    public var authorId: String
    public var authorProfile: UserProfile?
    public var type: PostType
    public var content: String?
    public var mediaURLs: [URL]
    public var projectId: String?
    public var project: CloudProject?
    public var tags: [String]
    public var mentions: [String]
    public var likeCount: Int
    public var commentCount: Int
    public var shareCount: Int
    public var isLikedByCurrentUser: Bool
    public var createdAt: Date

    public enum PostType: String, Codable {
        case text
        case audio
        case video
        case image
        case project
        case remix
        case collaboration
        case achievement
    }
}

/// Comment
public struct Comment: Identifiable, Codable {
    public let id: String
    public var authorId: String
    public var authorProfile: UserProfile?
    public var content: String
    public var parentId: String?
    public var targetType: TargetType
    public var targetId: String
    public var likeCount: Int
    public var replyCount: Int
    public var isLikedByCurrentUser: Bool
    public var createdAt: Date

    public enum TargetType: String, Codable {
        case project
        case post
        case marketplaceItem
        case user
    }
}

/// Notification
public struct Notification: Identifiable, Codable {
    public let id: String
    public var type: NotificationType
    public var title: String
    public var body: String
    public var imageURL: URL?
    public var actionURL: String?
    public var data: [String: String]?
    public var isRead: Bool
    public var createdAt: Date

    public enum NotificationType: String, Codable {
        case like
        case comment
        case follow
        case mention
        case collaboration
        case projectPublished
        case newFollowerContent
        case achievement
        case system
    }
}

// MARK: - API Responses

public struct PaginatedResponse<T: Codable>: Codable {
    public let items: [T]
    public let total: Int
    public let page: Int
    public let pageSize: Int
    public let hasMore: Bool
}

public struct APIResponse<T: Codable>: Codable {
    public let success: Bool
    public let data: T?
    public let error: APIError?
}

public struct APIError: Codable, Error {
    public let code: String
    public let message: String
    public let details: [String: String]?
}

// MARK: - Content Management API

@MainActor
public class ContentManagementAPI: ObservableObject {
    // Configuration
    private let configuration: APIConfiguration
    private var authToken: String?

    // State
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var error: APIError?

    // Cache
    private var projectCache: [String: CloudProject] = [:]
    private var userCache: [String: UserProfile] = [:]
    private let cacheExpiry: TimeInterval = 300 // 5 minutes

    // Session
    private let session: URLSession

    public init(configuration: APIConfiguration = .production) {
        self.configuration = configuration

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = configuration.timeout
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    public func setAuthToken(_ token: String?) {
        self.authToken = token
    }

    // MARK: - Projects API

    /// Get user's projects
    public func getMyProjects(page: Int = 1, pageSize: Int = 20) async throws -> PaginatedResponse<CloudProject> {
        return try await request(
            endpoint: "/projects/me",
            method: "GET",
            queryParams: ["page": "\(page)", "pageSize": "\(pageSize)"]
        )
    }

    /// Get a single project
    public func getProject(id: String) async throws -> CloudProject {
        if let cached = projectCache[id] {
            return cached
        }

        let project: CloudProject = try await request(endpoint: "/projects/\(id)", method: "GET")
        projectCache[id] = project
        return project
    }

    /// Create a new project
    public func createProject(_ project: CloudProject) async throws -> CloudProject {
        return try await request(
            endpoint: "/projects",
            method: "POST",
            body: project
        )
    }

    /// Update a project
    public func updateProject(_ project: CloudProject) async throws -> CloudProject {
        projectCache.removeValue(forKey: project.id)
        return try await request(
            endpoint: "/projects/\(project.id)",
            method: "PUT",
            body: project
        )
    }

    /// Delete a project
    public func deleteProject(id: String) async throws {
        projectCache.removeValue(forKey: id)
        let _: EmptyResponse = try await request(
            endpoint: "/projects/\(id)",
            method: "DELETE"
        )
    }

    /// Publish a project
    public func publishProject(id: String) async throws -> CloudProject {
        return try await request(
            endpoint: "/projects/\(id)/publish",
            method: "POST"
        )
    }

    /// Search projects
    public func searchProjects(
        query: String,
        genre: String? = nil,
        tags: [String]? = nil,
        sortBy: String = "relevance",
        page: Int = 1
    ) async throws -> PaginatedResponse<CloudProject> {
        var params: [String: String] = [
            "q": query,
            "sortBy": sortBy,
            "page": "\(page)"
        ]
        if let genre = genre { params["genre"] = genre }
        if let tags = tags { params["tags"] = tags.joined(separator: ",") }

        return try await request(
            endpoint: "/projects/search",
            method: "GET",
            queryParams: params
        )
    }

    /// Get trending projects
    public func getTrendingProjects(page: Int = 1) async throws -> PaginatedResponse<CloudProject> {
        return try await request(
            endpoint: "/projects/trending",
            method: "GET",
            queryParams: ["page": "\(page)"]
        )
    }

    // MARK: - Assets API

    /// Upload an asset
    public func uploadAsset(
        name: String,
        type: MediaAsset.AssetType,
        data: Data,
        mimeType: String,
        tags: [String] = [],
        onProgress: ((Double) -> Void)? = nil
    ) async throws -> MediaAsset {
        // Create multipart form data
        let boundary = UUID().uuidString
        var body = Data()

        // Add file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(name)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)

        // Add metadata
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"name\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(name)\r\n".data(using: .utf8)!)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"type\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(type.rawValue)\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: configuration.baseURL.appendingPathComponent("/assets"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        let (responseData, response) = try await session.data(for: request)
        try validateResponse(response)

        return try JSONDecoder().decode(MediaAsset.self, from: responseData)
    }

    /// Get user's assets
    public func getMyAssets(
        type: MediaAsset.AssetType? = nil,
        page: Int = 1
    ) async throws -> PaginatedResponse<MediaAsset> {
        var params: [String: String] = ["page": "\(page)"]
        if let type = type { params["type"] = type.rawValue }

        return try await request(
            endpoint: "/assets/me",
            method: "GET",
            queryParams: params
        )
    }

    /// Delete an asset
    public func deleteAsset(id: String) async throws {
        let _: EmptyResponse = try await request(
            endpoint: "/assets/\(id)",
            method: "DELETE"
        )
    }

    // MARK: - Templates API

    /// Get templates
    public func getTemplates(
        category: ProjectTemplate.Category? = nil,
        page: Int = 1
    ) async throws -> PaginatedResponse<ProjectTemplate> {
        var params: [String: String] = ["page": "\(page)"]
        if let category = category { params["category"] = category.rawValue }

        return try await request(
            endpoint: "/templates",
            method: "GET",
            queryParams: params
        )
    }

    /// Get template by ID
    public func getTemplate(id: String) async throws -> ProjectTemplate {
        return try await request(endpoint: "/templates/\(id)", method: "GET")
    }

    /// Create project from template
    public func createProjectFromTemplate(templateId: String, name: String) async throws -> CloudProject {
        return try await request(
            endpoint: "/templates/\(templateId)/instantiate",
            method: "POST",
            body: ["name": name]
        )
    }

    // MARK: - Marketplace API

    /// Browse marketplace
    public func browseMarketplace(
        type: MarketplaceItem.ItemType? = nil,
        category: String? = nil,
        query: String? = nil,
        sortBy: String = "popular",
        page: Int = 1
    ) async throws -> PaginatedResponse<MarketplaceItem> {
        var params: [String: String] = ["page": "\(page)", "sortBy": sortBy]
        if let type = type { params["type"] = type.rawValue }
        if let category = category { params["category"] = category }
        if let query = query { params["q"] = query }

        return try await request(
            endpoint: "/marketplace",
            method: "GET",
            queryParams: params
        )
    }

    /// Get marketplace item
    public func getMarketplaceItem(id: String) async throws -> MarketplaceItem {
        return try await request(endpoint: "/marketplace/\(id)", method: "GET")
    }

    /// Purchase item
    public func purchaseItem(id: String) async throws -> PurchaseResult {
        return try await request(
            endpoint: "/marketplace/\(id)/purchase",
            method: "POST"
        )
    }

    /// Get user's purchases
    public func getMyPurchases(page: Int = 1) async throws -> PaginatedResponse<MarketplaceItem> {
        return try await request(
            endpoint: "/marketplace/purchases",
            method: "GET",
            queryParams: ["page": "\(page)"]
        )
    }

    public struct PurchaseResult: Codable {
        public let success: Bool
        public let downloadURL: URL?
        public let receiptId: String
    }

    // MARK: - Social API

    /// Get feed
    public func getFeed(page: Int = 1) async throws -> PaginatedResponse<SocialPost> {
        return try await request(
            endpoint: "/feed",
            method: "GET",
            queryParams: ["page": "\(page)"]
        )
    }

    /// Get explore feed
    public func getExploreFeed(page: Int = 1) async throws -> PaginatedResponse<SocialPost> {
        return try await request(
            endpoint: "/explore",
            method: "GET",
            queryParams: ["page": "\(page)"]
        )
    }

    /// Create post
    public func createPost(_ post: SocialPost) async throws -> SocialPost {
        return try await request(
            endpoint: "/posts",
            method: "POST",
            body: post
        )
    }

    /// Like content
    public func like(targetType: String, targetId: String) async throws {
        let _: EmptyResponse = try await request(
            endpoint: "/likes",
            method: "POST",
            body: ["targetType": targetType, "targetId": targetId]
        )
    }

    /// Unlike content
    public func unlike(targetType: String, targetId: String) async throws {
        let _: EmptyResponse = try await request(
            endpoint: "/likes",
            method: "DELETE",
            body: ["targetType": targetType, "targetId": targetId]
        )
    }

    /// Add comment
    public func addComment(
        targetType: Comment.TargetType,
        targetId: String,
        content: String,
        parentId: String? = nil
    ) async throws -> Comment {
        var body: [String: Any] = [
            "targetType": targetType.rawValue,
            "targetId": targetId,
            "content": content
        ]
        if let parentId = parentId { body["parentId"] = parentId }

        return try await request(
            endpoint: "/comments",
            method: "POST",
            body: body
        )
    }

    /// Get comments
    public func getComments(
        targetType: Comment.TargetType,
        targetId: String,
        page: Int = 1
    ) async throws -> PaginatedResponse<Comment> {
        return try await request(
            endpoint: "/comments",
            method: "GET",
            queryParams: [
                "targetType": targetType.rawValue,
                "targetId": targetId,
                "page": "\(page)"
            ]
        )
    }

    // MARK: - Users API

    /// Get user profile
    public func getUserProfile(id: String) async throws -> UserProfile {
        if let cached = userCache[id] {
            return cached
        }

        let profile: UserProfile = try await request(endpoint: "/users/\(id)", method: "GET")
        userCache[id] = profile
        return profile
    }

    /// Update my profile
    public func updateMyProfile(_ profile: UserProfile) async throws -> UserProfile {
        return try await request(
            endpoint: "/users/me",
            method: "PUT",
            body: profile
        )
    }

    /// Follow user
    public func followUser(id: String) async throws {
        let _: EmptyResponse = try await request(
            endpoint: "/users/\(id)/follow",
            method: "POST"
        )
    }

    /// Unfollow user
    public func unfollowUser(id: String) async throws {
        let _: EmptyResponse = try await request(
            endpoint: "/users/\(id)/follow",
            method: "DELETE"
        )
    }

    /// Get followers
    public func getFollowers(userId: String, page: Int = 1) async throws -> PaginatedResponse<UserProfile> {
        return try await request(
            endpoint: "/users/\(userId)/followers",
            method: "GET",
            queryParams: ["page": "\(page)"]
        )
    }

    /// Get following
    public func getFollowing(userId: String, page: Int = 1) async throws -> PaginatedResponse<UserProfile> {
        return try await request(
            endpoint: "/users/\(userId)/following",
            method: "GET",
            queryParams: ["page": "\(page)"]
        )
    }

    /// Search users
    public func searchUsers(query: String, page: Int = 1) async throws -> PaginatedResponse<UserProfile> {
        return try await request(
            endpoint: "/users/search",
            method: "GET",
            queryParams: ["q": query, "page": "\(page)"]
        )
    }

    // MARK: - Notifications API

    /// Get notifications
    public func getNotifications(page: Int = 1) async throws -> PaginatedResponse<Notification> {
        return try await request(
            endpoint: "/notifications",
            method: "GET",
            queryParams: ["page": "\(page)"]
        )
    }

    /// Mark notification as read
    public func markNotificationRead(id: String) async throws {
        let _: EmptyResponse = try await request(
            endpoint: "/notifications/\(id)/read",
            method: "POST"
        )
    }

    /// Mark all notifications as read
    public func markAllNotificationsRead() async throws {
        let _: EmptyResponse = try await request(
            endpoint: "/notifications/read-all",
            method: "POST"
        )
    }

    /// Get unread count
    public func getUnreadNotificationCount() async throws -> Int {
        let response: [String: Int] = try await request(
            endpoint: "/notifications/unread-count",
            method: "GET"
        )
        return response["count"] ?? 0
    }

    // MARK: - Analytics API

    /// Get project analytics
    public func getProjectAnalytics(projectId: String, period: String = "30d") async throws -> ProjectAnalytics {
        return try await request(
            endpoint: "/analytics/projects/\(projectId)",
            method: "GET",
            queryParams: ["period": period]
        )
    }

    /// Get user analytics
    public func getMyAnalytics(period: String = "30d") async throws -> UserAnalytics {
        return try await request(
            endpoint: "/analytics/me",
            method: "GET",
            queryParams: ["period": period]
        )
    }

    public struct ProjectAnalytics: Codable {
        public let plays: [DataPoint]
        public let likes: [DataPoint]
        public let comments: [DataPoint]
        public let shares: [DataPoint]
        public let downloads: [DataPoint]
        public let uniqueListeners: Int
        public let averagePlayDuration: TimeInterval
        public let topCountries: [CountryStat]
        public let topReferrers: [ReferrerStat]

        public struct DataPoint: Codable {
            public let date: Date
            public let value: Int
        }

        public struct CountryStat: Codable {
            public let country: String
            public let count: Int
        }

        public struct ReferrerStat: Codable {
            public let source: String
            public let count: Int
        }
    }

    public struct UserAnalytics: Codable {
        public let totalPlays: Int
        public let totalLikes: Int
        public let totalFollowers: Int
        public let totalDownloads: Int
        public let revenueEarned: Decimal
        public let topProjects: [CloudProject]
        public let followerGrowth: [ProjectAnalytics.DataPoint]
    }

    // MARK: - Request Helper

    private func request<T: Decodable>(
        endpoint: String,
        method: String,
        queryParams: [String: String]? = nil,
        body: (any Encodable)? = nil
    ) async throws -> T {
        var urlComponents = URLComponents(url: configuration.baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: true)!

        if let queryParams = queryParams {
            urlComponents.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let apiKey = configuration.apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }

        if let body = body {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func request<T: Decodable>(
        endpoint: String,
        method: String,
        queryParams: [String: String]? = nil,
        body: [String: Any]?
    ) async throws -> T {
        var urlComponents = URLComponents(url: configuration.baseURL.appendingPathComponent(endpoint), resolvingAgainstBaseURL: true)!

        if let queryParams = queryParams {
            urlComponents.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError(code: "NETWORK_ERROR", message: "Invalid response", details: nil)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError(
                code: "HTTP_\(httpResponse.statusCode)",
                message: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
                details: nil
            )
        }
    }
}

// MARK: - Helper Types

struct EmptyResponse: Codable {}

struct AnyEncodable: Encodable {
    let value: Encodable

    init(_ value: Encodable) {
        self.value = value
    }

    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}
