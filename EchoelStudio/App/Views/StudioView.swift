import EchoelCore
import EchoelEngine
import SwiftUI
import UniformTypeIdentifiers

/// The root surface: transport on top, tracks below. Every edit goes through the store as a
/// command, so every edit is undoable — the transport's Undo/Redo show that from day one.
struct StudioView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(DocumentController.self) private var documents
    @Environment(HeartRateStrap.self) private var strap
    @Environment(CameraPulseSource.self) private var camera
    @Environment(MIDIInput.self) private var midi

    /// The Connections module (wave W4), the app's one: this window reports its phase to it, and
    /// the rig is let go only when the last window leaves the foreground (Q2).
    @Environment(ConnectionsController.self) private var connections

    @State private var router = StudioRouter()
    /// This window, as the connections know it.
    @State private var sceneID = UUID()
    /// This window's phase (a view reads its own scene's, not the app's).
    @Environment(\.scenePhase) private var scenePhase
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
    /// The jam (W16); off until the musician hosts or joins one on its page. Owned here so a jam
    /// keeps its clock while the page is closed.
    @State private var jam = JamSession()
    /// The tempo lock, Fixed or Flow (W12); owned here so Flow goes on while another view is open.
    @State private var flow = FlowController()
    /// The hits of the song's video files (CUT): found once per file, shown and snapped to in Arrange.
    @State private var videoHits = VideoHits()

    enum Surface: Hashable {
        case instrument, tracks, arrange, session, mixer, field, sky

        /// Its name on the bar of views, and the name of its area for VoiceOver.
        var title: String {
            switch self {
            case .instrument: "Instrument"
            case .tracks: "Tracks"
            case .arrange: "Arrange"
            case .session: "Session"
            case .mixer: "Mixer"
            case .field: "Field"
            case .sky: "Sky"
            }
        }

        /// Its symbol on the bar of views, above the word.
        var symbol: String {
            switch self {
            case .instrument: "pianokeys"
            case .tracks: "list.bullet"
            case .arrange: "rectangle.split.3x1"
            case .session: "square.grid.3x3"
            case .mixer: "slider.vertical.3"
            case .field: "circle.hexagongrid"
            case .sky: "moon.stars"
            }
        }

        /// Whether the keys belong under this view: where notes are played or written. The mixer,
        /// the Field and the sky keep their whole height — under the keys a phone left the mixer
        /// about 350 points for a strip that wants 520.
        var takesKeys: Bool {
            switch self {
            case .instrument, .tracks, .arrange, .session: true
            case .mixer, .field, .sky: false
            }
        }

        /// What the Keys switch does under this view. Under Tracks, Arrange and Session it decides;
        /// the Instrument always has its keys, and the mixer, the Field and the sky never do — there
        /// the switch is dimmed, so it does not look on over a view that shows no keys.
        var keysSwitch: KeysSwitch {
            switch self {
            case .instrument: .alwaysShown
            case .tracks, .arrange, .session: .decides
            case .mixer, .field, .sky: .neverShown
            }
        }
    }

    /// What the transport's Keys switch does under the chosen view (`Surface.keysSwitch`).
    enum KeysSwitch {
        case decides, alwaysShown, neverShown
    }

    var body: some View {
        @Bindable var router = router
        ZStack {
            studio
                // While the Field fills the screen the studio under it is not drawn at all: a
                // cross-fade let the arrange playhead show through the picture as a white bar
                // (device video 10021). Hidden, not removed, so nothing in it stops or reloads.
                .opacity(fieldFullscreen ? 0 : 1)
                .accessibilityHidden(fieldFullscreen)
            if fieldFullscreen {
                FieldFullscreen(close: { closeFieldFullscreen() })
                    .zIndex(1)
            }
        }
        .sheet(item: $router.sheet, onDismiss: { router.sheetClosed() }) { sheet in
            sheetContent(sheet)
        }
        .environment(router)
        .environment(streaming)
        .environment(jam)
        .environment(flow)
        .environment(videoHits)
        .background(Theme.Color.background)
        .onAppear {
            // A stem export asked for by Siri or Shortcuts comes up in the share sheet (PRO-W1).
            StudioIntentBridge.shared.share = { [weak router = self.router] url in router?.share(url) }
            engine.setSamples(documents.samples)
            engine.update(store.project)
            connections.scene(sceneID, is: ScenePresence.Phase(scenePhase))
            jam.attach(engine: engine, store: store, midi: midi)
            flow.attach(engine: engine, store: store, strap: strap, camera: camera, midi: midi, jam: jam,
                        connections: connections)
        }
        .onChange(of: store.project) { _, project in engine.update(project) }
        // Another song: Play starts and Stop returns at its bar 1, not at the last song's cue.
        .onChange(of: store.documentGeneration) { engine.forgetCue() }
        .onChange(of: documents.mediaRevision) { engine.setSamples(documents.samples) }
        .onChange(of: scenePhase) { _, phase in connections.scene(sceneID, is: ScenePresence.Phase(phase)) }
        .onDisappear { connections.sceneLeft(sceneID) }
    }

    /// Four named areas, so VoiceOver's Containers rotor reaches each in one swipe and says where
    /// it is (W18, m17): the transport, the chosen view, the keys, the bar of views.
    private var studio: some View {
        VStack(spacing: 0) {
            TransportBar(keysSwitch: surface.keysSwitch)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Transport")
                // Return, comma and period: the locate keys, which have no button of their own.
                .background { LocateKeys() }
            ListeningNote()
            Divider().overlay(Theme.Color.border)
            ZStack(alignment: .bottomTrailing) {
                surfaceView
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(surface.title)
                if showsVideoWindow, hasVideo, !fieldFullscreen {
                    VideoWindow(close: { showsVideoWindow = false })
                        .padding(Theme.Space.m)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .transition(.opacity)
                }
                // One picture at a time: the window rests while the Field, the Instrument (which
                // shows it) or the sky is the view, or the Field fills the screen.
                if showsFieldWindow, surface != .field, surface != .instrument, surface != .sky, !fieldFullscreen {
                    FieldWindow(expand: { openFieldFullscreen() }, close: { showsFieldWindow = false })
                        .padding(Theme.Space.m)
                        .transition(.opacity)
                }
                // `isOn` changes only at Go Live and Stop; the clock ticks in the badge.
                if streaming.isOn {
                    StreamLiveBadge(open: { router.sheet = .streaming })
                        .padding(Theme.Space.m)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            // The Instrument is played on the keys, so they stay under it whatever the Keys switch
            // says; the mixer, the Field and the sky never carry them (`Surface.takesKeys`).
            if surface == .instrument || (showsKeys && surface.takesKeys) {
                Divider().overlay(Theme.Color.border)
                PlayKeysView()
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Keys")
            }
            // The earlier instrument's chip bar at the bottom: one chip per view, in thumb reach.
            SurfaceBar(selection: $surface)
        }
        // A typed value (the tempo, a mixer strip) opens Echoel's number pad at the bottom
        // edge — a layer, not a presentation, so the sheet slot stays one (Law 7).
        .numberPadHost()
    }

    @ViewBuilder private func sheetContent(_ sheet: StudioSheet) -> some View {
        switch sheet {
        case .clipEditor(let track): ClipEditorView(trackID: track)
        case let .clip(track, clip): ClipEditorView(trackID: track, clipID: clip)
        case .share(let url): ShareSheet(url: url).ignoresSafeArea()
        case .effects(let track): EffectsView(owner: .track(track))
        case .masterEffects: EffectsView(owner: .master)
        case .store: StoreView()
        case .agent: AgentView()
        case .about: AboutView()
        case .learn: LearnView()
        case .renameSong: RenameSongView()
        case .rename(let target): RenameView(target: target)
        case .streaming: StreamingView()
        case .connections: ConnectionsView()
        case .jam: JamView()
        case let .regionEdit(track, region): RegionEditView(trackID: track, regionID: region)
        case let .regionColor(track, region): RegionColorView(trackID: track, regionID: region)
        case let .convertToMIDI(track, region): ConvertToMIDIView(trackID: track, regionID: region)
        case let .regionBake(track, region): RegionBakeView(trackID: track, regionID: region)
        case let .transcribe(track, region): TranscribeView(trackID: track, regionID: region)
        case .subtitles: SubtitlesView()
        case .browser: MediaBrowserView()
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

    /// Whether the song has a picture to show: a video track with a part on it. Changes only with
    /// an edit, never with the clock.
    private var hasVideo: Bool {
        store.project.tracks.contains { $0.kind == .video && !$0.regions.isEmpty }
    }

    /// The chosen view. While the Field fills the screen its own view rests, so the GPU draws one
    /// picture, not two.
    @ViewBuilder private var surfaceView: some View {
        switch surface {
        case .instrument:
            // The heart of Echoel (W12): the Field, the pulse, the Body Voice, the tempo lock.
            InstrumentSurface(showsField: !fieldFullscreen, expand: { openFieldFullscreen() })
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
        // At once, without a cross-fade: the fade was where the studio showed through.
        fieldFullscreen = true
    }

    private func closeFieldFullscreen() {
        fieldFullscreen = false
    }
}

/// Play/Stop, tempo, click, undo/redo. Reads only cold state (tempo, flags), never the
/// playhead, so an open menu elsewhere is never rebuilt by the clock: the song position beside
/// Play is its own leaf (`PositionReadout`).
struct TransportBar: View {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(DocumentController.self) private var documents
    @Environment(RecordController.self) private var recording
    @Environment(MIDIInput.self) private var midi
    @Environment(ParameterWriter.self) private var writer
    @Environment(JamSession.self) private var jam: JamSession?
    @State private var clickOn = true
    @AppStorage(PlayKeysView.shownKey) private var showsKeys = true
    @AppStorage(FieldWindow.shownKey) private var showsFieldWindow = true
    /// What the Keys switch does under the chosen view; dimmed where the view settles it.
    var keysSwitch = StudioView.KeysSwitch.decides

    /// The Keys switch as VoiceOver says it: its state where it decides, the reason where it does not.
    private var keysValue: String {
        switch keysSwitch {
        case .decides: showsKeys ? "Shown" : "Hidden"
        case .alwaysShown: "Always shown on this view"
        case .neverShown: "Not shown on this view"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Every control in sight, nothing clipped, no sideways scroll (device video 10021) —
            // and on a phone in portrait at most two rows (founder round 2): one row where it
            // fits (iPad, landscape); else the song row over the transport with every switch;
            // else the phone's two rows — song, pulse, Undo/Redo and More; Play, Record, Loop
            // and the tempo — with the rare switches in More. Only large text wraps further.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Theme.Space.s) {
                    transportGroup
                    TempoField()
                    switchesGroup
                    songRow(more: false)
                }
                VStack(spacing: Theme.Space.xs) {
                    songRow(more: false)
                    HStack(spacing: Theme.Space.s) {
                        transportGroup
                        TempoField()
                        switchesGroup
                        Spacer(minLength: 0)
                    }
                }
                VStack(spacing: Theme.Space.xs) {
                    songRow(more: true)
                    HStack(spacing: Theme.Space.s) {
                        transportGroup
                        TempoField(showsSteps: false)
                        Spacer(minLength: 0)
                    }
                }
                VStack(spacing: Theme.Space.xs) {
                    songRow(more: true)
                    HStack(spacing: Theme.Space.s) {
                        transportGroup
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: Theme.Space.s) {
                        TempoField(showsSteps: false)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, Theme.Space.m)
            .padding(.vertical, Theme.Space.xs)
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

    /// The song and its menu, the pulse while a body source is on, Undo and Redo. The song's name
    /// takes what room is left and truncates; nothing else gives way.
    private func songRow(more: Bool) -> some View {
        HStack(spacing: Theme.Space.s) {
            SongMenu()
                .layoutPriority(-1)
            Spacer(minLength: 0)
            PulseReading()
            Button { store.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                .buttonStyle(ToolButtonStyle())
                .shortcut(.undo)
                .disabled(!store.canUndo)
                .accessibilityLabel(store.undoTitle.map { "Undo \($0)" } ?? "Undo")

            Button { store.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                .buttonStyle(ToolButtonStyle())
                .shortcut(.redo)
                .disabled(!store.canRedo)
                .accessibilityLabel(store.redoTitle.map { "Redo \($0)" } ?? "Redo")
            if more { moreMenu }
        }
    }

    /// The switches a phone has no room for: click, MIDI Learn, keys, Field window, automation
    /// writing. The button lights while learning or writing is on, red while writing, so a
    /// state that changes what a touch does is never hidden behind the menu.
    private var moreMenu: some View {
        Menu {
            Toggle(isOn: Binding(get: { clickOn }, set: { clickOn = $0; engine.setClickEnabled($0) })) {
                Label("Click", systemImage: "metronome")
            }
            countInPicker
            Toggle(isOn: Binding(get: { midi.isLearning }, set: { midi.setLearning($0) })) {
                Label("MIDI Learn", systemImage: "slider.horizontal.2.square")
            }
            Toggle(isOn: $showsKeys) {
                Label("Keys", systemImage: "pianokeys")
            }
            .disabled(keysSwitch != .decides)
            Toggle(isOn: $showsFieldWindow) {
                Label("Field Window", systemImage: "rectangle.inset.bottomright.filled")
            }
            Toggle(isOn: Binding(get: { writer.isWriting }, set: { writer.setWriting($0) })) {
                Label("Write Automation", systemImage: "pencil.line")
            }
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuStyle(.button)
        .buttonStyle(ToolButtonStyle(isActive: writer.isWriting || midi.isLearning,
                                     fill: writer.isWriting ? .recording : .chosen))
        .accessibilityLabel("More")
        .accessibilityValue(writer.isWriting ? "Writing automation" : midi.isLearning ? "MIDI Learn on" : "")
    }

    /// The jam's host pressed Play and waits for the next bar line: Stop calls the start off.
    private var countsIn: Bool { jam?.startIsPending == true }

    /// Play, Record and Loop, side by side in every layout. With phones in a jam this phone
    /// hosts, Play waits for the jam's next bar line, so everyone starts together.
    private var transportGroup: some View {
        HStack(spacing: Theme.Space.s) {
            Button {
                if engine.isStalled {
                    engine.restartAudio()
                } else if countsIn {
                    jam?.cancelPendingStart()
                } else if engine.isPlaying {
                    Task { await recording.stopTransport() }
                } else if jam?.playOnTheNextBar() != true {
                    engine.play()
                }
            } label: {
                Image(systemName: engine.isStalled ? "arrow.clockwise" : engine.isPlaying || countsIn ? "stop.fill" : "play.fill")
            }
            // Playing is a signal, not a choice: the glyph turns green on the plain tile.
            .buttonStyle(ToolButtonStyle(isRunning: engine.isPlaying || countsIn))
            .shortcut(.playStop)
            .accessibilityLabel(engine.isStalled ? "Restart Audio" : engine.isPlaying || countsIn ? "Stop" : "Play")
            .accessibilityValue(countsIn ? "Starts on the next bar" : "")
            // When audio could not start, this is the way to try again (ultra-audit R1).
            .disabled(!engine.isRunning && !engine.isStalled)

            RecordButton()
                .shortcut(.record)

            Button { engine.setLoopsSong(!engine.loopsSong) } label: { Image(systemName: "repeat") }
                .buttonStyle(ToolButtonStyle(isActive: engine.loopsSong))
                .shortcut(.loop)
                .accessibilityLabel("Loop")
                .accessibilityValue(engine.loopsSong ? (engine.timecodeRuns ? "On, resting while timecode runs" : "On") : "Off")
                .accessibilityHint("Plays the song from bar 1 again after its last bar.")

            PositionReadout()
        }
    }

    /// Off, one or two bars of click before Record starts a stopped song; a setting of this device.
    private var countInPicker: some View {
        Picker(selection: Binding(get: { engine.countInLength }, set: { engine.setCountInLength($0) })) {
            ForEach(CountIn.Length.allCases, id: \.self) { length in
                Text(length.title).tag(length)
            }
        } label: {
            Label("Count-in", systemImage: "metronome")
        }
    }

    /// The switches: click, MIDI Learn, keys, Field window, automation writing.
    private var switchesGroup: some View {
        HStack(spacing: Theme.Space.s) {
            Button {
                clickOn.toggle()
                engine.setClickEnabled(clickOn)
            } label: {
                Image(systemName: "metronome")
            }
            .buttonStyle(ToolButtonStyle(isActive: clickOn))
            // Held: how many bars Record counts in before a stopped song starts.
            .contextMenu { countInPicker }
            .accessibilityLabel("Click")
            .accessibilityValue(clickOn ? "On" : "Off")
            .accessibilityHint("Touch and hold to choose the count-in before Record.")

            MIDILearnButton()

            Button { showsKeys.toggle() } label: { Image(systemName: "pianokeys") }
                .buttonStyle(ToolButtonStyle(isActive: showsKeys && keysSwitch == .decides))
                .disabled(keysSwitch != .decides)
                .accessibilityLabel("Keys")
                .accessibilityValue(keysValue)
                .accessibilityHint("Shows keys and pads that play the live track.")

            // The Field as a small window over the other views (wave W3).
            Button { showsFieldWindow.toggle() } label: { Image(systemName: "rectangle.inset.bottomright.filled") }
                .buttonStyle(ToolButtonStyle(isActive: showsFieldWindow))
                .accessibilityLabel("Field Window")
                .accessibilityValue(showsFieldWindow ? "Shown" : "Hidden")
                .accessibilityHint("Shows the Field as a small window over the other views.")

            // Automation writing, said in a word: a lone "A" was not understood (device video 10021).
            Button { writer.setWriting(!writer.isWriting) } label: {
                Label("Write", systemImage: "pencil.line")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(ToolButtonStyle(isActive: writer.isWriting, fill: .recording))
            .accessibilityLabel("Write Automation")
            .accessibilityValue(writer.isWriting ? "On" : "Off")
            .accessibilityHint("While playing, moving a control writes it into the song.")
        }
    }

    private var status: some View {
        VStack(spacing: 0) {
            // Work that is not on the disk: nothing else on this strip hides it, MIDI Learn included.
            if let unsaved = documents.saveError {
                Text(unsaved)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.record)
                    .padding(.bottom, Theme.Space.xxs)
            }
            // The menu closed and the export may first wait for the song's audio to decode: without
            // this line nothing on screen said anything was under way (review 2026-10-22).
            if documents.isExporting {
                Text(documents.exportProgress ?? Self.exporting)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .padding(.bottom, Theme.Space.xxs)
            }
            // The learn banner leads the strip and hides nothing under it: a message raised while
            // learning is as true as one raised before (round 4, C4).
            if midi.isLearning {
                Text(learnLine)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.accent)
                    .padding(.bottom, Theme.Space.xxs)
            }
            // What the fingertip on the camera should do (wave W1); its own leaf, so this strip
            // never observes the camera.
            TransportCueLine()
            // The beats a count-in still clicks before Record's downbeat; its own leaf.
            CountInLine()
            // "Loop Record · take N" while a take is cut into passes; its own leaf.
            LoopRecordLine()
            // Hosting, following, or the host lost (W16); its own leaf too.
            JamStatusLine()
            messages
        }
        // A line is said as it arrives, wherever VoiceOver is — in a sheet, over the full-screen
        // Field, in another view; `StatusStrip` decides what and how urgently (W18, M7).
        .onChange(of: statusStrip) { old, new in
            if let said = StatusStrip.announcement(from: old, to: new) { Theme.Accessibility.announce(said) }
        }
        // A problem that stood before the strip did: audio that could not start at launch.
        .onAppear {
            if let said = StatusStrip.announcement(from: StatusStrip(), to: statusStrip) {
                Theme.Accessibility.announce(said)
            }
        }
    }

    private static let exporting = "Exporting the song…"

    private var learnLine: String {
        midi.learnTarget == nil
            ? "MIDI Learn: tap a control, or move one in a plugin."
            : "MIDI Learn: move a knob or fader on your device."
    }

    /// The strip's lines as VoiceOver hears of them. Each one changes with an event, never with the
    /// clock — an export's step at most once a stem — so watching them is no hot state (Law 6).
    private var statusStrip: StatusStrip {
        StatusStrip(saveError: documents.saveError,
                    audioError: engine.lastError,
                    documentError: documents.lastError,
                    notice: Self.notices(engine.notice, engine.plugins.notice),
                    learning: midi.isLearning ? learnLine : nil,
                    exportStep: documents.isExporting ? (documents.exportProgress ?? Self.exporting) : nil,
                    exportResult: spokenExportResult)
    }

    /// The loudness line of the export just made, as it is said: a comma where the screen has a
    /// middle dot, which VoiceOver would name.
    private var spokenExportResult: String? {
        guard documents.lastExportIsNews, let loudness = documents.lastExportLoudness else { return nil }
        return Self.exportText(loudness, separator: ", ", arrow: " to ")
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
                    .padding(.bottom, Theme.Space.xxs)
            }
            if let document = documents.lastError {
                Text(document)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.record)
                    .padding(.bottom, Theme.Space.xxs)
            }
            if quiet, let notice {
                Text(notice)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .padding(.bottom, Theme.Space.xxs)
            }
            if let note = documents.launchNote {
                Text(note)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.record)
                    .padding(.bottom, Theme.Space.xxs)
            }
            // A safe start holds plugins of other makers; this is the one door that loads them.
            if engine.plugins.holdsPlugins {
                Button("Load Plugins from Other Makers") { engine.plugins.loadHeldPlugins() }
                    .buttonStyle(ToolButtonStyle())
                    .padding(.bottom, Theme.Space.xxs)
            }
            if let warning = documents.earlierSongsWarning {
                earlierSongsWarning(warning)
            }
            if let note = documents.earlierSongsNote {
                Text(note)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .padding(.bottom, Theme.Space.xxs)
            }
            // The export just made stands under a message; an older one only alone.
            if let loudness = documents.lastExportLoudness,
               documents.lastExportIsNews
                || (quiet && notice == nil && documents.saveError == nil && documents.launchNote == nil
                    && documents.earlierSongsWarning == nil && documents.earlierSongsNote == nil) {
                // Streaming services turn down what is louder than about -14 LUFS and ask for -1 dBTP.
                Text(Self.exportText(loudness))
                    .font(Theme.Font.caption.monospacedDigit())
                    .foregroundStyle(loudness.truePeak > -1 || !loudness.reachedTarget
                                     ? Theme.Color.warning : Theme.Color.textSecondary)
                    .padding(.bottom, Theme.Space.xxs)
            }
        }
    }

    /// Still true after a Play or another song, so it stays until the musician hides it.
    private func earlierSongsWarning(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Space.s) {
            Text(text)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.record)
            Button { documents.hideEarlierSongsWarning() } label: {
                Image(systemName: "xmark")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .frame(minWidth: Theme.Size.touch, minHeight: Theme.Size.touch)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hide This Message")
        }
        .padding(.bottom, Theme.Space.xxs)
    }

    /// Both notices when both stand — a pause and a plugin that came back — so the later one is
    /// not hidden behind the earlier until the next Play clears both (review 2026-10-21).
    static func notices(_ engine: String?, _ plugins: String?) -> String? {
        let standing = [engine, plugins].compactMap { $0 }
        return standing.isEmpty ? nil : standing.joined(separator: " ")
    }

    /// The export's loudness line. At Off the file's reading, as it always was; brought to a
    /// loudness, the mix before and the file after (CUT), how far the limiter took the peaks down,
    /// and — when a mix's peaks held it down, so more gain made it no louder — that it fell short.
    static func exportText(_ report: MixLoudness.Report, separator: String = " · ", arrow: String = " → ") -> String {
        func value(_ number: Double, _ unit: String) -> String {
            number.isFinite ? NumberText.string(number, decimals: 1, unit: unit) : "silent"
        }
        func change(_ before: Double?, _ after: Double, _ unit: String) -> String {
            guard let before, before.isFinite, after.isFinite else { return value(after, unit) }
            return NumberText.string(before, decimals: 1) + arrow + value(after, unit)
        }
        var text = "Last export: " + change(report.before?.integrated, report.integrated, "LUFS")
            + separator + change(report.before?.truePeak, report.truePeak, "dBTP")
        if report.limited >= 0.05 {
            text += separator + "limited by " + NumberText.string(report.limited, decimals: 1, unit: "dB")
        }
        if !report.reachedTarget, report.integrated.isFinite {
            text += " — it could not reach " + report.loudness.title
        }
        if report.truePeak > -1 { text += " — peaks above −1 dBTP may distort when encoded" }
        return text
    }
}

/// The song position beside the transport as bar.beat.sixteenth ("2.3.1"), in the bars the
/// engine counts. Its own leaf (Law 6): it polls 15 times a second while the song plays, and its
/// timeline is paused while it is stopped, when it reads where the transport rests.
/// A tap while stopped is the second Stop: back to bar 1, and the ruler's cue is forgotten.
private struct PositionReadout: View {
    @Environment(AudioEngine.self) private var engine
    @Environment(ProjectStore.self) private var store
    @Environment(RecordController.self) private var recording
    @Environment(DocumentController.self) private var documents

    var body: some View {
        // Both read here, outside the timeline: a Stop or a locate redraws the resting position.
        let playing = engine.isPlaying
        let resting = Double(engine.restingTick)
        let project = store.project
        TimelineView(.animation(minimumInterval: 1.0 / 15.0, paused: !playing)) { _ in
            let position = TimelineGeometry.position(atPosition: playing ? engine.heardTick(in: project) : resting,
                                                     meter: engine.playedMeterMap(of: project))
            Button { backToStart() } label: {
                Text(position.text)
                    .font(Theme.Font.value)
                    .foregroundStyle(Theme.Color.text)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(minWidth: 72, minHeight: Theme.Size.touch, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Position")
            .accessibilityValue(position.spoken)
            .accessibilityHint(playing ? "" : "Goes back to bar 1.")
        }
    }

    /// Only while stopped — while playing the transport's Stop is the first Stop — and never while
    /// a take records or an export is written.
    private func backToStart() {
        guard !engine.isPlaying,
              TimelineGeometry.mayLocate(recording: recording.isRecording, exporting: documents.isExporting) else { return }
        engine.transportStop()
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
        .buttonStyle(ToolButtonStyle(isActive: recording.isRecording, fill: .recording))
        .accessibilityLabel(recording.isRecording ? "Stop Recording" : "Record")
        .accessibilityHint(recording.armedTrack == nil ? "Records the track the keys play." : "")
        .disabled(!recording.canRecord)
    }
}

/// The camera's cue under the transport, readable: the label size in the secondary text colour,
/// shown only while the camera measures without a lock — the time a fingertip needs telling.
/// Its own leaf, the one view here that observes the camera (Law 6).
private struct TransportCueLine: View {
    @Environment(CameraPulseSource.self) private var camera

    var body: some View {
        if let line = CameraPulseCueLine.line(for: camera.status, cue: camera.cue) {
            Text(line)
                .font(Theme.Font.label)
                .foregroundStyle(Theme.Color.textSecondary)
                .padding(.bottom, Theme.Space.xs)
        }
    }
}

/// "Count-in 3" under the transport while Record counts in, the beats still to click. Its own leaf
/// (Law 6): the beats are polled ten times a second here and observed nowhere else. The number
/// changes once a beat and nothing blinks, far under the 3 Hz flash ceiling.
private struct CountInLine: View {
    @Environment(AudioEngine.self) private var engine

    var body: some View {
        if engine.runningCountIn != nil {
            TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                let left = engine.countInBeatsLeft
                if left > 0 {
                    Text("Count-in \(left)")
                        .font(Theme.Font.label.monospacedDigit())
                        .foregroundStyle(Theme.Color.record)
                        .padding(.bottom, Theme.Space.xs)
                        .accessibilityLabel("Count-in, \(left) beats")
                }
            }
        }
    }
}

/// "Loop Record · take N" under the transport while a take records passes of the loop, so the
/// musician sees takes come into being. Its own leaf (Law 6): the pass number is polled four times
/// a second here and observed nowhere else.
private struct LoopRecordLine: View {
    @Environment(RecordController.self) private var recording

    var body: some View {
        if recording.isLoopRecording {
            TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                Text("Loop Record · take \(recording.loopTakeNumber)")
                    .font(Theme.Font.label)
                    .foregroundStyle(Theme.Color.record)
                    .padding(.bottom, Theme.Space.xs)
                    .accessibilityLabel("Loop Record, take \(recording.loopTakeNumber)")
            }
        }
    }
}

/// A one-time note under the transport about listening level (team SAFE 2026-11-04): inline, not a
/// modal (Law 7), shown until the musician taps OK, then never again on this device. New songs start
/// with the master six decibels down (`StarterProject.masterVolumeDB`); the note says where to raise it.
private struct ListeningNote: View {
    static let seenKey = "safety.listeningNoteSeen"
    @AppStorage(ListeningNote.seenKey) private var seen = false

    var body: some View {
        if !seen {
            HStack(alignment: .top, spacing: Theme.Space.s) {
                Image(systemName: "headphones").accessibilityHidden(true)
                    .foregroundStyle(Theme.Color.textSecondary)
                Text("Listen at a moderate level, especially on headphones: long, loud listening can damage your hearing. A new song starts with the master 6 dB down; raise it on the Mixer.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("OK") { seen = true }
                    .buttonStyle(ToolButtonStyle())
                    .accessibilityLabel("OK, Hide the Listening Note")
            }
            .padding(.horizontal, Theme.Space.l)
            .padding(.vertical, Theme.Space.xs)
            .background(Theme.Color.surface)
        }
    }
}

/// The jam under the transport while there is one: hosting, following, or the host lost — in the
/// warning colour, with the tempo this phone plays on at. Its own leaf, the one view here that
/// reads the jam's phase, which changes only when the jam does (Law 6).
private struct JamStatusLine: View {
    @Environment(JamSession.self) private var jam: JamSession?

    var body: some View {
        // A stack even when it is empty, so the line is said as it changes (`onChange` needs a view).
        VStack(spacing: 0) {
            if let line = jam?.transportLine {
                Text(line.text)
                    .font(Theme.Font.caption)
                    .foregroundStyle(line.warning ? Theme.Color.warning : Theme.Color.textSecondary)
                    .padding(.bottom, Theme.Space.xxs)
            }
        }
        .onChange(of: jam?.transportLine?.text) { old, new in
            if let said = spoken(new, after: old) { Theme.Accessibility.announce(said) }
        }
    }

    /// The line as it changes, wherever VoiceOver is — the Jam page may be closed: a host lost or
    /// gone urgently (W18, M7/m22). The host's own line going back from "Starting on the next
    /// bar." to "Hosting a Jam." is not said: the music starting says it.
    private func spoken(_ text: String?, after previous: String?) -> Announcement? {
        guard let text, let jam else { return nil }
        if previous != nil, jam.role == .hosting, !jam.startIsPending { return nil }
        return Announcement(text, priority: jam.hostIsGone ? .urgent : .normal)
    }
}

/// Tempo as a number you drag vertically (up = faster) or step with the buttons. One drag is
/// one undo step. While an external MIDI clock, a jam's host or Flow (W12) sets the pace, it shows
/// theirs, names it under the number and is locked.
struct TempoField: View {
    @Environment(ProjectStore.self) private var store
    @Environment(MIDIInput.self) private var midi
    @Environment(JamSession.self) private var jam: JamSession?
    @Environment(NumberPadController.self) private var pad: NumberPadController?
    @Environment(FlowController.self) private var flow: FlowController?
    @State private var dragStart: Double?
    @State private var taps = TapTempo()
    @ScaledMetric(relativeTo: .title2) private var valueWidth: CGFloat = 72
    /// The − and + buttons. A phone in portrait leaves them out: the number itself is dragged,
    /// typed on the pad, or adjusted by VoiceOver, and Tap stays.
    var showsSteps = true

    private static let gestureKey = "project.tempo"
    /// Taps get their own key, so a drag or step after a run of taps is its own undo step.
    private static let tapKey = "project.tempo.tap"

    var body: some View {
        HStack(spacing: Theme.Space.xs) {
            if showsSteps {
                Button { nudge(-1) } label: { Image(systemName: "minus") }
                    .buttonStyle(ToolButtonStyle())
                    .accessibilityLabel("Slower")
                    .disabled(followsClock)
            }

            VStack(spacing: 0) {
                // To the hundredth, as typed (100,25), with only the places it needs (120, 100,5).
                Text(NumberText.string(shownTempo, decimalsUpTo: 2))
                    .font(Theme.Font.valueLarge)
                    .foregroundStyle(isTyped ? Theme.Color.accent : Theme.Color.text)
                // "EXT" stands where the unit stands, in the same few letters' room: while an
                // external MIDI clock sets the tempo, the number is the clock's — "JAM" while a jam's
                // host sets it, "FLOW" while the pulse does (T1: the source is always named). A word
                // would not fit under the number; VoiceOver says it in full below, and the line
                // under the transport says "Following the Jam."
                Text(Self.unit(source))
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            // A full touch target to tap or drag, not the number's own ~42 pt (W18, m14).
            .frame(minWidth: valueWidth, minHeight: Theme.Size.touch)
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
            .accessibilityValue(NumberText.string(shownTempo, decimalsUpTo: 2, unit: "BPM") + Self.spoken(source))
            .accessibilityAdjustableAction { direction in
                nudge(direction == .increment ? 1 : -1)
            }
            .accessibilityAction(named: "Type a Tempo", typeTempo)

            if showsSteps {
                Button { nudge(1) } label: { Image(systemName: "plus") }
                    .buttonStyle(ToolButtonStyle())
                    .accessibilityLabel("Faster")
                    .disabled(followsClock)
            }

            Button("Tap", action: tap)
                .buttonStyle(ToolButtonStyle())
                .accessibilityHint("Tap in time to set the tempo.")
                .disabled(followsClock)
        }
    }

    /// A MIDI clock, a jam's host or Flow sets the pace: the field shows theirs and takes no edit.
    private var followsClock: Bool { midi.followedSource != nil || followsJam || flows }

    private var followsJam: Bool { jam?.followsJam == true }

    private var flows: Bool { flow?.lock == .flow }

    /// What sets the pace now (T1).
    private var source: TempoSource {
        TempoSource.current(followsJam: followsJam, followsMIDIClock: midi.followedSource != nil, flows: flows)
    }

    /// The source's name under the number.
    static func unit(_ source: TempoSource) -> String {
        switch source {
        case .song: "BPM"
        case .flow: "FLOW"
        case .midiClock: "EXT"
        case .jam: "JAM"
        }
    }

    /// The source in full, for VoiceOver.
    static func spoken(_ source: TempoSource) -> String {
        switch source {
        case .song: ""
        case .flow: ", Following the Pulse"
        case .midiClock: ", External Clock"
        case .jam: ", Following the Jam"
        }
    }

    private static let padOwner = "project.tempo"

    private var isTyped: Bool { pad?.request?.owner == Self.padOwner }

    /// The tempo on Echoel's number pad, in BPM to a hundredth (100,25, as Ableton types it); one
    /// undo step. Not while an external clock sets the pace.
    private func typeTempo() {
        guard !followsClock, let pad else { return }
        let standard = store.project.descriptor(for: .tempo)?.defaultValue
        pad.open(NumberPadRequest(owner: Self.padOwner, title: "Tempo",
                                  format: NumberEntryFormat(scale: 1, decimals: 2, unit: "BPM"),
                                  range: Tempo.range, value: store.project.tempo, standard: standard) { bpm in
            set(bpm)
            store.endGesture()
        })
    }

    /// While a clock, a jam or Flow sets the pace, the field shows it; the song's own tempo waits
    /// underneath, unchanged.
    private var shownTempo: Double {
        switch source {
        case .jam: jam?.followedTempo ?? store.project.tempo
        case .midiClock: midi.clockTempo ?? store.project.tempo
        case .flow: flow?.shownTempo ?? store.project.tempo
        case .song: store.project.tempo
        }
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
    @Environment(JamSession.self) private var jam: JamSession?
    /// What Export WAV brings the mix to (CUT): kept on this device, never in the song; Off at first.
    @AppStorage(SongMenu.wavLoudnessKey) private var wavLoudness = ExportLoudness.exportDefault

    nonisolated static let wavLoudnessKey = "export.wav.loudness"

    var body: some View {
        Menu {
            // In sections, so twenty entries read as five groups (device video 10021).
            Section("Song") {
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
                // The song itself, with its audio, for another device running Echoel Studio.
                Button("Share Song…", systemImage: "square.and.arrow.up.on.square") {
                    Task {
                        if let url = await documents.shareSong(plugins: engine.plugins) { router.share(url) }
                    }
                }
                .disabled(documents.isExporting)
                // Every sound, video and picture the device holds for Echoel, to hear and place (Recovery 7).
                Button("Browser…", systemImage: "square.grid.2x2") { router.sheet = .browser }
                // A Standard MIDI File as new instrument tracks; an empty song takes its tempo and meter.
                Button("Import MIDI…", systemImage: "square.and.arrow.down") { router.sheet = .importMIDI }
                // The song's subtitles, from Transcribe on a part's hold menu, to edit (SUBS).
                Button("Subtitles…", systemImage: "captions.bubble") { router.sheet = .subtitles }
                keyAndScale
                timeSignatureMenu
            }
            Section("Export") {
                // Why the entries below are dimmed, as a line of the menu that cannot be tapped
                // (W18, m15): a song like Four Tracks opens with every one of them off.
                if let reason = exportWaitReason { Text(reason) }
                Button("Export WAV…", systemImage: "square.and.arrow.up") {
                    Task {
                        // A finished export is the newest news: its loudness line must not wait for a
                        // Play behind an older notice. A notice raised while it ran (a plugin that
                        // stopped mid-render, headphones pulled) is newer still, and stays.
                        let standing = TransportBar.notices(engine.notice, engine.plugins.notice)
                        if let url = await documents.exportWAV(plugins: engine.plugins, loudness: wavLoudness) {
                            if TransportBar.notices(engine.notice, engine.plugins.notice) == standing { engine.clearNotices() }
                            router.share(url)
                        }
                    }
                }
                // Only the arrangement is rendered: without a note or an audio region in it the file
                // would have no length.
                .disabled(documents.isExporting || !store.project.arrangementHasSound)
                wavLoudnessMenu
                // The mix as Headphone Spatial monitoring plays it, sample for sample (Recovery 5).
                Button("Export Spatial Headphone Mix (WAV)…", systemImage: "headphones") {
                    Task {
                        let standing = TransportBar.notices(engine.notice, engine.plugins.notice)
                        if let url = await documents.exportWAV(plugins: engine.plugins, loudness: .off,
                                                               headphoneSpatial: true) {
                            if TransportBar.notices(engine.notice, engine.plugins.notice) == standing { engine.clearNotices() }
                            router.share(url)
                        }
                    }
                }
                .disabled(documents.isExporting || !store.project.arrangementHasSound)
                // One file per track and return the mix hears, for another DAW.
                Button("Export Stems…", systemImage: "square.stack.3d.up") {
                    Task {
                        let standing = TransportBar.notices(engine.notice, engine.plugins.notice)
                        if let folder = await documents.exportStems(plugins: engine.plugins) {
                            if TransportBar.notices(engine.notice, engine.plugins.notice) == standing { engine.clearNotices() }
                            router.share(folder)
                        }
                    }
                }
                .disabled(documents.isExporting || !store.project.arrangementHasSound)
                // Every track on the master as an audio object, the returns as a stereo bed, in one
                // Broadcast Wave file with ADM metadata, for an immersive renderer or a DAW that
                // imports ADM.
                Button("Export ADM BWF (immersive)…", systemImage: "dot.radiowaves.left.and.right") {
                    Task {
                        let standing = TransportBar.notices(engine.notice, engine.plugins.notice)
                        if let url = await documents.exportADMBWF(plugins: engine.plugins) {
                            if TransportBar.notices(engine.notice, engine.plugins.notice) == standing { engine.clearNotices() }
                            router.share(url)
                        }
                    }
                }
                .disabled(documents.isExporting || !store.project.arrangementHasSound)
                Button("Export MIDI…", systemImage: "pianokeys") {
                    if let url = documents.exportMIDI() { router.share(url) }
                }
                .disabled(!store.project.arrangementHasEvents)
                // The arrangement's video and audio regions as an edit decision list with the
                // files beside it, for DaVinci Resolve and any editor (PRO-W1).
                Menu("Export EDL for Resolve", systemImage: "list.and.film") {
                    ForEach(EDLExport.FrameRate.allCases, id: \.self) { rate in
                        Button(rate.title) {
                            Task { if let folder = await documents.exportEDL(rate: rate) { router.share(folder) } }
                        }
                    }
                }
                .disabled(documents.isExporting || !store.project.tracks.contains { !$0.regions.isEmpty })
                // The same regions as an OpenTimelineIO bundle (.otioz) with the files inside, the
                // timeline Resolve reads with its tracks, clips and markers (PRO-W2).
                Menu("Export for Resolve (OTIO)", systemImage: "film.stack") {
                    ForEach(OTIOExport.FrameRate.allCases, id: \.self) { rate in
                        Button(rate.title) {
                            Task { if let url = await documents.exportOTIO(rate: rate) { router.share(url) } }
                        }
                    }
                }
                .disabled(documents.isExporting || !store.project.tracks.contains { !$0.regions.isEmpty })
                // The song as a DAWproject — tracks, clips, notes, tempo, markers and the audio — for
                // Bitwig, Studio One, Cubase and other DAWs (PRO-W2).
                Button("Export DAWproject", systemImage: "square.and.arrow.up.on.square") {
                    Task { if let url = await documents.exportDAWproject() { router.share(url) } }
                }
                .disabled(documents.isExporting || store.project.tracks.isEmpty)
                // The subtitles as SubRip and WebVTT text files, for an editor or a video platform (SUBS).
                Button("Export Subtitles (SRT)…", systemImage: "captions.bubble") {
                    if let url = documents.exportSubtitles(.srt) { router.share(url) }
                }
                .disabled(store.project.subtitles.isEmpty)
                Button("Export Subtitles (WebVTT)…", systemImage: "captions.bubble") {
                    if let url = documents.exportSubtitles(.webVTT) { router.share(url) }
                }
                .disabled(store.project.subtitles.isEmpty)
                // The song as an MP4 for social platforms or a screen: the mix under the video tracks.
                Button("Export Video…", systemImage: "film") { router.sheet = .exportVideo }
                    .disabled(documents.isExporting || VideoPlan.program(of: store.project).isEmpty)
                // The Field alone with transparency (ProRes 4444 or HEVC with alpha), a layer to lay
                // over the picture in Resolve or Final Cut (PRO-W2).
                Menu("Export Field Layer (Alpha)", systemImage: "square.2.layers.3d") {
                    ForEach([VideoExportPlan.Shape.landscape, .vertical, .square, .portrait], id: \.self) { shape in
                        Button(shape.title) {
                            Task {
                                if let url = await documents.exportFieldAlpha(plugins: engine.plugins, shape: shape) {
                                    router.share(url)
                                }
                            }
                        }
                    }
                }
                .disabled(documents.isExporting)
            }
            Section("Play and Sync") {
                // Every track at its pan's place around you, for headphones (Recovery 5). Only what
                // you hear: the song and the stereo export stay as they are.
                Toggle(isOn: Binding(get: { engine.headphoneSpatial }, set: { engine.setHeadphoneSpatial($0) })) {
                    Label("Headphone Spatial Monitor", systemImage: "headphones")
                }
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
                // One external clock at a time: while a jam's host sets the pace, this waits.
                .disabled(jam?.followsJam == true)
                Toggle(isOn: Binding(get: { midi.networkEnabled }, set: { midi.setNetwork($0) })) {
                    Label("Network MIDI", systemImage: "network")
                }
                if midi.networkEnabled { networkHostsMenu }
            }
            Section("Connect") {
                // OSC, ADM-OSC, Art-Net and sACN out (wave W4): every one off until switched on there.
                Button("Connections…", systemImage: "antenna.radiowaves.left.and.right") { router.sheet = .connections }
                midi2Menu
                // MIDI Time Code out and chase (W17-TC): off until chosen there.
                TimecodeMenu()
                // The body as a source (wave W1): off until chosen here — the chest strap or the rear
                // camera, one at a time; only then does iOS ask for Bluetooth or the camera. The pulse
                // shows beside Record while it is measured.
                BodySourceMenu()
                Button("Go Live…", systemImage: "dot.radiowaves.left.and.right") { router.sheet = .streaming }
                // Phones in one room play to one bar (W16): off until the musician hosts or joins.
                Button("Jam…", systemImage: "person.2.wave.2") { router.sheet = .jam }
            }
            Section("App") {
                if agent.isOffered {
                    Button("Assistant…", systemImage: "text.bubble") { router.sheet = .agent }
                }
                Button("Echoelmusic Plugins…", systemImage: "puzzlepiece.extension") { router.sheet = .store }
                // Short chapters on what this build does and where its controls are (Recovery 8).
                Button(StudioPlace.learn.title, systemImage: "book") { router.sheet = .learn }
                Button("About Echoelmusic", systemImage: "info.circle") { router.sheet = .about }
            }
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
        // What the menu holds, by its sections, not only its first two entries (W18, m16).
        .accessibilityHint("Songs, export, sync, connections and About. Songs save automatically.")
        .onAppear { documents.refresh() }
    }

    /// The loudness Export WAV brings the mix to: Off, the mix as it plays; a target with the true
    /// peak at or under −1 dBTP; or Peak, the default, the mix lowered only where it peaks above. The status line then says the mix before and the file after.
    private var wavLoudnessMenu: some View {
        Menu("WAV Loudness: \(wavLoudness.title)", systemImage: "speaker.wave.2") {
            ForEach(ExportLoudness.allCases, id: \.self) { choice in
                Button { wavLoudness = choice } label: {
                    if choice == wavLoudness {
                        Label(choice.title, systemImage: "checkmark")
                    } else {
                        Text(choice.title)
                    }
                }
            }
        }
    }

    /// What the dimmed export entries wait for, or nil while the main ones can run. A song without
    /// video keeps Export Video dimmed for good, which its own name explains; it is not said here.
    private var exportWaitReason: String? {
        if documents.isExporting { return "An export is under way." }
        if !store.project.arrangementHasSound {
            return "Exports render the arrangement. Place a clip with notes or an audio region in Arrange first."
        }
        return nil
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
            // The tone system and concert pitch every built-in tuned voice plays in (synth with all
            // its engines, the Body voice and the choir among them; the sampler's keymapped pitch)
            // and the pitch corrector corrects to. The drum kit is not retuned (a drum note names a
            // drum); a plugin of another maker and MIDI out receive notes, not the tuning. A song
            // stores the system's index and the pitch in hertz.
            Picker("Tone System", selection: Binding(get: { context.tuning }, set: { id in
                pick(.tuning, Double(TuningSystem.library.firstIndex { $0.id == id } ?? 0))
            })) {
                ForEach(TuningSystem.library) { Text($0.name).tag($0.id) }
            }
            .pickerStyle(.menu)
            Menu("Concert Pitch \u{00B7} A = \(NumberText.string(context.concertPitch, decimals: 2, unit: "Hz"))") {
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

    /// The hosts Network MIDI lets in, and only they (`NetworkMIDIAccess`): each can be removed, and
    /// a host connected outside the list can be allowed. Nothing is searched for on the network: a
    /// new host joins the list by connecting during the one-minute window opened here, or by being
    /// connected when Network MIDI is switched on.
    private var networkHostsMenu: some View {
        Menu("Network Hosts", systemImage: "desktopcomputer") {
            if midi.networkPairing {
                Button("Stop Waiting for a Host", systemImage: "xmark.circle") { midi.endNetworkPairing() }
            } else {
                Button("Let a New Host Connect", systemImage: "plus.circle") { midi.pairNetworkHost() }
            }
            Divider()
            if midi.networkContacts.isEmpty && midi.networkStrangers.isEmpty {
                Text("No hosts allowed")
            }
            ForEach(midi.networkContacts.indices, id: \.self) { index in
                let host = midi.networkContacts[index]
                Button(role: .destructive) { midi.removeNetworkHost(host) } label: {
                    Label("Remove \(host.title)", systemImage: "minus.circle")
                }
            }
            if !midi.networkStrangers.isEmpty {
                Divider()
                ForEach(midi.networkStrangers.indices, id: \.self) { index in
                    let host = midi.networkStrangers[index]
                    Button { midi.allowNetworkHost(host) } label: {
                        Label("Allow \(host.title)", systemImage: "checkmark.circle")
                    }
                }
            }
            Divider()
            Text(midi.networkPairing ? "For one minute, any host may connect and joins this list."
                                     : "Only hosts in this list can connect.")
        }
    }

    /// MIDI 2.0 (UMP), in and out, each off until switched on. The other side has to speak MIDI 2.0:
    /// nothing here negotiates it (no MIDI-CI, no Property Exchange).
    private var midi2Menu: some View {
        Menu("MIDI 2.0 (UMP)", systemImage: "pianokeys.inverse") {
            Toggle(isOn: Binding(get: { midi.midi2Enabled }, set: { midi.setMIDI2($0) })) {
                Text("MIDI 2.0 In")
                Text("High-resolution notes and controllers")
            }
            Toggle(isOn: Binding(get: { engine.mpe.midi2Enabled }, set: { engine.mpe.setMIDI2($0) })) {
                Text("MPE Out over MIDI 2.0")
                Text("Source \u{201C}Echoelmusic MPE (MIDI 2.0)\u{201D}, per-note bend")
            }
            Divider()
            Text("The other device or app must support MIDI 2.0.")
            MIDI2UnheardLine()
        }
    }

    /// MPE out (W5b): off until an output is chosen; the live track's notes then go out as a
    /// lower zone, pressure and slide following the body.
    private var mpeMenu: some View {
        Menu("MPE Out", systemImage: "pianokeys") {
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
            if engine.mpe.bodyExpressionWaitsForSharing {
                // A sentence, not a control: it says where the switch is.
                Section("Pressure and Slide follow the body only while Share Body Data is on (Connections).") {}
            }
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
        milliseconds == 0 ? "None" : NumberText.signed(milliseconds, decimals: 0, unit: "ms")
    }
}

/// The views of the studio at the bottom, where the earlier instrument had its bar: seven equal
/// cells, a symbol over the word, the chosen one the off-white tile. Every view is on screen on
/// every phone. As a row of word chips the bar was 536 points wide — on a 390-point screen Field
/// and Sky lay beyond the edge with nothing to hint at them (device recording of build 10068).
private struct SurfaceBar: View {
    @Binding var selection: StudioView.Surface

    private static var items: [StudioView.Surface] { [.instrument, .tracks, .arrange, .session, .mixer, .field, .sky] }

    var body: some View {
        HStack(spacing: Theme.Space.xxs) {
            ForEach(Array(Self.items.enumerated()), id: \.element) { index, surface in
                cell(surface)
                    .shortcut(.view(index))
            }
        }
        .padding(.horizontal, Theme.Space.xs)
        .padding(.vertical, Theme.Space.xs)
        .background(Theme.Color.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.Color.border).frame(height: 1)
        }
        .dynamicTypeSize(...Theme.Accessibility.denseStripLimit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Views")
    }

    private func cell(_ surface: StudioView.Surface) -> some View {
        let chosen = selection == surface
        return Button { selection = surface } label: {
            VStack(spacing: Theme.Space.xxs) {
                Image(systemName: surface.symbol)
                    .font(Theme.Font.label)
                    .accessibilityHidden(true)
                // One line, shrunk before it is cut: "Instrument" is the widest word of the seven.
                Text(surface.title)
                    .font(Theme.Font.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: Theme.Size.touch)
        }
        .buttonStyle(SurfaceCellStyle(isChosen: chosen))
        .animation(Theme.Motion.quick, value: chosen)
        .accessibilityLabel(surface.title)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }
}

/// A cell of the bar of views: the chosen one is the off-white tile with a black label, as every
/// chosen control; the others are plain symbol and word, so seven share a phone's width without
/// seven frames. It has no minimum width of its own — the tool button's 60 points times seven
/// is wider than a phone.
private struct SurfaceCellStyle: ButtonStyle {
    let isChosen: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isChosen ? Theme.Color.onAccent : Theme.Color.text)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .fill(isChosen ? Theme.Color.text : Theme.Color.surface)
            )
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? Theme.Motion.pressedOpacity : 1)
            .animation(Theme.Motion.quick, value: configuration.isPressed)
            .accessibilityShowsLargeContentViewer()
    }
}

/// The locate keys of the hardware keyboard (`ShortcutMap`): Return to bar 1, comma a bar back,
/// period a bar forward — through the transport's locate, as the ruler's tap goes, and refused
/// while a take records or an export is written. Buttons nobody sees, so the keys reach them;
/// they read the playhead only when a key is pressed, never in a body (Law 6).
private struct LocateKeys: View {
    @Environment(AudioEngine.self) private var engine
    @Environment(ProjectStore.self) private var store
    @Environment(RecordController.self) private var recording
    @Environment(DocumentController.self) private var documents

    private static let actions: [ShortcutMap.Action] = [.toStart, .barBack, .barForward]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Self.actions, id: \.self) { action in
                Button { go(action) } label: { EmptyView() }
                    .shortcut(action)
            }
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    private func go(_ action: ShortcutMap.Action) {
        guard TimelineGeometry.mayLocate(recording: recording.isRecording, exporting: documents.isExporting) else { return }
        let project = store.project
        let heard = engine.heardTick(in: project)
        let from = engine.isPlaying && heard.isFinite ? MusicalTime.integer(heard.rounded(.down)) : engine.restingTick
        engine.locate(to: ShortcutMap.locate(action, from: from, meter: engine.playedMeterMap(of: project)))
    }
}

private extension View {
    /// The hardware key `ShortcutMap` gives `action`, on the control that does it.
    @ViewBuilder func shortcut(_ action: ShortcutMap.Action) -> some View {
        if let key = ShortcutMap.key(for: action) {
            keyboardShortcut(KeyEquivalent(key.character), modifiers: key.modifiers)
        } else {
            self
        }
    }
}

private extension ShortcutMap.Key {
    var modifiers: EventModifiers {
        var held: EventModifiers = []
        if command { held.insert(.command) }
        if shift { held.insert(.shift) }
        return held
    }
}

/// How many MIDI 2.0 messages the engine could not hear — its own leaf, because the count moves
/// while a controller plays and the Song menu must not rebuild with it (Law 6).
private struct MIDI2UnheardLine: View {
    @Environment(MIDIInput.self) private var midi

    var body: some View {
        if midi.midi2Enabled, midi.unheardCount > 0 {
            Text("\(midi.unheardCount) messages without a MIDI 1.0 equivalent were not heard")
        }
    }
}

private extension ScenePresence.Phase {
    /// A phase the system adds later counts as the background: a lamp left lit by an app that may
    /// be suspended is the harm, a rig let go too early only waits for the next Play.
    init(_ phase: ScenePhase) {
        switch phase {
        case .active: self = .active
        case .inactive: self = .inactive
        case .background: self = .background
        @unknown default: self = .background
        }
    }
}
