import Foundation

/// Every change to a `Project` is one of these. The UI, MIDI-learn and the agent all build
/// commands and hand them to `ProjectStore`; nothing edits the document any other way.
/// That single door is what makes undo, saving, controller mapping and the agent agree.
public enum Command: Codable, Equatable, Sendable {
    // Project
    case renameProject(name: String)
    case setTempo(bpm: Double)
    case setTimeSignature(TimeSignature)
    case setTempoChange(at: Tick, bpm: Double)
    case removeTempoChange(at: Tick)

    // Tracks
    case addTrack(id: TrackID, name: String, kind: TrackKind, index: Int?)
    case removeTrack(TrackID)
    case renameTrack(TrackID, name: String)
    case moveTrack(TrackID, toIndex: Int)
    case setTrackColor(TrackID, colorIndex: Int)

    // Instrument
    case setInstrumentParameter(TrackID, key: String, value: Double)
    case loadInstrumentPreset(TrackID, name: String)
    case setInstrumentDevice(TrackID, InstrumentDevice)
    case setInstrumentSample(TrackID, MediaID?)
    case setInstrumentPlugin(TrackID, PluginComponent?)
    case setPluginState(TrackID, Data?)

    // Inserts
    case addInsert(track: TrackID, id: InsertID, plugin: PluginComponent, index: Int?)
    case removeInsert(track: TrackID, InsertID)
    case moveInsert(track: TrackID, InsertID, toIndex: Int)
    case setInsertBypass(track: TrackID, InsertID, Bool)
    case setInsertState(track: TrackID, InsertID, Data?)
    /// The master's insert chain, after the master fader. Same rules as a track's.
    case addMasterInsert(id: InsertID, plugin: PluginComponent, index: Int?)
    case removeMasterInsert(InsertID)
    case moveMasterInsert(InsertID, toIndex: Int)
    case setMasterInsertBypass(InsertID, Bool)
    case setMasterInsertState(InsertID, Data?)
    case addMedia(MediaFile)
    case removeMedia(MediaID)

    // Mixer
    case setVolume(MixerTarget, db: Double)
    case setPan(MixerTarget, pan: Double)
    case setMute(TrackID, Bool)
    case setSolo(TrackID, Bool)
    /// Sets a track's send into a return track; nil removes the send.
    case setSend(track: TrackID, to: TrackID, db: Double?)
    /// Plays a track on a stereo pair of the interface (its first channel, 0-based and even, at
    /// least 2), or into the master with nil.
    case setOutput(TrackID, channel: Int?)
    /// The interface input an audio track records from (0-based), or the first with nil.
    case setInput(TrackID, channel: Int?)
    /// When an audio track plays its input through its strip.
    case setMonitor(TrackID, MonitorMode)

    // MIDI
    /// Makes `control` move `target`, replacing whatever it moved before.
    case mapMIDI(MIDIControl, ParameterAddress)
    case unmapMIDI(MIDIControl)
    /// Replaces the automation of `target` with `points`; none removes the lane.
    case setAutomation(ParameterAddress, points: [AutomationPoint])

    // Clips
    case createClip(track: TrackID, id: ClipID, name: String, length: Tick)
    /// An audio clip on an audio track: a session loop of `length` ticks playing a song file.
    case createAudioClip(track: TrackID, id: ClipID, name: String, length: Tick, audio: ClipAudio)
    case deleteClip(ClipID)
    case renameClip(ClipID, name: String)
    case setClipLength(ClipID, length: Tick)

    // Notes
    case addNotes(ClipID, [Note])
    case updateNotes(ClipID, [Note])
    case removeNotes(ClipID, [NoteID])
    /// Replaces a MIDI clip's pitch bends and controllers with `controls`; none clears them.
    case setControls(ClipID, [ControlChange])

    // Arrangement
    case placeClip(track: TrackID, id: PlacementID, clip: ClipID, start: Tick)
    case movePlacement(track: TrackID, PlacementID, start: Tick)
    case removePlacement(track: TrackID, PlacementID)

    // Audio regions
    case placeAudio(track: TrackID, id: RegionID, media: MediaID, start: Tick)
    case moveRegion(track: TrackID, RegionID, start: Tick)
    case trimRegion(track: TrackID, RegionID, offset: Int, length: Int)
    case removeRegion(track: TrackID, RegionID)

    // Session
    case addScene(id: SceneID, name: String, index: Int?)
    case removeScene(SceneID)
    case renameScene(SceneID, name: String)
    case setSlot(track: TrackID, scene: SceneID, clip: ClipID?)
}

public enum MixerTarget: Codable, Equatable, Hashable, Sendable {
    case track(TrackID)
    case master
}

public enum CommandError: Error, Equatable, Sendable {
    case unknownTrack(TrackID)
    case unknownClip(ClipID)
    case unknownPlacement(PlacementID)
    case unknownScene(SceneID)
    case unknownNote(NoteID)
    case unknownMedia(MediaID)
    case unknownRegion(RegionID)
    case unknownInsert(InsertID)
    case duplicateID(String)
    case invalidValue(parameter: String, reason: String)
}

public enum Names {
    public static let maximumLength = 128

    /// Trimmed, non-empty, at most `maximumLength` characters.
    static func validated(_ name: String, parameter: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CommandError.invalidValue(parameter: parameter, reason: "must not be empty")
        }
        guard trimmed.count <= maximumLength else {
            throw CommandError.invalidValue(parameter: parameter, reason: "longer than \(maximumLength) characters")
        }
        return trimmed
    }
}

extension Command {
    /// Applies the command to `project`, or throws and leaves it untouched.
    public func apply(to project: inout Project) throws {
        switch self {
        case .renameProject(let name):
            project.name = try Names.validated(name, parameter: "name")

        case .setTempo(let bpm):
            guard bpm.isFinite, Tempo.range.contains(bpm) else {
                throw CommandError.invalidValue(parameter: "bpm", reason: "must be within \(Tempo.range)")
            }
            project.tempo = bpm

        case .setTimeSignature(let signature):
            guard signature.isValid else {
                throw CommandError.invalidValue(parameter: "timeSignature", reason: "numerator 1…32, denominator a power of two up to 32")
            }
            project.timeSignature = signature

        case let .setTempoChange(tick, bpm):
            guard tick > 0, tick <= MusicalTime.maximumTick else {
                throw CommandError.invalidValue(parameter: "tick", reason: "must be within 1…\(MusicalTime.maximumTick); tick 0 is the project tempo")
            }
            guard bpm.isFinite, Tempo.range.contains(bpm) else {
                throw CommandError.invalidValue(parameter: "bpm", reason: "must be within \(Tempo.range)")
            }
            project.tempoChanges.removeAll { $0.tick == tick }
            project.tempoChanges.append(TempoChange(tick: tick, bpm: bpm))
            project.tempoChanges.sort { $0.tick < $1.tick }

        case .removeTempoChange(let tick):
            guard project.tempoChanges.contains(where: { $0.tick == tick }) else {
                throw CommandError.invalidValue(parameter: "tick", reason: "no tempo change at \(tick)")
            }
            project.tempoChanges.removeAll { $0.tick == tick }

        case let .addTrack(id, name, kind, index):
            guard project.trackIndex(id) == nil else { throw CommandError.duplicateID(id.description) }
            let track = Track(id: id, name: try Names.validated(name, parameter: "name"), kind: kind,
                              colorIndex: project.tracks.count % Palette.trackColorCount)
            let at = index ?? project.tracks.count
            guard (0...project.tracks.count).contains(at) else {
                throw CommandError.invalidValue(parameter: "index", reason: "must be within 0…\(project.tracks.count)")
            }
            project.tracks.insert(track, at: at)

        case .removeTrack(let id):
            let t = try project.requireTrack(id)
            project.tracks.remove(at: t)
            // Nothing may send into a return that is gone, and no controller may move its controls.
            for i in project.tracks.indices { project.tracks[i].sends.removeAll { $0.target == id } }
            project.midiMappings.removeAll { $0.target.involves(id) }
            project.automation.removeAll { $0.target.involves(id) }

        case let .renameTrack(id, name):
            let t = try project.requireTrack(id)
            project.tracks[t].name = try Names.validated(name, parameter: "name")

        case let .moveTrack(id, toIndex):
            let t = try project.requireTrack(id)
            guard project.tracks.indices.contains(toIndex) else {
                throw CommandError.invalidValue(parameter: "toIndex", reason: "must be within 0…\(project.tracks.count - 1)")
            }
            let track = project.tracks.remove(at: t)
            project.tracks.insert(track, at: toIndex)

        case let .setTrackColor(id, colorIndex):
            let t = try project.requireTrack(id)
            guard (0..<Palette.trackColorCount).contains(colorIndex) else {
                throw CommandError.invalidValue(parameter: "colorIndex", reason: "must be within 0…\(Palette.trackColorCount - 1)")
            }
            project.tracks[t].colorIndex = colorIndex

        case let .setInstrumentParameter(id, key, value):
            let t = try project.requireTrack(id)
            guard project.tracks[t].kind == .instrument else {
                throw CommandError.invalidValue(parameter: "track", reason: "only instrument tracks have a synth")
            }
            guard let parameter = SynthParameter.named(ParameterKey(rawValue: key)) else {
                throw CommandError.invalidValue(parameter: "key", reason: "no synth parameter named \(key)")
            }
            guard parameter.accepts(value) else {
                throw CommandError.invalidValue(parameter: "value", reason: "must be within \(parameter.range)")
            }
            project.tracks[t].instrument.values[key] = value

        case let .loadInstrumentPreset(id, name):
            let t = try project.requireTrack(id)
            guard project.tracks[t].kind == .instrument else {
                throw CommandError.invalidValue(parameter: "track", reason: "only instrument tracks have a synth")
            }
            guard let preset = InstrumentPreset.named(name) else {
                throw CommandError.invalidValue(parameter: "name", reason: "no preset named \(name)")
            }
            var settings = project.tracks[t].instrument
            settings.preset = preset.name
            settings.values = preset.values
            project.tracks[t].instrument = settings

        case let .setInstrumentDevice(id, device):
            let t = try project.requireTrack(id)
            guard project.tracks[t].kind == .instrument else {
                throw CommandError.invalidValue(parameter: "track", reason: "only instrument tracks have an instrument")
            }
            guard device != .plugin || project.tracks[t].instrument.plugin != nil else {
                throw CommandError.invalidValue(parameter: "device", reason: "choose a plugin with instrument.plugin first")
            }
            project.tracks[t].instrument.device = device

        case let .setInstrumentSample(id, media):
            let t = try project.requireTrack(id)
            guard project.tracks[t].kind == .instrument else {
                throw CommandError.invalidValue(parameter: "track", reason: "only instrument tracks have an instrument")
            }
            if let media, project.mediaFile(media) == nil { throw CommandError.unknownMedia(media) }
            project.tracks[t].instrument.sample = media

        case let .setInstrumentPlugin(id, component):
            let t = try project.requireTrack(id)
            guard project.tracks[t].kind == .instrument else {
                throw CommandError.invalidValue(parameter: "track", reason: "only instrument tracks have an instrument")
            }
            guard let component else {
                project.forgetParameters(of: .instrument, on: id)
                project.tracks[t].instrument.plugin = nil
                project.tracks[t].instrument.pluginState = nil
                if project.tracks[t].instrument.device == .plugin { project.tracks[t].instrument.device = .synth }
                break
            }
            guard component.role == .instrument else {
                throw CommandError.invalidValue(parameter: "plugin", reason: "must be an instrument (type aumu)")
            }
            var named = component
            named.name = try Names.validated(component.name, parameter: "name")
            // Another plugin's settings mean nothing to this one.
            if project.tracks[t].instrument.plugin != named {
                project.tracks[t].instrument.pluginState = nil
                project.forgetParameters(of: .instrument, on: id)
            }
            project.tracks[t].instrument.plugin = named
            project.tracks[t].instrument.device = .plugin

        case let .setPluginState(id, state):
            let t = try project.requireTrack(id)
            guard project.tracks[t].instrument.plugin != nil else {
                throw CommandError.invalidValue(parameter: "track", reason: "the track has no plugin")
            }
            if let state, state.count > PluginComponent.maximumStateBytes {
                throw CommandError.invalidValue(parameter: "state", reason: "larger than \(PluginComponent.maximumStateBytes) bytes")
            }
            project.tracks[t].instrument.pluginState = state

        case let .addInsert(trackID, id, plugin, index):
            let t = try project.requireTrack(trackID)
            guard !project.hasInsert(id) else { throw CommandError.duplicateID(id.description) }
            guard plugin.role == .effect else {
                throw CommandError.invalidValue(parameter: "plugin", reason: "must be an effect (type aufx)")
            }
            guard project.tracks[t].inserts.count < Insert.maximumPerTrack else {
                throw CommandError.invalidValue(parameter: "track", reason: "has \(Insert.maximumPerTrack) inserts already")
            }
            let at = index ?? project.tracks[t].inserts.count
            guard (0...project.tracks[t].inserts.count).contains(at) else {
                throw CommandError.invalidValue(parameter: "index", reason: "must be within 0…\(project.tracks[t].inserts.count)")
            }
            var named = plugin
            named.name = try Names.validated(plugin.name, parameter: "name")
            project.tracks[t].inserts.insert(Insert(id: id, plugin: named), at: at)

        case let .removeInsert(trackID, id):
            let (t, i) = try project.requireInsert(id, on: trackID)
            project.tracks[t].inserts.remove(at: i)
            project.forgetParameters(of: .insert(id), on: trackID)

        case let .moveInsert(trackID, id, toIndex):
            let (t, i) = try project.requireInsert(id, on: trackID)
            guard project.tracks[t].inserts.indices.contains(toIndex) else {
                throw CommandError.invalidValue(parameter: "toIndex", reason: "must be within 0…\(project.tracks[t].inserts.count - 1)")
            }
            let insert = project.tracks[t].inserts.remove(at: i)
            project.tracks[t].inserts.insert(insert, at: toIndex)

        case let .setInsertBypass(trackID, id, bypassed):
            let (t, i) = try project.requireInsert(id, on: trackID)
            project.tracks[t].inserts[i].isBypassed = bypassed

        case let .setInsertState(trackID, id, state):
            let (t, i) = try project.requireInsert(id, on: trackID)
            if let state, state.count > PluginComponent.maximumStateBytes {
                throw CommandError.invalidValue(parameter: "state", reason: "larger than \(PluginComponent.maximumStateBytes) bytes")
            }
            project.tracks[t].inserts[i].state = state

        case let .addMasterInsert(id, plugin, index):
            guard !project.hasInsert(id) else { throw CommandError.duplicateID(id.description) }
            guard plugin.role == .effect else {
                throw CommandError.invalidValue(parameter: "plugin", reason: "must be an effect (type aufx)")
            }
            guard project.masterInserts.count < Insert.maximumPerTrack else {
                throw CommandError.invalidValue(parameter: "master", reason: "has \(Insert.maximumPerTrack) inserts already")
            }
            let at = index ?? project.masterInserts.count
            guard (0...project.masterInserts.count).contains(at) else {
                throw CommandError.invalidValue(parameter: "index", reason: "must be within 0…\(project.masterInserts.count)")
            }
            var named = plugin
            named.name = try Names.validated(plugin.name, parameter: "name")
            project.masterInserts.insert(Insert(id: id, plugin: named), at: at)

        case .removeMasterInsert(let id):
            let i = try project.requireMasterInsert(id)
            project.masterInserts.remove(at: i)
            project.forgetParameters(of: .insert(id), owner: .master)

        case let .moveMasterInsert(id, toIndex):
            let i = try project.requireMasterInsert(id)
            guard project.masterInserts.indices.contains(toIndex) else {
                throw CommandError.invalidValue(parameter: "toIndex", reason: "must be within 0…\(project.masterInserts.count - 1)")
            }
            let insert = project.masterInserts.remove(at: i)
            project.masterInserts.insert(insert, at: toIndex)

        case let .setMasterInsertBypass(id, bypassed):
            let i = try project.requireMasterInsert(id)
            project.masterInserts[i].isBypassed = bypassed

        case let .setMasterInsertState(id, state):
            let i = try project.requireMasterInsert(id)
            if let state, state.count > PluginComponent.maximumStateBytes {
                throw CommandError.invalidValue(parameter: "state", reason: "larger than \(PluginComponent.maximumStateBytes) bytes")
            }
            project.masterInserts[i].state = state

        case let .addMedia(file):
            guard project.mediaFile(file.id) == nil else { throw CommandError.duplicateID(file.id.description) }
            guard MediaFile.isSafePath(file.path) else {
                throw CommandError.invalidValue(parameter: "path", reason: "must be a relative path inside \(MediaFile.directory)/")
            }
            guard file.frameCount > 0, file.sampleRate.isFinite, file.sampleRate > 0 else {
                throw CommandError.invalidValue(parameter: "file", reason: "needs at least one frame at a positive sample rate")
            }
            var named = file
            named.name = try Names.validated(file.name, parameter: "name")
            project.media.append(named)

        case let .removeMedia(id):
            guard let m = project.media.firstIndex(where: { $0.id == id }) else { throw CommandError.unknownMedia(id) }
            project.media.remove(at: m)
            // Nothing may point at a file the song no longer has.
            for t in project.tracks.indices {
                if project.tracks[t].instrument.sample == id { project.tracks[t].instrument.sample = nil }
                project.tracks[t].regions.removeAll { $0.media == id }
                let gone = Set(project.tracks[t].clips.filter { $0.audio?.media == id }.map(\.id))
                project.tracks[t].clips.removeAll { gone.contains($0.id) }
                project.tracks[t].slots.removeAll { gone.contains($0.clip) }
            }

        case let .setVolume(target, db):
            guard db.isFinite, MixerStrip.volumeRange.contains(db) else {
                throw CommandError.invalidValue(parameter: "db", reason: "must be within \(MixerStrip.volumeRange)")
            }
            try project.withMixer(target) { $0.volumeDB = db }

        case let .setPan(target, pan):
            guard pan.isFinite, MixerStrip.panRange.contains(pan) else {
                throw CommandError.invalidValue(parameter: "pan", reason: "must be within \(MixerStrip.panRange)")
            }
            try project.withMixer(target) { $0.pan = pan }

        case let .setMute(id, muted):
            let t = try project.requireTrack(id)
            project.tracks[t].mixer.isMuted = muted

        case let .setSolo(id, soloed):
            let t = try project.requireTrack(id)
            project.tracks[t].mixer.isSoloed = soloed

        case let .setSend(trackID, targetID, db):
            let t = try project.requireTrack(trackID)
            let target = try project.requireTrack(targetID)
            guard project.tracks[target].kind == .returnTrack else {
                throw CommandError.invalidValue(parameter: "to", reason: "sends go into a return track")
            }
            guard project.tracks[t].kind != .returnTrack else {
                throw CommandError.invalidValue(parameter: "track", reason: "a return track does not send")
            }
            guard let db else {
                project.tracks[t].sends.removeAll { $0.target == targetID }
                break
            }
            guard db.isFinite, MixerStrip.volumeRange.contains(db) else {
                throw CommandError.invalidValue(parameter: "db", reason: "must be within \(MixerStrip.volumeRange)")
            }
            if let s = project.tracks[t].sends.firstIndex(where: { $0.target == targetID }) {
                project.tracks[t].sends[s].levelDB = db
            } else {
                project.tracks[t].sends.append(Send(target: targetID, levelDB: db))
            }

        case let .setOutput(id, channel):
            let t = try project.requireTrack(id)
            if let channel {
                guard Track.isValidOutput(channel) else {
                    throw CommandError.invalidValue(parameter: "channel",
                                                    reason: "an even channel from 2 to \(Track.outputChannelLimit - 2); 0/1 is the master")
                }
            }
            project.tracks[t].output = channel

        case let .setInput(id, channel):
            let t = try project.requireTrack(id)
            guard project.tracks[t].kind == .audio else {
                throw CommandError.invalidValue(parameter: "track", reason: "only audio tracks record")
            }
            if let channel {
                guard (0..<Track.inputChannelLimit).contains(channel) else {
                    throw CommandError.invalidValue(parameter: "channel", reason: "0…\(Track.inputChannelLimit - 1)")
                }
            }
            project.tracks[t].input = channel

        case let .setMonitor(id, mode):
            let t = try project.requireTrack(id)
            guard project.tracks[t].kind == .audio else {
                throw CommandError.invalidValue(parameter: "track", reason: "only audio tracks have an input")
            }
            project.tracks[t].monitor = mode

        case let .mapMIDI(control, target):
            guard control.isValid else {
                throw CommandError.invalidValue(parameter: "control", reason: "channel 0…15, controller 0…127")
            }
            guard project.descriptor(for: target) != nil else {
                throw CommandError.invalidValue(parameter: "target", reason: "names no parameter in this song")
            }
            project.midiMappings.removeAll { $0.control == control }
            project.midiMappings.append(MIDIMapping(control: control, target: target))

        case let .setAutomation(target, points):
            guard target != .tempo, let descriptor = project.descriptor(for: target) else {
                throw CommandError.invalidValue(parameter: "target",
                                                reason: "names no parameter that can be automated (the tempo has its own track)")
            }
            try AutomationLane.validate(points, range: descriptor.range)
            if let index = project.automation.firstIndex(where: { $0.target == target }) {
                if points.isEmpty {
                    project.automation.remove(at: index)
                } else {
                    project.automation[index].points = points
                }
            } else if !points.isEmpty {
                project.automation.append(AutomationLane(target: target, points: points))
            }

        case let .unmapMIDI(control):
            guard project.midiMappings.contains(where: { $0.control == control }) else {
                throw CommandError.invalidValue(parameter: "control", reason: "is not mapped")
            }
            project.midiMappings.removeAll { $0.control == control }

        case let .createClip(trackID, id, name, length):
            let t = try project.requireTrack(trackID)
            guard project.tracks[t].kind == .instrument else {
                throw CommandError.invalidValue(parameter: "track", reason: "MIDI clips belong on an instrument track")
            }
            guard project.clipLocation(id) == nil else { throw CommandError.duplicateID(id.description) }
            try Self.validateLength(length)
            project.tracks[t].clips.append(Clip(id: id, name: try Names.validated(name, parameter: "name"), length: length))

        case let .createAudioClip(trackID, id, name, length, audio):
            let t = try project.requireTrack(trackID)
            guard project.tracks[t].kind == .audio else {
                throw CommandError.invalidValue(parameter: "track", reason: "audio clips belong on an audio track")
            }
            guard project.clipLocation(id) == nil else { throw CommandError.duplicateID(id.description) }
            try Self.validateLength(length)
            try project.validate(audio)
            project.tracks[t].clips.append(Clip(id: id, name: try Names.validated(name, parameter: "name"),
                                                length: length, audio: audio))

        case .deleteClip(let id):
            let (t, c) = try project.requireClip(id)
            project.tracks[t].clips.remove(at: c)
            project.tracks[t].placements.removeAll { $0.clip == id }
            project.tracks[t].slots.removeAll { $0.clip == id }

        case let .renameClip(id, name):
            let (t, c) = try project.requireClip(id)
            project.tracks[t].clips[c].name = try Names.validated(name, parameter: "name")

        case let .setClipLength(id, length):
            let (t, c) = try project.requireClip(id)
            try Self.validateLength(length)
            project.tracks[t].clips[c].length = length

        case let .addNotes(id, notes):
            let (t, c) = try project.requireClip(id)
            var clip = project.tracks[t].clips[c]
            guard clip.audio == nil else { throw CommandError.invalidValue(parameter: "clip", reason: "an audio clip has no notes") }
            var seen = Set(clip.notes.map(\.id))
            for note in notes {
                try Self.validate(note, in: clip)
                guard seen.insert(note.id).inserted else { throw CommandError.duplicateID(note.id.description) }
                clip.notes.append(note)
            }
            clip.notes.sort(by: Self.noteOrder)
            project.tracks[t].clips[c] = clip

        case let .updateNotes(id, notes):
            let (t, c) = try project.requireClip(id)
            var clip = project.tracks[t].clips[c]
            for note in notes {
                guard let n = clip.notes.firstIndex(where: { $0.id == note.id }) else {
                    throw CommandError.unknownNote(note.id)
                }
                try Self.validate(note, in: clip)
                clip.notes[n] = note
            }
            clip.notes.sort(by: Self.noteOrder)
            project.tracks[t].clips[c] = clip

        case let .removeNotes(id, noteIDs):
            let (t, c) = try project.requireClip(id)
            let existing = Set(project.tracks[t].clips[c].notes.map(\.id))
            if let missing = noteIDs.first(where: { !existing.contains($0) }) {
                throw CommandError.unknownNote(missing)
            }
            let doomed = Set(noteIDs)
            project.tracks[t].clips[c].notes.removeAll { doomed.contains($0.id) }

        case let .setControls(id, controls):
            let (t, c) = try project.requireClip(id)
            let clip = project.tracks[t].clips[c]
            guard clip.audio == nil || controls.isEmpty else {
                throw CommandError.invalidValue(parameter: "clip", reason: "an audio clip has no controllers")
            }
            var seen = Set<ControlID>()
            for control in controls {
                try Self.validate(control, in: clip)
                guard seen.insert(control.id).inserted else { throw CommandError.duplicateID(control.id.description) }
            }
            // Stable: two changes of one kind on one tick keep their order, so the later one wins.
            project.tracks[t].clips[c].controls = controls.enumerated()
                .sorted { $0.element.start != $1.element.start ? $0.element.start < $1.element.start : $0.offset < $1.offset }
                .map(\.element)

        case let .placeClip(trackID, id, clipID, start):
            let t = try project.requireTrack(trackID)
            guard let c = project.tracks[t].clipIndex(clipID) else { throw CommandError.unknownClip(clipID) }
            guard project.tracks[t].clips[c].audio == nil else {
                throw CommandError.invalidValue(parameter: "clip", reason: "an audio clip plays in the session; place audio as a region")
            }
            guard project.tracks[t].placementIndex(id) == nil else { throw CommandError.duplicateID(id.description) }
            try Self.validateStart(start)
            project.tracks[t].placements.append(Placement(id: id, clip: clipID, start: start))
            project.tracks[t].placements.sort { $0.start < $1.start }

        case let .movePlacement(trackID, id, start):
            let t = try project.requireTrack(trackID)
            guard let p = project.tracks[t].placementIndex(id) else { throw CommandError.unknownPlacement(id) }
            try Self.validateStart(start)
            project.tracks[t].placements[p].start = start
            project.tracks[t].placements.sort { $0.start < $1.start }

        case let .removePlacement(trackID, id):
            let t = try project.requireTrack(trackID)
            guard let p = project.tracks[t].placementIndex(id) else { throw CommandError.unknownPlacement(id) }
            project.tracks[t].placements.remove(at: p)

        case let .placeAudio(trackID, id, mediaID, start):
            let t = try project.requireTrack(trackID)
            guard project.tracks[t].kind == .audio else {
                throw CommandError.invalidValue(parameter: "track", reason: "only audio tracks hold audio regions")
            }
            guard let file = project.mediaFile(mediaID) else { throw CommandError.unknownMedia(mediaID) }
            guard project.tracks.allSatisfy({ $0.regionIndex(id) == nil }) else { throw CommandError.duplicateID(id.description) }
            try Self.validateStart(start)
            project.tracks[t].regions.append(AudioRegion(id: id, media: mediaID, start: start, length: file.frameCount))
            project.tracks[t].regions.sort { $0.start < $1.start }

        case let .moveRegion(trackID, id, start):
            let t = try project.requireTrack(trackID)
            guard let r = project.tracks[t].regionIndex(id) else { throw CommandError.unknownRegion(id) }
            try Self.validateStart(start)
            project.tracks[t].regions[r].start = start
            project.tracks[t].regions.sort { $0.start < $1.start }

        case let .trimRegion(trackID, id, offset, length):
            let t = try project.requireTrack(trackID)
            guard let r = project.tracks[t].regionIndex(id) else { throw CommandError.unknownRegion(id) }
            let media = project.tracks[t].regions[r].media
            guard let file = project.mediaFile(media) else { throw CommandError.unknownMedia(media) }
            guard offset >= 0, offset < file.frameCount else {
                throw CommandError.invalidValue(parameter: "offset", reason: "must be within 0…\(file.frameCount - 1) frames")
            }
            guard length >= 1, length <= file.frameCount - offset else {
                throw CommandError.invalidValue(parameter: "length", reason: "must be within 1…\(file.frameCount - offset) frames")
            }
            project.tracks[t].regions[r].offset = offset
            project.tracks[t].regions[r].length = length

        case let .removeRegion(trackID, id):
            let t = try project.requireTrack(trackID)
            guard let r = project.tracks[t].regionIndex(id) else { throw CommandError.unknownRegion(id) }
            project.tracks[t].regions.remove(at: r)

        case let .addScene(id, name, index):
            guard project.sceneIndex(id) == nil else { throw CommandError.duplicateID(id.description) }
            let at = index ?? project.scenes.count
            guard (0...project.scenes.count).contains(at) else {
                throw CommandError.invalidValue(parameter: "index", reason: "must be within 0…\(project.scenes.count)")
            }
            project.scenes.insert(Scene(id: id, name: try Names.validated(name, parameter: "name")), at: at)

        case .removeScene(let id):
            guard let s = project.sceneIndex(id) else { throw CommandError.unknownScene(id) }
            project.scenes.remove(at: s)
            for t in project.tracks.indices {
                project.tracks[t].slots.removeAll { $0.scene == id }
            }

        case let .renameScene(id, name):
            guard let s = project.sceneIndex(id) else { throw CommandError.unknownScene(id) }
            project.scenes[s].name = try Names.validated(name, parameter: "name")

        case let .setSlot(trackID, sceneID, clipID):
            let t = try project.requireTrack(trackID)
            guard project.sceneIndex(sceneID) != nil else { throw CommandError.unknownScene(sceneID) }
            if let clipID, project.tracks[t].clipIndex(clipID) == nil {
                throw CommandError.unknownClip(clipID)
            }
            project.tracks[t].slots.removeAll { $0.scene == sceneID }
            if let clipID {
                project.tracks[t].slots.append(SlotAssignment(scene: sceneID, clip: clipID))
            }
        }
    }

    static func validateLength(_ length: Tick) throws {
        guard length > 0, length <= MusicalTime.maximumTick else {
            throw CommandError.invalidValue(parameter: "length", reason: "must be within 1…\(MusicalTime.maximumTick) ticks")
        }
    }

    static func validateStart(_ start: Tick) throws {
        guard start >= 0, start <= MusicalTime.maximumTick else {
            throw CommandError.invalidValue(parameter: "start", reason: "must be within 0…\(MusicalTime.maximumTick) ticks")
        }
    }

    static func validate(_ control: ControlChange, in clip: Clip) throws {
        guard control.isValid else {
            throw CommandError.invalidValue(parameter: "controls",
                                            reason: "a bend is 0…16383; a controller is 0…119 with a value of 0…127")
        }
        guard control.start >= 0, control.start < clip.length else {
            throw CommandError.invalidValue(parameter: "start", reason: "must lie inside the clip (0…\(clip.length - 1))")
        }
    }

    static func validate(_ note: Note, in clip: Clip) throws {
        guard Note.pitchRange.contains(note.pitch) else {
            throw CommandError.invalidValue(parameter: "pitch", reason: "must be within \(Note.pitchRange)")
        }
        guard Note.velocityRange.contains(note.velocity) else {
            throw CommandError.invalidValue(parameter: "velocity", reason: "must be within \(Note.velocityRange)")
        }
        guard note.start >= 0, note.start < clip.length else {
            throw CommandError.invalidValue(parameter: "start", reason: "must lie inside the clip (0…\(clip.length - 1))")
        }
        guard note.length > 0, note.length <= MusicalTime.maximumTick else {
            throw CommandError.invalidValue(parameter: "length", reason: "must be at least one tick")
        }
    }

    /// Notes are kept sorted by start, then pitch, so the document has one canonical order
    /// and two equal edits compare equal.
    static func noteOrder(_ a: Note, _ b: Note) -> Bool {
        if a.start != b.start { return a.start < b.start }
        if a.pitch != b.pitch { return a.pitch < b.pitch }
        return a.id.rawValue.uuidString < b.id.rawValue.uuidString
    }
}

public enum Palette {
    /// Number of track colours the UI offers. The document stores an index into them.
    public static let trackColorCount = 12
}

extension Project {
    func requireTrack(_ id: TrackID) throws -> Int {
        guard let t = trackIndex(id) else { throw CommandError.unknownTrack(id) }
        return t
    }

    func requireInsert(_ id: InsertID, on track: TrackID) throws -> (Int, Int) {
        let t = try requireTrack(track)
        guard let i = tracks[t].insertIndex(id) else { throw CommandError.unknownInsert(id) }
        return (t, i)
    }

    func requireMasterInsert(_ id: InsertID) throws -> Int {
        guard let i = masterInserts.firstIndex(where: { $0.id == id }) else { throw CommandError.unknownInsert(id) }
        return i
    }

    /// Whether any chain, a track's or the master's, holds an insert with this id.
    func hasInsert(_ id: InsertID) -> Bool {
        masterInserts.contains { $0.id == id } || tracks.contains { $0.insertIndex(id) != nil }
    }

    /// Rejects audio that does not lie within a file of the song.
    func validate(_ audio: ClipAudio) throws {
        guard let file = mediaFile(audio.media) else { throw CommandError.unknownMedia(audio.media) }
        guard audio.offset >= 0, audio.length >= 1, audio.offset < file.frameCount,
              audio.length <= file.frameCount - audio.offset else {
            throw CommandError.invalidValue(parameter: "audio", reason: "must lie within the file")
        }
    }

    func requireClip(_ id: ClipID) throws -> (Int, Int) {
        guard let location = clipLocation(id) else { throw CommandError.unknownClip(id) }
        return location
    }

    mutating func withMixer(_ target: MixerTarget, _ change: (inout MixerStrip) -> Void) throws {
        switch target {
        case .master:
            change(&master)
        case .track(let id):
            let t = try requireTrack(id)
            change(&tracks[t].mixer)
        }
    }
}
