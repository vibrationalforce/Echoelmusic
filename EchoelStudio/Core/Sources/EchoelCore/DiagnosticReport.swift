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
        /// Songs opened (`Event.songOpened`), and the length of the last of them in the bars Arrange
        /// counts; nil before one.
        public var songsOpened = 0
        public var songBars: Int?
        /// Seconds from the launch to the first sound that reached the master and to the first note
        /// played live (`DiagnosticLog.milestone`); nil when the run had none.
        public var firstSound: Double?
        public var firstNote: Double?
        /// Edits the song refused (`Event.editRefused`), and whether the run's build writes them:
        /// it does when the run holds any line of `Event` or a view line, which came in the same
        /// build. A run from an earlier build has none, and its refused edits are not in the log.
        public var refusedEdits = 0
        public var countsRefusals = false
        /// How often each view of the bar was shown, the one at launch included.
        public var views: [StudioPlace: Int] = [:]
        /// Follow Playhead in Arrange as the run last wrote it — when Arrange showed, or when it was
        /// switched — and how often it changed; nil when Arrange never showed.
        public var followsPlayhead: Bool?
        public var followSwitches = 0

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

    /// Refused edits in one run from which they are a notice rather than a note.
    public static let manyRefusedEdits = 5

    /// Seconds from the launch from which the run's first sound is a finding: a notice when a note
    /// played live or the audio's own start says it was due sooner, a note otherwise.
    public static let longWaitForSound = 60.0

    /// Seconds a note played live may come before the run's first sound: a note that sounds reaches
    /// the master's meter within a fraction of a second, so a longer gap is a note that did not.
    public static let noteBeforeSound = 2.0

    /// What the report says when no rule above a note matched. It speaks for the rules, not for the
    /// app: a fault the log does not write, or no rule reads, is not ruled out.
    public static let nothingFound = "None of the report's rules found a fault in the log."

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
        for raw in text.split(whereSeparator: \.isNewline) {
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
        var follow: Bool?
        for line in lines {
            if eventsSinceRefusals.contains(line.event) { summary.countsRefusals = true }
            if let place = viewsByEvent[line.event] {
                summary.views[place, default: 0] += 1
                continue
            }
            switch line.event {
            case Event.songOpened.description:
                summary.songsOpened += 1
                summary.songBars = line.number("bars").map { Swift.max(0, whole($0)) }
            case Event.editRefused.description:
                summary.refusedEdits += 1
            case Event.firstSound.description where summary.firstSound == nil:
                summary.firstSound = waited(line)
            case Event.firstNote.description where summary.firstNote == nil:
                summary.firstNote = waited(line)
            case Event.followPlayhead.description:
                guard let value = line.number("on") else { continue }
                let on = value != 0
                if let follow, follow != on { summary.followSwitches += 1 }
                follow = on
            default:
                break
            }
        }
        summary.followsPlayhead = follow
        return summary
    }

    /// The seconds since the launch a moment's line names (`DiagnosticLog.milestone`); nil for
    /// none, or for a wait below zero, which an edit in Files could write.
    private static func waited(_ line: Line) -> Double? {
        line.number("s").flatMap { $0 >= 0 ? $0 : nil }
    }

    /// Each view's line (`StudioPlace.shownEvent`), to the view.
    private static let viewsByEvent: [String: StudioPlace] = Dictionary(
        StudioPlace.views.compactMap { (place: StudioPlace) -> (String, StudioPlace)? in
            place.shownEvent.map { ($0.description, place) }
        },
        uniquingKeysWith: { first, _ in first })

    /// The lines that came in the build that writes refused edits (`Event` and the view lines):
    /// one of them in a run says its build would have written its refusals.
    private static let eventsSinceRefusals: Set<String> = Set(
        [Event.editRefused, Event.songOpened, Event.firstSound, Event.firstNote, Event.followPlayhead]
            .map { (event: StaticString) -> String in event.description })
        .union(viewsByEvent.keys)

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

        add(.failure, ["metrickit: crash"],
            { $0.count == 1 ? "iOS reported that the app ended with a crash." : "iOS reported \($0.count) crashes of the app." },
            "iOS hands a crash over at the next launch, so the line stands in the run after the one that ended, and its time is when iOS reported it. The last lines of the run before show what the app was doing. Share this report.")
        add(.failure, ["engine: render still stalled after rebuilds"],
            { _ in "The audio stayed silent after the app rebuilt it, so the song paused." },
            "Tap Restart Audio. Note what you did just before; the lines before this one show where it stopped.")
        add(.failure, ["engine: automatic tries used up"],
            { _ in "The audio could not start after several tries." },
            "Tap Restart Audio once the call or the other app using audio has ended.")
        add(.failure, ["record: writing failed"], { times("A take could not be written", $0.count) },
            "Check the free space on the device, then record again. The report names the error's code.")

        add(.problem, ["launch: safe start"], { matching in
            let deaths = matching.compactMap { $0.number("deaths") }.max().map { whole($0) } ?? 2
            return "The app did not finish starting \(deaths) times in a row, so it started safely."
        }, "The Field window is off and plugins from other makers wait. Tap Load Plugins from Other Makers in the status line; if the app stops again, share this report and name the song's plugins from other makers.")
        add(.problem, ["metrickit: hang"], { matching in
            let longest = matching.compactMap { $0.number("s") }.max() ?? 0
            return "The app stopped responding \(count(matching.count)), the longest for \(seconds(longest))."
        }, "Note which page was open. A hang that repeats on the same page is a fault to fix.")
        add(.problem, ["engine: render stalled, rebuilding"],
            { times("The audio stopped and the app rebuilt it", $0.count) },
            "If you heard a gap, it was here. Share the report with what was playing.")
        add(.problem, ["engine: configure failed"], { times("The audio could not be set up", $0.count) },
            "Another app, a call or an audio device may hold the audio. Tap Restart Audio once it is free; the line names the error's code.")
        add(.problem, ["graph: stream tap refused the format"],
            { times("A live stream could not take the song's sound format", $0.count) },
            "The stream went out without the song's sound. Share this report; the lines around it show the format.")
        add(.problem, ["field layer: shader compile failed", "field layer: shader entry point missing", "field layer: pipeline failed"],
            { _ in "The Field layer for video could not be built." },
            "A video export and the Field Layer export show no Field until it builds. Share this report; it names the step that failed.")
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
                               suggestion: "The engine's own render never ran over its time. Adding more at once may cross the limit; this is the song to measure it with.",
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
            "Share this report; the lines before it show what the app was doing.")
        add(.notice, ["engine: media services lost", "engine: replace after media services reset"],
            { _ in "iOS restarted its audio services, and the app rebuilt its audio." },
            "The song paused; press Play to go on. If it recurs, note what ran at the same time.")
        let warnings = lines.filter { $0.event == "memory: warning" }
        if !warnings.isEmpty {
            let released = warnings.reduce(0) { $0 + whole($1.number("released")) }
            let noun = released == 1 ? "sample that was" : "samples that were"
            let freed = released > 0 ? "The app released \(released) \(noun) not playing. " : ""
            out.append(Finding(weight: .notice, run: run,
                               title: times("The device ran low on memory", warnings.count),
                               suggestion: freed + "Close other apps if it repeats.",
                               count: warnings.count, evidence: warnings.suffix(evidenceLimit).map(\.text)))
        }
        add(.notice, ["field: memory warning, detail down"], { times("The Field lowered its detail for memory", $0.count) },
            "Full detail comes back after at most a minute without another warning.")
        add(.notice, ["record: take ends before rebuild"], { times("A take ended early because the audio was rebuilt", $0.count) },
            "The take keeps what it recorded up to then. The lines before it show why the audio was rebuilt.")
        add(.notice, ["engine: stopped underneath, rebuilding"], { times("iOS stopped the audio without notice, and the app rebuilt it", $0.count) },
            "If you heard a gap, this is when it was.")
        let lowered = lines.filter { $0.event == "field: detail" && ($0.number("level") ?? 2) < 2 }
        if !lowered.isEmpty {
            let slowest = lowered.compactMap { $0.number("fps") }.min()
            let slowestText = slowest.map { "; the slowest second showed \(whole($0)) frames" } ?? ""
            out.append(Finding(weight: .notice, run: run,
                               title: "The Field lowered its picture detail \(count(lowered.count))\(slowestText).",
                               suggestion: "Heat, Low Power Mode, a low battery, a memory warning or a frame rate the device cannot hold lower it on purpose; it comes back when they pass.",
                               count: lowered.count, evidence: lowered.suffix(evidenceLimit).map(\.text)))
        }
        add(.notice, ["document: recovered takes"], { _ in "Takes were recovered after the app ended without saving them." },
            "They are on a new track, Recovered Takes, one after another from the start; move each to its place. A take cut short by the end keeps what was written.")
        add(.notice, ["stream: ended"], { times("A live stream ended without Stop", $0.count) },
            "Leaving the app, a call, the network or a server ends a stream; the Go Live page said which.")
        add(.notice, ["jam: host lost"], { times("The jam lost its host", $0.count) },
            "Being apart or a weak link ends a jam; start it again from Jam.")
        add(.notice, ["jam: refused"], { times("A jam could not connect", $0.count) },
            "The Jam page said why; most often Local Network is off for Echoelmusic in Settings. Allow it, then try again.")
        out += bodySourceRules(on: lines, run: run)
        out += selfTestRules(on: lines, run: run)
        add(.notice, [DiagnosticLog.fullLine], { _ in "The log filled up; the rest of that run is not in it." },
            "Opening the app again starts a new run with room in the log.")
        let refused = lines.filter { $0.event == Event.editRefused.description }
        if !refused.isEmpty { out.append(refusals(refused, among: lines, run: run)) }
        if let slow = slowFirstSound(in: lines, run: run) { out.append(slow) }

        add(.note, ["engine: interruption began"], { times("Another app or a call interrupted the audio", $0.count) },
            "The song paused; press Play to go on.")
        add(.note, ["route: output device gone while playing, pausing"],
            { times("The output device went away while playing, so the song paused", $0.count) },
            "Headphones or an interface was unplugged. Press Play to go on.")
        add(.note, ["session: preferred rate refused", "session: preferred buffer refused"],
            { times("iOS kept its own sample rate or buffer size", $0.count) },
            "Nothing to do: the audio plays with the values iOS chose. Another app or an audio device usually sets them.")
        return out
    }

    /// The edits the song refused in one run: how many, the view that was shown when most of them
    /// came — the one the last view line before each named; a sheet over it, or another window on
    /// iPad, may have made the edit — and what the status line said, which each line's reason
    /// tells (`CommandError.logReason(for:)`). A notice from `manyRefusedEdits` on, below that a
    /// note: a refused edit changes nothing, and the status line said at the time that it was not
    /// done.
    private static func refusals(_ refused: [Line], among lines: [Line], run: Run) -> Finding {
        var shown: StudioPlace?
        var perView: [StudioPlace: Int] = [:]
        for line in lines {
            if let place = viewsByEvent[line.event] {
                shown = place
            } else if line.event == Event.editRefused.description, let shown {
                perView[shown, default: 0] += 1
            }
        }
        // The view with the most, the first of the bar on a tie (`max` keeps the first).
        let most = StudioPlace.views.compactMap { (place: StudioPlace) -> (place: StudioPlace, edits: Int)? in
            perView[place].map { (place, $0) }
        }.max { $0.edits < $1.edits }
        let total = refused.count
        var title = total == 1 ? "The song refused an edit" : "The song refused \(total) edits"
        if let most {
            let place = "while \(most.place.title) was shown"
            title += most.edits == total ? " \(place)" : ", \(most.edits) of them \(place)"
        }
        // What the status line said, by the kind each line names, kinds that said the same counted
        // together; a reason the app never writes is counted and not repeated.
        var kinds: [(said: String, hits: Int)] = []
        for kind in CommandError.Refusal.allCases {
            let hits = refused.filter { $0.reason == kind.reason.description }.count
            guard hits > 0 else { continue }
            if let same = kinds.firstIndex(where: { $0.said == kind.said }) {
                kinds[same].hits += hits
            } else {
                kinds.append((kind.said, hits))
            }
        }
        var suggestion = ""
        if kinds.count == 1, let only = kinds.first, only.hits == total {
            suggestion = total == 1 ? "The status line said \(only.said). " : "The status line said \(only.said) each time. "
        } else if !kinds.isEmpty {
            suggestion = "The status line said " + listed(kinds.map { "\(count($0.hits)) \($0.said)" }) + ". "
        }
        suggestion += "A refused edit leaves the song as it was."
        let weight: Finding.Weight = total >= manyRefusedEdits ? .notice : .note
        if weight == .notice {
            let place = most.map { " while \($0.place.title) was shown" } ?? " then"
            suggestion += " Share this report and say what you did\(place); the times of the lines say when."
        }
        return Finding(weight: weight, run: run, title: title + ".", suggestion: suggestion,
                       count: total, evidence: refused.suffix(evidenceLimit).map(\.text))
    }

    /// The run's first sound, when it came `longWaitForSound` or more after the launch, with the
    /// seconds, since when the audio was running (the first start's line) and when a note was
    /// played live before it. A notice when the log shows that something should have sounded
    /// sooner: a note `noteBeforeSound` or more before it, or audio that itself started only
    /// `longWaitForSound` after the launch. Otherwise a note: the log does not say when Play was
    /// pressed, so a slow sound and a musician who played nothing yet read the same.
    private static func slowFirstSound(in lines: [Line], run: Run) -> Finding? {
        guard let heard = lines.firstIndex(where: { $0.event == Event.firstSound.description }),
              let wait = waited(lines[heard]), wait >= longWaitForSound else { return nil }
        let sound = lines[heard]
        var parts: [String] = []
        var shown = [heard]
        var overdue = false
        if let launch = lines.first(where: { $0.event == "app: launch" }),
           let started = lines.firstIndex(where: { $0.event == "engine: started" }),
           let from = seconds(of: launch.time), let to = seconds(of: lines[started].time),
           let at = seconds(of: sound.time), from <= to, to <= at {
            parts.append("the audio was running after \(seconds(to - from))")
            shown.append(started)
            overdue = to - from >= longWaitForSound
        }
        if let struck = lines.firstIndex(where: { $0.event == Event.firstNote.description }),
           let played = waited(lines[struck]), wait - played >= noteBeforeSound {
            parts.append("a note was played live after \(seconds(played))")
            shown.append(struck)
            overdue = true
        }
        let title = "The first sound came \(seconds(wait)) after the launch"
            + (parts.isEmpty ? "" : "; " + parts.joined(separator: ", and "))
        let master = "The first sound is the first time the song or a note played live reached the master."
        let suggestion = overdue
            ? master + " The lines before it are what the app did meanwhile; share this report."
            : master + " If you pressed Play or a key well before then, the lines before it are what the app did meanwhile; share this report. If not, it only says when you first played."
        let evidence = shown.sorted().map { lines[$0].text }
        return Finding(weight: overdue ? .notice : .note, run: run, title: title + ".", suggestion: suggestion,
                       count: evidence.count, evidence: evidence)
    }

    /// "a", "a and b", "a, b and c".
    private static func listed(_ parts: [String]) -> String {
        guard parts.count > 1, let last = parts.last else { return parts.first ?? "" }
        return parts.dropLast().joined(separator: ", ") + " and " + last
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

    // MARK: - Body sources (BR-8)

    /// How long after the app is back from the background a loss still counts as one of the time
    /// away. A source that stopped delivering when the app left is found missing at its owner's next
    /// tick once its reading has aged out: the strap ticks once a second and holds a reading for three
    /// seconds, so its loss can land up to four seconds after the app is back. Five covers that.
    private static let awayGraceSeconds = 5.0

    /// What the report says about losses that came while the app was away from the screen. iOS can
    /// pause an app in the background (Echoelmusic stops its audio there when nothing plays, records
    /// or follows a clock), and nothing reads a body source while the app is paused.
    private static let awaySuggestion = "When Echoelmusic leaves the screen, iOS can pause it, and its body sources with it; keep it on the screen while a body source should move the song."

    /// One loss of a body source, and what came after it while the source stayed on.
    private struct BodySourceDrop {
        let line: Line
        /// The loss came while the app was in the background, or just after it came back.
        let whileAway: Bool
        var measuredAgain = false
        /// The gap as the log measured it, the number and its text as written; nil without a regain
        /// or with a number that is none.
        var gapSeconds: Double?
        var gapText: String?
    }

    /// What the self-test measured on this device (`SelfTest` in the engine, run from this page while
    /// the song is stopped): a unit that made samples that are no numbers is a failure, one that needed
    /// more than a block's time in its slowest percent of blocks a problem, one that went over full
    /// scale or stayed silent a notice; the run itself is a note with its highest load. The lines name
    /// units by their stored names and hold numbers only.
    private static func selfTestRules(on lines: [Line], run: Run) -> [Finding] {
        let units = lines.filter { $0.event == "selftest: unit" }
        var out: [Finding] = []
        func finding(_ weight: Finding.Weight, _ matching: [Line], _ title: String, _ suggestion: String) {
            guard !matching.isEmpty else { return }
            out.append(Finding(weight: weight, run: run, title: title, suggestion: suggestion, count: matching.count,
                               evidence: matching.suffix(evidenceLimit).map(\.text)))
        }
        func names(_ matching: [Line]) -> String {
            matching.map { $0.reason ?? "a unit" }.joined(separator: ", ")
        }
        let broken = units.filter { ($0.number("nonfinite") ?? 0) > 0 }
        finding(.failure, broken, "In the self-test, \(names(broken)) made samples that are not numbers.",
                "That is a fault in the app, not in the song. Share this report.")
        let late = units.filter { ($0.number("p99_load") ?? 0) > 1 }
        finding(.problem, late,
                "In the self-test, \(names(late)) needed more than a block's time in its slowest percent of blocks on this device.",
                "Play fewer of it at once on this device, and share this report: it names the unit to make lighter.")
        let loud = units.filter { ($0.number("over0db") ?? 0) > 0 }
        finding(.notice, loud, "In the self-test, \(names(loud)) went over full scale.",
                "The test plays a fixed signal at a moderate level. Share this report so the unit's level can be checked.")
        let silent = units.filter { ($0.number("silent") ?? 0) > 0 }
        finding(.notice, silent, "In the self-test, \(names(silent)) stayed silent.",
                "The test plays every unit with a signal it should answer. Share this report.")
        if let summary = lines.last(where: { $0.event == "selftest: summary" }) {
            let count = whole(summary.number("units"))
            let rate = whole(summary.number("Hz"))
            let frames = whole(summary.number("frames"))
            let load = summary.number("highest_p99_load") ?? 0
            finding(.note, [summary],
                    "The self-test played \(count) units at \(rate) Hz in blocks of \(frames) frames; the highest load was \(percent(load)) of a block's time.",
                    "Nothing to do unless a finding above names a unit. Run it again after a change to compare.")
        }
        return out
    }

    /// Each body source that stopped measuring while it was on (`BodySourceLog`): how often, how many
    /// of those while the app was in the background, the longest gap the log measured, and what to
    /// try. A pause that iOS or the app made on purpose, iOS holding the camera or a video take filming
    /// with it, is not counted: it ends by itself and the source needs nothing. Losses that all came
    /// while the app was away, each measured again after, are a note: leaving the screen explains them.
    /// The lines hold fixed words and durations only, so neither a finding nor its evidence can carry
    /// a body value.
    private static func bodySourceRules(on lines: [Line], run: Run) -> [Finding] {
        let away = awayFromTheScreen(lines)
        return BodySourceLog.Source.allCases.compactMap { bodySourceDrops($0, in: lines, away: away, run: run) }
    }

    /// For each line, whether it came while the app was in the background, from `app: background`
    /// to the next `app: active`, or within `awayGraceSeconds` after that. An `app: active` after an
    /// `app: inactive` alone (Control Centre, the app switcher) was no time away.
    private static func awayFromTheScreen(_ lines: [Line]) -> [Bool] {
        var flags: [Bool] = []
        flags.reserveCapacity(lines.count)
        var inBackground = false
        var backAt: Double?
        for line in lines {
            let time = seconds(of: line.time)
            if line.event == "app: background" {
                inBackground = true
            } else if line.event == "app: active", inBackground {
                inBackground = false
                backAt = time
            }
            if inBackground {
                flags.append(true)
            } else if let backAt, let time {
                flags.append(time >= backAt && time - backAt <= awayGraceSeconds)
            } else {
                flags.append(false)
            }
        }
        return flags
    }

    /// One source's losses. A regain belongs to the loss before it, and only while the source stayed
    /// on: a start or a stop between them ends the pair.
    private static func bodySourceDrops(_ source: BodySourceLog.Source, in lines: [Line], away: [Bool],
                                        run: Run) -> Finding? {
        let lost = source.lostEvent.description
        let regained = source.regainedEvent.description
        let onOrOff: Set<String> = [source.startedEvent.description, source.stoppedEvent.description]
        let pauses = Set(BodySourceLog.Loss.allCases.filter(\.isPause).map { $0.reason.description })
        let absent = BodySourceLog.absentField.description
        var drops: [BodySourceDrop] = []
        var open: Int?
        for (position, line) in lines.enumerated() {
            if line.event == lost {
                if let reason = line.reason, pauses.contains(reason) {
                    open = nil
                } else {
                    drops.append(BodySourceDrop(line: line, whileAway: position < away.count && away[position]))
                    open = drops.count - 1
                }
            } else if line.event == regained {
                if let index = open {
                    drops[index].measuredAgain = true
                    if let gap = line.number(absent), gap >= 0 {
                        drops[index].gapSeconds = gap
                        drops[index].gapText = line.fields[absent]
                    }
                }
                open = nil
            } else if onOrOff.contains(line.event) {
                open = nil
            }
        }
        guard let last = drops.last else { return nil }
        let awayCount = drops.filter(\.whileAway).count
        // The longest gap is quoted as the log wrote it, never rounded again.
        let longest = drops.filter { $0.gapSeconds != nil }.max { ($0.gapSeconds ?? 0) < ($1.gapSeconds ?? 0) }
        var title = "\(bodySourceName(source)) stopped measuring \(count(drops.count))"
        if awayCount == drops.count {
            title += drops.count == 1 ? ", while the app was in the background" : ", each while the app was in the background"
        } else if awayCount > 0 {
            title += ", \(awayCount == 1 ? "one" : String(awayCount)) of them while the app was in the background"
        }
        if let text = longest?.gapText {
            title += drops.count == 1 ? ", for \(text) s" : "; the longest gap was \(text) s"
        }
        if !last.measuredAgain {
            let continued = awayCount > 0 || longest?.gapText != nil
            title += (continued ? ", " : " ")
                + (drops.count == 1 ? "and was not measured again" : "and after the last it was not measured again")
        }
        // Away from the screen and back again: nothing about the source to fix, so its advice would mislead.
        let onlyAway = awayCount == drops.count && last.measuredAgain
        var suggestion = onlyAway ? awaySuggestion : bodySourceSuggestion(source)
        if awayCount > 0, !onlyAway { suggestion += " " + awaySuggestion }
        return Finding(weight: onlyAway ? .note : .notice, run: run, title: title + ".", suggestion: suggestion,
                       count: drops.count, evidence: drops.suffix(evidenceLimit).map { $0.line.text })
    }

    /// What the report calls a body source.
    private static func bodySourceName(_ source: BodySourceLog.Source) -> String {
        switch source {
        case .strap: "The heart rate strap"
        case .camera: "The camera pulse"
        case .health: "The Apple Health pulse"
        case .motion: "Phone Motion"
        }
    }

    /// What to try when a source stopped measuring, from what the app itself does and says to the
    /// musician about that source: its status words, its entries in Body Source, its camera cues.
    private static func bodySourceSuggestion(_ source: BodySourceLog.Source) -> String {
        switch source {
        case .strap:
            // A strap off the skin keeps sending, and the app drops those readings
            // (`HeartRateMeasurement`). After a lost link the app searches once, for
            // `HeartRateStrap.scanSeconds`, and choosing the strap again does nothing while it is on.
            // Off in Body Source stops every source, Phone Motion too (`BodySourceMenu`).
            "Check the strap's battery and that it sits snug on the skin: off the skin the app takes no pulse from it. When its link ends, the app looks for it for up to 20 seconds; after No strap found or Strap lost, choose Off and then Heart Rate Strap in Body Source (Off stops Phone Motion too). Until it measures again, routes from it add nothing."
        case .camera:
            // `PulseCue`: the flash's light or a bright lamp's; a hot phone can switch the flash off.
            "Keep a fingertip over the rear camera and flash, still and pressing gently: the camera reads the pulse from light through the finger, the flash's, which a hot phone can switch off, or a bright lamp's. If a line says the camera failed, turn it off and on again in Body Source (Off stops Phone Motion too). A heart rate strap is the reliable alternative."
        case .health:
            "Apple Health has a reading only once the Watch measured one and Health synced it, and at rest the Watch measures less often, so gaps are expected; routes from it add nothing until the next reading. A heart rate strap sends a reading about once a second."
        case .motion:
            "Its four sources add nothing until the next sample comes, then follow the phone again. Phone Motion needs no setting; if this repeats, share this report with what the app was doing."
        }
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
        text += "\nMade on this device from the app's diagnostics log, which holds what the audio and the app did as fixed words and numbers, never a name you typed. The app sent nothing; this file leaves the device only when you share it.\n\n"
        text += "## Findings\n\n"
        let actionable = findings.filter { $0.weight > .note }
        if actionable.isEmpty {
            text += "\(Self.nothingFound)\n\n"
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
        row("Song opened") { Self.songsPhrase($0, inTable: true) ?? "–" }
        row("First sound after launch") { summary in summary.firstSound.map { Self.seconds($0) } ?? "–" }
        row("First note after launch") { summary in summary.firstNote.map { Self.seconds($0) } ?? "–" }
        row("Edits refused") { $0.countsRefusals ? "\($0.refusedEdits)" : "–" }
        row("Views shown") { Self.viewsPhrase($0.views) }
        row("Follow Playhead in Arrange") { Self.followPhrase($0) }
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
        if let songs = Self.songsPhrase(summary, inTable: false) { parts.append(songs) }
        if let sound = summary.firstSound { parts.append("first sound \(Self.seconds(sound)) after launch") }
        if let played = summary.firstNote { parts.append("first note \(Self.seconds(played)) after launch") }
        return "\(name): " + parts.joined(separator: ", ") + "."
    }

    /// "16 bars", "1 bar".
    private static func barsPhrase(_ bars: Int) -> String {
        bars == 1 ? "1 bar" : "\(bars) bars"
    }

    /// The songs a run opened: "a song of 16 bars" (in the table "16 bars"), "2 songs, the last of
    /// 24 bars"; nil before one, or when the last line names no length.
    private static func songsPhrase(_ summary: RunSummary, inTable: Bool) -> String? {
        guard summary.songsOpened > 0, let bars = summary.songBars else { return nil }
        guard summary.songsOpened == 1 else { return "\(summary.songsOpened) songs, the last of \(barsPhrase(bars))" }
        return inTable ? barsPhrase(bars) : "a song of \(barsPhrase(bars))"
    }

    /// "Arrange 6 · Mixer 4 · Tracks 3": each view shown, the most shown first and the bar's order
    /// on a tie; "–" for none.
    private static func viewsPhrase(_ views: [StudioPlace: Int]) -> String {
        var shown: [(order: Int, place: StudioPlace, shows: Int)] = []
        for (order, place) in StudioPlace.views.enumerated() {
            if let shows = views[place] { shown.append((order, place, shows)) }
        }
        guard !shown.isEmpty else { return "–" }
        return shown.sorted { $0.shows != $1.shows ? $0.shows > $1.shows : $0.order < $1.order }
            .map { "\($0.place.title) \($0.shows)" }
            .joined(separator: " · ")
    }

    /// "on", "off, switched once"; "–" for a run in which Arrange never showed.
    private static func followPhrase(_ summary: RunSummary) -> String {
        guard let on = summary.followsPlayhead else { return "–" }
        let state = on ? "on" : "off"
        return summary.followSwitches > 0 ? "\(state), switched \(count(summary.followSwitches))" : state
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

// MARK: - The words the app writes for the report

extension DiagnosticReport {
    /// Events the app writes for the report since 2026-11-27 (TA-R3), as the app writes them and
    /// the rules above read them — one list, so the writer and the reader cannot drift apart. Each
    /// is fixed words; what varies is a number, or a reason from a fixed list. The words stay as
    /// they are: the run before in the file may come from an earlier build.
    public enum Event {
        /// An edit the song refused, its kind as the reason (`CommandError.logReason(for:)`).
        public static let editRefused: StaticString = "edit: refused"
        /// A song opened; `bars` is its length as Arrange counts it (`Arranging.songBars`).
        public static let songOpened: StaticString = "document: opened"
        /// The run's first sound on the master; `s` is the seconds since the launch
        /// (`DiagnosticLog.milestone`).
        public static let firstSound: StaticString = "launch: first sound"
        /// The run's first note played live, on the screen's keys or a controller; `s` as above.
        public static let firstNote: StaticString = "launch: first note"
        /// Follow Playhead in Arrange, `on` 1 or 0: when Arrange shows, and when it is switched.
        public static let followPlayhead: StaticString = "arrange: follow playhead"
    }
}

extension StudioPlace {
    /// The views of the bar at the bottom of the studio, in its order.
    static let views: [StudioPlace] = [.instrument, .tracks, .arrange, .session, .mixer, .field, .cycleTones]

    /// The line the diagnostics log gets when this view is shown — at launch and at each change —
    /// so the report can count the views and place a refused edit in one; nil for a place that is
    /// not a view of the bar.
    public var shownEvent: StaticString? {
        switch self {
        case .instrument: "view: instrument"
        case .tracks: "view: tracks"
        case .arrange: "view: arrange"
        case .session: "view: session"
        case .mixer: "view: mixer"
        case .field: "view: field"
        case .cycleTones: "view: cycle tones"
        default: nil
        }
    }
}

extension CommandError {
    /// The kinds of refusal the diagnostics log tells apart; their words stay as they are, like
    /// the events (`DiagnosticReport.Event`), and a new kind goes at the end.
    enum Refusal: CaseIterable {
        case partGone, alreadyThere
        /// A value whose reason the status line said as it was (`readableClause`).
        case value
        /// An error that is no `CommandError`.
        case other
        /// A value whose reason does not read alone, so the status line said only that it did not
        /// fit here.
        case unfit

        /// The reason the log writes: `edit: refused (part gone)`.
        var reason: StaticString {
            switch self {
            case .partGone: "part gone"
            case .alreadyThere: "already there"
            case .value: "value"
            case .other: "other"
            case .unfit: "does not fit"
            }
        }

        /// What the status line said for it (`sentence`), as the report repeats it: the clause in
        /// quotes, or, for a value whose reason reads alone, only that it said why — that reason
        /// can quote what the musician typed, so the log never holds it.
        var said: String {
            switch self {
            case .partGone: "“\(CommandError.goneClause)”"
            case .alreadyThere: "“\(CommandError.duplicateClause)”"
            case .value: "why it did not fit"
            case .other, .unfit: "“\(CommandError.unfitClause)”"
            }
        }
    }

    /// The reason the diagnostics log gives a refused edit: its kind in fixed words — never the
    /// sentence, whose clause can quote a value, nor an id. An error that is no `CommandError` is
    /// "other"; the app's status line then says that it does not fit here.
    public static func logReason(for error: any Error) -> StaticString {
        refusal(of: error).reason
    }

    static func refusal(of error: any Error) -> Refusal {
        guard let refused = error as? CommandError else { return .other }
        switch refused {
        case .unknownTrack, .unknownClip, .unknownPlacement, .unknownScene, .unknownNote, .unknownMedia,
             .unknownRegion, .unknownInsert:
            return .partGone
        case .duplicateID:
            return .alreadyThere
        case .invalidValue(_, let reason):
            return readableClause(reason) == nil ? .unfit : .value
        }
    }
}
