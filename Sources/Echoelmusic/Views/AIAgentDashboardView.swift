import SwiftUI

// MARK: - AI Agent Dashboard View
// Monitor and control AI sub-agents for autonomous music production

public struct AIAgentDashboardView: View {
    @StateObject private var agentSystem = AISubAgentSystem.shared

    @State private var selectedAgent: SubAgent?
    @State private var showWorkflowBuilder = false
    @State private var showTaskQueue = false

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // System Overview
                    systemOverview

                    // Active Agents Grid
                    activeAgentsSection

                    // Task Queue
                    taskQueueSection

                    // Quick Operations
                    quickOperationsSection

                    // Performance Metrics
                    performanceSection
                }
                .padding()
            }
            .navigationTitle("AI Agents")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showWorkflowBuilder = true }) {
                        Image(systemName: "plus.circle")
                    }
                }
            }
            .sheet(isPresented: $showWorkflowBuilder) {
                WorkflowBuilderView()
            }
        }
    }

    // MARK: - System Overview

    private var systemOverview: some View {
        HStack(spacing: 16) {
            MetricCard(
                title: "Active Agents",
                value: "\(agentSystem.activeAgents.count)",
                icon: "cpu",
                color: .blue
            )

            MetricCard(
                title: "Queued Tasks",
                value: "\(agentSystem.taskQueue.count)",
                icon: "list.bullet.clipboard",
                color: .orange
            )

            MetricCard(
                title: "Completed",
                value: "\(agentSystem.completedTasks.count)",
                icon: "checkmark.circle",
                color: .green
            )

            MetricCard(
                title: "System Load",
                value: "\(Int(agentSystem.systemLoad * 100))%",
                icon: "gauge",
                color: agentSystem.systemLoad > 0.8 ? .red : .cyan
            )
        }
    }

    // MARK: - Active Agents

    private var activeAgentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Agent Pool")
                    .font(.headline)

                Spacer()

                Button("View All") {
                    // Show all agents
                }
                .font(.subheadline)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                ForEach(AISubAgentSystem.AgentType.allCases, id: \.rawValue) { type in
                    AgentTypeCard(
                        type: type,
                        isActive: agentSystem.activeAgents.contains { $0.type == type }
                    )
                }
            }
        }
    }

    // MARK: - Task Queue

    private var taskQueueSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Task Queue")
                    .font(.headline)

                Spacer()

                if !agentSystem.taskQueue.isEmpty {
                    Button("Clear All") {
                        // Clear queue
                    }
                    .font(.subheadline)
                    .foregroundStyle(.red)
                }
            }

            if agentSystem.taskQueue.isEmpty {
                EmptyTaskQueue()
            } else {
                ForEach(agentSystem.taskQueue.prefix(5)) { task in
                    TaskQueueItem(task: task)
                }
            }
        }
    }

    // MARK: - Quick Operations

    private var quickOperationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Operations")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                OperationButton(
                    title: "Auto-Compose",
                    subtitle: "Generate new track",
                    icon: "sparkles",
                    color: .purple
                ) {
                    Task {
                        await agentSystem.autoCompose(
                            style: "pop",
                            duration: 180,
                            key: "C",
                            tempo: 120
                        )
                    }
                }

                OperationButton(
                    title: "Auto-Mix",
                    subtitle: "Balance & polish",
                    icon: "slider.horizontal.3",
                    color: .blue
                ) {
                    Task {
                        await agentSystem.autoMix(projectId: "current")
                    }
                }

                OperationButton(
                    title: "Auto-Master",
                    subtitle: "Final polish",
                    icon: "wand.and.stars",
                    color: .green
                ) {
                    Task {
                        _ = await agentSystem.autoMaster(
                            audioURL: URL(fileURLWithPath: "/tmp/mix.wav")
                        )
                    }
                }

                OperationButton(
                    title: "Analyze Track",
                    subtitle: "Deep analysis",
                    icon: "waveform.badge.magnifyingglass",
                    color: .orange
                ) {
                    // Analyze
                }

                OperationButton(
                    title: "Generate Variations",
                    subtitle: "Create alternatives",
                    icon: "arrow.triangle.branch",
                    color: .cyan
                ) {
                    // Generate
                }

                OperationButton(
                    title: "Quality Check",
                    subtitle: "AI review",
                    icon: "checkmark.seal",
                    color: .pink
                ) {
                    // Check
                }
            }
        }
    }

    // MARK: - Performance Section

    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Agent Performance")
                .font(.headline)

            VStack(spacing: 12) {
                ForEach(AISubAgentSystem.AgentType.allCases.prefix(5), id: \.rawValue) { type in
                    AgentPerformanceRow(type: type)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct AgentTypeCard: View {
    let type: AISubAgentSystem.AgentType
    let isActive: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.green : Color(.systemGray5))
                    .frame(width: 50, height: 50)

                Image(systemName: iconForType(type))
                    .font(.title3)
                    .foregroundStyle(isActive ? .white : .secondary)
            }

            Text(type.rawValue)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func iconForType(_ type: AISubAgentSystem.AgentType) -> String {
        switch type {
        case .composer: return "music.note.list"
        case .arranger: return "rectangle.3.group"
        case .mixer: return "slider.horizontal.3"
        case .masteringEngineer: return "wand.and.stars"
        case .soundDesigner: return "waveform.path"
        case .analyzer: return "magnifyingglass"
        case .generator: return "sparkles"
        case .performer: return "figure.dance"
        case .critic: return "text.badge.checkmark"
        case .researcher: return "books.vertical"
        }
    }
}

struct TaskQueueItem: View {
    let task: AgentTask

    var body: some View {
        HStack {
            Image(systemName: "circle.fill")
                .font(.caption)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.type.rawValue.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Priority: \(task.priority)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("~\(Int(task.estimatedDuration))s")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct EmptyTaskQueue: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.largeTitle)
                .foregroundStyle(.green)

            Text("No tasks in queue")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct OperationButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct AgentPerformanceRow: View {
    let type: AISubAgentSystem.AgentType

    var body: some View {
        HStack {
            Text(type.rawValue)
                .font(.subheadline)

            Spacer()

            // Success rate
            HStack(spacing: 4) {
                Text("98%")
                    .font(.caption)
                    .foregroundStyle(.green)
                Text("success")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Avg time
            HStack(spacing: 4) {
                Text("1.2s")
                    .font(.caption)
                Text("avg")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Tasks
            HStack(spacing: 4) {
                Text("45")
                    .font(.caption)
                Text("tasks")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct WorkflowBuilderView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var workflowName = ""
    @State private var selectedStages: [WorkflowStageConfig] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Workflow Info") {
                    TextField("Workflow Name", text: $workflowName)
                }

                Section("Stages") {
                    ForEach(selectedStages.indices, id: \.self) { index in
                        WorkflowStageRow(stage: $selectedStages[index])
                    }

                    Button("Add Stage") {
                        selectedStages.append(WorkflowStageConfig())
                    }
                }

                Section("Options") {
                    Toggle("Stop on Failure", isOn: .constant(true))
                    Toggle("Save as Template", isOn: .constant(false))
                }
            }
            .navigationTitle("New Workflow")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createWorkflow()
                        dismiss()
                    }
                    .disabled(workflowName.isEmpty)
                }
            }
        }
    }

    private func createWorkflow() {
        // Create workflow
    }
}

struct WorkflowStageRow: View {
    @Binding var stage: WorkflowStageConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Task Type", selection: $stage.taskType) {
                ForEach(AgentTask.TaskType.allCases, id: \.rawValue) { type in
                    Text(type.rawValue.capitalized).tag(type)
                }
            }

            Toggle("Parallel Execution", isOn: $stage.parallel)
        }
    }
}

struct WorkflowStageConfig {
    var taskType: AgentTask.TaskType = .analyze
    var parallel: Bool = false
}

extension AgentTask.TaskType: CaseIterable {
    public static var allCases: [AgentTask.TaskType] {
        [.compose, .arrange, .mix, .master, .analyze, .generate, .critique, .research]
    }
}

#Preview {
    AIAgentDashboardView()
}
