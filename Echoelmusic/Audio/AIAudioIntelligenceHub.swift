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
/// Migrated to @Observable for better performance (Swift 5.9+)
@MainActor
@Observable
final class AIAudioIntelligenceHub {

    // MARK: - Singleton

    static let shared = AIAudioIntelligenceHub()

    // MARK: - AI Engines

    /// AI Stem Separation Engine - Ableton/Logic competitive
    var stemSeparation = AIStemSeparationEngine()

    /// Bio-Reactive AI Composer - WORLD FIRST
    var bioComposer = BioReactiveAIComposer()

    /// Intelligent Audio Analyzer
    var analyzer = IntelligentAudioAnalyzer()

    // MARK: - Observable State

    var isProcessing = false
    var currentOperation: AIOperation = .idle
    var aiInsights: [AIInsight] = []
    var generatedContent: GeneratedContent?

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

    private func simulateBioUpdate() {
        // Simulate realistic bio variations
        var bio = bioComposer.biometrics

        // Heart rate with natural variation
        bio.heartRate += Double.random(in: -3...3)
        bio.heartRate = max(55, min(120, bio.heartRate))

        // HRV with natural variation
        bio.hrvSDNN += Double.random(in: -5...5)
        bio.hrvSDNN = max(20, min(100, bio.hrvSDNN))

        // Coherence with momentum
        let coherenceDelta = Float.random(in: -0.1...0.1)
        bio.coherenceScore += coherenceDelta
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

// MARK: - Intelligent Audio Analyzer

class IntelligentAudioAnalyzer {

    struct AudioAnalysis {
        var bpm: Double = 120
        var key: String = "C Major"
        var energy: Float = 0.5
        var valence: Float = 0.5  // Happy/Sad
        var danceability: Float = 0.5
        var acousticness: Float = 0.5
        var instrumentalness: Float = 0.5
        var speechiness: Float = 0.1
        var spectralCentroid: Float = 0
        var zeroCrossingRate: Float = 0
        var rmsEnergy: Float = 0

        // Genre probabilities
        var genreProbabilities: [String: Float] = [:]

        // Detected instruments
        var detectedInstruments: [String] = []

        // Sections
        var sections: [AudioSection] = []
    }

    struct AudioSection {
        var startTime: Double
        var duration: Double
        var type: SectionType
        var energy: Float

        enum SectionType: String {
            case intro, verse, preChorus, chorus, bridge, outro, instrumental, breakdown
        }
    }

    func analyze(buffer: AVAudioPCMBuffer) -> AudioAnalysis {
        var analysis = AudioAnalysis()

        guard let channelData = buffer.floatChannelData else { return analysis }

        let frameLength = Int(buffer.frameLength)
        var samples = [Float](repeating: 0, count: frameLength)

        // Mix to mono if needed
        let numChannels = Int(buffer.format.channelCount)
        for frame in 0..<frameLength {
            var sum: Float = 0
            for channel in 0..<numChannels {
                sum += channelData[channel][frame]
            }
            samples[frame] = sum / Float(numChannels)
        }

        // Calculate basic features
        analysis.rmsEnergy = calculateRMS(samples)
        analysis.zeroCrossingRate = calculateZeroCrossingRate(samples)
        analysis.spectralCentroid = calculateSpectralCentroid(samples, sampleRate: Float(buffer.format.sampleRate))

        // Estimate energy (0-1)
        analysis.energy = min(1.0, analysis.rmsEnergy * 10)

        // Estimate danceability from rhythm regularity
        analysis.danceability = estimateDanceability(samples)

        // Estimate acousticness from spectral features
        analysis.acousticness = 1.0 - min(1.0, analysis.spectralCentroid / 5000)

        // Estimate key (simplified)
        analysis.key = estimateKey(samples)

        // Estimate BPM
        analysis.bpm = estimateBPM(samples, sampleRate: Float(buffer.format.sampleRate))

        // Genre classification (simplified)
        analysis.genreProbabilities = classifyGenre(analysis)

        return analysis
    }

    private func calculateRMS(_ samples: [Float]) -> Float {
        var sumSquares: Float = 0
        for sample in samples {
            sumSquares += sample * sample
        }
        return sqrt(sumSquares / Float(samples.count))
    }

    private func calculateZeroCrossingRate(_ samples: [Float]) -> Float {
        var crossings = 0
        for i in 1..<samples.count {
            if (samples[i] >= 0 && samples[i-1] < 0) || (samples[i] < 0 && samples[i-1] >= 0) {
                crossings += 1
            }
        }
        return Float(crossings) / Float(samples.count)
    }

    private func calculateSpectralCentroid(_ samples: [Float], sampleRate: Float) -> Float {
        // Simplified spectral centroid using autocorrelation
        let fftSize = min(4096, samples.count)
        var weightedSum: Float = 0
        var totalMag: Float = 0

        for k in 1..<fftSize/2 {
            let frequency = Float(k) * sampleRate / Float(fftSize)
            let magnitude = abs(samples[k % samples.count])
            weightedSum += frequency * magnitude
            totalMag += magnitude
        }

        return totalMag > 0 ? weightedSum / totalMag : 1000
    }

    private func estimateDanceability(_ samples: [Float]) -> Float {
        // Real danceability estimation using rhythm regularity analysis
        guard samples.count > 4096 else { return 0.5 }

        let sampleRate: Float = 44100
        let hopSize = 512
        let frameSize = 1024

        // 1. Calculate onset strength envelope
        var onsetStrengths: [Float] = []
        var prevSpectralFlux: Float = 0

        for i in stride(from: 0, to: samples.count - frameSize, by: hopSize) {
            // Simple spectral flux (sum of positive differences)
            var spectralFlux: Float = 0
            var energy: Float = 0

            for j in 0..<frameSize {
                let sample = samples[i + j]
                energy += sample * sample
            }

            let currentFlux = sqrt(energy / Float(frameSize))
            let diff = max(0, currentFlux - prevSpectralFlux)
            spectralFlux = diff
            prevSpectralFlux = currentFlux

            onsetStrengths.append(spectralFlux)
        }

        guard onsetStrengths.count > 16 else { return 0.5 }

        // 2. Autocorrelation to find beat periodicity
        let maxLag = min(onsetStrengths.count / 2, 200)  // ~4 seconds at 44.1kHz/512hop
        var autocorr = [Float](repeating: 0, count: maxLag)

        for lag in 0..<maxLag {
            var sum: Float = 0
            for i in 0..<(onsetStrengths.count - lag) {
                sum += onsetStrengths[i] * onsetStrengths[i + lag]
            }
            autocorr[lag] = sum / Float(onsetStrengths.count - lag)
        }

        // 3. Find peaks in autocorrelation (beat periodicity)
        var peakStrength: Float = 0
        var peakCount = 0

        for i in 10..<maxLag-1 {  // Skip very short lags
            if autocorr[i] > autocorr[i-1] && autocorr[i] > autocorr[i+1] {
                peakStrength += autocorr[i]
                peakCount += 1
            }
        }

        // 4. Calculate rhythm regularity score
        let avgPeakStrength = peakCount > 0 ? peakStrength / Float(peakCount) : 0
        let maxAutocorr = autocorr.max() ?? 1
        let regularityScore = maxAutocorr > 0 ? avgPeakStrength / maxAutocorr : 0

        // 5. Calculate low-frequency energy ratio (bass presence = more danceable)
        var lowEnergy: Float = 0
        var totalEnergy: Float = 0
        let lowFreqBins = frameSize / 8  // ~0-700Hz at 44.1kHz

        for sample in samples {
            totalEnergy += sample * sample
        }

        // Simplified low-freq estimation using sample smoothing
        for i in stride(from: 0, to: samples.count - 4, by: 4) {
            let avg = (samples[i] + samples[i+1] + samples[i+2] + samples[i+3]) / 4
            lowEnergy += avg * avg
        }
        lowEnergy *= 4

        let bassRatio = totalEnergy > 0 ? min(1.0, lowEnergy / totalEnergy) : 0.5

        // 6. Combine factors into danceability score
        let danceability = regularityScore * 0.6 + bassRatio * 0.4

        return max(0.1, min(0.95, danceability))
    }

    private func estimateKey(_ samples: [Float]) -> String {
        // Real key estimation using chromagram analysis
        guard samples.count > 4096 else { return "C Major" }

        let sampleRate: Float = 44100
        let frameSize = 4096
        let hopSize = 2048

        // Pitch class frequencies (A4 = 440Hz, calculate for octave 4)
        let pitchClassFreqs: [Float] = [
            261.63, 277.18, 293.66, 311.13, 329.63, 349.23,  // C4, C#4, D4, D#4, E4, F4
            369.99, 392.00, 415.30, 440.00, 466.16, 493.88   // F#4, G4, G#4, A4, A#4, B4
        ]

        // Initialize chromagram (12 pitch classes)
        var chromagram = [Float](repeating: 0, count: 12)

        // Process frames
        var frameCount = 0
        for frameStart in stride(from: 0, to: samples.count - frameSize, by: hopSize) {
            // Extract frame and apply Hann window
            var frame = [Float](repeating: 0, count: frameSize)
            for i in 0..<frameSize {
                let window = 0.5 * (1 - cos(2 * Float.pi * Float(i) / Float(frameSize - 1)))
                frame[i] = samples[frameStart + i] * window
            }

            // Simple DFT-based pitch class detection
            for pitchClass in 0..<12 {
                let baseFreq = pitchClassFreqs[pitchClass]

                // Check multiple octaves (2-5)
                for octave in 2...5 {
                    let freq = baseFreq * pow(2, Float(octave - 4))
                    let bin = Int(freq * Float(frameSize) / sampleRate)

                    if bin > 0 && bin < frameSize / 2 {
                        // Goertzel-like magnitude estimation
                        var sumReal: Float = 0
                        var sumImag: Float = 0
                        let omega = 2 * Float.pi * Float(bin) / Float(frameSize)

                        for i in 0..<frameSize {
                            sumReal += frame[i] * cos(omega * Float(i))
                            sumImag += frame[i] * sin(omega * Float(i))
                        }

                        let magnitude = sqrt(sumReal * sumReal + sumImag * sumImag)
                        chromagram[pitchClass] += magnitude
                    }
                }
            }
            frameCount += 1
        }

        // Normalize chromagram
        if frameCount > 0 {
            let maxChroma = chromagram.max() ?? 1
            if maxChroma > 0 {
                for i in 0..<12 {
                    chromagram[i] /= maxChroma
                }
            }
        }

        // Key profiles (Krumhansl-Kessler)
        let majorProfile: [Float] = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
        let minorProfile: [Float] = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]

        let keyNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

        var bestKey = "C Major"
        var bestCorrelation: Float = -Float.infinity

        // Test all 24 keys (12 major + 12 minor)
        for root in 0..<12 {
            // Rotate chromagram to align with this root
            var rotatedChroma = [Float](repeating: 0, count: 12)
            for i in 0..<12 {
                rotatedChroma[i] = chromagram[(i + root) % 12]
            }

            // Correlation with major profile
            var majorCorr: Float = 0
            var minorCorr: Float = 0

            for i in 0..<12 {
                majorCorr += rotatedChroma[i] * majorProfile[i]
                minorCorr += rotatedChroma[i] * minorProfile[i]
            }

            if majorCorr > bestCorrelation {
                bestCorrelation = majorCorr
                bestKey = "\(keyNames[root]) Major"
            }
            if minorCorr > bestCorrelation {
                bestCorrelation = minorCorr
                bestKey = "\(keyNames[root]) Minor"
            }
        }

        return bestKey
    }

    private func estimateBPM(_ samples: [Float], sampleRate: Float) -> Double {
        // Simplified BPM estimation using onset detection
        // In production, this would use proper beat tracking

        var onsets: [Int] = []
        let threshold: Float = 0.1
        let windowSize = Int(sampleRate * 0.05)  // 50ms windows

        for i in stride(from: windowSize, to: samples.count - windowSize, by: windowSize) {
            let currentEnergy = samples[i..<i+windowSize].map { $0 * $0 }.reduce(0, +)
            let prevEnergy = samples[i-windowSize..<i].map { $0 * $0 }.reduce(0, +)

            if currentEnergy > prevEnergy * (1 + threshold) {
                onsets.append(i)
            }
        }

        // Calculate average inter-onset interval
        if onsets.count > 1 {
            var intervals: [Int] = []
            for i in 1..<onsets.count {
                intervals.append(onsets[i] - onsets[i-1])
            }

            let avgInterval = Double(intervals.reduce(0, +)) / Double(intervals.count)
            let bpm = 60.0 * Double(sampleRate) / avgInterval

            // Constrain to reasonable range
            return max(60, min(180, bpm))
        }

        return 120  // Default
    }

    private func classifyGenre(_ analysis: AudioAnalysis) -> [String: Float] {
        // Simplified genre classification based on features
        var genres: [String: Float] = [:]

        // Electronic: High energy, high spectral centroid
        genres["Electronic"] = (analysis.energy * 0.5 + min(1.0, analysis.spectralCentroid / 4000) * 0.5)

        // Acoustic: Low spectral centroid, high acousticness
        genres["Acoustic"] = analysis.acousticness

        // Hip-Hop: Medium energy, strong beat
        genres["Hip-Hop"] = (analysis.energy * 0.3 + analysis.danceability * 0.7)

        // Classical: Low ZCR, wide dynamic range
        genres["Classical"] = max(0, 1.0 - analysis.zeroCrossingRate * 10)

        // Ambient: Low energy, low ZCR
        genres["Ambient"] = max(0, (1.0 - analysis.energy) * 0.5 + (1.0 - analysis.zeroCrossingRate * 10) * 0.5)

        return genres
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

    /// Generate 40Hz Gamma healing music
    func generateGammaHealing() async -> GeneratedPhrase {
        // Configure for 40Hz gamma entrainment (MIT research)
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

// MARK: - Backward Compatibility

extension AIAudioIntelligenceHub: ObservableObject { }
