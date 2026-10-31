import EchoelCore
import SwiftUI

/// What a rename names: a track, a clip or a scene. The song itself has its own page, because
/// its name moves its package (`RenameSongView`).
enum RenameTarget: Hashable {
    case track(TrackID)
    case clip(ClipID)
    case scene(SceneID)
}

/// Renames a track, a clip or a scene through its command — one undo step. The button holds back
/// a name the door would refuse, or the one the object already has; an object that went away
/// while the sheet was open (undo, the assistant, another song) closes it.
struct RenameView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let target: RenameTarget
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            form
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .onAppear {
                    name = current ?? ""
                    focused = true
                }
                .onChange(of: current == nil) { _, gone in if gone { dismiss() } }
        }
        .preferredColorScheme(.dark)
    }

    /// The object's name now; nil once it is gone.
    private var current: String? {
        let project = store.project
        switch target {
        case .track(let id): return project.track(id)?.name
        case .clip(let id): return project.clip(id)?.name
        case .scene(let id): return project.scenes.first { $0.id == id }?.name
        }
    }

    private var title: String {
        switch target {
        case .track: "Rename Track"
        case .clip: "Rename Clip"
        case .scene: "Rename Scene"
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            Text("Name")
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Color.textSecondary)
            TextField("Name", text: $name)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.text)
                .autocorrectionDisabled()
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(rename)
                .padding(.horizontal, Theme.Space.s)
                .frame(minHeight: Theme.Size.touch)
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Theme.Color.border, lineWidth: 1))
                .accessibilityHint(isTooLong ? caption : "")
            if isTooLong {
                Text(caption)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.record)
            }
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

    private var isTooLong: Bool { trimmed.count > Names.maximumLength }

    private var caption: String { "At most \(Names.maximumLength) characters." }

    private var canRename: Bool {
        !trimmed.isEmpty && !isTooLong && current != nil && trimmed != current
    }

    private func rename() {
        guard canRename else { return }
        let command: Command
        switch target {
        case .track(let id): command = .renameTrack(id, name: trimmed)
        case .clip(let id): command = .renameClip(id, name: trimmed)
        case .scene(let id): command = .renameScene(id, name: trimmed)
        }
        try? store.perform(command)
        dismiss()
    }
}
