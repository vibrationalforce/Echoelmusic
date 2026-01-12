// SPDX-License-Identifier: MIT
// Copyright 2026 Echoelmusic
// Session Memory Persistence - Cross-Session Context Retention
// Inspired by: Claude-Mem - Adapted for bio-reactive creative workflows

import Foundation
import SwiftUI
import Combine

// MARK: - Session Memory Persistence
/// Maintains context across sessions using hybrid search (FTS + semantic)
/// Progressive disclosure pattern for token efficiency
@MainActor
public final class SessionMemoryPersistence: ObservableObject {

    public static let shared = SessionMemoryPersistence()

    // MARK: - State

    @Published public var observations: [Observation] = []
    @Published public var sessions: [Session] = []
    @Published public var insights: [Insight] = []
    @Published public var patterns: [Pattern] = []
    @Published public var isLoaded: Bool = false

    // Storage
    private let storageURL: URL
    private let maxObservations: Int = 10000
    private let maxSessionAge: TimeInterval = 30 * 24 * 60 * 60 // 30 days

    // MARK: - Models

    public struct Observation: Identifiable, Codable {
        public let id: UUID
        public let sessionId: UUID
        public let timestamp: Date
        public let type: ObservationType
        public let summary: String
        public let details: String?
        public let bioContext: BioContext?
        public var tags: [String]

        // For vector search (simplified)
        public var embedding: [Float]?

        public enum ObservationType: String, Codable, CaseIterable {
            case toolUse = "tool_use"
            case bioEvent = "bio_event"
            case userAction = "user_action"
            case aiSuggestion = "ai_suggestion"
            case contentCreation = "content_creation"
            case error = "error"
            case milestone = "milestone"
        }

        public struct BioContext: Codable {
            public let coherence: Double
            public let heartRate: Double
            public let energy: Double
            public let emotionalState: String
        }
    }

    public struct Session: Identifiable, Codable {
        public let id: UUID
        public let startedAt: Date
        public var endedAt: Date?
        public var projectName: String?
        public var observationCount: Int
        public var summaryGenerated: String?
        public var avgCoherence: Double?
    }

    public struct Insight: Identifiable, Codable {
        public let id: UUID
        public let discoveredAt: Date
        public let content: String
        public let source: String // "pattern_detection", "ai_analysis", "user_marked"
        public let confidence: Double
        public var isActedUpon: Bool
    }

    public struct Pattern: Identifiable, Codable {
        public let id: UUID
        public let name: String
        public let description: String
        public var occurrences: Int
        public let firstSeen: Date
        public var lastSeen: Date
        public var isPositive: Bool // Positive pattern or something to avoid
    }

    // MARK: - Initialization

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storageURL = documentsPath.appendingPathComponent("EchoelmusicMemory")

        Task {
            await load()
        }
    }

    // MARK: - Session Lifecycle

    /// Start a new session
    public func startSession(projectName: String? = nil) -> Session {
        let session = Session(
            id: UUID(),
            startedAt: Date(),
            endedAt: nil,
            projectName: projectName,
            observationCount: 0,
            summaryGenerated: nil,
            avgCoherence: nil
        )
        sessions.append(session)
        save()
        return session
    }

    /// End current session
    public func endSession(_ sessionId: UUID) {
        guard let index = sessions.firstIndex(where: { $0.id == sessionId }) else { return }

        sessions[index].endedAt = Date()

        // Calculate session stats
        let sessionObservations = observations.filter { $0.sessionId == sessionId }
        sessions[index].observationCount = sessionObservations.count

        // Calculate average coherence
        let coherenceValues = sessionObservations.compactMap { $0.bioContext?.coherence }
        if !coherenceValues.isEmpty {
            sessions[index].avgCoherence = coherenceValues.reduce(0, +) / Double(coherenceValues.count)
        }

        // Generate session summary
        sessions[index].summaryGenerated = generateSessionSummary(sessionObservations)

        save()
    }

    // MARK: - Observation Capture

    /// Capture an observation automatically
    public func capture(
        type: Observation.ObservationType,
        summary: String,
        details: String? = nil,
        bioContext: Observation.BioContext? = nil,
        tags: [String] = [],
        sessionId: UUID? = nil
    ) {
        let observation = Observation(
            id: UUID(),
            sessionId: sessionId ?? sessions.last?.id ?? UUID(),
            timestamp: Date(),
            type: type,
            summary: summary,
            details: details,
            bioContext: bioContext,
            tags: tags,
            embedding: nil // Would compute semantic embedding in production
        )

        observations.append(observation)

        // Maintain max observations
        if observations.count > maxObservations {
            observations.removeFirst(observations.count - maxObservations)
        }

        // Check for patterns
        detectPatterns(from: observation)

        save()
    }

    // MARK: - Progressive Disclosure (Token Efficiency)

    /// Get compact summary (50-100 tokens)
    public func compactSummary(limit: Int = 10) -> String {
        let recent = observations.suffix(limit)
        return recent.map { "[\($0.type.rawValue)] \($0.summary)" }.joined(separator: "; ")
    }

    /// Get timeline context around specific observations
    public func timelineContext(around observationIds: [UUID], windowMinutes: Int = 30) -> [Observation] {
        let window = TimeInterval(windowMinutes * 60)

        return observationIds.flatMap { id -> [Observation] in
            guard let target = observations.first(where: { $0.id == id }) else { return [] }

            return observations.filter { obs in
                abs(obs.timestamp.timeIntervalSince(target.timestamp)) <= window
            }
        }
        .uniqued()
    }

    /// Get full observation details (500-1000 tokens each)
    public func fullDetails(ids: [UUID]) -> [Observation] {
        observations.filter { ids.contains($0.id) }
    }

    // MARK: - Search (Hybrid: FTS + Semantic)

    /// Search observations
    public func search(query: String, type: Observation.ObservationType? = nil, limit: Int = 20) -> [Observation] {
        var results = observations

        // Filter by type
        if let type = type {
            results = results.filter { $0.type == type }
        }

        // Text search (FTS simulation)
        let queryLower = query.lowercased()
        results = results.filter { obs in
            obs.summary.lowercased().contains(queryLower) ||
            obs.details?.lowercased().contains(queryLower) ?? false ||
            obs.tags.contains { $0.lowercased().contains(queryLower) }
        }

        // Sort by relevance (recency for now)
        results.sort { $0.timestamp > $1.timestamp }

        return Array(results.prefix(limit))
    }

    /// Search by bio-context
    public func searchByBioState(
        minCoherence: Double? = nil,
        maxCoherence: Double? = nil,
        emotionalState: String? = nil
    ) -> [Observation] {
        observations.filter { obs in
            guard let bio = obs.bioContext else { return false }

            if let min = minCoherence, bio.coherence < min { return false }
            if let max = maxCoherence, bio.coherence > max { return false }
            if let state = emotionalState, bio.emotionalState != state { return false }

            return true
        }
    }

    // MARK: - Pattern Detection

    private func detectPatterns(from observation: Observation) {
        // Simple pattern detection
        // In production: More sophisticated ML-based detection

        // Time-of-day pattern
        let hour = Calendar.current.component(.hour, from: observation.timestamp)
        if let bio = observation.bioContext, bio.coherence > 0.8 {
            let timePattern = "High coherence at \(hour):00"
            updatePattern(named: timePattern, isPositive: true)
        }

        // Content type pattern
        if observation.type == .contentCreation {
            updatePattern(named: "Active content creation", isPositive: true)
        }

        // Error pattern
        if observation.type == .error {
            updatePattern(named: "Error occurrence", isPositive: false)
        }
    }

    private func updatePattern(named name: String, isPositive: Bool) {
        if let index = patterns.firstIndex(where: { $0.name == name }) {
            patterns[index].occurrences += 1
            patterns[index].lastSeen = Date()
        } else {
            let pattern = Pattern(
                id: UUID(),
                name: name,
                description: "Automatically detected pattern",
                occurrences: 1,
                firstSeen: Date(),
                lastSeen: Date(),
                isPositive: isPositive
            )
            patterns.append(pattern)
        }
    }

    // MARK: - Insight Generation

    /// Generate insights from patterns
    public func generateInsights() {
        // Analyze patterns and create insights

        // High coherence times
        let highCoherenceObs = searchByBioState(minCoherence: 0.8)
        if highCoherenceObs.count >= 5 {
            let hours = highCoherenceObs.map { Calendar.current.component(.hour, from: $0.timestamp) }
            let avgHour = hours.reduce(0, +) / hours.count

            addInsight(
                content: "Your coherence tends to peak around \(avgHour):00. Consider scheduling important creative work then.",
                source: "pattern_detection",
                confidence: Double(highCoherenceObs.count) / 20.0
            )
        }

        // Content creation patterns
        let contentObs = observations.filter { $0.type == .contentCreation }
        if contentObs.count >= 10 {
            let avgCoherence = contentObs.compactMap { $0.bioContext?.coherence }.reduce(0, +) / Double(contentObs.count)

            addInsight(
                content: "Your best content is created at \(Int(avgCoherence * 100))% average coherence.",
                source: "pattern_detection",
                confidence: 0.75
            )
        }
    }

    private func addInsight(content: String, source: String, confidence: Double) {
        // Check for duplicate
        guard !insights.contains(where: { $0.content == content }) else { return }

        let insight = Insight(
            id: UUID(),
            discoveredAt: Date(),
            content: content,
            source: source,
            confidence: min(1.0, confidence),
            isActedUpon: false
        )
        insights.append(insight)
    }

    // MARK: - Session Summary

    private func generateSessionSummary(_ sessionObservations: [Observation]) -> String {
        let types = Dictionary(grouping: sessionObservations, by: { $0.type })
        var parts: [String] = []

        if let content = types[.contentCreation] {
            parts.append("Created \(content.count) content items")
        }
        if let bio = types[.bioEvent] {
            parts.append("\(bio.count) bio events")
        }
        if let milestones = types[.milestone] {
            parts.append("\(milestones.count) milestones achieved")
        }

        return parts.isEmpty ? "Session completed" : parts.joined(separator: ", ")
    }

    // MARK: - Persistence

    private func load() async {
        isLoaded = false
        defer { isLoaded = true }

        // In production: Load from SQLite + file storage
        // For now: UserDefaults simulation

        if let data = UserDefaults.standard.data(forKey: "echoelmusic.memory.observations"),
           let decoded = try? JSONDecoder().decode([Observation].self, from: data) {
            observations = decoded
        }

        if let data = UserDefaults.standard.data(forKey: "echoelmusic.memory.sessions"),
           let decoded = try? JSONDecoder().decode([Session].self, from: data) {
            sessions = decoded
        }

        if let data = UserDefaults.standard.data(forKey: "echoelmusic.memory.insights"),
           let decoded = try? JSONDecoder().decode([Insight].self, from: data) {
            insights = decoded
        }

        if let data = UserDefaults.standard.data(forKey: "echoelmusic.memory.patterns"),
           let decoded = try? JSONDecoder().decode([Pattern].self, from: data) {
            patterns = decoded
        }

        // Clean old data
        cleanOldData()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(observations) {
            UserDefaults.standard.set(data, forKey: "echoelmusic.memory.observations")
        }
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: "echoelmusic.memory.sessions")
        }
        if let data = try? JSONEncoder().encode(insights) {
            UserDefaults.standard.set(data, forKey: "echoelmusic.memory.insights")
        }
        if let data = try? JSONEncoder().encode(patterns) {
            UserDefaults.standard.set(data, forKey: "echoelmusic.memory.patterns")
        }
    }

    private func cleanOldData() {
        let cutoff = Date().addingTimeInterval(-maxSessionAge)
        observations.removeAll { $0.timestamp < cutoff }
        sessions.removeAll { ($0.endedAt ?? $0.startedAt) < cutoff }
    }

    // MARK: - Data Export

    public func exportMemory() -> MemoryExport {
        MemoryExport(
            exportedAt: Date(),
            observations: observations,
            sessions: sessions,
            insights: insights,
            patterns: patterns
        )
    }

    public struct MemoryExport: Codable {
        public let exportedAt: Date
        public let observations: [Observation]
        public let sessions: [Session]
        public let insights: [Insight]
        public let patterns: [Pattern]
    }
}

// MARK: - Array Extension

extension Array where Element: Identifiable {
    func uniqued() -> [Element] {
        var seen = Set<String>()
        return filter { seen.insert(String(describing: $0.id)).inserted }
    }
}

// MARK: - Memory View

public struct SessionMemoryView: View {
    @ObservedObject private var memory = SessionMemoryPersistence.shared
    @State private var searchQuery: String = ""
    @State private var selectedTab: Tab = .observations

    enum Tab: String, CaseIterable {
        case observations = "Observations"
        case insights = "Insights"
        case patterns = "Patterns"
        case sessions = "Sessions"
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Tab", selection: $selectedTab) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Search
                if selectedTab == .observations {
                    TextField("Search observations...", text: $searchQuery)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                }

                // Content
                ScrollView {
                    switch selectedTab {
                    case .observations:
                        observationsView
                    case .insights:
                        insightsView
                    case .patterns:
                        patternsView
                    case .sessions:
                        sessionsView
                    }
                }
            }
            .navigationTitle("Session Memory")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Generate Insights") {
                            memory.generateInsights()
                        }
                        Button("Export Memory") {
                            _ = memory.exportMemory()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private var observationsView: some View {
        LazyVStack(spacing: 8) {
            let filtered = searchQuery.isEmpty
                ? memory.observations.suffix(50).reversed()
                : memory.search(query: searchQuery)

            ForEach(Array(filtered)) { obs in
                observationCard(obs)
            }
        }
        .padding()
    }

    private func observationCard(_ obs: SessionMemoryPersistence.Observation) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: observationIcon(obs.type))
                        .foregroundStyle(observationColor(obs.type))
                    Text(obs.type.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(obs.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text(obs.summary)
                    .font(.subheadline)

                if let bio = obs.bioContext {
                    HStack {
                        Label("\(Int(bio.coherence * 100))%", systemImage: "heart.fill")
                        Label(bio.emotionalState, systemImage: "face.smiling")
                    }
                    .font(.caption2)
                    .foregroundStyle(.green)
                }

                if !obs.tags.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(obs.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
    }

    private func observationIcon(_ type: SessionMemoryPersistence.Observation.ObservationType) -> String {
        switch type {
        case .toolUse: return "wrench.fill"
        case .bioEvent: return "heart.fill"
        case .userAction: return "hand.tap.fill"
        case .aiSuggestion: return "sparkles"
        case .contentCreation: return "paintbrush.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .milestone: return "flag.fill"
        }
    }

    private func observationColor(_ type: SessionMemoryPersistence.Observation.ObservationType) -> Color {
        switch type {
        case .toolUse: return .blue
        case .bioEvent: return .green
        case .userAction: return .purple
        case .aiSuggestion: return .yellow
        case .contentCreation: return .pink
        case .error: return .red
        case .milestone: return .orange
        }
    }

    private var insightsView: some View {
        LazyVStack(spacing: 12) {
            ForEach(memory.insights) { insight in
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.yellow)
                            Text("Insight")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(insight.confidence * 100))% confidence")
                                .font(.caption2)
                        }

                        Text(insight.content)
                            .font(.subheadline)

                        HStack {
                            Text(insight.source)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if insight.isActedUpon {
                                Label("Acted upon", systemImage: "checkmark")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }

    private var patternsView: some View {
        LazyVStack(spacing: 12) {
            ForEach(memory.patterns) { pattern in
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: pattern.isPositive ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                .foregroundStyle(pattern.isPositive ? .green : .red)
                            Text(pattern.name)
                                .font(.headline)
                        }

                        Text(pattern.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("\(pattern.occurrences) occurrences")
                            Spacer()
                            Text("Last: \(pattern.lastSeen, style: .relative)")
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding()
    }

    private var sessionsView: some View {
        LazyVStack(spacing: 12) {
            ForEach(memory.sessions.reversed()) { session in
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(session.projectName ?? "Untitled Session")
                                .font(.headline)
                            Spacer()
                            if session.endedAt == nil {
                                Text("Active")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.green)
                                    .foregroundStyle(.white)
                                    .cornerRadius(4)
                            }
                        }

                        HStack {
                            Label("\(session.observationCount) observations", systemImage: "eye")
                            if let coherence = session.avgCoherence {
                                Label("\(Int(coherence * 100))% avg coherence", systemImage: "heart")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        if let summary = session.summaryGenerated {
                            Text(summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(session.startedAt, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth {
                height += rowHeight + spacing
                rowWidth = size.width + spacing
                rowHeight = size.height
            } else {
                rowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
        height += rowHeight

        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    SessionMemoryView()
}
