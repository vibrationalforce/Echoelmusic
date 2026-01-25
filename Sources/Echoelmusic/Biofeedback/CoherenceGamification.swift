//
//  CoherenceGamification.swift
//  Echoelmusic
//
//  Coherence Training Gamification - Achievements, Streaks, Daily Challenges
//  Brings Biofeedback to 100% completion
//
//  Created by Echoelmusic Team
//  Copyright © 2026 Echoelmusic. All rights reserved.
//

import Foundation
import Combine

// MARK: - Achievement System

/// Achievement definition with requirements and rewards
public struct Achievement: Identifiable, Codable, Equatable {
    public let id: String
    public let title: String
    public let description: String
    public let icon: String
    public let tier: AchievementTier
    public let category: AchievementCategory
    public let requirement: AchievementRequirement
    public let xpReward: Int
    public var isUnlocked: Bool
    public var unlockedDate: Date?
    public var progress: Float  // 0-1

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

        public var xpMultiplier: Float {
            return Float(rawValue)
        }
    }

    public enum AchievementCategory: String, Codable, CaseIterable {
        case consistency = "Consistency"
        case mastery = "Mastery"
        case duration = "Duration"
        case social = "Social"
        case exploration = "Exploration"
    }
}

/// Achievement requirement types
public enum AchievementRequirement: Codable, Equatable {
    case sessionCount(Int)
    case totalMinutes(Int)
    case coherenceStreak(days: Int, minCoherence: Float)
    case peakCoherence(Float)
    case consecutiveDays(Int)
    case groupSession(participants: Int)
    case averageCoherence(Float, overSessions: Int)
    case longestSession(minutes: Int)
    case totalCoherenceMinutes(Int)
    case uniqueDays(Int)
}

// MARK: - User Level System

/// User level and XP progression
public struct UserLevel: Codable {
    public var currentLevel: Int
    public var currentXP: Int
    public var xpToNextLevel: Int
    public var totalXP: Int

    public var progressToNextLevel: Float {
        return Float(currentXP) / Float(xpToNextLevel)
    }

    public var levelTitle: String {
        switch currentLevel {
        case 0..<5: return "Newcomer"
        case 5..<10: return "Practitioner"
        case 10..<20: return "Explorer"
        case 20..<30: return "Adept"
        case 30..<40: return "Expert"
        case 40..<50: return "Master"
        case 50..<60: return "Sage"
        case 60..<75: return "Luminary"
        case 75..<90: return "Transcendent"
        case 90..<100: return "Enlightened"
        default: return "Quantum Master"
        }
    }

    public static func xpRequiredForLevel(_ level: Int) -> Int {
        // Exponential curve: each level requires more XP
        return Int(100 * pow(1.5, Double(level)))
    }

    public mutating func addXP(_ amount: Int) -> Bool {
        currentXP += amount
        totalXP += amount

        var leveledUp = false

        while currentXP >= xpToNextLevel {
            currentXP -= xpToNextLevel
            currentLevel += 1
            xpToNextLevel = UserLevel.xpRequiredForLevel(currentLevel)
            leveledUp = true
        }

        return leveledUp
    }

    public static var initial: UserLevel {
        return UserLevel(
            currentLevel: 1,
            currentXP: 0,
            xpToNextLevel: xpRequiredForLevel(1),
            totalXP: 0
        )
    }
}

// MARK: - Daily Challenge

/// Daily challenge for consistent engagement
public struct DailyChallenge: Identifiable, Codable {
    public let id: String
    public let title: String
    public let description: String
    public let requirement: ChallengeRequirement
    public let xpReward: Int
    public let expiresAt: Date
    public var isCompleted: Bool
    public var progress: Float

    public enum ChallengeRequirement: Codable {
        case completeSession
        case achieveCoherence(Float)
        case sessionDuration(minutes: Int)
        case morningSession  // Before 10 AM
        case eveningSession  // After 6 PM
        case multipleSession(count: Int)
    }
}

// MARK: - Streak Tracking

/// Streak tracking for consistency
public struct StreakData: Codable {
    public var currentStreak: Int
    public var longestStreak: Int
    public var lastSessionDate: Date?
    public var streakStartDate: Date?
    public var weeklyGoal: Int
    public var thisWeekSessions: Int

    public var isStreakActive: Bool {
        guard let lastDate = lastSessionDate else { return false }
        let calendar = Calendar.current
        let daysSinceLast = calendar.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        return daysSinceLast <= 1
    }

    public mutating func recordSession() {
        let today = Calendar.current.startOfDay(for: Date())

        if let lastDate = lastSessionDate {
            let lastDay = Calendar.current.startOfDay(for: lastDate)
            let daysDiff = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysDiff == 0 {
                // Same day - don't increment streak
            } else if daysDiff == 1 {
                // Consecutive day - increment streak
                currentStreak += 1
            } else {
                // Gap in streak - reset
                currentStreak = 1
                streakStartDate = today
            }
        } else {
            // First session ever
            currentStreak = 1
            streakStartDate = today
        }

        lastSessionDate = Date()
        longestStreak = max(longestStreak, currentStreak)
        thisWeekSessions += 1
    }

    public mutating func resetWeeklyProgress() {
        thisWeekSessions = 0
    }

    public static var initial: StreakData {
        return StreakData(
            currentStreak: 0,
            longestStreak: 0,
            lastSessionDate: nil,
            streakStartDate: nil,
            weeklyGoal: 5,
            thisWeekSessions: 0
        )
    }
}

// MARK: - Session Statistics

/// Comprehensive session statistics
public struct CoherenceStatistics: Codable {
    public var totalSessions: Int
    public var totalMinutes: Int
    public var averageCoherence: Float
    public var peakCoherence: Float
    public var peakCoherenceDate: Date?
    public var coherenceHistory: [Float]  // Last 30 session averages
    public var sessionsThisMonth: Int
    public var minutesThisMonth: Int

    public mutating func recordSession(duration: TimeInterval, averageCoherence: Float, peakCoherence: Float) {
        totalSessions += 1
        totalMinutes += Int(duration / 60)
        sessionsThisMonth += 1
        minutesThisMonth += Int(duration / 60)

        // Update average
        let totalCoherence = self.averageCoherence * Float(totalSessions - 1) + averageCoherence
        self.averageCoherence = totalCoherence / Float(totalSessions)

        // Update peak
        if peakCoherence > self.peakCoherence {
            self.peakCoherence = peakCoherence
            self.peakCoherenceDate = Date()
        }

        // Add to history
        coherenceHistory.append(averageCoherence)
        if coherenceHistory.count > 30 {
            coherenceHistory.removeFirst()
        }
    }

    public static var initial: CoherenceStatistics {
        return CoherenceStatistics(
            totalSessions: 0,
            totalMinutes: 0,
            averageCoherence: 0,
            peakCoherence: 0,
            peakCoherenceDate: nil,
            coherenceHistory: [],
            sessionsThisMonth: 0,
            minutesThisMonth: 0
        )
    }
}

// MARK: - Gamification Manager

/// Main gamification manager coordinating all gamification features
@MainActor
public final class CoherenceGamificationManager: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var userLevel: UserLevel
    @Published public private(set) var streakData: StreakData
    @Published public private(set) var statistics: CoherenceStatistics
    @Published public private(set) var achievements: [Achievement]
    @Published public private(set) var dailyChallenges: [DailyChallenge]
    @Published public private(set) var recentUnlocks: [Achievement] = []

    // MARK: - Private Properties

    private let userDefaultsKey = "echoelmusic_gamification"
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init() {
        self.userLevel = .initial
        self.streakData = .initial
        self.statistics = .initial
        self.achievements = Self.createDefaultAchievements()
        self.dailyChallenges = []

        loadState()
        generateDailyChallenges()
    }

    // MARK: - Session Recording

    /// Record a completed coherence session
    public func recordSession(
        duration: TimeInterval,
        averageCoherence: Float,
        peakCoherence: Float,
        wasGroupSession: Bool = false,
        participants: Int = 1
    ) {
        // Update statistics
        statistics.recordSession(
            duration: duration,
            averageCoherence: averageCoherence,
            peakCoherence: peakCoherence
        )

        // Update streak
        streakData.recordSession()

        // Award base XP
        let baseXP = calculateSessionXP(
            duration: duration,
            averageCoherence: averageCoherence,
            peakCoherence: peakCoherence
        )

        // Streak bonus
        let streakBonus = min(streakData.currentStreak * 10, 100)
        let totalXP = baseXP + streakBonus

        let leveledUp = userLevel.addXP(totalXP)

        // Check achievements
        checkAchievements(
            duration: duration,
            averageCoherence: averageCoherence,
            peakCoherence: peakCoherence,
            wasGroupSession: wasGroupSession,
            participants: participants
        )

        // Check daily challenges
        checkDailyChallenges(
            duration: duration,
            averageCoherence: averageCoherence
        )

        // Save state
        saveState()

        // Notify if leveled up
        if leveledUp {
            NotificationCenter.default.post(
                name: .coherenceGamificationLevelUp,
                object: userLevel
            )
        }
    }

    // MARK: - XP Calculation

    private func calculateSessionXP(
        duration: TimeInterval,
        averageCoherence: Float,
        peakCoherence: Float
    ) -> Int {
        let durationMinutes = Int(duration / 60)

        // Base XP: 10 per minute
        var xp = durationMinutes * 10

        // Coherence bonus
        if averageCoherence > 0.7 {
            xp = Int(Float(xp) * 1.5)
        } else if averageCoherence > 0.5 {
            xp = Int(Float(xp) * 1.2)
        }

        // Peak coherence bonus
        if peakCoherence > 0.9 {
            xp += 50
        } else if peakCoherence > 0.8 {
            xp += 25
        }

        return xp
    }

    // MARK: - Achievement Checking

    private func checkAchievements(
        duration: TimeInterval,
        averageCoherence: Float,
        peakCoherence: Float,
        wasGroupSession: Bool,
        participants: Int
    ) {
        var newUnlocks: [Achievement] = []

        for i in 0..<achievements.count {
            guard !achievements[i].isUnlocked else { continue }

            var shouldUnlock = false
            var progress: Float = 0

            switch achievements[i].requirement {
            case .sessionCount(let count):
                progress = Float(statistics.totalSessions) / Float(count)
                shouldUnlock = statistics.totalSessions >= count

            case .totalMinutes(let minutes):
                progress = Float(statistics.totalMinutes) / Float(minutes)
                shouldUnlock = statistics.totalMinutes >= minutes

            case .coherenceStreak(let days, let minCoherence):
                if averageCoherence >= minCoherence {
                    progress = Float(streakData.currentStreak) / Float(days)
                    shouldUnlock = streakData.currentStreak >= days
                }

            case .peakCoherence(let target):
                progress = peakCoherence / target
                shouldUnlock = peakCoherence >= target

            case .consecutiveDays(let days):
                progress = Float(streakData.currentStreak) / Float(days)
                shouldUnlock = streakData.currentStreak >= days

            case .groupSession(let minParticipants):
                if wasGroupSession {
                    progress = Float(participants) / Float(minParticipants)
                    shouldUnlock = participants >= minParticipants
                }

            case .averageCoherence(let target, let overSessions):
                if statistics.coherenceHistory.count >= overSessions {
                    let recent = statistics.coherenceHistory.suffix(overSessions)
                    let avg = recent.reduce(0, +) / Float(recent.count)
                    progress = avg / target
                    shouldUnlock = avg >= target
                }

            case .longestSession(let minutes):
                let durationMinutes = Int(duration / 60)
                progress = Float(durationMinutes) / Float(minutes)
                shouldUnlock = durationMinutes >= minutes

            case .totalCoherenceMinutes(let minutes):
                let coherenceMinutes = Int(Float(statistics.totalMinutes) * statistics.averageCoherence)
                progress = Float(coherenceMinutes) / Float(minutes)
                shouldUnlock = coherenceMinutes >= minutes

            case .uniqueDays(let days):
                // Simplified - use total sessions as proxy
                progress = Float(min(statistics.totalSessions, days)) / Float(days)
                shouldUnlock = statistics.totalSessions >= days
            }

            achievements[i].progress = min(1.0, progress)

            if shouldUnlock {
                achievements[i].isUnlocked = true
                achievements[i].unlockedDate = Date()

                // Award achievement XP
                let achievementXP = Int(Float(achievements[i].xpReward) * achievements[i].tier.xpMultiplier)
                _ = userLevel.addXP(achievementXP)

                newUnlocks.append(achievements[i])
            }
        }

        if !newUnlocks.isEmpty {
            recentUnlocks = newUnlocks
            NotificationCenter.default.post(
                name: .coherenceGamificationAchievementUnlocked,
                object: newUnlocks
            )
        }
    }

    // MARK: - Daily Challenges

    private func generateDailyChallenges() {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        // Clear old challenges
        dailyChallenges = dailyChallenges.filter { $0.expiresAt > Date() }

        // Generate 3 new challenges if needed
        if dailyChallenges.count < 3 {
            let challenges = [
                DailyChallenge(
                    id: "daily_session_\(today.timeIntervalSince1970)",
                    title: "Complete a Session",
                    description: "Complete any coherence training session today",
                    requirement: .completeSession,
                    xpReward: 50,
                    expiresAt: tomorrow,
                    isCompleted: false,
                    progress: 0
                ),
                DailyChallenge(
                    id: "daily_coherence_\(today.timeIntervalSince1970)",
                    title: "High Coherence",
                    description: "Achieve 70% or higher coherence in a session",
                    requirement: .achieveCoherence(0.7),
                    xpReward: 100,
                    expiresAt: tomorrow,
                    isCompleted: false,
                    progress: 0
                ),
                DailyChallenge(
                    id: "daily_duration_\(today.timeIntervalSince1970)",
                    title: "Extended Practice",
                    description: "Complete a 10+ minute session",
                    requirement: .sessionDuration(minutes: 10),
                    xpReward: 75,
                    expiresAt: tomorrow,
                    isCompleted: false,
                    progress: 0
                )
            ]

            dailyChallenges.append(contentsOf: challenges.prefix(3 - dailyChallenges.count))
        }
    }

    private func checkDailyChallenges(duration: TimeInterval, averageCoherence: Float) {
        let hour = Calendar.current.component(.hour, from: Date())

        for i in 0..<dailyChallenges.count {
            guard !dailyChallenges[i].isCompleted else { continue }

            var completed = false
            var progress: Float = 0

            switch dailyChallenges[i].requirement {
            case .completeSession:
                completed = true
                progress = 1.0

            case .achieveCoherence(let target):
                progress = averageCoherence / target
                completed = averageCoherence >= target

            case .sessionDuration(let minutes):
                let durationMinutes = Int(duration / 60)
                progress = Float(durationMinutes) / Float(minutes)
                completed = durationMinutes >= minutes

            case .morningSession:
                completed = hour < 10
                progress = completed ? 1.0 : 0.0

            case .eveningSession:
                completed = hour >= 18
                progress = completed ? 1.0 : 0.0

            case .multipleSession(let count):
                let todaySessions = statistics.sessionsThisMonth  // Simplified
                progress = Float(todaySessions) / Float(count)
                completed = todaySessions >= count
            }

            dailyChallenges[i].progress = min(1.0, progress)

            if completed {
                dailyChallenges[i].isCompleted = true
                _ = userLevel.addXP(dailyChallenges[i].xpReward)
            }
        }
    }

    // MARK: - Persistence

    private func saveState() {
        let state = GamificationState(
            userLevel: userLevel,
            streakData: streakData,
            statistics: statistics,
            achievements: achievements
        )

        if let encoded = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadState() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let state = try? JSONDecoder().decode(GamificationState.self, from: data) else {
            return
        }

        userLevel = state.userLevel
        streakData = state.streakData
        statistics = state.statistics

        // Merge saved achievements with defaults (to pick up new achievements)
        let savedIds = Set(state.achievements.map { $0.id })
        for achievement in state.achievements {
            if let index = achievements.firstIndex(where: { $0.id == achievement.id }) {
                achievements[index] = achievement
            }
        }
    }

    // MARK: - Default Achievements

    private static func createDefaultAchievements() -> [Achievement] {
        return [
            // Consistency - Bronze
            Achievement(
                id: "first_session",
                title: "First Steps",
                description: "Complete your first coherence session",
                icon: "heart.fill",
                tier: .bronze,
                category: .consistency,
                requirement: .sessionCount(1),
                xpReward: 25,
                isUnlocked: false,
                progress: 0
            ),
            Achievement(
                id: "week_warrior",
                title: "Week Warrior",
                description: "Practice 7 days in a row",
                icon: "flame.fill",
                tier: .bronze,
                category: .consistency,
                requirement: .consecutiveDays(7),
                xpReward: 100,
                isUnlocked: false,
                progress: 0
            ),
            // Consistency - Silver
            Achievement(
                id: "month_master",
                title: "Month Master",
                description: "Practice 30 days in a row",
                icon: "calendar",
                tier: .silver,
                category: .consistency,
                requirement: .consecutiveDays(30),
                xpReward: 500,
                isUnlocked: false,
                progress: 0
            ),
            // Consistency - Gold
            Achievement(
                id: "century_club",
                title: "Century Club",
                description: "Complete 100 sessions",
                icon: "star.fill",
                tier: .gold,
                category: .consistency,
                requirement: .sessionCount(100),
                xpReward: 1000,
                isUnlocked: false,
                progress: 0
            ),
            // Mastery - Bronze
            Achievement(
                id: "coherent_mind",
                title: "Coherent Mind",
                description: "Achieve 70% coherence in a session",
                icon: "brain.head.profile",
                tier: .bronze,
                category: .mastery,
                requirement: .peakCoherence(0.7),
                xpReward: 50,
                isUnlocked: false,
                progress: 0
            ),
            // Mastery - Silver
            Achievement(
                id: "high_achiever",
                title: "High Achiever",
                description: "Achieve 85% coherence in a session",
                icon: "chart.line.uptrend.xyaxis",
                tier: .silver,
                category: .mastery,
                requirement: .peakCoherence(0.85),
                xpReward: 200,
                isUnlocked: false,
                progress: 0
            ),
            // Mastery - Gold
            Achievement(
                id: "peak_performer",
                title: "Peak Performer",
                description: "Achieve 95% peak coherence",
                icon: "crown.fill",
                tier: .gold,
                category: .mastery,
                requirement: .peakCoherence(0.95),
                xpReward: 500,
                isUnlocked: false,
                progress: 0
            ),
            // Mastery - Platinum
            Achievement(
                id: "zen_master",
                title: "Zen Master",
                description: "Average 80% coherence over 10 sessions",
                icon: "sparkles",
                tier: .platinum,
                category: .mastery,
                requirement: .averageCoherence(0.8, overSessions: 10),
                xpReward: 1000,
                isUnlocked: false,
                progress: 0
            ),
            // Duration - Bronze
            Achievement(
                id: "focused_ten",
                title: "Focused Ten",
                description: "Complete a 10-minute session",
                icon: "clock.fill",
                tier: .bronze,
                category: .duration,
                requirement: .longestSession(minutes: 10),
                xpReward: 50,
                isUnlocked: false,
                progress: 0
            ),
            // Duration - Silver
            Achievement(
                id: "deep_dive",
                title: "Deep Dive",
                description: "Complete a 30-minute session",
                icon: "hourglass",
                tier: .silver,
                category: .duration,
                requirement: .longestSession(minutes: 30),
                xpReward: 150,
                isUnlocked: false,
                progress: 0
            ),
            // Duration - Gold
            Achievement(
                id: "marathon_meditator",
                title: "Marathon Meditator",
                description: "Complete a 60-minute session",
                icon: "figure.mind.and.body",
                tier: .gold,
                category: .duration,
                requirement: .longestSession(minutes: 60),
                xpReward: 300,
                isUnlocked: false,
                progress: 0
            ),
            // Duration - Platinum
            Achievement(
                id: "time_traveler",
                title: "Time Traveler",
                description: "Accumulate 1000 minutes of practice",
                icon: "clock.arrow.2.circlepath",
                tier: .platinum,
                category: .duration,
                requirement: .totalMinutes(1000),
                xpReward: 1000,
                isUnlocked: false,
                progress: 0
            ),
            // Social - Silver
            Achievement(
                id: "group_harmony",
                title: "Group Harmony",
                description: "Complete a group session with 5+ people",
                icon: "person.3.fill",
                tier: .silver,
                category: .social,
                requirement: .groupSession(participants: 5),
                xpReward: 200,
                isUnlocked: false,
                progress: 0
            ),
            // Social - Gold
            Achievement(
                id: "community_leader",
                title: "Community Leader",
                description: "Complete a group session with 20+ people",
                icon: "person.crop.circle.badge.plus",
                tier: .gold,
                category: .social,
                requirement: .groupSession(participants: 20),
                xpReward: 500,
                isUnlocked: false,
                progress: 0
            ),
            // Social - Diamond
            Achievement(
                id: "global_coherence",
                title: "Global Coherence",
                description: "Complete a group session with 100+ people",
                icon: "globe",
                tier: .diamond,
                category: .social,
                requirement: .groupSession(participants: 100),
                xpReward: 2000,
                isUnlocked: false,
                progress: 0
            ),
            // Exploration - Bronze
            Achievement(
                id: "explorer",
                title: "Explorer",
                description: "Practice on 10 different days",
                icon: "map.fill",
                tier: .bronze,
                category: .exploration,
                requirement: .uniqueDays(10),
                xpReward: 75,
                isUnlocked: false,
                progress: 0
            ),
            // Exploration - Silver
            Achievement(
                id: "dedicated_practitioner",
                title: "Dedicated Practitioner",
                description: "Complete 50 sessions",
                icon: "medal.fill",
                tier: .silver,
                category: .exploration,
                requirement: .sessionCount(50),
                xpReward: 250,
                isUnlocked: false,
                progress: 0
            ),
            // Consistency - Diamond
            Achievement(
                id: "year_of_coherence",
                title: "Year of Coherence",
                description: "Practice 365 days in a row",
                icon: "sun.max.fill",
                tier: .diamond,
                category: .consistency,
                requirement: .consecutiveDays(365),
                xpReward: 5000,
                isUnlocked: false,
                progress: 0
            ),
            // Mastery - Diamond
            Achievement(
                id: "transcendent",
                title: "Transcendent",
                description: "Achieve 99% peak coherence",
                icon: "wand.and.stars",
                tier: .diamond,
                category: .mastery,
                requirement: .peakCoherence(0.99),
                xpReward: 3000,
                isUnlocked: false,
                progress: 0
            ),
            // Duration - Diamond
            Achievement(
                id: "coherence_veteran",
                title: "Coherence Veteran",
                description: "Accumulate 10,000 minutes of practice",
                icon: "trophy.fill",
                tier: .diamond,
                category: .duration,
                requirement: .totalMinutes(10000),
                xpReward: 5000,
                isUnlocked: false,
                progress: 0
            )
        ]
    }
}

// MARK: - Persistence State

private struct GamificationState: Codable {
    let userLevel: UserLevel
    let streakData: StreakData
    let statistics: CoherenceStatistics
    let achievements: [Achievement]
}

// MARK: - Notifications

public extension Notification.Name {
    static let coherenceGamificationLevelUp = Notification.Name("coherenceGamificationLevelUp")
    static let coherenceGamificationAchievementUnlocked = Notification.Name("coherenceGamificationAchievementUnlocked")
}
