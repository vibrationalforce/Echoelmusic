import EchoelCore
import EchoelEngine
import SwiftUI

@main
struct EchoelStudioApp: App {
    @State private var store: ProjectStore
    @State private var engine: AudioEngine
    @State private var documents: DocumentController
    @State private var recording: RecordController
    @State private var plugins = StoreController()
    @State private var midi: MIDIInput
    @State private var writer: ParameterWriter
    @State private var launchpad: LaunchpadController
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // The standard effects load like any Audio Unit once they are registered in this process.
        StandardEffectUnit.register()
        let store = ProjectStore(project: .starter())
        let engine = AudioEngine()
        let documents = DocumentController(store: store)
        _store = State(initialValue: store)
        _engine = State(initialValue: engine)
        _documents = State(initialValue: documents)
        _recording = State(initialValue: RecordController(engine: engine, documents: documents, store: store))
        let writer = ParameterWriter(store: store, engine: engine)
        _writer = State(initialValue: writer)
        let midi = MIDIInput(router: engine.live, store: store, engine: engine, writer: writer)
        _midi = State(initialValue: midi)
        _launchpad = State(initialValue: LaunchpadController(store: store, engine: engine, midi: midi))
        // A control moved in a plugin's own interface: the learn target while learning, else written.
        engine.plugins.onParameterMoved = { [weak writer, weak midi] address, position, phase in
            if let midi, midi.isLearning {
                midi.choose(address)
            } else {
                writer?.pluginMoved(address, to: position, phase: phase)
            }
        }
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            StudioView()
                .environment(store)
                .environment(engine)
                .environment(documents)
                .environment(recording)
                .environment(plugins)
                .environment(midi)
                .environment(writer)
                .preferredColorScheme(.dark)
                .task {
                    documents.restore()
                    engine.start()
                    midi.start()
                    launchpad.start()
                    engine.clock.start()
                }
                .onChange(of: store.project) { _, project in
                    documents.projectChanged()
                    Task { await recording.trackRemoved(from: project) }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            // Plugins keep their settings to themselves until asked; ask before writing the song.
            try? store.perform(engine.plugins.captureCommands(for: store.project), title: "Plugin Settings")
            documents.saveNow()
        }
    }
}

extension Project {
    /// A new project opens with one instrument track and one scene, so the first thing a
    /// musician sees is a place to play, not an empty screen.
    static func starter() -> Project {
        var project = Project(name: "New Song")
        try? Command.addTrack(id: TrackID(), name: "Instrument 1", kind: .instrument, index: nil).apply(to: &project)
        try? Command.addScene(id: SceneID(), name: "Scene 1", index: nil).apply(to: &project)
        return project
    }
}
