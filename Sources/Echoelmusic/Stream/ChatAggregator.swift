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
        print("💬 ChatAggregator: Started")
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        cancellables.removeAll()
        print("💬 ChatAggregator: Stopped")
    }

    func addMessage(_ message: ChatMessage) {
        // AI Moderation check
        if moderationEnabled && isToxic(message.text) {
            toxicMessagesBlocked += 1
            print("🚫 ChatAggregator: Blocked toxic message from \(message.username)")
            return
        }

        messages.append(message)
        print("💬 [\(message.platform.rawValue)] \(message.username): \(message.text)")
    }

    private func isToxic(_ text: String) -> Bool {
        let lowercased = text.lowercased()

        // Multi-tier toxicity detection
        // Tier 1: Explicit blocked terms
        let blockedTerms = ["spam", "scam", "hate", "kill", "die", "nazi", "racist"]
        if blockedTerms.contains(where: { lowercased.contains($0) }) {
            return true
        }

        // Tier 2: Excessive caps (shouting)
        let uppercaseRatio = Double(text.filter { $0.isUppercase }.count) / Double(max(text.count, 1))
        if text.count > 10 && uppercaseRatio > 0.7 {
            return true
        }

        // Tier 3: Repeated characters (spam pattern)
        let repeatedPattern = try? NSRegularExpression(pattern: "(.)\\1{4,}")
        if let matches = repeatedPattern?.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text)), matches > 0 {
            return true
        }

        // Tier 4: URL spam (multiple links)
        let urlCount = text.components(separatedBy: "http").count - 1
        if urlCount > 2 {
            return true
        }

        return false
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
