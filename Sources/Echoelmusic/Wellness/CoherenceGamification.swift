//
//  CoherenceGamification.swift
//  Echoelmusic
//
//  Gamification system for coherence training
//  Achievements, streaks, challenges, and progress tracking
//
//  Created by Echoelmusic Team
//  Copyright © 2026 Echoelmusic. All rights reserved.
//

import Foundation

// MARK: - Achievement System

/// Achievement tiers based on difficulty/rarity
public enum AchievementTier: Int, Codable, CaseIterable {
    case bronze = 1
    case silver = 2
    case gold = 3
    case platinum = 4
    case diamond = 5

    public var name: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        case .diamond: return "Diamond"
        }
    }

    public var xpMultiplier: Double {
        return Double(rawValue)
    }

    public var color: String {
        switch self {
        case .bronze: return "#CD7F32"
        case .silver: return "#C0C0C0"
        case .gold: return "#FFD700"
        case .platinum: return "#E5E4E2"
        case .diamond: return "#B9F2FF"
        }
    }
}

/// Achievement categories
public enum AchievementCategory: String, Codable, CaseIterable {
    case consistency = "Consistency"      // Daily/weekly streaks
    case mastery = "Mastery"              // Skill-based
    case duration = "Duration"            // Time spent
    case social = "Social"                // Group sessions
    case exploration = "Exploration"      // Feature discovery
    case special = "Special"              // Limited time/events
}

/// Individual achievement definition
public struct Achievement: Codable, Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let category: AchievementCategory
    public let tier: AchievementTier
    public let requirement: AchievementRequirement
    public let xpReward: Int
    public let iconName: String
    public let isSecret: Bool

    public init(
        id: String,
        title: String,
        description: String,
        category: AchievementCategory,
        tier: AchievementTier,
        requirement: AchievementRequirement,
        xpReward: Int,
        iconName: String = "star.fill",
        isSecret: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.tier = tier
        self.requirement = requirement
        self.xpReward = xpReward
        self.iconName = iconName
        self.isSecret = isSecret
    }
}

/// Achievement requirement types
public enum AchievementRequirement: Codable {
    case sessionCount(Int)
    case totalMinutes(Int)
    case coherenceStreak(days: Int, minCoherence: Float)
    case peakCoherence(Float)
    case averageCoherence(Float, overSessions: Int)
    case groupSession(participants: Int)
    case dailyStreak(days: Int)
    case weeklyGoal(sessions: Int, weeks: Int)
    case perfectSession(minCoherence: Float, durationMinutes: Int)
    case featureUnlock(featureId: String)
    case timeOfDay(hour: Int, sessions: Int)
    case cumulativeHours(Int)
    case bioReactiveSync(syncScore: Float)
}

/// Unlocked achievement record
public struct UnlockedAchievement: Codable, Identifiable {
    public let id: String
    public let achievementId: String
    public let unlockedAt: Date
    public let sessionId: String?
    public let progress: Float  // 1.0 = complete
}

// MARK: - Progress & Levels

/// User level based on XP
public struct UserLevel: Codable {
    public let level: Int
    public let currentXP: Int
    public let xpForNextLevel: Int
    public let totalXP: Int
    public let title: String

    public var progressToNextLevel: Float {
        let xpInLevel = currentXP
        let xpNeeded = xpForNextLevel - xpForLevel(level)
        return Float(xpInLevel) / Float(xpNeeded)
    }

    private func xpForLevel(_ level: Int) -> Int {
        // Exponential XP curve
        return Int(100 * pow(1.5, Double(level - 1)))
    }

    public static let titles: [Int: String] = [
        1: "Newcomer",
        5: "Explorer",
        10: "Practitioner",
        15: "Adept",
        20: "Expert",
        25: "Master",
        30: "Grandmaster",
        40: "Sage",
        50: "Enlightened",
        75: "Transcendent",
        100: "Quantum Master"
    ]
}

/// Daily/weekly progress tracking
public struct ProgressStats: Codable {
    public var totalSessions: Int
    public var totalMinutes: Int
    public var averageCoherence: Float
    public var peakCoherence: Float
    public var currentStreak: Int
    public var longestStreak: Int
    public var lastSessionDate: Date?
    public var weeklySessionGoal: Int
    public var weeklySessionsCompleted: Int
    public var dailyMinutesGoal: Int
    public var dailyMinutesCompleted: Int

    public init() {
        totalSessions = 0
        totalMinutes = 0
        averageCoherence = 0
        peakCoherence = 0
        currentStreak = 0
        longestStreak = 0
        lastSessionDate = nil
        weeklySessionGoal = 5
        weeklySessionsCompleted = 0
        dailyMinutesGoal = 15
        dailyMinutesCompleted = 0
    }
}

// MARK: - Challenges

/// Daily/weekly challenge
public struct Challenge: Codable, Identifiable {
    public let id: String
    public let title: String
    public let description: String
    public let type: ChallengeType
    public let target: Float
    public let xpReward: Int
    public let startDate: Date
    public let endDate: Date
    public var progress: Float
    public var isCompleted: Bool

    public enum ChallengeType: String, Codable {
        case dailyCoherence = "Reach target coherence"
        case dailyMinutes = "Practice for X minutes"
        case weeklyStreak = "Complete sessions this week"
        case peakChallenge = "Achieve peak coherence"
        case groupChallenge = "Join group session"
        case morningPractice = "Morning session"
        case eveningPractice = "Evening wind-down"
        case perfectSession = "Maintain coherence"
    }
}

// MARK: - Leaderboard

/// Leaderboard entry (opt-in, privacy-respecting)
public struct LeaderboardEntry: Codable, Identifiable {
    public let id: String
    public let displayName: String  // Anonymized or chosen name
    public let avatarId: String
    public let score: Int
    public let rank: Int
    public let level: Int
    public let isCurrentUser: Bool
}

/// Leaderboard types
public enum LeaderboardType: String, Codable, CaseIterable {
    case weekly = "This Week"
    case monthly = "This Month"
    case allTime = "All Time"
    case friends = "Friends"
    case local = "Near You"
}

// MARK: - Gamification Engine

/// Main gamification manager
@MainActor
public final class CoherenceGamificationEngine: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var userLevel: UserLevel
    @Published public private(set) var stats: ProgressStats
    @Published public private(set) var unlockedAchievements: [UnlockedAchievement]
    @Published public private(set) var activeChallenges: [Challenge]
    @Published public private(set) var leaderboard: [LeaderboardEntry]

    // MARK: - Private Properties

    private let achievements: [Achievement]
    private let userDefaults: UserDefaults
    private let storageKey = "echoelmusic.gamification"

    // MARK: - Initialization

    public init() {
        self.userDefaults = UserDefaults.standard
        self.achievements = Self.createAchievements()
        self.userLevel = UserLevel(level: 1, currentXP: 0, xpForNextLevel: 100, totalXP: 0, title: "Newcomer")
        self.stats = ProgressStats()
        self.unlockedAchievements = []
        self.activeChallenges = []
        self.leaderboard = []

        loadState()
        generateDailyChallenges()
    }

    // MARK: - Session Recording

    /// Record a completed session
    public func recordSession(
        durationMinutes: Int,
        averageCoherence: Float,
        peakCoherence: Float,
        sessionId: String = UUID().uuidString,
        isGroupSession: Bool = false,
        participantCount: Int = 1
    ) {
        // Update stats
        stats.totalSessions += 1
        stats.totalMinutes += durationMinutes
        stats.dailyMinutesCompleted += durationMinutes

        // Update coherence averages
        let totalCoherenceSessions = Float(stats.totalSessions - 1)
        stats.averageCoherence = (stats.averageCoherence * totalCoherenceSessions + averageCoherence) / Float(stats.totalSessions)

        if peakCoherence > stats.peakCoherence {
            stats.peakCoherence = peakCoherence
        }

        // Update streak
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastSession = stats.lastSessionDate {
            let lastDay = calendar.startOfDay(for: lastSession)
            let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysDiff == 1 {
                stats.currentStreak += 1
            } else if daysDiff > 1 {
                stats.currentStreak = 1
            }
            // Same day = no change to streak
        } else {
            stats.currentStreak = 1
        }

        if stats.currentStreak > stats.longestStreak {
            stats.longestStreak = stats.currentStreak
        }

        stats.lastSessionDate = Date()
        stats.weeklySessionsCompleted += 1

        // Check achievements
        checkAchievements(
            sessionId: sessionId,
            durationMinutes: durationMinutes,
            averageCoherence: averageCoherence,
            peakCoherence: peakCoherence,
            isGroupSession: isGroupSession,
            participantCount: participantCount
        )

        // Update challenges
        updateChallenges(
            durationMinutes: durationMinutes,
            averageCoherence: averageCoherence,
            peakCoherence: peakCoherence
        )

        // Award XP
        let baseXP = durationMinutes * 10
        let coherenceBonus = Int(averageCoherence * 20)
        let streakBonus = stats.currentStreak * 5
        awardXP(baseXP + coherenceBonus + streakBonus)

        saveState()
    }

    // MARK: - Achievement Checking

    private func checkAchievements(
        sessionId: String,
        durationMinutes: Int,
        averageCoherence: Float,
        peakCoherence: Float,
        isGroupSession: Bool,
        participantCount: Int
    ) {
        for achievement in achievements {
            // Skip if already unlocked
            guard !unlockedAchievements.contains(where: { $0.achievementId == achievement.id }) else {
                continue
            }

            let isUnlocked = checkRequirement(
                achievement.requirement,
                durationMinutes: durationMinutes,
                averageCoherence: averageCoherence,
                peakCoherence: peakCoherence,
                isGroupSession: isGroupSession,
                participantCount: participantCount
            )

            if isUnlocked {
                unlockAchievement(achievement, sessionId: sessionId)
            }
        }
    }

    private func checkRequirement(
        _ requirement: AchievementRequirement,
        durationMinutes: Int,
        averageCoherence: Float,
        peakCoherence: Float,
        isGroupSession: Bool,
        participantCount: Int
    ) -> Bool {
        switch requirement {
        case .sessionCount(let count):
            return stats.totalSessions >= count

        case .totalMinutes(let minutes):
            return stats.totalMinutes >= minutes

        case .coherenceStreak(let days, let minCoherence):
            return stats.currentStreak >= days && averageCoherence >= minCoherence

        case .peakCoherence(let target):
            return peakCoherence >= target

        case .averageCoherence(let target, _):
            return averageCoherence >= target

        case .groupSession(let participants):
            return isGroupSession && participantCount >= participants

        case .dailyStreak(let days):
            return stats.currentStreak >= days

        case .weeklyGoal(let sessions, _):
            return stats.weeklySessionsCompleted >= sessions

        case .perfectSession(let minCoherence, let duration):
            return averageCoherence >= minCoherence && durationMinutes >= duration

        case .cumulativeHours(let hours):
            return stats.totalMinutes >= hours * 60

        default:
            return false
        }
    }

    private func unlockAchievement(_ achievement: Achievement, sessionId: String) {
        let unlocked = UnlockedAchievement(
            id: UUID().uuidString,
            achievementId: achievement.id,
            unlockedAt: Date(),
            sessionId: sessionId,
            progress: 1.0
        )

        unlockedAchievements.append(unlocked)
        awardXP(achievement.xpReward)

        // Post notification for UI
        NotificationCenter.default.post(
            name: .achievementUnlocked,
            object: achievement
        )
    }

    // MARK: - XP & Leveling

    private func awardXP(_ amount: Int) {
        let newTotalXP = userLevel.totalXP + amount
        var newLevel = userLevel.level
        var xpForNext = xpRequiredForLevel(newLevel + 1)

        // Check for level up
        while newTotalXP >= xpForNext {
            newLevel += 1
            xpForNext = xpRequiredForLevel(newLevel + 1)
        }

        let title = UserLevel.titles.filter { $0.key <= newLevel }.max(by: { $0.key < $1.key })?.value ?? "Newcomer"

        let previousLevel = userLevel.level
        userLevel = UserLevel(
            level: newLevel,
            currentXP: newTotalXP - xpRequiredForLevel(newLevel),
            xpForNextLevel: xpForNext,
            totalXP: newTotalXP,
            title: title
        )

        // Level up notification
        if newLevel > previousLevel {
            NotificationCenter.default.post(
                name: .levelUp,
                object: newLevel
            )
        }
    }

    private func xpRequiredForLevel(_ level: Int) -> Int {
        if level <= 1 { return 0 }
        return Int(100 * pow(1.5, Double(level - 1)))
    }

    // MARK: - Challenges

    private func generateDailyChallenges() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        // Remove expired challenges
        activeChallenges.removeAll { $0.endDate < Date() }

        // Generate new daily challenges if needed
        let dailyChallengeCount = activeChallenges.filter {
            calendar.isDate($0.startDate, inSameDayAs: today)
        }.count

        if dailyChallengeCount < 3 {
            let newChallenges = [
                Challenge(
                    id: UUID().uuidString,
                    title: "Morning Mindfulness",
                    description: "Complete a 10-minute session before noon",
                    type: .morningPractice,
                    target: 10,
                    xpReward: 50,
                    startDate: today,
                    endDate: tomorrow,
                    progress: 0,
                    isCompleted: false
                ),
                Challenge(
                    id: UUID().uuidString,
                    title: "Coherence Champion",
                    description: "Achieve 70% average coherence in one session",
                    type: .dailyCoherence,
                    target: 0.7,
                    xpReward: 75,
                    startDate: today,
                    endDate: tomorrow,
                    progress: 0,
                    isCompleted: false
                ),
                Challenge(
                    id: UUID().uuidString,
                    title: "Practice Makes Perfect",
                    description: "Complete 15 minutes of practice today",
                    type: .dailyMinutes,
                    target: 15,
                    xpReward: 40,
                    startDate: today,
                    endDate: tomorrow,
                    progress: 0,
                    isCompleted: false
                )
            ]

            for challenge in newChallenges where activeChallenges.count < 3 {
                activeChallenges.append(challenge)
            }
        }
    }

    private func updateChallenges(
        durationMinutes: Int,
        averageCoherence: Float,
        peakCoherence: Float
    ) {
        for index in activeChallenges.indices {
            guard !activeChallenges[index].isCompleted else { continue }

            switch activeChallenges[index].type {
            case .dailyMinutes:
                activeChallenges[index].progress = Float(stats.dailyMinutesCompleted) / activeChallenges[index].target
            case .dailyCoherence:
                activeChallenges[index].progress = averageCoherence / activeChallenges[index].target
            case .peakChallenge:
                activeChallenges[index].progress = peakCoherence / activeChallenges[index].target
            case .morningPractice:
                let hour = Calendar.current.component(.hour, from: Date())
                if hour < 12 && durationMinutes >= Int(activeChallenges[index].target) {
                    activeChallenges[index].progress = 1.0
                }
            default:
                break
            }

            // Check completion
            if activeChallenges[index].progress >= 1.0 {
                activeChallenges[index].isCompleted = true
                awardXP(activeChallenges[index].xpReward)

                NotificationCenter.default.post(
                    name: .challengeCompleted,
                    object: activeChallenges[index]
                )
            }
        }
    }

    // MARK: - Persistence

    private func saveState() {
        let encoder = JSONEncoder()

        if let levelData = try? encoder.encode(userLevel) {
            userDefaults.set(levelData, forKey: "\(storageKey).level")
        }

        if let statsData = try? encoder.encode(stats) {
            userDefaults.set(statsData, forKey: "\(storageKey).stats")
        }

        if let achievementsData = try? encoder.encode(unlockedAchievements) {
            userDefaults.set(achievementsData, forKey: "\(storageKey).achievements")
        }

        if let challengesData = try? encoder.encode(activeChallenges) {
            userDefaults.set(challengesData, forKey: "\(storageKey).challenges")
        }
    }

    private func loadState() {
        let decoder = JSONDecoder()

        if let levelData = userDefaults.data(forKey: "\(storageKey).level"),
           let level = try? decoder.decode(UserLevel.self, from: levelData) {
            userLevel = level
        }

        if let statsData = userDefaults.data(forKey: "\(storageKey).stats"),
           let loadedStats = try? decoder.decode(ProgressStats.self, from: statsData) {
            stats = loadedStats
        }

        if let achievementsData = userDefaults.data(forKey: "\(storageKey).achievements"),
           let loadedAchievements = try? decoder.decode([UnlockedAchievement].self, from: achievementsData) {
            unlockedAchievements = loadedAchievements
        }

        if let challengesData = userDefaults.data(forKey: "\(storageKey).challenges"),
           let loadedChallenges = try? decoder.decode([Challenge].self, from: challengesData) {
            activeChallenges = loadedChallenges
        }
    }

    // MARK: - Achievement Definitions

    private static func createAchievements() -> [Achievement] {
        return [
            // Consistency achievements
            Achievement(
                id: "first_session",
                title: "First Steps",
                description: "Complete your first coherence session",
                category: .consistency,
                tier: .bronze,
                requirement: .sessionCount(1),
                xpReward: 50,
                iconName: "star.fill"
            ),
            Achievement(
                id: "week_warrior",
                title: "Week Warrior",
                description: "Complete 7 sessions in one week",
                category: .consistency,
                tier: .silver,
                requirement: .weeklyGoal(sessions: 7, weeks: 1),
                xpReward: 150,
                iconName: "flame.fill"
            ),
            Achievement(
                id: "streak_7",
                title: "One Week Strong",
                description: "Maintain a 7-day practice streak",
                category: .consistency,
                tier: .silver,
                requirement: .dailyStreak(days: 7),
                xpReward: 200,
                iconName: "calendar"
            ),
            Achievement(
                id: "streak_30",
                title: "Monthly Master",
                description: "Maintain a 30-day practice streak",
                category: .consistency,
                tier: .gold,
                requirement: .dailyStreak(days: 30),
                xpReward: 500,
                iconName: "calendar.badge.checkmark"
            ),
            Achievement(
                id: "streak_100",
                title: "Century Club",
                description: "Maintain a 100-day practice streak",
                category: .consistency,
                tier: .diamond,
                requirement: .dailyStreak(days: 100),
                xpReward: 2000,
                iconName: "crown.fill"
            ),

            // Mastery achievements
            Achievement(
                id: "coherence_50",
                title: "Finding Balance",
                description: "Achieve 50% average coherence",
                category: .mastery,
                tier: .bronze,
                requirement: .averageCoherence(0.5, overSessions: 1),
                xpReward: 75,
                iconName: "heart.fill"
            ),
            Achievement(
                id: "coherence_70",
                title: "In The Zone",
                description: "Achieve 70% average coherence",
                category: .mastery,
                tier: .silver,
                requirement: .averageCoherence(0.7, overSessions: 1),
                xpReward: 150,
                iconName: "bolt.heart.fill"
            ),
            Achievement(
                id: "coherence_90",
                title: "Peak Performer",
                description: "Achieve 90% average coherence",
                category: .mastery,
                tier: .gold,
                requirement: .averageCoherence(0.9, overSessions: 1),
                xpReward: 300,
                iconName: "star.circle.fill"
            ),
            Achievement(
                id: "peak_95",
                title: "Transcendence",
                description: "Reach 95% peak coherence",
                category: .mastery,
                tier: .platinum,
                requirement: .peakCoherence(0.95),
                xpReward: 500,
                iconName: "sparkles"
            ),
            Achievement(
                id: "perfect_10",
                title: "Perfect Ten",
                description: "Maintain 80%+ coherence for 10 minutes",
                category: .mastery,
                tier: .gold,
                requirement: .perfectSession(minCoherence: 0.8, durationMinutes: 10),
                xpReward: 400,
                iconName: "checkmark.seal.fill"
            ),

            // Duration achievements
            Achievement(
                id: "hour_1",
                title: "Hour One",
                description: "Accumulate 1 hour of practice",
                category: .duration,
                tier: .bronze,
                requirement: .cumulativeHours(1),
                xpReward: 100,
                iconName: "clock.fill"
            ),
            Achievement(
                id: "hour_10",
                title: "Dedicated",
                description: "Accumulate 10 hours of practice",
                category: .duration,
                tier: .silver,
                requirement: .cumulativeHours(10),
                xpReward: 300,
                iconName: "hourglass"
            ),
            Achievement(
                id: "hour_100",
                title: "Committed",
                description: "Accumulate 100 hours of practice",
                category: .duration,
                tier: .gold,
                requirement: .cumulativeHours(100),
                xpReward: 1000,
                iconName: "hourglass.bottomhalf.filled"
            ),
            Achievement(
                id: "hour_1000",
                title: "10,000 Hours Legend",
                description: "Accumulate 1,000 hours of practice",
                category: .duration,
                tier: .diamond,
                requirement: .cumulativeHours(1000),
                xpReward: 5000,
                iconName: "infinity"
            ),

            // Social achievements
            Achievement(
                id: "group_first",
                title: "Better Together",
                description: "Join your first group session",
                category: .social,
                tier: .bronze,
                requirement: .groupSession(participants: 2),
                xpReward: 100,
                iconName: "person.2.fill"
            ),
            Achievement(
                id: "group_10",
                title: "Community Builder",
                description: "Join a session with 10+ participants",
                category: .social,
                tier: .silver,
                requirement: .groupSession(participants: 10),
                xpReward: 200,
                iconName: "person.3.fill"
            ),
            Achievement(
                id: "group_100",
                title: "Global Harmony",
                description: "Join a session with 100+ participants",
                category: .social,
                tier: .gold,
                requirement: .groupSession(participants: 100),
                xpReward: 500,
                iconName: "globe"
            ),

            // Session count achievements
            Achievement(
                id: "sessions_10",
                title: "Getting Started",
                description: "Complete 10 sessions",
                category: .consistency,
                tier: .bronze,
                requirement: .sessionCount(10),
                xpReward: 100,
                iconName: "10.circle.fill"
            ),
            Achievement(
                id: "sessions_50",
                title: "Regular Practice",
                description: "Complete 50 sessions",
                category: .consistency,
                tier: .silver,
                requirement: .sessionCount(50),
                xpReward: 250,
                iconName: "50.circle.fill"
            ),
            Achievement(
                id: "sessions_100",
                title: "Centurion",
                description: "Complete 100 sessions",
                category: .consistency,
                tier: .gold,
                requirement: .sessionCount(100),
                xpReward: 500,
                iconName: "100.circle.fill"
            ),
            Achievement(
                id: "sessions_500",
                title: "Half Millennium",
                description: "Complete 500 sessions",
                category: .consistency,
                tier: .platinum,
                requirement: .sessionCount(500),
                xpReward: 1500,
                iconName: "star.leadinghalf.filled"
            ),
            Achievement(
                id: "sessions_1000",
                title: "Thousand Sessions Master",
                description: "Complete 1,000 sessions",
                category: .consistency,
                tier: .diamond,
                requirement: .sessionCount(1000),
                xpReward: 5000,
                iconName: "trophy.fill"
            )
        ]
    }

    // MARK: - Public API

    /// Get all available achievements
    public func getAllAchievements() -> [Achievement] {
        return achievements
    }

    /// Get achievements by category
    public func getAchievements(for category: AchievementCategory) -> [Achievement] {
        return achievements.filter { $0.category == category }
    }

    /// Get progress for a specific achievement
    public func getProgress(for achievementId: String) -> Float {
        if let unlocked = unlockedAchievements.first(where: { $0.achievementId == achievementId }) {
            return unlocked.progress
        }

        guard let achievement = achievements.first(where: { $0.id == achievementId }) else {
            return 0
        }

        // Calculate progress based on requirement
        switch achievement.requirement {
        case .sessionCount(let count):
            return Float(stats.totalSessions) / Float(count)
        case .totalMinutes(let minutes):
            return Float(stats.totalMinutes) / Float(minutes)
        case .dailyStreak(let days):
            return Float(stats.currentStreak) / Float(days)
        case .cumulativeHours(let hours):
            return Float(stats.totalMinutes) / Float(hours * 60)
        case .peakCoherence(let target):
            return stats.peakCoherence / target
        default:
            return 0
        }
    }

    /// Reset daily stats (called at midnight)
    public func resetDailyStats() {
        stats.dailyMinutesCompleted = 0
        generateDailyChallenges()
        saveState()
    }

    /// Reset weekly stats (called on Monday)
    public func resetWeeklyStats() {
        stats.weeklySessionsCompleted = 0
        saveState()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let achievementUnlocked = Notification.Name("echoelmusic.achievementUnlocked")
    static let levelUp = Notification.Name("echoelmusic.levelUp")
    static let challengeCompleted = Notification.Name("echoelmusic.challengeCompleted")
}
