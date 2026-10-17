import EchoelCore
import SwiftUI

@main
struct EchoelStudioApp: App {
    @State private var store: ProjectStore
    @State private var engine = AudioEngine()
    @State private var documents: DocumentController
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let store = ProjectStore(project: .starter())
        _store = State(initialValue: store)
        _documents = State(initialValue: DocumentController(store: store))
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            StudioView()
                .environment(store)
                .environment(engine)
                .environment(documents)
                .preferredColorScheme(.dark)
                .task {
                    documents.restore()
                    engine.start()
                }
                .onChange(of: store.project) { documents.projectChanged() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { documents.saveNow() }
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
