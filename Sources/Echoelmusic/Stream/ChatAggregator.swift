import Foundation
import Combine
import NaturalLanguage

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
        // Multi-layer toxic content detection
        let lowercased = text.lowercased()

        // Layer 1: Keyword filter for obvious violations
        let toxicKeywords = [
            "spam", "scam", "hate", "kill", "die", "racist",
            "nazi", "terrorist", "bomb", "suicide"
        ]
        if toxicKeywords.contains(where: { lowercased.contains($0) }) {
            return true
        }

        // Layer 2: Pattern detection for common toxic patterns
        let toxicPatterns = [
            "^[A-Z\\s!]{20,}$",  // All caps shouting
            "(.)\\1{5,}",        // Repeated characters (spammy)
            "\\b(buy|click|free|winner)\\b.*\\b(now|here|link)\\b"  // Scam patterns
        ]
        for pattern in toxicPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if regex.firstMatch(in: text, options: [], range: range) != nil {
                    return true
                }
            }
        }

        // Layer 3: CoreML sentiment analysis (if model available)
        if let toxicityScore = analyzeWithCoreML(text), toxicityScore > 0.8 {
            return true
        }

        return false
    }

    private func analyzeWithCoreML(_ text: String) -> Float? {
        // Use Natural Language framework for sentiment analysis
        // NLTagger is available on iOS 12+ / macOS 10.14+
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text

        let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        if let sentimentValue = sentiment?.rawValue, let score = Double(sentimentValue) {
            // Convert sentiment (-1 to 1) to toxicity (0 to 1)
            // Negative sentiment is more likely toxic
            return Float(max(0, -score))
        }

        return nil
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
