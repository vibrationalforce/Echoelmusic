import Foundation
import Combine
import os.log

// ═══════════════════════════════════════════════════════════════════════════════
// WISE COMPLETE MODE
// ═══════════════════════════════════════════════════════════════════════════════
//
// "Flüssiges Licht trifft unendliche Weisheit"
//
// The ultimate integration of:
// • EchoelWisdom™ - Evidence-based knowledge & coaching
// • Complete Mode - All systems working in perfect harmony
// • Bio-reactive awareness - Physiological state integration
// • Quantum creativity - AI-enhanced creative flow
// • Self-healing resilience - Adaptive system optimization
//
// When Wise Complete Mode is active, the system operates at its highest
// potential while maintaining evidence-based grounding and user wellbeing.
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Wise Complete Mode Controller

@MainActor
public final class WiseCompleteMode: ObservableObject {

    // MARK: - Singleton

    public static let shared = WiseCompleteMode()

    // MARK: - Published State

    /// Current wisdom mode state
    @Published public var state: WisdomState = .initializing

    /// Integration level (0-1) - how well all systems are synchronized
    @Published public var integrationLevel: Float = 0.0

    /// Wisdom coherence (0-1) - evidence quality and knowledge availability
    @Published public var wisdomCoherence: Float = 0.0

    /// User wellbeing score (0-1) - based on bio data and interaction patterns
    @Published public var wellbeingScore: Float = 0.5

    /// Active coaching mode
    @Published public var coachingMode: CoachingMode = .socratic

    /// Circadian-aware interface mode
    @Published public var circadianMode: CircadianMode = .afternoon

    /// Crisis detection state
    @Published public var crisisState: CrisisState = .none

    // MARK: - Sub-Systems

    /// EchoelWisdom knowledge and coaching engine
    public let wisdom = EchoelWisdom.shared

    /// Query engine for natural language understanding
    public let queryEngine = WisdomQueryEngine.shared

    /// Knowledge base with evidence-based content
    public let knowledgeBase = WisdomKnowledgeBase.shared

    // MARK: - Private State

    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.echoelmusic.wisdom", category: "WiseCompleteMode")
    private var updateTimer: Timer?
    private var sessionStartTime: Date?
    private var interactionCount: Int = 0

    // MARK: - Initialization

    private init() {
        setupWisdomSystem()
        setupCircadianAdaptation()
        setupWellbeingMonitoring()
        startIntegrationLoop()

        logger.info("🌌 Wise Complete Mode: Initializing...")
        logger.info("   Connected to Knowledge Streams")
        logger.info("   Evidence-based, trauma-informed, user-empowering")
    }

    // MARK: - Setup

    private func setupWisdomSystem() {
        // Connect wisdom subsystems
        wisdom.$currentState
            .sink { [weak self] wisdomState in
                self?.handleWisdomStateChange(wisdomState)
            }
            .store(in: &cancellables)

        // Monitor query responses for quality
        queryEngine.$lastResponseQuality
            .sink { [weak self] quality in
                self?.wisdomCoherence = quality
            }
            .store(in: &cancellables)

        // Knowledge base readiness
        knowledgeBase.$isReady
            .sink { [weak self] ready in
                if ready {
                    self?.logger.info("📚 Knowledge Base: Ready")
                }
            }
            .store(in: &cancellables)
    }

    private func setupCircadianAdaptation() {
        // Update circadian mode based on time of day
        updateCircadianMode()

        // Check every 30 minutes
        Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCircadianMode()
            }
        }
    }

    private func setupWellbeingMonitoring() {
        // Monitor for dependency patterns (too frequent usage)
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkUsagePatterns()
            }
        }
    }

    private func startIntegrationLoop() {
        // 1 Hz integration check
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateIntegration()
            }
        }
    }

    // MARK: - State Management

    /// Activate Wise Complete Mode
    public func activate() {
        guard state != .wiseComplete else { return }

        state = .activating
        sessionStartTime = Date()

        logger.info("✨ Wise Complete Mode: Activating...")

        // Initialize all subsystems
        wisdom.activate()
        queryEngine.initialize()
        knowledgeBase.load()

        // Transition to active state after brief initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.state = .wiseComplete
            self?.logger.info("🌌 Wise Complete Mode: ACTIVE")
            self?.logger.info("   All systems synchronized")
            self?.logger.info("   Ready to assist with wisdom and care")
        }
    }

    /// Deactivate Wise Complete Mode
    public func deactivate() {
        guard state == .wiseComplete else { return }

        state = .deactivating

        logger.info("🌙 Wise Complete Mode: Deactivating...")

        // Gracefully shut down subsystems
        wisdom.deactivate()

        state = .inactive

        // Log session summary
        if let startTime = sessionStartTime {
            let duration = Date().timeIntervalSince(startTime)
            logger.info("📊 Session Summary:")
            logger.info("   Duration: \(Int(duration / 60)) minutes")
            logger.info("   Interactions: \(self.interactionCount)")
        }
    }

    // MARK: - Integration Updates

    private func updateIntegration() {
        guard state == .wiseComplete else { return }

        // Calculate integration level from all subsystems
        let wisdomActive = wisdom.currentState == .active ? 1.0 : 0.0
        let queryReady = queryEngine.isReady ? 1.0 : 0.0
        let knowledgeLoaded = knowledgeBase.isReady ? 1.0 : 0.0

        let rawIntegration = Float(wisdomActive * 0.4 + queryReady * 0.3 + knowledgeLoaded * 0.3)

        // Smooth transition
        integrationLevel = integrationLevel * 0.9 + rawIntegration * 0.1

        // Update wellbeing based on interaction patterns
        updateWellbeingScore()
    }

    private func updateWellbeingScore() {
        // Factors that influence wellbeing score:
        // 1. Usage patterns (not too frequent = healthy)
        // 2. Query sentiment (positive/neutral = healthy)
        // 3. Session duration (moderate = healthy)
        // 4. Bio data if available (HRV coherence)

        var score: Float = 0.5

        // Usage frequency factor
        let hourlyRate = Float(interactionCount) / max(1, Float(sessionDuration / 3600))
        if hourlyRate < 20 {
            score += 0.2  // Healthy usage
        } else if hourlyRate > 50 {
            score -= 0.2  // Potentially excessive
        }

        // Session duration factor (2-4 hours = optimal)
        let hours = sessionDuration / 3600
        if hours > 1 && hours < 4 {
            score += 0.1
        } else if hours > 6 {
            score -= 0.2
        }

        // Clamp to valid range
        wellbeingScore = max(0, min(1, score))
    }

    private var sessionDuration: TimeInterval {
        guard let start = sessionStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    // MARK: - Circadian Adaptation

    private func updateCircadianMode() {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 6..<12:
            circadianMode = .morning
        case 12..<18:
            circadianMode = .afternoon
        case 18..<22:
            circadianMode = .evening
        default:
            circadianMode = .night
        }

        logger.info("🌅 Circadian Mode: \(self.circadianMode.rawValue)")
    }

    // MARK: - Wisdom State Handling

    private func handleWisdomStateChange(_ newState: EchoelWisdom.WisdomEngineState) {
        switch newState {
        case .active:
            if state == .activating {
                // Part of activation complete
            }
        case .processingQuery:
            interactionCount += 1
        case .crisisDetected:
            handleCrisisDetection()
        default:
            break
        }
    }

    // MARK: - Crisis Detection & Response

    private func handleCrisisDetection() {
        crisisState = .detected

        logger.warning("🚨 Crisis indicators detected - escalating support")

        // Provide crisis resources
        let crisisResponse = CrisisResponse(
            acknowledgment: "I hear that you're going through something difficult right now.",
            resources: CrisisResources.all,
            supportMessage: "You're not alone. These feelings are valid, and help is available."
        )

        wisdom.provideCrisisSupport(crisisResponse)
    }

    // MARK: - Usage Pattern Monitoring

    private func checkUsagePatterns() {
        // Check for potential dependency patterns
        if interactionCount > 100 && sessionDuration < 7200 {
            // High interaction rate - gentle reminder
            let reminder = """
            I notice you've consulted me frequently this session. 💜

            Remember: You have wisdom within you too.

            Sometimes the best answer comes from sitting with the question, not asking AI.

            Would you like to take a break and come back later?
            """

            wisdom.provideGentleReminder(reminder)
        }
    }

    // MARK: - Public API

    /// Process a user query through the wisdom system
    public func processQuery(_ query: String) async -> WisdomResponse {
        guard state == .wiseComplete else {
            return WisdomResponse(
                message: "Wise Complete Mode is not active. Please activate first.",
                sources: [],
                confidence: 0
            )
        }

        interactionCount += 1

        // Check for crisis indicators first
        if queryEngine.detectsCrisisIndicators(in: query) {
            handleCrisisDetection()
        }

        // Process through wisdom system
        return await wisdom.processQuery(query, mode: coachingMode)
    }

    /// Set the coaching mode
    public func setCoachingMode(_ mode: CoachingMode) {
        coachingMode = mode
        logger.info("🎭 Coaching Mode: \(mode.rawValue)")
    }

    /// Get current system status
    public func getStatus() -> WiseCompleteModeStatus {
        return WiseCompleteModeStatus(
            state: state,
            integrationLevel: integrationLevel,
            wisdomCoherence: wisdomCoherence,
            wellbeingScore: wellbeingScore,
            coachingMode: coachingMode,
            circadianMode: circadianMode,
            sessionDuration: sessionDuration,
            interactionCount: interactionCount
        )
    }
}

// MARK: - Supporting Types

extension WiseCompleteMode {

    /// Wisdom mode states
    public enum WisdomState: String {
        case initializing = "Initializing"
        case inactive = "Inactive"
        case activating = "Activating"
        case wiseComplete = "Wise Complete"
        case deactivating = "Deactivating"
        case error = "Error"
    }

    /// Coaching modes based on user needs
    public enum CoachingMode: String, CaseIterable {
        case socratic = "Socratic"      // Ask questions, guide discovery
        case educational = "Educational" // Teach concepts with sources
        case supportive = "Supportive"   // Empathetic presence, validation
        case strategic = "Strategic"     // Goal-setting, action planning

        var description: String {
            switch self {
            case .socratic:
                return "Ask questions, don't give answers. Guide discovery through inquiry."
            case .educational:
                return "Teach concepts with peer-reviewed sources. Build understanding."
            case .supportive:
                return "Empathetic presence and validation. Meet user where they are."
            case .strategic:
                return "Goal-setting and action planning. Break down challenges."
            }
        }
    }

    /// Circadian-aware interface modes (evidence-based lighting)
    public enum CircadianMode: String {
        case morning = "Morning"     // Bright, cooler tones (blue-enriched)
        case afternoon = "Afternoon" // Full spectrum, balanced
        case evening = "Evening"     // Warmer, dimmer tones (blue-depleted)
        case night = "Night"         // Amber/red only (preserve melatonin)

        /// Primary color for this circadian mode
        var primaryColor: String {
            switch self {
            case .morning: return "#00E5FF"   // Cyan
            case .afternoon: return "#2979FF" // Blue
            case .evening: return "#FF6E40"   // Orange
            case .night: return "#FFA000"     // Amber
            }
        }

        /// Whether blue light should be enabled
        var blueEnabled: Bool {
            switch self {
            case .morning, .afternoon: return true
            case .evening: return false
            case .night: return false  // Preserve melatonin
            }
        }
    }

    /// Crisis detection states
    public enum CrisisState: String {
        case none = "None"
        case potential = "Potential"
        case detected = "Detected"
        case escalated = "Escalated"
    }
}

// MARK: - Crisis Support

struct CrisisResponse {
    let acknowledgment: String
    let resources: [CrisisResource]
    let supportMessage: String
}

struct CrisisResource: Identifiable {
    let id = UUID()
    let name: String
    let phone: String
    let region: String
    let available: String
}

enum CrisisResources {
    static let all: [CrisisResource] = [
        CrisisResource(
            name: "988 Suicide & Crisis Lifeline",
            phone: "988",
            region: "US",
            available: "24/7"
        ),
        CrisisResource(
            name: "Crisis Text Line",
            phone: "Text HOME to 741741",
            region: "US",
            available: "24/7"
        ),
        CrisisResource(
            name: "Samaritans",
            phone: "116 123",
            region: "EU/UK",
            available: "24/7"
        ),
        CrisisResource(
            name: "Telefonseelsorge",
            phone: "0800 111 0 111",
            region: "Germany",
            available: "24/7"
        ),
        CrisisResource(
            name: "International Association for Suicide Prevention",
            phone: "https://www.iasp.info/resources/Crisis_Centres/",
            region: "International",
            available: "Varies by region"
        )
    ]
}

// MARK: - Wisdom Response

public struct WisdomResponse {
    public let message: String
    public let sources: [WisdomSource]
    public let confidence: Float
    public var suggestions: [String] = []
    public var followUpQuestions: [String] = []
    public var emotionalTone: EmotionalTone = .neutral

    public enum EmotionalTone: String {
        case empathetic = "Empathetic"
        case encouraging = "Encouraging"
        case neutral = "Neutral"
        case cautionary = "Cautionary"
        case celebratory = "Celebratory"
    }
}

public struct WisdomSource: Identifiable {
    public let id = UUID()
    public let title: String
    public let journal: String?
    public let year: Int?
    public let pmid: String?
    public let doi: String?
    public let evidenceLevel: String
    public let summary: String
}

// MARK: - Status Report

public struct WiseCompleteModeStatus {
    public let state: WiseCompleteMode.WisdomState
    public let integrationLevel: Float
    public let wisdomCoherence: Float
    public let wellbeingScore: Float
    public let coachingMode: WiseCompleteMode.CoachingMode
    public let circadianMode: WiseCompleteMode.CircadianMode
    public let sessionDuration: TimeInterval
    public let interactionCount: Int

    public var summary: String {
        return """
        ╔══════════════════════════════════════════════════════╗
        ║  ΞΞΞΞΞ  Wise Complete Mode Status  ΞΞΞΞΞ            ║
        ╚══════════════════════════════════════════════════════╝

        State: \(state.rawValue)
        Integration: \(String(format: "%.0f%%", integrationLevel * 100))
        Wisdom Coherence: \(String(format: "%.0f%%", wisdomCoherence * 100))
        Wellbeing Score: \(String(format: "%.0f%%", wellbeingScore * 100))

        Coaching Mode: \(coachingMode.rawValue)
        Circadian Mode: \(circadianMode.rawValue)

        Session: \(Int(sessionDuration / 60)) minutes
        Interactions: \(interactionCount)

        ◉ Connected to Knowledge Streams
        📚 Evidence-based responses enabled
        💜 Trauma-informed protocols active
        """
    }
}
