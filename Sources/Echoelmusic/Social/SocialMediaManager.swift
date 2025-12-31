import Foundation
import Combine
import UIKit
import AuthenticationServices

/// SocialMediaManager - One-Click Multi-Platform Publishing
///
/// Ermöglicht gleichzeitiges Posten/Live-Gehen auf allen Plattformen:
/// - Instagram, TikTok, YouTube, Facebook, Twitter/X
/// - Twitch, Kick, LinkedIn
///
/// Features:
/// - One-Click Live auf allen Plattformen
/// - One-Click Post auf allen Plattformen
/// - Plattform-spezifische Optimierung (Format, Hashtags)
/// - Scheduling (geplantes Posten)
/// - Analytics Dashboard
/// Migrated to @Observable for better performance (Swift 5.9+)
@MainActor
@Observable
final class SocialMediaManager {

    // MARK: - Singleton

    static let shared = SocialMediaManager()

    // MARK: - Observable State

    var connectedPlatforms: Set<Platform> = []
    var isPosting: Bool = false
    var isLive: Bool = false
    var postProgress: [Platform: PostStatus] = [:]
    var liveStatus: [Platform: LiveStatus] = [:]

    // MARK: - Platform Definition

    enum Platform: String, CaseIterable, Identifiable {
        case instagram = "Instagram"
        case tiktok = "TikTok"
        case youtube = "YouTube"
        case facebook = "Facebook"
        case twitter = "X (Twitter)"
        case twitch = "Twitch"
        case kick = "Kick"
        case linkedin = "LinkedIn"
        case threads = "Threads"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .instagram: return "camera.circle.fill"
            case .tiktok: return "music.note"
            case .youtube: return "play.rectangle.fill"
            case .facebook: return "person.2.circle.fill"
            case .twitter: return "bubble.left.fill"
            case .twitch: return "tv.fill"
            case .kick: return "bolt.circle.fill"
            case .linkedin: return "briefcase.fill"
            case .threads: return "at.circle.fill"
            }
        }

        var color: String {
            switch self {
            case .instagram: return "#E4405F"
            case .tiktok: return "#000000"
            case .youtube: return "#FF0000"
            case .facebook: return "#1877F2"
            case .twitter: return "#000000"
            case .twitch: return "#9146FF"
            case .kick: return "#53FC18"
            case .linkedin: return "#0A66C2"
            case .threads: return "#000000"
            }
        }

        var supportsLive: Bool {
            switch self {
            case .instagram, .tiktok, .youtube, .facebook, .twitch, .kick, .linkedin:
                return true
            case .twitter, .threads:
                return false
            }
        }

        var supportsVideo: Bool {
            return true // Alle unterstützen Video
        }

        var maxVideoDuration: Int { // Sekunden
            switch self {
            case .instagram: return 90  // Reels
            case .tiktok: return 180    // 3 Minuten
            case .youtube: return 43200 // 12 Stunden
            case .facebook: return 14400 // 4 Stunden
            case .twitter: return 140   // 2:20
            case .twitch: return 0      // Unlimited (Live)
            case .kick: return 0        // Unlimited (Live)
            case .linkedin: return 600  // 10 Minuten
            case .threads: return 300   // 5 Minuten
            }
        }

        var optimalResolution: (width: Int, height: Int) {
            switch self {
            case .instagram, .tiktok, .threads:
                return (1080, 1920) // 9:16 Portrait
            case .youtube, .facebook, .twitter, .linkedin:
                return (1920, 1080) // 16:9 Landscape
            case .twitch, .kick:
                return (1920, 1080) // 16:9 Landscape
            }
        }
    }

    // MARK: - Status Types

    enum PostStatus: Equatable {
        case idle
        case preparing
        case uploading(progress: Double)
        case processing
        case completed(url: String)
        case failed(error: String)
    }

    enum LiveStatus: Equatable {
        case offline
        case connecting
        case live(viewers: Int, duration: TimeInterval)
        case ended
        case failed(error: String)
    }

    // MARK: - Platform Credentials

    struct PlatformCredentials: Codable {
        var accessToken: String
        var refreshToken: String?
        var expiresAt: Date?
        var streamKey: String?
        var channelId: String?
    }

    private var credentials: [Platform: PlatformCredentials] = [:]

    // MARK: - Content

    struct Content {
        var videoURL: URL?
        var audioURL: URL?
        var thumbnailImage: UIImage?
        var title: String
        var description: String
        var hashtags: [String]
        var scheduledTime: Date?
        var visibility: Visibility

        enum Visibility: String, CaseIterable {
            case `public` = "Öffentlich"
            case unlisted = "Nicht gelistet"
            case `private` = "Privat"
            case followers = "Nur Follower"
        }
    }

    // MARK: - RTMP Endpoints

    private let rtmpEndpoints: [Platform: String] = [
        .youtube: "rtmp://a.rtmp.youtube.com/live2/",
        .twitch: "rtmp://live.twitch.tv/app/",
        .facebook: "rtmps://live-api-s.facebook.com:443/rtmp/",
        .kick: "rtmp://ingest.kick.com/live/",
        .instagram: "rtmps://live-upload.instagram.com:443/rtmp/",
        .tiktok: "rtmp://push.tiktok.com/live/",
        .linkedin: "rtmp://live.linkedin.com/live/"
    ]

    // MARK: - Initialization

    private init() {
        loadCredentials()
        #if DEBUG
        debugLog("✅ SocialMediaManager: Initialized")
        debugLog("📱 Supported Platforms: \(Platform.allCases.count)")
        #endif
    }

    // MARK: - One-Click Live

    /// 🔴 ONE-CLICK LIVE - Gehe auf allen verbundenen Plattformen gleichzeitig live
    func goLiveEverywhere(title: String, description: String) async throws {
        guard !connectedPlatforms.isEmpty else {
            throw SocialMediaError.noPlatformsConnected
        }

        let livePlatforms = connectedPlatforms.filter { $0.supportsLive }
        guard !livePlatforms.isEmpty else {
            throw SocialMediaError.noLivePlatformsConnected
        }

        isLive = true

        // Starte Live auf allen Plattformen parallel
        await withTaskGroup(of: (Platform, Result<Void, Error>).self) { group in
            for platform in livePlatforms {
                group.addTask {
                    do {
                        try await self.startLive(on: platform, title: title, description: description)
                        return (platform, .success(()))
                    } catch {
                        return (platform, .failure(error))
                    }
                }
            }

            for await (platform, result) in group {
                await MainActor.run {
                    switch result {
                    case .success:
                        self.liveStatus[platform] = .live(viewers: 0, duration: 0)
                        #if DEBUG
                        debugLog("🔴 LIVE auf \(platform.rawValue)")
                        #endif
                    case .failure(let error):
                        self.liveStatus[platform] = .failed(error: error.localizedDescription)
                        #if DEBUG
                        debugLog("❌ Live fehlgeschlagen auf \(platform.rawValue): \(error)")
                        #endif
                    }
                }
            }
        }

        #if DEBUG
        debugLog("🔴 LIVE AUF \(livePlatforms.count) PLATTFORMEN!")
        #endif
    }

    /// Beende Live auf allen Plattformen
    func endLiveEverywhere() async {
        for platform in connectedPlatforms where liveStatus[platform] != nil {
            await endLive(on: platform)
        }
        isLive = false
        #if DEBUG
        debugLog("⬛ Live beendet auf allen Plattformen")
        #endif
    }

    // MARK: - One-Click Post

    /// 📤 ONE-CLICK POST - Poste auf allen verbundenen Plattformen gleichzeitig
    func postEverywhere(content: Content) async throws {
        guard !connectedPlatforms.isEmpty else {
            throw SocialMediaError.noPlatformsConnected
        }

        isPosting = true

        // Poste auf allen Plattformen parallel
        await withTaskGroup(of: (Platform, Result<String, Error>).self) { group in
            for platform in connectedPlatforms {
                group.addTask {
                    do {
                        // Optimiere Content für Plattform
                        let optimizedContent = await self.optimizeContent(content, for: platform)
                        let postURL = try await self.post(optimizedContent, to: platform)
                        return (platform, .success(postURL))
                    } catch {
                        return (platform, .failure(error))
                    }
                }
            }

            for await (platform, result) in group {
                await MainActor.run {
                    switch result {
                    case .success(let url):
                        self.postProgress[platform] = .completed(url: url)
                        #if DEBUG
                        debugLog("✅ Gepostet auf \(platform.rawValue): \(url)")
                        #endif
                    case .failure(let error):
                        self.postProgress[platform] = .failed(error: error.localizedDescription)
                        #if DEBUG
                        debugLog("❌ Post fehlgeschlagen auf \(platform.rawValue): \(error)")
                        #endif
                    }
                }
            }
        }

        isPosting = false
        #if DEBUG
        debugLog("📤 GEPOSTET AUF \(connectedPlatforms.count) PLATTFORMEN!")
        #endif
    }

    // MARK: - Platform Connection

    /// Verbinde mit einer Plattform (OAuth)
    func connect(to platform: Platform) async throws {
        // Simuliere OAuth Flow
        #if DEBUG
        debugLog("🔗 Verbinde mit \(platform.rawValue)...")
        #endif

        // In echter Implementierung: OAuth Flow mit ASWebAuthenticationSession
        // Hier: Simulierte Verbindung

        connectedPlatforms.insert(platform)
        postProgress[platform] = .idle
        liveStatus[platform] = .offline

        #if DEBUG
        debugLog("✅ Verbunden mit \(platform.rawValue)")
        #endif
    }

    /// Trenne Verbindung zu einer Plattform
    func disconnect(from platform: Platform) {
        connectedPlatforms.remove(platform)
        credentials.removeValue(forKey: platform)
        postProgress.removeValue(forKey: platform)
        liveStatus.removeValue(forKey: platform)
        saveCredentials()

        #if DEBUG
        debugLog("🔌 Getrennt von \(platform.rawValue)")
        #endif
    }

    // MARK: - Private Methods

    private func startLive(on platform: Platform, title: String, description: String) async throws {
        guard let creds = credentials[platform], let streamKey = creds.streamKey else {
            throw SocialMediaError.notAuthenticated(platform)
        }

        guard let rtmpEndpoint = rtmpEndpoints[platform] else {
            throw SocialMediaError.platformNotSupported(platform)
        }

        let rtmpURL = rtmpEndpoint + streamKey

        // Verbinde StreamEngine mit RTMP
        // StreamEngine.shared.addDestination(rtmpURL, for: platform)

        await MainActor.run {
            liveStatus[platform] = .connecting
        }

        // Simuliere Verbindung
        try await Task.sleep(nanoseconds: 1_000_000_000)

        await MainActor.run {
            liveStatus[platform] = .live(viewers: 0, duration: 0)
        }
    }

    private func endLive(on platform: Platform) async {
        // StreamEngine.shared.removeDestination(for: platform)
        await MainActor.run {
            liveStatus[platform] = .ended
        }
    }

    private func post(_ content: Content, to platform: Platform) async throws -> String {
        guard credentials[platform] != nil else {
            throw SocialMediaError.notAuthenticated(platform)
        }

        await MainActor.run {
            postProgress[platform] = .preparing
        }

        // Simuliere Upload
        for progress in stride(from: 0.0, to: 1.0, by: 0.1) {
            try await Task.sleep(nanoseconds: 100_000_000)
            await MainActor.run {
                self.postProgress[platform] = .uploading(progress: progress)
            }
        }

        await MainActor.run {
            postProgress[platform] = .processing
        }

        try await Task.sleep(nanoseconds: 500_000_000)

        // Generiere Post URL
        let postId = UUID().uuidString.prefix(8)
        let url: String

        switch platform {
        case .instagram:
            url = "https://instagram.com/p/\(postId)"
        case .tiktok:
            url = "https://tiktok.com/@user/video/\(postId)"
        case .youtube:
            url = "https://youtube.com/watch?v=\(postId)"
        case .facebook:
            url = "https://facebook.com/watch/?v=\(postId)"
        case .twitter:
            url = "https://x.com/user/status/\(postId)"
        case .twitch:
            url = "https://twitch.tv/videos/\(postId)"
        case .kick:
            url = "https://kick.com/video/\(postId)"
        case .linkedin:
            url = "https://linkedin.com/posts/\(postId)"
        case .threads:
            url = "https://threads.net/@user/post/\(postId)"
        }

        return url
    }

    private func optimizeContent(_ content: Content, for platform: Platform) async -> Content {
        var optimized = content

        // Plattform-spezifische Hashtags
        switch platform {
        case .instagram:
            optimized.hashtags.append(contentsOf: ["#reels", "#viral", "#explore"])
        case .tiktok:
            optimized.hashtags.append(contentsOf: ["#fyp", "#foryou", "#viral"])
        case .youtube:
            optimized.hashtags.append(contentsOf: ["#shorts", "#music", "#content"])
        case .twitter:
            optimized.hashtags = Array(optimized.hashtags.prefix(3)) // Max 3 Hashtags
        default:
            break
        }

        // Titel-Länge anpassen
        let maxTitleLength: Int
        switch platform {
        case .twitter: maxTitleLength = 280
        case .instagram: maxTitleLength = 2200
        case .tiktok: maxTitleLength = 150
        case .youtube: maxTitleLength = 100
        default: maxTitleLength = 500
        }

        if optimized.title.count > maxTitleLength {
            optimized.title = String(optimized.title.prefix(maxTitleLength - 3)) + "..."
        }

        return optimized
    }

    // MARK: - Persistence

    private func loadCredentials() {
        // Lade aus Keychain
        // In echter Implementierung: KeychainAccess
    }

    private func saveCredentials() {
        // Speichere in Keychain
    }

    // MARK: - Scheduling System

    /// Scheduled posts queue
    var scheduledPosts: [ScheduledPost] = []

    /// Scheduler timer
    private var schedulerTimer: Timer?

    /// Scheduled post model
    struct ScheduledPost: Identifiable, Codable {
        let id: UUID
        var content: ScheduledContent
        var scheduledTime: Date
        var platforms: [String] // Platform raw values
        var status: ScheduledStatus

        enum ScheduledStatus: String, Codable {
            case pending
            case posting
            case completed
            case failed
        }

        struct ScheduledContent: Codable {
            var title: String
            var description: String
            var hashtags: [String]
            var videoPath: String?
            var audioPath: String?
            var visibility: String
        }
    }

    /// Schedule a post for later
    func schedulePost(
        content: Content,
        at scheduledTime: Date,
        platforms: Set<Platform>
    ) throws {
        guard scheduledTime > Date() else {
            throw SocialMediaError.uploadFailed("Scheduled time must be in the future")
        }

        guard !platforms.isEmpty else {
            throw SocialMediaError.noPlatformsConnected
        }

        let scheduledContent = ScheduledPost.ScheduledContent(
            title: content.title,
            description: content.description,
            hashtags: content.hashtags,
            videoPath: content.videoURL?.path,
            audioPath: content.audioURL?.path,
            visibility: content.visibility.rawValue
        )

        let scheduledPost = ScheduledPost(
            id: UUID(),
            content: scheduledContent,
            scheduledTime: scheduledTime,
            platforms: platforms.map { $0.rawValue },
            status: .pending
        )

        scheduledPosts.append(scheduledPost)
        scheduledPosts.sort { $0.scheduledTime < $1.scheduledTime }

        saveScheduledPosts()
        startSchedulerIfNeeded()

        #if DEBUG
        debugLog("📅 Scheduled post for \(scheduledTime) on \(platforms.count) platforms")
        #endif
    }

    /// Cancel a scheduled post
    func cancelScheduledPost(id: UUID) {
        scheduledPosts.removeAll { $0.id == id }
        saveScheduledPosts()
        #if DEBUG
        debugLog("❌ Cancelled scheduled post \(id)")
        #endif
    }

    /// Start the scheduler timer
    private func startSchedulerIfNeeded() {
        guard schedulerTimer == nil else { return }

        schedulerTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.processScheduledPosts()
            }
        }

        #if DEBUG
        debugLog("⏰ Scheduler started")
        #endif
    }

    /// Stop the scheduler timer
    func stopScheduler() {
        schedulerTimer?.invalidate()
        schedulerTimer = nil
        #if DEBUG
        debugLog("⏰ Scheduler stopped")
        #endif
    }

    /// Process due scheduled posts
    private func processScheduledPosts() {
        let now = Date()
        let duePosts = scheduledPosts.filter { $0.status == .pending && $0.scheduledTime <= now }

        for post in duePosts {
            Task {
                await processScheduledPost(post)
            }
        }
    }

    /// Process a single scheduled post
    private func processScheduledPost(_ post: ScheduledPost) async {
        guard let index = scheduledPosts.firstIndex(where: { $0.id == post.id }) else { return }

        scheduledPosts[index].status = .posting

        // Convert back to Content
        let content = Content(
            videoURL: post.content.videoPath.flatMap { URL(fileURLWithPath: $0) },
            audioURL: post.content.audioPath.flatMap { URL(fileURLWithPath: $0) },
            thumbnailImage: nil,
            title: post.content.title,
            description: post.content.description,
            hashtags: post.content.hashtags,
            scheduledTime: nil,
            visibility: Content.Visibility(rawValue: post.content.visibility) ?? .public
        )

        // Get platforms
        let platforms = Set(post.platforms.compactMap { Platform(rawValue: $0) })

        do {
            // Temporarily set connected platforms to the scheduled ones
            let previousConnected = connectedPlatforms
            connectedPlatforms = platforms.intersection(connectedPlatforms)

            try await postEverywhere(content: content)

            connectedPlatforms = previousConnected

            scheduledPosts[index].status = .completed
            #if DEBUG
            debugLog("✅ Scheduled post \(post.id) completed")
            #endif
        } catch {
            scheduledPosts[index].status = .failed
            #if DEBUG
            debugLog("❌ Scheduled post \(post.id) failed: \(error)")
            #endif
        }

        saveScheduledPosts()
    }

    /// Save scheduled posts to storage
    private func saveScheduledPosts() {
        guard let data = try? JSONEncoder().encode(scheduledPosts) else { return }
        UserDefaults.standard.set(data, forKey: "scheduledPosts")
    }

    /// Load scheduled posts from storage
    private func loadScheduledPosts() {
        guard let data = UserDefaults.standard.data(forKey: "scheduledPosts"),
              let posts = try? JSONDecoder().decode([ScheduledPost].self, from: data) else { return }
        scheduledPosts = posts.filter { $0.status == .pending }
        startSchedulerIfNeeded()
    }

    // MARK: - Analytics

    /// Analytics data for posts
    var analytics: [Platform: PostAnalytics] = [:]

    struct PostAnalytics {
        var totalViews: Int = 0
        var totalLikes: Int = 0
        var totalComments: Int = 0
        var totalShares: Int = 0
        var engagementRate: Double = 0.0
        var recentPosts: [PostPerformance] = []
    }

    struct PostPerformance: Identifiable {
        let id: UUID
        let postURL: String
        let platform: Platform
        let postedAt: Date
        var views: Int
        var likes: Int
        var comments: Int
        var shares: Int
    }

    /// Fetch analytics for all connected platforms
    func fetchAnalytics() async {
        for platform in connectedPlatforms {
            // In production: Call platform APIs
            // Simulated analytics:
            analytics[platform] = PostAnalytics(
                totalViews: Int.random(in: 1000...100000),
                totalLikes: Int.random(in: 100...10000),
                totalComments: Int.random(in: 10...1000),
                totalShares: Int.random(in: 5...500),
                engagementRate: Double.random(in: 1.0...15.0),
                recentPosts: []
            )
        }
        #if DEBUG
        debugLog("📊 Analytics fetched for \(connectedPlatforms.count) platforms")
        #endif
    }

    // MARK: - Errors

    enum SocialMediaError: LocalizedError {
        case noPlatformsConnected
        case noLivePlatformsConnected
        case notAuthenticated(Platform)
        case platformNotSupported(Platform)
        case uploadFailed(String)
        case networkError(String)

        var errorDescription: String? {
            switch self {
            case .noPlatformsConnected:
                return "Keine Plattformen verbunden. Verbinde mindestens eine Plattform."
            case .noLivePlatformsConnected:
                return "Keine Live-fähigen Plattformen verbunden."
            case .notAuthenticated(let platform):
                return "Nicht bei \(platform.rawValue) angemeldet."
            case .platformNotSupported(let platform):
                return "\(platform.rawValue) wird noch nicht unterstützt."
            case .uploadFailed(let reason):
                return "Upload fehlgeschlagen: \(reason)"
            case .networkError(let reason):
                return "Netzwerkfehler: \(reason)"
            }
        }
    }
}

// MARK: - SwiftUI View

import SwiftUI

struct OneClickPublishView: View {
    @StateObject private var manager = SocialMediaManager.shared
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var selectedPlatforms: Set<SocialMediaManager.Platform> = []

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {

                // Platform Selection
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 15) {
                    ForEach(SocialMediaManager.Platform.allCases) { platform in
                        PlatformButton(
                            platform: platform,
                            isConnected: manager.connectedPlatforms.contains(platform),
                            isSelected: selectedPlatforms.contains(platform),
                            status: manager.liveStatus[platform] ?? .offline
                        ) {
                            if manager.connectedPlatforms.contains(platform) {
                                if selectedPlatforms.contains(platform) {
                                    selectedPlatforms.remove(platform)
                                } else {
                                    selectedPlatforms.insert(platform)
                                }
                            } else {
                                Task {
                                    try? await manager.connect(to: platform)
                                    selectedPlatforms.insert(platform)
                                }
                            }
                        }
                    }
                }
                .padding()

                // Title & Description
                TextField("Titel", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                TextField("Beschreibung", text: $description)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)

                Spacer()

                // One-Click Buttons
                HStack(spacing: 20) {
                    // 🔴 GO LIVE
                    Button(action: {
                        Task {
                            try? await manager.goLiveEverywhere(
                                title: title,
                                description: description
                            )
                        }
                    }) {
                        HStack {
                            Image(systemName: "dot.radiowaves.left.and.right")
                            Text(manager.isLive ? "LIVE BEENDEN" : "GO LIVE")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(manager.isLive ? Color.gray : Color.red)
                        .cornerRadius(15)
                    }
                    .disabled(selectedPlatforms.isEmpty)

                    // 📤 POST
                    Button(action: {
                        Task {
                            let content = SocialMediaManager.Content(
                                videoURL: nil,
                                audioURL: nil,
                                thumbnailImage: nil,
                                title: title,
                                description: description,
                                hashtags: ["echoelmusic", "music", "content"],
                                scheduledTime: nil,
                                visibility: .public
                            )
                            try? await manager.postEverywhere(content: content)
                        }
                    }) {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text(manager.isPosting ? "POSTING..." : "POST")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(manager.isPosting ? Color.gray : Color.blue)
                        .cornerRadius(15)
                    }
                    .disabled(selectedPlatforms.isEmpty || manager.isPosting)
                }
                .padding()
            }
            .navigationTitle("One-Click Publish")
        }
    }
}

struct PlatformButton: View {
    let platform: SocialMediaManager.Platform
    let isConnected: Bool
    let isSelected: Bool
    let status: SocialMediaManager.LiveStatus
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : (isConnected ? Color.green.opacity(0.3) : Color.gray.opacity(0.3)))
                        .frame(width: 60, height: 60)

                    Image(systemName: platform.icon)
                        .font(.title2)
                        .foregroundColor(isSelected ? .white : (isConnected ? .green : .gray))

                    // Live Indicator
                    if case .live = status {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                            .offset(x: 20, y: -20)
                    }
                }

                Text(platform.rawValue)
                    .font(.caption2)
                    .foregroundColor(isConnected ? .primary : .secondary)
            }
        }
    }
}

// MARK: - Backward Compatibility

/// Backward compatibility for existing code using @StateObject/@ObservedObject
extension SocialMediaManager: ObservableObject { }

#Preview {
    OneClickPublishView()
}
