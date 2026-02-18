// MARK: - EchoelaManager.swift
// Echoelmusic Suite - Echoela AI Assistant Core
// Copyright 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine

// MARK: - Echoela Manager

/// Central AI Assistant Manager for the Echoelmusic Suite
/// Shared across all targets: Main App, AUv3, App Clip, watchOS, Widgets
@MainActor
public final class EchoelaManager: ObservableObject {

    // MARK: - Singleton

    public static let shared = EchoelaManager()

    // MARK: - Published State

    @Published public private(set) var isActive: Bool = false
    @Published public private(set) var currentContext: EchoelaContext = .idle
    @Published public private(set) var highlightedElement: String?
    @Published public private(set) var lastResponse: EchoelaResponse?
    @Published public private(set) var conversationHistory: [EchoelaMessage] = []
    @Published public private(set) var availableTools: [EchoelaTool] = []

    // MARK: - Types

    public enum EchoelaContext: String, Codable {
        case idle
        case production          // DAW/Production mode
        case performance         // Live performance
        case minting             // NFT creation
        case meditation          // Wellness session
        case collaboration       // Multi-user session
        case auv3                // Running as AUv3 plugin
        case watchSensing        // watchOS biometric capture
        case widgetPreview       // Widget interaction
        case appClipPreview      // App Clip instant experience
    }

    public struct EchoelaMessage: Identifiable, Codable {
        public let id: UUID
        public let role: Role
        public let content: String
        public let timestamp: Date
        public var tools: [ToolCall]?
        public var bioContext: BioContext?

        public enum Role: String, Codable {
            case user
            case assistant
            case system
            case tool
        }

        public struct ToolCall: Codable {
            public let toolID: String
            public let action: String
            public let parameters: [String: String]
            public let deepLink: URL?
        }

        public struct BioContext: Codable {
            public let heartRate: Double
            public let hrv: Double
            public let coherence: Double
            public let eegBands: EEGBands?

            public struct EEGBands: Codable {
                public let delta: Double
                public let theta: Double
                public let alpha: Double
                public let beta: Double
                public let gamma: Double
            }
        }
    }

    public struct EchoelaResponse: Codable {
        public let text: String
        public let highlightElements: [String]
        public let suggestedActions: [SuggestedAction]
        public let deepLinks: [URL]

        public struct SuggestedAction: Codable {
            public let title: String
            public let icon: String
            public let deepLink: URL
            public let isDestructive: Bool
        }
    }

    public struct EchoelaTool: Identifiable, Codable {
        public let id: String
        public let name: String
        public let description: String
        public let category: ToolCategory
        public let deepLinkScheme: String
        public let requiredPermissions: [Permission]

        public enum ToolCategory: String, Codable {
            case production       // Audio/visual production
            case nft              // NFT minting & management
            case biometric        // Health data access
            case collaboration    // Multi-user features
            case settings         // App configuration
            case compliance       // Legal/licensing checks
        }

        public enum Permission: String, Codable {
            case healthKit
            case microphone
            case camera
            case location
            case blockchain
            case notifications
        }
    }

    // MARK: - Configuration

    private var cancellables = Set<AnyCancellable>()

    /// Deep link URL scheme
    public static let deepLinkScheme = "echoelmusic"

    /// Available tool definitions
    private let toolDefinitions: [EchoelaTool] = [
        EchoelaTool(
            id: "start_meditation",
            name: "Start Meditation",
            description: "Begin a bio-reactive meditation session",
            category: .biometric,
            deepLinkScheme: "echoelmusic://action/meditation/start",
            requiredPermissions: [.healthKit]
        ),
        EchoelaTool(
            id: "mint_nft",
            name: "Mint NFT",
            description: "Create an NFT from the current session",
            category: .nft,
            deepLinkScheme: "echoelmusic://action/nft/mint",
            requiredPermissions: [.blockchain]
        ),
        EchoelaTool(
            id: "watch_sensing",
            name: "Start Watch Sensing",
            description: "Begin biometric data collection on Apple Watch",
            category: .biometric,
            deepLinkScheme: "echoelmusic://action/watch/sense",
            requiredPermissions: [.healthKit]
        ),
        EchoelaTool(
            id: "auv3_lock",
            name: "Lock AUv3 Parameters",
            description: "Lock current parameters in the AUv3 plugin",
            category: .production,
            deepLinkScheme: "echoelmusic://action/auv3/lock",
            requiredPermissions: []
        ),
        EchoelaTool(
            id: "collaboration_invite",
            name: "Invite Collaborator",
            description: "Send collaboration invite to another artist",
            category: .collaboration,
            deepLinkScheme: "echoelmusic://action/collab/invite",
            requiredPermissions: [.notifications]
        ),
        EchoelaTool(
            id: "gema_verify",
            name: "Verify GEMA/ISRC",
            description: "Check licensing compliance for the current track",
            category: .compliance,
            deepLinkScheme: "echoelmusic://action/compliance/gema",
            requiredPermissions: []
        ),
        EchoelaTool(
            id: "splits_configure",
            name: "Configure Revenue Splits",
            description: "Set up 0xSplits for collaborator payments",
            category: .nft,
            deepLinkScheme: "echoelmusic://action/nft/splits",
            requiredPermissions: [.blockchain]
        ),
        // Morphic Engine tools
        EchoelaTool(
            id: "morphic_create",
            name: "Create Morphic Effect",
            description: "Generate a custom DSP effect from a natural language description",
            category: .production,
            deepLinkScheme: "echoelmusic://action/morphic/create",
            requiredPermissions: []
        ),
        EchoelaTool(
            id: "morphic_preset",
            name: "Load Morphic Preset",
            description: "Load a built-in Morphic effect preset",
            category: .production,
            deepLinkScheme: "echoelmusic://action/morphic/preset",
            requiredPermissions: []
        ),
        EchoelaTool(
            id: "morphic_bio",
            name: "Bio-Bind Morphic Effect",
            description: "Connect biometric signals to effect parameters",
            category: .biometric,
            deepLinkScheme: "echoelmusic://action/morphic/bio",
            requiredPermissions: [.healthKit]
        ),
        EchoelaTool(
            id: "morphic_sandbox",
            name: "Sandbox Status",
            description: "Check Morphic sandbox health and active sessions",
            category: .production,
            deepLinkScheme: "echoelmusic://action/morphic/status",
            requiredPermissions: []
        )
    ]

    // MARK: - Initialization

    private init() {
        availableTools = toolDefinitions
        setupContextObservers()
    }

    private func setupContextObservers() {
        // Monitor context changes for tool availability
        $currentContext
            .sink { [weak self] context in
                self?.updateAvailableTools(for: context)
            }
            .store(in: &cancellables)
    }

    private func updateAvailableTools(for context: EchoelaContext) {
        // Filter tools based on current context
        switch context {
        case .auv3:
            availableTools = toolDefinitions.filter { $0.category == .production }
        case .watchSensing:
            availableTools = toolDefinitions.filter { $0.category == .biometric }
        case .minting:
            availableTools = toolDefinitions.filter { $0.category == .nft || $0.category == .compliance }
        case .appClipPreview:
            availableTools = toolDefinitions.filter { $0.id == "mint_nft" }
        default:
            availableTools = toolDefinitions
        }
    }

    // MARK: - Public API

    /// Activate Echoela assistant
    public func activate(in context: EchoelaContext = .idle) {
        isActive = true
        currentContext = context
        log.info("Echoela activated in context: \(context.rawValue)")
    }

    /// Deactivate Echoela assistant
    public func deactivate() {
        isActive = false
        highlightedElement = nil
        log.info("Echoela deactivated")
    }

    /// Set the current context
    public func setContext(_ context: EchoelaContext) {
        currentContext = context
        log.info("Echoela context changed to: \(context.rawValue)")
    }

    /// Highlight a UI element
    public func highlight(elementID: String?) {
        highlightedElement = elementID
        if let id = elementID {
            log.debug("Highlighting element: \(id)")
        }
    }

    /// Send a message to Echoela
    public func sendMessage(_ content: String, bioContext: EchoelaMessage.BioContext? = nil) async throws -> EchoelaResponse {
        let userMessage = EchoelaMessage(
            id: UUID(),
            role: .user,
            content: content,
            timestamp: Date(),
            tools: nil,
            bioContext: bioContext
        )
        conversationHistory.append(userMessage)

        // Process with on-device Foundation Models or fallback to LLM
        let response = try await processMessage(userMessage)

        let assistantMessage = EchoelaMessage(
            id: UUID(),
            role: .assistant,
            content: response.text,
            timestamp: Date(),
            tools: extractToolCalls(from: response),
            bioContext: nil
        )
        conversationHistory.append(assistantMessage)

        lastResponse = response
        return response
    }

    /// Execute a deep link action
    public func executeDeepLink(_ url: URL) {
        guard url.scheme == Self.deepLinkScheme else {
            log.warning("Invalid deep link scheme: \(url.scheme ?? "nil")")
            return
        }

        log.info("Executing deep link: \(url.absoluteString)")

        // Parse and execute action
        if let host = url.host, host == "action" {
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            handleAction(pathComponents, queryItems: URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        }
    }

    /// Generate a deep link for an action
    public func generateDeepLink(action: String, id: String? = nil, parameters: [String: String]? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = Self.deepLinkScheme
        components.host = "action"
        components.path = id.map { "/\(action)/\($0)" } ?? "/\(action)"

        if let params = parameters {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        return components.url
    }

    /// Clear conversation history
    public func clearHistory() {
        conversationHistory.removeAll()
        lastResponse = nil
    }

    // MARK: - Private Methods

    private func processMessage(_ message: EchoelaMessage) async throws -> EchoelaResponse {
        // Build context-aware prompt
        let contextPrompt = buildContextPrompt(for: message)

        // Try on-device processing first (Foundation Models Framework)
        if let onDeviceResponse = try? await processOnDevice(contextPrompt) {
            return onDeviceResponse
        }

        // Fallback to cloud LLM
        return try await processWithLLM(message)
    }

    private func buildContextPrompt(for message: EchoelaMessage) -> String {
        var prompt = """
        You are Echoela, the AI assistant for Echoelmusic - a bio-reactive audio-visual platform.

        Current Context: \(currentContext.rawValue)
        Available Tools: \(availableTools.map { $0.name }.joined(separator: ", "))

        """

        if let bio = message.bioContext {
            prompt += """

            User's Current Bio-State:
            - Heart Rate: \(Int(bio.heartRate)) BPM
            - HRV: \(Int(bio.hrv)) ms
            - Coherence: \(Int(bio.coherence * 100))%
            """

            if let eeg = bio.eegBands {
                prompt += """

                - EEG: Delta=\(eeg.delta), Theta=\(eeg.theta), Alpha=\(eeg.alpha), Beta=\(eeg.beta), Gamma=\(eeg.gamma)
                """
            }
        }

        prompt += """

        When suggesting actions, generate deep links in the format: echoelmusic://action/[category]/[action]

        User Message: \(message.content)
        """

        return prompt
    }

    private func processOnDevice(_ prompt: String) async throws -> EchoelaResponse? {
        // Foundation Models Framework integration (iOS 19+, macOS 15+, visionOS 26+)
        // This would use Apple's on-device AI capabilities
        // For now, return nil to fallback to cloud processing
        return nil
    }

    private func processWithLLM(_ message: EchoelaMessage) async throws -> EchoelaResponse {
        // Use existing LLMService
        let llmResponse = try await LLMService.shared.sendMessage(
            message.content,
            bioContext: message.bioContext.map {
                LLMService.Message.BioContext(
                    heartRate: $0.heartRate,
                    hrv: $0.hrv,
                    coherence: $0.coherence,
                    bioState: currentContext.rawValue
                )
            }
        )

        // Parse response for deep links and highlights
        let deepLinks = extractDeepLinks(from: llmResponse)
        let highlights = extractHighlights(from: llmResponse)
        let actions = extractSuggestedActions(from: llmResponse)

        return EchoelaResponse(
            text: llmResponse,
            highlightElements: highlights,
            suggestedActions: actions,
            deepLinks: deepLinks
        )
    }

    private func extractDeepLinks(from text: String) -> [URL] {
        let pattern = "echoelmusic://[\\w/\\-\\?=&]+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        return matches.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return URL(string: String(text[range]))
        }
    }

    private func extractHighlights(from text: String) -> [String] {
        // Extract element IDs mentioned for highlighting
        let pattern = "\\[highlight:([\\w\\-]+)\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        return matches.compactMap { match in
            guard match.numberOfRanges > 1,
                  let range = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[range])
        }
    }

    private func extractSuggestedActions(from text: String) -> [EchoelaResponse.SuggestedAction] {
        // Generate contextual actions based on response content
        var actions: [EchoelaResponse.SuggestedAction] = []

        if text.lowercased().contains("meditation") || text.lowercased().contains("breathing") {
            if let url = generateDeepLink(action: "meditation/start") {
                actions.append(EchoelaResponse.SuggestedAction(
                    title: "Start Meditation",
                    icon: "heart.circle.fill",
                    deepLink: url,
                    isDestructive: false
                ))
            }
        }

        if text.lowercased().contains("nft") || text.lowercased().contains("mint") {
            if let url = generateDeepLink(action: "nft/mint") {
                actions.append(EchoelaResponse.SuggestedAction(
                    title: "Mint NFT",
                    icon: "sparkles.rectangle.stack",
                    deepLink: url,
                    isDestructive: false
                ))
            }
        }

        if text.lowercased().contains("collaborate") || text.lowercased().contains("invite") {
            if let url = generateDeepLink(action: "collab/invite") {
                actions.append(EchoelaResponse.SuggestedAction(
                    title: "Invite Collaborator",
                    icon: "person.2.fill",
                    deepLink: url,
                    isDestructive: false
                ))
            }
        }

        if text.lowercased().contains("effect") || text.lowercased().contains("morphic") || text.lowercased().contains("create") || text.lowercased().contains("custom") {
            if let url = generateDeepLink(action: "morphic/create") {
                actions.append(EchoelaResponse.SuggestedAction(
                    title: "Create Morphic Effect",
                    icon: "wand.and.stars",
                    deepLink: url,
                    isDestructive: false
                ))
            }
        }

        return actions
    }

    private func extractToolCalls(from response: EchoelaResponse) -> [EchoelaMessage.ToolCall]? {
        guard !response.deepLinks.isEmpty else { return nil }

        return response.deepLinks.compactMap { url -> EchoelaMessage.ToolCall? in
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }

            let pathComponents = components.path.split(separator: "/").map(String.init)
            guard pathComponents.count >= 1 else { return nil }

            let action = pathComponents.joined(separator: "/")
            let parameters = (components.queryItems ?? []).reduce(into: [String: String]()) { dict, item in
                dict[item.name] = item.value ?? ""
            }

            return EchoelaMessage.ToolCall(
                toolID: pathComponents.first ?? "unknown",
                action: action,
                parameters: parameters,
                deepLink: url
            )
        }
    }

    private func handleAction(_ pathComponents: [String], queryItems: [URLQueryItem]?) {
        guard let category = pathComponents.first else { return }

        let action = pathComponents.dropFirst().joined(separator: "/")
        let params = (queryItems ?? []).reduce(into: [String: String]()) { dict, item in
            dict[item.name] = item.value ?? ""
        }

        log.info("Handling action: \(category)/\(action) with params: \(params)")

        // Dispatch to appropriate handler
        switch category {
        case "meditation":
            handleMeditationAction(action, params: params)
        case "nft":
            handleNFTAction(action, params: params)
        case "watch":
            handleWatchAction(action, params: params)
        case "auv3":
            handleAUv3Action(action, params: params)
        case "collab":
            handleCollaborationAction(action, params: params)
        case "compliance":
            handleComplianceAction(action, params: params)
        case "morphic":
            handleMorphicAction(action, params: params)
        default:
            log.warning("Unknown action category: \(category)")
        }
    }

    private func handleMeditationAction(_ action: String, params: [String: String]) {
        NotificationCenter.default.post(
            name: .echoelaAction,
            object: nil,
            userInfo: ["category": "meditation", "action": action, "params": params]
        )
    }

    private func handleNFTAction(_ action: String, params: [String: String]) {
        NotificationCenter.default.post(
            name: .echoelaAction,
            object: nil,
            userInfo: ["category": "nft", "action": action, "params": params]
        )
    }

    private func handleWatchAction(_ action: String, params: [String: String]) {
        NotificationCenter.default.post(
            name: .echoelaAction,
            object: nil,
            userInfo: ["category": "watch", "action": action, "params": params]
        )
    }

    private func handleAUv3Action(_ action: String, params: [String: String]) {
        NotificationCenter.default.post(
            name: .echoelaAction,
            object: nil,
            userInfo: ["category": "auv3", "action": action, "params": params]
        )
    }

    private func handleCollaborationAction(_ action: String, params: [String: String]) {
        NotificationCenter.default.post(
            name: .echoelaAction,
            object: nil,
            userInfo: ["category": "collab", "action": action, "params": params]
        )
    }

    private func handleComplianceAction(_ action: String, params: [String: String]) {
        NotificationCenter.default.post(
            name: .echoelaAction,
            object: nil,
            userInfo: ["category": "compliance", "action": action, "params": params]
        )
    }

    private func handleMorphicAction(_ action: String, params: [String: String]) {
        switch action {
        case "create":
            // Compile a new Morphic effect from description
            if let description = params["description"] {
                Task {
                    do {
                        let session = try await MorphicSandboxManager.shared.compileAndRun(
                            description: description,
                            name: params["name"]
                        )
                        log.info("Morphic: created and activated effect '\(session.graph.name)'")
                    } catch {
                        log.error("Morphic create failed: \(error.localizedDescription)")
                    }
                }
            }
        case "preset":
            // Load a Morphic preset
            NotificationCenter.default.post(
                name: .echoelaAction,
                object: nil,
                userInfo: ["category": "morphic", "action": "preset", "params": params]
            )
        case "bio":
            // Toggle bio-reactive binding
            MorphicSandboxManager.shared.config.bioReactiveEnabled = params["enabled"] != "false"
        case "status":
            // Report sandbox health
            let report = MorphicSandboxManager.shared.healthReport
            log.info("Morphic sandbox: \(report.activeSessions)/\(report.maxSessions) sessions, CPU: \(String(format: "%.0f", report.averageCPU * 100))%, healthy: \(report.isHealthy)")
        default:
            NotificationCenter.default.post(
                name: .echoelaAction,
                object: nil,
                userInfo: ["category": "morphic", "action": action, "params": params]
            )
        }
    }
}

// MARK: - Notification Names

public extension Notification.Name {
    static let echoelaAction = Notification.Name("com.echoelmusic.echoela.action")
    static let echoelaHighlight = Notification.Name("com.echoelmusic.echoela.highlight")
    static let echoelaContextChanged = Notification.Name("com.echoelmusic.echoela.contextChanged")
}
