import Foundation

/// Reads a Standard MIDI File (format 0 or 1) — the counterpart of `MIDIFile`, which writes one —
/// and turns it into commands that add its notes to a song as new instrument tracks, one undo step.
///
/// What is read: notes (on, off, an on at velocity 0 as off), the tempo map and the first time
/// signature. Controllers, bends, programs and system exclusive are stepped over. Format 1 keeps
/// one track per file track that plays notes; format 0 is split by channel. A track whose notes
/// are all on channel 10 plays the drum kit, as General MIDI places drums there. Ticks are scaled
/// to the document's 960 per quarter. A file in timecode division or format 2 is refused.
public enum MIDIFileImport {
    /// Larger files are refused before they are read: no song needs one.
    public static let maximumBytes = 16 * 1_024 * 1_024
    /// Notes over the whole file; a file with more is refused rather than cut.
    public static let maximumNotes = 200_000

    public enum ReadError: Error, Equatable, Sendable {
        case notAMIDIFile
        case tooLarge
        case unsupportedFormat(Int)
        /// SMPTE timecode division: frames, not beats, so it has no bars to land on.
        case timecodeDivision
        /// A chunk or an event runs past the end of the file, or a data byte has no status.
        case damaged
        case tooManyNotes
        case noNotes
        /// The song holds no more instrument tracks than `free`; the file needs `needed`.
        case tooManyTracks(needed: Int, free: Int)

        public var explanation: String {
            switch self {
            case .notAMIDIFile: "The file is not a MIDI file."
            case .tooLarge: "The MIDI file is larger than Echoel reads."
            case .unsupportedFormat(let format): "MIDI files of format \(format) are not read; formats 0 and 1 are."
            case .timecodeDivision: "The MIDI file counts in timecode frames, not beats."
            case .damaged: "The MIDI file is damaged."
            case .tooManyNotes: "The MIDI file holds more notes than Echoel reads at once."
            case .noNotes: "The MIDI file plays no notes."
            case let .tooManyTracks(needed, free):
                "The file has \(needed) tracks with notes; the song has room for \(free) more instrument tracks."
            }
        }
    }

    /// One track's notes, in document ticks from the start of the file.
    public struct ImportedTrack: Equatable, Sendable {
        public var name: String?
        /// Every note is on MIDI channel 10 (index 9).
        public var isDrums: Bool
        public var notes: [Note]
    }

    public struct Content: Equatable, Sendable {
        public var tracks: [ImportedTrack]
        /// The tempo at the start; nil when the file names none (MIDI then means 120).
        public var tempo: Double?
        /// Tempo changes after the start, in document ticks.
        public var tempoChanges: [TempoChange]
        public var timeSignature: TimeSignature?
    }

    // MARK: Reading

    public static func read(_ data: Data) throws -> Content {
        guard data.count <= maximumBytes else { throw ReadError.tooLarge }
        var reader = ByteReader(bytes: [UInt8](data))
        guard reader.remaining >= 14, reader.tag() == "MThd" else { throw ReadError.notAMIDIFile }
        let headerSize = try reader.u32()
        let headerLength = Int(headerSize)
        guard headerLength >= 6 else { throw ReadError.damaged }
        let formatField = try reader.u16()
        let format = Int(formatField)
        _ = try reader.u16()   // the track count; the chunks themselves are what is read
        let division = try reader.u16()
        try reader.skip(headerLength - 6)
        guard format == 0 || format == 1 else { throw ReadError.unsupportedFormat(format) }
        guard division & 0x8000 == 0 else { throw ReadError.timecodeDivision }
        guard division > 0 else { throw ReadError.damaged }

        var parsed: [ParsedTrack] = []
        var noteCount = 0
        while reader.remaining >= 8 {
            let tag = reader.tag()
            let size = try reader.u32()
            let length = Int(size)
            guard length <= reader.remaining else { throw ReadError.damaged }
            if tag == "MTrk" {
                var track = ByteReader(bytes: reader.bytes, at: reader.at, end: reader.at + length)
                let one = try parseTrack(&track, division: Int64(division))
                noteCount += one.notes.count
                guard noteCount <= maximumNotes else { throw ReadError.tooManyNotes }
                parsed.append(one)
            }
            try reader.skip(length)
        }

        var tempos: [Tick: Double] = [:]
        var signature: TimeSignature?
        for track in parsed {
            for (tick, bpm) in track.tempos { tempos[tick] = bpm }
            if signature == nil { signature = track.signature }
        }
        let tracks = format == 0 ? parsed.flatMap(splitByChannel) : parsed.compactMap(asTrack)
        guard !tracks.isEmpty else { throw ReadError.noNotes }
        return Content(tracks: tracks,
                       tempo: tempos[0],
                       tempoChanges: tempos.filter { $0.key > 0 }.sorted { $0.key < $1.key }
                           .map { TempoChange(tick: $0.key, bpm: $0.value) },
                       timeSignature: signature)
    }

    /// A note as read, with its channel, before the file's tracks become the song's.
    struct ChannelNote: Equatable {
        var channel: Int
        var note: Note
    }

    struct ParsedTrack {
        var name: String?
        var notes: [ChannelNote] = []
        var tempos: [(Tick, Double)] = []
        var signature: TimeSignature?
    }

    static func parseTrack(_ reader: inout ByteReader, division: Int64) throws -> ParsedTrack {
        var track = ParsedTrack()
        var raw: Int64 = 0
        var status: UInt8?
        /// Notes sounding, by channel and pitch: start ticks and velocities, first on, first off.
        var open: [Int: [(start: Tick, velocity: Int)]] = [:]
        func document(_ tick: Int64) -> Tick {
            Swift.min((tick * MusicalTime.ticksPerQuarter + division / 2) / division, MusicalTime.maximumTick + 1)
        }
        func close(_ key: Int, at end: Tick) {
            guard var waiting = open[key], !waiting.isEmpty else { return }
            let first = waiting.removeFirst()
            open[key] = waiting
            guard first.start <= MusicalTime.maximumTick else { return }
            let length = Swift.min(Swift.max(end - first.start, 1), MusicalTime.maximumTick)
            track.notes.append(ChannelNote(channel: key >> 7, note: Note(pitch: key & 0x7F, velocity: first.velocity,
                                                                         start: first.start, length: length)))
        }

        while reader.remaining > 0 {
            // Positions past what a song holds stop counting up; no overflow on a hostile delta.
            let delta = try reader.variableLength()
            raw = Swift.min(raw + Int64(delta), Int64(1) << 40)
            let tick = document(raw)
            var first = try reader.u8()
            if first == 0xFF {
                status = nil
                let type = try reader.u8()
                let size = try reader.variableLength()
                let payload = try reader.take(Int(size))
                switch type {
                case 0x2F:
                    reader.at = reader.end
                case 0x03 where track.name == nil:
                    let name = String(decoding: payload, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty { track.name = name }
                case 0x51 where payload.count == 3:
                    let micros = Int(payload[0]) << 16 | Int(payload[1]) << 8 | Int(payload[2])
                    if micros > 0 {
                        let bpm = Swift.min(Swift.max(60_000_000 / Double(micros), Tempo.range.lowerBound), Tempo.range.upperBound)
                        track.tempos.append((tick, bpm))
                    }
                case 0x58 where payload.count >= 2 && track.signature == nil && payload[1] < 8:
                    let signature = TimeSignature(Int(payload[0]), 1 << Int(payload[1]))
                    if signature.isValid { track.signature = signature }
                default:
                    break
                }
                continue
            }
            if first == 0xF0 || first == 0xF7 {
                status = nil
                let size = try reader.variableLength()
                try reader.skip(Int(size))
                continue
            }
            var data1: UInt8
            if first & 0x80 != 0 {
                status = first
                data1 = try reader.u8()
            } else {
                guard let running = status else { throw ReadError.damaged }
                data1 = first
                first = running
            }
            let kind = first & 0xF0
            let channel = Int(first & 0x0F)
            // Program change and channel pressure carry one data byte, the others two.
            var data2: UInt8 = 0
            if kind != 0xC0 && kind != 0xD0 { data2 = try reader.u8() }
            data1 &= 0x7F
            let key = channel << 7 | Int(data1)
            if kind == 0x90 && data2 & 0x7F > 0 {
                open[key, default: []].append((tick, Int(data2 & 0x7F)))
            } else if kind == 0x80 || kind == 0x90 {
                close(key, at: tick)
            }
        }
        // A note the file never ends stops where its track does.
        let end = document(raw)
        for key in open.keys.sorted() {
            while !(open[key] ?? []).isEmpty { close(key, at: end) }
        }
        track.notes.sort { ($0.note.start, $0.note.pitch) < ($1.note.start, $1.note.pitch) }
        return track
    }

    static func asTrack(_ parsed: ParsedTrack) -> ImportedTrack? {
        guard !parsed.notes.isEmpty else { return nil }
        return ImportedTrack(name: parsed.name, isDrums: parsed.notes.allSatisfy { $0.channel == 9 },
                             notes: parsed.notes.map(\.note))
    }

    static func splitByChannel(_ parsed: ParsedTrack) -> [ImportedTrack] {
        let channels = Set(parsed.notes.map(\.channel)).sorted()
        return channels.map { channel in
            let name = channels.count == 1 ? parsed.name : Names.derived(parsed.name ?? "", suffix: "Ch \(channel + 1)")
            return ImportedTrack(name: name, isDrums: channel == 9,
                                 notes: parsed.notes.filter { $0.channel == channel }.map(\.note))
        }
    }

    // MARK: Commands

    /// What adds `content` to `project`: per track an instrument track (the drum kit for a drum
    /// track) with one clip of the notes, placed at bar 1. An empty arrangement takes the file's
    /// tempo map and time signature as well; a song that already plays something keeps its own,
    /// and the notes land on the same ticks. Perform them as one undo step.
    public static func commands(for content: Content, fileName: String, in project: Project) throws -> [Command] {
        let tracks = content.tracks.filter { !$0.notes.isEmpty }
        guard !tracks.isEmpty else { throw ReadError.noNotes }
        let free = Track.limit(for: .instrument) - project.tracks.filter { $0.kind == .instrument }.count
        guard tracks.count <= free else { throw ReadError.tooManyTracks(needed: tracks.count, free: Swift.max(free, 0)) }

        var commands: [Command] = []
        var signature = project.timeSignature
        if !project.arrangementHasEvents && !project.arrangementHasSound {
            if let fileSignature = content.timeSignature, fileSignature != project.timeSignature {
                commands.append(.setTimeSignature(fileSignature))
                signature = fileSignature
            }
            if let tempo = content.tempo { commands.append(.setTempo(bpm: tempo)) }
            if content.tempo != nil || !content.tempoChanges.isEmpty {
                commands += project.tempoChanges.map { .removeTempoChange(at: $0.tick) }
                commands += content.tempoChanges.filter { $0.tick <= MusicalTime.maximumTick }
                    .map { .setTempoChange(at: $0.tick, bpm: $0.bpm) }
            }
        }

        let bar = Swift.max(MusicalTime.ticksPerBar(signature), 1)
        let base = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        for (index, imported) in tracks.enumerated() {
            let track = TrackID(), clip = ClipID()
            let name = imported.name.map { Names.derived($0, suffix: "") }
                ?? Names.derived(base.isEmpty ? "MIDI" : base, suffix: tracks.count == 1 ? "" : "\(index + 1)")
            let last = imported.notes.map { $0.start + $0.length }.max() ?? bar
            let length = Swift.min(Swift.max((last + bar - 1) / bar * bar, bar), MusicalTime.maximumTick)
            commands.append(.addTrack(id: track, name: name, kind: .instrument, index: nil))
            if imported.isDrums { commands.append(.setInstrumentDevice(track, .drums)) }
            commands.append(.createClip(track: track, id: clip, name: name, length: length))
            commands.append(.addNotes(clip, imported.notes.filter { $0.start < length }))
            commands.append(.placeClip(track: track, id: PlacementID(), clip: clip, start: 0))
        }
        return commands
    }
}

/// Big-endian reading over a byte array with a hard end; every read past it is `damaged`.
struct ByteReader {
    let bytes: [UInt8]
    var at: Int
    let end: Int

    init(bytes: [UInt8], at: Int = 0, end: Int? = nil) {
        self.bytes = bytes
        self.at = at
        self.end = Swift.min(end ?? bytes.count, bytes.count)
    }

    var remaining: Int { Swift.max(end - at, 0) }

    mutating func u8() throws -> UInt8 {
        guard at < end else { throw MIDIFileImport.ReadError.damaged }
        defer { at += 1 }
        return bytes[at]
    }

    mutating func u16() throws -> UInt16 {
        let high = try u8()
        let low = try u8()
        return UInt16(high) << 8 | UInt16(low)
    }

    mutating func u32() throws -> UInt32 {
        let high = try u16()
        let low = try u16()
        return UInt32(high) << 16 | UInt32(low)
    }

    /// Four ASCII letters, or an empty tag when fewer remain.
    mutating func tag() -> String {
        guard remaining >= 4 else { return "" }
        defer { at += 4 }
        return String(decoding: bytes[at..<at + 4], as: UTF8.self)
    }

    mutating func take(_ count: Int) throws -> [UInt8] {
        guard count >= 0, count <= remaining else { throw MIDIFileImport.ReadError.damaged }
        defer { at += count }
        return Array(bytes[at..<at + count])
    }

    mutating func skip(_ count: Int) throws {
        guard count >= 0, count <= remaining else { throw MIDIFileImport.ReadError.damaged }
        at += count
    }

    /// A MIDI variable-length quantity: at most four bytes, 28 bits.
    mutating func variableLength() throws -> UInt32 {
        var value: UInt32 = 0
        for _ in 0..<4 {
            let byte = try u8()
            value = value << 7 | UInt32(byte & 0x7F)
            if byte & 0x80 == 0 { return value }
        }
        throw MIDIFileImport.ReadError.damaged
    }
}
