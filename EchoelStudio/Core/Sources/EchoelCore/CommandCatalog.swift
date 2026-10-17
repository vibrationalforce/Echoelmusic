/// A readable description of every command: a stable name, a title for the Undo menu, a
/// sentence for people and for the agent, and the parameters. The agent's tool list and the
/// MIDI-learn picker are built from this, so a command without an entry cannot exist —
/// `spec(for:)` switches over every `Kind`, and the compiler enforces that the switch is complete.
public struct CommandSpec: Equatable, Sendable {
    /// Stable identifier, e.g. `track.add`. Stored in MIDI mappings — never rename one.
    public let name: String
    /// Shown in the Undo menu: "Undo Add Track".
    public let title: String
    public let summary: String
    public let parameters: [ParameterSpec]
}

public struct ParameterSpec: Equatable, Sendable {
    public enum ValueType: String, Sendable {
        case string, number, integer, boolean, ticks, trackID, clipID, placementID, sceneID, mediaID, regionID
        case noteList, noteIDList, timeSignature, trackKind, mixerTarget
    }

    public let name: String
    public let type: ValueType
    public let summary: String
    public let isOptional: Bool

    public init(_ name: String, _ type: ValueType, _ summary: String, optional: Bool = false) {
        self.name = name
        self.type = type
        self.summary = summary
        self.isOptional = optional
    }
}

extension Command {
    public enum Kind: String, CaseIterable, Sendable {
        case renameProject, setTempo, setTimeSignature, setTempoChange, removeTempoChange
        case addTrack, removeTrack, renameTrack, moveTrack, setTrackColor
        case setInstrumentParameter, loadInstrumentPreset, setInstrumentDevice, setInstrumentSample
        case setInstrumentPlugin, setPluginState
        case addMedia, removeMedia
        case setVolume, setPan, setMute, setSolo
        case createClip, deleteClip, renameClip, setClipLength
        case addNotes, updateNotes, removeNotes
        case placeClip, movePlacement, removePlacement
        case placeAudio, moveRegion, trimRegion, removeRegion
        case addScene, removeScene, renameScene, setSlot
    }

    public var kind: Kind {
        switch self {
        case .renameProject: .renameProject
        case .setTempo: .setTempo
        case .setTimeSignature: .setTimeSignature
        case .setTempoChange: .setTempoChange
        case .removeTempoChange: .removeTempoChange
        case .addTrack: .addTrack
        case .removeTrack: .removeTrack
        case .renameTrack: .renameTrack
        case .moveTrack: .moveTrack
        case .setTrackColor: .setTrackColor
        case .setInstrumentParameter: .setInstrumentParameter
        case .loadInstrumentPreset: .loadInstrumentPreset
        case .setInstrumentDevice: .setInstrumentDevice
        case .setInstrumentSample: .setInstrumentSample
        case .setInstrumentPlugin: .setInstrumentPlugin
        case .setPluginState: .setPluginState
        case .addMedia: .addMedia
        case .removeMedia: .removeMedia
        case .setVolume: .setVolume
        case .setPan: .setPan
        case .setMute: .setMute
        case .setSolo: .setSolo
        case .createClip: .createClip
        case .deleteClip: .deleteClip
        case .renameClip: .renameClip
        case .setClipLength: .setClipLength
        case .addNotes: .addNotes
        case .updateNotes: .updateNotes
        case .removeNotes: .removeNotes
        case .placeClip: .placeClip
        case .movePlacement: .movePlacement
        case .removePlacement: .removePlacement
        case .placeAudio: .placeAudio
        case .moveRegion: .moveRegion
        case .trimRegion: .trimRegion
        case .removeRegion: .removeRegion
        case .addScene: .addScene
        case .removeScene: .removeScene
        case .renameScene: .renameScene
        case .setSlot: .setSlot
        }
    }
}

public enum CommandCatalog {
    public static var all: [CommandSpec] {
        Command.Kind.allCases.map(spec(for:))
    }

    public static func spec(for kind: Command.Kind) -> CommandSpec {
        typealias P = ParameterSpec
        switch kind {
        case .renameProject:
            return CommandSpec(name: "project.rename", title: "Rename Project",
                               summary: "Gives the project a new name.",
                               parameters: [P("name", .string, "The new name.")])
        case .setTempo:
            return CommandSpec(name: "project.tempo", title: "Change Tempo",
                               summary: "Sets the song tempo in beats per minute (20–999).",
                               parameters: [P("bpm", .number, "Tempo in BPM.")])
        case .setTimeSignature:
            return CommandSpec(name: "project.timeSignature", title: "Change Time Signature",
                               summary: "Sets the time signature, for example 4/4 or 7/8.",
                               parameters: [P("timeSignature", .timeSignature, "Numerator 1–32, denominator 1, 2, 4, 8, 16 or 32.")])
        case .setTempoChange:
            return CommandSpec(name: "tempo.change.set", title: "Set Tempo Change",
                               summary: "From a position after the song start, plays at a new tempo until the next change. Replaces a change at the same position.",
                               parameters: [P("tick", .ticks, "Position in ticks (960 per quarter note), after 0."),
                                            P("bpm", .number, "Tempo in BPM (20–999).")])
        case .removeTempoChange:
            return CommandSpec(name: "tempo.change.remove", title: "Remove Tempo Change",
                               summary: "Removes the tempo change at a position.",
                               parameters: [P("tick", .ticks, "Position of the change in ticks.")])
        case .addTrack:
            return CommandSpec(name: "track.add", title: "Add Track",
                               summary: "Adds an instrument, audio or return track.",
                               parameters: [P("id", .trackID, "Identifier for the new track."),
                                            P("name", .string, "Track name."),
                                            P("kind", .trackKind, "instrument, audio or returnTrack."),
                                            P("index", .integer, "Position in the track list; appended when omitted.", optional: true)])
        case .removeTrack:
            return CommandSpec(name: "track.remove", title: "Delete Track",
                               summary: "Deletes a track with all its clips.",
                               parameters: [P("track", .trackID, "The track to delete.")])
        case .renameTrack:
            return CommandSpec(name: "track.rename", title: "Rename Track",
                               summary: "Gives a track a new name.",
                               parameters: [P("track", .trackID, "The track."), P("name", .string, "The new name.")])
        case .moveTrack:
            return CommandSpec(name: "track.move", title: "Move Track",
                               summary: "Moves a track to another position in the list.",
                               parameters: [P("track", .trackID, "The track."), P("toIndex", .integer, "New position, 0 is first.")])
        case .setTrackColor:
            return CommandSpec(name: "track.color", title: "Change Track Color",
                               summary: "Chooses one of the 12 track colours.",
                               parameters: [P("track", .trackID, "The track."), P("colorIndex", .integer, "Colour 0–11.")])
        case .setInstrumentParameter:
            return CommandSpec(name: "instrument.parameter", title: "Change Sound",
                               summary: "Sets one synth parameter of an instrument track, e.g. synth.cutoff in Hz.",
                               parameters: [P("track", .trackID, "An instrument track."),
                                            P("key", .string, "A synth parameter key: " + SynthParameter.all.map(\.key.rawValue).joined(separator: ", ") + "."),
                                            P("value", .number, "The new value, within the parameter's range.")])
        case .loadInstrumentPreset:
            return CommandSpec(name: "instrument.preset", title: "Load Preset",
                               summary: "Replaces an instrument track's sound with a built-in preset.",
                               parameters: [P("track", .trackID, "An instrument track."),
                                            P("name", .string, "One of: " + InstrumentPreset.all.map(\.name).joined(separator: ", ") + ".")])
        case .setInstrumentDevice:
            return CommandSpec(name: "instrument.device", title: "Change Instrument",
                               summary: "Chooses the built-in instrument that plays an instrument track.",
                               parameters: [P("track", .trackID, "An instrument track."),
                                            P("device", .string, "One of: " + InstrumentDevice.allCases.map(\.rawValue).joined(separator: ", ") + "; plugin needs instrument.plugin first.")])
        case .setInstrumentSample:
            return CommandSpec(name: "instrument.sample", title: "Choose Sample",
                               summary: "Sets the audio file the sampler of an instrument track plays, or clears it.",
                               parameters: [P("track", .trackID, "An instrument track."),
                                            P("media", .mediaID, "A file in the song's media, or null to clear.")])
        case .setInstrumentPlugin:
            return CommandSpec(name: "instrument.plugin", title: "Choose Plugin",
                               summary: "Plays an instrument track through an installed Audio Unit instrument, or clears it and returns to the synth.",
                               parameters: [P("track", .trackID, "An instrument track."),
                                            P("plugin", .string, "The component: type aumu, subtype, manufacturer, name, manufacturer name; null to clear.")])
        case .setPluginState:
            return CommandSpec(name: "instrument.pluginState", title: "Plugin Settings",
                               summary: "Stores the settings a track's plugin reported, so the song reopens with them. Written by the app, not typed.",
                               parameters: [P("track", .trackID, "A track with a plugin."),
                                            P("state", .string, "The plugin's saved state, at most 8 MB; null to forget it.")])
        case .addMedia:
            return CommandSpec(name: "media.add", title: "Import Audio",
                               summary: "Records an audio file the app has copied into the song's Media folder.",
                               parameters: [P("file", .string, "The file: id, name, path inside Media/, frame count, sample rate.")])
        case .removeMedia:
            return CommandSpec(name: "media.remove", title: "Remove Audio",
                               summary: "Removes an audio file from the song; its regions go and samplers that played it fall silent.",
                               parameters: [P("media", .mediaID, "A file in the song's media.")])
        case .setVolume:
            return CommandSpec(name: "mixer.volume", title: "Change Volume",
                               summary: "Sets a fader level in dB (−144 is silence, +6 is the maximum).",
                               parameters: [P("target", .mixerTarget, "A track or the master."), P("db", .number, "Level in dB.")])
        case .setPan:
            return CommandSpec(name: "mixer.pan", title: "Change Pan",
                               summary: "Sets the stereo position from −1 (left) to +1 (right).",
                               parameters: [P("target", .mixerTarget, "A track or the master."), P("pan", .number, "Pan −1…+1.")])
        case .setMute:
            return CommandSpec(name: "mixer.mute", title: "Mute",
                               summary: "Mutes or unmutes a track.",
                               parameters: [P("track", .trackID, "The track."), P("muted", .boolean, "true to mute.")])
        case .setSolo:
            return CommandSpec(name: "mixer.solo", title: "Solo",
                               summary: "Solos or unsolos a track.",
                               parameters: [P("track", .trackID, "The track."), P("soloed", .boolean, "true to solo.")])
        case .createClip:
            return CommandSpec(name: "clip.create", title: "New Clip",
                               summary: "Creates an empty MIDI clip on an instrument track.",
                               parameters: [P("track", .trackID, "An instrument track."),
                                            P("id", .clipID, "Identifier for the new clip."),
                                            P("name", .string, "Clip name."),
                                            P("length", .ticks, "Loop length in ticks (960 per quarter note).")])
        case .deleteClip:
            return CommandSpec(name: "clip.delete", title: "Delete Clip",
                               summary: "Deletes a clip and every place it is used.",
                               parameters: [P("clip", .clipID, "The clip.")])
        case .renameClip:
            return CommandSpec(name: "clip.rename", title: "Rename Clip",
                               summary: "Gives a clip a new name.",
                               parameters: [P("clip", .clipID, "The clip."), P("name", .string, "The new name.")])
        case .setClipLength:
            return CommandSpec(name: "clip.length", title: "Change Clip Length",
                               summary: "Sets a clip's loop length in ticks.",
                               parameters: [P("clip", .clipID, "The clip."), P("length", .ticks, "New length in ticks.")])
        case .addNotes:
            return CommandSpec(name: "notes.add", title: "Add Notes",
                               summary: "Adds notes to a MIDI clip.",
                               parameters: [P("clip", .clipID, "The clip."), P("notes", .noteList, "Notes with pitch, velocity, start and length.")])
        case .updateNotes:
            return CommandSpec(name: "notes.update", title: "Edit Notes",
                               summary: "Changes existing notes (move, resize, velocity), matched by id.",
                               parameters: [P("clip", .clipID, "The clip."), P("notes", .noteList, "The notes in their new form.")])
        case .removeNotes:
            return CommandSpec(name: "notes.remove", title: "Delete Notes",
                               summary: "Deletes notes from a MIDI clip.",
                               parameters: [P("clip", .clipID, "The clip."), P("notes", .noteIDList, "Ids of the notes to delete.")])
        case .placeClip:
            return CommandSpec(name: "arrangement.place", title: "Place Clip",
                               summary: "Puts a clip of a track on the arrangement timeline.",
                               parameters: [P("track", .trackID, "The track that owns the clip."),
                                            P("id", .placementID, "Identifier for the placement."),
                                            P("clip", .clipID, "The clip."),
                                            P("start", .ticks, "Position on the timeline in ticks.")])
        case .movePlacement:
            return CommandSpec(name: "arrangement.move", title: "Move Clip",
                               summary: "Moves a placed clip to a new position on the timeline.",
                               parameters: [P("track", .trackID, "The track."), P("placement", .placementID, "The placement."),
                                            P("start", .ticks, "New position in ticks.")])
        case .removePlacement:
            return CommandSpec(name: "arrangement.remove", title: "Remove Clip from Arrangement",
                               summary: "Removes a placed clip from the timeline; the clip itself stays.",
                               parameters: [P("track", .trackID, "The track."), P("placement", .placementID, "The placement.")])
        case .placeAudio:
            return CommandSpec(name: "audio.place", title: "Place Audio",
                               summary: "Puts a whole audio file from the song's media on an audio track's timeline.",
                               parameters: [P("track", .trackID, "An audio track."),
                                            P("id", .regionID, "Identifier for the region."),
                                            P("media", .mediaID, "A file in the song's media."),
                                            P("start", .ticks, "Position on the timeline in ticks.")])
        case .moveRegion:
            return CommandSpec(name: "audio.move", title: "Move Audio",
                               summary: "Moves an audio region to a new position on the timeline.",
                               parameters: [P("track", .trackID, "The audio track."), P("region", .regionID, "The region."),
                                            P("start", .ticks, "New position in ticks.")])
        case .trimRegion:
            return CommandSpec(name: "audio.trim", title: "Trim Audio",
                               summary: "Chooses which part of the file an audio region plays, in frames of the file.",
                               parameters: [P("track", .trackID, "The audio track."), P("region", .regionID, "The region."),
                                            P("offset", .integer, "First frame that plays."),
                                            P("length", .integer, "Frames that play, at least 1, ending at or before the file's end.")])
        case .removeRegion:
            return CommandSpec(name: "audio.remove", title: "Delete Audio",
                               summary: "Removes an audio region from the timeline; the file stays in the song.",
                               parameters: [P("track", .trackID, "The audio track."), P("region", .regionID, "The region.")])
        case .addScene:
            return CommandSpec(name: "scene.add", title: "Add Scene",
                               summary: "Adds a scene (a row of clip slots) to the session view.",
                               parameters: [P("id", .sceneID, "Identifier for the scene."),
                                            P("name", .string, "Scene name."),
                                            P("index", .integer, "Position; appended when omitted.", optional: true)])
        case .removeScene:
            return CommandSpec(name: "scene.remove", title: "Delete Scene",
                               summary: "Deletes a scene and empties its slots; the clips stay.",
                               parameters: [P("scene", .sceneID, "The scene.")])
        case .renameScene:
            return CommandSpec(name: "scene.rename", title: "Rename Scene",
                               summary: "Gives a scene a new name.",
                               parameters: [P("scene", .sceneID, "The scene."), P("name", .string, "The new name.")])
        case .setSlot:
            return CommandSpec(name: "session.slot", title: "Set Clip Slot",
                               summary: "Puts a clip into a track's slot in a scene, or empties the slot.",
                               parameters: [P("track", .trackID, "The track."), P("scene", .sceneID, "The scene."),
                                            P("clip", .clipID, "The clip; omit to empty the slot.", optional: true)])
        }
    }
}
