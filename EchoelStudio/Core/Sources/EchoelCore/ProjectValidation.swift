import Foundation

/// The same rules the commands enforce, applied to a whole project read from disk. A song file
/// never went through `ProjectStore.perform`, and the engine trusts what it plays: a time
/// signature over 0 or a tempo of 0 would stop the render thread. So the reader checks it all
/// before the song opens, and refuses a file that breaks a rule rather than playing it.
extension Project {
    /// Every time signature change after tick 0, at rising ticks, a signature a song can have,
    /// on a bar line of the signature before it — and at most `maximumTick`.
    static func validateMeter(signature: TimeSignature, changes: [TimeSignatureChange]) throws {
        var meter = MeterMap(signature: signature)
        var previous: Tick = 0
        for change in changes {
            guard change.tick > previous, change.tick <= MusicalTime.maximumTick else {
                throw invalid("timeSignatureChanges", "ticks must rise from after 0 to at most \(MusicalTime.maximumTick)")
            }
            guard change.signature.isValid else {
                throw invalid("timeSignatureChanges", "numerator 1…32, denominator a power of two up to 32")
            }
            guard meter.isBarLine(change.tick) else {
                throw invalid("timeSignatureChanges", "the change at tick \(change.tick) is not on a bar line")
            }
            previous = change.tick
            meter = MeterMap(signature: signature, changes: changes.filter { $0.tick <= change.tick })
        }
    }

    public func validate() throws {
        guard timeSignature.isValid else { throw Self.invalid("timeSignature", "numerator 1…32, denominator a power of two up to 32") }
        guard tempo.isFinite, Tempo.range.contains(tempo) else { throw Self.invalid("tempo", "must be within \(Tempo.range)") }
        // An unknown tone system is kept and plays as twelve equal steps; a later build may know it.
        guard context.isValid else { throw Self.invalid("context", "root 0…11, concert pitch 400…480 Hz, swing 0…1") }
        var previous: Tick = 0
        for change in tempoChanges {
            guard change.tick > previous, change.tick <= MusicalTime.maximumTick else {
                throw Self.invalid("tempoChanges", "ticks must rise from after 0")
            }
            guard change.bpm.isFinite, Tempo.range.contains(change.bpm) else {
                throw Self.invalid("tempoChanges", "bpm must be within \(Tempo.range)")
            }
            previous = change.tick
        }
        try Self.validateMeter(signature: timeSignature, changes: timeSignatureChanges)
        try Self.validateMarkers(markers, nameLimit: 2 * Names.maximumLength)
        try lighting.validate()
        try Subtitles.validate(subtitles)
        try Self.validate(master, name: "master")
        try Self.validateName(name, "name")
        var sceneIDs = Set<SceneID>()
        for scene in scenes {
            guard sceneIDs.insert(scene.id).inserted else { throw CommandError.duplicateID(scene.id.description) }
            try Self.validateName(scene.name, "scenes")
        }
        var mediaIDs = Set<MediaID>()
        for file in media {
            // Regions, samples and audio clips find their file by id; two files with one id
            // would leave it to chance which one plays.
            guard mediaIDs.insert(file.id).inserted else { throw CommandError.duplicateID(file.id.description) }
            try Self.validateName(file.name, "media")
            guard MediaFile.isSafePath(file.path) else { throw Self.invalid("media", "a path leaves the Media folder") }
            guard file.hasUsableFormat else {
                throw Self.invalid("media", "a file has no frames, too many, or a sample rate outside \(MediaFile.sampleRateRange)")
            }
        }
        guard midiMappings.allSatisfy(\.control.isValid),
              Set(midiMappings.map(\.control)).count == midiMappings.count else {
            throw Self.invalid("midiMappings", "a controller out of range, or mapped twice")
        }
        var automated = Set<ParameterAddress>()
        for lane in automation {
            guard automated.insert(lane.target).inserted, lane.target.owner != .project else {
                throw Self.invalid("automation", "a parameter has two lanes, or a song-wide one has one")
            }
        }
        var trackIDs = Set<TrackID>(), clipIDs = Set<ClipID>(), regionIDs = Set<RegionID>(), insertIDs = Set<InsertID>()
        guard storedMasterInserts.count <= Insert.maximumPerTrack else { throw Self.invalid("masterInserts", "too many") }
        for part in storedMasterInserts.kept {
            guard insertIDs.insert(InsertID(part.id)).inserted else { throw CommandError.duplicateID(part.id.uuidString) }
        }
        for insert in masterInserts {
            guard insertIDs.insert(insert.id).inserted else { throw CommandError.duplicateID(insert.id.description) }
            guard insert.plugin.role == .effect else { throw Self.invalid("masterInserts", "an insert is not an effect") }
            if let state = insert.state, state.count > PluginComponent.maximumStateBytes {
                throw Self.invalid("masterInserts", "an effect's state is larger than \(PluginComponent.maximumStateBytes) bytes")
            }
        }
        for track in tracks {
            guard trackIDs.insert(track.id).inserted else { throw CommandError.duplicateID(track.id.description) }
            try Self.validateName(track.name, "tracks")
            try Self.validate(track.mixer, name: "mixer")
            try validate(track.instrument)
            try Self.validateContent(of: track)
            for clip in track.clips {
                guard clipIDs.insert(clip.id).inserted else { throw CommandError.duplicateID(clip.id.description) }
                try Self.validateName(clip.name, "clips")
                try Command.validateLength(clip.length)
                // Note ids are unique within a clip, as `addNotes` keeps them — not across clips.
                var noteIDs = Set<NoteID>()
                for note in clip.notes {
                    guard noteIDs.insert(note.id).inserted else { throw CommandError.duplicateID(note.id.description) }
                    try Command.validate(note, in: clip)
                }
                guard Set(clip.controls.map(\.id)).count == clip.controls.count else {
                    throw Self.invalid("controls", "two controller changes share an id")
                }
                for control in clip.controls { try Command.validate(control, in: clip) }
                guard clip.audio == nil || clip.controls.isEmpty else {
                    throw Self.invalid("controls", "an audio clip has no controllers")
                }
                if let audio = clip.audio {
                    guard track.kind == .audio, clip.notes.isEmpty else {
                        throw Self.invalid("clips", "an audio clip sits on an audio track and has no notes")
                    }
                    try validate(audio)
                }
            }
            // Placement ids are unique within a track, as `placeClip` keeps them.
            var placementIDs = Set<PlacementID>()
            for placement in track.placements {
                guard placementIDs.insert(placement.id).inserted else { throw CommandError.duplicateID(placement.id.description) }
                guard let c = track.clipIndex(placement.clip) else { throw CommandError.unknownClip(placement.clip) }
                guard track.clips[c].audio == nil else { throw Self.invalid("placements", "an audio clip is session-only") }
                try Command.validateStart(placement.start)
            }
            // A slot holds one of this track's own clips, in a scene that exists, one per scene.
            var filledScenes = Set<SceneID>()
            for slot in track.slots {
                guard sceneIDs.contains(slot.scene) else { throw CommandError.unknownScene(slot.scene) }
                guard track.clipIndex(slot.clip) != nil else { throw CommandError.unknownClip(slot.clip) }
                guard filledScenes.insert(slot.scene).inserted else { throw Self.invalid("slots", "a track holds two clips in one scene") }
            }
            if let output = track.output, !Track.isValidOutput(output) { throw Self.invalid("output", "not a stereo pair after 1/2") }
            if let input = track.input, track.kind != .audio || !(0..<Track.inputChannelLimit).contains(input) {
                throw Self.invalid("input", "only an audio track records, from input 0…\(Track.inputChannelLimit - 1)")
            }
            if let width = track.inputChannels {
                guard track.kind == .audio, (1...Track.maximumInputChannels).contains(width),
                      (track.input ?? 0) + width <= Track.inputChannelLimit else {
                    throw Self.invalid("inputChannels", "an audio track records 1 or \(Track.maximumInputChannels) inputs, within the first \(Track.inputChannelLimit)")
                }
            }
            if track.monitor != .auto, track.kind != .audio { throw Self.invalid("monitor", "only an audio track has an input") }
            if let arpeggio = track.arpeggio {
                guard track.kind == .instrument else { throw Self.invalid("arpeggio", "only an instrument track arpeggiates") }
                if let problem = arpeggio.problem { throw Self.invalid("arpeggio", problem) }
            }
            for send in track.sends {
                guard track.kind != .returnTrack,
                      tracks.first(where: { $0.id == send.target })?.kind == .returnTrack,
                      send.levelDB.isFinite, MixerStrip.volumeRange.contains(send.levelDB) else {
                    throw Self.invalid("sends", "a send must go from a track into a return track, within the fader's range")
                }
            }
            guard Set(track.sends.map(\.target)).count == track.sends.count else { throw Self.invalid("sends", "two sends into one return") }
            guard track.storedInserts.count <= Insert.maximumPerTrack else { throw Self.invalid("inserts", "too many on one track") }
            for part in track.storedInserts.kept {
                guard insertIDs.insert(InsertID(part.id)).inserted else { throw CommandError.duplicateID(part.id.uuidString) }
            }
            for insert in track.inserts {
                guard insertIDs.insert(insert.id).inserted else { throw CommandError.duplicateID(insert.id.description) }
                guard insert.plugin.role == .effect else { throw Self.invalid("inserts", "an insert is not an effect") }
                if let state = insert.state, state.count > PluginComponent.maximumStateBytes {
                    throw Self.invalid("inserts", "an effect's state is larger than \(PluginComponent.maximumStateBytes) bytes")
                }
            }
            try Self.validateTakeGroups(of: track)
            for region in track.regions {
                guard regionIDs.insert(region.id).inserted else { throw CommandError.duplicateID(region.id.description) }
                guard let file = mediaFile(region.media) else { throw CommandError.unknownMedia(region.media) }
                guard (file.kind == .video) == (track.kind == .video) else {
                    throw Self.invalid("regions", "a video track shows video files, an audio track plays audio files")
                }
                try Command.validateStart(region.start)
                guard region.offset >= 0, region.length >= 1, region.offset < file.frameCount,
                      region.length <= file.frameCount - region.offset else {
                    throw Self.invalid("regions", "a region reaches past the end of its file")
                }
                // Fades, level and warp (AUD-2, optional inside format 4): the ranges the editor keeps.
                let rise = region.fadeIn ?? 0, fall = region.fadeOut ?? 0
                guard rise >= 0, fall >= 0, rise <= region.length, fall <= region.length - rise else {
                    throw Self.invalid("regions", "a region's fades are longer than the region")
                }
                if let gain = region.gainDB, !(gain.isFinite && AudioRegion.gainRange.contains(gain)) {
                    throw Self.invalid("regions", "a region's gain is outside \(AudioRegion.gainRange) dB")
                }
                if let bpm = region.nativeBPM, !(bpm.isFinite && AudioRegion.nativeBPMRange.contains(bpm)) {
                    throw Self.invalid("regions", "a region's native tempo is outside \(AudioRegion.nativeBPMRange) BPM")
                }
                // A transposition (W-4, optional inside format 4): the range the editor keeps.
                if let cents = region.transposeCents, !(cents.isFinite && AudioRegion.transposeRange.contains(cents)) {
                    throw Self.invalid("regions", "a region's transposition is outside \(AudioRegion.transposeRange) cents")
                }
                // A colour correction (COLOR, optional inside format 4) belongs to a video part, every value in range.
                if let grade = region.grade {
                    guard track.kind == .video, grade.isValid else {
                        throw Self.invalid("regions", "a colour correction off a video part, or a value outside its range")
                    }
                }
                // A bake (W3, optional inside format 4) names an audio file that holds the region's stretch.
                guard bakeFits(region) else {
                    throw Self.invalid("regions", "a region's bake names no original that holds its stretch, or a setting out of range")
                }
            }
        }
        // A route moves a parameter that exists in this song; unlike a lane it is not kept for a
        // later build — a route on nothing would be a body moving nothing (G-A M11).
        guard modRoutes.allSatisfy({ descriptor(for: $0.target) != nil }) else {
            throw Self.invalid("modRoutes", "a route's target names nothing in this song")
        }
        do {
            _ = try Modulation.validate(modRoutes, targets: Set(modRoutes.map(\.target)))
        } catch {
            throw Self.invalid("modRoutes", "more than \(Modulation.routeLimit) routes, a repeated id, or a depth outside −1…1")
        }
        try validateKeptParts()
        for lane in automation {
            // A lane on a parameter this build does not know is kept, but still plays safely.
            let range = descriptor(for: lane.target)?.range ?? -Double.infinity...Double.infinity
            try AutomationLane.validate(lane.points, range: range)
        }
    }

    /// What a track holds matches its kind, as the commands keep it: an instrument track plays
    /// MIDI clips and no audio regions, an audio track audio clips and regions, a return track
    /// effects only, a video track video regions only. (An audio clip off an audio track is
    /// refused in the clip loop, a region of the wrong kind of file in the region loop.)
    private static func validateContent(of track: Track) throws {
        switch track.kind {
        case .instrument:
            guard track.regions.isEmpty else { throw invalid("regions", "only an audio track holds audio regions") }
        case .audio:
            guard track.clips.allSatisfy({ $0.audio != nil }) else { throw invalid("clips", "an audio track holds audio clips only") }
        case .returnTrack:
            guard track.clips.isEmpty, track.placements.isEmpty, track.slots.isEmpty, track.regions.isEmpty else {
                throw invalid("tracks", "a return track holds effects only")
            }
        case .video:
            guard track.clips.isEmpty, track.placements.isEmpty, track.slots.isEmpty, track.inserts.isEmpty,
                  track.sends.isEmpty, track.output == nil else {
                throw invalid("tracks", "a video track holds video regions only")
            }
        }
    }

    /// A stored name is never empty. Its length is held to twice what the editor allows, not to
    /// the limit itself: the count of characters follows the system's Unicode rules, and a name
    /// right at the limit, saved on one system, must not lock the song on another.
    private static func validateName(_ name: String, _ parameter: String) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw invalid(parameter, "a name is empty") }
        guard name.count <= 2 * Names.maximumLength else {
            throw invalid(parameter, "a name is longer than \(2 * Names.maximumLength) characters")
        }
    }

    private func validate(_ instrument: InstrumentSettings) throws {
        for (key, value) in instrument.values {
            // A key this build does not know is kept for the build that does; a known one obeys its range.
            if let parameter = SynthParameter.builtIn(ParameterKey(rawValue: key)), !parameter.accepts(value) {
                // A whole number past the last choice is a choice a newer build appended (an engine,
                // a rule): nothing stands in for it, so the song asks for that build.
                if parameter.taper == .stepped, value.isFinite, value == value.rounded(),
                   value > parameter.range.upperBound, value <= 1_000_000 {
                    throw UnknownStoredName(field: key, name: String(Int(value)))
                }
                throw Self.invalid(key, "must be within \(parameter.range)")
            }
        }
        if let sample = instrument.sample {
            guard let file = mediaFile(sample) else { throw CommandError.unknownMedia(sample) }
            guard file.kind == .audio else { throw Self.invalid("instrument", "a sampler plays an audio file") }
        }
        if let slices = instrument.slices {
            guard !slices.isEmpty else { throw Self.invalid("instrument", "slices are absent, never empty") }
            guard let sample = instrument.sample, let file = mediaFile(sample) else {
                throw Self.invalid("instrument", "slices cut no file")
            }
            try SampleSlice.validate(slices, frameCount: file.frameCount)
        }
        if let wavetable = instrument.wavetable {
            guard let file = mediaFile(wavetable.media) else { throw CommandError.unknownMedia(wavetable.media) }
            guard file.kind == .audio else { throw Self.invalid("instrument", "a wavetable is cut from an audio file") }
            guard WavetableSource.frameRange.contains(wavetable.frames) else {
                throw Self.invalid("instrument", "a wavetable's cycles are outside \(WavetableSource.frameRange)")
            }
        }
        if instrument.device == .plugin, instrument.plugin == nil { throw Self.invalid("instrument", "plays a plugin it does not name") }
        if let state = instrument.pluginState, state.count > PluginComponent.maximumStateBytes {
            throw Self.invalid("pluginState", "larger than \(PluginComponent.maximumStateBytes) bytes")
        }
    }

    private static func validate(_ strip: MixerStrip, name: String) throws {
        guard strip.volumeDB.isFinite, MixerStrip.volumeRange.contains(strip.volumeDB),
              strip.pan.isFinite, MixerStrip.panRange.contains(strip.pan) else {
            throw invalid(name, "volume or pan out of range")
        }
    }

    static func invalid(_ parameter: String, _ reason: String) -> CommandError {
        .invalidValue(parameter: parameter, reason: reason)
    }
}
