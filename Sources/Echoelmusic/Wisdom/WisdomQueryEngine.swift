import Foundation
import Combine
import os.log

// ═══════════════════════════════════════════════════════════════════════════════
// WISDOM QUERY ENGINE
// ═══════════════════════════════════════════════════════════════════════════════
//
// Natural Language Understanding for EchoelWisdom™
//
// Features:
// • Intent classification
// • Entity extraction
// • Context awareness
// • Sentiment analysis
// • Crisis indicator detection
// • Multi-turn conversation support
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Wisdom Query Engine

@MainActor
public final class WisdomQueryEngine: ObservableObject {

    // MARK: - Singleton

    public static let shared = WisdomQueryEngine()

    // MARK: - Published State

    @Published public var isReady: Bool = false
    @Published public var lastResponseQuality: Float = 0.0
    @Published public var conversationContext: ConversationContext = ConversationContext()

    // MARK: - Private State

    private let logger = Logger(subsystem: "com.echoelmusic.wisdom", category: "QueryEngine")
    private var queryPatterns: [QueryPattern] = []
    private var entityExtractors: [EntityExtractor] = []
    private var sentimentAnalyzer: SentimentAnalyzer?

    // MARK: - Initialization

    private init() {
        logger.info("🔍 Wisdom Query Engine: Initialized")
    }

    // MARK: - Initialization

    public func initialize() {
        loadQueryPatterns()
        loadEntityExtractors()
        initializeSentimentAnalyzer()
        isReady = true
        logger.info("✅ Query Engine: Ready")
    }

    // MARK: - Pattern Loading

    private func loadQueryPatterns() {
        queryPatterns = [
            // Technical patterns
            QueryPattern(
                category: .technical,
                patterns: [
                    "how do i", "how to", "what's the best way to",
                    "eq", "compress", "reverb", "delay", "mix", "master",
                    "frequency", "db", "gain", "level", "pan", "stereo"
                ],
                weight: 1.0
            ),

            // Emotional patterns
            QueryPattern(
                category: .emotional,
                patterns: [
                    "i feel", "i'm feeling", "i'm stuck", "stuck",
                    "overwhelmed", "frustrated", "not good enough",
                    "imposter", "can't", "never", "always fail"
                ],
                weight: 1.2
            ),

            // Crisis patterns (highest priority)
            QueryPattern(
                category: .crisis,
                patterns: [
                    "suicide", "suicidal", "kill myself", "end my life",
                    "self-harm", "hurt myself", "want to die",
                    "can't go on", "no point", "better off dead"
                ],
                weight: 10.0  // Highest priority
            ),

            // Philosophical patterns
            QueryPattern(
                category: .philosophical,
                patterns: [
                    "why", "purpose", "meaning", "what is",
                    "nature of", "philosophy", "ethics", "moral"
                ],
                weight: 0.8
            ),

            // Health-adjacent patterns
            QueryPattern(
                category: .health,
                patterns: [
                    "anxiety", "stress", "depression", "mental health",
                    "hrv", "heart rate", "breathing", "sleep", "insomnia"
                ],
                weight: 1.1
            ),

            // Industry patterns
            QueryPattern(
                category: .industry,
                patterns: [
                    "spotify", "apple music", "streaming", "royalties",
                    "label", "distribution", "artist rights", "payment"
                ],
                weight: 0.9
            ),

            // Neuroscience patterns
            QueryPattern(
                category: .neuroscience,
                patterns: [
                    "brain", "neuroscience", "dopamine", "serotonin",
                    "amygdala", "cortex", "neural", "cognitive"
                ],
                weight: 1.0
            )
        ]
    }

    private func loadEntityExtractors() {
        entityExtractors = [
            // Frequency entity extractor
            EntityExtractor(
                type: .frequency,
                pattern: #"(\d+(?:\.\d+)?)\s*(?:hz|Hz|HZ|khz|kHz|KHZ)"#
            ),

            // dB entity extractor
            EntityExtractor(
                type: .decibel,
                pattern: #"(-?\d+(?:\.\d+)?)\s*(?:db|dB|DB)"#
            ),

            // Time entity extractor
            EntityExtractor(
                type: .time,
                pattern: #"(\d+(?:\.\d+)?)\s*(?:ms|sec|s|min|minutes?|hours?)"#
            ),

            // Musical key extractor
            EntityExtractor(
                type: .musicalKey,
                pattern: #"([A-Ga-g][#b]?)\s*(?:major|minor|maj|min|m)?"#
            ),

            // BPM extractor
            EntityExtractor(
                type: .tempo,
                pattern: #"(\d+)\s*(?:bpm|BPM)"#
            )
        ]
    }

    private func initializeSentimentAnalyzer() {
        sentimentAnalyzer = SentimentAnalyzer()
    }

    // MARK: - Query Analysis

    public func analyzeQuery(_ query: String) -> QueryAnalysis {
        let lowercaseQuery = query.lowercased()

        // 1. Pattern matching for category
        let categoryScores = calculateCategoryScores(lowercaseQuery)

        // 2. Entity extraction
        let entities = extractEntities(query)

        // 3. Sentiment analysis
        let sentiment = sentimentAnalyzer?.analyze(query) ?? .neutral

        // 4. Crisis detection (always check)
        let isCrisis = detectsCrisisIndicators(in: lowercaseQuery)

        // 5. Determine primary category
        let primaryCategory: QueryCategory
        if isCrisis {
            primaryCategory = .crisis
        } else {
            primaryCategory = categoryScores.max(by: { $0.value < $1.value })?.key ?? .general
        }

        // 6. Build analysis result
        let analysis = QueryAnalysis(
            originalQuery: query,
            normalizedQuery: lowercaseQuery,
            primaryCategory: primaryCategory,
            categoryScores: categoryScores,
            entities: entities,
            sentiment: sentiment,
            isCrisis: isCrisis,
            conversationTurn: conversationContext.turnCount
        )

        // Update conversation context
        updateConversationContext(with: analysis)

        // Update quality metric
        lastResponseQuality = Float(categoryScores.values.max() ?? 0.5)

        return analysis
    }

    // MARK: - Category Scoring

    private func calculateCategoryScores(_ query: String) -> [QueryCategory: Double] {
        var scores: [QueryCategory: Double] = [:]

        for pattern in queryPatterns {
            var patternScore = 0.0

            for keyword in pattern.patterns {
                if query.contains(keyword) {
                    patternScore += 1.0
                }
            }

            // Normalize and weight
            let normalizedScore = (patternScore / Double(pattern.patterns.count)) * Double(pattern.weight)
            scores[pattern.category] = normalizedScore
        }

        return scores
    }

    // MARK: - Entity Extraction

    private func extractEntities(_ query: String) -> [ExtractedEntity] {
        var entities: [ExtractedEntity] = []

        for extractor in entityExtractors {
            do {
                let regex = try NSRegularExpression(pattern: extractor.pattern, options: [])
                let range = NSRange(query.startIndex..<query.endIndex, in: query)

                regex.enumerateMatches(in: query, options: [], range: range) { match, _, _ in
                    if let match = match,
                       let valueRange = Range(match.range(at: 1), in: query) {
                        let value = String(query[valueRange])
                        entities.append(ExtractedEntity(
                            type: extractor.type,
                            value: value,
                            originalText: String(query[Range(match.range, in: query)!])
                        ))
                    }
                }
            } catch {
                logger.error("Entity extraction error: \(error.localizedDescription)")
            }
        }

        return entities
    }

    // MARK: - Crisis Detection

    public func detectsCrisisIndicators(in query: String) -> Bool {
        let crisisPatterns = queryPatterns.first { $0.category == .crisis }?.patterns ?? []
        return crisisPatterns.contains { query.contains($0) }
    }

    // MARK: - Conversation Context

    private func updateConversationContext(with analysis: QueryAnalysis) {
        conversationContext.turnCount += 1
        conversationContext.recentCategories.append(analysis.primaryCategory)

        // Keep only recent categories
        if conversationContext.recentCategories.count > 10 {
            conversationContext.recentCategories.removeFirst()
        }

        // Track sentiment trend
        conversationContext.sentimentHistory.append(analysis.sentiment)
        if conversationContext.sentimentHistory.count > 10 {
            conversationContext.sentimentHistory.removeFirst()
        }

        // Update dominant topics
        let categoryCounts = conversationContext.recentCategories.reduce(into: [:]) { counts, category in
            counts[category, default: 0] += 1
        }
        if let dominant = categoryCounts.max(by: { $0.value < $1.value })?.key {
            conversationContext.dominantTopic = dominant
        }
    }

    public func resetConversation() {
        conversationContext = ConversationContext()
        logger.info("🔄 Conversation context reset")
    }

    // MARK: - Query Suggestion

    public func suggestFollowUpQueries(for analysis: QueryAnalysis) -> [String] {
        switch analysis.primaryCategory {
        case .technical:
            return [
                "Can you explain the underlying physics?",
                "What are common mistakes to avoid?",
                "How does this apply to different genres?"
            ]

        case .emotional:
            return [
                "Would you like to explore this feeling more?",
                "What has helped in similar situations before?",
                "Would neuroscience perspective be helpful?"
            ]

        case .philosophical:
            return [
                "How does this relate to your creative practice?",
                "What would different philosophers say?",
                "What assumptions are we making?"
            ]

        case .health:
            return [
                "Would you like evidence-based strategies?",
                "Should we explore the neuroscience?",
                "Have you consulted a healthcare professional?"
            ]

        case .industry:
            return [
                "Want to see the financial breakdown?",
                "Interested in alternative models?",
                "Should we discuss artist advocacy?"
            ]

        case .neuroscience:
            return [
                "Want to go deeper into the mechanisms?",
                "How does this apply practically?",
                "What are the current research frontiers?"
            ]

        case .crisis:
            return [] // No suggestions for crisis - direct to resources

        case .general:
            return [
                "Can you be more specific about what you're looking for?",
                "Is this about your creative work or general curiosity?",
                "Would you like technical or philosophical perspective?"
            ]
        }
    }
}

// MARK: - Supporting Types

public struct QueryPattern {
    let category: QueryCategory
    let patterns: [String]
    let weight: Float
}

public enum QueryCategory: String, CaseIterable {
    case technical = "Technical"
    case emotional = "Emotional"
    case philosophical = "Philosophical"
    case health = "Health"
    case industry = "Industry"
    case neuroscience = "Neuroscience"
    case crisis = "Crisis"
    case general = "General"
}

public struct EntityExtractor {
    let type: EntityType
    let pattern: String
}

public enum EntityType: String {
    case frequency = "Frequency"
    case decibel = "Decibel"
    case time = "Time"
    case musicalKey = "Musical Key"
    case tempo = "Tempo"
    case instrument = "Instrument"
    case effect = "Effect"
}

public struct ExtractedEntity: Identifiable {
    public let id = UUID()
    public let type: EntityType
    public let value: String
    public let originalText: String
}

public struct QueryAnalysis {
    public let originalQuery: String
    public let normalizedQuery: String
    public let primaryCategory: QueryCategory
    public let categoryScores: [QueryCategory: Double]
    public let entities: [ExtractedEntity]
    public let sentiment: Sentiment
    public let isCrisis: Bool
    public let conversationTurn: Int

    public var confidence: Double {
        return categoryScores.values.max() ?? 0.0
    }
}

// MARK: - Sentiment Analysis

public enum Sentiment: String {
    case veryPositive = "Very Positive"
    case positive = "Positive"
    case neutral = "Neutral"
    case negative = "Negative"
    case veryNegative = "Very Negative"
    case distressed = "Distressed"
}

public class SentimentAnalyzer {
    private let positiveWords = Set([
        "good", "great", "excellent", "love", "amazing", "wonderful",
        "happy", "excited", "beautiful", "perfect", "fantastic",
        "grateful", "thankful", "inspired", "creative", "flow"
    ])

    private let negativeWords = Set([
        "bad", "terrible", "hate", "awful", "horrible", "ugly",
        "sad", "depressed", "frustrated", "stuck", "fail",
        "never", "can't", "won't", "impossible", "hopeless"
    ])

    private let distressWords = Set([
        "overwhelmed", "exhausted", "broken", "alone", "worthless",
        "helpless", "trapped", "scared", "terrified", "panic"
    ])

    public func analyze(_ text: String) -> Sentiment {
        let words = text.lowercased().split(separator: " ").map(String.init)

        var positiveCount = 0
        var negativeCount = 0
        var distressCount = 0

        for word in words {
            if positiveWords.contains(word) { positiveCount += 1 }
            if negativeWords.contains(word) { negativeCount += 1 }
            if distressWords.contains(word) { distressCount += 1 }
        }

        // Check for distress first
        if distressCount > 0 {
            return .distressed
        }

        let total = positiveCount + negativeCount
        if total == 0 { return .neutral }

        let ratio = Double(positiveCount) / Double(total)

        switch ratio {
        case 0.8...1.0: return .veryPositive
        case 0.6..<0.8: return .positive
        case 0.4..<0.6: return .neutral
        case 0.2..<0.4: return .negative
        default: return .veryNegative
        }
    }
}

// MARK: - Conversation Context

public struct ConversationContext {
    public var turnCount: Int = 0
    public var recentCategories: [QueryCategory] = []
    public var sentimentHistory: [Sentiment] = []
    public var dominantTopic: QueryCategory?
    public var mentionedEntities: [ExtractedEntity] = []

    public var averageSentiment: Sentiment {
        let sentimentValues: [Sentiment: Int] = [
            .veryPositive: 2,
            .positive: 1,
            .neutral: 0,
            .negative: -1,
            .veryNegative: -2,
            .distressed: -3
        ]

        guard !sentimentHistory.isEmpty else { return .neutral }

        let total = sentimentHistory.reduce(0) { sum, sentiment in
            sum + (sentimentValues[sentiment] ?? 0)
        }
        let average = Double(total) / Double(sentimentHistory.count)

        switch average {
        case 1.5...2.0: return .veryPositive
        case 0.5..<1.5: return .positive
        case -0.5..<0.5: return .neutral
        case -1.5..<(-0.5): return .negative
        default: return .veryNegative
        }
    }

    public var isEmotionallyEscalating: Bool {
        guard sentimentHistory.count >= 3 else { return false }

        let recentThree = sentimentHistory.suffix(3)
        let sentimentValues: [Sentiment: Int] = [
            .veryPositive: 2, .positive: 1, .neutral: 0,
            .negative: -1, .veryNegative: -2, .distressed: -3
        ]

        let values = recentThree.map { sentimentValues[$0] ?? 0 }
        // Check if consistently getting more negative
        return values[1] < values[0] && values[2] < values[1]
    }
}
