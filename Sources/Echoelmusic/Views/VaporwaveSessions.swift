import SwiftUI

// MARK: - Vaporwave Sessions View
// Session Browser und History im Vaporwave Palace Style

struct VaporwaveSessions: View {

    // MARK: - Environment

    @EnvironmentObject var recordingEngine: RecordingEngine
    @Environment(\.dismiss) var dismiss

    // MARK: - State

    @State private var selectedFilter: SessionFilter = .all
    @State private var searchText = ""
    @State private var selectedSession: Session? = nil
    @State private var showExport = false

    enum SessionFilter: String, CaseIterable {
        case all = "ALL"
        case focus = "FOCUS"
        case create = "CREATE"
        case heal = "HEAL"
        case live = "LIVE"

        var color: Color {
            switch self {
            case .all: return VaporwaveColors.textPrimary
            case .focus: return VaporwaveColors.neonCyan
            case .create: return VaporwaveColors.neonPurple
            case .heal: return VaporwaveColors.coherenceHigh
            case .live: return VaporwaveColors.neonPink
            }
        }
    }

    // MARK: - Mock Data

    struct Session: Identifiable {
        let id = UUID()
        let name: String
        let date: Date
        let duration: TimeInterval
        let mode: SessionFilter
        let avgCoherence: Double
        let peakCoherence: Double
        let avgHRV: Double
    }

    private var mockSessions: [Session] {
        [
            Session(name: "Morning Flow", date: Date().addingTimeInterval(-3600), duration: 1800, mode: .focus, avgCoherence: 72, peakCoherence: 89, avgHRV: 58),
            Session(name: "Beat Session", date: Date().addingTimeInterval(-86400), duration: 3600, mode: .create, avgCoherence: 65, peakCoherence: 78, avgHRV: 52),
            Session(name: "Evening Heal", date: Date().addingTimeInterval(-172800), duration: 1200, mode: .heal, avgCoherence: 81, peakCoherence: 94, avgHRV: 68),
            Session(name: "Live @ Sisyphos", date: Date().addingTimeInterval(-259200), duration: 7200, mode: .live, avgCoherence: 58, peakCoherence: 85, avgHRV: 45),
            Session(name: "Deep Focus", date: Date().addingTimeInterval(-345600), duration: 2400, mode: .focus, avgCoherence: 76, peakCoherence: 91, avgHRV: 62),
            Session(name: "Nia9ara Recording", date: Date().addingTimeInterval(-432000), duration: 5400, mode: .create, avgCoherence: 69, peakCoherence: 82, avgHRV: 55),
        ]
    }

    private var filteredSessions: [Session] {
        mockSessions.filter { session in
            (selectedFilter == .all || session.mode == selectedFilter) &&
            (searchText.isEmpty || session.name.localizedCaseInsensitiveContains(searchText))
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                VaporwaveGradients.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Filter Pills
                    filterBar

                    // Search
                    searchBar

                    // Sessions List
                    sessionsList
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("SESSIONS")
                        .font(VaporwaveTypography.sectionTitle())
                        .foregroundColor(VaporwaveColors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(VaporwaveColors.textSecondary)
                    }
                    .accessibilityLabel("Close sessions")
                }
            }
            .sheet(item: $selectedSession) { session in
                SessionDetailView(session: session)
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VaporwaveSpacing.sm) {
                ForEach(SessionFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        withAnimation(VaporwaveAnimation.smooth) {
                            selectedFilter = filter
                        }
                    }) {
                        Text(filter.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(selectedFilter == filter ? filter.color : VaporwaveColors.textTertiary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedFilter == filter ? filter.color.opacity(0.2) : Color.clear)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selectedFilter == filter ? filter.color.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .accessibilityLabel("\(filter.rawValue) filter")
                    .accessibilityAddTraits(selectedFilter == filter ? .isSelected : [])
                }
            }
            .padding(.horizontal, VaporwaveSpacing.lg)
            .padding(.vertical, VaporwaveSpacing.md)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: VaporwaveSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(VaporwaveColors.textTertiary)

            TextField("Search sessions...", text: $searchText)
                .font(VaporwaveTypography.body())
                .foregroundColor(VaporwaveColors.textPrimary)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(VaporwaveColors.textTertiary)
                }
            }
        }
        .padding(VaporwaveSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .padding(.horizontal, VaporwaveSpacing.lg)
        .padding(.bottom, VaporwaveSpacing.md)
    }

    // MARK: - Sessions List

    private var sessionsList: some View {
        ScrollView {
            LazyVStack(spacing: VaporwaveSpacing.md) {
                ForEach(filteredSessions) { session in
                    SessionCard(session: session)
                        .onTapGesture {
                            selectedSession = session
                        }
                }
            }
            .padding(.horizontal, VaporwaveSpacing.lg)
            .padding(.bottom, VaporwaveSpacing.xl)
        }
    }

    // MARK: - Session Card

    struct SessionCard: View {
        let session: Session

        private var dateFormatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter
        }

        private var durationString: String {
            let hours = Int(session.duration) / 3600
            let minutes = (Int(session.duration) % 3600) / 60
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(minutes)m"
        }

        var body: some View {
            HStack(spacing: VaporwaveSpacing.md) {
                // Mode indicator
                Circle()
                    .fill(session.mode.color)
                    .frame(width: 8, height: 8)
                    .neonGlow(color: session.mode.color, radius: 5)

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.name)
                        .font(VaporwaveTypography.body())
                        .foregroundColor(VaporwaveColors.textPrimary)

                    Text(dateFormatter.string(from: session.date))
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }

                Spacer()

                // Stats
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("\(Int(session.avgCoherence))")
                            .font(VaporwaveTypography.dataSmall())
                            .foregroundColor(coherenceColor(session.avgCoherence))
                        Text("avg")
                            .font(VaporwaveTypography.label())
                            .foregroundColor(VaporwaveColors.textTertiary)
                    }

                    Text(durationString)
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
            .padding(VaporwaveSpacing.md)
            .glassCard()
        }

        private func coherenceColor(_ score: Double) -> Color {
            if score < 40 { return VaporwaveColors.coherenceLow }
            else if score < 60 { return VaporwaveColors.coherenceMedium }
            else { return VaporwaveColors.coherenceHigh }
        }
    }

    // MARK: - Session Detail View

    struct SessionDetailView: View {
        let session: Session
        @Environment(\.dismiss) var dismiss
        @State private var showExport = false

        var body: some View {
            ZStack {
                VaporwaveGradients.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: VaporwaveSpacing.xl) {
                        // Header
                        VStack(spacing: VaporwaveSpacing.sm) {
                            Text(session.name)
                                .font(VaporwaveTypography.sectionTitle())
                                .foregroundColor(VaporwaveColors.textPrimary)
                                .neonGlow(color: session.mode.color, radius: 10)

                            Text(session.mode.rawValue)
                                .font(VaporwaveTypography.label())
                                .foregroundColor(session.mode.color)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(session.mode.color.opacity(0.2))
                                )
                        }
                        .padding(.top, VaporwaveSpacing.xl)

                        // Coherence Graph Placeholder
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        session.mode.color.opacity(0.3),
                                        session.mode.color.opacity(0.1)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 200)
                            .overlay(
                                Text("Coherence Timeline")
                                    .font(VaporwaveTypography.caption())
                                    .foregroundColor(VaporwaveColors.textTertiary)
                            )
                            .glassCard()

                        // Stats Grid
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: VaporwaveSpacing.md) {
                            StatBox(title: "AVG COHERENCE", value: "\(Int(session.avgCoherence))", color: VaporwaveColors.coherenceHigh)
                            StatBox(title: "PEAK COHERENCE", value: "\(Int(session.peakCoherence))", color: VaporwaveColors.neonCyan)
                            StatBox(title: "AVG HRV", value: "\(Int(session.avgHRV)) ms", color: VaporwaveColors.hrv)
                            StatBox(title: "DURATION", value: formatDuration(session.duration), color: VaporwaveColors.neonPurple)
                        }

                        // Action Buttons
                        VStack(spacing: VaporwaveSpacing.md) {
                            Button(action: { showExport = true }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("EXPORT SESSION")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(VaporwaveColors.neonPink)
                                .frame(maxWidth: .infinity)
                                .padding(VaporwaveSpacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(VaporwaveColors.neonPink.opacity(0.15))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(VaporwaveColors.neonPink.opacity(0.5), lineWidth: 1)
                                )
                            }

                            Button(action: { /* Replay */ }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("REPLAY BIO-DATA")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(VaporwaveColors.neonCyan)
                                .frame(maxWidth: .infinity)
                                .padding(VaporwaveSpacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(VaporwaveColors.neonCyan.opacity(0.15))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(VaporwaveColors.neonCyan.opacity(0.5), lineWidth: 1)
                                )
                            }
                        }

                        Spacer()
                    }
                    .padding(.horizontal, VaporwaveSpacing.lg)
                }

                // Close Button
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(VaporwaveColors.textSecondary)
                        }
                        .padding(VaporwaveSpacing.lg)
                    }
                    Spacer()
                }
            }
            .sheet(isPresented: $showExport) {
                VaporwaveExport(sessionName: session.name)
            }
        }

        private func formatDuration(_ duration: TimeInterval) -> String {
            let hours = Int(duration) / 3600
            let minutes = (Int(duration) % 3600) / 60
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            }
            return "\(minutes) min"
        }
    }

    // MARK: - Stat Box

    struct StatBox: View {
        let title: String
        let value: String
        let color: Color

        var body: some View {
            VStack(spacing: VaporwaveSpacing.sm) {
                Text(title)
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)

                Text(value)
                    .font(VaporwaveTypography.dataSmall())
                    .foregroundColor(color)
                    .neonGlow(color: color, radius: 5)
            }
            .frame(maxWidth: .infinity)
            .padding(VaporwaveSpacing.md)
            .glassCard()
        }
    }
}

#if DEBUG
#Preview {
    VaporwaveSessions()
        .environmentObject(RecordingEngine())
}
#endif
