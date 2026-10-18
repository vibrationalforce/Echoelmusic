import EchoelCore
import SwiftUI

/// The assistant page: the conversation, what it changed in the song, and one field to ask.
/// Every request is one undo step, so the Undo button here takes the whole request back.
struct AgentView: View {
    @Environment(AgentSession.self) private var agent
    @Environment(ProjectStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                conversation
                Divider().overlay(Theme.Color.border)
                inputRow
            }
            .background(Theme.Color.background)
            .navigationTitle("Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .onAppear {
                agent.refreshAvailability()
                focused = agent.availability == .ready
            }
        }
        .preferredColorScheme(.dark)
    }

    private var conversation: some View {
        ScrollViewReader { reader in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Theme.Space.s) {
                    if case let .unavailable(reason) = agent.availability {
                        Text(reason)
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Color.textSecondary)
                    } else if agent.lines.isEmpty {
                        Text("Tell me what to change, for example: “Add a drum track with a four-on-the-floor kick at 120 BPM.” Everything I do is one undo step.")
                            .font(Theme.Font.body)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                    ForEach(agent.lines) { line in row(line).id(line.id) }
                    if agent.isWorking {
                        ProgressView().accessibilityLabel("Working")
                    }
                }
                .padding(Theme.Space.l)
            }
            .onChange(of: agent.lines.count) {
                if let last = agent.lines.last { reader.scrollTo(last.id, anchor: .bottom) }
            }
        }
    }

    private func row(_ line: AgentLine) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.s) {
            switch line.role {
            case .musician:
                Spacer(minLength: Theme.Space.xl)
                Text(line.text)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.text)
                    .padding(Theme.Space.m)
                    .background(Theme.Color.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
            case .assistant:
                Text(line.text)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.text)
                Spacer(minLength: Theme.Space.xl)
            case .action:
                Image(systemName: "checkmark").foregroundStyle(Theme.Color.play).accessibilityHidden(true)
                Text(line.text)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                Spacer()
            case .problem:
                Text(line.text)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.record)
                Spacer()
            }
        }
        .textSelection(.enabled)
    }

    private var inputRow: some View {
        HStack(spacing: Theme.Space.s) {
            TextField("Ask the assistant", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .focused($focused)
                .submitLabel(.send)
                .onSubmit(send)
                .padding(Theme.Space.s)
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Theme.Color.border, lineWidth: 1))
            Button(action: send) { Image(systemName: "arrow.up") }
                .buttonStyle(ToolButtonStyle(isActive: true))
                .accessibilityLabel("Send")
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || agent.isWorking || agent.availability != .ready)
        }
        .padding(Theme.Space.m)
        .background(Theme.Color.surface)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Undo") { store.undo() }
                .disabled(store.undoTitle != "Agent" || agent.isWorking)
                .accessibilityLabel("Undo the assistant's last request")
        }
        ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
    }

    private func send() {
        let request = draft
        // Keep the text when it cannot be sent now, rather than dropping it silently.
        guard !request.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !agent.isWorking, agent.availability == .ready else { return }
        draft = ""
        Task { await agent.send(request) }
    }
}
