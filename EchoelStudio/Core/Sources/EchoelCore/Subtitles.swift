import Foundation

public typealias SubtitleID = Identifier<SubtitleCue>

/// One subtitle: a line or two of text shown from `start` to `end` on the song's timeline
/// (SUBS, 2026-11-05). Optional inside format 4: a song without subtitles stores no key, exactly
/// as before. Echoel writes them from speech it recognizes on the device (Transcribe) and the
/// musician edits them; they leave the app as SRT, WebVTT and OTIO markers.
public struct SubtitleCue: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: SubtitleID
    /// Where the cue appears and disappears, in ticks from the song's start; `start` < `end`.
    public var start: Tick
    public var end: Tick
    /// One line of plain text, single spaces, no line breaks: the export breaks it into lines.
    public var text: String

    public init(id: SubtitleID = SubtitleID(), start: Tick, end: Tick, text: String) {
        self.id = id
        self.start = start
        self.end = end
        self.text = text
    }

    /// How many cues one song holds. An hour of speech is about a thousand; the bound keeps a
    /// damaged file from carrying millions.
    public static let maximumCount = 10_000
}

/// The arithmetic of subtitles: text into lines, recognized words into cues, cues into SRT and
/// WebVTT. Plain functions over values — the app's recognizer hands words in, the export takes the
/// text out; nothing here hears or writes a file.
public enum Subtitles {
    /// Characters on one line, and lines in one cue — the broadcast convention.
    public static let maximumLineLength = 42
    public static let maximumLines = 2
    /// A pause longer than this between two words starts a new cue.
    public static let pauseSeconds = 0.7
    /// A cue lasts at most this long.
    public static let maximumCueSeconds = 6.0

    // MARK: - Text

    /// The text as a cue stores it: every run of spaces, tabs and line breaks one space, control
    /// characters dropped, nothing at either end.
    public static func normalized(_ text: String) -> String {
        var out = ""
        var pendingSpace = false
        for scalar in text.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                pendingSpace = !out.isEmpty
                continue
            }
            if CharacterSet.controlCharacters.contains(scalar) { continue }
            if pendingSpace { out.unicodeScalars.append(" ") }
            pendingSpace = false
            out.unicodeScalars.append(scalar)
        }
        return out
    }

    /// The text broken into lines of at most `maximumLineLength` characters at its spaces, each
    /// line as full as the next word allows; a word longer than a line is cut. Counted in
    /// characters as a reader sees them.
    public static func lines(_ text: String) -> [String] {
        var lines: [String] = []
        var current = ""
        for word in normalized(text).split(separator: " ") {
            var rest = String(word)
            while rest.count > maximumLineLength {
                if !current.isEmpty {
                    lines.append(current)
                    current = ""
                }
                lines.append(String(rest.prefix(maximumLineLength)))
                rest = String(rest.dropFirst(maximumLineLength))
            }
            if rest.isEmpty { continue }
            if current.isEmpty {
                current = rest
            } else if current.count + 1 + rest.count <= maximumLineLength {
                current += " " + rest
            } else {
                lines.append(current)
                current = rest
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }

    /// Whether the text is one a cue may store: normalized, not empty, within two lines.
    public static func isValidText(_ text: String) -> Bool {
        !text.isEmpty && normalized(text) == text && lines(text).count <= maximumLines
    }

    // MARK: - Words into cues

    /// One recognized word (or a few, as a recognizer reports them) with its time in seconds from
    /// the start of what was heard.
    public struct Word: Equatable, Sendable {
        public var text: String
        public var start: Double
        public var end: Double

        public init(text: String, start: Double, end: Double) {
            self.text = text
            self.start = start
            self.end = end
        }
    }

    /// A cue in seconds from the start of what was heard, before it is placed on the timeline.
    public struct TimedText: Equatable, Sendable {
        public var start: Double
        public var end: Double
        public var text: String

        public init(start: Double, end: Double, text: String) {
            self.start = start
            self.end = end
            self.text = text
        }
    }

    /// The words gathered into cues: a pause longer than `pauseSeconds` starts a new one, as does a
    /// cue that would last longer than `maximumCueSeconds` or not fit two lines. Words without
    /// text or with a time that is not a number are left out; the words are taken in time order,
    /// and a cue never starts before the one before it ended. A single word longer than six
    /// seconds is held for six.
    public static func cues(from words: [Word]) -> [TimedText] {
        let clean = words.compactMap { word -> Word? in
            let text = normalized(word.text)
            guard !text.isEmpty, word.start.isFinite, word.end.isFinite else { return nil }
            let start = Swift.max(0, word.start)
            return Word(text: text, start: start, end: Swift.max(start, word.end))
        }
        let ordered = clean.enumerated().sorted { a, b in
            a.element.start != b.element.start ? a.element.start < b.element.start : a.offset < b.offset
        }.map(\.element)
        // A word too long for two lines is cut into pieces that each fit, sharing its time evenly.
        var pieces: [Word] = []
        let room = maximumLineLength * maximumLines
        for word in ordered {
            let chunks = lines(word.text).count <= maximumLines ? [word.text] : stride(from: 0, to: word.text.count, by: room).map {
                String(word.text.dropFirst($0).prefix(room))
            }
            let share = (word.end - word.start) / Double(chunks.count)
            for (index, chunk) in chunks.enumerated() {
                pieces.append(Word(text: chunk, start: word.start + share * Double(index),
                                   end: word.start + share * Double(index + 1)))
            }
        }
        var cues: [TimedText] = []
        var current: TimedText?
        func close() {
            guard var cue = current else { return }
            if let last = cues.last { cue.start = Swift.max(cue.start, last.end) }
            cue.end = Swift.min(Swift.max(cue.end, cue.start), cue.start + maximumCueSeconds)
            cues.append(cue)
            current = nil
        }
        for word in pieces {
            if let cue = current {
                let joined = cue.text + " " + word.text
                let paused = word.start - cue.end > pauseSeconds
                let tooLong = word.end - cue.start > maximumCueSeconds
                if paused || tooLong || lines(joined).count > maximumLines {
                    close()
                } else {
                    current = TimedText(start: cue.start, end: Swift.max(cue.end, word.end), text: joined)
                    continue
                }
            }
            current = TimedText(start: word.start, end: word.end, text: word.text)
        }
        close()
        return cues
    }

    /// The cues placed on the timeline: `origin` is the song second where what was heard began,
    /// `scale` the song seconds one second of it lasts (1 at the file's own speed). A cue that
    /// would last no tick, or lands past the song's last tick, is left out.
    public static func placed(_ cues: [TimedText], at origin: Double, scale: Double = 1,
                              tempoMap map: TempoMap) -> [SubtitleCue] {
        guard origin.isFinite, scale.isFinite, scale > 0 else { return [] }
        var placed: [SubtitleCue] = []
        for cue in cues {
            // To the nearest tick: a second of speech lands on the tick it names, not one before.
            let start = MusicalTime.integer(map.position(atSeconds: origin + cue.start * scale).rounded())
            var end = MusicalTime.integer(map.position(atSeconds: origin + cue.end * scale).rounded())
            if let last = placed.last, start < last.end { continue }
            if end <= start { end = start + 1 }
            guard start >= 0, end <= MusicalTime.maximumTick else { continue }
            let text = normalized(cue.text)
            guard isValidText(text) else { continue }
            placed.append(SubtitleCue(start: start, end: end, text: text))
        }
        return placed
    }

    // MARK: - Validation

    /// At most `SubtitleCue.maximumCount` cues, each id once, each `start` < `end` within the
    /// timeline, starts rising and never before the cue before ended, each text valid.
    static func validate(_ cues: [SubtitleCue]) throws {
        guard cues.count <= SubtitleCue.maximumCount else {
            throw CommandError.invalidValue(parameter: "subtitles", reason: "at most \(SubtitleCue.maximumCount)")
        }
        var ids = Set<SubtitleID>()
        var previousEnd: Tick = 0
        for cue in cues {
            guard ids.insert(cue.id).inserted else { throw CommandError.duplicateID(cue.id.description) }
            guard cue.start >= previousEnd, cue.start < cue.end, cue.end <= MusicalTime.maximumTick else {
                throw CommandError.invalidValue(parameter: "subtitles",
                                                reason: "each cue ends after it starts and starts after the one before ended")
            }
            guard isValidText(cue.text) else {
                throw CommandError.invalidValue(parameter: "subtitles",
                                                reason: "a text is empty, has line breaks or needs more than two lines of \(maximumLineLength) characters")
            }
            previousEnd = cue.end
        }
    }

    // MARK: - SRT and WebVTT

    /// A time in whole milliseconds, half a millisecond rounding up.
    public static func milliseconds(_ seconds: Double) -> Int {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        let value = (seconds * 1_000).rounded(.toNearestOrAwayFromZero)
        return value < Double(Int32.max) * 1_000 ? Int(value) : Int(Int32.max) * 1_000
    }

    /// `HH:MM:SS<separator>mmm` — a comma for SRT, a full stop for WebVTT.
    public static func timestamp(_ milliseconds: Int, separator: Character) -> String {
        let ms = Swift.max(0, milliseconds)
        let hours = ms / 3_600_000, minutes = ms / 60_000 % 60, seconds = ms / 1_000 % 60, rest = ms % 1_000
        func pad(_ value: Int, _ width: Int) -> String {
            let digits = String(value)
            return String(repeating: "0", count: Swift.max(0, width - digits.count)) + digits
        }
        return "\(pad(hours, 2)):\(pad(minutes, 2)):\(pad(seconds, 2))\(separator)\(pad(rest, 3))"
    }

    /// Each cue's start and end in milliseconds from the song's start, over its tempo map; an end
    /// that rounds onto its start lasts one millisecond.
    static func times(_ project: Project) -> [(start: Int, end: Int, lines: [String])] {
        let map = project.tempoMap
        return project.subtitles.map { cue in
            let start = milliseconds(map.seconds(at: cue.start))
            let end = Swift.max(start + 1, milliseconds(map.seconds(at: cue.end)))
            return (start, end, lines(cue.text))
        }
    }

    /// SRT has no escape: the angle brackets players read as tags are written as their look-alikes
    /// `‹` and `›`, so a text is shown as it was typed.
    public static func escapedSRT(_ line: String) -> String {
        line.replacingOccurrences(of: "<", with: "‹").replacingOccurrences(of: ">", with: "›")
    }

    /// WebVTT's three escapes: `&`, `<` and `>` as character references.
    public static func escapedVTT(_ line: String) -> String {
        line.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// The song's subtitles as SubRip text: numbered from 1, `HH:MM:SS,mmm --> HH:MM:SS,mmm`, the
    /// lines, a blank line; UTF-8, `\n` line ends. The same song gives the same bytes.
    public static func srt(for project: Project) -> String {
        var out = ""
        for (index, cue) in times(project).enumerated() {
            out += "\(index + 1)\n"
            out += "\(timestamp(cue.start, separator: ",")) --> \(timestamp(cue.end, separator: ","))\n"
            for line in cue.lines { out += escapedSRT(line) + "\n" }
            out += "\n"
        }
        return out
    }

    /// The song's subtitles as WebVTT: the `WEBVTT` header, then each cue's
    /// `HH:MM:SS.mmm --> HH:MM:SS.mmm` and its lines, a blank line between; UTF-8, `\n` line ends.
    public static func vtt(for project: Project) -> String {
        var out = "WEBVTT\n\n"
        for cue in times(project) {
            out += "\(timestamp(cue.start, separator: ".")) --> \(timestamp(cue.end, separator: "."))\n"
            for line in cue.lines { out += escapedVTT(line) + "\n" }
            out += "\n"
        }
        return out
    }
}

extension Project {
    /// The cue with `id`, if the song has one.
    public func subtitle(_ id: SubtitleID) -> SubtitleCue? {
        subtitles.first { $0.id == id }
    }

    /// Changes the subtitles on a copy and keeps it only when the whole list is still valid.
    mutating func applySubtitles(_ change: (inout [SubtitleCue]) throws -> Void) throws {
        var draft = subtitles
        try change(&draft)
        draft.sort { $0.start != $1.start ? $0.start < $1.start : $0.end < $1.end }
        try Subtitles.validate(draft)
        subtitles = draft
    }
}
