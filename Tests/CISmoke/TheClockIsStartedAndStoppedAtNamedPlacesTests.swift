//
//  TheClockIsStartedAndStoppedAtNamedPlacesTests.swift
//  Restructure A1, step 4 (founder 2026-10-04: „Verbinde anschließend A1 SessionController als
//  eindeutigen Besitzer des Ablaufs für Öffnen, Sichern und Abspielen. Verwende die bestehenden
//  kanonischen Zustände.")
//
//  Open and Save have their one gate in `SessionController` (steps 1–3). PLAY AND STOP ALREADY HAVE
//  ONE OWNER, and it is not moved: `ProjectTransport` derives the run state from the existing flags
//  (`Transport.isPlaying`, `TimelineRegionPlayer.isPlaying`, `RecordController.isRecording`,
//  `EngineBus.instrumentRunning`) and routes the ONE Stop and the head's resume. Moving that into a
//  new type would rename seven guarded call sites without changing one behaviour — the founder's
//  rule against tests that only follow the implementation. What was missing was a FENCE: nothing
//  stopped a new surface from calling `pattern.play(` or `pattern.stop()` directly and growing a
//  second play/stop truth beside the head's. This guard is that fence.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · SOURCE-TEXT SCAN (claims 1–2) — the census of every direct start/stop of the one clock in
//    `Sources/`, per file, and that each start names its cause (T1, `PatternEngine.PlayCause`).
//  · END-TO-END BEHAVIOUR (claim 3, COUNTERWEIGHT) — `ProjectTransport` is shipped and pure: the
//    ONE Stop still prefers the song's own stop, and a held session still resumes through it.
//  · DEVICE PROBE — none; this guard changes no behaviour.
//
//  GRADING against the parent tree (#433/#464): this commit changes no Swift under `Sources/`, so
//  every assertion has the SAME verdict on the parent — green. ZERO regressions: it is a RATCHET,
//  a forward guard by construction. The census was measured on the worktree with a Python
//  transcription of claim 1 (comment-stripped, same regex): 15 sites in 7 files, as listed.
//
//  ⚠️ A RED HERE IS NOT AN ORDER TO DELETE YOUR CALL (#364). A new owner of the clock may be
//  right — an export, a new player. Add it to `expected` IN THE SAME COMMIT, with its reason in
//  the commit body. A chrome control that plays or stops belongs to `ProjectTransport` instead.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

final class TheClockIsStartedAndStoppedAtNamedPlacesTests: XCTestCase {

    /// Every file under `Sources/` that starts or stops the one clock directly, and how often.
    /// The chrome reaches the clock only through `Studio/ProjectTransport.swift`; the two other
    /// `Studio/` files are the session's own start/stop (`EchoelStudioView.generate`,
    /// `stopEverything`) and the instrument plate's pause (`WorkspaceView.pause`, #179).
    private static let expected: [String: Int] = [
        "Echoelmusic/Audio/LoopExporter.swift": 4,              // offline render, `.loopExport`
        "Echoelmusic/EchoelmusicApp.swift": 1,                   // the app's shutdown stop
        "Echoelmusic/Sequencer/ArrangementPlayer.swift": 3,      // dormant player (no caller)
        "Echoelmusic/Sequencer/TimelineRegionPlayer.swift": 2,   // the song's play / stop
        "Echoelmusic/Studio/EchoelStudioView.swift": 2,          // the session's start / stop
        "Echoelmusic/Studio/ProjectTransport.swift": 2,          // the ONE Stop + the head's resume
        "Echoelmusic/Studio/WorkspaceView.swift": 1,             // the plate's pause (#179)
    ]

    private static let clockCall = "\\bpattern\\??\\.(play|stop)\\("

    // MARK: 1 — the census: no new direct start or stop of the clock appears unannounced

    func testEveryDirectClockCallIsInAKnownPlace() throws {
        let census = try clockCensus()
        XCTAssertEqual(census.counts, Self.expected, """
            The direct starts and stops of the one clock moved. A chrome control that plays or \
            stops must go through `ProjectTransport` (the head's one Play / Stop), never call \
            `pattern.play(` / `pattern.stop()` itself — a second call site is a second play/stop \
            truth. A genuinely new owner (an export, a player) is added to `expected` in the same \
            commit, with its reason. Census now: \(census.counts.sorted { $0.key < $1.key })
            """)
    }

    // MARK: 2 — every start names its cause (T1: the transport's play log says who)

    func testEveryDirectStartNamesItsCause() throws {
        let census = try clockCensus()
        XCTAssertFalse(census.plays.isEmpty, "premise: the census found the clock's starts")
        for (file, line) in census.plays {
            XCTAssertTrue(line.contains("play(cause: ."), """
                \(file) starts the clock without naming a cause: `\(line)`. The default is \
                `.unspecified`, which reads in a device log as "a new caller nobody named".
                """)
            XCTAssertFalse(line.contains("cause: .unspecified"), "\(file) names the anonymous cause")
        }
    }

    // MARK: 3 — COUNTERWEIGHT: the one Stop still routes through the canonical states

    func testTheOneStopStillRoutesThroughTheCanonicalStates() {
        XCTAssertEqual(ProjectTransport.stopAction(songPlaying: true, clockRunning: true), .song,
                       "a playing song is stopped by its own stop, which stops the clock in turn")
        XCTAssertEqual(ProjectTransport.stopAction(songPlaying: false, clockRunning: true), .clock)
        XCTAssertEqual(ProjectTransport.stopAction(songPlaying: false, clockRunning: false), .nothing)
        let held = ProjectTransport.Facts(clockRunning: false, songPlaying: false, recording: false,
                                          sessionRunning: true, songStartable: false)
        XCTAssertEqual(ProjectTransport.status(held), .paused)
        XCTAssertEqual(ProjectTransport.playAction(held, instrumentInFront: false), .resumeInstrument,
                       "a held session's Play resumes through the head, the one resume")
    }

    // MARK: - helpers

    private struct Census {
        var counts: [String: Int] = [:]
        var plays: [(String, String)] = []
    }

    private func clockCensus() throws -> Census {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        let base = root.appendingPathComponent("Sources")
        guard FileManager.default.fileExists(atPath: base.path),
              let walker = FileManager.default.enumerator(atPath: base.path) else {
            throw XCTSkip("Sources/ not on disk — this run has no source tree")
        }
        let regex = try NSRegularExpression(pattern: Self.clockCall)
        var census = Census()
        var seen = 0
        for case let rel as String in walker where rel.hasSuffix(".swift") {
            seen += 1
            let code = SourceText.codeOnly(
                try String(contentsOf: base.appendingPathComponent(rel), encoding: .utf8))
            for line in code.components(separatedBy: "\n") {
                let range = NSRange(line.startIndex..., in: line)
                let matches = regex.matches(in: line, range: range)
                guard !matches.isEmpty else { continue }
                census.counts[rel, default: 0] += matches.count
                if line.contains("pattern.play(") || line.contains("pattern?.play(") {
                    census.plays.append((rel, line.trimmingCharacters(in: .whitespaces)))
                }
            }
        }
        XCTAssertGreaterThan(seen, 200, """
            only \(seen) Swift files walked under Sources/; the tree holds several hundred, so the \
            census would be vacuous
            """)
        return census
    }
}
