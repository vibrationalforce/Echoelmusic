// SaveWritesIntoTheOpenProjectTests.swift
// Echoel — DMMW Phase 5 · slice 2 (founder 2026-09-29: "Speichern/Wiederöffnen"). Every Save
// used to add a NEW library row: `currentProject()` never passes an id, so `Project.init` minted
// a fresh UUID each time and `ProjectStore.storeRow` — which replaces BY ID — never replaced
// anything. Open a piece, change a note, Save: the library grew a second "My piece" and the one
// the header named was the stale copy. A workstation keeps ONE row per piece.
//
// What the slice does, on the existing owners (no new modal, no new store method):
//   · `ProjectStore.currentProjectID` becomes readable (`public private(set)`); its writers stay
//     `noteCurrent`, `clearCurrent` and `delete`.
//   · The ONE Save alert offers "Save changes" (into the open project, same id, renamed if the
//     name was edited) and "Save as new" (the old behaviour, now deliberate) while a project is
//     open; with nothing open (a New piece, a fresh launch) it offers the one "Save".
//   · Both Save doors prefill the OPEN project's name, so "Save changes" does not rename it by
//     accident to a generated session name.
//
// Claims, labelled per `Tests/CISmoke/CLAUDE.md` §1:
//   1. END-TO-END over a real `ProjectStore` on an isolated directory: a save carrying the open
//      id replaces the row (count unchanged, renamed, header name follows); a save without it
//      adds a row and becomes the open project; the recovery slot never becomes it; New piece
//      and delete forget it.
//   2. SOURCE-TEXT SCAN: the alert's two branches and their actions; `saveIntoOpenProject` sets
//      the id BEFORE `withSession` and falls back to a new row, never a drop; both doors prefill
//      the open name; the id has no public setter.
// GRADING against the parent: claim 1 compiles only here (`currentProjectID` was private) —
// FORWARD guards, no verdict on the parent. Claim 2 is red on the parent by anchor absence
// (`saveIntoOpenProject`, "Save changes") — one absence, not several (#486). The counterweights
// (the recovery slot, delete, clearCurrent) are premises this slice relies on and did not change.
// Added with the review of b884e7a52 (HIGH): opening the AUTOSAVE row clears the open project —
// before, it kept the previous row open, and "Save changes" overwrote that piece with the recovered
// take. Red on b884e7a52 by anchor absence (the branch did not exist): one finding.
// ⛔ HONEST LIMITS. Alert button rendering and VoiceOver reading are a DEVICE PROBE. The
// library row keeps its place only by `storeRow`'s "newest first" — a Save changes moves the
// piece to the top, which is the store's rule for every write, not something this slice chose.
// NEEDS-FOUNDER-VERIFY: open a saved piece → change a note → Save → "Save changes" → the
// library still has ONE row with that name and reopening it shows the change.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class SaveWritesIntoTheOpenProjectTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"
    private static let storePath = "Sources/Echoelmusic/Core/ProjectStore.swift"

    private var writtenSubdirectories: [String] = []

    /// A store on its own subdirectory (the `AutosaveSlotTests` shape: UUID so a reused simulator
    /// container cannot hand a second run the first run's rows, and `tearDown` removes the file).
    private func isolatedStore(_ tag: String = #function) -> ProjectStore {
        let subdirectory = "EchoelTests-saveover-\(tag)-\(UUID().uuidString)"
        writtenSubdirectories.append(subdirectory)
        return ProjectStore(store: AppGroupStore(subdirectory: subdirectory))
    }

    override func tearDown() async throws {
        for subdirectory in writtenSubdirectories {
            AppGroupStore(subdirectory: subdirectory).delete(name: "projects.json")
        }
        writtenSubdirectories = []
    }

    private func take(named name: String, bpm: Double = 120) -> Project {
        Project(name: name, styleRaw: MusicStyle.offered.first?.rawValue ?? "ambient",
                keyRoot: 0, scaleRaw: Scale.major.rawValue, bpm: bpm,
                modeRaw: ComposerMode.flowFree.rawValue,
                fxCharacterRaw: FXCharacter.clean.rawValue,
                loopBars: 4, a4Hz: 440, toneSystemID: "edo12", moodFields: nil, artist: "",
                patch: SynthPatch(name: "Test"), notes: [], rawTake: nil,
                drumSteps: [], drumAccents: [])
    }

    // MARK: 1 — END-TO-END: one row per piece

    func testSaveChangesReplacesTheOpenRowAndSaveAsNewAddsOne() throws {
        let store = isolatedStore("replace")
        XCTAssertNil(store.currentProjectID, "a fresh store has no open project: the alert offers the one Save")

        let first = store.save(take(named: "My piece", bpm: 100))
        XCTAssertEqual(store.currentProjectID, first.id, "a Save makes its row the open project")
        XCTAssertEqual(store.projects.count, 1)

        // "Save changes": the same snapshot, carrying the open id — the saveIntoOpenProject shape.
        let openID = try XCTUnwrap(store.currentProjectID)
        var changed = take(named: "My piece (v2)", bpm: 112)
        changed.id = openID
        store.save(changed)
        XCTAssertEqual(store.projects.count, 1, """
            Save changes must REPLACE the open row — a second row per Save is the defect this \
            slice removes
            """)
        XCTAssertEqual(store.projects.first?.id, openID)
        XCTAssertEqual(store.projects.first?.name, "My piece (v2)", "an edited name renames the piece")
        XCTAssertEqual(store.projects.first?.bpm, 112, "the row carries the changed take")
        XCTAssertEqual(store.currentProjectName, "My piece (v2)", "the header follows the rename")
        XCTAssertEqual(store.currentProjectID, openID, "still the same piece")

        // "Save as new": no id carried — a second row, and it becomes the open project.
        let copy = store.save(take(named: "My piece copy"))
        XCTAssertEqual(store.projects.count, 2, "Save as new is the deliberate copy")
        XCTAssertNotEqual(copy.id, openID)
        XCTAssertEqual(store.currentProjectID, copy.id, "the copy is what the player now works on")
        XCTAssertEqual(store.currentProjectName, "My piece copy")
    }

    func testTheOpenProjectIsForgottenWhereTheAlertMustOfferOnlySave() {
        let store = isolatedStore("forget")
        let piece = store.save(take(named: "Piece"))

        // Counterweight: the recovery slot never becomes the open project (`noteCurrent`), so an
        // autosave cannot turn "Save changes" into a write over the slot.
        var auto = take(named: Project.autosaveNamePrefix + "Session")
        auto.id = Project.autosaveSlotID
        store.save(auto)
        XCTAssertEqual(store.currentProjectID, piece.id, "an autosave does not change the open project")

        // New piece → nothing open.
        store.clearCurrent()
        XCTAssertNil(store.currentProjectID, "after New piece the alert offers the one Save")
        XCTAssertNil(store.currentProjectName)

        // Open again (noteCurrent), then delete THAT row → nothing open.
        store.noteCurrent(piece)
        XCTAssertEqual(store.currentProjectID, piece.id)
        store.delete(id: piece.id)
        XCTAssertNil(store.currentProjectID, """
            a deleted piece cannot be saved over — the alert must offer Save, and \
            saveIntoOpenProject's fallback adds a row instead of writing into a ghost
            """)
    }

    // MARK: 2 — SOURCE: the alert, the writer, the doors

    func testTheSaveAlertOffersSaveChangesOnlyWhileAPieceIsOpen() throws {
        let code = try source(Self.studio)
        let actions = try member(".alert(\"Save project\", isPresented: $showSaveDialog) {", in: code)
        guard let branch = actions.range(of: "if projects.currentProjectName != nil {"),
              let changes = actions.range(of: "Button(\"Save changes\") { saveIntoOpenProject() }"),
              let asNew = actions.range(of: "Button(\"Save as new\") { saveProject() }"),
              let otherwise = actions.range(of: "} else {"),
              let plain = actions.range(of: "Button(\"Save\") { saveProject() }") else {
            return XCTFail("ANCHOR MISSING: the Save alert's two branches (#454)")
        }
        XCTAssertTrue(branch.upperBound <= changes.lowerBound && changes.upperBound <= asNew.lowerBound,
                      "with a piece open: Save changes first, then Save as new")
        XCTAssertTrue(asNew.upperBound <= otherwise.lowerBound && otherwise.upperBound <= plain.lowerBound,
                      "nothing open: the one Save, which adds a row")
        XCTAssertTrue(actions.contains("Button(\"Cancel\", role: .cancel) {}"))
        // The #495 promise below the buttons is untouched (its own guard owns the words).
        XCTAssertEqual(code.components(separatedBy: ".alert(\"Save project\"").count - 1, 1,
                       "still ONE Save alert — no new presentation modifier (black-screen law)")
    }

    func testSaveChangesCarriesTheOpenIdIntoTheSessionAndNeverDropsTheTake() throws {
        let code = try source(Self.studio)
        let body = try member("private func saveIntoOpenProject() {", in: code)
        guard let guardLine = body.range(of: "guard let openID = projects.currentProjectID else { saveProject(); return }"),
              let setID = body.range(of: "take.id = openID"),
              let write = body.range(of: "projects.save(withSession(take))") else {
            return XCTFail("ANCHOR MISSING: saveIntoOpenProject's three steps (#454)")
        }
        XCTAssertTrue(guardLine.upperBound <= setID.lowerBound && setID.upperBound <= write.lowerBound, """
            the id is set BEFORE withSession, so the Session is captured onto the row it belongs \
            to; with nothing open the take still lands as a new row
            """)
        XCTAssertTrue(body.contains("var take = currentProject()"),
                      "the SAME snapshot Save and Live Colabo take — one definition of a take (#416)")
        // Counterweight: Save as new is still the old writer, byte for byte.
        XCTAssertTrue(code.contains("projects.save(withSession(currentProject()))"))
    }

    func testBothSaveDoorsPrefillTheOpenPiecesName() throws {
        let code = try source(Self.studio)
        let prefill = "saveName = projects.currentProjectName ?? session.sessionName(bpm: beatPlayer.pattern.tempo)"
        XCTAssertEqual(code.components(separatedBy: prefill).count - 1, 2, """
            the Workstation's "save" door and SaveSessionButton both prefill the OPEN name — \
            otherwise "Save changes" would rename the piece to a generated session name
            """)
        XCTAssertEqual(code.components(separatedBy: "showSaveDialog = true").count - 1, 2,
                       "the two doors, and no third that skips the prefill")
    }

    /// ⛔ Review of b884e7a52 (HIGH). `noteCurrent` skips the recovery slot, so opening the
    /// Autosave row left the PREVIOUS row as the open project, and "Save changes" then wrote the
    /// recovered take over that other piece under its name. After a recovery nothing named is
    /// open: `open(_:)` must forget the open id for the slot and note it for every other row.
    func testOpeningTheAutosaveRowLeavesNoPieceToSaveOver() throws {
        let code = try source(Self.studio)
        let open = try member("private func open(_ p: Project) {", in: code)
        guard let branch = open.range(of: "if p.id == Project.autosaveSlotID {"),
              let clear = open.range(of: "projects.clearCurrent()"),
              let otherwise = open.range(of: "} else {"),
              let note = open.range(of: "projects.noteCurrent(p)") else {
            return XCTFail("ANCHOR MISSING: open(_:)'s open-project branch (#454)")
        }
        XCTAssertTrue(branch.upperBound <= clear.lowerBound && clear.upperBound <= otherwise.lowerBound
                        && otherwise.upperBound <= note.lowerBound,
                      "the recovery slot clears the open project; every other row becomes it")
        XCTAssertEqual(open.components(separatedBy: "projects.noteCurrent(").count - 1, 1,
                       "no unconditional noteCurrent left beside the branch")

        // The store half the branch relies on, end to end: after a recovery the alert's
        // condition (`currentProjectName != nil`) is false and there is no id to save over.
        let store = isolatedStore("recover")
        store.save(take(named: "B"))
        var auto = take(named: Project.autosaveNamePrefix + "Session")
        auto.id = Project.autosaveSlotID
        store.save(auto)
        store.noteCurrent(auto)
        XCTAssertNotNil(store.currentProjectID, "noteCurrent alone skips the slot — the defect's premise")
        store.clearCurrent()
        XCTAssertNil(store.currentProjectName)
        XCTAssertNil(store.currentProjectID)
    }

    func testTheOpenIdHasOneOwner() throws {
        let store = try source(Self.storePath)
        XCTAssertTrue(store.contains("@ObservationIgnored public private(set) var currentProjectID: UUID?"),
                      "readable for Save changes, writable only inside the store")
        let studio = try source(Self.studio)
        XCTAssertFalse(studio.contains("currentProjectID ="), "the view never writes the open id")
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

    /// The brace-matched body that starts at `anchor`, searched from the anchor's FIRST
    /// character, so an anchor ending in `{` opens the member itself (the #408 lesson: a search
    /// from the anchor's end skips that brace and returns the wrong block).
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
