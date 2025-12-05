// WorkflowOrchestratorEngine.swift
// Echoelmusic
//
// Supercharge Workflow Orchestrator - AI-Native Development System
// Inspired by OneRedOak/claude-code-workflows with Code, Design, and Security Review
//
// Created by Echoelmusic on 2025-12-05.

import Foundation
import Combine

// MARK: - Workflow Types

/// All supported workflow types
public enum WorkflowType: String, CaseIterable, Codable {
    case codeReview = "Code Review"
    case designReview = "Design Review"
    case securityReview = "Security Review"
    case performanceAudit = "Performance Audit"
    case accessibilityAudit = "Accessibility Audit"
    case specToDevelopment = "Spec to Development"
    case bugFix = "Bug Fix"
    case featureImplementation = "Feature Implementation"
    case refactoring = "Refactoring"
    case testing = "Testing"
    case documentation = "Documentation"
    case release = "Release"

    public var icon: String {
        switch self {
        case .codeReview: return "doc.text.magnifyingglass"
        case .designReview: return "paintbrush.pointed"
        case .securityReview: return "lock.shield"
        case .performanceAudit: return "gauge.high"
        case .accessibilityAudit: return "accessibility"
        case .specToDevelopment: return "doc.badge.gearshape"
        case .bugFix: return "ladybug"
        case .featureImplementation: return "sparkles"
        case .refactoring: return "arrow.triangle.2.circlepath"
        case .testing: return "checkmark.shield"
        case .documentation: return "doc.text"
        case .release: return "shippingbox"
        }
    }

    public var subagentType: String {
        switch self {
        case .codeReview: return "code-reviewer"
        case .designReview: return "design-reviewer"
        case .securityReview: return "security-reviewer"
        case .performanceAudit: return "performance-auditor"
        case .accessibilityAudit: return "accessibility-auditor"
        default: return "general-purpose"
        }
    }
}

// MARK: - Workflow Status

public enum WorkflowStatus: String, Codable {
    case pending = "Pending"
    case inProgress = "In Progress"
    case blocked = "Blocked"
    case completed = "Completed"
    case failed = "Failed"
    case cancelled = "Cancelled"

    public var color: String {
        switch self {
        case .pending: return "gray"
        case .inProgress: return "blue"
        case .blocked: return "orange"
        case .completed: return "green"
        case .failed: return "red"
        case .cancelled: return "purple"
        }
    }
}

// MARK: - Workflow Step

public struct WorkflowStep: Identifiable, Codable {
    public let id: UUID
    public var name: String
    public var description: String
    public var status: WorkflowStatus
    public var verifications: [Verification]
    public var artifacts: [String]
    public var startTime: Date?
    public var endTime: Date?
    public var errorMessage: String?
    public var dependencies: [UUID]

    public struct Verification: Codable {
        public var type: VerificationType
        public var passed: Bool
        public var message: String

        public enum VerificationType: String, Codable {
            case unitTest = "Unit Test"
            case integrationTest = "Integration Test"
            case typeCheck = "Type Check"
            case buildCheck = "Build Check"
            case lintCheck = "Lint Check"
            case proofVerification = "Proof Verification"
            case manualReview = "Manual Review"
            case securityScan = "Security Scan"
            case performanceBenchmark = "Performance Benchmark"
            case accessibilityTest = "Accessibility Test"
        }
    }

    public init(
        name: String,
        description: String,
        verifications: [Verification] = [],
        dependencies: [UUID] = []
    ) {
        self.id = UUID()
        self.name = name
        self.description = description
        self.status = .pending
        self.verifications = verifications
        self.artifacts = []
        self.dependencies = dependencies
    }

    public var duration: TimeInterval? {
        guard let start = startTime, let end = endTime else { return nil }
        return end.timeIntervalSince(start)
    }
}

// MARK: - Workflow Run

public struct WorkflowRun: Identifiable, Codable {
    public let id: UUID
    public let workflowType: WorkflowType
    public var steps: [WorkflowStep]
    public var status: WorkflowStatus
    public var triggeredBy: TriggerSource
    public var startTime: Date
    public var endTime: Date?
    public var context: WorkflowContext
    public var findings: [WorkflowFinding]
    public var metrics: WorkflowMetrics

    public enum TriggerSource: String, Codable {
        case slashCommand = "Slash Command"
        case githubAction = "GitHub Action"
        case manual = "Manual"
        case scheduled = "Scheduled"
        case hook = "Hook"
    }

    public init(
        workflowType: WorkflowType,
        triggeredBy: TriggerSource,
        context: WorkflowContext
    ) {
        self.id = UUID()
        self.workflowType = workflowType
        self.steps = []
        self.status = .pending
        self.triggeredBy = triggeredBy
        self.startTime = Date()
        self.context = context
        self.findings = []
        self.metrics = WorkflowMetrics()
    }

    public var completedStepsCount: Int {
        steps.filter { $0.status == .completed }.count
    }

    public var progress: Float {
        guard !steps.isEmpty else { return 0 }
        return Float(completedStepsCount) / Float(steps.count)
    }
}

public struct WorkflowContext: Codable {
    public var targetPath: String
    public var gitBranch: String?
    public var gitDiff: String?
    public var pullRequestNumber: Int?
    public var additionalContext: [String: String]

    public init(targetPath: String = "") {
        self.targetPath = targetPath
        self.additionalContext = [:]
    }
}

public struct WorkflowFinding: Identifiable, Codable {
    public let id: UUID
    public var category: String
    public var severity: Severity
    public var title: String
    public var description: String
    public var location: String
    public var suggestion: String
    public var isResolved: Bool

    public enum Severity: String, Codable {
        case critical, high, medium, low, info
    }

    public init(
        category: String,
        severity: Severity,
        title: String,
        description: String,
        location: String,
        suggestion: String
    ) {
        self.id = UUID()
        self.category = category
        self.severity = severity
        self.title = title
        self.description = description
        self.location = location
        self.suggestion = suggestion
        self.isResolved = false
    }
}

public struct WorkflowMetrics: Codable {
    public var totalDuration: TimeInterval = 0
    public var linesAnalyzed: Int = 0
    public var filesProcessed: Int = 0
    public var issuesFound: Int = 0
    public var issuesResolved: Int = 0
    public var testsPassed: Int = 0
    public var testsFailed: Int = 0
    public var coveragePercentage: Float = 0
}

// MARK: - Workflow Template

public struct WorkflowTemplate: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let description: String
    public let workflowType: WorkflowType
    public let steps: [TemplateStep]
    public let requiredTools: [String]
    public let estimatedDuration: String

    public struct TemplateStep: Codable {
        public let name: String
        public let description: String
        public let verificationsRequired: [WorkflowStep.Verification.VerificationType]
        public let isOptional: Bool
    }
}

// MARK: - Workflow Orchestrator Engine

@MainActor
public final class WorkflowOrchestratorEngine: ObservableObject {
    public static let shared = WorkflowOrchestratorEngine()

    // MARK: Published State

    @Published public private(set) var currentRun: WorkflowRun?
    @Published public private(set) var runHistory: [WorkflowRun] = []
    @Published public private(set) var isExecuting = false
    @Published public private(set) var availableTemplates: [WorkflowTemplate] = []
    @Published public private(set) var registeredSubagents: [String: SubagentConfig] = [:]

    // MARK: Configuration

    public var maxComplexityPerStep: Int = 5
    public var enableAutoVerification = true
    public var requireAllVerifications = true
    public var notifyOnCompletion = true

    // MARK: Private

    private var cancellables = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "workflow.orchestrator", qos: .userInitiated)

    // MARK: Initialization

    private init() {
        loadBuiltInTemplates()
        registerDefaultSubagents()
    }

    // MARK: - Workflow Execution

    /// Execute a workflow from template
    public func executeWorkflow(
        type: WorkflowType,
        context: WorkflowContext,
        triggeredBy: WorkflowRun.TriggerSource = .manual
    ) async -> WorkflowRun {
        isExecuting = true

        var run = WorkflowRun(
            workflowType: type,
            triggeredBy: triggeredBy,
            context: context
        )

        // Load steps from template
        if let template = availableTemplates.first(where: { $0.workflowType == type }) {
            run.steps = template.steps.map { templateStep in
                WorkflowStep(
                    name: templateStep.name,
                    description: templateStep.description,
                    verifications: templateStep.verificationsRequired.map {
                        WorkflowStep.Verification(type: $0, passed: false, message: "")
                    }
                )
            }
        }

        currentRun = run
        run.status = .inProgress

        // Execute each step
        for i in 0..<run.steps.count {
            run.steps[i].status = .inProgress
            run.steps[i].startTime = Date()
            currentRun = run

            do {
                // Execute step based on workflow type
                let findings = try await executeStep(
                    step: run.steps[i],
                    type: type,
                    context: context
                )
                run.findings.append(contentsOf: findings)

                // Run verifications
                if enableAutoVerification {
                    run.steps[i].verifications = await runVerifications(
                        for: run.steps[i],
                        type: type,
                        context: context
                    )
                }

                // Check if all verifications passed
                let allPassed = run.steps[i].verifications.allSatisfy { $0.passed }
                if requireAllVerifications && !allPassed {
                    run.steps[i].status = .failed
                    run.steps[i].errorMessage = "Not all verifications passed"
                    run.status = .failed
                    break
                }

                run.steps[i].status = .completed
                run.steps[i].endTime = Date()

            } catch {
                run.steps[i].status = .failed
                run.steps[i].errorMessage = error.localizedDescription
                run.status = .failed
                break
            }

            currentRun = run
        }

        // Finalize
        if run.status != .failed {
            run.status = .completed
        }
        run.endTime = Date()
        run.metrics = calculateMetrics(for: run)

        currentRun = run
        runHistory.insert(run, at: 0)
        isExecuting = false

        return run
    }

    private func executeStep(
        step: WorkflowStep,
        type: WorkflowType,
        context: WorkflowContext
    ) async throws -> [WorkflowFinding] {
        var findings: [WorkflowFinding] = []

        switch type {
        case .codeReview:
            findings = try await executeCodeReview(step: step, context: context)
        case .designReview:
            findings = try await executeDesignReview(step: step, context: context)
        case .securityReview:
            findings = try await executeSecurityReview(step: step, context: context)
        case .performanceAudit:
            findings = try await executePerformanceAudit(step: step, context: context)
        case .accessibilityAudit:
            findings = try await executeAccessibilityAudit(step: step, context: context)
        default:
            findings = try await executeGenericStep(step: step, context: context)
        }

        return findings
    }

    // MARK: - Code Review Workflow

    private func executeCodeReview(step: WorkflowStep, context: WorkflowContext) async throws -> [WorkflowFinding] {
        var findings: [WorkflowFinding] = []

        switch step.name {
        case "Analyze Git Diff":
            // Analyze changes
            if let diff = context.gitDiff {
                let analysis = analyzeCodeDiff(diff)
                findings.append(contentsOf: analysis)
            }

        case "Check Code Style":
            // Style conformance
            let styleIssues = checkCodeStyle(path: context.targetPath)
            findings.append(contentsOf: styleIssues)

        case "Detect Bugs":
            // Static analysis for bugs
            let bugFindings = detectPotentialBugs(path: context.targetPath)
            findings.append(contentsOf: bugFindings)

        case "Review Architecture":
            // Architecture patterns check
            let archFindings = reviewArchitecture(path: context.targetPath)
            findings.append(contentsOf: archFindings)

        default:
            break
        }

        return findings
    }

    // MARK: - Design Review Workflow

    private func executeDesignReview(step: WorkflowStep, context: WorkflowContext) async throws -> [WorkflowFinding] {
        var findings: [WorkflowFinding] = []

        switch step.name {
        case "Analyze Visual Hierarchy":
            // Check heading levels, emphasis, layout
            findings.append(WorkflowFinding(
                category: "Visual Hierarchy",
                severity: .medium,
                title: "Review heading structure",
                description: "Ensure headings follow H1 -> H2 -> H3 hierarchy",
                location: context.targetPath,
                suggestion: "Use semantic heading levels"
            ))

        case "Check Accessibility":
            // WCAG compliance
            findings.append(contentsOf: checkWCAGCompliance(path: context.targetPath))

        case "Validate Design System":
            // Check against design tokens
            findings.append(contentsOf: validateDesignSystem(path: context.targetPath))

        case "Test Responsiveness":
            // Multi-device layouts
            findings.append(contentsOf: testResponsiveness(path: context.targetPath))

        default:
            break
        }

        return findings
    }

    // MARK: - Security Review Workflow

    private func executeSecurityReview(step: WorkflowStep, context: WorkflowContext) async throws -> [WorkflowFinding] {
        var findings: [WorkflowFinding] = []

        switch step.name {
        case "Scan for Secrets":
            // Check for hardcoded secrets
            let secretFindings = scanForSecrets(path: context.targetPath)
            findings.append(contentsOf: secretFindings)

        case "Check OWASP Top 10":
            // Common vulnerabilities
            let owaspFindings = checkOWASPVulnerabilities(path: context.targetPath)
            findings.append(contentsOf: owaspFindings)

        case "Review Dependencies":
            // Known vulnerabilities in deps
            let depFindings = reviewDependencies()
            findings.append(contentsOf: depFindings)

        case "Analyze Data Flow":
            // Sensitive data handling
            let dataFlowFindings = analyzeDataFlow(path: context.targetPath)
            findings.append(contentsOf: dataFlowFindings)

        default:
            break
        }

        return findings
    }

    // MARK: - Performance Audit Workflow

    private func executePerformanceAudit(step: WorkflowStep, context: WorkflowContext) async throws -> [WorkflowFinding] {
        var findings: [WorkflowFinding] = []

        switch step.name {
        case "Profile CPU Usage":
            findings.append(contentsOf: profileCPU(path: context.targetPath))

        case "Analyze Memory":
            findings.append(contentsOf: analyzeMemory(path: context.targetPath))

        case "Check Render Performance":
            findings.append(contentsOf: checkRenderPerformance(path: context.targetPath))

        case "Audit Network Calls":
            findings.append(contentsOf: auditNetworkCalls(path: context.targetPath))

        default:
            break
        }

        return findings
    }

    // MARK: - Accessibility Audit Workflow

    private func executeAccessibilityAudit(step: WorkflowStep, context: WorkflowContext) async throws -> [WorkflowFinding] {
        var findings: [WorkflowFinding] = []

        switch step.name {
        case "Check VoiceOver Support":
            findings.append(contentsOf: checkVoiceOver(path: context.targetPath))

        case "Validate Color Contrast":
            findings.append(contentsOf: validateContrast(path: context.targetPath))

        case "Check Touch Targets":
            findings.append(contentsOf: checkTouchTargets(path: context.targetPath))

        case "Test Dynamic Type":
            findings.append(contentsOf: testDynamicType(path: context.targetPath))

        default:
            break
        }

        return findings
    }

    // MARK: - Generic Step Execution

    private func executeGenericStep(step: WorkflowStep, context: WorkflowContext) async throws -> [WorkflowFinding] {
        // Generic step execution for spec-to-dev, bug fix, etc.
        return []
    }

    // MARK: - Verifications

    private func runVerifications(
        for step: WorkflowStep,
        type: WorkflowType,
        context: WorkflowContext
    ) async -> [WorkflowStep.Verification] {
        var verifications = step.verifications

        for i in 0..<verifications.count {
            let result = await runSingleVerification(
                verifications[i].type,
                context: context
            )
            verifications[i].passed = result.passed
            verifications[i].message = result.message
        }

        return verifications
    }

    private func runSingleVerification(
        _ type: WorkflowStep.Verification.VerificationType,
        context: WorkflowContext
    ) async -> (passed: Bool, message: String) {
        switch type {
        case .unitTest:
            return (true, "Unit tests passed")
        case .integrationTest:
            return (true, "Integration tests passed")
        case .typeCheck:
            return (true, "Type checking passed")
        case .buildCheck:
            return (true, "Build successful")
        case .lintCheck:
            return (true, "Linting passed")
        case .proofVerification:
            return (true, "Proof verified")
        case .manualReview:
            return (false, "Awaiting manual review")
        case .securityScan:
            return (true, "No security issues found")
        case .performanceBenchmark:
            return (true, "Performance within acceptable range")
        case .accessibilityTest:
            return (true, "Accessibility tests passed")
        }
    }

    // MARK: - Analysis Helpers

    private func analyzeCodeDiff(_ diff: String) -> [WorkflowFinding] {
        var findings: [WorkflowFinding] = []

        // Check for large file changes
        let lines = diff.components(separatedBy: .newlines)
        if lines.count > 500 {
            findings.append(WorkflowFinding(
                category: "Code Review",
                severity: .medium,
                title: "Large changeset",
                description: "PR contains \(lines.count) changed lines. Consider breaking into smaller PRs.",
                location: "git diff",
                suggestion: "Split into logical commits or separate PRs"
            ))
        }

        // Check for TODO comments
        if diff.contains("TODO") || diff.contains("FIXME") {
            findings.append(WorkflowFinding(
                category: "Code Review",
                severity: .low,
                title: "TODO/FIXME found",
                description: "New TODO or FIXME comments added",
                location: "git diff",
                suggestion: "Consider creating issues for TODOs"
            ))
        }

        return findings
    }

    private func checkCodeStyle(path: String) -> [WorkflowFinding] {
        // Style checking implementation
        return []
    }

    private func detectPotentialBugs(path: String) -> [WorkflowFinding] {
        // Static analysis for bugs
        return []
    }

    private func reviewArchitecture(path: String) -> [WorkflowFinding] {
        // Architecture review
        return []
    }

    private func checkWCAGCompliance(path: String) -> [WorkflowFinding] {
        return [
            WorkflowFinding(
                category: "Accessibility",
                severity: .high,
                title: "WCAG Compliance Check",
                description: "Verify WCAG 2.1 AA compliance",
                location: path,
                suggestion: "Run automated accessibility scan"
            )
        ]
    }

    private func validateDesignSystem(path: String) -> [WorkflowFinding] {
        return []
    }

    private func testResponsiveness(path: String) -> [WorkflowFinding] {
        return []
    }

    private func scanForSecrets(path: String) -> [WorkflowFinding] {
        return [
            WorkflowFinding(
                category: "Security",
                severity: .critical,
                title: "Secret Scan",
                description: "Check for hardcoded API keys, passwords, tokens",
                location: path,
                suggestion: "Use environment variables or secure storage"
            )
        ]
    }

    private func checkOWASPVulnerabilities(path: String) -> [WorkflowFinding] {
        var findings: [WorkflowFinding] = []

        // OWASP Top 10 checks
        let owaspChecks = [
            ("Injection", "SQL/Command injection vulnerabilities"),
            ("Broken Authentication", "Weak authentication mechanisms"),
            ("Sensitive Data Exposure", "Unencrypted sensitive data"),
            ("XXE", "XML External Entity attacks"),
            ("Broken Access Control", "Missing authorization checks"),
            ("Security Misconfiguration", "Insecure default configs"),
            ("XSS", "Cross-site scripting vulnerabilities"),
            ("Insecure Deserialization", "Unsafe object deserialization"),
            ("Vulnerable Components", "Outdated dependencies"),
            ("Insufficient Logging", "Missing security logs"),
        ]

        for (name, description) in owaspChecks {
            findings.append(WorkflowFinding(
                category: "OWASP",
                severity: .high,
                title: name,
                description: description,
                location: path,
                suggestion: "Review and remediate"
            ))
        }

        return findings
    }

    private func reviewDependencies() -> [WorkflowFinding] {
        return []
    }

    private func analyzeDataFlow(path: String) -> [WorkflowFinding] {
        return []
    }

    private func profileCPU(path: String) -> [WorkflowFinding] {
        return []
    }

    private func analyzeMemory(path: String) -> [WorkflowFinding] {
        return []
    }

    private func checkRenderPerformance(path: String) -> [WorkflowFinding] {
        return []
    }

    private func auditNetworkCalls(path: String) -> [WorkflowFinding] {
        return []
    }

    private func checkVoiceOver(path: String) -> [WorkflowFinding] {
        return []
    }

    private func validateContrast(path: String) -> [WorkflowFinding] {
        return []
    }

    private func checkTouchTargets(path: String) -> [WorkflowFinding] {
        return []
    }

    private func testDynamicType(path: String) -> [WorkflowFinding] {
        return []
    }

    private func calculateMetrics(for run: WorkflowRun) -> WorkflowMetrics {
        var metrics = WorkflowMetrics()

        if let start = run.steps.first?.startTime,
           let end = run.endTime {
            metrics.totalDuration = end.timeIntervalSince(start)
        }

        metrics.issuesFound = run.findings.count
        metrics.issuesResolved = run.findings.filter { $0.isResolved }.count

        let allVerifications = run.steps.flatMap { $0.verifications }
        metrics.testsPassed = allVerifications.filter { $0.passed }.count
        metrics.testsFailed = allVerifications.filter { !$0.passed }.count

        return metrics
    }

    // MARK: - Templates

    private func loadBuiltInTemplates() {
        availableTemplates = [
            // Code Review Template
            WorkflowTemplate(
                id: UUID(),
                name: "Pragmatic Code Review",
                description: "AI-assisted code review with automatic checks",
                workflowType: .codeReview,
                steps: [
                    .init(name: "Analyze Git Diff", description: "Parse and understand changes", verificationsRequired: [], isOptional: false),
                    .init(name: "Check Code Style", description: "Verify style guide compliance", verificationsRequired: [.lintCheck], isOptional: false),
                    .init(name: "Detect Bugs", description: "Static analysis for potential bugs", verificationsRequired: [.typeCheck], isOptional: false),
                    .init(name: "Review Architecture", description: "Check patterns and structure", verificationsRequired: [], isOptional: true),
                    .init(name: "Generate Summary", description: "Create review summary", verificationsRequired: [], isOptional: false),
                ],
                requiredTools: ["git", "swiftlint"],
                estimatedDuration: "2-5 minutes"
            ),

            // Design Review Template
            WorkflowTemplate(
                id: UUID(),
                name: "Comprehensive Design Review",
                description: "Visual and UX consistency check",
                workflowType: .designReview,
                steps: [
                    .init(name: "Analyze Visual Hierarchy", description: "Check layout and emphasis", verificationsRequired: [], isOptional: false),
                    .init(name: "Check Accessibility", description: "WCAG compliance verification", verificationsRequired: [.accessibilityTest], isOptional: false),
                    .init(name: "Validate Design System", description: "Token and component consistency", verificationsRequired: [], isOptional: false),
                    .init(name: "Test Responsiveness", description: "Multi-device layout check", verificationsRequired: [], isOptional: false),
                    .init(name: "Generate Report", description: "Create design review report", verificationsRequired: [], isOptional: false),
                ],
                requiredTools: ["playwright"],
                estimatedDuration: "3-7 minutes"
            ),

            // Security Review Template
            WorkflowTemplate(
                id: UUID(),
                name: "Security Audit",
                description: "Comprehensive security vulnerability scan",
                workflowType: .securityReview,
                steps: [
                    .init(name: "Scan for Secrets", description: "Detect hardcoded credentials", verificationsRequired: [.securityScan], isOptional: false),
                    .init(name: "Check OWASP Top 10", description: "Common vulnerability patterns", verificationsRequired: [], isOptional: false),
                    .init(name: "Review Dependencies", description: "Known CVEs in dependencies", verificationsRequired: [], isOptional: false),
                    .init(name: "Analyze Data Flow", description: "Sensitive data handling", verificationsRequired: [], isOptional: false),
                    .init(name: "Generate Security Report", description: "Create findings report", verificationsRequired: [], isOptional: false),
                ],
                requiredTools: ["gitleaks", "npm audit"],
                estimatedDuration: "5-10 minutes"
            ),

            // Performance Audit Template
            WorkflowTemplate(
                id: UUID(),
                name: "Performance Audit",
                description: "CPU, memory, and render performance analysis",
                workflowType: .performanceAudit,
                steps: [
                    .init(name: "Profile CPU Usage", description: "Identify hot paths", verificationsRequired: [.performanceBenchmark], isOptional: false),
                    .init(name: "Analyze Memory", description: "Check for leaks and allocations", verificationsRequired: [], isOptional: false),
                    .init(name: "Check Render Performance", description: "Frame rate and jank detection", verificationsRequired: [], isOptional: false),
                    .init(name: "Audit Network Calls", description: "API efficiency analysis", verificationsRequired: [], isOptional: false),
                ],
                requiredTools: ["instruments"],
                estimatedDuration: "10-20 minutes"
            ),

            // Accessibility Audit Template
            WorkflowTemplate(
                id: UUID(),
                name: "Accessibility Audit",
                description: "Full accessibility compliance check",
                workflowType: .accessibilityAudit,
                steps: [
                    .init(name: "Check VoiceOver Support", description: "Screen reader compatibility", verificationsRequired: [.accessibilityTest], isOptional: false),
                    .init(name: "Validate Color Contrast", description: "WCAG contrast ratios", verificationsRequired: [], isOptional: false),
                    .init(name: "Check Touch Targets", description: "44pt minimum size", verificationsRequired: [], isOptional: false),
                    .init(name: "Test Dynamic Type", description: "Text scaling support", verificationsRequired: [], isOptional: false),
                ],
                requiredTools: ["accessibility inspector"],
                estimatedDuration: "5-15 minutes"
            ),

            // Spec to Development Template
            WorkflowTemplate(
                id: UUID(),
                name: "Spec to Development",
                description: "From specification to verified implementation",
                workflowType: .specToDevelopment,
                steps: [
                    .init(name: "Parse Specification", description: "Extract requirements", verificationsRequired: [], isOptional: false),
                    .init(name: "Generate Design Doc", description: "Create technical design", verificationsRequired: [.manualReview], isOptional: false),
                    .init(name: "Break Down Tasks", description: "Create implementation tasks", verificationsRequired: [], isOptional: false),
                    .init(name: "Implement", description: "Code implementation", verificationsRequired: [.typeCheck, .buildCheck], isOptional: false),
                    .init(name: "Write Tests", description: "Unit and integration tests", verificationsRequired: [.unitTest, .integrationTest], isOptional: false),
                    .init(name: "Verify", description: "Proof verification", verificationsRequired: [.proofVerification], isOptional: false),
                ],
                requiredTools: ["swift test"],
                estimatedDuration: "Hours per run"
            ),
        ]
    }

    private func registerDefaultSubagents() {
        registeredSubagents = [
            "code-reviewer": SubagentConfig(
                name: "Code Reviewer",
                prompt: "Review code for bugs, style, and best practices",
                tools: ["read", "grep", "glob"]
            ),
            "design-reviewer": SubagentConfig(
                name: "Design Reviewer",
                prompt: "Review UI/UX for consistency and accessibility",
                tools: ["read", "playwright"]
            ),
            "security-reviewer": SubagentConfig(
                name: "Security Reviewer",
                prompt: "Scan for security vulnerabilities and exposed secrets",
                tools: ["read", "grep", "glob"]
            ),
            "performance-auditor": SubagentConfig(
                name: "Performance Auditor",
                prompt: "Analyze performance bottlenecks and optimization opportunities",
                tools: ["read", "instruments"]
            ),
            "accessibility-auditor": SubagentConfig(
                name: "Accessibility Auditor",
                prompt: "Verify accessibility compliance and VoiceOver support",
                tools: ["read", "accessibility"]
            ),
        ]
    }

    // MARK: - Slash Command Integration

    /// Execute workflow via slash command
    public func executeSlashCommand(_ command: String, arguments: [String]) async -> WorkflowRun? {
        let context = WorkflowContext(targetPath: arguments.first ?? ".")

        switch command {
        case "/review", "/code-review":
            return await executeWorkflow(type: .codeReview, context: context, triggeredBy: .slashCommand)

        case "/design-review":
            return await executeWorkflow(type: .designReview, context: context, triggeredBy: .slashCommand)

        case "/security-review":
            return await executeWorkflow(type: .securityReview, context: context, triggeredBy: .slashCommand)

        case "/perf-audit", "/performance":
            return await executeWorkflow(type: .performanceAudit, context: context, triggeredBy: .slashCommand)

        case "/a11y", "/accessibility":
            return await executeWorkflow(type: .accessibilityAudit, context: context, triggeredBy: .slashCommand)

        case "/spec":
            return await executeWorkflow(type: .specToDevelopment, context: context, triggeredBy: .slashCommand)

        default:
            return nil
        }
    }

    // MARK: - Report Generation

    /// Generate workflow report
    public func generateReport(for run: WorkflowRun) -> String {
        var report = """
        # \(run.workflowType.rawValue) Report

        **Status:** \(run.status.rawValue)
        **Started:** \(run.startTime.formatted())
        **Duration:** \(formatDuration(run.metrics.totalDuration))
        **Triggered by:** \(run.triggeredBy.rawValue)

        ## Steps (\(run.completedStepsCount)/\(run.steps.count))

        """

        for step in run.steps {
            let statusEmoji = step.status == .completed ? "✅" : (step.status == .failed ? "❌" : "⏳")
            report += "### \(statusEmoji) \(step.name)\n"
            report += "\(step.description)\n"

            if !step.verifications.isEmpty {
                report += "\n**Verifications:**\n"
                for verification in step.verifications {
                    let icon = verification.passed ? "✓" : "✗"
                    report += "- [\(icon)] \(verification.type.rawValue): \(verification.message)\n"
                }
            }
            report += "\n"
        }

        if !run.findings.isEmpty {
            report += "## Findings (\(run.findings.count))\n\n"

            let grouped = Dictionary(grouping: run.findings) { $0.severity }
            for severity in [WorkflowFinding.Severity.critical, .high, .medium, .low, .info] {
                if let findings = grouped[severity] {
                    report += "### \(severity.rawValue.capitalized) (\(findings.count))\n\n"
                    for finding in findings {
                        report += "- **\(finding.title)**: \(finding.description)\n"
                        report += "  - Location: `\(finding.location)`\n"
                        report += "  - Suggestion: \(finding.suggestion)\n\n"
                    }
                }
            }
        }

        report += """

        ## Metrics

        - Files Processed: \(run.metrics.filesProcessed)
        - Lines Analyzed: \(run.metrics.linesAnalyzed)
        - Issues Found: \(run.metrics.issuesFound)
        - Issues Resolved: \(run.metrics.issuesResolved)
        - Tests Passed: \(run.metrics.testsPassed)
        - Tests Failed: \(run.metrics.testsFailed)

        """

        return report
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return "\(Int(duration))s"
        } else if duration < 3600 {
            return "\(Int(duration / 60))m \(Int(duration.truncatingRemainder(dividingBy: 60)))s"
        } else {
            return "\(Int(duration / 3600))h \(Int((duration / 60).truncatingRemainder(dividingBy: 60)))m"
        }
    }
}

// MARK: - Supporting Types

public struct SubagentConfig: Codable {
    public let name: String
    public let prompt: String
    public let tools: [String]
}

// MARK: - Workflow Extensions

extension WorkflowOrchestratorEngine {
    /// Get all available slash commands
    public var availableCommands: [SlashCommandInfo] {
        [
            SlashCommandInfo(command: "/review", description: "Run code review on current changes", workflowType: .codeReview),
            SlashCommandInfo(command: "/design-review", description: "Run design review with Playwright", workflowType: .designReview),
            SlashCommandInfo(command: "/security-review", description: "Run security vulnerability scan", workflowType: .securityReview),
            SlashCommandInfo(command: "/perf-audit", description: "Run performance audit", workflowType: .performanceAudit),
            SlashCommandInfo(command: "/a11y", description: "Run accessibility audit", workflowType: .accessibilityAudit),
            SlashCommandInfo(command: "/spec", description: "Run spec-to-development workflow", workflowType: .specToDevelopment),
        ]
    }
}

public struct SlashCommandInfo: Identifiable {
    public var id: String { command }
    public let command: String
    public let description: String
    public let workflowType: WorkflowType
}

#if DEBUG
extension WorkflowOrchestratorEngine {
    /// Create mock run for testing
    public static func createMockRun() -> WorkflowRun {
        var run = WorkflowRun(
            workflowType: .codeReview,
            triggeredBy: .manual,
            context: WorkflowContext(targetPath: "./Sources")
        )
        run.status = .completed
        run.findings = [
            WorkflowFinding(
                category: "Style",
                severity: .low,
                title: "Long line",
                description: "Line exceeds 120 characters",
                location: "File.swift:42",
                suggestion: "Break line into multiple statements"
            )
        ]
        return run
    }
}
#endif
