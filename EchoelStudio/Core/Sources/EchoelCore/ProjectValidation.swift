/// The same rules the commands enforce, applied to a whole project read from disk. A song file
/// never went through `ProjectStore.perform`, and the engine trusts what it plays: a time
/// signature over 0 or a tempo of 0 would stop the render thread. So the reader checks it all
/// before the song opens, and refuses a file that breaks a rule rather than playing it.
extension Project {
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
        try Self.validate(master, name: "master")
        for file in media {
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
        guard masterInserts.count <= Insert.maximumPerTrack else { throw Self.invalid("masterInserts", "too many") }
        for insert in masterInserts {
            guard insertIDs.insert(insert.id).inserted else { throw CommandError.duplicateID(insert.id.description) }
            guard insert.plugin.role == .effect else { throw Self.invalid("masterInserts", "an insert is not an effect") }
            if let state = insert.state, state.count > PluginComponent.maximumStateBytes {
                throw Self.invalid("masterInserts", "an effect's state is larger than \(PluginComponent.maximumStateBytes) bytes")
            }
        }
        for track in tracks {
            guard trackIDs.insert(track.id).inserted else { throw CommandError.duplicateID(track.id.description) }
            try Self.validate(track.mixer, name: "mixer")
            try validate(track.instrument)
            for clip in track.clips {
                guard clipIDs.insert(clip.id).inserted else { throw CommandError.duplicateID(clip.id.description) }
                try Command.validateLength(clip.length)
                for note in clip.notes { try Command.validate(note, in: clip) }
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
            for placement in track.placements {
                guard let c = track.clipIndex(placement.clip) else { throw CommandError.unknownClip(placement.clip) }
                guard track.clips[c].audio == nil else { throw Self.invalid("placements", "an audio clip is session-only") }
                try Command.validateStart(placement.start)
            }
            if let output = track.output, !Track.isValidOutput(output) { throw Self.invalid("output", "not a stereo pair after 1/2") }
            if let input = track.input, track.kind != .audio || !(0..<Track.inputChannelLimit).contains(input) {
                throw Self.invalid("input", "only an audio track records, from input 0…\(Track.inputChannelLimit - 1)")
            }
            if track.monitor != .auto, track.kind != .audio { throw Self.invalid("monitor", "only an audio track has an input") }
            for send in track.sends {
                guard track.kind != .returnTrack,
                      tracks.first(where: { $0.id == send.target })?.kind == .returnTrack,
                      send.levelDB.isFinite, MixerStrip.volumeRange.contains(send.levelDB) else {
                    throw Self.invalid("sends", "a send must go from a track into a return track, within the fader's range")
                }
            }
            guard Set(track.sends.map(\.target)).count == track.sends.count else { throw Self.invalid("sends", "two sends into one return") }
            guard track.inserts.count <= Insert.maximumPerTrack else { throw Self.invalid("inserts", "too many on one track") }
            for insert in track.inserts {
                guard insertIDs.insert(insert.id).inserted else { throw CommandError.duplicateID(insert.id.description) }
                guard insert.plugin.role == .effect else { throw Self.invalid("inserts", "an insert is not an effect") }
                if let state = insert.state, state.count > PluginComponent.maximumStateBytes {
                    throw Self.invalid("inserts", "an effect's state is larger than \(PluginComponent.maximumStateBytes) bytes")
                }
            }
            for region in track.regions {
                guard regionIDs.insert(region.id).inserted else { throw CommandError.duplicateID(region.id.description) }
                guard let file = mediaFile(region.media) else { throw CommandError.unknownMedia(region.media) }
                try Command.validateStart(region.start)
                guard region.offset >= 0, region.length >= 1, region.offset < file.frameCount,
                      region.length <= file.frameCount - region.offset else {
                    throw Self.invalid("regions", "a region reaches past the end of its file")
                }
            }
        }
        for lane in automation {
            // A lane on a parameter this build does not know is kept, but still plays safely.
            let range = descriptor(for: lane.target)?.range ?? -Double.infinity...Double.infinity
            try AutomationLane.validate(lane.points, range: range)
        }
    }

    private func validate(_ instrument: InstrumentSettings) throws {
        for (key, value) in instrument.values {
            // A key this build does not know is kept for the build that does; a known one obeys its range.
            if let parameter = SynthParameter.named(ParameterKey(rawValue: key)), !parameter.accepts(value) {
                throw Self.invalid(key, "must be within \(parameter.range)")
            }
        }
        if let sample = instrument.sample, mediaFile(sample) == nil { throw CommandError.unknownMedia(sample) }
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

    private static func invalid(_ parameter: String, _ reason: String) -> CommandError {
        .invalidValue(parameter: parameter, reason: reason)
    }
}
