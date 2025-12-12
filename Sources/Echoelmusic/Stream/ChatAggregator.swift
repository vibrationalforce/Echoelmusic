import Foundation
import Combine

/// Chat Aggregator for Twitch, YouTube, Facebook Live
/// Aggregates chat messages from multiple platforms with AI moderation
@MainActor
class ChatAggregator: ObservableObject {

    @Published var messages: [ChatMessage] = []
    @Published var isActive: Bool = false

    // AI Moderation
    @Published var moderationEnabled: Bool = true
    @Published var toxicMessagesBlocked: Int = 0

    private var cancellables = Set<AnyCancellable>()

    func start() {
        guard !isActive else { return }
        isActive = true
        EchoelLogger.log("💬", "ChatAggregator: Started", category: EchoelLogger.system)
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        cancellables.removeAll()
        EchoelLogger.log("💬", "ChatAggregator: Stopped", category: EchoelLogger.system)
    }

    func addMessage(_ message: ChatMessage) {
        // AI Moderation check
        if moderationEnabled && isToxic(message.text) {
            toxicMessagesBlocked += 1
            EchoelLogger.log("🚫", "ChatAggregator: Blocked toxic message from \(message.username)", category: EchoelLogger.system)
            return
        }

        messages.append(message)
        EchoelLogger.log("💬", "[\(message.platform.rawValue)] \(message.username): \(message.text)", category: EchoelLogger.system)
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
