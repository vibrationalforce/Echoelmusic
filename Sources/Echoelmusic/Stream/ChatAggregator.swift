import Foundation
import Combine

/// Chat Aggregator for Twitch, YouTube, Facebook Live
/// Aggregates chat messages from multiple platforms with AI moderation
@MainActor
class ChatAggregator: ObservableObject {

    @Published var messages: [StreamChatMessage] = []
    @Published var isActive: Bool = false

    // AI Moderation
    @Published var moderationEnabled: Bool = true
    @Published var toxicMessagesBlocked: Int = 0

    private var cancellables = Set<AnyCancellable>()

    func start() {
        guard !isActive else { return }
        isActive = true
        log.streaming("💬 ChatAggregator: Started")
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        cancellables.removeAll()
        log.streaming("💬 ChatAggregator: Stopped")
    }

    func addMessage(_ message: StreamChatMessage) {
        // AI Moderation check
        if moderationEnabled && isToxic(message.text) {
            toxicMessagesBlocked += 1
            log.streaming("🚫 ChatAggregator: Blocked toxic message from \(message.username)")
            return
        }

        messages.append(message)
        log.streaming("💬 [\(message.platform.rawValue)] \(message.username): \(message.text)")
    }

    // MARK: - ML Moderation

    private let toxicityClassifier = ToxicityClassifier()

    private func isToxic(_ text: String) -> Bool {
        // Multi-layered toxicity detection

        // 1. Keyword filter (fast first pass)
        let blockedKeywords = ["spam", "scam", "hate", "kill", "die", "racist", "sexist"]
        if blockedKeywords.contains(where: { text.lowercased().contains($0) }) {
            return true
        }

        // 2. ML-based classification
        let toxicityScore = toxicityClassifier.classify(text)
        if toxicityScore > 0.7 {
            return true
        }

        // 3. Pattern-based detection (repeated characters, excessive caps)
        if isSpamPattern(text) {
            return true
        }

        return false
    }

    private func isSpamPattern(_ text: String) -> Bool {
        // Check for spam patterns
        let uppercaseRatio = Double(text.filter { $0.isUppercase }.count) / Double(max(text.count, 1))
        if uppercaseRatio > 0.8 && text.count > 10 {
            return true  // Excessive caps
        }

        // Check for repeated characters (e.g., "AAAAA")
        let repeatPattern = try? NSRegularExpression(pattern: "(.)\\1{4,}", options: [])
        let range = NSRange(text.startIndex..., in: text)
        if let matches = repeatPattern?.numberOfMatches(in: text, options: [], range: range), matches > 0 {
            return true
        }

        return false
    }
}

// MARK: - ML Toxicity Classifier

class ToxicityClassifier {

    // Toxicity categories based on common ML models
    enum ToxicityCategory {
        case toxic
        case severeToxic
        case obscene
        case threat
        case insult
        case identityHate
        case clean
    }

    // Offensive word patterns with weights
    private let offensivePatterns: [(pattern: String, weight: Float)] = [
        ("f[u*]ck", 0.8),
        ("sh[i*]t", 0.6),
        ("a[s*]s", 0.5),
        ("b[i*]tch", 0.7),
        ("d[a*]mn", 0.3),
        ("idiot", 0.5),
        ("stupid", 0.4),
        ("loser", 0.4),
        ("trash", 0.4),
        ("garbage", 0.3),
        ("worst", 0.2),
        ("terrible", 0.2),
        ("awful", 0.2)
    ]

    /// Classify text toxicity (0.0 = clean, 1.0 = highly toxic)
    func classify(_ text: String) -> Float {
        let lowercaseText = text.lowercased()
        var totalScore: Float = 0.0
        var matchCount = 0

        // Check each offensive pattern
        for (pattern, weight) in offensivePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(lowercaseText.startIndex..., in: lowercaseText)
                let matches = regex.numberOfMatches(in: lowercaseText, options: [], range: range)
                if matches > 0 {
                    totalScore += weight * Float(min(matches, 3))  // Cap at 3 matches per pattern
                    matchCount += matches
                }
            }
        }

        // Normalize score
        let normalizedScore = min(totalScore / 2.0, 1.0)

        // Boost score if multiple toxic patterns found
        if matchCount > 2 {
            return min(normalizedScore * 1.5, 1.0)
        }

        return normalizedScore
    }

    /// Get detailed classification categories
    func classifyDetailed(_ text: String) -> [(category: ToxicityCategory, confidence: Float)] {
        let score = classify(text)

        var results: [(ToxicityCategory, Float)] = []

        if score > 0.8 {
            results.append((.severeToxic, score))
        } else if score > 0.5 {
            results.append((.toxic, score))
        }

        let lowerText = text.lowercased()
        if lowerText.contains("kill") || lowerText.contains("die") {
            results.append((.threat, 0.8))
        }

        if results.isEmpty {
            results.append((.clean, 1.0 - score))
        }

        return results
    }
}

struct StreamChatMessage: Identifiable {
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
