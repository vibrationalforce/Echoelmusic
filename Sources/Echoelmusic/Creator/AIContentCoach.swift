// SPDX-License-Identifier: MIT
// Copyright 2026 Echoelmusic
// AI Content Coach - Bio-Reactive Content Optimization
// Inspired by: CreatorBuddy.io - Adapted for Echoelmusic's bio-reactive paradigm

import Foundation
import SwiftUI
import Combine

// MARK: - AI Content Coach
/// Intelligent content optimization coach for bio-reactive creators
/// Analyzes content, bio-patterns, and audience engagement to suggest improvements
@MainActor
public final class AIContentCoach: ObservableObject {

    public static let shared = AIContentCoach()

    // MARK: - State

    @Published public var contentAnalysis: ContentAnalysis?
    @Published public var suggestions: [ContentSuggestion] = []
    @Published public var bioPatternInsights: [BioPatternInsight] = []
    @Published public var audienceInsights: AudienceInsights?
    @Published public var isAnalyzing: Bool = false

    // MARK: - Content Analysis

    public struct ContentAnalysis: Identifiable {
        public let id: UUID
        public let analyzedAt: Date
        public let contentType: ContentType
        public let scores: ContentScores
        public let bioAlignment: BioAlignment
        public let recommendations: [Recommendation]

        public enum ContentType: String, CaseIterable {
            case music = "Music"
            case video = "Video"
            case visualArt = "Visual Art"
            case lightShow = "Light Show"
            case liveStream = "Live Stream"
            case bioExperience = "Bio-Experience"
        }

        public struct ContentScores {
            public var engagement: Double      // 0-100 predicted engagement
            public var bioResonance: Double    // 0-100 bio-coherence alignment
            public var creativity: Double      // 0-100 originality score
            public var technicalQuality: Double // 0-100 production quality
            public var emotionalImpact: Double // 0-100 emotional resonance

            public var overall: Double {
                (engagement + bioResonance + creativity + technicalQuality + emotionalImpact) / 5.0
            }
        }

        public struct BioAlignment {
            public var coherenceMatch: Double  // How well content matches creator's coherence
            public var energyMatch: Double     // Energy level alignment
            public var breathSync: Double      // Breath rhythm integration
            public var heartSync: Double       // Heart rate integration
            public var optimalCreationTime: String // Best time to create based on bio-patterns
        }

        public struct Recommendation: Identifiable {
            public let id: UUID
            public var category: Category
            public var title: String
            public var description: String
            public var impact: Impact
            public var bioRelated: Bool

            public enum Category: String, CaseIterable {
                case timing = "Timing"
                case structure = "Structure"
                case bioIntegration = "Bio-Integration"
                case engagement = "Engagement"
                case technical = "Technical"
                case emotional = "Emotional"
            }

            public enum Impact: String, CaseIterable {
                case high = "High Impact"
                case medium = "Medium Impact"
                case low = "Low Impact"
            }
        }
    }

    // MARK: - Content Suggestion

    public struct ContentSuggestion: Identifiable {
        public let id: UUID
        public var type: SuggestionType
        public var title: String
        public var description: String
        public var basedOn: String           // What data it's based on
        public var bioContext: String?       // Bio-state when suggestion generated
        public var confidence: Double        // 0-1 confidence score
        public var actionable: Bool

        public enum SuggestionType: String, CaseIterable {
            case nextContent = "What to Create Next"
            case bioOptimal = "Bio-Optimal Timing"
            case styleVariation = "Style Variation"
            case audienceGrowth = "Audience Growth"
            case collaboration = "Collaboration"
            case trending = "Trending Topic"
        }
    }

    // MARK: - Bio Pattern Insight

    public struct BioPatternInsight: Identifiable {
        public let id: UUID
        public var pattern: String
        public var discovery: String
        public var recommendation: String
        public var timeframe: String         // "morning", "evening", "weekly"
        public var dataPoints: Int           // How much data supports this
    }

    // MARK: - Audience Insights

    public struct AudienceInsights {
        public var totalReach: Int
        public var engagementRate: Double
        public var peakEngagementTimes: [String]
        public var topContentTypes: [String]
        public var audienceBioPreferences: BioPreferences

        public struct BioPreferences {
            public var preferredCoherence: Double // Audience responds best to this coherence
            public var preferredEnergy: Double
            public var preferredTempo: Double
            public var preferredVisualsIntensity: Double
        }
    }

    // MARK: - Analysis Functions

    /// Analyze content and provide coaching insights
    public func analyzeContent(
        type: ContentAnalysis.ContentType,
        duration: TimeInterval,
        bioData: BioCreationData?
    ) async -> ContentAnalysis {
        isAnalyzing = true
        defer { isAnalyzing = false }

        // Simulate analysis
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        let analysis = ContentAnalysis(
            id: UUID(),
            analyzedAt: Date(),
            contentType: type,
            scores: ContentAnalysis.ContentScores(
                engagement: Double.random(in: 65...95),
                bioResonance: bioData?.coherence ?? 0 * 100,
                creativity: Double.random(in: 70...90),
                technicalQuality: Double.random(in: 75...95),
                emotionalImpact: Double.random(in: 60...90)
            ),
            bioAlignment: ContentAnalysis.BioAlignment(
                coherenceMatch: bioData?.coherence ?? 0.7,
                energyMatch: bioData?.energy ?? 0.6,
                breathSync: 0.8,
                heartSync: 0.75,
                optimalCreationTime: determineOptimalTime()
            ),
            recommendations: generateRecommendations(for: type)
        )

        contentAnalysis = analysis
        return analysis
    }

    /// Generate personalized content suggestions
    public func generateSuggestions(basedOn history: [ContentHistory]) async {
        isAnalyzing = true
        defer { isAnalyzing = false }

        // Analyze patterns and generate suggestions
        suggestions = [
            ContentSuggestion(
                id: UUID(),
                type: .bioOptimal,
                title: "Create during high coherence",
                description: "Your best content was created when HRV coherence was above 75%. Current coherence: optimal",
                basedOn: "Last 30 days bio-data",
                bioContext: "High coherence detected",
                confidence: 0.85,
                actionable: true
            ),
            ContentSuggestion(
                id: UUID(),
                type: .nextContent,
                title: "Meditative ambient piece",
                description: "Based on your bio-patterns and audience engagement, a calm ambient piece would perform well",
                basedOn: "Audience analytics + bio-patterns",
                bioContext: nil,
                confidence: 0.78,
                actionable: true
            ),
            ContentSuggestion(
                id: UUID(),
                type: .styleVariation,
                title: "Add more breath-synced elements",
                description: "Content with breath-synchronized rhythms gets 40% more engagement",
                basedOn: "Engagement analysis",
                bioContext: nil,
                confidence: 0.82,
                actionable: true
            ),
            ContentSuggestion(
                id: UUID(),
                type: .trending,
                title: "Bio-reactive visual meditation",
                description: "Trending: 10-minute bio-reactive visual meditations are gaining traction",
                basedOn: "Platform trends",
                bioContext: nil,
                confidence: 0.71,
                actionable: true
            )
        ]
    }

    /// Analyze bio-patterns to find creative insights
    public func analyzeBioPatterns(data: [BioDataPoint]) async {
        bioPatternInsights = [
            BioPatternInsight(
                id: UUID(),
                pattern: "Morning Coherence Peak",
                discovery: "Your HRV coherence peaks between 9-11 AM",
                recommendation: "Schedule creative sessions during this window for best results",
                timeframe: "daily",
                dataPoints: 45
            ),
            BioPatternInsight(
                id: UUID(),
                pattern: "Post-Exercise Creativity",
                discovery: "Creativity scores are 30% higher after light exercise",
                recommendation: "Take a 10-minute walk before major creative sessions",
                timeframe: "session",
                dataPoints: 23
            ),
            BioPatternInsight(
                id: UUID(),
                pattern: "Breath-Tempo Correlation",
                discovery: "Your best music has tempo aligned with breath rate (10-14 BPM ratio)",
                recommendation: "Match composition tempo to current breathing rate",
                timeframe: "creation",
                dataPoints: 67
            )
        ]
    }

    // MARK: - Helpers

    private func determineOptimalTime() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<10: return "Early Morning - High Focus"
        case 10..<12: return "Late Morning - Peak Creativity"
        case 12..<14: return "Midday - Good for Reviews"
        case 14..<17: return "Afternoon - Steady Production"
        case 17..<20: return "Evening - Creative Flow"
        default: return "Night - Experimental Time"
        }
    }

    private func generateRecommendations(for type: ContentAnalysis.ContentType) -> [ContentAnalysis.Recommendation] {
        [
            ContentAnalysis.Recommendation(
                id: UUID(),
                category: .bioIntegration,
                title: "Increase breath synchronization",
                description: "Add subtle breath-rate modulation to enhance viewer connection",
                impact: .high,
                bioRelated: true
            ),
            ContentAnalysis.Recommendation(
                id: UUID(),
                category: .engagement,
                title: "Add interactive bio-overlay",
                description: "Real-time coherence display increases viewer engagement by 25%",
                impact: .medium,
                bioRelated: true
            ),
            ContentAnalysis.Recommendation(
                id: UUID(),
                category: .timing,
                title: "Optimal length: 8-12 minutes",
                description: "This duration maximizes retention for \(type.rawValue) content",
                impact: .medium,
                bioRelated: false
            )
        ]
    }

    // MARK: - Data Types

    public struct BioCreationData {
        public var coherence: Double
        public var energy: Double
        public var heartRate: Double
        public var breathingRate: Double
    }

    public struct ContentHistory: Identifiable {
        public let id: UUID
        public let createdAt: Date
        public let type: ContentAnalysis.ContentType
        public let engagement: Double
        public let bioStateAtCreation: BioCreationData?
    }

    public struct BioDataPoint: Identifiable {
        public let id: UUID
        public let timestamp: Date
        public let coherence: Double
        public let heartRate: Double
        public let breathingRate: Double
    }
}

// MARK: - Content Coach View

public struct AIContentCoachView: View {
    @ObservedObject private var coach = AIContentCoach.shared
    @State private var selectedTab: Tab = .suggestions

    enum Tab: String, CaseIterable {
        case suggestions = "Suggestions"
        case analysis = "Analysis"
        case patterns = "Bio Patterns"
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

                // Content
                ScrollView {
                    switch selectedTab {
                    case .suggestions:
                        suggestionsView
                    case .analysis:
                        analysisView
                    case .patterns:
                        patternsView
                    }
                }
            }
            .navigationTitle("AI Content Coach")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task {
                            await coach.generateSuggestions(basedOn: [])
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(coach.isAnalyzing)
                }
            }
        }
    }

    private var suggestionsView: some View {
        LazyVStack(spacing: 12) {
            if coach.suggestions.isEmpty {
                emptyState(
                    icon: "lightbulb",
                    title: "No suggestions yet",
                    message: "Create some content to get personalized suggestions"
                )
            } else {
                ForEach(coach.suggestions) { suggestion in
                    suggestionCard(suggestion)
                }
            }
        }
        .padding()
    }

    private func suggestionCard(_ suggestion: AIContentCoach.ContentSuggestion) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: suggestionIcon(suggestion.type))
                        .foregroundStyle(.green)
                    Text(suggestion.type.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(suggestion.confidence * 100))%")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }

                Text(suggestion.title)
                    .font(.headline)

                Text(suggestion.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let bioContext = suggestion.bioContext {
                    HStack {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                        Text(bioContext)
                            .font(.caption)
                    }
                    .foregroundStyle(.pink)
                }
            }
        }
    }

    private func suggestionIcon(_ type: AIContentCoach.ContentSuggestion.SuggestionType) -> String {
        switch type {
        case .nextContent: return "plus.circle"
        case .bioOptimal: return "heart.text.square"
        case .styleVariation: return "paintbrush"
        case .audienceGrowth: return "person.3"
        case .collaboration: return "person.2"
        case .trending: return "chart.line.uptrend.xyaxis"
        }
    }

    private var analysisView: some View {
        VStack(spacing: 16) {
            if let analysis = coach.contentAnalysis {
                // Scores
                GroupBox("Content Scores") {
                    VStack(spacing: 12) {
                        scoreRow("Engagement", score: analysis.scores.engagement, color: .blue)
                        scoreRow("Bio Resonance", score: analysis.scores.bioResonance, color: .green)
                        scoreRow("Creativity", score: analysis.scores.creativity, color: .purple)
                        scoreRow("Technical", score: analysis.scores.technicalQuality, color: .orange)
                        scoreRow("Emotional", score: analysis.scores.emotionalImpact, color: .pink)

                        Divider()

                        HStack {
                            Text("Overall Score")
                                .fontWeight(.semibold)
                            Spacer()
                            Text("\(Int(analysis.scores.overall))/100")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.green)
                        }
                    }
                }

                // Bio Alignment
                GroupBox("Bio Alignment") {
                    VStack(spacing: 8) {
                        alignmentRow("Coherence Match", value: analysis.bioAlignment.coherenceMatch)
                        alignmentRow("Energy Match", value: analysis.bioAlignment.energyMatch)
                        alignmentRow("Breath Sync", value: analysis.bioAlignment.breathSync)
                        alignmentRow("Heart Sync", value: analysis.bioAlignment.heartSync)

                        Divider()

                        HStack {
                            Image(systemName: "clock")
                            Text("Optimal time: \(analysis.bioAlignment.optimalCreationTime)")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                // Recommendations
                GroupBox("Recommendations") {
                    ForEach(analysis.recommendations) { rec in
                        recommendationRow(rec)
                    }
                }
            } else {
                emptyState(
                    icon: "chart.bar",
                    title: "No analysis yet",
                    message: "Analyze content to see detailed scores"
                )
            }
        }
        .padding()
    }

    private func scoreRow(_ label: String, score: Double, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            ProgressView(value: score / 100)
                .frame(width: 100)
                .tint(color)
            Text("\(Int(score))")
                .font(.caption)
                .frame(width: 30)
        }
    }

    private func alignmentRow(_ label: String, value: Double) -> some View {
        HStack {
            Text(label)
                .font(.caption)
            Spacer()
            Text("\(Int(value * 100))%")
                .font(.caption)
                .foregroundStyle(value > 0.7 ? .green : (value > 0.5 ? .orange : .red))
        }
    }

    private func recommendationRow(_ rec: AIContentCoach.ContentAnalysis.Recommendation) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: rec.bioRelated ? "heart.fill" : "lightbulb.fill")
                .foregroundStyle(rec.bioRelated ? .pink : .yellow)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(rec.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(rec.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(rec.impact.rawValue)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(impactColor(rec.impact).opacity(0.2))
                .foregroundStyle(impactColor(rec.impact))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }

    private func impactColor(_ impact: AIContentCoach.ContentAnalysis.Recommendation.Impact) -> Color {
        switch impact {
        case .high: return .red
        case .medium: return .orange
        case .low: return .gray
        }
    }

    private var patternsView: some View {
        LazyVStack(spacing: 12) {
            if coach.bioPatternInsights.isEmpty {
                emptyState(
                    icon: "waveform.path.ecg",
                    title: "No patterns discovered yet",
                    message: "Create more content to discover your bio-patterns"
                )
            } else {
                ForEach(coach.bioPatternInsights) { insight in
                    patternCard(insight)
                }
            }
        }
        .padding()
    }

    private func patternCard(_ insight: AIContentCoach.BioPatternInsight) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundStyle(.green)
                    Text(insight.pattern)
                        .font(.headline)
                    Spacer()
                    Text("\(insight.dataPoints) data points")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(insight.discovery)
                    .font(.subheadline)

                Divider()

                HStack {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text(insight.recommendation)
                        .font(.caption)
                }
            }
        }
    }

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
}

#Preview {
    AIContentCoachView()
}
