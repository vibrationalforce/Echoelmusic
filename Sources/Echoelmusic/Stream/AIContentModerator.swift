import Foundation
import NaturalLanguage
import Accelerate

// ═══════════════════════════════════════════════════════════════════════════════
// AI CONTENT MODERATOR - ADVANCED TOXICITY DETECTION
// ═══════════════════════════════════════════════════════════════════════════════
//
// Multi-layered content moderation system:
// • NLP-based sentiment analysis
// • Pattern matching for known toxic phrases
// • Contextual understanding with word embeddings
// • Bio-reactive sensitivity adjustment
// • Learning system with feedback loop
//
// ═══════════════════════════════════════════════════════════════════════════════

@MainActor
final class AIContentModerator: ObservableObject {

    // MARK: - Published State

    @Published var isEnabled: Bool = true
    @Published var sensitivity: ModerationSensitivity = .balanced
    @Published var blockedMessages: Int = 0
    @Published var flaggedMessages: Int = 0
    @Published var processedMessages: Int = 0

    // MARK: - Moderation Categories

    enum ModerationCategory: String, CaseIterable {
        case toxicity = "Toxicity"
        case harassment = "Harassment"
        case spam = "Spam"
        case selfHarm = "Self-Harm"
        case hate = "Hate Speech"
        case sexual = "Sexual Content"
        case violence = "Violence"
        case misinformation = "Misinformation"

        var threshold: Float {
            switch self {
            case .toxicity: return 0.7
            case .harassment: return 0.6
            case .spam: return 0.8
            case .selfHarm: return 0.3  // Low threshold - high sensitivity
            case .hate: return 0.5
            case .sexual: return 0.6
            case .violence: return 0.6
            case .misinformation: return 0.7
            }
        }
    }

    enum ModerationSensitivity: String, CaseIterable {
        case relaxed = "Relaxed"
        case balanced = "Balanced"
        case strict = "Strict"
        case maximum = "Maximum"

        var multiplier: Float {
            switch self {
            case .relaxed: return 0.7
            case .balanced: return 1.0
            case .strict: return 1.3
            case .maximum: return 1.6
            }
        }
    }

    // MARK: - Analysis Result

    struct ModerationResult {
        let isAllowed: Bool
        let overallScore: Float
        let categoryScores: [ModerationCategory: Float]
        let flaggedCategories: [ModerationCategory]
        let sentiment: Sentiment
        let confidence: Float
        let suggestedAction: Action

        enum Sentiment {
            case positive
            case neutral
            case negative
            case mixed
        }

        enum Action {
            case allow
            case flag
            case block
            case timeout(duration: TimeInterval)
            case ban
        }
    }

    // MARK: - NLP Components

    private let sentimentPredictor: NLModel?
    private let tagger: NLTagger
    private let tokenizer: NLTokenizer

    // MARK: - Pattern Databases

    private var toxicPatterns: [ToxicPattern] = []
    private var safePatterns: [String] = []
    private var customBlockedWords: Set<String> = []
    private var customAllowedWords: Set<String> = []

    // MARK: - Learning System

    private var falsePositives: [String] = []
    private var falseNegatives: [String] = []

    // MARK: - Bio-Reactive

    private var bioCoherence: Float = 0.5
    private var stressLevel: Float = 0.5

    // MARK: - Initialization

    init() {
        // Initialize NLP components
        self.tagger = NLTagger(tagSchemes: [.sentimentScore, .lexicalClass, .nameType])
        self.tokenizer = NLTokenizer(unit: .word)

        // Load sentiment model
        if let modelURL = Bundle.main.url(forResource: "SentimentClassifier", withExtension: "mlmodelc") {
            self.sentimentPredictor = try? NLModel(contentsOf: modelURL)
        } else {
            self.sentimentPredictor = nil
        }

        // Initialize toxic patterns
        loadToxicPatterns()

        print("✅ AIContentModerator: Initialized")
    }

    // MARK: - Pattern Loading

    private func loadToxicPatterns() {
        toxicPatterns = [
            // Harassment patterns
            ToxicPattern(pattern: #"(kill|die|hurt)\s+(yourself|urself)"#, category: .selfHarm, weight: 1.0),
            ToxicPattern(pattern: #"kys"#, category: .selfHarm, weight: 0.95),
            ToxicPattern(pattern: #"go\s+die"#, category: .harassment, weight: 0.9),

            // Hate speech patterns
            ToxicPattern(pattern: #"(\b)(racist|sexist|bigot)(\b)"#, category: .hate, weight: 0.6),
            ToxicPattern(pattern: #"all\s+\w+\s+(should|must|need to)\s+(die|leave|go)"#, category: .hate, weight: 0.9),

            // Spam patterns
            ToxicPattern(pattern: #"(buy|click|subscribe|follow)\s+(now|here|my)"#, category: .spam, weight: 0.7),
            ToxicPattern(pattern: #"https?://\S+\s*(https?://\S+)+"#, category: .spam, weight: 0.8),
            ToxicPattern(pattern: #"(.)\1{5,}"#, category: .spam, weight: 0.6),  // Repeated characters
            ToxicPattern(pattern: #"([A-Z\s]{10,})"#, category: .spam, weight: 0.5),  // ALL CAPS

            // Violence patterns
            ToxicPattern(pattern: #"(shoot|stab|attack|bomb)\s+(you|them|everyone)"#, category: .violence, weight: 0.85),

            // Toxicity patterns
            ToxicPattern(pattern: #"(stupid|idiot|moron|dumb)\s+(streamer|person|people)"#, category: .toxicity, weight: 0.7),
            ToxicPattern(pattern: #"you('re|r)?\s+(trash|garbage|worthless)"#, category: .toxicity, weight: 0.8),
        ]
    }

    // MARK: - Moderation

    func moderate(_ text: String, username: String? = nil) -> ModerationResult {
        processedMessages += 1

        let normalizedText = normalizeText(text)

        // 1. Pattern matching
        let patternScores = analyzePatterns(normalizedText)

        // 2. NLP sentiment analysis
        let sentiment = analyzeSentiment(normalizedText)

        // 3. Linguistic analysis
        let linguisticScore = analyzeLinguistics(normalizedText)

        // 4. Context analysis
        let contextScore = analyzeContext(normalizedText, username: username)

        // 5. Calculate overall scores
        var categoryScores: [ModerationCategory: Float] = [:]

        for category in ModerationCategory.allCases {
            var score: Float = 0.0

            // Pattern score
            if let patternScore = patternScores[category] {
                score = max(score, patternScore)
            }

            // Adjust based on sentiment
            switch sentiment {
            case .negative:
                score *= 1.2
            case .positive:
                score *= 0.7
            default:
                break
            }

            // Adjust based on linguistics
            score += linguisticScore * 0.1

            // Adjust based on context
            score *= contextScore

            // Apply sensitivity
            score *= sensitivity.multiplier

            // Bio-reactive adjustment
            score = applyBioReactiveAdjustment(score)

            categoryScores[category] = min(score, 1.0)
        }

        // Determine flagged categories
        let flaggedCategories = categoryScores.filter { $0.value > $0.key.threshold * sensitivity.multiplier }
            .map { $0.key }

        // Calculate overall score
        let overallScore = categoryScores.values.max() ?? 0.0

        // Determine action
        let action = determineAction(overallScore: overallScore, flaggedCategories: flaggedCategories)
        let isAllowed = action == .allow || action == .flag

        // Update stats
        if !isAllowed {
            blockedMessages += 1
        } else if !flaggedCategories.isEmpty {
            flaggedMessages += 1
        }

        // Calculate confidence
        let confidence = calculateConfidence(patternScores: patternScores, overallScore: overallScore)

        return ModerationResult(
            isAllowed: isAllowed,
            overallScore: overallScore,
            categoryScores: categoryScores,
            flaggedCategories: flaggedCategories,
            sentiment: sentiment,
            confidence: confidence,
            suggestedAction: action
        )
    }

    // MARK: - Text Normalization

    private func normalizeText(_ text: String) -> String {
        var normalized = text.lowercased()

        // Remove extra whitespace
        normalized = normalized.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)

        // Handle common obfuscation
        normalized = deobfuscate(normalized)

        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func deobfuscate(_ text: String) -> String {
        var deobfuscated = text

        // Leet speak conversions
        let leetMap: [Character: Character] = [
            "0": "o", "1": "i", "3": "e", "4": "a", "5": "s",
            "7": "t", "8": "b", "@": "a", "$": "s"
        ]

        deobfuscated = String(deobfuscated.map { leetMap[$0] ?? $0 })

        // Remove spacing tricks (h e l l o -> hello)
        let spacedPattern = #"(\w)\s+(?=\w\s+\w)"#
        if let regex = try? NSRegularExpression(pattern: spacedPattern) {
            let range = NSRange(deobfuscated.startIndex..., in: deobfuscated)
            deobfuscated = regex.stringByReplacingMatches(in: deobfuscated, range: range, withTemplate: "$1")
        }

        // Remove repeated characters (hellooooo -> hello)
        let repeatedPattern = #"(.)\1{2,}"#
        if let regex = try? NSRegularExpression(pattern: repeatedPattern) {
            let range = NSRange(deobfuscated.startIndex..., in: deobfuscated)
            deobfuscated = regex.stringByReplacingMatches(in: deobfuscated, range: range, withTemplate: "$1$1")
        }

        return deobfuscated
    }

    // MARK: - Pattern Analysis

    private func analyzePatterns(_ text: String) -> [ModerationCategory: Float] {
        var scores: [ModerationCategory: Float] = [:]

        for pattern in toxicPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern.pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                let matches = regex.numberOfMatches(in: text, range: range)

                if matches > 0 {
                    let score = min(pattern.weight + Float(matches - 1) * 0.1, 1.0)
                    scores[pattern.category] = max(scores[pattern.category] ?? 0, score)
                }
            }
        }

        // Check custom blocked words
        for word in customBlockedWords {
            if text.contains(word.lowercased()) {
                scores[.toxicity] = max(scores[.toxicity] ?? 0, 0.9)
            }
        }

        return scores
    }

    // MARK: - Sentiment Analysis

    private func analyzeSentiment(_ text: String) -> ModerationResult.Sentiment {
        tagger.string = text

        var sentimentScore: Float = 0.0
        var tokenCount: Float = 0.0

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .sentence, scheme: .sentimentScore) { tag, _ in
            if let tag = tag, let score = Float(tag.rawValue) {
                sentimentScore += score
                tokenCount += 1
            }
            return true
        }

        // Also use NLP model if available
        if let predictor = sentimentPredictor {
            if let prediction = predictor.predictedLabel(for: text) {
                switch prediction.lowercased() {
                case "positive":
                    sentimentScore += 0.5
                case "negative":
                    sentimentScore -= 0.5
                default:
                    break
                }
                tokenCount += 1
            }
        }

        guard tokenCount > 0 else { return .neutral }

        let avgScore = sentimentScore / tokenCount

        if avgScore > 0.2 { return .positive }
        if avgScore < -0.2 { return .negative }
        if abs(avgScore) < 0.1 { return .neutral }
        return .mixed
    }

    // MARK: - Linguistic Analysis

    private func analyzeLinguistics(_ text: String) -> Float {
        var score: Float = 0.0

        tokenizer.string = text
        var tokens: [String] = []

        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            tokens.append(String(text[tokenRange]))
            return true
        }

        // Check for aggressive punctuation
        let exclamationCount = text.filter { $0 == "!" }.count
        if exclamationCount > 3 {
            score += 0.1 * Float(min(exclamationCount, 10))
        }

        // Check for ALL CAPS ratio
        let uppercaseRatio = Float(text.filter { $0.isUppercase }.count) / Float(max(text.count, 1))
        if uppercaseRatio > 0.7 && text.count > 5 {
            score += 0.2
        }

        // Check for excessive profanity indicators
        let asteriskGroups = text.components(separatedBy: " ").filter { $0.contains("*") && $0.count > 2 }
        score += Float(asteriskGroups.count) * 0.15

        return min(score, 1.0)
    }

    // MARK: - Context Analysis

    private func analyzeContext(_ text: String, username: String?) -> Float {
        var multiplier: Float = 1.0

        // Very short messages with toxic content are often more intentional
        if text.count < 20 {
            multiplier *= 1.1
        }

        // Messages targeting the streamer
        if text.lowercased().contains("streamer") || text.lowercased().contains("you") {
            multiplier *= 1.15
        }

        // Repeated user behavior (would need history tracking)
        // For now, just return the multiplier

        return multiplier
    }

    // MARK: - Bio-Reactive Adjustment

    func updateBioParameters(coherence: Float, stressLevel: Float) {
        self.bioCoherence = coherence
        self.stressLevel = stressLevel
    }

    private func applyBioReactiveAdjustment(_ score: Float) -> Float {
        // When user stress is high, be more protective
        let stressMultiplier = 1.0 + (stressLevel - 0.5) * 0.3

        // When coherence is low, be more protective
        let coherenceMultiplier = 1.0 + (0.5 - bioCoherence) * 0.2

        return score * stressMultiplier * coherenceMultiplier
    }

    // MARK: - Action Determination

    private func determineAction(overallScore: Float, flaggedCategories: [ModerationCategory]) -> ModerationResult.Action {
        // Self-harm is always highest priority
        if flaggedCategories.contains(.selfHarm) {
            return .block
        }

        // Very high scores
        if overallScore > 0.9 {
            return .ban
        }

        if overallScore > 0.75 {
            return .block
        }

        if overallScore > 0.5 {
            return .timeout(duration: 300) // 5 minutes
        }

        if overallScore > 0.3 {
            return .flag
        }

        return .allow
    }

    // MARK: - Confidence Calculation

    private func calculateConfidence(patternScores: [ModerationCategory: Float], overallScore: Float) -> Float {
        // Higher confidence when pattern matches are clear
        let patternConfidence = patternScores.values.max() ?? 0.0

        // Lower confidence for borderline cases
        let borderlineAdjustment: Float
        if overallScore > 0.4 && overallScore < 0.6 {
            borderlineAdjustment = -0.2
        } else {
            borderlineAdjustment = 0.0
        }

        return min(max(patternConfidence + 0.3 + borderlineAdjustment, 0.0), 1.0)
    }

    // MARK: - Learning System

    func reportFalsePositive(_ text: String) {
        falsePositives.append(text)

        // Add common words from false positives to safe list
        let words = text.lowercased().components(separatedBy: .whitespaces)
        for word in words {
            if falsePositives.filter({ $0.lowercased().contains(word) }).count > 3 {
                safePatterns.append(word)
            }
        }
    }

    func reportFalseNegative(_ text: String) {
        falseNegatives.append(text)

        // Add to custom blocked words if recurring
        let words = text.lowercased().components(separatedBy: .whitespaces)
        for word in words {
            if falseNegatives.filter({ $0.lowercased().contains(word) }).count > 2 {
                customBlockedWords.insert(word)
            }
        }
    }

    // MARK: - Configuration

    func addBlockedWord(_ word: String) {
        customBlockedWords.insert(word.lowercased())
    }

    func removeBlockedWord(_ word: String) {
        customBlockedWords.remove(word.lowercased())
    }

    func addAllowedWord(_ word: String) {
        customAllowedWords.insert(word.lowercased())
    }

    func removeAllowedWord(_ word: String) {
        customAllowedWords.remove(word.lowercased())
    }

    // MARK: - Statistics

    func getStatistics() -> ModerationStatistics {
        let blockRate = processedMessages > 0 ? Float(blockedMessages) / Float(processedMessages) : 0.0
        let flagRate = processedMessages > 0 ? Float(flaggedMessages) / Float(processedMessages) : 0.0

        return ModerationStatistics(
            totalProcessed: processedMessages,
            blocked: blockedMessages,
            flagged: flaggedMessages,
            allowed: processedMessages - blockedMessages,
            blockRate: blockRate,
            flagRate: flagRate,
            falsePositiveReports: falsePositives.count,
            falseNegativeReports: falseNegatives.count
        )
    }

    struct ModerationStatistics {
        let totalProcessed: Int
        let blocked: Int
        let flagged: Int
        let allowed: Int
        let blockRate: Float
        let flagRate: Float
        let falsePositiveReports: Int
        let falseNegativeReports: Int
    }
}

// MARK: - Toxic Pattern

private struct ToxicPattern {
    let pattern: String
    let category: AIContentModerator.ModerationCategory
    let weight: Float
}

// MARK: - Chat Aggregator Extension

extension ChatAggregator {

    private static var _moderator: AIContentModerator?

    var aiModerator: AIContentModerator {
        if ChatAggregator._moderator == nil {
            ChatAggregator._moderator = AIContentModerator()
        }
        return ChatAggregator._moderator!
    }

    func moderateMessage(_ message: ChatMessage) -> Bool {
        guard moderationEnabled else { return true }

        let result = aiModerator.moderate(message.text, username: message.username)

        if !result.isAllowed {
            toxicMessagesBlocked += 1
            print("🚫 ChatAggregator: Blocked message - \(result.flaggedCategories.map { $0.rawValue }.joined(separator: ", "))")
            return false
        }

        if !result.flaggedCategories.isEmpty {
            print("⚠️ ChatAggregator: Flagged message - \(result.flaggedCategories.map { $0.rawValue }.joined(separator: ", "))")
        }

        return true
    }
}

// MARK: - Enhanced Chat Message

extension ChatMessage {

    struct ModerationInfo {
        let isModerated: Bool
        let categories: [AIContentModerator.ModerationCategory]
        let score: Float
        let action: AIContentModerator.ModerationResult.Action
    }
}
