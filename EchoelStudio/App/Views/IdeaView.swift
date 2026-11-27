import EchoelCore
import SwiftUI

/// "Idea…" from the Song menu (TH-7, first part): a chord sketch for the song's key, proposed and
/// never written by itself. The page shows the idea's chord names; Another gives the next one; Add
/// to Track puts it on the chosen track as a new clip after its last one, one undo step. No model
/// runs here (`IdeaEngine`), which is why the page says Idea and never AI.
struct IdeaView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            IdeaPage()
                .navigationTitle("Idea")
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

/// The page. Reads the song where an edit changes it — its key, meter and tracks — never the clock
/// (Law 6).
private struct IdeaPage: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(DocumentController.self) private var documents
    /// Which idea is shown; Another counts it up.
    @State private var seed: UInt64 = 0
    @State private var bars = 4
    @State private var bass = true
    /// The track the idea goes to; nil follows the track the keys play.
    @State private var picked: TrackID?
    /// Whether the idea shown was added, for the line under the button.
    @State private var added = false

    private static let barChoices = [2, 4, 8]

    var body: some View {
        let project = store.project
        let playable = project.tracks.filter { (track: Track) -> Bool in
            track.kind == .instrument && PlaySurface.surface(for: track.instrument) == .keys
        }
        let target = playable.first { $0.id == picked } ?? FieldGridView.keysTrack(in: project, engine: engine) ?? playable.first
        let sketch = IdeaEngine.propose(IdeaEngine.Request(context: project.context, meter: project.timeSignature,
                                                           bars: bars, seed: seed, bass: bass))
        List {
            EchoelSection("Idea \(seed &+ 1)", footer: "A proposal in the song's key, one chord a bar. A seed picks among the chords the key holds; no model runs here. The key, the tempo and the sound stay yours.") {
                chords(of: sketch)
            }
            EchoelSection("Shape") {
                Picker("Bars", selection: $bars) {
                    ForEach(Self.barChoices, id: \.self) { (count: Int) in Text("\(count)").tag(count) }
                }
                .pickerStyle(.menu)
                Toggle("Bass Line", isOn: $bass)
                    .frame(minHeight: Theme.Size.touch)
            }
            EchoelSection("Track", footer: "Add to Track writes the idea as a new clip after the track's last one. Listen, and one Undo takes it back.") {
                destination(playable, target: target, sketch: sketch, in: project)
            }
        }
        .echoelList()
        .onChange(of: seed) { added = false }
        .onChange(of: bars) { added = false }
        .onChange(of: bass) { added = false }
    }

    @ViewBuilder private func chords(of sketch: IdeaEngine.Proposal) -> some View {
        if sketch.isEmpty {
            ForEach(sketch.remarks, id: \.self) { (remark: IdeaEngine.Remark) in
                ParagraphText(remark.sentence)
            }
        } else {
            Text(sketch.chords.map(\.name).joined(separator: "  ·  "))
                .font(Theme.Font.valueLarge)
                .foregroundStyle(Theme.Color.text)
                .frame(maxWidth: .infinity, minHeight: Theme.Size.touch, alignment: .leading)
                .accessibilityLabel(sketch.chords.map(\.spokenName).joined(separator: ", "))
            Button("Another", systemImage: "arrow.triangle.2.circlepath") { seed &+= 1 }
                .buttonStyle(EchoelRowButtonStyle())
                .accessibilityHint("Shows the next idea.")
        }
    }

    @ViewBuilder private func destination(_ playable: [Track], target: Track?, sketch: IdeaEngine.Proposal,
                                          in project: Project) -> some View {
        if let target {
            Picker("Add To", selection: Binding(get: { TrackID?.some(target.id) }, set: { picked = $0 })) {
                ForEach(playable, id: \.id) { (track: Track) in
                    Text(track.name).tag(TrackID?.some(track.id))
                }
            }
            .pickerStyle(.menu)
            Button("Add to Track", systemImage: "plus") { add(sketch, to: target, in: project) }
                .buttonStyle(EchoelRowButtonStyle())
                .disabled(sketch.isEmpty)
                .accessibilityHint("Writes the idea to the track as a new clip.")
            if added {
                NoteText("Added to “\(target.name)”.")
            } else if !sketch.isEmpty {
                NoteText("Goes to bar \(Self.bar(for: target, in: project)) of “\(target.name)”.")
            }
        } else {
            ParagraphText("Add an instrument track that is played on keys first: an idea needs a track to go to.")
        }
    }

    private func add(_ sketch: IdeaEngine.Proposal, to target: Track, in project: Project) {
        let commands = sketch.commands(on: target.id, in: project)
        guard !commands.isEmpty else { return }
        if documents.attempt(commands, title: "Idea") {
            added = true
            Theme.Accessibility.announce(Announcement("Idea added to \(target.name)", priority: .normal))
        }
    }

    /// The bar, counted from 1, the idea would start on.
    private static func bar(for target: Track, in project: Project) -> Int {
        let barTicks = MusicalTime.ticksPerBar(project.timeSignature)
        guard barTicks > 0 else { return 1 }
        return Int(IdeaEngine.firstFreeBar(on: target, barTicks: barTicks) / barTicks) + 1
    }
}
