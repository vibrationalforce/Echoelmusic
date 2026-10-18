import Foundation

/// Reading a song the earlier Echoelmusic app saved, so a tester who updates keeps their music.
///
/// The earlier app kept the arrangement in `Timeline/timeline.json` (lanes and regions) and the
/// clips the regions point at in `Clips/clips.json` (an array of slots, `null` for an empty
/// one), both in the App Group container; a saved song carries the same two inside its project
/// envelope. Only what this app can play is taken: MIDI lanes become instrument tracks with
/// their notes, mixer level, pan, mute and solo; audio lanes become empty audio tracks. Bio,
/// video and visual lanes, drum grids, note operators and audio regions are left behind.
///
/// Every element is read leniently — one unreadable lane, region or clip is skipped, not the
/// song — and the project is built through the commands, so it obeys every rule a song made
/// here obeys.
public enum LegacySong {
    /// The earlier app counted 480 ticks to the quarter note.
    static let ticksPerQuarter: Tick = 480

    /// The song built from the earlier app's two files. Throws when neither holds a lane.
    public static func project(timeline: Data, clips: Data, tempo: Double, name: String) throws -> Project {
        let decoder = JSONDecoder()
        let document = try decoder.decode(Timeline.self, from: timeline)
        let slots = (try? decoder.decode([Lenient<Clip?>].self, from: clips)) ?? []
        return try project(document, clips: slots.compactMap { $0.value ?? nil }, tempo: tempo, name: name)
    }

    /// Every song in the earlier app's library (`projects.json`), each with the name it was
    /// saved under. A song whose envelope cannot be read is left out.
    public static func library(_ data: Data) -> [Project] {
        let decoder = JSONDecoder()
        guard let rows = try? decoder.decode([Lenient<SavedSong>].self, from: data) else { return [] }
        return rows.compactMap { row in
            guard let song = row.value, let session = song.session,
                  let envelope = try? decoder.decode(Envelope.self, from: session) else { return nil }
            let tempo = envelope.timebase?.tempoMap?.entries.first?.bpm ?? song.bpm ?? Tempo.defaultBPM
            let clips = envelope.content.clipSlots.compactMap { $0.value ?? nil }
            let name = song.name ?? envelope.meta?.name ?? "Imported Song"
            return try? project(envelope.content.timeline, clips: clips, tempo: tempo, name: name)
        }
    }

    // MARK: - Conversion

    static func project(_ document: Timeline, clips: [Clip], tempo: Double, name: String) throws -> Project {
        let lanes = document.lanes.compactMap(\.value)
        guard !lanes.isEmpty else {
            throw CommandError.invalidValue(parameter: "timeline", reason: "the song has no lanes")
        }
        var project = Project()
        try Command.renameProject(name: safeName(name, fallback: "Imported Song")).apply(to: &project)
        try Command.setTempo(bpm: tempo.isFinite ? Swift.min(Swift.max(tempo, Tempo.range.lowerBound), Tempo.range.upperBound)
                                                 : Tempo.defaultBPM).apply(to: &project)
        let clipsByID = Dictionary(clips.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let regions = document.regions.compactMap(\.value)
        for (number, lane) in lanes.enumerated() {
            let kind: TrackKind
            switch lane.kind {
            case "midi": kind = .instrument
            case "audio": kind = .audio
            default: continue
            }
            // A song with more lanes than this app has voices keeps the first ones that fit.
            guard project.canAddTrack(kind) else { continue }
            let track = TrackID()
            try Command.addTrack(id: track, name: safeName(lane.name ?? "", fallback: "Track \(number + 1)"),
                                 kind: kind, index: nil).apply(to: &project)
            try mix(lane, onto: track, in: &project)
            guard kind == .instrument else { continue }
            if lane.builtinInstrument == "drums" {
                try Command.setInstrumentDevice(track, .drums).apply(to: &project)
            }
            let own = regions.filter { $0.laneID == lane.id }.sorted { $0.startTick < $1.startTick }
            try place(own, of: lane, clips: clipsByID, on: track, in: &project)
        }
        return project
    }

    /// Level 0…2 (1 is unity) as a fader in dB, pan −1…+1, mute and solo.
    static func mix(_ lane: Lane, onto track: TrackID, in project: inout Project) throws {
        let level = Double(lane.level ?? 1)
        if level.isFinite, level != 1 {
            let db = level > 0 ? 20 * Foundation.log10(level) : MixerStrip.volumeRange.lowerBound
            try Command.setVolume(.track(track), db: Swift.min(Swift.max(db, MixerStrip.volumeRange.lowerBound),
                                                               MixerStrip.volumeRange.upperBound)).apply(to: &project)
        }
        if let pan = lane.pan.map(Double.init), pan.isFinite, pan != 0 {
            try Command.setPan(.track(track), pan: Swift.min(Swift.max(pan, -1), 1)).apply(to: &project)
        }
        if lane.isMuted == true { try Command.setMute(track, true).apply(to: &project) }
        if lane.isSoloed == true { try Command.setSolo(track, true).apply(to: &project) }
    }

    /// Each region plays its clip from its offset for its length, so each distinct stretch of a
    /// clip becomes one clip here, placed wherever a region played it.
    static func place(_ regions: [Region], of lane: Lane, clips: [UUID: Clip], on track: TrackID,
                      in project: inout Project) throws {
        struct Stretch: Hashable { var clip: UUID; var offset: Tick; var length: Tick; var transpose: Int }
        var made: [Stretch: ClipID] = [:]
        for region in regions {
            guard let source = clips[region.clipID], source.kind == "midi" || source.kind == nil else { continue }
            guard let length = converted(region.lengthTicks), length > 0, let start = converted(region.startTick),
                  let offset = converted(Swift.max(0, region.contentOffsetTicks ?? 0)) else { continue }
            let stretch = Stretch(clip: region.clipID, offset: offset, length: length,
                                  transpose: semitones(lane.transposeSemitones) + semitones(region.transposeSemitones))
            let id: ClipID
            if let existing = made[stretch] {
                id = existing
            } else {
                id = ClipID()
                try Command.createClip(track: track, id: id, name: safeName(source.name ?? "", fallback: "Part"),
                                       length: length).apply(to: &project)
                let notes = (source.melody?.notes ?? []).compactMap { $0.value }.compactMap {
                    note($0, from: stretch.offset, length: length, transpose: stretch.transpose)
                }
                if !notes.isEmpty { try Command.addNotes(id, notes).apply(to: &project) }
                made[stretch] = id
            }
            try Command.placeClip(track: track, id: PlacementID(), clip: id, start: start).apply(to: &project)
        }
    }

    /// A note of the earlier app in this clip's time, or nil when it lies outside the stretch or
    /// leaves the keyboard.
    static func note(_ old: Note, from offset: Tick, length: Tick, transpose: Int) -> EchoelCore.Note? {
        guard let oldStart = old.startTick ?? steps(old.startStep ?? 0),
              let oldLength = old.lengthTicks ?? steps(old.lengthSteps ?? 1),
              let scaledStart = converted(oldStart) else { return nil }
        // Both lie within a song, so the difference cannot overflow.
        let start = scaledStart - offset
        guard start >= 0, start < length else { return nil }
        let (pitch, overflow) = old.pitch.addingReportingOverflow(transpose)
        guard !overflow, EchoelCore.Note.pitchRange.contains(pitch) else { return nil }
        let noteLength = oldLength > 0 ? converted(oldLength) ?? MusicalTime.maximumTick : 1
        let velocity = Double(old.velocity ?? 0.8)
        let midi = velocity.isFinite ? Int((velocity * 127).rounded()) : 100
        return EchoelCore.Note(pitch: pitch,
                               velocity: Swift.min(Swift.max(midi, EchoelCore.Note.velocityRange.lowerBound),
                                                   EchoelCore.Note.velocityRange.upperBound),
                               start: start, length: Swift.min(Swift.max(noteLength, 1), MusicalTime.maximumTick))
    }

    static var scale: Tick { MusicalTime.ticksPerQuarter / ticksPerQuarter }

    /// Ticks of the earlier app in this format's ticks, or nil when they overflow or lie outside a
    /// song. Every number in its files is read through here: a damaged file holds anything.
    static func converted(_ ticks: Tick) -> Tick? {
        let (value, overflow) = ticks.multipliedReportingOverflow(by: scale)
        return overflow || value < 0 || value > MusicalTime.maximumTick ? nil : value
    }

    /// Sixteenth steps in the earlier app's ticks, or nil on overflow.
    static func steps(_ steps: Tick) -> Tick? {
        let (value, overflow) = steps.multipliedReportingOverflow(by: ticksPerQuarter / 4)
        return overflow ? nil : value
    }

    /// A transpose of the earlier app, held to more than the keyboard spans so a sum cannot overflow.
    static func semitones(_ value: Int?) -> Int {
        Swift.min(Swift.max(value ?? 0, -256), 256)
    }

    static func safeName(_ name: String, fallback: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        return String(trimmed.prefix(Names.maximumLength))
    }

    // MARK: - The earlier app's shapes, only the fields used

    struct Timeline: Decodable {
        var lanes: [Lenient<Lane>]
        var regions: [Lenient<Region>]
    }

    struct Lane: Decodable {
        var id: UUID?
        var name: String?
        var kind: String
        var level: Float?
        var pan: Float?
        var isMuted: Bool?
        var isSoloed: Bool?
        var transposeSemitones: Int?
        var builtinInstrument: String?
    }

    struct Region: Decodable {
        var laneID: UUID
        var clipID: UUID
        var startTick: Tick
        var lengthTicks: Tick
        var contentOffsetTicks: Tick?
        var transposeSemitones: Int?
    }

    struct Clip: Decodable {
        var id: UUID
        var name: String?
        var kind: String?
        var melody: Melody?
    }

    struct Melody: Decodable {
        var notes: [Lenient<Note>]
    }

    struct Note: Decodable {
        var pitch: Int
        var startTick: Tick?
        var lengthTicks: Tick?
        var startStep: Tick?
        var lengthSteps: Tick?
        var velocity: Float?
    }

    struct SavedSong: Decodable {
        var name: String?
        var bpm: Double?
        /// The project envelope, written as base64 by the earlier app's encoder.
        var session: Data?
    }

    struct Envelope: Decodable {
        struct Meta: Decodable { var name: String? }
        struct Timebase: Decodable { var tempoMap: TempoEntries? }
        struct TempoEntries: Decodable { var entries: [Entry]; struct Entry: Decodable { var bpm: Double } }
        struct Content: Decodable {
            var timeline: Timeline
            var clipSlots: [Lenient<Clip?>]
        }
        var meta: Meta?
        var timebase: Timebase?
        var content: Content
    }

    /// One element that may fail to read without failing its array.
    struct Lenient<Value: Decodable>: Decodable {
        var value: Value?
        init(from decoder: Decoder) throws {
            value = try? Value(from: decoder)
        }
    }
}
