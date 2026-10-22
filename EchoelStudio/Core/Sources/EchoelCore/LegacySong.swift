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
        let rows = libraryRows(data)
        return (0..<rows.count).compactMap { rows.project(at: $0) }
    }

    /// The earlier app's library read but not yet converted, so the app can bring the songs over
    /// one at a time and record how far it got (review 2026-10-21).
    public static func libraryRows(_ data: Data) -> Library {
        Library(rows: ((try? JSONDecoder().decode([Lenient<SavedSong>].self, from: data)) ?? []).map(\.value))
    }

    /// The earlier app's songs in one place it wrote to, read but not converted: its open song
    /// first, then its library, so the import can bring them over one at a time, each named by its
    /// key (review 2026-10-21, 2026-10-22).
    public struct Songs: Sendable {
        let timeline: Data?
        let clips: Data
        let tempo: Double
        let library: Library

        /// `timeline` and `clips` are the earlier app's open song, nil when it left none; `tempo`
        /// is the one that song was made at, since the earlier app kept no song tempo.
        public init(timeline: Data?, clips: Data, tempo: Double, library: Library) {
            self.timeline = timeline
            self.clips = clips
            self.tempo = tempo
            self.library = library
        }

        /// Every place, the unreadable ones included.
        public var count: Int { (timeline == nil ? 0 : 1) + library.count }

        /// The song in place `index`, or nil when it cannot be read or there is no such place.
        public func project(at index: Int) -> Project? {
            guard let timeline else { return library.project(at: index) }
            guard index == 0 else { return library.project(at: index - 1) }
            return try? LegacySong.project(timeline: timeline, clips: clips, tempo: tempo, name: "Earlier Song")
        }

        /// What names the song in place `index` on every launch, wherever it sits: a digest of
        /// what the earlier app wrote for it, without converting it. The same song read from
        /// another place the earlier app wrote to, or after it saved another song ahead of this
        /// one, has the same key; a song saved again with changes has another. Nil when there is
        /// no such place or its row holds no song at all.
        public func key(at index: Int) -> String? {
            guard let timeline else { return library.key(at: index) }
            guard index == 0 else { return library.key(at: index - 1) }
            return "t" + LegacySong.digest([timeline, clips])
        }
    }

    /// The rows of the earlier app's library. A row keeps its place whether or not it can be read,
    /// so an index names the same song on every launch.
    public struct Library: Sendable {
        let rows: [SavedSong?]

        /// Every row, the unreadable ones included.
        public var count: Int { rows.count }

        /// See `Songs.key(at:)`.
        public func key(at index: Int) -> String? {
            guard rows.indices.contains(index), let song = rows[index] else { return nil }
            return "r" + LegacySong.digest([Data((song.name ?? "").utf8), Data((song.bpm.map { "\($0)" } ?? "").utf8),
                                            song.session ?? Data()])
        }

        /// The song in row `index`, each with the name it was saved under; nil when the row or its
        /// envelope cannot be read, or there is no such row.
        public func project(at index: Int) -> Project? {
            guard rows.indices.contains(index), let song = rows[index], let session = song.session,
                  let envelope = try? JSONDecoder().decode(Envelope.self, from: session) else { return nil }
            let tempo = envelope.timebase?.tempoMap?.entries.first?.bpm ?? song.bpm ?? Tempo.defaultBPM
            let clips = envelope.content.clipSlots.compactMap { $0.value ?? nil }
            let name = song.name ?? envelope.meta?.name ?? "Imported Song"
            return try? LegacySong.project(envelope.content.timeline, clips: clips, tempo: tempo, name: name)
        }
    }

    /// FNV-1a over the parts, each led by its length so two parts never read as one: the same
    /// bytes give the same key on every launch and every platform, which `Hasher` does not.
    static func digest(_ parts: [Data]) -> String {
        let prime: UInt64 = 0x0000_0100_0000_01b3
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for part in parts {
            var length = UInt64(part.count)
            for _ in 0..<8 {
                hash = (hash ^ (length & 0xff)) &* prime
                length >>= 8
            }
            for byte in part { hash = (hash ^ UInt64(byte)) &* prime }
        }
        let hex = String(hash, radix: 16)
        return String(repeating: "0", count: 16 - hex.count) + hex
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
        // Held to 0…1 before it becomes an Int: a damaged file's 1e30 would trap the conversion.
        let velocity = Double(old.velocity ?? 0.8)
        let midi = velocity.isFinite ? Int((Swift.min(Swift.max(velocity, 0), 1) * 127).rounded()) : 100
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

    struct SavedSong: Decodable, Sendable {
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
