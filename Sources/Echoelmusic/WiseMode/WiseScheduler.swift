import Foundation
import SwiftUI
import Combine
import UserNotifications

// MARK: - Wise Scheduler System
/// Automatischer Mode-Wechsel nach Zeitplan
/// Intelligente Planung basierend auf Tageszeit, Gewohnheiten und Kalender

/// Geplante Mode-Änderung
struct WiseScheduleItem: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var mode: WiseMode
    var presetID: UUID?
    var schedule: ScheduleType
    var isEnabled: Bool
    var notifyBefore: Int // Minuten vor Aktivierung (0 = keine Benachrichtigung)
    var autoStart: Bool
    var createdAt: Date
    var lastTriggered: Date?

    init(
        name: String,
        mode: WiseMode,
        schedule: ScheduleType,
        presetID: UUID? = nil,
        notifyBefore: Int = 5,
        autoStart: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.mode = mode
        self.presetID = presetID
        self.schedule = schedule
        self.isEnabled = true
        self.notifyBefore = notifyBefore
        self.autoStart = autoStart
        self.createdAt = Date()
        self.lastTriggered = nil
    }

    // Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: WiseScheduleItem, rhs: WiseScheduleItem) -> Bool {
        lhs.id == rhs.id
    }
}

/// Zeitplan-Typ
enum ScheduleType: Codable, Hashable {
    case daily(time: TimeOfDay)
    case weekly(days: [Weekday], time: TimeOfDay)
    case specificDate(date: Date)
    case timeRange(start: TimeOfDay, end: TimeOfDay)
    case smart(trigger: SmartTrigger)

    var displayName: String {
        switch self {
        case .daily(let time):
            return "Täglich um \(time.formatted)"
        case .weekly(let days, let time):
            let dayNames = days.map { $0.shortName }.joined(separator: ", ")
            return "\(dayNames) um \(time.formatted)"
        case .specificDate(let date):
            return date.formatted(date: .abbreviated, time: .shortened)
        case .timeRange(let start, let end):
            return "\(start.formatted) - \(end.formatted)"
        case .smart(let trigger):
            return trigger.displayName
        }
    }
}

/// Tageszeit-Struktur
struct TimeOfDay: Codable, Hashable {
    var hour: Int
    var minute: Int

    var formatted: String {
        String(format: "%02d:%02d", hour, minute)
    }

    var date: Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
    }

    static var morning: TimeOfDay { TimeOfDay(hour: 7, minute: 0) }
    static var noon: TimeOfDay { TimeOfDay(hour: 12, minute: 0) }
    static var afternoon: TimeOfDay { TimeOfDay(hour: 15, minute: 0) }
    static var evening: TimeOfDay { TimeOfDay(hour: 19, minute: 0) }
    static var night: TimeOfDay { TimeOfDay(hour: 22, minute: 0) }
}

/// Wochentage
enum Weekday: Int, Codable, CaseIterable, Hashable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var shortName: String {
        switch self {
        case .sunday: return "So"
        case .monday: return "Mo"
        case .tuesday: return "Di"
        case .wednesday: return "Mi"
        case .thursday: return "Do"
        case .friday: return "Fr"
        case .saturday: return "Sa"
        }
    }

    var fullName: String {
        switch self {
        case .sunday: return "Sonntag"
        case .monday: return "Montag"
        case .tuesday: return "Dienstag"
        case .wednesday: return "Mittwoch"
        case .thursday: return "Donnerstag"
        case .friday: return "Freitag"
        case .saturday: return "Samstag"
        }
    }

    static var weekdays: [Weekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday]
    }

    static var weekend: [Weekday] {
        [.saturday, .sunday]
    }
}

/// Smart Trigger für intelligente Aktivierung
enum SmartTrigger: String, Codable, CaseIterable, Hashable {
    case morningRoutine = "Morning Routine"
    case workStart = "Work Start"
    case lunchBreak = "Lunch Break"
    case afternoonSlump = "Afternoon Slump"
    case eveningWindDown = "Evening Wind-Down"
    case bedtime = "Bedtime"
    case lowEnergy = "Low Energy Detected"
    case highStress = "High Stress Detected"
    case optimalFlow = "Optimal Flow Window"

    var displayName: String { rawValue }

    var icon: String {
        switch self {
        case .morningRoutine: return "sunrise"
        case .workStart: return "briefcase"
        case .lunchBreak: return "fork.knife"
        case .afternoonSlump: return "cup.and.saucer"
        case .eveningWindDown: return "sunset"
        case .bedtime: return "moon.zzz"
        case .lowEnergy: return "battery.25"
        case .highStress: return "heart.text.square"
        case .optimalFlow: return "water.waves"
        }
    }

    var suggestedMode: WiseMode {
        switch self {
        case .morningRoutine: return .energize
        case .workStart: return .focus
        case .lunchBreak: return .meditation
        case .afternoonSlump: return .energize
        case .eveningWindDown: return .healing
        case .bedtime: return .sleep
        case .lowEnergy: return .energize
        case .highStress: return .healing
        case .optimalFlow: return .flow
        }
    }
}

// MARK: - Wise Scheduler Manager

/// Verwaltung aller geplanten Mode-Wechsel
@MainActor
class WiseScheduler: ObservableObject {

    // MARK: - Singleton
    static let shared = WiseScheduler()

    // MARK: - Published State

    @Published var scheduleItems: [WiseScheduleItem] = []
    @Published var isSchedulerEnabled: Bool = true
    @Published var nextScheduledItem: WiseScheduleItem?
    @Published var timeUntilNext: TimeInterval = 0

    // MARK: - Private Properties

    private let userDefaults = UserDefaults.standard
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Callbacks

    var onScheduleTriggered: ((WiseScheduleItem) -> Void)?

    // MARK: - Initialization

    private init() {
        loadSchedules()
        setupDefaultSchedulesIfNeeded()
        startScheduler()
        requestNotificationPermission()

        print("⏰ WiseScheduler: Initialized with \(scheduleItems.count) items")
    }

    // MARK: - Schedule Management

    /// Erstellt einen neuen Zeitplan
    func createSchedule(
        name: String,
        mode: WiseMode,
        schedule: ScheduleType,
        presetID: UUID? = nil,
        notifyBefore: Int = 5,
        autoStart: Bool = true
    ) -> WiseScheduleItem {
        let item = WiseScheduleItem(
            name: name,
            mode: mode,
            schedule: schedule,
            presetID: presetID,
            notifyBefore: notifyBefore,
            autoStart: autoStart
        )

        scheduleItems.append(item)
        saveSchedules()
        updateNextScheduledItem()
        scheduleNotification(for: item)

        print("📅 Created schedule: \(name)")
        return item
    }

    /// Aktualisiert einen Zeitplan
    func updateSchedule(_ item: WiseScheduleItem) {
        if let index = scheduleItems.firstIndex(where: { $0.id == item.id }) {
            scheduleItems[index] = item
            saveSchedules()
            updateNextScheduledItem()

            // Reschedule notification
            cancelNotification(for: item)
            if item.isEnabled {
                scheduleNotification(for: item)
            }
        }
    }

    /// Löscht einen Zeitplan
    func deleteSchedule(_ item: WiseScheduleItem) {
        cancelNotification(for: item)
        scheduleItems.removeAll { $0.id == item.id }
        saveSchedules()
        updateNextScheduledItem()

        print("🗑️ Deleted schedule: \(item.name)")
    }

    /// Aktiviert/Deaktiviert einen Zeitplan
    func toggleSchedule(_ item: WiseScheduleItem) {
        if var updatedItem = scheduleItems.first(where: { $0.id == item.id }) {
            updatedItem.isEnabled.toggle()
            updateSchedule(updatedItem)
        }
    }

    // MARK: - Scheduler Logic

    private func startScheduler() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkSchedules()
            }
        }

        // Initial check
        checkSchedules()
    }

    private func checkSchedules() {
        guard isSchedulerEnabled else { return }

        let now = Date()
        let calendar = Calendar.current

        for item in scheduleItems where item.isEnabled {
            if shouldTrigger(item: item, at: now, using: calendar) {
                triggerSchedule(item)
            }
        }

        updateNextScheduledItem()
    }

    private func shouldTrigger(item: WiseScheduleItem, at date: Date, using calendar: Calendar) -> Bool {
        // Prevent re-triggering within same minute
        if let lastTriggered = item.lastTriggered,
           calendar.isDate(lastTriggered, equalTo: date, toGranularity: .minute) {
            return false
        }

        let currentHour = calendar.component(.hour, from: date)
        let currentMinute = calendar.component(.minute, from: date)
        let currentWeekday = calendar.component(.weekday, from: date)

        switch item.schedule {
        case .daily(let time):
            return currentHour == time.hour && currentMinute == time.minute

        case .weekly(let days, let time):
            guard let weekday = Weekday(rawValue: currentWeekday) else { return false }
            return days.contains(weekday) && currentHour == time.hour && currentMinute == time.minute

        case .specificDate(let targetDate):
            return calendar.isDate(date, equalTo: targetDate, toGranularity: .minute)

        case .timeRange(let start, let end):
            let currentTime = currentHour * 60 + currentMinute
            let startTime = start.hour * 60 + start.minute
            let endTime = end.hour * 60 + end.minute
            return currentTime >= startTime && currentTime <= endTime

        case .smart:
            // Smart triggers are handled separately based on bio data
            return false
        }
    }

    private func triggerSchedule(_ item: WiseScheduleItem) {
        var updatedItem = item
        updatedItem.lastTriggered = Date()

        if let index = scheduleItems.firstIndex(where: { $0.id == item.id }) {
            scheduleItems[index] = updatedItem
        }

        saveSchedules()

        // Apply mode change
        if item.autoStart {
            if let presetID = item.presetID,
               let preset = WisePresetManager.shared.presets.first(where: { $0.id == presetID }) {
                WisePresetManager.shared.applyPreset(preset)
            } else {
                WiseModeManager.shared.switchMode(to: item.mode, reason: .scheduled)
            }
        }

        onScheduleTriggered?(item)

        print("⏰ Triggered schedule: \(item.name)")
    }

    /// Prüft Smart Triggers basierend auf Bio-Daten
    func checkSmartTriggers(hrv: Float, coherence: Float, heartRate: Float) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())

        for item in scheduleItems where item.isEnabled {
            if case .smart(let trigger) = item.schedule {
                var shouldTrigger = false

                switch trigger {
                case .morningRoutine:
                    shouldTrigger = hour >= 6 && hour <= 9
                case .workStart:
                    shouldTrigger = hour >= 8 && hour <= 10
                case .lunchBreak:
                    shouldTrigger = hour >= 12 && hour <= 13
                case .afternoonSlump:
                    shouldTrigger = hour >= 14 && hour <= 16 && hrv < 40
                case .eveningWindDown:
                    shouldTrigger = hour >= 18 && hour <= 20
                case .bedtime:
                    shouldTrigger = hour >= 21 && hour <= 23
                case .lowEnergy:
                    shouldTrigger = hrv < 30 && coherence < 0.4
                case .highStress:
                    shouldTrigger = heartRate > 90 && coherence < 0.3
                case .optimalFlow:
                    shouldTrigger = coherence > 0.7 && hrv > 50
                }

                if shouldTrigger {
                    triggerSchedule(item)
                }
            }
        }
    }

    // MARK: - Next Scheduled Item

    private func updateNextScheduledItem() {
        let now = Date()
        let calendar = Calendar.current

        var nearestItem: WiseScheduleItem?
        var nearestTime: Date?

        for item in scheduleItems where item.isEnabled {
            if let nextOccurrence = getNextOccurrence(for: item, after: now, using: calendar) {
                if nearestTime == nil || nextOccurrence < nearestTime! {
                    nearestTime = nextOccurrence
                    nearestItem = item
                }
            }
        }

        nextScheduledItem = nearestItem
        if let time = nearestTime {
            timeUntilNext = time.timeIntervalSince(now)
        } else {
            timeUntilNext = 0
        }
    }

    private func getNextOccurrence(for item: WiseScheduleItem, after date: Date, using calendar: Calendar) -> Date? {
        switch item.schedule {
        case .daily(let time):
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = time.hour
            components.minute = time.minute
            if let nextDate = calendar.date(from: components), nextDate > date {
                return nextDate
            }
            // Next day
            components.day! += 1
            return calendar.date(from: components)

        case .weekly(let days, let time):
            let currentWeekday = calendar.component(.weekday, from: date)
            for offset in 0...7 {
                if let futureDate = calendar.date(byAdding: .day, value: offset, to: date) {
                    let futureWeekday = calendar.component(.weekday, from: futureDate)
                    if let weekday = Weekday(rawValue: futureWeekday), days.contains(weekday) {
                        var components = calendar.dateComponents([.year, .month, .day], from: futureDate)
                        components.hour = time.hour
                        components.minute = time.minute
                        if let nextDate = calendar.date(from: components), nextDate > date {
                            return nextDate
                        }
                    }
                }
            }
            return nil

        case .specificDate(let targetDate):
            return targetDate > date ? targetDate : nil

        case .timeRange(let start, _):
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = start.hour
            components.minute = start.minute
            return calendar.date(from: components)

        case .smart:
            return nil // Smart triggers don't have fixed times
        }
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                print("🔔 Notification permission granted")
            }
        }
    }

    private func scheduleNotification(for item: WiseScheduleItem) {
        guard item.notifyBefore > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Wise Mode"
        content.body = "\(item.name) startet in \(item.notifyBefore) Minuten"
        content.sound = .default

        // Create trigger based on schedule type
        var trigger: UNNotificationTrigger?

        switch item.schedule {
        case .daily(let time):
            var dateComponents = DateComponents()
            dateComponents.hour = time.hour
            dateComponents.minute = max(0, time.minute - item.notifyBefore)
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        case .weekly(let days, let time):
            for day in days {
                var dateComponents = DateComponents()
                dateComponents.weekday = day.rawValue
                dateComponents.hour = time.hour
                dateComponents.minute = max(0, time.minute - item.notifyBefore)
                trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            }

        case .specificDate(let date):
            let notifyDate = date.addingTimeInterval(-Double(item.notifyBefore * 60))
            let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notifyDate)
            trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)

        default:
            break
        }

        if let trigger = trigger {
            let request = UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func cancelNotification(for item: WiseScheduleItem) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [item.id.uuidString])
    }

    // MARK: - Default Schedules

    private func setupDefaultSchedulesIfNeeded() {
        guard scheduleItems.isEmpty else { return }

        // Morning Focus
        _ = createSchedule(
            name: "Morning Focus",
            mode: .focus,
            schedule: .daily(time: TimeOfDay(hour: 9, minute: 0)),
            notifyBefore: 5,
            autoStart: false
        )

        // Lunch Meditation
        _ = createSchedule(
            name: "Lunch Meditation",
            mode: .meditation,
            schedule: .daily(time: TimeOfDay(hour: 12, minute: 30)),
            notifyBefore: 5,
            autoStart: false
        )

        // Evening Wind-Down
        _ = createSchedule(
            name: "Evening Wind-Down",
            mode: .healing,
            schedule: .daily(time: TimeOfDay(hour: 20, minute: 0)),
            notifyBefore: 10,
            autoStart: false
        )

        // Sleep Preparation
        _ = createSchedule(
            name: "Sleep Preparation",
            mode: .sleep,
            schedule: .daily(time: TimeOfDay(hour: 22, minute: 0)),
            notifyBefore: 15,
            autoStart: false
        )

        print("⏰ Created default schedules")
    }

    // MARK: - Persistence

    private func saveSchedules() {
        if let data = try? JSONEncoder().encode(scheduleItems) {
            userDefaults.set(data, forKey: "wiseScheduler.items")
        }
        userDefaults.set(isSchedulerEnabled, forKey: "wiseScheduler.enabled")
    }

    private func loadSchedules() {
        if let data = userDefaults.data(forKey: "wiseScheduler.items"),
           let items = try? JSONDecoder().decode([WiseScheduleItem].self, from: data) {
            scheduleItems = items
        }
        isSchedulerEnabled = userDefaults.bool(forKey: "wiseScheduler.enabled")
    }
}

// MARK: - Schedule Editor View

struct WiseScheduleEditor: View {
    @ObservedObject var scheduler = WiseScheduler.shared
    @State private var showingAddSheet = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Wise Scheduler")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Toggle("", isOn: $scheduler.isSchedulerEnabled)
                    .labelsHidden()

                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }

            // Next Scheduled
            if let next = scheduler.nextScheduledItem {
                NextScheduleCard(item: next, timeUntil: scheduler.timeUntilNext)
            }

            // Schedule List
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(scheduler.scheduleItems) { item in
                        ScheduleItemRow(
                            item: item,
                            onToggle: { scheduler.toggleSchedule(item) },
                            onDelete: { scheduler.deleteSchedule(item) }
                        )
                    }
                }
            }
        }
        .padding()
        .sheet(isPresented: $showingAddSheet) {
            AddScheduleSheet()
        }
    }
}

struct NextScheduleCard: View {
    let item: WiseScheduleItem
    let timeUntil: TimeInterval

    var body: some View {
        HStack {
            Image(systemName: item.mode.icon)
                .font(.title)
                .foregroundColor(item.mode.color)

            VStack(alignment: .leading) {
                Text("Next: \(item.name)")
                    .font(.headline)
                Text(formatTimeUntil(timeUntil))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(item.mode.color.opacity(0.1))
        .cornerRadius(12)
    }

    private func formatTimeUntil(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "In \(hours)h \(minutes)m"
        } else {
            return "In \(minutes) minutes"
        }
    }
}

struct ScheduleItemRow: View {
    let item: WiseScheduleItem
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: item.mode.icon)
                .foregroundColor(item.mode.color)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(item.schedule.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { item.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .opacity(item.isEnabled ? 1.0 : 0.5)
    }
}

struct AddScheduleSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var selectedMode: WiseMode = .focus
    @State private var hour = 9
    @State private var minute = 0
    @State private var selectedDays: Set<Weekday> = Set(Weekday.weekdays)

    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)

                    Picker("Mode", selection: $selectedMode) {
                        ForEach(WiseMode.allCases, id: \.self) { mode in
                            Label(mode.rawValue, systemImage: mode.icon)
                                .tag(mode)
                        }
                    }
                }

                Section("Time") {
                    Stepper("Hour: \(hour)", value: $hour, in: 0...23)
                    Stepper("Minute: \(minute)", value: $minute, in: 0...59, step: 5)
                }

                Section("Days") {
                    ForEach(Weekday.allCases, id: \.self) { day in
                        Toggle(day.fullName, isOn: Binding(
                            get: { selectedDays.contains(day) },
                            set: { isOn in
                                if isOn {
                                    selectedDays.insert(day)
                                } else {
                                    selectedDays.remove(day)
                                }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("New Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let time = TimeOfDay(hour: hour, minute: minute)
                        let schedule: ScheduleType = selectedDays.count == 7
                            ? .daily(time: time)
                            : .weekly(days: Array(selectedDays), time: time)

                        _ = WiseScheduler.shared.createSchedule(
                            name: name.isEmpty ? selectedMode.rawValue : name,
                            mode: selectedMode,
                            schedule: schedule
                        )
                        dismiss()
                    }
                }
            }
        }
    }
}
