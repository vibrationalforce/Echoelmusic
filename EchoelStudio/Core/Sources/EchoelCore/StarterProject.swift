import Foundation

/// The songs a new song can start from. Each is built through the same commands a musician uses,
/// so the door's checks run on it, and none holds a note: a starter is a place to play, never a
/// composition (docs/dev/NEUPLANUNG_2026-10-18.md §0). Which one a song started from is not stored.
public enum StarterProject: CaseIterable, Sendable {
    /// One instrument track and one scene. A plugged-in keyboard plays the first instrument track at
    /// once, so even the empty song sounds under the musician's hands.
    case empty
    /// Four instrument tracks to sketch on: Keys, Bass and Lead on synth sounds, and Drums with an
    /// empty one-bar pattern ready to fill. Keys comes first on purpose: a plugged-in keyboard plays
    /// the first instrument track, and the drum kit sounds on its drum keys only.
    case fourTracks

    /// The name in the New Song menu.
    public var title: String {
        switch self {
        case .empty: "Empty"
        case .fourTracks: "Four Tracks"
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
        case .fourTracks:
            for (name, preset) in [("Keys", "Soft Keys"), ("Bass", "Sub Bass"), ("Lead", "Square Lead")] {
                let track = TrackID(newID())
                try Command.addTrack(id: track, name: name, kind: .instrument, index: nil).apply(to: &project)
                try Command.loadInstrumentPreset(track, name: preset).apply(to: &project)
            }
            let drums = TrackID(newID()), beat = ClipID(newID())
            try Command.addTrack(id: drums, name: "Drums", kind: .instrument, index: nil).apply(to: &project)
            try Command.setInstrumentDevice(drums, .drums).apply(to: &project)
            try Command.createClip(track: drums, id: beat, name: "Beat", length: MusicalTime.ticksPerBar(project.timeSignature))
                .apply(to: &project)
            try Command.placeClip(track: drums, id: PlacementID(newID()), clip: beat, start: 0).apply(to: &project)
            try Command.addScene(id: SceneID(newID()), name: "Scene 1", index: nil).apply(to: &project)
        }
        return project
    }
}
