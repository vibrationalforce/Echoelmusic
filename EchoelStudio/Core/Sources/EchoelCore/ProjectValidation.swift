/// The same rules the commands enforce, applied to a whole project read from disk. A song file
/// never went through `ProjectStore.perform`, and the engine trusts what it plays: a time
/// signature over 0 or a tempo of 0 would stop the render thread. So the reader checks it all
/// before the song opens, and refuses a file that breaks a rule rather than playing it.
extension Project {
    public func validate() throws {
        guard timeSignature.isValid else { throw Self.invalid("timeSignature", "numerator 1…32, denominator a power of two up to 32") }
        guard tempo.isFinite, Tempo.range.contains(tempo) else { throw Self.invalid("tempo", "must be within \(Tempo.range)") }
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
            guard file.frameCount > 0, file.sampleRate.isFinite, file.sampleRate > 0 else {
                throw Self.invalid("media", "a file has no frames or no sample rate")
            }
        }
        guard midiMappings.allSatisfy(\.control.isValid),
              Set(midiMappings.map(\.control)).count == midiMappings.count else {
            throw Self.invalid("midiMappings", "a controller out of range, or mapped twice")
        }
        var trackIDs = Set<TrackID>(), clipIDs = Set<ClipID>(), regionIDs = Set<RegionID>(), insertIDs = Set<InsertID>()
        for track in tracks {
            guard trackIDs.insert(track.id).inserted else { throw CommandError.duplicateID(track.id.description) }
            try Self.validate(track.mixer, name: "mixer")
            try validate(track.instrument)
            for clip in track.clips {
                guard clipIDs.insert(clip.id).inserted else { throw CommandError.duplicateID(clip.id.description) }
                try Command.validateLength(clip.length)
                for note in clip.notes { try Command.validate(note, in: clip) }
            }
            for placement in track.placements {
                guard track.clipIndex(placement.clip) != nil else { throw CommandError.unknownClip(placement.clip) }
                try Command.validateStart(placement.start)
            }
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
