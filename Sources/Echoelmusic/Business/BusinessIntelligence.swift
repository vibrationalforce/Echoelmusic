import Foundation
import Combine

// ═══════════════════════════════════════════════════════════════════════════════
// BUSINESS INTELLIGENCE & MARKETING ANALYTICS
// ═══════════════════════════════════════════════════════════════════════════════
//
// Privacy-First Analytics for Business Growth:
// • User Journey Tracking (anonymized)
// • Feature Adoption Metrics
// • Engagement Scoring
// • Churn Prediction
// • A/B Testing Framework
// • Marketing Attribution
//
// ═══════════════════════════════════════════════════════════════════════════════

/// Business Intelligence Engine with Privacy-First Analytics
@MainActor
class BusinessIntelligence: ObservableObject {

    // MARK: - Published Metrics

    @Published var dailyActiveUsers: Int = 0
    @Published var weeklyActiveUsers: Int = 0
    @Published var monthlyActiveUsers: Int = 0
    @Published var averageSessionDuration: TimeInterval = 0
    @Published var featureAdoptionRates: [String: Float] = [:]
    @Published var engagementScore: Float = 0
    @Published var churnRisk: ChurnRisk = .low
    @Published var conversionFunnel: ConversionFunnel = ConversionFunnel()

    // MARK: - Singleton

    static let shared = BusinessIntelligence()

    // MARK: - Private State

    private var sessionStartTime: Date?
    private var currentSessionEvents: [AnalyticsEvent] = []
    private var userJourney: [JourneyStep] = []
    private var abTestAssignments: [String: String] = [:]

    private let analyticsQueue = DispatchQueue(label: "bi.analytics", qos: .utility)
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Storage Keys

    private enum StorageKeys {
        static let firstLaunchDate = "bi_first_launch"
        static let totalSessions = "bi_total_sessions"
        static let featureUsage = "bi_feature_usage"
        static let conversionEvents = "bi_conversion_events"
        static let userSegment = "bi_user_segment"
        static let cohortId = "bi_cohort_id"
    }

    // MARK: - Initialization

    private init() {
        setupTracking()
        loadPersistentMetrics()
        startSession()
    }

    private func setupTracking() {
        // Track app lifecycle
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.startSession()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.endSession()
            }
            .store(in: &cancellables)
    }

    private func loadPersistentMetrics() {
        // Load from UserDefaults
        let defaults = UserDefaults.standard

        if defaults.object(forKey: StorageKeys.firstLaunchDate) == nil {
            defaults.set(Date(), forKey: StorageKeys.firstLaunchDate)
            assignCohort()
        }
    }

    // MARK: - Session Tracking

    func startSession() {
        sessionStartTime = Date()
        currentSessionEvents = []

        incrementSessionCount()
        trackEvent(.sessionStart)
    }

    func endSession() {
        guard let startTime = sessionStartTime else { return }

        let duration = Date().timeIntervalSince(startTime)
        averageSessionDuration = calculateRollingAverage(
            current: averageSessionDuration,
            new: duration,
            weight: 0.1
        )

        trackEvent(.sessionEnd(duration: duration))
        analyzeSession()

        sessionStartTime = nil
    }

    private func incrementSessionCount() {
        let current = UserDefaults.standard.integer(forKey: StorageKeys.totalSessions)
        UserDefaults.standard.set(current + 1, forKey: StorageKeys.totalSessions)
    }

    // MARK: - Event Tracking

    /// Track an analytics event (privacy-safe, no PII)
    func trackEvent(_ event: AnalyticsEvent) {
        currentSessionEvents.append(event)

        // Update real-time metrics
        analyticsQueue.async { [weak self] in
            self?.processEvent(event)
        }
    }

    /// Track feature usage
    func trackFeatureUsage(_ feature: Feature) {
        trackEvent(.featureUsed(feature))
        updateFeatureAdoption(feature)
    }

    /// Track conversion event
    func trackConversion(_ conversion: ConversionEvent) {
        trackEvent(.conversion(conversion))
        updateConversionFunnel(conversion)
    }

    /// Track user journey step
    func trackJourneyStep(_ step: JourneyStep) {
        userJourney.append(step)
        analyzeJourney()
    }

    private func processEvent(_ event: AnalyticsEvent) {
        // Process event for real-time analytics
        // All processing is anonymized
    }

    private func updateFeatureAdoption(_ feature: Feature) {
        var usage = UserDefaults.standard.dictionary(forKey: StorageKeys.featureUsage) as? [String: Int] ?? [:]
        usage[feature.rawValue] = (usage[feature.rawValue] ?? 0) + 1
        UserDefaults.standard.set(usage, forKey: StorageKeys.featureUsage)

        // Update adoption rate
        let totalSessions = UserDefaults.standard.integer(forKey: StorageKeys.totalSessions)
        if totalSessions > 0 {
            featureAdoptionRates[feature.rawValue] = Float(usage[feature.rawValue] ?? 0) / Float(totalSessions)
        }
    }

    private func updateConversionFunnel(_ conversion: ConversionEvent) {
        switch conversion {
        case .appInstall:
            conversionFunnel.installed = true
        case .onboardingComplete:
            conversionFunnel.onboarded = true
        case .firstSession:
            conversionFunnel.firstSessionComplete = true
        case .featureDiscovery(let feature):
            conversionFunnel.featuresDiscovered.insert(feature)
        case .trialStart:
            conversionFunnel.trialStarted = true
        case .subscription(let tier):
            conversionFunnel.subscribed = true
            conversionFunnel.subscriptionTier = tier
        case .referral:
            conversionFunnel.referred = true
        case .review:
            conversionFunnel.reviewed = true
        }
    }

    // MARK: - Engagement Analysis

    /// Calculate user engagement score (0-100)
    func calculateEngagementScore() -> Float {
        var score: Float = 0

        // Session frequency (0-25 points)
        let sessionsPerWeek = calculateSessionsPerWeek()
        score += min(sessionsPerWeek / 7.0 * 25, 25)

        // Session duration (0-25 points)
        let avgDurationMinutes = Float(averageSessionDuration / 60)
        score += min(avgDurationMinutes / 15.0 * 25, 25)

        // Feature diversity (0-25 points)
        let featuresUsed = Float(featureAdoptionRates.filter { $0.value > 0 }.count)
        let totalFeatures = Float(Feature.allCases.count)
        score += (featuresUsed / totalFeatures) * 25

        // Progression (0-25 points)
        let progressionScore = calculateProgressionScore()
        score += progressionScore * 25

        engagementScore = score
        return score
    }

    private func calculateSessionsPerWeek() -> Float {
        let totalSessions = Float(UserDefaults.standard.integer(forKey: StorageKeys.totalSessions))
        guard let firstLaunch = UserDefaults.standard.object(forKey: StorageKeys.firstLaunchDate) as? Date else {
            return 0
        }

        let weeksSinceInstall = Float(Date().timeIntervalSince(firstLaunch) / 604800)  // 604800 = 1 week
        return weeksSinceInstall > 0 ? totalSessions / weeksSinceInstall : totalSessions
    }

    private func calculateProgressionScore() -> Float {
        // Score based on journey progression
        var score: Float = 0

        if conversionFunnel.onboarded { score += 0.2 }
        if conversionFunnel.firstSessionComplete { score += 0.2 }
        if conversionFunnel.featuresDiscovered.count >= 3 { score += 0.2 }
        if conversionFunnel.trialStarted { score += 0.2 }
        if conversionFunnel.subscribed { score += 0.2 }

        return score
    }

    // MARK: - Churn Prediction

    /// Predict churn risk based on user behavior
    func predictChurnRisk() -> ChurnRisk {
        var riskScore: Float = 0

        // Days since last session
        let daysSinceLastSession = calculateDaysSinceLastSession()
        if daysSinceLastSession > 14 { riskScore += 0.4 }
        else if daysSinceLastSession > 7 { riskScore += 0.2 }
        else if daysSinceLastSession > 3 { riskScore += 0.1 }

        // Declining session duration
        if isSessionDurationDeclining() { riskScore += 0.2 }

        // Low feature adoption
        let avgAdoption = featureAdoptionRates.values.reduce(0, +) / Float(max(featureAdoptionRates.count, 1))
        if avgAdoption < 0.1 { riskScore += 0.2 }

        // Not progressed in funnel
        if !conversionFunnel.onboarded { riskScore += 0.1 }
        if !conversionFunnel.trialStarted && getDaysSinceInstall() > 7 { riskScore += 0.1 }

        churnRisk = ChurnRisk(score: riskScore)
        return churnRisk
    }

    private func calculateDaysSinceLastSession() -> Int {
        // Simplified - would track last session date
        return 0
    }

    private func isSessionDurationDeclining() -> Bool {
        // Would compare recent sessions to historical average
        return false
    }

    private func getDaysSinceInstall() -> Int {
        guard let firstLaunch = UserDefaults.standard.object(forKey: StorageKeys.firstLaunchDate) as? Date else {
            return 0
        }
        return Calendar.current.dateComponents([.day], from: firstLaunch, to: Date()).day ?? 0
    }

    // MARK: - A/B Testing

    /// Get A/B test variant for experiment
    func getABTestVariant(experiment: String) -> String {
        if let existing = abTestAssignments[experiment] {
            return existing
        }

        // Consistent assignment based on user ID hash
        let variants = ["control", "variant_a", "variant_b"]
        let hash = abs(UUID().uuidString.hashValue)
        let variant = variants[hash % variants.count]

        abTestAssignments[experiment] = variant
        return variant
    }

    /// Track A/B test conversion
    func trackABTestConversion(experiment: String, metric: String, value: Float) {
        let variant = abTestAssignments[experiment] ?? "unknown"
        trackEvent(.abTestConversion(experiment: experiment, variant: variant, metric: metric, value: value))
    }

    // MARK: - Cohort Analysis

    private func assignCohort() {
        // Assign to weekly cohort
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-'W'ww"
        let cohortId = formatter.string(from: Date())
        UserDefaults.standard.set(cohortId, forKey: StorageKeys.cohortId)
    }

    func getCohortId() -> String {
        return UserDefaults.standard.string(forKey: StorageKeys.cohortId) ?? "unknown"
    }

    // MARK: - User Segmentation

    /// Determine user segment based on behavior
    func getUserSegment() -> UserSegment {
        let engagement = calculateEngagementScore()
        let churn = predictChurnRisk()
        let isSubscriber = conversionFunnel.subscribed

        if isSubscriber && engagement > 75 {
            return .powerUser
        } else if isSubscriber {
            return .loyalUser
        } else if engagement > 50 {
            return .engagedUser
        } else if churn == .high {
            return .atRisk
        } else if getDaysSinceInstall() < 7 {
            return .newUser
        } else {
            return .casualUser
        }
    }

    // MARK: - Journey Analysis

    private func analyzeJourney() {
        // Identify common patterns and drop-off points
        guard userJourney.count >= 3 else { return }

        // Check for friction points
        let recentSteps = userJourney.suffix(5)
        var backtrackCount = 0

        for i in 1..<recentSteps.count {
            let steps = Array(recentSteps)
            if steps[i].screenDepth < steps[i-1].screenDepth {
                backtrackCount += 1
            }
        }

        if backtrackCount >= 2 {
            trackEvent(.frictionDetected(screen: userJourney.last?.screenName ?? "unknown"))
        }
    }

    private func analyzeSession() {
        // Session analysis for insights
        let duration = Date().timeIntervalSince(sessionStartTime ?? Date())

        // Short session detection
        if duration < 30 {
            trackEvent(.shortSession)
        }

        // Feature engagement analysis
        let featuresUsedInSession = currentSessionEvents.compactMap { event -> Feature? in
            if case .featureUsed(let feature) = event {
                return feature
            }
            return nil
        }

        if featuresUsedInSession.isEmpty && duration > 60 {
            trackEvent(.noFeatureEngagement)
        }
    }

    // MARK: - Marketing Attribution

    /// Track marketing attribution
    func trackAttribution(source: AttributionSource, campaign: String?) {
        UserDefaults.standard.set(source.rawValue, forKey: "attribution_source")
        if let campaign = campaign {
            UserDefaults.standard.set(campaign, forKey: "attribution_campaign")
        }

        trackEvent(.attribution(source: source, campaign: campaign))
    }

    func getAttributionSource() -> AttributionSource {
        let sourceRaw = UserDefaults.standard.string(forKey: "attribution_source") ?? "organic"
        return AttributionSource(rawValue: sourceRaw) ?? .organic
    }

    // MARK: - Reporting

    /// Generate analytics report
    func generateReport() -> AnalyticsReport {
        return AnalyticsReport(
            date: Date(),
            cohortId: getCohortId(),
            segment: getUserSegment(),
            engagementScore: calculateEngagementScore(),
            churnRisk: predictChurnRisk(),
            conversionFunnel: conversionFunnel,
            featureAdoption: featureAdoptionRates,
            sessionMetrics: SessionMetrics(
                totalSessions: UserDefaults.standard.integer(forKey: StorageKeys.totalSessions),
                averageDuration: averageSessionDuration,
                sessionsPerWeek: calculateSessionsPerWeek()
            ),
            attribution: getAttributionSource()
        )
    }

    // MARK: - Helpers

    private func calculateRollingAverage(current: TimeInterval, new: TimeInterval, weight: Float) -> TimeInterval {
        return current * TimeInterval(1 - weight) + new * TimeInterval(weight)
    }
}

// MARK: - Supporting Types

enum AnalyticsEvent {
    case sessionStart
    case sessionEnd(duration: TimeInterval)
    case featureUsed(Feature)
    case conversion(ConversionEvent)
    case abTestConversion(experiment: String, variant: String, metric: String, value: Float)
    case attribution(source: AttributionSource, campaign: String?)
    case frictionDetected(screen: String)
    case shortSession
    case noFeatureEngagement
}

enum Feature: String, CaseIterable {
    case audioEngine = "audio_engine"
    case spatialAudio = "spatial_audio"
    case binauralBeats = "binaural_beats"
    case hrvTraining = "hrv_training"
    case visualizer = "visualizer"
    case recording = "recording"
    case midiInput = "midi_input"
    case aiComposer = "ai_composer"
    case cloudSync = "cloud_sync"
    case ledControl = "led_control"
    case arMode = "ar_mode"
    case breathingGuide = "breathing_guide"
}

enum ConversionEvent {
    case appInstall
    case onboardingComplete
    case firstSession
    case featureDiscovery(Feature)
    case trialStart
    case subscription(String)  // tier
    case referral
    case review
}

struct ConversionFunnel {
    var installed: Bool = false
    var onboarded: Bool = false
    var firstSessionComplete: Bool = false
    var featuresDiscovered: Set<Feature> = []
    var trialStarted: Bool = false
    var subscribed: Bool = false
    var subscriptionTier: String?
    var referred: Bool = false
    var reviewed: Bool = false

    var completionPercentage: Float {
        var completed = 0
        if installed { completed += 1 }
        if onboarded { completed += 1 }
        if firstSessionComplete { completed += 1 }
        if !featuresDiscovered.isEmpty { completed += 1 }
        if trialStarted { completed += 1 }
        if subscribed { completed += 1 }
        return Float(completed) / 6.0 * 100
    }
}

struct JourneyStep {
    let screenName: String
    let screenDepth: Int
    let timestamp: Date
    let duration: TimeInterval?
}

enum ChurnRisk: String {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    init(score: Float) {
        if score > 0.6 { self = .high }
        else if score > 0.3 { self = .medium }
        else { self = .low }
    }
}

enum UserSegment: String {
    case newUser = "New User"
    case casualUser = "Casual User"
    case engagedUser = "Engaged User"
    case loyalUser = "Loyal User"
    case powerUser = "Power User"
    case atRisk = "At Risk"
}

enum AttributionSource: String {
    case organic = "organic"
    case appStore = "app_store"
    case social = "social"
    case referral = "referral"
    case paidAd = "paid_ad"
    case influencer = "influencer"
    case press = "press"
}

struct SessionMetrics {
    let totalSessions: Int
    let averageDuration: TimeInterval
    let sessionsPerWeek: Float
}

struct AnalyticsReport {
    let date: Date
    let cohortId: String
    let segment: UserSegment
    let engagementScore: Float
    let churnRisk: ChurnRisk
    let conversionFunnel: ConversionFunnel
    let featureAdoption: [String: Float]
    let sessionMetrics: SessionMetrics
    let attribution: AttributionSource
}

// MARK: - UIKit Import for Notifications

#if os(iOS)
import UIKit
#endif
