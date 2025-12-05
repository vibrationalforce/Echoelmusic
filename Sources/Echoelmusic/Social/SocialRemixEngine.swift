// SocialRemixEngine.swift
// Echoelmusic - Social Remix & Collaboration Platform
// Created by Claude (Phase 4) - December 2025

import Foundation
import CryptoKit

// MARK: - Artist Profile

/// Public artist profile
public struct ArtistProfile: Identifiable, Codable {
    public let id: UUID
    public var username: String
    public var displayName: String
    public var bio: String
    public var avatarURL: URL?
    public var bannerURL: URL?
    public var website: URL?
    public var socialLinks: [SocialLink]

    // Stats
    public var followerCount: Int
    public var followingCount: Int
    public var projectCount: Int
    public var remixCount: Int
    public var totalPlays: Int
    public var totalLikes: Int

    // Settings
    public var allowRemixes: Bool
    public var requireAttribution: Bool
    public var defaultLicense: CreativeLicense

    public var joinedDate: Date
    public var lastActiveDate: Date

    public init(username: String) {
        self.id = UUID()
        self.username = username
        self.displayName = username
        self.bio = ""
        self.socialLinks = []
        self.followerCount = 0
        self.followingCount = 0
        self.projectCount = 0
        self.remixCount = 0
        self.totalPlays = 0
        self.totalLikes = 0
        self.allowRemixes = true
        self.requireAttribution = true
        self.defaultLicense = .ccBySa
        self.joinedDate = Date()
        self.lastActiveDate = Date()
    }
}

public struct SocialLink: Codable {
    public var platform: SocialPlatform
    public var url: URL
    public var username: String?
}

public enum SocialPlatform: String, Codable, CaseIterable {
    case instagram, twitter, soundcloud, spotify, bandcamp
    case youtube, tiktok, twitch, discord, mastodon
}

// MARK: - Creative License

/// License types for shared projects
public enum CreativeLicense: String, Codable, CaseIterable {
    case allRightsReserved = "All Rights Reserved"
    case ccBy = "CC BY (Attribution)"
    case ccBySa = "CC BY-SA (Attribution-ShareAlike)"
    case ccByNc = "CC BY-NC (Attribution-NonCommercial)"
    case ccByNcSa = "CC BY-NC-SA (Attribution-NonCommercial-ShareAlike)"
    case cc0 = "CC0 (Public Domain)"
    case customLicense = "Custom License"

    var allowsRemixes: Bool {
        switch self {
        case .allRightsReserved: return false
        case .customLicense: return false  // Depends on terms
        default: return true
        }
    }

    var requiresAttribution: Bool {
        switch self {
        case .cc0: return false
        case .allRightsReserved: return false
        default: return true
        }
    }

    var allowsCommercialUse: Bool {
        switch self {
        case .ccByNc, .ccByNcSa: return false
        case .allRightsReserved, .customLicense: return false
        default: return true
        }
    }

    var requiresShareAlike: Bool {
        switch self {
        case .ccBySa, .ccByNcSa: return true
        default: return false
        }
    }

    var description: String {
        switch self {
        case .allRightsReserved:
            return "No remixes or derivatives allowed without explicit permission."
        case .ccBy:
            return "Free to remix and share with attribution."
        case .ccBySa:
            return "Free to remix with attribution. Derivatives must use same license."
        case .ccByNc:
            return "Free to remix for non-commercial use with attribution."
        case .ccByNcSa:
            return "Non-commercial remixes with attribution. Same license required."
        case .cc0:
            return "Public domain. No restrictions."
        case .customLicense:
            return "See project description for license terms."
        }
    }
}

// MARK: - Project

/// A shared music project
public struct SharedProject: Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var description: String
    public var artistId: UUID
    public var artistUsername: String

    // Content
    public var coverArtURL: URL?
    public var audioPreviewURL: URL?
    public var projectFileURL: URL?  // Downloadable project
    public var stemsURLs: [URL]?      // Individual stems

    // Metadata
    public var bpm: Float?
    public var key: String?
    public var genre: [String]
    public var tags: [String]
    public var duration: TimeInterval

    // Licensing
    public var license: CreativeLicense
    public var customLicenseTerms: String?
    public var allowRemixes: Bool
    public var allowStemDownload: Bool

    // Stats
    public var playCount: Int
    public var likeCount: Int
    public var remixCount: Int
    public var downloadCount: Int
    public var commentCount: Int

    // Remix chain
    public var isRemix: Bool
    public var originalProjectId: UUID?
    public var remixChain: [RemixAttribution]  // Full attribution chain

    // Timestamps
    public var createdAt: Date
    public var updatedAt: Date
    public var publishedAt: Date?

    // Visibility
    public var visibility: ProjectVisibility

    public init(title: String, artistId: UUID, artistUsername: String) {
        self.id = UUID()
        self.title = title
        self.description = ""
        self.artistId = artistId
        self.artistUsername = artistUsername
        self.genre = []
        self.tags = []
        self.duration = 0
        self.license = .ccBySa
        self.allowRemixes = true
        self.allowStemDownload = true
        self.playCount = 0
        self.likeCount = 0
        self.remixCount = 0
        self.downloadCount = 0
        self.commentCount = 0
        self.isRemix = false
        self.remixChain = []
        self.createdAt = Date()
        self.updatedAt = Date()
        self.visibility = .draft
    }
}

public enum ProjectVisibility: String, Codable {
    case draft = "Draft"
    case privateProject = "Private"
    case unlisted = "Unlisted"
    case publicProject = "Public"
}

// MARK: - Remix Attribution

/// Attribution for remix chain
public struct RemixAttribution: Codable, Identifiable {
    public let id: UUID
    public var projectId: UUID
    public var projectTitle: String
    public var artistId: UUID
    public var artistUsername: String
    public var license: CreativeLicense
    public var remixedAt: Date
    public var generation: Int  // 1 = first remix, 2 = remix of remix, etc.

    public init(project: SharedProject, generation: Int) {
        self.id = UUID()
        self.projectId = project.id
        self.projectTitle = project.title
        self.artistId = project.artistId
        self.artistUsername = project.artistUsername
        self.license = project.license
        self.remixedAt = Date()
        self.generation = generation
    }
}

// MARK: - Version History

/// Version control for projects
public struct ProjectVersion: Identifiable, Codable {
    public let id: UUID
    public var projectId: UUID
    public var versionNumber: Int
    public var commitMessage: String
    public var projectFileURL: URL
    public var createdAt: Date
    public var changesSummary: String?

    public init(projectId: UUID, versionNumber: Int, commitMessage: String, fileURL: URL) {
        self.id = UUID()
        self.projectId = projectId
        self.versionNumber = versionNumber
        self.commitMessage = commitMessage
        self.projectFileURL = fileURL
        self.createdAt = Date()
    }
}

// MARK: - Collaboration

/// Real-time collaboration session
public struct CollaborationSession: Identifiable, Codable {
    public let id: UUID
    public var projectId: UUID
    public var hostArtistId: UUID
    public var participants: [CollaborationParticipant]
    public var status: SessionStatus
    public var createdAt: Date
    public var maxParticipants: Int

    public enum SessionStatus: String, Codable {
        case waiting, active, paused, ended
    }

    public init(projectId: UUID, hostId: UUID) {
        self.id = UUID()
        self.projectId = projectId
        self.hostArtistId = hostId
        self.participants = []
        self.status = .waiting
        self.createdAt = Date()
        self.maxParticipants = 4
    }
}

public struct CollaborationParticipant: Codable, Identifiable {
    public var id: UUID { artistId }
    public var artistId: UUID
    public var username: String
    public var role: ParticipantRole
    public var joinedAt: Date
    public var permissions: Set<CollaborationPermission>

    public enum ParticipantRole: String, Codable {
        case host, editor, viewer
    }
}

public enum CollaborationPermission: String, Codable {
    case editTracks, editEffects, editArrangement
    case addTracks, deleteTracks
    case exportProject, inviteOthers
}

// MARK: - Comments & Feedback

public struct ProjectComment: Identifiable, Codable {
    public let id: UUID
    public var projectId: UUID
    public var authorId: UUID
    public var authorUsername: String
    public var content: String
    public var timestamp: TimeInterval?  // Position in track for timestamped comments
    public var parentCommentId: UUID?    // For replies
    public var likeCount: Int
    public var createdAt: Date
    public var isEdited: Bool

    public init(projectId: UUID, authorId: UUID, authorUsername: String, content: String) {
        self.id = UUID()
        self.projectId = projectId
        self.authorId = authorId
        self.authorUsername = authorUsername
        self.content = content
        self.likeCount = 0
        self.createdAt = Date()
        self.isEdited = false
    }
}

// MARK: - Discovery

/// Recommendation algorithm inputs
public struct DiscoveryPreferences: Codable {
    public var favoriteGenres: [String]
    public var favoriteTags: [String]
    public var followedArtists: [UUID]
    public var likedProjects: [UUID]
    public var recentlyPlayed: [UUID]
    public var preferredBPMRange: ClosedRange<Float>?
    public var preferredKeys: [String]?
}

public struct DiscoveryResult: Identifiable {
    public let id = UUID()
    public var project: SharedProject
    public var relevanceScore: Float
    public var matchReasons: [String]
}

// MARK: - Feed Item

public enum FeedItem: Identifiable {
    case newProject(SharedProject)
    case newRemix(SharedProject, original: SharedProject)
    case collaboration(CollaborationSession)
    case artistUpdate(ArtistProfile, message: String)
    case milestone(ArtistProfile, milestone: String)

    public var id: UUID {
        switch self {
        case .newProject(let project): return project.id
        case .newRemix(let remix, _): return remix.id
        case .collaboration(let session): return session.id
        case .artistUpdate(let artist, _): return artist.id
        case .milestone(let artist, _): return artist.id
        }
    }

    public var timestamp: Date {
        switch self {
        case .newProject(let project): return project.createdAt
        case .newRemix(let remix, _): return remix.createdAt
        case .collaboration(let session): return session.createdAt
        case .artistUpdate(let artist, _): return artist.lastActiveDate
        case .milestone(let artist, _): return artist.lastActiveDate
        }
    }
}

// MARK: - Social Remix Engine

/// Main social and remix platform engine
public actor SocialRemixEngine {

    public static let shared = SocialRemixEngine()

    // Local storage
    private var currentUser: ArtistProfile?
    private var projects: [UUID: SharedProject] = [:]
    private var artists: [UUID: ArtistProfile] = [:]
    private var versions: [UUID: [ProjectVersion]] = [:]
    private var comments: [UUID: [ProjectComment]] = [:]

    // Discovery
    private var discoveryPreferences: DiscoveryPreferences?

    private init() {}

    // MARK: - User Management

    public func setCurrentUser(_ profile: ArtistProfile) {
        currentUser = profile
        artists[profile.id] = profile
    }

    public func getCurrentUser() -> ArtistProfile? {
        currentUser
    }

    public func updateProfile(_ profile: ArtistProfile) {
        artists[profile.id] = profile
        if profile.id == currentUser?.id {
            currentUser = profile
        }
    }

    public func getArtist(id: UUID) -> ArtistProfile? {
        artists[id]
    }

    public func searchArtists(query: String) -> [ArtistProfile] {
        let lowercaseQuery = query.lowercased()
        return artists.values.filter {
            $0.username.lowercased().contains(lowercaseQuery) ||
            $0.displayName.lowercased().contains(lowercaseQuery)
        }
    }

    // MARK: - Project Management

    public func createProject(title: String) -> SharedProject? {
        guard let user = currentUser else { return nil }

        var project = SharedProject(title: title, artistId: user.id, artistUsername: user.username)
        project.license = user.defaultLicense
        project.allowRemixes = user.allowRemixes

        projects[project.id] = project
        return project
    }

    public func updateProject(_ project: SharedProject) {
        var updated = project
        updated.updatedAt = Date()
        projects[project.id] = updated
    }

    public func deleteProject(id: UUID) {
        projects.removeValue(forKey: id)
        versions.removeValue(forKey: id)
        comments.removeValue(forKey: id)
    }

    public func getProject(id: UUID) -> SharedProject? {
        projects[id]
    }

    public func getProjectsByArtist(id: UUID) -> [SharedProject] {
        projects.values.filter { $0.artistId == id }
    }

    public func publishProject(id: UUID) {
        guard var project = projects[id] else { return }
        project.visibility = .publicProject
        project.publishedAt = Date()
        projects[id] = project
    }

    // MARK: - Remix System

    /// Fork a project for remixing
    public func forkProject(originalId: UUID, newTitle: String) async -> SharedProject? {
        guard let user = currentUser,
              let original = projects[originalId],
              original.allowRemixes,
              original.license.allowsRemixes else {
            return nil
        }

        var remix = SharedProject(title: newTitle, artistId: user.id, artistUsername: user.username)

        // Set up remix chain
        remix.isRemix = true
        remix.originalProjectId = originalId

        // Build attribution chain
        var chain = original.remixChain
        chain.append(RemixAttribution(project: original, generation: chain.count + 1))
        remix.remixChain = chain

        // Inherit license if ShareAlike
        if original.license.requiresShareAlike {
            remix.license = original.license
        }

        // Copy metadata
        remix.bpm = original.bpm
        remix.key = original.key
        remix.genre = original.genre

        projects[remix.id] = remix

        // Update original's remix count
        if var orig = projects[originalId] {
            orig.remixCount += 1
            projects[originalId] = orig
        }

        return remix
    }

    /// Get all remixes of a project
    public func getRemixes(of projectId: UUID) -> [SharedProject] {
        projects.values.filter { $0.originalProjectId == projectId }
    }

    /// Get full remix tree (original + all descendants)
    public func getRemixTree(rootId: UUID) -> [SharedProject] {
        var tree: [SharedProject] = []

        // Add root
        if let root = projects[rootId] {
            tree.append(root)
        }

        // Recursively find all remixes
        func addRemixes(of id: UUID) {
            let remixes = getRemixes(of: id)
            tree.append(contentsOf: remixes)
            for remix in remixes {
                addRemixes(of: remix.id)
            }
        }

        addRemixes(of: rootId)
        return tree
    }

    /// Generate attribution text for a remix
    public func generateAttributionText(for project: SharedProject) -> String {
        guard !project.remixChain.isEmpty else {
            return "Original work by \(project.artistUsername)"
        }

        var lines: [String] = ["\"\(project.title)\" by \(project.artistUsername)"]
        lines.append("")
        lines.append("Remix chain:")

        for (index, attribution) in project.remixChain.enumerated() {
            let prefix = String(repeating: "  ", count: index)
            lines.append("\(prefix)↳ \"\(attribution.projectTitle)\" by \(attribution.artistUsername)")
            lines.append("\(prefix)  License: \(attribution.license.rawValue)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Version Control

    public func saveVersion(projectId: UUID, message: String, fileURL: URL) {
        let projectVersions = versions[projectId] ?? []
        let versionNumber = projectVersions.count + 1

        let version = ProjectVersion(
            projectId: projectId,
            versionNumber: versionNumber,
            commitMessage: message,
            fileURL: fileURL
        )

        versions[projectId, default: []].append(version)
    }

    public func getVersionHistory(projectId: UUID) -> [ProjectVersion] {
        versions[projectId] ?? []
    }

    public func revertToVersion(projectId: UUID, versionId: UUID) -> ProjectVersion? {
        versions[projectId]?.first { $0.id == versionId }
    }

    // MARK: - Comments

    public func addComment(projectId: UUID, content: String, timestamp: TimeInterval? = nil) -> ProjectComment? {
        guard let user = currentUser else { return nil }

        var comment = ProjectComment(
            projectId: projectId,
            authorId: user.id,
            authorUsername: user.username,
            content: content
        )
        comment.timestamp = timestamp

        comments[projectId, default: []].append(comment)

        // Update project comment count
        if var project = projects[projectId] {
            project.commentCount += 1
            projects[projectId] = project
        }

        return comment
    }

    public func getComments(projectId: UUID) -> [ProjectComment] {
        comments[projectId] ?? []
    }

    public func getTimestampedComments(projectId: UUID) -> [ProjectComment] {
        (comments[projectId] ?? []).filter { $0.timestamp != nil }
            .sorted { ($0.timestamp ?? 0) < ($1.timestamp ?? 0) }
    }

    // MARK: - Social Actions

    public func likeProject(id: UUID) {
        guard var project = projects[id] else { return }
        project.likeCount += 1
        projects[id] = project

        // Update user preferences
        discoveryPreferences?.likedProjects.append(id)
    }

    public func unlikeProject(id: UUID) {
        guard var project = projects[id] else { return }
        project.likeCount = max(0, project.likeCount - 1)
        projects[id] = project

        discoveryPreferences?.likedProjects.removeAll { $0 == id }
    }

    public func recordPlay(projectId: UUID) {
        guard var project = projects[projectId] else { return }
        project.playCount += 1
        projects[projectId] = project

        // Update recent plays
        discoveryPreferences?.recentlyPlayed.insert(projectId, at: 0)
        if (discoveryPreferences?.recentlyPlayed.count ?? 0) > 100 {
            discoveryPreferences?.recentlyPlayed.removeLast()
        }
    }

    public func followArtist(id: UUID) {
        guard var artist = artists[id],
              var user = currentUser else { return }

        artist.followerCount += 1
        user.followingCount += 1

        artists[id] = artist
        currentUser = user

        discoveryPreferences?.followedArtists.append(id)
    }

    public func unfollowArtist(id: UUID) {
        guard var artist = artists[id],
              var user = currentUser else { return }

        artist.followerCount = max(0, artist.followerCount - 1)
        user.followingCount = max(0, user.followingCount - 1)

        artists[id] = artist
        currentUser = user

        discoveryPreferences?.followedArtists.removeAll { $0 == id }
    }

    // MARK: - Discovery

    public func setDiscoveryPreferences(_ prefs: DiscoveryPreferences) {
        discoveryPreferences = prefs
    }

    public func discover(limit: Int = 20) -> [DiscoveryResult] {
        var results: [DiscoveryResult] = []
        let prefs = discoveryPreferences ?? DiscoveryPreferences(
            favoriteGenres: [], favoriteTags: [], followedArtists: [],
            likedProjects: [], recentlyPlayed: []
        )

        for project in projects.values where project.visibility == .publicProject {
            var score: Float = 0
            var reasons: [String] = []

            // Genre match
            let genreOverlap = Set(project.genre).intersection(Set(prefs.favoriteGenres))
            if !genreOverlap.isEmpty {
                score += Float(genreOverlap.count) * 0.2
                reasons.append("Matches your favorite genres: \(genreOverlap.joined(separator: ", "))")
            }

            // Tag match
            let tagOverlap = Set(project.tags).intersection(Set(prefs.favoriteTags))
            if !tagOverlap.isEmpty {
                score += Float(tagOverlap.count) * 0.15
                reasons.append("Has tags you like")
            }

            // From followed artist
            if prefs.followedArtists.contains(project.artistId) {
                score += 0.3
                reasons.append("From artist you follow")
            }

            // BPM match
            if let bpm = project.bpm, let range = prefs.preferredBPMRange {
                if range.contains(bpm) {
                    score += 0.1
                    reasons.append("BPM in your preferred range")
                }
            }

            // Key match
            if let key = project.key, let preferred = prefs.preferredKeys {
                if preferred.contains(key) {
                    score += 0.1
                    reasons.append("In a key you like")
                }
            }

            // Popularity boost
            let popularityScore = log10(Float(project.playCount + 1)) / 10
            score += min(0.15, popularityScore)

            // Recency boost
            let ageInDays = Date().timeIntervalSince(project.createdAt) / 86400
            if ageInDays < 7 {
                score += 0.1
                reasons.append("Recently released")
            }

            // Avoid already played
            if prefs.recentlyPlayed.contains(project.id) {
                score -= 0.5
            }

            if score > 0.1 && !prefs.recentlyPlayed.contains(project.id) {
                results.append(DiscoveryResult(
                    project: project,
                    relevanceScore: score,
                    matchReasons: reasons
                ))
            }
        }

        return results
            .sorted { $0.relevanceScore > $1.relevanceScore }
            .prefix(limit)
            .map { $0 }
    }

    public func searchProjects(query: String, filters: SearchFilters? = nil) -> [SharedProject] {
        let lowercaseQuery = query.lowercased()

        return projects.values.filter { project in
            guard project.visibility == .publicProject else { return false }

            // Text search
            let matchesQuery = project.title.lowercased().contains(lowercaseQuery) ||
                              project.description.lowercased().contains(lowercaseQuery) ||
                              project.artistUsername.lowercased().contains(lowercaseQuery) ||
                              project.tags.contains { $0.lowercased().contains(lowercaseQuery) } ||
                              project.genre.contains { $0.lowercased().contains(lowercaseQuery) }

            guard matchesQuery else { return false }

            // Apply filters
            if let filters = filters {
                if let genres = filters.genres, !genres.isEmpty {
                    guard !Set(project.genre).isDisjoint(with: Set(genres)) else { return false }
                }

                if let bpmRange = filters.bpmRange, let bpm = project.bpm {
                    guard bpmRange.contains(bpm) else { return false }
                }

                if let key = filters.key, project.key != key {
                    return false
                }

                if filters.remixableOnly && !project.allowRemixes {
                    return false
                }

                if filters.hasStemsOnly && project.stemsURLs == nil {
                    return false
                }
            }

            return true
        }
    }

    public struct SearchFilters {
        public var genres: [String]?
        public var bpmRange: ClosedRange<Float>?
        public var key: String?
        public var remixableOnly: Bool = false
        public var hasStemsOnly: Bool = false
        public var license: CreativeLicense?
        public var sortBy: SortOption = .relevance

        public enum SortOption {
            case relevance, newest, mostPlayed, mostLiked, mostRemixed
        }
    }

    // MARK: - Feed

    public func getFeed(limit: Int = 50) -> [FeedItem] {
        var items: [FeedItem] = []
        let followedIds = discoveryPreferences?.followedArtists ?? []

        // Get recent projects from followed artists
        for project in projects.values {
            guard followedIds.contains(project.artistId) else { continue }
            guard project.visibility == .publicProject else { continue }

            if project.isRemix, let originalId = project.originalProjectId,
               let original = projects[originalId] {
                items.append(.newRemix(project, original: original))
            } else {
                items.append(.newProject(project))
            }
        }

        // Sort by timestamp
        return items.sorted { $0.timestamp > $1.timestamp }.prefix(limit).map { $0 }
    }

    // MARK: - Export

    public func exportProjectBundle(projectId: UUID) -> ProjectBundle? {
        guard let project = projects[projectId] else { return nil }

        return ProjectBundle(
            project: project,
            versions: versions[projectId] ?? [],
            comments: comments[projectId] ?? [],
            attributionText: generateAttributionText(for: project)
        )
    }

    public struct ProjectBundle: Codable {
        public var project: SharedProject
        public var versions: [ProjectVersion]
        public var comments: [ProjectComment]
        public var attributionText: String
    }
}

// MARK: - Notification Types

public enum SocialNotification: Identifiable {
    case newFollower(ArtistProfile)
    case projectLiked(SharedProject, by: ArtistProfile)
    case projectRemixed(SharedProject, remix: SharedProject)
    case newComment(ProjectComment, on: SharedProject)
    case collaborationInvite(CollaborationSession, from: ArtistProfile)

    public var id: String {
        switch self {
        case .newFollower(let artist): return "follow_\(artist.id)"
        case .projectLiked(let project, let artist): return "like_\(project.id)_\(artist.id)"
        case .projectRemixed(let project, let remix): return "remix_\(project.id)_\(remix.id)"
        case .newComment(let comment, _): return "comment_\(comment.id)"
        case .collaborationInvite(let session, _): return "collab_\(session.id)"
        }
    }
}
