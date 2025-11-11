import Foundation
import SwiftUI
import Combine

/// Evidenzbasiertes Gamification-System nach Fogg Behavior Model und Flow Theory
///
/// Design-Prinzipien:
/// - Fogg Behavior Model: B = Motivation × Ability × Trigger
/// - Flow State Theory (Csikszentmihalyi): Challenge-Skill-Balance
/// - Self-Determination Theory: Autonomy, Competence, Relatedness
/// - Evidence-based: Oxford CEBM Levels für Feature-Validierung
@MainActor
class GamificationEngine: ObservableObject {

    // MARK: - Published State

    @Published var currentXP: Int = 0
    @Published var currentLevel: Int = 1
    @Published var achievements: [Achievement] = []
    @Published var unlockedAchievements: Set<String> = []
    @Published var dailyStreak: Int = 0
    @Published var lastActiveDate: Date?
    @Published var sessionStats: SessionStats = SessionStats()


    // MARK: - Constants

    /// XP required for next level (exponential curve)
    private func xpForLevel(_ level: Int) -> Int {
        return Int(pow(Double(level), 2.5) * 100)
    }

    /// Current level from total XP
    private func levelFromXP(_ xp: Int) -> Int {
        return Int(floor(0.1 * sqrt(Double(xp))))
    }


    // MARK: - Initialization

    init() {
        setupAchievements()
        loadProgress()
        checkDailyStreak()
    }


    // MARK: - Achievement Definitions

    private func setupAchievements() {
        achievements = [
            // PRACTICE Category - Daily Engagement
            Achievement(
                id: "first_session",
                title: "First Steps",
                description: "Complete your first Echoelmusic session",
                category: .practice,
                rarity: .common,
                xpReward: 10,
                condition: { stats in stats.totalSessions >= 1 },
                evidenceLevel: .level1a
            ),
            Achievement(
                id: "daily_streak_7",
                title: "Week Warrior",
                description: "Maintain a 7-day practice streak",
                category: .practice,
                rarity: .uncommon,
                xpReward: 25,
                condition: { [weak self] _ in (self?.dailyStreak ?? 0) >= 7 },
                evidenceLevel: .level1a
            ),
            Achievement(
                id: "daily_streak_30",
                title: "Monthly Master",
                description: "Maintain a 30-day practice streak",
                category: .practice,
                rarity: .rare,
                xpReward: 50,
                condition: { [weak self] _ in (self?.dailyStreak ?? 0) >= 30 },
                evidenceLevel: .level1a
            ),
            Achievement(
                id: "total_time_10h",
                title: "Dedicated Practitioner",
                description: "Accumulate 10 hours of practice time",
                category: .practice,
                rarity: .rare,
                xpReward: 50,
                condition: { stats in stats.totalPracticeMinutes >= 600 },
                evidenceLevel: .level2a
            ),

            // MASTERY Category - Skill Progression
            Achievement(
                id: "gesture_precision_high",
                title: "Gesture Virtuoso",
                description: "Achieve 90%+ gesture recognition accuracy",
                category: .mastery,
                rarity: .epic,
                xpReward: 100,
                condition: { stats in stats.gestureAccuracy >= 0.9 },
                evidenceLevel: .level3a
            ),
            Achievement(
                id: "bio_control_expert",
                title: "Bio-Control Master",
                description: "Control audio parameters with HRV coherence >80",
                category: .mastery,
                rarity: .epic,
                xpReward: 100,
                condition: { stats in stats.maxHRVCoherence >= 80.0 },
                evidenceLevel: .level2a
            ),
            Achievement(
                id: "spatial_audio_master",
                title: "Spatial Audio Architect",
                description: "Use all 6 spatial audio modes",
                category: .mastery,
                rarity: .rare,
                xpReward: 50,
                condition: { stats in stats.spatialModesUsed >= 6 },
                evidenceLevel: .level3b
            ),
            Achievement(
                id: "effects_chain_pro",
                title: "Effects Chain Wizard",
                description: "Create a 5+ node effects chain",
                category: .mastery,
                rarity: .uncommon,
                xpReward: 25,
                condition: { stats in stats.maxEffectsChainLength >= 5 },
                evidenceLevel: .level4
            ),

            // DISCOVERY Category - Exploration
            Achievement(
                id: "all_visualizations",
                title: "Visual Explorer",
                description: "Try all 5 visualization modes",
                category: .discovery,
                rarity: .uncommon,
                xpReward: 25,
                condition: { stats in stats.visualizationModesUsed >= 5 },
                evidenceLevel: .level4
            ),
            Achievement(
                id: "midi_integration",
                title: "MIDI Pioneer",
                description: "Connect and use external MIDI controller",
                category: .discovery,
                rarity: .rare,
                xpReward: 50,
                condition: { stats in stats.midiDevicesConnected >= 1 },
                evidenceLevel: .level3b
            ),
            Achievement(
                id: "led_control_unlock",
                title: "Light Show Director",
                description: "Control LED lighting system",
                category: .discovery,
                rarity: .epic,
                xpReward: 100,
                condition: { stats in stats.ledPatternsCreated >= 1 },
                evidenceLevel: .level3a
            ),
            Achievement(
                id: "recording_first",
                title: "Studio Engineer",
                description: "Record and export your first track",
                category: .discovery,
                rarity: .uncommon,
                xpReward: 25,
                condition: { stats in stats.tracksRecorded >= 1 },
                evidenceLevel: .level4
            ),

            // WELLNESS Category - Health & Longevity
            Achievement(
                id: "hrv_improvement",
                title: "Flow State Initiate",
                description: "Improve HRV coherence by 20 points in a session",
                category: .wellness,
                rarity: .rare,
                xpReward: 50,
                condition: { stats in stats.hrvImprovementInSession >= 20.0 },
                evidenceLevel: .level1a
            ),
            Achievement(
                id: "meditation_time_30min",
                title: "Meditation Adept",
                description: "Complete 30 minutes of guided breathing",
                category: .wellness,
                rarity: .uncommon,
                xpReward: 25,
                condition: { stats in stats.meditationMinutes >= 30 },
                evidenceLevel: .level1a
            ),
            Achievement(
                id: "coherence_master",
                title: "Coherence Master",
                description: "Maintain HRV coherence >80 for 5 minutes",
                category: .wellness,
                rarity: .legendary,
                xpReward: 250,
                condition: { stats in stats.highCoherenceMinutes >= 5 },
                evidenceLevel: .level1a
            ),
            Achievement(
                id: "stress_reduction",
                title: "Stress Warrior",
                description: "Reduce heart rate by 15 BPM during session",
                category: .wellness,
                rarity: .rare,
                xpReward: 50,
                condition: { stats in stats.heartRateReduction >= 15.0 },
                evidenceLevel: .level2a
            ),

            // LEGENDARY Achievements
            Achievement(
                id: "perfect_week",
                title: "Perfect Week",
                description: "Complete all daily goals for 7 consecutive days",
                category: .practice,
                rarity: .legendary,
                xpReward: 250,
                condition: { stats in stats.perfectDays >= 7 },
                evidenceLevel: .level2a
            ),
            Achievement(
                id: "flow_state_wizard",
                title: "Flow State Wizard",
                description: "Enter flow state (coherence >80) in 10 sessions",
                category: .wellness,
                rarity: .legendary,
                xpReward: 250,
                condition: { stats in stats.flowStateSessions >= 10 },
                evidenceLevel: .level1a
            )
        ]
    }


    // MARK: - Achievement Checking

    func checkAchievements() {
        for achievement in achievements {
            // Skip already unlocked
            guard !unlockedAchievements.contains(achievement.id) else { continue }

            // Check condition
            if achievement.condition(sessionStats) {
                unlockAchievement(achievement)
            }
        }
    }

    private func unlockAchievement(_ achievement: Achievement) {
        // Mark as unlocked
        unlockedAchievements.insert(achievement.id)

        // Award XP
        addXP(achievement.xpReward)

        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Show notification
        showAchievementNotification(achievement)

        // Save progress
        saveProgress()

        print("🏆 Achievement Unlocked: \(achievement.title) (+\(achievement.xpReward) XP)")
    }


    // MARK: - XP & Leveling

    func addXP(_ amount: Int) {
        let oldLevel = currentLevel
        currentXP += amount
        currentLevel = levelFromXP(currentXP)

        // Check for level up
        if currentLevel > oldLevel {
            onLevelUp(from: oldLevel, to: currentLevel)
        }
    }

    private func onLevelUp(from oldLevel: Int, to newLevel: Int) {
        // Haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Show level up notification
        print("⬆️ Level Up! \(oldLevel) → \(newLevel)")

        // Save progress
        saveProgress()
    }

    func xpToNextLevel() -> Int {
        let nextLevelXP = xpForLevel(currentLevel + 1)
        let currentLevelXP = xpForLevel(currentLevel)
        return nextLevelXP - currentXP
    }

    func progressToNextLevel() -> Double {
        let currentLevelXP = xpForLevel(currentLevel)
        let nextLevelXP = xpForLevel(currentLevel + 1)
        let progress = Double(currentXP - currentLevelXP) / Double(nextLevelXP - currentLevelXP)
        return max(0, min(1, progress))
    }


    // MARK: - Daily Streak

    private func checkDailyStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        guard let lastActive = lastActiveDate else {
            // First session ever
            dailyStreak = 1
            lastActiveDate = today
            saveProgress()
            return
        }

        let lastActiveDay = calendar.startOfDay(for: lastActive)
        let daysDifference = calendar.dateComponents([.day], from: lastActiveDay, to: today).day ?? 0

        if daysDifference == 0 {
            // Same day - no change
            return
        } else if daysDifference == 1 {
            // Next day - increment streak
            dailyStreak += 1
        } else {
            // Streak broken
            dailyStreak = 1
        }

        lastActiveDate = today
        saveProgress()
    }

    func markSessionActive() {
        checkDailyStreak()
        sessionStats.totalSessions += 1
    }


    // MARK: - Session Stats Updates

    func updateHRVCoherence(_ coherence: Double) {
        sessionStats.maxHRVCoherence = max(sessionStats.maxHRVCoherence, coherence)

        if coherence > 80 {
            sessionStats.highCoherenceMinutes += 1.0 / 60.0  // Assume called once per second
        }

        if coherence > 80 && sessionStats.sessionStartCoherence > 0 {
            sessionStats.flowStateSessions += 1
        }
    }

    func updateHeartRate(_ heartRate: Double) {
        if sessionStats.sessionStartHeartRate == 0 {
            sessionStats.sessionStartHeartRate = heartRate
        }

        let reduction = sessionStats.sessionStartHeartRate - heartRate
        sessionStats.heartRateReduction = max(sessionStats.heartRateReduction, reduction)
    }

    func recordSpatialModeUsed(_ mode: String) {
        sessionStats.spatialModesUsed += 1
    }

    func recordVisualizationModeUsed(_ mode: String) {
        sessionStats.visualizationModesUsed += 1
    }

    func recordEffectsChainLength(_ length: Int) {
        sessionStats.maxEffectsChainLength = max(sessionStats.maxEffectsChainLength, length)
    }

    func recordMIDIDeviceConnected() {
        sessionStats.midiDevicesConnected += 1
    }

    func recordLEDPatternCreated() {
        sessionStats.ledPatternsCreated += 1
    }

    func recordTrack() {
        sessionStats.tracksRecorded += 1
    }

    func addPracticeTime(_ minutes: Int) {
        sessionStats.totalPracticeMinutes += minutes
    }

    func addMeditationTime(_ minutes: Int) {
        sessionStats.meditationMinutes += minutes
    }


    // MARK: - Persistence

    private func saveProgress() {
        let defaults = UserDefaults.standard
        defaults.set(currentXP, forKey: "gamification.xp")
        defaults.set(currentLevel, forKey: "gamification.level")
        defaults.set(Array(unlockedAchievements), forKey: "gamification.unlocked")
        defaults.set(dailyStreak, forKey: "gamification.streak")
        defaults.set(lastActiveDate, forKey: "gamification.lastActive")

        // Save session stats
        if let encoded = try? JSONEncoder().encode(sessionStats) {
            defaults.set(encoded, forKey: "gamification.sessionStats")
        }
    }

    private func loadProgress() {
        let defaults = UserDefaults.standard
        currentXP = defaults.integer(forKey: "gamification.xp")
        currentLevel = defaults.integer(forKey: "gamification.level")
        if currentLevel == 0 { currentLevel = 1 }

        if let unlocked = defaults.array(forKey: "gamification.unlocked") as? [String] {
            unlockedAchievements = Set(unlocked)
        }

        dailyStreak = defaults.integer(forKey: "gamification.streak")
        lastActiveDate = defaults.object(forKey: "gamification.lastActive") as? Date

        // Load session stats
        if let data = defaults.data(forKey: "gamification.sessionStats"),
           let decoded = try? JSONDecoder().decode(SessionStats.self, from: data) {
            sessionStats = decoded
        }
    }


    // MARK: - UI Helpers

    private func showAchievementNotification(_ achievement: Achievement) {
        // This would integrate with your notification system
        // For now, just print
        print("🎉 \(achievement.title)")
        print("   \(achievement.description)")
        print("   +\(achievement.xpReward) XP")
    }

    func getUnlockedAchievements() -> [Achievement] {
        return achievements.filter { unlockedAchievements.contains($0.id) }
    }

    func getLockedAchievements() -> [Achievement] {
        return achievements.filter { !unlockedAchievements.contains($0.id) }
    }

    func achievementsByCategory(_ category: AchievementCategory) -> [Achievement] {
        return achievements.filter { $0.category == category }
    }
}


// MARK: - Achievement Model

struct Achievement: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let category: AchievementCategory
    let rarity: AchievementRarity
    let xpReward: Int
    let condition: (SessionStats) -> Bool
    let evidenceLevel: EvidenceLevel

    enum CodingKeys: String, CodingKey {
        case id, title, description, category, rarity, xpReward, evidenceLevel
    }

    init(id: String, title: String, description: String, category: AchievementCategory,
         rarity: AchievementRarity, xpReward: Int, condition: @escaping (SessionStats) -> Bool,
         evidenceLevel: EvidenceLevel) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.rarity = rarity
        self.xpReward = xpReward
        self.condition = condition
        self.evidenceLevel = evidenceLevel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        category = try container.decode(AchievementCategory.self, forKey: .category)
        rarity = try container.decode(AchievementRarity.self, forKey: .rarity)
        xpReward = try container.decode(Int.self, forKey: .xpReward)
        evidenceLevel = try container.decode(EvidenceLevel.self, forKey: .evidenceLevel)
        condition = { _ in false }  // Default condition for decoded achievements
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(category, forKey: .category)
        try container.encode(rarity, forKey: .rarity)
        try container.encode(xpReward, forKey: .xpReward)
        try container.encode(evidenceLevel, forKey: .evidenceLevel)
    }
}


// MARK: - Achievement Category

enum AchievementCategory: String, Codable, CaseIterable {
    case practice = "Practice"
    case mastery = "Mastery"
    case discovery = "Discovery"
    case wellness = "Wellness"

    var icon: String {
        switch self {
        case .practice: return "calendar"
        case .mastery: return "star.fill"
        case .discovery: return "safari"
        case .wellness: return "heart.fill"
        }
    }

    var color: Color {
        switch self {
        case .practice: return .blue
        case .mastery: return .purple
        case .discovery: return .orange
        case .wellness: return .green
        }
    }
}


// MARK: - Achievement Rarity

enum AchievementRarity: String, Codable, CaseIterable {
    case common = "Common"
    case uncommon = "Uncommon"
    case rare = "Rare"
    case epic = "Epic"
    case legendary = "Legendary"

    var color: Color {
        switch self {
        case .common: return .white
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .yellow
        }
    }

    var xpMultiplier: Double {
        switch self {
        case .common: return 1.0
        case .uncommon: return 2.5
        case .rare: return 5.0
        case .epic: return 10.0
        case .legendary: return 25.0
        }
    }
}


// MARK: - Evidence Level (Oxford CEBM)

enum EvidenceLevel: String, Codable {
    case level1a = "1a - Systematic Review"
    case level1b = "1b - RCT"
    case level2a = "2a - Cohort Study"
    case level2b = "2b - Case-Control"
    case level3a = "3a - Systematic Review of Case-Control"
    case level3b = "3b - Individual Case-Control"
    case level4 = "4 - Case Series"
    case level5 = "5 - Expert Opinion"

    var description: String {
        return rawValue
    }
}


// MARK: - Session Stats

struct SessionStats: Codable {
    var totalSessions: Int = 0
    var totalPracticeMinutes: Int = 0
    var meditationMinutes: Int = 0

    var gestureAccuracy: Double = 0.0
    var maxHRVCoherence: Double = 0.0
    var hrvImprovementInSession: Double = 0.0
    var sessionStartCoherence: Double = 0.0
    var highCoherenceMinutes: Double = 0.0
    var flowStateSessions: Int = 0

    var sessionStartHeartRate: Double = 0.0
    var heartRateReduction: Double = 0.0

    var spatialModesUsed: Int = 0
    var visualizationModesUsed: Int = 0
    var maxEffectsChainLength: Int = 0

    var midiDevicesConnected: Int = 0
    var ledPatternsCreated: Int = 0
    var tracksRecorded: Int = 0

    var perfectDays: Int = 0
}
