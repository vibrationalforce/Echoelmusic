//
//  SocialSharingSystem.swift
//  Echoelmusic
//
//  Social sharing, discovery, and community features for creators
//  with project sharing, collaboration, marketplace, and analytics.
//

import SwiftUI
import Combine
import AVFoundation

// MARK: - Social Sharing System

@MainActor
class SocialSharingSystem: ObservableObject {

    // MARK: - Published Properties

    @Published var currentUser: SocialUser?
    @Published var isSignedIn: Bool = false
    @Published var feed: [FeedItem] = []
    @Published var trendingProjects: [SharedProject] = []
    @Published var followedUsers: [SocialUser] = []
    @Published var followers: [SocialUser] = []
    @Published var notifications: [SocialNotification] = []
    @Published var messages: [DirectMessage] = []
    @Published var myProjects: [SharedProject] = []
    @Published var likedProjects: [SharedProject] = []
    @Published var savedProjects: [SharedProject] = []

    // MARK: - Discovery

    @Published var exploreCategories: [Category] = []
    @Published var featuredCreators: [SocialUser] = []
    @Published var challenges: [Challenge] = []
    @Published var playlists: [Playlist] = []

    // MARK: - Analytics

    @Published var analytics: UserAnalytics = UserAnalytics()

    // MARK: - Settings

    var privacyMode: PrivacyMode = .public
    var allowCollaborationRequests: Bool = true
    var allowComments: Bool = true
    var allowRemixes: Bool = true
    var notificationsEnabled: Bool = true

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        setupExploreCategories()
        loadCachedData()
    }

    // MARK: - Setup

    private func setupExploreCategories() {
        exploreCategories = [
            Category(name: "Electronic", icon: "waveform", color: "blue"),
            Category(name: "Hip Hop", icon: "music.mic", color: "purple"),
            Category(name: "Rock", icon: "guitars", color: "red"),
            Category(name: "Pop", icon: "star.fill", color: "pink"),
            Category(name: "Classical", icon: "music.quarternote.3", color: "gold"),
            Category(name: "Jazz", icon: "music.note", color: "orange"),
            Category(name: "Ambient", icon: "sparkles", color: "cyan"),
            Category(name: "Experimental", icon: "wand.and.stars", color: "green")
        ]
    }

    private func loadCachedData() {
        // In production, load from UserDefaults or database
    }

    // MARK: - Authentication

    func signIn(email: String, password: String) async throws {
        // In production, authenticate with backend
        try await Task.sleep(nanoseconds: 1_000_000_000)

        currentUser = SocialUser(
            id: UUID(),
            username: "creator123",
            displayName: "Creator",
            email: email,
            bio: "Music producer",
            profileImageURL: nil,
            followers: 0,
            following: 0,
            projectCount: 0,
            verified: false
        )

        isSignedIn = true
        await loadUserData()
    }

    func signOut() {
        currentUser = nil
        isSignedIn = false
        feed.removeAll()
        followedUsers.removeAll()
        notifications.removeAll()
    }

    func createAccount(email: String, username: String, password: String) async throws {
        // In production, create account on backend
        try await Task.sleep(nanoseconds: 1_000_000_000)
        try await signIn(email: email, password: password)
    }

    // MARK: - User Data

    private func loadUserData() async {
        await loadFeed()
        await loadFollowedUsers()
        await loadNotifications()
        await loadMyProjects()
    }

    func updateProfile(displayName: String, bio: String, profileImage: URL?) async throws {
        guard var user = currentUser else { return }

        user.displayName = displayName
        user.bio = bio
        user.profileImageURL = profileImage

        currentUser = user

        // In production, update on backend
    }

    // MARK: - Feed

    private func loadFeed() async {
        // In production, fetch from backend
        feed = generateMockFeed()
    }

    func refreshFeed() async {
        await loadFeed()
    }

    func loadMoreFeed() async {
        // In production, paginate from backend
        let moreFeed = generateMockFeed()
        feed.append(contentsOf: moreFeed)
    }

    private func generateMockFeed() -> [FeedItem] {
        // Mock data
        return []
    }

    // MARK: - Project Sharing

    func shareProject(_ project: LocalProject, settings: ShareSettings) async throws -> SharedProject {
        guard let user = currentUser else {
            throw SocialError.notSignedIn
        }

        // Prepare project for sharing
        let sharedProject = SharedProject(
            id: UUID(),
            title: project.name,
            description: settings.description,
            creator: user,
            createdAt: Date(),
            genre: settings.genre,
            tags: settings.tags,
            coverArtURL: settings.coverArtURL,
            audioURL: nil, // Will be uploaded
            waveformData: nil,
            likes: 0,
            plays: 0,
            downloads: 0,
            comments: [],
            isPublic: settings.isPublic,
            allowRemix: settings.allowRemix,
            allowDownload: settings.allowDownload,
            license: settings.license
        )

        // Upload audio file
        // In production, upload to storage service

        // Save to backend
        // In production, save to database

        myProjects.append(sharedProject)

        return sharedProject
    }

    func updateSharedProject(_ project: SharedProject) async throws {
        guard let index = myProjects.firstIndex(where: { $0.id == project.id }) else {
            throw SocialError.projectNotFound
        }

        myProjects[index] = project

        // In production, update on backend
    }

    func deleteSharedProject(_ project: SharedProject) async throws {
        myProjects.removeAll { $0.id == project.id }

        // In production, delete from backend
    }

    // MARK: - Interactions

    func likeProject(_ project: SharedProject) async throws {
        var updatedProject = project
        updatedProject.likes += 1

        if !likedProjects.contains(where: { $0.id == project.id }) {
            likedProjects.append(updatedProject)
        }

        // In production, update on backend

        // Send notification to creator
        sendNotification(to: project.creator, type: .like, content: "liked your project '\(project.title)'")
    }

    func unlikeProject(_ project: SharedProject) async throws {
        var updatedProject = project
        updatedProject.likes -= 1

        likedProjects.removeAll { $0.id == project.id }

        // In production, update on backend
    }

    func commentOnProject(_ project: SharedProject, text: String) async throws {
        guard let user = currentUser else {
            throw SocialError.notSignedIn
        }

        let comment = Comment(
            id: UUID(),
            author: user,
            text: text,
            createdAt: Date(),
            likes: 0,
            replies: []
        )

        // In production, save to backend

        // Send notification to creator
        sendNotification(to: project.creator, type: .comment, content: "commented on '\(project.title)': \(text)")
    }

    func saveProject(_ project: SharedProject) {
        if !savedProjects.contains(where: { $0.id == project.id }) {
            savedProjects.append(project)
        }
    }

    func unsaveProject(_ project: SharedProject) {
        savedProjects.removeAll { $0.id == project.id }
    }

    func shareProjectExternal(_ project: SharedProject, to platform: SocialPlatform) async throws {
        let shareURL = generateShareURL(for: project)

        switch platform {
        case .twitter:
            let text = "Check out my new track: \(project.title) on Echoelmusic! \(shareURL)"
            // In production, open Twitter share sheet

        case .facebook:
            // In production, open Facebook share dialog

        case .instagram:
            // In production, share to Instagram Stories

        case .tiktok:
            // In production, share to TikTok

        case .soundcloud:
            // In production, upload to SoundCloud API

        case .youtube:
            // In production, upload to YouTube API
        }
    }

    private func generateShareURL(for project: SharedProject) -> String {
        "https://echoelmusic.app/project/\(project.id.uuidString)"
    }

    // MARK: - Following

    func followUser(_ user: SocialUser) async throws {
        guard !followedUsers.contains(where: { $0.id == user.id }) else { return }

        followedUsers.append(user)

        // In production, update on backend

        // Send notification
        sendNotification(to: user, type: .follow, content: "started following you")
    }

    func unfollowUser(_ user: SocialUser) async throws {
        followedUsers.removeAll { $0.id == user.id }

        // In production, update on backend
    }

    private func loadFollowedUsers() async {
        // In production, fetch from backend
    }

    func loadFollowers() async {
        // In production, fetch from backend
    }

    // MARK: - Discovery

    func searchProjects(query: String, filters: SearchFilters) async throws -> [SharedProject] {
        // In production, search backend with filters
        return []
    }

    func searchUsers(query: String) async throws -> [SocialUser] {
        // In production, search backend
        return []
    }

    func loadTrendingProjects() async {
        // In production, fetch from backend with trending algorithm
        trendingProjects = []
    }

    func loadFeaturedCreators() async {
        // In production, fetch from backend
        featuredCreators = []
    }

    func loadChallenges() async {
        // In production, fetch from backend
        challenges = [
            Challenge(
                id: UUID(),
                title: "30 Day Producer Challenge",
                description: "Create one track every day for 30 days",
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 30, to: Date())!,
                participants: 1250,
                prize: "$500 + Featured Artist",
                rules: ["Original music only", "Daily submissions", "Any genre"],
                submissions: []
            ),
            Challenge(
                id: UUID(),
                title: "Lo-Fi Beat Battle",
                description: "Create the chillest lo-fi beat",
                startDate: Date(),
                endDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
                participants: 450,
                prize: "Collaboration with top producer",
                rules: ["Lo-fi genre", "Max 3 minutes", "Submit by deadline"],
                submissions: []
            )
        ]
    }

    func joinChallenge(_ challenge: Challenge) async throws {
        // In production, register user for challenge
        analytics.challengesJoined += 1
    }

    func submitToChallenge(_ challenge: Challenge, project: SharedProject) async throws {
        // In production, submit project to challenge
    }

    // MARK: - Collaboration

    func sendCollaborationRequest(to user: SocialUser, message: String) async throws {
        guard allowCollaborationRequests else {
            throw SocialError.collaborationDisabled
        }

        let request = CollaborationRequest(
            id: UUID(),
            from: currentUser!,
            to: user,
            message: message,
            status: .pending,
            createdAt: Date()
        )

        // In production, send to backend

        sendNotification(to: user, type: .collaborationRequest, content: "sent you a collaboration request: \(message)")
    }

    func acceptCollaborationRequest(_ request: CollaborationRequest) async throws {
        // In production, create collaboration session
    }

    func declineCollaborationRequest(_ request: CollaborationRequest) async throws {
        // In production, update request status
    }

    // MARK: - Notifications

    private func loadNotifications() async {
        // In production, fetch from backend
    }

    private func sendNotification(to user: SocialUser, type: NotificationType, content: String) {
        let notification = SocialNotification(
            id: UUID(),
            type: type,
            from: currentUser,
            to: user,
            content: content,
            createdAt: Date(),
            read: false
        )

        // In production, send to backend
    }

    func markNotificationAsRead(_ notification: SocialNotification) {
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].read = true
        }

        // In production, update on backend
    }

    func clearAllNotifications() {
        notifications.removeAll()

        // In production, delete on backend
    }

    // MARK: - Messaging

    func sendMessage(to user: SocialUser, text: String, attachment: URL? = nil) async throws {
        guard let sender = currentUser else {
            throw SocialError.notSignedIn
        }

        let message = DirectMessage(
            id: UUID(),
            from: sender,
            to: user,
            text: text,
            attachmentURL: attachment,
            sentAt: Date(),
            read: false
        )

        messages.append(message)

        // In production, send to backend

        sendNotification(to: user, type: .message, content: "sent you a message")
    }

    func loadMessages(with user: SocialUser) async throws -> [DirectMessage] {
        // In production, fetch from backend
        return messages.filter { ($0.from.id == user.id && $0.to.id == currentUser?.id) || ($0.from.id == currentUser?.id && $0.to.id == user.id) }
    }

    // MARK: - Analytics

    func trackPlay(for project: SharedProject) async {
        analytics.totalPlays += 1

        // In production, track on backend
    }

    func trackDownload(for project: SharedProject) async {
        analytics.totalDownloads += 1

        // In production, track on backend
    }

    func loadAnalytics() async {
        // In production, fetch from backend
        analytics = UserAnalytics(
            totalPlays: 1250,
            totalLikes: 450,
            totalDownloads: 180,
            totalFollowers: 125,
            totalProjects: 15,
            challengesJoined: 3,
            collaborations: 5,
            topCountries: ["United States": 450, "United Kingdom": 200, "Germany": 150],
            topGenres: ["Electronic": 600, "Hip Hop": 400, "Ambient": 250],
            playsByDate: generateMockPlaysByDate()
        )
    }

    private func generateMockPlaysByDate() -> [Date: Int] {
        var data: [Date: Int] = [:]
        let calendar = Calendar.current

        for i in 0..<30 {
            if let date = calendar.date(byAdding: .day, value: -i, to: Date()) {
                data[date] = Int.random(in: 10...100)
            }
        }

        return data
    }

    // MARK: - Marketplace

    func listPresetForSale(preset: Preset, price: Decimal, description: String) async throws {
        // In production, create marketplace listing
    }

    func listSamplePackForSale(pack: SamplePack, price: Decimal, description: String) async throws {
        // In production, create marketplace listing
    }

    func purchaseItem(_ item: MarketplaceItem) async throws {
        // In production, process payment
        analytics.totalSpent += item.price
    }

    func downloadPurchasedItem(_ item: MarketplaceItem) async throws -> URL {
        // In production, download from storage
        throw SocialError.notImplemented
    }
}

// MARK: - Data Models

struct SocialUser: Identifiable, Codable, Equatable {
    let id: UUID
    var username: String
    var displayName: String
    var email: String
    var bio: String
    var profileImageURL: URL?
    var coverImageURL: URL?
    var followers: Int
    var following: Int
    var projectCount: Int
    var verified: Bool
    var createdAt: Date = Date()
    var links: [SocialLink] = []
}

struct SocialLink: Codable {
    var platform: String
    var url: URL
}

struct SharedProject: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var creator: SocialUser
    var createdAt: Date
    var genre: String
    var tags: [String]
    var coverArtURL: URL?
    var audioURL: URL?
    var waveformData: Data?
    var likes: Int
    var plays: Int
    var downloads: Int
    var comments: [Comment]
    var isPublic: Bool
    var allowRemix: Bool
    var allowDownload: Bool
    var license: License

    enum License: String, Codable {
        case allRightsReserved = "All Rights Reserved"
        case creativeCommons = "Creative Commons"
        case creativeCommonsNonCommercial = "CC BY-NC"
        case creativeCommonsShareAlike = "CC BY-SA"
        case publicDomain = "Public Domain"
    }
}

struct Comment: Identifiable, Codable {
    let id: UUID
    var author: SocialUser
    var text: String
    var createdAt: Date
    var likes: Int
    var replies: [Comment]
}

struct FeedItem: Identifiable {
    let id = UUID()
    var type: FeedItemType
    var user: SocialUser
    var project: SharedProject?
    var timestamp: Date

    enum FeedItemType {
        case newProject
        case like
        case comment
        case follow
        case remix
        case challenge
    }
}

struct Category: Identifiable {
    let id = UUID()
    var name: String
    var icon: String
    var color: String
}

struct Challenge: Identifiable {
    let id: UUID
    var title: String
    var description: String
    var startDate: Date
    var endDate: Date
    var participants: Int
    var prize: String
    var rules: [String]
    var submissions: [SharedProject]
}

struct Playlist: Identifiable {
    let id = UUID()
    var title: String
    var description: String
    var creator: SocialUser
    var projects: [SharedProject]
    var followers: Int
    var isPublic: Bool
}

struct SocialNotification: Identifiable {
    let id: UUID
    var type: NotificationType
    var from: SocialUser?
    var to: SocialUser
    var content: String
    var createdAt: Date
    var read: Bool
}

enum NotificationType {
    case like
    case comment
    case follow
    case collaborationRequest
    case message
    case mention
    case remix
    case challengeUpdate
}

struct DirectMessage: Identifiable {
    let id: UUID
    var from: SocialUser
    var to: SocialUser
    var text: String
    var attachmentURL: URL?
    var sentAt: Date
    var read: Bool
}

struct CollaborationRequest: Identifiable {
    let id: UUID
    var from: SocialUser
    var to: SocialUser
    var message: String
    var status: Status
    var createdAt: Date

    enum Status {
        case pending
        case accepted
        case declined
    }
}

struct UserAnalytics {
    var totalPlays: Int = 0
    var totalLikes: Int = 0
    var totalDownloads: Int = 0
    var totalFollowers: Int = 0
    var totalProjects: Int = 0
    var challengesJoined: Int = 0
    var collaborations: Int = 0
    var totalEarned: Decimal = 0
    var totalSpent: Decimal = 0
    var topCountries: [String: Int] = [:]
    var topGenres: [String: Int] = [:]
    var playsByDate: [Date: Int] = [:]
}

struct ShareSettings {
    var description: String
    var genre: String
    var tags: [String]
    var coverArtURL: URL?
    var isPublic: Bool
    var allowRemix: Bool
    var allowDownload: Bool
    var license: SharedProject.License
}

struct SearchFilters {
    var genre: String?
    var minDuration: TimeInterval?
    var maxDuration: TimeInterval?
    var minDate: Date?
    var maxDate: Date?
    var sortBy: SortOption

    enum SortOption {
        case recent
        case popular
        case trending
        case mostPlayed
        case mostLiked
    }
}

struct MarketplaceItem: Identifiable {
    let id = UUID()
    var type: ItemType
    var title: String
    var description: String
    var seller: SocialUser
    var price: Decimal
    var rating: Float
    var downloads: Int

    enum ItemType {
        case preset
        case samplePack
        case template
        case plugin
    }
}

struct Preset: Identifiable {
    let id = UUID()
    var name: String
    var category: String
}

struct SamplePack: Identifiable {
    let id = UUID()
    var name: String
    var sampleCount: Int
}

struct LocalProject {
    var name: String
}

enum SocialPlatform {
    case twitter
    case facebook
    case instagram
    case tiktok
    case soundcloud
    case youtube
}

enum PrivacyMode {
    case `public`
    case followers
    case `private`
}

enum SocialError: Error {
    case notSignedIn
    case projectNotFound
    case collaborationDisabled
    case notImplemented
}

// MARK: - SwiftUI Views

struct SocialFeedView: View {
    @StateObject private var socialSystem: SocialSharingSystem

    init(socialSystem: SocialSharingSystem) {
        _socialSystem = StateObject(wrappedValue: socialSystem)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(socialSystem.feed) { item in
                        FeedItemView(item: item, socialSystem: socialSystem)
                    }
                }
                .padding()
            }
            .navigationTitle("Feed")
            .refreshable {
                await socialSystem.refreshFeed()
            }
        }
    }
}

struct FeedItemView: View {
    let item: FeedItem
    @ObservedObject var socialSystem: SocialSharingSystem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // User info
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading) {
                    Text(item.user.displayName)
                        .font(.headline)
                    Text(item.timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Project preview
            if let project = item.project {
                ProjectPreviewCard(project: project, socialSystem: socialSystem)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct ProjectPreviewCard: View {
    let project: SharedProject
    @ObservedObject var socialSystem: SocialSharingSystem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover art
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 200)
                .cornerRadius(8)

            Text(project.title)
                .font(.headline)

            Text(project.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack {
                Label("\(project.plays)", systemImage: "play.fill")
                Label("\(project.likes)", systemImage: "heart.fill")
                Label("\(project.comments.count)", systemImage: "bubble.left.fill")
            }
            .font(.caption)
            .foregroundColor(.secondary)

            HStack {
                ForEach(project.tags.prefix(3), id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.2))
                        .cornerRadius(4)
                }
            }
        }
    }
}
