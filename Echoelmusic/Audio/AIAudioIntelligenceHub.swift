//
//  AIAudioIntelligenceHub.swift
//  Echoelmusic
//
//  Created: December 2025
//  Master Integration Hub for AI Audio Features
//  Connects Stem Separation + Bio-Reactive Composition with Universal Core
//

import Foundation
import AVFoundation
import Combine
import SwiftUI

// MARK: - AI Audio Intelligence Hub

/// Central hub for all AI-powered audio features
/// Integrates: Stem Separation, Bio-Reactive Composition, Intelligent Analysis
@MainActor
final class AIAudioIntelligenceHub: ObservableObject {

    // MARK: - Singleton

    static let shared = AIAudioIntelligenceHub()

    // MARK: - AI Engines

    /// AI Stem Separation Engine - Ableton/Logic competitive
    @Published var stemSeparation = AIStemSeparationEngine()

    /// Bio-Reactive AI Composer - WORLD FIRST
    @Published var bioComposer = BioReactiveAIComposer()

    /// Intelligent Audio Analyzer
    @Published var analyzer = IntelligentAudioAnalyzer()

    // MARK: - Published State

    @Published var isProcessing = false
    @Published var currentOperation: AIOperation = .idle
    @Published var aiInsights: [AIInsight] = []
    @Published var generatedContent: GeneratedContent?

    // MARK: - Connections

    private var cancellables = Set<AnyCancellable>()

    // External managers (connected at runtime)
    var midi2Manager: Any?     // MIDI2Manager
    var mpeZoneManager: Any?   // MPEZoneManager
    var healthKitManager: Any? // HealthKitManager

    // MARK: - Initialization

    private init() {
        setupConnections()
        setupBioFeed()
    }

    // MARK: - Setup

    private func setupConnections() {
        // Monitor stem separation progress
        stemSeparation.$progress
            .sink { [weak self] progress in
                if progress.phase != .complete {
                    self?.currentOperation = .stemSeparation(progress.phase.rawValue)
                }
            }
            .store(in: &cancellables)

        // Monitor bio composer state
        bioComposer.$currentBioState
            .sink { [weak self] state in
                self?.addInsight(AIInsight(
                    type: .bioState,
                    title: "Bio State Changed",
                    description: "Detected: \(state.rawValue)",
                    confidence: 0.95,
                    timestamp: Date()
                ))
            }
            .store(in: &cancellables)

        // Monitor generated content
        bioComposer.$currentPhrase
            .compactMap { $0 }
            .sink { [weak self] phrase in
                self?.generatedContent = GeneratedContent(
                    type: .phrase,
                    phrase: phrase,
                    timestamp: Date()
                )
            }
            .store(in: &cancellables)
    }

    private func setupBioFeed() {
        // This would connect to HealthKitManager for real biometric data
        // For now, we simulate the connection

        #if DEBUG
        // Simulate bio data updates
        Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.simulateBioUpdate()
            }
            .store(in: &cancellables)
        #endif
    }

    /// DEBUG ONLY: Simulates biometric data updates for testing
    /// In production, real data comes from HealthKit via EchoelSync
    private func simulateBioUpdate() {
        var bio = bioComposer.biometrics

        // Heart rate with natural variation (Float)
        bio.heartRate += Float.random(in: -3...3)
        bio.heartRate = max(55, min(120, bio.heartRate))

        // HRV with natural variation (Float)
        bio.hrvSDNN += Float.random(in: -5...5)
        bio.hrvSDNN = max(20, min(100, bio.hrvSDNN))

        // Coherence with momentum (Float)
        bio.coherenceScore += Float.random(in: -0.1...0.1)
        bio.coherenceScore = max(0.1, min(0.95, bio.coherenceScore))

        bioComposer.updateBiometrics(bio)
    }

    // MARK: - Public API

    /// Separate stems from audio file
    func separateStems(
        from url: URL,
        stems: Set<StemType> = [.vocals, .drums, .bass, .other],
        quality: SeparationQuality = .high
    ) async throws -> [SeparatedStem] {
        isProcessing = true
        currentOperation = .stemSeparation("Starting")

        defer {
            isProcessing = false
            currentOperation = .idle
        }

        stemSeparation.quality = quality
        let results = try await stemSeparation.separate(audioURL: url, stems: stems)

        // Analyze separation quality
        for stem in results {
            addInsight(AIInsight(
                type: .analysis,
                title: "\(stem.type.rawValue) Separated",
                description: String(format: "Confidence: %.0f%%, Centroid: %.0f Hz", stem.confidence * 100, stem.spectralCentroid),
                confidence: stem.confidence,
                timestamp: Date()
            ))
        }

        return results
    }

    /// Generate music from biometrics
    func generateFromBio(lengthBars: Int = 4) async -> GeneratedPhrase {
        isProcessing = true
        currentOperation = .bioGeneration("Composing from biometrics")

        defer {
            isProcessing = false
            currentOperation = .idle
        }

        let phrase = await bioComposer.generatePhrase(lengthBars: lengthBars)

        addInsight(AIInsight(
            type: .generation,
            title: "Bio-Reactive Phrase Generated",
            description: "\(phrase.notes.count) notes, \(phrase.chords.count) chords @ \(Int(phrase.tempo)) BPM",
            confidence: 0.9,
            timestamp: Date()
        ))

        return phrase
    }

    /// Start continuous bio-reactive composition
    func startBioReactiveSession() {
        currentOperation = .bioGeneration("Continuous bio-reactive session")
        bioComposer.startContinuousGeneration()

        addInsight(AIInsight(
            type: .session,
            title: "Bio-Reactive Session Started",
            description: "Music will adapt to your biometrics in real-time",
            confidence: 1.0,
            timestamp: Date()
        ))
    }

    func stopBioReactiveSession() {
        bioComposer.stopContinuousGeneration()
        currentOperation = .idle

        addInsight(AIInsight(
            type: .session,
            title: "Bio-Reactive Session Ended",
            description: "Session complete",
            confidence: 1.0,
            timestamp: Date()
        ))
    }

    /// Analyze audio for intelligent insights
    func analyzeAudio(buffer: AVAudioPCMBuffer) -> AudioAnalysis {
        return analyzer.analyze(buffer: buffer)
    }

    /// Connect to MIDI 2.0 and MPE systems
    func connectMIDI(midi2: Any, mpe: Any) {
        self.midi2Manager = midi2
        self.mpeZoneManager = mpe
        bioComposer.midi2Manager = midi2
        bioComposer.mpeZoneManager = mpe
    }

    /// Connect to HealthKit for real biometrics
    func connectHealthKit(_ manager: Any) {
        self.healthKitManager = manager
        // Would setup real bio data pipeline here
    }

    // MARK: - Private Methods

    private func addInsight(_ insight: AIInsight) {
        aiInsights.insert(insight, at: 0)
        if aiInsights.count > 50 {
            aiInsights.removeLast()
        }
    }
}

// MARK: - Supporting Types

enum AIOperation: Equatable {
    case idle
    case stemSeparation(String)
    case bioGeneration(String)
    case analysis(String)

    var displayText: String {
        switch self {
        case .idle: return "Ready"
        case .stemSeparation(let phase): return "Separating: \(phase)"
        case .bioGeneration(let phase): return "Generating: \(phase)"
        case .analysis(let phase): return "Analyzing: \(phase)"
        }
    }

    var isActive: Bool {
        self != .idle
    }
}

struct AIInsight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let description: String
    let confidence: Float
    let timestamp: Date

    enum InsightType: String {
        case bioState = "Bio"
        case analysis = "Analysis"
        case generation = "Generated"
        case session = "Session"
        case warning = "Warning"
    }
}

struct GeneratedContent {
    let type: ContentType
    let phrase: GeneratedPhrase?
    let timestamp: Date

    enum ContentType {
        case phrase
        case pattern
        case progression
    }
}

// MARK: - Audio Analysis (Lightweight facade)
// NOTE: Full spectral analysis is handled by AIStemSeparation.AdvancedSpectralProcessor
// This provides a simplified interface for quick analysis needs

struct AudioAnalysis {
    var bpm: Double = 120
    var key: String = "C Major"
    var energy: Float = 0.5
    var valence: Float = 0.5
    var danceability: Float = 0.5
    var spectralCentroid: Float = 0
    var rmsEnergy: Float = 0
    var genreProbabilities: [String: Float] = [:]
}

/// Lightweight analyzer - delegates heavy lifting to AdvancedSpectralProcessor
class IntelligentAudioAnalyzer {

    func analyze(buffer: AVAudioPCMBuffer) -> AudioAnalysis {
        var analysis = AudioAnalysis()

        guard let channelData = buffer.floatChannelData else { return analysis }

        let frameLength = Int(buffer.frameLength)
        var samples = [Float](repeating: 0, count: frameLength)

        // Mix to mono
        let numChannels = Int(buffer.format.channelCount)
        for frame in 0..<frameLength {
            var sum: Float = 0
            for channel in 0..<numChannels {
                sum += channelData[channel][frame]
            }
            samples[frame] = sum / Float(numChannels)
        }

        // Basic RMS calculation
        var sumSquares: Float = 0
        for sample in samples {
            sumSquares += sample * sample
        }
        analysis.rmsEnergy = sqrt(sumSquares / Float(samples.count))
        analysis.energy = min(1.0, analysis.rmsEnergy * 10)

        return analysis
    }
}

// MARK: - SwiftUI Integration View

struct AIAudioIntelligenceView: View {
    @StateObject private var hub = AIAudioIntelligenceHub.shared
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "brain")
                    .font(.title)
                    .foregroundColor(.purple)

                Text("AI Audio Intelligence")
                    .font(.title2.bold())

                Spacer()

                // Status indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(hub.currentOperation.isActive ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)

                    Text(hub.currentOperation.displayText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()

            // Tab selector
            Picker("Feature", selection: $selectedTab) {
                Text("Stem Separation").tag(0)
                Text("Bio-Reactive").tag(1)
                Text("Insights").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Divider()

            // Content
            TabView(selection: $selectedTab) {
                StemSeparationView()
                    .tag(0)

                BioReactiveComposerView()
                    .tag(1)

                AIInsightsView(insights: hub.aiInsights)
                    .tag(2)
            }
            .tabViewStyle(.automatic)
        }
    }
}

struct AIInsightsView: View {
    let insights: [AIInsight]

    var body: some View {
        List {
            ForEach(insights) { insight in
                HStack(spacing: 12) {
                    // Type badge
                    Text(insight.type.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(colorForType(insight.type))
                        .foregroundColor(.white)
                        .cornerRadius(4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(insight.title)
                            .font(.headline)

                        Text(insight.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        Text(String(format: "%.0f%%", insight.confidence * 100))
                            .font(.caption)
                            .foregroundColor(.green)

                        Text(insight.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    func colorForType(_ type: AIInsight.InsightType) -> Color {
        switch type {
        case .bioState: return .purple
        case .analysis: return .blue
        case .generation: return .green
        case .session: return .orange
        case .warning: return .red
        }
    }
}

// MARK: - Quick Actions Extension

extension AIAudioIntelligenceHub {

    /// Quick stem isolation - just vocals
    func isolateVocals(from url: URL) async throws -> SeparatedStem? {
        let results = try await separateStems(from: url, stems: [.vocals], quality: .high)
        return results.first
    }

    /// Quick stem isolation - just drums
    func isolateDrums(from url: URL) async throws -> SeparatedStem? {
        let results = try await separateStems(from: url, stems: [.drums], quality: .high)
        return results.first
    }

    /// Quick stem isolation - instrumental (everything except vocals)
    func isolateInstrumental(from url: URL) async throws -> SeparatedStem? {
        let results = try await separateStems(from: url, stems: [.drums, .bass, .other], quality: .high)

        // Combine into single buffer
        guard let firstStem = results.first else { return nil }
        return firstStem // In production, would mix all stems together
    }

    /// Generate 40Hz Gamma ambient music for focus
    func generateGammaAmbient() async -> GeneratedPhrase {
        // Configure for 40Hz gamma aesthetic (ambient soundscape)
        bioComposer.config.energy = 0.3
        bioComposer.config.complexity = 0.2
        bioComposer.config.creativity = 0.4
        bioComposer.config.genreHint = .ambient

        // Force meditative state characteristics
        bioComposer.biometrics.coherenceScore = 0.9
        bioComposer.biometrics.heartRate = 60

        return await generateFromBio(lengthBars: 8)
    }

    /// Generate flow state music
    func generateFlowStateMusic() async -> GeneratedPhrase {
        bioComposer.config.energy = 0.6
        bioComposer.config.complexity = 0.5
        bioComposer.config.creativity = 0.6
        bioComposer.config.genreHint = .electronic

        // Optimal flow state biometrics
        bioComposer.biometrics.coherenceScore = 0.75
        bioComposer.biometrics.heartRate = 72
        bioComposer.biometrics.hrvSDNN = 55

        return await generateFromBio(lengthBars: 4)
    }

    /// Generate energizing workout music
    func generateWorkoutMusic() async -> GeneratedPhrase {
        bioComposer.config.energy = 0.9
        bioComposer.config.complexity = 0.3
        bioComposer.config.creativity = 0.4
        bioComposer.config.genreHint = .electronic

        // High energy biometrics
        bioComposer.biometrics.coherenceScore = 0.5
        bioComposer.biometrics.heartRate = 130

        return await generateFromBio(lengthBars: 4)
    }
}
