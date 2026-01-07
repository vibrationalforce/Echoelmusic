// WellnessTrackingEngine.swift
// Echoelmusic - 2000% Ralph Wiggum Laser Feuerwehr LKW Fahrer Mode
//
// Personal wellness tracking and mindfulness tools
// For general wellness purposes only - NOT medical advice
//
// DISCLAIMER: This software is for general wellness and entertainment
// purposes only. It does NOT provide medical advice, diagnosis, or treatment.
// Always consult qualified healthcare professionals for medical concerns.
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation
import Combine

#if canImport(HealthKit)
import HealthKit
#endif

// MARK: - Wellness Disclaimer

/// Important wellness disclaimer - always displayed to users
public struct WellnessDisclaimer: Sendable {
    public static let full = """
    IMPORTANT WELLNESS DISCLAIMER

    This application is designed for general wellness, relaxation, and entertainment purposes only.

    This app does NOT:
    - Provide medical advice, diagnosis, or treatment
    - Replace professional healthcare guidance
    - Claim to cure, treat, or prevent any medical condition
    - Make any health claims beyond general wellness support

    The biofeedback features are for self-exploration and relaxation only.
    The meditation and breathing exercises are general wellness practices.

    If you have any health concerns, please consult a qualified healthcare professional.

    By using this app, you acknowledge that you understand these limitations.
    """

    public static let short = "For general wellness only. Not medical advice. Consult healthcare professionals for medical concerns."

    public static let meditation = "Meditation is a general wellness practice. Results vary. Not a substitute for professional mental health support."

    public static let biofeedback = "Biofeedback readings are for self-awareness only. Not diagnostic. Consult professionals for health concerns."
}

// MARK: - Wellness Category

/// Categories of wellness activities (non-medical)
public enum WellnessCategory: String, CaseIterable, Codable, Sendable {
    // Relaxation
    case relaxation = "Relaxation"
    case stressRelief = "Stress Relief"
    case calmness = "Calmness"
    case tranquility = "Tranquility"

    // Mindfulness
    case meditation = "Meditation"
    case breathwork = "Breathwork"
    case mindfulness = "Mindfulness"
    case presence = "Present Moment"
    case gratitude = "Gratitude"

    // Focus
    case focus = "Focus"
    case concentration = "Concentration"
    case creativity = "Creativity"
    case clarity = "Mental Clarity"

    // Energy
    case energizing = "Energizing"
    case motivation = "Motivation"
    case vitality = "Vitality"
    case awakening = "Awakening"

    // Rest
    case sleepSupport = "Sleep Support"
    case windDown = "Wind Down"
    case restful = "Restful"
    case recovery = "Recovery"

    // Movement
    case gentleMovement = "Gentle Movement"
    case stretching = "Stretching"
    case bodyAwareness = "Body Awareness"
    case grounding = "Grounding"

    // Social
    case connection = "Connection"
    case compassion = "Compassion"
    case selfCare = "Self-Care"
    case emotional = "Emotional Wellness"

    public var description: String {
        switch self {
        case .relaxation: return "General relaxation practices"
        case .stressRelief: return "Techniques for everyday stress management"
        case .meditation: return "Traditional meditation practices"
        case .breathwork: return "Breathing exercises for wellness"
        case .focus: return "Attention and focus practices"
        case .sleepSupport: return "Practices to support restful sleep"
        default: return "\(rawValue) practices for general wellness"
        }
    }
}

// MARK: - Wellness Session

/// A wellness practice session
public struct WellnessSession: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var category: WellnessCategory
    public var duration: TimeInterval
    public var startTime: Date
    public var endTime: Date?
    public var notes: String?
    public var moodBefore: MoodLevel?
    public var moodAfter: MoodLevel?
    public var biofeedback: BiofeedbackSnapshot?

    public enum MoodLevel: Int, Codable, Sendable, CaseIterable {
        case veryLow = 1
        case low = 2
        case neutral = 3
        case good = 4
        case great = 5

        public var emoji: String {
            switch self {
            case .veryLow: return "😔"
            case .low: return "😕"
            case .neutral: return "😐"
            case .good: return "🙂"
            case .great: return "😊"
            }
        }
    }

    public struct BiofeedbackSnapshot: Codable, Sendable {
        public var coherenceLevel: Float?
        public var calmness: Float?
        public var breathingRate: Float?
        public var timestamp: Date

        public init(coherenceLevel: Float? = nil, calmness: Float? = nil, breathingRate: Float? = nil) {
            self.coherenceLevel = coherenceLevel
            self.calmness = calmness
            self.breathingRate = breathingRate
            self.timestamp = Date()
        }
    }

    public init(name: String, category: WellnessCategory, duration: TimeInterval = 0) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.duration = duration
        self.startTime = Date()
        self.endTime = nil
        self.notes = nil
        self.moodBefore = nil
        self.moodAfter = nil
        self.biofeedback = nil
    }

    public var isComplete: Bool {
        endTime != nil
    }

    public var actualDuration: TimeInterval {
        if let end = endTime {
            return end.timeIntervalSince(startTime)
        }
        return Date().timeIntervalSince(startTime)
    }
}

// MARK: - Breathing Pattern

/// Breathing exercise patterns
public struct BreathingPattern: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var description: String
    public var inhaleSeconds: Double
    public var holdInSeconds: Double
    public var exhaleSeconds: Double
    public var holdOutSeconds: Double
    public var cycles: Int
    public var category: WellnessCategory

    public init(
        name: String,
        description: String,
        inhale: Double,
        holdIn: Double,
        exhale: Double,
        holdOut: Double,
        cycles: Int,
        category: WellnessCategory = .breathwork
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.inhaleSeconds = inhale
        self.holdInSeconds = holdIn
        self.exhaleSeconds = exhale
        self.holdOutSeconds = holdOut
        self.cycles = cycles
        self.category = category
    }

    public var cycleDuration: TimeInterval {
        inhaleSeconds + holdInSeconds + exhaleSeconds + holdOutSeconds
    }

    public var totalDuration: TimeInterval {
        cycleDuration * Double(cycles)
    }

    // MARK: - Preset Patterns

    public static let boxBreathing = BreathingPattern(
        name: "Box Breathing",
        description: "Equal inhale, hold, exhale, hold. A balanced technique.",
        inhale: 4, holdIn: 4, exhale: 4, holdOut: 4, cycles: 6,
        category: .relaxation
    )

    public static let relaxingBreath = BreathingPattern(
        name: "Relaxing Breath (4-7-8)",
        description: "Extended exhale for relaxation support.",
        inhale: 4, holdIn: 7, exhale: 8, holdOut: 0, cycles: 4,
        category: .sleepSupport
    )

    public static let energizingBreath = BreathingPattern(
        name: "Energizing Breath",
        description: "Quick breaths for an energizing sensation.",
        inhale: 2, holdIn: 0, exhale: 2, holdOut: 0, cycles: 20,
        category: .energizing
    )

    public static let calmingBreath = BreathingPattern(
        name: "Calming Breath",
        description: "Slow, deep breaths for calmness.",
        inhale: 5, holdIn: 2, exhale: 7, holdOut: 2, cycles: 5,
        category: .calmness
    )

    public static let coherenceBreath = BreathingPattern(
        name: "Coherence Breath",
        description: "5-second rhythm associated with relaxation states.",
        inhale: 5, holdIn: 0, exhale: 5, holdOut: 0, cycles: 12,
        category: .mindfulness
    )

    public static let morningBreath = BreathingPattern(
        name: "Morning Awakening",
        description: "Gentle breath pattern for starting the day.",
        inhale: 4, holdIn: 2, exhale: 4, holdOut: 1, cycles: 8,
        category: .awakening
    )

    public static let allPatterns: [BreathingPattern] = [
        .boxBreathing, .relaxingBreath, .energizingBreath,
        .calmingBreath, .coherenceBreath, .morningBreath
    ]
}

// MARK: - Meditation Guide

/// Guided meditation content
public struct MeditationGuide: Identifiable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var description: String
    public var duration: TimeInterval
    public var category: WellnessCategory
    public var difficulty: Difficulty
    public var instructions: [Instruction]
    public var audioURL: URL?

    public enum Difficulty: String, Codable, Sendable, CaseIterable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
    }

    public struct Instruction: Identifiable, Codable, Sendable {
        public let id: UUID
        public var text: String
        public var startTime: TimeInterval
        public var duration: TimeInterval
        public var voiceGuidance: Bool

        public init(text: String, startTime: TimeInterval, duration: TimeInterval, voiceGuidance: Bool = true) {
            self.id = UUID()
            self.text = text
            self.startTime = startTime
            self.duration = duration
            self.voiceGuidance = voiceGuidance
        }
    }

    public init(
        title: String,
        description: String,
        duration: TimeInterval,
        category: WellnessCategory,
        difficulty: Difficulty = .beginner
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.duration = duration
        self.category = category
        self.difficulty = difficulty
        self.instructions = []
        self.audioURL = nil
    }

    // MARK: - Preset Meditations

    public static let bodyScanning = MeditationGuide(
        title: "Body Awareness",
        description: "A gentle practice to bring awareness to different parts of your body.",
        duration: 600,
        category: .bodyAwareness,
        difficulty: .beginner
    )

    public static let breathAwareness = MeditationGuide(
        title: "Breath Awareness",
        description: "Simply notice your natural breathing without trying to change it.",
        duration: 300,
        category: .mindfulness,
        difficulty: .beginner
    )

    public static let lovingKindness = MeditationGuide(
        title: "Kindness Practice",
        description: "Cultivate feelings of goodwill towards yourself and others.",
        duration: 900,
        category: .compassion,
        difficulty: .intermediate
    )

    public static let gratitudeReflection = MeditationGuide(
        title: "Gratitude Reflection",
        description: "Reflect on things you appreciate in your life.",
        duration: 600,
        category: .gratitude,
        difficulty: .beginner
    )

    public static let focusTraining = MeditationGuide(
        title: "Focus Training",
        description: "Practice bringing attention to a single point of focus.",
        duration: 600,
        category: .focus,
        difficulty: .intermediate
    )
}

// MARK: - Wellness Goal

/// Personal wellness goals
public struct WellnessGoal: Identifiable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var description: String
    public var category: WellnessCategory
    public var targetMinutesPerDay: Int
    public var targetDaysPerWeek: Int
    public var startDate: Date
    public var progress: [DailyProgress]
    public var isActive: Bool

    public struct DailyProgress: Identifiable, Codable, Sendable {
        public let id: UUID
        public var date: Date
        public var minutesCompleted: Int
        public var sessionsCompleted: Int

        public init(date: Date, minutesCompleted: Int, sessionsCompleted: Int) {
            self.id = UUID()
            self.date = date
            self.minutesCompleted = minutesCompleted
            self.sessionsCompleted = sessionsCompleted
        }
    }

    public init(
        title: String,
        description: String = "",
        category: WellnessCategory,
        targetMinutesPerDay: Int = 10,
        targetDaysPerWeek: Int = 5
    ) {
        self.id = UUID()
        self.title = title
        self.description = description
        self.category = category
        self.targetMinutesPerDay = targetMinutesPerDay
        self.targetDaysPerWeek = targetDaysPerWeek
        self.startDate = Date()
        self.progress = []
        self.isActive = true
    }

    public var weeklyProgress: Double {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        let thisWeekProgress = progress.filter { $0.date >= startOfWeek }
        let daysWithTarget = thisWeekProgress.filter { $0.minutesCompleted >= targetMinutesPerDay }.count
        return Double(daysWithTarget) / Double(targetDaysPerWeek)
    }
}

// MARK: - Wellness Journal Entry

/// Personal wellness journal
public struct JournalEntry: Identifiable, Codable, Sendable {
    public let id: UUID
    public var date: Date
    public var title: String
    public var content: String
    public var mood: WellnessSession.MoodLevel
    public var tags: [String]
    public var category: WellnessCategory?
    public var isPrivate: Bool

    public init(title: String, content: String, mood: WellnessSession.MoodLevel) {
        self.id = UUID()
        self.date = Date()
        self.title = title
        self.content = content
        self.mood = mood
        self.tags = []
        self.category = nil
        self.isPrivate = true
    }
}

// MARK: - Wellness Statistics

/// Aggregated wellness statistics (non-medical)
public struct WellnessStatistics: Sendable {
    public var totalSessions: Int
    public var totalMinutes: Int
    public var currentStreak: Int
    public var longestStreak: Int
    public var favoriteCategory: WellnessCategory?
    public var averageMoodBefore: Double
    public var averageMoodAfter: Double
    public var moodImprovement: Double
    public var weeklyMinutes: [Int] // Last 7 days

    public static let empty = WellnessStatistics(
        totalSessions: 0,
        totalMinutes: 0,
        currentStreak: 0,
        longestStreak: 0,
        favoriteCategory: nil,
        averageMoodBefore: 3.0,
        averageMoodAfter: 3.0,
        moodImprovement: 0,
        weeklyMinutes: [0, 0, 0, 0, 0, 0, 0]
    )
}

// MARK: - Wellness Tracking Engine

/// Main wellness tracking engine
/// DISCLAIMER: For general wellness only. Not medical advice.
@MainActor
public final class WellnessTrackingEngine: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isSessionActive: Bool = false
    @Published public private(set) var currentSession: WellnessSession?
    @Published public private(set) var sessions: [WellnessSession] = []
    @Published public private(set) var goals: [WellnessGoal] = []
    @Published public private(set) var journal: [JournalEntry] = []
    @Published public private(set) var statistics: WellnessStatistics = .empty

    @Published public var selectedCategory: WellnessCategory = .relaxation
    @Published public var reminderEnabled: Bool = true
    @Published public var quantumEnhanced: Bool = true

    // MARK: - Biofeedback (Non-Medical)

    /// Current coherence level (for self-awareness, not diagnostic)
    @Published public private(set) var currentCoherence: Float = 0.5

    /// Current calmness indicator (subjective, not medical)
    @Published public private(set) var currentCalmness: Float = 0.5

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var sessionTimer: Timer?
    private var breathingTimer: Timer?

    // MARK: - Initialization

    public init() {
        setupBiofeedbackSimulation()
        loadSavedData()
    }

    private func setupBiofeedbackSimulation() {
        // Simulate biofeedback readings (not actual medical measurements)
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateBiofeedback()
            }
            .store(in: &cancellables)
    }

    private func updateBiofeedback() {
        // Simulated biofeedback for visualization (not medical)
        let time = Date().timeIntervalSince1970
        let baseCoherence = isSessionActive ? 0.6 : 0.4
        currentCoherence = Float(baseCoherence + 0.3 * sin(time * 0.2))
        currentCalmness = Float(baseCoherence + 0.25 * cos(time * 0.15))
    }

    private func loadSavedData() {
        // Load saved sessions, goals, journal from UserDefaults or database
        updateStatistics()
    }

    // MARK: - Session Management

    /// Start a new wellness session
    public func startSession(name: String, category: WellnessCategory, moodBefore: WellnessSession.MoodLevel? = nil) {
        guard !isSessionActive else { return }

        var session = WellnessSession(name: name, category: category)
        session.moodBefore = moodBefore

        currentSession = session
        isSessionActive = true

        print("WellnessTrackingEngine: Started '\(name)' session (\(category.rawValue))")
        print(WellnessDisclaimer.short)
    }

    /// End the current session
    public func endSession(moodAfter: WellnessSession.MoodLevel? = nil, notes: String? = nil) {
        guard isSessionActive, var session = currentSession else { return }

        session.endTime = Date()
        session.moodAfter = moodAfter
        session.notes = notes
        session.duration = session.actualDuration
        session.biofeedback = WellnessSession.BiofeedbackSnapshot(
            coherenceLevel: currentCoherence,
            calmness: currentCalmness
        )

        sessions.append(session)
        currentSession = nil
        isSessionActive = false

        updateStatistics()
        updateGoalProgress(session)

        print("WellnessTrackingEngine: Completed session. Duration: \(Int(session.duration / 60)) minutes")
    }

    /// Cancel the current session
    public func cancelSession() {
        currentSession = nil
        isSessionActive = false
    }

    // MARK: - Breathing Exercises

    /// Start a breathing exercise
    public func startBreathingExercise(_ pattern: BreathingPattern, completion: ((Bool) -> Void)? = nil) {
        startSession(name: pattern.name, category: pattern.category)

        var currentCycle = 0
        var currentPhase = 0 // 0: inhale, 1: hold in, 2: exhale, 3: hold out
        let phases = [pattern.inhaleSeconds, pattern.holdInSeconds, pattern.exhaleSeconds, pattern.holdOutSeconds]

        func nextPhase() {
            currentPhase += 1
            if currentPhase >= 4 {
                currentPhase = 0
                currentCycle += 1
            }

            if currentCycle >= pattern.cycles {
                breathingTimer?.invalidate()
                breathingTimer = nil
                endSession()
                completion?(true)
                return
            }

            let duration = phases[currentPhase]
            if duration > 0 {
                breathingTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
                    nextPhase()
                }
            } else {
                nextPhase()
            }
        }

        // Start first phase
        breathingTimer = Timer.scheduledTimer(withTimeInterval: phases[0], repeats: false) { _ in
            nextPhase()
        }
    }

    /// Stop breathing exercise
    public func stopBreathingExercise() {
        breathingTimer?.invalidate()
        breathingTimer = nil
        if isSessionActive {
            endSession()
        }
    }

    // MARK: - Goals

    /// Create a new wellness goal
    public func createGoal(
        title: String,
        category: WellnessCategory,
        targetMinutesPerDay: Int = 10,
        targetDaysPerWeek: Int = 5
    ) -> WellnessGoal {
        let goal = WellnessGoal(
            title: title,
            category: category,
            targetMinutesPerDay: targetMinutesPerDay,
            targetDaysPerWeek: targetDaysPerWeek
        )
        goals.append(goal)
        return goal
    }

    /// Update goal progress
    private func updateGoalProgress(_ session: WellnessSession) {
        let today = Calendar.current.startOfDay(for: Date())
        let minutesCompleted = Int(session.duration / 60)

        for i in 0..<goals.count where goals[i].category == session.category && goals[i].isActive {
            if let existingIndex = goals[i].progress.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
                goals[i].progress[existingIndex].minutesCompleted += minutesCompleted
                goals[i].progress[existingIndex].sessionsCompleted += 1
            } else {
                let progress = WellnessGoal.DailyProgress(
                    date: today,
                    minutesCompleted: minutesCompleted,
                    sessionsCompleted: 1
                )
                goals[i].progress.append(progress)
            }
        }
    }

    // MARK: - Journal

    /// Add a journal entry
    public func addJournalEntry(title: String, content: String, mood: WellnessSession.MoodLevel, tags: [String] = []) {
        var entry = JournalEntry(title: title, content: content, mood: mood)
        entry.tags = tags
        entry.category = selectedCategory
        journal.append(entry)
    }

    /// Delete a journal entry
    public func deleteJournalEntry(_ entryId: UUID) {
        journal.removeAll { $0.id == entryId }
    }

    // MARK: - Statistics

    /// Update wellness statistics
    private func updateStatistics() {
        let totalSessions = sessions.count
        let totalMinutes = Int(sessions.reduce(0) { $0 + $1.duration } / 60)

        // Calculate streaks
        let sortedSessions = sessions.sorted { $0.startTime > $1.startTime }
        var currentStreak = 0
        var longestStreak = 0
        var tempStreak = 0
        var lastDate: Date?

        for session in sortedSessions {
            let sessionDate = Calendar.current.startOfDay(for: session.startTime)
            if let last = lastDate {
                let dayDiff = Calendar.current.dateComponents([.day], from: sessionDate, to: last).day ?? 0
                if dayDiff == 1 {
                    tempStreak += 1
                    longestStreak = max(longestStreak, tempStreak)
                } else if dayDiff > 1 {
                    tempStreak = 1
                }
            } else {
                tempStreak = 1
                // Check if today or yesterday for current streak
                let today = Calendar.current.startOfDay(for: Date())
                let daysSince = Calendar.current.dateComponents([.day], from: sessionDate, to: today).day ?? 0
                if daysSince <= 1 {
                    currentStreak = tempStreak
                }
            }
            lastDate = sessionDate
        }

        // Calculate favorite category
        let categoryCounts = Dictionary(grouping: sessions) { $0.category }
            .mapValues { $0.count }
        let favoriteCategory = categoryCounts.max { $0.value < $1.value }?.key

        // Calculate mood changes
        let moodBeforeValues = sessions.compactMap { $0.moodBefore?.rawValue }
        let moodAfterValues = sessions.compactMap { $0.moodAfter?.rawValue }
        let avgBefore = moodBeforeValues.isEmpty ? 3.0 : moodBeforeValues.reduce(0.0) { $0 + Double($1) } / Double(moodBeforeValues.count)
        let avgAfter = moodAfterValues.isEmpty ? 3.0 : moodAfterValues.reduce(0.0) { $0 + Double($1) } / Double(moodAfterValues.count)

        // Weekly minutes
        var weeklyMinutes = [Int](repeating: 0, count: 7)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for session in sessions {
            let sessionDate = calendar.startOfDay(for: session.startTime)
            if let dayIndex = calendar.dateComponents([.day], from: sessionDate, to: today).day,
               dayIndex >= 0 && dayIndex < 7 {
                weeklyMinutes[6 - dayIndex] += Int(session.duration / 60)
            }
        }

        statistics = WellnessStatistics(
            totalSessions: totalSessions,
            totalMinutes: totalMinutes,
            currentStreak: currentStreak,
            longestStreak: max(longestStreak, currentStreak),
            favoriteCategory: favoriteCategory,
            averageMoodBefore: avgBefore,
            averageMoodAfter: avgAfter,
            moodImprovement: avgAfter - avgBefore,
            weeklyMinutes: weeklyMinutes
        )
    }

    // MARK: - Recommendations

    /// Get personalized recommendations (general wellness, not medical)
    public func getRecommendations() -> [WellnessRecommendation] {
        var recommendations: [WellnessRecommendation] = []

        // Based on time of day
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 10 {
            recommendations.append(WellnessRecommendation(
                title: "Morning Mindfulness",
                description: "Start your day with a brief mindfulness practice",
                category: .mindfulness,
                duration: 300
            ))
        } else if hour > 21 {
            recommendations.append(WellnessRecommendation(
                title: "Evening Wind Down",
                description: "Prepare for restful sleep with relaxation",
                category: .sleepSupport,
                duration: 600
            ))
        }

        // Based on current coherence (for variety, not medical)
        if currentCoherence < 0.4 {
            recommendations.append(WellnessRecommendation(
                title: "Calming Breath",
                description: "Try some calming breathing exercises",
                category: .breathwork,
                duration: 300
            ))
        }

        // Based on statistics
        if statistics.currentStreak > 0 {
            recommendations.append(WellnessRecommendation(
                title: "Keep Your Streak!",
                description: "You're on a \(statistics.currentStreak)-day streak. Keep it going!",
                category: statistics.favoriteCategory ?? .relaxation,
                duration: 600
            ))
        }

        return recommendations
    }

    public struct WellnessRecommendation: Identifiable, Sendable {
        public let id = UUID()
        public var title: String
        public var description: String
        public var category: WellnessCategory
        public var duration: TimeInterval
    }

    // MARK: - Export Data

    /// Export wellness data for personal records
    public func exportData() -> WellnessDataExport {
        return WellnessDataExport(
            exportDate: Date(),
            disclaimer: WellnessDisclaimer.full,
            sessions: sessions,
            goals: goals,
            journal: journal,
            statistics: statistics
        )
    }

    public struct WellnessDataExport: Codable, Sendable {
        public var exportDate: Date
        public var disclaimer: String
        public var sessions: [WellnessSession]
        public var goals: [WellnessGoal]
        public var journal: [JournalEntry]
        public var statistics: WellnessStatistics
    }
}

// MARK: - Sound Bath Generator

/// Ambient sound generator for wellness sessions
@MainActor
public final class SoundBathGenerator: ObservableObject {

    public enum SoundType: String, CaseIterable, Sendable {
        case tibetanBowls = "Tibetan Bowls"
        case crystalBowls = "Crystal Bowls"
        case oceanWaves = "Ocean Waves"
        case rainforest = "Rainforest"
        case fireplace = "Fireplace"
        case whiteNoise = "White Noise"
        case pinkNoise = "Pink Noise"
        case brownNoise = "Brown Noise"
        case binaural = "Binaural Beats"
        case isochronic = "Isochronic Tones"
        case solfeggio = "Solfeggio Frequencies"
        case quantumHarmonics = "Quantum Harmonics"
    }

    @Published public var isPlaying: Bool = false
    @Published public var volume: Float = 0.7
    @Published public var selectedSounds: Set<SoundType> = [.tibetanBowls]
    @Published public var binauralFrequency: Float = 10.0 // Alpha waves

    public func play() {
        isPlaying = true
    }

    public func pause() {
        isPlaying = false
    }

    public func stop() {
        isPlaying = false
    }
}

// MARK: - Mindful Reminder

/// Gentle reminders for mindfulness breaks
public struct MindfulReminder: Identifiable, Codable, Sendable {
    public let id: UUID
    public var message: String
    public var category: WellnessCategory
    public var time: Date
    public var isEnabled: Bool
    public var repeatDays: Set<Int> // 1 = Sunday, 7 = Saturday

    public init(message: String, category: WellnessCategory, time: Date) {
        self.id = UUID()
        self.message = message
        self.category = category
        self.time = time
        self.isEnabled = true
        self.repeatDays = Set(1...7) // Every day
    }

    public static let suggestions = [
        "Take a moment to breathe deeply",
        "Notice how your body feels right now",
        "What are you grateful for today?",
        "Take a mindful pause",
        "Check in with yourself",
        "Time for a wellness break"
    ]
}
