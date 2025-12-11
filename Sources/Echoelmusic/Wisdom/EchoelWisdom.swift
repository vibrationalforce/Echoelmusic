import Foundation
import Combine
import os.log

// ═══════════════════════════════════════════════════════════════════════════════
// ECHOELWISDOM™ - UNIVERSAL KNOWLEDGE ARCHITECTURE
// ═══════════════════════════════════════════════════════════════════════════════
//
// "The Cosmic Library of Sound, Science, and Self"
//
// Aesthetic: Vaporwave • Sci-Fi • Steampunk • Evidence-Based
//
// Philosophy:
// • The Aesthetic: Accessing a cosmic library, retrofuturistic terminals
// • The Reality: Peer-reviewed neuroscience, PubMed-backed evidence
// • The Balance: Have fun with the vibe, stay rigorous with the science
//
// "What ancient mystics imagined as cosmic records,
//  We build as distributed knowledge networks.
//  Same wonder, better methodology."
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - EchoelWisdom Engine

@MainActor
public final class EchoelWisdom: ObservableObject {

    // MARK: - Singleton

    public static let shared = EchoelWisdom()

    // MARK: - Published State

    /// Current engine state
    @Published public var currentState: WisdomEngineState = .inactive

    /// Active knowledge domains
    @Published public var activeDomains: Set<KnowledgeDomain> = []

    /// Recent queries for context
    @Published public var recentQueries: [WisdomQuery] = []

    /// Current coaching context
    @Published public var coachingContext: CoachingContext?

    /// Quality metrics
    @Published public var responseQuality: Float = 0.0

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.echoelmusic.wisdom", category: "EchoelWisdom")
    private var queryHistory: [WisdomQuery] = []
    private var userProfile: UserProfile?

    // MARK: - Initialization

    private init() {
        logger.info("📚 EchoelWisdom™: Knowledge Architecture Initialized")
        logger.info("   ◉ Connected to peer-reviewed sources")
        logger.info("   ◉ Evidence-based, trauma-informed")
        logger.info("   ◉ Critical thinking enabled")
    }

    // MARK: - Activation

    public func activate() {
        guard currentState == .inactive else { return }

        currentState = .initializing

        // Initialize all knowledge domains
        activeDomains = Set(KnowledgeDomain.allCases)

        // Load user context if available
        loadUserContext()

        currentState = .active

        logger.info("✨ EchoelWisdom™: ACTIVE")
        printWelcomeMessage()
    }

    public func deactivate() {
        guard currentState == .active else { return }

        currentState = .inactive

        // Save session data
        saveSessionData()

        logger.info("🌙 EchoelWisdom™: Deactivated")
    }

    // MARK: - Query Processing

    public func processQuery(_ query: String, mode: WiseCompleteMode.CoachingMode) async -> WisdomResponse {
        currentState = .processingQuery

        // Create query object
        let wisdomQuery = WisdomQuery(
            text: query,
            timestamp: Date(),
            mode: mode,
            context: coachingContext
        )

        // Log query
        queryHistory.append(wisdomQuery)
        recentQueries = Array(queryHistory.suffix(10))

        // Classify intent
        let intent = classifyIntent(query)

        // Check for crisis indicators
        if detectsCrisisIndicators(in: query) {
            currentState = .crisisDetected
            return generateCrisisResponse(query)
        }

        // Generate response based on intent and mode
        let response = await generateResponse(
            query: wisdomQuery,
            intent: intent,
            mode: mode
        )

        currentState = .active
        responseQuality = response.confidence

        return response
    }

    // MARK: - Intent Classification

    private func classifyIntent(_ query: String) -> QueryIntent {
        let lowercaseQuery = query.lowercased()

        // Technical questions
        if lowercaseQuery.contains("how do i") ||
           lowercaseQuery.contains("eq") ||
           lowercaseQuery.contains("compress") ||
           lowercaseQuery.contains("mix") {
            return .technical
        }

        // Emotional support
        if lowercaseQuery.contains("feel") ||
           lowercaseQuery.contains("stuck") ||
           lowercaseQuery.contains("not good enough") ||
           lowercaseQuery.contains("overwhelmed") {
            return .emotional
        }

        // Philosophical
        if lowercaseQuery.contains("why") ||
           lowercaseQuery.contains("purpose") ||
           lowercaseQuery.contains("meaning") {
            return .philosophical
        }

        // Health-related
        if lowercaseQuery.contains("anxiety") ||
           lowercaseQuery.contains("stress") ||
           lowercaseQuery.contains("hrv") ||
           lowercaseQuery.contains("heart rate") {
            return .healthAdjacent
        }

        // Industry critique
        if lowercaseQuery.contains("spotify") ||
           lowercaseQuery.contains("artist") ||
           lowercaseQuery.contains("industry") ||
           lowercaseQuery.contains("label") {
            return .industryCritique
        }

        return .general
    }

    // MARK: - Response Generation

    private func generateResponse(
        query: WisdomQuery,
        intent: QueryIntent,
        mode: WiseCompleteMode.CoachingMode
    ) async -> WisdomResponse {

        // Get relevant knowledge
        let sources = WisdomKnowledgeBase.shared.search(
            query: query.text,
            domains: Array(activeDomains),
            limit: 5
        )

        // Generate response based on mode
        let message: String
        let tone: WisdomResponse.EmotionalTone
        var followUpQuestions: [String] = []

        switch mode {
        case .socratic:
            message = generateSocraticResponse(query: query, intent: intent, sources: sources)
            tone = .neutral
            followUpQuestions = generateSocraticQuestions(query: query, intent: intent)

        case .educational:
            message = generateEducationalResponse(query: query, intent: intent, sources: sources)
            tone = .encouraging
            followUpQuestions = generateEducationalFollowUps(intent: intent)

        case .supportive:
            message = generateSupportiveResponse(query: query, intent: intent, sources: sources)
            tone = .empathetic
            followUpQuestions = generateSupportiveFollowUps(query: query)

        case .strategic:
            message = generateStrategicResponse(query: query, intent: intent, sources: sources)
            tone = .encouraging
            followUpQuestions = generateStrategicFollowUps(intent: intent)
        }

        return WisdomResponse(
            message: message,
            sources: sources,
            confidence: calculateConfidence(sources: sources),
            suggestions: generateSuggestions(intent: intent),
            followUpQuestions: followUpQuestions,
            emotionalTone: tone
        )
    }

    // MARK: - Socratic Responses

    private func generateSocraticResponse(
        query: WisdomQuery,
        intent: QueryIntent,
        sources: [WisdomSource]
    ) -> String {
        switch intent {
        case .technical:
            return """
            Accessing the sonic archives... 🎛️

            Before I share what the research shows, let me ask:

            What have you tried so far? Understanding your current approach helps me give more relevant guidance.

            And what's the specific context - genre, mood, or reference track you're aiming for?
            """

        case .emotional:
            return """
            I sense there's something deeper here... 💜

            When you describe feeling this way, what specifically triggers that thought?

            Is it the outcome of your work, or the process itself that feels challenging?

            Sometimes our inner critic speaks loudest when we're actually growing. What would you tell a friend in your situation?
            """

        case .philosophical:
            return """
            Ah, you've touched on one of the great questions... ✨

            Before I share what philosophers and scientists have explored, I'm curious:

            What draws you to this question right now? There's often wisdom in understanding why we ask what we ask.
            """

        case .healthAdjacent:
            return """
            This is an important area - let me be thoughtful here... 🧠

            First: Are you exploring this out of curiosity, or are you experiencing something that concerns you?

            (If it's the latter, I want to make sure you have the right support - sometimes that means a healthcare professional rather than an AI.)
            """

        case .industryCritique:
            return """
            Now we're getting into the politics of music... 📊

            Before I share the data, what's your current understanding of how artist compensation works?

            And what sparked this question - a personal experience, or something you read?
            """

        case .general:
            return """
            Let me explore this with you... 🔮

            Can you tell me more about what prompted this question?

            Understanding your context helps me draw from the right knowledge streams.
            """
        }
    }

    private func generateSocraticQuestions(query: WisdomQuery, intent: QueryIntent) -> [String] {
        switch intent {
        case .technical:
            return [
                "What does 'success' look like for this specific task?",
                "How would you describe the current sound vs. your target?",
                "What reference tracks inspire you here?"
            ]
        case .emotional:
            return [
                "What would change if this feeling wasn't present?",
                "When have you overcome similar challenges before?",
                "What's one small thing you could do right now?"
            ]
        case .philosophical:
            return [
                "How does this question connect to your creative practice?",
                "What assumptions might be worth examining?",
                "What would different philosophers say about this?"
            ]
        default:
            return [
                "What's most important to you about this?",
                "What would you want to learn first?",
                "How does this connect to your larger goals?"
            ]
        }
    }

    // MARK: - Educational Responses

    private func generateEducationalResponse(
        query: WisdomQuery,
        intent: QueryIntent,
        sources: [WisdomSource]
    ) -> String {
        var response = "Let me share what the research shows... 📚\n\n"

        if !sources.isEmpty {
            response += "Key findings from peer-reviewed sources:\n\n"

            for (index, source) in sources.prefix(3).enumerated() {
                response += "\(index + 1). \(source.summary)\n"
                if let journal = source.journal, let year = source.year {
                    response += "   (Source: \(journal), \(year))\n"
                }
                response += "\n"
            }
        }

        response += """

        Important context:
        • Evidence quality varies - I've prioritized systematic reviews and RCTs
        • Science is provisional - new research may refine these findings
        • Individual responses vary - what works generally may not apply specifically

        Would you like to explore any of these findings deeper?
        """

        return response
    }

    private func generateEducationalFollowUps(intent: QueryIntent) -> [String] {
        return [
            "Would you like the original research citations?",
            "Should I explain the methodology behind these studies?",
            "Are there contradictory findings I should share?"
        ]
    }

    // MARK: - Supportive Responses

    private func generateSupportiveResponse(
        query: WisdomQuery,
        intent: QueryIntent,
        sources: [WisdomSource]
    ) -> String {
        if intent == .emotional {
            return """
            I hear you. What you're experiencing sounds challenging. 💜

            First, let me say: Your feelings are valid. Creative work is vulnerable work, and it makes sense to feel this way sometimes.

            When we're in the midst of something difficult, our brains can convince us that the feeling will last forever. But emotions are like weather - they pass.

            You're not alone in this. Many creators experience exactly what you're describing.

            What would feel most helpful right now?
            • Talking through what's happening
            • Some neuroscience perspective on why this happens
            • Practical strategies others have found useful
            • Just being heard without advice

            I'm here. No judgment.
            """
        }

        return """
        Thank you for sharing this with me. 💜

        I want to make sure I understand what you're experiencing before offering anything.

        Can you tell me more about what's happening? I'm listening.
        """
    }

    private func generateSupportiveFollowUps(query: WisdomQuery) -> [String] {
        return [
            "How are you feeling right now, in this moment?",
            "What would feel supportive?",
            "Is there anything you need that I might be able to help with?"
        ]
    }

    // MARK: - Strategic Responses

    private func generateStrategicResponse(
        query: WisdomQuery,
        intent: QueryIntent,
        sources: [WisdomSource]
    ) -> String {
        return """
        Let's break this down into actionable steps... 🎯

        Based on what you've shared, here's a framework:

        **1. Define the Goal**
        What does success look like? (Be specific and measurable)

        **2. Current State Assessment**
        Where are you now? What resources do you have?

        **3. Gap Analysis**
        What's the difference between where you are and where you want to be?

        **4. Action Steps**
        What's the smallest next action you can take?

        Let's work through these together. Starting with #1: What's the specific outcome you're aiming for?
        """
    }

    private func generateStrategicFollowUps(intent: QueryIntent) -> [String] {
        return [
            "What's the single most important step right now?",
            "What resources do you already have?",
            "What could you delegate or postpone?",
            "What's the deadline, real or self-imposed?"
        ]
    }

    // MARK: - Crisis Detection

    public func detectsCrisisIndicators(in query: String) -> Bool {
        let crisisKeywords = [
            "suicide", "suicidal", "kill myself", "end my life",
            "self-harm", "hurt myself", "cutting",
            "can't go on", "no point", "better off dead",
            "want to die", "ending it"
        ]

        let lowercaseQuery = query.lowercased()
        return crisisKeywords.contains { lowercaseQuery.contains($0) }
    }

    private func generateCrisisResponse(_ query: String) -> WisdomResponse {
        let message = """
        I hear that you're going through something really difficult right now. 💜

        I want you to know that you matter, and what you're feeling is real and valid.

        Please reach out to someone who can truly support you:

        🆘 **Crisis Resources:**
        • US: 988 (Suicide & Crisis Lifeline) - Call or text, 24/7
        • Crisis Text Line: Text HOME to 741741
        • EU/UK: 116 123 (Samaritans)
        • Germany: 0800 111 0 111 (Telefonseelsorge)
        • International: https://www.iasp.info/resources/Crisis_Centres/

        I'm an AI and can't provide the support you deserve right now.
        Real humans are ready to help - please reach out to them.

        If you're in immediate danger, please contact emergency services: 911 (US) / 112 (EU).

        You are not alone. 💙
        """

        return WisdomResponse(
            message: message,
            sources: [],
            confidence: 1.0,
            suggestions: ["Contact a crisis line", "Reach out to a trusted person", "Emergency services if in danger"],
            followUpQuestions: [],
            emotionalTone: .empathetic
        )
    }

    // MARK: - Crisis Support

    public func provideCrisisSupport(_ response: CrisisResponse) {
        logger.warning("🚨 Providing crisis support")
        // Crisis support is handled immediately without delay
    }

    public func provideGentleReminder(_ reminder: String) {
        logger.info("💜 Gentle reminder provided")
        // This would be displayed to the user through the UI
    }

    // MARK: - Helper Methods

    private func calculateConfidence(sources: [WisdomSource]) -> Float {
        if sources.isEmpty { return 0.3 }

        // Higher confidence with more high-quality sources
        let avgQuality = sources.map { source -> Float in
            switch source.evidenceLevel {
            case "Level 1a", "Level 1b": return 1.0
            case "Level 2a", "Level 2b": return 0.8
            case "Level 3": return 0.6
            default: return 0.4
            }
        }.reduce(0, +) / Float(sources.count)

        return min(avgQuality * (1.0 + Float(sources.count) * 0.05), 1.0)
    }

    private func generateSuggestions(intent: QueryIntent) -> [String] {
        switch intent {
        case .technical:
            return ["Try with headphones", "Reference a professional mix", "Take a break and return"]
        case .emotional:
            return ["Practice self-compassion", "Reach out to a peer", "Journal your thoughts"]
        case .healthAdjacent:
            return ["Consult a healthcare professional", "Try evidence-based breathing exercises"]
        default:
            return ["Explore related topics", "Ask follow-up questions"]
        }
    }

    private func loadUserContext() {
        // Load any saved user preferences/context
    }

    private func saveSessionData() {
        // Save session data for continuity
    }

    private func printWelcomeMessage() {
        let welcome = """
        ╔══════════════════════════════════════════════════════╗
        ║  ΞΞΞΞΞ  ЄchoєlWisδom™  ΞΞΞΞΞ                        ║
        ║  Universal Knowledge Terminal v∞.0                   ║
        ║  Status: ◉ Connected to Knowledge Streams            ║
        ╚══════════════════════════════════════════════════════╝

        > Accessing peer-reviewed literature database...
        > Calibrating evidence-based response protocols...
        > Loading trauma-informed communication framework...
        > Ready.

        What wisdom do you seek? 🌌
        """
        logger.info("\(welcome)")
    }
}

// MARK: - Supporting Types

extension EchoelWisdom {

    /// Engine states
    public enum WisdomEngineState: String {
        case inactive = "Inactive"
        case initializing = "Initializing"
        case active = "Active"
        case processingQuery = "Processing Query"
        case crisisDetected = "Crisis Detected"
        case error = "Error"
    }

    /// Knowledge domains
    public enum KnowledgeDomain: String, CaseIterable {
        case neuroscience = "Neuroscience"
        case musicTheory = "Music Theory"
        case psychology = "Psychology"
        case polyvagalTheory = "Polyvagal Theory"
        case circadianScience = "Circadian Science"
        case audioEngineering = "Audio Engineering"
        case musicIndustry = "Music Industry"
        case philosophy = "Philosophy"
        case traumaInformed = "Trauma-Informed Practice"
        case wellness = "Wellness (Evidence-Based)"
    }

    /// Query intent classification
    public enum QueryIntent {
        case technical
        case emotional
        case philosophical
        case healthAdjacent
        case industryCritique
        case general
    }
}

// MARK: - Query Object

public struct WisdomQuery: Identifiable {
    public let id = UUID()
    public let text: String
    public let timestamp: Date
    public let mode: WiseCompleteMode.CoachingMode
    public let context: CoachingContext?
}

// MARK: - Coaching Context

public struct CoachingContext {
    public var recentTopics: [String] = []
    public var emotionalState: EmotionalState = .neutral
    public var sessionDuration: TimeInterval = 0
    public var interactionCount: Int = 0

    public enum EmotionalState {
        case positive
        case neutral
        case negative
        case distressed
    }
}

// MARK: - User Profile

struct UserProfile {
    var preferredMode: WiseCompleteMode.CoachingMode = .socratic
    var knowledgeLevel: KnowledgeLevel = .intermediate
    var topicsOfInterest: [EchoelWisdom.KnowledgeDomain] = []
    var accessibilityNeeds: [AccessibilityNeed] = []

    enum KnowledgeLevel {
        case beginner, intermediate, advanced, expert
    }

    enum AccessibilityNeed {
        case screenReader, reducedMotion, highContrast, simplifiedLanguage
    }
}
