import Foundation

/// The app's own diagnostic log: one text file the musician shares from Files, holding the latest
/// run and the run before it (NEUPLANUNG §6 — no account, no server, no telemetry, no crash SDK;
/// the log is local and the user exports it). A line is written with one unbuffered write before
/// the call returns, so a run that dies after a step still shows the step. "Latest", not "this":
/// shared after a crash and before the next launch, the last run in the file is the one that died.
///
/// What a line can hold is fixed by its types: the event, a reason and the field names are
/// `StaticString`, so only text written in the source reaches the file; values are numbers. An
/// error writes its domain and code, never its description, which can carry a file's name; the
/// domain — a developer's string, a type name for a Swift error — keeps letters, digits, dots,
/// dashes and underscores only, the last 64 of them. The version and the build are kept to digits
/// and dots. So nothing a musician typed — a song's, a track's or a file's name — reaches the file
/// through what this type writes. A run carried over keeps only lines in this log's shape (a time
/// stamp, two spaces, no control character): text added to the file in Files in another shape does
/// not move on, but a line typed in that exact shape would.
///
/// Any thread but the render thread: a line takes a lock and writes to a file.
public final class DiagnosticLog: @unchecked Sendable {
    /// The line above the run before the latest one.
    public static let runBeforeHeader = "== run before =="
    /// The line above the latest run.
    public static let latestRunHeader = "== latest run =="
    /// The last line of a run that reached `capacity`.
    public static let fullLine = "diagnostics: log full here, the run's later lines are dropped"

    public let url: URL
    /// The bytes one run may take, its header included, 1 KiB to 64 MiB; the file holds at most two
    /// runs.
    public let capacity: Int
    private let clock: @Sendable () -> Date
    private let lock = NSLock()
    private var handle: FileHandle?
    private var written = 0
    private var isFull = false

    public init(url: URL, capacity: Int = 256 * 1024, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.url = url
        // Bounded, so the end the next launch reads (`2 * capacity + 64`) cannot overflow.
        self.capacity = Swift.min(Swift.max(1024, capacity), 64 * 1024 * 1024)
        self.clock = clock
    }

    deinit {
        try? handle?.close()
    }

    /// Starts a run: the last run's lines move under `runBeforeHeader`, the run before that is
    /// dropped, and the first line names the version and build. Once per launch; a log whose
    /// folder cannot be made or written stays silent and never throws.
    public func begin(version: String, build: String) {
        let launch = "app: launch v\(Self.plain(version)) (\(Self.plain(build))), times in UTC"
        let time = Self.timestamp(clock())
        lock.lock()
        defer { lock.unlock() }
        try? handle?.close()
        handle = nil
        written = 0
        isFull = false
        let files = FileManager.default
        do {
            try files.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            // Only the end of the file is read, and a byte cut short by a lost battery costs one
            // character, not the run: the run before a crash is what the file is for.
            let last = Self.ownLines(Self.lastRun(in: Self.tail(of: url, bytes: 2 * capacity + 64)), budget: capacity)
            var start = ""
            if !last.isEmpty { start += Self.runBeforeHeader + "\n" + last }
            start += Self.latestRunHeader + "\n"
            try Data(start.utf8).write(to: url, options: .atomic)
            let file = try FileHandle(forWritingTo: url)
            try file.seekToEnd()
            handle = file
            written = (Self.latestRunHeader + "\n").utf8.count
        } catch {
            return
        }
        append(launch, at: time)
    }

    /// Writes `event`, then `(reason)` when there is one, then each field as `name=value`.
    /// Returns the line without its time, for a log that stamps its own (`os_log`).
    @discardableResult
    public func note(_ event: StaticString, because reason: StaticString? = nil,
                     _ fields: [(StaticString, Double)] = []) -> String {
        var line = event.description
        if let reason { line += " (\(reason.description))" }
        for (name, value) in fields { line += " \(name.description)=\(Self.number(value))" }
        let time = Self.timestamp(clock())
        lock.lock()
        defer { lock.unlock() }
        append(line, at: time)
        return line
    }

    /// Writes `event` with the error's domain and code — never its description.
    @discardableResult
    public func note(_ event: StaticString, error: any Error) -> String {
        let line = "\(event.description) error=\(Self.domain(error._domain)) code=\(error._code)"
        let time = Self.timestamp(clock())
        lock.lock()
        defer { lock.unlock() }
        append(line, at: time)
        return line
    }

    /// The file as it stands: the run before, then the latest run.
    public func text() -> String {
        lock.lock()
        defer { lock.unlock() }
        return (try? Data(contentsOf: url)).map { String(decoding: $0, as: UTF8.self) } ?? ""
    }

    // MARK: - Under the lock

    /// `time` was read before the lock, so the clock never runs while it is held.
    private func append(_ line: String, at time: String) {
        guard let handle, !isFull else { return }
        var bytes = Data((time + "  " + line + "\n").utf8)
        let closing = (time + "  " + Self.fullLine + "\n").utf8.count
        if bytes.count + closing > capacity - written {
            isFull = true
            bytes = Data((time + "  " + Self.fullLine + "\n").utf8)
        }
        do {
            try handle.write(contentsOf: bytes)
            written += bytes.count
        } catch {
            isFull = true
        }
    }

    // MARK: - Pure

    /// The last `bytes` of the file, decoded so that a broken byte becomes U+FFFD instead of
    /// losing the text; empty when there is no file.
    static func tail(of url: URL, bytes: Int) -> String {
        guard let file = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? file.close() }
        guard let size = try? file.seekToEnd() else { return "" }
        let start = size > UInt64(bytes) ? size - UInt64(bytes) : 0
        guard (try? file.seek(toOffset: start)) != nil, let data = try? file.readToEnd() else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    /// The lines under the last `latestRunHeader`, or nothing when the text has none (an empty
    /// file, a file this log did not write).
    static func lastRun(in text: String) -> String {
        guard let marker = text.range(of: latestRunHeader + "\n", options: .backwards) else { return "" }
        return String(text[marker.upperBound...])
    }

    /// The lines in this log's shape, each ending in a newline, the newest that fit in `budget`
    /// bytes. A run's header and a line in any other shape stay behind; a line a crash cut short
    /// keeps what it has.
    static func ownLines(_ text: String, budget: Int) -> String {
        var kept: [Substring] = []
        var bytes = 0
        for line in text.split(separator: "\n", omittingEmptySubsequences: true).reversed() where isOwn(line) {
            let size = line.utf8.count + 1
            guard bytes + size <= budget else { break }
            kept.append(line)
            bytes += size
        }
        return kept.reversed().map { String($0) + "\n" }.joined()
    }

    private static func isOwn(_ line: Substring) -> Bool {
        let shape = Array("0000-00-00T00:00:00.000Z  ".utf8)
        let bytes = Array(line.utf8.prefix(shape.count + 1))
        guard bytes.count > shape.count else { return false }
        for (byte, expected) in zip(bytes, shape) {
            let digit = byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
            guard expected == UInt8(ascii: "0") ? digit : byte == expected else { return false }
        }
        return !line.unicodeScalars.contains { $0.properties.generalCategory == .control }
    }

    /// Digits and dots only, at most 16 of them; anything else is `?`.
    static func plain(_ value: String) -> String {
        let allowed = !value.isEmpty && value.count <= 16 && value.allSatisfy { $0 == "." || ($0.isASCII && $0.isWholeNumber) }
        return allowed ? value : "?"
    }

    /// An error domain kept to ASCII letters, digits, `.`, `-` and `_`, its last 64 characters —
    /// the end names the type, the start is the module; every other character becomes `_`, so the
    /// line stays one line.
    static func domain(_ value: String) -> String {
        let kept = value.suffix(64).map { character -> Character in
            character.isASCII && (character.isLetter || character.isNumber || "._-".contains(character)) ? character : "_"
        }
        return kept.isEmpty ? "?" : String(kept)
    }

    /// A whole number without a fraction, any other to three places.
    static func number(_ value: Double) -> String {
        guard value.isFinite else { return value.isNaN ? "nan" : (value > 0 ? "inf" : "-inf") }
        if value.rounded() == value, Swift.abs(value) < 1e15 { return String(Int64(value)) }
        return String((value * 1000).rounded() / 1000)
    }

    /// UTC to the millisecond, `2026-10-23T01:15:00.250Z`, by the civil-from-days arithmetic so
    /// no calendar or time zone is involved.
    static func timestamp(_ date: Date) -> String {
        let milliseconds = Int64((date.timeIntervalSince1970 * 1000).rounded(.down))
        let (seconds, fraction) = floorDivision(milliseconds, 1000)
        let (days, secondOfDay) = floorDivision(seconds, 86_400)
        let z = days + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let dayOfEra = z - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1_460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let shifted = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * shifted + 2) / 5 + 1
        let month = shifted < 10 ? shifted + 3 : shifted - 9
        let year = yearOfEra + era * 400 + (month <= 2 ? 1 : 0)
        return "\(pad(year, 4))-\(pad(month, 2))-\(pad(day, 2))T\(pad(secondOfDay / 3_600, 2)):"
            + "\(pad(secondOfDay % 3_600 / 60, 2)):\(pad(secondOfDay % 60, 2)).\(pad(fraction, 3))Z"
    }

    private static func floorDivision(_ value: Int64, _ divisor: Int64) -> (Int64, Int64) {
        let remainder = value % divisor
        return remainder < 0 ? (value / divisor - 1, remainder + divisor) : (value / divisor, remainder)
    }

    private static func pad(_ value: Int64, _ width: Int) -> String {
        let digits = String(value)
        return digits.count >= width ? digits : String(repeating: "0", count: width - digits.count) + digits
    }
}
