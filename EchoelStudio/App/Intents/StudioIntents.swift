import AppIntents
import EchoelCore
import Foundation

/// Siri, Shortcuts, Spotlight and the Action button (PRO-W1, founder 2026-11-04 "Siri control"):
/// the safe subset of what the studio does — play and stop, tempo, a new track of a kind, a
/// scene's launch, the key, a track's mute, the stem export. Every song edit is ordinary commands
/// (`ShortcutCommands`) performed through `ProjectStore.perform` as ONE undo step; nothing here
/// deletes, and nothing reaches the network. Each intent opens the app, because the song and its
/// sound live in the app's process. Phrases in English here, German in `de.lproj/AppShortcuts.strings`.
@MainActor
final class StudioIntentBridge {
    static let shared = StudioIntentBridge()

    weak var store: ProjectStore?
    weak var engine: AudioEngine?
    weak var documents: DocumentController?
    /// Hands a finished export to the share sheet; set by the studio's root view.
    var share: ((URL) -> Void)?

    private init() {}

    /// The open song's store, or the reason there is none yet.
    func requireStore() throws -> ProjectStore {
        guard let store else { throw IntentFailure("Echoelmusic is still opening. Try again in a moment.") }
        return store
    }

    func requireEngine() throws -> AudioEngine {
        guard let engine else { throw IntentFailure("Echoelmusic is still opening. Try again in a moment.") }
        return engine
    }

    /// Performs `commands` as one undo step named `title`; a refusal comes back as what to say.
    func perform(_ commands: [Command], title: String) throws {
        let store = try requireStore()
        do {
            try store.perform(commands, title: title)
        } catch {
            throw IntentFailure("The song did not take that: \(error).")
        }
    }
}

/// What Siri says when a request cannot be done.
struct IntentFailure: Error, CustomLocalizedStringResourceConvertible {
    let message: String
    init(_ message: String) { self.message = message }
    var localizedStringResource: LocalizedStringResource { "\(message)" }
}

private func failure(_ error: Error) -> IntentFailure {
    if let failure = error as? IntentFailure { return failure }
    if let shortcut = error as? ShortcutCommands.Failure { return IntentFailure(shortcut.description) }
    return IntentFailure("\(error)")
}

// MARK: - Entities

/// A track of the open song, for "Mute Bass".
struct TrackEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Track"
    static let defaultQuery = TrackQuery()

    let id: String
    let name: String
    let kind: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(kind)")
    }

    init(_ track: Track) {
        id = track.id.description
        name = track.name
        kind = track.kind == .returnTrack ? "Return" : track.kind.rawValue.capitalized
    }
}

struct TrackQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [TrackEntity] {
        await MainActor.run {
            let tracks = StudioIntentBridge.shared.store?.project.tracks ?? []
            return tracks.filter { identifiers.contains($0.id.description) }.map(TrackEntity.init)
        }
    }

    func entities(matching string: String) async throws -> [TrackEntity] {
        await MainActor.run {
            let tracks = StudioIntentBridge.shared.store?.project.tracks ?? []
            let wanted = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let number = Int(wanted), tracks.indices.contains(number - 1) { return [TrackEntity(tracks[number - 1])] }
            return tracks.filter { $0.name.lowercased().contains(wanted) }.map(TrackEntity.init)
        }
    }

    func suggestedEntities() async throws -> [TrackEntity] {
        await MainActor.run { (StudioIntentBridge.shared.store?.project.tracks ?? []).map(TrackEntity.init) }
    }
}

/// A scene of the open song's session, for "Launch Chorus" or "Launch scene 2".
struct SceneEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Scene"
    static let defaultQuery = SceneQuery()

    let id: String
    let name: String
    let number: Int

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "Scene \(number)")
    }
}

struct SceneQuery: EntityStringQuery {
    @MainActor private static func all() -> [SceneEntity] {
        let scenes = StudioIntentBridge.shared.store?.project.scenes ?? []
        return scenes.enumerated().map { SceneEntity(id: $0.element.id.description, name: $0.element.name, number: $0.offset + 1) }
    }

    func entities(for identifiers: [String]) async throws -> [SceneEntity] {
        await MainActor.run { Self.all().filter { identifiers.contains($0.id) } }
    }

    func entities(matching string: String) async throws -> [SceneEntity] {
        await MainActor.run {
            let wanted = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let scenes = Self.all()
            if let number = Int(wanted) { return scenes.filter { $0.number == number } }
            return scenes.filter { $0.name.lowercased().contains(wanted) }
        }
    }

    func suggestedEntities() async throws -> [SceneEntity] {
        await MainActor.run { Self.all() }
    }
}

enum TrackKindChoice: String, AppEnum {
    case instrument, drums, audio, video

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Track Kind"
    static let caseDisplayRepresentations: [TrackKindChoice: DisplayRepresentation] = [
        .instrument: "Instrument",
        .drums: "Drums",
        .audio: "Audio",
        .video: "Video",
    ]

    var choice: ShortcutCommands.TrackChoice {
        switch self {
        case .instrument: .instrument
        case .drums: .drums
        case .audio: .audio
        case .video: .video
        }
    }
}

enum KeyRootChoice: String, AppEnum {
    case c, cSharp, d, eFlat, e, f, fSharp, g, aFlat, a, bFlat, b

    /// The pitch class, 0 (C) … 11 (B).
    var pitchClass: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Key"
    static let caseDisplayRepresentations: [KeyRootChoice: DisplayRepresentation] = [
        .c: "C", .cSharp: "C♯", .d: "D", .eFlat: "E♭", .e: "E", .f: "F",
        .fSharp: "F♯", .g: "G", .aFlat: "A♭", .a: "A", .bFlat: "B♭", .b: "B",
    ]
}

enum ScaleChoice: String, AppEnum {
    case major, minor, dorian, phrygian, lydian, mixolydian, locrian
    case harmonicMinor, melodicMinor, majorPentatonic, minorPentatonic, blues

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Scale"
    static let caseDisplayRepresentations: [ScaleChoice: DisplayRepresentation] = [
        .major: "Major", .minor: "Minor", .dorian: "Dorian", .phrygian: "Phrygian", .lydian: "Lydian",
        .mixolydian: "Mixolydian", .locrian: "Locrian", .harmonicMinor: "Harmonic Minor",
        .melodicMinor: "Melodic Minor", .majorPentatonic: "Major Pentatonic",
        .minorPentatonic: "Minor Pentatonic", .blues: "Blues",
    ]

    var scale: Scale { Scale(rawValue: rawValue) ?? .major }
}

// MARK: - Intents

struct PlayIntent: AppIntent {
    static let title: LocalizedStringResource = "Play"
    static let description = IntentDescription("Plays the open song from where the playhead stands.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let engine = try StudioIntentBridge.shared.requireEngine()
        engine.play()
        guard engine.isPlaying else { throw IntentFailure("The song cannot play right now.") }
        return .result(dialog: "Playing.")
    }
}

struct StopIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop"
    static let description = IntentDescription("Stops the song and returns to where it plays from: the bar set on the ruler, or bar 1.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try StudioIntentBridge.shared.requireEngine().transportStop()
        return .result(dialog: "Stopped.")
    }
}

struct SetTempoIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Tempo"
    static let description = IntentDescription("Sets the song's tempo in beats per minute (20–999). One undo step.")
    static let openAppWhenRun = true

    @Parameter(title: "Tempo (BPM)")
    var bpm: Double

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let bridge = StudioIntentBridge.shared
        do {
            let commands = try ShortcutCommands.setTempo(bpm, in: try bridge.requireStore().project)
            try bridge.perform(commands, title: "Change Tempo")
        } catch {
            throw failure(error)
        }
        return .result(dialog: "Tempo \(NumberText.string(bpm, decimals: bpm == bpm.rounded() ? 0 : 1)) BPM.")
    }
}

struct AddTrackIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Track"
    static let description = IntentDescription("Adds an instrument, drum, audio or video track to the song. One undo step.")
    static let openAppWhenRun = true

    @Parameter(title: "Kind")
    var kind: TrackKindChoice

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let bridge = StudioIntentBridge.shared
        let name: String
        do {
            let project = try bridge.requireStore().project
            name = ShortcutCommands.defaultName(for: kind.choice, in: project)
            try bridge.perform(try ShortcutCommands.addTrack(kind.choice, name: name, in: project), title: "Add Track")
        } catch {
            throw failure(error)
        }
        return .result(dialog: "Added \(name).")
    }
}

struct LaunchSceneIntent: AppIntent {
    static let title: LocalizedStringResource = "Launch Scene"
    static let description = IntentDescription("Plays every clip of a session scene from the next bar, starting the song if it is stopped.")
    static let openAppWhenRun = true

    @Parameter(title: "Scene")
    var scene: SceneEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let bridge = StudioIntentBridge.shared
        do {
            let store = try bridge.requireStore()
            let engine = try bridge.requireEngine()
            let id = try ShortcutCommands.scene(number: scene.number, in: store.project)
            guard id.description == scene.id else { throw IntentFailure("The scenes changed; choose the scene again.") }
            engine.launch(id, in: store.project)
        } catch {
            throw failure(error)
        }
        return .result(dialog: "Launching \(scene.name).")
    }
}

struct SetKeyIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Key"
    static let description = IntentDescription("Sets the song's key and scale. One undo step.")
    static let openAppWhenRun = true

    @Parameter(title: "Key")
    var root: KeyRootChoice

    @Parameter(title: "Scale")
    var scale: ScaleChoice

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let bridge = StudioIntentBridge.shared
        let title: String
        do {
            let store = try bridge.requireStore()
            try bridge.perform(try ShortcutCommands.setKey(root: root.pitchClass, scale: scale.scale, in: store.project),
                               title: "Change Key")
            title = store.project.context.title
        } catch {
            throw failure(error)
        }
        return .result(dialog: "The song is in \(title).")
    }
}

struct MuteTrackIntent: AppIntent {
    static let title: LocalizedStringResource = "Mute or Unmute Track"
    static let description = IntentDescription("Mutes a track, or unmutes it when it is muted. One undo step.")
    static let openAppWhenRun = true

    @Parameter(title: "Track")
    var track: TrackEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let bridge = StudioIntentBridge.shared
        let muted: Bool
        do {
            let store = try bridge.requireStore()
            guard let found = store.project.tracks.first(where: { $0.id.description == track.id }) else {
                throw IntentFailure("There is no track \(track.name) in the open song.")
            }
            muted = !found.mixer.isMuted
            try bridge.perform([.setMute(found.id, muted)], title: muted ? "Mute" : "Unmute")
        } catch {
            throw failure(error)
        }
        let line = muted ? "\(track.name) muted." : "\(track.name) unmuted."
        return .result(dialog: "\(line)")
    }
}

struct ExportStemsIntent: AppIntent {
    static let title: LocalizedStringResource = "Export Stems"
    static let description = IntentDescription("Renders one WAV per track the mix hears, with the song's markers as cue points, and opens the share sheet.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let bridge = StudioIntentBridge.shared
        guard let documents = bridge.documents else { throw IntentFailure("Echoelmusic is still opening. Try again in a moment.") }
        let engine = try bridge.requireEngine()
        // An export that already runs refuses a second one without a word: `exportStems` answers
        // nil and leaves `lastError` as it was. Said here, or the line below speaks whatever stood
        // there from something else.
        guard !documents.isExporting else {
            throw IntentFailure("Echoelmusic is exporting already. Try again when that export is done.")
        }
        guard let folder = await documents.exportStems(plugins: engine.plugins) else {
            throw IntentFailure(documents.lastError ?? "The stems could not be exported.")
        }
        bridge.share?(folder)
        return .result(dialog: "The stems are ready to share.")
    }
}

// MARK: - Phrases

struct StudioShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: PlayIntent(), phrases: [
            "Play \(.applicationName)",
            "Start \(.applicationName)",
        ], shortTitle: "Play", systemImageName: "play.fill")
        AppShortcut(intent: StopIntent(), phrases: [
            "Stop \(.applicationName)",
        ], shortTitle: "Stop", systemImageName: "stop.fill")
        AppShortcut(intent: SetTempoIntent(), phrases: [
            "Set the tempo in \(.applicationName)",
            "Change the tempo in \(.applicationName)",
        ], shortTitle: "Set Tempo", systemImageName: "metronome")
        AppShortcut(intent: AddTrackIntent(), phrases: [
            "Add a \(\.$kind) track in \(.applicationName)",
            "New \(\.$kind) track in \(.applicationName)",
        ], shortTitle: "Add Track", systemImageName: "plus.rectangle.on.rectangle")
        AppShortcut(intent: LaunchSceneIntent(), phrases: [
            "Launch \(\.$scene) in \(.applicationName)",
            "Launch a scene in \(.applicationName)",
        ], shortTitle: "Launch Scene", systemImageName: "play.square.stack")
        AppShortcut(intent: SetKeyIntent(), phrases: [
            "Set the key in \(.applicationName)",
        ], shortTitle: "Set Key", systemImageName: "music.note")
        AppShortcut(intent: MuteTrackIntent(), phrases: [
            "Mute \(\.$track) in \(.applicationName)",
        ], shortTitle: "Mute Track", systemImageName: "speaker.slash")
        AppShortcut(intent: ExportStemsIntent(), phrases: [
            "Export stems in \(.applicationName)",
        ], shortTitle: "Export Stems", systemImageName: "square.stack.3d.up")
    }
}
