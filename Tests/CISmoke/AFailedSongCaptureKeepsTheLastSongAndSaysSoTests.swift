//
//  AFailedSongCaptureKeepsTheLastSongAndSaysSoTests.swift
//  Restructure A1, step 2 (founder 2026-10-04, wörtlich: „Speicherfehler müssen sichtbar ankommen;
//  ein fehlgeschlagenes Sichern darf keinen stillen Projektverlust verursachen.")
//
//  THE DEFECT THIS PINS SHUT. A song that cannot be encoded (a non-finite value, #512) made
//  `attachSession` fail; `SessionSaveOpen` then returned the take WITHOUT a Session, and "Save
//  changes" wrote that row over the saved one — so the piece's song was gone from the library,
//  reopening it gave an empty song, and the only trace was a log line nobody sees.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claims 1–3) — `SessionSaveOpen`, `Project`, `ProjectStore` and the
//    song types are shipped; a lane level of NaN makes `JSONEncoder` throw, which is the real
//    failure, not a stand-in. `ProjectStore` gets an injected writer — no disk.
//  · SOURCE-TEXT SCAN (claims 4–5) — the Studio's capture uses the outcome form and reports it;
//    the banner shows the note. Both live in `View`s no test can instantiate.
//  · DEVICE PROBE, OPEN — the banner reading well. A non-finite song value cannot be produced
//    from the UI on purpose (every writer clamps), so there is no device step to ask for.
//
//  GRADING against the parent tree (#433/#464): the file does NOT compile there — it names
//  `SessionSaveOpen.Capture`, `keepingSongOf:` and `noteSongCapture`, created by this commit —
//  so no assertion has a verdict on the parent (ONE absence, #486). Claims 1–3 are FORWARD
//  guards, transcribed by reading `capturing(…keepingSongOf:)` → `capture` → `attachSession`;
//  claims 4–5's needles were grepped against the worktree and are absent on the parent.
//  COUNTERWEIGHT (#343): claim 2 — a song that DOES encode still replaces the previous one; the
//  new form keeps an old song only when the new one could not be written.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class AFailedSongCaptureKeepsTheLastSongAndSaysSoTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let banner = "Sources/Echoelmusic/Studio/ProjectSaveStatusView.swift"

    private static let take = Project(
        name: "Capture A", styleRaw: "ambient", keyRoot: 0, scaleRaw: "major", bpm: 96,
        modeRaw: "flowFree", fxCharacterRaw: "warm", loopBars: 4, a4Hz: 440,
        toneSystemID: nil, moodFields: nil, artist: "",
        patch: SynthPatch(name: "Default"), notes: [], rawTake: nil,
        drumSteps: [], drumAccents: [])

    private static let grid = [Clip?](repeating: nil, count: ClipStore.slotCount)

    private func capture(_ song: TimelineDocument, keeping previous: Project?) -> SessionSaveOpen.Capture {
        SessionSaveOpen.capturing(Self.take, timeline: song, clipSlots: Self.grid,
                                  songForm: Arrangement(), playerAutomation: [],
                                  sampleRate: 48_000, spatial: SpatialScene(),
                                  keepingSongOf: previous)
    }

    private static var goodSong: TimelineDocument {
        TimelineDocument(lanes: [TimelineLane(name: "Good", kind: .audio)], regions: [])
    }

    private static var brokenSong: TimelineDocument {
        var lane = TimelineLane(name: "Broken", kind: .audio)
        lane.level = .nan
        return TimelineDocument(lanes: [lane], regions: [])
    }

    // MARK: 1 — a song that cannot be written keeps the song the row was saved with

    func testABrokenSongKeepsTheLastSavedSong() throws {
        let first = capture(Self.goodSong, keeping: nil)
        XCTAssertTrue(first.songSaved, "premise: a finite song encodes")
        let savedEnvelope = try XCTUnwrap(first.project.sessionEnvelope)

        let second = capture(Self.brokenSong, keeping: first.project)
        XCTAssertFalse(second.songSaved, """
            premise: a NaN lane level must make the song fail to encode (#512). If this is green \
            the encoder or the lane type started sanitising, and this claim needs a new failure.
            """)
        XCTAssertEqual(second.project.sessionEnvelope, savedEnvelope, """
            A Save whose song could not be written left the row without the song it was saved \
            with. Reopening that piece would give an empty song — the silent loss A1 step 2 closes.
            """)
        guard case .restorable(let session) = second.project.readSession() else {
            return XCTFail("the kept song must still open")
        }
        XCTAssertEqual(session.content.timeline.lanes.first?.name, "Good")
    }

    // MARK: 2 — COUNTERWEIGHT: a song that encodes replaces the previous one

    func testAGoodSongStillReplacesThePreviousOne() throws {
        let first = capture(Self.goodSong, keeping: nil)
        var renamed = Self.goodSong
        renamed.lanes[0].name = "Newer"
        let second = capture(renamed, keeping: first.project)
        XCTAssertTrue(second.songSaved)
        guard case .restorable(let session) = second.project.readSession() else {
            return XCTFail("the new song must open")
        }
        XCTAssertEqual(session.content.timeline.lanes.first?.name, "Newer",
                       "keeping the old song is ONLY for a failed capture — a good Save writes the new one")
    }

    // MARK: 3 — a broken song with nothing older keeps nothing, and the store says so

    func testTheStoreSaysWhenTheSongWasNotSaved() {
        let orphan = capture(Self.brokenSong, keeping: nil)
        XCTAssertFalse(orphan.songSaved)
        XCTAssertNil(orphan.project.sessionEnvelope,
                     "nothing older to keep — the row must not claim a song it does not have")

        let store = ProjectStore(writeProjects: { _ in true })
        XCTAssertNil(store.songNotSavedNote, "a fresh store reports nothing")
        store.noteSongCapture(saved: false)
        let note = store.songNotSavedNote ?? ""
        XCTAssertTrue(note.contains("not the song"), "the note must say the SONG was not saved: \(note)")
        XCTAssertTrue(note.contains("last saved song was kept"), "and what was kept instead: \(note)")
        XCTAssertFalse(store.hasPendingSave, """
            The note must not block Open: the row reached the disk, and a song that cannot encode \
            would otherwise lock the player out of every other piece.
            """)
        store.noteSongCapture(saved: true)
        XCTAssertNil(store.songNotSavedNote, "the next Save that writes the song clears the note")
    }

    // MARK: 4 — the Studio's Save uses the outcome form and reports it

    func testTheStudioCaptureReportsTheOutcome() throws {
        let body = try member("private func withSession(_ take: Project) -> Project {", in: Self.studio)
        try assertOrder(in: body, ["SessionSaveOpen.capturing(",
                                   "keepingSongOf: projects.recoveryProject(id: take.id)",
                                   "projects.noteSongCapture(saved: capture.songSaved)",
                                   "return capture.project"],
                        why: "the capture keeps the row's last song and the Save reports whether the song made it")
    }

    // MARK: 5 — the banner shows it

    func testTheBannerShowsTheNote() throws {
        let code = SourceText.codeOnly(try text(Self.banner))
        for needle in ["if let note = projects.songNotSavedNote", "Label(\"Arrangement not saved\"", "Text(note)"] {
            XCTAssertTrue(code.contains(needle), "`ProjectSaveStatusView` lost `\(needle)` — the note would never reach the screen")
        }
    }

    // MARK: - helpers

    private func member(_ signature: String, in relative: String) throws -> String {
        let code = SourceText.codeOnly(try text(relative))
        XCTAssertEqual(code.components(separatedBy: signature).count - 1, 1,
                       "`\(signature)` must occur exactly once in \(relative) — re-anchor this guard")
        guard let start = code.range(of: signature) else {
            XCTFail("`\(signature)` is gone from \(relative) — re-anchor this guard on its new home")
            return ""
        }
        var depth = 1
        var index = start.upperBound
        while index < code.endIndex, depth > 0 {
            switch code[index] {
            case "{": depth += 1
            case "}": depth -= 1
            default: break
            }
            index = code.index(after: index)
        }
        return String(code[start.upperBound..<index])
    }

    private func assertOrder(in body: String, _ needles: [String], why: String) throws {
        XCTAssertFalse(body.isEmpty, "the declaration body is empty — the anchor missed")
        var cursor = body.startIndex
        for needle in needles {
            guard let hit = body.range(of: needle, range: cursor..<body.endIndex) else {
                XCTFail("`\(needle)` is missing or out of order. \(why)")
                return
            }
            cursor = hit.upperBound
        }
    }

    private func text(_ relative: String) throws -> String {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        let file = url.appendingPathComponent(relative)
        guard FileManager.default.fileExists(atPath: file.path) else {
            throw XCTSkip("\(relative) not on disk — this run has no source tree")
        }
        return try String(contentsOf: file, encoding: .utf8)
    }
}
