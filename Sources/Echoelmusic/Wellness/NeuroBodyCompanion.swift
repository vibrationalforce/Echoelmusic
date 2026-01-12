// SPDX-License-Identifier: MIT
// Copyright 2026 Echoelmusic
// DISCLAIMER: Wellness companion for creative sessions. NOT medical advice.

import Foundation
import SwiftUI
import Combine
import UserNotifications

// MARK: - NeuroBody Companion
/// Integrated wellness companion for long production sessions
/// Helps maintain health through movement, nutrition, social connection & break reminders
@MainActor
public final class NeuroBodyCompanion: ObservableObject {

    public static let shared = NeuroBodyCompanion()

    // MARK: - Session Tracking

    @Published public private(set) var sessionStartTime: Date?
    @Published public private(set) var totalSessionDuration: TimeInterval = 0
    @Published public private(set) var timeSinceLastBreak: TimeInterval = 0
    @Published public private(set) var timeSinceLastMovement: TimeInterval = 0
    @Published public private(set) var timeSinceLastMeal: TimeInterval = 0
    @Published public private(set) var timeSinceLastHydration: TimeInterval = 0

    // MARK: - Wellness State

    @Published public var isEnabled: Bool = true
    @Published public var currentWellnessScore: Double = 1.0 // 0-1
    @Published public var activeReminder: WellnessReminder?
    @Published public var pendingReminders: [WellnessReminder] = []
    @Published public var completedToday: [WellnessActivity] = []

    // MARK: - Settings

    @Published public var breakIntervalMinutes: Int = 45
    @Published public var movementIntervalMinutes: Int = 30
    @Published public var hydrationIntervalMinutes: Int = 60
    @Published public var mealReminderEnabled: Bool = true
    @Published public var socialReminderEnabled: Bool = true
    @Published public var notificationsEnabled: Bool = true
    @Published public var gentleMode: Bool = false // Less intrusive reminders

    // MARK: - Timers

    private var sessionTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Types

    public enum WellnessCategory: String, CaseIterable, Identifiable {
        case movement = "Bewegung"
        case stretch = "Dehnen"
        case hydration = "Trinken"
        case nutrition = "Ernährung"
        case eyeRest = "Augen"
        case breathing = "Atmung"
        case posture = "Haltung"
        case social = "Sozial"
        case nature = "Natur"
        case rest = "Pause"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .movement: return "figure.walk"
            case .stretch: return "figure.flexibility"
            case .hydration: return "drop.fill"
            case .nutrition: return "leaf.fill"
            case .eyeRest: return "eye"
            case .breathing: return "wind"
            case .posture: return "figure.stand"
            case .social: return "person.2.fill"
            case .nature: return "tree.fill"
            case .rest: return "moon.fill"
            }
        }

        public var color: Color {
            switch self {
            case .movement: return .orange
            case .stretch: return .purple
            case .hydration: return .blue
            case .nutrition: return .green
            case .eyeRest: return .cyan
            case .breathing: return .mint
            case .posture: return .indigo
            case .social: return .pink
            case .nature: return .green
            case .rest: return .gray
            }
        }
    }

    public struct WellnessReminder: Identifiable {
        public let id = UUID()
        public let category: WellnessCategory
        public let title: String
        public let message: String
        public let duration: TimeInterval? // Suggested duration
        public let priority: Priority
        public let createdAt: Date

        public enum Priority: Int, Comparable {
            case low = 0
            case medium = 1
            case high = 2
            case urgent = 3

            public static func < (lhs: Priority, rhs: Priority) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
        }
    }

    public struct WellnessActivity: Identifiable {
        public let id = UUID()
        public let category: WellnessCategory
        public let completedAt: Date
        public let duration: TimeInterval
        public let notes: String?
    }

    // MARK: - Initialization

    private init() {
        loadSettings()
        requestNotificationPermission()
    }

    // MARK: - Session Management

    public func startSession() {
        guard sessionStartTime == nil else { return }

        sessionStartTime = Date()
        timeSinceLastBreak = 0
        timeSinceLastMovement = 0

        // Start monitoring timer
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSessionMetrics()
            }
        }

        // Initial wellness check
        updateSessionMetrics()
    }

    public func endSession() {
        sessionTimer?.invalidate()
        sessionTimer = nil

        if let start = sessionStartTime {
            totalSessionDuration += Date().timeIntervalSince(start)
        }
        sessionStartTime = nil
    }

    public func pauseSession() {
        sessionTimer?.invalidate()
    }

    public func resumeSession() {
        guard sessionStartTime != nil else {
            startSession()
            return
        }

        sessionTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSessionMetrics()
            }
        }
    }

    // MARK: - Metrics Update

    private func updateSessionMetrics() {
        guard isEnabled, let start = sessionStartTime else { return }

        let now = Date()
        let sessionDuration = now.timeIntervalSince(start)

        timeSinceLastBreak += 60
        timeSinceLastMovement += 60
        timeSinceLastHydration += 60

        // Calculate wellness score
        updateWellnessScore()

        // Check for reminders
        checkAndGenerateReminders()
    }

    private func updateWellnessScore() {
        var score = 1.0

        // Deduct for long time without breaks
        let breakMinutes = timeSinceLastBreak / 60
        if breakMinutes > Double(breakIntervalMinutes) {
            score -= min(0.3, (breakMinutes - Double(breakIntervalMinutes)) * 0.01)
        }

        // Deduct for lack of movement
        let movementMinutes = timeSinceLastMovement / 60
        if movementMinutes > Double(movementIntervalMinutes) {
            score -= min(0.2, (movementMinutes - Double(movementIntervalMinutes)) * 0.005)
        }

        // Deduct for dehydration
        let hydrationMinutes = timeSinceLastHydration / 60
        if hydrationMinutes > Double(hydrationIntervalMinutes) {
            score -= min(0.2, (hydrationMinutes - Double(hydrationIntervalMinutes)) * 0.003)
        }

        currentWellnessScore = max(0, min(1, score))
    }

    // MARK: - Reminder Generation

    private func checkAndGenerateReminders() {
        var newReminders: [WellnessReminder] = []

        // Break reminder
        if timeSinceLastBreak >= Double(breakIntervalMinutes) * 60 {
            let overdue = timeSinceLastBreak - Double(breakIntervalMinutes) * 60
            let priority: WellnessReminder.Priority = overdue > 1800 ? .urgent : (overdue > 900 ? .high : .medium)

            newReminders.append(WellnessReminder(
                category: .rest,
                title: "Zeit für eine Pause",
                message: "Du arbeitest seit \(Int(timeSinceLastBreak / 60)) Minuten. Eine kurze Pause hilft deiner Konzentration.",
                duration: 300, // 5 min
                priority: priority,
                createdAt: Date()
            ))
        }

        // Movement reminder
        if timeSinceLastMovement >= Double(movementIntervalMinutes) * 60 {
            newReminders.append(WellnessReminder(
                category: .movement,
                title: "Bewege dich!",
                message: "Steh auf, geh ein paar Schritte, aktiviere deinen Kreislauf.",
                duration: 120,
                priority: .medium,
                createdAt: Date()
            ))
        }

        // Hydration reminder
        if timeSinceLastHydration >= Double(hydrationIntervalMinutes) * 60 {
            newReminders.append(WellnessReminder(
                category: .hydration,
                title: "Trink etwas",
                message: "Dein Gehirn braucht Wasser für optimale Funktion.",
                duration: nil,
                priority: .medium,
                createdAt: Date()
            ))
        }

        // Eye rest (20-20-20 rule)
        if Int(timeSinceLastBreak) % 1200 == 0 && timeSinceLastBreak > 0 { // Every 20 min
            newReminders.append(WellnessReminder(
                category: .eyeRest,
                title: "20-20-20 Regel",
                message: "Schau 20 Sekunden auf etwas 20 Meter entfernt.",
                duration: 20,
                priority: .low,
                createdAt: Date()
            ))
        }

        // Posture check (every 15 min)
        if Int(timeSinceLastBreak) % 900 == 0 && timeSinceLastBreak > 0 {
            newReminders.append(WellnessReminder(
                category: .posture,
                title: "Haltungscheck",
                message: "Schultern zurück, Rücken gerade, Füße flach am Boden.",
                duration: nil,
                priority: .low,
                createdAt: Date()
            ))
        }

        // Social reminder (every 2 hours)
        if socialReminderEnabled && timeSinceLastBreak >= 7200 && Int(timeSinceLastBreak) % 7200 < 60 {
            newReminders.append(WellnessReminder(
                category: .social,
                title: "Soziale Verbindung",
                message: "Schreib einem Freund, ruf jemanden an, oder plane ein Treffen.",
                duration: nil,
                priority: .low,
                createdAt: Date()
            ))
        }

        // Add new reminders
        for reminder in newReminders {
            if !pendingReminders.contains(where: { $0.category == reminder.category }) {
                pendingReminders.append(reminder)

                // Show notification
                if notificationsEnabled && !gentleMode {
                    showNotification(reminder)
                }
            }
        }

        // Set highest priority as active
        if activeReminder == nil, let highest = pendingReminders.sorted(by: { $0.priority > $1.priority }).first {
            activeReminder = highest
        }
    }

    // MARK: - Activity Completion

    public func completeActivity(_ category: WellnessCategory, duration: TimeInterval = 0, notes: String? = nil) {
        // Record activity
        let activity = WellnessActivity(
            category: category,
            completedAt: Date(),
            duration: duration,
            notes: notes
        )
        completedToday.append(activity)

        // Reset timers based on category
        switch category {
        case .rest:
            timeSinceLastBreak = 0
        case .movement, .stretch:
            timeSinceLastMovement = 0
            timeSinceLastBreak = 0 // Movement counts as break
        case .hydration:
            timeSinceLastHydration = 0
        case .nutrition:
            timeSinceLastMeal = 0
            timeSinceLastHydration = 0 // Meals usually include drink
        default:
            break
        }

        // Remove pending reminder for this category
        pendingReminders.removeAll { $0.category == category }

        // Clear active if it was this category
        if activeReminder?.category == category {
            activeReminder = pendingReminders.sorted(by: { $0.priority > $1.priority }).first
        }

        // Update wellness score
        updateWellnessScore()

        // Haptic feedback
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }

    public func dismissReminder(_ reminder: WellnessReminder) {
        pendingReminders.removeAll { $0.id == reminder.id }
        if activeReminder?.id == reminder.id {
            activeReminder = pendingReminders.sorted(by: { $0.priority > $1.priority }).first
        }
    }

    public func snoozeReminder(_ reminder: WellnessReminder, minutes: Int = 10) {
        dismissReminder(reminder)

        // Re-add after snooze period
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(minutes * 60)) { [weak self] in
            self?.pendingReminders.append(reminder)
        }
    }

    // MARK: - Quick Actions

    public static let quickBreakActivities: [(String, WellnessCategory, TimeInterval)] = [
        ("2 Min Dehnen", .stretch, 120),
        ("5 Min Spaziergang", .movement, 300),
        ("1 Min Atemübung", .breathing, 60),
        ("Wasser trinken", .hydration, 0),
        ("Gesunder Snack", .nutrition, 0),
        ("20-20-20 Augen", .eyeRest, 20),
        ("Kurz raus gehen", .nature, 180),
        ("Freund anschreiben", .social, 0)
    ]

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func showNotification(_ reminder: WellnessReminder) {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.message
        content.sound = .default
        content.categoryIdentifier = "wellness_reminder"

        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Persistence

    private let settingsKey = "echoelmusic.neurobody.settings"

    private func loadSettings() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(Settings.self, from: data) {
            breakIntervalMinutes = settings.breakInterval
            movementIntervalMinutes = settings.movementInterval
            hydrationIntervalMinutes = settings.hydrationInterval
            gentleMode = settings.gentleMode
            notificationsEnabled = settings.notificationsEnabled
        }
    }

    public func saveSettings() {
        let settings = Settings(
            breakInterval: breakIntervalMinutes,
            movementInterval: movementIntervalMinutes,
            hydrationInterval: hydrationIntervalMinutes,
            gentleMode: gentleMode,
            notificationsEnabled: notificationsEnabled
        )
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    private struct Settings: Codable {
        let breakInterval: Int
        let movementInterval: Int
        let hydrationInterval: Int
        let gentleMode: Bool
        let notificationsEnabled: Bool
    }

    // MARK: - Statistics

    public var todayStats: (breaks: Int, movement: Int, hydration: Int) {
        let breaks = completedToday.filter { $0.category == .rest }.count
        let movement = completedToday.filter { $0.category == .movement || $0.category == .stretch }.count
        let hydration = completedToday.filter { $0.category == .hydration }.count
        return (breaks, movement, hydration)
    }

    public var totalMovementToday: TimeInterval {
        completedToday
            .filter { $0.category == .movement || $0.category == .stretch }
            .reduce(0) { $0 + $1.duration }
    }
}

// MARK: - NeuroBody Companion View

public struct NeuroBodyCompanionView: View {
    @ObservedObject private var companion = NeuroBodyCompanion.shared
    @State private var showSettings = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Wellness Score
                    wellnessScoreCard

                    // Active Reminder
                    if let reminder = companion.activeReminder {
                        activeReminderCard(reminder)
                    }

                    // Quick Actions
                    quickActionsSection

                    // Today's Progress
                    todayProgressSection

                    // Session Info
                    sessionInfoCard
                }
                .padding()
            }
            .navigationTitle("NeuroBody")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Toggle(isOn: $companion.isEnabled) {
                        Image(systemName: companion.isEnabled ? "heart.fill" : "heart")
                    }
                    .toggleStyle(.button)
                }
            }
            .sheet(isPresented: $showSettings) {
                settingsView
            }
        }
    }

    private var wellnessScoreCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Wellness Score")
                    .font(.headline)
                Spacer()
                Text(wellnessEmoji)
                    .font(.title2)
            }

            // Circular progress
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: companion.currentWellnessScore)
                    .stroke(wellnessColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack {
                    Text("\(Int(companion.currentWellnessScore * 100))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))

                    Text(wellnessStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 150, height: 150)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var wellnessColor: Color {
        if companion.currentWellnessScore >= 0.8 { return .green }
        if companion.currentWellnessScore >= 0.5 { return .yellow }
        return .red
    }

    private var wellnessEmoji: String {
        if companion.currentWellnessScore >= 0.8 { return "😊" }
        if companion.currentWellnessScore >= 0.5 { return "😐" }
        return "😔"
    }

    private var wellnessStatus: String {
        if companion.currentWellnessScore >= 0.8 { return "Ausgezeichnet" }
        if companion.currentWellnessScore >= 0.5 { return "Könnte besser sein" }
        return "Zeit für eine Pause!"
    }

    private func activeReminderCard(_ reminder: NeuroBodyCompanion.WellnessReminder) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: reminder.category.icon)
                    .font(.title2)
                    .foregroundStyle(reminder.category.color)

                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.title)
                        .font(.headline)
                    Text(reminder.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                Button("Erledigt") {
                    companion.completeActivity(reminder.category, duration: reminder.duration ?? 0)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button("Später") {
                    companion.snoozeReminder(reminder, minutes: 10)
                }
                .buttonStyle(.bordered)

                Button {
                    companion.dismissReminder(reminder)
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(reminder.category.color.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(reminder.category.color.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(16)
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(NeuroBodyCompanion.quickBreakActivities, id: \.0) { activity in
                    Button {
                        companion.completeActivity(activity.1, duration: activity.2)
                    } label: {
                        HStack {
                            Image(systemName: activity.1.icon)
                                .foregroundStyle(activity.1.color)
                            Text(activity.0)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.tertiarySystemBackground))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var todayProgressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Heute")
                .font(.headline)

            HStack(spacing: 16) {
                statItem(icon: "pause.circle", value: "\(companion.todayStats.breaks)", label: "Pausen")
                statItem(icon: "figure.walk", value: "\(companion.todayStats.movement)", label: "Bewegung")
                statItem(icon: "drop.fill", value: "\(companion.todayStats.hydration)", label: "Getrunken")
                statItem(icon: "clock", value: formatDuration(companion.totalMovementToday), label: "Aktiv")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.green)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var sessionInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Session")
                    .font(.headline)
                Spacer()
                if companion.sessionStartTime != nil {
                    Text("Aktiv")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            HStack {
                infoItem(label: "Seit Pause", value: formatDuration(companion.timeSinceLastBreak))
                infoItem(label: "Seit Bewegung", value: formatDuration(companion.timeSinceLastMovement))
                infoItem(label: "Seit Trinken", value: formatDuration(companion.timeSinceLastHydration))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private func infoItem(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        return "\(hours)h \(mins)m"
    }

    private var settingsView: some View {
        NavigationStack {
            Form {
                Section("Intervalle") {
                    Stepper("Pause alle \(companion.breakIntervalMinutes) Min", value: $companion.breakIntervalMinutes, in: 15...90, step: 5)
                    Stepper("Bewegung alle \(companion.movementIntervalMinutes) Min", value: $companion.movementIntervalMinutes, in: 15...60, step: 5)
                    Stepper("Trinken alle \(companion.hydrationIntervalMinutes) Min", value: $companion.hydrationIntervalMinutes, in: 30...120, step: 15)
                }

                Section("Benachrichtigungen") {
                    Toggle("Push-Benachrichtigungen", isOn: $companion.notificationsEnabled)
                    Toggle("Sanfter Modus", isOn: $companion.gentleMode)
                    Toggle("Soziale Erinnerungen", isOn: $companion.socialReminderEnabled)
                    Toggle("Essens-Erinnerungen", isOn: $companion.mealReminderEnabled)
                }

                Section {
                    Button("Einstellungen speichern") {
                        companion.saveSettings()
                        showSettings = false
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Einstellungen")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        companion.saveSettings()
                        showSettings = false
                    }
                }
            }
        }
    }
}

// MARK: - Compact Status Bar Widget

public struct NeuroBodyStatusBar: View {
    @ObservedObject private var companion = NeuroBodyCompanion.shared
    @State private var showFullView = false

    public init() {}

    public var body: some View {
        Button {
            showFullView = true
        } label: {
            HStack(spacing: 8) {
                // Wellness indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                // Time since break
                if companion.timeSinceLastBreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("\(Int(companion.timeSinceLastBreak / 60))m")
                            .font(.caption2)
                    }
                    .foregroundStyle(companion.timeSinceLastBreak > Double(companion.breakIntervalMinutes * 60) ? .red : .secondary)
                }

                // Active reminder indicator
                if companion.activeReminder != nil {
                    Image(systemName: "bell.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showFullView) {
            NeuroBodyCompanionView()
        }
    }

    private var statusColor: Color {
        if companion.currentWellnessScore >= 0.8 { return .green }
        if companion.currentWellnessScore >= 0.5 { return .yellow }
        return .red
    }
}
