import Foundation
import Combine

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
    }

    // MARK: - Configuration

    private var apiKey: String?
    private let session: URLSession
    private var cancellables = Set<AnyCancellable>()

    // MARK: - System Prompts

    private let systemPrompt = """
    You are Echoel, a creative AI assistant embedded in Echoelmusic - a bio-reactive music creation platform.

    Your role is to:
    1. Guide users through meditation and music creation sessions based on their biometric state
    2. Interpret HRV, heart rate, and coherence data to provide personalized guidance
    3. Suggest musical elements (scales, tempos, harmonies) that match the user's current state
    4. Offer breathing exercises and meditation techniques
    5. Explain the science behind biofeedback and music therapy

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

        // Add assistant response to history
        let assistantMessage = Message(
            id: UUID(),
            role: .assistant,
            content: response,
            timestamp: Date(),
            bioContext: nil
        )
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

    /// Get guidance based on current bio-state
    func getBioGuidance(heartRate: Double, hrv: Double, coherence: Double) async throws -> String {
        let bioState = determineBioState(heartRate: heartRate, hrv: hrv, coherence: coherence)

        let prompt = """
        My current bio-state:
        - Heart Rate: \(Int(heartRate)) BPM
        - HRV: \(Int(hrv)) ms
        - Coherence: \(Int(coherence * 100))%
        - State: \(bioState)

        Based on this, what should I focus on right now in my session?
        """

        let context = Message.BioContext(
            heartRate: heartRate,
            hrv: hrv,
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
    func interpretSession(bioData: [BioDataPoint]) async throws -> String {
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

    private func sendClaudeRequest(messages: [Message], bioContext: Message.BioContext?, apiKey: String) async throws -> String {
        guard let url = URL(string: "\(LLMProvider.claude.baseURL)/messages") else {
            throw LLMError.apiError("Invalid Claude API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        // Build system prompt with bio-context
        var fullSystemPrompt = systemPrompt
        if let bio = bioContext {
            fullSystemPrompt += "\n\nCurrent Bio-Data:\n- Heart Rate: \(Int(bio.heartRate)) BPM\n- HRV: \(Int(bio.hrv)) ms\n- Coherence: \(Int(bio.coherence * 100))%\n- State: \(bio.bioState)"
        }

        // Build messages array
        let apiMessages = messages.map { msg -> [String: String] in
            ["role": msg.role == .user ? "user" : "assistant", "content": msg.content]
        }

        let body: [String: Any] = [
            "model": LLMProvider.claude.modelName,
            "max_tokens": 1024,
            "system": fullSystemPrompt,
            "messages": apiMessages
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
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
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw LLMError.invalidResponse
        }

        connectionStatus = .connected
        return text
    }

    private func sendOpenAIRequest(messages: [Message], bioContext: Message.BioContext?, apiKey: String) async throws -> String {
        guard let url = URL(string: "\(LLMProvider.openAI.baseURL)/chat/completions") else {
            throw LLMError.apiError("Invalid OpenAI API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        // Build system prompt with bio-context
        var fullSystemPrompt = systemPrompt
        if let bio = bioContext {
            fullSystemPrompt += "\n\nCurrent Bio-Data:\n- Heart Rate: \(Int(bio.heartRate)) BPM\n- HRV: \(Int(bio.hrv)) ms\n- Coherence: \(Int(bio.coherence * 100))%\n- State: \(bio.bioState)"
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

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
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
    }

    private func sendOllamaRequest(messages: [Message], bioContext: Message.BioContext?) async throws -> String {
        guard let url = URL(string: "\(LLMProvider.local.baseURL)/chat") else {
            throw LLMError.apiError("Invalid Ollama API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Build system prompt with bio-context
        var fullSystemPrompt = systemPrompt
        if let bio = bioContext {
            fullSystemPrompt += "\n\nCurrent Bio-Data:\n- Heart Rate: \(Int(bio.heartRate)) BPM\n- HRV: \(Int(bio.hrv)) ms\n- Coherence: \(Int(bio.coherence * 100))%\n- State: \(bio.bioState)"
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

    private func summarizeBioData(_ data: [BioDataPoint]) -> String {
        guard !data.isEmpty else { return "No data available" }

        let avgHR = data.map { $0.heartRate }.reduce(0, +) / Double(data.count)
        let avgHRV = data.map { $0.hrv }.reduce(0, +) / Double(data.count)
        let avgCoherence = data.map { $0.coherence }.reduce(0, +) / Double(data.count)
        let duration = data.last!.timestamp.timeIntervalSince(data.first!.timestamp)

        return """
        - Duration: \(Int(duration / 60)) minutes
        - Average Heart Rate: \(Int(avgHR)) BPM
        - Average HRV: \(Int(avgHRV)) ms
        - Average Coherence: \(Int(avgCoherence * 100))%
        - Trend: \(avgCoherence > data.first!.coherence ? "Improving" : "Declining")
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

struct BioDataPoint {
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
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No API key configured. Set up your LLM provider in Settings."
        case .invalidResponse:
            return "Received invalid response from LLM service"
        case .apiError(let message):
            return "API Error: \(message)"
        case .networkError(let error):
            return "Network Error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Keychain Helper

private enum KeychainHelper {
    static func save(key: String, value: String) {
        let data = value.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
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

import SwiftUI

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
                Text("Echoel AI")
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
                TextField("Ask Echoel...", text: $inputText)
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
                print("LLM Error: \(error)")
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

#Preview {
    LLMChatView()
}
