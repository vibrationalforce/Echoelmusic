// TheCrashNetIsUpBeforeTheStoresTests.swift
// Echoel — GMMW SH-2 (2026-10-08). The diag log and the launch counter are up before the first
// store is constructed.
//
// WHAT THIS GUARDS. Swift evaluates a struct's stored-property initial values in declaration
// order, before the first statement of `init()`. `EchoelmusicApp` declares dozens of
// `@State … = X()` defaults — stores among them, some of which decode from disk — and
// `EchoelCrashLog.begin()` and `LaunchGuard.beginLaunch()` used to be the first two statements
// of `init()`, i.e. AFTER all of them. A crash in one of those constructors therefore wrote no
// diag log (the sink was still closed, and `breadcrumb` is a silent no-op then) and never
// raised the counter Safe Mode reads, so the next launch neither knew nor said why. SH-2 makes
// the FIRST stored property's initializer raise the net.
//
// THE CLAIMS — all SOURCE-TEXT SCANS over `EchoelmusicApp.swift`, read through
// `SourceText.codeOnly`:
//   1. The first stored property of the type calls `EchoelmusicApp.raiseCrashNet()`. A fixture
//      with a store declared first proves the scan can fail for its named reason (#367), and
//      a fixture with a `static let` and an `@Environment(\.…)` first proves it skips the one
//      and sees the other.
//   2. `raiseCrashNet()` opens the log BEFORE it counts the launch, and announces the verdict
//      AFTER the count (the #915 lines, which the `LaunchGuardSmokeTests` ownership scan also
//      reads — the call stayed in this file on purpose so that scan still sees it).
//   3. The net is raised exactly once: one `EchoelCrashLog.begin()` and one
//      `LaunchGuard.beginLaunch()` in the app, one call of `raiseCrashNet()`, none of them at
//      the head of `init()`, and no other file under `Sources/` calls `EchoelCrashLog.begin()`
//      (a second call would truncate the log the first one opened).
//
// ⚠️ HONEST GRADING (#433), transcribed in Python against the parent `4ba2eb1` and the
// worktree. This file names no `Sources/` symbol, so it compiles against both trees.
//   · claim 1: REGRESSION — on the parent the first stored property is
//     `@State private var audioEngine: AudioEngine`. The two fixtures are FORWARD (they drive
//     this file's own scan).
//   · claim 2: red on the parent by ANCHOR ABSENCE only — `raiseCrashNet()` does not exist
//     there. One absence, not a regression count (#486).
//   · claim 3: the `init()`-head check is a REGRESSION (the parent's `init()` opens with both
//     calls); the helper-call count is the same anchor absence as claim 2; the two
//     one-call-in-the-app counts and the whole-`Sources/` `begin()` count are COUNTERWEIGHTS,
//     green on both trees.
// Stripper `SourceText.codeOnly`: TRAGEND for claim 3 — 5 of its 12 verdicts over the two
// trees flip on a raw read, because `init()`'s own SH-2 comment names both calls and two other
// files under `Sources/` name `EchoelCrashLog.begin()` in prose. PROPHYLAKTISCH for claims 1
// and 2 (0 flips).
//
// ⚠️ THE LIMIT. Source text, not behaviour: nothing here constructs the app. That Swift runs
// stored initial values in declaration order is the language's rule, not something this file
// can observe. And the net adds the LOG and the COUNT, not recovery — Safe Mode constructs the
// same defaults, so a constructor crash still repeats (SH-11). DEVICE PROBE, open: a launch
// whose log opens with the `launch v` line (`EchoelCrashLog.launchLinePrefix`) and reaches the
// `LaunchGuard:` verdict before `init a: audio core`. After a run that ended badly `begin()`
// writes its `retain…` lines between the two, so "the second line" holds only after a clean run.
// No breadcrumb marks the stored defaults themselves: a log that stops between the verdict and
// `init a:` died in one of them, the `register(defaults:)` calls or the `APP INIT` line.

import Foundation
import XCTest

final class TheCrashNetIsUpBeforeTheStoresTests: XCTestCase {

    private static let appPath = "Sources/Echoelmusic/EchoelmusicApp.swift"
    private static let typeHead = "struct EchoelmusicApp: App {"
    private static let helperHead = "private static func raiseCrashNet() -> Bool {"
    private static let netCall = "EchoelmusicApp.raiseCrashNet()"

    // MARK: 1 — the first stored property raises the net

    func testTheFirstStoredPropertyRaisesTheCrashNet() throws {
        let app = try source(Self.appPath)
        let first = try XCTUnwrap(Self.firstStoredProperty(in: app),
                                  "ANCHOR MISSING: `\(Self.typeHead)` or any stored property after it (#408)")
        XCTAssertTrue(first.contains("= " + Self.netCall), """
            The first stored property of `EchoelmusicApp` is `\(first.trimmingCharacters(in: .whitespaces))`, \
            not the crash net. Swift runs stored initial values in declaration order before \
            `init()`, so every default above the net runs with the diag log closed and the launch \
            counter unmoved — a crash there writes nothing and Safe Mode never learns of it. Keep \
            `crashNetRaised` the FIRST stored property (SH-2).
            """)

        // #367 — the scan must be able to fail for its named reason: a store declared first.
        let storeFirst = """
            struct EchoelmusicApp: App {
                @State private var clips = ClipStore()
                private let crashNetRaised: Bool = EchoelmusicApp.raiseCrashNet()
            }
            """
        XCTAssertEqual(Self.firstStoredProperty(in: storeFirst)?.trimmingCharacters(in: .whitespaces),
                       "@State private var clips = ClipStore()",
                       "the scan no longer reports a store declared above the crash net")

        // …and it skips what is not an instance stored property, while seeing an attributed one.
        let staticFirst = """
            struct EchoelmusicApp: App {
                private static let key = "k"
                @Environment(\\.scenePhase) private var scenePhase
                private let crashNetRaised: Bool = EchoelmusicApp.raiseCrashNet()
            }
            """
        XCTAssertEqual(Self.firstStoredProperty(in: staticFirst)?.trimmingCharacters(in: .whitespaces),
                       "@Environment(\\.scenePhase) private var scenePhase",
                       "the scan must skip a `static` member and still see an attributed stored property")
    }

    // MARK: 2 — the net opens the log, then counts, then says the verdict

    func testTheNetOpensTheLogBeforeItCountsTheLaunch() throws {
        let app = try source(Self.appPath)
        guard let body = Self.bracedBody(after: Self.helperHead, in: app) else {
            return XCTFail("ANCHOR MISSING: `\(Self.helperHead)` or its closing brace (#408)")
        }
        guard let open = body.range(of: "EchoelCrashLog.begin()"),
              let count = body.range(of: "LaunchGuard.beginLaunch()"),
              let safe = body.range(of: "\"LaunchGuard: SAFE MODE"),
              let normal = body.range(of: "\"LaunchGuard: normal launch") else {
            return XCTFail("""
                `raiseCrashNet()` lost the log opening, the launch count or one of the two verdict \
                lines. All four belong to the net (SH-2, #915).
                """)
        }
        XCTAssertLessThan(open.lowerBound, count.lowerBound, """
            `raiseCrashNet()` counts the launch before it opens the diag log. The verdict lines \
            after the count would then go to a closed sink, and a crash inside the count would \
            leave no log at all.
            """)
        XCTAssertLessThan(count.lowerBound, safe.lowerBound,
                          "the Safe-Mode line must follow the count: the verdict does not exist before it")
        XCTAssertLessThan(count.lowerBound, normal.lowerBound,
                          "the normal-launch line must follow the count: the verdict does not exist before it")
    }

    // MARK: 3 — raised exactly once, and nowhere else

    func testTheNetIsRaisedExactlyOnce() throws {
        let app = try source(Self.appPath)
        XCTAssertEqual(Self.occurrences(of: "EchoelCrashLog.begin()", in: app), 1,
                       "`EchoelmusicApp` must open the diag log exactly once — a second call truncates the first")
        XCTAssertEqual(Self.occurrences(of: "LaunchGuard.beginLaunch()", in: app), 1,
                       "`EchoelmusicApp` must count the launch exactly once")
        XCTAssertEqual(Self.occurrences(of: Self.netCall, in: app), 1, """
            `raiseCrashNet()` must be called exactly once, from the first stored property. A \
            second call would truncate the diag log the first one opened and count the launch twice.
            """)

        // The head of `init()` — up to its first log line — no longer opens or counts (SH-2).
        guard let initHead = app.range(of: "    init() {"),
              let firstLine = app.range(of: "\"APP INIT [start]", range: initHead.upperBound..<app.endIndex) else {
            return XCTFail("ANCHOR MISSING: `init()` or its `APP INIT [start]` line (#408)")
        }
        let head = app[initHead.upperBound..<firstLine.lowerBound]
        XCTAssertFalse(head.contains("EchoelCrashLog.begin()") || head.contains("LaunchGuard.beginLaunch()"), """
            `init()` opens the diag log or counts the launch again. By then every stored default \
            has already run — the net belongs in the first stored property (SH-2).
            """)

        // No other file under `Sources/` opens the log.
        let root = try repositoryRoot()
        var callers: [String] = []
        let sources = root.appendingPathComponent("Sources")
        let walker = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil)
        var scanned = 0
        while let url = walker?.nextObject() as? URL {
            guard url.pathExtension == "swift",
                  let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            scanned += 1
            let code = SourceText.codeOnly(text)
            if Self.occurrences(of: "EchoelCrashLog.begin()", in: code) > 0 {
                let path = url.standardizedFileURL.path
                let tail = path.range(of: "/Sources/").map { "Sources/" + path[$0.upperBound...] }
                callers.append(tail ?? path)
            }
        }
        XCTAssertGreaterThan(scanned, 0, "no Swift file was read under Sources/ — a scan that saw nothing is not a pass (#454)")
        XCTAssertEqual(callers, [Self.appPath], """
            `EchoelCrashLog.begin()` is called from \(callers). It must be called once, from the \
            app's crash net: every call truncates the diag log and reinstalls the signal handlers.
            """)
    }

    // MARK: - Pure scan helpers (driven on the real file and on the fixtures)

    /// The first instance stored property declared after `struct EchoelmusicApp: App {`, as its
    /// whole line, or nil when the head or every property is missing. A member line sits at
    /// four spaces, may carry attributes (`@State`, `@Environment(\.scenePhase)`) and an access
    /// modifier, and declares `let` or `var`; a `static` member is not an instance property.
    /// ⚠️ A computed `var` matches too — harmless here, because the net is a `let` with an
    /// initial value and must come before everything else anyway.
    static func firstStoredProperty(in code: String) -> String? {
        guard let head = code.range(of: typeHead) else { return nil }
        let pattern = #"^    (?:@\w+(?:\([^)\n]*\))?\s+)*(?:(?:private|fileprivate|internal|public)\s+)?(?:let|var)\s+\w+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        for line in code[head.upperBound...].components(separatedBy: "\n") {
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            if regex.firstMatch(in: line, range: range) != nil { return line }
        }
        return nil
    }

    /// The text between `head`'s opening brace and its matching closing brace. Literal-naive:
    /// `raiseCrashNet()`'s string literals carry no brace (measured), so counting is sound here.
    static func bracedBody(after head: String, in code: String) -> String? {
        guard let start = code.range(of: head) else { return nil }
        var depth = 0
        var i = code.index(before: start.upperBound)   // the opening brace
        while i < code.endIndex {
            if code[i] == "{" {
                depth += 1
            } else if code[i] == "}" {
                depth -= 1
                if depth == 0 { return String(code[start.upperBound..<i]) }
            }
            i = code.index(after: i)
        }
        return nil
    }

    static func occurrences(of needle: String, in text: String) -> Int {
        text.components(separatedBy: needle).count - 1
    }

    private func repositoryRoot() throws -> URL {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0..<8 {
            if FileManager.default.fileExists(atPath: dir.appendingPathComponent("Package.swift").path) { return dir }
            dir = dir.deletingLastPathComponent()
        }
        throw XCTSkip("source tree not present above \(#filePath)")
    }

    private func source(_ relativePath: String) throws -> String {
        let url = try repositoryRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("source tree not present at \(url.path)")
        }
        return SourceText.codeOnly(try String(contentsOf: url, encoding: .utf8))
    }
}
