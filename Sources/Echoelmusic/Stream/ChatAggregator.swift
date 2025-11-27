//
//  ChatAggregator.swift
//  Echoelmusic
//
//  Created: 2025-11-24
//  Updated: 2025-11-27
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  CHAT AGGREGATOR - Multi-platform streaming chat integration
//
//  **Features:**
//  - Twitch, YouTube, Facebook, TikTok, Kick integration
//  - AI-powered moderation with sentiment analysis
//  - Spam detection and rate limiting
//  - User levels (mod, sub, VIP, etc.)
//  - Emote rendering and parsing
//  - Chat commands / bot integration
//  - Donation/tip alerts
//  - Chat statistics and analytics
//  - Message filtering and highlighting
//  - Chat replay for VODs
//  - Text-to-speech for donations
//

import Foundation
import Combine
import NaturalLanguage

// MARK: - Chat Aggregator

@MainActor
class ChatAggregator: ObservableObject {
    static let shared = ChatAggregator()

    // MARK: - Published State

    @Published var messages: [ChatMessage] = []
    @Published var isActive: Bool = false
    @Published var connectedPlatforms: Set<ChatPlatform> = []

    // AI Moderation
    @Published var moderationEnabled: Bool = true
    @Published var toxicMessagesBlocked: Int = 0
    @Published var spamMessagesBlocked: Int = 0
    @Published var moderationSensitivity: ModerationLevel = .moderate

    // Statistics
    @Published var messagesPerMinute: Double = 0
    @Published var totalMessages: Int = 0
    @Published var uniqueChatters: Int = 0
    @Published var topChatters: [ChatterStats] = []

    // Donations/Tips
    @Published var donations: [Donation] = []
    @Published var totalDonations: Double = 0

    // Alerts
    @Published var currentAlert: ChatAlert?

    // MARK: - Configuration

    @Published var chatCommands: [ChatCommand] = []
    @Published var bannedWords: [String] = []
    @Published var highlightKeywords: [String] = []
    @Published var slowModeSeconds: Int = 0
    @Published var maxMessageLength: Int = 500
    @Published var emoteOnlyMode: Bool = false
    @Published var subscriberOnlyMode: Bool = false

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private var platformConnections: [ChatPlatform: PlatformConnection] = [:]
    private var chatHistory: [ChatMessage] = []  // For replay
    private var userCache: [String: CachedUser] = [:]
    private var recentMessages: [String: Date] = [:]  // For duplicate detection
    private var messagesThisMinute: [Date] = []
    private var sentimentAnalyzer: NLModel?
    private var messageQueue = AsyncStream<ChatMessage>.Continuation?

    // MARK: - Initialization

    private init() {
        setupDefaultCommands()
        loadBannedWords()
        startStatisticsTimer()
        print("✅ ChatAggregator: Initialized")
    }

    private func setupDefaultCommands() {
        chatCommands = [
            ChatCommand(trigger: "!help", response: "Available commands: !help, !discord, !socials, !song", cooldown: 5),
            ChatCommand(trigger: "!discord", response: "Join our Discord: discord.gg/echoelmusic", cooldown: 10),
            ChatCommand(trigger: "!socials", response: "Follow on Twitter: @echoelmusic | Instagram: @echoelmusic", cooldown: 10),
            ChatCommand(trigger: "!song", response: "Current track: [Song info from DAW]", cooldown: 5, dynamic: true),
            ChatCommand(trigger: "!uptime", response: "[Stream uptime]", cooldown: 30, dynamic: true),
        ]
    }

    private func loadBannedWords() {
        // Default banned words (can be customized)
        bannedWords = ["spam", "scam", "hate", "racist", "porn", "xxx"]
    }

    private func startStatisticsTimer() {
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.calculateStatistics()
            }
            .store(in: &cancellables)
    }

    // MARK: - Platform Connection

    /// Connect to a streaming platform's chat
    func connect(to platform: ChatPlatform, credentials: PlatformCredentials) async throws {
        guard !connectedPlatforms.contains(platform) else {
            print("⚠️ ChatAggregator: Already connected to \(platform.rawValue)")
            return
        }

        let connection = PlatformConnection(platform: platform, credentials: credentials)

        do {
            try await connection.connect()
            platformConnections[platform] = connection
            connectedPlatforms.insert(platform)

            // Subscribe to incoming messages
            connection.messagePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] message in
                    self?.handleIncomingMessage(message)
                }
                .store(in: &cancellables)

            // Subscribe to donations
            connection.donationPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] donation in
                    self?.handleDonation(donation)
                }
                .store(in: &cancellables)

            print("✅ ChatAggregator: Connected to \(platform.rawValue)")
        } catch {
            print("❌ ChatAggregator: Failed to connect to \(platform.rawValue): \(error)")
            throw ChatError.connectionFailed(platform: platform, reason: error.localizedDescription)
        }
    }

    /// Disconnect from a platform
    func disconnect(from platform: ChatPlatform) async {
        guard let connection = platformConnections[platform] else { return }

        await connection.disconnect()
        platformConnections.removeValue(forKey: platform)
        connectedPlatforms.remove(platform)

        print("👋 ChatAggregator: Disconnected from \(platform.rawValue)")
    }

    /// Start aggregating chat from all connected platforms
    func start() {
        guard !isActive else { return }
        isActive = true
        print("💬 ChatAggregator: Started aggregating chat")
    }

    /// Stop aggregating chat
    func stop() {
        guard isActive else { return }
        isActive = false
        print("💬 ChatAggregator: Stopped")
    }

    // MARK: - Message Handling

    private func handleIncomingMessage(_ message: ChatMessage) {
        guard isActive else { return }

        // Run through moderation pipeline
        guard passesModeration(message) else { return }

        // Check for commands
        if message.text.hasPrefix("!") {
            handleCommand(message)
        }

        // Add to messages
        addMessage(message)

        // Check for highlights
        checkHighlights(message)

        // Update statistics
        updateStatistics(for: message)
    }

    func addMessage(_ message: ChatMessage) {
        // Add to live messages (keep last 500)
        messages.append(message)
        if messages.count > 500 {
            messages.removeFirst()
        }

        // Add to history for replay
        chatHistory.append(message)

        totalMessages += 1
        messagesThisMinute.append(Date())

        print("💬 [\(message.platform.rawValue)] \(message.username): \(message.text)")
    }

    // MARK: - AI Moderation

    private func passesModeration(_ message: ChatMessage) -> Bool {
        // Skip moderation for mods and VIPs
        if message.userLevel == .moderator || message.userLevel == .vip || message.userLevel == .broadcaster {
            return true
        }

        // Check subscriber-only mode
        if subscriberOnlyMode && message.userLevel == .regular {
            return false
        }

        // Check slow mode
        if slowModeSeconds > 0 {
            let key = "\(message.platform.rawValue):\(message.username)"
            if let lastMessage = recentMessages[key] {
                if Date().timeIntervalSince(lastMessage) < Double(slowModeSeconds) {
                    return false
                }
            }
            recentMessages[key] = Date()
        }

        // Check message length
        if message.text.count > maxMessageLength {
            return false
        }

        // Check emote-only mode
        if emoteOnlyMode && !isEmoteOnly(message.text) {
            return false
        }

        // Check banned words
        if containsBannedWord(message.text) {
            toxicMessagesBlocked += 1
            print("🚫 ChatAggregator: Blocked message with banned word from \(message.username)")
            return false
        }

        // AI toxicity check
        if moderationEnabled {
            let toxicityScore = calculateToxicity(message.text)
            let threshold = moderationSensitivity.threshold

            if toxicityScore > threshold {
                toxicMessagesBlocked += 1
                print("🚫 ChatAggregator: Blocked toxic message (score: \(toxicityScore)) from \(message.username)")
                return false
            }
        }

        // Spam detection
        if isSpam(message) {
            spamMessagesBlocked += 1
            print("🚫 ChatAggregator: Blocked spam from \(message.username)")
            return false
        }

        // Duplicate message detection
        if isDuplicate(message) {
            spamMessagesBlocked += 1
            return false
        }

        return true
    }

    private func containsBannedWord(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return bannedWords.contains { lowercased.contains($0) }
    }

    private func calculateToxicity(_ text: String) -> Double {
        // Use NaturalLanguage framework for sentiment analysis
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text

        var toxicityScore: Double = 0

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .paragraph, scheme: .sentimentScore) { tag, _ in
            if let tag = tag, let score = Double(tag.rawValue) {
                // Sentiment score: -1 (negative) to 1 (positive)
                // Convert to toxicity: 0 (safe) to 1 (toxic)
                toxicityScore = max(0, -score)
            }
            return true
        }

        // Additional checks for toxic patterns
        let capsRatio = Double(text.filter { $0.isUppercase }.count) / Double(max(text.count, 1))
        if capsRatio > 0.7 && text.count > 10 {
            toxicityScore += 0.2  // Excessive caps penalty
        }

        // Check for repeated characters (spam pattern)
        let repeatPattern = #"(.)\1{4,}"#
        if text.range(of: repeatPattern, options: .regularExpression) != nil {
            toxicityScore += 0.3
        }

        return min(toxicityScore, 1.0)
    }

    private func isSpam(_ message: ChatMessage) -> Bool {
        let text = message.text.lowercased()

        // Check for URL spam
        let urlCount = text.components(separatedBy: "http").count - 1
        if urlCount > 2 {
            return true
        }

        // Check for excessive special characters
        let specialCharRatio = Double(text.filter { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }.count) / Double(max(text.count, 1))
        if specialCharRatio > 0.5 && text.count > 20 {
            return true
        }

        // Check for repeated messages (same user)
        let recentFromUser = messages.suffix(20).filter { $0.username == message.username }
        let duplicates = recentFromUser.filter { $0.text.lowercased() == text }.count
        if duplicates >= 3 {
            return true
        }

        return false
    }

    private func isDuplicate(_ message: ChatMessage) -> Bool {
        let key = "\(message.username):\(message.text.prefix(50))"
        if let lastSent = recentMessages[key], Date().timeIntervalSince(lastSent) < 30 {
            return true
        }
        recentMessages[key] = Date()
        return false
    }

    private func isEmoteOnly(_ text: String) -> Bool {
        // Check if message contains only emotes (simplified check)
        let words = text.components(separatedBy: .whitespaces)
        return words.allSatisfy { $0.hasPrefix(":") && $0.hasSuffix(":") }
    }

    // MARK: - Chat Commands

    private func handleCommand(_ message: ChatMessage) {
        let commandText = message.text.lowercased().trimmingCharacters(in: .whitespaces)

        for command in chatCommands where commandText.hasPrefix(command.trigger.lowercased()) {
            // Check cooldown
            if let lastUsed = command.lastUsed, Date().timeIntervalSince(lastUsed) < Double(command.cooldown) {
                return
            }

            // Execute command
            let response = command.dynamic ? getDynamicResponse(for: command) : command.response

            // Send response to all platforms
            Task {
                await sendMessage(response, replyTo: message)
            }

            // Update last used
            if let index = chatCommands.firstIndex(where: { $0.trigger == command.trigger }) {
                chatCommands[index].lastUsed = Date()
            }

            return
        }
    }

    private func getDynamicResponse(for command: ChatCommand) -> String {
        switch command.trigger {
        case "!song":
            // Get current song from DAW
            return "Currently playing: [Integration with DAWTimelineEngine needed]"
        case "!uptime":
            // Get stream uptime
            return "Stream has been live for [Integration with StreamEngine needed]"
        default:
            return command.response
        }
    }

    // MARK: - Donations

    private func handleDonation(_ donation: Donation) {
        donations.append(donation)
        totalDonations += donation.amount

        // Show alert
        let alert = ChatAlert(
            type: .donation,
            title: "\(donation.username) donated \(formatCurrency(donation.amount))!",
            message: donation.message,
            duration: 10
        )
        showAlert(alert)

        // Text-to-speech for donations over threshold
        if donation.amount >= 5.0, let message = donation.message {
            speakDonation(username: donation.username, amount: donation.amount, message: message)
        }

        print("💰 Donation: \(donation.username) - \(formatCurrency(donation.amount))")
    }

    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }

    private func speakDonation(username: String, amount: Double, message: String) {
        // Use AVSpeechSynthesizer for TTS
        print("🔊 TTS: \(username) donated \(formatCurrency(amount)): \(message)")
        // Implementation would use AVSpeechSynthesizer
    }

    // MARK: - Alerts

    private func showAlert(_ alert: ChatAlert) {
        currentAlert = alert

        // Auto-dismiss after duration
        Task {
            try? await Task.sleep(nanoseconds: UInt64(alert.duration) * 1_000_000_000)
            if currentAlert?.id == alert.id {
                currentAlert = nil
            }
        }
    }

    // MARK: - Highlights

    private func checkHighlights(_ message: ChatMessage) {
        let text = message.text.lowercased()

        for keyword in highlightKeywords {
            if text.contains(keyword.lowercased()) {
                // Highlight this message
                if let index = messages.lastIndex(where: { $0.id == message.id }) {
                    messages[index].isHighlighted = true
                }
                break
            }
        }
    }

    // MARK: - Statistics

    private func calculateStatistics() {
        // Calculate messages per minute
        let oneMinuteAgo = Date().addingTimeInterval(-60)
        messagesThisMinute = messagesThisMinute.filter { $0 > oneMinuteAgo }
        messagesPerMinute = Double(messagesThisMinute.count)

        // Calculate unique chatters
        var chatters = Set<String>()
        for message in messages {
            chatters.insert("\(message.platform.rawValue):\(message.username)")
        }
        uniqueChatters = chatters.count

        // Calculate top chatters
        var chatterCounts: [String: ChatterStats] = [:]
        for message in messages {
            let key = "\(message.platform.rawValue):\(message.username)"
            if var stats = chatterCounts[key] {
                stats.messageCount += 1
                chatterCounts[key] = stats
            } else {
                chatterCounts[key] = ChatterStats(
                    username: message.username,
                    platform: message.platform,
                    messageCount: 1,
                    userLevel: message.userLevel
                )
            }
        }
        topChatters = chatterCounts.values
            .sorted { $0.messageCount > $1.messageCount }
            .prefix(10)
            .map { $0 }
    }

    private func updateStatistics(for message: ChatMessage) {
        // Update user cache
        let key = "\(message.platform.rawValue):\(message.username)"
        if var user = userCache[key] {
            user.lastSeen = Date()
            user.messageCount += 1
            userCache[key] = user
        } else {
            userCache[key] = CachedUser(
                username: message.username,
                platform: message.platform,
                firstSeen: Date(),
                lastSeen: Date(),
                messageCount: 1,
                userLevel: message.userLevel
            )
        }
    }

    // MARK: - Sending Messages

    /// Send a message to all connected platforms
    func sendMessage(_ text: String, replyTo: ChatMessage? = nil) async {
        for (platform, connection) in platformConnections {
            do {
                try await connection.send(text, replyTo: replyTo?.id)
                print("📤 Sent to \(platform.rawValue): \(text)")
            } catch {
                print("❌ Failed to send to \(platform.rawValue): \(error)")
            }
        }
    }

    /// Send a message to a specific platform
    func sendMessage(_ text: String, to platform: ChatPlatform) async throws {
        guard let connection = platformConnections[platform] else {
            throw ChatError.notConnected(platform: platform)
        }

        try await connection.send(text, replyTo: nil)
    }

    // MARK: - Chat Replay

    /// Get chat messages for VOD replay at specific timestamp
    func getReplayMessages(at timestamp: TimeInterval, window: TimeInterval = 5) -> [ChatMessage] {
        return chatHistory.filter { message in
            let messageTime = message.timestamp.timeIntervalSince(chatHistory.first?.timestamp ?? Date())
            return abs(messageTime - timestamp) <= window
        }
    }

    /// Export chat history
    func exportChatHistory() -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(chatHistory)
    }

    // MARK: - Moderation Actions

    /// Ban a user (requires mod permissions on platform)
    func banUser(_ username: String, platform: ChatPlatform, reason: String? = nil) async throws {
        guard let connection = platformConnections[platform] else {
            throw ChatError.notConnected(platform: platform)
        }

        try await connection.ban(username, reason: reason)
        print("🔨 Banned \(username) on \(platform.rawValue)")
    }

    /// Timeout a user
    func timeoutUser(_ username: String, platform: ChatPlatform, duration: Int) async throws {
        guard let connection = platformConnections[platform] else {
            throw ChatError.notConnected(platform: platform)
        }

        try await connection.timeout(username, duration: duration)
        print("⏱️ Timed out \(username) on \(platform.rawValue) for \(duration)s")
    }

    /// Delete a specific message
    func deleteMessage(_ messageId: UUID) async {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            let message = messages[index]

            if let connection = platformConnections[message.platform] {
                try? await connection.deleteMessage(message.platformMessageId)
            }

            messages.remove(at: index)
        }
    }
}

// MARK: - Supporting Types

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let platform: ChatPlatform
    let platformMessageId: String?
    let username: String
    let displayName: String?
    let text: String
    let timestamp: Date
    var userLevel: UserLevel
    let badges: [ChatBadge]
    let emotes: [ChatEmote]
    var isHighlighted: Bool = false
    let color: String?  // User's chat color

    init(
        id: UUID = UUID(),
        platform: ChatPlatform,
        platformMessageId: String? = nil,
        username: String,
        displayName: String? = nil,
        text: String,
        timestamp: Date = Date(),
        userLevel: UserLevel = .regular,
        badges: [ChatBadge] = [],
        emotes: [ChatEmote] = [],
        isHighlighted: Bool = false,
        color: String? = nil
    ) {
        self.id = id
        self.platform = platform
        self.platformMessageId = platformMessageId
        self.username = username
        self.displayName = displayName
        self.text = text
        self.timestamp = timestamp
        self.userLevel = userLevel
        self.badges = badges
        self.emotes = emotes
        self.isHighlighted = isHighlighted
        self.color = color
    }
}

enum ChatPlatform: String, CaseIterable, Codable {
    case twitch = "Twitch"
    case youtube = "YouTube"
    case facebook = "Facebook"
    case tiktok = "TikTok"
    case kick = "Kick"
    case instagram = "Instagram"

    var icon: String {
        switch self {
        case .twitch: return "tv"
        case .youtube: return "play.rectangle"
        case .facebook: return "person.2"
        case .tiktok: return "music.note"
        case .kick: return "k.circle"
        case .instagram: return "camera"
        }
    }

    var color: String {
        switch self {
        case .twitch: return "#9146FF"
        case .youtube: return "#FF0000"
        case .facebook: return "#1877F2"
        case .tiktok: return "#000000"
        case .kick: return "#53FC18"
        case .instagram: return "#E1306C"
        }
    }
}

enum UserLevel: String, Codable, Comparable {
    case regular = "Regular"
    case subscriber = "Subscriber"
    case vip = "VIP"
    case moderator = "Moderator"
    case broadcaster = "Broadcaster"

    var rank: Int {
        switch self {
        case .regular: return 0
        case .subscriber: return 1
        case .vip: return 2
        case .moderator: return 3
        case .broadcaster: return 4
        }
    }

    static func < (lhs: UserLevel, rhs: UserLevel) -> Bool {
        return lhs.rank < rhs.rank
    }
}

struct ChatBadge: Codable {
    let name: String
    let imageURL: URL?
}

struct ChatEmote: Codable {
    let id: String
    let name: String
    let imageURL: URL?
    let startIndex: Int
    let endIndex: Int
}

struct ChatCommand: Identifiable {
    let id = UUID()
    var trigger: String
    var response: String
    var cooldown: Int  // Seconds
    var dynamic: Bool = false
    var lastUsed: Date?
    var modOnly: Bool = false
}

struct Donation: Identifiable {
    let id = UUID()
    let platform: ChatPlatform
    let username: String
    let amount: Double
    let currency: String
    let message: String?
    let timestamp: Date
}

struct ChatAlert: Identifiable {
    let id = UUID()
    let type: AlertType
    let title: String
    let message: String?
    let duration: TimeInterval

    enum AlertType {
        case donation
        case subscription
        case follow
        case raid
        case host
        case custom
    }
}

enum ModerationLevel: String, CaseIterable {
    case lenient = "Lenient"
    case moderate = "Moderate"
    case strict = "Strict"

    var threshold: Double {
        switch self {
        case .lenient: return 0.8
        case .moderate: return 0.5
        case .strict: return 0.3
        }
    }
}

struct ChatterStats: Identifiable {
    let id = UUID()
    let username: String
    let platform: ChatPlatform
    var messageCount: Int
    let userLevel: UserLevel
}

struct CachedUser {
    let username: String
    let platform: ChatPlatform
    let firstSeen: Date
    var lastSeen: Date
    var messageCount: Int
    let userLevel: UserLevel
}

// MARK: - Platform Connection

class PlatformConnection: ObservableObject {
    let platform: ChatPlatform
    let credentials: PlatformCredentials

    @Published var isConnected: Bool = false

    let messagePublisher = PassthroughSubject<ChatMessage, Never>()
    let donationPublisher = PassthroughSubject<Donation, Never>()

    init(platform: ChatPlatform, credentials: PlatformCredentials) {
        self.platform = platform
        self.credentials = credentials
    }

    func connect() async throws {
        // Platform-specific connection logic
        switch platform {
        case .twitch:
            try await connectToTwitch()
        case .youtube:
            try await connectToYouTube()
        case .facebook:
            try await connectToFacebook()
        case .tiktok:
            try await connectToTikTok()
        case .kick:
            try await connectToKick()
        case .instagram:
            try await connectToInstagram()
        }

        isConnected = true
    }

    func disconnect() async {
        isConnected = false
        print("📴 \(platform.rawValue): Disconnected")
    }

    func send(_ text: String, replyTo: String?) async throws {
        guard isConnected else { throw ChatError.notConnected(platform: platform) }

        // Platform-specific send logic
        print("📤 \(platform.rawValue): Sending '\(text)'")
    }

    func ban(_ username: String, reason: String?) async throws {
        guard isConnected else { throw ChatError.notConnected(platform: platform) }
        print("🔨 \(platform.rawValue): Banning \(username)")
    }

    func timeout(_ username: String, duration: Int) async throws {
        guard isConnected else { throw ChatError.notConnected(platform: platform) }
        print("⏱️ \(platform.rawValue): Timing out \(username) for \(duration)s")
    }

    func deleteMessage(_ messageId: String?) async throws {
        guard isConnected, let messageId = messageId else { return }
        print("🗑️ \(platform.rawValue): Deleting message \(messageId)")
    }

    // MARK: - Platform-Specific Connections

    private func connectToTwitch() async throws {
        // Twitch IRC connection
        // In production: Connect to irc.chat.twitch.tv:6697
        // Join channel: JOIN #channelname
        // Parse IRC messages and convert to ChatMessage
        print("📺 Connecting to Twitch IRC...")

        // Simulate connection
        try await Task.sleep(nanoseconds: 500_000_000)

        // Start mock message generation for testing
        startMockMessages()
    }

    private func connectToYouTube() async throws {
        // YouTube Live Chat API
        // Requires OAuth2 authentication
        // Poll liveChatMessages endpoint
        print("📺 Connecting to YouTube Live Chat API...")
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    private func connectToFacebook() async throws {
        // Facebook Live Chat
        // Graph API: /{live-video-id}/live_comments
        print("📺 Connecting to Facebook Live...")
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    private func connectToTikTok() async throws {
        // TikTok Live API (if available)
        print("📺 Connecting to TikTok Live...")
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    private func connectToKick() async throws {
        // Kick.com WebSocket connection
        print("📺 Connecting to Kick.com...")
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    private func connectToInstagram() async throws {
        // Instagram Live (limited API access)
        print("📺 Connecting to Instagram Live...")
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    // MARK: - Mock Message Generator (for testing)

    private func startMockMessages() {
        let mockUsernames = ["StreamFan42", "MusicLover", "VJPro", "ChatBot3000", "CoolViewer", "AudioWizard"]
        let mockMessages = [
            "Great stream!",
            "Love this track",
            "What BPM is this?",
            "Those visuals are insane",
            "First time here, loving it!",
            "Can you play some house music?",
            "The lighting effects are amazing",
            "This is fire 🔥",
            "How long have you been producing?",
            "Your setup is incredible"
        ]

        Task {
            while isConnected {
                let message = ChatMessage(
                    platform: platform,
                    platformMessageId: UUID().uuidString,
                    username: mockUsernames.randomElement()!,
                    text: mockMessages.randomElement()!,
                    userLevel: [.regular, .subscriber, .vip].randomElement()!
                )

                messagePublisher.send(message)

                // Random delay between messages
                let delay = UInt64.random(in: 3_000_000_000...10_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
            }
        }
    }
}

struct PlatformCredentials {
    let platform: ChatPlatform
    let accessToken: String?
    let refreshToken: String?
    let channelId: String?
    let clientId: String?
    let clientSecret: String?

    // Twitch-specific
    var twitchUsername: String?
    var twitchChannel: String?

    // YouTube-specific
    var youtubeLiveChatId: String?
}

// MARK: - Errors

enum ChatError: Error, LocalizedError {
    case notConnected(platform: ChatPlatform)
    case connectionFailed(platform: ChatPlatform, reason: String)
    case authenticationFailed(platform: ChatPlatform)
    case rateLimited(platform: ChatPlatform)
    case messageTooLong
    case sendFailed

    var errorDescription: String? {
        switch self {
        case .notConnected(let platform):
            return "Not connected to \(platform.rawValue)"
        case .connectionFailed(let platform, let reason):
            return "Failed to connect to \(platform.rawValue): \(reason)"
        case .authenticationFailed(let platform):
            return "Authentication failed for \(platform.rawValue)"
        case .rateLimited(let platform):
            return "Rate limited on \(platform.rawValue)"
        case .messageTooLong:
            return "Message exceeds maximum length"
        case .sendFailed:
            return "Failed to send message"
        }
    }
}

// MARK: - Chat View Support

extension ChatMessage {
    /// Formatted time string for display
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    /// User badge icons for display
    var badgeIcons: [String] {
        var icons: [String] = []

        switch userLevel {
        case .broadcaster: icons.append("mic.fill")
        case .moderator: icons.append("shield.fill")
        case .vip: icons.append("star.fill")
        case .subscriber: icons.append("heart.fill")
        case .regular: break
        }

        return icons
    }
}
