import Foundation
import Combine

// MARK: - Taskmaster Engine
// Spec-to-Software Verification-Driven Development
// "Don't trust it - verify every step with proofs"
// Implements the workflow: Spec → Design → Tasks → Implementation → Verification

/// Taskmaster Engine for Claude Code integration
/// Manages the entire development lifecycle from specifications to verified software
@MainActor
@Observable
class TaskmasterEngine {

    // MARK: - State

    /// Current project being managed
    var currentProject: Project?

    /// All tasks in the system
    var tasks: [DevelopmentTask] = []

    /// Current workflow phase
    var currentPhase: WorkflowPhase = .idle

    /// Verification results
    var verificationResults: [VerificationResult] = []

    /// Context from MCP
    var mcpContext: MCPContext?

    /// Whether verification mode is enabled
    var verificationEnabled: Bool = true

    /// Maximum complexity per step (context engineering)
    var maxComplexityPerStep: Int = 5

    // MARK: - Types

    /// Project specification
    struct Project: Identifiable, Codable {
        let id: UUID
        var name: String
        var description: String
        var specifications: [Specification]
        var technicalDesign: TechnicalDesign?
        var status: ProjectStatus
        var createdAt: Date
        var updatedAt: Date

        enum ProjectStatus: String, Codable {
            case draft
            case specifying
            case designing
            case implementing
            case testing
            case verified
            case complete
        }
    }

    /// Specification document
    struct Specification: Identifiable, Codable {
        let id: UUID
        var title: String
        var description: String
        var requirements: [Requirement]
        var acceptance: [AcceptanceCriteria]
        var priority: Priority
        var complexity: Int // 1-10

        enum Priority: String, Codable, CaseIterable {
            case critical, high, medium, low
        }
    }

    struct Requirement: Identifiable, Codable {
        let id: UUID
        var description: String
        var type: RequirementType
        var verified: Bool

        enum RequirementType: String, Codable {
            case functional
            case nonFunctional
            case constraint
            case assumption
        }
    }

    struct AcceptanceCriteria: Identifiable, Codable {
        let id: UUID
        var given: String
        var when: String
        var then: String
        var verified: Bool
    }

    /// Technical design document
    struct TechnicalDesign: Codable {
        var architecture: String
        var components: [Component]
        var dataFlow: String
        var dependencies: [Dependency]
        var securityConsiderations: [String]
        var performanceRequirements: [String]

        struct Component: Identifiable, Codable {
            let id: UUID
            var name: String
            var responsibility: String
            var interfaces: [String]
            var dependencies: [UUID]
        }

        struct Dependency: Identifiable, Codable {
            let id: UUID
            var name: String
            var version: String
            var purpose: String
        }
    }

    /// Development task with verification
    struct DevelopmentTask: Identifiable, Codable {
        let id: UUID
        var title: String
        var description: String
        var specificationId: UUID?
        var dependencies: [UUID]
        var subtasks: [Subtask]
        var status: TaskStatus
        var complexity: Int
        var estimatedSteps: Int
        var actualSteps: Int
        var verifications: [Verification]
        var createdAt: Date
        var completedAt: Date?

        enum TaskStatus: String, Codable {
            case pending
            case ready // All dependencies met
            case inProgress
            case awaitingVerification
            case verified
            case failed
            case blocked
        }

        struct Subtask: Identifiable, Codable {
            let id: UUID
            var description: String
            var status: TaskStatus
            var verification: Verification?
        }

        struct Verification: Codable {
            var type: VerificationType
            var command: String?
            var expectedOutput: String?
            var actualOutput: String?
            var passed: Bool
            var timestamp: Date

            enum VerificationType: String, Codable {
                case unitTest
                case integrationTest
                case typeCheck
                case lintCheck
                case buildCheck
                case manualReview
                case proofVerification
                case propertyTest
            }
        }
    }

    /// Workflow phases
    enum WorkflowPhase: String {
        case idle = "Idle"
        case specifying = "Gathering Specifications"
        case designing = "Technical Design"
        case taskBreakdown = "Breaking Down Tasks"
        case implementing = "Implementing"
        case verifying = "Verifying"
        case complete = "Complete"
    }

    /// Verification result
    struct VerificationResult: Identifiable {
        let id: UUID
        let taskId: UUID
        let step: Int
        let verificationType: DevelopmentTask.Verification.VerificationType
        let passed: Bool
        let details: String
        let timestamp: Date
    }

    /// MCP Context from external tools
    struct MCPContext: Codable {
        var codebaseContext: String?
        var buildLogs: [String]
        var errorTraces: [String]
        var databaseSchemas: [String]
        var dependencies: [String: String]
        var testResults: [TestResult]
        var lastUpdated: Date

        struct TestResult: Codable {
            let name: String
            let passed: Bool
            let duration: TimeInterval
            let output: String?
        }
    }

    // MARK: - Initialization

    private var cancellables = Set<AnyCancellable>()

    init() {
        print("🎯 Taskmaster Engine initialized")
        print("📋 Verification mode: \(verificationEnabled ? "ENABLED" : "DISABLED")")
        print("🔢 Max complexity per step: \(maxComplexityPerStep)")
    }

    // MARK: - Project Management

    /// Create a new project from specifications
    func createProject(
        name: String,
        description: String
    ) -> Project {
        let project = Project(
            id: UUID(),
            name: name,
            description: description,
            specifications: [],
            technicalDesign: nil,
            status: .draft,
            createdAt: Date(),
            updatedAt: Date()
        )

        currentProject = project
        currentPhase = .specifying

        print("📁 Project created: \(name)")
        return project
    }

    /// Add specification to current project
    func addSpecification(
        title: String,
        description: String,
        requirements: [String],
        acceptance: [(given: String, when: String, then: String)],
        priority: Specification.Priority = .medium,
        complexity: Int = 5
    ) throws {
        guard var project = currentProject else {
            throw TaskmasterError.noActiveProject
        }

        let spec = Specification(
            id: UUID(),
            title: title,
            description: description,
            requirements: requirements.map { req in
                Requirement(
                    id: UUID(),
                    description: req,
                    type: .functional,
                    verified: false
                )
            },
            acceptance: acceptance.map { ac in
                AcceptanceCriteria(
                    id: UUID(),
                    given: ac.given,
                    when: ac.when,
                    then: ac.then,
                    verified: false
                )
            },
            priority: priority,
            complexity: complexity
        )

        project.specifications.append(spec)
        project.updatedAt = Date()
        currentProject = project

        print("📝 Specification added: \(title) (complexity: \(complexity))")
    }

    // MARK: - Task Generation (Context Engineering)

    /// Generate tasks from specifications with complexity limits
    /// Key insight: Don't ask AI to do too much per step
    func generateTasks() throws -> [DevelopmentTask] {
        guard let project = currentProject else {
            throw TaskmasterError.noActiveProject
        }

        currentPhase = .taskBreakdown
        var generatedTasks: [DevelopmentTask] = []

        for spec in project.specifications {
            // Break down based on complexity
            let taskCount = max(1, spec.complexity / maxComplexityPerStep)

            for i in 0..<taskCount {
                let subtaskComplexity = min(maxComplexityPerStep, spec.complexity - (i * maxComplexityPerStep))

                let task = DevelopmentTask(
                    id: UUID(),
                    title: "\(spec.title) - Part \(i + 1)/\(taskCount)",
                    description: "Implement portion \(i + 1) of \(spec.title)",
                    specificationId: spec.id,
                    dependencies: i > 0 ? [generatedTasks.last!.id] : [],
                    subtasks: generateSubtasks(for: spec, part: i, complexity: subtaskComplexity),
                    status: .pending,
                    complexity: subtaskComplexity,
                    estimatedSteps: subtaskComplexity * 3,
                    actualSteps: 0,
                    verifications: [],
                    createdAt: Date(),
                    completedAt: nil
                )

                generatedTasks.append(task)
            }
        }

        tasks = generatedTasks
        updateTaskReadiness()

        print("✅ Generated \(generatedTasks.count) tasks with max complexity \(maxComplexityPerStep) per task")
        return generatedTasks
    }

    private func generateSubtasks(
        for spec: Specification,
        part: Int,
        complexity: Int
    ) -> [DevelopmentTask.Subtask] {
        // Generate subtasks based on requirements
        let reqsPerPart = max(1, spec.requirements.count / max(1, spec.complexity / maxComplexityPerStep))
        let startIdx = part * reqsPerPart
        let endIdx = min(startIdx + reqsPerPart, spec.requirements.count)

        var subtasks: [DevelopmentTask.Subtask] = []

        for i in startIdx..<endIdx {
            let req = spec.requirements[i]
            subtasks.append(DevelopmentTask.Subtask(
                id: UUID(),
                description: req.description,
                status: .pending,
                verification: nil
            ))
        }

        // Always add a verification subtask
        subtasks.append(DevelopmentTask.Subtask(
            id: UUID(),
            description: "Verify implementation meets acceptance criteria",
            status: .pending,
            verification: nil
        ))

        return subtasks
    }

    /// Update task readiness based on dependencies
    private func updateTaskReadiness() {
        for i in 0..<tasks.count {
            if tasks[i].status == .pending {
                let allDependenciesMet = tasks[i].dependencies.allSatisfy { depId in
                    tasks.first(where: { $0.id == depId })?.status == .verified
                }

                if allDependenciesMet && tasks[i].dependencies.isEmpty == false {
                    tasks[i].status = .ready
                } else if tasks[i].dependencies.isEmpty {
                    tasks[i].status = .ready
                }
            }
        }
    }

    // MARK: - Implementation with Verification

    /// Get the next task to work on
    func getNextTask() -> DevelopmentTask? {
        // Prioritize by: ready status, then by priority (via spec), then by creation date
        return tasks
            .filter { $0.status == .ready }
            .sorted { t1, t2 in
                // Sort by complexity (simpler first for momentum)
                t1.complexity < t2.complexity
            }
            .first
    }

    /// Start working on a task
    func startTask(_ taskId: UUID) throws {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else {
            throw TaskmasterError.taskNotFound
        }

        guard tasks[index].status == .ready else {
            throw TaskmasterError.taskNotReady
        }

        tasks[index].status = .inProgress
        currentPhase = .implementing

        print("🚀 Started task: \(tasks[index].title)")
    }

    /// Complete a subtask with verification
    func completeSubtask(
        taskId: UUID,
        subtaskId: UUID,
        verification: DevelopmentTask.Verification
    ) throws {
        guard let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) else {
            throw TaskmasterError.taskNotFound
        }

        guard let subtaskIndex = tasks[taskIndex].subtasks.firstIndex(where: { $0.id == subtaskId }) else {
            throw TaskmasterError.subtaskNotFound
        }

        // Record verification
        tasks[taskIndex].subtasks[subtaskIndex].verification = verification
        tasks[taskIndex].actualSteps += 1

        if verification.passed {
            tasks[taskIndex].subtasks[subtaskIndex].status = .verified
            print("✅ Subtask verified: \(tasks[taskIndex].subtasks[subtaskIndex].description)")
        } else {
            tasks[taskIndex].subtasks[subtaskIndex].status = .failed
            print("❌ Subtask failed verification: \(tasks[taskIndex].subtasks[subtaskIndex].description)")

            // Record failure for analysis
            verificationResults.append(VerificationResult(
                id: UUID(),
                taskId: taskId,
                step: tasks[taskIndex].actualSteps,
                verificationType: verification.type,
                passed: false,
                details: verification.actualOutput ?? "No output",
                timestamp: Date()
            ))
        }

        // Check if all subtasks are complete
        checkTaskCompletion(taskId: taskId)
    }

    private func checkTaskCompletion(taskId: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskId }) else { return }

        let allSubtasksVerified = tasks[index].subtasks.allSatisfy { $0.status == .verified }
        let anySubtaskFailed = tasks[index].subtasks.contains { $0.status == .failed }

        if allSubtasksVerified {
            tasks[index].status = .verified
            tasks[index].completedAt = Date()
            updateTaskReadiness()
            print("🎉 Task completed and verified: \(tasks[index].title)")
        } else if anySubtaskFailed {
            tasks[index].status = .failed
            print("⚠️ Task has failed subtasks: \(tasks[index].title)")
        }

        // Check if all tasks are complete
        if tasks.allSatisfy({ $0.status == .verified }) {
            currentPhase = .complete
            if var project = currentProject {
                project.status = .verified
                currentProject = project
            }
            print("🏆 All tasks verified! Project complete.")
        }
    }

    // MARK: - Verification Helpers

    /// Create a verification for unit tests
    func createUnitTestVerification(
        command: String,
        expectedOutput: String? = nil
    ) -> DevelopmentTask.Verification {
        DevelopmentTask.Verification(
            type: .unitTest,
            command: command,
            expectedOutput: expectedOutput,
            actualOutput: nil,
            passed: false,
            timestamp: Date()
        )
    }

    /// Create a verification for type checking
    func createTypeCheckVerification() -> DevelopmentTask.Verification {
        DevelopmentTask.Verification(
            type: .typeCheck,
            command: "swift build",
            expectedOutput: "Build complete!",
            actualOutput: nil,
            passed: false,
            timestamp: Date()
        )
    }

    /// Create a verification for build
    func createBuildVerification() -> DevelopmentTask.Verification {
        DevelopmentTask.Verification(
            type: .buildCheck,
            command: "swift build -c release",
            expectedOutput: nil,
            actualOutput: nil,
            passed: false,
            timestamp: Date()
        )
    }

    /// Run verification and update result
    func runVerification(
        _ verification: inout DevelopmentTask.Verification,
        actualOutput: String,
        passed: Bool
    ) {
        verification.actualOutput = actualOutput
        verification.passed = passed
        verification.timestamp = Date()
    }

    // MARK: - MCP Context Integration

    /// Update context from MCP server
    func updateMCPContext(_ context: MCPContext) {
        self.mcpContext = context
        print("🔄 MCP context updated: \(context.buildLogs.count) build logs, \(context.testResults.count) test results")
    }

    /// Get relevant context for current task
    func getContextForTask(_ taskId: UUID) -> String {
        guard let task = tasks.first(where: { $0.id == taskId }),
              let context = mcpContext else {
            return "No context available"
        }

        var contextString = """
        ## Task Context

        **Task:** \(task.title)
        **Complexity:** \(task.complexity)
        **Dependencies:** \(task.dependencies.count)

        ### Recent Build Logs
        \(context.buildLogs.suffix(5).joined(separator: "\n"))

        ### Error Traces
        \(context.errorTraces.suffix(3).joined(separator: "\n"))

        ### Test Results
        """

        for result in context.testResults.suffix(10) {
            contextString += "\n- \(result.name): \(result.passed ? "✅" : "❌")"
        }

        return contextString
    }

    // MARK: - Analytics

    /// Get verification success rate
    func getVerificationSuccessRate() -> Double {
        guard !verificationResults.isEmpty else { return 1.0 }

        let passed = verificationResults.filter { $0.passed }.count
        return Double(passed) / Double(verificationResults.count)
    }

    /// Get average steps per task
    func getAverageStepsPerTask() -> Double {
        let completedTasks = tasks.filter { $0.status == .verified }
        guard !completedTasks.isEmpty else { return 0 }

        let totalSteps = completedTasks.reduce(0) { $0 + $1.actualSteps }
        return Double(totalSteps) / Double(completedTasks.count)
    }

    /// Get complexity analysis
    func getComplexityAnalysis() -> ComplexityAnalysis {
        ComplexityAnalysis(
            totalTasks: tasks.count,
            completedTasks: tasks.filter { $0.status == .verified }.count,
            failedTasks: tasks.filter { $0.status == .failed }.count,
            averageComplexity: tasks.isEmpty ? 0 : Double(tasks.reduce(0) { $0 + $1.complexity }) / Double(tasks.count),
            maxComplexityUsed: tasks.map { $0.complexity }.max() ?? 0,
            verificationSuccessRate: getVerificationSuccessRate(),
            averageStepsPerTask: getAverageStepsPerTask()
        )
    }

    struct ComplexityAnalysis {
        let totalTasks: Int
        let completedTasks: Int
        let failedTasks: Int
        let averageComplexity: Double
        let maxComplexityUsed: Int
        let verificationSuccessRate: Double
        let averageStepsPerTask: Double
    }

    // MARK: - Errors

    enum TaskmasterError: Error, LocalizedError {
        case noActiveProject
        case taskNotFound
        case subtaskNotFound
        case taskNotReady
        case verificationFailed(String)
        case complexityTooHigh(Int)

        var errorDescription: String? {
            switch self {
            case .noActiveProject:
                return "No active project. Create a project first."
            case .taskNotFound:
                return "Task not found"
            case .subtaskNotFound:
                return "Subtask not found"
            case .taskNotReady:
                return "Task is not ready. Dependencies may not be met."
            case .verificationFailed(let reason):
                return "Verification failed: \(reason)"
            case .complexityTooHigh(let complexity):
                return "Complexity \(complexity) exceeds maximum \(5). Break down further."
            }
        }
    }
}

// MARK: - Taskmaster CLI Commands

extension TaskmasterEngine {

    /// Parse a PRD document and generate specifications
    func parsePRD(_ prdContent: String) throws -> [Specification] {
        // Parse PRD into specifications
        // This would integrate with Claude for intelligent parsing

        var specs: [Specification] = []

        // Extract features/requirements from PRD
        let lines = prdContent.components(separatedBy: "\n")
        var currentTitle = ""
        var currentRequirements: [String] = []

        for line in lines {
            if line.hasPrefix("## ") {
                // Save previous spec if exists
                if !currentTitle.isEmpty && !currentRequirements.isEmpty {
                    let spec = Specification(
                        id: UUID(),
                        title: currentTitle,
                        description: "",
                        requirements: currentRequirements.map { req in
                            Requirement(id: UUID(), description: req, type: .functional, verified: false)
                        },
                        acceptance: [],
                        priority: .medium,
                        complexity: min(10, currentRequirements.count * 2)
                    )
                    specs.append(spec)
                }

                currentTitle = String(line.dropFirst(3))
                currentRequirements = []
            } else if line.hasPrefix("- ") {
                currentRequirements.append(String(line.dropFirst(2)))
            }
        }

        // Don't forget last spec
        if !currentTitle.isEmpty && !currentRequirements.isEmpty {
            let spec = Specification(
                id: UUID(),
                title: currentTitle,
                description: "",
                requirements: currentRequirements.map { req in
                    Requirement(id: UUID(), description: req, type: .functional, verified: false)
                },
                acceptance: [],
                priority: .medium,
                complexity: min(10, currentRequirements.count * 2)
            )
            specs.append(spec)
        }

        print("📄 Parsed PRD: \(specs.count) specifications extracted")
        return specs
    }

    /// Export current state as JSON
    func exportState() throws -> Data {
        let state = TaskmasterState(
            project: currentProject,
            tasks: tasks,
            phase: currentPhase.rawValue,
            verificationResults: verificationResults.map { result in
                TaskmasterState.VerificationResultDTO(
                    id: result.id,
                    taskId: result.taskId,
                    step: result.step,
                    type: result.verificationType.rawValue,
                    passed: result.passed,
                    details: result.details,
                    timestamp: result.timestamp
                )
            }
        )

        return try JSONEncoder().encode(state)
    }

    struct TaskmasterState: Codable {
        let project: Project?
        let tasks: [DevelopmentTask]
        let phase: String
        let verificationResults: [VerificationResultDTO]

        struct VerificationResultDTO: Codable {
            let id: UUID
            let taskId: UUID
            let step: Int
            let type: String
            let passed: Bool
            let details: String
            let timestamp: Date
        }
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

struct TaskmasterDashboardView: View {
    @State private var engine = TaskmasterEngine()
    @State private var selectedTask: TaskmasterEngine.DevelopmentTask?

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Taskmaster")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    Text(engine.currentPhase.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(.cyan)
                }

                Spacer()

                // Stats
                VStack(alignment: .trailing) {
                    Text("\(engine.tasks.filter { $0.status == .verified }.count)/\(engine.tasks.count)")
                        .font(.title2.monospacedDigit())
                        .foregroundStyle(.green)

                    Text("Tasks Verified")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .padding()
            .liquidGlass(.regular, cornerRadius: 20)

            // Verification Rate
            if !engine.verificationResults.isEmpty {
                LiquidGlassProgress(
                    progress: engine.getVerificationSuccessRate(),
                    label: "Verification Success Rate",
                    tint: engine.getVerificationSuccessRate() > 0.8 ? .green : .orange
                )
            }

            // Task List
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(engine.tasks) { task in
                        TaskRowView(task: task, isSelected: selectedTask?.id == task.id)
                            .onTapGesture {
                                selectedTask = task
                            }
                    }
                }
            }

            // Next Task Button
            if let nextTask = engine.getNextTask() {
                Button {
                    try? engine.startTask(nextTask.id)
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start: \(nextTask.title)")
                    }
                }
                .buttonStyle(.liquidGlass(tint: .green))
            }
        }
        .padding()
    }
}

struct TaskRowView: View {
    let task: TaskmasterEngine.DevelopmentTask
    let isSelected: Bool

    var statusColor: Color {
        switch task.status {
        case .pending: return .gray
        case .ready: return .blue
        case .inProgress: return .orange
        case .awaitingVerification: return .yellow
        case .verified: return .green
        case .failed: return .red
        case .blocked: return .purple
        }
    }

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)

                Text("Complexity: \(task.complexity) | Steps: \(task.actualSteps)/\(task.estimatedSteps)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Text(task.status.rawValue)
                .font(.caption)
                .foregroundStyle(statusColor)
        }
        .padding()
        .liquidGlass(
            isSelected ? .tinted : .regular,
            tint: isSelected ? statusColor.opacity(0.3) : nil,
            cornerRadius: 12
        )
    }
}

#Preview("Taskmaster Dashboard") {
    ZStack {
        AnimatedGlassBackground()
        TaskmasterDashboardView()
    }
    .preferredColorScheme(.dark)
}
