import EchoelCore
import SwiftUI

/// The Song page: the open song's name, its groove and its tempo changes. The name goes through
/// `DocumentController.renameSong`, which moves the song's package to match; Done renames only
/// with a name the door would take and that differs from the one the song has. Swing and tempo
/// changes apply as they are set, each one undo step (`SongFrameSection`). The sheet belongs to
/// the song it opened for: another song opening meanwhile (one sent from Files or AirDrop)
/// closes it rather than giving that song this name.
struct RenameSongView: View {
    @Environment(DocumentController.self) private var documents
    @Environment(ProjectStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var song: Int?
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            form
                .navigationTitle("Song Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .onAppear {
                    name = store.project.name
                    song = documents.songsOpened
                }
                .onChange(of: documents.songsOpened) { dismiss() }
                // The red line under the field is not seen with VoiceOver: say it as it appears,
                // at high priority, so the echo of the key or the paste that crossed the limit
                // does not talk over it (review 007 round 1).
                .onChange(of: isTooLong) { _, tooLong in
                    guard tooLong else { return }
                    var limit = AttributedString(caption)
                    limit.accessibilitySpeechAnnouncementPriority = .high
                    AccessibilityNotification.Announcement(limit).post()
                }
        }
        .preferredColorScheme(.dark)
    }

    /// The name, then the song's frame; the page hosts the number pad its fields type on.
    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                Text("Name")
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.Color.textSecondary)
                field
                Text(caption)
                    .font(Theme.Font.caption)
                    .foregroundStyle(isTooLong ? Theme.Color.record : Theme.Color.textSecondary)
                    // The field's hint and the announcement say it; read here too, it came twice.
                    .accessibilityHidden(true)
                SongFrameSection()
                    .padding(.top, Theme.Space.l)
            }
            .padding(Theme.Space.l)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Theme.Color.background)
        .numberPadHost()
    }

    /// The name field, with a clear button: a song is often renamed from scratch.
    private var field: some View {
        HStack(spacing: Theme.Space.xs) {
            TextField("Song name", text: $name)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.text)
                // A made-up title is not a misspelling, and Done would commit the correction.
                .autocorrectionDisabled()
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(rename)
                .accessibilityHint(caption)
            if !name.isEmpty {
                Button { name = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Color.textSecondary)
                        .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear Name")
            }
        }
        .padding(.leading, Theme.Space.s)
        .frame(minHeight: Theme.Size.touch)
        .background(Theme.Color.surfaceRaised, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.medium).stroke(Theme.Color.borderStrong, lineWidth: 1))
    }

    /// Done keeps a new name; the groove and tempo changes are already in the song.
    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Done", action: done)
                .disabled(!canLeave)
                .accessibilityHint(isTooLong ? caption : "")
        }
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var isTooLong: Bool { trimmed.count > Names.maximumLength }

    private var caption: String {
        isTooLong ? "At most \(Names.maximumLength) characters." : "Its file in the Files app is renamed too."
    }

    private var canRename: Bool {
        !trimmed.isEmpty && !isTooLong && trimmed != store.project.name
    }

    /// An unchanged name leaves as it came; an empty or too long one holds Done back.
    private var canLeave: Bool {
        canRename || trimmed == store.project.name
    }

    private func rename() {
        guard canRename, song == documents.songsOpened else { return }
        documents.renameSong(to: trimmed)
        dismiss()
    }

    private func done() {
        if canRename { rename() } else { dismiss() }
    }
}
