import Foundation
import SwiftUI
import Combine

/// Health & Wellness Manager
/// Provides wellness features WITHOUT medical claims
///
/// IMPORTANT DISCLAIMERS:
/// - NOT a medical device
/// - NOT for diagnosis or treatment
/// - NOT a substitute for professional medical advice
/// - For wellness and relaxation purposes only
/// - Always consult healthcare professionals for medical concerns
///
/// Features:
/// - Stress reduction exercises
/// - Breathing guidance
/// - Relaxation sessions
/// - Wellness tracking (subjective)
/// - Educational content
/// - Privacy-first (data stays on device)

// MARK: - Wellness Disclaimers

public struct WellnessDisclaimer {
    public static let general = """
    IMPORTANT DISCLAIMER:

    BLAB is a wellness and creative tool, NOT a medical device.

    • NOT intended for diagnosis, treatment, or prevention of any disease
    • NOT a substitute for professional medical advice
    • NOT FDA approved or clinically validated
    • For relaxation and wellness purposes only

    Biofeedback features are for educational and wellness purposes.
    Always consult qualified healthcare professionals for medical concerns.

    If you experience discomfort, stop use immediately and consult a doctor.
    """

    public static let biofeedback = """
    BIOFEEDBACK DISCLAIMER:

    Heart rate and HRV measurements are for wellness tracking only.

    • May not be medically accurate
    • Not suitable for medical diagnosis
    • Not for monitoring medical conditions

    Do NOT rely on this app for health-critical decisions.
    """

    public static let wellness = """
    WELLNESS DISCLAIMER:

    This app provides relaxation and stress reduction exercises.

    • Results vary by individual
    • Not guaranteed to provide specific benefits
    • Not a replacement for therapy or counseling

    If you have anxiety, depression, or other mental health concerns,
    please seek help from licensed mental health professionals.
    """
}

// MARK: - Wellness Session

public struct WellnessSession: Identifiable, Codable {
    public let id: String
    public let name: String
    public let description: String
    public let category: WellnessCategory
    public let duration: Int // minutes
    public let guidanceType: GuidanceType
    public let benefits: [String] // Carefully worded, non-medical
    public var timesCompleted: Int

    public init(
        id: String,
        name: String,
        description: String,
        category: WellnessCategory,
        duration: Int,
        guidanceType: GuidanceType,
        benefits: [String],
        timesCompleted: Int = 0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.duration = duration
        self.guidanceType = guidanceType
        self.benefits = benefits
        self.timesCompleted = timesCompleted
    }
}

public enum WellnessCategory: String, Codable, CaseIterable {
    case breathwork = "Breathwork"
    case meditation = "Meditation"
    case relaxation = "Relaxation"
    case focus = "Focus"
    case creativity = "Creativity"
    case energy = "Energy"
}

public enum GuidanceType: String, Codable {
    case visual = "Visual"
    case audio = "Audio"
    case combined = "Visual + Audio"
    case self_guided = "Self-Guided"
}

// MARK: - Wellness Tracking (Subjective)

public struct WellnessEntry: Identifiable, Codable {
    public let id: String
    public let date: Date
    public let mood: SubjectiveMood
    public let energyLevel: Int // 1-10
    public let stressLevel: Int // 1-10
    public let note: String?

    // Subjective self-report, NOT medical data
}

public enum SubjectiveMood: String, Codable, CaseIterable {
    case veryGood = "Very Good"
    case good = "Good"
    case neutral = "Neutral"
    case notGreat = "Not Great"
    case difficult = "Difficult"

    public var emoji: String {
        switch self {
        case .veryGood: return "😊"
        case .good: return "🙂"
        case .neutral: return "😐"
        case .notGreat: return "😕"
        case .difficult: return "😔"
        }
    }

    public var color: Color {
        switch self {
        case .veryGood: return .green
        case .good: return .blue
        case .neutral: return .gray
        case .notGreat: return .orange
        case .difficult: return .red
        }
    }
}

// MARK: - Wellness Manager

@MainActor
public final class WellnessManager: ObservableObject {

    public static let shared = WellnessManager()

    // MARK: - Published Properties

    @Published public var sessions: [WellnessSession]
    @Published public var wellnessEntries: [WellnessEntry]
    @Published public var disclaimerAccepted: Bool
    @Published public var showDisclaimerAlert: Bool = false

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // Predefined wellness sessions
    private let defaultSessions: [WellnessSession] = [
        WellnessSession(
            id: "calm_breath",
            name: "Calm Breathing",
            description: "Simple breathing exercise for relaxation",
            category: .breathwork,
            duration: 5,
            guidanceType: .visual,
            benefits: [
                "May help promote relaxation",
                "Practice mindful breathing",
                "Simple stress reduction technique"
            ]
        ),
        WellnessSession(
            id: "deep_relax",
            name: "Deep Relaxation",
            description: "Guided relaxation with biofeedback",
            category: .relaxation,
            duration: 15,
            guidanceType: .combined,
            benefits: [
                "Practice deep relaxation",
                "Visual feedback for awareness",
                "Peaceful experience"
            ]
        ),
        WellnessSession(
            id: "morning_energy",
            name: "Morning Energy",
            description: "Energizing session to start your day",
            category: .energy,
            duration: 10,
            guidanceType: .audio,
            benefits: [
                "Uplifting experience",
                "Feel more awake",
                "Positive start to the day"
            ]
        ),
        WellnessSession(
            id: "creative_flow",
            name: "Creative Flow",
            description: "Session designed for creative exploration",
            category: .creativity,
            duration: 20,
            guidanceType: .self_guided,
            benefits: [
                "Explore creative expression",
                "Open-ended exploration",
                "Playful experience"
            ]
        ),
        WellnessSession(
            id: "focus_session",
            name: "Focus Session",
            description: "Improve concentration and attention",
            category: .focus,
            duration: 15,
            guidanceType: .visual,
            benefits: [
                "Practice sustained attention",
                "Reduce distractions",
                "Calm, focused state"
            ]
        ),
        WellnessSession(
            id: "mindful_moment",
            name: "Mindful Moment",
            description: "Quick mindfulness practice",
            category: .meditation,
            duration: 3,
            guidanceType: .visual,
            benefits: [
                "Brief mindfulness practice",
                "Reset your attention",
                "Present moment awareness"
            ]
        ),
    ]

    // MARK: - Initialization

    private init() {
        sessions = defaultSessions
        wellnessEntries = Self.loadWellnessEntries()
        disclaimerAccepted = UserDefaults.standard.bool(forKey: "WellnessDisclaimerAccepted")

        print("🧘 Wellness Manager initialized")
        print("   Sessions available: \(sessions.count)")
        print("   Disclaimer accepted: \(disclaimerAccepted ? "✅" : "❌")")
    }

    // MARK: - Disclaimer Management

    public func showDisclaimer() {
        showDisclaimerAlert = true
    }

    public func acceptDisclaimer() {
        disclaimerAccepted = true
        UserDefaults.standard.set(true, forKey: "WellnessDisclaimerAccepted")
        showDisclaimerAlert = false

        print("✅ Wellness disclaimer accepted")
    }

    public func requireDisclaimerIfNeeded() {
        if !disclaimerAccepted {
            showDisclaimer()
        }
    }

    // MARK: - Session Management

    public func startWellnessSession(_ sessionID: String) {
        requireDisclaimerIfNeeded()

        guard disclaimerAccepted else {
            print("⚠️ Cannot start wellness session without accepting disclaimer")
            return
        }

        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return
        }

        print("🧘 Starting wellness session: \(sessions[index].name)")

        // Track completion
        NotificationCenter.default.post(
            name: .wellnessSessionStarted,
            object: sessions[index]
        )
    }

    public func completeWellnessSession(_ sessionID: String) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionID }) else {
            return
        }

        sessions[index].timesCompleted += 1
        saveSessions()

        // Award XP
        GamificationManager.shared.addXP(sessions[index].duration * 10)

        print("✅ Completed wellness session: \(sessions[index].name)")

        NotificationCenter.default.post(
            name: .wellnessSessionCompleted,
            object: sessions[index]
        )
    }

    // MARK: - Wellness Tracking

    public func addWellnessEntry(_ entry: WellnessEntry) {
        wellnessEntries.append(entry)
        saveWellnessEntries()

        print("📝 Wellness entry added (Mood: \(entry.mood.rawValue))")
    }

    public func getRecentMoodTrend(days: Int = 7) -> [SubjectiveMood] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        return wellnessEntries
            .filter { $0.date >= cutoffDate }
            .sorted { $0.date < $1.date }
            .map { $0.mood }
    }

    public func getAverageStressLevel(days: Int = 7) -> Double? {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()

        let recentEntries = wellnessEntries.filter { $0.date >= cutoffDate }

        guard !recentEntries.isEmpty else { return nil }

        let sum = recentEntries.map { $0.stressLevel }.reduce(0, +)
        return Double(sum) / Double(recentEntries.count)
    }

    // MARK: - Persistence

    private func saveSessions() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: "WellnessSessions")
        }
    }

    private func saveWellnessEntries() {
        if let encoded = try? JSONEncoder().encode(wellnessEntries) {
            UserDefaults.standard.set(encoded, forKey: "WellnessEntries")
        }
    }

    private static func loadWellnessEntries() -> [WellnessEntry] {
        guard let data = UserDefaults.standard.data(forKey: "WellnessEntries"),
              let entries = try? JSONDecoder().decode([WellnessEntry].self, from: data) else {
            return []
        }
        return entries
    }

    // MARK: - Privacy & Export

    public func exportWellnessData() -> String {
        // Export user's wellness data (for personal use, HIPAA-like privacy)
        var csv = "Date,Mood,Energy Level,Stress Level,Note\n"

        for entry in wellnessEntries {
            let dateStr = ISO8601DateFormatter().string(from: entry.date)
            let note = entry.note?.replacingOccurrences(of: ",", with: ";") ?? ""
            csv += "\(dateStr),\(entry.mood.rawValue),\(entry.energyLevel),\(entry.stressLevel),\(note)\n"
        }

        return csv
    }

    public func deleteAllWellnessData() {
        wellnessEntries.removeAll()
        UserDefaults.standard.removeObject(forKey: "WellnessEntries")

        print("🗑️ All wellness data deleted")
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let wellnessSessionStarted = Notification.Name("WellnessSessionStarted")
    static let wellnessSessionCompleted = Notification.Name("WellnessSessionCompleted")
}

// MARK: - SwiftUI Views

/// Disclaimer Alert View
public struct WellnessDisclaimerView: View {
    @ObservedObject private var wellnessManager = WellnessManager.shared
    let onAccept: () -> Void

    public init(onAccept: @escaping () -> Void) {
        self.onAccept = onAccept
    }

    public var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Important Disclaimer")
                .font(.title)
                .bold()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(WellnessDisclaimer.general)
                        .font(.body)

                    Divider()

                    Text(WellnessDisclaimer.biofeedback)
                        .font(.body)

                    Divider()

                    Text(WellnessDisclaimer.wellness)
                        .font(.body)
                }
                .padding()
            }
            .frame(maxHeight: 400)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)

            Button(action: {
                wellnessManager.acceptDisclaimer()
                onAccept()
            }) {
                Text("I Understand and Accept")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

/// Wellness Session Card
public struct WellnessSessionCard: View {
    let session: WellnessSession
    let onStart: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(session.name)
                    .font(.headline)

                Spacer()

                Text("\(session.duration) min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(session.description)
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(session.benefits, id: \.self) { benefit in
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text(benefit)
                            .font(.caption)
                    }
                }
            }

            Button(action: onStart) {
                Text("Start Session")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}
