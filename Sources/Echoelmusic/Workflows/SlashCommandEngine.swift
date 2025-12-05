// SlashCommandEngine.swift
// Echoelmusic
//
// Slash Command System for AI-Native Development Workflows
// Implements /review, /design-review, /security-review, and custom commands
//
// Created by Echoelmusic on 2025-12-05.

import Foundation
import Combine

// MARK: - Slash Command Definition

public struct SlashCommand: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let aliases: [String]
    public let description: String
    public let usage: String
    public let examples: [String]
    public let category: Category
    public let parameters: [Parameter]
    public let isBuiltIn: Bool
    public var isEnabled: Bool
    public var customPrompt: String?

    public enum Category: String, Codable, CaseIterable {
        case review = "Review"
        case development = "Development"
        case testing = "Testing"
        case documentation = "Documentation"
        case utility = "Utility"
        case custom = "Custom"
    }

    public struct Parameter: Codable {
        public let name: String
        public let description: String
        public let type: ParameterType
        public let isRequired: Bool
        public let defaultValue: String?

        public enum ParameterType: String, Codable {
            case string, path, number, boolean, choice
        }
    }

    public init(
        name: String,
        aliases: [String] = [],
        description: String,
        usage: String,
        examples: [String] = [],
        category: Category,
        parameters: [Parameter] = [],
        isBuiltIn: Bool = true,
        customPrompt: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.aliases = aliases
        self.description = description
        self.usage = usage
        self.examples = examples
        self.category = category
        self.parameters = parameters
        self.isBuiltIn = isBuiltIn
        self.isEnabled = true
        self.customPrompt = customPrompt
    }
}

// MARK: - Command Execution Result

public struct CommandExecutionResult {
    public let command: String
    public let success: Bool
    public let output: String
    public let duration: TimeInterval
    public let artifacts: [CommandArtifact]
    public let errors: [String]

    public struct CommandArtifact {
        public let type: ArtifactType
        public let name: String
        public let content: String

        public enum ArtifactType {
            case report, diff, file, url
        }
    }
}

// MARK: - Slash Command Engine

@MainActor
public final class SlashCommandEngine: ObservableObject {
    public static let shared = SlashCommandEngine()

    // MARK: Published State

    @Published public private(set) var registeredCommands: [SlashCommand] = []
    @Published public private(set) var isExecuting = false
    @Published public private(set) var lastExecutionResult: CommandExecutionResult?
    @Published public private(set) var commandHistory: [CommandHistoryEntry] = []

    // MARK: Dependencies

    private let workflowOrchestrator = WorkflowOrchestratorEngine.shared
    private let designAgent = DesignAgentEngine.shared

    // MARK: Private

    private var commandMap: [String: SlashCommand] = [:]
    private var cancellables = Set<AnyCancellable>()

    // MARK: Initialization

    private init() {
        registerBuiltInCommands()
        loadCustomCommands()
    }

    // MARK: - Command Registration

    private func registerBuiltInCommands() {
        let builtInCommands: [SlashCommand] = [
            // Code Review Commands
            SlashCommand(
                name: "review",
                aliases: ["code-review", "cr"],
                description: "Run AI-assisted code review on current changes",
                usage: "/review [path] [--strict] [--focus=<area>]",
                examples: [
                    "/review",
                    "/review ./Sources",
                    "/review --strict",
                    "/review --focus=security"
                ],
                category: .review,
                parameters: [
                    .init(name: "path", description: "Path to review", type: .path, isRequired: false, defaultValue: "."),
                    .init(name: "strict", description: "Enable strict mode", type: .boolean, isRequired: false, defaultValue: "false"),
                    .init(name: "focus", description: "Focus area", type: .choice, isRequired: false, defaultValue: nil)
                ]
            ),

            // Design Review Commands
            SlashCommand(
                name: "design-review",
                aliases: ["dr", "ui-review"],
                description: "Run comprehensive design review with Playwright",
                usage: "/design-review [path] [--wcag] [--responsive]",
                examples: [
                    "/design-review",
                    "/design-review ./Sources/Views",
                    "/design-review --wcag"
                ],
                category: .review,
                parameters: [
                    .init(name: "path", description: "Path to review", type: .path, isRequired: false, defaultValue: "."),
                    .init(name: "wcag", description: "Check WCAG compliance", type: .boolean, isRequired: false, defaultValue: "true"),
                    .init(name: "responsive", description: "Test responsiveness", type: .boolean, isRequired: false, defaultValue: "true")
                ]
            ),

            // Security Review Commands
            SlashCommand(
                name: "security-review",
                aliases: ["sr", "security"],
                description: "Scan for security vulnerabilities and exposed secrets",
                usage: "/security-review [path] [--owasp] [--deps]",
                examples: [
                    "/security-review",
                    "/security-review --owasp",
                    "/security-review --deps"
                ],
                category: .review,
                parameters: [
                    .init(name: "path", description: "Path to scan", type: .path, isRequired: false, defaultValue: "."),
                    .init(name: "owasp", description: "Check OWASP Top 10", type: .boolean, isRequired: false, defaultValue: "true"),
                    .init(name: "deps", description: "Review dependencies", type: .boolean, isRequired: false, defaultValue: "true")
                ]
            ),

            // Performance Commands
            SlashCommand(
                name: "perf-audit",
                aliases: ["performance", "perf"],
                description: "Run performance audit on specified code",
                usage: "/perf-audit [path] [--profile] [--memory]",
                examples: [
                    "/perf-audit",
                    "/perf-audit ./Sources/Audio",
                    "/perf-audit --profile --memory"
                ],
                category: .review,
                parameters: [
                    .init(name: "path", description: "Path to audit", type: .path, isRequired: false, defaultValue: "."),
                    .init(name: "profile", description: "Enable CPU profiling", type: .boolean, isRequired: false, defaultValue: "false"),
                    .init(name: "memory", description: "Enable memory analysis", type: .boolean, isRequired: false, defaultValue: "false")
                ]
            ),

            // Accessibility Commands
            SlashCommand(
                name: "a11y",
                aliases: ["accessibility", "acc"],
                description: "Run accessibility audit",
                usage: "/a11y [path] [--voiceover] [--contrast]",
                examples: [
                    "/a11y",
                    "/a11y ./Sources/Views",
                    "/a11y --voiceover"
                ],
                category: .review,
                parameters: [
                    .init(name: "path", description: "Path to audit", type: .path, isRequired: false, defaultValue: "."),
                    .init(name: "voiceover", description: "Test VoiceOver", type: .boolean, isRequired: false, defaultValue: "true"),
                    .init(name: "contrast", description: "Check color contrast", type: .boolean, isRequired: false, defaultValue: "true")
                ]
            ),

            // Development Commands
            SlashCommand(
                name: "spec",
                aliases: ["spec-to-dev", "implement"],
                description: "Run specification to development workflow",
                usage: "/spec <spec-file> [--verify] [--test]",
                examples: [
                    "/spec ./specs/feature.md",
                    "/spec ./specs/api.yaml --verify"
                ],
                category: .development,
                parameters: [
                    .init(name: "spec-file", description: "Path to specification", type: .path, isRequired: true, defaultValue: nil),
                    .init(name: "verify", description: "Enable verification", type: .boolean, isRequired: false, defaultValue: "true"),
                    .init(name: "test", description: "Generate tests", type: .boolean, isRequired: false, defaultValue: "true")
                ]
            ),

            SlashCommand(
                name: "fix",
                aliases: ["bugfix", "debug"],
                description: "Analyze and fix a bug",
                usage: "/fix <issue-description> [--file=<path>]",
                examples: [
                    "/fix 'Audio crackling on high CPU'",
                    "/fix 'Memory leak' --file=./Sources/Audio/Engine.swift"
                ],
                category: .development,
                parameters: [
                    .init(name: "issue", description: "Issue description or ID", type: .string, isRequired: true, defaultValue: nil),
                    .init(name: "file", description: "Related file path", type: .path, isRequired: false, defaultValue: nil)
                ]
            ),

            SlashCommand(
                name: "refactor",
                aliases: ["rf"],
                description: "Suggest and apply refactoring",
                usage: "/refactor <path> [--pattern=<pattern>]",
                examples: [
                    "/refactor ./Sources/Audio",
                    "/refactor ./Sources --pattern=extract-method"
                ],
                category: .development,
                parameters: [
                    .init(name: "path", description: "Path to refactor", type: .path, isRequired: true, defaultValue: nil),
                    .init(name: "pattern", description: "Refactoring pattern", type: .choice, isRequired: false, defaultValue: nil)
                ]
            ),

            // Testing Commands
            SlashCommand(
                name: "test",
                aliases: ["run-tests"],
                description: "Run tests with coverage",
                usage: "/test [filter] [--coverage] [--watch]",
                examples: [
                    "/test",
                    "/test AudioEngine",
                    "/test --coverage"
                ],
                category: .testing,
                parameters: [
                    .init(name: "filter", description: "Test filter", type: .string, isRequired: false, defaultValue: nil),
                    .init(name: "coverage", description: "Generate coverage", type: .boolean, isRequired: false, defaultValue: "false"),
                    .init(name: "watch", description: "Watch mode", type: .boolean, isRequired: false, defaultValue: "false")
                ]
            ),

            SlashCommand(
                name: "gen-tests",
                aliases: ["generate-tests", "gt"],
                description: "Generate tests for specified code",
                usage: "/gen-tests <path> [--unit] [--integration]",
                examples: [
                    "/gen-tests ./Sources/Audio/Engine.swift",
                    "/gen-tests ./Sources/AI --integration"
                ],
                category: .testing,
                parameters: [
                    .init(name: "path", description: "Path to generate tests for", type: .path, isRequired: true, defaultValue: nil),
                    .init(name: "unit", description: "Generate unit tests", type: .boolean, isRequired: false, defaultValue: "true"),
                    .init(name: "integration", description: "Generate integration tests", type: .boolean, isRequired: false, defaultValue: "false")
                ]
            ),

            // Documentation Commands
            SlashCommand(
                name: "doc",
                aliases: ["docs", "document"],
                description: "Generate documentation for code",
                usage: "/doc <path> [--format=<format>]",
                examples: [
                    "/doc ./Sources/Audio",
                    "/doc ./Sources --format=docc"
                ],
                category: .documentation,
                parameters: [
                    .init(name: "path", description: "Path to document", type: .path, isRequired: true, defaultValue: nil),
                    .init(name: "format", description: "Output format", type: .choice, isRequired: false, defaultValue: "markdown")
                ]
            ),

            // Utility Commands
            SlashCommand(
                name: "optimize-performance",
                aliases: ["opt-perf"],
                description: "Optimize CPU/GPU/Memory performance",
                usage: "/optimize-performance [target]",
                examples: [
                    "/optimize-performance",
                    "/optimize-performance audio",
                    "/optimize-performance visual"
                ],
                category: .utility
            ),

            SlashCommand(
                name: "audio-engineer",
                aliases: ["dsp", "mastering"],
                description: "Audio engineering and mastering assistant",
                usage: "/audio-engineer [task]",
                examples: [
                    "/audio-engineer",
                    "/audio-engineer 'design lowpass filter'"
                ],
                category: .utility
            ),

            SlashCommand(
                name: "debug-doctor",
                aliases: ["diagnose"],
                description: "Diagnose and hunt bugs",
                usage: "/debug-doctor [symptom]",
                examples: [
                    "/debug-doctor",
                    "/debug-doctor 'app crashes on launch'"
                ],
                category: .utility
            ),

            SlashCommand(
                name: "quantum-science",
                aliases: ["quantum"],
                description: "Quantum-inspired algorithm development",
                usage: "/quantum-science [concept]",
                examples: [
                    "/quantum-science",
                    "/quantum-science 'quantum flow state'"
                ],
                category: .utility
            ),

            SlashCommand(
                name: "inspire",
                aliases: ["design-inspire", "inspiration"],
                description: "Get design inspiration for UI component",
                usage: "/inspire <component> [--source=<source>]",
                examples: [
                    "/inspire waveform",
                    "/inspire mixer --source=stripe",
                    "/inspire dashboard"
                ],
                category: .utility,
                parameters: [
                    .init(name: "component", description: "Component type", type: .string, isRequired: true, defaultValue: nil),
                    .init(name: "source", description: "Inspiration source", type: .choice, isRequired: false, defaultValue: nil)
                ]
            ),

            SlashCommand(
                name: "help",
                aliases: ["h", "?"],
                description: "Show help for commands",
                usage: "/help [command]",
                examples: [
                    "/help",
                    "/help review",
                    "/help design-review"
                ],
                category: .utility,
                parameters: [
                    .init(name: "command", description: "Command name", type: .string, isRequired: false, defaultValue: nil)
                ]
            ),
        ]

        for command in builtInCommands {
            registeredCommands.append(command)
            commandMap[command.name] = command
            for alias in command.aliases {
                commandMap[alias] = command
            }
        }
    }

    private func loadCustomCommands() {
        // Load custom commands from .claude/commands/ directory
        // These are project-specific commands
    }

    // MARK: - Command Execution

    /// Execute a slash command
    public func execute(_ input: String) async -> CommandExecutionResult {
        let startTime = Date()
        isExecuting = true

        defer { isExecuting = false }

        // Parse command
        let parsed = parseCommand(input)
        guard let commandName = parsed.command else {
            return CommandExecutionResult(
                command: input,
                success: false,
                output: "Invalid command format",
                duration: 0,
                artifacts: [],
                errors: ["Could not parse command"]
            )
        }

        // Find command
        guard let command = commandMap[commandName] else {
            let suggestions = suggestCommands(for: commandName)
            return CommandExecutionResult(
                command: input,
                success: false,
                output: "Unknown command: /\(commandName)",
                duration: 0,
                artifacts: [],
                errors: suggestions.isEmpty ? ["Command not found"] : ["Did you mean: \(suggestions.joined(separator: ", "))?"]
            )
        }

        // Execute command
        let result: CommandExecutionResult

        switch command.name {
        case "review", "code-review":
            result = await executeCodeReview(parsed: parsed)

        case "design-review":
            result = await executeDesignReview(parsed: parsed)

        case "security-review":
            result = await executeSecurityReview(parsed: parsed)

        case "perf-audit":
            result = await executePerfAudit(parsed: parsed)

        case "a11y":
            result = await executeAccessibilityAudit(parsed: parsed)

        case "spec":
            result = await executeSpecToDev(parsed: parsed)

        case "inspire":
            result = await executeInspire(parsed: parsed)

        case "help":
            result = executeHelp(parsed: parsed)

        default:
            result = await executeGenericCommand(command: command, parsed: parsed)
        }

        // Record history
        let duration = Date().timeIntervalSince(startTime)
        let historyEntry = CommandHistoryEntry(
            command: input,
            timestamp: Date(),
            success: result.success,
            duration: duration
        )
        commandHistory.insert(historyEntry, at: 0)
        if commandHistory.count > 100 {
            commandHistory = Array(commandHistory.prefix(100))
        }

        lastExecutionResult = result

        return result
    }

    // MARK: - Command Implementations

    private func executeCodeReview(parsed: ParsedCommand) async -> CommandExecutionResult {
        let path = parsed.arguments.first ?? "."
        let context = WorkflowContext(targetPath: path)

        let run = await workflowOrchestrator.executeWorkflow(
            type: .codeReview,
            context: context,
            triggeredBy: .slashCommand
        )

        let report = workflowOrchestrator.generateReport(for: run)

        return CommandExecutionResult(
            command: "/review",
            success: run.status == .completed,
            output: report,
            duration: run.metrics.totalDuration,
            artifacts: [.init(type: .report, name: "code-review-report.md", content: report)],
            errors: run.findings.filter { $0.severity == .critical }.map { $0.title }
        )
    }

    private func executeDesignReview(parsed: ParsedCommand) async -> CommandExecutionResult {
        let path = parsed.arguments.first ?? "."
        let context = WorkflowContext(targetPath: path)

        let run = await workflowOrchestrator.executeWorkflow(
            type: .designReview,
            context: context,
            triggeredBy: .slashCommand
        )

        // Also run design agent
        let designReport = await designAgent.reviewDesign(
            EmptyView(),
            context: ReviewContext.default
        )

        let combinedReport = """
        \(workflowOrchestrator.generateReport(for: run))

        ---

        ## Design Agent Analysis

        **Score:** \(Int(designReport.score))/100

        \(designReport.summary)

        ### Findings

        \(designReport.findings.map { "- \($0.severity.emoji) **\($0.title)**: \($0.description)" }.joined(separator: "\n"))
        """

        return CommandExecutionResult(
            command: "/design-review",
            success: run.status == .completed && designReport.score >= 70,
            output: combinedReport,
            duration: run.metrics.totalDuration,
            artifacts: [.init(type: .report, name: "design-review-report.md", content: combinedReport)],
            errors: []
        )
    }

    private func executeSecurityReview(parsed: ParsedCommand) async -> CommandExecutionResult {
        let path = parsed.arguments.first ?? "."
        let context = WorkflowContext(targetPath: path)

        let run = await workflowOrchestrator.executeWorkflow(
            type: .securityReview,
            context: context,
            triggeredBy: .slashCommand
        )

        let report = workflowOrchestrator.generateReport(for: run)

        let criticalIssues = run.findings.filter { $0.severity == .critical || $0.severity == .high }

        return CommandExecutionResult(
            command: "/security-review",
            success: criticalIssues.isEmpty,
            output: report,
            duration: run.metrics.totalDuration,
            artifacts: [.init(type: .report, name: "security-review-report.md", content: report)],
            errors: criticalIssues.map { "[\($0.severity.rawValue.uppercased())] \($0.title)" }
        )
    }

    private func executePerfAudit(parsed: ParsedCommand) async -> CommandExecutionResult {
        let path = parsed.arguments.first ?? "."
        let context = WorkflowContext(targetPath: path)

        let run = await workflowOrchestrator.executeWorkflow(
            type: .performanceAudit,
            context: context,
            triggeredBy: .slashCommand
        )

        let report = workflowOrchestrator.generateReport(for: run)

        return CommandExecutionResult(
            command: "/perf-audit",
            success: run.status == .completed,
            output: report,
            duration: run.metrics.totalDuration,
            artifacts: [.init(type: .report, name: "performance-audit-report.md", content: report)],
            errors: []
        )
    }

    private func executeAccessibilityAudit(parsed: ParsedCommand) async -> CommandExecutionResult {
        let path = parsed.arguments.first ?? "."
        let context = WorkflowContext(targetPath: path)

        let run = await workflowOrchestrator.executeWorkflow(
            type: .accessibilityAudit,
            context: context,
            triggeredBy: .slashCommand
        )

        let report = workflowOrchestrator.generateReport(for: run)

        return CommandExecutionResult(
            command: "/a11y",
            success: run.status == .completed,
            output: report,
            duration: run.metrics.totalDuration,
            artifacts: [.init(type: .report, name: "accessibility-audit-report.md", content: report)],
            errors: []
        )
    }

    private func executeSpecToDev(parsed: ParsedCommand) async -> CommandExecutionResult {
        guard let specFile = parsed.arguments.first else {
            return CommandExecutionResult(
                command: "/spec",
                success: false,
                output: "Error: Specification file required",
                duration: 0,
                artifacts: [],
                errors: ["Missing required argument: spec-file"]
            )
        }

        var context = WorkflowContext(targetPath: specFile)
        context.additionalContext["verify"] = parsed.flags["verify"] ?? "true"

        let run = await workflowOrchestrator.executeWorkflow(
            type: .specToDevelopment,
            context: context,
            triggeredBy: .slashCommand
        )

        let report = workflowOrchestrator.generateReport(for: run)

        return CommandExecutionResult(
            command: "/spec",
            success: run.status == .completed,
            output: report,
            duration: run.metrics.totalDuration,
            artifacts: [.init(type: .report, name: "spec-to-dev-report.md", content: report)],
            errors: run.steps.filter { $0.status == .failed }.map { $0.errorMessage ?? $0.name }
        )
    }

    private func executeInspire(parsed: ParsedCommand) async -> CommandExecutionResult {
        guard let component = parsed.arguments.first else {
            return CommandExecutionResult(
                command: "/inspire",
                success: false,
                output: "Error: Component name required",
                duration: 0,
                artifacts: [],
                errors: ["Missing required argument: component"]
            )
        }

        let category: DesignInspiration.Category
        switch component.lowercased() {
        case "dashboard": category = .dashboard
        case "mixer", "controls": category = .controls
        case "waveform", "spectrum", "visualization": category = .visualization
        case "navigation", "nav": category = .navigation
        case "mobile": category = .mobile
        case "wearable", "watch", "ring": category = .wearable
        case "spatial", "vr", "ar": category = .spatial
        default: category = .visualization
        }

        let inspirations = await designAgent.getInspiration(for: category)
        let suggestions = await designAgent.generateDesignSuggestions(for: component)

        var output = """
        # Design Inspiration for "\(component)"

        ## Top Inspirations

        """

        for (index, inspiration) in inspirations.enumerated() {
            output += """

            ### \(index + 1). \(inspiration.title) (\(inspiration.source.rawValue))

            \(inspiration.description)

            **Techniques:** \(inspiration.techniques.joined(separator: ", "))
            **Color Palette:** \(inspiration.colorPalette.joined(separator: " "))
            **Tags:** \(inspiration.tags.joined(separator: ", "))

            """
        }

        if !suggestions.isEmpty {
            output += "\n## Design Suggestions\n\n"
            for suggestion in suggestions {
                output += """
                ### \(suggestion.title)

                \(suggestion.description)

                **Techniques:** \(suggestion.techniques.joined(separator: ", "))

                """
            }
        }

        return CommandExecutionResult(
            command: "/inspire",
            success: true,
            output: output,
            duration: 0,
            artifacts: [],
            errors: []
        )
    }

    private func executeHelp(parsed: ParsedCommand) -> CommandExecutionResult {
        if let commandName = parsed.arguments.first, let command = commandMap[commandName] {
            // Show help for specific command
            let output = """
            # /\(command.name)

            \(command.description)

            **Usage:** `\(command.usage)`
            **Aliases:** \(command.aliases.isEmpty ? "none" : command.aliases.map { "/" + $0 }.joined(separator: ", "))
            **Category:** \(command.category.rawValue)

            ## Parameters

            \(command.parameters.isEmpty ? "No parameters" : command.parameters.map { param in
                "- **\(param.name)** (\(param.type.rawValue))\(param.isRequired ? " [required]" : ""): \(param.description)\(param.defaultValue.map { " (default: \($0))" } ?? "")"
            }.joined(separator: "\n"))

            ## Examples

            \(command.examples.map { "- `\($0)`" }.joined(separator: "\n"))
            """

            return CommandExecutionResult(
                command: "/help",
                success: true,
                output: output,
                duration: 0,
                artifacts: [],
                errors: []
            )
        }

        // Show all commands
        let categories = Dictionary(grouping: registeredCommands) { $0.category }

        var output = """
        # Available Commands

        """

        for category in SlashCommand.Category.allCases {
            if let commands = categories[category], !commands.isEmpty {
                output += "\n## \(category.rawValue)\n\n"
                for command in commands {
                    output += "- **/\(command.name)** - \(command.description)\n"
                }
            }
        }

        output += "\n---\n\nUse `/help <command>` for detailed information about a specific command."

        return CommandExecutionResult(
            command: "/help",
            success: true,
            output: output,
            duration: 0,
            artifacts: [],
            errors: []
        )
    }

    private func executeGenericCommand(command: SlashCommand, parsed: ParsedCommand) async -> CommandExecutionResult {
        if let prompt = command.customPrompt {
            // Execute custom command with prompt
            return CommandExecutionResult(
                command: "/\(command.name)",
                success: true,
                output: "Executing custom command with prompt: \(prompt)",
                duration: 0,
                artifacts: [],
                errors: []
            )
        }

        return CommandExecutionResult(
            command: "/\(command.name)",
            success: true,
            output: "Command /\(command.name) executed",
            duration: 0,
            artifacts: [],
            errors: []
        )
    }

    // MARK: - Command Parsing

    private struct ParsedCommand {
        var command: String?
        var arguments: [String] = []
        var flags: [String: String] = [:]
    }

    private func parseCommand(_ input: String) -> ParsedCommand {
        var result = ParsedCommand()

        // Remove leading slash
        var trimmed = input.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("/") {
            trimmed = String(trimmed.dropFirst())
        }

        // Split by spaces (respecting quotes)
        let parts = splitCommandLine(trimmed)

        guard let first = parts.first else { return result }

        result.command = first

        for part in parts.dropFirst() {
            if part.hasPrefix("--") {
                // Flag
                let flagContent = String(part.dropFirst(2))
                if let equalIndex = flagContent.firstIndex(of: "=") {
                    let key = String(flagContent[..<equalIndex])
                    let value = String(flagContent[flagContent.index(after: equalIndex)...])
                    result.flags[key] = value
                } else {
                    result.flags[flagContent] = "true"
                }
            } else {
                // Argument
                result.arguments.append(part)
            }
        }

        return result
    }

    private func splitCommandLine(_ input: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var inQuotes = false
        var quoteChar: Character = "\""

        for char in input {
            if char == "\"" || char == "'" {
                if inQuotes && char == quoteChar {
                    inQuotes = false
                } else if !inQuotes {
                    inQuotes = true
                    quoteChar = char
                } else {
                    current.append(char)
                }
            } else if char == " " && !inQuotes {
                if !current.isEmpty {
                    parts.append(current)
                    current = ""
                }
            } else {
                current.append(char)
            }
        }

        if !current.isEmpty {
            parts.append(current)
        }

        return parts
    }

    private func suggestCommands(for input: String) -> [String] {
        // Simple fuzzy matching
        let lowercased = input.lowercased()
        return registeredCommands
            .filter { command in
                command.name.lowercased().contains(lowercased) ||
                command.aliases.contains { $0.lowercased().contains(lowercased) }
            }
            .prefix(3)
            .map { "/\($0.name)" }
    }

    // MARK: - Custom Command Management

    /// Register a custom command
    public func registerCustomCommand(
        name: String,
        description: String,
        prompt: String
    ) {
        let command = SlashCommand(
            name: name,
            description: description,
            usage: "/\(name)",
            category: .custom,
            isBuiltIn: false,
            customPrompt: prompt
        )

        registeredCommands.append(command)
        commandMap[name] = command
    }

    /// Unregister a custom command
    public func unregisterCommand(_ name: String) {
        guard let command = commandMap[name], !command.isBuiltIn else { return }

        registeredCommands.removeAll { $0.name == name }
        commandMap.removeValue(forKey: name)
    }

    // MARK: - Autocomplete

    /// Get autocomplete suggestions
    public func autocomplete(prefix: String) -> [String] {
        let cleanPrefix = prefix.hasPrefix("/") ? String(prefix.dropFirst()) : prefix

        if cleanPrefix.isEmpty {
            return registeredCommands.prefix(10).map { "/\($0.name)" }
        }

        return registeredCommands
            .filter { $0.name.hasPrefix(cleanPrefix.lowercased()) || $0.aliases.contains { $0.hasPrefix(cleanPrefix.lowercased()) } }
            .prefix(5)
            .map { "/\($0.name)" }
    }
}

// MARK: - Command History Entry

public struct CommandHistoryEntry: Identifiable, Codable {
    public let id: UUID
    public let command: String
    public let timestamp: Date
    public let success: Bool
    public let duration: TimeInterval

    public init(command: String, timestamp: Date, success: Bool, duration: TimeInterval) {
        self.id = UUID()
        self.command = command
        self.timestamp = timestamp
        self.success = success
        self.duration = duration
    }
}

// MARK: - Empty View for Design Review

private struct EmptyView: View {
    var body: some View {
        Color.clear
    }
}

#if DEBUG
extension SlashCommandEngine {
    /// Test command execution
    public func testCommand(_ input: String) async {
        let result = await execute(input)
        print("Command: \(result.command)")
        print("Success: \(result.success)")
        print("Duration: \(result.duration)s")
        print("Output:\n\(result.output)")
        if !result.errors.isEmpty {
            print("Errors: \(result.errors.joined(separator: ", "))")
        }
    }
}
#endif
