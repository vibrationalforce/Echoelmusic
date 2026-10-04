//
//  AFailedSaveNeverReplacesThePieceTests.swift
//  Restructure A1, step 1 (founder 2026-10-04, wörtlich: „Speicherfehler müssen sichtbar
//  ankommen; ein fehlgeschlagenes Sichern darf keinen stillen Projektverlust verursachen.")
//
//  THE DEFECT: Open and New piece rescue the live piece (`autosaveTake`) and then overwrite it,
//  and the overwrite writes THROUGH to disk (`TimelineStore.replaceDocument`,
//  `ClipStore.replaceSlots`). A failed library write left the rescue only in `ProjectStore`'s
//  memory — so the piece's last copy on disk was replaced while its only other copy lived in
//  RAM. `SessionController.replacementRefusal` refuses the replacement while the canonical
//  `ProjectStore.hasPendingSave` is true, and says so in words.
//
//  WHAT THIS PINS, by kind (Tests/CISmoke/CLAUDE.md §1):
//  · END-TO-END BEHAVIOUR (claims 1–2) — `ProjectStore` with an injected failing write, the
//    real `hasPendingSave`, the real `retrySave`, and `SessionController` on top of them.
//  · SOURCE-TEXT SCAN (claims 3–5) — the order inside `EchoelStudioView.open(_:)`,
//    `openFromLibrary(_:)` and `startNewPiece()`. All three are `private` on a `View`; no test
//    can call them, so the guard pins that the refusal sits BEFORE the first overwrite.
//  · DEVICE PROBE, OPEN — that the sentence appears next to the Open row / the New-piece row,
//    and that the banner's "Retry save" then lets the step through. Not observable here.
//
//  GRADING against the parent tree (#433/#464): the file does NOT compile there — it names
//  `SessionController`, created by this commit — so no assertion has a verdict on the parent.
//  All five claims are FORWARD guards; claims 3–5 were transcribed in Python against both
//  trees (the refusal needles are absent on the parent, present in order here). Claim 2's
//  "Retry save" counterweight and claim 1's no-pending half are green on both trees by
//  construction — they are the premises that make the refusal mean anything.
//
//  `Tests/CISmoke` is the blocking bundle.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class AFailedSaveNeverReplacesThePieceTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let banner = "Sources/Echoelmusic/Studio/ProjectSaveStatusView.swift"

    // MARK: 1 — the gate reads the store's own failure, and Retry lifts it

    func testAFailedSaveRefusesBothReplacementsUntilTheRetrySucceeds() {
        var acceptsWrites = false
        let store = ProjectStore(store: AppGroupStore(subdirectory: "ReplaceGate-\(UUID().uuidString)"),
                                 writeProjects: { _ in acceptsWrites })
        XCTAssertNil(SessionController.replacementRefusal(.open, hasPendingSave: store.hasPendingSave),
                     "with nothing pending, Open must go through — a gate that always refuses is a lock")
        XCTAssertNil(SessionController.replacementRefusal(.newPiece, hasPendingSave: store.hasPendingSave))

        store.save(Project(
            name: "Own composition", styleRaw: "ambient", keyRoot: 0,
            scaleRaw: "major", bpm: 96, modeRaw: "flowFree",
            fxCharacterRaw: "warm", loopBars: 4, a4Hz: 440,
            toneSystemID: nil, moodFields: nil, artist: "",
            patch: SynthPatch(name: "Default"), notes: [], rawTake: nil,
            drumSteps: [], drumAccents: []))
        XCTAssertTrue(store.hasPendingSave, "premise: a refused write leaves the save pending")
        XCTAssertNotNil(SessionController.replacementRefusal(.open, hasPendingSave: store.hasPendingSave), """
            A save failed and Open was allowed anyway. Open writes the next song through to disk, \
            so the failed piece's only remaining copy would be in memory.
            """)
        XCTAssertNotNil(SessionController.replacementRefusal(.newPiece, hasPendingSave: store.hasPendingSave), """
            A save failed and New piece was allowed anyway — the empty song is written through \
            to disk at once, the same loss as Open.
            """)

        acceptsWrites = true
        XCTAssertTrue(store.retrySave())
        XCTAssertNil(SessionController.replacementRefusal(.open, hasPendingSave: store.hasPendingSave),
                     "after a successful Retry the piece is on disk; Open must go through again")
        XCTAssertNil(SessionController.replacementRefusal(.newPiece, hasPendingSave: store.hasPendingSave))
    }

    // MARK: 2 — the refusal names the way out the banner already offers

    func testTheRefusalSaysNothingWasReplacedAndNamesTheRetry() throws {
        let open = try XCTUnwrap(SessionController.replacementRefusal(.open, hasPendingSave: true))
        let new = try XCTUnwrap(SessionController.replacementRefusal(.newPiece, hasPendingSave: true))
        XCTAssertNotEqual(open, new, "each refusal names the step the player tapped")
        for sentence in [open, new] {
            XCTAssertTrue(sentence.contains("nothing was replaced"),
                          "the refusal must say the piece in front is untouched: \(sentence)")
            XCTAssertTrue(sentence.contains("Retry save"),
                          "the refusal must name the banner's button: \(sentence)")
        }
        let banner = SourceText.codeOnly(try text(Self.banner))
        XCTAssertTrue(banner.contains("Button(\"Retry save\")"), """
            The banner's "Retry save" button is gone, and the refusal still sends the player to \
            it. Rename both together.
            """)
    }

    // MARK: 3 — Open refuses after the rescue and before the first overwrite

    func testOpenAsksAfterTheRescueAndBeforeTheFirstOverwrite() throws {
        let body = try function("private func open(_ p: Project) {")
        try assertOrder(in: body, [
            "autosaveTake()",
            "SessionController.replacementRefusal(.open, hasPendingSave: projects.hasPendingSave)",
            "return",
            "projects.noteCurrent(p)",
            "style = openStyle",
        ], why: """
            The refusal must sit AFTER the rescue (a rescue that failed right now is the case that \
            matters most) and BEFORE the first line that overwrites the piece in front.
            """)
    }

    // MARK: 4 — the library door does not install the song when Open refused

    func testTheLibraryDoorStopsWhenOpenRefused() throws {
        let body = try function("private func openFromLibrary(_ p: Project) {")
        try assertOrder(in: body, [
            "open(p)",
            "guard !projects.hasPendingSave else { return }",
            "SessionSaveOpen.restoreSong(",
        ], why: """
            `openFromLibrary` restores the song after `open(p)`. When `open(p)` refused, the song \
            must not be replaced either — `restoreSong` writes `timeline.json` through to disk.
            """)
    }

    // MARK: 5 — New piece refuses before the empty song is written

    func testNewPieceAsksBeforeTheEmptySongIsWritten() throws {
        let body = try function("private func startNewPiece() {")
        try assertOrder(in: body, [
            "autosaveTake()",
            "SessionController.replacementRefusal(.newPiece, hasPendingSave: projects.hasPendingSave)",
            "return",
            "SessionSaveOpen.startEmptySong(",
        ], why: """
            `startEmptySong` writes the empty song through to disk. The refusal must come after \
            the rescue and before it.
            """)
    }

    // MARK: - helpers

    /// The brace-matched body of the ONE function whose signature is `signature` (#408).
    private func function(_ signature: String) throws -> String {
        let code = SourceText.codeOnly(try text(Self.studio))
        let hits = code.components(separatedBy: signature).count - 1
        XCTAssertEqual(hits, 1, "`\(signature)` must occur exactly once — re-anchor this guard")
        guard let start = code.range(of: signature) else {
            XCTFail("`\(signature)` is gone from `EchoelStudioView` — re-anchor this guard on its new home")
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

    /// Each needle must occur, and each AFTER the previous one.
    private func assertOrder(in body: String, _ needles: [String], why: String) throws {
        XCTAssertFalse(body.isEmpty, "the function body is empty — the anchor missed")
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
