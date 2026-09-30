// TheHealthRowSaysWhatTheWristIsDoingTests.swift
// Echoel — interface audit 2026-09-30, Zug 3 ("Status-Leiter in Worten für jeden Hardware-Pfad"),
// the Apple Health path: the bio panel gets an "Apple Health" row while Health is the chosen source.
//
// WHAT IT GUARDS. Choosing "Play with Apple Health" (#1319) selects a publisher the picker does
// not own and cannot see: it starts at APP level, it writes minutes apart at rest, and a declined
// read permission looks exactly like a Watch that has not written yet (Apple hides read denial —
// measured in `EchoelBioEngine.requestAuthorization`, recorded in `Bio/HealthSourceStatus.swift`).
// Until this slice the panel's only word for that was the camera-shaped "Connecting…". Now
// `HealthSourceRung` names four rungs — Off / Waiting / Receiving / Unavailable — and
// `EchoelStudioView.HealthSourceStatusRow` renders them under the chooser.
//
// HOW THE STUDIO READS A PUBLISHER IT MAY NOT HOLD. `ThePickerDoesNotOwnEverySourceTests`
// claim 2 keeps `HealthKitBioPublisher` out of the Studio layer as CODE, so that no second
// lifecycle owner can appear there (BLE-3). The row therefore reads `HealthSourceStatus` — a
// separate `@Observable` the publisher WRITES and the app INJECTS — and the publisher's own
// `isAuthorized`/`isPublishing` FORWARD to it, so there is one definition of each flag (#416).
// Claim 5 pins both halves of that boundary; that guard's claim 2 stays green for a true reason.
//
// §1 LIMIT: claims 1, 2 and 6 are END-TO-END BEHAVIOUR on shipped types (`HealthSourceRung` is a
// pure enum; `HealthSourceStatus` a `@MainActor` class with no dependencies). Claims 3–5 are
// SOURCE-TEXT SCANS: they prove the row is mounted, gated, cold and wired; they do not prove it
// renders. Whether "Waiting · no reading yet" turns into "Receiving · your Watch" on a wrist is a
// DEVICE PROBE — NEEDS-FOUNDER-VERIFY sits on the row's declaration, not here.
//
// §3 HONEST GRADING. This file names NEW symbols (`HealthSourceRung`, `HealthSourceStatus`), so it
// does not compile against the parent (b0369144b): NO assertion has a verdict there. Hand-
// transcribed in Python against both trees: claims 1, 2 and 6 are FORWARD (the types do not
// exist on the parent); claim 3 is red on the parent by ANCHOR ABSENCE (no
// `HealthSourceStatusRow` struct — one absence, reported once, #486); claim 4 is red on the
// parent by the same absence (zero mounts); claim 5 is red on the parent for its named reason
// (the publisher's two flags were stored there, `status` did not exist, the app injected only
// the writer) and every one of its assertions is a COUNTERWEIGHT on this tree. ZERO regressions
// claimed. Stripper: `SourceText.codeOnly` on both trees — PROPHYLAKTISCH (0 of 5 scan verdicts
// flip; the leaf's doc comment names `HealthKitBioPublisher`, and the negative needle in claim 3
// is the only assertion the stripper touches — it is green raw AND stripped because the doc
// lines are `///`, and claim 3's body is brace-matched from the `struct` line, not the doc).

import Foundation
import XCTest
@testable import Echoelmusic

final class TheHealthRowSaysWhatTheWristIsDoingTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let publisher = "Sources/Echoelmusic/Bio/HealthKitBioPublisher.swift"
    private static let status = "Sources/Echoelmusic/Bio/HealthSourceStatus.swift"
    private static let app = "Sources/Echoelmusic/EchoelmusicApp.swift"

    /// Whole words the ladder may not speak: there has been no audio input since #1302, and
    /// "denied" would promise knowledge Apple withholds (the status file's header).
    private static let forbiddenWords: Set<String> = ["mic", "microphone", "input", "inputs",
                                                       "denied"]

    // MARK: - claim 1 (E2E) — the rung follows the two flags and the frame, all eight ways

    func testTheRungFollowsTheFlagsAndTheFrame() {
        typealias Row = (publishing: Bool, failed: Bool, fresh: Bool, expect: HealthSourceRung)
        let table: [Row] = [
            (false, false, false, .off),
            (false, false, true,  .off),          // a stale co-writer frame does not make it "on"
            (true,  false, false, .waiting),
            (true,  false, true,  .receiving),
            (false, true,  false, .unavailable),
            (false, true,  true,  .unavailable),
            (true,  true,  false, .unavailable),  // a failed start outranks a running loop
            (true,  true,  true,  .unavailable),
        ]
        for row in table {
            XCTAssertEqual(HealthSourceRung.rung(isPublishing: row.publishing,
                                                 couldNotStart: row.failed,
                                                 wristFrameFresh: row.fresh),
                           row.expect, """
                rung(isPublishing: \(row.publishing), couldNotStart: \(row.failed), \
                wristFrameFresh: \(row.fresh)) must be \(row.expect): a failed start is a fact \
                about the device and wins; off before the loop runs; then the frame decides.
                """)
        }
        XCTAssertEqual(HealthSourceRung.allCases.count, 4,
                       "the ladder has four rungs — a fifth needs a row in this table and a word")
    }

    // MARK: - claim 2 (E2E) — every rung has a distinct word, a line that starts with it, a
    //         caption and a spoken form; the remedy sits where a declined sheet shows up

    func testEveryRungHasItsWordsAndTheRemedySitsOnWaiting() {
        var words = Set<String>(), captions = Set<String>()
        for rung in HealthSourceRung.allCases {
            XCTAssertTrue(rung.line.hasPrefix(rung.word + " · "),
                          "\(rung): the value cell must start with the word — `\(rung.line)`")
            XCTAssertFalse(rung.caption.isEmpty, "\(rung): a rung without a caption is a dot")
            XCTAssertNotEqual(rung.caption, rung.line, "\(rung): the caption must add something")
            XCTAssertTrue(rung.spoken.contains("Apple Health"),
                          "\(rung): VoiceOver must name the source — `\(rung.spoken)`")
            for text in [rung.word, rung.line, rung.caption, rung.spoken] {
                let tokens = Set(text.lowercased().split { !$0.isLetter }.map(String.init))
                XCTAssertTrue(tokens.isDisjoint(with: Self.forbiddenWords), """
                    \(rung) speaks a forbidden word in `\(text)`: no audio input exists (#1302) \
                    and Apple hides read denial, so "denied" would claim what nothing measures.
                    """)
            }
            words.insert(rung.word); captions.insert(rung.caption)
        }
        XCTAssertEqual(words.count, 4, "four rungs, four words — two rungs sharing one is one rung")
        XCTAssertEqual(captions.count, 4, "four rungs, four captions")
        XCTAssertTrue(HealthSourceRung.waiting.caption.contains("Health app"), """
            The remedy for a declined sheet must sit on `waiting`, because a declined sheet \
            LOOKS like waiting (Apple hides read denial) — `\(HealthSourceRung.waiting.caption)`
            """)
        XCTAssertTrue(HealthSourceRung.unavailable.caption.contains("another bio source"), """
            `unavailable` is a fact about the device; its remedy is a different source — \
            `\(HealthSourceRung.unavailable.caption)`
            """)
        XCTAssertTrue(HealthSourceRung.off.line.contains("Play"),
                      "`off` must say what turns it on: the ask fires at the first Play")
    }

    // MARK: - claim 3 (SCAN) — the leaf reads the status and the bus, on its own clock, and
    //         holds no handle to the publisher

    func testTheLeafReadsTheStatusAndTheBusOnItsOwnClock() throws {
        let code = try source(Self.studio)
        let decl = "private struct HealthSourceStatusRow: View {"
        XCTAssertEqual(code.components(separatedBy: decl).count - 1, 1,
                       "`HealthSourceStatusRow` must be declared exactly once — re-anchor (#408)")
        let body = try structBody(after: decl, in: code)
        for needle in ["@Environment(HealthSourceStatus.self) private var status",
                       "@Environment(EngineBus.self) private var bus",
                       "TimelineView(.periodic(from: .now, by: Self.tick))",
                       "HealthSourceRung.rung(isPublishing: status.isPublishing,",
                       "couldNotStart: status.couldNotStart,",
                       "wristFrameFresh: bus.usableBio()?.source == .healthKit)",
                       "Text(rung.line)",
                       "Text(rung.caption)",
                       ".accessibilityValue(rung.spoken)",
                       ".accessibilityLabel(\"Apple Health\")"] {
            XCTAssertTrue(body.contains(needle), """
                `HealthSourceStatusRow` lost `\(needle)`. The row derives its rung from the \
                status object and from `usableBio()` — the SOURCE's own 90 s window, the same \
                question `BioStripView` asks — on a 10 s `TimelineView` so "Receiving" can EXPIRE \
                when the Watch stops writing (there is no event to observe for that).
                """)
        }
        for banned in ["Timer.", "cameraRPPG", "HealthKitBioPublisher", ".start(", ".stop("] {
            XCTAssertFalse(body.contains(banned), """
                `HealthSourceStatusRow` contains `\(banned)`. The leaf may READ the wrist's status; \
                it may not hold the publisher, start or stop it (BLE-3, #1319), run its own \
                `Timer`, or read the camera.
                """)
        }
    }

    // MARK: - claim 4 (SCAN) — mounted exactly once, under the chooser, only while Health is chosen

    func testTheRowIsMountedOnceUnderTheChooserWhileHealthIsChosen() throws {
        var mounts = 0
        var files = 0
        for path in try swiftSources() {
            files += 1
            mounts += SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
                .components(separatedBy: "HealthSourceStatusRow()").count - 1
        }
        XCTAssertGreaterThan(files, 100, "the Sources walk found \(files) files — it did not walk")
        XCTAssertEqual(mounts, 1, "`HealthSourceStatusRow()` must be constructed exactly once, in `bioPanel`")

        let code = try source(Self.studio)
        guard let row = code.range(of: "\n            bioSourceRow\n"),
              let mount = code.range(of: "HealthSourceStatusRow()"),
              let strip = code.range(of: "AlwaysOnBioPanelStrip()") else {
            XCTFail("ANCHOR MISSING: bioSourceRow mount, HealthSourceStatusRow() or AlwaysOnBioPanelStrip() — re-anchor")
            return
        }
        XCTAssertTrue(row.upperBound <= mount.lowerBound && mount.upperBound <= strip.lowerBound, """
            The Apple Health row must sit directly under the chooser it describes and before the \
            always-on block — the panel's own reading order.
            """)
        let before = String(code[code.index(mount.lowerBound, offsetBy: -220, limitedBy: code.startIndex) ?? code.startIndex ..< mount.lowerBound])
        XCTAssertTrue(before.contains("if BioSourceOption(rawValue: bioSourceRaw) == .health {"), """
            The row must be gated on the CHOSEN source (`bioSourceRaw` is @AppStorage, a cold \
            read). Shown for every source it would describe a co-writer the person did not pick.
            """)
    }

    // MARK: - claim 5 (SCAN) — the boundary: status written by the publisher, injected by the
    //         app, flags defined once

    func testTheStatusIsWrittenOnceInjectedOnceAndNeverMirrored() throws {
        let pub = try source(Self.publisher)
        for needle in ["public let status = HealthSourceStatus()",
                       "public var isAuthorized: Bool { status.isAuthorized }",
                       "public var isPublishing: Bool { status.isPublishing }",
                       "status.isAuthorized = await engine.requestAuthorization()",
                       "status.couldNotStart = true",
                       "status.couldNotStart = false",
                       "status.isPublishing = true",
                       "status.isPublishing = false"] {
            XCTAssertTrue(pub.contains(needle), """
                `HealthKitBioPublisher` lost `\(needle)`. The publisher WRITES the status object \
                and FORWARDS its own two flags to it — one definition each (#416). A stored mirror \
                here would drift from the row silently.
                """)
        }
        for stored in ["var isAuthorized = false", "var isPublishing = false"] {
            XCTAssertFalse(pub.contains(stored), """
                `HealthKitBioPublisher` declares a STORED `\(stored)` again. The flags live in \
                `HealthSourceStatus`; a second copy is the #416 defect this slice removed.
                """)
        }
        let status = try source(Self.status)
        for needle in ["public internal(set) var isAuthorized = false",
                       "public internal(set) var isPublishing = false",
                       "public internal(set) var couldNotStart = false"] {
            XCTAssertTrue(status.contains(needle), """
                `HealthSourceStatus` lost `\(needle)` — `internal(set)` is the boundary: the \
                publisher (same module) writes, a leaf can only read.
                """)
        }
        let app = try source(Self.app)
        XCTAssertTrue(app.contains(".environment(healthBio.status)"), """
            `EchoelmusicApp` no longer injects `healthBio.status`. The row reads it from the \
            environment; without the injection `@Environment(HealthSourceStatus.self)` traps at \
            first render of the bio panel with Health chosen.
            """)
        XCTAssertFalse(app.contains(".environment(healthBio)"), """
            `EchoelmusicApp` injects the PUBLISHER itself. The Studio layer must be unable to \
            reach `start`/`stop` on it (#1319, BLE-3) — inject the status, never the owner.
            """)
    }

    // MARK: - claim 6 (E2E) — a fresh status is Off

    @MainActor
    func testAFreshStatusReadsOff() {
        let fresh = HealthSourceStatus()
        XCTAssertFalse(fresh.isAuthorized); XCTAssertFalse(fresh.isPublishing)
        XCTAssertFalse(fresh.couldNotStart)
        XCTAssertEqual(HealthSourceRung.rung(isPublishing: fresh.isPublishing,
                                             couldNotStart: fresh.couldNotStart,
                                             wristFrameFresh: false), .off,
                       "before any start the row says Off — and what turns it on")
    }

    // MARK: - helpers

    private struct AnchorMissing: Error { let reason: String }

    /// Brace-matched body from the declaration line to its closing brace (#408: never a fixed
    /// window — this repo writes 30-line doc blocks and `SourceText.codeOnly` keeps line count).
    private func structBody(after decl: String, in code: String) throws -> String {
        guard let start = code.range(of: decl) else {
            throw AnchorMissing(reason: "`\(decl)` not found — re-anchor this scan")
        }
        var depth = 0
        var index = code.index(before: start.upperBound)   // the `{` that ends the declaration
        while index < code.endIndex {
            let ch = code[index]
            if ch == "{" { depth += 1 }
            if ch == "}" { depth -= 1; if depth == 0 { return String(code[start.lowerBound...index]) } }
            index = code.index(after: index)
        }
        throw AnchorMissing(reason: "unbalanced braces after `\(decl)`")
    }

    private func swiftSources() throws -> [URL] {
        let root = try repoRoot().appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            throw AnchorMissing(reason: "cannot enumerate Sources/")
        }
        var urls: [URL] = []
        for case let url as URL in walker where url.pathExtension == "swift" { urls.append(url) }
        return urls
    }

    private func source(_ relativePath: String) throws -> String {
        let path = try repoRoot().appendingPathComponent(relativePath)
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw AnchorMissing(reason: "\(relativePath) is missing while the tree is present — re-anchor this scan; do not let it skip.")
        }
        return SourceText.codeOnly(try String(contentsOf: path, encoding: .utf8))
    }

    private func repoRoot() throws -> URL {
        let here = URL(fileURLWithPath: #filePath)
        let root = here.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        guard FileManager.default.fileExists(
            atPath: root.appendingPathComponent("Sources").path) else {
            throw XCTSkip("source tree not present under \(root.path)")
        }
        return root
    }
}
