import Foundation

/// The first of the app's test agents (2026-11-27): what the diagnostic log (`DiagnosticLog`) says
/// about the two runs it holds, as findings a person can act on — each with what to try and the
/// lines it rests on, the most serious first — and the log itself as the material behind them.
///
/// It reads the log and nothing else, so it knows what the app wrote there: fixed words and
/// numbers, never a name a musician typed, no audio, no song. It judges by the rules written
/// below, not by a model, and it changes nothing: the report is text that stays on the device
/// until the musician shares it.
public struct DiagnosticReport: Equatable, Sendable {
    /// Which run of the file a line belongs to.
    public enum Run: String, Equatable, Sendable {
        case latest = "latest run"
        case before = "run before"
    }

    /// One line of the log, taken apart: `<time>  <event> (<reason>) name=value …`.
    public struct Line: Equatable, Sendable {
        public let run: Run
        /// UTC to the millisecond, as the log writes it: `2026-11-27T10:26:00.250Z`.
        public let time: String
        public let event: String
        public let reason: String?
        /// Each `name=value` at the end of the line, the value as written.
        public let fields: [String: String]
        /// The line as the log has it, for the evidence.
        public let text: String

        /// A field read as a number; nil when the line has none of that name or it is no number.
        public func number(_ name: String) -> Double? {
            fields[name].flatMap { Double($0) }.flatMap { $0.isFinite ? $0 : nil }
        }
    }

    /// One thing the log shows, with what to try and the lines that show it.
    public struct Finding: Equatable, Sendable {
        public enum Weight: Int, Comparable, Sendable {
            /// Worth knowing, nothing to do.
            case note
            /// Something to watch: it may explain what was heard or seen.
            case notice
            /// Something went wrong, and the app carried on.
            case problem
            /// Something did not come back: a crash, a take not written, silence after every try.
            case failure

            public static func < (lhs: Weight, rhs: Weight) -> Bool { lhs.rawValue < rhs.rawValue }

            public var word: String {
                switch self {
                case .note: "Note"
                case .notice: "Notice"
                case .problem: "Problem"
                case .failure: "Failure"
                }
            }
        }

        public let weight: Weight
        public let run: Run
        public let title: String
        /// What the musician can try, or what sharing the report gives.
        public let suggestion: String
        /// How many lines the finding rests on.
        public let count: Int
        /// The last of those lines, at most `DiagnosticReport.evidenceLimit`, oldest first.
        public let evidence: [String]
    }

    /// What one run holds, in numbers.
    public struct RunSummary: Equatable, Sendable {
        public var version: String?
        public var build: String?
        public var firstTime: String?
        public var lastTime: String?
        public var lines = 0
        /// Ten-second windows of audio the engine reported (`engine: render load`).
        public var audioWindows = 0
        /// Callbacks that used more than the time their frames allow.
        public var missedTime = 0
        /// Jumps in the render's sample time: a gap or a repeat.
        public var sampleJumps = 0
        /// The largest share of its time one callback used, 1 = all of it.
        public var highestLoad = 0.0

        /// Whole minutes from the first line to the last; nil without two readable times.
        public var minutes: Int? {
            guard let firstTime, let lastTime,
                  let first = DiagnosticReport.seconds(of: firstTime),
                  let last = DiagnosticReport.seconds(of: lastTime), last >= first else { return nil }
            return Int(((last - first) / 60).rounded())
        }
    }

    /// The most lines a finding quotes.
    public static let evidenceLimit = 3

    public let lines: [Line]
    public let findings: [Finding]
    public let latest: RunSummary
    /// Nil when the file holds one run only.
    public let before: RunSummary?
    /// The log as it was read, the material behind every finding.
    public let log: String

    public init(log text: String) {
        log = text
        var parsed: [Line] = []
        var run: Run = .latest
        var sawBefore = false
        for raw in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(raw)
            if line == DiagnosticLog.runBeforeHeader { run = .before; sawBefore = true; continue }
            if line == DiagnosticLog.latestRunHeader { run = .latest; continue }
            if let taken = Self.parse(line, run: run) { parsed.append(taken) }
        }
        lines = parsed
        latest = Self.summary(of: parsed.filter { $0.run == .latest })
        let earlier = parsed.filter { $0.run == .before }
        before = sawBefore || !earlier.isEmpty ? Self.summary(of: earlier) : nil
        findings = Self.findings(in: parsed)
    }

    // MARK: - Reading a line

    /// The line in the log's shape, taken apart; nil for any other line.
    static func parse(_ text: String, run: Run) -> Line? {
        let separator = "  "
        guard let gap = text.range(of: separator) else { return nil }
        let time = String(text[..<gap.lowerBound])
        guard seconds(of: time) != nil else { return nil }
        var rest = String(text[gap.upperBound...])
        guard !rest.isEmpty else { return nil }
        // The launch line names version and build in its own words, without fields.
        if rest.hasPrefix("app: launch ") {
            return Line(run: run, time: time, event: "app: launch", reason: nil, fields: launchFields(rest), text: text)
        }
        var fields: [String: String] = [:]
        var words = rest.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        while let last = words.last, let taken = field(last) {
            fields[taken.name] = taken.value
            words.removeLast()
        }
        rest = words.joined(separator: " ")
        var reason: String?
        if rest.hasSuffix(")"), let open = rest.range(of: " (", options: .backwards) {
            reason = String(rest[open.upperBound..<rest.index(before: rest.endIndex)])
            rest = String(rest[..<open.lowerBound])
        }
        guard !rest.isEmpty else { return nil }
        return Line(run: run, time: time, event: rest, reason: reason, fields: fields, text: text)
    }

    /// `name=value`, the name a field name as the source writes them; nil for any other word.
    private static func field(_ word: String) -> (name: String, value: String)? {
        guard let equals = word.firstIndex(of: "=") else { return nil }
        let name = word[..<equals]
        let value = word[word.index(after: equals)...]
        guard let first = name.first, first.isLetter || first == "_", !value.isEmpty,
              name.allSatisfy({ ($0.isASCII && ($0.isLetter || $0.isNumber)) || $0 == "_" }) else { return nil }
        return (String(name), String(value))
    }

    /// `app: launch v11.0.0 (10088), times in UTC` → version and build.
    private static func launchFields(_ text: String) -> [String: String] {
        var fields: [String: String] = [:]
        let words = text.split(separator: " ")
        if words.count > 2, words[2].hasPrefix("v") { fields["version"] = String(words[2].dropFirst()) }
        if words.count > 3 {
            let build = String(words[3].filter { $0.isNumber || $0 == "." })
            if !build.isEmpty { fields["build"] = build }
        }
        return fields
    }

    /// Seconds since 1970 for a time in the log's shape, `2026-11-27T10:26:00.250Z`; nil for any
    /// other text. Civil-to-days arithmetic, so no calendar or time zone is involved.
    static func seconds(of stamp: String) -> Double? {
        let bytes = Array(stamp.utf8)
        let shape = Array("0000-00-00T00:00:00.000Z".utf8)
        guard bytes.count == shape.count else { return nil }
        for (byte, expected) in zip(bytes, shape) {
            let digit = byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
            guard expected == UInt8(ascii: "0") ? digit : byte == expected else { return nil }
        }
        func number(_ range: Range<Int>) -> Int {
            range.reduce(0) { $0 * 10 + Int(bytes[$1] - UInt8(ascii: "0")) }
        }
        let (year, month, day) = (number(0..<4), number(5..<7), number(8..<10))
        let (hour, minute, second, milli) = (number(11..<13), number(14..<16), number(17..<19), number(20..<23))
        guard (1...12).contains(month), (1...31).contains(day), hour < 24, minute < 60, second < 61 else { return nil }
        let shifted = month <= 2 ? year - 1 : year
        let era = (shifted >= 0 ? shifted : shifted - 399) / 400
        let yearOfEra = shifted - era * 400
        let dayOfYear = (153 * ((month + 9) % 12) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        let days = era * 146_097 + dayOfEra - 719_468
        return Double(days * 86_400 + hour * 3_600 + minute * 60 + second) + Double(milli) / 1_000
    }

    // MARK: - Numbers

    private static func summary(of lines: [Line]) -> RunSummary {
        var summary = RunSummary()
        summary.lines = lines.count
        summary.firstTime = lines.first?.time
        summary.lastTime = lines.last?.time
        if let launch = lines.first(where: { $0.event == "app: launch" }) {
            summary.version = launch.fields["version"]
            summary.build = launch.fields["build"]
        }
        for line in lines where line.event == "engine: render load" {
            summary.audioWindows += 1
            summary.missedTime += whole(line.number("over100"))
            summary.sampleJumps += whole(line.number("gaps"))
            summary.highestLoad = Swift.max(summary.highestLoad, line.number("peak") ?? 0)
        }
        return summary
    }

    // MARK: - The rules

    private static func findings(in lines: [Line]) -> [Finding] {
        var found: [(Finding, order: Int)] = []
        for run in [Run.latest, .before] {
            let own = lines.filter { $0.run == run }
            for finding in rules(on: own, run: run) { found.append((finding, order: found.count)) }
        }
        if lines.isEmpty {
            found.append((Finding(weight: .note, run: .latest,
                                  title: "The log holds no lines yet.",
                                  suggestion: "Play a song for a minute, then make the report again. If it stays empty, the app could not write its Diagnostics folder.",
                                  count: 0, evidence: []), order: 0))
        }
        return found.sorted { left, right in
            if left.0.weight != right.0.weight { return left.0.weight > right.0.weight }
            if left.0.run != right.0.run { return left.0.run == .latest }
            return left.order < right.order
        }.map { $0.0 }
    }

    /// Every rule over one run's lines. A rule matches fixed event words the app writes; a line it
    /// does not know stays in the material and makes no finding.
    private static func rules(on lines: [Line], run: Run) -> [Finding] {
        var out: [Finding] = []
        func add(_ weight: Finding.Weight, _ events: Set<String>, _ title: (([Line]) -> String),
                 _ suggestion: String) {
            let matching = lines.filter { events.contains($0.event) }
            guard !matching.isEmpty else { return }
            out.append(Finding(weight: weight, run: run, title: title(matching), suggestion: suggestion,
                               count: matching.count, evidence: matching.suffix(evidenceLimit).map(\.text)))
        }

        add(.failure, ["metrickit: crash"], { times("The app ended with a crash", $0.count) },
            "Share this report: the time and the crash's signal point to the fix. iOS reports a crash at the next launch, so it can stand in the run after the one that ended.")
        add(.failure, ["engine: render still stalled after rebuilds", "engine: automatic tries used up"],
            { _ in "The audio stayed silent after the app rebuilt it." },
            "Note what you did just before. Closing and opening the app starts the audio afresh; sharing this report shows where it stopped.")
        add(.failure, ["record: writing failed"], { times("A take could not be written", $0.count) },
            "Check the free space on the device, then record again. The report names the error's code.")

        add(.problem, ["launch: safe start"], { matching in
            let deaths = matching.compactMap { $0.number("deaths") }.max().map { whole($0) } ?? 2
            return "The app did not finish starting \(deaths) times in a row, so it started safely."
        }, "The Field window is off and plugins from other makers wait until you load them. Load them one by one; the one that stops the app is the one to report.")
        add(.problem, ["metrickit: hang"], { matching in
            let longest = matching.compactMap { $0.number("s") }.max() ?? 0
            return "The app stopped responding \(count(matching.count)), the longest for \(seconds(longest))."
        }, "Note which page was open. A hang that repeats on the same page is a fault to fix.")
        add(.problem, ["engine: render stalled, rebuilding"],
            { times("The audio stopped and the app rebuilt it", $0.count) },
            "If you heard a gap, it was here. Share the report with what was playing.")
        add(.problem, ["engine: configure failed", "session: preferred buffer refused", "session: preferred rate refused"],
            { times("iOS refused an audio setting the app asked for", $0.count) },
            "Another app, a call or an audio device may hold the audio. Unplug and plug the device again, or restart the app.")
        add(.problem, ["field: shader compile failed, flat picture", "field: shader entry point missing, flat picture",
                       "field: pipeline failed, flat picture"],
            { _ in "The Field fell back to a flat picture." },
            "The picture works without the GPU look. Sharing the report names the step that failed.")

        let windows = lines.filter { $0.event == "engine: render load" }
        let missed = windows.reduce(0) { $0 + whole($1.number("over100")) }
        let jumps = windows.reduce(0) { $0 + whole($1.number("gaps")) }
        let peak = windows.compactMap { $0.number("peak") }.max() ?? 0
        if missed > 0 {
            let late = windows.filter { ($0.number("over100") ?? 0) > 0 }
            out.append(Finding(weight: .problem, run: run,
                               title: "The audio missed its deadline \(count(missed)) in \(late.count) of \(windows.count) ten-second windows; the highest load was \(percent(peak)).",
                               suggestion: "Note what played: how many tracks and effects, and whether the Field or a video window was open. Fewer at once should stop it; if it happens with little playing, it is a fault to fix.",
                               count: late.count, evidence: late.suffix(evidenceLimit).map(\.text)))
        } else if peak >= 0.75 {
            let busy = windows.filter { ($0.number("over75") ?? 0) > 0 }
            out.append(Finding(weight: .notice, run: run,
                               title: "The audio came close to its time limit: the highest load was \(percent(peak)).",
                               suggestion: "Nothing was missed. Adding more at once may cross the limit; this is the song to measure it with.",
                               count: Swift.max(busy.count, 1), evidence: (busy.isEmpty ? windows : busy).suffix(evidenceLimit).map(\.text)))
        }
        if jumps > 0 {
            let jumped = windows.filter { ($0.number("gaps") ?? 0) > 0 }
            out.append(Finding(weight: .problem, run: run,
                               title: "The audio's sample time jumped \(count(jumps)): a gap or a repeat.",
                               suggestion: "If you heard a click or a gap, the times here say when. Say what you heard with the report.",
                               count: jumped.count, evidence: jumped.suffix(evidenceLimit).map(\.text)))
        }

        add(.notice, ["metrickit: cpu exception", "metrickit: disk write exception"],
            { times("iOS reported the app using too much processor time or writing too much", $0.count) },
            "Share the report; iOS sends these a day later, so the run it names can be an earlier one.")
        add(.notice, ["engine: media services lost", "engine: replace after media services reset"],
            { _ in "iOS restarted its audio services, and the app rebuilt its audio." },
            "Nothing to do if it played on. If it recurs, note what ran at the same time.")
        add(.notice, ["memory: warning"], { times("The device ran low on memory", $0.count) },
            "Samples not playing were released to make room. Close other apps if it repeats.")
        add(.notice, ["field: memory warning, detail down"], { times("The Field lowered its detail for memory", $0.count) },
            "The picture comes back to full detail when memory allows.")
        let lowered = lines.filter { $0.event == "field: detail" && ($0.number("level") ?? 2) < 2 }
        if !lowered.isEmpty {
            let slowest = lowered.compactMap { $0.number("fps") }.min()
            let slowestText = slowest.map { "; the slowest second showed \(whole($0)) frames" } ?? ""
            out.append(Finding(weight: .notice, run: run,
                               title: "The Field lowered its picture detail \(count(lowered.count))\(slowestText).",
                               suggestion: "Heat, Low Power Mode or a heavy song lowers it on purpose, so the sound keeps its time. A cooler device brings it back.",
                               count: lowered.count, evidence: lowered.suffix(evidenceLimit).map(\.text)))
        }
        add(.notice, ["document: recovered takes"], { _ in "Takes were recovered after the app ended without saving them." },
            "They are on their tracks. Listen to their ends: a take cut short by the end is kept as far as it was written.")
        add(.notice, ["stream: ended"], { times("A live stream ended without Stop", $0.count) },
            "The network or the server ended it. The time says when.")
        add(.notice, ["jam: host lost"], { times("The jam lost its host", $0.count) },
            "Being apart or a weak link ends a jam; start it again from Jam.")
        add(.notice, [DiagnosticLog.fullLine], { _ in "The log filled up; what came after is not in it." },
            "Share the report soon after something happens, so the moment is still in the log.")

        add(.note, ["engine: interruption began"], { times("Another app or a call interrupted the audio", $0.count) },
            "Nothing to do; the audio comes back when the interruption ends.")
        add(.note, ["route: output device gone while playing, pausing"],
            { times("The output device went away while playing, so the song paused", $0.count) },
            "Headphones or an interface was unplugged. Play goes on from where it stopped.")
        return out
    }

    private static func times(_ text: String, _ count: Int) -> String {
        count == 1 ? text + "." : text + " \(count) times."
    }

    private static func count(_ value: Int) -> String {
        value == 1 ? "once" : "\(value) times"
    }

    private static func seconds(_ value: Double) -> String {
        guard value.isFinite, value >= 0 else { return "an unknown time" }
        return value < 10 ? "\((value * 10).rounded() / 10) s" : "\(whole(value)) s"
    }

    /// A share of the budget as a whole percent, `0.874` → `87 %`.
    static func percent(_ share: Double) -> String {
        guard share.isFinite else { return "–" }
        return "\(whole(share * 100)) %"
    }

    /// A number from the log as a whole number that cannot trap: the file can be edited in Files,
    /// so a value may be anything. Nil and non-finite are 0; the rest is rounded and held within a
    /// billion either way.
    static func whole(_ value: Double?) -> Int {
        guard let value, value.isFinite else { return 0 }
        return Int(Swift.min(Swift.max(value.rounded(), -1_000_000_000), 1_000_000_000))
    }

    // MARK: - The report as text

    /// One sentence per run: its version, when it ran, how long and how many lines.
    public var overview: [String] {
        [describe(latest, as: "Latest run")] + (before.map { [describe($0, as: "Run before")] } ?? [])
    }

    /// The report as Markdown: the findings, the numbers of each run, and the log.
    public var markdown: String {
        var text = "# Echoelmusic report\n\n"
        for sentence in overview { text += sentence + "\n" }
        text += "\nMade on this device from the app's diagnostics log, which holds what the audio and the app did as fixed words and numbers, never a name you typed. Nothing has been sent anywhere.\n\n"
        text += "## Findings\n\n"
        let actionable = findings.filter { $0.weight > .note }
        if actionable.isEmpty {
            text += "Nothing in the log points to a fault.\n\n"
        }
        for (index, finding) in findings.enumerated() {
            text += "\(index + 1). **\(finding.weight.word)** · \(finding.run.rawValue) · \(finding.title)\n"
            text += "   Try: \(finding.suggestion)\n"
            if !finding.evidence.isEmpty {
                let shown = finding.count > finding.evidence.count ? " (the last \(finding.evidence.count) of \(finding.count))" : ""
                text += "   Lines\(shown):\n\n   ```\n"
                for line in finding.evidence { text += "   \(line)\n" }
                text += "   ```\n"
            }
            text += "\n"
        }
        text += "## Numbers\n\n| | Latest run | Run before |\n|---|---|---|\n"
        let other = before ?? RunSummary()
        func row(_ name: String, _ value: (RunSummary) -> String) {
            text += "| \(name) | \(value(latest)) | \(before == nil ? "–" : value(other)) |\n"
        }
        row("Version") { summary in summary.version.map { "\($0) (\(summary.build ?? "?"))" } ?? "–" }
        row("Length") { $0.minutes.map { "\($0) min" } ?? "–" }
        row("Lines") { "\($0.lines)" }
        row("Audio windows of 10 s") { "\($0.audioWindows)" }
        row("Callbacks that missed their time") { "\($0.missedTime)" }
        row("Sample-time jumps") { "\($0.sampleJumps)" }
        row("Highest load") { $0.audioWindows > 0 ? Self.percent($0.highestLoad) : "–" }
        text += "\n## The log\n\n```\n" + log + (log.hasSuffix("\n") || log.isEmpty ? "" : "\n") + "```\n"
        return text
    }

    private func describe(_ summary: RunSummary, as name: String) -> String {
        var parts: [String] = []
        if let version = summary.version { parts.append("version \(version) (\(summary.build ?? "?"))") }
        if let first = summary.firstTime, let last = summary.lastTime {
            parts.append("\(Self.day(first)) \(Self.clock(first)) to \(Self.clock(last)) UTC")
        }
        if let minutes = summary.minutes { parts.append("\(minutes) min") }
        parts.append("\(summary.lines) \(summary.lines == 1 ? "line" : "lines")")
        return "\(name): " + parts.joined(separator: ", ") + "."
    }

    /// `2026-11-27T10:26:00.250Z` → `2026-11-27`.
    private static func day(_ stamp: String) -> String { String(stamp.prefix(10)) }

    /// `2026-11-27T10:26:00.250Z` → `10:26`.
    private static func clock(_ stamp: String) -> String {
        let characters = Array(stamp)
        guard characters.count >= 16 else { return stamp }
        return String(characters[11..<16])
    }
}
