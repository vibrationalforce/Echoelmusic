// SPDX-License-Identifier: MIT
// Copyright 2026 Echoelmusic
// Ultra-Modern Creator Workflow Engine
// Inspired by: GSD, Ralph Wiggum Philosophy, Auto-Claude, Claude Code 2.1.3
// Target: Ready before 2032 - Already where others will be in 2040

import Foundation
import SwiftUI
import Combine

// MARK: - Ultra-Modern Creator Workflow
/// Next-generation content creation workflow combining:
/// - GSD (Get Shit Done) 4-stage process
/// - Ralph Wiggum fresh context philosophy
/// - Auto-Claude parallel processing
/// - Claude Code 2.1.3 capability model
@MainActor
public final class UltraModernCreatorWorkflow: ObservableObject {

    public static let shared = UltraModernCreatorWorkflow()

    // MARK: - State

    @Published public var currentPhase: WorkflowPhase = .ideation
    @Published public var project: CreatorProject?
    @Published public var activeTasks: [AtomicTask] = []
    @Published public var completedTasks: [AtomicTask] = []
    @Published public var isExecuting: Bool = false

    // Parallel processing (Auto-Claude inspired)
    @Published public var parallelAgents: [AgentInstance] = []
    public let maxParallelAgents: Int = 12

    // Memory persistence (Claude-Mem inspired)
    @Published public var sessionMemory: SessionMemory = SessionMemory()

    // MARK: - GSD 4-Stage Workflow

    public enum WorkflowPhase: Int, CaseIterable, Identifiable {
        case ideation = 0      // /gsd:new-project - Extract complete vision
        case planning = 1      // /gsd:create-roadmap - Generate phased roadmap
        case execution = 2     // /gsd:execute-plan - Atomic tasks in fresh context
        case iteration = 3     // /gsd:complete-milestone - Ship & adjust

        public var id: Int { rawValue }

        public var name: String {
            switch self {
            case .ideation: return "Ideation"
            case .planning: return "Planning"
            case .execution: return "Execution"
            case .iteration: return "Iteration"
            }
        }

        public var icon: String {
            switch self {
            case .ideation: return "lightbulb.fill"
            case .planning: return "map.fill"
            case .execution: return "hammer.fill"
            case .iteration: return "arrow.triangle.2.circlepath"
            }
        }

        public var color: Color {
            switch self {
            case .ideation: return .yellow
            case .planning: return .blue
            case .execution: return .green
            case .iteration: return .purple
            }
        }

        public var gsdCommand: String {
            switch self {
            case .ideation: return "/gsd:new-project"
            case .planning: return "/gsd:create-roadmap"
            case .execution: return "/gsd:execute-plan"
            case .iteration: return "/gsd:complete-milestone"
            }
        }
    }

    // MARK: - Creator Project (GSD PROJECT.md equivalent)

    public struct CreatorProject: Identifiable, Codable {
        public let id: UUID
        public var name: String
        public var vision: String
        public var createdAt: Date
        public var modifiedAt: Date

        // GSD State Management
        public var stateDocument: StateDocument
        public var roadmap: Roadmap
        public var conventions: ProjectConventions

        // Bio-Reactive Context
        public var bioContext: BioCreationContext

        public init(name: String, vision: String) {
            self.id = UUID()
            self.name = name
            self.vision = vision
            self.createdAt = Date()
            self.modifiedAt = Date()
            self.stateDocument = StateDocument()
            self.roadmap = Roadmap()
            self.conventions = ProjectConventions()
            self.bioContext = BioCreationContext()
        }
    }

    // MARK: - State Document (GSD STATE.md equivalent)

    public struct StateDocument: Codable {
        public var decisions: [Decision] = []
        public var blockers: [Blocker] = []
        public var insights: [Insight] = []
        public var currentPosition: String = ""

        public struct Decision: Identifiable, Codable {
            public let id: UUID
            public let madeAt: Date
            public let description: String
            public let rationale: String
        }

        public struct Blocker: Identifiable, Codable {
            public let id: UUID
            public var description: String
            public var status: BlockerStatus
            public var resolution: String?

            public enum BlockerStatus: String, Codable {
                case active = "Active"
                case resolved = "Resolved"
                case deferred = "Deferred"
            }
        }

        public struct Insight: Identifiable, Codable {
            public let id: UUID
            public let discoveredAt: Date
            public let content: String
            public let source: String // "bio-feedback", "user-input", "ai-analysis"
        }
    }

    // MARK: - Roadmap (GSD Phased Approach)

    public struct Roadmap: Codable {
        public var phases: [Phase] = []
        public var currentPhaseIndex: Int = 0

        public struct Phase: Identifiable, Codable {
            public let id: UUID
            public var name: String
            public var description: String
            public var tasks: [AtomicTask]
            public var status: PhaseStatus
            public var order: Int

            public enum PhaseStatus: String, Codable {
                case pending = "Pending"
                case inProgress = "In Progress"
                case completed = "Completed"
                case blocked = "Blocked"
            }
        }
    }

    // MARK: - Atomic Task (GSD XML Task Structure)

    public struct AtomicTask: Identifiable, Codable {
        public let id: UUID
        public var name: String
        public var type: TaskType
        public var files: [String]        // Target files
        public var action: String         // Specific steps
        public var verify: String         // Testable success condition
        public var done: String           // Completion criteria
        public var status: TaskStatus
        public var bioSnapshot: BioSnapshot? // Bio state when created

        // Ralph Philosophy: Fresh context per task
        public var contextId: UUID?       // Isolated context identifier
        public var agentId: UUID?         // Which parallel agent

        public enum TaskType: String, Codable, CaseIterable {
            case auto = "auto"           // AI executes autonomously
            case manual = "manual"       // Requires user action
            case review = "review"       // Needs human review
            case bioSync = "bio-sync"    // Synced to bio-state
        }

        public enum TaskStatus: String, Codable {
            case pending = "Pending"
            case inProgress = "In Progress"
            case verifying = "Verifying"
            case completed = "Completed"
            case failed = "Failed"
            case blocked = "Blocked"
        }
    }

    // MARK: - Bio Snapshot (Echoelmusic Unique)

    public struct BioSnapshot: Codable {
        public let capturedAt: Date
        public let heartRate: Double
        public let hrvCoherence: Double
        public let breathingRate: Double
        public let emotionalState: String
        public let energyLevel: Double
    }

    // MARK: - Bio Creation Context

    public struct BioCreationContext: Codable {
        public var targetCoherence: Double = 0.7
        public var creativeMode: CreativeMode = .balanced
        public var bioSyncEnabled: Bool = true
        public var autoBreakReminders: Bool = true

        public enum CreativeMode: String, Codable, CaseIterable {
            case calm = "Calm Creative"
            case balanced = "Balanced"
            case energetic = "High Energy"
            case flow = "Flow State"
            case meditative = "Meditative"
        }
    }

    // MARK: - Project Conventions (GSD Brownfield Pattern)

    public struct ProjectConventions: Codable {
        public var stack: [String] = []
        public var architecture: String = ""
        public var testingApproach: String = ""
        public var namingConventions: String = ""
        public var bioIntegrationPatterns: String = ""
    }

    // MARK: - Parallel Agent (Auto-Claude Inspired)

    public struct AgentInstance: Identifiable {
        public let id: UUID
        public var name: String
        public var status: AgentStatus
        public var currentTask: AtomicTask?
        public var worktree: String?      // Isolated git worktree
        public var startedAt: Date
        public var completedTasks: Int = 0

        public enum AgentStatus: String {
            case idle = "Idle"
            case working = "Working"
            case verifying = "Verifying"
            case completed = "Completed"
            case error = "Error"
        }
    }

    // MARK: - Session Memory (Claude-Mem Inspired)

    public struct SessionMemory: Codable {
        public var observations: [Observation] = []
        public var insights: [String] = []
        public var learnedPatterns: [String: String] = [:]

        public struct Observation: Identifiable, Codable {
            public let id: UUID
            public let timestamp: Date
            public let type: String       // "tool_use", "bio_event", "user_action"
            public let summary: String
            public let details: String?
        }

        /// Progressive disclosure: compact summaries first
        public func compactSummary(maxTokens: Int = 100) -> String {
            observations.suffix(10).map { $0.summary }.joined(separator: "; ")
        }
    }

    // MARK: - Phase 1: Ideation

    public func startIdeation(name: String, initialVision: String) {
        project = CreatorProject(name: name, vision: initialVision)
        currentPhase = .ideation

        // Capture bio-state at project inception
        let bioSnapshot = captureBioSnapshot()
        sessionMemory.observations.append(
            SessionMemory.Observation(
                id: UUID(),
                timestamp: Date(),
                type: "project_start",
                summary: "Project '\(name)' started with coherence \(Int(bioSnapshot.hrvCoherence * 100))%",
                details: initialVision
            )
        )
    }

    // MARK: - Phase 2: Planning

    public func generateRoadmap() async {
        guard var proj = project else { return }

        currentPhase = .planning

        // Generate phases based on project vision
        let phases = await generatePhasesFromVision(proj.vision)
        proj.roadmap.phases = phases
        project = proj
    }

    private func generatePhasesFromVision(_ vision: String) async -> [Roadmap.Phase] {
        // AI-powered phase generation
        // In production: Use LLMService

        return [
            Roadmap.Phase(
                id: UUID(),
                name: "Foundation",
                description: "Setup core structure and bio-integration",
                tasks: [],
                status: .pending,
                order: 0
            ),
            Roadmap.Phase(
                id: UUID(),
                name: "Core Features",
                description: "Implement main functionality",
                tasks: [],
                status: .pending,
                order: 1
            ),
            Roadmap.Phase(
                id: UUID(),
                name: "Polish",
                description: "Refine and optimize",
                tasks: [],
                status: .pending,
                order: 2
            )
        ]
    }

    // MARK: - Phase 3: Execution (Ralph + Auto-Claude)

    /// Execute tasks with fresh context per task (Ralph Philosophy)
    public func executePhase(phaseIndex: Int) async {
        guard var proj = project,
              phaseIndex < proj.roadmap.phases.count else { return }

        currentPhase = .execution
        isExecuting = true
        defer { isExecuting = false }

        var phase = proj.roadmap.phases[phaseIndex]
        phase.status = .inProgress
        proj.roadmap.phases[phaseIndex] = phase

        // Execute tasks with parallel agents (Auto-Claude pattern)
        await executeTasksInParallel(phase.tasks)

        phase.status = .completed
        proj.roadmap.phases[phaseIndex] = phase
        project = proj
    }

    /// Parallel task execution with isolated contexts
    private func executeTasksInParallel(_ tasks: [AtomicTask]) async {
        // Create agent pool
        let agentCount = min(tasks.count, maxParallelAgents)

        for i in 0..<agentCount {
            let agent = AgentInstance(
                id: UUID(),
                name: "Agent-\(i + 1)",
                status: .idle,
                currentTask: nil,
                worktree: "worktree-\(i)",
                startedAt: Date()
            )
            parallelAgents.append(agent)
        }

        // Distribute tasks across agents
        await withTaskGroup(of: Void.self) { group in
            for (index, task) in tasks.enumerated() {
                let agentIndex = index % agentCount

                group.addTask {
                    await self.executeTaskWithFreshContext(task, agentIndex: agentIndex)
                }
            }
        }

        // Clean up agents
        parallelAgents.removeAll()
    }

    /// Execute single task with fresh context (Ralph Wiggum Philosophy)
    private func executeTaskWithFreshContext(_ task: AtomicTask, agentIndex: Int) async {
        var mutableTask = task
        mutableTask.contextId = UUID() // Fresh context ID
        mutableTask.agentId = parallelAgents[agentIndex].id
        mutableTask.status = .inProgress

        // Update agent status
        parallelAgents[agentIndex].status = .working
        parallelAgents[agentIndex].currentTask = mutableTask

        // Execute in isolated context
        // In production: Actual task execution

        // Simulate execution
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Verify task completion
        mutableTask.status = .verifying
        parallelAgents[agentIndex].status = .verifying

        // Verification passed
        mutableTask.status = .completed
        completedTasks.append(mutableTask)

        // Record observation (Claude-Mem pattern)
        sessionMemory.observations.append(
            SessionMemory.Observation(
                id: UUID(),
                timestamp: Date(),
                type: "task_complete",
                summary: "Completed: \(task.name)",
                details: task.verify
            )
        )

        parallelAgents[agentIndex].status = .completed
        parallelAgents[agentIndex].completedTasks += 1
    }

    // MARK: - Phase 4: Iteration

    public func completeIteration() {
        currentPhase = .iteration

        // Generate summary
        let summary = generateIterationSummary()

        // Record in state document
        project?.stateDocument.insights.append(
            StateDocument.Insight(
                id: UUID(),
                discoveredAt: Date(),
                content: summary,
                source: "iteration-complete"
            )
        )
    }

    private func generateIterationSummary() -> String {
        let completed = completedTasks.count
        let avgCoherence = completedTasks.compactMap { $0.bioSnapshot?.hrvCoherence }.reduce(0, +) / Double(max(completed, 1))

        return """
        Iteration Summary:
        - Tasks completed: \(completed)
        - Average coherence: \(Int(avgCoherence * 100))%
        - Insights discovered: \(sessionMemory.insights.count)
        """
    }

    // MARK: - Bio Integration

    private func captureBioSnapshot() -> BioSnapshot {
        // In production: Get from HealthKitManager
        BioSnapshot(
            capturedAt: Date(),
            heartRate: 72,
            hrvCoherence: 0.75,
            breathingRate: 12,
            emotionalState: "focused",
            energyLevel: 0.7
        )
    }

    // MARK: - Task Creation Helper

    public func createTask(
        name: String,
        type: AtomicTask.TaskType = .auto,
        files: [String] = [],
        action: String,
        verify: String,
        done: String
    ) -> AtomicTask {
        AtomicTask(
            id: UUID(),
            name: name,
            type: type,
            files: files,
            action: action,
            verify: verify,
            done: done,
            status: .pending,
            bioSnapshot: captureBioSnapshot()
        )
    }
}

// MARK: - Workflow View

public struct UltraModernCreatorWorkflowView: View {
    @ObservedObject private var workflow = UltraModernCreatorWorkflow.shared

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Phase Progress Bar
                phaseProgressBar

                // Main Content
                ScrollView {
                    VStack(spacing: 20) {
                        // Current Phase Card
                        currentPhaseCard

                        // Active Agents (if executing)
                        if workflow.isExecuting {
                            agentsSection
                        }

                        // Tasks
                        tasksSection

                        // Memory Insights
                        memorySection
                    }
                    .padding()
                }
            }
            .navigationTitle("Creator Workflow")
        }
    }

    private var phaseProgressBar: some View {
        HStack(spacing: 0) {
            ForEach(UltraModernCreatorWorkflow.WorkflowPhase.allCases) { phase in
                phaseIndicator(phase)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    private func phaseIndicator(_ phase: UltraModernCreatorWorkflow.WorkflowPhase) -> some View {
        let isActive = workflow.currentPhase == phase
        let isPast = workflow.currentPhase.rawValue > phase.rawValue

        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isPast ? phase.color : (isActive ? phase.color.opacity(0.3) : Color.gray.opacity(0.2)))
                    .frame(width: 32, height: 32)

                Image(systemName: phase.icon)
                    .font(.caption)
                    .foregroundStyle(isPast || isActive ? .white : .secondary)
            }

            Text(phase.name)
                .font(.caption2)
                .foregroundStyle(isActive ? phase.color : .secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var currentPhaseCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: workflow.currentPhase.icon)
                        .font(.title2)
                        .foregroundStyle(workflow.currentPhase.color)

                    VStack(alignment: .leading) {
                        Text(workflow.currentPhase.name)
                            .font(.headline)
                        Text(workflow.currentPhase.gsdCommand)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if workflow.isExecuting {
                        ProgressView()
                    }
                }

                Divider()

                if let project = workflow.project {
                    Text(project.vision)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } label: {
            Label("Current Phase", systemImage: "play.circle.fill")
        }
    }

    private var agentsSection: some View {
        GroupBox {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                ForEach(workflow.parallelAgents) { agent in
                    agentCard(agent)
                }
            }
        } label: {
            Label("Parallel Agents (\(workflow.parallelAgents.count)/\(workflow.maxParallelAgents))", systemImage: "person.3.fill")
        }
    }

    private func agentCard(_ agent: UltraModernCreatorWorkflow.AgentInstance) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(agentStatusColor(agent.status))
                .frame(width: 40, height: 40)
                .overlay(
                    Text("\(agent.completedTasks)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                )

            Text(agent.name)
                .font(.caption2)

            Text(agent.status.rawValue)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }

    private func agentStatusColor(_ status: UltraModernCreatorWorkflow.AgentInstance.AgentStatus) -> Color {
        switch status {
        case .idle: return .gray
        case .working: return .blue
        case .verifying: return .orange
        case .completed: return .green
        case .error: return .red
        }
    }

    private var tasksSection: some View {
        GroupBox {
            if workflow.completedTasks.isEmpty && workflow.activeTasks.isEmpty {
                Text("No tasks yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(workflow.activeTasks) { task in
                        taskRow(task, isActive: true)
                    }
                    ForEach(workflow.completedTasks.suffix(5)) { task in
                        taskRow(task, isActive: false)
                    }
                }
            }
        } label: {
            Label("Tasks (\(workflow.completedTasks.count) completed)", systemImage: "checklist")
        }
    }

    private func taskRow(_ task: UltraModernCreatorWorkflow.AtomicTask, isActive: Bool) -> some View {
        HStack {
            Image(systemName: isActive ? "circle" : "checkmark.circle.fill")
                .foregroundStyle(isActive ? .blue : .green)

            VStack(alignment: .leading) {
                Text(task.name)
                    .font(.subheadline)
                Text(task.verify)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let bio = task.bioSnapshot {
                Text("\(Int(bio.hrvCoherence * 100))%")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding(8)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }

    private var memorySection: some View {
        GroupBox {
            if workflow.sessionMemory.observations.isEmpty {
                Text("No observations yet")
                    .foregroundStyle(.secondary)
            } else {
                Text(workflow.sessionMemory.compactSummary())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } label: {
            Label("Session Memory", systemImage: "brain.head.profile")
        }
    }
}

#Preview {
    UltraModernCreatorWorkflowView()
}
