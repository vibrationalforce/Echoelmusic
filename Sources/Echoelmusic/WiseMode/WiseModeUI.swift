import SwiftUI
import WidgetKit

// MARK: - Wise Mode UI Components
/// Widget, Watch Complication und Haptic Feedback

// MARK: - Home Screen Widget

/// Widget Entry für Wise Mode
struct WiseModeWidgetEntry: TimelineEntry {
    let date: Date
    let mode: WiseMode
    let wisdomLevel: WisdomLevel
    let todaySessions: Int
    let todayMinutes: Int
    let currentCoherence: Float
    let streakDays: Int
}

/// Widget Provider
struct WiseModeWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> WiseModeWidgetEntry {
        WiseModeWidgetEntry(
            date: Date(),
            mode: .focus,
            wisdomLevel: .learning,
            todaySessions: 3,
            todayMinutes: 45,
            currentCoherence: 0.65,
            streakDays: 7
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WiseModeWidgetEntry) -> Void) {
        let entry = placeholder(in: context)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WiseModeWidgetEntry>) -> Void) {
        let currentDate = Date()
        let userDefaults = UserDefaults(suiteName: "group.com.echoelmusic.wise")

        let mode = WiseMode(rawValue: userDefaults?.string(forKey: "currentMode") ?? "Focus") ?? .focus
        let wisdomLevel = WisdomLevel(rawValue: userDefaults?.integer(forKey: "wisdomLevel") ?? 0) ?? .novice
        let todaySessions = userDefaults?.integer(forKey: "todaySessions") ?? 0
        let todayMinutes = userDefaults?.integer(forKey: "todayMinutes") ?? 0
        let currentCoherence = userDefaults?.float(forKey: "currentCoherence") ?? 0
        let streakDays = userDefaults?.integer(forKey: "streakDays") ?? 0

        let entry = WiseModeWidgetEntry(
            date: currentDate,
            mode: mode,
            wisdomLevel: wisdomLevel,
            todaySessions: todaySessions,
            todayMinutes: todayMinutes,
            currentCoherence: currentCoherence,
            streakDays: streakDays
        )

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate) ?? currentDate
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

/// Small Widget View
struct WiseModeWidgetSmall: View {
    let entry: WiseModeWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: entry.mode.icon)
                    .font(.title2)
                    .foregroundColor(entry.mode.color)
                Spacer()
                Image(systemName: entry.wisdomLevel.icon)
                    .font(.caption)
                    .foregroundColor(entry.wisdomLevel.color)
            }

            Text(entry.mode.rawValue)
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            HStack {
                Label("\(entry.todayMinutes)m", systemImage: "clock")
                    .font(.caption2)
                Spacer()
                if entry.streakDays > 0 {
                    Label("\(entry.streakDays)", systemImage: "flame")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
    }
}

/// Medium Widget View
struct WiseModeWidgetMedium: View {
    let entry: WiseModeWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left: Current Mode
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: entry.mode.icon)
                    .font(.largeTitle)
                    .foregroundColor(entry.mode.color)

                Text(entry.mode.rawValue)
                    .font(.headline)

                Text(entry.mode.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            // Right: Stats
            VStack(alignment: .leading, spacing: 6) {
                StatRow(icon: "brain", label: "Level", value: entry.wisdomLevel.displayName)
                StatRow(icon: "clock", label: "Today", value: "\(entry.todayMinutes)m")
                StatRow(icon: "play.circle", label: "Sessions", value: "\(entry.todaySessions)")
                StatRow(icon: "flame", label: "Streak", value: "\(entry.streakDays) days")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
}

/// Large Widget View
struct WiseModeWidgetLarge: View {
    let entry: WiseModeWidgetEntry

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Wise Mode")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(entry.mode.rawValue)
                        .font(.title)
                        .fontWeight(.bold)
                }

                Spacer()

                Image(systemName: entry.mode.icon)
                    .font(.system(size: 40))
                    .foregroundColor(entry.mode.color)
            }

            Divider()

            // Coherence Ring
            CoherenceRingView(coherence: entry.currentCoherence)
                .frame(height: 100)

            Divider()

            // Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                WidgetStatCard(icon: "brain", title: "Wisdom", value: entry.wisdomLevel.displayName, color: entry.wisdomLevel.color)
                WidgetStatCard(icon: "flame", title: "Streak", value: "\(entry.streakDays) days", color: .orange)
                WidgetStatCard(icon: "clock", title: "Today", value: "\(entry.todayMinutes)m", color: .blue)
                WidgetStatCard(icon: "play.circle", title: "Sessions", value: "\(entry.todaySessions)", color: .green)
            }
        }
        .padding()
    }
}

struct StatRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct WidgetStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct CoherenceRingView: View {
    let coherence: Float

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 10)

            // Progress ring
            Circle()
                .trim(from: 0, to: CGFloat(coherence))
                .stroke(coherenceColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Center text
            VStack(spacing: 2) {
                Text("\(Int(coherence * 100))%")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Coherence")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    var coherenceColor: Color {
        if coherence >= 0.7 {
            return .green
        } else if coherence >= 0.4 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Watch Complication Views

/// Wisdom Level Watch Complication
struct WisdomLevelComplication: View {
    let level: WisdomLevel
    let progress: Float

    var body: some View {
        ZStack {
            // Progress arc
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(level.color, lineWidth: 4)
                .rotationEffect(.degrees(-90))

            // Icon
            Image(systemName: level.icon)
                .font(.title3)
                .foregroundColor(level.color)
        }
    }
}

/// Circular Complication (small)
struct WiseModeCircularComplication: View {
    let mode: WiseMode
    let coherence: Float

    var body: some View {
        ZStack {
            Circle()
                .fill(mode.color.opacity(0.3))

            Image(systemName: mode.icon)
                .font(.title2)
                .foregroundColor(mode.color)
        }
    }
}

/// Rectangular Complication (medium)
struct WiseModeRectangularComplication: View {
    let mode: WiseMode
    let todayMinutes: Int
    let streakDays: Int

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: mode.icon)
                .font(.title2)
                .foregroundColor(mode.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(mode.rawValue)
                    .font(.headline)
                HStack(spacing: 4) {
                    Label("\(todayMinutes)m", systemImage: "clock")
                    if streakDays > 0 {
                        Label("\(streakDays)", systemImage: "flame")
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Haptic Feedback System

/// Wise Haptic Feedback Manager
@MainActor
class WiseHapticFeedbackManager: ObservableObject {

    // MARK: - Singleton
    static let shared = WiseHapticFeedbackManager()

    // MARK: - State

    @Published var isEnabled: Bool = true
    @Published var intensity: Float = 0.6

    // MARK: - Feedback Generators
    #if os(iOS)
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    #endif

    // MARK: - Initialization

    private init() {
        prepareGenerators()
    }

    private func prepareGenerators() {
        #if os(iOS)
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
        #endif
    }

    // MARK: - Mode Change Haptics

    /// Haptic für Mode-Wechsel
    func modeChangeHaptic(to mode: WiseMode) {
        guard isEnabled else { return }

        #if os(iOS)
        switch mode {
        case .focus:
            // Sharp, focused pattern
            impactHeavy.impactOccurred(intensity: CGFloat(intensity))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.impactMedium.impactOccurred(intensity: CGFloat(self.intensity * 0.7))
            }

        case .flow:
            // Smooth wave pattern
            for i in 0..<3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                    self.impactLight.impactOccurred(intensity: CGFloat(self.intensity * (1 - Float(i) * 0.2)))
                }
            }

        case .healing:
            // Gentle pulsing
            impactLight.impactOccurred(intensity: CGFloat(intensity * 0.5))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.impactLight.impactOccurred(intensity: CGFloat(self.intensity * 0.3))
            }

        case .meditation:
            // Single soft impact
            impactLight.impactOccurred(intensity: CGFloat(intensity * 0.4))

        case .energize:
            // Quick bursts
            for i in 0..<4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) {
                    self.impactMedium.impactOccurred(intensity: CGFloat(self.intensity))
                }
            }

        case .sleep:
            // Very gentle fade
            impactLight.impactOccurred(intensity: CGFloat(intensity * 0.3))

        case .social:
            // Friendly double tap
            impactMedium.impactOccurred(intensity: CGFloat(intensity * 0.7))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.impactMedium.impactOccurred(intensity: CGFloat(self.intensity * 0.7))
            }

        case .custom:
            // Standard feedback
            impactMedium.impactOccurred(intensity: CGFloat(intensity))
        }
        #endif
    }

    // MARK: - Coherence Haptics

    /// Haptic für Kohärenz-Erreichen
    func coherenceAchievedHaptic(level: Float) {
        guard isEnabled else { return }

        #if os(iOS)
        if level >= 0.9 {
            // Excellent coherence
            notificationGenerator.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.notificationGenerator.notificationOccurred(.success)
            }
        } else if level >= 0.7 {
            // Good coherence
            notificationGenerator.notificationOccurred(.success)
        } else if level >= 0.5 {
            // Moderate coherence
            impactMedium.impactOccurred(intensity: CGFloat(intensity * 0.6))
        }
        #endif
    }

    /// Periodisches Kohärenz-Feedback während Session
    func coherencePulseHaptic(coherence: Float) {
        guard isEnabled, coherence > 0.5 else { return }

        #if os(iOS)
        let pulseIntensity = CGFloat(intensity * coherence)
        impactLight.impactOccurred(intensity: pulseIntensity)
        #endif
    }

    // MARK: - UI Interaction Haptics

    /// Haptic für Button-Tap
    func buttonTapHaptic() {
        guard isEnabled else { return }

        #if os(iOS)
        impactLight.impactOccurred(intensity: CGFloat(intensity * 0.5))
        #endif
    }

    /// Haptic für Slider-Änderung
    func sliderChangeHaptic() {
        guard isEnabled else { return }

        #if os(iOS)
        selectionGenerator.selectionChanged()
        #endif
    }

    /// Haptic für Erfolg
    func successHaptic() {
        guard isEnabled else { return }

        #if os(iOS)
        notificationGenerator.notificationOccurred(.success)
        #endif
    }

    /// Haptic für Warnung
    func warningHaptic() {
        guard isEnabled else { return }

        #if os(iOS)
        notificationGenerator.notificationOccurred(.warning)
        #endif
    }

    /// Haptic für Fehler
    func errorHaptic() {
        guard isEnabled else { return }

        #if os(iOS)
        notificationGenerator.notificationOccurred(.error)
        #endif
    }

    // MARK: - Wisdom Level Haptics

    /// Haptic für Level-Up
    func levelUpHaptic(newLevel: WisdomLevel) {
        guard isEnabled else { return }

        #if os(iOS)
        // Celebration pattern
        notificationGenerator.notificationOccurred(.success)

        for i in 1...newLevel.rawValue {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                self.impactMedium.impactOccurred(intensity: CGFloat(self.intensity))
            }
        }
        #endif
    }
}

// MARK: - Main Wise Mode View

/// Hauptansicht für Wise Mode Selection
struct WiseModeSelectionView: View {
    @ObservedObject var manager = WiseModeManager.shared
    @ObservedObject var haptics = WiseHapticFeedbackManager.shared

    var body: some View {
        VStack(spacing: 20) {
            // Current Mode Header
            CurrentModeHeader(mode: manager.currentMode, wisdomLevel: manager.wisdomLevel)

            // Mode Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(WiseMode.allCases, id: \.self) { mode in
                    WiseModeCard(
                        mode: mode,
                        isSelected: mode == manager.currentMode,
                        isTransitioning: manager.isTransitioning
                    ) {
                        haptics.buttonTapHaptic()
                        manager.switchMode(to: mode)
                    }
                }
            }

            // Quick Actions
            QuickActionsRow()
        }
        .padding()
        .onChange(of: manager.currentMode) { _, newMode in
            haptics.modeChangeHaptic(to: newMode)
        }
    }
}

struct CurrentModeHeader: View {
    let mode: WiseMode
    let wisdomLevel: WisdomLevel

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Current Mode")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(mode.rawValue)
                    .font(.title)
                    .fontWeight(.bold)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Image(systemName: wisdomLevel.icon)
                    .foregroundColor(wisdomLevel.color)
                Text(wisdomLevel.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(mode.color.opacity(0.1))
        .cornerRadius(16)
    }
}

struct WiseModeCard: View {
    let mode: WiseMode
    let isSelected: Bool
    let isTransitioning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: mode.icon)
                    .font(.system(size: 32))
                    .foregroundColor(isSelected ? .white : mode.color)

                Text(mode.rawValue)
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)

                Text(mode.description)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? mode.color : Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: isSelected ? mode.color.opacity(0.3) : .clear, radius: 8, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(mode.color.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
            )
            .scaleEffect(isTransitioning && isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
        .disabled(isTransitioning)
    }
}

struct QuickActionsRow: View {
    @ObservedObject var manager = WiseModeManager.shared

    var body: some View {
        HStack(spacing: 12) {
            QuickActionButton(icon: "brain.head.profile", title: "Focus", color: .cyan) {
                manager.quickFocus()
            }

            QuickActionButton(icon: "water.waves", title: "Flow", color: .blue) {
                manager.quickFlow()
            }

            QuickActionButton(icon: "figure.mind.and.body", title: "Meditate", color: .purple) {
                manager.quickMeditation()
            }

            QuickActionButton(icon: "moon.zzz", title: "Sleep", color: .indigo) {
                manager.quickSleep()
            }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
