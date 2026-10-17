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
    case addMedia(MediaFile)
    case removeMedia(MediaID)

    // Mixer
    case setVolume(MixerTarget, db: Double)
    case setPan(MixerTarget, pan: Double)
    case setMute(TrackID, Bool)
    case setSolo(TrackID, Bool)

    // Clips
    case createClip(track: TrackID, id: ClipID, name: String, length: Tick)
    case deleteClip(ClipID)
    case renameClip(ClipID, name: String)
    case setClipLength(ClipID, length: Tick)

    // Notes
    case addNotes(ClipID, [Note])
    case updateNotes(ClipID, [Note])
    case removeNotes(ClipID, [NoteID])

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
            if project.tracks[t].instrument.plugin != named { project.tracks[t].instrument.pluginState = nil }
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

        case let .createClip(trackID, id, name, length):
            let t = try project.requireTrack(trackID)
            guard project.tracks[t].kind == .instrument else {
                throw CommandError.invalidValue(parameter: "track", reason: "MIDI clips belong on an instrument track")
            }
            guard project.clipLocation(id) == nil else { throw CommandError.duplicateID(id.description) }
            try Self.validateLength(length)
            project.tracks[t].clips.append(Clip(id: id, name: try Names.validated(name, parameter: "name"), length: length))

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

        case let .placeClip(trackID, id, clipID, start):
            let t = try project.requireTrack(trackID)
            guard project.tracks[t].clipIndex(clipID) != nil else { throw CommandError.unknownClip(clipID) }
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

    private static func validateLength(_ length: Tick) throws {
        guard length > 0, length <= MusicalTime.maximumTick else {
            throw CommandError.invalidValue(parameter: "length", reason: "must be within 1…\(MusicalTime.maximumTick) ticks")
        }
    }

    private static func validateStart(_ start: Tick) throws {
        guard start >= 0, start <= MusicalTime.maximumTick else {
            throw CommandError.invalidValue(parameter: "start", reason: "must be within 0…\(MusicalTime.maximumTick) ticks")
        }
    }

    private static func validate(_ note: Note, in clip: Clip) throws {
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
