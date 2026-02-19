import Foundation
import Combine
import SwiftUI

// MARK: - LLM Service

/// AI-powered creative assistant and bio-reactive guidance
/// Integrates with Claude, GPT, and local models for:
/// - Session guidance based on bio-state
/// - Creative suggestions and prompts
/// - Bio-data interpretation
/// - Meditation and breathing guidance
/// - Musical theory assistance
@MainActor
class LLMService: ObservableObject {

    private let log = ProfessionalLogger.shared

    // MARK: - Singleton

    static let shared = LLMService()

    // MARK: - Published State

    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var lastResponse: String = ""
    @Published private(set) var conversationHistory: [Message] = []
    @Published private(set) var provider: LLMProvider = .claude
    @Published private(set) var connectionStatus: ConnectionStatus = .disconnected

    // MARK: - Types

    enum LLMProvider: String, CaseIterable {
        case claude = "Claude"
        case openAI = "OpenAI"
        case local = "Local (Ollama)"

        var modelName: String {
            switch self {
            case .claude: return "claude-sonnet-4-20250514"
            case .openAI: return "gpt-4o"
            case .local: return "llama3.2"
            }
        }

        var baseURL: String {
            switch self {
            case .claude: return "https://api.anthropic.com/v1"
            case .openAI: return "https://api.openai.com/v1"
            case .local: return "http://localhost:11434/api"
            }
        }
    }

    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    struct Message: Identifiable, Codable {
        let id: UUID
        let role: Role
        let content: String
        let timestamp: Date
        var bioContext: BioContext?

        /// Structured content blocks (JSON-encoded) for tool_use/tool_result support.
        /// When present, this is used instead of `content` when building API messages.
        /// Stored as Data for Codable compatibility since content blocks contain [String: Any].
        var toolContentJSON: Data?

        enum Role: String, Codable {
            case user
            case assistant
            case system
        }

        struct BioContext: Codable {
            let heartRate: Double
            let hrv: Double
            let coherence: Double
            let bioState: String
        }

        /// Returns the structured content blocks if present, otherwise nil.
        var contentBlocks: [[String: Any]]? {
            guard let data = toolContentJSON,
                  let blocks = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return nil
            }
            return blocks
        }

        /// Extract tool_use IDs from this message's content blocks (for assistant messages).
        var toolUseIds: Set<String> {
            guard let blocks = contentBlocks else { return [] }
            var ids = Set<String>()
            for block in blocks {
                if let type = block["type"] as? String, type == "tool_use",
                   let id = block["id"] as? String {
                    ids.insert(id)
                }
            }
            return ids
        }
    }

    // MARK: - Configuration

    private var apiKey: String?
    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()

    /// Temporarily holds structured content blocks from the last API response
    /// when it contains tool_use blocks. Used by sendMessage to store in the Message.
    private var lastResponseContentBlocks: Data?

    // MARK: - Retry Configuration

    /// Retry policy for API calls
    struct RetryPolicy {
        let maxRetries: Int
        let initialDelay: TimeInterval
        let maxDelay: TimeInterval
        let multiplier: Double
        let retryableStatusCodes: Set<Int>

        static let `default` = RetryPolicy(
            maxRetries: 3,
            initialDelay: 1.0,
            maxDelay: 30.0,
            multiplier: 2.0,
            retryableStatusCodes: [408, 429, 500, 502, 503, 504]
        )
    }

    private let retryPolicy = RetryPolicy.default

    // MARK: - System Prompts

    private let systemPrompt = """
    You are Echoela, the creative AI assistant embedded in Echoelmusic - a bio-reactive music creation platform.

    Your role is to:
    1. Guide users through meditation and music creation sessions based on their biometric state
    2. Interpret HRV, heart rate, and coherence data to provide personalized guidance
    3. Suggest musical elements (scales, tempos, harmonies) that match the user's current state
    4. Offer breathing exercises and meditation techniques
    5. Explain the science behind biofeedback and music-based wellness

    You have access to real-time bio-data and should tailor your responses accordingly.

    Bio-State Reference:
    - High Coherence (>0.7): User is calm and focused. Suggest expansive, creative exploration.
    - Low Coherence (<0.3): User may be stressed. Offer grounding techniques first.
    - High HRV (>60ms): Good recovery state. Optimal for creative work.
    - Low HRV (<30ms): May indicate fatigue or stress. Suggest restorative activities.
    - Elevated Heart Rate (>100bpm): Active state. Match with energetic content or offer calming.

    Musical Guidance:
    - Calm states: Pentatonic, major 7ths, slow tempos (50-70 BPM)
    - Focused states: Dorian mode, moderate tempos (80-100 BPM)
    - Energetic states: Mixolydian, faster tempos (110-130 BPM)
    - Stressed states: Simple intervals, grounding bass, 4/4 time

    Always be warm, supportive, and encouraging. Avoid clinical language.
    Keep responses concise unless the user asks for detailed explanations.
    """

    // MARK: - Initialization

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)

        loadAPIKey()
    }

    private func loadAPIKey() {
        // Load from Keychain or environment
        if let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] {
            apiKey = key
            provider = .claude
        } else if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            apiKey = key
            provider = .openAI
        } else {
            // Check Keychain
            apiKey = KeychainHelper.load(key: "echoelmusic.llm.apikey")
        }
    }

    // MARK: - Configuration

    func configure(provider: LLMProvider, apiKey: String) {
        self.provider = provider
        self.apiKey = apiKey
        KeychainHelper.save(key: "echoelmusic.llm.apikey", value: apiKey)
        connectionStatus = .disconnected
    }

    // MARK: - Chat Interface

    /// Send a message with optional bio-context
    func sendMessage(_ content: String, bioContext: Message.BioContext? = nil) async throws -> String {
        isProcessing = true
        defer { isProcessing = false }

        // Add user message to history
        let userMessage = Message(
            id: UUID(),
            role: .user,
            content: content,
            timestamp: Date(),
            bioContext: bioContext
        )
        conversationHistory.append(userMessage)

        // Build request
        let response = try await sendRequest(messages: conversationHistory, bioContext: bioContext)

        // Add assistant response to history, preserving tool_use content blocks if present
        var assistantMessage = Message(
            id: UUID(),
            role: .assistant,
            content: response,
            timestamp: Date(),
            bioContext: nil
        )
        assistantMessage.toolContentJSON = lastResponseContentBlocks
        lastResponseContentBlocks = nil
        conversationHistory.append(assistantMessage)

        lastResponse = response
        return response
    }

    /// Clear conversation history
    func clearHistory() {
        conversationHistory.removeAll()
        lastResponse = ""
    }

    // MARK: - Bio-Reactive Prompts

    /// Get guidance based on current bio-state.
    /// Privacy: Only sends aggregated bio-state label to the LLM, never raw biometric values.
    func getBioGuidance(heartRate: Double, hrv: Double, coherence: Double) async throws -> String {
        let bioState = determineBioState(heartRate: heartRate, hrv: hrv, coherence: coherence)

        // Only send aggregated state label — raw HR/HRV/coherence never leaves the device
        let prompt = """
        My current bio-state: \(bioState)
        Based on this, what should I focus on right now in my session?
        """

        let context = Message.BioContext(
            heartRate: 0,
            hrv: 0,
            coherence: coherence,
            bioState: bioState
        )

        return try await sendMessage(prompt, bioContext: context)
    }

    /// Get meditation guidance
    func getMeditationGuidance(duration: TimeInterval, focus: MeditationFocus) async throws -> String {
        let prompt = """
        Guide me through a \(Int(duration / 60))-minute \(focus.rawValue) meditation.
        Include breathing patterns and what to focus on.
        """
        return try await sendMessage(prompt)
    }

    /// Get musical suggestions
    func getMusicalSuggestions(bioState: String, genre: String? = nil) async throws -> String {
        var prompt = "Suggest musical elements that would complement my current \(bioState) state."
        if let genre = genre {
            prompt += " I'm working in the \(genre) genre."
        }
        prompt += " Include: key, scale, tempo, chord progression, and instrumentation ideas."

        return try await sendMessage(prompt)
    }

    /// Interpret a session recording
    func interpretSession(bioData: [LLMBioDataPoint]) async throws -> String {
        let summary = summarizeBioData(bioData)

        let prompt = """
        Analyze my session bio-data:
        \(summary)

        What patterns do you notice? How did my state evolve?
        What should I focus on in my next session?
        """

        return try await sendMessage(prompt)
    }

    // MARK: - API Request

    private func sendRequest(messages: [Message], bioContext: Message.BioContext?) async throws -> String {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw LLMError.missingAPIKey
        }

        connectionStatus = .connecting

        switch provider {
        case .claude:
            return try await sendClaudeRequest(messages: messages, bioContext: bioContext, apiKey: apiKey)
        case .openAI:
            return try await sendOpenAIRequest(messages: messages, bioContext: bioContext, apiKey: apiKey)
        case .local:
            return try await sendOllamaRequest(messages: messages, bioContext: bioContext)
        }
    }

    private func sendClaudeRequest(messages: [Message], bioContext: Message.BioContext?, apiKey: String, retryCount: Int = 0) async throws -> String {
        guard let url = URL(string: "\(LLMProvider.claude.baseURL)/messages") else {
            throw LLMError.apiError("Invalid Claude API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // Build system prompt with bio-context — only aggregated state, never raw biometrics
        var fullSystemPrompt = systemPrompt
        if let bio = bioContext {
            fullSystemPrompt += "\n\nCurrent Bio-State: \(bio.bioState)"
        }

        // Build messages array with structured content block support
        let rawAPIMessages = messages.map { buildAPIMessage(from: $0) }

        // Validate tool_result/tool_use pairing to prevent API 400 errors
        let apiMessages = validateAndSanitizeAPIMessages(rawAPIMessages)

        let body: [String: Any] = [
            "model": LLMProvider.claude.modelName,
            "max_tokens": 1024,
            "system": fullSystemPrompt,
            "messages": apiMessages
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.invalidResponse
            }

            // Handle retryable status codes (500, 502, 503, 504, 429, 408)
            if retryPolicy.retryableStatusCodes.contains(httpResponse.statusCode) && retryCount < retryPolicy.maxRetries {
                let delay = min(retryPolicy.initialDelay * pow(retryPolicy.multiplier, Double(retryCount)), retryPolicy.maxDelay)
                log.warning("Claude API returned \(httpResponse.statusCode), retrying in \(delay)s (attempt \(retryCount + 1)/\(retryPolicy.maxRetries))", category: .intelligence)

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await sendClaudeRequest(messages: messages, bioContext: bioContext, apiKey: apiKey, retryCount: retryCount + 1)
            }

            if httpResponse.statusCode != 200 {
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorData["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    // Detect tool_result validation errors specifically
                    if let errorType = error["type"] as? String,
                       errorType == "invalid_request_error",
                       message.contains("tool_use_id") && message.contains("tool_result") {
                        log.error("Tool result validation error: \(message). Conversation history may contain orphaned tool references.", category: .intelligence)
                        throw LLMError.invalidToolResult(message)
                    }
                    throw LLMError.apiError(message)
                }
                throw LLMError.apiError("HTTP \(httpResponse.statusCode)")
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let contentBlocks = json["content"] as? [[String: Any]] else {
                throw LLMError.invalidResponse
            }

            // Extract text from content blocks
            let textParts = contentBlocks.compactMap { block -> String? in
                guard let type = block["type"] as? String, type == "text" else { return nil }
                return block["text"] as? String
            }

            guard !textParts.isEmpty else {
                throw LLMError.invalidResponse
            }

            let text = textParts.joined(separator: "\n")

            // Check if response contains tool_use blocks — store them for future validation
            let hasToolUse = contentBlocks.contains { ($0["type"] as? String) == "tool_use" }
            if hasToolUse {
                log.info("Claude response contains tool_use blocks — storing structured content for validation", category: .intelligence)
                // The caller (sendMessage) will need to store this in the Message's toolContentJSON
                // We store it in a thread-local-like property for the caller to pick up
                lastResponseContentBlocks = try? JSONSerialization.data(withJSONObject: contentBlocks)
            } else {
                lastResponseContentBlocks = nil
            }

            connectionStatus = .connected
            return text

        } catch let error as LLMError {
            throw error
        } catch {
            // Network errors - retry if possible
            if retryCount < retryPolicy.maxRetries {
                let delay = min(retryPolicy.initialDelay * pow(retryPolicy.multiplier, Double(retryCount)), retryPolicy.maxDelay)
                log.warning("Claude API network error, retrying in \(delay)s (attempt \(retryCount + 1)/\(retryPolicy.maxRetries)): \(error.localizedDescription)", category: .intelligence)

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await sendClaudeRequest(messages: messages, bioContext: bioContext, apiKey: apiKey, retryCount: retryCount + 1)
            }
            throw LLMError.networkError(error)
        }
    }

    private func sendOpenAIRequest(messages: [Message], bioContext: Message.BioContext?, apiKey: String, retryCount: Int = 0) async throws -> String {
        guard let url = URL(string: "\(LLMProvider.openAI.baseURL)/chat/completions") else {
            throw LLMError.apiError("Invalid OpenAI API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Build system prompt with bio-context — only aggregated state, never raw biometrics
        var fullSystemPrompt = systemPrompt
        if let bio = bioContext {
            fullSystemPrompt += "\n\nCurrent Bio-State: \(bio.bioState)"
        }

        // Build messages array
        var apiMessages: [[String: String]] = [
            ["role": "system", "content": fullSystemPrompt]
        ]
        apiMessages += messages.map { msg in
            ["role": msg.role == .user ? "user" : "assistant", "content": msg.content]
        }

        let body: [String: Any] = [
            "model": LLMProvider.openAI.modelName,
            "max_tokens": 1024,
            "messages": apiMessages
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw LLMError.invalidResponse
            }

            // Handle retryable status codes (500, 502, 503, 504, 429, 408)
            if retryPolicy.retryableStatusCodes.contains(httpResponse.statusCode) && retryCount < retryPolicy.maxRetries {
                let delay = min(retryPolicy.initialDelay * pow(retryPolicy.multiplier, Double(retryCount)), retryPolicy.maxDelay)
                log.warning("OpenAI API returned \(httpResponse.statusCode), retrying in \(delay)s (attempt \(retryCount + 1)/\(retryPolicy.maxRetries))", category: .intelligence)

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await sendOpenAIRequest(messages: messages, bioContext: bioContext, apiKey: apiKey, retryCount: retryCount + 1)
            }

            if httpResponse.statusCode != 200 {
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorData["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    throw LLMError.apiError(message)
                }
                throw LLMError.apiError("HTTP \(httpResponse.statusCode)")
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                throw LLMError.invalidResponse
            }

            connectionStatus = .connected
            return content

        } catch let error as LLMError {
            throw error
        } catch {
            // Network errors - retry if possible
            if retryCount < retryPolicy.maxRetries {
                let delay = min(retryPolicy.initialDelay * pow(retryPolicy.multiplier, Double(retryCount)), retryPolicy.maxDelay)
                log.warning("OpenAI API network error, retrying in \(delay)s (attempt \(retryCount + 1)/\(retryPolicy.maxRetries)): \(error.localizedDescription)", category: .intelligence)

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await sendOpenAIRequest(messages: messages, bioContext: bioContext, apiKey: apiKey, retryCount: retryCount + 1)
            }
            throw LLMError.networkError(error)
        }
    }

    private func sendOllamaRequest(messages: [Message], bioContext: Message.BioContext?) async throws -> String {
        guard let url = URL(string: "\(LLMProvider.local.baseURL)/chat") else {
            throw LLMError.apiError("Invalid Ollama API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build system prompt with bio-context — only aggregated state, never raw biometrics
        var fullSystemPrompt = systemPrompt
        if let bio = bioContext {
            fullSystemPrompt += "\n\nCurrent Bio-State: \(bio.bioState)"
        }

        // Build messages array for Ollama
        var apiMessages: [[String: String]] = [
            ["role": "system", "content": fullSystemPrompt]
        ]
        apiMessages += messages.map { msg in
            ["role": msg.role == .user ? "user" : "assistant", "content": msg.content]
        }

        let body: [String: Any] = [
            "model": LLMProvider.local.modelName,
            "messages": apiMessages,
            "stream": false
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw LLMError.apiError("Local model not available")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw LLMError.invalidResponse
        }

        connectionStatus = .connected
        return content
    }

    // MARK: - Message Building & Validation

    /// Converts an internal Message to an API-compatible dictionary.
    /// Uses structured content blocks when present, otherwise falls back to simple string content.
    private func buildAPIMessage(from msg: Message) -> [String: Any] {
        let role: String = msg.role == .user ? "user" : "assistant"

        if let contentBlocks = msg.contentBlocks {
            return ["role": role, "content": contentBlocks]
        }

        return ["role": role, "content": msg.content]
    }

    /// Validates and sanitizes an array of API messages to ensure tool_result blocks
    /// have corresponding tool_use blocks in the immediately preceding assistant message.
    ///
    /// This prevents the Claude API error:
    /// "unexpected tool_use_id found in tool_result blocks. Each tool_result block
    /// must have a corresponding tool_use block in the previous message."
    private func validateAndSanitizeAPIMessages(_ messages: [[String: Any]]) -> [[String: Any]] {
        var sanitized: [[String: Any]] = []

        for (index, message) in messages.enumerated() {
            guard let content = message["content"] else {
                sanitized.append(message)
                continue
            }

            // Simple string content — no tool blocks possible
            if content is String {
                sanitized.append(message)
                continue
            }

            // Structured content blocks — validate tool_result references
            guard var contentBlocks = content as? [[String: Any]] else {
                sanitized.append(message)
                continue
            }

            let role = message["role"] as? String ?? ""

            if role == "user" {
                // Collect valid tool_use IDs from the immediately preceding assistant message
                var validToolUseIds = Set<String>()
                if index > 0 {
                    let prevMessage = sanitized[sanitized.count - 1]
                    if let prevRole = prevMessage["role"] as? String, prevRole == "assistant",
                       let prevContent = prevMessage["content"] as? [[String: Any]] {
                        for block in prevContent {
                            if let type = block["type"] as? String, type == "tool_use",
                               let id = block["id"] as? String {
                                validToolUseIds.insert(id)
                            }
                        }
                    }
                }

                // Filter out tool_result blocks that reference non-existent tool_use IDs
                let originalCount = contentBlocks.count
                contentBlocks = contentBlocks.filter { block in
                    guard let type = block["type"] as? String, type == "tool_result" else {
                        return true // Keep non-tool_result blocks
                    }
                    guard let toolUseId = block["tool_use_id"] as? String else {
                        return false // Remove tool_result without a tool_use_id
                    }
                    let isValid = validToolUseIds.contains(toolUseId)
                    if !isValid {
                        log.warning("Stripped orphaned tool_result referencing tool_use_id '\(toolUseId)' — no matching tool_use in preceding assistant message", category: .intelligence)
                    }
                    return isValid
                }

                // If all content blocks were stripped, replace with a text block
                if contentBlocks.isEmpty && originalCount > 0 {
                    contentBlocks = [["type": "text", "text": "[Previous tool results no longer available]"]]
                }

                // If only text blocks remain, simplify to a plain string
                if contentBlocks.allSatisfy({ ($0["type"] as? String) == "text" }) && contentBlocks.count == 1,
                   let text = contentBlocks[0]["text"] as? String {
                    var simplified = message
                    simplified["content"] = text
                    sanitized.append(simplified)
                    continue
                }
            }

            var sanitizedMessage = message
            sanitizedMessage["content"] = contentBlocks
            sanitized.append(sanitizedMessage)
        }

        return sanitized
    }

    // MARK: - Helpers

    private func determineBioState(heartRate: Double, hrv: Double, coherence: Double) -> String {
        if coherence > 0.7 && heartRate < 75 {
            return "Deep Relaxation"
        } else if coherence > 0.5 {
            return "Calm & Focused"
        } else if heartRate > 100 {
            return "Elevated/Active"
        } else if hrv < 30 {
            return "Fatigued"
        } else if coherence < 0.3 {
            return "Scattered/Stressed"
        } else {
            return "Balanced"
        }
    }

    private func summarizeBioData(_ data: [LLMBioDataPoint]) -> String {
        guard !data.isEmpty,
              let firstPoint = data.first,
              let lastPoint = data.last else {
            return "No data available"
        }

        let avgHR = data.map { $0.heartRate }.reduce(0, +) / Double(data.count)
        let avgHRV = data.map { $0.hrv }.reduce(0, +) / Double(data.count)
        let avgCoherence = data.map { $0.coherence }.reduce(0, +) / Double(data.count)
        let duration = lastPoint.timestamp.timeIntervalSince(firstPoint.timestamp)

        return """
        - Duration: \(Int(duration / 60)) minutes
        - Average Heart Rate: \(Int(avgHR)) BPM
        - Average HRV: \(Int(avgHRV)) ms
        - Average Coherence: \(Int(avgCoherence * 100))%
        - Trend: \(avgCoherence > firstPoint.coherence ? "Improving" : "Declining")
        """
    }
}

// MARK: - Types

enum MeditationFocus: String, CaseIterable {
    case breathing = "breathing"
    case bodyAwareness = "body awareness"
    case heartCoherence = "heart coherence"
    case visualization = "visualization"
    case openAwareness = "open awareness"
}

/// Bio data point for LLM context (renamed to avoid conflict with Recording/Session.BioDataPoint)
struct LLMBioDataPoint {
    let timestamp: Date
    let heartRate: Double
    let hrv: Double
    let coherence: Double
}

// MARK: - Errors

enum LLMError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(String)
    case invalidToolResult(String) // Tool_result references a non-existent tool_use_id
    case serverError(Int)  // For 5xx errors after retries exhausted
    case rateLimited       // For 429 errors after retries exhausted
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key configured. Set up your LLM provider in Settings."
        case .invalidResponse:
            return "Received invalid response from LLM service"
        case .apiError(let message):
            return "API Error: \(message)"
        case .invalidToolResult(let message):
            return "Tool Result Validation Error: \(message)"
        case .serverError(let code):
            return "Server Error (\(code)): The AI service is temporarily unavailable. Please try again in a few moments."
        case .rateLimited:
            return "Rate Limited: Too many requests. Please wait a moment before trying again."
        case .networkError(let error):
            return "Network Error: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .missingAPIKey:
            return "Go to Settings > AI to configure your API key."
        case .invalidResponse:
            return "Try again. If the problem persists, the AI service may be experiencing issues."
        case .apiError:
            return "Check your API key and try again."
        case .invalidToolResult:
            return "The conversation history contains invalid tool references. Try clearing the chat history and starting a new conversation."
        case .serverError:
            return "The AI service is experiencing high load. Please wait 30 seconds and try again."
        case .rateLimited:
            return "You've made too many requests. Wait 1 minute before trying again."
        case .networkError:
            return "Check your internet connection and try again."
        }
    }
}

// MARK: - Keychain Helper

private enum KeychainHelper {
    static func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else {
            // Log encoding failure but don't crash
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            // Log keychain error silently in production
        }
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        guard status == errSecSuccess,
              let data = dataTypeRef as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }

        return value
    }
}

// MARK: - SwiftUI Views

/// Chat interface for LLM assistant
struct LLMChatView: View {
    @StateObject private var llm = LLMService.shared
    @State private var inputText = ""
    @State private var showSettings = false

    // Bio context from parent
    var currentHeartRate: Double = 72
    var currentHRV: Double = 50
    var currentCoherence: Double = 0.5

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("Echoela AI")
                    .font(.headline)
                Spacer()
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gear")
                }
            }
            .padding()
            .background(Color(.systemBackground))

            // Messages
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(llm.conversationHistory) { message in
                        MessageBubble(message: message)
                    }

                    if llm.isProcessing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Thinking...")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                    }
                }
                .padding()
            }

            // Input
            HStack(spacing: 12) {
                TextField("Ask Echoela...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(llm.isProcessing)

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(inputText.isEmpty || llm.isProcessing)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .sheet(isPresented: $showSettings) {
            LLMSettingsView()
        }
    }

    private func sendMessage() {
        let text = inputText
        inputText = ""

        Task {
            let context = LLMService.Message.BioContext(
                heartRate: currentHeartRate,
                hrv: currentHRV,
                coherence: currentCoherence,
                bioState: ""
            )

            do {
                _ = try await llm.sendMessage(text, bioContext: context)
            } catch {
                log.error("LLM Error: \(error)", category: .intelligence)
            }
        }
    }
}

struct MessageBubble: View {
    let message: LLMService.Message

    var body: some View {
        HStack {
            if message.role == .user { Spacer() }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(message.role == .user ? Color.purple : Color(.systemGray5))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                if let bio = message.bioContext {
                    HStack(spacing: 8) {
                        Label("\(Int(bio.heartRate))", systemImage: "heart.fill")
                        Label("\(Int(bio.hrv))ms", systemImage: "waveform.path.ecg")
                        Label("\(Int(bio.coherence * 100))%", systemImage: "circle.hexagongrid.fill")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }

            if message.role == .assistant { Spacer() }
        }
    }
}

struct LLMSettingsView: View {
    @StateObject private var llm = LLMService.shared
    @State private var selectedProvider: LLMService.LLMProvider = .claude
    @State private var apiKey = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Provider") {
                    Picker("LLM Provider", selection: $selectedProvider) {
                        ForEach(LLMService.LLMProvider.allCases, id: \.self) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("Model: \(selectedProvider.modelName)")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                if selectedProvider != .local {
                    Section("API Key") {
                        SecureField("Enter API Key", text: $apiKey)
                    }
                }

                Section {
                    Button("Save Configuration") {
                        llm.configure(provider: selectedProvider, apiKey: apiKey)
                        dismiss()
                    }
                    .disabled(selectedProvider != .local && apiKey.isEmpty)
                }

                Section("Status") {
                    HStack {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(statusText)
                    }
                }
            }
            .navigationTitle("AI Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                selectedProvider = llm.provider
            }
        }
    }

    private var statusColor: Color {
        switch llm.connectionStatus {
        case .connected: return .green
        case .connecting: return .yellow
        case .disconnected: return .gray
        case .error: return .red
        }
    }

    private var statusText: String {
        switch llm.connectionStatus {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        case .disconnected: return "Not connected"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

#if DEBUG
#Preview {
    LLMChatView()
}
#endif
