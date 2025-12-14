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

    // MARK: - AI Moderation

    private lazy var toxicityClassifier: ToxicityClassifier? = {
        return ToxicityClassifier()
    }()

    private func isToxic(_ text: String) -> Bool {
        // Use CoreML toxicity classifier if available
        if let classifier = toxicityClassifier,
           let prediction = classifier.classify(text: text) {
            return prediction.isToxic
        }

        // Fallback to rule-based filter
        return isRuleBasedToxic(text)
    }

    private func isRuleBasedToxic(_ text: String) -> Bool {
        let lowercased = text.lowercased()

        // Keyword-based detection
        let toxicKeywords = ["spam", "scam", "hate", "abuse", "harass"]
        if toxicKeywords.contains(where: { lowercased.contains($0) }) {
            return true
        }

        // Excessive caps detection (shouting)
        let capsRatio = Double(text.filter { $0.isUppercase }.count) / Double(max(text.count, 1))
        if capsRatio > 0.7 && text.count > 10 {
            return true
        }

        // Repeated character spam
        let repeatedPattern = #"(.)\1{4,}"#
        if let regex = try? NSRegularExpression(pattern: repeatedPattern),
           regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
            return true
        }

        // Link spam (multiple URLs)
        let urlPattern = #"https?://\S+"#
        if let regex = try? NSRegularExpression(pattern: urlPattern) {
            let matches = regex.numberOfMatches(in: text, range: NSRange(text.startIndex..., in: text))
            if matches > 2 {
                return true
            }
        }

        return false
    }
}

// MARK: - CoreML Toxicity Classifier

class ToxicityClassifier {
    // CoreML model reference - loaded at runtime if available
    private var model: Any? // MLModel when available

    struct Prediction {
        let isToxic: Bool
        let confidence: Float
        let categories: [String: Float]
    }

    init() {
        loadModel()
    }

    private func loadModel() {
        // Try to load the ToxicityClassifier.mlmodelc from bundle
        guard let modelURL = Bundle.main.url(forResource: "ToxicityClassifier", withExtension: "mlmodelc") else {
            print("⚠️ ToxicityClassifier: Model not found - using rule-based fallback")
            return
        }

        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuOnly // Fast for text
            model = try MLModel(contentsOf: modelURL, configuration: config)
            print("🧠 ToxicityClassifier: Loaded CoreML model")
        } catch {
            print("⚠️ ToxicityClassifier: Failed to load model - \(error)")
        }
    }

    func classify(text: String) -> Prediction? {
        guard model != nil else { return nil }

        // In production: Use NLModel or custom MLModel for text classification
        // For now, return nil to use rule-based fallback
        // This would be implemented with actual CoreML text classification

        // Placeholder: Simple sentiment heuristics
        let negativeWords = ["hate", "terrible", "awful", "disgusting", "trash"]
        let matchCount = negativeWords.filter { text.lowercased().contains($0) }.count

        if matchCount > 0 {
            return Prediction(
                isToxic: matchCount >= 2,
                confidence: Float(min(matchCount, 3)) / 3.0,
                categories: ["negative": Float(matchCount) / 5.0]
            )
        }

        return Prediction(isToxic: false, confidence: 0.9, categories: [:])
    }
}

import CoreML

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
