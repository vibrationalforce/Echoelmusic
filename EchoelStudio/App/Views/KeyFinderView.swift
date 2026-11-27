import EchoelCore
import SwiftUI

/// "Find Key…" from the Song menu (TH-9's door): which major or minor key the song's notes fit
/// best, as a proposal. It reads the clips of the tracks played on keys — all of them, or one —
/// and names the best fit and the runner-up (`KeyFinder`). Nothing is set until Use for Song, which
/// sets the key's root and scale as one undo step.
struct KeyFinderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            KeyFinderPage()
                .navigationTitle("Find Key")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
                    }
                }
        }
        .preferredColorScheme(.dark)
    }
}

/// The page. Reads the song only: its notes change with an edit, never with the clock (Law 6).
private struct KeyFinderPage: View {
    @Environment(ProjectStore.self) private var store
    @Environment(DocumentController.self) private var documents
    /// The one track whose notes are read; nil reads every track played on keys.
    @State private var only: TrackID?

    var body: some View {
        let project = store.project
        let readable = KeyFinder.tracks(in: project)
        let finding = KeyFinder.find(in: project, track: only)
        List {
            EchoelSection("Notes", footer: "Read from the clips of tracks played on keys, each clip once. Drum kits and sliced samplers are left out: their notes pick a sound, not a pitch.") {
                Picker("From", selection: $only) {
                    Text("Every Track on Keys").tag(TrackID?.none)
                    ForEach(readable, id: \.id) { (track: Track) in
                        Text(track.name).tag(TrackID?.some(track.id))
                    }
                }
                .pickerStyle(.menu)
            }
            EchoelSection("Proposal", footer: "Counted from how long each note sounds, compared with every major and minor key. It sets nothing by itself, and one Undo takes Use for Song back. Other scales stay yours to choose in the Song menu.") {
                if let finding {
                    proposal(finding, song: project.context)
                } else {
                    ParagraphText("No notes on a track played on keys here: nothing to find yet.")
                }
            }
        }
        .echoelList()
    }

    @ViewBuilder private func proposal(_ finding: KeyFinder.Finding, song: MusicalContext) -> some View {
        line("Fits best", finding.best.key.title)
        line("Next", finding.runnerUp.key.title)
        line("The song now", song.title)
        if finding.isWeak {
            NoteText("The notes fit no major or minor key well. The song may be in another scale, or change key.")
        } else if finding.isAmbiguous {
            NoteText("A close call: the two share most of their notes. Listen for where the music comes to rest.")
        }
        Button("Use for Song", systemImage: "checkmark") {
            if documents.attempt(finding.commands, title: "Set Key") {
                Theme.Accessibility.announce(Announcement("Key set to \(finding.best.key.title)", priority: .normal))
            }
        }
        .buttonStyle(EchoelRowButtonStyle())
        .accessibilityHint("Sets the song's key and scale to the best fit.")
    }

    private func line(_ name: String, _ value: String) -> some View {
        HStack(spacing: Theme.Space.m) {
            Text(name)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textSecondary)
            Spacer(minLength: Theme.Space.s)
            Text(value)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.text)
        }
        .frame(minHeight: Theme.Size.touch)
        .accessibilityElement(children: .combine)
    }
}
