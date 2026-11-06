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
    case setTempoCurve(at: Tick, curve: TempoCurve)
    case setTimeSignatureChange(at: Tick, TimeSignature)
    case removeTimeSignatureChange(at: Tick)
    case setKeyRoot(Int)
    case setScale(Scale)
    case setTuning(id: String)
    case setConcertPitch(hertz: Double)
    case setSwing(Double)

    // Markers (PRO-W1): named positions on the timeline, one per tick.
    case addMarker(at: Tick, name: String)
    case renameMarker(at: Tick, name: String)
    case moveMarker(from: Tick, to: Tick)
    case removeMarker(at: Tick)

    // Subtitles (SUBS): timed text on the timeline, starts rising, never overlapping.
    /// New cues, as Transcribe hears them: every cue they overlap goes, they take its place.
    case placeSubtitles([SubtitleCue])
    case setSubtitleText(SubtitleID, text: String)
    case setSubtitleTiming(SubtitleID, start: Tick, end: Tick)
    case removeSubtitle(SubtitleID)

    // Light (CUES): fixtures patched on DMX universes, cues, and where a cue starts.
    case addFixture(PatchedFixture)
    case patchFixture(FixtureID, universe: Int, address: Int)
    case renameFixture(FixtureID, name: String)
    case removeFixture(FixtureID)
    case addCue(LightCue, index: Int?)
    case setCue(LightCue)
    case removeCue(CueID)
    case placeCue(CueID, at: Tick)
    case removeCuePlacement(at: Tick)

    // Tracks
    case addTrack(id: TrackID, name: String, kind: TrackKind, index: Int?)
    case removeTrack(TrackID)
    case renameTrack(TrackID, name: String)
    case moveTrack(TrackID, toIndex: Int)
    case setTrackColor(TrackID, colorIndex: Int)

    // Instrument
    case setInstrumentParameter(TrackID, key: String, value: Double)
    case loadInstrumentPreset(TrackID, name: String)
    /// A built-in instrument's whole sound at once — its preset name and every stored value — as
    /// an A/B comparison takes it back (PRO-W1). A value of a later build may only stay as it is.
    case setInstrumentSound(TrackID, preset: String, values: [String: Double])
    case setInstrumentDevice(TrackID, InstrumentDevice)
    case setInstrumentSample(TrackID, MediaID?)
    /// The pads the sampler's file is cut into (the break slicer); empty plays it across the keys.
    case setSamplerSlices(TrackID, [SampleSlice])
    /// The audio file the synth's wavetable engine is cut from, or nil for the factory shapes.
    case setInstrumentWavetable(TrackID, WavetableSource?)
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
    /// The interface input an audio track records from (0-based), or the first with nil; with
    /// `stereo`, that input and the next one as left and right. One step: both are set together.
    case setInput(TrackID, channel: Int?, stereo: Bool)
    /// When an audio track plays its input through its strip.
    case setMonitor(TrackID, MonitorMode)
    /// An instrument track's arpeggiator: its settings (switched on or off), or nil to remove it.
    case setArpeggio(TrackID, Arpeggio?)

    // MIDI
    /// Makes `control` move `target`, replacing whatever it moved before.
    case mapMIDI(MIDIControl, ParameterAddress)
    case unmapMIDI(MIDIControl)
    /// Replaces the automation of `target` with `points`; none removes the lane.
    case setAutomation(ParameterAddress, points: [AutomationPoint])

    // Modulation (W2)
    /// Adds `route`, or replaces the route with its id.
    case setModRoute(ModulationRoute)
    case removeModRoute(UUID)

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
    /// Cuts a placed clip in two at `at` (song ticks, strictly inside it). The placement plays a
    /// new clip `head` up to the cut; a new placement `placement` plays a new clip `tail` from it.
    /// A note across the cut ends there in the head and sounds again from the cut in the tail. The
    /// old clip goes when nothing plays it any more; a clip a slot or another placement uses stays.
    case splitPlacement(track: TrackID, PlacementID, at: Tick, head: ClipID, tail: ClipID, placement: PlacementID)
    /// Joins two or more placements of one track into one new clip `clip`, spanning the earliest
    /// start to the latest end: the notes and controller moves the placements played, in song
    /// order, with overlaps of one pitch resolved as playback resolves them. The earliest
    /// placement plays the new clip, the others go; a clip nothing uses any more goes with them.
    case consolidatePlacements(track: TrackID, [PlacementID], clip: ClipID)
    /// Gives a placement a clip of its own: a copy of the clip it shares with other placements or
    /// session slots (a linked copy, an alias), under `clip`. The others keep the original; an edit
    /// to either afterwards stays with it. Refused when nothing else plays the clip.
    case makePlacementUnique(track: TrackID, PlacementID, clip: ClipID)

    // Audio regions
    case placeAudio(track: TrackID, id: RegionID, media: MediaID, start: Tick)
    /// A whole video file on a video track's timeline (format 4); moved, trimmed and removed as a region.
    case placeVideo(track: TrackID, id: RegionID, media: MediaID, start: Tick)
    /// Cuts a region (audio or video) in two where `at` sounds; the second part is `newID`.
    case splitRegion(track: TrackID, RegionID, at: Tick, newID: RegionID)
    case moveRegion(track: TrackID, RegionID, start: Tick)
    case trimRegion(track: TrackID, RegionID, offset: Int, length: Int)
    case removeRegion(track: TrackID, RegionID)
    /// Joins two or more audio regions of one track into the earliest of them — only where no
    /// rendering is needed: pieces of one file that follow each other in the file and on the
    /// timeline, as a split leaves them. Overlapping or separate audio needs a bounce and is refused.
    case consolidateRegions(track: TrackID, [RegionID])
    /// A region's fade-in and fade-out, in frames of its file, and their curves. Both lengths
    /// together fit in the region; 0 is no fade.
    case setRegionFades(track: TrackID, RegionID, fadeIn: Int, fadeOut: Int, fadeInCurve: FadeCurve, fadeOutCurve: FadeCurve)
    /// A region's own level in dB, before the track's fader (`AudioRegion.gainRange`).
    case setRegionGain(track: TrackID, RegionID, gainDB: Double)
    /// Whether a region follows the song's tempo, and the tempo its file was played at
    /// (`AudioRegion.nativeBPMRange`). Following, it keeps its pitch and spans its beats.
    case setRegionWarp(track: TrackID, RegionID, nativeBPM: Double, followsTempo: Bool)
    /// A video part's colour correction (COLOR): exposure, contrast, saturation, temperature, tint
    /// and lift, gamma and gain on the luma, each within its `ColorGrade` range. The file is never
    /// changed; the standard grade removes the correction.
    case setRegionGrade(track: TrackID, RegionID, grade: ColorGrade)
    /// Records `media` — a file the app rendered from the region's original — and points the
    /// region at it, `bake` naming the original and the settings (W3). The region keeps its place,
    /// length, fades, gain and warp. A baked region is baked again from its original, never from
    /// the baked file. One step: Undo plays the original again.
    case bakeRegion(track: TrackID, RegionID, media: MediaFile, bake: RegionBaking)
    /// Points a baked region back at its original, at the same stretch; the baked file stays in the song.
    case revertRegionBake(track: TrackID, RegionID)

    // Takes (Recovery 4)
    /// Folds take `take` — a region of an audio track, a placement of an instrument track — with
    /// the takes it overlaps: into the folder one of them is in, else into a new folder `group`.
    /// The take sounds over its whole span from then on. Nothing to fold with changes nothing.
    case foldTake(track: TrackID, take: UUID, group: TakeGroupID)
    /// The comp of folder `group`: take `take` sounds from `start` to `end` (ticks).
    case compTake(track: TrackID, group: TakeGroupID, take: UUID, start: Tick, end: Tick)
    /// Unfolds folder `group`: its takes stay as plain regions or placements and all sound.
    case removeTakeGroup(track: TrackID, TakeGroupID)

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

    /// A name the app composes for the user — "<base> <suffix>" — shortened on the base so it
    /// always passes `validated`: a track called by 128 characters still gets a clip. The suffix
    /// stays whole, an empty base yields the suffix alone, and nothing at all yields "Untitled".
    /// Before this, three views built `"\(track.name) Clip"` by hand and the command was refused
    /// behind a `try?` — a long track name made every new clip silently impossible.
    public static func derived(_ base: String, suffix: String) -> String {
        let tail = String(suffix.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maximumLength))
        let room = maximumLength - (tail.isEmpty ? 0 : tail.count + 1)
        let head = String(base.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Swift.max(room, 0)))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        switch (head.isEmpty, tail.isEmpty) {
        case (true, true): return "Untitled"
        case (true, false): return tail
        case (false, true): return head
        case (false, false): return "\(head) \(tail)"
        }
    }
}

extension Command {
    /// Applies the command to `project`, or throws and leaves it untouched. A take that went with
    /// the change — a deleted region, placement or track — leaves its folder (`pruneTakeGroups`).
    public func apply(to project: inout Project) throws {
        try applyChange(to: &project)
        project.pruneTakeGroups()
    }

    private func applyChange(to project: inout Project) throws {
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
            // The later changes stay on bar lines, or the new first bar is refused.
            try Project.validateMeter(signature: signature, changes: project.timeSignatureChanges)
            project.timeSignature = signature

        case let .setTempoChange(tick, bpm):
            guard tick > 0, tick <= MusicalTime.maximumTick else {
                throw CommandError.invalidValue(parameter: "tick", reason: "must be within 1…\(MusicalTime.maximumTick); tick 0 is the project tempo")
            }
            guard bpm.isFinite, Tempo.range.contains(bpm) else {
                throw CommandError.invalidValue(parameter: "bpm", reason: "must be within \(Tempo.range)")
            }
            // A new tempo for a change keeps how the tempo reaches it (a ramp stays a ramp).
            let kept = project.tempoChanges.first { $0.tick == tick }
            project.tempoChanges.removeAll { $0.tick == tick }
            project.tempoChanges.append(kept?.with(bpm: bpm) ?? TempoChange(tick: tick, bpm: bpm))
            project.tempoChanges.sort { $0.tick < $1.tick }

        case .removeTempoChange(let tick):
            guard project.tempoChanges.contains(where: { $0.tick == tick }) else {
                throw CommandError.invalidValue(parameter: "tick", reason: "no tempo change at \(tick)")
            }
            project.tempoChanges.removeAll { $0.tick == tick }

        case let .setTimeSignatureChange(tick, signature):
            guard tick > 0, tick <= MusicalTime.maximumTick else {
                throw CommandError.invalidValue(parameter: "tick", reason: "must be within 1…\(MusicalTime.maximumTick); tick 0 is the song's time signature")
            }
            guard signature.isValid else {
                throw CommandError.invalidValue(parameter: "timeSignature", reason: "numerator 1…32, denominator a power of two up to 32")
            }
            var changes = project.timeSignatureChanges.filter { $0.tick != tick }
            changes.append(TimeSignatureChange(tick: tick, signature: signature))
            changes.sort { $0.tick < $1.tick }
            // On a bar line of the bars before it, and every later change still on one.
            try Project.validateMeter(signature: project.timeSignature, changes: changes)
            project.timeSignatureChanges = changes

        case .removeTimeSignatureChange(let tick):
            guard project.timeSignatureChanges.contains(where: { $0.tick == tick }) else {
                throw CommandError.invalidValue(parameter: "tick", reason: "no time signature change at \(tick)")
            }
            let changes = project.timeSignatureChanges.filter { $0.tick != tick }
            try Project.validateMeter(signature: project.timeSignature, changes: changes)
            project.timeSignatureChanges = changes

        case let .setTempoCurve(tick, curve):
            guard let index = project.tempoChanges.firstIndex(where: { $0.tick == tick }) else {
                throw CommandError.invalidValue(parameter: "tick", reason: "no tempo change at \(tick)")
            }
            project.tempoChanges[index] = project.tempoChanges[index].with(curve: curve)

        case .setKeyRoot(let root):
            guard MusicalContext.rootRange.contains(root) else {
                throw CommandError.invalidValue(parameter: "root", reason: "a pitch class 0 (C) … 11 (B)")
            }
            project.context.root = root

        case .setScale(let scale):
            project.context.scale = scale

        case .setTuning(let id):
            guard TuningSystem.library.contains(where: { $0.id == id }) else {
                throw CommandError.invalidValue(parameter: "id", reason: "names no tone system")
            }
            project.context.tuning = id

        case .setConcertPitch(let hertz):
            guard hertz.isFinite, MusicalContext.concertPitchRange.contains(hertz) else {
                throw CommandError.invalidValue(parameter: "hertz", reason: "must be within \(MusicalContext.concertPitchRange)")
            }
            project.context.concertPitch = hertz

        case .setSwing(let amount):
            guard amount.isFinite, MusicalContext.swingRange.contains(amount) else {
                throw CommandError.invalidValue(parameter: "amount", reason: "must be within 0…1")
            }
            project.context.swing = amount

        case .addFixture(let fixture):
            try project.applyLight { try $0.addFixture(fixture) }
        case let .patchFixture(id, universe, address):
            try project.applyLight { try $0.patchFixture(id, universe: universe, address: address) }
        case let .renameFixture(id, name):
            try project.applyLight { try $0.renameFixture(id, name: name) }
        case .removeFixture(let id):
            try project.applyLight { try $0.removeFixture(id) }
        case let .addCue(cue, index):
            try project.applyLight { try $0.addCue(cue, index: index) }
        case .setCue(let cue):
            try project.applyLight { try $0.setCue(cue) }
        case .removeCue(let id):
            try project.applyLight { try $0.removeCue(id) }
        case let .placeCue(id, tick):
            try project.applyLight { try $0.placeCue(id, at: tick) }
        case .removeCuePlacement(let tick):
            try project.applyLight { try $0.removeCuePlacement(at: tick) }

        case .placeSubtitles(let cues):
            guard !cues.isEmpty else {
                throw CommandError.invalidValue(parameter: "cues", reason: "must not be empty")
            }
            try project.applySubtitles { list in
                for cue in cues {
                    guard Subtitles.isValidText(cue.text) else {
                        throw CommandError.invalidValue(parameter: "text",
                                                        reason: "empty, with line breaks, or longer than two lines of \(Subtitles.maximumLineLength) characters")
                    }
                }
                list.removeAll { old in
                    cues.contains { $0.id == old.id || ($0.start < old.end && old.start < $0.end) }
                }
                list.append(contentsOf: cues)
            }
        case let .setSubtitleText(id, text):
            let clean = Subtitles.normalized(text)
            guard Subtitles.isValidText(clean) else {
                throw CommandError.invalidValue(parameter: "text",
                                                reason: "empty or longer than two lines of \(Subtitles.maximumLineLength) characters")
            }
            try project.applySubtitles { list in
                guard let index = list.firstIndex(where: { $0.id == id }) else {
                    throw CommandError.invalidValue(parameter: "cue", reason: "no subtitle \(id)")
                }
                list[index].text = clean
            }
        case let .setSubtitleTiming(id, start, end):
            guard start >= 0, start < end, end <= MusicalTime.maximumTick else {
                throw CommandError.invalidValue(parameter: "start",
                                                reason: "start before end, within 0…\(MusicalTime.maximumTick) ticks")
            }
            try project.applySubtitles { list in
                guard let index = list.firstIndex(where: { $0.id == id }) else {
                    throw CommandError.invalidValue(parameter: "cue", reason: "no subtitle \(id)")
                }
                list[index].start = start
                list[index].end = end
            }
        case .removeSubtitle(let id):
            try project.applySubtitles { list in
                guard list.contains(where: { $0.id == id }) else {
                    throw CommandError.invalidValue(parameter: "cue", reason: "no subtitle \(id)")
                }
                list.removeAll { $0.id == id }
            }

        case let .addMarker(tick, name):
            try Self.validateMarkerTick(tick)
            guard project.marker(at: tick) == nil else {
                throw CommandError.invalidValue(parameter: "tick", reason: "a marker already stands at \(tick)")
            }
            guard project.markers.count < Marker.maximumCount else {
                throw CommandError.invalidValue(parameter: "markers", reason: "a song holds at most \(Marker.maximumCount) markers")
            }
            var markers = project.markers
            markers.append(Marker(tick: tick, name: try Names.validated(name, parameter: "name")))
            markers.sort { $0.tick < $1.tick }
            project.markers = markers

        case let .renameMarker(tick, name):
            guard let index = project.markers.firstIndex(where: { $0.tick == tick }) else {
                throw CommandError.invalidValue(parameter: "tick", reason: "no marker at \(tick)")
            }
            project.markers[index].name = try Names.validated(name, parameter: "name")

        case let .moveMarker(from, to):
            guard let index = project.markers.firstIndex(where: { $0.tick == from }) else {
                throw CommandError.invalidValue(parameter: "from", reason: "no marker at \(from)")
            }
            try Self.validateMarkerTick(to)
            guard to == from || project.marker(at: to) == nil else {
                throw CommandError.invalidValue(parameter: "to", reason: "a marker already stands at \(to)")
            }
            var markers = project.markers
            markers[index].tick = to
            markers.sort { $0.tick < $1.tick }
            project.markers = markers

        case let .removeMarker(tick):
            guard project.marker(at: tick) != nil else {
                throw CommandError.invalidValue(parameter: "tick", reason: "no marker at \(tick)")
            }
            project.markers.removeAll { $0.tick == tick }

        case let .addTrack(id, name, kind, index):
            guard project.trackIndex(id) == nil else { throw CommandError.duplicateID(id.description) }
            guard project.canAddTrack(kind) else {
                throw CommandError.invalidValue(parameter: "kind",
                                                reason: "a song holds at most \(Track.limit(for: kind)) tracks of this kind")
            }
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
            // A route on a parameter that is gone would refuse the song when it next opens.
            project.modRoutes.removeAll { $0.target.involves(id) }
            project.storedRoutes.kept.removeAll { $0.target?.involves(id) == true }

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
                throw CommandError.invalidValue(parameter: "track", reason: "only instrument tracks have an instrument")
            }
            guard let parameter = SynthParameter.builtIn(ParameterKey(rawValue: key)) else {
                throw CommandError.invalidValue(parameter: "key", reason: "no instrument parameter named \(key)")
            }
            guard parameter.accepts(value) else {
                throw CommandError.invalidValue(parameter: "value", reason: "must be within \(parameter.range)")
            }
            project.tracks[t].instrument.values[key] = value

        case let .setInstrumentSound(id, preset, values):
            let t = try project.requireTrack(id)
            guard project.tracks[t].kind == .instrument else {
                throw CommandError.invalidValue(parameter: "track", reason: "only instrument tracks have an instrument")
            }
            let name = preset.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, preset.count <= 2 * Names.maximumLength else {
                throw CommandError.invalidValue(parameter: "preset", reason: "must not be empty")
            }
            let current = project.tracks[t].instrument.values
            for (key, value) in values {
                if let parameter = SynthParameter.builtIn(ParameterKey(rawValue: key)) {
                    guard parameter.accepts(value) else {
                        throw CommandError.invalidValue(parameter: "values", reason: "\(key) must be within \(parameter.range)")
                    }
                } else if current[key] != value {
                    throw CommandError.invalidValue(parameter: "values", reason: "no instrument parameter named \(key)")
                }
            }
            project.tracks[t].instrument.preset = preset
            project.tracks[t].instrument.values = values

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
            // A preset is the synth's sound: it replaces every synth value and keeps the rest,
            // another device's value or one a later build wrote (docs/FORMAT.md keeps those).
            let synth = InstrumentDevice.synth.rawValue + "."
            settings.values = settings.values.filter { !$0.key.hasPrefix(synth) }
                .merging(preset.values) { _, new in new }
            project.tracks[t].instrument = settings

        case let .setInstrumentDevice(id, device):
            let t = try project.requireTrack(id)
            guard project.tracks[t].kind == .instrument else {
                throw CommandError.invalidValue(parameter: "track", reason: "only instrument tracks have an instrument")
            }
            guard device != .unrecognized else {
                throw CommandError.invalidValue(parameter: "device", reason: "names no instrument this build plays")
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
            if let media {
                guard let file = project.mediaFile(media) else { throw CommandError.unknownMedia(media) }
                guard file.kind == .audio else {
                    throw CommandError.invalidValue(parameter: "media", reason: "a sampler plays an audio file, not a video")
                }
            }
            // Slices are frames of one file: another file starts uncut.
            if project.tracks[t].instrument.sample != media { project.tracks[t].instrument.slices = nil }
            project.tracks[t].instrument.sample = media

        case let .setSamplerSlices(id, slices):
            let t = try project.requireTrack(id)
            guard project.tracks[t].kind == .instrument else {
                throw CommandError.invalidValue(parameter: "track", reason: "only instrument tracks have an instrument")
            }
            if slices.isEmpty {
                project.tracks[t].instrument.slices = nil
                break
            }
            guard let media = project.tracks[t].instrument.sample, let file = project.mediaFile(media) else {
                throw CommandError.invalidValue(parameter: "slices", reason: "the sampler has no file to cut")
            }
            try SampleSlice.validate(slices, frameCount: file.frameCount)
            project.tracks[t].instrument.slices = slices

        case let .setInstrumentWavetable(id, source):
            let t = try project.requireTrack(id)
            guard project.tracks[t].kind == .instrument else {
                throw CommandError.invalidValue(parameter: "track", reason: "only instrument tracks have an instrument")
            }
            if let source {
                guard let file = project.mediaFile(source.media) else { throw CommandError.unknownMedia(source.media) }
                guard file.kind == .audio else {
                    throw CommandError.invalidValue(parameter: "media", reason: "a wavetable is cut from an audio file, not a video")
                }
                guard WavetableSource.frameRange.contains(source.frames) else {
                    throw CommandError.invalidValue(parameter: "frames",
                                                    reason: "must be within \(WavetableSource.frameRange.lowerBound)…\(WavetableSource.frameRange.upperBound)")
                }
            }
            project.tracks[t].instrument.wavetable = source

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
            guard project.tracks[t].kind != .video else {
                throw CommandError.invalidValue(parameter: "track", reason: "a video track has no sound to process")
            }
            guard !project.hasInsert(id) else { throw CommandError.duplicateID(id.description) }
            guard plugin.role == .effect else {
                throw CommandError.invalidValue(parameter: "plugin", reason: "must be an effect (type aufx)")
            }
            guard project.tracks[t].storedInserts.count < Insert.maximumPerTrack else {
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
            guard project.storedMasterInserts.count < Insert.maximumPerTrack else {
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
            guard file.hasUsableFormat else {
                throw CommandError.invalidValue(parameter: "file",
                                                reason: "needs at least one frame at a sample rate of \(MediaFile.sampleRateRange)")
            }
            var named = file
            named.name = try Names.validated(file.name, parameter: "name")
            project.media.append(named)

        case let .removeMedia(id):
            guard let m = project.media.firstIndex(where: { $0.id == id }) else { throw CommandError.unknownMedia(id) }
            project.media.remove(at: m)
            // Nothing may point at a file the song no longer has.
            for t in project.tracks.indices {
                if project.tracks[t].instrument.sample == id {
                    project.tracks[t].instrument.sample = nil
                    project.tracks[t].instrument.slices = nil
                }
                if project.tracks[t].instrument.wavetable?.media == id { project.tracks[t].instrument.wavetable = nil }
                project.tracks[t].regions.removeAll { $0.media == id }
                // A region baked from this file keeps playing its baked file, without a way back.
                for r in project.tracks[t].regions.indices where project.tracks[t].regions[r].bake?.source == id {
                    project.tracks[t].regions[r].bake = nil
                }
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
            guard project.tracks[t].kind != .video || db == nil else {
                throw CommandError.invalidValue(parameter: "track", reason: "a video track has no sound to send")
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
                guard project.tracks[t].kind != .video else {
                    throw CommandError.invalidValue(parameter: "track", reason: "a video track has no sound to route")
                }
                guard Track.isValidOutput(channel) else {
                    throw CommandError.invalidValue(parameter: "channel",
                                                    reason: "an even channel from 2 to \(Track.outputChannelLimit - 2); 0/1 is the master")
                }
            }
            project.tracks[t].output = channel

        case let .setInput(id, channel, stereo):
            let t = try project.requireTrack(id)
            guard project.tracks[t].kind == .audio else {
                throw CommandError.invalidValue(parameter: "track", reason: "only audio tracks record")
            }
            let width = stereo ? Track.maximumInputChannels : 1
            guard (0...(Track.inputChannelLimit - width)).contains(channel ?? 0) else {
                throw CommandError.invalidValue(parameter: "channel", reason: "0…\(Track.inputChannelLimit - width)")
            }
            project.tracks[t].input = channel
            project.tracks[t].inputChannels = stereo ? width : nil

        case let .setMonitor(id, mode):
            let t = try project.requireTrack(id)
            guard project.tracks[t].kind == .audio else {
                throw CommandError.invalidValue(parameter: "track", reason: "only audio tracks have an input")
            }
            project.tracks[t].monitor = mode

        case let .setArpeggio(id, arpeggio):
            let t = try project.requireTrack(id)
            guard project.tracks[t].kind == .instrument else {
                throw CommandError.invalidValue(parameter: "track", reason: "only an instrument track arpeggiates")
            }
            if let problem = arpeggio?.problem { throw CommandError.invalidValue(parameter: "arpeggio", reason: problem) }
            project.tracks[t].arpeggio = arpeggio

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
            // The song-wide frame — tempo, key, tuning, swing — is not automated: the tempo has
            // its own track, and the engine reads the rest once per song.
            guard target.owner != .project, let descriptor = project.descriptor(for: target) else {
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

        case let .setModRoute(route):
            guard project.descriptor(for: route.target) != nil else {
                throw CommandError.invalidValue(parameter: "target", reason: "names no parameter in this song")
            }
            guard route.depth.isFinite, (-1...1).contains(route.depth) else {
                throw CommandError.invalidValue(parameter: "depth", reason: "must be within −1…1")
            }
            // A route kept from a newer build is not this build's to change or to shadow.
            guard !project.storedRoutes.kept.contains(where: { $0.id == route.id }) else {
                throw CommandError.duplicateID(route.id.uuidString)
            }
            if let index = project.modRoutes.firstIndex(where: { $0.id == route.id }) {
                project.modRoutes[index] = route
            } else {
                guard project.storedRoutes.count < Modulation.routeLimit else {
                    throw CommandError.invalidValue(parameter: "route", reason: "a song holds at most \(Modulation.routeLimit) routes")
                }
                project.modRoutes.append(route)
            }

        case let .removeModRoute(id):
            guard project.modRoutes.contains(where: { $0.id == id }) else {
                throw CommandError.invalidValue(parameter: "route", reason: "is not in this song")
            }
            project.modRoutes.removeAll { $0.id == id }

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
            // What starts past the new end is dropped with it, so the clip stays a valid one —
            // a note left behind would make the song refuse to open (undo brings it back).
            project.tracks[t].clips[c].length = length
            project.tracks[t].clips[c].notes.removeAll { $0.start >= length }
            project.tracks[t].clips[c].controls.removeAll { $0.start >= length }

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

        case let .splitPlacement(trackID, id, cut, headID, tailID, placementID):
            let t = try project.requireTrack(trackID)
            guard let p = project.tracks[t].placementIndex(id) else { throw CommandError.unknownPlacement(id) }
            let placement = project.tracks[t].placements[p]
            guard let c = project.tracks[t].clipIndex(placement.clip) else { throw CommandError.unknownClip(placement.clip) }
            let clip = project.tracks[t].clips[c]
            guard cut > placement.start, cut < placement.start + clip.length else {
                throw CommandError.invalidValue(parameter: "at", reason: "must lie inside the placed clip, after its first tick")
            }
            for newID in [headID, tailID] where project.clipLocation(newID) != nil {
                throw CommandError.duplicateID(newID.description)
            }
            guard headID != tailID else { throw CommandError.duplicateID(tailID.description) }
            guard project.tracks[t].placementIndex(placementID) == nil else { throw CommandError.duplicateID(placementID.description) }
            let (head, tail) = Self.split(clip, at: cut - placement.start, head: headID, tail: tailID)
            var track = project.tracks[t]
            track.placements[p].clip = headID
            track.placements.append(Placement(id: placementID, clip: tailID, start: cut))
            track.placements.sort { $0.start < $1.start }
            track.clips.insert(contentsOf: [head, tail], at: c + 1)
            track.removeClipIfUnused(clip.id)
            track.splitTake(id.rawValue, at: cut, into: placementID.rawValue)
            project.tracks[t] = track

        case let .consolidatePlacements(trackID, ids, clipID):
            let t = try project.requireTrack(trackID)
            guard ids.count >= 2 else {
                throw CommandError.invalidValue(parameter: "placements", reason: "needs at least two placements")
            }
            guard Set(ids).count == ids.count else { throw CommandError.duplicateID("placements") }
            guard project.clipLocation(clipID) == nil else { throw CommandError.duplicateID(clipID.description) }
            var track = project.tracks[t]
            for id in ids where track.placementIndex(id) == nil { throw CommandError.unknownPlacement(id) }
            let chosen = Set(ids)
            // In the track's order, which is the order playback reads them in.
            var parts: [(placement: Placement, clip: Clip)] = []
            for placement in track.placements where chosen.contains(placement.id) {
                guard let clip = track.clips.first(where: { $0.id == placement.clip }) else {
                    throw CommandError.unknownClip(placement.clip)
                }
                parts.append((placement, clip))
            }
            guard let first = parts.min(by: { $0.placement.start < $1.placement.start }) else {
                throw CommandError.invalidValue(parameter: "placements", reason: "needs at least two placements")
            }
            let merged = Self.consolidated(parts, id: clipID, name: first.clip.name)
            try Self.validateLength(merged.length)
            let sources = parts.map { $0.clip.id }
            let at = track.clips.firstIndex { sources.contains($0.id) } ?? track.clips.count
            track.placements.removeAll { chosen.contains($0.id) && $0.id != first.placement.id }
            if let p = track.placementIndex(first.placement.id) { track.placements[p].clip = clipID }
            track.clips.insert(merged, at: at)
            for source in Set(sources) { track.removeClipIfUnused(source) }
            project.tracks[t] = track

        case let .makePlacementUnique(trackID, id, clipID):
            let t = try project.requireTrack(trackID)
            guard let p = project.tracks[t].placementIndex(id) else { throw CommandError.unknownPlacement(id) }
            let source = project.tracks[t].placements[p].clip
            guard let c = project.tracks[t].clipIndex(source) else { throw CommandError.unknownClip(source) }
            guard project.clipLocation(clipID) == nil else { throw CommandError.duplicateID(clipID.description) }
            guard project.tracks[t].uses(of: source) >= 2 else {
                throw CommandError.invalidValue(parameter: "placement", reason: "its clip plays nowhere else")
            }
            var copy = project.tracks[t].clips[c]
            copy.id = clipID
            project.tracks[t].clips.insert(copy, at: c + 1)
            project.tracks[t].placements[p].clip = clipID

        case let .placeAudio(trackID, id, mediaID, start):
            let t = try project.requireTrack(trackID)
            guard project.tracks[t].kind == .audio else {
                throw CommandError.invalidValue(parameter: "track", reason: "only audio tracks hold audio regions")
            }
            guard let file = project.mediaFile(mediaID) else { throw CommandError.unknownMedia(mediaID) }
            guard file.kind == .audio else {
                throw CommandError.invalidValue(parameter: "media", reason: "a video goes on a video track")
            }
            guard project.tracks.allSatisfy({ $0.regionIndex(id) == nil }) else { throw CommandError.duplicateID(id.description) }
            try Self.validateStart(start)
            project.tracks[t].regions.append(AudioRegion(id: id, media: mediaID, start: start, length: file.frameCount))
            project.tracks[t].regions.sort { $0.start < $1.start }

        case let .placeVideo(trackID, id, mediaID, start):
            let t = try project.requireTrack(trackID)
            guard project.tracks[t].kind == .video else {
                throw CommandError.invalidValue(parameter: "track", reason: "only video tracks show video")
            }
            guard let file = project.mediaFile(mediaID) else { throw CommandError.unknownMedia(mediaID) }
            guard file.kind == .video else {
                throw CommandError.invalidValue(parameter: "media", reason: "an audio file goes on an audio track")
            }
            guard project.tracks.allSatisfy({ $0.regionIndex(id) == nil }) else { throw CommandError.duplicateID(id.description) }
            try Self.validateStart(start)
            project.tracks[t].regions.append(AudioRegion(id: id, media: mediaID, start: start, length: file.frameCount))
            project.tracks[t].regions.sort { $0.start < $1.start }

        case let .splitRegion(trackID, id, tick, newID):
            let t = try project.requireTrack(trackID)
            guard let r = project.tracks[t].regionIndex(id) else { throw CommandError.unknownRegion(id) }
            guard project.tracks.allSatisfy({ $0.regionIndex(newID) == nil }) else {
                throw CommandError.duplicateID(newID.description)
            }
            let region = project.tracks[t].regions[r]
            guard project.mediaFile(region.media) != nil else { throw CommandError.unknownMedia(region.media) }
            // The cut falls where `tick` sounds: the file time from the region's start to it, over the
            // song's tempo map. Nothing of the file is lost — the two parts play what the one did.
            let elapsed = project.fileFrames(of: region, at: tick) ?? .nan
            guard elapsed.isFinite, tick > region.start, elapsed.rounded() >= 1,
                  elapsed.rounded() < Double(region.length) else {
                throw CommandError.invalidValue(parameter: "at", reason: "must fall inside the region")
            }
            let head = Int(elapsed.rounded())
            // The head keeps the fade-in, the tail the fade-out; both keep the region's gain and warp.
            var tail = region
            tail.id = newID
            tail.start = tick
            tail.offset = region.offset + head
            tail.length = region.length - head
            tail.fadeIn = nil
            project.tracks[t].regions[r].length = head
            project.tracks[t].regions[r].fadeOut = nil
            Self.holdFades(&project.tracks[t].regions[r])
            Self.holdFades(&tail)
            project.tracks[t].regions.append(tail)
            project.tracks[t].regions.sort { $0.start < $1.start }
            project.tracks[t].splitTake(id.rawValue, at: tick, into: newID.rawValue)

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
            // A shorter region keeps its fades as far as they fit, the fade-in first.
            Self.holdFades(&project.tracks[t].regions[r])

        case let .removeRegion(trackID, id):
            let t = try project.requireTrack(trackID)
            guard let r = project.tracks[t].regionIndex(id) else { throw CommandError.unknownRegion(id) }
            project.tracks[t].regions.remove(at: r)

        case let .consolidateRegions(trackID, ids):
            let t = try project.requireTrack(trackID)
            guard ids.count >= 2 else {
                throw CommandError.invalidValue(parameter: "regions", reason: "needs at least two regions")
            }
            guard Set(ids).count == ids.count else { throw CommandError.duplicateID("regions") }
            var regions: [AudioRegion] = []
            for id in ids {
                guard let r = project.tracks[t].regionIndex(id) else { throw CommandError.unknownRegion(id) }
                regions.append(project.tracks[t].regions[r])
            }
            guard let joined = project.joinedWithoutRendering(regions) else {
                throw CommandError.invalidValue(parameter: "regions",
                                                reason: "only pieces of one file that follow each other join without a bounce; overlapping or separate audio needs a bounce")
            }
            let chosen = Set(ids)
            project.tracks[t].regions.removeAll { chosen.contains($0.id) && $0.id != joined.id }
            if let r = project.tracks[t].regionIndex(joined.id) { project.tracks[t].regions[r] = joined }

        case let .setRegionFades(trackID, id, fadeIn, fadeOut, fadeInCurve, fadeOutCurve):
            let t = try project.requireTrack(trackID)
            guard project.tracks[t].kind == .audio else {
                throw CommandError.invalidValue(parameter: "track", reason: "only audio regions fade")
            }
            guard let r = project.tracks[t].regionIndex(id) else { throw CommandError.unknownRegion(id) }
            let length = project.tracks[t].regions[r].length
            guard fadeIn >= 0, fadeIn <= length else {
                throw CommandError.invalidValue(parameter: "fadeIn", reason: "must be within 0…\(length) frames")
            }
            guard fadeOut >= 0, fadeOut <= length - fadeIn else {
                throw CommandError.invalidValue(parameter: "fadeOut", reason: "must be within 0…\(length - fadeIn) frames")
            }
            project.tracks[t].regions[r].fadeIn = fadeIn == 0 ? nil : fadeIn
            project.tracks[t].regions[r].fadeOut = fadeOut == 0 ? nil : fadeOut
            project.tracks[t].regions[r].fadeInCurve = fadeInCurve
            project.tracks[t].regions[r].fadeOutCurve = fadeOutCurve

        case let .setRegionGain(trackID, id, gainDB):
            let t = try project.requireTrack(trackID)
            guard project.tracks[t].kind == .audio else {
                throw CommandError.invalidValue(parameter: "track", reason: "only audio regions have a level")
            }
            guard let r = project.tracks[t].regionIndex(id) else { throw CommandError.unknownRegion(id) }
            guard gainDB.isFinite, AudioRegion.gainRange.contains(gainDB) else {
                throw CommandError.invalidValue(parameter: "gainDB",
                                                reason: "must be within \(AudioRegion.gainRange.lowerBound)…\(AudioRegion.gainRange.upperBound) dB")
            }
            project.tracks[t].regions[r].gainDB = gainDB == 0 ? nil : gainDB

        case let .setRegionGrade(trackID, id, grade):
            let t = try project.requireTrack(trackID)
            guard project.tracks[t].kind == .video else {
                throw CommandError.invalidValue(parameter: "track", reason: "only video parts have a colour correction")
            }
            guard let r = project.tracks[t].regionIndex(id) else { throw CommandError.unknownRegion(id) }
            guard grade.isValid else {
                throw CommandError.invalidValue(parameter: "grade", reason: "every value must be a number within its range")
            }
            project.tracks[t].regions[r].grade = grade.isNeutral ? nil : grade

        case let .bakeRegion(trackID, id, file, bake):
            let t = try project.requireTrack(trackID)
            guard project.tracks[t].kind == .audio else {
                throw CommandError.invalidValue(parameter: "track", reason: "only audio regions are baked")
            }
            guard let r = project.tracks[t].regionIndex(id) else { throw CommandError.unknownRegion(id) }
            guard bake.isValid else {
                throw CommandError.invalidValue(parameter: "bake", reason: "needs an edit, each setting within its range")
            }
            var region = project.tracks[t].regions[r]
            let original = region.original
            guard bake.source == original.media else {
                throw CommandError.invalidValue(parameter: "bake", reason: "a region is baked from the file it was made from")
            }
            guard let source = project.mediaFile(bake.source), source.kind == .audio else { throw CommandError.unknownMedia(bake.source) }
            guard file.kind == .audio, file.sampleRate == source.sampleRate else {
                throw CommandError.invalidValue(parameter: "media", reason: "a baked file is audio at its original's rate")
            }
            guard file.frameCount <= source.frameCount - Swift.min(bake.sourceOffset, source.frameCount) else {
                throw CommandError.invalidValue(parameter: "media", reason: "a baked file is a stretch of its original")
            }
            let offset = original.offset - bake.sourceOffset
            guard offset >= 0, region.length <= file.frameCount - offset else {
                throw CommandError.invalidValue(parameter: "media", reason: "the baked file must hold the region's stretch")
            }
            try Command.addMedia(file).applyChange(to: &project)
            region.media = file.id
            region.offset = offset
            region.bake = bake
            project.tracks[t].regions[r] = region

        case let .revertRegionBake(trackID, id):
            let t = try project.requireTrack(trackID)
            guard let r = project.tracks[t].regionIndex(id) else { throw CommandError.unknownRegion(id) }
            var region = project.tracks[t].regions[r]
            guard region.bake != nil else {
                throw CommandError.invalidValue(parameter: "region", reason: "the region is not baked")
            }
            guard project.bakeFits(region) else {
                throw CommandError.invalidValue(parameter: "region", reason: "its original no longer holds the region's stretch")
            }
            let original = region.original
            region.media = original.media
            region.offset = original.offset
            region.bake = nil
            project.tracks[t].regions[r] = region

        case let .setRegionWarp(trackID, id, nativeBPM, followsTempo):
            let t = try project.requireTrack(trackID)
            guard project.tracks[t].kind == .audio else {
                throw CommandError.invalidValue(parameter: "track", reason: "only audio regions follow the tempo")
            }
            guard let r = project.tracks[t].regionIndex(id) else { throw CommandError.unknownRegion(id) }
            guard nativeBPM.isFinite, AudioRegion.nativeBPMRange.contains(nativeBPM) else {
                throw CommandError.invalidValue(parameter: "nativeBPM",
                                                reason: "must be within \(AudioRegion.nativeBPMRange.lowerBound)…\(AudioRegion.nativeBPMRange.upperBound) BPM")
            }
            var region = project.tracks[t].regions[r]
            region.nativeBPM = nativeBPM
            region.followsTempo = followsTempo ? true : nil
            // Within the song: a region that would end past the last tick does not warp.
            guard let stop = Arranging.end(of: region, in: project), stop <= MusicalTime.maximumTick else {
                throw CommandError.invalidValue(parameter: "nativeBPM", reason: "the region would end past the song's last bar")
            }
            project.tracks[t].regions[r] = region

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

        case let .foldTake(trackID, take, group):
            try project.foldTake(take, on: trackID, newGroup: group)

        case let .compTake(trackID, group, take, start, end):
            try project.compTake(take, in: group, on: trackID, from: start, to: end)

        case let .removeTakeGroup(trackID, group):
            let t = try project.requireTrack(trackID)
            guard let g = project.tracks[t].takeGroupIndex(group) else {
                throw CommandError.invalidValue(parameter: "group", reason: "no such take folder on the track")
            }
            project.tracks[t].takeGroups.remove(at: g)
        }
    }

    static func validateLength(_ length: Tick) throws {
        guard length > 0, length <= MusicalTime.maximumTick else {
            throw CommandError.invalidValue(parameter: "length", reason: "must be within 1…\(MusicalTime.maximumTick) ticks")
        }
    }

    /// Holds a region's stored fades inside its length, the fade-in first ("in wins"); a fade that
    /// no longer fits any of is no fade.
    static func holdFades(_ region: inout AudioRegion) {
        let (rise, fall) = region.effectiveFades
        region.fadeIn = rise == 0 ? nil : rise
        region.fadeOut = fall == 0 ? nil : fall
    }

    static func validateMarkerTick(_ tick: Tick) throws {
        guard tick >= 0, tick <= MusicalTime.maximumTick else {
            throw CommandError.invalidValue(parameter: "tick", reason: "must be within 0…\(MusicalTime.maximumTick) ticks")
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

    /// A clip cut at `point` (clip ticks, inside it) into two new clips with the clip's name.
    /// What the placement played sounds the same up to the cut: a note across it is shortened to
    /// the cut in the head and starts again at the cut in the tail (with its id — ids are unique
    /// within a clip). A bend or controller in effect at the cut is set again at the tail's start
    /// unless the tail sets it there itself, so the tail plays the same alone or launched.
    static func split(_ clip: Clip, at point: Tick, head headID: ClipID, tail tailID: ClipID) -> (Clip, Clip) {
        var headNotes: [Note] = []
        var tailNotes: [Note] = []
        for note in clip.notes where note.start < clip.length {
            let end = Swift.min(note.start + note.length, clip.length)
            if note.start < point {
                var kept = note
                kept.length = Swift.min(end, point) - note.start
                headNotes.append(kept)
                if end > point {
                    var rest = note
                    rest.start = 0
                    rest.length = end - point
                    tailNotes.append(rest)
                }
            } else {
                var moved = note
                moved.start -= point
                tailNotes.append(moved)
            }
        }
        let headControls = clip.controls.filter { $0.start < point }
        var tailControls = clip.controls.filter { $0.start >= point && $0.start < clip.length }.map { change in
            var moved = change
            moved.start -= point
            return moved
        }
        var carried: [ControlChange] = []
        for change in headControls.reversed() where !carried.contains(where: { $0.kind == change.kind }) {
            carried.append(change)
        }
        let restated = carried.reversed().filter { last in
            !tailControls.contains { $0.kind == last.kind && $0.start == 0 } && last.rest != last.value
        }.map { ControlChange(kind: $0.kind, start: 0, value: $0.value) }
        tailControls.insert(contentsOf: restated, at: 0)
        return (Clip(id: headID, name: clip.name, length: point, notes: headNotes.sorted(by: noteOrder), controls: headControls),
                Clip(id: tailID, name: clip.name, length: clip.length - point,
                     notes: tailNotes.sorted(by: noteOrder), controls: tailControls))
    }

    /// What `parts` played, as one clip from the earliest start to the latest end. Notes come
    /// through playback's own overlap rule (`PlaybackPlan.resolvingOverlaps`), so the clip holds
    /// what was heard, not a second reading of it. A placement that bent or held the pedal and
    /// ends inside the span returns them to rest there, as playback did. Ids are new: two parts
    /// may play the same clip, and its ids are unique only within it.
    static func consolidated(_ parts: [(placement: Placement, clip: Clip)], id: ClipID, name: String) -> Clip {
        let start = parts.map { $0.placement.start }.min() ?? 0
        let stop = parts.map { $0.placement.start + $0.clip.length }.max() ?? start
        var intervals: [PlaybackPlan.Interval] = []
        var returns: [ControlChange] = []
        var changes: [ControlChange] = []
        for (placement, clip) in parts {
            let shift = placement.start - start
            for note in clip.notes where note.start < clip.length {
                let end = Swift.min(note.start + note.length, clip.length)
                intervals.append(PlaybackPlan.Interval(start: shift + note.start, end: shift + end,
                                                       pitch: note.pitch, velocity: note.velocity))
            }
            var moved: [ControlChange.Kind] = []
            for control in clip.controls where control.start < clip.length {
                changes.append(ControlChange(kind: control.kind, start: shift + control.start, value: control.value))
                if !moved.contains(control.kind) { moved.append(control.kind) }
            }
            let end = shift + clip.length
            guard end < stop - start else { continue }
            for kind in moved {
                if let rest = ControlChange(kind: kind, start: end, value: 0).rest {
                    returns.append(ControlChange(kind: kind, start: end, value: rest))
                }
            }
        }
        let notes = PlaybackPlan.resolvingOverlaps(intervals).map { interval in
            Note(pitch: interval.pitch, velocity: interval.velocity, start: interval.start, length: interval.end - interval.start)
        }
        // Stable: at one tick a return to rest comes before a new value, as in playback.
        let controls = (returns + changes).enumerated()
            .sorted { $0.element.start != $1.element.start ? $0.element.start < $1.element.start : $0.offset < $1.offset }
            .map(\.element)
        return Clip(id: id, name: name, length: stop - start, notes: notes.sorted(by: noteOrder), controls: controls)
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

extension Track {
    /// Removes a clip nothing plays any more — no placement and no session slot — after an edit
    /// replaced it with new clips. A clip still in use stays.
    /// How many places play the clip: its placements in the arrangement and its session slots.
    /// Two or more is a linked clip — an edit to its notes is heard in every one of them.
    public func uses(of clip: ClipID) -> Int {
        placements.reduce(0) { $0 + ($1.clip == clip ? 1 : 0) } + slots.reduce(0) { $0 + ($1.clip == clip ? 1 : 0) }
    }

    mutating func removeClipIfUnused(_ id: ClipID) {
        guard !placements.contains(where: { $0.clip == id }), !slots.contains(where: { $0.clip == id }) else { return }
        clips.removeAll { $0.id == id }
    }
}

extension Project {
    /// The one region that plays what `regions` play, when no rendering is needed: pieces of one
    /// file of the song, each starting in the file where the one before it ends and on the
    /// timeline where it stops (within a tick, the rounding of a split). Nil otherwise —
    /// overlapping regions both sound, and audio from different files or places needs a bounce.
    /// The result keeps the earliest region's id.
    public func joinedWithoutRendering(_ regions: [AudioRegion]) -> AudioRegion? {
        let ordered = regions.sorted { $0.start < $1.start }
        guard let first = ordered.first, let last = ordered.last, ordered.count >= 2, mediaFile(first.media) != nil else { return nil }
        // One level and one way of following the tempo for the whole, and no fade inside it: a fade
        // between two pieces, or two levels, would be lost by the join and needs a bounce.
        guard ordered.allSatisfy({ $0.gainDB == first.gainDB && $0.nativeBPM == first.nativeBPM
                                    && $0.followsTempo == first.followsTempo }),
              ordered.dropFirst().allSatisfy({ ($0.fadeIn ?? 0) == 0 }),
              ordered.dropLast().allSatisfy({ ($0.fadeOut ?? 0) == 0 }) else { return nil }
        var joined = first
        joined.fadeOut = last.fadeOut
        joined.fadeOutCurve = last.fadeOutCurve
        for (before, next) in zip(ordered, ordered.dropFirst()) {
            guard next.media == first.media, next.start > before.start,
                  next.offset == before.offset + before.length,
                  let stop = Arranging.end(of: before, in: self), abs(next.start - stop) <= 1 else { return nil }
            joined.length += next.length
        }
        return joined
    }

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
            || storedMasterInserts.kept.contains { $0.id == id.rawValue }
            || tracks.contains { $0.storedInserts.kept.contains { $0.id == id.rawValue } }
    }

    /// Rejects audio that does not lie within a file of the song.
    func validate(_ audio: ClipAudio) throws {
        guard let file = mediaFile(audio.media) else { throw CommandError.unknownMedia(audio.media) }
        guard file.kind == .audio else {
            throw CommandError.invalidValue(parameter: "audio", reason: "an audio clip plays an audio file, not a video")
        }
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
