import Foundation

/// Names that two or more tracks carry. A song keeps its names and nothing renames them, so a song
/// from before 2026-11-20, when Add Drums numbered by count, can hold two tracks called "Drums 2"
/// (recordings 10083 and 10088). They read alike in the mixer, the arrangement and the session,
/// and VoiceOver would say "Mute Drums 2" twice (MixerView). The track list says so in one line
/// and numbers them in one step; the rename sheet says it while the typed name is another
/// track's. Nothing is refused: two tracks may share a name on purpose.
public enum TrackNaming {
    /// The title of the undo step that numbers the names.
    public static let title = "Number Track Names"

    /// The names two or more tracks carry, each once, in the order of the first track carrying it.
    public static func shared(in project: Project) -> [String] {
        var carriers: [String: Int] = [:]
        for track in project.tracks { carriers[track.name, default: 0] += 1 }
        var names: [String] = []
        for track in project.tracks where carriers[track.name, default: 0] > 1 && !names.contains(track.name) {
            names.append(track.name)
        }
        return names
    }

    /// One rename for every track after the first that carries a shared name, to be performed as
    /// ONE undo step: a name that ends in a number takes the next number above it that no track
    /// carries ("Drums 2" → "Drums 3"), any other name the first free number from 2 ("Bass" →
    /// "Bass 2"). The first track of each name keeps it — except that the Body voice's track keeps
    /// "Body" wherever it stands, because `BodyVoice` finds its track by that name: renamed, the
    /// switch would read off and switching on would add a second voice. Empty when no name is
    /// shared.
    public static func numbering(in project: Project) -> [Command] {
        var taken = project.tracks.map(\.name)
        let voice = BodyVoice.track(in: project)
        var kept: Set<String> = []
        if let voice { kept.insert(voice.name) }
        var commands: [Command] = []
        for track in project.tracks where track.id != voice?.id {
            // The first track of a name keeps it.
            if kept.insert(track.name).inserted { continue }
            let name = renumbered(track.name, taken: taken)
            taken.append(name)
            commands.append(.renameTrack(track.id, name: name))
        }
        return commands
    }

    /// The line the track list shows while a name is shared, nil while none is: "Two tracks are
    /// called “Drums 2”." for one name, "Tracks share the names “Drums 2” and “Bass”." for more.
    public static func notice(in project: Project) -> String? {
        let names = shared(in: project)
        guard let only = names.first else { return nil }
        guard names.count > 1 else {
            let carriers = project.tracks.filter { $0.name == only }.count
            return "\(spelled(carriers)) tracks are called “\(only)”."
        }
        let quoted = names.map { "“\($0)”" }
        let last = quoted[quoted.count - 1]
        return "Tracks share the names \(quoted.dropLast().joined(separator: ", ")) and \(last)."
    }

    /// What the rename sheet says while `name`, trimmed as the door trims it, is the name of a
    /// track other than `track`; nil otherwise. The rename still goes through.
    public static func caption(renaming track: TrackID, to name: String, in project: Project) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, project.tracks.contains(where: { $0.id != track && $0.name == trimmed }) else {
            return nil
        }
        return "Another track is called “\(trimmed)”."
    }

    /// A name for a later track of `name` that no name in `taken` is.
    static func renumbered(_ name: String, taken: [String]) -> String {
        guard let found = finalNumber(of: name) else { return Names.unique(name, taken: taken) }
        let used = Set(taken)
        var n = found.number + 1
        while used.contains(Names.derived(found.stem, suffix: "\(n)")) { n += 1 }
        return Names.derived(found.stem, suffix: "\(n)")
    }

    /// The name before its final number and the number, when the name ends in at most
    /// `Names.maximumDigits` digits after a space ("Drums 2") or is a number ("2"); nil for
    /// "Bass", and for "Bass2", whose digit is part of the word.
    static func finalNumber(of name: String) -> (stem: String, number: Int)? {
        let digits = name.reversed().prefix { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty, digits.count <= Names.maximumDigits,
              let value = Int(String(digits.reversed())) else { return nil }
        let head = name.dropLast(digits.count)
        guard head.isEmpty || head.last == " " else { return nil }
        return (String(head).trimmingCharacters(in: .whitespacesAndNewlines), value)
    }

    /// "Two" … "Nine", then digits: how many tracks carry a name, at the start of a sentence.
    private static func spelled(_ count: Int) -> String {
        let words = ["Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"]
        return (2...9).contains(count) ? words[count - 2] : "\(count)"
    }
}
