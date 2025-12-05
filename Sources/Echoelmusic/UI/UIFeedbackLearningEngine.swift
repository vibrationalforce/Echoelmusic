import Foundation
import Combine
import SwiftUI
import CoreML
import os.log

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// ═══════════════════════════════════════════════════════════════════════════════
// ECHOELMUSIC UI FEEDBACK LEARNING ENGINE
// ═══════════════════════════════════════════════════════════════════════════════
//
// "Quantum Wonder Ultra Deep Think Sink Mode"
//
// Self-Learning UI/UX System that evolves from:
// • User Interaction Patterns
// • Implicit Feedback (hesitation, corrections, abandonment)
// • Explicit Feedback (ratings, reports, preferences)
// • A/B Testing Results
// • Performance Metrics
// • Accessibility Usage
// • Cross-Session Learning
// • Collective Intelligence (anonymized patterns)
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - UI Feedback Learning Engine

@MainActor
public final class UIFeedbackLearningEngine: ObservableObject {

    // MARK: - Singleton

    public static let shared = UIFeedbackLearningEngine()

    // MARK: - Published State

    @Published public var learningState: LearningState = .idle
    @Published public var userProfile: UserBehaviorProfile = UserBehaviorProfile()
    @Published public var activeExperiments: [ABExperiment] = []
    @Published public var learnedOptimizations: [LearnedOptimization] = []
    @Published public var feedbackScore: Float = 0.5
    @Published public var adaptationLevel: AdaptationLevel = .moderate

    // MARK: - Private State

    private let logger = Logger(subsystem: "com.echoelmusic", category: "UIFeedbackLearning")
    private var cancellables = Set<AnyCancellable>()

    // Interaction tracking
    private var interactionHistory: [UIInteraction] = []
    private var sessionStartTime = Date()
    private var touchHeatmap: [[Float]] = []
    private var scrollPatterns: [ScrollPattern] = []
    private var gestureSuccessRates: [String: Float] = [:]

    // Learning models
    private var behaviorPredictor: BehaviorPredictor?
    private var frustrationDetector: FrustrationDetector?
    private var preferenceInferrer: PreferenceInferrer?
    private var usabilityAnalyzer: UsabilityAnalyzer?

    // Persistence
    private let userDefaultsKey = "UIFeedbackLearningData"
    private var lastPersistTime = Date()

    // MARK: - Initialization

    private init() {
        setupLearningModels()
        loadPersistedData()
        startInteractionTracking()
        logger.info("🧠 UI Feedback Learning Engine activated - Quantum Wonder Mode")
    }

    // MARK: - Setup

    private func setupLearningModels() {
        behaviorPredictor = BehaviorPredictor()
        frustrationDetector = FrustrationDetector()
        preferenceInferrer = PreferenceInferrer()
        usabilityAnalyzer = UsabilityAnalyzer()
    }

    private func loadPersistedData() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let profile = try? JSONDecoder().decode(UserBehaviorProfile.self, from: data) {
            userProfile = profile
            logger.info("📊 Loaded user behavior profile with \(profile.totalInteractions) interactions")
        }
    }

    private func persistData() {
        guard Date().timeIntervalSince(lastPersistTime) > 60 else { return }  // Max once per minute

        if let data = try? JSONEncoder().encode(userProfile) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            lastPersistTime = Date()
        }
    }

    private func startInteractionTracking() {
        // 10 Hz interaction analysis
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.analyzeRecentInteractions()
            }
            .store(in: &cancellables)

        // 1 Hz deep learning cycle
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.deepLearningCycle()
            }
            .store(in: &cancellables)

        // 5 minute persistence cycle
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.persistData()
            }
            .store(in: &cancellables)
    }

    // MARK: - Interaction Recording

    /// Record a user interaction for learning
    public func recordInteraction(_ interaction: UIInteraction) {
        interactionHistory.append(interaction)
        userProfile.totalInteractions += 1

        // Keep recent history
        if interactionHistory.count > 10000 {
            interactionHistory.removeFirst(5000)
        }

        // Update heatmap for touch interactions
        if case .touch(let point, _) = interaction.type {
            updateTouchHeatmap(point: point)
        }

        // Track gesture success
        if case .gesture(let name, let success) = interaction.type {
            updateGestureSuccessRate(gesture: name, success: success)
        }

        // Detect frustration signals
        detectFrustrationSignals(interaction)
    }

    /// Record explicit user feedback
    public func recordFeedback(_ feedback: ExplicitFeedback) {
        userProfile.explicitFeedback.append(feedback)

        // Immediate learning from explicit feedback
        applyExplicitFeedback(feedback)

        logger.info("📝 Explicit feedback recorded: \(feedback.type.rawValue) - \(feedback.rating)/5")
    }

    /// Record a usability issue
    public func reportUsabilityIssue(_ issue: UsabilityIssue) {
        userProfile.reportedIssues.append(issue)

        // Prioritize learning from reported issues
        usabilityAnalyzer?.analyzeIssue(issue)

        logger.warning("⚠️ Usability issue reported: \(issue.description)")

        // Generate immediate fix suggestion
        generateFixSuggestion(for: issue)
    }

    // MARK: - Implicit Feedback Detection

    private func detectFrustrationSignals(_ interaction: UIInteraction) {
        guard let detector = frustrationDetector else { return }

        let frustrationScore = detector.analyze(
            interaction: interaction,
            history: interactionHistory
        )

        if frustrationScore > 0.7 {
            // High frustration detected
            let signal = FrustrationSignal(
                score: frustrationScore,
                interaction: interaction,
                timestamp: Date(),
                context: getCurrentContext()
            )

            userProfile.frustrationSignals.append(signal)
            logger.warning("😤 Frustration detected (score: \(String(format: "%.2f", frustrationScore)))")

            // Trigger adaptive response
            triggerAdaptiveResponse(for: signal)
        }
    }

    private func updateTouchHeatmap(point: CGPoint) {
        // Normalize to 100x100 grid
        let gridX = min(99, max(0, Int(point.x / 10)))
        let gridY = min(99, max(0, Int(point.y / 10)))

        // Ensure heatmap is initialized
        if touchHeatmap.isEmpty {
            touchHeatmap = Array(repeating: Array(repeating: 0, count: 100), count: 100)
        }

        touchHeatmap[gridY][gridX] += 1
    }

    private func updateGestureSuccessRate(gesture: String, success: Bool) {
        let currentRate = gestureSuccessRates[gesture] ?? 0.5
        let newRate = currentRate * 0.95 + (success ? 0.05 : 0)
        gestureSuccessRates[gesture] = newRate

        // Flag problematic gestures
        if newRate < 0.7 {
            logger.warning("⚠️ Gesture '\(gesture)' has low success rate: \(String(format: "%.0f", newRate * 100))%")
        }
    }

    // MARK: - Learning Cycles

    private func analyzeRecentInteractions() {
        guard !interactionHistory.isEmpty else { return }

        let recentInteractions = interactionHistory.suffix(50)

        // Analyze interaction patterns
        let patterns = analyzePatterns(Array(recentInteractions))

        // Update user profile
        updateUserProfile(with: patterns)

        // Check for A/B experiment data
        recordExperimentData(from: Array(recentInteractions))
    }

    private func deepLearningCycle() {
        learningState = .learning

        // 1. Behavior prediction update
        behaviorPredictor?.train(on: interactionHistory)

        // 2. Preference inference
        let inferredPreferences = preferenceInferrer?.infer(from: userProfile)
        if let prefs = inferredPreferences {
            applyInferredPreferences(prefs)
        }

        // 3. Usability analysis
        let usabilityScore = usabilityAnalyzer?.calculateScore(
            interactions: interactionHistory,
            issues: userProfile.reportedIssues
        ) ?? 0.5

        userProfile.usabilityScore = usabilityScore

        // 4. Generate optimizations
        generateOptimizations()

        // 5. Update feedback score
        calculateFeedbackScore()

        learningState = .idle
    }

    // MARK: - Pattern Analysis

    private func analyzePatterns(_ interactions: [UIInteraction]) -> InteractionPatterns {
        var patterns = InteractionPatterns()

        // Time between interactions
        var intervals: [TimeInterval] = []
        for i in 1..<interactions.count {
            intervals.append(interactions[i].timestamp.timeIntervalSince(interactions[i-1].timestamp))
        }
        patterns.averageInteractionInterval = intervals.isEmpty ? 0 : intervals.reduce(0, +) / Double(intervals.count)

        // Hesitation detection (long pauses before action)
        patterns.hesitationCount = intervals.filter { $0 > 2.0 && $0 < 10.0 }.count

        // Rapid repeated actions (frustration signal)
        patterns.rapidRepeatCount = countRapidRepeats(interactions)

        // Navigation depth
        patterns.maxNavigationDepth = calculateNavigationDepth(interactions)

        // Feature usage distribution
        patterns.featureUsage = calculateFeatureUsage(interactions)

        return patterns
    }

    private func countRapidRepeats(_ interactions: [UIInteraction]) -> Int {
        var count = 0
        var lastInteraction: UIInteraction?

        for interaction in interactions {
            if let last = lastInteraction,
               interaction.timestamp.timeIntervalSince(last.timestamp) < 0.5,
               interaction.componentId == last.componentId {
                count += 1
            }
            lastInteraction = interaction
        }

        return count
    }

    private func calculateNavigationDepth(_ interactions: [UIInteraction]) -> Int {
        var depth = 0
        var maxDepth = 0

        for interaction in interactions {
            if case .navigation(let direction) = interaction.type {
                if direction == .forward || direction == .push {
                    depth += 1
                    maxDepth = max(maxDepth, depth)
                } else if direction == .back || direction == .pop {
                    depth = max(0, depth - 1)
                }
            }
        }

        return maxDepth
    }

    private func calculateFeatureUsage(_ interactions: [UIInteraction]) -> [String: Int] {
        var usage: [String: Int] = [:]

        for interaction in interactions {
            let feature = interaction.componentId ?? "unknown"
            usage[feature, default: 0] += 1
        }

        return usage
    }

    // MARK: - User Profile Updates

    private func updateUserProfile(with patterns: InteractionPatterns) {
        // Update skill level based on interaction speed and accuracy
        let skillIndicator = 1.0 / max(patterns.averageInteractionInterval, 0.1)
        userProfile.skillLevel = userProfile.skillLevel * 0.95 + Float(skillIndicator) * 0.05

        // Update preferred interaction speed
        userProfile.preferredSpeed = InteractionSpeed(from: patterns.averageInteractionInterval)

        // Track feature preferences
        for (feature, count) in patterns.featureUsage {
            userProfile.featurePreferences[feature, default: 0] += count
        }

        // Detect accessibility needs
        if patterns.hesitationCount > 5 || gestureSuccessRates.values.contains(where: { $0 < 0.6 }) {
            userProfile.mayNeedAccessibilitySupport = true
        }
    }

    // MARK: - Optimization Generation

    private func generateOptimizations() {
        var newOptimizations: [LearnedOptimization] = []

        // 1. Layout optimizations based on touch heatmap
        if let layoutOpt = generateLayoutOptimization() {
            newOptimizations.append(layoutOpt)
        }

        // 2. Gesture optimizations based on success rates
        for (gesture, rate) in gestureSuccessRates where rate < 0.8 {
            newOptimizations.append(LearnedOptimization(
                type: .gestureSimplification,
                target: gesture,
                confidence: 1.0 - rate,
                suggestion: "Simplify or replace \(gesture) gesture",
                autoApplicable: false
            ))
        }

        // 3. Speed optimizations based on user skill
        if userProfile.skillLevel > 0.8 {
            newOptimizations.append(LearnedOptimization(
                type: .speedIncrease,
                target: "animations",
                confidence: userProfile.skillLevel,
                suggestion: "Reduce animation duration for expert user",
                autoApplicable: true
            ))
        }

        // 4. Accessibility optimizations
        if userProfile.mayNeedAccessibilitySupport {
            newOptimizations.append(LearnedOptimization(
                type: .accessibilityEnhancement,
                target: "global",
                confidence: 0.8,
                suggestion: "Enable accessibility optimizations",
                autoApplicable: true
            ))
        }

        // Apply auto-applicable optimizations
        for opt in newOptimizations where opt.autoApplicable && opt.confidence > 0.7 {
            applyOptimization(opt)
        }

        learnedOptimizations = newOptimizations
    }

    private func generateLayoutOptimization() -> LearnedOptimization? {
        guard !touchHeatmap.isEmpty else { return nil }

        // Find hot zones
        var maxHeat: Float = 0
        var hotZone: (x: Int, y: Int) = (50, 50)

        for y in 0..<100 {
            for x in 0..<100 {
                if touchHeatmap[y][x] > maxHeat {
                    maxHeat = touchHeatmap[y][x]
                    hotZone = (x, y)
                }
            }
        }

        // Suggest moving important controls to hot zone
        if maxHeat > 100 {
            return LearnedOptimization(
                type: .layoutAdjustment,
                target: "primary_controls",
                confidence: min(maxHeat / 200, 1.0),
                suggestion: "Move primary controls closer to position (\(hotZone.x * 10), \(hotZone.y * 10))",
                autoApplicable: false,
                metadata: ["hotX": hotZone.x, "hotY": hotZone.y]
            )
        }

        return nil
    }

    private func applyOptimization(_ optimization: LearnedOptimization) {
        switch optimization.type {
        case .speedIncrease:
            NotificationCenter.default.post(
                name: .uiSpeedOptimization,
                object: UISpeedConfig(multiplier: 0.7)
            )
            logger.info("⚡ Applied speed optimization")

        case .accessibilityEnhancement:
            NotificationCenter.default.post(
                name: .uiAccessibilityOptimization,
                object: nil
            )
            logger.info("♿ Applied accessibility optimization")

        default:
            break
        }
    }

    // MARK: - A/B Testing

    public func startExperiment(_ experiment: ABExperiment) {
        activeExperiments.append(experiment)
        logger.info("🧪 Started A/B experiment: \(experiment.name)")
    }

    public func recordExperimentResult(_ experimentId: String, variant: String, success: Bool) {
        guard let index = activeExperiments.firstIndex(where: { $0.id == experimentId }) else { return }

        var experiment = activeExperiments[index]
        experiment.recordResult(variant: variant, success: success)
        activeExperiments[index] = experiment

        // Check if experiment is conclusive
        if experiment.isConclusive {
            concludeExperiment(experiment)
        }
    }

    private func recordExperimentData(from interactions: [UIInteraction]) {
        for experiment in activeExperiments where !experiment.isConclusive {
            let relevantInteractions = interactions.filter { $0.experimentId == experiment.id }

            for interaction in relevantInteractions {
                if case .experimentAction(let variant, let success) = interaction.type {
                    recordExperimentResult(experiment.id, variant: variant, success: success)
                }
            }
        }
    }

    private func concludeExperiment(_ experiment: ABExperiment) {
        guard let winner = experiment.getWinner() else { return }

        logger.info("🏆 Experiment '\(experiment.name)' concluded. Winner: \(winner)")

        // Apply winning variant
        NotificationCenter.default.post(
            name: .uiExperimentConcluded,
            object: ExperimentResult(experiment: experiment, winner: winner)
        )

        // Remove from active experiments
        activeExperiments.removeAll { $0.id == experiment.id }
    }

    // MARK: - Explicit Feedback Handling

    private func applyExplicitFeedback(_ feedback: ExplicitFeedback) {
        switch feedback.type {
        case .featureRating:
            if feedback.rating < 3 {
                // Low rating - flag for improvement
                logger.warning("⭐ Low rating for feature: \(feedback.target ?? "unknown")")
            } else if feedback.rating >= 4 {
                // High rating - reinforce this pattern
                if let target = feedback.target {
                    userProfile.featurePreferences[target, default: 0] += 10
                }
            }

        case .usabilityReport:
            // Immediate attention needed
            if let details = feedback.details {
                reportUsabilityIssue(UsabilityIssue(
                    type: .userReported,
                    description: details,
                    severity: feedback.rating < 2 ? .critical : .moderate,
                    component: feedback.target
                ))
            }

        case .suggestion:
            // Log suggestion for review
            logger.info("💡 User suggestion: \(feedback.details ?? "")")

        case .accessibility:
            userProfile.mayNeedAccessibilitySupport = true
            applyOptimization(LearnedOptimization(
                type: .accessibilityEnhancement,
                target: "global",
                confidence: 1.0,
                suggestion: "User requested accessibility support",
                autoApplicable: true
            ))
        }
    }

    // MARK: - Adaptive Response

    private func triggerAdaptiveResponse(for signal: FrustrationSignal) {
        switch adaptationLevel {
        case .none:
            return

        case .subtle:
            // Subtle hints only
            NotificationCenter.default.post(name: .uiSubtleHint, object: signal)

        case .moderate:
            // Show help tooltip
            NotificationCenter.default.post(name: .uiShowHelp, object: signal)

        case .aggressive:
            // Simplify UI temporarily
            NotificationCenter.default.post(name: .uiSimplifyMode, object: signal)

        case .full:
            // Full assistance mode
            NotificationCenter.default.post(name: .uiAssistanceMode, object: signal)
        }
    }

    private func generateFixSuggestion(for issue: UsabilityIssue) {
        let suggestion = usabilityAnalyzer?.generateFix(for: issue)

        if let fix = suggestion {
            learnedOptimizations.append(LearnedOptimization(
                type: .usabilityFix,
                target: issue.component ?? "global",
                confidence: 0.9,
                suggestion: fix,
                autoApplicable: false
            ))
        }
    }

    // MARK: - Scoring

    private func calculateFeedbackScore() {
        var score: Float = 0.5

        // Usability score contribution (40%)
        score += userProfile.usabilityScore * 0.4

        // Frustration inverse contribution (30%)
        let recentFrustrations = userProfile.frustrationSignals.filter {
            $0.timestamp > Date().addingTimeInterval(-3600)
        }.count
        let frustrationScore = max(0, 1.0 - Float(recentFrustrations) / 10.0)
        score += frustrationScore * 0.3

        // Explicit feedback contribution (30%)
        let recentFeedback = userProfile.explicitFeedback.suffix(20)
        if !recentFeedback.isEmpty {
            let avgRating = Float(recentFeedback.map { $0.rating }.reduce(0, +)) / Float(recentFeedback.count) / 5.0
            score += avgRating * 0.3
        } else {
            score += 0.15  // Neutral if no feedback
        }

        feedbackScore = min(max(score, 0), 1)
    }

    // MARK: - Context

    private func getCurrentContext() -> InteractionContext {
        return InteractionContext(
            screenName: getCurrentScreenName(),
            sessionDuration: Date().timeIntervalSince(sessionStartTime),
            recentActions: interactionHistory.suffix(10).map { $0.type.description },
            deviceOrientation: getDeviceOrientation(),
            networkStatus: getNetworkStatus()
        )
    }

    private func getCurrentScreenName() -> String {
        // Get from navigation controller or scene
        return "Main"  // Placeholder
    }

    private func getDeviceOrientation() -> String {
        #if os(iOS)
        switch UIDevice.current.orientation {
        case .portrait: return "portrait"
        case .landscapeLeft, .landscapeRight: return "landscape"
        default: return "unknown"
        }
        #else
        return "desktop"
        #endif
    }

    private func getNetworkStatus() -> String {
        return "connected"  // Placeholder - integrate with Reachability
    }

    // MARK: - Preferences Inference

    private func applyInferredPreferences(_ preferences: InferredPreferences) {
        // Apply color scheme preference
        if let scheme = preferences.preferredColorScheme {
            userProfile.colorSchemePreference = scheme
        }

        // Apply layout density preference
        if let density = preferences.preferredDensity {
            userProfile.layoutDensityPreference = density
        }

        // Apply animation preference
        userProfile.prefersReducedMotion = preferences.prefersReducedMotion
    }

    // MARK: - Public API

    /// Get recommended UI configuration based on learning
    public func getRecommendedConfig() -> UIConfiguration {
        return UIConfiguration(
            animationSpeed: userProfile.skillLevel > 0.7 ? .fast : .normal,
            layoutDensity: userProfile.layoutDensityPreference,
            colorScheme: userProfile.colorSchemePreference,
            accessibilityMode: userProfile.mayNeedAccessibilitySupport,
            showHints: userProfile.skillLevel < 0.3,
            simplifiedMode: userProfile.frustrationSignals.count > 10
        )
    }

    /// Predict next likely user action
    public func predictNextAction() -> PredictedAction? {
        return behaviorPredictor?.predict(
            history: interactionHistory,
            profile: userProfile
        )
    }

    /// Get improvement suggestions for a component
    public func getImprovementSuggestions(for componentId: String) -> [String] {
        return learnedOptimizations
            .filter { $0.target == componentId }
            .map { $0.suggestion }
    }
}

// MARK: - Data Types

public enum LearningState {
    case idle
    case learning
    case applying
}

public enum AdaptationLevel: String, CaseIterable {
    case none = "None"
    case subtle = "Subtle"
    case moderate = "Moderate"
    case aggressive = "Aggressive"
    case full = "Full"
}

public struct UserBehaviorProfile: Codable {
    public var totalInteractions: Int = 0
    public var skillLevel: Float = 0.5
    public var preferredSpeed: InteractionSpeed = .normal
    public var usabilityScore: Float = 0.5
    public var featurePreferences: [String: Int] = [:]
    public var mayNeedAccessibilitySupport: Bool = false
    public var colorSchemePreference: ColorSchemePreference = .system
    public var layoutDensityPreference: LayoutDensity = .normal
    public var prefersReducedMotion: Bool = false

    public var explicitFeedback: [ExplicitFeedback] = []
    public var frustrationSignals: [FrustrationSignal] = []
    public var reportedIssues: [UsabilityIssue] = []
}

public enum InteractionSpeed: String, Codable {
    case slow
    case normal
    case fast
    case expert

    init(from interval: TimeInterval) {
        if interval < 0.3 { self = .expert }
        else if interval < 0.6 { self = .fast }
        else if interval < 1.5 { self = .normal }
        else { self = .slow }
    }
}

public enum ColorSchemePreference: String, Codable {
    case light
    case dark
    case system
}

public enum LayoutDensity: String, Codable {
    case compact
    case normal
    case comfortable
}

public struct UIInteraction {
    public let id = UUID()
    public let type: InteractionType
    public let componentId: String?
    public let timestamp: Date
    public let duration: TimeInterval?
    public let experimentId: String?

    public init(type: InteractionType, componentId: String? = nil, duration: TimeInterval? = nil, experimentId: String? = nil) {
        self.type = type
        self.componentId = componentId
        self.timestamp = Date()
        self.duration = duration
        self.experimentId = experimentId
    }
}

public enum InteractionType {
    case touch(point: CGPoint, pressure: Float)
    case gesture(name: String, success: Bool)
    case tap(componentId: String)
    case longPress(componentId: String, duration: TimeInterval)
    case scroll(direction: ScrollDirection, velocity: Float)
    case navigation(direction: NavigationDirection)
    case input(field: String, characterCount: Int)
    case experimentAction(variant: String, success: Bool)
    case featureUse(name: String)
    case error(message: String)
    case cancellation(action: String)

    var description: String {
        switch self {
        case .touch: return "touch"
        case .gesture(let name, _): return "gesture:\(name)"
        case .tap(let id): return "tap:\(id)"
        case .longPress(let id, _): return "longPress:\(id)"
        case .scroll(let dir, _): return "scroll:\(dir)"
        case .navigation(let dir): return "nav:\(dir)"
        case .input(let field, _): return "input:\(field)"
        case .experimentAction(let variant, _): return "experiment:\(variant)"
        case .featureUse(let name): return "feature:\(name)"
        case .error(let msg): return "error:\(msg)"
        case .cancellation(let action): return "cancel:\(action)"
        }
    }
}

public enum ScrollDirection {
    case up, down, left, right
}

public enum NavigationDirection {
    case forward, back, push, pop, tab
}

public struct InteractionPatterns {
    public var averageInteractionInterval: TimeInterval = 0
    public var hesitationCount: Int = 0
    public var rapidRepeatCount: Int = 0
    public var maxNavigationDepth: Int = 0
    public var featureUsage: [String: Int] = [:]
}

public struct ExplicitFeedback: Codable {
    public let id = UUID()
    public let type: FeedbackType
    public let rating: Int  // 1-5
    public let target: String?
    public let details: String?
    public let timestamp: Date

    public init(type: FeedbackType, rating: Int, target: String? = nil, details: String? = nil) {
        self.type = type
        self.rating = rating
        self.target = target
        self.details = details
        self.timestamp = Date()
    }

    public enum FeedbackType: String, Codable {
        case featureRating
        case usabilityReport
        case suggestion
        case accessibility
    }
}

public struct FrustrationSignal: Codable {
    public let id = UUID()
    public let score: Float
    public let interactionDescription: String
    public let timestamp: Date
    public let contextDescription: String

    init(score: Float, interaction: UIInteraction, timestamp: Date, context: InteractionContext) {
        self.score = score
        self.interactionDescription = interaction.type.description
        self.timestamp = timestamp
        self.contextDescription = context.screenName
    }
}

public struct UsabilityIssue: Codable {
    public let id = UUID()
    public let type: IssueType
    public let description: String
    public let severity: Severity
    public let component: String?
    public let timestamp: Date

    public init(type: IssueType, description: String, severity: Severity, component: String? = nil) {
        self.type = type
        self.description = description
        self.severity = severity
        self.component = component
        self.timestamp = Date()
    }

    public enum IssueType: String, Codable {
        case userReported
        case autoDetected
        case crashRelated
        case performanceRelated
        case accessibilityRelated
    }

    public enum Severity: String, Codable {
        case minor
        case moderate
        case major
        case critical
    }
}

public struct InteractionContext {
    public let screenName: String
    public let sessionDuration: TimeInterval
    public let recentActions: [String]
    public let deviceOrientation: String
    public let networkStatus: String
}

public struct LearnedOptimization {
    public let id = UUID()
    public let type: OptimizationType
    public let target: String
    public let confidence: Float
    public let suggestion: String
    public let autoApplicable: Bool
    public var metadata: [String: Any]?

    public enum OptimizationType {
        case layoutAdjustment
        case gestureSimplification
        case speedIncrease
        case accessibilityEnhancement
        case usabilityFix
        case colorAdjustment
        case navigationSimplification
    }
}

public struct ScrollPattern {
    public let direction: ScrollDirection
    public let velocity: Float
    public let distance: Float
    public let duration: TimeInterval
}

public struct ABExperiment: Identifiable {
    public let id: String
    public let name: String
    public let variants: [String]
    public var results: [String: ExperimentResults] = [:]
    public let requiredSampleSize: Int

    public var isConclusive: Bool {
        let totalSamples = results.values.map { $0.total }.reduce(0, +)
        return totalSamples >= requiredSampleSize
    }

    public mutating func recordResult(variant: String, success: Bool) {
        if results[variant] == nil {
            results[variant] = ExperimentResults()
        }
        results[variant]?.record(success: success)
    }

    public func getWinner() -> String? {
        guard isConclusive else { return nil }

        return results.max(by: { $0.value.successRate < $1.value.successRate })?.key
    }
}

public struct ExperimentResults {
    public var successes: Int = 0
    public var total: Int = 0

    public var successRate: Float {
        guard total > 0 else { return 0 }
        return Float(successes) / Float(total)
    }

    public mutating func record(success: Bool) {
        total += 1
        if success { successes += 1 }
    }
}

public struct ExperimentResult {
    public let experiment: ABExperiment
    public let winner: String
}

public struct UIConfiguration {
    public var animationSpeed: AnimationSpeed
    public var layoutDensity: LayoutDensity
    public var colorScheme: ColorSchemePreference
    public var accessibilityMode: Bool
    public var showHints: Bool
    public var simplifiedMode: Bool

    public enum AnimationSpeed {
        case slow, normal, fast, instant
    }
}

public struct InferredPreferences {
    public var preferredColorScheme: ColorSchemePreference?
    public var preferredDensity: LayoutDensity?
    public var prefersReducedMotion: Bool = false
}

public struct PredictedAction {
    public let action: String
    public let confidence: Float
    public let suggestedPreload: String?
}

public struct UISpeedConfig {
    public let multiplier: Float
}

// MARK: - Learning Models

class BehaviorPredictor {
    private var patterns: [String: Int] = [:]

    func train(on interactions: [UIInteraction]) {
        // Build n-gram model of interaction sequences
        for i in 0..<(interactions.count - 1) {
            let current = interactions[i].type.description
            let next = interactions[i + 1].type.description
            let key = "\(current)->\(next)"
            patterns[key, default: 0] += 1
        }
    }

    func predict(history: [UIInteraction], profile: UserBehaviorProfile) -> PredictedAction? {
        guard let last = history.last else { return nil }

        let lastAction = last.type.description
        var bestNext: String?
        var bestCount = 0

        for (pattern, count) in patterns {
            if pattern.hasPrefix(lastAction + "->") && count > bestCount {
                bestCount = count
                bestNext = String(pattern.dropFirst(lastAction.count + 2))
            }
        }

        guard let next = bestNext else { return nil }

        return PredictedAction(
            action: next,
            confidence: Float(bestCount) / Float(patterns.values.reduce(0, +)),
            suggestedPreload: next.contains("nav") ? next : nil
        )
    }
}

class FrustrationDetector {
    func analyze(interaction: UIInteraction, history: [UIInteraction]) -> Float {
        var score: Float = 0

        // Check for rapid repeated actions
        let recentSame = history.suffix(5).filter { $0.componentId == interaction.componentId }
        if recentSame.count > 3 {
            score += 0.3
        }

        // Check for error interactions
        if case .error = interaction.type {
            score += 0.4
        }

        // Check for cancellations
        if case .cancellation = interaction.type {
            score += 0.2
        }

        // Check for erratic scrolling
        let recentScrolls = history.suffix(10).compactMap { interaction -> ScrollDirection? in
            if case .scroll(let dir, _) = interaction.type { return dir }
            return nil
        }
        if recentScrolls.count > 5 {
            let directions = Set(recentScrolls.map { "\($0)" })
            if directions.count > 2 {
                score += 0.3  // Scrolling in multiple directions = lost
            }
        }

        return min(score, 1.0)
    }
}

class PreferenceInferrer {
    func infer(from profile: UserBehaviorProfile) -> InferredPreferences {
        var prefs = InferredPreferences()

        // Infer color scheme from usage time (placeholder - would need actual time tracking)
        prefs.preferredColorScheme = .system

        // Infer density from skill level
        if profile.skillLevel > 0.7 {
            prefs.preferredDensity = .compact
        } else if profile.skillLevel < 0.3 {
            prefs.preferredDensity = .comfortable
        }

        // Infer motion preference from interaction patterns
        prefs.prefersReducedMotion = profile.mayNeedAccessibilitySupport

        return prefs
    }
}

class UsabilityAnalyzer {
    func calculateScore(interactions: [UIInteraction], issues: [UsabilityIssue]) -> Float {
        var score: Float = 1.0

        // Deduct for issues
        for issue in issues {
            switch issue.severity {
            case .minor: score -= 0.05
            case .moderate: score -= 0.1
            case .major: score -= 0.2
            case .critical: score -= 0.3
            }
        }

        // Deduct for error interactions
        let errors = interactions.filter {
            if case .error = $0.type { return true }
            return false
        }
        score -= Float(errors.count) * 0.02

        return max(0, score)
    }

    func analyzeIssue(_ issue: UsabilityIssue) {
        // Deep analysis of issue
    }

    func generateFix(for issue: UsabilityIssue) -> String? {
        switch issue.type {
        case .accessibilityRelated:
            return "Add accessibility labels and increase touch targets"
        case .performanceRelated:
            return "Optimize rendering and reduce animation complexity"
        case .userReported:
            return "Review user feedback and consider UX redesign"
        default:
            return "Investigate and address reported issue"
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    public static let uiSpeedOptimization = Notification.Name("uiSpeedOptimization")
    public static let uiAccessibilityOptimization = Notification.Name("uiAccessibilityOptimization")
    public static let uiExperimentConcluded = Notification.Name("uiExperimentConcluded")
    public static let uiSubtleHint = Notification.Name("uiSubtleHint")
    public static let uiShowHelp = Notification.Name("uiShowHelp")
    public static let uiSimplifyMode = Notification.Name("uiSimplifyMode")
    public static let uiAssistanceMode = Notification.Name("uiAssistanceMode")
}
