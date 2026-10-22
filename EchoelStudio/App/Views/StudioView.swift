import EchoelCore
import SwiftUI

/// The root surface: transport on top, tracks below. Every edit goes through the store as a
/// command, so every edit is undoable — the transport's Undo/Redo show that from day one.
struct StudioView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(DocumentController.self) private var documents

    @State private var router = StudioRouter()
    @State private var surface: Surface = .tracks

    enum Surface: Hashable { case tracks, arrange, session, mixer }

    var body: some View {
        @Bindable var router = router
        VStack(spacing: 0) {
            TransportBar()
            Divider().overlay(Theme.Color.border)
            Picker("View", selection: $surface) {
                Text("Tracks").tag(Surface.tracks)
                Text("Arrange").tag(Surface.arrange)
                Text("Session").tag(Surface.session)
                Text("Mixer").tag(Surface.mixer)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Space.m)
            .padding(.vertical, Theme.Space.s)
            .background(Theme.Color.surface)
            switch surface {
            case .tracks: TrackListView { router.sheet = .clipEditor($0) }
            case .arrange:
                ArrangeView(open: { router.sheet = .clip($0, $1) },
                            importAudio: { router.sheet = .importAudio($0, $1) })
            case .session:
                SessionView(open: { router.sheet = .clip($0, $1) }, importClip: { router.sheet = .importClip($0, $1) })
            case .mixer: MixerView()
            }
        }
        .sheet(item: $router.sheet) { sheet in
            switch sheet {
            case .clipEditor(let track): ClipEditorView(trackID: track)
            case let .clip(track, clip): ClipEditorView(trackID: track, clipID: clip)
            case .share(let url): ShareSheet(url: url).ignoresSafeArea()
            case .effects(let track): EffectsView(owner: .track(track))
            case .masterEffects: EffectsView(owner: .master)
            case .store: StoreView()
            case .agent: AgentView()
            case .about: AboutView()
            case let .importAudio(track, start):
                AudioFilePicker(pick: { url in
                    router.sheet = nil
                    Task { await documents.importAudio(url, placingOn: track, at: start) }
                }, cancel: { router.sheet = nil })
                .ignoresSafeArea()
            case let .importClip(track, scene):
                AudioFilePicker(pick: { url in
                    router.sheet = nil
                    Task { await documents.importAudioClip(url, onto: track, scene: scene) }
                }, cancel: { router.sheet = nil })
                .ignoresSafeArea()
            }
        }
        .environment(router)
        .background(Theme.Color.background)
        .onAppear {
            engine.setSamples(documents.samples)
            engine.update(store.project)
        }
        .onChange(of: store.project) { _, project in engine.update(project) }
        .onChange(of: documents.mediaRevision) { engine.setSamples(documents.samples) }
    }
}

/// Play/Stop, tempo, click, undo/redo. Reads only cold state (tempo, flags), never the
/// playhead, so an open menu elsewhere is never rebuilt by the clock.
struct TransportBar: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(DocumentController.self) private var documents
    @Environment(RecordController.self) private var recording
    @Environment(MIDIInput.self) private var midi
    @Environment(ParameterWriter.self) private var writer
    @State private var clickOn = true

    var body: some View {
        VStack(spacing: 0) {
            // A phone in portrait cannot show every control at once: then the strip scrolls
            // sideways instead of squeezing or clipping its buttons.
            ViewThatFits(in: .horizontal) {
                controls
                ScrollView(.horizontal, showsIndicators: false) { controls }
            }
            .frame(minHeight: Theme.Size.transportHeight)
            // Under the controls, not over them: laid over the strip, a message of two or three
            // lines covered Play and Record and took their taps (review 2026-10-21).
            status
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.Space.m)
        }
        .dynamicTypeSize(...Theme.Accessibility.denseStripLimit)
        .background(Theme.Color.surface)
    }

    private var controls: some View {
        HStack(spacing: Theme.Space.s) {
            Button {
                if engine.isStalled {
                    engine.restartAudio()
                } else if engine.isPlaying {
                    Task { await recording.stopTransport() }
                } else {
                    engine.play()
                }
            } label: {
                Image(systemName: engine.isStalled ? "arrow.clockwise" : engine.isPlaying ? "stop.fill" : "play.fill")
            }
            .buttonStyle(ToolButtonStyle(isActive: engine.isPlaying, activeColor: Theme.Color.play))
            .accessibilityLabel(engine.isStalled ? "Restart audio" : engine.isPlaying ? "Stop" : "Play")
            // When audio could not start, this is the way to try again (ultra-audit R1).
            .disabled(!engine.isRunning && !engine.isStalled)

            RecordButton()

            TempoField()

            Button {
                clickOn.toggle()
                engine.setClickEnabled(clickOn)
            } label: {
                Image(systemName: "metronome")
            }
            .buttonStyle(ToolButtonStyle(isActive: clickOn))
            .accessibilityLabel("Click")
            .accessibilityValue(clickOn ? "On" : "Off")

            MIDILearnButton()

            Button { writer.setWriting(!writer.isWriting) } label: {
                Text("A").font(Theme.Font.label)
            }
            .buttonStyle(ToolButtonStyle(isActive: writer.isWriting, activeColor: Theme.Color.record))
            .accessibilityLabel("Write Automation")
            .accessibilityValue(writer.isWriting ? "On" : "Off")
            .accessibilityHint("While playing, moving a control writes it into the song.")

            Spacer(minLength: Theme.Space.s)

            SongMenu()

            Spacer(minLength: Theme.Space.s)

            Button { store.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .buttonStyle(ToolButtonStyle())
                .disabled(!store.canUndo)
                .accessibilityLabel(store.undoTitle.map { "Undo \($0)" } ?? "Undo")

            Button { store.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .buttonStyle(ToolButtonStyle())
                .disabled(!store.canRedo)
                .accessibilityLabel(store.redoTitle.map { "Redo \($0)" } ?? "Redo")
        }
        .padding(.horizontal, Theme.Space.m)
    }

    private var status: some View {
        VStack(spacing: 0) {
            // Work that is not on the disk: nothing else on this strip hides it, MIDI Learn included.
            if let unsaved = documents.saveError {
                Text(unsaved)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.record)
                    .padding(.bottom, 2)
            }
            // The menu closed and the export may first wait for the song's audio to decode: without
            // this line nothing on screen said anything was under way (review 2026-10-22).
            if documents.isExporting {
                Text("Exporting the song…")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .padding(.bottom, 2)
            }
            // The learn banner leads the strip and hides nothing under it: a message raised while
            // learning is as true as one raised before (round 4, C4).
            if midi.isLearning {
                Text(midi.learnTarget == nil ? "MIDI Learn: tap a control, or move one in a plugin." : "MIDI Learn: move a knob or fader on your device.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.accent)
                    .padding(.bottom, 2)
            }
            messages
        }
    }

    /// The audio and the document each say their own message, so one never hides the other
    /// (round 4, C4); a notice only when neither has one. Each line carries its own padding: with
    /// nothing to say, the strip keeps its height.
    private var messages: some View {
        let notice = Self.notices(engine.notice, engine.plugins.notice)
        let quiet = engine.lastError == nil && documents.lastError == nil
        return VStack(spacing: 0) {
            if let audio = engine.lastError {
                Text(audio)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.record)
                    .padding(.bottom, 2)
            }
            if let document = documents.lastError {
                Text(document)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.record)
                    .padding(.bottom, 2)
            }
            if quiet, let notice {
                Text(notice)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .padding(.bottom, 2)
            }
            if let note = documents.launchNote {
                Text(note)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.record)
                    .padding(.bottom, 2)
            }
            if let warning = documents.earlierSongsWarning {
                earlierSongsWarning(warning)
            }
            if let note = documents.earlierSongsNote {
                Text(note)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .padding(.bottom, 2)
            }
            // The export just made stands under a message; an older one only alone.
            if let loudness = documents.lastExportLoudness,
               documents.lastExportIsNews
                || (quiet && notice == nil && documents.saveError == nil && documents.launchNote == nil
                    && documents.earlierSongsWarning == nil && documents.earlierSongsNote == nil) {
                // Streaming services turn down what is louder than about -14 LUFS and ask for -1 dBTP.
                Text(Self.exportText(integrated: loudness.integrated, truePeak: loudness.truePeak))
                    .font(Theme.Font.caption.monospacedDigit())
                    .foregroundStyle(loudness.truePeak > -1 ? Theme.Color.accent : Theme.Color.textSecondary)
                    .padding(.bottom, 2)
            }
        }
    }

    /// Still true after a Play or another song, so it stays until the musician hides it.
    private func earlierSongsWarning(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(text)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.record)
            Button { documents.hideEarlierSongsWarning() } label: {
                Image(systemName: "xmark")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hide this message")
        }
        .padding(.bottom, 2)
    }

    /// Both notices when both stand — a pause and a plugin that came back — so the later one is
    /// not hidden behind the earlier until the next Play clears both (review 2026-10-21).
    static func notices(_ engine: String?, _ plugins: String?) -> String? {
        let standing = [engine, plugins].compactMap { $0 }
        return standing.isEmpty ? nil : standing.joined(separator: " ")
    }

    static func exportText(integrated: Double, truePeak: Double) -> String {
        func value(_ number: Double, _ unit: String) -> String {
            number.isFinite ? String(format: "%.1f", number) + " " + unit : "silent"
        }
        let warning = truePeak > -1 ? " — peaks above −1 dBTP may distort when encoded" : ""
        return "Last export: " + value(integrated, "LUFS") + " · " + value(truePeak, "dBTP") + warning
    }
}

/// Starts a take on the armed track, or ends the one running.
struct RecordButton: View {
    @Environment(RecordController.self) private var recording

    var body: some View {
        Button {
            if recording.isRecording {
                Task { await recording.stopRecording() }
            } else {
                recording.record()
            }
        } label: {
            Image(systemName: "record.circle")
        }
        .buttonStyle(ToolButtonStyle(isActive: recording.isRecording, activeColor: Theme.Color.record))
        .accessibilityLabel(recording.isRecording ? "Stop Recording" : "Record")
        .accessibilityHint(recording.armedTrack == nil ? "Arm a track first." : "")
        .disabled(!recording.canRecord)
    }
}

/// Tempo as a number you drag vertically (up = faster) or step with the buttons. One drag is
/// one undo step.
struct TempoField: View {
    @Environment(ProjectStore.self) private var store
    @Environment(MIDIInput.self) private var midi
    @State private var dragStart: Double?
    @State private var taps = TapTempo()
    @ScaledMetric(relativeTo: .title2) private var valueWidth: CGFloat = 72

    private static let gestureKey = "project.tempo"
    /// Taps get their own key, so a drag or step after a run of taps is its own undo step.
    private static let tapKey = "project.tempo.tap"

    var body: some View {
        HStack(spacing: Theme.Space.xs) {
            Button { nudge(-1) } label: { Image(systemName: "minus") }
                .buttonStyle(ToolButtonStyle())
                .accessibilityLabel("Slower")
                .disabled(followsClock)

            VStack(spacing: 0) {
                Text(shownTempo, format: .number.precision(.fractionLength(1)))
                    .font(Theme.Font.valueLarge)
                    .foregroundStyle(Theme.Color.text)
                // EXT: an external MIDI clock sets the tempo.
                Text(midi.followedSource == nil ? "BPM" : "EXT")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            .frame(minWidth: valueWidth)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        let start = dragStart ?? store.project.tempo
                        dragStart = start
                        // 4 pt per BPM, rounded to tenths.
                        let target = ((start - Double(value.translation.height) / 4) * 10).rounded() / 10
                        set(target)
                    }
                    .onEnded { _ in
                        dragStart = nil
                        store.endGesture()
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Tempo")
            .accessibilityValue("\(Int(shownTempo.rounded())) BPM")
            .accessibilityAdjustableAction { direction in
                nudge(direction == .increment ? 1 : -1)
            }

            Button { nudge(1) } label: { Image(systemName: "plus") }
                .buttonStyle(ToolButtonStyle())
                .accessibilityLabel("Faster")
                .disabled(followsClock)

            Button("Tap", action: tap)
                .buttonStyle(ToolButtonStyle())
                .accessibilityHint("Tap in time to set the tempo.")
                .disabled(followsClock)
        }
    }

    private var followsClock: Bool { midi.followedSource != nil }

    /// While a clock is followed it sets the pace; the song's own tempo waits underneath, unchanged.
    private var shownTempo: Double {
        followsClock ? (midi.clockTempo ?? store.project.tempo) : store.project.tempo
    }

    /// A run of taps is one undo step: a new measurement closes the one before.
    private func tap() {
        let now = ProcessInfo.processInfo.systemUptime
        if taps.startsOver(at: now) { store.endGesture() }
        if let bpm = taps.tap(at: now) { set(bpm, key: Self.tapKey) }
    }

    private func nudge(_ delta: Double) {
        set((store.project.tempo + delta).rounded())
        store.endGesture()
    }

    private func set(_ bpm: Double, key: String = TempoField.gestureKey) {
        guard !followsClock else { return }
        let clamped = min(max(bpm, Tempo.range.lowerBound), Tempo.range.upperBound)
        try? store.perform(.setTempo(bpm: clamped), coalescingKey: key)
    }
}

/// The song's name, and the menu to start or open another. Songs save themselves.
struct SongMenu: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(MIDIInput.self) private var midi
    @Environment(DocumentController.self) private var documents
    @Environment(StudioRouter.self) private var router
    @Environment(AgentSession.self) private var agent

    var body: some View {
        Menu {
            Menu("New Song", systemImage: "plus") {
                ForEach(StarterProject.allCases, id: \.self) { starter in
                    Button(starter.title) { documents.newSong(starter) }
                }
            }
            if agent.isOffered {
                Button("Assistant", systemImage: "text.bubble") { router.sheet = .agent }
            }
            Button("Echoel Plugins", systemImage: "puzzlepiece.extension") { router.sheet = .store }
            Button("About Echoel", systemImage: "info.circle") { router.sheet = .about }
            Menu("Send MIDI Clock", systemImage: "metronome") {
                ForEach(engine.clock.destinations) { destination in
                    Button { engine.clock.toggle(destination) } label: {
                        if engine.clock.isChosen(destination) {
                            Label(destination.name, systemImage: "checkmark")
                        } else {
                            Text(destination.name)
                        }
                    }
                }
            }
            .disabled(engine.clock.destinations.isEmpty)
            Menu("Clock Offset", systemImage: "timer") {
                ForEach(MIDIClockOutput.offsetChoices, id: \.self) { choice in
                    Button { engine.clock.setOffset(milliseconds: choice) } label: {
                        if engine.clock.offsetMilliseconds == choice {
                            Label(Self.offsetTitle(choice), systemImage: "checkmark")
                        } else {
                            Text(Self.offsetTitle(choice))
                        }
                    }
                }
            }
            .disabled(engine.clock.chosen.isEmpty)
            Menu("Follow MIDI Clock", systemImage: "clock.arrow.2.circlepath") {
                Button { midi.follow(nil) } label: {
                    if midi.followedSource == nil { Label("Off", systemImage: "checkmark") } else { Text("Off") }
                }
                ForEach(midi.sources) { source in
                    Button { midi.follow(source.id) } label: {
                        if midi.followedSource == source.id {
                            Label(source.name, systemImage: "checkmark")
                        } else {
                            Text(source.name)
                        }
                    }
                }
            }
            Toggle(isOn: Binding(get: { midi.networkEnabled }, set: { midi.setNetwork($0) })) {
                Label("Network MIDI", systemImage: "network")
            }
            Button("Export WAV", systemImage: "square.and.arrow.up") {
                Task {
                    // A finished export is the newest news: its loudness line must not wait for a
                    // Play behind an older notice. A notice raised while it ran (a plugin that
                    // stopped mid-render, headphones pulled) is newer still, and stays.
                    let standing = TransportBar.notices(engine.notice, engine.plugins.notice)
                    if let url = await documents.exportWAV(plugins: engine.plugins) {
                        if TransportBar.notices(engine.notice, engine.plugins.notice) == standing { engine.clearNotices() }
                        router.sheet = .share(url)
                    }
                }
            }
            // Only the arrangement is rendered: without a note or an audio region in it the file
            // would have no length.
            .disabled(documents.isExporting || !store.project.arrangementHasSound)
            Button("Export MIDI", systemImage: "pianokeys") {
                if let url = documents.exportMIDI() { router.sheet = .share(url) }
            }
            .disabled(!store.project.arrangementHasEvents)
            Menu("Open", systemImage: "folder") {
                ForEach(documents.songs) { song in
                    Button {
                        documents.open(song.url)
                    } label: {
                        if song.url == documents.currentURL {
                            Label(song.name, systemImage: "checkmark")
                        } else {
                            Text(song.name)
                        }
                    }
                }
            }
            .disabled(documents.songs.isEmpty)
        } label: {
            HStack(spacing: Theme.Space.xs) {
                Text(store.project.name)
                    .font(Theme.Font.title)
                    .foregroundStyle(Theme.Color.text)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: Theme.Size.touch)
        }
        .accessibilityLabel("Song \(store.project.name)")
        .accessibilityHint("New song or open another. Songs save automatically.")
        .onAppear { documents.refresh() }
    }

    static func offsetTitle(_ milliseconds: Double) -> String {
        milliseconds == 0 ? "None" : String(format: "%+.0f ms", milliseconds)
    }
}
