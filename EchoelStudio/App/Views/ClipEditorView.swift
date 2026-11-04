import EchoelCore
import SwiftUI


/// The note editor for an instrument track's clip.
struct ClipEditorView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(RecordController.self) private var recording
    @Environment(JamSession.self) private var jam: JamSession?
    @Environment(\.dismiss) private var dismiss
    let trackID: TrackID
    /// The clip to edit; nil edits the track's first clip.
    var clipID: ClipID?
    /// The one magnet, shared with the arrangement and kept on this device (`SnapGrid`).
    @AppStorage(SnapGrid.storageKey) private var snap: SnapGrid = .standard
    @State private var page: Page = .notes
    /// The piano roll's zoom, kept on this device, never in the song: at the base a note is
    /// 17 pt high, under a fingertip (accessibility audit 2026-11-01, M5).
    @AppStorage(PianoRoll.zoomKey) private var zoom = PianoRoll.zoomLevels[0]

    enum Page: Hashable { case notes, sound }

    private static let newClipBars: Tick = 4

    /// The stored zoom as one of the levels, so a value no level has (written by another version,
    /// or not a number) still lands on one.
    private var zoomIndex: Int {
        let levels = PianoRoll.zoomLevels
        return levels.indices.min { abs(levels[$0] - zoom) < abs(levels[$1] - zoom) } ?? 0
    }

    /// The magnet's step in this clip's own meter; 0 with it off.
    private func grid(for clip: Clip) -> Tick {
        snap.editorStep(meter: store.project.clipMeter(clip.id))
    }

    /// The step grid's cell: the magnet's step from a thirty-second triplet up to a quarter, else
    /// a sixteenth — a drum row needs cells, and 128 to a bar would not fit a finger.
    private func drumStep(for clip: Clip) -> Tick {
        let step = grid(for: clip)
        return (80...MusicalTime.ticksPerQuarter).contains(step) ? step : NoteEditing.freeNoteLength
    }

    private func editedClip(_ track: Track) -> Clip? {
        if let clipID, let index = track.clipIndex(clipID) { return track.clips[index] }
        return track.clips.first
    }

    /// Whether the page shows the piano roll, the one view the zoom is for.
    private func showsPianoRoll(_ track: Track?) -> Bool {
        guard page == .notes, let track, track.instrument.device != .drums else { return false }
        return editedClip(track) != nil
    }

    /// The jam's host pressed Play and waits for the next bar line: Stop calls the start off.
    private var countsIn: Bool { jam?.startIsPending == true }

    /// Play and Stop as at the transport: with phones in a jam this phone hosts, Play waits for
    /// the jam's next bar line, so everyone starts together.
    private func playOrStop() {
        if countsIn {
            jam?.cancelPendingStart()
        } else if engine.isPlaying {
            // A running take ends with the song, as at the transport's Stop.
            Task { await recording.stopTransport() }
        } else if jam?.playOnTheNextBar() != true {
            engine.play()
        }
    }

    var body: some View {
        let track = store.project.track(trackID)
        let showsRoll = showsPianoRoll(track)
        NavigationStack {
            Group {
                if let track, page == .sound {
                    SoundPanel(track: track)
                } else if let track, let clip = editedClip(track), track.instrument.device == .drums {
                    StepGridView(clip: clip, color: Theme.Color.track(track.colorIndex), step: drumStep(for: clip))
                } else if let track, let clip = editedClip(track) {
                    PianoRoll(clip: clip, color: Theme.Color.track(track.colorIndex), grid: grid(for: clip),
                              snap: snap, zoom: PianoRoll.zoomLevels[zoomIndex])
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
                        playOrStop()
                    } label: {
                        Image(systemName: engine.isPlaying || countsIn ? "stop.fill" : "play.fill")
                    }
                    .accessibilityLabel(engine.isPlaying || countsIn ? "Stop" : "Play")
                    .accessibilityValue(countsIn ? "Starts on the next bar" : "")
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
                        Picker("Snap", selection: $snap) {
                            ForEach(SnapGrid.allCases, id: \.self) { choice in
                                Text(choice.title).tag(choice).accessibilityLabel(choice.spokenTitle)
                            }
                        }
                        .pickerStyle(.menu)
                        .accessibilityLabel("Snap")
                        .accessibilityValue(snap.spokenTitle)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    zoomButtons
                    Spacer()
                }
            }
            .toolbar(showsRoll ? .visible : .hidden, for: .bottomBar)
        }
        .preferredColorScheme(.dark)
    }

    /// Zoom Out and Zoom In for the piano roll; the top bar has no room left on a phone.
    @ViewBuilder private var zoomButtons: some View {
        let levels = PianoRoll.zoomLevels
        let spoken = "\(Int((levels[zoomIndex] * 100).rounded())) percent"
        Button {
            zoom = levels[Swift.max(zoomIndex - 1, 0)]
        } label: {
            Image(systemName: "minus.magnifyingglass")
        }
        .disabled(zoomIndex == 0)
        .accessibilityLabel("Zoom Out")
        .accessibilityValue(spoken)
        Button {
            zoom = levels[Swift.min(zoomIndex + 1, levels.count - 1)]
        } label: {
            Image(systemName: "plus.magnifyingglass")
        }
        .disabled(zoomIndex == levels.count - 1)
        .accessibilityLabel("Zoom In")
        .accessibilityValue(spoken)
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
        // Four bars of the song's meter from bar 1, where the clip is placed.
        let length = Swift.max(Arranging.ticks(movingBars: Self.newClipBars, from: 0, meter: store.project.meterMap), 1)
        try? store.perform([
            .createClip(track: track.id, id: clip, name: Names.derived(track.name, suffix: "Clip"), length: length),
            .placeClip(track: track.id, id: PlacementID(), clip: clip, start: 0),
        ], title: "New Clip")
    }
}

/// Keys on the left, the note grid on the right. Tap empty space to add a note, tap a note to
/// choose it, double-tap it (or Delete Note) to remove it, drag a note to move it, drag its right edge to change its length. Drags on
/// empty space scroll. One drag is one undo step. With VoiceOver the grid's Add Note writes the
/// note after the last one, each note is said in bars and beats and is edited from its actions,
/// and every action says what it did (accessibility audit 2026-11-01, B1/M4/m1).
struct PianoRoll: View {
    @Environment(ProjectStore.self) private var store
    let clip: Clip
    let color: Color
    /// The magnet's step in ticks; 0 with it off (stepless).
    let grid: Tick
    /// The magnet itself, for Quantize.
    var snap: SnapGrid = .standard
    /// One of `zoomLevels`: rows grow by it, columns half as fast, so bigger notes do not cost the
    /// whole bar (accessibility audit 2026-11-01, M5).
    var zoom: Double = 1

    /// Where the zoom is kept: on this device, never in the song.
    nonisolated static let zoomKey = "pianoRoll.zoom"
    /// From the drawn base (18 pt rows) to rows of a full touch target (45 pt).
    nonisolated static let zoomLevels: [Double] = [1, 1.5, 2, 2.5]

    @ScaledMetric(relativeTo: .caption) private var baseRowHeight: CGFloat = 18
    @ScaledMetric(relativeTo: .caption) private var keyWidth: CGFloat = 52
    /// Points per sixteenth note at the base zoom.
    private static let basePointsPerSixteenth: CGFloat = 28
    /// The note a single tap chose. Rows are 18 pt at the base zoom, under a fingertip, so a
    /// single tap never deletes (a slip took a note away, CI audit 2026-10-31): a tap chooses, a
    /// double tap or Delete Note removes.
    @State private var selected: NoteID?
    /// Quantize's swing, kept on this device: 0, 0.25, 0.5 or 0.75.
    @AppStorage(PianoRoll.swingKey) private var swing = 0.0

    nonisolated static let swingKey = "pianoRoll.quantizeSwing"
    /// The steps Quantize and VoiceOver count in: the magnet's, or a sixteenth with it off.
    private var step: Tick { grid > 0 ? grid : NoteEditing.freeNoteLength }

    private var rowHeight: CGFloat { baseRowHeight * CGFloat(zoom) }
    private var pointsPerSixteenth: CGFloat { Self.basePointsPerSixteenth * CGFloat(1 + zoom) / 2 }
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
            // A zoom keeps the notes in view instead of leaving the same points on screen.
            .onChange(of: zoom) { proxy.scrollTo(anchorPitch, anchor: .center) }
        }
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: Theme.Space.s) {
                chordMenu
                timingMenu
                selectionBar
            }
            .padding(Theme.Space.m)
        }
        // Velocity typed in opens Echoel's number pad at the editor's bottom edge.
        .numberPadHost()
    }

    /// The row a zoom keeps in view: the chosen note's, else the clip's middle pitch, else C5.
    private var anchorPitch: Int {
        if let id = selected, let note = clip.notes.first(where: { $0.id == id }) { return note.pitch }
        let pitches = clip.notes.map(\.pitch).sorted()
        return pitches.isEmpty ? 72 : pitches[pitches.count / 2]
    }

    /// A keyboard on its side: white keys in the light text colour, black keys as shorter black
    /// bars over them, as on an instrument — the two told apart by shade and by length (device
    /// video 10021 showed only grey bars). Each C is named.
    private var keys: some View {
        VStack(spacing: 0) {
            ForEach(Note.pitchRange.reversed(), id: \.self) { pitch in
                key(pitch)
            }
        }
    }

    private func key(_ pitch: Int) -> some View {
        let black = NoteEditing.isBlackKey(pitch)
        return ZStack(alignment: .leading) {
            Rectangle().fill(Theme.Color.keyWhite)
            if black {
                Rectangle()
                    .fill(Theme.Color.keyBlack)
                    .frame(width: keyWidth * 0.6)
            }
            if pitch % 12 == 0 {
                Text(NoteEditing.name(of: pitch))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.keyLabel)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, Theme.Space.xs)
            }
        }
        .frame(width: keyWidth, height: rowHeight)
        // The line between two white keys: under B (above C) and under E (above F) a full key
        // ends; elsewhere a black key sits between them.
        .overlay(alignment: .bottom) {
            if pitch % 12 == 0 || pitch % 12 == 5 {
                Rectangle().fill(Theme.Color.textSecondary).frame(height: Theme.Space.hairline)
            }
        }
        .id(pitch)
        .accessibilityHidden(true)
    }

    private var noteGrid: some View {
        let meter = store.project.clipMeter(clip.id)
        return ZStack(alignment: .topLeading) {
            gridCanvas
            ForEach(clip.notes) { note in
                NoteBlock(note: note, clip: clip, color: color, grid: grid, meter: meter,
                          pointsPerTick: pointsPerTick, rowHeight: rowHeight,
                          isSelected: selected == note.id, select: { selected = note.id })
                    // VoiceOver reads the notes in time, a chord from its lowest note, after the grid.
                    .accessibilitySortPriority(-(Double(note.start) * 128 + Double(note.pitch)))
            }
        }
        .frame(width: gridWidth, height: gridHeight, alignment: .topLeading)
        .coordinateSpace(.named(NoteBlock.gridSpace))
        .accessibilityElement(children: .contain)
    }

    /// The grid a finger taps to add a note. VoiceOver's double tap there is Add Note — never a
    /// tap in the middle of the grid, which would add or remove a note no one chose (B1).
    private var gridCanvas: some View {
        Canvas { context, size in drawGrid(in: &context, size: size) }
            .frame(width: gridWidth, height: gridHeight)
            .contentShape(Rectangle())
            .onTapGesture { location in
                selected = nil
                tap(at: location)
            }
            .accessibilityLabel("Note Grid")
            .accessibilityValue(noteCount)
            .accessibilityHint("Adds a note one step after the last one.")
            .accessibilityAction { addNote() }
            .accessibilityAction(named: "Add Note") { addNote() }
            .accessibilitySortPriority(1)
    }

    private var noteCount: String {
        clip.notes.count == 1 ? "1 note" : "\(clip.notes.count) notes"
    }

    /// While a note is chosen: its velocity and the one button that deletes it, in reach of the thumb.
    @ViewBuilder private var selectionBar: some View {
        if let id = selected, let note = clip.notes.first(where: { $0.id == id }) {
            velocityField(note)
            Button("Delete Note", systemImage: "trash", role: .destructive) {
                do {
                    try store.perform(.removeNotes(clip.id, [id]))
                    announce("\(NoteEditing.name(of: note.pitch)) deleted.")
                } catch {
                    announce("The note could not be deleted.", urgent: true)
                }
                selected = nil
            }
            .buttonStyle(ToolButtonStyle())
        }
    }

    /// The chosen note's velocity in Echoel's value field: drag up or down, tap to type it, swipe
    /// with VoiceOver. A drag is one undo step (its commits share a key, closed when it lifts).
    private func velocityField(_ note: Note) -> some View {
        SettingField(title: "Velocity", value: note.velocity, range: Note.velocityRange, standard: 100,
                     commit: { velocity in
                         var louder = note
                         louder.velocity = velocity
                         try? store.perform(.updateNotes(clip.id, [louder]), coalescingKey: "note.velocity.\(note.id)")
                     },
                     ended: { store.endGesture() })
            .frame(width: 112)
    }

    /// The magnet Quantize uses: the chosen one, a sixteenth with it off.
    private var quantizeSnap: SnapGrid { snap == .off ? .sixteenth : snap }

    /// Quantize and Humanize, on the chosen note or, with none chosen, on every note of the clip.
    /// Each is one undo step; Humanize draws a new seed each time and redo replays its notes.
    private var timingMenu: some View {
        Menu {
            Section("Quantize to \(quantizeSnap.title)") {
                ForEach([1.0, 0.75, 0.5, 0.25], id: \.self) { strength in
                    Button("Quantize \(Int(strength * 100)) %") { quantize(strength: strength) }
                }
                Picker("Swing", selection: $swing) {
                    ForEach([0.0, 0.25, 0.5, 0.75], id: \.self) { Text("\(Int($0 * 100)) %").tag($0) }
                }
                .pickerStyle(.menu)
            }
            Section("Humanize") {
                Button("Humanize Light") { humanize(timing: 10, velocity: 6) }
                Button("Humanize Medium") { humanize(timing: 30, velocity: 12) }
                Button("Humanize Strong") { humanize(timing: 60, velocity: 24) }
            }
        } label: {
            Label("Timing", systemImage: "metronome")
        }
        .menuStyle(.button)
        .buttonStyle(ToolButtonStyle())
        .accessibilityLabel("Timing")
        .accessibilityHint(selected == nil ? "Quantize or humanize every note." : "Quantize or humanize the chosen note.")
    }

    /// Chords that fit next, best first (ECHOELTOOLS D5): ranked by harmonic function in the song's
    /// key, without a model. A pick places the chord after the last note, one bar long; nothing is
    /// written until one is picked. A borrowed chord names the notes it brings from outside the scale.
    private var chordMenu: some View {
        let context = store.project.context
        let place = ChordSuggest.position(in: clip, context: context)
        let chords = Array(ChordSuggest.ranked(after: place.previous, sounding: place.sounding, in: context)
            .prefix(Self.suggestedChords))
        return Menu {
            if chords.isEmpty {
                Text("Set a key and scale in the Song menu to get chord suggestions.")
            } else if place.start >= clip.length {
                Text("No room after the last note.")
            } else {
                Section(place.previous.map { "After \($0.name)" } ?? "To open") {
                    ForEach(chords, id: \.pitchClasses) { chord in
                        Button(chordTitle(chord, in: context)) { insert(chord) }
                    }
                }
            }
        } label: {
            Label("Chords", systemImage: "pianokeys")
        }
        .menuStyle(.button)
        .buttonStyle(ToolButtonStyle())
        .accessibilityLabel("Chords")
        .accessibilityHint("Suggests chords that fit after the last note.")
    }

    private static let suggestedChords = 6

    private func chordTitle(_ chord: ChordSuggest.Chord, in context: MusicalContext) -> String {
        let outside = ChordSuggest.outside(chord, in: context).map { MusicalContext.rootNames[$0] }
        return outside.isEmpty ? chord.name : "\(chord.name) — borrowed, \(outside.joined(separator: " ")) outside the scale"
    }

    private func insert(_ chord: ChordSuggest.Chord) {
        let context = store.project.context
        let meter = store.project.clipMeter(clip.id)
        let start = ChordSuggest.position(in: clip, context: context).start
        guard let command = ChordSuggest.insert(chord, in: clip, context: context, length: meter.ticksPerBar(at: start)) else {
            return announce("No room after the last note.")
        }
        do {
            try store.perform([command], title: "Chord")
            let place = NoteEditing.spokenPosition(start, meter: meter, grid: NoteEditing.spokenStep(for: grid))
            announce("Added \(chord.name), \(place).")
        } catch {
            announce("The chord could not be added.", urgent: true)
        }
    }

    private var chosen: Set<NoteID> {
        guard let id = selected, clip.notes.contains(where: { $0.id == id }) else { return [] }
        return [id]
    }

    private var scope: String { chosen.isEmpty ? "All notes" : "The note" }

    private func quantize(strength: Double) {
        let meter = store.project.clipMeter(clip.id)
        guard let command = NoteTiming.quantized(clip, chosen: chosen, snap: quantizeSnap, meter: meter,
                                                 strength: strength, swing: swing) else {
            return announce("\(scope) already on the grid.")
        }
        do {
            try store.perform([command], title: "Quantize")
            announce("\(scope) quantized to \(quantizeSnap.spokenTitle).")
        } catch {
            announce("The notes could not be quantized.", urgent: true)
        }
    }

    private func humanize(timing: Tick, velocity: Int) {
        let seed = UInt64.random(in: .min ... .max)
        guard let command = NoteTiming.humanized(clip, chosen: chosen, timing: timing, velocity: velocity, seed: seed) else {
            return announce("No notes to humanize.")
        }
        do {
            try store.perform([command], title: "Humanize")
            announce("\(scope) humanized.")
        } catch {
            announce("The notes could not be humanized.", urgent: true)
        }
    }

    private func tap(at location: CGPoint) {
        let pitch = Note.pitchRange.upperBound - Int(location.y / rowHeight)
        let tick = Tick(location.x / pointsPerTick)
        guard let command = NoteEditing.tap(in: clip, pitch: pitch, tick: tick, grid: grid) else { return }
        try? store.perform(command)
    }

    /// Add Note: a note one grid step after the last one at its pitch (C4 at the start of an empty
    /// clip), said with its place; at the clip's end, said instead of silence.
    private func addNote() {
        guard let command = NoteEditing.addAfterLast(in: clip, grid: grid),
              case let .addNotes(_, notes) = command, let note = notes.first else {
            announce("No room after the last note.")
            return
        }
        do {
            try store.perform(command)
            let place = NoteEditing.spokenPosition(note.start, meter: store.project.clipMeter(clip.id),
                                                   grid: NoteEditing.spokenStep(for: grid))
            announce("Added \(NoteEditing.name(of: note.pitch)), \(place).")
        } catch {
            announce("The note could not be added.", urgent: true)
        }
    }

    /// What an action did, for VoiceOver: its focus stays on the grid, so nothing else says it.
    /// Said the app's one way (`Theme.Accessibility`); a failure urgently.
    private func announce(_ text: String, urgent: Bool = false) {
        Theme.Accessibility.announce(Announcement(text, priority: urgent ? .urgent : .normal))
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
        // Bar and beat lines of the clip's own meter: the song's from where the clip is placed.
        let meter = store.project.clipMeter(clip.id)
        var tick: Tick = 0
        // The magnet's lines (a sixteenth's with it off), thinned to at least 4 pt apart.
        var lineStep = Swift.max(step, 1)
        while CGFloat(lineStep) * pointsPerTick < 4 { lineStep *= 2 }
        while tick <= clip.length {
            let x = CGFloat(tick) * pointsPerTick
            let color = meter.isBarLine(tick) ? Theme.Color.textTertiary
                : (meter.beatStart(at: tick) == tick ? Theme.Color.border : Theme.Color.surfaceRaised)
            context.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)), with: .color(color))
            tick += lineStep
        }
    }
}

/// One note: a block in the track color, brighter with velocity. A tap chooses it (outlined in
/// the accent), a double tap removes it, dragging moves it, dragging the right edge resizes it.
/// Its VoiceOver actions edit it in steps of a named size and say the result; VoiceOver's own
/// double tap chooses it, as a tap does, and never removes it.
struct NoteBlock: View {
    @Environment(ProjectStore.self) private var store
    let note: Note
    let clip: Clip
    let color: Color
    let grid: Tick
    /// The clip's meter (`Project.clipMeter`), for saying where the note is in bars and beats.
    let meter: MeterMap
    let pointsPerTick: CGFloat
    let rowHeight: CGFloat
    var isSelected = false
    var select: () -> Void = {}

    @State private var origin: Note?

    private static let edgeWidth: CGFloat = 14
    private static let minimumWidth: CGFloat = 6
    static let gridSpace = "pianoRoll.grid"

    var body: some View {
        spoken(block)
    }

    private var block: some View {
        let width = Swift.max(CGFloat(note.length) * pointsPerTick, Self.minimumWidth)
        return RoundedRectangle(cornerRadius: Theme.Radius.small)
            .fill(color.opacity(0.45 + 0.55 * Double(note.velocity) / 127))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.small)
                    .stroke(isSelected ? Theme.Color.accent : Theme.Color.background.opacity(0.6),
                            lineWidth: isSelected ? 2 : 1)
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
            .onTapGesture(count: 2) { perform(.removeNotes(clip.id, [note.id])) }
            .onTapGesture { select() }
            .highPriorityGesture(drag)
            .offset(x: CGFloat(note.start) * pointsPerTick,
                    y: CGFloat(Note.pitchRange.upperBound - note.pitch) * rowHeight)
    }

    /// The note for VoiceOver: its name, its place in bars and beats (never ticks, M4), and its
    /// actions. The explicit default action is what keeps VoiceOver's double tap from reaching
    /// the double-tap-to-delete gesture (the double-tap trap).
    private func spoken(_ content: some View) -> some View {
        content
            .accessibilityElement()
            .accessibilityLabel("\(NoteEditing.name(of: note.pitch)) Note")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityValue(NoteEditing.spokenDetails(of: note, meter: meter, grid: NoteEditing.spokenStep(for: grid)))
            .accessibilityAction { choose() }
            .accessibilityAction(named: "Up a Semitone") { nudge(semitones: 1) }
            .accessibilityAction(named: "Down a Semitone") { nudge(semitones: -1) }
            .accessibilityAction(named: "Up an Octave") { nudge(semitones: 12) }
            .accessibilityAction(named: "Down an Octave") { nudge(semitones: -12) }
            .accessibilityAction(named: "Later by One Step") { nudge(ticks: step) }
            .accessibilityAction(named: "Earlier by One Step") { nudge(ticks: -step) }
            .accessibilityAction(named: "Later by One Bar") { nudge(ticks: bar) }
            .accessibilityAction(named: "Earlier by One Bar") { nudge(ticks: -bar) }
            .accessibilityAction(named: "Longer by One Step") { resize(steps: 1) }
            .accessibilityAction(named: "Shorter by One Step") { resize(steps: -1) }
            .accessibilityAction(named: "Delete") { delete() }
    }

    private var name: String { NoteEditing.name(of: note.pitch) }

    /// A step of the note's actions: the magnet's, or a sixteenth with it off.
    private var step: Tick { grid > 0 ? grid : NoteEditing.freeNoteLength }

    /// One bar of the meter where the note starts.
    private var bar: Tick { meter.ticksPerBar(at: note.start) }

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

    /// VoiceOver's double tap: chosen, as by a tap, so Delete Note appears.
    private func choose() {
        select()
        announce("\(name) selected.")
    }

    /// Exactly a semitone, an octave, a step or a bar — or, where that would leave the keyboard or
    /// the clip, nothing, and the reason said (`NoteEditing.nudged`).
    private func nudge(semitones: Int = 0, ticks: Tick = 0) {
        guard let moved = NoteEditing.nudged(note, byTicks: ticks, semitones: semitones, in: clip) else {
            if semitones != 0 {
                announce(semitones > 0 ? "Top of the keyboard." : "Bottom of the keyboard.")
            } else {
                announce(ticks > 0 ? "End of the clip." : "Start of the clip.")
            }
            return
        }
        guard perform(.updateNotes(clip.id, [moved])) else {
            return announce("The note could not be moved.", urgent: true)
        }
        announce(semitones != 0 ? NoteEditing.name(of: moved.pitch)
                                : NoteEditing.spokenPosition(moved.start, meter: meter, grid: NoteEditing.spokenStep(for: grid)))
    }

    private func resize(steps: Int) {
        guard let resized = NoteEditing.resized(note, bySteps: steps, grid: step, in: clip) else {
            announce(steps > 0 ? "End of the clip." : "Shortest length.")
            return
        }
        guard perform(.updateNotes(clip.id, [resized])) else {
            return announce("The note could not be resized.", urgent: true)
        }
        announce("\(NoteEditing.spokenLength(resized.length, grid: NoteEditing.spokenStep(for: grid))) long")
    }

    private func delete() {
        guard perform(.removeNotes(clip.id, [note.id])) else {
            return announce("The note could not be deleted.", urgent: true)
        }
        announce("\(name) deleted.")
    }

    /// Whether the store took the edit.
    @discardableResult
    private func perform(_ command: Command, coalescing: Bool = false) -> Bool {
        do {
            try store.perform(command, coalescingKey: coalescing ? key : nil)
            return true
        } catch {
            return false
        }
    }

    /// What an action did, for VoiceOver, which stays on the note and would say nothing. Said
    /// the app's one way (`Theme.Accessibility`); a failure urgently.
    private func announce(_ text: String, urgent: Bool = false) {
        Theme.Accessibility.announce(Announcement(text, priority: urgent ? .urgent : .normal))
    }
}
