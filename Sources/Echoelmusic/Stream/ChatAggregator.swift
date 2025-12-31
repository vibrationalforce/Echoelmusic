import Foundation
import Combine

/// Chat Aggregator for Twitch, YouTube, Facebook Live
/// Aggregates chat messages from multiple platforms with AI moderation
/// Migrated to @Observable for better performance (Swift 5.9+)
@MainActor
@Observable
final class ChatAggregator {

    var messages: [ChatMessage] = []
    var isActive: Bool = false

    // AI Moderation
    var moderationEnabled: Bool = true
    var toxicMessagesBlocked: Int = 0

    private var cancellables = Set<AnyCancellable>()

    func start() {
        guard !isActive else { return }
        isActive = true
        #if DEBUG
        debugLog("💬 ChatAggregator: Started")
        #endif
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        cancellables.removeAll()
        #if DEBUG
        debugLog("💬 ChatAggregator: Stopped")
        #endif
    }

    func addMessage(_ message: ChatMessage) {
        // AI Moderation check
        if moderationEnabled && isToxic(message.text) {
            toxicMessagesBlocked += 1
            #if DEBUG
            debugLog("🚫 ChatAggregator: Blocked toxic message from \(message.username)")
            #endif
            return
        }

        messages.append(message)
        #if DEBUG
        debugLog("💬 [\(message.platform.rawValue)] \(message.username): \(message.text)")
        #endif
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

// MARK: - Backward Compatibility

/// Backward compatibility for existing code using @StateObject/@ObservedObject
extension ChatAggregator: ObservableObject { }
