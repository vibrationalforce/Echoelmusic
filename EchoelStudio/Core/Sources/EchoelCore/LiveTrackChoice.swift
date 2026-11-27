/// One track the keys on the screen can be pointed at, for the menu in their header ("Plays Keys"):
/// every instrument track of the song, in song order, because only an instrument track plays from
/// keys. A name that two of them share is told apart by the track's place in the song, so the menu
/// never offers two choices that read the same (two tracks called "Drums 2", A88-2).
///
/// Which track plays is the engine's (`AudioEngine.liveTrack`, kept for the session, never in the
/// song): a choice here only names it. What a take writes stays what the keys play: no choice
/// while one records (`offersMenu`), and a choice takes an armed instrument track's arm along
/// (`movesArm`). Pure, so the list, its words and both rules are tested here.
public struct LiveTrackChoice: Equatable, Sendable, Identifiable {
    public let id: TrackID
    /// What the menu shows and says: the track's name, and its place in the song ("Drums 2, track
    /// 4") when another instrument track carries the same name. A comma, not a dot, so VoiceOver
    /// reads it as words.
    public let label: String

    /// The instrument tracks of `project`, in song order.
    public static func choices(in project: Project) -> [LiveTrackChoice] {
        let playable = project.tracks.enumerated().filter { $0.element.kind == .instrument }
        var count: [String: Int] = [:]
        for entry in playable { count[entry.element.name, default: 0] += 1 }
        return playable.map { entry in
            let name = entry.element.name
            let shared = (count[name] ?? 0) > 1
            return LiveTrackChoice(id: entry.element.id, label: shared ? "\(name), track \(entry.offset + 1)" : name)
        }
    }

    /// The header over the keys for the track they play: "Plays Keys". A track that is gone or
    /// cannot play from keys reads as the first instrument track, which the engine then plays
    /// (`AudioEngine.liveTrackID(in:)`); a song without one says so.
    public static func header(live: TrackID?, in project: Project) -> String {
        let all = choices(in: project)
        guard let choice = all.first(where: { $0.id == live }) ?? all.first else { return "No instrument track" }
        return "Plays \(choice.label)"
    }

    /// Whether the header is a menu: with two choices or more, and never while a take records. A
    /// take is written to the track that was armed when it began, while the keys sound on the live
    /// track; pointed elsewhere mid-take, they would play one track and write the notes to another.
    public static func offersMenu(_ choices: [LiveTrackChoice], recording: Bool) -> Bool {
        choices.count > 1 && !recording
    }

    /// Whether choosing `track` for the keys also moves the arm to it: when another instrument track
    /// is armed. Record writes to the armed track, and with nothing armed it arms the track the keys
    /// play — so after a first take that track stays armed, and the next take would land on a track
    /// the keys no longer play. An armed audio track keeps its arm: it records its input, never the
    /// keys.
    public static func movesArm(to track: TrackID, armed: TrackID?, in project: Project) -> Bool {
        guard let armed, armed != track else { return false }
        return project.track(armed)?.kind == .instrument && project.track(track)?.kind == .instrument
    }
}
