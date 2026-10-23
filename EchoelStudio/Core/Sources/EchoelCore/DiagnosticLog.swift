import Foundation

/// The app's own diagnostic log: one text file the musician shares from Files, holding the run
/// before this one and this run (NEUPLANUNG §6 — no account, no server, no telemetry, no crash
/// SDK; the log is local and the user exports it). A line is written with one unbuffered write
/// before the call returns, so a run that dies after a step still shows the step.
///
/// What a line can hold is fixed by its types: the event, a reason and the field names are
/// `StaticString`, so only text written in the source reaches the file; values are numbers. An
/// error writes its domain and code, never its description, which can carry a file's name. The
/// version and the build are kept to digits and dots. So nothing a musician typed — a song's,
/// a track's or a file's name — is ever in the file.
///
/// Any thread but the render thread: a line takes a lock and writes to a file.
public final class DiagnosticLog: @unchecked Sendable {
    /// The line above the run before this one.
    public static let previousRunHeader = "== previous run =="
    /// The line above this run.
    public static let thisRunHeader = "== this run =="
    /// The last line of a run that reached `capacity`.
    public static let fullLine = "diagnostics: this run's log is full, later lines are dropped"

    public let url: URL
    /// The bytes one run may take, its header included; the file holds at most two runs.
    public let capacity: Int
    private let clock: @Sendable () -> Date
    private let lock = NSLock()
    private var handle: FileHandle?
    private var written = 0
    private var isFull = false

    public init(url: URL, capacity: Int = 256 * 1024, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.url = url
        self.capacity = Swift.max(1024, capacity)
        self.clock = clock
    }

    deinit {
        try? handle?.close()
    }

    /// Starts this run: the last run's lines move under `previousRunHeader`, the run before that
    /// is dropped, and the first line names the version and build. Once per launch; a log whose
    /// folder cannot be made or written stays silent and never throws.
    public func begin(version: String, build: String) {
        lock.lock()
        defer { lock.unlock() }
        try? handle?.close()
        handle = nil
        written = 0
        isFull = false
        let files = FileManager.default
        do {
            try files.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            // A run written under a larger capacity keeps only its end.
            let whole = Self.lastRun(in: (try? String(contentsOf: url, encoding: .utf8)) ?? "")
            let last = String(decoding: whole.utf8.suffix(capacity), as: UTF8.self)
            var start = ""
            if !last.isEmpty {
                start += Self.previousRunHeader + "\n" + last
                if !last.hasSuffix("\n") { start += "\n" }
            }
            start += Self.thisRunHeader + "\n"
            try Data(start.utf8).write(to: url, options: .atomic)
            let file = try FileHandle(forWritingTo: url)
            try file.seekToEnd()
            handle = file
            written = (Self.thisRunHeader + "\n").utf8.count
        } catch {
            return
        }
        append(stamped("app: launch v\(Self.plain(version)) (\(Self.plain(build)))"))
    }

    /// Writes `event`, then `(reason)` when there is one, then each field as `name=value`.
    /// Returns the line without its time, for a log that stamps its own (`os_log`).
    @discardableResult
    public func note(_ event: StaticString, because reason: StaticString? = nil,
                     _ fields: [(StaticString, Double)] = []) -> String {
        var line = event.description
        if let reason { line += " (\(reason.description))" }
        for (name, value) in fields { line += " \(name.description)=\(Self.number(value))" }
        lock.lock()
        defer { lock.unlock() }
        append(stamped(line))
        return line
    }

    /// Writes `event` with the error's domain and code — never its description.
    @discardableResult
    public func note(_ event: StaticString, error: any Error) -> String {
        let line = "\(event.description) error=\(error._domain) code=\(error._code)"
        lock.lock()
        defer { lock.unlock() }
        append(stamped(line))
        return line
    }

    /// The file as it stands: the run before this one, then this run.
    public func text() -> String {
        lock.lock()
        defer { lock.unlock() }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
    }

    // MARK: - Under the lock

    private func append(_ line: String) {
        guard let handle, !isFull else { return }
        var bytes = Data((line + "\n").utf8)
        let room = capacity - written
        if bytes.count + Self.fullLine.utf8.count + 1 > room {
            isFull = true
            bytes = Data((Self.fullLine + "\n").utf8)
        }
        do {
            try handle.write(contentsOf: bytes)
            written += bytes.count
        } catch {
            isFull = true
        }
    }

    private func stamped(_ line: String) -> String {
        Self.timestamp(clock()) + "  " + line
    }

    // MARK: - Pure

    /// The lines under the last `thisRunHeader`, or nothing when the file has none (an empty
    /// file, a file this log did not write).
    static func lastRun(in text: String) -> String {
        guard let marker = text.range(of: thisRunHeader + "\n", options: .backwards) else { return "" }
        return String(text[marker.upperBound...])
    }

    /// Digits and dots only, at most 16 of them; anything else is `?`.
    static func plain(_ value: String) -> String {
        let allowed = !value.isEmpty && value.count <= 16 && value.allSatisfy { $0 == "." || ($0.isASCII && $0.isWholeNumber) }
        return allowed ? value : "?"
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
