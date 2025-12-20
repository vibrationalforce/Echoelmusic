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
    @Published var moderationSensitivity: ModerationSensitivity = .medium

    // Sentiment analyzer
    private let sentimentAnalyzer = NLTagger(tagSchemes: [.sentimentScore])

    // Pattern-based filter
    private let toxicPatterns: [ToxicPattern] = [
        ToxicPattern(pattern: #"\b(spam|scam)\b"#, severity: .high),
        ToxicPattern(pattern: #"\b(hate|kill|die)\b"#, severity: .high),
        ToxicPattern(pattern: #"(.)\1{4,}"#, severity: .low),  // Repeated chars (spaaaam)
        ToxicPattern(pattern: #"[A-Z]{5,}"#, severity: .low),  // ALL CAPS
        ToxicPattern(pattern: #"https?://\S+"#, severity: .medium),  // Links (potential spam)
    ]

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

    /// Analyze text for toxicity using NLP sentiment analysis and pattern matching
    private func isToxic(_ text: String) -> Bool {
        let toxicityScore = analyzeToxicity(text)
        let threshold = moderationSensitivity.threshold

        if toxicityScore >= threshold {
            print("🔍 Toxicity detected: \(String(format: "%.2f", toxicityScore)) (threshold: \(threshold))")
            return true
        }
        return false
    }

    /// Calculate toxicity score using multiple signals
    /// - Returns: Score from 0.0 (safe) to 1.0 (toxic)
    private func analyzeToxicity(_ text: String) -> Double {
        var score: Double = 0.0

        // 1. Sentiment Analysis using NaturalLanguage
        sentimentAnalyzer.string = text
        let range = text.startIndex..<text.endIndex

        if let sentimentTag = sentimentAnalyzer.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore).0,
           let sentimentScore = Double(sentimentTag.rawValue) {
            // Sentiment ranges from -1 (negative) to 1 (positive)
            // Convert negative sentiment to toxicity score
            if sentimentScore < 0 {
                score += abs(sentimentScore) * 0.4  // Weight: 40%
            }
        }

        // 2. Pattern-based detection
        let patternScore = analyzePatterns(text)
        score += patternScore * 0.4  // Weight: 40%

        // 3. Character-level analysis (spam detection)
        let spamScore = analyzeSpamCharacteristics(text)
        score += spamScore * 0.2  // Weight: 20%

        return min(1.0, score)
    }

    /// Check text against toxic patterns
    private func analyzePatterns(_ text: String) -> Double {
        var maxSeverity: Double = 0.0

        for toxicPattern in toxicPatterns {
            if let regex = try? NSRegularExpression(pattern: toxicPattern.pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..., in: text)
                let matches = regex.numberOfMatches(in: text, range: range)

                if matches > 0 {
                    let severityValue = toxicPattern.severity.score
                    maxSeverity = max(maxSeverity, severityValue)
                }
            }
        }

        return maxSeverity
    }

    /// Analyze spam-like characteristics
    private func analyzeSpamCharacteristics(_ text: String) -> Double {
        var score: Double = 0.0

        // Check for excessive caps
        let capsCount = text.filter { $0.isUppercase }.count
        let capsRatio = Double(capsCount) / max(1.0, Double(text.count))
        if capsRatio > 0.7 && text.count > 5 {
            score += 0.3
        }

        // Check for repeated characters
        var repeatCount = 0
        var lastChar: Character?
        for char in text {
            if char == lastChar {
                repeatCount += 1
            } else {
                repeatCount = 0
            }
            if repeatCount >= 3 {
                score += 0.2
                break
            }
            lastChar = char
        }

        // Check for excessive emoji/special chars
        let specialCount = text.filter { !$0.isLetter && !$0.isNumber && !$0.isWhitespace }.count
        let specialRatio = Double(specialCount) / max(1.0, Double(text.count))
        if specialRatio > 0.5 && text.count > 3 {
            score += 0.2
        }

        return min(1.0, score)
    }
}

// MARK: - Moderation Types

enum ModerationSensitivity: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var threshold: Double {
        switch self {
        case .low: return 0.7
        case .medium: return 0.5
        case .high: return 0.3
        }
    }

    var description: String {
        switch self {
        case .low: return "Only block obvious toxic content"
        case .medium: return "Balanced moderation"
        case .high: return "Strict moderation, may catch false positives"
        }
    }
}

struct ToxicPattern {
    let pattern: String
    let severity: Severity

    enum Severity {
        case low
        case medium
        case high

        var score: Double {
            switch self {
            case .low: return 0.3
            case .medium: return 0.6
            case .high: return 0.9
            }
        }
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
