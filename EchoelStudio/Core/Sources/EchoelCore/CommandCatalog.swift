/// A readable description of every command: a stable name, a title for the Undo menu, a
/// sentence for people and for the agent, and the parameters. The agent's tool list and the
/// MIDI-learn picker are built from this, so a command without an entry cannot exist —
/// `spec(for:)` switches over every `Kind`, and the compiler enforces that the switch is complete.
public struct CommandSpec: Equatable, Sendable {
    /// Stable identifier, e.g. `track.add`. Not stored in a song — a mapping stores a
    /// `ParameterAddress` — but the assistant's instructions name it, so never rename one.
    public let name: String
    /// Shown in the Undo menu: "Undo Add Track".
    public let title: String
    public let summary: String
    public let parameters: [ParameterSpec]
}

public struct ParameterSpec: Equatable, Sendable {
    public enum ValueType: String, Sendable {
        case string, number, integer, boolean, ticks, trackID, clipID, placementID, sceneID, mediaID, regionID, insertID
        case noteList, noteIDList, timeSignature, trackKind, mixerTarget, pointList, controlList
        case placementIDList, regionIDList
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
        case setKeyRoot, setScale, setTuning, setConcertPitch, setSwing
        case addTrack, removeTrack, renameTrack, moveTrack, setTrackColor
        case setInstrumentParameter, loadInstrumentPreset, setInstrumentDevice, setInstrumentSample
        case setInstrumentPlugin, setPluginState
        case addInsert, removeInsert, moveInsert, setInsertBypass, setInsertState
        case addMasterInsert, removeMasterInsert, moveMasterInsert, setMasterInsertBypass, setMasterInsertState
        case addMedia, removeMedia
        case setVolume, setPan, setMute, setSolo, setSend, setOutput, setInput, setMonitor
        case mapMIDI, unmapMIDI, setAutomation
        case setModRoute, removeModRoute
        case createClip, createAudioClip, deleteClip, renameClip, setClipLength
        case addNotes, updateNotes, removeNotes, setControls
        case placeClip, movePlacement, removePlacement
        case placeAudio, moveRegion, trimRegion, removeRegion
        case placeVideo, splitRegion
        case splitPlacement, consolidatePlacements, consolidateRegions
        case addScene, removeScene, renameScene, setSlot
    }

    public var kind: Kind {
        switch self {
        case .renameProject: .renameProject
        case .setTempo: .setTempo
        case .setTimeSignature: .setTimeSignature
        case .setTempoChange: .setTempoChange
        case .removeTempoChange: .removeTempoChange
        case .setKeyRoot: .setKeyRoot
        case .setScale: .setScale
        case .setTuning: .setTuning
        case .setConcertPitch: .setConcertPitch
        case .setSwing: .setSwing
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
        case .addInsert: .addInsert
        case .removeInsert: .removeInsert
        case .moveInsert: .moveInsert
        case .setInsertBypass: .setInsertBypass
        case .setInsertState: .setInsertState
        case .addMasterInsert: .addMasterInsert
        case .removeMasterInsert: .removeMasterInsert
        case .moveMasterInsert: .moveMasterInsert
        case .setMasterInsertBypass: .setMasterInsertBypass
        case .setMasterInsertState: .setMasterInsertState
        case .addMedia: .addMedia
        case .removeMedia: .removeMedia
        case .setVolume: .setVolume
        case .setPan: .setPan
        case .setMute: .setMute
        case .setSolo: .setSolo
        case .setSend: .setSend
        case .setOutput: .setOutput
        case .setInput: .setInput
        case .setMonitor: .setMonitor
        case .mapMIDI: .mapMIDI
        case .unmapMIDI: .unmapMIDI
        case .setAutomation: .setAutomation
        case .setModRoute: .setModRoute
        case .removeModRoute: .removeModRoute
        case .createClip: .createClip
        case .createAudioClip: .createAudioClip
        case .deleteClip: .deleteClip
        case .renameClip: .renameClip
        case .setClipLength: .setClipLength
        case .addNotes: .addNotes
        case .updateNotes: .updateNotes
        case .removeNotes: .removeNotes
        case .setControls: .setControls
        case .placeClip: .placeClip
        case .movePlacement: .movePlacement
        case .removePlacement: .removePlacement
        case .placeAudio: .placeAudio
        case .placeVideo: .placeVideo
        case .splitRegion: .splitRegion
        case .moveRegion: .moveRegion
        case .trimRegion: .trimRegion
        case .removeRegion: .removeRegion
        case .splitPlacement: .splitPlacement
        case .consolidatePlacements: .consolidatePlacements
        case .consolidateRegions: .consolidateRegions
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
        case .setKeyRoot:
            return CommandSpec(name: "context.root", title: "Change Key",
                               summary: "Sets the key's root as a pitch class: 0 = C, 1 = C♯ … 11 = B. Writes no notes.",
                               parameters: [P("root", .integer, "Pitch class 0–11.")])
        case .setScale:
            return CommandSpec(name: "context.scale", title: "Change Scale",
                               summary: "Sets the song's scale. Writes no notes and does not yet constrain played notes; chromatic constrains nothing.",
                               parameters: [P("scale", .string, Scale.allCases.map(\.rawValue).joined(separator: ", ") + ".")])
        case .setTuning:
            return CommandSpec(name: "context.tuning", title: "Change Tone System",
                               summary: "Sets the tone system the song is tuned in, measured from the key's root.",
                               parameters: [P("id", .string, TuningSystem.library.map(\.id).joined(separator: ", ") + ".")])
        case .setConcertPitch:
            return CommandSpec(name: "context.concertPitch", title: "Change Concert Pitch",
                               summary: "Sets the A above middle C in hertz (400–480).",
                               parameters: [P("hertz", .number, "Concert pitch in Hz.")])
        case .setSwing:
            return CommandSpec(name: "context.swing", title: "Change Swing",
                               summary: "How late every second sixteenth note falls: 0 straight, 1 a full triplet feel.",
                               parameters: [P("amount", .number, "Swing 0–1.")])
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
                               summary: "Chooses one of the 12 track colors.",
                               parameters: [P("track", .trackID, "The track."), P("colorIndex", .integer, "Color 0–11.")])
        case .setInstrumentParameter:
            return CommandSpec(name: "instrument.parameter", title: "Change Sound",
                               summary: "Sets one value of an instrument track's built-in instrument, e.g. synth.cutoff in Hz.",
                               parameters: [P("track", .trackID, "An instrument track."),
                                            P("key", .string, "An instrument parameter key: "
                                                + InstrumentDevice.builtIn.flatMap(\.parameters).map(\.key.rawValue).joined(separator: ", ") + "."),
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
                                            P("device", .string, "One of: " + InstrumentDevice.choosable.map(\.rawValue).joined(separator: ", ") + "; plugin needs instrument.plugin first.")])
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
        case .addInsert:
            return CommandSpec(name: "insert.add", title: "Add Effect",
                               summary: "Adds an installed Audio Unit effect to a track's insert chain, before its fader and pan.",
                               parameters: [P("track", .trackID, "The track."),
                                            P("id", .insertID, "Identifier for the insert."),
                                            P("plugin", .string, "The component: type aufx, subtype, manufacturer, name, manufacturer name."),
                                            P("index", .integer, "Position in the chain; appended when omitted.", optional: true)])
        case .removeInsert:
            return CommandSpec(name: "insert.remove", title: "Remove Effect",
                               summary: "Removes an effect from a track's insert chain.",
                               parameters: [P("track", .trackID, "The track."), P("insert", .insertID, "The insert.")])
        case .moveInsert:
            return CommandSpec(name: "insert.move", title: "Move Effect",
                               summary: "Moves an effect to another position in a track's insert chain.",
                               parameters: [P("track", .trackID, "The track."), P("insert", .insertID, "The insert."),
                                            P("toIndex", .integer, "New position in the chain.")])
        case .setInsertBypass:
            return CommandSpec(name: "insert.bypass", title: "Bypass Effect",
                               summary: "Bypasses an effect, or turns it back on; it keeps its place and settings.",
                               parameters: [P("track", .trackID, "The track."), P("insert", .insertID, "The insert."),
                                            P("bypassed", .boolean, "True to bypass.")])
        case .setInsertState:
            return CommandSpec(name: "insert.state", title: "Effect Settings",
                               summary: "Stores the settings an effect reported, so the song reopens with them. Written by the app, not typed.",
                               parameters: [P("track", .trackID, "The track."), P("insert", .insertID, "The insert."),
                                            P("state", .string, "The effect's saved state, at most 8 MB; null to forget it.")])
        case .addMasterInsert:
            return CommandSpec(name: "master.insert.add", title: "Add Master Effect",
                               summary: "Adds an effect to the master's insert chain, after the master fader — where a final limiter goes.",
                               parameters: [P("id", .insertID, "Identifier for the insert."),
                                            P("plugin", .string, "The component: type aufx, subtype, manufacturer, name, manufacturer name."),
                                            P("index", .integer, "Position in the chain; appended when omitted.", optional: true)])
        case .removeMasterInsert:
            return CommandSpec(name: "master.insert.remove", title: "Remove Master Effect",
                               summary: "Removes an effect from the master's insert chain.",
                               parameters: [P("insert", .insertID, "The insert.")])
        case .moveMasterInsert:
            return CommandSpec(name: "master.insert.move", title: "Move Master Effect",
                               summary: "Moves an effect to another position in the master's insert chain.",
                               parameters: [P("insert", .insertID, "The insert."),
                                            P("toIndex", .integer, "New position in the chain.")])
        case .setMasterInsertBypass:
            return CommandSpec(name: "master.insert.bypass", title: "Bypass Master Effect",
                               summary: "Bypasses a master effect, or turns it back on; it keeps its place and settings.",
                               parameters: [P("insert", .insertID, "The insert."), P("bypassed", .boolean, "True to bypass.")])
        case .setMasterInsertState:
            return CommandSpec(name: "master.insert.state", title: "Master Effect Settings",
                               summary: "Stores the settings a master effect reported, so the song reopens with them. Written by the app, not typed.",
                               parameters: [P("insert", .insertID, "The insert."),
                                            P("state", .string, "The effect's saved state, at most 8 MB; null to forget it.")])
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
        case .setSend:
            return CommandSpec(name: "mixer.send", title: "Send",
                               summary: "Sets how much of a track goes into a return track, after its fader and pan; null removes the send.",
                               parameters: [P("track", .trackID, "The sending track (not a return)."),
                                            P("to", .trackID, "The return track."),
                                            P("db", .number, "Send level in dB, as on a fader; omit to remove.", optional: true)])
        case .setOutput:
            return CommandSpec(name: "mixer.output", title: "Track Output",
                               summary: "Plays a track on its own stereo pair of the audio interface, e.g. a channel on a DJ mixer, or back into the master.",
                               parameters: [P("track", .trackID, "The track."),
                                            P("channel", .integer, "First channel of the pair, 0-based and even, from 2 (outputs 3/4); omit for the master.", optional: true)])
        case .setInput:
            return CommandSpec(name: "track.input", title: "Track Input",
                               summary: "Chooses which input of the audio interface an audio track records from.",
                               parameters: [P("track", .trackID, "The audio track."),
                                            P("channel", .integer, "The input, 0-based (0 is input 1); omit for the first.", optional: true)])
        case .setMonitor:
            return CommandSpec(name: "track.monitor", title: "Track Monitoring",
                               summary: "Chooses when an audio track plays its input through its channel strip.",
                               parameters: [P("track", .trackID, "The audio track."),
                                            P("mode", .string, "auto (while armed), in (always) or off. A track is heard only through wired headphones, an audio interface or a line output, never the device's own speaker, Bluetooth, AirPlay or HDMI; the device's own microphone only through wired headphones or an interface.")])
        case .mapMIDI:
            return CommandSpec(name: "midi.map", title: "Learn MIDI",
                               summary: "Makes a controller knob or fader move a parameter across its whole range.",
                               parameters: [P("control", .string, "Channel 0…15 and controller number 0…127."),
                                            P("target", .string, "The parameter address, e.g. track/<id>/mixer.volume.")])
        case .setAutomation:
            return CommandSpec(name: "automation.set", title: "Edit Automation",
                               summary: "Sets how a mixer or instrument parameter moves over the song: straight lines between points. No points removes the automation.",
                               parameters: [P("target", .string, "The parameter address, e.g. track/<id>/mixer.volume."),
                                            P("points", .pointList, "Points of tick and value, ticks rising, values in the parameter's range.")])
        case .setModRoute:
            return CommandSpec(name: "modulation.set", title: "Edit Modulation",
                               summary: "Makes a source (the body's heart rate, HRV, coherence or breath, an LFO, a macro or a MIDI controller) move a parameter by a depth, or changes the route with that id.",
                               parameters: [P("id", .string, "The route's identifier; a new one adds a route."),
                                            P("source", .string, "body.heartRate, body.hrv, body.coherence, body.breath, lfo.1, macro.1 or midi.cc.1."),
                                            P("target", .string, "The parameter address, e.g. track/<id>/mixer.volume."),
                                            P("depth", .number, "−1…1 of the parameter's travel."),
                                            P("curve", .string, "linear or square.", optional: true),
                                            P("polarity", .string, "unipolar (0…1) or bipolar (centered).", optional: true)])
        case .removeModRoute:
            return CommandSpec(name: "modulation.remove", title: "Remove Modulation",
                               summary: "Removes one modulation route.",
                               parameters: [P("id", .string, "The route's identifier.")])
        case .unmapMIDI:
            return CommandSpec(name: "midi.unmap", title: "Forget MIDI",
                               summary: "Stops a controller knob or fader moving anything.",
                               parameters: [P("control", .string, "Channel 0…15 and controller number 0…127.")])
        case .createClip:
            return CommandSpec(name: "clip.create", title: "New Clip",
                               summary: "Creates an empty MIDI clip on an instrument track.",
                               parameters: [P("track", .trackID, "An instrument track."),
                                            P("id", .clipID, "Identifier for the new clip."),
                                            P("name", .string, "Clip name."),
                                            P("length", .ticks, "Loop length in ticks (960 per quarter note).")])
        case .createAudioClip:
            return CommandSpec(name: "clip.createAudio", title: "New Audio Clip",
                               summary: "Creates a session loop on an audio track that plays part of a song file.",
                               parameters: [P("track", .trackID, "An audio track."),
                                            P("id", .clipID, "Identifier for the new clip."),
                                            P("name", .string, "Clip name."),
                                            P("length", .ticks, "Loop length in ticks (960 per quarter note)."),
                                            P("media", .mediaID, "A file in the song's media."),
                                            P("offset", .integer, "First frame of the file that plays.", optional: true),
                                            P("frames", .integer, "How many frames of the file play.")])
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
        case .setControls:
            return CommandSpec(name: "controls.set", title: "Edit Controllers",
                               summary: "Replaces a MIDI clip's pitch bends and controllers.",
                               parameters: [P("clip", .clipID, "The clip."),
                                            P("controls", .controlList, "Bends (0…16383) and controllers (0…119, value 0…127) with their start in ticks.")])
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
        case .placeVideo:
            return CommandSpec(name: "video.place", title: "Place Video",
                               summary: "Puts a whole video file from the song's media on a video track's timeline; the song's mix is its sound.",
                               parameters: [P("track", .trackID, "A video track."),
                                            P("id", .regionID, "Identifier for the region."),
                                            P("media", .mediaID, "A video file in the song's media."),
                                            P("start", .ticks, "Position on the timeline in ticks.")])
        case .splitRegion:
            return CommandSpec(name: "region.split", title: "Split",
                               summary: "Cuts an audio or video region in two where a tick sounds; both parts together play what it played.",
                               parameters: [P("track", .trackID, "The audio or video track."), P("region", .regionID, "The region."),
                                            P("at", .ticks, "Where the cut falls, inside the region, in ticks."),
                                            P("newID", .regionID, "Identifier for the second part.")])
        case .moveRegion:
            return CommandSpec(name: "audio.move", title: "Move Audio",
                               summary: "Moves an audio or video region to a new position on the timeline.",
                               parameters: [P("track", .trackID, "The audio track."), P("region", .regionID, "The region."),
                                            P("start", .ticks, "New position in ticks.")])
        case .trimRegion:
            return CommandSpec(name: "audio.trim", title: "Trim Audio",
                               summary: "Chooses which part of the file an audio or video region plays, in frames of the file (a video's in 48 000 units per second).",
                               parameters: [P("track", .trackID, "The audio track."), P("region", .regionID, "The region."),
                                            P("offset", .integer, "First frame that plays."),
                                            P("length", .integer, "Frames that play, at least 1, ending at or before the file's end.")])
        case .removeRegion:
            return CommandSpec(name: "audio.remove", title: "Delete Audio",
                               summary: "Removes an audio or video region from the timeline; the file stays in the song.",
                               parameters: [P("track", .trackID, "The audio track."), P("region", .regionID, "The region.")])
        case .splitPlacement:
            return CommandSpec(name: "arrangement.split", title: "Split Clip",
                               summary: "Cuts a placed clip in two at a position inside it. A note across the cut ends there and sounds again from it; both halves become clips of their own.",
                               parameters: [P("track", .trackID, "The track."), P("placement", .placementID, "The placement."),
                                            P("at", .ticks, "Song position of the cut in ticks, inside the placed clip."),
                                            P("head", .clipID, "Identifier for the clip before the cut."),
                                            P("tail", .clipID, "Identifier for the clip after the cut."),
                                            P("newPlacement", .placementID, "Identifier for the placement of the part after the cut.")])
        case .consolidatePlacements:
            return CommandSpec(name: "arrangement.consolidate", title: "Consolidate Clips",
                               summary: "Joins two or more placed clips of one track into one new clip that plays what they played.",
                               parameters: [P("track", .trackID, "The track."),
                                            P("placements", .placementIDList, "The placements to join, at least two."),
                                            P("clip", .clipID, "Identifier for the joined clip.")])
        case .consolidateRegions:
            return CommandSpec(name: "region.consolidate", title: "Join Regions",
                               summary: "Joins audio or video regions that are consecutive pieces of one file (as a split leaves them) into one. Overlapping or separate media needs a bounce and is refused.",
                               parameters: [P("track", .trackID, "The audio or video track."),
                                            P("regions", .regionIDList, "The regions to join, at least two.")])
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
