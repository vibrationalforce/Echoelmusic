import SwiftUI

// MARK: - Automation Workflow View
// n8n workflow automation management interface

public struct AutomationWorkflowView: View {
    @StateObject private var n8n = N8NWorkflowIntegration.shared

    @State private var showConnectionSheet = false
    @State private var showTemplates = false
    @State private var showWebhookLogs = false

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Connection status
                    connectionStatus

                    // Active workflows
                    if n8n.isConnected {
                        activeWorkflowsSection
                        webhookSection
                        templatesSection
                    }
                }
                .padding()
            }
            .navigationTitle("Automation")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Connect to n8n", action: { showConnectionSheet = true })
                        Button("Browse Templates", action: { showTemplates = true })
                        Button("View Logs", action: { showWebhookLogs = true })
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showConnectionSheet) {
                N8NConnectionView(integration: n8n)
            }
            .sheet(isPresented: $showTemplates) {
                WorkflowTemplatesView(integration: n8n)
            }
            .sheet(isPresented: $showWebhookLogs) {
                WebhookLogsView()
            }
        }
    }

    // MARK: - Connection Status

    private var connectionStatus: some View {
        HStack {
            // Status indicator
            Circle()
                .fill(n8n.isConnected ? Color.green : Color.red)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(n8n.isConnected ? "Connected to n8n" : "Not Connected")
                    .font(.headline)

                if n8n.isConnected {
                    Text("Webhook server running on port 5679")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(n8n.isConnected ? "Disconnect" : "Connect") {
                if n8n.isConnected {
                    n8n.disconnect()
                } else {
                    showConnectionSheet = true
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Active Workflows

    private var activeWorkflowsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Active Workflows")
                    .font(.headline)

                Spacer()

                Button("Refresh") {
                    Task { await n8n.loadWorkflows() }
                }
                .font(.subheadline)
            }

            if n8n.activeWorkflows.isEmpty {
                EmptyWorkflowsView()
            } else {
                ForEach(n8n.activeWorkflows) { workflow in
                    WorkflowRow(workflow: workflow) {
                        Task {
                            _ = try? await n8n.executeWorkflow(workflow.id)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Webhooks

    private var webhookSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Webhooks")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                WebhookCard(
                    name: "Project Created",
                    path: "/echoelmusic/project/created",
                    icon: "doc.badge.plus"
                )

                WebhookCard(
                    name: "Project Exported",
                    path: "/echoelmusic/project/exported",
                    icon: "square.and.arrow.up"
                )

                WebhookCard(
                    name: "Render Complete",
                    path: "/echoelmusic/render/complete",
                    icon: "checkmark.seal"
                )

                WebhookCard(
                    name: "Analysis Complete",
                    path: "/echoelmusic/analysis/complete",
                    icon: "waveform.badge.magnifyingglass"
                )
            }
        }
    }

    // MARK: - Templates

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Quick Templates")
                    .font(.headline)

                Spacer()

                Button("View All") {
                    showTemplates = true
                }
                .font(.subheadline)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(n8n.getWorkflowTemplates(), id: \.name) { template in
                        TemplateCard(template: template)
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct N8NConnectionView: View {
    @ObservedObject var integration: N8NWorkflowIntegration
    @Environment(\.dismiss) private var dismiss

    @State private var serverURL = "http://localhost:5678"
    @State private var apiKey = ""
    @State private var isConnecting = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("n8n Server URL", text: $serverURL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()

                    SecureField("API Key", text: $apiKey)
                } header: {
                    Text("Connection Details")
                } footer: {
                    Text("Enter your n8n instance URL and API key")
                }

                Section("Webhook Server") {
                    LabeledContent("Local Port", value: "5679")
                    Toggle("Enable Webhooks", isOn: .constant(true))
                }

                if let error = error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Connect to n8n")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Connect") {
                        Task { await connect() }
                    }
                    .disabled(serverURL.isEmpty || apiKey.isEmpty || isConnecting)
                }
            }
        }
    }

    private func connect() async {
        isConnecting = true
        error = nil

        do {
            try await integration.connect(url: serverURL, apiKey: apiKey)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isConnecting = false
    }
}

struct WorkflowRow: View {
    let workflow: N8NWorkflow
    let onExecute: () -> Void

    var body: some View {
        HStack {
            // Status
            Circle()
                .fill(workflow.active ? Color.green : Color.gray)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(workflow.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Last updated: \(workflow.updatedAt)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onExecute) {
                Image(systemName: "play.fill")
            }
            .buttonStyle(.bordered)
            .disabled(!workflow.active)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct EmptyWorkflowsView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No workflows found")
                .font(.subheadline)

            Text("Create workflows in n8n to automate Echoelmusic")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct WebhookCard: View {
    let name: String
    let path: String
    let icon: String

    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.accentColor)

                Spacer()

                Button(action: copyPath) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
            }

            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)

            Text(path)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func copyPath() {
        #if os(iOS)
        UIPasteboard.general.string = "http://localhost:5679\(path)"
        #endif
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }
}

struct TemplateCard: View {
    let template: N8NWorkflowTemplate

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: iconForTrigger(template.trigger))
                    .foregroundStyle(.accentColor)

                Spacer()
            }

            Text(template.name)
                .font(.subheadline)
                .fontWeight(.medium)

            Text(template.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                ForEach(template.nodes.prefix(3), id: \.self) { node in
                    Text(node)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }

                if template.nodes.count > 3 {
                    Text("+\(template.nodes.count - 3)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Button("Use Template") {
                // Apply template
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
        .frame(width: 200)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func iconForTrigger(_ trigger: String) -> String {
        switch trigger {
        case "project_created": return "doc.badge.plus"
        case "project_exported": return "square.and.arrow.up"
        case "project_published": return "globe"
        case "collaborator_joined": return "person.badge.plus"
        case "render_complete": return "checkmark.seal"
        case "stems_exported": return "square.stack.3d.up"
        default: return "bolt"
        }
    }
}

struct WorkflowTemplatesView: View {
    @ObservedObject var integration: N8NWorkflowIntegration
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(integration.getWorkflowTemplates(), id: \.name) { template in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(template.name)
                            .font(.headline)

                        Text(template.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("Trigger: \(template.trigger)")
                            .font(.caption)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(template.nodes, id: \.self) { node in
                                    Text(node)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(.systemGray5))
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        Button("Install Template") {
                            // Install
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Workflow Templates")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct WebhookLogsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(0..<10) { i in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("POST")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())

                            Text("/echoelmusic/project/created")
                                .font(.subheadline)

                            Spacer()

                            Text("200")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }

                        Text("2 minutes ago")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Webhook Logs")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AutomationWorkflowView()
}
