// ALibraryRowIsRenamedInPlaceTests.swift
// Echoel — DMMW Phase 5 · slice 4 (founder 2026-09-29, Phase 5: "Öffnen, speichern, umbenennen
// und zuletzt bearbeitet anzeigen"). There was no rename. The only way to change a piece's name
// was to open it and "Save changes" under a new name — which also re-stamps the saved time and
// moves the row to the top, so a rename looked like a new take. A piece that was not open could
// not be renamed at all.
//
// What the slice does, on the existing owners (no modal, no second store, no presentation
// modifier):
//   · `ProjectStore.rename(id:to:)` — edits ONE row in place: same id, same position, same
//     `savedAt`; trims; refuses an empty name and the recovery slot; moves the header's name when
//     the renamed row is the open piece; returns whether the write is confirmed.
//   · the library row offers "Rename" in its long-press menu and as a VoiceOver action (never on
//     the Autosave row), and swaps itself for `LibraryRenameRow`, a leaf `View` that owns the
//     typed text.
//
// Claims, labelled per `Tests/CISmoke/CLAUDE.md` §1:
//   1. END-TO-END over a real `ProjectStore` on an isolated directory: in place, trimmed, refused
//      where it cannot hold, the header follows only the open row, a failed write is not confirmed.
//   2. SOURCE-TEXT SCAN: both doors reach `beginRename`, both are withheld from the recovery slot,
//      the one writer calls the store, both sections go through the one switch, and the leaf owns
//      the text (the root holds only the id).
// GRADING against the parent: claim 1 does not compile there (`rename(id:to:)` does not exist) —
// FORWARD guards, no verdict; hand-transcribed. Claim 2 is red there by ANCHOR ABSENCE
// (`libraryRow`, `beginRename`, `LibraryRenameRow`) — one absence (#486). Counterweights inside
// claim 2 (the Delete doors of slice 3, the swipe's own section arrays) are green on both trees.
// ⛔ HONEST LIMITS. The field's focus, the keyboard and VoiceOver reading the action are a DEVICE
// PROBE. At the largest Dynamic Type sizes the field and its two buttons share one line and the
// field narrows; it does not wrap. NEEDS-FOUNDER-VERIFY: Open → long-press a saved piece →
// Rename → type → Save → the row keeps its place and its "Saved …" time; with the piece open, the
// header shows the new name.

import Foundation
import XCTest
@testable import Echoelmusic

@MainActor
final class ALibraryRowIsRenamedInPlaceTests: XCTestCase {

    private static let studio = "Sources/Echoelmusic/Studio/EchoelStudioView.swift"

    private var writtenSubdirectories: [String] = []

    override func tearDown() async throws {
        for subdirectory in writtenSubdirectories {
            AppGroupStore(subdirectory: subdirectory).delete(name: "projects.json")
        }
        writtenSubdirectories = []
    }

    private func isolatedStore(_ tag: String, writeProjects: (([Project]) -> Bool)? = nil) -> ProjectStore {
        let subdirectory = "EchoelTests-rename-\(tag)-\(UUID().uuidString)"
        writtenSubdirectories.append(subdirectory)
        return ProjectStore(store: AppGroupStore(subdirectory: subdirectory), writeProjects: writeProjects)
    }

    private func take(named name: String) -> Project {
        Project(name: name, styleRaw: MusicStyle.offered.first?.rawValue ?? "ambient",
                keyRoot: 0, scaleRaw: Scale.major.rawValue, bpm: 110,
                modeRaw: ComposerMode.flowFree.rawValue,
                fxCharacterRaw: FXCharacter.clean.rawValue,
                loopBars: 4, a4Hz: 440, toneSystemID: "edo12", moodFields: nil, artist: "",
                patch: SynthPatch(name: "Test"), notes: [], rawTake: nil,
                drumSteps: [], drumAccents: [])
    }

    // MARK: 1 — END-TO-END: the store

    func testARenameKeepsTheRowsIdPlaceAndSavedTime() throws {
        let store = isolatedStore("inplace")
        let older = store.save(take(named: "First"))
        let newer = store.save(take(named: "Second"))
        XCTAssertEqual(store.projects.map(\.id), [newer.id, older.id], "newest first before the rename")
        let stamped = try XCTUnwrap(store.projects.last?.savedAt)

        XCTAssertTrue(store.rename(id: older.id, to: "  First, renamed \n"))
        XCTAssertEqual(store.projects.map(\.id), [newer.id, older.id], """
            a rename is not a new take: the row stays where it was (`save` would move it to the top)
            """)
        XCTAssertEqual(store.projects.last?.name, "First, renamed", "whitespace is trimmed")
        XCTAssertEqual(store.projects.last?.savedAt, stamped, "the saved time is the take's, not the name's")
        XCTAssertEqual(store.projects.count, 2, "no copy")
    }

    func testARenameIsRefusedWhereItCannotHold() {
        let store = isolatedStore("refuse")
        let piece = store.save(take(named: "Piece"))
        XCTAssertFalse(store.rename(id: piece.id, to: "   "), "an empty name is refused")
        XCTAssertEqual(store.projects.first?.name, "Piece")
        XCTAssertFalse(store.rename(id: UUID(), to: "Ghost"), "an unknown row is refused")

        var auto = take(named: Project.autosaveNamePrefix + "Session")
        auto.id = Project.autosaveSlotID
        store.save(auto)
        XCTAssertFalse(store.rename(id: Project.autosaveSlotID, to: "Mine"), """
            the recovery slot's name is rewritten by every autosave, so a rename there cannot hold
            """)
        XCTAssertEqual(store.projects.first { $0.id == Project.autosaveSlotID }?.name,
                       Project.autosaveNamePrefix + "Session")
        XCTAssertTrue(store.rename(id: piece.id, to: "Piece"), "the same name is a confirmed no-op")
    }

    func testTheHeaderFollowsOnlyTheOpenRow() {
        let store = isolatedStore("header")
        let a = store.save(take(named: "A"))
        let b = store.save(take(named: "B"))          // B is the open piece now
        XCTAssertEqual(store.currentProjectID, b.id)

        store.rename(id: a.id, to: "A2")
        XCTAssertEqual(store.currentProjectName, "B", "renaming another row leaves the header alone")

        store.rename(id: b.id, to: "B2")
        XCTAssertEqual(store.currentProjectName, "B2", "the open piece's new name reaches the header")
        XCTAssertEqual(store.currentProjectID, b.id)
    }

    func testAFailedWriteIsNotAConfirmedRename() {
        var allow = true
        let store = isolatedStore("fail", writeProjects: { _ in allow })
        let piece = store.save(take(named: "Kept"))
        allow = false
        XCTAssertFalse(store.rename(id: piece.id, to: "Lost"), "the write failed, so the rename is not confirmed")
        XCTAssertEqual(store.projects.first?.name, "Kept", "the visible library holds confirmed writes only")
        XCTAssertEqual(store.currentProjectName, "Kept", "the header keeps the confirmed name")
        XCTAssertNotNil(store.saveError, "the failure is retained like any save, so it can be retried")
    }

    // MARK: 2 — SOURCE: the doors, the writer, the leaf

    func testBothDoorsOpenTheRenameAndNeitherOffersItOnTheRecoverySlot() throws {
        let code = try source(Self.studio)
        let row = try member("private func projectRow(_ p: Project) -> some View {", in: code)
        let actions = try member(".accessibilityActions {", in: row)
        XCTAssertTrue(actions.contains("if p.id != Project.autosaveSlotID {")
                        && actions.contains("Button(\"Rename\") { beginRename(p) }"),
                      "VoiceOver reaches Rename as an action, and not on the Autosave row")
        let menu = try member(".contextMenu {", in: row)
        guard let gate = menu.range(of: "if p.id != Project.autosaveSlotID {"),
              let rename = menu.range(of: "Button { beginRename(p) } label: {"),
              let delete = menu.range(of: "Button(role: .destructive) { deleteFromLibrary(p) }") else {
            return XCTFail("ANCHOR MISSING: the row menu's Rename and Delete (#454)")
        }
        XCTAssertTrue(gate.upperBound <= rename.lowerBound && rename.upperBound <= delete.lowerBound,
                      "Rename sits behind the recovery-slot gate, before Delete")
        // Counterweight: slice 3's Delete action is untouched.
        XCTAssertTrue(row.contains(".accessibilityAction(named: \"Delete\") { deleteFromLibrary(p) }"))

        let begin = try member("private func beginRename(_ p: Project) {", in: code)
        XCTAssertTrue(begin.contains("guard p.id != Project.autosaveSlotID else { return }"))
        XCTAssertTrue(begin.contains("renamingProjectID = p.id"))
    }

    func testTheOneWriterAndTheOneSwitch() throws {
        let code = try source(Self.studio)
        let commit = try member("private func commitRename(_ p: Project, to name: String) {", in: code)
        XCTAssertTrue(commit.contains("projects.rename(id: p.id, to: name)"))
        XCTAssertTrue(commit.contains("renamingProjectID = nil"))
        XCTAssertEqual(code.components(separatedBy: "projects.rename(").count - 1, 1,
                       "one rename writer in the view")

        let sheet = try member("private var openSheet: some View {", in: code)
        XCTAssertTrue(sheet.contains("ForEach(saved) { p in libraryRow(p) }"))
        XCTAssertTrue(sheet.contains("ForEach(autosaved) { p in libraryRow(p) }"), """
            both sections go through the one switch — a section that called `projectRow` directly \
            could never show the rename field (#285: the two sections must not drift)
            """)
        XCTAssertTrue(sheet.contains(".onDisappear { renamingProjectID = nil }"))
        // Counterweight: the swipe still deletes out of each section's OWN array (#285).
        XCTAssertTrue(sheet.contains("idx.map { saved[$0].id }.forEach { projects.delete(id: $0) }"))
        XCTAssertTrue(sheet.contains("idx.map { autosaved[$0].id }.forEach { projects.delete(id: $0) }"))

        let lane = try member("private func libraryRow(_ p: Project) -> some View {", in: code)
        guard let branch = lane.range(of: "if renamingProjectID == p.id {"),
              let field = lane.range(of: "LibraryRenameRow(currentName: p.name,"),
              let plain = lane.range(of: "projectRow(p)") else {
            return XCTFail("ANCHOR MISSING: the row switch (#454)")
        }
        XCTAssertTrue(branch.upperBound <= field.lowerBound && field.upperBound <= plain.lowerBound)
    }

    func testTheLeafOwnsTheTypedTextAndSaveCannotLie() throws {
        let code = try source(Self.studio)
        let leaf = try member("private struct LibraryRenameRow: View {", in: code)
        XCTAssertTrue(leaf.contains("@State private var text = \"\""), "the text is the leaf's state")
        XCTAssertTrue(leaf.contains("TextField(\"Name\", text: $text)"))
        XCTAssertTrue(leaf.contains(".disabled(!canSave)"), "Save is off while the trimmed name is empty")
        XCTAssertTrue(leaf.contains(".onSubmit { if canSave { commit(text) } }"),
                      "Return cannot submit what Save would refuse")
        XCTAssertEqual(leaf.components(separatedBy: "minHeight: 44").count - 1, 3,
                       "the field and both buttons are 44-pt targets")
        // The root holds the id, never the text: keystrokes must not rebuild the root body.
        XCTAssertTrue(code.contains("@State private var renamingProjectID: UUID?"))
        XCTAssertFalse(code.contains("@State private var renameText"))
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
