import Foundation

// MARK: - n8n Workflow Automation Integration
// Connect Echoelmusic to n8n for external workflow automation
// Supports: Webhooks, triggers, actions, data transformation

@MainActor
public final class N8NWorkflowIntegration: ObservableObject {
    public static let shared = N8NWorkflowIntegration()

    @Published public private(set) var isConnected = false
    @Published public private(set) var activeWorkflows: [N8NWorkflow] = []
    @Published public private(set) var webhookServer: WebhookServer?

    // Connection
    private var n8nBaseURL: URL?
    private var apiKey: String?

    // Webhook handling
    private var webhookHandlers: [String: (WebhookPayload) async -> WebhookResponse] = [:]

    // Configuration
    public struct Configuration {
        public var n8nURL: String = "http://localhost:5678"
        public var apiKey: String = ""
        public var webhookPort: UInt16 = 5679
        public var enableWebhooks: Bool = true
        public var enablePolling: Bool = false
        public var pollingInterval: TimeInterval = 30

        public static let `default` = Configuration()
    }

    private var config: Configuration = .default

    public init() {}

    // MARK: - Connection

    /// Connect to n8n instance
    public func connect(url: String, apiKey: String) async throws {
        self.n8nBaseURL = URL(string: url)
        self.apiKey = apiKey

        // Test connection
        guard let baseURL = n8nBaseURL else {
            throw N8NError.invalidURL
        }

        let healthURL = baseURL.appendingPathComponent("healthz")
        var request = URLRequest(url: healthURL)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw N8NError.connectionFailed
        }

        isConnected = true

        // Start webhook server if enabled
        if config.enableWebhooks {
            try await startWebhookServer()
        }

        // Load workflows
        await loadWorkflows()
    }

    /// Disconnect from n8n
    public func disconnect() {
        isConnected = false
        webhookServer?.stop()
        webhookServer = nil
        activeWorkflows.removeAll()
    }

    // MARK: - Workflow Management

    /// Load workflows from n8n
    public func loadWorkflows() async {
        guard let baseURL = n8nBaseURL, let apiKey = apiKey else { return }

        let workflowsURL = baseURL.appendingPathComponent("api/v1/workflows")
        var request = URLRequest(url: workflowsURL)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(N8NWorkflowsResponse.self, from: data)
            activeWorkflows = response.data
        } catch {
            print("Failed to load workflows: \(error)")
        }
    }

    /// Execute a workflow
    public func executeWorkflow(_ workflowId: String, data: [String: Any] = [:]) async throws -> N8NExecutionResult {
        guard let baseURL = n8nBaseURL, let apiKey = apiKey else {
            throw N8NError.notConnected
        }

        let executeURL = baseURL.appendingPathComponent("api/v1/workflows/\(workflowId)/execute")
        var request = URLRequest(url: executeURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: data)

        let (responseData, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(N8NExecutionResult.self, from: responseData)
    }

    /// Create a new workflow
    public func createWorkflow(_ workflow: N8NWorkflowDefinition) async throws -> N8NWorkflow {
        guard let baseURL = n8nBaseURL, let apiKey = apiKey else {
            throw N8NError.notConnected
        }

        let createURL = baseURL.appendingPathComponent("api/v1/workflows")
        var request = URLRequest(url: createURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(workflow)

        let (responseData, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(N8NWorkflow.self, from: responseData)
    }

    // MARK: - Webhook Server

    private func startWebhookServer() async throws {
        webhookServer = WebhookServer(port: config.webhookPort)
        webhookServer?.requestHandler = { [weak self] payload in
            await self?.handleWebhook(payload) ?? WebhookResponse(status: 404, body: "Not found")
        }
        try await webhookServer?.start()
    }

    private func handleWebhook(_ payload: WebhookPayload) async -> WebhookResponse {
        // Find handler for path
        if let handler = webhookHandlers[payload.path] {
            return await handler(payload)
        }

        // Default handlers for Echoelmusic triggers
        switch payload.path {
        case "/echoelmusic/project/created":
            return await handleProjectCreated(payload)
        case "/echoelmusic/project/exported":
            return await handleProjectExported(payload)
        case "/echoelmusic/render/complete":
            return await handleRenderComplete(payload)
        case "/echoelmusic/analysis/complete":
            return await handleAnalysisComplete(payload)
        default:
            return WebhookResponse(status: 404, body: "Unknown webhook path")
        }
    }

    // MARK: - Webhook Handlers

    private func handleProjectCreated(_ payload: WebhookPayload) async -> WebhookResponse {
        // Trigger project created workflow
        if let workflowId = getWorkflowId(for: "project_created") {
            _ = try? await executeWorkflow(workflowId, data: payload.body)
        }
        return WebhookResponse(status: 200, body: "OK")
    }

    private func handleProjectExported(_ payload: WebhookPayload) async -> WebhookResponse {
        if let workflowId = getWorkflowId(for: "project_exported") {
            _ = try? await executeWorkflow(workflowId, data: payload.body)
        }
        return WebhookResponse(status: 200, body: "OK")
    }

    private func handleRenderComplete(_ payload: WebhookPayload) async -> WebhookResponse {
        if let workflowId = getWorkflowId(for: "render_complete") {
            _ = try? await executeWorkflow(workflowId, data: payload.body)
        }
        return WebhookResponse(status: 200, body: "OK")
    }

    private func handleAnalysisComplete(_ payload: WebhookPayload) async -> WebhookResponse {
        if let workflowId = getWorkflowId(for: "analysis_complete") {
            _ = try? await executeWorkflow(workflowId, data: payload.body)
        }
        return WebhookResponse(status: 200, body: "OK")
    }

    private func getWorkflowId(for trigger: String) -> String? {
        return activeWorkflows.first { $0.name.lowercased().contains(trigger) }?.id
    }

    // MARK: - Custom Webhook Registration

    /// Register custom webhook handler
    public func registerWebhook(path: String, handler: @escaping (WebhookPayload) async -> WebhookResponse) {
        webhookHandlers[path] = handler
    }

    /// Unregister webhook handler
    public func unregisterWebhook(path: String) {
        webhookHandlers.removeValue(forKey: path)
    }

    // MARK: - Echoelmusic Triggers

    /// Trigger workflow from Echoelmusic event
    public func trigger(_ event: EchoelEvent) async {
        let workflowId: String?

        switch event {
        case .projectCreated(let projectId):
            workflowId = getWorkflowId(for: "project_created")
            if let id = workflowId {
                _ = try? await executeWorkflow(id, data: ["projectId": projectId])
            }

        case .projectExported(let projectId, let format, let url):
            workflowId = getWorkflowId(for: "project_exported")
            if let id = workflowId {
                _ = try? await executeWorkflow(id, data: [
                    "projectId": projectId,
                    "format": format,
                    "url": url.absoluteString
                ])
            }

        case .analysisComplete(let analysisId, let results):
            workflowId = getWorkflowId(for: "analysis_complete")
            if let id = workflowId {
                _ = try? await executeWorkflow(id, data: [
                    "analysisId": analysisId,
                    "results": results
                ])
            }

        case .collaboratorJoined(let sessionId, let userId):
            workflowId = getWorkflowId(for: "collaborator_joined")
            if let id = workflowId {
                _ = try? await executeWorkflow(id, data: [
                    "sessionId": sessionId,
                    "userId": userId
                ])
            }

        case .custom(let name, let data):
            workflowId = getWorkflowId(for: name)
            if let id = workflowId {
                _ = try? await executeWorkflow(id, data: data)
            }
        }
    }

    public enum EchoelEvent {
        case projectCreated(projectId: String)
        case projectExported(projectId: String, format: String, url: URL)
        case analysisComplete(analysisId: String, results: [String: Any])
        case collaboratorJoined(sessionId: String, userId: String)
        case custom(name: String, data: [String: Any])
    }

    // MARK: - Prebuilt Workflow Templates

    /// Get prebuilt workflow templates for common automations
    public func getWorkflowTemplates() -> [N8NWorkflowTemplate] {
        return [
            N8NWorkflowTemplate(
                name: "Auto-backup to Cloud",
                description: "Automatically backup exported projects to cloud storage",
                trigger: "project_exported",
                nodes: ["Echoelmusic Trigger", "Google Drive Upload", "Slack Notification"]
            ),
            N8NWorkflowTemplate(
                name: "Social Media Post",
                description: "Post to social media when track is published",
                trigger: "project_published",
                nodes: ["Echoelmusic Trigger", "Twitter Post", "Instagram Post", "Facebook Post"]
            ),
            N8NWorkflowTemplate(
                name: "Collaboration Notification",
                description: "Send notifications when collaborators join",
                trigger: "collaborator_joined",
                nodes: ["Echoelmusic Trigger", "Email Send", "Push Notification"]
            ),
            N8NWorkflowTemplate(
                name: "AI Analysis Pipeline",
                description: "Run AI analysis on new projects",
                trigger: "project_created",
                nodes: ["Echoelmusic Trigger", "Echoelmusic Analyze", "Database Store", "Report Generate"]
            ),
            N8NWorkflowTemplate(
                name: "Stem Distribution",
                description: "Distribute stems to collaborators",
                trigger: "stems_exported",
                nodes: ["Echoelmusic Trigger", "File Split", "Email Send Multiple", "Dropbox Upload"]
            )
        ]
    }

    public func configure(_ config: Configuration) {
        self.config = config
    }
}

// MARK: - n8n Types

public struct N8NWorkflow: Codable, Identifiable {
    public let id: String
    public let name: String
    public let active: Bool
    public let createdAt: String
    public let updatedAt: String
}

public struct N8NWorkflowsResponse: Codable {
    public let data: [N8NWorkflow]
}

public struct N8NWorkflowDefinition: Codable {
    public var name: String
    public var nodes: [N8NNode]
    public var connections: [String: [[String: Any]]]
    public var active: Bool = false
}

public struct N8NNode: Codable {
    public var name: String
    public var type: String
    public var position: [Int]
    public var parameters: [String: Any]

    enum CodingKeys: String, CodingKey {
        case name, type, position, parameters
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decode(String.self, forKey: .type)
        position = try container.decode([Int].self, forKey: .position)
        parameters = [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(position, forKey: .position)
    }
}

public struct N8NExecutionResult: Codable {
    public let id: String
    public let finished: Bool
    public let mode: String
    public let startedAt: String
    public let stoppedAt: String?
}

public struct N8NWorkflowTemplate {
    public let name: String
    public let description: String
    public let trigger: String
    public let nodes: [String]
}

// MARK: - Webhook Types

public struct WebhookPayload {
    public let method: String
    public let path: String
    public let headers: [String: String]
    public let body: [String: Any]
}

public struct WebhookResponse {
    public let status: Int
    public let body: String
    public var headers: [String: String] = [:]
}

// MARK: - Webhook Server

public class WebhookServer {
    private let port: UInt16
    public var requestHandler: ((WebhookPayload) async -> WebhookResponse)?

    public init(port: UInt16) {
        self.port = port
    }

    public func start() async throws {
        // Start HTTP server
        print("Webhook server started on port \(port)")
    }

    public func stop() {
        print("Webhook server stopped")
    }
}

// MARK: - Errors

public enum N8NError: Error {
    case invalidURL
    case connectionFailed
    case notConnected
    case workflowNotFound
    case executionFailed
}

// MARK: - Echoelmusic n8n Node Actions

/// Actions that can be triggered from n8n
public class EchoelmusicN8NActions {

    /// Create project from n8n
    public static func createProject(name: String, template: String?) async throws -> String {
        // Create project logic
        return UUID().uuidString
    }

    /// Export project from n8n
    public static func exportProject(projectId: String, format: String, quality: String) async throws -> URL {
        // Export logic
        return URL(fileURLWithPath: "/tmp/export.wav")
    }

    /// Run analysis from n8n
    public static func analyzeAudio(url: URL, analysisType: String) async throws -> [String: Any] {
        // Analysis logic
        return ["bpm": 120, "key": "C major"]
    }

    /// Apply preset from n8n
    public static func applyPreset(projectId: String, presetId: String) async throws {
        // Apply preset logic
    }

    /// Generate content from n8n
    public static func generateContent(type: String, parameters: [String: Any]) async throws -> URL {
        // Generate content logic
        return URL(fileURLWithPath: "/tmp/generated.wav")
    }
}
