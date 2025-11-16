import SwiftUI

/// Session History View - Browse and manage past sessions
/// Shows recorded sessions with auto-generated highlights and export options
struct SessionHistoryView: View {

    // MARK: - Environment Objects

    @EnvironmentObject var recordingEngine: RecordingEngine
    @EnvironmentObject var healthKitManager: HealthKitManager

    // MARK: - State

    @State private var sessions: [SessionRecord] = SessionRecord.mockSessions
    @State private var selectedSession: SessionRecord?
    @State private var showExportOptions = false
    @State private var searchText = ""
    @State private var filterMode: FilterMode = .all

    // MARK: - Filter Mode

    enum FilterMode: String, CaseIterable {
        case all = "All"
        case today = "Today"
        case week = "This Week"
        case month = "This Month"
        case highlights = "Highlights"

        var icon: String {
            switch self {
            case .all: return "square.grid.2x2.fill"
            case .today: return "calendar"
            case .week: return "calendar.badge.clock"
            case .month: return "calendar.circle.fill"
            case .highlights: return "star.fill"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.05, blue: 0.15), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {

                    // MARK: - Search Bar
                    searchBar

                    // MARK: - Filter Pills
                    filterPills

                    // MARK: - Sessions Grid
                    sessionsGrid

                }
            }
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedSession) { session in
                sessionDetailSheet(session: session)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.5))

            TextField("Search sessions...", text: $searchText)
                .foregroundColor(.white)
                .accentColor(.cyan)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.1))
        )
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Filter Pills

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(FilterMode.allCases, id: \.self) { mode in
                    Button(action: { filterMode = mode }) {
                        HStack(spacing: 6) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 12))

                            Text(mode.rawValue)
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(filterMode == mode ? .black : .white.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(filterMode == mode ? Color.cyan : Color.white.opacity(0.1))
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Sessions Grid

    private var sessionsGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ],
                spacing: 16
            ) {
                ForEach(filteredSessions) { session in
                    sessionCard(session: session)
                        .onTapGesture {
                            selectedSession = session
                        }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Session Card

    private func sessionCard(session: SessionRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {

            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: session.visualMode.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 140)

                // Play button overlay
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "play.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 20))
                    )

                // Highlight badge
                if session.hasHighlights {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 14))
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.7))
                                )
                                .padding(8)
                        }
                        Spacer()
                    }
                }
            }

            // Session info
            VStack(alignment: .leading, spacing: 6) {
                Text(session.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    // Duration
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(formatDuration(session.duration))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.white.opacity(0.6))

                    // Date
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                        Text(formatDate(session.date))
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.white.opacity(0.6))
                }

                // Biometric stats
                HStack(spacing: 8) {
                    biometricBadge(
                        icon: "heart.fill",
                        value: "\(session.avgHeartRate)",
                        color: .red
                    )

                    biometricBadge(
                        icon: "waveform.path.ecg",
                        value: "\(session.avgCoherence)",
                        color: .green
                    )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }

    // MARK: - Session Detail Sheet

    private func sessionDetailSheet(session: SessionRecord) -> some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // Video Preview
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: session.visualMode.gradientColors,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 220)

                            Circle()
                                .fill(Color.black.opacity(0.6))
                                .frame(width: 70, height: 70)
                                .overlay(
                                    Image(systemName: "play.fill")
                                        .foregroundColor(.white)
                                        .font(.system(size: 30))
                                )
                        }
                        .padding(.horizontal, 20)

                        // Session Stats
                        VStack(spacing: 16) {
                            statsRow(
                                icon: "clock.fill",
                                label: "Duration",
                                value: formatDuration(session.duration),
                                color: .cyan
                            )

                            statsRow(
                                icon: "heart.fill",
                                label: "Avg Heart Rate",
                                value: "\(session.avgHeartRate) BPM",
                                color: .red
                            )

                            statsRow(
                                icon: "waveform.path.ecg",
                                label: "Avg Coherence",
                                value: "\(session.avgCoherence)%",
                                color: .green
                            )

                            statsRow(
                                icon: "flame.fill",
                                label: "Peak Moments",
                                value: "\(session.peakMoments)",
                                color: .orange
                            )
                        }
                        .padding(.horizontal, 20)

                        // Highlights
                        if session.hasHighlights {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Auto-Generated Highlights")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(0..<3, id: \.self) { index in
                                            highlightCard(index: index)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }

                        // Export Options
                        VStack(spacing: 12) {
                            Text("Export & Share")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            exportButton(
                                icon: "square.and.arrow.up.fill",
                                title: "Export Full Session",
                                subtitle: "MP4 + Audio Track"
                            )

                            exportButton(
                                icon: "scissors",
                                title: "Export Highlights Only",
                                subtitle: "Best moments as short clips"
                            )

                            exportButton(
                                icon: "rectangle.stack.fill",
                                title: "Create Reels/Shorts",
                                subtitle: "Platform-optimized 15-60s clips"
                            )

                            exportButton(
                                icon: "music.note",
                                title: "Audio Only",
                                subtitle: "WAV or MP3 format"
                            )
                        }
                        .padding(.horizontal, 20)

                        // Delete Session Button
                        Button(action: {}) {
                            Label("Delete Session", systemImage: "trash")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.red.opacity(0.1))
                                )
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .padding(.top, 20)
                }
            }
            .navigationTitle(session.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selectedSession = nil
                    }
                }
            }
        }
    }

    // MARK: - Helper Views

    private func biometricBadge(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }

    private func statsRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)

                Text(label)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func highlightCard(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cyan.opacity(0.3))
                    .frame(width: 140, height: 100)

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }

            Text("Peak Moment \(index + 1)")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            Text("0:\(15 + index * 10)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(width: 140)
    }

    private func exportButton(icon: String, title: String, subtitle: String) -> some View {
        Button(action: {}) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.cyan)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }

    // MARK: - Computed Properties

    private var filteredSessions: [SessionRecord] {
        sessions.filter { session in
            if !searchText.isEmpty {
                return session.name.localizedCaseInsensitiveContains(searchText)
            }

            switch filterMode {
            case .all:
                return true
            case .today:
                return Calendar.current.isDateInToday(session.date)
            case .week:
                return Calendar.current.isDate(session.date, equalTo: Date(), toGranularity: .weekOfYear)
            case .month:
                return Calendar.current.isDate(session.date, equalTo: Date(), toGranularity: .month)
            case .highlights:
                return session.hasHighlights
            }
        }
    }

    // MARK: - Helper Functions

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Session Record Model

struct SessionRecord: Identifiable {
    let id = UUID()
    var name: String
    var date: Date
    var duration: Int // seconds
    var avgHeartRate: Int
    var avgCoherence: Int
    var peakMoments: Int
    var visualMode: VisualizationMode
    var hasHighlights: Bool

    static var mockSessions: [SessionRecord] {
        [
            SessionRecord(
                name: "Morning Flow",
                date: Date(),
                duration: 1245,
                avgHeartRate: 72,
                avgCoherence: 78,
                peakMoments: 5,
                visualMode: .particles,
                hasHighlights: true
            ),
            SessionRecord(
                name: "Deep Meditation",
                date: Date().addingTimeInterval(-86400),
                duration: 1820,
                avgHeartRate: 58,
                avgCoherence: 92,
                peakMoments: 8,
                visualMode: .mandala,
                hasHighlights: true
            ),
            SessionRecord(
                name: "Creative Session",
                date: Date().addingTimeInterval(-172800),
                duration: 980,
                avgHeartRate: 85,
                avgCoherence: 65,
                peakMoments: 3,
                visualMode: .cymatics,
                hasHighlights: false
            ),
            SessionRecord(
                name: "Night Vibes",
                date: Date().addingTimeInterval(-259200),
                duration: 1560,
                avgHeartRate: 68,
                avgCoherence: 82,
                peakMoments: 6,
                visualMode: .spectral,
                hasHighlights: true
            ),
            SessionRecord(
                name: "Breath Work",
                date: Date().addingTimeInterval(-345600),
                duration: 720,
                avgHeartRate: 62,
                avgCoherence: 88,
                peakMoments: 4,
                visualMode: .waveform,
                hasHighlights: false
            ),
            SessionRecord(
                name: "Energy Boost",
                date: Date().addingTimeInterval(-432000),
                duration: 540,
                avgHeartRate: 98,
                avgCoherence: 55,
                peakMoments: 2,
                visualMode: .particles,
                hasHighlights: false
            )
        ]
    }
}

// MARK: - VisualizationMode Extension

extension VisualizationMode {
    var gradientColors: [Color] {
        switch self {
        case .particles:
            return [.cyan, .blue]
        case .cymatics:
            return [.purple, .pink]
        case .waveform:
            return [.green, .cyan]
        case .spectral:
            return [.orange, .red]
        case .mandala:
            return [.pink, .purple]
        }
    }
}

// MARK: - Preview

#Preview {
    SessionHistoryView()
        .environmentObject(RecordingEngine())
        .environmentObject(HealthKitManager())
}
