import EchoelCore
import SwiftUI


/// The note editor for an instrument track's clip.
struct ClipEditorView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(RecordController.self) private var recording
    @Environment(\.dismiss) private var dismiss
    let trackID: TrackID
    /// The clip to edit; nil edits the track's first clip.
    var clipID: ClipID?
    @State private var grid: NoteEditing.Grid = .sixteenth
    @State private var page: Page = .notes

    enum Page: Hashable { case notes, sound }

    private static let newClipBars: Tick = 4

    private func editedClip(_ track: Track) -> Clip? {
        if let clipID, let index = track.clipIndex(clipID) { return track.clips[index] }
        return track.clips.first
    }

    var body: some View {
        let track = store.project.track(trackID)
        NavigationStack {
            Group {
                if let track, page == .sound {
                    SoundPanel(track: track)
                } else if let track, let clip = editedClip(track), track.instrument.device == .drums {
                    StepGridView(clip: clip, color: Theme.Color.track(track.colorIndex), step: grid.rawValue)
                } else if let track, let clip = editedClip(track) {
                    PianoRoll(clip: clip, color: Theme.Color.track(track.colorIndex), grid: grid.rawValue)
                } else if let track {
                    emptyState(track)
                } else {
                    Text("This track was deleted.")
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Color.background)
            .navigationTitle(track?.name ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if engine.isPlaying {
                            // A running take ends with the song, as at the transport's Stop.
                            Task { await recording.stopTransport() }
                        } else {
                            engine.play()
                        }
                    } label: {
                        Image(systemName: engine.isPlaying ? "stop.fill" : "play.fill")
                    }
                    .accessibilityLabel(engine.isPlaying ? "Stop" : "Play")
                    .disabled(!engine.isRunning)
                }
                ToolbarItem(placement: .principal) {
                    Picker("Page", selection: $page) {
                        Text(track?.instrument.device == .drums ? "Steps" : "Notes").tag(Page.notes)
                        Text("Sound").tag(Page.sound)
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if page == .notes {
                        Picker("Grid", selection: $grid) {
                            ForEach(NoteEditing.Grid.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .accessibilityLabel("Grid")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func emptyState(_ track: Track) -> some View {
        VStack(spacing: Theme.Space.m) {
            Text("No clip on this track yet.")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textSecondary)
            Button {
                newClip(on: track)
            } label: {
                Label("New \(Self.newClipBars)-Bar Clip", systemImage: "plus")
                    .padding(.horizontal, Theme.Space.m)
            }
            .buttonStyle(ToolButtonStyle(isActive: true))
        }
    }

    private func newClip(on track: Track) {
        let clip = ClipID()
        let length = Self.newClipBars * MusicalTime.ticksPerBar(store.project.timeSignature)
        try? store.perform([
            .createClip(track: track.id, id: clip, name: Names.derived(track.name, suffix: "Clip"), length: length),
            .placeClip(track: track.id, id: PlacementID(), clip: clip, start: 0),
        ], title: "New Clip")
    }
}

/// Keys on the left, the note grid on the right. Tap empty space to add a note, tap a note
/// to remove it, drag a note to move it, drag its right edge to change its length. Drags on
/// empty space scroll. One drag is one undo step.
struct PianoRoll: View {
    @Environment(ProjectStore.self) private var store
    let clip: Clip
    let color: Color
    let grid: Tick

    @ScaledMetric(relativeTo: .caption) private var rowHeight: CGFloat = 18
    @ScaledMetric(relativeTo: .caption) private var keyWidth: CGFloat = 52
    /// Points per sixteenth note; the horizontal zoom.
    private let pointsPerSixteenth: CGFloat = 28

    private var pointsPerTick: CGFloat { pointsPerSixteenth / 240 }
    private var gridWidth: CGFloat { CGFloat(clip.length) * pointsPerTick }
    private var gridHeight: CGFloat { CGFloat(Note.pitchRange.count) * rowHeight }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 0) {
                    keys
                    ScrollView(.horizontal) {
                        noteGrid
                    }
                }
            }
            .onAppear { proxy.scrollTo(72, anchor: .top) }   // C5 near the top: the middle octaves in view
        }
    }

    private var keys: some View {
        VStack(spacing: 0) {
            ForEach(Note.pitchRange.reversed(), id: \.self) { pitch in
                let black = NoteEditing.isBlackKey(pitch)
                Text(pitch % 12 == 0 ? NoteEditing.name(of: pitch) : "")
                    .font(Theme.Font.caption)
                    .foregroundStyle(black ? Theme.Color.textSecondary : Theme.Color.background)
                    .frame(width: keyWidth, height: rowHeight, alignment: .trailing)
                    .padding(.trailing, Theme.Space.xs)
                    .background(black ? Theme.Color.surface : Theme.Color.textSecondary)
                    .overlay(alignment: .bottom) { Rectangle().fill(Theme.Color.background).frame(height: 1) }
                    .id(pitch)
                    .accessibilityHidden(true)
            }
        }
    }

    private var noteGrid: some View {
        ZStack(alignment: .topLeading) {
            Canvas { context, size in drawGrid(in: &context, size: size) }
                .frame(width: gridWidth, height: gridHeight)
                .contentShape(Rectangle())
                .onTapGesture { location in tap(at: location) }
                .accessibilityLabel("Note grid")
                .accessibilityHint("Each note below can be moved, resized or deleted from its actions.")

            ForEach(clip.notes) { note in
                NoteBlock(note: note, clip: clip, color: color, grid: grid,
                          pointsPerTick: pointsPerTick, rowHeight: rowHeight)
            }
        }
        .frame(width: gridWidth, height: gridHeight, alignment: .topLeading)
        .coordinateSpace(.named(NoteBlock.gridSpace))
    }

    private func tap(at location: CGPoint) {
        let pitch = Note.pitchRange.upperBound - Int(location.y / rowHeight)
        let tick = Tick(location.x / pointsPerTick)
        guard let command = NoteEditing.tap(in: clip, pitch: pitch, tick: tick, grid: grid) else { return }
        try? store.perform(command)
    }

    private func drawGrid(in context: inout GraphicsContext, size: CGSize) {
        for pitch in Note.pitchRange where NoteEditing.isBlackKey(pitch) {
            let y = CGFloat(Note.pitchRange.upperBound - pitch) * rowHeight
            context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: rowHeight)), with: .color(Theme.Color.surface))
        }
        for pitch in Note.pitchRange where pitch % 12 == 0 {
            let y = CGFloat(Note.pitchRange.upperBound - pitch + 1) * rowHeight
            context.fill(Path(CGRect(x: 0, y: y - 1, width: size.width, height: 1)), with: .color(Theme.Color.border))
        }
        let bar = MusicalTime.ticksPerBar(store.project.timeSignature)
        let beat = MusicalTime.ticksPerBeat(store.project.timeSignature)
        var tick: Tick = 0
        let step = Swift.max(grid, 1)
        while tick <= clip.length {
            let x = CGFloat(tick) * pointsPerTick
            let color = tick % bar == 0 ? Theme.Color.textTertiary : (tick % beat == 0 ? Theme.Color.border : Theme.Color.surfaceRaised)
            context.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)), with: .color(color))
            tick += step
        }
    }
}

/// One note: a block in the track colour, brighter with velocity. Tap removes it, dragging
/// moves it, dragging the right edge resizes it. Its VoiceOver actions do the same.
struct NoteBlock: View {
    @Environment(ProjectStore.self) private var store
    let note: Note
    let clip: Clip
    let color: Color
    let grid: Tick
    let pointsPerTick: CGFloat
    let rowHeight: CGFloat

    @State private var origin: Note?

    private static let edgeWidth: CGFloat = 14
    private static let minimumWidth: CGFloat = 6
    static let gridSpace = "pianoRoll.grid"

    var body: some View {
        let width = Swift.max(CGFloat(note.length) * pointsPerTick, Self.minimumWidth)
        RoundedRectangle(cornerRadius: Theme.Radius.small)
            .fill(color.opacity(0.45 + 0.55 * Double(note.velocity) / 127))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .stroke(Theme.Color.background.opacity(0.6), lineWidth: 1)
            )
            .overlay(alignment: .trailing) {
                // The resize handle, visible so the edge is findable.
                Rectangle()
                    .fill(Theme.Color.background.opacity(0.35))
                    .frame(width: 2)
                    .padding(.vertical, Theme.Space.xxs)
                    .padding(.trailing, Theme.Space.xxs)
                    .accessibilityHidden(true)
            }
            .frame(width: width, height: rowHeight - 1)
            .contentShape(Rectangle())
            .onTapGesture { perform(.removeNotes(clip.id, [note.id])) }
            .highPriorityGesture(drag)
            .offset(x: CGFloat(note.start) * pointsPerTick,
                    y: CGFloat(Note.pitchRange.upperBound - note.pitch) * rowHeight)
            .accessibilityElement()
            .accessibilityLabel("\(NoteEditing.name(of: note.pitch)) note")
            .accessibilityValue("starts at tick \(note.start), \(note.length) ticks long, velocity \(note.velocity)")
            .accessibilityAction(named: "Delete") { perform(.removeNotes(clip.id, [note.id])) }
            .accessibilityAction(named: "Up a Semitone") { nudge(semitones: 1) }
            .accessibilityAction(named: "Down a Semitone") { nudge(semitones: -1) }
            .accessibilityAction(named: "Later by One Step") { nudge(ticks: grid) }
            .accessibilityAction(named: "Earlier by One Step") { nudge(ticks: -grid) }
    }

    private var key: String { "note.drag.\(note.id.description)" }

    /// One gesture for both edits, decided by where it starts on the note as the drag found it:
    /// the right edge resizes, the body moves. Measured in the grid's coordinate space, which
    /// does not move with the note, so the translation stays stable while the block follows the
    /// finger.
    private var drag: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(Self.gridSpace))
            .onChanged { value in
                let start = origin ?? note
                origin = start
                let resizing = NoteEditing.dragTakesTheEnd(
                    of: start, startX: Double(value.startLocation.x), pointsPerTick: Double(pointsPerTick),
                    edgeWidth: Double(Self.edgeWidth), minimumWidth: Double(Self.minimumWidth))
                let edited: Note
                if resizing {
                    let end = start.start + start.length + Tick(value.translation.width / pointsPerTick)
                    edited = NoteEditing.resized(start, toEnd: end, grid: grid, in: clip)
                } else {
                    edited = NoteEditing.moved(start, byTicks: Tick(value.translation.width / pointsPerTick),
                                               semitones: -Int((value.translation.height / rowHeight).rounded()),
                                               grid: grid, in: clip)
                }
                if edited != note { perform(.updateNotes(clip.id, [edited]), coalescing: true) }
            }
            .onEnded { _ in finishDrag() }
    }

    private func finishDrag() {
        origin = nil
        store.endGesture()
    }

    private func nudge(semitones: Int = 0, ticks: Tick = 0) {
        let moved = NoteEditing.moved(note, byTicks: ticks, semitones: semitones, grid: grid, in: clip)
        if moved != note { perform(.updateNotes(clip.id, [moved])) }
    }

    private func perform(_ command: Command, coalescing: Bool = false) {
        try? store.perform(command, coalescingKey: coalescing ? key : nil)
    }
}
