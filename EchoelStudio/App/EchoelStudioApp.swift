import EchoelCore
import SwiftUI

@main
struct EchoelStudioApp: App {
    @State private var store = ProjectStore(project: .starter())
    @State private var engine = AudioEngine()

    var body: some SwiftUI.Scene {
        WindowGroup {
            StudioView()
                .environment(store)
                .environment(engine)
                .preferredColorScheme(.dark)
                .task { engine.start() }
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
