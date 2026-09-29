// TheLibraryRowSaysWhenAndDeletesWithoutASwipeTests.swift
// Echoel — DMMW Phase 5 · slice 3 (founder 2026-09-29: "Speichern/Wiederöffnen", and in every
// slice "nichts nur per horizontalem Wischen erreichbar"). Two defects in the one library row:
//   · `Project.savedAt` was stored on every row and shown on none — two saves of one piece read
//     identically, and the only way to tell them apart was to open one.
//   · Delete existed ONLY as the List's horizontal swipe (`.onDelete`), and a full swipe deletes at
//     once. VoiceOver already reaches it — `.onDelete` gives each row a "Delete" action — but a
//     sighted player without the swipe had no second road at all.
//     ⛔ The first version of this header said VoiceOver reached the swipe "only through a gesture
//     they must know" and added its own Delete action; that duplicated the one `.onDelete` already
//     provides (review of 648799434, LOW). The action is gone and claim 1 now forbids it.
//
// What the slice does, on the existing owners (no modal, no store method, no new presentation
// modifier — `.contextMenu` is not one):
//   · a third caption line, `Self.savedLine(p.savedAt)`;
//   · the open button is at least 44 pt tall and carries a VoiceOver hint;
//   · "Delete" in the row's long-press menu, through ONE private writer, `deleteFromLibrary`,
//     which calls `ProjectStore.delete(id:)` — the swipe's own store call.
//
// Claims, labelled per `Tests/CISmoke/CLAUDE.md` §1:
//   1. SOURCE-TEXT SCAN — `projectRow` mounts the date line, the 44-pt frame, the hint, the action
//      and the menu; the menu calls `deleteFromLibrary(p)`; the writer is one store call; the row
//      carries no second VoiceOver Delete beside the one `.onDelete` provides.
//   2. SOURCE-TEXT SCAN, COUNTERWEIGHTS — the swipe still maps through its OWN section arrays (the
//      data-loss rule `LibraryAutosaveSectionTests` owns; re-read here because this slice adds a
//      second delete road beside it) and the row still leads with the name.
//   3. END-TO-END over shipped value code — `savedLine` names the moment and tells two times of one
//      day apart; the hint promises no rescue; a delete of the OPEN row through the store forgets
//      the header name (the premise the menu's Delete relies on).
// GRADING against the parent: claim 1 is red there by ANCHOR ABSENCE — `deleteFromLibrary`,
// `savedLine` and `libraryRowHint` do not exist — ONE absence, reported per needle (#486). Claim 3
// does not compile against the parent (it names `savedLine`/`libraryRowHint`): FORWARD guards, no
// verdict there; hand-transcribed. Claim 2 is COUNTERWEIGHTS, green on both trees.
// ⛔ HONEST LIMITS. The row's rendering, the long-press menu, VoiceOver speaking the action and
// Dynamic Type reflow are a DEVICE PROBE. There is still no confirmation step: the swipe keeps its
// full-travel delete (the owning guard pins its handlers, not its style), and the long press is a
// deliberate two-step, not an "are you sure". The Autosave row can be deleted the same way — it is
// the user's slot. NEEDS-FOUNDER-VERIFY: Open → long-press a row → "Delete" → the row goes; with
// VoiceOver, swipe up/down on a row reaches "Delete".

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class TheLibraryRowSaysWhenAndDeletesWithoutASwipeTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"

    private var writtenSubdirectories: [String] = []

    override func tearDown() async throws {
        for subdirectory in writtenSubdirectories {
            AppGroupStore(subdirectory: subdirectory).delete(name: "projects.json")
        }
        writtenSubdirectories = []
    }

    // MARK: 1 — SOURCE: the row

    func testTheRowSaysWhenItWasSavedAndIsATallTarget() throws {
        let row = try member("private func projectRow(_ p: Project) -> some View {", in: try source(Self.studio))
        XCTAssertTrue(row.contains("Text(Self.savedLine(p.savedAt))"),
                      "the row shows when the take was written — `savedAt` had no reader on screen")
        XCTAssertTrue(row.contains(".frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)"),
                      "the open button is at least 44 pt tall, whatever lines the row carries")
        XCTAssertTrue(row.contains(".accessibilityHint(Self.libraryRowHint)"))
    }

    func testDeleteHasARoadBesideTheSwipeAndItTakesTheOneWriter() throws {
        let code = try source(Self.studio)
        let row = try member("private func projectRow(_ p: Project) -> some View {", in: code)
        XCTAssertFalse(row.contains("accessibilityAction(named: \"Delete\")"), """
            `.onDelete` already gives each row VoiceOver's Delete action; a second one lists Delete \
            twice in the rotor (review of 648799434)
            """)
        guard let menu = row.range(of: ".contextMenu {"),
              let destructive = row.range(of: "Button(role: .destructive) { deleteFromLibrary(p) }") else {
            return XCTFail("ANCHOR MISSING: the row's long-press Delete (#454)")
        }
        XCTAssertTrue(menu.upperBound <= destructive.lowerBound, "the destructive button sits inside the row's menu")
        XCTAssertEqual(row.components(separatedBy: ".contextMenu {").count - 1, 1,
                       "one menu on the row, built by the one row builder")

        let writer = try member("private func deleteFromLibrary(_ p: Project) {", in: code)
        XCTAssertTrue(writer.contains("projects.delete(id: p.id)"), "the store's own delete — it also forgets the open id")
        XCTAssertEqual(writer.components(separatedBy: "projects.").count - 1, 1,
                       "the writer is ONE store call: no second path that could delete a different row")
    }

    // MARK: 2 — COUNTERWEIGHTS

    func testTheSwipeStillDeletesOutOfItsOwnSectionAndTheRowLeadsWithTheName() throws {
        let code = try source(Self.studio)
        let sheet = try member("private var openSheet: some View {", in: code)
        XCTAssertTrue(sheet.contains("idx.map { saved[$0].id }.forEach { projects.delete(id: $0) }"))
        XCTAssertTrue(sheet.contains("idx.map { autosaved[$0].id }.forEach { projects.delete(id: $0) }"))
        XCTAssertFalse(sheet.contains("projects.projects[$0]"), "never an index into the whole array (#285)")
        let row = try member("private func projectRow(_ p: Project) -> some View {", in: code)
        guard let name = row.range(of: "Text(p.name)"),
              let when = row.range(of: "Text(Self.savedLine(p.savedAt))") else {
            return XCTFail("ANCHOR MISSING: the row's name and date lines (#454)")
        }
        XCTAssertTrue(name.upperBound <= when.lowerBound, "the name leads; the date is a caption under it")
    }

    // MARK: 3 — END-TO-END: the words and the store

    func testTheSavedLineNamesTheMomentAndTellsTwoTimesOfOneDayApart() {
        let morning = Date(timeIntervalSinceReferenceDate: 812_000_000)   // a fixed instant
        let evening = morning.addingTimeInterval(8 * 3600)
        let first = EchoelStudioView.savedLine(morning)
        XCTAssertTrue(first.hasPrefix("Saved "), first)
        XCTAssertGreaterThan(first.count, "Saved ".count, "a date follows the word")
        XCTAssertNotEqual(first, EchoelStudioView.savedLine(evening),
                          "two saves eight hours apart must not read the same — the time is part of the line")
    }

    func testTheHintPromisesNoRescue() {
        let hint = EchoelStudioView.libraryRowHint
        XCTAssertTrue(hint.hasPrefix("Opens this piece"), hint)
        XCTAssertFalse(hint.contains("Autosave"), """
            the autosave rescue is conditional (`autosaveTake()` writes only with parts or a \
            composed loop) and does not run for the Autosave row itself — the hint must not promise it
            """)
    }

    func testDeletingTheOpenRowForgetsTheHeaderName() {
        let subdirectory = "EchoelTests-rowdelete-\(UUID().uuidString)"
        writtenSubdirectories.append(subdirectory)
        let store = ProjectStore(store: AppGroupStore(subdirectory: subdirectory))
        let piece = store.save(Project(name: "Row", styleRaw: MusicStyle.offered.first?.rawValue ?? "ambient",
                                       keyRoot: 0, scaleRaw: Scale.major.rawValue, bpm: 100,
                                       modeRaw: ComposerMode.flowFree.rawValue,
                                       fxCharacterRaw: FXCharacter.clean.rawValue,
                                       loopBars: 4, a4Hz: 440, toneSystemID: "edo12", moodFields: nil,
                                       artist: "", patch: SynthPatch(name: "Test"), notes: [],
                                       rawTake: nil, drumSteps: [], drumAccents: []))
        XCTAssertEqual(store.currentProjectName, "Row")
        store.delete(id: piece.id)   // what `deleteFromLibrary` calls
        XCTAssertTrue(store.projects.isEmpty)
        XCTAssertNil(store.currentProjectName, "the header cannot name a piece the library no longer holds")
        XCTAssertNil(store.currentProjectID)
    }

    // MARK: - Helpers

    private struct AnchorMissing: Error {}

    private func source(_ relativePath: String) throws -> String {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { root.deleteLastPathComponent() }
        guard let text = try? String(contentsOf: root.appendingPathComponent(relativePath),
                                     encoding: .utf8) else {
            XCTFail("ANCHOR MISSING: cannot read \(relativePath) (#454)")
            throw AnchorMissing()
        }
        return SourceText.codeOnly(text)
    }

    /// The brace-matched body that starts at `anchor`, searched from the anchor's FIRST character
    /// (#408: a search from the anchor's end skips the opening brace and returns the wrong block).
    private func member(_ anchor: String, in code: String) throws -> String {
        guard let start = code.range(of: anchor),
              let open = code[start.lowerBound...].firstIndex(of: "{") else {
            XCTFail("ANCHOR MISSING: \(anchor) (#454)")
            throw AnchorMissing()
        }
        var depth = 0
        var cursor = open
        while cursor < code.endIndex {
            if code[cursor] == "{" { depth += 1 }
            if code[cursor] == "}" {
                depth -= 1
                if depth == 0 { return String(code[open...cursor]) }
            }
            cursor = code.index(after: cursor)
        }
        XCTFail("UNBALANCED: \(anchor)")
        throw AnchorMissing()
    }
}
