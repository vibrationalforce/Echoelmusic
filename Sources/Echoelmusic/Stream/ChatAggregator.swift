import Foundation
import Combine
import os.log

/// Chat Aggregator for Twitch, YouTube, Facebook Live
/// Aggregates chat messages from multiple platforms with AI moderation
@MainActor
class ChatAggregator: ObservableObject {

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.echoelmusic", category: "ChatAggregator")

    @Published var messages: [ChatMessage] = []
    @Published var isActive: Bool = false

    // AI Moderation
    @Published var moderationEnabled: Bool = true
    @Published var toxicMessagesBlocked: Int = 0

    private var cancellables = Set<AnyCancellable>()

    func start() {
        guard !isActive else { return }
        isActive = true
        logger.info("Started")
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        cancellables.removeAll()
        logger.info("Stopped")
    }

    func addMessage(_ message: ChatMessage) {
        // AI Moderation check
        if moderationEnabled && isToxic(message.text) {
            toxicMessagesBlocked += 1
            logger.warning("Blocked toxic message from \(message.username, privacy: .public)")
            return
        }

        messages.append(message)
        logger.debug("[\(message.platform.rawValue, privacy: .public)] \(message.username, privacy: .public): \(message.text, privacy: .public)")
    }

    private func isToxic(_ text: String) -> Bool {
        // TODO: Implement CoreML toxic comment detection
        // Placeholder simple filter
        let keywords = ["spam", "scam", "hate"]
        return keywords.contains { text.lowercased().contains($0) }
    }
}

struct ChatMessage: Identifiable {
    let id = UUID()
    let platform: Platform
    let username: String
    let text: String
    let timestamp: Date
    let isModerator: Bool
    let isSubscriber: Bool

    enum Platform: String {
        case twitch = "Twitch"
        case youtube = "YouTube"
        case facebook = "Facebook"
    }
}
