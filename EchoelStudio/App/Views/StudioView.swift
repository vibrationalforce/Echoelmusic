import EchoelCore
import SwiftUI
import UniformTypeIdentifiers

/// The root surface: transport on top, tracks below. Every edit goes through the store as a
/// command, so every edit is undoable — the transport's Undo/Redo show that from day one.
struct StudioView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(DocumentController.self) private var documents
    @Environment(HeartRateStrap.self) private var strap

    @State private var router = StudioRouter()
    /// The Connections module (wave W4), owned here so a connection keeps sending while its
    /// panel is closed; every connection is off until switched on in the panel.
    @State private var connections = ConnectionsController()
    @State private var surface: Surface = .tracks
    /// The keys and pads under the surface; on by default so the phone alone makes sound.
    @AppStorage(PlayKeysView.shownKey) private var showsKeys = true
    /// The Field as a small window over the other views (wave W3); on by default, so the picture
    /// is in sight from the first launch, fullscreen one tap away.
    @AppStorage(FieldWindow.shownKey) private var showsFieldWindow = true
    /// The Field over the whole studio. A layer, not a presentation: the sheet slot stays one.
    @State private var fieldFullscreen = false
    /// The song's video as a small window (wave W7); on by default while the song has video.
    @AppStorage(VideoWindow.shownKey) private var showsVideoWindow = true
    /// The live stream (W14); off until Go Live on its page. Owned here so a stream outlives the page.
    @State private var streaming = StreamingController()

    enum Surface: Hashable { case tracks, arrange, session, mixer, field, sky }

    var body: some View {
        @Bindable var router = router
        ZStack {
            VStack(spacing: 0) {
                TransportBar()
                Divider().overlay(Theme.Color.border)
                ZStack(alignment: .bottomTrailing) {
                    surfaceView
                    if showsVideoWindow, hasVideo, !fieldFullscreen {
                        VideoWindow(close: { showsVideoWindow = false })
                            .padding(Theme.Space.m)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                            .transition(.opacity)
                    }
                    // One picture at a time: the window rests while the Field or the sky is the view,
                    // or the Field fills the screen.
                    if showsFieldWindow, surface != .field, surface != .sky, !fieldFullscreen {
                        FieldWindow(expand: { openFieldFullscreen() }, close: { showsFieldWindow = false })
                            .padding(Theme.Space.m)
                            .transition(.opacity)
                    }
                    // `isLive`/`isStarting` change only at Go Live and Stop; the clock ticks in the badge.
                    if streaming.isLive || streaming.isStarting {
                        StreamLiveBadge(open: { router.sheet = .streaming })
                            .padding(Theme.Space.m)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }
                if showsKeys {
                    Divider().overlay(Theme.Color.border)
                    PlayKeysView()
                }
                // The earlier instrument's chip bar at the bottom: one chip per view, in thumb reach.
                SurfaceBar(selection: $surface)
            }
            // A typed value (the tempo, a mixer strip) opens Echoel's number pad at the bottom
            // edge — a layer, not a presentation, so the sheet slot stays one (Law 7).
            .numberPadHost()
            if fieldFullscreen {
                FieldFullscreen(close: { closeFieldFullscreen() })
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .sheet(item: $router.sheet, onDismiss: { router.sheetClosed() }) { sheet in
            switch sheet {
            case .clipEditor(let track): ClipEditorView(trackID: track)
            case let .clip(track, clip): ClipEditorView(trackID: track, clipID: clip)
            case .share(let url): ShareSheet(url: url).ignoresSafeArea()
            case .effects(let track): EffectsView(owner: .track(track))
            case .masterEffects: EffectsView(owner: .master)
            case .store: StoreView()
            case .agent: AgentView()
            case .about: AboutView()
            case .renameSong: RenameSongView()
            case .rename(let target): RenameView(target: target)
            case .streaming: StreamingView()
            case .connections: ConnectionsView()
            case let .importAudio(track, start):
                AudioFilePicker(pick: { url in
                    router.sheet = nil
                    Task { await documents.importAudio(url, placingOn: track, at: start) }
                }, cancel: { router.sheet = nil })
                .ignoresSafeArea()
            case let .importVideoFromPhotos(track, start):
                VideoLibraryPicker(pick: { url in
                    router.sheet = nil
                    Task {
                        await documents.importVideo(url, onto: track, at: start)
                        try? FileManager.default.removeItem(at: url)
                    }
                }, cancel: { router.sheet = nil })
                .ignoresSafeArea()
            case let .importVideoFromFiles(track, start):
                AudioFilePicker(pick: { url in
                    router.sheet = nil
                    Task { await documents.importVideo(url, onto: track, at: start) }
                }, cancel: { router.sheet = nil }, types: [.movie])
                .ignoresSafeArea()
            case .cameraTake(let track): CameraTakeView(track: track)
            case .exportVideo: VideoExportView()
            case .importMIDI:
                AudioFilePicker(pick: { url in
                    router.sheet = nil
                    documents.importMIDI(url)
                }, cancel: { router.sheet = nil }, types: [.midi])
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
        .environment(streaming)
        .environment(connections)
        .background(Theme.Color.background)
        .onAppear {
            engine.setSamples(documents.samples)
            engine.update(store.project)
            connections.attach(engine: engine, store: store, strap: strap)
        }
        .onChange(of: store.project) { _, project in engine.update(project) }
        .onChange(of: documents.mediaRevision) { engine.setSamples(documents.samples) }
    }

    /// Whether the song has a picture to show: a video track with a part on it. Changes only with
    /// an edit, never with the clock.
    private var hasVideo: Bool {
        store.project.tracks.contains { $0.kind == .video && !$0.regions.isEmpty }
    }

    /// The chosen view. While the Field fills the screen its own view rests, so the GPU draws one
    /// picture, not two.
    @ViewBuilder private var surfaceView: some View {
        switch surface {
        case .tracks: TrackListView { router.sheet = .clipEditor($0) }
        case .arrange:
            ArrangeView(open: { router.sheet = .clip($0, $1) },
                        importAudio: { track, tick in
                            router.sheet = store.project.track(track)?.kind == .video
                                ? .importVideoFromPhotos(track, tick) : .importAudio(track, tick)
                        })
        case .session:
            SessionView(open: { router.sheet = .clip($0, $1) }, importClip: { router.sheet = .importClip($0, $1) })
        case .mixer: MixerView()
        case .field:
            if fieldFullscreen {
                Theme.Color.background
            } else {
                FieldSurface(expand: { openFieldFullscreen() })
            }
        case .sky:
            // The sky drawn from the star table, place, time and the phone's attitude (Sky S2).
            SkySurface()
        }
    }

    private func openFieldFullscreen() {
        withAnimation(.easeOut(duration: 0.15)) { fieldFullscreen = true }
    }

    private func closeFieldFullscreen() {
        withAnimation(.easeOut(duration: 0.15)) { fieldFullscreen = false }
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
    @AppStorage(PlayKeysView.shownKey) private var showsKeys = true
    @AppStorage(FieldWindow.shownKey) private var showsFieldWindow = true

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

            PulseReading()

            Button { engine.setLoopsSong(!engine.loopsSong) } label: { Image(systemName: "repeat") }
                .buttonStyle(ToolButtonStyle(isActive: engine.loopsSong))
                .accessibilityLabel("Loop")
                .accessibilityValue(engine.loopsSong ? "On" : "Off")
                .accessibilityHint("Plays the song from bar 1 again after its last bar.")

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

            Button { showsKeys.toggle() } label: { Image(systemName: "pianokeys") }
                .buttonStyle(ToolButtonStyle(isActive: showsKeys))
                .accessibilityLabel("Keys")
                .accessibilityValue(showsKeys ? "Shown" : "Hidden")
                .accessibilityHint("Shows keys and pads that play the live track.")

            // The Field as a small window over the other views (wave W3).
            Button { showsFieldWindow.toggle() } label: { Image(systemName: "rectangle.inset.bottomright.filled") }
                .buttonStyle(ToolButtonStyle(isActive: showsFieldWindow))
                .accessibilityLabel("Field Window")
                .accessibilityValue(showsFieldWindow ? "Shown" : "Hidden")
                .accessibilityHint("Shows the Field as a small window over the other views.")

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
                Text(documents.exportProgress ?? "Exporting the song…")
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
            // What the fingertip on the camera should do (wave W1); its own leaf, so this strip
            // never observes the camera.
            CameraPulseCueLine()
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
            // A safe start holds plugins of other makers; this is the one door that loads them.
            if engine.plugins.holdsPlugins {
                Button("Load plugins from other makers") { engine.plugins.loadHeldPlugins() }
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.accent)
                    .buttonStyle(.plain)
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
        .accessibilityHint(recording.armedTrack == nil ? "Records the track the keys play." : "")
        .disabled(!recording.canRecord)
    }
}

/// Tempo as a number you drag vertically (up = faster) or step with the buttons. One drag is
/// one undo step.
struct TempoField: View {
    @Environment(ProjectStore.self) private var store
    @Environment(MIDIInput.self) private var midi
    @Environment(NumberPadController.self) private var pad: NumberPadController?
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
                    .foregroundStyle(isTyped ? Theme.Color.accent : Theme.Color.text)
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
            .onTapGesture(perform: typeTempo)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Tempo")
            .accessibilityValue("\(Int(shownTempo.rounded())) BPM")
            .accessibilityAdjustableAction { direction in
                nudge(direction == .increment ? 1 : -1)
            }
            .accessibilityAction(named: "Type a tempo", typeTempo)

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

    private static let padOwner = "project.tempo"

    private var isTyped: Bool { pad?.request?.owner == Self.padOwner }

    /// The tempo on Echoel's number pad, in BPM to a tenth; one undo step. Not while an external
    /// clock sets the pace.
    private func typeTempo() {
        guard !followsClock, let pad else { return }
        let standard = store.project.descriptor(for: .tempo)?.defaultValue
        pad.open(NumberPadRequest(owner: Self.padOwner, title: "Tempo",
                                  format: NumberEntryFormat(scale: 1, decimals: 1, unit: "BPM"),
                                  range: Tempo.range, value: store.project.tempo, standard: standard) { bpm in
            set(bpm)
            store.endGesture()
        })
    }

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
    @Environment(RecordController.self) private var recording
    @Environment(StudioRouter.self) private var router
    @Environment(AgentSession.self) private var agent
    @Environment(ParameterWriter.self) private var writer

    var body: some View {
        Menu {
            Menu("New Song", systemImage: "plus") {
                ForEach(StarterProject.allCases, id: \.self) { starter in
                    // A take running in this song lands in it first.
                    Button(starter.title) {
                        Task {
                            await recording.finishTakes()
                            documents.newSong(starter)
                        }
                    }
                }
            }
            // The Song page: name, swing, tempo changes. Not while an import, an export, a take or
            // the media load uses the package: a rename then moves it at once, and a finished
            // export cannot take the slot from a typed name.
            Button("Song Settings…", systemImage: "slider.horizontal.3") { router.sheet = .renameSong }
                .disabled(documents.packageIsBusy)
            keyAndScale
            timeSignatureMenu
            if agent.isOffered {
                Button("Assistant", systemImage: "text.bubble") { router.sheet = .agent }
            }
            Button("Echoel Plugins", systemImage: "puzzlepiece.extension") { router.sheet = .store }
            Button("About Echoel", systemImage: "info.circle") { router.sheet = .about }
            Button("Live Stream…", systemImage: "dot.radiowaves.left.and.right") { router.sheet = .streaming }
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
            mpeMenu
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
            // OSC, ADM-OSC, Art-Net and sACN out (wave W4): every one off until switched on there.
            Button("Connections…", systemImage: "antenna.radiowaves.left.and.right") { router.sheet = .connections }
            // The body as a source (wave W1): off until chosen here — the chest strap or the rear
            // camera, one at a time; only then does iOS ask for Bluetooth or the camera. The pulse
            // shows beside Record while it is measured.
            BodySourceMenu()
            Button("Export WAV", systemImage: "square.and.arrow.up") {
                Task {
                    // A finished export is the newest news: its loudness line must not wait for a
                    // Play behind an older notice. A notice raised while it ran (a plugin that
                    // stopped mid-render, headphones pulled) is newer still, and stays.
                    let standing = TransportBar.notices(engine.notice, engine.plugins.notice)
                    if let url = await documents.exportWAV(plugins: engine.plugins) {
                        if TransportBar.notices(engine.notice, engine.plugins.notice) == standing { engine.clearNotices() }
                        router.share(url)
                    }
                }
            }
            // Only the arrangement is rendered: without a note or an audio region in it the file
            // would have no length.
            .disabled(documents.isExporting || !store.project.arrangementHasSound)
            // One file per track and return the mix hears, for another DAW.
            Button("Export Stems", systemImage: "square.stack.3d.up") {
                Task {
                    let standing = TransportBar.notices(engine.notice, engine.plugins.notice)
                    if let folder = await documents.exportStems(plugins: engine.plugins) {
                        if TransportBar.notices(engine.notice, engine.plugins.notice) == standing { engine.clearNotices() }
                        router.share(folder)
                    }
                }
            }
            .disabled(documents.isExporting || !store.project.arrangementHasSound)
            Button("Export MIDI", systemImage: "pianokeys") {
                if let url = documents.exportMIDI() { router.share(url) }
            }
            .disabled(!store.project.arrangementHasEvents)
            // A Standard MIDI File as new instrument tracks; an empty song takes its tempo and meter.
            Button("Import MIDI…", systemImage: "square.and.arrow.down") { router.sheet = .importMIDI }
            // The song as an MP4 for social platforms or a screen: the mix under the video tracks.
            Button("Export Video", systemImage: "film") { router.sheet = .exportVideo }
                .disabled(documents.isExporting || VideoPlan.program(of: store.project).isEmpty)
            // The song itself, with its audio, for another device running Echoel Studio.
            Button("Share Song", systemImage: "square.and.arrow.up.on.square") {
                Task {
                    if let url = await documents.shareSong(plugins: engine.plugins) { router.share(url) }
                }
            }
            .disabled(documents.isExporting)
            Menu("Open", systemImage: "folder") {
                ForEach(documents.songs) { song in
                    Button {
                        Task {
                            await recording.finishTakes()
                            documents.open(song.url)
                        }
                    } label: {
                        // By path: the list spells a package with a trailing slash, and a renamed or
                        // new song's URL is built without one.
                        if song.url.standardizedFileURL.path == documents.currentURL?.standardizedFileURL.path {
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
                Text(documents.songTitle)
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
        .accessibilityLabel("Song \(documents.songTitle)")
        .accessibilityHint("New song or open another. Songs save automatically.")
        .onAppear { documents.refresh() }
    }

    /// The song's key and scale, and whether a keyboard is held in them. Through the writer like
    /// every other control, so a pick while automation writing is armed lands in the lane. Nothing
    /// else sets them on screen; the assistant is hidden on devices without its model.
    private var keyAndScale: some View {
        let context = store.project.context
        return Menu {
            Picker("Key", selection: Binding(get: { context.root }, set: { pick(.keyRoot, Double($0)) })) {
                ForEach(MusicalContext.rootRange, id: \.self) { Text(MusicalContext.rootNames[$0]).tag($0) }
            }
            .pickerStyle(.menu)
            Picker("Scale", selection: Binding(get: { context.scale }, set: { scale in
                pick(.scale, Double(Scale.allCases.firstIndex(of: scale) ?? 0))
            })) {
                ForEach(Scale.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
            // The tone system and concert pitch every tuned voice plays in; a song stores the
            // system's index and the pitch in hertz.
            Picker("Tone System", selection: Binding(get: { context.tuning }, set: { id in
                pick(.tuning, Double(TuningSystem.library.firstIndex { $0.id == id } ?? 0))
            })) {
                ForEach(TuningSystem.library) { Text($0.name).tag($0.id) }
            }
            .pickerStyle(.menu)
            Menu("Concert Pitch \u{00B7} A = \(String(format: "%.2f", context.concertPitch)) Hz") {
                ForEach(MusicalContext.concertPitchPresets, id: \.title) { preset in
                    Button {
                        pick(.concertPitch, preset.hertz)
                    } label: {
                        if abs(preset.hertz - context.concertPitch) < 0.005 {
                            Label(preset.title, systemImage: "checkmark")
                        } else {
                            Text(preset.title)
                        }
                    }
                }
            }
            // On this device: a controller's keys sound the nearest pitch in the scale. Not for a
            // drum kit, whose keys pick drums; a chromatic scale holds nothing.
            Toggle(isOn: Binding(get: { engine.keysFollowScale }, set: { engine.setKeysFollowScale($0) })) {
                Label("Keys Follow Scale", systemImage: "pianokeys")
            }
        } label: {
            Label("Key \u{00B7} \(context.title)", systemImage: "music.note")
        }
    }

    /// The song's time signature: the common ones by name, any other by its two numbers. A
    /// change keeps every note on its tick; the bar lines move around them (one undo step).
    private var timeSignatureMenu: some View {
        let current = store.project.timeSignature
        return Menu {
            ForEach(Self.commonSignatures, id: \.self) { signature in
                Button { setSignature(signature) } label: {
                    if signature == current {
                        Label(Self.title(signature), systemImage: "checkmark")
                    } else {
                        Text(Self.title(signature))
                    }
                }
            }
            Divider()
            Picker("Beats per Bar", selection: Binding(get: { current.numerator }, set: {
                setSignature(TimeSignature($0, current.denominator))
            })) {
                ForEach(1...32, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.menu)
            Picker("Beat Unit", selection: Binding(get: { current.denominator }, set: {
                setSignature(TimeSignature(current.numerator, $0))
            })) {
                ForEach(TimeSignature.allowedDenominators.sorted(), id: \.self) { Text("1/\($0)").tag($0) }
            }
            .pickerStyle(.menu)
        } label: {
            Label("Time Signature \u{00B7} \(Self.title(current))", systemImage: "music.quarternote.3")
        }
    }

    static let commonSignatures: [TimeSignature] = [
        TimeSignature(4, 4), TimeSignature(3, 4), TimeSignature(2, 4), TimeSignature(5, 4),
        TimeSignature(6, 8), TimeSignature(7, 8), TimeSignature(9, 8), TimeSignature(12, 8),
    ]

    static func title(_ signature: TimeSignature) -> String {
        "\(signature.numerator)/\(signature.denominator)"
    }

    private func setSignature(_ signature: TimeSignature) {
        guard signature != store.project.timeSignature else { return }
        try? store.perform(.setTimeSignature(signature))
    }

    private func pick(_ address: ParameterAddress, _ value: Double) {
        writer.set(address, to: value, coalescingKey: nil)
        writer.endGesture()
    }

    /// MPE out (W5b): off until an output is chosen; the live track's notes then go out as a
    /// lower zone, pressure and slide following the body.
    private var mpeMenu: some View {
        Menu("Send MPE", systemImage: "pianokeys") {
            ForEach(engine.mpe.destinations) { destination in
                Button { engine.mpe.toggle(destination) } label: {
                    if engine.mpe.isChosen(destination) {
                        Label(destination.name, systemImage: "checkmark")
                    } else {
                        Text(destination.name)
                    }
                }
            }
            Divider()
            sourceMenu("Pressure", current: engine.mpe.pressureSource) { engine.mpe.setPressure($0) }
            sourceMenu("Slide", current: engine.mpe.slideSource) { engine.mpe.setSlide($0) }
        }
        .disabled(engine.mpe.destinations.isEmpty)
    }

    private func sourceMenu(_ title: String, current: ModulationSource?,
                            choose: @escaping (ModulationSource?) -> Void) -> some View {
        Menu("\(title): \(MIDIMPEOutput.title(current))") {
            Button { choose(nil) } label: {
                if current == nil { Label("Off", systemImage: "checkmark") } else { Text("Off") }
            }
            ForEach(MIDIMPEOutput.bodySources, id: \.self) { source in
                Button { choose(source) } label: {
                    if current == source {
                        Label(MIDIMPEOutput.title(source), systemImage: "checkmark")
                    } else {
                        Text(MIDIMPEOutput.title(source))
                    }
                }
            }
        }
    }

    static func offsetTitle(_ milliseconds: Double) -> String {
        milliseconds == 0 ? "None" : String(format: "%+.0f ms", milliseconds)
    }
}

/// The views of the studio as a row of chips — the earlier instrument's bottom bar: the chosen
/// one filled with the accent, the others raised with a hairline. It scrolls sideways when the
/// text is large rather than squeezing six names into a segmented control.
private struct SurfaceBar: View {
    @Binding var selection: StudioView.Surface

    private static var items: [(surface: StudioView.Surface, title: String)] {
        [(.tracks, "Tracks"), (.arrange, "Arrange"), (.session, "Session"),
         (.mixer, "Mixer"), (.field, "Field"), (.sky, "Sky")]
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Space.s) {
                ForEach(Self.items, id: \.surface) { item in
                    chip(item.surface, item.title)
                }
            }
            .padding(.horizontal, Theme.Space.m)
            .padding(.vertical, Theme.Space.s)
        }
        .background(Theme.Color.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Color.border).frame(height: 1)
        }
        .dynamicTypeSize(...Theme.Accessibility.denseStripLimit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("View")
    }

    private func chip(_ surface: StudioView.Surface, _ title: String) -> some View {
        let chosen = selection == surface
        return Button(title) { selection = surface }
            .buttonStyle(ToolButtonStyle(isActive: chosen))
            .animation(Theme.Motion.quick, value: chosen)
            .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}
