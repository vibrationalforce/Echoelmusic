import EchoelCore
import SwiftUI

/// Renames the open song. The name goes through `DocumentController.renameSong`, which moves the
/// song's package to match; the button only holds back a name the door would refuse, or the
/// name the song already has.
struct RenameSongView: View {
    @Environment(DocumentController.self) private var documents
    @Environment(ProjectStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            form
                .navigationTitle("Rename Song")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .onAppear {
                    name = store.project.name
                    focused = true
                }
        }
        .preferredColorScheme(.dark)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("Name")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Color.textSecondary)
            TextField("Song name", text: $name)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.text)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(rename)
                .padding(Theme.Space.s)
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Theme.Color.border, lineWidth: 1))
            Text("Its file in the Files app is renamed too.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
            Spacer(minLength: 0)
        }
        .padding(Theme.Space.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.Color.background)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
            Button("Rename", action: rename).disabled(!canRename)
        }
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var canRename: Bool {
        !trimmed.isEmpty && trimmed.count <= Names.maximumLength && trimmed != store.project.name
    }

    private func rename() {
        guard canRename else { return }
        documents.renameSong(to: trimmed)
        dismiss()
    }
}
