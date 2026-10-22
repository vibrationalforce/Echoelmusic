import Foundation

/// The songs a new song can start from. Each is built through the same commands a musician uses,
/// so the door's checks run on it, and none holds a note: a starter is a place to play, never a
/// composition (docs/dev/NEUPLANUNG_2026-10-18.md §0). Which one a song started from is not stored.
public enum StarterProject: CaseIterable, Sendable {
    /// One instrument track and one scene. A plugged-in keyboard plays the first instrument track at
    /// once, so even the empty song sounds under the musician's hands.
    case empty

    /// The name in the New Song menu.
    public var title: String {
        switch self {
        case .empty: "Empty"
        }
    }

    /// The starter as a new song named "New Song". Every id comes from `newID`; the default makes
    /// fresh ones, and that matters: the engine and the app tell tracks apart by id across a song
    /// switch, so two songs sharing an id would share a voice, an armed track and a plugin.
    public func project(newID: () -> UUID = { UUID() }) throws -> Project {
        var project = Project(name: "New Song")
        switch self {
        case .empty:
            try Command.addTrack(id: TrackID(newID()), name: "Instrument 1", kind: .instrument, index: nil)
                .apply(to: &project)
            try Command.addScene(id: SceneID(newID()), name: "Scene 1", index: nil).apply(to: &project)
        }
        return project
    }
}
