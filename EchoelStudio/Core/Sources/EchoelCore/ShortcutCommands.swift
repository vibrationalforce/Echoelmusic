import Foundation

/// The song edits Siri, Shortcuts, Spotlight and the Action button may ask for (PRO-W1): the safe
/// subset of the command catalog — nothing that deletes, nothing that reaches a file or the
/// network. Each builds ordinary commands from what a spoken request carries (a tempo, a kind of
/// track, a key), validated like every edit, for the app to perform through the one door as ONE
/// undo step. The app's intents add the transport, scene launch and stem export, which are not
/// song edits. Nothing here knows about App Intents.
public enum ShortcutCommands {
    /// The kinds of track a spoken request can add.
    public enum TrackChoice: String, CaseIterable, Sendable {
        case instrument, drums, audio, video

        /// The name a new track of the kind takes before a number: "Drums 2".
        public var baseName: String {
            switch self {
            case .instrument: "Instrument"
            case .drums: "Drums"
            case .audio: "Audio"
            case .video: "Video"
            }
        }
    }

    public enum Failure: Error, Equatable, Sendable, CustomStringConvertible {
        case invalid(String)
        case noScene(number: Int, count: Int)

        public var description: String {
            switch self {
            case .invalid(let reason): reason
            case let .noScene(number, count):
                count == 0 ? "The song has no scenes." : "There is no scene \(number); the song has \(count)."
            }
        }
    }

    /// The song's tempo, 20–999 BPM.
    public static func setTempo(_ bpm: Double, in project: Project) throws -> [Command] {
        try agent(.setTempo(bpm: bpm), in: project)
    }

    /// A new track of `choice`, named `name` or "<Kind> <n>" — a drum track with its kit and a
    /// one-bar beat at bar 1, as the assistant adds one.
    public static func addTrack(_ choice: TrackChoice, name: String? = nil, in project: Project) throws -> [Command] {
        let given = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = given.isEmpty ? defaultName(for: choice, in: project) : given
        let kind: TrackKind = choice == .video ? .video : choice == .audio ? .audio : .instrument
        guard project.canAddTrack(kind) else {
            throw Failure.invalid("The song holds at most \(Track.limit(for: kind)) tracks of this kind.")
        }
        if choice == .video {
            return [.addTrack(id: TrackID(), name: title, kind: .video, index: nil)]
        }
        return try agent(.addTrack(name: title, kind: choice.rawValue, sound: nil), in: project)
    }

    /// The song's key: a root 0 (C) … 11 (B) and a scale. Nothing to do is an error the request says.
    public static func setKey(root: Int, scale: Scale, in project: Project) throws -> [Command] {
        guard MusicalContext.rootRange.contains(root) else { throw Failure.invalid("A key root is 0 (C) to 11 (B).") }
        guard scale != .chromatic else { return [.setScale(.chromatic)] }
        var commands: [Command] = []
        if project.context.root != root { commands.append(.setKeyRoot(root)) }
        if project.context.scale != scale || project.context.unrecognizedScale != nil { commands.append(.setScale(scale)) }
        guard !commands.isEmpty else { throw Failure.invalid("The song is already in \(project.context.title).") }
        return commands
    }

    /// The scene a spoken number names, 1-based in the session's order.
    public static func scene(number: Int, in project: Project) throws -> SceneID {
        guard number >= 1, number <= project.scenes.count else {
            throw Failure.noScene(number: number, count: project.scenes.count)
        }
        return project.scenes[number - 1].id
    }

    /// "<Kind> <n>", the first number no track of the song carries.
    public static func defaultName(for choice: TrackChoice, in project: Project) -> String {
        let taken = Set(project.tracks.map(\.name))
        var number = 1
        while taken.contains("\(choice.baseName) \(number)") { number += 1 }
        return "\(choice.baseName) \(number)"
    }

    private static func agent(_ action: AgentAction, in project: Project) throws -> [Command] {
        do {
            return try AgentTools.commands(for: action, in: project)
        } catch let error as AgentError {
            throw Failure.invalid(error.description)
        }
    }
}
