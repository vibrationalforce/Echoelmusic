import Foundation
import SwiftUI
import Combine

/// Gamification System
/// Motivates and engages users through achievements, progress tracking, and challenges
///
/// Features:
/// - Achievements & Badges
/// - Experience Points (XP) & Levels
/// - Daily/Weekly Challenges
/// - Streak Tracking
/// - Leaderboards (optional, privacy-respecting)
/// - Rewards & Unlockables
/// - Progress Visualization

// MARK: - Achievement

public struct Achievement: Identifiable, Codable {
    public let id: String
    public let name: String
    public let description: String
    public let icon: String // SF Symbol name
    public let category: AchievementCategory
    public let xpReward: Int
    public let difficulty: Difficulty
    public var progress: Int
    public let totalRequired: Int
    public var isUnlocked: Bool
    public var unlockedDate: Date?

    public var progressPercentage: Double {
        return min(1.0, Double(progress) / Double(totalRequired))
    }

    public init(
        id: String,
        name: String,
        description: String,
        icon: String,
        category: AchievementCategory,
        xpReward: Int,
        difficulty: Difficulty,
        totalRequired: Int = 1
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.category = category
        self.xpReward = xpReward
        self.difficulty = difficulty
        self.progress = 0
        self.totalRequired = totalRequired
        self.isUnlocked = false
        self.unlockedDate = nil
    }
}

public enum AchievementCategory: String, Codable, CaseIterable {
    case exploration = "Exploration"
    case creation = "Creation"
    case wellness = "Wellness"
    case social = "Social"
    case mastery = "Mastery"
    case special = "Special"
}

public enum Difficulty: String, Codable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    case epic = "Epic"

    var color: Color {
        switch self {
        case .easy: return .green
        case .medium: return .orange
        case .hard: return .red
        case .epic: return .purple
        }
    }
}

// MARK: - Challenge

public struct Challenge: Identifiable, Codable {
    public let id: String
    public let name: String
    public let description: String
    public let type: ChallengeType
    public let xpReward: Int
    public let startDate: Date
    public let endDate: Date
    public var progress: Int
    public let goal: Int
    public var isCompleted: Bool

    public var isActive: Bool {
        let now = Date()
        return now >= startDate && now <= endDate && !isCompleted
    }

    public var progressPercentage: Double {
        return min(1.0, Double(progress) / Double(goal))
    }

    public var timeRemaining: String {
        let remaining = endDate.timeIntervalSince(Date())
        if remaining <= 0 { return "Expired" }

        let hours = Int(remaining / 3600)
        if hours > 24 {
            let days = hours / 24
            return "\(days) day\(days != 1 ? "s" : "") left"
        } else {
            return "\(hours) hour\(hours != 1 ? "s" : "") left"
        }
    }
}

public enum ChallengeType: String, Codable {
    case daily = "Daily"
    case weekly = "Weekly"
    case special = "Special"
}

// MARK: - User Progress

public struct UserProgress: Codable {
    public var level: Int
    public var xp: Int
    public var totalSessions: Int
    public var totalMinutesPlayed: Int
    public var currentStreak: Int
    public var longestStreak: Int
    public var lastSessionDate: Date?
    public var achievements: [Achievement]
    public var challenges: [Challenge]

    public init() {
        self.level = 1
        self.xp = 0
        self.totalSessions = 0
        self.totalMinutesPlayed = 0
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastSessionDate = nil
        self.achievements = []
        self.challenges = []
    }

    public var xpForNextLevel: Int {
        return level * 100 // Simple formula: 100 XP per level
    }

    public var progressToNextLevel: Double {
        let xpNeeded = xpForNextLevel
        let xpInCurrentLevel = xp % xpNeeded
        return Double(xpInCurrentLevel) / Double(xpNeeded)
    }

    public var unlockedAchievements: [Achievement] {
        return achievements.filter { $0.isUnlocked }
    }

    public var activeChallenges: [Challenge] {
        return challenges.filter { $0.isActive }
    }
}

// MARK: - Gamification Manager

@MainActor
public final class GamificationManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = GamificationManager()

    // MARK: - Published Properties

    @Published public private(set) var userProgress: UserProgress
    @Published public var showAchievementPopup: Bool = false
    @Published public var recentlyUnlockedAchievement: Achievement?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // All available achievements
    private let allAchievements: [Achievement] = [
        // Exploration
        Achievement(
            id: "first_session",
            name: "First Steps",
            description: "Complete your first session",
            icon: "play.circle.fill",
            category: .exploration,
            xpReward: 50,
            difficulty: .easy
        ),
        Achievement(
            id: "explore_all_modes",
            name: "Visual Explorer",
            description: "Try all 5 visualization modes",
            icon: "eye.fill",
            category: .exploration,
            xpReward: 200,
            difficulty: .medium,
            totalRequired: 5
        ),
        Achievement(
            id: "spatial_audio_master",
            name: "Spatial Audio Master",
            description: "Try all 6 spatial audio modes",
            icon: "sparkles",
            category: .exploration,
            xpReward: 300,
            difficulty: .medium,
            totalRequired: 6
        ),

        // Creation
        Achievement(
            id: "first_export",
            name: "Creator",
            description: "Export your first video",
            icon: "square.and.arrow.up.fill",
            category: .creation,
            xpReward: 100,
            difficulty: .easy
        ),
        Achievement(
            id: "prolific_creator",
            name: "Prolific Creator",
            description: "Export 50 videos",
            icon: "film.fill",
            category: .creation,
            xpReward: 1000,
            difficulty: .hard,
            totalRequired: 50
        ),
        Achievement(
            id: "custom_preset",
            name: "Sound Designer",
            description: "Create and save a custom preset",
            icon: "waveform.circle.fill",
            category: .creation,
            xpReward: 150,
            difficulty: .medium
        ),

        // Wellness
        Achievement(
            id: "coherence_master",
            name: "Coherence Master",
            description: "Achieve 90+ coherence",
            icon: "heart.circle.fill",
            category: .wellness,
            xpReward: 200,
            difficulty: .medium
        ),
        Achievement(
            id: "meditation_streak_7",
            name: "Week of Zen",
            description: "7-day practice streak",
            icon: "leaf.fill",
            category: .wellness,
            xpReward: 500,
            difficulty: .hard
        ),
        Achievement(
            id: "meditation_streak_30",
            name: "Month of Mindfulness",
            description: "30-day practice streak",
            icon: "sun.max.fill",
            category: .wellness,
            xpReward: 2000,
            difficulty: .epic
        ),
        Achievement(
            id: "total_hours_10",
            name: "Committed Practitioner",
            description: "Practice for 10 total hours",
            icon: "clock.fill",
            category: .wellness,
            xpReward: 800,
            difficulty: .hard,
            totalRequired: 600 // minutes
        ),

        // Social
        Achievement(
            id: "first_jam",
            name: "Jam Session",
            description: "Complete your first multiplayer jam",
            icon: "person.2.fill",
            category: .social,
            xpReward: 300,
            difficulty: .medium
        ),
        Achievement(
            id: "share_creation",
            name: "Sharer",
            description: "Share a creation with others",
            icon: "square.and.arrow.up.fill",
            category: .social,
            xpReward: 100,
            difficulty: .easy
        ),

        // Mastery
        Achievement(
            id: "all_achievements",
            name: "Completionist",
            description: "Unlock all achievements",
            icon: "star.fill",
            category: .mastery,
            xpReward: 5000,
            difficulty: .epic
        ),
        Achievement(
            id: "level_10",
            name: "Adept",
            description: "Reach level 10",
            icon: "10.circle.fill",
            category: .mastery,
            xpReward: 1000,
            difficulty: .hard
        ),
        Achievement(
            id: "level_25",
            name: "Expert",
            description: "Reach level 25",
            icon: "25.circle.fill",
            category: .mastery,
            xpReward: 2500,
            difficulty: .epic
        ),

        // Special
        Achievement(
            id: "early_adopter",
            name: "Early Adopter",
            description: "Joined during beta period",
            icon: "gift.fill",
            category: .special,
            xpReward: 1000,
            difficulty: .epic
        ),
        Achievement(
            id: "4k_export",
            name: "4K Creator",
            description: "Export a 4K video",
            icon: "4k.tv.fill",
            category: .special,
            xpReward: 300,
            difficulty: .medium
        ),
    ]

    // MARK: - Initialization

    private init() {
        // Load saved progress
        if let savedProgress = Self.loadProgress() {
            userProgress = savedProgress
        } else {
            userProgress = UserProgress()
            userProgress.achievements = allAchievements
        }

        print("🎮 Gamification Manager initialized")
        print("   Level: \(userProgress.level)")
        print("   XP: \(userProgress.xp)")
        print("   Achievements: \(userProgress.unlockedAchievements.count)/\(allAchievements.count)")
        print("   Current Streak: \(userProgress.currentStreak) days")
    }

    // MARK: - Progress Management

    private func saveProgress() {
        if let encoded = try? JSONEncoder().encode(userProgress) {
            UserDefaults.standard.set(encoded, forKey: "UserProgress")
        }
    }

    private static func loadProgress() -> UserProgress? {
        guard let data = UserDefaults.standard.data(forKey: "UserProgress"),
              let progress = try? JSONDecoder().decode(UserProgress.self, from: data) else {
            return nil
        }
        return progress
    }

    // MARK: - Session Tracking

    public func startSession() {
        userProgress.totalSessions += 1
        updateStreak()
        saveProgress()

        print("🎮 Session started (Total: \(userProgress.totalSessions))")

        // Check achievement
        checkAchievement(id: "first_session")
    }

    public func endSession(durationMinutes: Int) {
        userProgress.totalMinutesPlayed += durationMinutes
        addXP(durationMinutes * 5) // 5 XP per minute
        saveProgress()

        // Check time-based achievements
        checkAchievement(id: "total_hours_10", progress: userProgress.totalMinutesPlayed)

        print("🎮 Session ended (+\(durationMinutes * 5) XP)")
    }

    private func updateStreak() {
        let now = Date()
        let calendar = Calendar.current

        if let lastSession = userProgress.lastSessionDate {
            let daysSince = calendar.dateComponents([.day], from: lastSession, to: now).day ?? 0

            if daysSince == 1 {
                // Consecutive day
                userProgress.currentStreak += 1
                print("🔥 Streak: \(userProgress.currentStreak) days")
            } else if daysSince > 1 {
                // Streak broken
                print("💔 Streak broken")
                userProgress.currentStreak = 1
            }
            // If same day, don't change streak
        } else {
            // First session
            userProgress.currentStreak = 1
        }

        // Update longest streak
        if userProgress.currentStreak > userProgress.longestStreak {
            userProgress.longestStreak = userProgress.currentStreak
        }

        // Check streak achievements
        checkAchievement(id: "meditation_streak_7", progress: userProgress.currentStreak)
        checkAchievement(id: "meditation_streak_30", progress: userProgress.currentStreak)

        userProgress.lastSessionDate = now
    }

    // MARK: - XP & Leveling

    public func addXP(_ amount: Int) {
        userProgress.xp += amount

        // Check for level up
        while userProgress.xp >= userProgress.xpForNextLevel {
            levelUp()
        }

        saveProgress()
    }

    private func levelUp() {
        userProgress.level += 1
        print("🎉 Level Up! Now level \(userProgress.level)")

        // Trigger celebration
        NotificationCenter.default.post(
            name: .levelUp,
            object: userProgress.level
        )

        // Check level achievements
        if userProgress.level == 10 {
            checkAchievement(id: "level_10")
        } else if userProgress.level == 25 {
            checkAchievement(id: "level_25")
        }

        AccessibilityManager.shared.triggerHaptic(type: .success)
        AccessibilityManager.shared.announce("Level up! You are now level \(userProgress.level)")
    }

    // MARK: - Achievement System

    public func checkAchievement(id: String, progress: Int? = nil) {
        guard let index = userProgress.achievements.firstIndex(where: { $0.id == id }) else {
            return
        }

        var achievement = userProgress.achievements[index]

        if achievement.isUnlocked {
            return // Already unlocked
        }

        // Update progress
        if let newProgress = progress {
            achievement.progress = newProgress
        } else {
            achievement.progress += 1
        }

        // Check if unlocked
        if achievement.progress >= achievement.totalRequired {
            unlockAchievement(id: id)
        } else {
            userProgress.achievements[index] = achievement
            saveProgress()
        }
    }

    private func unlockAchievement(id: String) {
        guard let index = userProgress.achievements.firstIndex(where: { $0.id == id }) else {
            return
        }

        var achievement = userProgress.achievements[index]
        achievement.isUnlocked = true
        achievement.unlockedDate = Date()

        userProgress.achievements[index] = achievement

        // Award XP
        addXP(achievement.xpReward)

        // Show popup
        recentlyUnlockedAchievement = achievement
        showAchievementPopup = true

        saveProgress()

        print("🏆 Achievement Unlocked: \(achievement.name) (+\(achievement.xpReward) XP)")

        // Haptic & sound
        AccessibilityManager.shared.triggerHaptic(type: .success)
        AccessibilityManager.shared.announce("Achievement unlocked: \(achievement.name)")

        // Notify
        NotificationCenter.default.post(
            name: .achievementUnlocked,
            object: achievement
        )

        // Check if all achievements unlocked
        if userProgress.unlockedAchievements.count == allAchievements.count {
            checkAchievement(id: "all_achievements")
        }
    }

    // MARK: - Event Tracking

    public func trackEvent(_ event: GameEvent) {
        switch event {
        case .visualizationModeChanged:
            checkAchievement(id: "explore_all_modes")

        case .spatialAudioModeChanged:
            checkAchievement(id: "spatial_audio_master")

        case .videoExported:
            checkAchievement(id: "first_export")
            checkAchievement(id: "prolific_creator")

        case .presetSaved:
            checkAchievement(id: "custom_preset")

        case .highCoherence(let value):
            if value >= 90 {
                checkAchievement(id: "coherence_master")
            }

        case .multiplayerJamCompleted:
            checkAchievement(id: "first_jam")

        case .creationShared:
            checkAchievement(id: "share_creation")

        case .export4K:
            checkAchievement(id: "4k_export")
        }
    }

    public enum GameEvent {
        case visualizationModeChanged
        case spatialAudioModeChanged
        case videoExported
        case presetSaved
        case highCoherence(Float)
        case multiplayerJamCompleted
        case creationShared
        case export4K
    }

    // MARK: - Challenges

    public func generateDailyChallenge() -> Challenge {
        let challenges = [
            Challenge(
                id: UUID().uuidString,
                name: "Daily Practice",
                description: "Complete a 10-minute session",
                type: .daily,
                xpReward: 100,
                startDate: Date(),
                endDate: Date().addingTimeInterval(86400), // 24 hours
                progress: 0,
                goal: 10,
                isCompleted: false
            ),
            Challenge(
                id: UUID().uuidString,
                name: "Explore Mode",
                description: "Try a new visualization mode",
                type: .daily,
                xpReward: 75,
                startDate: Date(),
                endDate: Date().addingTimeInterval(86400),
                progress: 0,
                goal: 1,
                isCompleted: false
            ),
            Challenge(
                id: UUID().uuidString,
                name: "Coherence Quest",
                description: "Achieve 80+ coherence",
                type: .daily,
                xpReward: 150,
                startDate: Date(),
                endDate: Date().addingTimeInterval(86400),
                progress: 0,
                goal: 80,
                isCompleted: false
            ),
        ]

        return challenges.randomElement()!
    }

    public func completeChallenge(id: String) {
        guard let index = userProgress.challenges.firstIndex(where: { $0.id == id }) else {
            return
        }

        var challenge = userProgress.challenges[index]
        challenge.isCompleted = true
        userProgress.challenges[index] = challenge

        // Award XP
        addXP(challenge.xpReward)

        saveProgress()

        print("✅ Challenge Completed: \(challenge.name) (+\(challenge.xpReward) XP)")
    }

    // MARK: - Statistics

    public func getStatistics() -> [String: Any] {
        return [
            "level": userProgress.level,
            "xp": userProgress.xp,
            "totalSessions": userProgress.totalSessions,
            "totalHours": userProgress.totalMinutesPlayed / 60,
            "currentStreak": userProgress.currentStreak,
            "longestStreak": userProgress.longestStreak,
            "achievementsUnlocked": userProgress.unlockedAchievements.count,
            "totalAchievements": allAchievements.count,
            "achievementPercentage": Int((Double(userProgress.unlockedAchievements.count) / Double(allAchievements.count)) * 100)
        ]
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let levelUp = Notification.Name("LevelUp")
    static let achievementUnlocked = Notification.Name("AchievementUnlocked")
}

// MARK: - SwiftUI Views

/// Achievement popup overlay
public struct AchievementPopupView: View {
    let achievement: Achievement
    @Binding var isShowing: Bool

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: achievement.icon)
                .font(.system(size: 60))
                .foregroundColor(.yellow)

            Text("Achievement Unlocked!")
                .font(.headline)

            Text(achievement.name)
                .font(.title2)
                .bold()

            Text(achievement.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Text("+\(achievement.xpReward) XP")
                .font(.caption)
                .bold()
                .foregroundColor(.green)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(UIColor.systemBackground))
                .shadow(radius: 20)
        )
        .padding(40)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    isShowing = false
                }
            }
        }
    }
}
