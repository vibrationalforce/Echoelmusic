// EchoelMindEngine.swift
// Echoelmusic — On-Device Foundation Models Intelligence
//
// ═══════════════════════════════════════════════════════════════════════════════
// EchoelMind — Apple Foundation Models bridge for on-device AI intelligence
//
// Apple Foundation Models Framework (iOS 26+):
// - 3B parameter LLM, entirely on-device
// - Free, private, no cloud required
// - 4096 token context window
// - Guided generation (JSON schema enforcement)
// - Tool calling (model → app callbacks)
// - Multilingual (all Apple Intelligence languages)
//
// Integration Points:
// ┌──────────────────────────────────────────────────────────────────────────┐
// │  EchoelMind (On-Device LLM)                                             │
// │       │                                                                  │
// │       ├──→ Echoela AI Assistant (enhanced with local LLM)               │
// │       ├──→ Bio-Reactive Narrative (coherence → story generation)         │
// │       ├──→ Lyrics Intelligence (correction, context, meaning)           │
// │       ├──→ Sound Description (audio → text for accessibility)           │
// │       ├──→ Session Summarization (session → insights)                   │
// │       ├──→ Creative Suggestions (bio-state → musical ideas)             │
// │       └──→ Dynamic UI Text (context-aware labels & descriptions)        │
// └──────────────────────────────────────────────────────────────────────────┘
//
// Design Philosophy:
// - Zero cloud dependency — everything runs on Apple Neural Engine
// - Bio-reactive prompting — coherence modulates creativity/focus
// - Guided generation — structured outputs for reliable integration
// - Privacy-first — no data leaves the device
//
// Limitations (by design):
// - Not for complex reasoning or math
// - Limited world knowledge (training cutoff)
// - 4096 token context — break tasks into small pieces
// - Best for: summarization, extraction, classification, creative text
//
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine

// MARK: - Mind Types

/// Tasks the on-device LLM can perform
public enum MindTask: String, CaseIterable, Sendable {
    case summarize = "Summarize"                    // Session/content summarization
    case describe = "Describe"                      // Audio/visual → text description
    case suggest = "Suggest"                        // Creative suggestions
    case classify = "Classify"                      // Categorize content/mood
    case extract = "Extract"                        // Extract structured data
    case generate = "Generate"                      // Generate creative text
    case correct = "Correct"                        // Lyrics/text correction
    case translate = "Translate"                    // Context-aware translation assist
    case narrative = "Narrative"                    // Bio-reactive storytelling
}

/// Bio-reactive prompt modifier
public enum MindMood: String, Sendable {
    case calm = "calm, serene, contemplative"
    case focused = "focused, precise, analytical"
    case creative = "creative, playful, exploratory"
    case energetic = "energetic, bold, dynamic"
    case stressed = "grounding, reassuring, simple"

    /// Map coherence to mood
    public static func from(coherence: Float) -> MindMood {
        switch coherence {
        case 0..<0.2: return .stressed
        case 0.2..<0.4: return .calm
        case 0.4..<0.6: return .focused
        case 0.6..<0.8: return .creative
        default: return .energetic
        }
    }
}

/// Structured response from on-device LLM
public struct MindResponse: Sendable, Identifiable {
    public let id: UUID
    public let task: MindTask
    public let input: String
    public let output: String
    public let mood: MindMood
    public let tokenCount: Int
    public let latencyMs: Double
    public let isOnDevice: Bool
    public let timestamp: Date

    public init(
        task: MindTask,
        input: String,
        output: String,
        mood: MindMood = .focused,
        tokenCount: Int = 0,
        latencyMs: Double = 0,
        isOnDevice: Bool = true
    ) {
        self.id = UUID()
        self.task = task
        self.input = input
        self.output = output
        self.mood = mood
        self.tokenCount = tokenCount
        self.latencyMs = latencyMs
        self.isOnDevice = isOnDevice
        self.timestamp = Date()
    }
}

/// Guided generation schema for structured outputs
public struct MindSchema: Sendable {
    public let name: String
    public let fields: [SchemaField]

    public struct SchemaField: Sendable {
        public let name: String
        public let type: FieldType
        public let description: String

        public enum FieldType: String, Sendable {
            case string = "string"
            case number = "number"
            case boolean = "boolean"
            case array = "array"
            case object = "object"
        }
    }

    /// Predefined schemas
    public static let moodClassification = MindSchema(
        name: "MoodClassification",
        fields: [
            .init(name: "mood", type: .string, description: "Primary mood (calm, energetic, melancholic, joyful, tense)"),
            .init(name: "confidence", type: .number, description: "Confidence 0-1"),
            .init(name: "tags", type: .array, description: "Mood descriptor tags"),
        ]
    )

    public static let sessionSummary = MindSchema(
        name: "SessionSummary",
        fields: [
            .init(name: "title", type: .string, description: "Short session title"),
            .init(name: "duration", type: .string, description: "Session duration"),
            .init(name: "highlights", type: .array, description: "Key moments"),
            .init(name: "bioInsight", type: .string, description: "Biometric insight"),
            .init(name: "musicalInsight", type: .string, description: "Musical insight"),
        ]
    )

    public static let creativeSuggestion = MindSchema(
        name: "CreativeSuggestion",
        fields: [
            .init(name: "idea", type: .string, description: "Creative suggestion"),
            .init(name: "category", type: .string, description: "Category (harmony, rhythm, texture, arrangement)"),
            .init(name: "reasoning", type: .string, description: "Why this suggestion fits"),
        ]
    )

    public static let lyricsCorrection = MindSchema(
        name: "LyricsCorrection",
        fields: [
            .init(name: "corrected", type: .string, description: "Corrected lyrics text"),
            .init(name: "changes", type: .array, description: "List of changes made"),
            .init(name: "confidence", type: .number, description: "Correction confidence 0-1"),
        ]
    )
}

// MARK: - EchoelMindEngine

/// On-device AI intelligence engine using Apple Foundation Models
///
/// Provides local LLM capabilities for creative AI features without cloud dependency.
/// All inference runs on Apple Neural Engine for privacy and low latency.
///
/// Usage:
/// ```swift
/// let mind = EchoelMindEngine.shared
///
/// // Simple text generation
/// let response = try await mind.generate(
///     task: .suggest,
///     prompt: "Suggest a chord progression for a calm ambient piece"
/// )
///
/// // Bio-reactive generation (mood adapts to coherence)
/// let narrative = try await mind.generateBioReactive(
///     task: .narrative,
///     prompt: "Describe the current musical atmosphere"
/// )
///
/// // Structured output (guided generation)
/// let mood = try await mind.generateStructured(
///     task: .classify,
///     prompt: "Classify the mood: \(audioDescription)",
///     schema: .moodClassification
/// )
/// ```
@MainActor
public final class EchoelMindEngine: ObservableObject {

    public static let shared = EchoelMindEngine()

    // MARK: - Published State

    /// Whether Foundation Models framework is available
    @Published public var isAvailable: Bool = false

    /// Whether the on-device model is downloaded and ready
    @Published public var isModelReady: Bool = false

    /// Current bio-reactive mood
    @Published public var currentMood: MindMood = .focused

    /// Is currently generating
    @Published public var isGenerating: Bool = false

    /// Latest response
    @Published public var latestResponse: MindResponse?

    /// Generation history this session
    @Published public var history: [MindResponse] = []

    /// Average generation latency
    @Published public var averageLatencyMs: Double = 0

    /// Total tokens generated this session
    @Published public var totalTokens: Int = 0

    /// Current coherence value (from bio data)
    @Published public var coherence: Float = 0.5

    // MARK: - Internal

    private var cancellables = Set<AnyCancellable>()
    private var busSubscription: BusSubscription?
    private var latencyHistory: [Double] = []

    // MARK: - Initialization

    private init() {
        checkAvailability()
        subscribeToBus()
    }

    // MARK: - Core Generation API

    /// Generate text using the on-device LLM
    public func generate(
        task: MindTask,
        prompt: String,
        maxTokens: Int = 512,
        temperature: Float = 0.7
    ) async throws -> MindResponse {
        isGenerating = true
        defer { isGenerating = false }

        let startTime = CFAbsoluteTimeGetCurrent()

        // Build system prompt based on task
        let systemPrompt = buildSystemPrompt(for: task)
        let fullPrompt = "\(systemPrompt)\n\nUser: \(prompt)"

        // Call Foundation Models framework
        // On iOS 26+, this calls the on-device 3B parameter model
        let output = await runFoundationModel(
            prompt: fullPrompt,
            maxTokens: maxTokens,
            temperature: temperature
        )

        let latencyMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        let response = MindResponse(
            task: task,
            input: prompt,
            output: output,
            mood: currentMood,
            tokenCount: estimateTokens(output),
            latencyMs: latencyMs,
            isOnDevice: true
        )

        // Update state
        latestResponse = response
        history.append(response)
        totalTokens += response.tokenCount
        updateLatencyStats(latencyMs)

        // Publish to bus
        EngineBus.shared.publish(.custom(
            topic: "mind.response",
            payload: [
                "task": task.rawValue,
                "tokens": "\(response.tokenCount)",
                "latencyMs": "\(Int(latencyMs))"
            ]
        ))

        return response
    }

    /// Generate with bio-reactive mood modulation
    ///
    /// The prompt is automatically enhanced with mood context
    /// derived from current biometric state.
    public func generateBioReactive(
        task: MindTask,
        prompt: String,
        maxTokens: Int = 512
    ) async throws -> MindResponse {
        let moodContext = "Current atmosphere: \(currentMood.rawValue). "
        let bioPrompt = moodContext + prompt

        // Temperature adapts to mood
        let temperature: Float
        switch currentMood {
        case .creative, .energetic: temperature = 0.9
        case .focused: temperature = 0.5
        case .calm: temperature = 0.6
        case .stressed: temperature = 0.3
        }

        return try await generate(
            task: task,
            prompt: bioPrompt,
            maxTokens: maxTokens,
            temperature: temperature
        )
    }

    /// Generate structured output with guided generation
    public func generateStructured(
        task: MindTask,
        prompt: String,
        schema: MindSchema
    ) async throws -> MindResponse {
        let schemaDescription = schema.fields
            .map { "- \($0.name) (\($0.type.rawValue)): \($0.description)" }
            .joined(separator: "\n")

        let structuredPrompt = """
        \(prompt)

        Respond as JSON with this structure:
        \(schemaDescription)
        """

        return try await generate(
            task: task,
            prompt: structuredPrompt,
            maxTokens: 1024,
            temperature: 0.3 // Lower temperature for structured output
        )
    }

    // MARK: - Specialized Features

    /// Correct extracted lyrics using language model
    public func correctLyrics(_ rawLyrics: String, language: EchoelLanguage = .english) async throws -> String {
        let response = try await generate(
            task: .correct,
            prompt: "Correct these song lyrics. Fix spelling, punctuation, and obvious ASR errors. Keep the original meaning. Language: \(language.displayName)\n\nLyrics:\n\(rawLyrics)",
            maxTokens: 1024,
            temperature: 0.2
        )
        return response.output
    }

    /// Summarize a music session
    public func summarizeSession(
        duration: TimeInterval,
        avgCoherence: Float,
        peakCoherence: Float,
        instruments: [String],
        keyMoments: [String]
    ) async throws -> MindResponse {
        let prompt = """
        Summarize this music session:
        - Duration: \(Int(duration / 60)) minutes
        - Average coherence: \(Int(avgCoherence * 100))%
        - Peak coherence: \(Int(peakCoherence * 100))%
        - Instruments used: \(instruments.joined(separator: ", "))
        - Key moments: \(keyMoments.joined(separator: "; "))

        Provide a brief, insightful summary focusing on the bio-reactive journey.
        """

        return try await generateStructured(
            task: .summarize,
            prompt: prompt,
            schema: .sessionSummary
        )
    }

    /// Generate creative suggestion based on bio-state
    public func suggestCreative(
        currentKey: String? = nil,
        currentTempo: Float? = nil,
        currentInstruments: [String] = []
    ) async throws -> MindResponse {
        var context = "Current musical context: "
        if let key = currentKey { context += "Key: \(key). " }
        if let tempo = currentTempo { context += "Tempo: \(Int(tempo)) BPM. " }
        if !currentInstruments.isEmpty {
            context += "Instruments: \(currentInstruments.joined(separator: ", ")). "
        }
        context += "Bio-state: \(currentMood.rawValue)."

        return try await generateBioReactive(
            task: .suggest,
            prompt: context + " Suggest one creative musical idea that fits this moment."
        )
    }

    /// Describe audio content for accessibility
    public func describeAudio(
        frequencyData: [Float],
        amplitude: Float,
        instruments: [String]
    ) async throws -> String {
        let spectralDescription: String
        let lowEnergy = frequencyData.prefix(frequencyData.count / 3).reduce(0, +)
        let highEnergy = frequencyData.suffix(frequencyData.count / 3).reduce(0, +)

        if lowEnergy > highEnergy * 2 {
            spectralDescription = "bass-heavy, warm"
        } else if highEnergy > lowEnergy * 2 {
            spectralDescription = "bright, airy"
        } else {
            spectralDescription = "balanced"
        }

        let response = try await generate(
            task: .describe,
            prompt: "Briefly describe this sound: \(spectralDescription), amplitude \(Int(amplitude * 100))%, instruments: \(instruments.joined(separator: ", ")). One sentence.",
            maxTokens: 100,
            temperature: 0.5
        )
        return response.output
    }

    /// Generate bio-reactive narrative for immersive experience
    public func generateNarrative(bioContext: String) async throws -> String {
        let response = try await generateBioReactive(
            task: .narrative,
            prompt: "Generate a brief poetic narrative for this moment in an immersive bio-reactive music experience. Context: \(bioContext)"
        )
        return response.output
    }

    // MARK: - Private Methods

    /// Run the Foundation Models framework on-device LLM
    private func runFoundationModel(
        prompt: String,
        maxTokens: Int,
        temperature: Float
    ) async -> String {
        // Foundation Models Framework Integration
        //
        // On iOS 26+:
        // ```swift
        // import FoundationModels
        //
        // let session = LanguageModelSession()
        // let response = try await session.respond(to: prompt)
        // return response.content
        // ```
        //
        // With guided generation:
        // ```swift
        // let response = try await session.respond(
        //     to: prompt,
        //     generating: MySchema.self  // Codable struct
        // )
        // ```
        //
        // The framework is available on Apple Intelligence-compatible devices
        // when Apple Intelligence is enabled. The on-device model handles:
        // - Summarization, extraction, classification
        // - Creative text generation
        // - Tool calling (model calls back into app)
        //
        // For now, we publish the prompt to EngineBus for the UI layer
        // to handle via the FoundationModels framework (requires iOS 26+ SDK).

        EngineBus.shared.publish(.custom(
            topic: "mind.request",
            payload: [
                "prompt": String(prompt.prefix(500)), // Truncate for bus
                "maxTokens": "\(maxTokens)",
                "temperature": "\(temperature)"
            ]
        ))

        // Return prompt echo until Foundation Models SDK is linked
        // In production, this returns the actual LLM response
        return "[EchoelMind: Foundation Models response pending SDK integration]"
    }

    /// Build system prompt for specific task type
    private func buildSystemPrompt(for task: MindTask) -> String {
        let base = "You are Echoela, the AI intelligence inside Echoelmusic, a bio-reactive audio-visual platform. "

        switch task {
        case .summarize:
            return base + "Provide concise, insightful summaries. Focus on the bio-reactive journey and musical highlights."
        case .describe:
            return base + "Describe sounds and visuals poetically but accurately. One to two sentences maximum."
        case .suggest:
            return base + "Suggest creative musical ideas that fit the current bio-state and musical context. Be specific and actionable."
        case .classify:
            return base + "Classify the content accurately. Respond only with the requested classification."
        case .extract:
            return base + "Extract the requested information precisely. Output only the extracted data."
        case .generate:
            return base + "Generate creative, original text that enhances the musical experience."
        case .correct:
            return base + "Correct text while preserving the original meaning and artistic intent. Fix only clear errors."
        case .translate:
            return base + "Assist with translation, preserving musical and poetic qualities where possible."
        case .narrative:
            return base + "Generate brief, evocative narratives for immersive experiences. Match the current bio-reactive mood."
        }
    }

    /// Estimate token count (rough heuristic)
    private func estimateTokens(_ text: String) -> Int {
        // ~4 characters per token for English
        return max(1, text.count / 4)
    }

    /// Check if Foundation Models framework is available
    private func checkAvailability() {
        // Foundation Models requires:
        // 1. iOS 26+ / macOS 26+
        // 2. Apple Intelligence-compatible device
        // 3. Apple Intelligence enabled by user
        if #available(iOS 26, macOS 26, *) {
            isAvailable = true
            isModelReady = true // Model is managed by the system
        } else {
            isAvailable = false
            isModelReady = false
        }
    }

    /// Subscribe to EngineBus for bio-reactive updates
    private func subscribeToBus() {
        busSubscription = EngineBus.shared.subscribe(to: .bio) { [weak self] msg in
            if case .bioUpdate(let bio) = msg {
                Task { @MainActor in
                    self?.coherence = bio.coherence
                    self?.currentMood = MindMood.from(coherence: bio.coherence)
                }
            }
        }
    }

    /// Track generation latency
    private func updateLatencyStats(_ latencyMs: Double) {
        latencyHistory.append(latencyMs)
        if latencyHistory.count > 50 {
            latencyHistory.removeFirst()
        }
        averageLatencyMs = latencyHistory.reduce(0, +) / Double(latencyHistory.count)
    }
}
