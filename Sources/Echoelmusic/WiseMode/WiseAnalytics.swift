import Foundation
import SwiftUI
import Combine

// MARK: - Wise Analytics System
/// Dashboard für Nutzungsstatistiken und Fortschritts-Tracking
/// Visualisiert Bio-Daten, Session-Statistiken und Trends

/// Zeitraum für Analytics
enum AnalyticsPeriod: String, CaseIterable {
    case day = "Today"
    case week = "This Week"
    case month = "This Month"
    case year = "This Year"
    case allTime = "All Time"

    var days: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .year: return 365
        case .allTime: return 10000
        }
    }
}

/// Aggregierte Statistiken
struct WiseAnalyticsSnapshot: Codable {
    let period: String
    let startDate: Date
    let endDate: Date

    // Session Stats
    var totalSessions: Int
    var totalMinutes: Int
    var averageSessionDuration: Int // Minuten
    var longestSession: Int // Minuten

    // Bio Stats
    var averageCoherence: Float
    var peakCoherence: Float
    var averageHRV: Float
    var peakHRV: Float
    var totalFlowMinutes: Int

    // Mode Distribution
    var modeDistribution: [String: Int] // Mode -> Minuten
    var mostUsedMode: String

    // Progress
    var wisdomLevel: Int
    var wisdomProgress: Float // 0-1 zum nächsten Level
    var streakDays: Int
    var longestStreak: Int

    // Trends
    var coherenceTrend: Float // -1 bis +1 (sinkend/steigend)
    var sessionTrend: Float
}

/// Tägliche Zusammenfassung
struct DailySummary: Codable, Identifiable {
    let id: UUID
    let date: Date
    var sessions: Int
    var minutes: Int
    var averageCoherence: Float
    var peakCoherence: Float
    var flowMinutes: Int
    var dominantMode: String

    init(date: Date) {
        self.id = UUID()
        self.date = date
        self.sessions = 0
        self.minutes = 0
        self.averageCoherence = 0
        self.peakCoherence = 0
        self.flowMinutes = 0
        self.dominantMode = WiseMode.focus.rawValue
    }
}

/// Kohärenz-Datenpunkt für Charts
struct CoherenceDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Float
    let mode: WiseMode
}

/// Session-Datenpunkt für Charts
struct SessionDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let duration: Int // Minuten
    let mode: WiseMode
}

// MARK: - Wise Analytics Manager

/// Zentrale Verwaltung für Analytics und Statistiken
@MainActor
class WiseAnalyticsManager: ObservableObject {

    // MARK: - Singleton
    static let shared = WiseAnalyticsManager()

    // MARK: - Published State

    @Published var currentSnapshot: WiseAnalyticsSnapshot?
    @Published var selectedPeriod: AnalyticsPeriod = .week
    @Published var dailySummaries: [DailySummary] = []
    @Published var coherenceHistory: [CoherenceDataPoint] = []
    @Published var sessionHistory: [SessionDataPoint] = []

    // MARK: - Live Stats

    @Published var todaySessions: Int = 0
    @Published var todayMinutes: Int = 0
    @Published var todayCoherence: Float = 0.0
    @Published var currentStreak: Int = 0

    // MARK: - Achievements

    @Published var achievements: [WiseAchievement] = []
    @Published var recentAchievements: [WiseAchievement] = []

    // MARK: - Private Properties

    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        loadPersistedData()
        refreshAnalytics()
        setupBindings()

        print("📊 WiseAnalyticsManager: Initialized")
    }

    // MARK: - Analytics Refresh

    /// Aktualisiert alle Analytics
    func refreshAnalytics() {
        let sessions = WiseModeManager.shared.loadAllSessionStats()
        let period = selectedPeriod

        Task { @MainActor in
            self.currentSnapshot = generateSnapshot(from: sessions, period: period)
            self.dailySummaries = generateDailySummaries(from: sessions, days: period.days)
            self.coherenceHistory = generateCoherenceHistory(from: sessions, days: min(period.days, 30))
            self.sessionHistory = generateSessionHistory(from: sessions, days: period.days)
            self.updateTodayStats(from: sessions)
            self.checkAchievements()
        }
    }

    /// Ändert den Analytics-Zeitraum
    func setPeriod(_ period: AnalyticsPeriod) {
        selectedPeriod = period
        refreshAnalytics()
    }

    // MARK: - Snapshot Generation

    private func generateSnapshot(from sessions: [WiseSessionStats], period: AnalyticsPeriod) -> WiseAnalyticsSnapshot {
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -period.days, to: now) ?? now

        let filteredSessions = sessions.filter { $0.startTime >= startDate }

        // Session Stats
        let totalSessions = filteredSessions.count
        let totalMinutes = filteredSessions.reduce(0) { $0 + Int($1.duration / 60) }
        let averageSessionDuration = totalSessions > 0 ? totalMinutes / totalSessions : 0
        let longestSession = filteredSessions.map { Int($0.duration / 60) }.max() ?? 0

        // Bio Stats
        let averageCoherence = filteredSessions.isEmpty ? 0 : filteredSessions.map { $0.averageCoherence }.reduce(0, +) / Float(filteredSessions.count)
        let peakCoherence = filteredSessions.map { $0.peakCoherence }.max() ?? 0
        let averageHRV = filteredSessions.isEmpty ? 0 : filteredSessions.map { $0.averageHRV }.reduce(0, +) / Float(filteredSessions.count)
        let peakHRV = filteredSessions.map { $0.averageHRV }.max() ?? 0
        let totalFlowMinutes = filteredSessions.reduce(0) { $0 + $1.flowStateMinutes }

        // Mode Distribution
        var modeDistribution: [String: Int] = [:]
        for session in filteredSessions {
            let mode = session.mode.rawValue
            modeDistribution[mode, default: 0] += Int(session.duration / 60)
        }
        let mostUsedMode = modeDistribution.max(by: { $0.value < $1.value })?.key ?? WiseMode.focus.rawValue

        // Progress
        let manager = WiseModeManager.shared
        let wisdomLevel = manager.wisdomLevel.rawValue
        let wisdomProgress = calculateWisdomProgress()
        let streakDays = manager.streakDays
        let longestStreak = userDefaults.integer(forKey: "wiseAnalytics.longestStreak")

        // Trends (compare to previous period)
        let coherenceTrend = calculateTrend(current: averageCoherence, sessions: sessions, period: period, metric: { $0.averageCoherence })
        let sessionTrend = calculateSessionTrend(current: totalSessions, sessions: sessions, period: period)

        return WiseAnalyticsSnapshot(
            period: period.rawValue,
            startDate: startDate,
            endDate: now,
            totalSessions: totalSessions,
            totalMinutes: totalMinutes,
            averageSessionDuration: averageSessionDuration,
            longestSession: longestSession,
            averageCoherence: averageCoherence,
            peakCoherence: peakCoherence,
            averageHRV: averageHRV,
            peakHRV: peakHRV,
            totalFlowMinutes: totalFlowMinutes,
            modeDistribution: modeDistribution,
            mostUsedMode: mostUsedMode,
            wisdomLevel: wisdomLevel,
            wisdomProgress: wisdomProgress,
            streakDays: streakDays,
            longestStreak: max(longestStreak, streakDays),
            coherenceTrend: coherenceTrend,
            sessionTrend: sessionTrend
        )
    }

    private func generateDailySummaries(from sessions: [WiseSessionStats], days: Int) -> [DailySummary] {
        var summaries: [Date: DailySummary] = [:]
        let calendar = Calendar.current

        for session in sessions {
            let day = calendar.startOfDay(for: session.startTime)

            if summaries[day] == nil {
                summaries[day] = DailySummary(date: day)
            }

            summaries[day]?.sessions += 1
            summaries[day]?.minutes += Int(session.duration / 60)
            summaries[day]?.flowMinutes += session.flowStateMinutes

            if session.peakCoherence > (summaries[day]?.peakCoherence ?? 0) {
                summaries[day]?.peakCoherence = session.peakCoherence
            }
        }

        // Calculate averages
        for (day, var summary) in summaries {
            let daySessions = sessions.filter { calendar.isDate($0.startTime, inSameDayAs: day) }
            if !daySessions.isEmpty {
                summary.averageCoherence = daySessions.map { $0.averageCoherence }.reduce(0, +) / Float(daySessions.count)

                // Find dominant mode
                var modeMinutes: [WiseMode: Int] = [:]
                for session in daySessions {
                    modeMinutes[session.mode, default: 0] += Int(session.duration / 60)
                }
                summary.dominantMode = modeMinutes.max(by: { $0.value < $1.value })?.key.rawValue ?? WiseMode.focus.rawValue

                summaries[day] = summary
            }
        }

        return summaries.values
            .sorted { $0.date > $1.date }
            .prefix(days)
            .map { $0 }
    }

    private func generateCoherenceHistory(from sessions: [WiseSessionStats], days: Int) -> [CoherenceDataPoint] {
        var dataPoints: [CoherenceDataPoint] = []

        for session in sessions.suffix(100) { // Last 100 sessions
            dataPoints.append(CoherenceDataPoint(
                timestamp: session.startTime,
                value: session.averageCoherence,
                mode: session.mode
            ))
        }

        return dataPoints.sorted { $0.timestamp < $1.timestamp }
    }

    private func generateSessionHistory(from sessions: [WiseSessionStats], days: Int) -> [SessionDataPoint] {
        sessions.map { session in
            SessionDataPoint(
                date: session.startTime,
                duration: Int(session.duration / 60),
                mode: session.mode
            )
        }
        .sorted { $0.date < $1.date }
    }

    private func updateTodayStats(from sessions: [WiseSessionStats]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let todaySessions = sessions.filter { calendar.isDate($0.startTime, inSameDayAs: today) }

        self.todaySessions = todaySessions.count
        self.todayMinutes = todaySessions.reduce(0) { $0 + Int($1.duration / 60) }
        self.todayCoherence = todaySessions.isEmpty ? 0 : todaySessions.map { $0.averageCoherence }.reduce(0, +) / Float(todaySessions.count)
        self.currentStreak = WiseModeManager.shared.streakDays
    }

    // MARK: - Trend Calculation

    private func calculateTrend(current: Float, sessions: [WiseSessionStats], period: AnalyticsPeriod, metric: (WiseSessionStats) -> Float) -> Float {
        let now = Date()
        let periodStart = Calendar.current.date(byAdding: .day, value: -period.days, to: now) ?? now
        let previousPeriodStart = Calendar.current.date(byAdding: .day, value: -period.days * 2, to: now) ?? now

        let previousSessions = sessions.filter { $0.startTime >= previousPeriodStart && $0.startTime < periodStart }

        guard !previousSessions.isEmpty else { return 0 }

        let previousAverage = previousSessions.map(metric).reduce(0, +) / Float(previousSessions.count)

        guard previousAverage > 0 else { return 0 }

        return (current - previousAverage) / previousAverage
    }

    private func calculateSessionTrend(current: Int, sessions: [WiseSessionStats], period: AnalyticsPeriod) -> Float {
        let now = Date()
        let periodStart = Calendar.current.date(byAdding: .day, value: -period.days, to: now) ?? now
        let previousPeriodStart = Calendar.current.date(byAdding: .day, value: -period.days * 2, to: now) ?? now

        let previousCount = sessions.filter { $0.startTime >= previousPeriodStart && $0.startTime < periodStart }.count

        guard previousCount > 0 else { return 0 }

        return Float(current - previousCount) / Float(previousCount)
    }

    private func calculateWisdomProgress() -> Float {
        let manager = WiseModeManager.shared
        let currentLevel = manager.wisdomLevel
        let totalSessions = manager.totalSessions

        guard let nextLevel = WisdomLevel(rawValue: currentLevel.rawValue + 1) else {
            return 1.0 // Max level reached
        }

        let currentRequired = currentLevel.requiredSessions
        let nextRequired = nextLevel.requiredSessions
        let progress = Float(totalSessions - currentRequired) / Float(nextRequired - currentRequired)

        return max(0, min(1, progress))
    }

    // MARK: - Achievements

    private func checkAchievements() {
        let manager = WiseModeManager.shared
        var newAchievements: [WiseAchievement] = []

        // Session Milestones
        for milestone in [1, 5, 10, 25, 50, 100, 250, 500, 1000] {
            if manager.totalSessions >= milestone {
                newAchievements.append(WiseAchievement(
                    id: "sessions_\(milestone)",
                    name: "\(milestone) Sessions",
                    description: "Completed \(milestone) Wise sessions",
                    icon: "checkmark.circle.fill",
                    color: .green,
                    earnedAt: Date()
                ))
            }
        }

        // Streak Milestones
        for streak in [3, 7, 14, 30, 60, 90, 180, 365] {
            if manager.streakDays >= streak {
                newAchievements.append(WiseAchievement(
                    id: "streak_\(streak)",
                    name: "\(streak)-Day Streak",
                    description: "Practiced for \(streak) consecutive days",
                    icon: "flame.fill",
                    color: .orange,
                    earnedAt: Date()
                ))
            }
        }

        // Wisdom Level
        for level in WisdomLevel.allCases {
            if manager.wisdomLevel.rawValue >= level.rawValue {
                newAchievements.append(WiseAchievement(
                    id: "level_\(level.rawValue)",
                    name: level.displayName,
                    description: "Reached \(level.englishName) wisdom level",
                    icon: level.icon,
                    color: level.color,
                    earnedAt: Date()
                ))
            }
        }

        // Total Minutes
        for minutes in [60, 300, 600, 1200, 2400, 6000, 12000] {
            if manager.totalMinutes >= minutes {
                let hours = minutes / 60
                newAchievements.append(WiseAchievement(
                    id: "minutes_\(minutes)",
                    name: "\(hours) Hours",
                    description: "Spent \(hours) hours in Wise mode",
                    icon: "clock.fill",
                    color: .blue,
                    earnedAt: Date()
                ))
            }
        }

        achievements = newAchievements
        recentAchievements = newAchievements.suffix(3).reversed()
    }

    // MARK: - Export

    /// Exportiert Analytics als JSON
    func exportAnalytics() -> Data? {
        guard let snapshot = currentSnapshot else { return nil }
        return try? JSONEncoder().encode(snapshot)
    }

    /// Exportiert als CSV für externe Analyse
    func exportSessionsCSV() -> String {
        let sessions = WiseModeManager.shared.loadAllSessionStats()

        var csv = "Date,Mode,Duration (min),Avg Coherence,Peak Coherence,Avg HRV,Flow Minutes\n"

        for session in sessions {
            let date = ISO8601DateFormatter().string(from: session.startTime)
            let line = "\(date),\(session.mode.rawValue),\(Int(session.duration / 60)),\(session.averageCoherence),\(session.peakCoherence),\(session.averageHRV),\(session.flowStateMinutes)"
            csv += line + "\n"
        }

        return csv
    }

    // MARK: - Persistence

    private func loadPersistedData() {
        if let data = userDefaults.data(forKey: "wiseAnalytics.achievements"),
           let loaded = try? JSONDecoder().decode([WiseAchievement].self, from: data) {
            achievements = loaded
        }
    }

    private func savePersistedData() {
        if let data = try? JSONEncoder().encode(achievements) {
            userDefaults.set(data, forKey: "wiseAnalytics.achievements")
        }

        if let snapshot = currentSnapshot {
            userDefaults.set(max(userDefaults.integer(forKey: "wiseAnalytics.longestStreak"), snapshot.streakDays),
                           forKey: "wiseAnalytics.longestStreak")
        }
    }

    // MARK: - Bindings

    private func setupBindings() {
        $selectedPeriod
            .dropFirst()
            .sink { [weak self] _ in
                self?.refreshAnalytics()
            }
            .store(in: &cancellables)
    }
}

// MARK: - Achievement

struct WiseAchievement: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let colorName: String
    let earnedAt: Date

    var color: Color {
        switch colorName {
        case "green": return .green
        case "orange": return .orange
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "red": return .red
        case "yellow": return .yellow
        case "cyan": return .cyan
        default: return .gray
        }
    }

    init(id: String, name: String, description: String, icon: String, color: Color, earnedAt: Date) {
        self.id = id
        self.name = name
        self.description = description
        self.icon = icon
        self.earnedAt = earnedAt

        // Convert Color to string
        switch color {
        case .green: self.colorName = "green"
        case .orange: self.colorName = "orange"
        case .blue: self.colorName = "blue"
        case .purple: self.colorName = "purple"
        case .pink: self.colorName = "pink"
        case .red: self.colorName = "red"
        case .yellow: self.colorName = "yellow"
        case .cyan: self.colorName = "cyan"
        default: self.colorName = "gray"
        }
    }
}

// MARK: - Analytics Dashboard View

struct WiseAnalyticsDashboard: View {
    @ObservedObject var analytics = WiseAnalyticsManager.shared
    @State private var selectedPeriod: AnalyticsPeriod = .week

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Period Selector
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(AnalyticsPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedPeriod) { _, newPeriod in
                    analytics.setPeriod(newPeriod)
                }

                // Quick Stats
                QuickStatsGrid(analytics: analytics)

                // Coherence Chart
                if !analytics.coherenceHistory.isEmpty {
                    CoherenceChartView(dataPoints: analytics.coherenceHistory)
                }

                // Mode Distribution
                if let snapshot = analytics.currentSnapshot {
                    ModeDistributionView(distribution: snapshot.modeDistribution)
                }

                // Recent Achievements
                if !analytics.recentAchievements.isEmpty {
                    AchievementsView(achievements: analytics.recentAchievements)
                }

                // Daily Summaries
                DailySummariesView(summaries: analytics.dailySummaries)
            }
            .padding()
        }
        .onAppear {
            analytics.refreshAnalytics()
        }
    }
}

struct QuickStatsGrid: View {
    @ObservedObject var analytics: WiseAnalyticsManager

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "Today",
                value: "\(analytics.todaySessions)",
                subtitle: "sessions",
                icon: "calendar",
                color: .blue
            )

            StatCard(
                title: "Minutes",
                value: "\(analytics.todayMinutes)",
                subtitle: "today",
                icon: "clock",
                color: .green
            )

            StatCard(
                title: "Coherence",
                value: String(format: "%.0f%%", analytics.todayCoherence * 100),
                subtitle: "average",
                icon: "heart.circle",
                color: .pink
            )

            StatCard(
                title: "Streak",
                value: "\(analytics.currentStreak)",
                subtitle: "days",
                icon: "flame",
                color: .orange
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct CoherenceChartView: View {
    let dataPoints: [CoherenceDataPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Coherence Trend")
                .font(.headline)

            // Simple line chart representation
            GeometryReader { geometry in
                Path { path in
                    guard !dataPoints.isEmpty else { return }

                    let maxValue = dataPoints.map { $0.value }.max() ?? 1
                    let minValue = dataPoints.map { $0.value }.min() ?? 0
                    let range = max(maxValue - minValue, 0.1)

                    let stepX = geometry.size.width / CGFloat(dataPoints.count - 1)
                    let scaleY = geometry.size.height / CGFloat(range)

                    for (index, point) in dataPoints.enumerated() {
                        let x = CGFloat(index) * stepX
                        let y = geometry.size.height - CGFloat(point.value - minValue) * scaleY

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.purple, lineWidth: 2)
            }
            .frame(height: 150)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct ModeDistributionView: View {
    let distribution: [String: Int]

    var total: Int {
        distribution.values.reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mode Distribution")
                .font(.headline)

            ForEach(distribution.sorted(by: { $0.value > $1.value }), id: \.key) { mode, minutes in
                let percentage = total > 0 ? Float(minutes) / Float(total) : 0

                HStack {
                    Text(mode)
                        .font(.subheadline)
                        .frame(width: 80, alignment: .leading)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 20)

                            Rectangle()
                                .fill(WiseMode(rawValue: mode)?.color ?? .gray)
                                .frame(width: geometry.size.width * CGFloat(percentage), height: 20)
                        }
                        .cornerRadius(4)
                    }
                    .frame(height: 20)

                    Text("\(minutes)m")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct AchievementsView: View {
    let achievements: [WiseAchievement]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Achievements")
                .font(.headline)

            ForEach(achievements) { achievement in
                HStack(spacing: 12) {
                    Image(systemName: achievement.icon)
                        .font(.title2)
                        .foregroundColor(achievement.color)
                        .frame(width: 40)

                    VStack(alignment: .leading) {
                        Text(achievement.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(achievement.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct DailySummariesView: View {
    let summaries: [DailySummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Activity")
                .font(.headline)

            ForEach(summaries.prefix(7)) { summary in
                HStack {
                    Text(summary.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)

                    Spacer()

                    Label("\(summary.sessions)", systemImage: "play.circle")
                        .font(.caption)

                    Label("\(summary.minutes)m", systemImage: "clock")
                        .font(.caption)

                    Label(String(format: "%.0f%%", summary.averageCoherence * 100), systemImage: "heart")
                        .font(.caption)
                        .foregroundColor(.pink)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
