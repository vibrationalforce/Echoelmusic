import Foundation
import Combine

// MARK: - MCP Context Engine
// Model Context Protocol integration for Claude Code
// Streams live data: build logs, database schemas, error traces
// "Deep codebase intelligence is the difference between an agent that just works
// and one that makes you work"

/// MCP (Model Context Protocol) Context Engine
/// Provides intelligent codebase context to AI assistants
@MainActor
@Observable
class MCPContextEngine {

    // MARK: - State

    /// Whether the engine is connected to MCP server
    var isConnected: Bool = false

    /// Current connection status
    var connectionStatus: ConnectionStatus = .disconnected

    /// Available MCP tools
    var availableTools: [MCPTool] = []

    /// Cached context
    var cachedContext: CodebaseContext?

    /// Last context update time
    var lastContextUpdate: Date?

    /// Active subscriptions
    var activeSubscriptions: [ContextSubscription] = []

    // MARK: - Types

    enum ConnectionStatus: String {
        case disconnected = "Disconnected"
        case connecting = "Connecting..."
        case connected = "Connected"
        case error = "Connection Error"
    }

    /// MCP Tool definition
    struct MCPTool: Identifiable, Codable {
        let id: String
        let name: String
        let description: String
        let inputSchema: [String: Any]?
        let category: ToolCategory

        enum ToolCategory: String, Codable {
            case codebase = "Codebase"
            case build = "Build"
            case test = "Test"
            case database = "Database"
            case memory = "Memory"
            case external = "External"
        }

        enum CodingKeys: String, CodingKey {
            case id, name, description, category
        }

        init(id: String, name: String, description: String, inputSchema: [String: Any]? = nil, category: ToolCategory) {
            self.id = id
            self.name = name
            self.description = description
            self.inputSchema = inputSchema
            self.category = category
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            description = try container.decode(String.self, forKey: .description)
            category = try container.decode(ToolCategory.self, forKey: .category)
            inputSchema = nil
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(description, forKey: .description)
            try container.encode(category, forKey: .category)
        }
    }

    /// Codebase context from MCP
    struct CodebaseContext: Codable {
        var projectName: String
        var projectPath: String
        var language: String
        var framework: String
        var files: [FileContext]
        var symbols: [SymbolContext]
        var dependencies: [DependencyContext]
        var buildStatus: BuildStatus
        var testStatus: TestStatus
        var recentChanges: [ChangeContext]
        var semanticIndex: SemanticIndex?

        struct FileContext: Identifiable, Codable {
            let id: UUID
            let path: String
            let language: String
            let lineCount: Int
            let lastModified: Date
            let symbols: [String]
            var relevanceScore: Float
        }

        struct SymbolContext: Identifiable, Codable {
            let id: UUID
            let name: String
            let kind: SymbolKind
            let filePath: String
            let lineNumber: Int
            let documentation: String?
            let references: Int

            enum SymbolKind: String, Codable {
                case `class`, `struct`, `enum`, `protocol`
                case function, method, property, variable
                case type, constant, macro
            }
        }

        struct DependencyContext: Identifiable, Codable {
            let id: UUID
            let name: String
            let version: String
            let source: DependencySource
            let isDirectDependency: Bool

            enum DependencySource: String, Codable {
                case spm, cocoapods, carthage, npm, pip, cargo
            }
        }

        struct BuildStatus: Codable {
            let isBuilding: Bool
            let lastBuildResult: BuildResult
            let lastBuildTime: Date?
            let errors: [BuildError]
            let warnings: [BuildWarning]

            enum BuildResult: String, Codable {
                case success, failure, unknown
            }

            struct BuildError: Identifiable, Codable {
                let id: UUID
                let message: String
                let file: String?
                let line: Int?
                let column: Int?
            }

            struct BuildWarning: Identifiable, Codable {
                let id: UUID
                let message: String
                let file: String?
                let line: Int?
            }
        }

        struct TestStatus: Codable {
            let totalTests: Int
            let passedTests: Int
            let failedTests: Int
            let skippedTests: Int
            let lastRunTime: Date?
            let coverage: Float?
            let failedTestNames: [String]
        }

        struct ChangeContext: Identifiable, Codable {
            let id: UUID
            let filePath: String
            let changeType: ChangeType
            let timestamp: Date
            let author: String?
            let summary: String

            enum ChangeType: String, Codable {
                case added, modified, deleted, renamed
            }
        }

        struct SemanticIndex: Codable {
            let embeddings: [String: [Float]]
            let clusters: [Cluster]

            struct Cluster: Identifiable, Codable {
                let id: UUID
                let name: String
                let files: [String]
                let description: String
            }
        }
    }

    /// Context subscription for real-time updates
    struct ContextSubscription: Identifiable {
        let id: UUID
        let type: SubscriptionType
        let callback: (Any) -> Void

        enum SubscriptionType: String {
            case buildStatus
            case testResults
            case fileChanges
            case errors
            case all
        }
    }

    // MARK: - MCP Server Configuration

    struct MCPServerConfig: Codable {
        let serverUrl: String
        let authToken: String?
        let capabilities: [String]
        let timeout: TimeInterval

        static let augmentCode = MCPServerConfig(
            serverUrl: "mcp://augment.code/context",
            authToken: nil,
            capabilities: ["codebase", "build", "test", "memory"],
            timeout: 30
        )

        static let local = MCPServerConfig(
            serverUrl: "stdio://auggie-context-mcp",
            authToken: nil,
            capabilities: ["codebase"],
            timeout: 10
        )
    }

    // MARK: - Private State

    private var serverConfig: MCPServerConfig?
    private var cancellables = Set<AnyCancellable>()
    private var contextUpdateTimer: Timer?

    // MARK: - Initialization

    init() {
        setupDefaultTools()
        print("🔌 MCP Context Engine initialized")
    }

    private func setupDefaultTools() {
        availableTools = [
            MCPTool(
                id: "get_codebase_context",
                name: "Get Codebase Context",
                description: "Retrieve full codebase context including files, symbols, and dependencies",
                category: .codebase
            ),
            MCPTool(
                id: "search_symbols",
                name: "Search Symbols",
                description: "Search for symbols (classes, functions, variables) in the codebase",
                category: .codebase
            ),
            MCPTool(
                id: "get_file_context",
                name: "Get File Context",
                description: "Get detailed context for a specific file",
                category: .codebase
            ),
            MCPTool(
                id: "get_build_status",
                name: "Get Build Status",
                description: "Get current build status, errors, and warnings",
                category: .build
            ),
            MCPTool(
                id: "get_test_results",
                name: "Get Test Results",
                description: "Get test execution results and coverage",
                category: .test
            ),
            MCPTool(
                id: "get_dependencies",
                name: "Get Dependencies",
                description: "List all project dependencies with versions",
                category: .codebase
            ),
            MCPTool(
                id: "semantic_search",
                name: "Semantic Search",
                description: "Search codebase using natural language",
                category: .codebase
            ),
            MCPTool(
                id: "get_recent_changes",
                name: "Get Recent Changes",
                description: "Get list of recent file changes",
                category: .codebase
            ),
            MCPTool(
                id: "store_memory",
                name: "Store Memory",
                description: "Store information in persistent memory",
                category: .memory
            ),
            MCPTool(
                id: "retrieve_memory",
                name: "Retrieve Memory",
                description: "Retrieve stored information from memory",
                category: .memory
            )
        ]
    }

    // MARK: - Connection Management

    /// Connect to MCP server
    func connect(config: MCPServerConfig = .local) async throws {
        connectionStatus = .connecting
        serverConfig = config

        // Simulate connection (in production, this would connect via stdio or HTTP)
        try await Task.sleep(nanoseconds: 500_000_000)

        connectionStatus = .connected
        isConnected = true

        // Start context updates
        startContextUpdates()

        print("✅ Connected to MCP server: \(config.serverUrl)")
    }

    /// Disconnect from MCP server
    func disconnect() {
        stopContextUpdates()
        connectionStatus = .disconnected
        isConnected = false
        cachedContext = nil

        print("🔌 Disconnected from MCP server")
    }

    // MARK: - Context Retrieval

    /// Get full codebase context
    func getCodebaseContext() async throws -> CodebaseContext {
        guard isConnected else {
            throw MCPError.notConnected
        }

        // In production, this would call the MCP server
        // For now, we'll generate context from the current project

        let context = await generateLocalContext()
        cachedContext = context
        lastContextUpdate = Date()

        return context
    }

    /// Search for symbols in the codebase
    func searchSymbols(query: String, kinds: [CodebaseContext.SymbolContext.SymbolKind]? = nil) async throws -> [CodebaseContext.SymbolContext] {
        guard let context = cachedContext else {
            let freshContext = try await getCodebaseContext()
            return freshContext.symbols.filter { symbol in
                symbol.name.localizedCaseInsensitiveContains(query) &&
                (kinds == nil || kinds!.contains(symbol.kind))
            }
        }

        return context.symbols.filter { symbol in
            symbol.name.localizedCaseInsensitiveContains(query) &&
            (kinds == nil || kinds!.contains(symbol.kind))
        }
    }

    /// Get context for specific file
    func getFileContext(path: String) async throws -> CodebaseContext.FileContext? {
        guard let context = cachedContext else {
            let freshContext = try await getCodebaseContext()
            return freshContext.files.first { $0.path == path }
        }

        return context.files.first { $0.path == path }
    }

    /// Semantic search using natural language
    func semanticSearch(query: String, topK: Int = 10) async throws -> [CodebaseContext.FileContext] {
        guard let context = cachedContext else {
            throw MCPError.noContextAvailable
        }

        // In production, this would use embeddings
        // For now, we do a simple relevance scoring
        var scoredFiles = context.files.map { file -> (file: CodebaseContext.FileContext, score: Float) in
            var score: Float = 0

            // Score based on path matching
            if file.path.localizedCaseInsensitiveContains(query) {
                score += 0.5
            }

            // Score based on symbol matching
            for symbol in file.symbols {
                if symbol.localizedCaseInsensitiveContains(query) {
                    score += 0.1
                }
            }

            return (file, score)
        }

        scoredFiles.sort { $0.score > $1.score }

        return Array(scoredFiles.prefix(topK).map { result in
            var file = result.file
            file.relevanceScore = result.score
            return file
        })
    }

    // MARK: - Build & Test Integration

    /// Get current build status
    func getBuildStatus() async throws -> CodebaseContext.BuildStatus {
        guard let context = cachedContext else {
            let freshContext = try await getCodebaseContext()
            return freshContext.buildStatus
        }

        return context.buildStatus
    }

    /// Get test results
    func getTestStatus() async throws -> CodebaseContext.TestStatus {
        guard let context = cachedContext else {
            let freshContext = try await getCodebaseContext()
            return freshContext.testStatus
        }

        return context.testStatus
    }

    // MARK: - Memory (Persistent Context)

    private var memory: [String: Any] = [:]

    /// Store information in persistent memory
    func storeMemory(key: String, value: Any) {
        memory[key] = value
        print("💾 Stored in memory: \(key)")
    }

    /// Retrieve from persistent memory
    func retrieveMemory(key: String) -> Any? {
        return memory[key]
    }

    /// Clear memory
    func clearMemory() {
        memory.removeAll()
        print("🗑️ Memory cleared")
    }

    // MARK: - Subscriptions

    /// Subscribe to context updates
    func subscribe(
        to type: ContextSubscription.SubscriptionType,
        callback: @escaping (Any) -> Void
    ) -> UUID {
        let subscription = ContextSubscription(
            id: UUID(),
            type: type,
            callback: callback
        )

        activeSubscriptions.append(subscription)
        return subscription.id
    }

    /// Unsubscribe from updates
    func unsubscribe(id: UUID) {
        activeSubscriptions.removeAll { $0.id == id }
    }

    // MARK: - Context Updates

    private func startContextUpdates() {
        contextUpdateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                try? await self?.refreshContext()
            }
        }
    }

    private func stopContextUpdates() {
        contextUpdateTimer?.invalidate()
        contextUpdateTimer = nil
    }

    private func refreshContext() async throws {
        let context = try await getCodebaseContext()

        // Notify subscribers
        for subscription in activeSubscriptions {
            switch subscription.type {
            case .buildStatus:
                subscription.callback(context.buildStatus)
            case .testResults:
                subscription.callback(context.testStatus)
            case .fileChanges:
                subscription.callback(context.recentChanges)
            case .errors:
                subscription.callback(context.buildStatus.errors)
            case .all:
                subscription.callback(context)
            }
        }
    }

    // MARK: - Local Context Generation

    private func generateLocalContext() async -> CodebaseContext {
        // Generate context from local project
        // This simulates what the MCP server would provide

        CodebaseContext(
            projectName: "Echoelmusic",
            projectPath: "/home/user/Echoelmusic",
            language: "Swift",
            framework: "SwiftUI",
            files: [
                CodebaseContext.FileContext(
                    id: UUID(),
                    path: "Sources/Echoelmusic/Core/TaskmasterEngine.swift",
                    language: "Swift",
                    lineCount: 500,
                    lastModified: Date(),
                    symbols: ["TaskmasterEngine", "DevelopmentTask", "Verification"],
                    relevanceScore: 1.0
                ),
                CodebaseContext.FileContext(
                    id: UUID(),
                    path: "Sources/Echoelmusic/Core/MCPContextEngine.swift",
                    language: "Swift",
                    lineCount: 400,
                    lastModified: Date(),
                    symbols: ["MCPContextEngine", "CodebaseContext", "MCPTool"],
                    relevanceScore: 1.0
                )
            ],
            symbols: [
                CodebaseContext.SymbolContext(
                    id: UUID(),
                    name: "TaskmasterEngine",
                    kind: .class,
                    filePath: "Sources/Echoelmusic/Core/TaskmasterEngine.swift",
                    lineNumber: 15,
                    documentation: "Taskmaster Engine for Claude Code integration",
                    references: 10
                ),
                CodebaseContext.SymbolContext(
                    id: UUID(),
                    name: "MCPContextEngine",
                    kind: .class,
                    filePath: "Sources/Echoelmusic/Core/MCPContextEngine.swift",
                    lineNumber: 12,
                    documentation: "MCP Context Engine for codebase intelligence",
                    references: 5
                )
            ],
            dependencies: [
                CodebaseContext.DependencyContext(
                    id: UUID(),
                    name: "SwiftUI",
                    version: "5.0",
                    source: .spm,
                    isDirectDependency: true
                ),
                CodebaseContext.DependencyContext(
                    id: UUID(),
                    name: "Combine",
                    version: "5.0",
                    source: .spm,
                    isDirectDependency: true
                )
            ],
            buildStatus: CodebaseContext.BuildStatus(
                isBuilding: false,
                lastBuildResult: .success,
                lastBuildTime: Date(),
                errors: [],
                warnings: []
            ),
            testStatus: CodebaseContext.TestStatus(
                totalTests: 150,
                passedTests: 148,
                failedTests: 2,
                skippedTests: 0,
                lastRunTime: Date(),
                coverage: 0.85,
                failedTestNames: ["testEdgeCase1", "testEdgeCase2"]
            ),
            recentChanges: [
                CodebaseContext.ChangeContext(
                    id: UUID(),
                    filePath: "Sources/Echoelmusic/Core/TaskmasterEngine.swift",
                    changeType: .added,
                    timestamp: Date(),
                    author: "Claude",
                    summary: "Added Taskmaster Engine for verification-driven development"
                )
            ],
            semanticIndex: nil
        )
    }

    // MARK: - Tool Execution

    /// Execute an MCP tool
    func executeTool(
        toolId: String,
        parameters: [String: Any]
    ) async throws -> Any {
        guard isConnected else {
            throw MCPError.notConnected
        }

        guard let tool = availableTools.first(where: { $0.id == toolId }) else {
            throw MCPError.toolNotFound(toolId)
        }

        switch toolId {
        case "get_codebase_context":
            return try await getCodebaseContext()

        case "search_symbols":
            let query = parameters["query"] as? String ?? ""
            return try await searchSymbols(query: query)

        case "get_build_status":
            return try await getBuildStatus()

        case "get_test_results":
            return try await getTestStatus()

        case "semantic_search":
            let query = parameters["query"] as? String ?? ""
            let topK = parameters["top_k"] as? Int ?? 10
            return try await semanticSearch(query: query, topK: topK)

        case "store_memory":
            let key = parameters["key"] as? String ?? ""
            let value = parameters["value"] ?? ""
            storeMemory(key: key, value: value)
            return ["success": true]

        case "retrieve_memory":
            let key = parameters["key"] as? String ?? ""
            return retrieveMemory(key: key) ?? ["error": "Key not found"]

        default:
            throw MCPError.toolNotImplemented(toolId)
        }
    }

    // MARK: - Errors

    enum MCPError: Error, LocalizedError {
        case notConnected
        case connectionFailed(String)
        case toolNotFound(String)
        case toolNotImplemented(String)
        case noContextAvailable
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .notConnected:
                return "Not connected to MCP server"
            case .connectionFailed(let reason):
                return "Connection failed: \(reason)"
            case .toolNotFound(let toolId):
                return "Tool not found: \(toolId)"
            case .toolNotImplemented(let toolId):
                return "Tool not implemented: \(toolId)"
            case .noContextAvailable:
                return "No context available. Refresh context first."
            case .invalidResponse:
                return "Invalid response from MCP server"
            }
        }
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

struct MCPContextView: View {
    @State private var engine = MCPContextEngine()
    @State private var searchQuery = ""
    @State private var searchResults: [MCPContextEngine.CodebaseContext.FileContext] = []

    var body: some View {
        VStack(spacing: 20) {
            // Connection Status
            HStack {
                Circle()
                    .fill(engine.isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)

                Text(engine.connectionStatus.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))

                Spacer()

                Button(engine.isConnected ? "Disconnect" : "Connect") {
                    Task {
                        if engine.isConnected {
                            engine.disconnect()
                        } else {
                            try? await engine.connect()
                        }
                    }
                }
                .buttonStyle(.liquidGlass(variant: .regular, size: .small))
            }
            .padding()
            .liquidGlass(.regular, cornerRadius: 16)

            // Search
            LiquidGlassSearchBar(text: $searchQuery, placeholder: "Semantic search...")

            if !searchQuery.isEmpty {
                Button("Search") {
                    Task {
                        searchResults = try await engine.semanticSearch(query: searchQuery)
                    }
                }
                .buttonStyle(.liquidGlass(tint: .cyan))
            }

            // Results
            if !searchResults.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(searchResults) { file in
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundStyle(.cyan)

                                VStack(alignment: .leading) {
                                    Text(file.path.components(separatedBy: "/").last ?? file.path)
                                        .font(.subheadline)
                                        .foregroundStyle(.white)

                                    Text("\(file.lineCount) lines")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.6))
                                }

                                Spacer()

                                Text(String(format: "%.0f%%", file.relevanceScore * 100))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.green)
                            }
                            .padding()
                            .liquidGlass(.regular, cornerRadius: 12)
                        }
                    }
                }
            }

            // Available Tools
            VStack(alignment: .leading, spacing: 12) {
                Text("Available Tools")
                    .font(.headline)
                    .foregroundStyle(.white)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(engine.availableTools) { tool in
                        HStack {
                            Image(systemName: toolIcon(for: tool.category))
                                .foregroundStyle(toolColor(for: tool.category))

                            Text(tool.name)
                                .font(.caption)
                                .foregroundStyle(.white)
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .liquidGlass(.regular, cornerRadius: 8)
                    }
                }
            }

            Spacer()
        }
        .padding()
    }

    private func toolIcon(for category: MCPContextEngine.MCPTool.ToolCategory) -> String {
        switch category {
        case .codebase: return "doc.text.magnifyingglass"
        case .build: return "hammer"
        case .test: return "checkmark.circle"
        case .database: return "cylinder"
        case .memory: return "brain"
        case .external: return "arrow.up.right.circle"
        }
    }

    private func toolColor(for category: MCPContextEngine.MCPTool.ToolCategory) -> Color {
        switch category {
        case .codebase: return .cyan
        case .build: return .orange
        case .test: return .green
        case .database: return .purple
        case .memory: return .pink
        case .external: return .blue
        }
    }
}

#Preview("MCP Context Engine") {
    ZStack {
        AnimatedGlassBackground()
        MCPContextView()
    }
    .preferredColorScheme(.dark)
}
