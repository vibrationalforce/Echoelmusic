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
                ArrangeView(open: { router.sheet = .clipEditor($0) },
                            importAudio: { router.sheet = .importAudio($0, $1) })
            case .session: SessionView { router.sheet = .clip($0, $1) }
            case .mixer: MixerView()
            }
        }
        .sheet(item: $router.sheet) { sheet in
            switch sheet {
            case .clipEditor(let track): ClipEditorView(trackID: track)
            case let .clip(track, clip): ClipEditorView(trackID: track, clipID: clip)
            case .share(let url): ShareSheet(url: url).ignoresSafeArea()
            case .effects(let track): EffectsView(trackID: track)
            case .store: StoreView()
            case let .importAudio(track, start):
                AudioFilePicker(pick: { url in
                    router.sheet = nil
                    Task { await documents.importAudio(url, placingOn: track, at: start) }
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
    @State private var clickOn = true

    var body: some View {
        HStack(spacing: Theme.Space.s) {
            Button {
                if engine.isPlaying {
                    Task { await recording.stopTransport() }
                } else {
                    engine.play()
                }
            } label: {
                Image(systemName: engine.isPlaying ? "stop.fill" : "play.fill")
            }
            .buttonStyle(ToolButtonStyle(isActive: engine.isPlaying, activeColor: Theme.Color.play))
            .accessibilityLabel(engine.isPlaying ? "Stop" : "Play")
            .disabled(!engine.isRunning)

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
        .frame(minHeight: Theme.Size.transportHeight)
        .dynamicTypeSize(...Theme.Accessibility.denseStripLimit)
        .background(Theme.Color.surface)
        .overlay(alignment: .bottom) {
            if midi.isLearning {
                Text(midi.learnTarget == nil ? "MIDI Learn: tap a control." : "MIDI Learn: move a knob or fader on your device.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.accent)
                    .padding(.bottom, 2)
            } else if let error = engine.lastError ?? documents.lastError {
                Text(error)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.record)
                    .padding(.bottom, 2)
            }
        }
    }
}

/// Starts a take on the armed track, or ends the one running.
struct RecordButton: View {
    @Environment(AudioEngine.self) private var engine
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
        .accessibilityHint(recording.armedTrack == nil ? "Arm an audio track first." : "")
        .disabled(recording.armedTrack == nil || !engine.isInputOpen)
    }
}

/// Tempo as a number you drag vertically (up = faster) or step with the buttons. One drag is
/// one undo step.
struct TempoField: View {
    @Environment(ProjectStore.self) private var store
    @State private var dragStart: Double?
    @ScaledMetric(relativeTo: .title2) private var valueWidth: CGFloat = 72

    private static let gestureKey = "project.tempo"

    var body: some View {
        HStack(spacing: Theme.Space.xs) {
            Button { nudge(-1) } label: { Image(systemName: "minus") }
                .buttonStyle(ToolButtonStyle())
                .accessibilityLabel("Slower")

            VStack(spacing: 0) {
                Text(store.project.tempo, format: .number.precision(.fractionLength(1)))
                    .font(Theme.Font.valueLarge)
                    .foregroundStyle(Theme.Color.text)
                Text("BPM")
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
            .accessibilityValue("\(Int(store.project.tempo.rounded())) BPM")
            .accessibilityAdjustableAction { direction in
                nudge(direction == .increment ? 1 : -1)
            }

            Button { nudge(1) } label: { Image(systemName: "plus") }
                .buttonStyle(ToolButtonStyle())
                .accessibilityLabel("Faster")
        }
    }

    private func nudge(_ delta: Double) {
        set((store.project.tempo + delta).rounded())
        store.endGesture()
    }

    private func set(_ bpm: Double) {
        let clamped = min(max(bpm, Tempo.range.lowerBound), Tempo.range.upperBound)
        try? store.perform(.setTempo(bpm: clamped), coalescingKey: Self.gestureKey)
    }
}

/// The song's name, and the menu to start or open another. Songs save themselves.
struct SongMenu: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(DocumentController.self) private var documents
    @Environment(StudioRouter.self) private var router

    var body: some View {
        Menu {
            Button("New Song", systemImage: "plus") { documents.newSong() }
            Button("Echoel Plugins", systemImage: "puzzlepiece.extension") { router.sheet = .store }
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
            Button("Export WAV", systemImage: "square.and.arrow.up") {
                Task {
                    if let url = await documents.exportWAV(plugins: engine.plugins) { router.sheet = .share(url) }
                }
            }
            .disabled(documents.isExporting
                      || store.project.tracks.allSatisfy { $0.clips.allSatisfy(\.notes.isEmpty) && $0.regions.isEmpty })
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
}
