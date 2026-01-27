// OnDeviceIntelligence.swift
// Echoelmusic
//
// On-Device Foundation Model Integration
// Semantic Music Discovery & Local Audio Analysis
//
// Created: 2026-01-25
// Phase 10000 ULTRA MODE - Apple Intelligence Integration

import Foundation
import Combine
import NaturalLanguage

#if canImport(CoreML)
import CoreML
#endif

#if canImport(Speech)
import Speech
#endif

// MARK: - Semantic Query Result

/// Result from semantic music query
public struct SemanticQueryResult: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let query: String
    public let interpretedMood: String
    public let interpretedGenre: String?
    public let interpretedTempo: TempoRange?
    public let interpretedEnergy: EnergyLevel
    public let confidenceScore: Double
    public let suggestedPresets: [String]
    public let timestamp: Date

    public enum TempoRange: String, Sendable {
        case verySlow = "very_slow"      // < 60 BPM
        case slow = "slow"               // 60-90 BPM
        case moderate = "moderate"       // 90-120 BPM
        case fast = "fast"               // 120-150 BPM
        case veryFast = "very_fast"      // > 150 BPM
    }

    public enum EnergyLevel: String, Sendable {
        case calm = "calm"
        case relaxed = "relaxed"
        case balanced = "balanced"
        case energetic = "energetic"
        case intense = "intense"
    }
}

// MARK: - Audio Vibe Tag

/// Generated "Key Vibe" tag for audio content
public struct AudioVibeTag: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let primaryMood: String
    public let secondaryMoods: [String]
    public let energyLevel: Double      // 0.0 - 1.0
    public let valence: Double          // 0.0 (negative) - 1.0 (positive)
    public let acousticness: Double     // 0.0 - 1.0
    public let danceability: Double     // 0.0 - 1.0
    public let keywords: [String]
    public let generatedDescription: String
    public let analysisTimestamp: Date
    public let processingTimeMs: Int

    public init(
        id: UUID = UUID(),
        primaryMood: String,
        secondaryMoods: [String] = [],
        energyLevel: Double,
        valence: Double,
        acousticness: Double,
        danceability: Double,
        keywords: [String],
        generatedDescription: String,
        analysisTimestamp: Date = Date(),
        processingTimeMs: Int
    ) {
        self.id = id
        self.primaryMood = primaryMood
        self.secondaryMoods = secondaryMoods
        self.energyLevel = energyLevel
        self.valence = valence
        self.acousticness = acousticness
        self.danceability = danceability
        self.keywords = keywords
        self.generatedDescription = generatedDescription
        self.analysisTimestamp = analysisTimestamp
        self.processingTimeMs = processingTimeMs
    }
}

// MARK: - On-Device Intelligence Engine

/// Main engine for on-device AI processing
/// Uses Apple's NaturalLanguage framework and CoreML for local inference
@MainActor
public final class OnDeviceIntelligenceEngine: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isProcessing: Bool = false
    @Published public private(set) var lastQuery: SemanticQueryResult?
    @Published public private(set) var cachedVibeTags: [UUID: AudioVibeTag] = [:]
    @Published public private(set) var modelStatus: ModelStatus = .notLoaded

    public enum ModelStatus: String, Sendable {
        case notLoaded = "not_loaded"
        case loading = "loading"
        case ready = "ready"
        case error = "error"
        case unsupported = "unsupported"
    }

    // MARK: - Private Properties

    private let nlProcessor: NLLanguageRecognizer
    private let sentimentTagger: NLTagger
    private var cancellables = Set<AnyCancellable>()

    // Mood keyword mappings for semantic understanding
    private let moodKeywords: [String: [String]] = [
        "calm": ["peaceful", "serene", "tranquil", "quiet", "gentle", "soft", "soothing", "meditation", "zen", "relax"],
        "melancholic": ["sad", "rainy", "nostalgic", "lonely", "blue", "melancholy", "bittersweet", "wistful"],
        "energetic": ["upbeat", "energetic", "powerful", "dynamic", "driving", "intense", "pumping", "workout"],
        "romantic": ["love", "romantic", "intimate", "sensual", "passionate", "tender", "heartfelt"],
        "mysterious": ["dark", "mysterious", "eerie", "haunting", "ambient", "atmospheric", "cinematic"],
        "happy": ["joyful", "happy", "cheerful", "bright", "sunny", "uplifting", "positive", "playful"],
        "focus": ["concentration", "focus", "study", "work", "productive", "deep work", "flow"],
        "dreamy": ["dream", "floating", "ethereal", "cosmic", "space", "astral", "otherworldly"]
    ]

    // Location/scene mappings
    private let sceneKeywords: [String: [String]] = [
        "tokyo": ["japanese", "japan", "tokyo", "anime", "lo-fi", "city pop"],
        "paris": ["french", "paris", "cafe", "romantic", "accordion", "chanson"],
        "beach": ["ocean", "beach", "waves", "tropical", "summer", "surf"],
        "forest": ["nature", "forest", "woods", "birds", "rain", "ambient"],
        "night": ["night", "midnight", "nocturnal", "late night", "after dark"],
        "morning": ["morning", "sunrise", "dawn", "coffee", "wake up"]
    ]

    // MARK: - Initialization

    public init() {
        self.nlProcessor = NLLanguageRecognizer()
        self.sentimentTagger = NLTagger(tagSchemes: [.sentimentScore, .lexicalClass])

        loadModels()
    }

    // MARK: - Model Loading

    private func loadModels() {
        modelStatus = .loading

        // NaturalLanguage framework is always available on Apple platforms
        // CoreML models would be loaded here for more advanced features
        Task {
            do {
                // Simulate model loading (in production, load actual CoreML models)
                try await Task.sleep(nanoseconds: 100_000_000) // 100ms

                await MainActor.run {
                    self.modelStatus = .ready
                }
            } catch {
                await MainActor.run {
                    self.modelStatus = .error
                }
            }
        }
    }

    // MARK: - Semantic Music Query

    /// Process a natural language music query
    /// - Parameter query: Natural language query (e.g., "songs that sound like a rainy Tokyo night")
    /// - Returns: Semantic query result with interpreted parameters
    public func processSemanticQuery(_ query: String) async -> SemanticQueryResult {
        isProcessing = true
        defer { isProcessing = false }

        let startTime = Date()

        // Analyze the query
        let lowercaseQuery = query.lowercased()

        // Detect language
        nlProcessor.processString(query)
        let detectedLanguage = nlProcessor.dominantLanguage ?? .english

        // Extract mood
        let detectedMood = detectMood(from: lowercaseQuery)

        // Extract scene/location context
        let sceneContext = detectScene(from: lowercaseQuery)

        // Analyze sentiment
        let sentiment = analyzeSentiment(query)

        // Determine tempo from context
        let tempoRange = inferTempo(from: lowercaseQuery, mood: detectedMood)

        // Determine energy level
        let energyLevel = inferEnergy(from: detectedMood, sentiment: sentiment)

        // Generate preset suggestions
        let presets = generatePresetSuggestions(
            mood: detectedMood,
            scene: sceneContext,
            energy: energyLevel
        )

        let processingTime = Date().timeIntervalSince(startTime)
        let confidence = calculateConfidence(
            moodMatch: detectedMood != "neutral",
            sceneMatch: sceneContext != nil,
            sentiment: sentiment
        )

        let result = SemanticQueryResult(
            id: UUID(),
            query: query,
            interpretedMood: detectedMood,
            interpretedGenre: sceneContext,
            interpretedTempo: tempoRange,
            interpretedEnergy: energyLevel,
            confidenceScore: confidence,
            suggestedPresets: presets,
            timestamp: Date()
        )

        lastQuery = result
        return result
    }

    // MARK: - Audio Vibe Tag Generation

    /// Generate "Key Vibe" tags for audio content
    /// - Parameters:
    ///   - audioFeatures: Extracted audio features
    ///   - duration: Audio duration in seconds
    /// - Returns: Generated vibe tag
    public func generateVibeTag(
        audioFeatures: AudioFeatures,
        duration: TimeInterval
    ) async -> AudioVibeTag {
        isProcessing = true
        let startTime = Date()
        defer { isProcessing = false }

        // Analyze features to determine mood
        let primaryMood = determinePrimaryMood(from: audioFeatures)
        let secondaryMoods = determineSecondaryMoods(from: audioFeatures, excluding: primaryMood)

        // Generate keywords
        let keywords = generateKeywords(
            mood: primaryMood,
            energy: audioFeatures.energy,
            tempo: audioFeatures.tempo
        )

        // Generate natural language description
        let description = generateDescription(
            mood: primaryMood,
            energy: audioFeatures.energy,
            tempo: audioFeatures.tempo,
            duration: duration
        )

        let processingTime = Int(Date().timeIntervalSince(startTime) * 1000)

        let tag = AudioVibeTag(
            primaryMood: primaryMood,
            secondaryMoods: secondaryMoods,
            energyLevel: audioFeatures.energy,
            valence: audioFeatures.valence,
            acousticness: audioFeatures.acousticness,
            danceability: audioFeatures.danceability,
            keywords: keywords,
            generatedDescription: description,
            processingTimeMs: processingTime
        )

        // Cache the result
        cachedVibeTags[tag.id] = tag

        return tag
    }

    // MARK: - Private Methods

    private func detectMood(from text: String) -> String {
        var bestMatch = "neutral"
        var bestScore = 0

        for (mood, keywords) in moodKeywords {
            let score = keywords.reduce(0) { count, keyword in
                text.contains(keyword) ? count + 1 : count
            }
            if score > bestScore {
                bestScore = score
                bestMatch = mood
            }
        }

        return bestMatch
    }

    private func detectScene(from text: String) -> String? {
        for (scene, keywords) in sceneKeywords {
            for keyword in keywords {
                if text.contains(keyword) {
                    return scene
                }
            }
        }
        return nil
    }

    private func analyzeSentiment(_ text: String) -> Double {
        sentimentTagger.string = text

        var totalScore: Double = 0
        var count = 0

        sentimentTagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .sentence,
            scheme: .sentimentScore
        ) { tag, _ in
            if let tag = tag, let score = Double(tag.rawValue) {
                totalScore += score
                count += 1
            }
            return true
        }

        return count > 0 ? totalScore / Double(count) : 0
    }

    private func inferTempo(from text: String, mood: String) -> SemanticQueryResult.TempoRange {
        // Fast indicators
        let fastWords = ["fast", "upbeat", "energetic", "workout", "running", "dance", "party"]
        if fastWords.contains(where: { text.contains($0) }) {
            return .fast
        }

        // Slow indicators
        let slowWords = ["slow", "calm", "peaceful", "meditation", "sleep", "relax", "ambient"]
        if slowWords.contains(where: { text.contains($0) }) {
            return .slow
        }

        // Infer from mood
        switch mood {
        case "calm", "melancholic", "dreamy":
            return .slow
        case "energetic", "happy":
            return .fast
        default:
            return .moderate
        }
    }

    private func inferEnergy(from mood: String, sentiment: Double) -> SemanticQueryResult.EnergyLevel {
        switch mood {
        case "calm":
            return .calm
        case "melancholic", "dreamy":
            return .relaxed
        case "romantic", "mysterious":
            return .balanced
        case "happy":
            return .energetic
        case "energetic":
            return .intense
        default:
            // Use sentiment as fallback
            if sentiment > 0.3 {
                return .energetic
            } else if sentiment < -0.3 {
                return .relaxed
            }
            return .balanced
        }
    }

    private func generatePresetSuggestions(
        mood: String,
        scene: String?,
        energy: SemanticQueryResult.EnergyLevel
    ) -> [String] {
        var presets: [String] = []

        // Mood-based presets
        switch mood {
        case "calm":
            presets.append(contentsOf: ["DeepMeditation", "ZenMaster", "AmbientDrone"])
        case "energetic":
            presets.append(contentsOf: ["ActiveFlow", "TechnoMinimal", "RaveStrobe"])
        case "melancholic":
            presets.append(contentsOf: ["NeoClassical", "AmbientDrone"])
        case "happy":
            presets.append(contentsOf: ["ActiveFlow", "SunriseMeditation"])
        case "focus":
            presets.append(contentsOf: ["FocusFlow", "DeepMeditation"])
        case "dreamy":
            presets.append(contentsOf: ["CosmicNebula", "QuantumField"])
        default:
            presets.append("DefaultPreset")
        }

        // Scene-based additions
        if let scene = scene {
            switch scene {
            case "tokyo":
                presets.append("LoFiBeats")
            case "night":
                presets.append("NightMode")
            case "morning":
                presets.append("SunriseMeditation")
            default:
                break
            }
        }

        return Array(Set(presets)).prefix(5).map { $0 }
    }

    private func calculateConfidence(moodMatch: Bool, sceneMatch: Bool, sentiment: Double) -> Double {
        var confidence = 0.5  // Base confidence

        if moodMatch { confidence += 0.25 }
        if sceneMatch { confidence += 0.15 }
        if abs(sentiment) > 0.3 { confidence += 0.1 }

        return min(1.0, confidence)
    }

    private func determinePrimaryMood(from features: AudioFeatures) -> String {
        if features.energy > 0.7 && features.valence > 0.5 {
            return "energetic"
        } else if features.energy < 0.3 && features.valence > 0.5 {
            return "calm"
        } else if features.valence < 0.3 {
            return "melancholic"
        } else if features.danceability > 0.7 {
            return "groovy"
        } else {
            return "balanced"
        }
    }

    private func determineSecondaryMoods(from features: AudioFeatures, excluding primary: String) -> [String] {
        var moods: [String] = []

        if features.acousticness > 0.6 && primary != "acoustic" {
            moods.append("acoustic")
        }
        if features.energy > 0.5 && primary != "energetic" {
            moods.append("dynamic")
        }
        if features.valence > 0.7 && primary != "happy" {
            moods.append("uplifting")
        }

        return moods
    }

    private func generateKeywords(mood: String, energy: Double, tempo: Double) -> [String] {
        var keywords = [mood]

        if energy > 0.7 {
            keywords.append("high-energy")
        } else if energy < 0.3 {
            keywords.append("chill")
        }

        if tempo > 120 {
            keywords.append("upbeat")
        } else if tempo < 80 {
            keywords.append("slow")
        }

        return keywords
    }

    private func generateDescription(mood: String, energy: Double, tempo: Double, duration: TimeInterval) -> String {
        let energyDesc = energy > 0.7 ? "high-energy" : energy < 0.3 ? "calm" : "balanced"
        let tempoDesc = tempo > 120 ? "upbeat" : tempo < 80 ? "slow-paced" : "moderate-tempo"

        return "A \(energyDesc), \(tempoDesc) piece with \(mood) vibes. Perfect for " +
               (energy > 0.6 ? "active moments" : "relaxation") + "."
    }
}

// MARK: - Audio Features

/// Audio feature extraction result
public struct AudioFeatures: Sendable, Equatable {
    public let tempo: Double           // BPM
    public let energy: Double          // 0.0 - 1.0
    public let valence: Double         // 0.0 - 1.0 (negative to positive)
    public let acousticness: Double    // 0.0 - 1.0
    public let danceability: Double    // 0.0 - 1.0
    public let loudness: Double        // dB
    public let key: Int                // 0-11 (C to B)
    public let mode: Int               // 0 = minor, 1 = major

    public init(
        tempo: Double = 120,
        energy: Double = 0.5,
        valence: Double = 0.5,
        acousticness: Double = 0.5,
        danceability: Double = 0.5,
        loudness: Double = -10,
        key: Int = 0,
        mode: Int = 1
    ) {
        self.tempo = tempo
        self.energy = energy
        self.valence = valence
        self.acousticness = acousticness
        self.danceability = danceability
        self.loudness = loudness
        self.key = key
        self.mode = mode
    }
}

// MARK: - Preview Support

#if DEBUG
extension OnDeviceIntelligenceEngine {
    /// Create a mock result for previews
    public static func mockQueryResult() -> SemanticQueryResult {
        SemanticQueryResult(
            id: UUID(),
            query: "songs that sound like a rainy Tokyo night",
            interpretedMood: "melancholic",
            interpretedGenre: "tokyo",
            interpretedTempo: .slow,
            interpretedEnergy: .relaxed,
            confidenceScore: 0.85,
            suggestedPresets: ["LoFiBeats", "NightMode", "AmbientDrone"],
            timestamp: Date()
        )
    }
}
#endif
